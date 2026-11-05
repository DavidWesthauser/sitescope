import Foundation

/// Retry state belongs to one AR coordinate origin; asynchronous results must carry its generation.
public struct MapSaveTransaction: Sendable {
    public private(set) var generation = UUID()
    public private(set) var data: Data?
    public private(set) var guide: String?
    public private(set) var publication: Room?

    public init() {}

    public mutating func reset() {
        generation = UUID()
        data = nil
        guide = nil
        publication = nil
    }

    public func validate(_ generation: UUID) throws {
        guard generation == self.generation else { throw Failure.sessionChanged }
    }

    /// A successful persistence response must not be described as an unsaved room.
    public func validateCompletion(_ generation: UUID) throws {
        guard generation == self.generation else { throw Failure.savedSessionChanged }
    }

    public mutating func capture(_ data: Data, generation: UUID, guide: String? = nil) throws {
        try validate(generation)
        self.data = data
        self.guide = guide
    }

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
                return "The room was saved, but the AR session changed. Close AR and reopen this room to recover its saved alignment."
            }
        }
    }
}
