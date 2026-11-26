import SwiftUI
import UniformTypeIdentifiers

/// Sign-in and registration screen for cloud accounts.
struct AuthenticationView: View {
    @EnvironmentObject var store: Store
    @State private var email = ""
    @State private var password = ""
    @State private var register = false
    @State private var notice = ""
    var body: some View {
        NavigationStack {
            Form {
                Section { Label("Instructions anchored to your workplace", systemImage: "arkit").font(.headline) }
                Section(register ? "Create account" : "Welcome back") {
                    TextField("Email", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier(
                            "auth.email")
                    SecureField("Password (at least 8 characters)", text: $password).textContentType(
                        register ? .newPassword : .password
                    ).accessibilityIdentifier("auth.password")
                    Button(register ? "Register" : "Sign in") {
                        store.run {
                            let active = try await store.client().authenticate(
                                email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password,
                                register: register)
                            if active {
                                store.signedIn = true
                            } else {
                                notice = "Check your email to confirm your account, then sign in."
                            }
                        }
                    }.disabled(email.isEmpty || password.count < 8 || store.busy).accessibilityIdentifier("auth.submit")
                    Toggle("I need an account", isOn: $register)
                    if !notice.isEmpty { Text(notice) }
                }
                Section {
                    Text(
                        "Camera access is requested only when opening AR. sitescope supports camera-only world tracking; LiDAR is optional."
                    ).font(.footnote)
                }
            }.navigationTitle("sitescope")
        }
    }
}
/// Project list with search, project creation and local-file import.
struct ProjectDashboard: View {
    @EnvironmentObject var store: Store
    @State private var creating = false
    @State private var name = ""
    @State private var query = ""
    @State private var importing = false
    @State private var path: [UUID] = []
    var body: some View {
        NavigationStack(path: $path) {
            List {
                if store.projects.isEmpty {
                    ContentUnavailableView {
                        Label("Your work, in place", systemImage: "arkit")
                    } description: {
                        Text(
                            "Use + to create a project, then scan a room and attach instructions where the work happens."
                        )

                    }
                } else if !query.isEmpty
                    && !store.projects.contains(where: { $0.name.localizedCaseInsensitiveContains(query) })
                {
                    ContentUnavailableView.search(text: query)
                }
                ForEach(store.projects.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) {
                    project in
                    NavigationLink(value: project.id) { ProjectRow(project: project) }
                }
            }
            .navigationTitle("Projects").accessibilityIdentifier("projects.list")
            .searchable(text: $query, prompt: "Find a project")
            .onChange(of: store.projects.count) { previous, current in
                if current > previous { query = "" }
            }
            .navigationDestination(for: UUID.self) { id in
                if let project = store.projects.first(where: { $0.id == id }) { ProjectDetail(project: project) }
            }
            .toolbar {
                if store.isLocalMode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Import project", systemImage: "square.and.arrow.down") { importing = true }
                            .disabled(store.busy).accessibilityIdentifier("projects.import")
                    }
                }
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
            .fileImporter(isPresented: $importing, allowedContentTypes: [.sitescopeProject]) { result in
                switch result {
                case .success(let url):
                    store.run {
                        let project = try await store.importProjectFile(from: url)
                        query = ""
                        path.append(project.id)
                    }
                case .failure(let error): store.error = error.localizedDescription
                }
            }
            .alert("New project", isPresented: $creating) {
                TextField("Project name", text: $name)
                Button("Create") {
                    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !title.isEmpty else { return }
                    store.run {
                        try await store.createProject(name: title)
                        query = ""
                    }
                }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.busy)
                Button("Cancel", role: .cancel) {}
            }
            .task { do { try await store.loadProjects() } catch { store.error = error.localizedDescription } }
            .refreshable { do { try await store.loadProjects() } catch { store.error = error.localizedDescription } }
        }
    }
}
/// One project in the dashboard list.
private struct ProjectRow: View {
    let project: Project
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
                Text("Rooms and instructions").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 4)
    }
}
struct Membership: Decodable, Identifiable {
    let project_id: UUID
    let user_id: UUID
    var id: UUID { user_id }
}
/// Lists the workers with access to a project; the manager can revoke their access.
struct MembersView: View {
    @EnvironmentObject var store: Store
    let project: Project
    @State private var members: [Membership] = []
    @State private var revoking: Membership?
    var body: some View {
        List(members) { member in
            VStack(alignment: .leading) {
                Text(member.user_id.uuidString).font(.caption).textSelection(.enabled)
                Button("Revoke Access", role: .destructive) { revoking = member }
            }
        }.navigationTitle("Workers").task { do { try await load() } catch { store.error = error.localizedDescription } }
            .confirmationDialog(
                "Revoke this worker’s access?",
                isPresented: Binding(get: { revoking != nil }, set: { if !$0 { revoking = nil } }),
                titleVisibility: .visible, presenting: revoking
            ) { member in
                Button("Revoke Access", role: .destructive) {
                    store.run {
                        try await store.client().rpc(
                            "revoke_worker",
                            arguments: ["project": project.id.uuidString, "worker": member.user_id.uuidString])
                        try await load()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("They can no longer open \(project.name). You can share the project with them again later.")
            }
    }
    func load() async throws {
        members = try await store.client().list("memberships", query: "&project_id=eq.\(project.id)")
    }
}
/// Edits one spatial instruction. Managers can change its content; everyone can update its status.
struct TaskEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var item: Annotation
    let room: Room
    let manager: Bool
    @State private var deleting = false
    @State private var discarding = false
    // Snapshot of the saved task; comparing against it detects unsaved edits.
    private let original: Annotation
    private let onReposition: (() -> Void)?
    init(item: Annotation, room: Room, manager: Bool, onReposition: (() -> Void)? = nil) {
        _item = State(initialValue: item)
        original = item
        self.room = room
        self.manager = manager
        self.onReposition = onReposition
    }
    var body: some View {
        Form {
            Section("Instruction") {
                if manager {
                    TextField("Title", text: $item.title, axis: .vertical).lineLimit(1...3)
                    TextField("Description", text: $item.detail, axis: .vertical).lineLimit(3...8)
                    Picker("Priority", selection: $item.priority) {
                        Text("Low").tag(0)
                        Text("Normal").tag(1)
                        Text("High").tag(2)
                    }
                } else {
                    Text(item.title).font(.headline)
                    Text(item.detail)
                }
            }
            Picker("Status", selection: $item.status) {
                ForEach(TaskStatus.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Button("Save task") {
                store.run {
                    try await store.saveTask(item, room: room, manager: manager)
                    dismiss()
                }
            }.disabled(
                store.busy || item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || item.title.count > 240)
            if manager, let onReposition {
                Button("Reposition geometry in AR") {
                    onReposition()
                    dismiss()
                }.disabled(item != original)
            }
            if manager {
                Section {
                    Button("Delete Instruction", role: .destructive) { deleting = true }
                        .accessibilityIdentifier("task.delete")
                        .confirmationDialog(
                            "Delete “\(original.title)”?", isPresented: $deleting, titleVisibility: .visible
                        ) {
                            Button("Delete Instruction", role: .destructive) {
                                store.run {
                                    try await store.deleteTask(item, room: room)
                                    dismiss()
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Its drawing is removed from the room too. This can’t be undone.")
                        }
                }
            }
        }.navigationTitle(original.title).navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .interactiveDismissDisabled(item != original)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { if item != original { discarding = true } else { dismiss() } }.disabled(store.busy)
                        .confirmationDialog(
                            "Discard unsaved task edits?", isPresented: $discarding, titleVisibility: .visible
                        ) {
                            Button("Discard Changes", role: .destructive) { dismiss() }
                            Button("Keep Editing", role: .cancel) {}
                        }
                }
            }
    }
}
/// Shown instead of a login screen when on-device data exists but cannot be read; a login cannot work offline.
struct LocalDataRecoveryView: View {
    @EnvironmentObject var store: Store
    @State private var confirming = false
    @State private var backup: URL?
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Saved data can't be opened", systemImage: "externaldrive.badge.exclamationmark")
            } description: {
                Text(
                    "sitescope couldn't read the projects saved on this device. Nothing has been deleted. Starting fresh keeps the unreadable file as a backup in the app's data folder."
                )
            } actions: {
                Button("Start fresh, keep backup") { confirming = true }.buttonStyle(.borderedProminent)
                    .controlSize(.large).prominentLabelContrast()
                    .confirmationDialog(
                        "Start with an empty project list? The unreadable file is moved to a backup, not deleted.",
                        isPresented: $confirming, titleVisibility: .visible
                    ) {
                        Button("Start Fresh") {
                            do { try store.startFreshKeepingBackup() } catch {
                                store.error = error.localizedDescription
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
            }
            .navigationTitle("sitescope")
        }
    }
}
