import SwiftUI

/// Who has access to a project, house or room, granted exactly here. Adding and revoking need level 3 and the
/// network; the server decides (DATABASE_API.md). Access on a project or house covers everything inside it.
struct AccessView: View {
    @EnvironmentObject var store: Store
    let scope: AccessScope
    @State private var grants: [AccessGrant] = []
    @State private var loaded = false
    @State private var adding = false
    @State private var revoking: AccessGrant?

    var body: some View {
        List {
            Section {
                ForEach(grants) { grant in
                    LabeledContent(grant.user?.display_name ?? store.name(of: grant.user_id), value: grant.role.label)
                        .swipeActions {
                            Button("Remove", systemImage: "person.badge.minus", role: .destructive) { revoking = grant }
                        }
                        .contextMenu {
                            Button("Remove Access", systemImage: "person.badge.minus", role: .destructive) {
                                revoking = grant
                            }
                        }
                }
            } header: {
                if !grants.isEmpty { Text("People") }
            } footer: {
                Text(footer)
            }
        }
        .overlay {
            if !store.isOnline {
                ContentUnavailableView(
                    "You’re Offline", systemImage: "wifi.slash",
                    description: Text("Sharing needs a connection. Your other changes are saved on this iPhone."))
            } else if loaded && grants.isEmpty {
                ContentUnavailableView {
                    Label("Not Shared", systemImage: "person.2")
                } description: {
                    Text("Add people by the email they signed up with.")
                } actions: {
                    Button("Add Person") { adding = true }.buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Person", systemImage: "person.badge.plus") { adding = true }
                    .disabled(!store.isOnline).accessibilityIdentifier("access.add")
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $adding, onDismiss: { Task { await load() } }) {
            AddPersonView(scope: scope)
        }
        .confirmationDialog(
            "Remove \(revoking?.user?.display_name ?? "this person")?",
            isPresented: Binding(get: { revoking != nil }, set: { if !$0 { revoking = nil } }),
            titleVisibility: .visible, presenting: revoking
        ) { grant in
            Button("Remove Access", role: .destructive) {
                store.run {
                    try await store.revoke(grant)
                    await load()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("They lose access to “\(scope.name)” unless it is shared with them another way.")
        }
    }

    private var footer: String {
        switch scope {
        case .project: return "Access to the project includes all its houses and rooms, also ones added later."
        case .house: return "Access to the house includes all its rooms, also ones added later."
        case .room: return "Access to this room only."
        }
    }
    private func load() async {
        guard store.isOnline else { return }
        do {
            grants = try await store.grants(on: scope)
            loaded = true
        } catch { store.error = error.localizedDescription }
    }
}

/// Adds a person by email with a role. Granting again changes the role.
struct AddPersonView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let scope: AccessScope
    @State private var email = ""
    @State private var role = AccessRole.external

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("access.email")
                } footer: {
                    Text("They need a sitescope account with this email.")
                }
                Section {
                    Picker("Role", selection: $role) {
                        ForEach(AccessRole.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Role")
                } footer: {
                    Text(role.summary)
                }
            }
            .navigationTitle("Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.run {
                            try await store.grant(role, on: scope, toEmail: email)
                            dismiss()
                        }
                    }
                    .disabled(!email.contains("@") || store.busy)
                    .accessibilityIdentifier("access.grant")
                }
            }
        }
    }
}

/// Who is responsible, and handing it over where allowed: a project by an admin, a house by the project's
/// responsible person, a room by the house's. Needs the network.
struct ResponsibleRow: View {
    @EnvironmentObject var store: Store
    let scope: AccessScope
    let current: UUID?
    let canChange: Bool

    var body: some View {
        if canChange && store.isOnline {
            Picker(
                "Responsible",
                selection: Binding(
                    get: { current ?? UUID() },
                    set: { person in
                        guard person != current else { return }
                        store.run { try await store.setResponsible(person, of: scope) }
                    })
            ) {
                ForEach(store.profiles.filter { $0.is_active || $0.user_id == current }) { profile in
                    Text(profile.display_name).tag(profile.user_id)
                }
            }
            .disabled(store.busy)
            .accessibilityIdentifier("responsible.picker")
        } else {
            LabeledContent("Responsible", value: store.name(of: current))
        }
    }
}

/// The footer that tells people why controls are there or missing.
enum AccessLevelText {
    static func footer(_ level: AccessLevel, scope: String) -> String {
        switch level {
        case .none: return "You see this \(scope) because something inside it is shared with you."
        case .external: return "You can view this \(scope)."
        case .member: return "As a member you can add and edit rooms, scans and drawings here."
        case .responsible: return "You are responsible for this \(scope)."
        case .admin: return "You are an administrator."
        }
    }
}
