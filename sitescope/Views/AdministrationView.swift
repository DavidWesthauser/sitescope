import SwiftUI

/// Administration for admins (docs/DATABASE_API.md): activate or deactivate people, assign their organization, and
/// create or edit organizations. Who is an admin is set in the Supabase dashboard; the app cannot change it.
struct AdministrationView: View {
    @EnvironmentObject var store: Store
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
                            Text(subtitle(of: profile)).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("People")
            } footer: {
                Text("Inactive people keep their data but lose all access. Nobody is deleted.")
            }
            Section {
                if store.organizations.isEmpty {
                    Text("No organizations yet.").foregroundStyle(.secondary)
                }
                ForEach(store.organizations) { organization in
                    NavigationLink {
                        OrganizationEditor(organization: organization, isNew: false)
                    } label: {
                        LabeledContent(organization.name, value: organization.status == .active ? "Active" : "Inactive")
                    }
                }
                Button("Add Organization", systemImage: "plus") { creating = true }
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
        .sheet(isPresented: $creating) {
            NavigationStack { OrganizationEditor(organization: Organization(name: ""), isNew: true) }
                .presentationDetents([.medium, .large])
        }
    }

    private func subtitle(of profile: Profile) -> String {
        let organization = store.organizations.first { $0.id == profile.organization_id }?.name ?? "No organization"
        return profile.is_active ? organization : "Inactive · \(organization)"
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
                            : "An inactive person can still sign in but sees nothing.")
                }
            }
        }
        .navigationTitle(profile?.display_name ?? "Person")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Creates (in a sheet, with Cancel and Add) or edits (pushed, with Save) an organization: name, status and the
/// person responsible for it. Errors show in the form, because an alert from the app's root cannot appear over a sheet.
private struct OrganizationEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var organization: Organization
    let isNew: Bool
    @State private var saving = false
    @State private var problem: String?

    var body: some View {
        Form {
            Section {
                TextField("Organization Name", text: $organization.name).accessibilityIdentifier("organization.name")
                Picker("Status", selection: $organization.status) {
                    Text("Active").tag(Organization.Status.active)
                    Text("Inactive").tag(Organization.Status.inactive)
                }
                Picker("Responsible", selection: $organization.responsible_id) {
                    Text("Nobody").tag(UUID?.none)
                    ForEach(store.profiles) { Text($0.display_name).tag(Optional($0.user_id)) }
                }
            } footer: {
                if let problem { Text(problem).foregroundStyle(Color("Warning")) }
            }
        }
        .navigationTitle(isNew ? "New Organization" : "Organization")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            ToolbarItem(placement: .confirmationAction) {
                if saving {
                    ProgressView()
                } else {
                    Button(isNew ? "Add" : "Save") { save() }
                        .disabled(organization.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        saving = true
        problem = nil
        Task {
            defer { saving = false }
            do {
                try await store.saveOrganization(organization, isNew: isNew)
                dismiss()
            } catch { problem = error.localizedDescription }
        }
    }
}
