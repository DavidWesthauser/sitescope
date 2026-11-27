import SwiftUI
import UIKit

@main struct SitescopeApp: App {
    @StateObject private var store = Store()
    @AppStorage(AppearancePreference.storageKey) private var appearance = AppearancePreference.system
    init() {
        // HIG (Text fields): show a Clear button at the trailing end of single-line text fields.
        UITextField.appearance().clearButtonMode = .whileEditing
        #if DEBUG
            /// UI tests pass this flag so transitions do not delay element queries; Release builds are unaffected.
            if ProcessInfo.processInfo.arguments.contains("-disableAnimations") {
                UIView.setAnimationsEnabled(false)
            }
        #endif
    }
    var body: some Scene {
        WindowGroup {
            // The app is only usable while signed in.
            Group {
                if store.signedIn {
                    ProjectDashboard()
                } else {
                    AuthenticationView()
                }
            }
            .environmentObject(store)
            .appAppearance(appearance)
            .alert(
                "sitescope",
                isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
            ) {
                Button("OK") { store.error = nil }
            } message: {
                Text(store.error ?? "")
            }
            .overlay {
                if store.busy {
                    ZStack {
                        // Dimming scrim; black at low opacity is the system convention in both appearances.
                        Color.black.opacity(0.12).ignoresSafeArea()
                        ProgressView("Working…").padding(24).background(
                            .regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }
}
