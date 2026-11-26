import SwiftUI
import UIKit

@main struct SitescopeApp: App {
    @StateObject private var store = Store()
    @State private var importedProjectName: String?
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
            Group {
                if store.signedIn {
                    ProjectDashboard()
                } else if store.unreadableLocalData != nil {
                    LocalDataRecoveryView()
                } else {
                    AuthenticationView()
                }
            }
            .environmentObject(store)
            .appAppearance(appearance)
            .onOpenURL { url in
                guard !store.busy else {
                    store.error = "Finish the current operation, then open the project file again."
                    return
                }
                store.run { importedProjectName = try await store.importProjectFile(from: url).name }
            }
            .alert(
                store.error == nil && importedProjectName != nil ? "Project imported" : "sitescope",
                isPresented: Binding(
                    get: { store.error != nil || importedProjectName != nil },
                    set: {
                        if !$0 {
                            store.error = nil
                            importedProjectName = nil
                        }
                    })
            ) {
                Button("OK") {
                    store.error = nil
                    importedProjectName = nil
                }
            } message: {
                Text(
                    store.error
                        ?? "“\(importedProjectName ?? "Project")” is now an editable copy in Projects. Later changes are not synchronized."
                )
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
