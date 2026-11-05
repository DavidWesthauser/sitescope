import ARKit
import RealityKit
import UIKit
import simd

/// Placement targeting, touch drawing, the locked view and draft image selection.
extension ARController {
    private func hit(_ point: CGPoint) -> simd_float4x4? {
        guard trackingNormal else { return nil }
        guard let query = view.makeRaycastQuery(from: point, allowing: .existingPlaneGeometry, alignment: .any),
              let result = view.session.raycast(query).first,
              let frame = view.session.currentFrame,
              let plane=result.anchor as? ARPlaneAnchor,let pose=try? Pose(plane.transform),
              placementSurfaceIsReady(id:plane.identifier,pose:pose,at:frame.timestamp) else { return nil }
        let distance = simd_distance(frame.camera.transform.columns.3.xyz,result.worldTransform.columns.3.xyz)
        guard distance >= 0.15, distance <= 5 else { return nil }
        return result.worldTransform
    }
    func updateTarget() {
        guard trackingNormal, let point=aimPoint,
              let query=view.makeRaycastQuery(from:point,allowing:.existingPlaneGeometry,alignment:.any),
              let result=view.session.raycast(query).first,
              let plane=result.anchor as? ARPlaneAnchor,
              let camera=view.session.currentFrame?.camera else {
            targetedSurface=nil; setTarget(ready:false,text:"Aim at a detected surface"); return
        }
        let distance=simd_distance(camera.transform.columns.3.xyz,result.worldTransform.columns.3.xyz)
        let settled=(try? Pose(plane.transform)).map { placementSurfaceIsReady(id:plane.identifier,pose:$0,at:view.session.currentFrame?.timestamp ?? 0) } ?? false
        let ready=settled && distance>=0.15 && distance<=5
        targetedSurface=ready ? plane.identifier : nil
        // A 5 cm readout avoids republishing the whole screen for millimetre jitter.
        setTarget(ready:ready,text:distance>5 ? "Move closer to the surface" : (distance<0.15 ? "Move slightly away from the surface" : (!settled ? "Surface refining — hold steady briefly" : String(format:"%@ · %.2f m",plane.alignment == .vertical ? "Vertical surface" : "Horizontal surface",(distance*20).rounded()/20))))
    }
    private func setTarget(ready:Bool,text:String) {
        if targetReady != ready { targetReady=ready }
        if surfaceTarget != text { surfaceTarget=text }
    }
    /// Placement tracking is independent of the display cache, including large/offscreen planes.
    func placementSurfaceIsReady(id:UUID,pose:Pose,at time:TimeInterval) -> Bool {
        if placementStability[id] == nil,placementStability.count>=4,
           let oldest=placementTimes.min(by:{$0.value<$1.value})?.key {
            placementStability.removeValue(forKey:oldest);placementTimes.removeValue(forKey:oldest)
        }
        var quality=placementStability[id] ?? surfaceStability[id] ?? SurfaceStability()
        quality.observe(pose,at:time);placementStability[id]=quality;placementTimes[id]=time
        return quality.isReady(at:time)
    }
    @objc func tapped(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: view)
        if mode != .mapping, localization.state == .aligned {
            var entity = view.entity(at: point)
            while let current = entity {
                if let id = UUID(uuidString: current.name), let item = annotations.first(where: { $0.id == id }) { selected = item; return }
                entity = current.parent
            }
            if mode == .editing && tool != .line { captureScreenPoint(point) }
        }
    }
    @objc func dragged(_ recognizer: UIPanGestureRecognizer) {
        guard mode == .editing, [.line,.arrow].contains(tool) else { return }
        switch recognizer.state {
        case .began: beginStroke(); captureScreenPoint(recognizer.location(in:view),reportMiss:false)
        case .changed: captureScreenPoint(recognizer.location(in:view),reportMiss:false)
        case .ended: captureScreenPoint(recognizer.location(in:view),reportMiss:false); endStroke()
        case .cancelled,.failed: endStroke()
        default: break
        }
    }
    func beginStroke() { if !lockingView && tool == .line && !lineDraft.isDrawing { lineDraft.begin() } }
    func endStroke() {
        if tool == .line { lineDraft.end(); draft=lineDraft.points; renderDraft() }
    }
    func captureScreenPoint(_ point: CGPoint, reportMiss: Bool = true) {
        // On a locked view the snapshot's own projection and alignment are authoritative; live tracking is not needed.
        guard mode == .editing, !lockingView, trackingNormal || frozenFrame != nil,
              let alignment = frozenFrame?.sessionFromRoom ?? localization.roomToSession else { return }
        if drawingPlane == nil {
            guard let hit = hit(point), let frame = view.session.currentFrame else {
                if reportMiss { error = "No surface here yet. Scan another angle, or use measured-distance placement." }; return
            }
            lockPlane(point: hit.columns.3.xyz, normal: hit.columns.1.xyz, camera: frame.camera)
        }
        guard let drawingPlane, let camera = view.session.currentFrame?.camera else { return }
        let viewport = frozenFrame?.viewport ?? view.bounds.size
        guard viewport.width>0, viewport.height>0 else { return }
        let vp = frozenFrame?.viewProjection ?? camera.projectionMatrix(for: .portrait, viewportSize: viewport, zNear: 0.01, zFar: 100) * camera.viewMatrix(for: .portrait)
        let normalized = SIMD2<Float>(Float(point.x/viewport.width),Float(point.y/viewport.height))
        guard let ray = DrawingGeometry.ray(screen: normalized, inverseViewProjection: simd_inverse(vp)),
              let sessionPlane = try? Pose(alignment.matrix*drawingPlane.matrix),
              let position = DrawingGeometry.intersection(ray, plane: sessionPlane) else { return }
        appendPoint(Point3((simd_inverse(alignment.matrix)*SIMD4(position,1)).xyz))
    }
    private func lockPlane(point: SIMD3<Float>, normal: SIMD3<Float>, camera: ARCamera) {
        guard let alignment = localization.roomToSession else { return }
        let right = simd_inverse(camera.viewMatrix(for: .portrait)).columns.0.xyz
        guard let plane = try? DrawingGeometry.plane(at: point, normal: normal, camera: camera.transform.columns.3.xyz, preferredRight: right) else { return }
        drawingPlane = try? Pose(simd_inverse(alignment.matrix)*plane.matrix)
    }
    private func appendPoint(_ point: Point3) {
        switch tool {
        case .text,.marker,.image: draft = [point]
        case .arrow:
            if draft.isEmpty { draft = [point] }
            else if simd_distance(draft[0].vector, point.vector)>0.02 {
                if draft.count == 1 { draft.append(point) } else { draft = [draft[0],point] }
            }
        case .line:
            lineDraft.append(point); draft=lineDraft.points
        case .area:
            if let previous = draft.last, simd_distance(previous.vector,point.vector)<0.015 { return }
            guard draft.count<128 else { return }; draft.append(point)
        }
        renderDraft(throttled:tool == .line && lineDraft.isDrawing)
    }
    func freezeView() {
        if frozenFrame != nil { resumeCamera(); return }
        guard mode == .editing, !lockingView, trackingNormal, let alignment = localization.roomToSession, let frame = view.session.currentFrame else { return }
        guard draft.isEmpty else { error = "Save or clear this drawing before locking a new view."; return }
        let viewport = view.bounds.size
        guard let hit = hit(aimPoint ?? CGPoint(x:viewport.width/2,y:viewport.height/2)) else {
            error = "Aim at a detected wall or floor and hold steady briefly while it refines. Use measured-distance placement if no surface is detected."; return
        }
        guard let request=viewCapture.begin() else { return }
        lockPlane(point: hit.columns.3.xyz, normal: hit.columns.1.xyz, camera: frame.camera)
        let vp = frame.camera.projectionMatrix(for: .portrait, viewportSize: viewport, zNear: 0.01, zFar: 100)*frame.camera.viewMatrix(for: .portrait)
        view.snapshot(saveToHDR: false) { [weak self] image in
            Task { @MainActor in
                guard let self,self.viewCapture.accepts(request) else { return }
                defer { self.viewCapture.finish(request) }
                guard let image,self.trackingNormal,self.localization.state == .aligned,!self.stopped else {
                    if self.draft.isEmpty { self.drawingPlane=nil };return
                }
                guard self.draft.isEmpty else { return }
                guard let current=self.view.session.currentFrame,
                      let before=try? Pose(frame.camera.transform),let after=try? Pose(current.camera.transform),
                      CameraCaptureQuality.isSteady(from:before,to:after) else {
                    self.drawingPlane=nil;self.error="Hold the phone steady for a moment, then lock the view again.";return
                }
                self.frozenFrame = FrozenDrawingFrame(image: image, viewProjection: vp, viewport: viewport, sessionFromRoom: alignment)
                self.guidance = "View locked. Draw or type on this fixed surface, then resume the camera."
            }
        }
    }
    func cancelViewCapture() {
        if viewCapture.isPending { viewCapture.cancel();if draft.isEmpty { drawingPlane=nil } }
    }
    func resumeCamera() {
        cancelViewCapture();frozenFrame = nil; if draft.isEmpty { drawingPlane = nil }
        // Tracking may have dropped while the view was locked; apply the deferred de-alignment now.
        if !trackingNormal, localization.state == .aligned { localization.searching(); normalSince=nil; startedAt=Date(); clearVisuals(); hideSurfaces(); guidance=trackingIssue.instruction }
    }
    /// Session-level loss (background, interruption, failure) still ends a locked view.
    func leaveFrozenView() { if lineDraft.isDrawing { endStroke() }; cancelViewCapture(); frozenFrame = nil; if draft.isEmpty { drawingPlane = nil } }
    /// Capture at the centre crosshair; manual distance is an explicit adjustment, never a silent fallback.
    func capture(distance: Float? = nil) {
        guard !lockingView else { return }
        guard trackingNormal, let frame = view.session.currentFrame else { error = "Wait for normal tracking."; return }
        let point = aimPoint ?? CGPoint(x:view.bounds.midX,y:view.bounds.midY)
        if mode == .editing, distance == nil || drawingPlane != nil { captureScreenPoint(point); return }
        var matrix: simd_float4x4
        if let distance {
            let viewport=view.bounds.size
            guard viewport.width>0, viewport.height>0 else { return }
            let vp=frame.camera.projectionMatrix(for:.portrait,viewportSize:viewport,zNear:0.01,zFar:100)*frame.camera.viewMatrix(for:.portrait)
            guard let ray=DrawingGeometry.ray(screen:SIMD2(Float(point.x/viewport.width),Float(point.y/viewport.height)),inverseViewProjection:simd_inverse(vp)),
                  let position=DrawingGeometry.measuredPoint(camera:frame.camera.transform.columns.3.xyz,direction:ray.direction,distance:distance) else { return }
            matrix=frame.camera.transform; matrix.columns.3=SIMD4(position,1)
        } else {
            guard let hit = hit(point) else { error = "No surface found. Move slowly, try another angle, or choose explicit distance placement."; return }; matrix = hit
        }
        let position = Point3(matrix.columns.3.xyz)
        if mode == .mapping { return }
        guard mode == .editing, let alignment = localization.roomToSession else { error = "Confirm room alignment before placing instructions."; return }
        if drawingPlane == nil { lockPlane(point: position.vector, normal: frame.camera.transform.columns.2.xyz, camera: frame.camera) }
        let roomPoint = (simd_inverse(alignment.matrix) * SIMD4(position.vector,1)).xyz
        appendPoint(Point3(roomPoint))
    }
    func undoPoint() {
        guard !draft.isEmpty else { return }
        if tool == .line { lineDraft.undo(); draft=lineDraft.points } else { draft.removeLast() }
        if draft.isEmpty && frozenFrame == nil { drawingPlane=nil }; renderDraft()
    }
    func clearDraft() { lineDraft.clear(); draft = []; if frozenFrame == nil { drawingPlane = nil }; if let preview { view.scene.removeAnchor(preview) }; preview = nil }
    func makeAnnotation(kind: AnnotationKind, title: String, detail: String, priority: Int, image: SpatialImage? = nil) throws -> Annotation {
        guard localization.roomToSession != nil, let first = draft.first else { throw AppError.message("Capture a point after aligning the room.") }
        var matrix = drawingPlane?.matrix ?? matrix_identity_float4x4
        matrix.columns.3 = SIMD4(first.vector,1)
        let inverse = simd_inverse(matrix)
        let paths = kind == .line ? lineDraft.strokes.filter { $0.count>=2 }.map { $0.map { Point3((inverse*SIMD4($0.vector,1)).xyz) } } : []
        let points = kind == .line ? Array((paths.first ?? []).prefix(128)) : draft.map { Point3((inverse*SIMD4($0.vector,1)).xyz) }
        var result = Annotation(room: room, kind: kind, pose: try Pose(matrix), points: points, title: title, detail: detail)
        result.priority = priority; result.image=image
        if kind == .line { result.strokes=paths }
        do { try result.validate(room: room) }
        catch { throw AppError.message(kind == .area ? "Tap at least three corners on the same surface; the first three must not be on one straight line." : (kind == .image ? "Check the image, its size and position on the surface." : "Draw at least one stroke, then lift your finger.")) }
        return result
    }
    func beginImageRequest(clearExisting:Bool = false) -> UUID {
        draftImageRequest.cancel()
        let request=draftImageRequest.begin()!
        imageLoading=true
        if clearExisting { imageData=nil;draftImage=nil;draftImageTexture=nil;renderDraft() }
        return request
    }
    func imageRequestIsCurrent(_ request:UUID) -> Bool { !stopped && draftImageRequest.accepts(request) }
    func finishImageRequest(_ request:UUID) { if draftImageRequest.finish(request) { imageLoading=false } }
    func cancelImageRequest() { draftImageRequest.cancel();imageLoading=false }
    func setImage(_ data: Data,request:UUID? = nil) async throws {
        if let request, !imageRequestIsCurrent(request) { throw CancellationError() }
        let asset=try await SpatialImageAsset.prepare(data)
        guard !stopped,request.map(imageRequestIsCurrent) ?? true else { throw CancellationError() }
        imageData=asset.data; draftImage=asset.image; draftImageTexture=asset.texture
        imageWidth=min(0.4,3/Float(asset.image.size.height/asset.image.size.width)); renderDraft()
    }
    func restoreImageDraft(_ item: Annotation, store: Store, request:UUID) async throws {
        guard let image=item.image else { return }
        let data=try await store.downloadAsset(path:image.path)
        try await setImage(data,request:request)
        guard imageRequestIsCurrent(request) else { throw CancellationError() }
        imageWidth=image.width
    }
}
