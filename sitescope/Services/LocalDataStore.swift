import Foundation

/// Everything saved on the device in on-device mode. The file starts empty.
struct LocalData: Codable, Sendable {
    var projects: [Project] = []
    var rooms: [Room] = []
    var annotations: [Annotation] = []
    // Fixed literal UUID: the force unwrap cannot fail.
    static let userID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}

/// Reads and writes `local.json` and the `assets/` folder beside it. In on-device mode this is the source of truth;
/// `onChange` lets the view model mirror every saved state.
@MainActor final class LocalDataStore {
    let fileURL: URL
    private(set) var data: LocalData
    /// Called after each successful write, on the main actor.
    var onChange: (@MainActor (LocalData) -> Void)?
    private var pendingChange: Task<Void, Error>?

    /// Opens the file, or creates an empty one. Throws without touching the file when it exists but cannot be decoded.
    init(fileURL: URL) throws {
        self.fileURL = fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            data = try JSONDecoder().decode(LocalData.self, from: Data(contentsOf: fileURL))
        } else {
            data = LocalData()
            try Self.persist(data, at: fileURL)
        }
    }

    var assetRoot: URL { fileURL.deletingLastPathComponent().appendingPathComponent("assets", isDirectory: true) }

    /// Applies a change only after it is safely on disk. Encoding and the atomic write run off the main actor.
    /// Changes are chained, so each starts from the previous result and concurrent edits cannot overwrite each other.
    func change(_ operation: @escaping @MainActor (inout LocalData) throws -> Void) async throws {
        let previous = pendingChange
        let url = fileURL
        let change = Task { @MainActor in
            _ = await previous?.result
            var next = self.data
            try operation(&next)
            let snapshot = next
            try await Task.detached(priority: .userInitiated) { try Self.persist(snapshot, at: url) }.value
            self.data = snapshot
            self.onChange?(snapshot)
        }
        pendingChange = change
        try await change.value
    }

    /// Resolves a relative asset path inside `assets/`; absolute paths and `..` are rejected.
    func assetURL(_ path: String) throws -> URL {
        guard !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else {
            throw AppError.message("Invalid asset path.")
        }
        return assetRoot.appendingPathComponent(path)
    }
    func readAsset(path: String) throws -> Data { try Data(contentsOf: assetURL(path)) }
    func writeAsset(path: String, data: Data) throws {
        let url = try assetURL(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    /// Moves an unreadable file aside (never deletes it) and returns the backup location.
    static func moveAside(_ url: URL) throws -> URL {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backup = url.deletingLastPathComponent().appendingPathComponent("local-unreadable-\(stamp).json")
        try FileManager.default.moveItem(at: url, to: backup)
        return backup
    }

    /// Nonisolated so encoding and the write run off the main actor.
    /// The atomic write means a crash never leaves a half-written file.
    private nonisolated static func persist(_ data: LocalData, at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(data).write(to: url, options: .atomic)
    }
}
