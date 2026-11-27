import SwiftUI

/// App settings: your name and account, administration for admins, appearance, scanning tips and app version.
struct SettingsView: View {
    @EnvironmentObject var store: Store
    @AppStorage(AppearancePreference.storageKey) private var appearance = AppearancePreference.system
    @State private var nameDraft = ""
    var body: some View {
        Form {
            if let me = store.myProfile {
                NameSection(
                    placeholder: "Your name", stored: me.display_name, identifier: "settings.displayName",
                    draft: $nameDraft, save: { name in store.run { try await store.setDisplayName(name) } }
                )
                .onAppear { nameDraft = me.display_name }
            }
            Section {
                LabeledContent("Email", value: store.accountEmail ?? "–")
                if store.isAdmin {
                    NavigationLink {
                        AdministrationView()
                    } label: {
                        Label("Administration", systemImage: "person.badge.key")
                    }.accessibilityIdentifier("settings.admin")
                }
            } header: {
                Text("Account")
            } footer: {
                Text(store.isAdmin ? "You are an administrator." : "Others see your name on projects you are part of.")
            }
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { Text($0.label).tag($0) }
                }.accessibilityIdentifier("settings.appearance")
            } footer: {
                Text("System follows the Light or Dark setting of your iPhone.")
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
                    "Spatial work instructions for iOS 17 and later. Room recognition uses camera features from the saved scan. Lighting and texture affect accuracy. Check drawings against the physical room before work."
                )
            }
            // HIG: the destructive action sits alone in the last section.
            Section {
                Button("Sign Out", role: .destructive) {
                    store.run { await store.signOut() }
                }.accessibilityIdentifier("settings.signOut")
            } footer: {
                Text("You need to sign in again to use sitescope.")
            }
        }.navigationTitle("Settings")
    }
    private static var version: String {
        let info = Bundle.main.infoDictionary
        return
            "\(info?["CFBundleShortVersionString"] as? String ?? "–") (\(info?["CFBundleVersion"] as? String ?? "–"))"
    }
}
