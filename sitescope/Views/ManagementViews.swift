import SwiftUI

/// Sign-in and registration. The app shows nothing else until someone is signed in.
struct AuthenticationView: View {
    /// Supabase's default minimum; the server checks it again on sign-up.
    static let minimumPasswordLength = 6
    @EnvironmentObject var store: Store
    @State private var email = ""
    @State private var password = ""
    @State private var register = false
    @State private var notice = ""
    var body: some View {
        NavigationStack {
            Form {
                Section { Label("Instructions anchored to your workplace", systemImage: "arkit").font(.headline) }
                Section {
                    TextField("Email", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier(
                            "auth.email")
                    SecureField("Password (at least 6 characters)", text: $password).textContentType(
                        register ? .newPassword : .password
                    ).accessibilityIdentifier("auth.password")
                    Button(register ? "Register" : "Sign In") {
                        store.run {
                            let active = try await store.signIn(email: email, password: password, register: register)
                            if !active { notice = "Check your email to confirm your account, then sign in." }
                        }
                    }.disabled(
                        email.isEmpty || password.count < Self.minimumPasswordLength || store.busy || !store.hasBackend
                    )
                    .accessibilityIdentifier("auth.submit")
                    Toggle("I need an account", isOn: $register)
                    if !notice.isEmpty { Text(notice) }
                } header: {
                    Text(register ? "Create account" : "Welcome back")
                } footer: {
                    Text("An account is needed to use sitescope. Projects are shared through the people responsible.")
                }
                if !store.hasBackend {
                    Section {
                        Label("No server configured", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Color("Warning"))
                    } footer: {
                        Text("Add the Supabase URL and publishable key to Secrets.xcconfig and build again.")
                    }
                }
            }.navigationTitle("sitescope")
        }
    }
}
/// The projects the signed-in user may see, with search and project creation.
struct ProjectDashboard: View {
    @EnvironmentObject var store: Store
    @State private var creating = false
    @State private var name = ""
    @State private var query = ""
    var body: some View {
        NavigationStack {
            List {
                if store.projects.isEmpty {
                    ContentUnavailableView {
                        Label("No projects yet", systemImage: "building.2")
                    } description: {
                        Text(
                            "Create a project with +, or ask the person responsible for a project to share it with you."
                        )
                    }
                } else if !query.isEmpty
                    && !store.projects.contains(where: { $0.name.localizedCaseInsensitiveContains(query) })
                {
                    ContentUnavailableView.search(text: query)
                }
                ForEach(store.projects.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) {
                    project in
                    NavigationLink {
                        ProjectDetail(project: project)
                    } label: {
                        ProjectRow(project: project, responsible: store.name(of: project.responsible_id))
                    }
                }
            }
            .navigationTitle("Projects").accessibilityIdentifier("projects.list")
            .searchable(text: $query, prompt: "Find a project")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New project", systemImage: "plus") {
                        name = ""
                        creating = true
                    }.accessibilityIdentifier("projects.new")
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }.accessibilityLabel("Settings").accessibilityIdentifier("settings.open")
                }
            }
            .alert("New project", isPresented: $creating) {
                TextField("Project name", text: $name)
                Button("Create") {
                    store.run {
                        try await store.createProject(name: name)
                        query = ""
                    }
                }.disabled(DisplayName.normalized(name) == nil || store.busy)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You become responsible for it.")
            }
            .task { await reload() }
            .refreshable { await reload() }
        }
    }
    private func reload() async {
        do {
            try await store.loadAccount()
            try await store.loadProjects()
        } catch { store.error = error.localizedDescription }
    }
}
/// One project in the dashboard list.
private struct ProjectRow: View {
    let project: Project
    let responsible: String
    @ScaledMetric(relativeTo: .title3) private var tile = 46
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        // At accessibility sizes the icon goes above the name, so long names keep the full row width.
        let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 14))
        layout {
            Image(systemName: "building.2").font(.title3).foregroundStyle(.tint).frame(width: tile, height: tile)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name).font(.headline)
                Text("Responsible: \(responsible)").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 4)
    }
}
