import Foundation
import CryptoKit

public struct ProjectTransferManifest: Codable, Sendable {
    public var version: Int = 1
    public var project: Project
    public var rooms: [Room]
    public var annotations: [Annotation]
    public var assets: [ProjectTransferAsset]
    public init(version: Int = 1, project: Project, rooms: [Room], annotations: [Annotation], assets: [ProjectTransferAsset]) {
        self.version = version; self.project = project; self.rooms = rooms
        self.annotations = annotations; self.assets = assets
    }
}

public struct ProjectTransferAsset: Codable, Sendable {
    public var path: String
    public var byteCount: UInt64
    public var sha256: String
    public init(path: String, byteCount: UInt64, sha256: String) {
        self.path = path; self.byteCount = byteCount; self.sha256 = sha256
    }
}

/// A bounded manifest followed by streamed, checksum-protected asset bytes.
public enum ProjectTransferArchive {
    public enum Failure: Error, LocalizedError {
        case invalidArchive, unsupportedVersion, invalidProject, invalidPath, missingAsset, unsafeFile, limitExceeded, checksumMismatch, destinationExists
        public var errorDescription: String? {
            switch self {
            case .invalidArchive: return "The project file is damaged or incomplete."
            case .unsupportedVersion: return "This project file uses an unsupported version."
            case .invalidProject: return "The project contains inconsistent room or task data."
            case .invalidPath: return "The project contains an unsafe asset path."
            case .missingAsset: return "A referenced project asset is missing."
            case .unsafeFile: return "Project assets must be regular files, without symbolic links."
            case .limitExceeded: return "The project exceeds the transfer size limits."
            case .checksumMismatch: return "A project asset failed its integrity check."
            case .destinationExists: return "The destination already exists."
            }
        }
    }
    private static let magic = Data("sitescope01".utf8)
    private static let chunkSize = 1_048_576
    private static let manifestLimit: UInt64 = 16 * 1_048_576
    private static let assetLimit: UInt64 = 256 * 1_048_576
    private static let totalLimit: UInt64 = 1024 * 1_048_576
    private static var fm: FileManager { .default }

    public static func write(project: Project, rooms: [Room], annotations: [Annotation], assetRoot: URL, to destination: URL) throws {
        var manifest = ProjectTransferManifest(project: project, rooms: rooms, annotations: annotations, assets: [])
        let paths = try references(manifest).sorted()
        let rootAttributes = try fm.attributesOfItem(atPath: assetRoot.path)
        guard rootAttributes[.type] as? FileAttributeType == .typeDirectory else { throw Failure.unsafeFile }
        let root = assetRoot.resolvingSymlinksInPath()
        var total: UInt64 = 0
        for path in paths {
            let url = try assetURL(path, root: root)
            let size = try fileSize(url)
            guard size <= assetLimit, size <= totalLimit - total else { throw Failure.limitExceeded }
            total += size
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let hash = try stream(handle, byteCount: size)
            guard try handle.read(upToCount: 1)?.isEmpty ?? true else { throw Failure.invalidArchive }
            manifest.assets.append(ProjectTransferAsset(path: path, byteCount: size, sha256: hash))
        }
        try validate(manifest)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(manifest)
        guard UInt64(data.count) <= manifestLimit else { throw Failure.limitExceeded }
        try requireAbsent(destination)
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(".sitescope-export-\(UUID().uuidString)")
        guard fm.createFile(atPath: temporary.path, contents: nil) else { throw Failure.unsafeFile }
        defer { try? fm.removeItem(at: temporary) }
        let output = try FileHandle(forWritingTo: temporary)
        do {
            try output.write(contentsOf: magic)
            var length = UInt64(data.count).littleEndian
            try withUnsafeBytes(of: &length) { try output.write(contentsOf: Data($0)) }
            try output.write(contentsOf: data)
            for asset in manifest.assets {
                let url = try assetURL(asset.path, root: root)
                guard try fileSize(url) == asset.byteCount else { throw Failure.invalidArchive }
                let input = try FileHandle(forReadingFrom: url)
                defer { try? input.close() }
                let hash = try stream(input, byteCount: asset.byteCount, output: output)
                guard hash == asset.sha256, try input.read(upToCount: 1)?.isEmpty ?? true else { throw Failure.checksumMismatch }
            }
            try output.synchronize()
            try output.close()
            try requireAbsent(destination)
            try fm.moveItem(at: temporary, to: destination)
        } catch {
            try? output.close()
            throw error
        }
    }

    public static func read(from source: URL, extractTo destination: URL) throws -> ProjectTransferManifest {
        try requireAbsent(destination)
        _ = try fileSize(source)
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        guard try exact(input, count: 8) == magic else { throw Failure.invalidArchive }
        let lengthData = try exact(input, count: 8)
        let length = lengthData.enumerated().reduce(UInt64(0)) { $0 | (UInt64($1.element) << ($1.offset * 8)) }
        guard length > 0, length <= manifestLimit else { throw Failure.limitExceeded }
        let manifest = try JSONDecoder().decode(ProjectTransferManifest.self, from: exact(input, count: Int(length)))
        try validate(manifest)
        let staging = destination.deletingLastPathComponent().appendingPathComponent(".sitescope-import-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: staging) }
        for asset in manifest.assets {
            let url = staging.appendingPathComponent(asset.path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Also catches path aliases on case-insensitive filesystems.
            try requireAbsent(url)
            guard fm.createFile(atPath: url.path, contents: nil) else { throw Failure.unsafeFile }
            let output = try FileHandle(forWritingTo: url)
            do {
                let hash = try stream(input, byteCount: asset.byteCount, output: output)
                try output.close()
                guard hash == asset.sha256 else { throw Failure.checksumMismatch }
            } catch { try? output.close(); throw error }
        }
        guard try input.read(upToCount: 1)?.isEmpty ?? true else { throw Failure.invalidArchive }
        try requireAbsent(destination)
        try fm.moveItem(at: staging, to: destination)
        return manifest
    }

    private static func references(_ manifest: ProjectTransferManifest) throws -> Set<String> {
        guard manifest.version == 1 else { throw Failure.unsupportedVersion }
        guard manifest.rooms.count <= 256, manifest.annotations.count <= 2000 else { throw Failure.limitExceeded }
        var rooms: [UUID: Room] = [:]
        var paths = Set<String>()
        var points = 0
        for room in manifest.rooms {
            guard room.project_id == manifest.project.id, rooms[room.id] == nil else { throw Failure.invalidProject }
            try room.validate()
            rooms[room.id] = room
            points += room.reference_points.count + (room.surfaces ?? []).reduce(0) { $0 + $1.vertices.count }
            if let path = room.map_path { try validatePath(path, project: manifest.project.id, room: room.id); paths.insert(path) }
        }
        var ids = Set<UUID>()
        for annotation in manifest.annotations {
            guard ids.insert(annotation.id).inserted, let room = rooms[annotation.room_id] else { throw Failure.invalidProject }
            try annotation.validate(room: room)
            points += annotation.points.count + (annotation.strokes ?? []).reduce(0) { $0 + $1.count }
            if let image = annotation.image {
                try image.validate()
                try validatePath(image.path, project: manifest.project.id, room: room.id)
                paths.insert(image.path)
            }
        }
        guard points <= 100_000 else { throw Failure.limitExceeded }
        return paths
    }

    private static func validate(_ manifest: ProjectTransferManifest) throws {
        let expected = try references(manifest)
        guard manifest.assets.count == expected.count,
              manifest.assets.map(\.path) == expected.sorted() else { throw Failure.invalidProject }
        var total: UInt64 = 0
        for asset in manifest.assets {
            guard asset.byteCount <= assetLimit, asset.byteCount <= totalLimit - total else { throw Failure.limitExceeded }
            guard asset.sha256.utf8.count == 64, asset.sha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { throw Failure.invalidArchive }
            total += asset.byteCount
        }
    }

    private static func validatePath(_ path: String, project: UUID, room: UUID) throws {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count >= 3,
              parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
              UUID(uuidString: String(parts[0])) == project, UUID(uuidString: String(parts[1])) == room,
              path.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || [45, 46, 47, 95].contains($0) }) else { throw Failure.invalidPath }
    }

    private static func assetURL(_ path: String, root: URL) throws -> URL {
        var url = root
        for component in path.split(separator: "/") {
            url.appendPathComponent(String(component))
            let attributes = try fm.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType != .typeSymbolicLink else { throw Failure.unsafeFile }
        }
        return url
    }

    private static func fileSize(_ url: URL) throws -> UInt64 {
        let attributes = try fm.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber else { throw Failure.unsafeFile }
        return size.uint64Value
    }

    private static func requireAbsent(_ url: URL) throws {
        if (try? fm.attributesOfItem(atPath: url.path)) != nil { throw Failure.destinationExists }
    }

    private static func exact(_ input: FileHandle, count: Int) throws -> Data {
        var data = Data()
        while data.count < count {
            guard let chunk = try input.read(upToCount: min(chunkSize, count - data.count)), !chunk.isEmpty else { throw Failure.invalidArchive }
            data.append(chunk)
        }
        return data
    }

    private static func stream(_ input: FileHandle, byteCount: UInt64, output: FileHandle? = nil) throws -> String {
        var hash = SHA256()
        var remaining = byteCount
        while remaining > 0 {
            let chunk = try exact(input, count: Int(min(UInt64(chunkSize), remaining)))
            hash.update(data: chunk)
            try output?.write(contentsOf: chunk)
            remaining -= UInt64(chunk.count)
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
