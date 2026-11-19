import Foundation

/// Retry state belongs to one AR coordinate origin; asynchronous results must carry its generation.
public struct MapSaveTransaction: Sendable {
    /// Changes on every reset; a save that finishes after the session moved on is rejected.
    public private(set) var generation = UUID()
    /// The captured map snapshot, staged until the room is uploaded.
    public private(set) var data: Data?
    /// The scan guide image captured with the snapshot; the staged room must carry the same one.
    public private(set) var guide: String?
    /// The room ready to publish, set only after `stage` has checked the snapshot and its upload path.
    public private(set) var publication: Room?

    public init() {}

    /// Starts a new generation and discards the snapshot, so late results from the old session are ignored.
    public mutating func reset() {
        generation = UUID()
        data = nil
        guide = nil
        publication = nil
    }

    /// Rejects results produced for an earlier AR session, whose coordinates no longer match.
    public func validate(_ generation: UUID) throws {
        guard generation == self.generation else { throw Failure.sessionChanged }
    }

    /// A successful persistence response must not be described as an unsaved room.
    public func validateCompletion(_ generation: UUID) throws {
        guard generation == self.generation else { throw Failure.savedSessionChanged }
    }

    /// Stores the snapshot only if it still belongs to the current generation.
    public mutating func capture(_ data: Data, generation: UUID, guide: String? = nil) throws {
        try validate(generation)
        self.data = data
        self.guide = guide
    }

    /// Publishes only a complete room: a snapshot, an uploaded map path and a matching guide image.
    public mutating func stage(_ room: Room, generation: UUID) throws {
        try validate(generation)
        guard data != nil, room.map_path != nil, room.scan_guide_jpeg == guide else { throw Failure.incompleteSnapshot }
        try room.validate()
        publication = room
    }

    public enum Failure: Error, LocalizedError, Sendable {
        case sessionChanged, incompleteSnapshot, savedSessionChanged

        public var errorDescription: String? {
            switch self {
            case .sessionChanged:
                return "The scan session changed while saving. Finish the current scan and retry."
            case .incompleteSnapshot:
                return "The room map snapshot or uploaded map path is missing. Retry saving the scan."
            case .savedSessionChanged:
                return
                    "The room was saved, but the AR session changed. Close AR and reopen this room to recover its saved alignment."
            }
        }
    }
}
