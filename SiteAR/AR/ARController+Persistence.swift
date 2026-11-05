import ARKit
import RealityKit
import UIKit

/// Saving the room map and loading saved instructions and their image textures.
extension ARController {
    func reload(_ items: [Annotation], store: Store) async { guard !stopped else { return };annotations = items; await loadImageTextures(store:store); if !stopped { render() } }
    func loadImageTextures(store: Store) async {
        guard !stopped,!Task.isCancelled else { return }
        let generation=UUID();imageLoadGeneration=generation
        let validPaths=Set(annotations.compactMap { $0.image?.path })
        imageTextures=imageTextures.filter { validPaths.contains($0.key) }
        if localization.state == .aligned { render() }
        let budget=max(0,Self.maximumImageTextures-imageTextures.count)
        let pending=validPaths.filter { imageTextures[$0] == nil }.sorted()
        let missing=Array(pending.prefix(budget))
        hiddenImageCount=pending.count-missing.count
        guard !missing.isEmpty,!stopped,!Task.isCancelled else { loadingSavedImages=false;return }
        loadingSavedImages=true
        defer { if imageLoadGeneration == generation { loadingSavedImages=false } }
        for path in missing {
            guard imageLoadGeneration == generation,!stopped,!Task.isCancelled else { return }
            do {
                let data=try await store.downloadAsset(path:path)
                guard imageLoadGeneration == generation,!stopped,!Task.isCancelled else { return }
                let texture=try await SpatialImageAsset.loadTexture(data)
                guard imageLoadGeneration == generation,!stopped,!Task.isCancelled else { return }
                imageTextures[path]=texture
            } catch {
                guard imageLoadGeneration == generation,!stopped,!Task.isCancelled else { return }
                self.error="A saved image could not be loaded. Its task remains available in the list. \(error.localizedDescription)"
            }
        }
    }
    func saveMap(store: Store) async throws -> Room {
        let generation = mapSave.generation
        guard mode == .mapping, running, !stopped, !interrupted, trackingNormal else {
            throw AppError.message("The scan is paused. Recover tracking before saving the room.")
        }
        if let publication = mapSave.publication {
            try await store.publishRoom(publication)
            return try finishMapPublication(publication,generation:generation)
        }
        guard scan.canFinish else {
            throw AppError.message("Pause at textured views in all four directions from at least three positions. Wait for stable tracking, detected surfaces and a ready room map.")
        }
        if mapSave.data == nil {
            let guide:String?
            if saveScanGuide {
                guard let buffer=view.session.currentFrame?.capturedImage,
                      let encoded=await ScanGuideImage.capture(buffer) else {
                    throw AppError.message("Couldn't capture the optional scan-view photo. Hold the camera steady and retry, or turn it off in Scan options.")
                }
                try mapSave.validate(generation)
                guide=encoded
            } else { guide=nil }
            let map: ARWorldMap = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WorldMapHandoff, Error>) in
                view.session.getCurrentWorldMap { map, error in
                    if let error { continuation.resume(throwing: error) }
                    else if let map { continuation.resume(returning: WorldMapHandoff(map: map)) }
                    else { continuation.resume(throwing: AppError.message("ARKit could not produce a map.")) }
                }
            }.map
            try mapSave.validate(generation)
            guard map.anchors.contains(where: { $0.name == sentinelName }) else { throw AppError.message("Room anchor missing from map. Restart mapping.") }
            let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
            try mapSave.capture(data, generation: generation, guide:guide)
            savedMap = map
        }
        guard trackingNormal, mapped, let data = mapSave.data else { throw AppError.message("Tracking changed while saving. Recheck the room and retry.") }
        let root = "\(room.project_id.uuidString.lowercased())/\(room.id.uuidString.lowercased())/\(UUID().uuidString.lowercased())"
        let mapPath = root + ".worldmap"
        var updated = room; updated.map_path = mapPath
        updated.scan_guide_jpeg = mapSave.guide
        updated.surfaces = detectedSurfaces.values.sorted { $0.id.uuidString < $1.id.uuidString }
        try await store.uploadAsset(path: mapPath, data: data, type: "application/octet-stream")
        try mapSave.validate(generation)
        // An interrupted/restarted session must never publish or reuse its predecessor's snapshot.
        try mapSave.stage(updated, generation: generation)
        try await store.publishRoom(updated)
        return try finishMapPublication(updated,generation:generation)
    }

    private func finishMapPublication(_ published:Room,generation:UUID) throws -> Room {
        do { try mapSave.validateCompletion(generation) }
        catch {
            // Persistence succeeded, but identity alignment belongs to the previous AR session.
            room=published;mode = .walkthrough;running=false;ready=false;savedMap=nil
            cancelViewCapture();view.session.pause();localization.lose();clearVisuals();clearSurfaces()
            guidance=error.localizedDescription
            throw error
        }
        return published
    }

    /// Continue drawing immediately in the same verified manager session, without relocalizing.
    func beginEditing(_ savedRoom: Room) {
        room = savedRoom; mode = .editing; showSurfaceGuides = false; scannedThisSession = true
        localization.propose(.identity, method: .map); localization.confirm(normalTracking: trackingNormal)
        render(); refreshSurfaceVisuals()
        guidance = "Draw on detected surfaces. Drag for a line, or tap corners for an area."
    }
}

/// ARKit hands a freshly created map to exactly one callback; nothing else holds or mutates it,
/// so moving it to the main actor is safe even though `ARWorldMap` is not `Sendable`.
private struct WorldMapHandoff: @unchecked Sendable { let map: ARWorldMap }
