import SwiftUI

/// App settings: appearance, account or local-mode status, scanning tips and app version.
struct SettingsView: View {
    @EnvironmentObject var store: Store
    @AppStorage(AppearancePreference.storageKey) private var appearance = AppearancePreference.system
    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { Text($0.label).tag($0) }
                }.accessibilityIdentifier("settings.appearance")
            } footer: {
                Text("System follows the Light or Dark setting of your iPhone.")
            }
            if store.isLocalMode {
                Section {
                    Text("No account connected")
                } header: {
                    Text("On this device")
                } footer: {
                    Text(
                        "Your projects, room maps and instructions are saved on this device. Sharing becomes available when cloud accounts are connected."
                    )
                }
            } else {
                Section("Account") {
                    Text(store.backend?.user?.email ?? "Signed in")
                }
                Section {
                    Button("Sign Out", role: .destructive) {
                        store.run {
                            await store.backend?.signOut()
                            store.projects = []
                            store.rooms = []
                            store.annotations = []
                            store.signedIn = false
                        }
                    }
                }
            }
            Section {
                NavigationLink {
                    TrackingTipsView()
                } label: {
                    Label("Camera-only scanning tips", systemImage: "camera.viewfinder")
                }
            }
            Section {
                LabeledContent("Version", value: Self.version)
            } header: {
                Text("About sitescope")
            } footer: {
                Text(
                    "Spatial work instructions for iOS 17 and later. Room recognition uses camera features from the saved scan. Lighting and texture affect accuracy. Check drawings against the physical room before work. Exported project files include room maps and images."
                )
            }
        }.navigationTitle("Settings")
    }
    private static var version: String {
        let info = Bundle.main.infoDictionary
        return
            "\(info?["CFBundleShortVersionString"] as? String ?? "–") (\(info?["CFBundleVersion"] as? String ?? "–"))"
    }
}
