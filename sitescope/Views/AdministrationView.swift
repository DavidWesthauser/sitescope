import SwiftUI

/// Administration for admins (docs/DATABASE_API.md): activate or deactivate people, assign their organization, and
/// create or edit organizations. Who is an admin is set in the Supabase dashboard; the app cannot change it.
struct AdministrationView: View {
    @EnvironmentObject var store: Store
    @State private var editing: Organization?
    @State private var creating = false

    var body: some View {
        List {
            Section {
                ForEach(store.profiles) { profile in
                    NavigationLink {
                        PersonView(profileID: profile.user_id)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.display_name)
                            Text(subtitle(of: profile)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("People")
            } footer: {
                Text("Deactivated people keep their data but lose all access. Nobody is deleted.")
            }
            Section {
                if store.organizations.isEmpty {
                    Text("No organizations yet").foregroundStyle(.secondary)
                }
                ForEach(store.organizations) { organization in
                    Button {
                        editing = organization
                    } label: {
                        LabeledContent(organization.name, value: organization.status == .active ? "Active" : "Inactive")
                    }.tint(.primary)
                }
                Button("Add organization", systemImage: "plus") { creating = true }
                    .accessibilityIdentifier("admin.organizations.new")
            } header: {
                Text("Organizations")
            } footer: {
                Text("People of an inactive organization lose all access until it is active again.")
            }
        }
        .navigationTitle("Administration")
        .task { await reload() }
        .refreshable { await reload() }
        .sheet(item: $editing) { organization in
            OrganizationEditor(organization: organization, isNew: false)
        }
        .sheet(isPresented: $creating) {
            OrganizationEditor(organization: Organization(name: ""), isNew: true)
        }
    }

    private func subtitle(of profile: Profile) -> String {
        let organization = store.organizations.first { $0.id == profile.organization_id }?.name ?? "No organization"
        return profile.is_active ? organization : "Deactivated · \(organization)"
    }
    private func reload() async {
        do { try await store.loadPeople() } catch { store.error = error.localizedDescription }
    }
}

/// One person: active state and organization.
private struct PersonView: View {
    @EnvironmentObject var store: Store
    let profileID: UUID
    private var profile: Profile? { store.profiles.first { $0.user_id == profileID } }

    var body: some View {
        Form {
            if let profile {
                Section {
                    Toggle(
                        "Active",
                        isOn: Binding(
                            get: { profile.is_active },
                            set: { active in store.run { try await store.setActive(active, of: profile) } })
                    ).disabled(store.busy || profile.user_id == store.userID)
                        .accessibilityIdentifier("admin.person.active")
                    Picker(
                        "Organization",
                        selection: Binding(
                            get: { profile.organization_id },
                            set: { organization in
                                store.run { try await store.setOrganization(organization, of: profile) }
                            })
                    ) {
                        Text("None").tag(UUID?.none)
                        ForEach(store.organizations) { Text($0.name).tag(Optional($0.id)) }
                    }.disabled(store.busy)
                } footer: {
                    Text(
                        profile.user_id == store.userID
                            ? "You cannot deactivate yourself."
                            : "A deactivated person can still sign in but sees nothing.")
                }
            }
        }
        .navigationTitle(profile?.display_name ?? "Person")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Creates or edits an organization: name, status and the person responsible for it.
private struct OrganizationEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var organization: Organization
    let isNew: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("Organization name", text: $organization.name).accessibilityIdentifier("organization.name")
                Picker("Status", selection: $organization.status) {
                    Text("Active").tag(Organization.Status.active)
                    Text("Inactive").tag(Organization.Status.inactive)
                }
                Picker("Responsible", selection: $organization.responsible_id) {
                    Text("Nobody").tag(UUID?.none)
                    ForEach(store.profiles) { Text($0.display_name).tag(Optional($0.user_id)) }
                }
            }
            .navigationTitle(isNew ? "New Organization" : organization.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.run {
                            try await store.saveOrganization(organization, isNew: isNew)
                            dismiss()
                        }
                    }.disabled(organization.name.trimmingCharacters(in: .whitespaces).isEmpty || store.busy)
                }
            }
        }
    }
}
