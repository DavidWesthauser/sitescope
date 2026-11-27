import SwiftUI

/// Who has access to a project, house or room, and granting or revoking it (level ≥ 3 on the scope).
/// Grants on a project or house also cover what is below it; this screen lists the ones made exactly here.
struct AccessView: View {
    @EnvironmentObject var store: Store
    let scope: AccessScope
    @State private var grants: [AccessGrant] = []
    @State private var email = ""
    @State private var role = AccessRole.external
    @State private var revoking: AccessGrant?

    var body: some View {
        List {
            Section {
                if grants.isEmpty {
                    Text("Nobody has been given access here yet.").foregroundStyle(.secondary)
                }
                ForEach(grants) { grant in
                    LabeledContent(grant.user?.display_name ?? store.name(of: grant.user_id), value: grant.role.label)
                        .swipeActions {
                            Button("Revoke", role: .destructive) { revoking = grant }
                        }
                        .contextMenu {
                            Button("Revoke Access", systemImage: "person.badge.minus", role: .destructive) {
                                revoking = grant
                            }
                        }
                }
            } header: {
                Text("People with access")
            } footer: {
                Text(footer)
            }
            Section {
                TextField("Email of a registered person", text: $email).keyboardType(.emailAddress)
                    .textContentType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("access.email")
                Picker("Role", selection: $role) {
                    ForEach(AccessRole.allCases) { Text($0.label).tag($0) }
                }
                Button("Grant Access", systemImage: "person.badge.plus") {
                    store.run {
                        try await store.grant(role, on: scope, toEmail: email)
                        email = ""
                        try await load()
                    }
                }.disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || store.busy)
                    .accessibilityIdentifier("access.grant")
            } header: {
                Text("Add a person")
            } footer: {
                Text("\(role.label): \(role.summary) Granting again changes the role.")
            }
        }
        .navigationTitle("Access")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await reload() }
        .confirmationDialog(
            "Revoke access for \(revoking?.user?.display_name ?? "this person")?",
            isPresented: Binding(get: { revoking != nil }, set: { if !$0 { revoking = nil } }),
            titleVisibility: .visible, presenting: revoking
        ) { grant in
            Button("Revoke Access", role: .destructive) {
                store.run {
                    try await store.revoke(grant)
                    try await load()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("They lose access to \(scope.name) unless they have it through another grant.")
        }
    }

    private var footer: String {
        switch scope {
        case .project: return "Access to the project includes all its houses and rooms, also ones added later."
        case .house: return "Access to the house includes all its rooms, also ones added later."
        case .room: return "Access to this room only."
        }
    }
    private func load() async throws {
        grants = try await store.grants(on: scope)
    }
    private func reload() async {
        do { try await load() } catch { store.error = error.localizedDescription }
    }
}

/// Who is responsible for a project, house or room, and handing it over when allowed: a project only by an admin,
/// a house by the responsible of its project, a room by the responsible of its house.
struct ResponsibleSection: View {
    @EnvironmentObject var store: Store
    let scope: AccessScope
    let current: UUID?
    let canChange: Bool
    let changed: () async throws -> Void

    var body: some View {
        Section {
            if canChange {
                Picker(
                    "Responsible",
                    selection: Binding(
                        get: { current ?? UUID() },
                        set: { person in
                            guard person != current else { return }
                            store.run {
                                try await store.setResponsible(person, of: scope)
                                try await changed()
                            }
                        })
                ) {
                    ForEach(store.profiles.filter { $0.is_active || $0.user_id == current }) { profile in
                        Text(profile.display_name).tag(profile.user_id)
                    }
                }.disabled(store.busy).accessibilityIdentifier("responsible.picker")
            } else {
                LabeledContent("Responsible", value: store.name(of: current))
            }
        } footer: {
            Text(footer)
        }
    }
    private var footer: String {
        switch scope {
        case .project: return "Only an administrator can hand over a project."
        case .house: return "The person responsible for the project can hand over a house."
        case .room: return "The person responsible for the house can hand over a room."
        }
    }
}

/// The caller's own level, shown at the end of a screen so people know why controls are missing.
struct AccessLevelFooter: View {
    let level: AccessLevel
    var body: some View {
        Section {
        } footer: {
            Text("Your access here: \(level.label)")
        }
    }
}
