import SwiftUI
import UIKit

@main struct SitescopeApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var scenePhase
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
            // The app is only usable while signed in; signed in, it works offline.
            Group {
                if store.signedIn {
                    ProjectListView()
                } else {
                    SignInView()
                }
            }
            .environmentObject(store)
            .appAppearance(appearance)
            .alert(
                "Couldn’t Complete the Action",
                isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
            ) {
                Button("OK") { store.error = nil }
            } message: {
                Text(store.error ?? "")
            }
            // Coming back to the app uploads what waited and fetches what others changed (T-008).
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { store.syncSoon() }
            }
        }
    }
}
