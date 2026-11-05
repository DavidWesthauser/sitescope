import ARKit
import RealityKit
import SwiftUI
import AVFoundation
import simd

struct FrozenDrawingFrame {
    let image: UIImage
    let viewProjection: simd_float4x4
    let viewport: CGSize
    let sessionFromRoom: Pose
}

/// All session callbacks are delivered on the main queue. Views never invent spatial positions.
@MainActor final class ARController: NSObject, ObservableObject, @preconcurrency ARSessionDelegate {
    @Published var localization = Localization()
    @Published var guidance = "Preparing camera…"
    @Published var trackingNormal = false
    @Published private(set) var trackingIssue:TrackingIssue = .initializing
    @Published var targetReady=false
    @Published var viewCapture=ViewCaptureRequest()
    var lockingView:Bool { viewCapture.isPending }
    @Published var mapped = false
    @Published var draft: [Point3] = []
    @Published var lineDraft=FreehandDraft()
    @Published var draftImage: UIImage?
    @Published var imageWidth: Float=0.4 { didSet { renderDraft() } }
    var imageData: Data?
    var draftImageTexture: TextureResource?
    var imageTextures: [String:TextureResource]=[:]
    var cachedImageTextureCount:Int { imageTextures.count }
    var imageLoadGeneration = UUID()
    var draftImageRequest = ViewCaptureRequest()
    @Published var loadingSavedImages = false
    /// Saved image instructions shown as outlines because the texture budget is full.
    @Published var hiddenImageCount = 0
    /// Textures are at most 1024 px per side (~5 MB with mipmaps), so this bounds image memory to roughly 170 MB.
    static let maximumImageTextures = 32
    @Published var imageLoading = false
    @Published var saveScanGuide = true
    var lastDraftRender: CFTimeInterval=0
    var aimPoint: CGPoint?
    var imageHeight: Float { imageWidth*Float((draftImage?.size.height ?? 1)/(draftImage?.size.width ?? 1)) }
    @Published var draftText = "" { didSet { renderDraft() } }
    @Published var frozenFrame: FrozenDrawingFrame?
    @Published var drawingPlane: Pose? // roomFromDrawingPlane; immutable for this stroke.
    @Published var selected: Annotation?
    @Published var error: String?
    @Published var ready = false
    let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
    var room: Room
    @Published var mode: ARMode
    /// True after Finish turns a fresh scan into drawing: alignment comes from this scan, not from recognizing a saved one.
    @Published var scannedThisSession = false
    @Published var scan = ScanProgress()
    @Published var surfaceTarget = "Find a surface"
    var targetedSurface: UUID? { didSet { if oldValue != targetedSurface { refreshSurfaceColors() } } }
    @Published var tool: AnnotationKind = .line { didSet { renderDraft() } }
    @Published var showSurfaceGuides = true { didSet { refreshSurfaceVisuals() } }
    var detectedSurfaces: [UUID: SurfacePatch] = [:]
    var surfaceEntities: [UUID: AnchorEntity] = [:]
    var surfaceStability:[UUID:SurfaceStability]=[:]
    var placementStability:[UUID:SurfaceStability]=[:]
    var placementTimes:[UUID:TimeInterval]=[:]
    var renderedPatches:[UUID:SurfacePatch]=[:]
    var outlineFade:AnimationResource?
    /// Written once in init and read only in deinit, so the nonisolated deinit cannot race with it.
    nonisolated(unsafe) private var memoryObserver:NSObjectProtocol?
    @Published private(set) var renderingReduced=false
    var cachedSurfaceCount:Int { detectedSurfaces.count }
    private var lastProgressUpdate: TimeInterval = 0
    private var lastMiniatureUpdate: TimeInterval = 0
    private var coverage = ScanCoverage()
    var annotations: [Annotation] = []
    var savedMap: ARWorldMap?
    var normalSince: TimeInterval?
    var startedAt = Date()
    var content: AnchorEntity?
    var preview: AnchorEntity?
    struct RenderedContent {
        struct Key: Equatable { let annotations: [Annotation]; let textures: Set<String>; let alignment: Pose }
        let key: Key; let anchor: AnchorEntity
    }
    var renderedContent: RenderedContent?
    var stopped = false
    var running = false
    private var restoredSentinel = false
    var interrupted = false
    private var tapRecognizer: UITapGestureRecognizer?
    var mapSave = MapSaveTransaction()

    init(room: Room, mode: ARMode) {
        self.room = room; self.mode = mode
        super.init()
        showSurfaceGuides = mode == .mapping
        // Overlays are flat unlit guides; skip camera post-processing and scene understanding the app never uses.
        view.renderOptions = [.disableMotionBlur,.disableDepthOfField,.disableCameraGrain,.disableHDR,.disableFaceMesh,.disablePersonOcclusion,.disableGroundingShadows]
        view.environment.sceneUnderstanding.options = []
        view.session.delegate = self; view.session.delegateQueue = .main
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        view.addGestureRecognizer(tap); tapRecognizer = tap
        view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragged(_:))))
        memoryObserver=NotificationCenter.default.addObserver(forName:UIApplication.didReceiveMemoryWarningNotification,object:nil,queue:.main) { [weak self] _ in
            Task { @MainActor in self?.reduceScanLoad() }
        }
    }
    deinit { if let memoryObserver { NotificationCenter.default.removeObserver(memoryObserver) } }
    func reduceScanLoad() {
        guard !renderingReduced else { return };renderingReduced=true
        releaseSurfaceRendering()
    }
    func prepare(store: Store) async {
        do {
            guard ARWorldTrackingConfiguration.isSupported else { throw AppError.message("This device does not support AR world tracking. Use the task list instead.") }
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else { throw AppError.message("Camera access is denied. Enable sitescope in Settings → Privacy & Security → Camera. Tasks remain available without AR.") }
            try room.validate()
            if mode != .mapping {
                try await store.loadAnnotations(room)
                annotations = store.annotations.filter { $0.room_id == room.id }
                try annotations.forEach { try $0.validate(room: room) }
                if let path = room.map_path {
                    do {
                        let data = try await store.downloadAsset(path: path)
                        guard let map = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data),
                              map.anchors.contains(where: { $0.name == sentinelName }) else { throw AppError.message("Map is corrupt or belongs to another coordinate system.") }
                        savedMap = map
                    } catch { self.error = "Map unavailable: \(error.localizedDescription). Ask the manager to restore the saved room map; tasks remain available." }
                }
            }
            guard !stopped else { return }; ready = true
            if mode == .mapping { startMapping() }
            else if savedMap != nil { startMap() }
            else { localization.fail();guidance="No room map is available. Open the task list or ask the manager to rescan this room." }
            if mode != .mapping {
                await loadImageTextures(store:store)
                if !stopped { render() }
            }
        } catch { updateTracking(.unavailable);self.error = error.localizedDescription; guidance = "AR unavailable · use the task list" }
    }
    var mapAvailable:Bool { savedMap != nil }
    var canChangeScanGuide:Bool { mapSave.data == nil }
    var sentinelName: String { "sitescope.room.\(room.coordinate_id.uuidString)" }
    private func configuration(map: ARWorldMap? = nil) -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.isAutoFocusEnabled=true
        config.initialWorldMap = map
        // No depth stream or environment probes: nothing reads them, and both cost GPU time every frame.
        config.environmentTexturing = .none
        return config
    }
    private func reset(_ config: ARWorldTrackingConfiguration) {
        mapSave.reset()
        if mode == .mapping { savedMap = nil }
        cancelViewCapture();frozenFrame = nil
        clearVisuals(); localization.searching(); normalSince = nil; restoredSentinel = false; scannedThisSession = false
        clearSurfaces(); scan = ScanProgress(); coverage = ScanCoverage(); lastProgressUpdate = 0;lastMiniatureUpdate = 0;renderingReduced=false
        trackingNormal = false; trackingIssue = .initializing; targetReady=false; mapped = false
        startedAt = Date(); running = true; interrupted = false
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }
    func startMapping() {
        guard ready else { return }
        reset(configuration())
        view.session.add(anchor: ARAnchor(name: sentinelName, transform: matrix_identity_float4x4))
        guidance = "Move slowly around the room. Look at textured walls, floor and furniture."
    }
    func startMap() {
        guard ready, let savedMap else { error = "No usable room map. Ask the manager to restore it; the task list remains available."; return }
        reset(configuration(map: savedMap)); guidance = "Searching for the room. Look at captured details from overlapping viewpoints."
    }
    func continueSearching() {
        guard running, savedMap != nil, localization.state == .failed else { return }
        localization.searching(); normalSince=nil; startedAt=Date()
        guidance="Search continues. Move to a scanned area and look at familiar details."
    }
    func confirm() {
        localization.confirm(normalTracking: trackingNormal)
        if localization.state == .aligned { render(); renderDraft(); refreshSurfaceVisuals(); guidance = "Room recognized. Saved drawings are visible." }
    }
    func stop() { mapSave.reset();imageLoadGeneration=UUID();loadingSavedImages=false;cancelImageRequest();cancelViewCapture();stopped = true; running = false; view.session.pause(); clearVisuals(); clearSurfaces();imageTextures.removeAll();renderedContent=nil }
    func suspend() {
        mapSave.reset()
        updateTracking(.unavailable)
        guard running else { return }; interrupted = true; localization.lose(); trackingNormal = false; leaveFrozenView(); clearVisuals(); hideSurfaces(); view.session.pause()
        guidance = mode == .mapping ? "Scan paused. Return to continue scanning." : "Session paused. Return to the same spot to recover alignment."
    }
    /// Re-run without reset: ARKit keeps its in-memory map and anchors and relocalizes against them
    /// (see `sessionShouldAttemptRelocalization`). A full reset would throw away the scan in progress.
    func resume() {
        guard interrupted, ready, running, !stopped else { return }; interrupted = false
        view.session.run(configuration())
        normalSince = nil; startedAt = Date()
        if mode != .mapping { localization.searching() }
        guidance = mode == .mapping ? "Scan resumed. Point at an area you already scanned so tracking can reconnect." : TrackingIssue.relocalizing.instruction
    }
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard running, !stopped, !interrupted else { return }
        let issue:TrackingIssue
        switch frame.camera.trackingState {
        case .normal: issue = .none
        case .notAvailable: issue = .unavailable
        case .limited(let reason):
            switch reason {
            case .initializing: issue = .initializing
            case .excessiveMotion: issue = .excessiveMotion
            case .insufficientFeatures: issue = .insufficientFeatures
            case .relocalizing: issue = .relocalizing
            @unknown default: issue = .unavailable
            }
        }
        updateTracking(issue)
        let normal=issue == .none
        // Apple's guidance: a map is worth saving once status is .mapped or .extending, never .limited/.notAvailable.
        let mapIsReady=frame.worldMappingStatus == .mapped || frame.worldMappingStatus == .extending
        if mapped != mapIsReady { mapped=mapIsReady }
        if frame.timestamp - lastProgressUpdate > (renderingReduced ? 0.5 : 0.25) {
            if ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical { reduceScanLoad() }
            lastProgressUpdate = frame.timestamp
            var progress = ScanProgress()
            progress.normalTracking = normal; progress.mapReady = mapped
            // Only threshold crossings matter to the UI. Quantizing keeps `scan` equal between ticks so SwiftUI stays idle.
            let stable = normal ? Double(frame.timestamp - (normalSince ?? frame.timestamp)) : 0
            progress.stableSeconds = min(2, (stable*2).rounded(.down)/2)
            progress.featureCount = min(frame.rawFeaturePoints?.points.count ?? 0, ScanProgress.minimumFeatureCount)
            let visible=ScanRenderingBudget.visiblePatches(Array(detectedSurfaces.values),camera:frame.camera.transform.columns.3.xyz,maximum:renderingReduced ? 12 : 24)
            // The miniature consolidates geometry on the main thread; refresh it once a second unless the set of patches changes.
            if frame.timestamp - lastMiniatureUpdate >= 1 || visible.map(\.id) != scan.surfaces.map(\.id) {
                progress.surfaces = visible; lastMiniatureUpdate = frame.timestamp
            } else { progress.surfaces = scan.surfaces }
            progress.observedSurfaceCount=detectedSurfaces.count
            progress.renderingReduced=renderingReduced
            if mode == .mapping {
                coverage.observe(position:frame.camera.transform.columns.3.xyz,forward:-frame.camera.transform.columns.2.xyz,
                                 reliable:normal && progress.hasUsefulFeatures && (frame.worldMappingStatus == .mapped || frame.worldMappingStatus == .extending),at:frame.timestamp)
            }
            let yaw=atan2(-frame.camera.transform.columns.2.x,-frame.camera.transform.columns.2.z)
            progress.cameraYaw=abs(ScanVisualization.shortAngle(from:scan.cameraYaw,to:yaw)-scan.cameraYaw)<0.035 ? scan.cameraYaw : yaw
            progress.coverage=coverage
            if scan != progress { scan = progress }
            updateTarget();renderScanSurfaces(visible:visible)
        }
        if normal { if normalSince == nil { normalSince = frame.timestamp } } else { normalSince = nil }
        if mode == .mapping {
            if !normal { setGuidance(issue.instruction) }
            else if !scan.hasUsefulFeatures { setGuidance("Look at a textured corner or door frame and pause briefly. More visible detail is needed for this view.") }
            else if !coverage.ready { setGuidance(coverage.instruction) }
            else if !mapped { setGuidance("Slowly revisit captured details so ARKit can connect the room map.") }
            else { setGuidance(scan.canFinish ? "Room map ready. Finish scanning to start drawing." : "Keep moving gently until surfaces are detected and tracking is stable.") }
            return
        }
        if !normal { setGuidance(issue.instruction) }
        // A locked view carries its own camera and alignment, so a tracking hiccup must not take it away mid-drawing.
        if !normal && frozenFrame == nil && localization.state == .aligned {
            localization.searching(); normalSince = nil; clearVisuals(); hideSurfaces(); startedAt = Date(); setGuidance(issue.instruction); return
        }
        if localization.recoverMap(restoredRoomAnchor: restoredSentinel, normalTracking: normal,
                                   stableSeconds: Double(frame.timestamp - (normalSince ?? frame.timestamp)),
                                   mapAvailable: frame.worldMappingStatus == .mapped || frame.worldMappingStatus == .extending) {
            render(); renderDraft(); refreshSurfaceVisuals()
            guidance = scannedThisSession ? "Tracking restored. Your drawings are back in place." : "Room recognized. Saved drawings are restored."
        }
        if localization.state == .relocalizing && Date().timeIntervalSince(startedAt) > 40 {
            localization.timedOut(); clearVisuals(); guidance = "Room not recognized yet. Look at captured corners and textured surfaces. Continue searching without a restart; drawings stay hidden."
        }
    }
    private func setGuidance(_ text:String) { if guidance != text { guidance=text } }
    func updateTracking(_ issue:TrackingIssue) {
        if trackingIssue != issue { trackingIssue=issue }
        let normal=issue == .none
        if trackingNormal != normal { trackingNormal=normal;if normal { refreshSurfaceVisuals() } else { hideSurfaces() } }
        if !normal {
            normalSince=nil;coverage.interrupt()
            if scan.normalTracking { scan.normalTracking=false;scan.stableSeconds=0;scan.coverage=coverage }
            surfaceStability.removeAll(keepingCapacity:true)
            placementStability.removeAll(keepingCapacity:true);placementTimes.removeAll(keepingCapacity:true)
            targetedSurface=nil
            cancelViewCapture();if targetReady { targetReady=false }
            if frozenFrame == nil, lineDraft.isDrawing { endStroke() }
        }
    }
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { process(anchors) }
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { process(anchors) }
    private func process(_ anchors: [ARAnchor]) {
        guard running, !interrupted, !stopped else { return }
        for anchor in anchors {
            if let plane = anchor as? ARPlaneAnchor { updateSurface(plane) }
            if anchor.name == sentinelName { restoredSentinel = true }

        }
    }
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            removeSurface(id:anchor.identifier)
            if anchor.name == sentinelName {
                restoredSentinel=false
                if mode != .mapping {
                    localization.searching();normalSince=nil;startedAt=Date()
                    clearVisuals();hideSurfaces()
                    setGuidance("The saved room anchor was lost. Look at previously scanned details to recover alignment.")
                }
            }
        }
    }
    // Preserve the current origin during transient tracking loss. Recovery/restart stays explicit.
    func sessionShouldAttemptRelocalization(_ session:ARSession) -> Bool { running && !stopped }
    func sessionWasInterrupted(_ session: ARSession) { mapSave.reset();updateTracking(.relocalizing); interrupted = true; localization.lose(); trackingNormal = false; leaveFrozenView(); clearVisuals(); hideSurfaces(); guidance = "AR interrupted. Recover alignment after returning." }
    func sessionInterruptionEnded(_ session: ARSession) { resume() }
    func session(_ session: ARSession, didFailWithError error: Error) { mapSave.reset();updateTracking(.unavailable); localization.fail(); leaveFrozenView(); clearVisuals(); hideSurfaces(); self.error = "AR session failed: \(error.localizedDescription). Close AR and reopen the room." }
}
