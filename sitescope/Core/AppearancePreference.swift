/// The in-app appearance choice. The raw values are persisted under the `appearance` key in UserDefaults;
/// keep them stable.
public enum AppearancePreference: String, CaseIterable, Identifiable, Sendable {
    /// Follows the iPhone's Light/Dark setting. This is the default, as the HIG recommends.
    case system
    case light
    case dark

    public static let storageKey = "appearance"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// Reads a stored value; anything unknown or missing falls back to `.system`.
    public init(stored: String?) {
        self = stored.flatMap(Self.init(rawValue:)) ?? .system
    }
}
