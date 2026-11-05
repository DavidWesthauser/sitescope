import ARKit
import RealityKit
import UIKit
import simd

/// Detected-plane metadata cache and the bounded outline renderer used while scanning.
extension ARController {
    func updateSurface(_ plane: ARPlaneAnchor) {
        let boundary=ScanRenderingBudget.displayBoundary(plane.geometry.boundaryVertices.map(Point3.init),maximum:64)
        guard boundary.count>=3,let pose=try? Pose(plane.transform) else { removeSurface(id:plane.identifier);return }
        let patch=SurfacePatch(id:plane.identifier,pose:pose,vertices:boundary,vertical:plane.alignment == .vertical)
        updateSurfacePatch(patch)
        guard trackingNormal,detectedSurfaces[patch.id] != nil else { return }
        var stability=surfaceStability[patch.id] ?? SurfaceStability()
        stability.observe(pose,at:view.session.currentFrame?.timestamp ?? ProcessInfo.processInfo.systemUptime)
        surfaceStability[patch.id]=stability
    }
    func removeSurface(id:UUID) {
        detectedSurfaces.removeValue(forKey:id);surfaceStability.removeValue(forKey:id)
        placementStability.removeValue(forKey:id);placementTimes.removeValue(forKey:id)
        renderedPatches.removeValue(forKey:id)
        if let root=surfaceEntities.removeValue(forKey:id) {
            root.isEnabled=false
            for child in Array(root.children) { child.removeFromParent() }
            view.scene.removeAnchor(root)
        }
        if targetedSurface == id { targetedSurface=nil;targetReady=false }
        if scan.surfaces.contains(where:{$0.id == id}) {
            scan.surfaces.removeAll(where:{$0.id == id});scan.observedSurfaceCount=detectedSurfaces.count
        }
    }
    /// Coalesce AR callbacks into a bounded metadata cache. Rendering occurs once per UI tick.
    func updateSurfacePatch(_ input:SurfacePatch) {
        var patch=input
        patch.vertices=ScanRenderingBudget.displayBoundary(input.vertices,maximum:64)
        guard patch.vertices.count>=3 else { removeSurface(id:patch.id);return }
        if detectedSurfaces[patch.id] == nil,detectedSurfaces.count>=128 {
            let camera=view.session.currentFrame?.camera.transform.columns.3.xyz ?? .zero
            func distance(_ item:SurfacePatch) -> Float { simd_distance_squared(item.pose.matrix.columns.3.xyz,camera) }
            guard let farthest=detectedSurfaces.values.max(by:{distance($0)<distance($1)}),distance(patch)<distance(farthest) else { return }
            detectedSurfaces.removeValue(forKey:farthest.id);surfaceStability.removeValue(forKey:farthest.id)
        }
        detectedSurfaces[patch.id]=patch
    }
    /// At most 24 patches and two drawables per patch; never one entity/animation per edge.
    /// `nearest` is the tick's already-ranked patch list, so ranking runs once per tick.
    func renderScanSurfaces(visible nearest:[SurfacePatch]? = nil) {
        guard trackingNormal,mode == .mapping || localization.state == .aligned else { hideSurfaces();return }
        let visible:[SurfacePatch]
        if showSurfaceGuides {
            let camera=view.session.currentFrame?.camera.transform.columns.3.xyz ?? .zero
            visible=nearest ?? ScanRenderingBudget.visiblePatches(Array(detectedSurfaces.values),camera:camera,maximum:renderingReduced ? 12 : 24)
        }
        else if mode == .editing,drawingPlane == nil,let id=targetedSurface,let patch=detectedSurfaces[id] { visible=[patch] }
        else { visible=[] }
        // ARKit refines most planes every frame. Rebuilding every outline each tick caused periodic main-thread
        // hitches, so new outlines always appear but refinements of existing ones are spread across ticks (nearest first).
        var refinements=renderingReduced ? 2 : 4
        let ids=Set(visible.map(\.id))
        for id in Array(surfaceEntities.keys) where !ids.contains(id) {
            if let root=surfaceEntities.removeValue(forKey:id) { view.scene.removeAnchor(root) }
            renderedPatches.removeValue(forKey:id)
        }
        for patch in visible {
            let root:AnchorEntity
            if let existing=surfaceEntities[patch.id] { root=existing }
            else {
                root=AnchorEntity(world:SIMD3<Float>.zero);surfaceEntities[patch.id]=root
                view.scene.addAnchor(root)
            }
            root.isEnabled=true;root.transform=Transform(matrix:patch.pose.matrix)
            let firstGeometry=renderedPatches[patch.id] == nil
            if let rendered=renderedPatches[patch.id] {
                if Self.outlineMatches(rendered.vertices,patch.vertices) { continue }
                guard refinements>0 else { continue }; refinements -= 1
            }
            let points=ScanRenderingBudget.displayBoundary(patch.vertices,maximum:renderingReduced ? 12 : 24)
                .map { Point3($0.vector+SIMD3<Float>(0,0.003,0)) }
            var allRendered=true
            for halo in (renderingReduced ? [false] : [true,false]) {
                let name=halo ? "halo" : "edge"
                guard let geometry=ScanRenderingBudget.outline(points,thickness:halo ? 0.013 : 0.0035) else {
                    root.findEntity(named:name)?.removeFromParent();allRendered=false;continue
                }
                var descriptor=MeshDescriptor(name:"Batched scan outline")
                descriptor.positions=MeshBuffers.Positions(geometry.positions);descriptor.primitives = .triangles(geometry.indices)
                guard let mesh=try? MeshResource.generate(from:[descriptor]) else {
                    root.findEntity(named:name)?.removeFromParent();allRendered=false;continue
                }
                if let model=root.findEntity(named:name) as? ModelEntity {
                    model.model=ModelComponent(mesh:mesh,materials:[outlineMaterial(halo:halo,selected:patch.id == targetedSurface)])
                } else {
                    let model=ModelEntity(mesh:mesh,materials:[outlineMaterial(halo:halo,selected:patch.id == targetedSurface)])
                    model.name=name;root.addChild(model)
                }
            }
            if allRendered {
                renderedPatches[patch.id]=patch
                if firstGeometry { revealOutline(root) }
            } else { renderedPatches.removeValue(forKey:patch.id) }
        }
    }
    /// Sub-centimetre boundary jitter is invisible at room scale and not worth a new mesh.
    private static func outlineMatches(_ a:[Point3],_ b:[Point3]) -> Bool {
        a.count == b.count && zip(a,b).allSatisfy { simd_distance_squared($0.vector,$1.vector) < 0.0001 }
    }
    /// One engine-managed animation per outline, without per-frame mesh regeneration.
    private func revealOutline(_ root:Entity) {
        guard !renderingReduced,!UIAccessibility.isReduceMotionEnabled else { return }
        if #available(iOS 18.0,*) {
            root.components.set(OpacityComponent(opacity:1))
            if outlineFade == nil {
                outlineFade=try? AnimationResource.generate(with:FromToByAnimation<Float>(from:0.15,to:1,duration:0.45,timing:.easeOut,bindTarget:.opacity,fillMode:.forwards))
            }
            if let outlineFade { root.playAnimation(outlineFade) }
        }
    }
    private func outlineMaterial(halo:Bool,selected:Bool) -> UnlitMaterial {
        var material=UnlitMaterial(color:selected ? .systemMint : .white)
        if halo { material.blending = .transparent(opacity:.init(floatLiteral:0.1)) }
        return material
    }
    func refreshSurfaceVisuals() {
        let allowed = trackingNormal && (mode == .mapping || localization.state == .aligned)
        for (id,entity) in surfaceEntities {
            entity.isEnabled = allowed && (showSurfaceGuides || (mode == .editing && drawingPlane == nil && id == targetedSurface))
        }
    }
    func refreshSurfaceColors() {
        for (id,entity) in surfaceEntities {
            for child in entity.children {
                if let model=child as? ModelEntity { model.model?.materials=[outlineMaterial(halo:child.name.hasPrefix("halo"),selected:id == targetedSurface)] }
            }
        }
    }
    func hideSurfaces() { for entity in surfaceEntities.values { entity.isEnabled = false } }
    func releaseSurfaceRendering() {
        for entity in surfaceEntities.values { view.scene.removeAnchor(entity) }
        surfaceEntities=[:];renderedPatches=[:]
    }
    func clearSurfaces() {
        releaseSurfaceRendering();detectedSurfaces=[:];surfaceStability=[:];placementStability=[:];placementTimes=[:]
    }
}
