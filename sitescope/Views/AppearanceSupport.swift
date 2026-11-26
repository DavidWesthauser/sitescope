import SwiftUI
import UIKit

extension AppearancePreference {
    /// `nil` lets the scene follow the iPhone's setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension View {
    /// Applies the stored appearance to the whole window. `preferredColorScheme` covers SwiftUI content;
    /// the window override also covers UIKit presentations (share sheet, alerts, confirmation dialogs) and makes
    /// switching back to System reliable, which `preferredColorScheme(nil)` alone does not do after an explicit choice.
    func appAppearance(_ appearance: AppearancePreference) -> some View {
        preferredColorScheme(appearance.colorScheme)
            .background(WindowAppearance(style: appearance.interfaceStyle).frame(width: 0, height: 0))
    }
}

extension View {
    /// Label color for `.borderedProminent` buttons on the accent fill. The dark accent (#4FD1DC) is light, so
    /// white text would be about 1.8:1; black reaches 11.5:1. Light mode keeps white (5.7:1 on #00727F).
    func prominentLabelContrast() -> some View { modifier(ProminentLabelContrast()) }
}

private struct ProminentLabelContrast: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    func body(content: Content) -> some View {
        // A disabled button keeps the system's dimmed label.
        if isEnabled {
            content.foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
        } else {
            content
        }
    }
}

/// Sets `overrideUserInterfaceStyle` on the hosting window, so everything presented from it follows the setting.
private struct WindowAppearance: UIViewRepresentable {
    let style: UIUserInterfaceStyle

    func makeUIView(context: Context) -> Probe { Probe() }
    func updateUIView(_ view: Probe, context: Context) {
        view.style = style
        view.apply()
    }

    final class Probe: UIView {
        var style: UIUserInterfaceStyle = .unspecified
        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }
        func apply() {
            // Every window of the scene, so sheets and alerts that UIKit hosts in their own window follow too.
            guard let scene = window?.windowScene else { return }
            for window in scene.windows where window.overrideUserInterfaceStyle != style {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
