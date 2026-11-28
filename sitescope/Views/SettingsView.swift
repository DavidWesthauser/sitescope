import SwiftUI

/// Settings: your name and account, sync, appearance, help and the app version; signing out last.
struct SettingsView: View {
    @EnvironmentObject var store: Store
    @AppStorage(AppearancePreference.storageKey) private var appearance = AppearancePreference.system
    @State private var name = ""
    @State private var signingOut = false
    @FocusState private var editingName: Bool

    var body: some View {
        Form {
            Section {
                TextField("Your Name", text: $name)
                    .textContentType(.name).submitLabel(.done)
                    .focused($editingName)
                    .onSubmit(saveName)
                    .disabled(!store.isOnline || store.myProfile == nil)
                    .accessibilityIdentifier("settings.displayName")
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
                Text(
                    store.isOnline
                        ? "Others see your name on projects you share. You sign in with your email."
                        : "Your name can be changed when you’re online.")
            }
            Section {
                LabeledContent("Status") { SyncStatusView() }
                LabeledContent("Waiting Changes", value: "\(store.waitingChanges)")
                Button("Sync Now", systemImage: "arrow.triangle.2.circlepath") { Task { await store.refresh() } }
                    .disabled(!store.isOnline || store.isSyncing)
                if store.failedChanges > 0 {
                    Button("Retry Failed Changes", systemImage: "arrow.clockwise") { Task { await store.retry() } }
                }
            } header: {
                Text("Sync")
            } footer: {
                Text(
                    store.syncProblem
                        ?? "Changes are saved on this iPhone first and upload when you’re online. Swipe a failed item to the right to retry it."
                )
            }
            SyncNoticesSection()
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { Text($0.label).tag($0) }
                }.accessibilityIdentifier("settings.appearance")
                NavigationLink {
                    TrackingTipsView()
                } label: {
                    Label("Scanning Tips", systemImage: "camera.viewfinder")
                }
            }
            Section {
                LabeledContent("Version", value: Self.version)
            } header: {
                Text("About")
            } footer: {
                Text(
                    "Spatial drawings for iOS 17 and later. Room recognition uses camera features from the saved scan; lighting and texture affect accuracy. Check drawings against the room before work."
                )
            }
            Section {
                Button("Sign Out", role: .destructive) { signingOut = true }
                    .accessibilityIdentifier("settings.signOut")
            }
        }
        .navigationTitle("Settings")
        .onAppear { name = store.myProfile?.display_name ?? "" }
        .onChange(of: editingName) { _, editing in
            if !editing { saveName() }
        }
        .confirmationDialog("Sign Out?", isPresented: $signingOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { store.run { await store.signOut() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                store.waitingChanges == 0
                    ? "Your projects stay on this iPhone for the next sign-in."
                    : "\(store.waitingChanges) changes haven’t uploaded yet. They stay on this iPhone and upload after you sign in again."
            )
        }
    }

    private func saveName() {
        let text = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let current = store.myProfile?.display_name, text != current, !text.isEmpty else {
            name = store.myProfile?.display_name ?? name
            return
        }
        store.run { try await store.setDisplayName(text) }
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        return
            "\(info?["CFBundleShortVersionString"] as? String ?? "–") (\(info?["CFBundleVersion"] as? String ?? "–"))"
    }
}
