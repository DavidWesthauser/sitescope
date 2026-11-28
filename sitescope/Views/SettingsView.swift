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
                LabeledContent("Name") {
                    TextField("Your name", text: $name)
                        .multilineTextAlignment(.trailing)
                        .textContentType(.name).submitLabel(.done)
                        .focused($editingName)
                        .onSubmit(saveName)
                        .disabled(!store.isOnline || store.myProfile == nil)
                        .accessibilityIdentifier("settings.displayName")
                }
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
                LabeledContent("Waiting to Upload", value: "\(store.pendingChanges)")
                Button("Sync Now", systemImage: "arrow.triangle.2.circlepath") { Task { await store.syncNow() } }
                    .disabled(!store.isOnline || store.isSyncing)
            } header: {
                Text("Sync")
            } footer: {
                Text(
                    store.syncProblem ?? "Changes are saved on this iPhone first and upload when you’re online.")
            }
            if !store.failedItems.isEmpty {
                Section {
                    ForEach(store.failedItems, id: \.key) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                            Text(item.reason).font(.footnote).foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("Retry", systemImage: "arrow.clockwise") { Task { await store.retry(item.key) } }
                                .tint(.accentColor)
                        }
                    }
                    Button("Retry All", systemImage: "arrow.clockwise") { Task { await store.retry() } }
                        .disabled(!store.isOnline || store.isSyncing)
                } header: {
                    Text("Couldn’t Upload")
                } footer: {
                    Text("These stay on this iPhone. Swipe one to retry it alone.")
                }
            }
            SyncNoticesSection()
            Section("General") {
                Picker(selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { Text($0.label).tag($0) }
                } label: {
                    Label("Appearance", systemImage: "circle.lefthalf.filled")
                }.accessibilityIdentifier("settings.appearance")
                NavigationLink {
                    TrackingTipsView()
                } label: {
                    Label("Scanning Tips", systemImage: "lightbulb")
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
        .alert("Sign Out?", isPresented: $signingOut) {
            Button("Sign Out", role: .destructive) { store.run { await store.signOut() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                store.waitingChanges == 0
                    ? "Your projects stay on this iPhone for the next sign-in."
                    : store.waitingChanges == 1
                        ? "1 change hasn’t uploaded yet. It stays on this iPhone and uploads after you sign in again."
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
