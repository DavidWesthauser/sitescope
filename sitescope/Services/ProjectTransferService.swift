import Foundation

/// Exports an on-device project as a `.sitescope` file and imports such files as independent copies.
/// The archive format itself is `ProjectTransferArchive` in Core.
@MainActor final class ProjectTransferService {
    private let storage: LocalDataStore
    init(storage: LocalDataStore) { self.storage = storage }

    /// A portable copy of a local project. The share UI owns cleanup of the returned temporary folder.
    func export(_ project: Project) async throws -> URL {
        let data = storage.data
        guard let saved = data.projects.first(where: { $0.id == project.id }) else {
            throw AppError.message("Project no longer exists.")
        }
        var exportedRooms = data.rooms.filter { $0.project_id == saved.id }
        // The current workflow uses room-map recognition; obsolete recovery targets are not transferred.
        for index in exportedRooms.indices {
            exportedRooms[index].marker = nil
            exportedRooms[index].reference_points = []
            exportedRooms[index].reference_notes = ""
        }
        let roomIDs = Set(exportedRooms.map(\.id))
        let exportedAnnotations = data.annotations.filter { roomIDs.contains($0.room_id) }
        let assetRoot = storage.assetRoot
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(
            "sitescope-Export-\(UUID().uuidString)", isDirectory: true)
        let file = destination.appendingPathComponent("sitescope-\(saved.id.uuidString.prefix(8)).sitescope")
        let snapshotRooms = exportedRooms
        return try await Task.detached(priority: .userInitiated) {
            do {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
                try FileManager.default.createDirectory(at: assetRoot, withIntermediateDirectories: true)
                try ProjectTransferArchive.write(
                    project: saved, rooms: snapshotRooms, annotations: exportedAnnotations, assetRoot: assetRoot,
                    to: file)
                return file
            } catch {
                try? FileManager.default.removeItem(at: destination)
                throw error
            }
        }.value
    }

    /// Imports an independent copy owned by `owner`; existing projects, identifiers and coordinate systems are
    /// never replaced.
    func importProject(from source: URL, owner: UUID) async throws -> Project {
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        let folder = storage.fileURL.deletingLastPathComponent()
        let stage = folder.appendingPathComponent(".sitescope-transfer-\(UUID().uuidString)", isDirectory: true)
        let extracted = stage.appendingPathComponent("extracted", isDirectory: true)
        let assetsRoot = storage.assetRoot
        // Staging: everything is extracted and validated in a hidden folder first. The project becomes visible
        // only in the single `storage.change` commit, so a failure leaves existing data untouched.
        // The catch removes any partial files.
        var installedAssets: URL?
        do {
            let manifest = try await Task.detached(priority: .userInitiated) {
                try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: false)
                return try ProjectTransferArchive.read(from: source, extractTo: extracted)
            }.value
            try Task.checkCancellation()
            let existing = storage.data
            var identifiers = Set(
                existing.projects.map(\.id) + existing.rooms.map(\.id) + existing.annotations.map(\.id))
            func newID() -> UUID {
                var id = UUID()
                while !identifiers.insert(id).inserted { id = UUID() }
                return id
            }
            let project = Project(id: newID(), owner_id: owner, name: try DisplayName.validated(manifest.project.name))
            var roomIDs: [UUID: UUID] = [:]
            for room in manifest.rooms { roomIDs[room.id] = newID() }
            var paths: [String: String] = [:]
            for asset in manifest.assets {
                let parts = asset.path.split(separator: "/", omittingEmptySubsequences: false)
                guard parts.count >= 3, let oldRoom = UUID(uuidString: String(parts[1])), let newRoom = roomIDs[oldRoom]
                else {
                    throw ProjectTransferArchive.Failure.invalidProject
                }
                paths[asset.path] =
                    "\(project.id.uuidString.lowercased())/\(newRoom.uuidString.lowercased())/"
                    + parts.dropFirst(2).joined(separator: "/")
            }
            func remap(_ path: String) throws -> String {
                guard let mapped = paths[path] else { throw ProjectTransferArchive.Failure.missingAsset }
                return mapped
            }
            var importedRooms: [Room] = []
            for original in manifest.rooms {
                guard let id = roomIDs[original.id] else { throw ProjectTransferArchive.Failure.invalidProject }
                var room = original
                room.id = id
                room.project_id = project.id
                room.name = try DisplayName.validated(original.name)
                room.marker = nil
                room.reference_points = []
                room.reference_notes = ""
                room.map_path = try original.map_path.map(remap)
                try room.validate()
                importedRooms.append(room)
            }
            let newRooms = Dictionary(uniqueKeysWithValues: importedRooms.map { ($0.id, $0) })
            var importedAnnotations: [Annotation] = []
            for original in manifest.annotations {
                guard let roomID = roomIDs[original.room_id], let room = newRooms[roomID] else {
                    throw ProjectTransferArchive.Failure.invalidProject
                }
                var annotation = original
                annotation.id = newID()
                annotation.room_id = roomID
                if var image = annotation.image {
                    image.path = try remap(image.path)
                    annotation.image = image
                }
                try annotation.validate(room: room)
                importedAnnotations.append(annotation)
            }
            // Every asset path was inserted into `paths` in the loop above, so this lookup cannot fail.
            let assetCopies = manifest.assets.map { (source: $0.path, destination: paths[$0.path]!) }
            let projectAssets = assetsRoot.appendingPathComponent(project.id.uuidString.lowercased(), isDirectory: true)
            try await Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                try fm.createDirectory(at: assetsRoot, withIntermediateDirectories: true)
                let attributes = try fm.attributesOfItem(atPath: assetsRoot.path)
                guard attributes[.type] as? FileAttributeType == .typeDirectory else {
                    throw ProjectTransferArchive.Failure.unsafeFile
                }
                guard !fm.fileExists(atPath: projectAssets.path) else {
                    throw ProjectTransferArchive.Failure.destinationExists
                }
                let prepared = stage.appendingPathComponent("prepared-assets", isDirectory: true)
                try fm.createDirectory(at: prepared, withIntermediateDirectories: false)
                for copy in assetCopies {
                    // The archive codec has already validated each path and extracted regular files.
                    let suffix = copy.destination.split(separator: "/").dropFirst().joined(separator: "/")
                    let target = prepared.appendingPathComponent(suffix)
                    try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try fm.copyItem(at: extracted.appendingPathComponent(copy.source), to: target)
                }
                // FileManager refuses an existing destination. Only this new project's asset tree moves.
                try fm.moveItem(at: prepared, to: projectAssets)
            }.value
            installedAssets = projectAssets
            try Task.checkCancellation()
            let roomsToAdd = importedRooms
            let annotationsToAdd = importedAnnotations
            try await storage.change { data in
                guard !data.projects.contains(where: { $0.id == project.id }),
                    Set(data.rooms.map(\.id)).isDisjoint(with: roomsToAdd.map(\.id)),
                    Set(data.annotations.map(\.id)).isDisjoint(with: annotationsToAdd.map(\.id))
                else { throw ProjectTransferArchive.Failure.destinationExists }
                data.projects.append(project)
                data.rooms.append(contentsOf: roomsToAdd)
                data.annotations.append(contentsOf: annotationsToAdd)
            }
            await Task.detached { try? FileManager.default.removeItem(at: stage) }.value
            return project
        } catch {
            let rollback = installedAssets
            await Task.detached {
                if let rollback { try? FileManager.default.removeItem(at: rollback) }
                try? FileManager.default.removeItem(at: stage)
            }.value
            throw error
        }
    }
}
