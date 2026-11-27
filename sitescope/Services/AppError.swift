import Foundation

/// An error whose text is shown to the user as is.
enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case .message(let text): text
        }
    }
}

extension DisplayName {
    /// The trimmed name, or an error the user can read.
    static func validated(_ value: String) throws -> String {
        guard let name = normalized(value) else {
            throw AppError.message("Use a name between 1 and \(maximumLength) characters.")
        }
        return name
    }
}
