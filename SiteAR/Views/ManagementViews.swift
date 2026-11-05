import SwiftUI
import UniformTypeIdentifiers

struct AuthenticationView: View {
    @EnvironmentObject var store: Store
    @State private var email = ""; @State private var password = ""; @State private var register = false
    @State private var notice = ""
    var body: some View {
        NavigationStack {
            Form {
                Section { Label("Instructions anchored to your workplace", systemImage: "arkit").font(.headline) }
                Section(register ? "Create account" : "Welcome back") {
                    TextField("Email", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("auth.email")
                    SecureField("Password (at least 8 characters)", text: $password).textContentType(register ? .newPassword : .password).accessibilityIdentifier("auth.password")
                    Button(register ? "Register" : "Sign in") {
                        store.run {
                            let active = try await store.client().authenticate(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, register: register)
                            if active { store.signedIn = true } else { notice = "Check your email to confirm your account, then sign in." }
                        }
                    }.disabled(email.isEmpty || password.count < 8 || store.busy).accessibilityIdentifier("auth.submit")
                    Toggle("I need an account", isOn: $register)
                    if !notice.isEmpty { Text(notice) }
                }
                Section { Text("Camera access is requested only when opening AR. sitescope supports camera-only world tracking; LiDAR is optional.").font(.footnote) }
            }.navigationTitle("sitescope")
        }
    }
}
struct ProjectDashboard: View {
    @EnvironmentObject var store: Store
    @State private var creating = false; @State private var name = ""
    @State private var query=""
    @State private var importing = false
    @State private var path: [UUID] = []
    var body: some View {
        NavigationStack(path: $path) {
            List {
                if store.projects.isEmpty {
                    ContentUnavailableView {
                        Label("Your work, in place",systemImage:"arkit")
                    } description: {
                        Text("Use + to create a project, then scan a room and attach instructions where the work happens.")

                    }
                } else if !query.isEmpty && !store.projects.contains(where:{$0.name.localizedCaseInsensitiveContains(query)}) {
                    ContentUnavailableView.search(text:query)
                }
                ForEach(store.projects.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { project in
                    NavigationLink(value:project.id) {
                        HStack(spacing:14) {
                            Image(systemName:"building.2").font(.title3).foregroundStyle(.teal).frame(width:46,height:46).background(.teal.opacity(0.1),in:RoundedRectangle(cornerRadius:12))
                            VStack(alignment:.leading,spacing:4) { Text(project.name).font(.headline);Text("Rooms and instructions").font(.caption).foregroundStyle(.secondary) }
                        }.padding(.vertical,4)
                    }
                }
            }
            .navigationTitle("Projects").accessibilityIdentifier("projects.list")
            .searchable(text:$query,prompt:"Find a project")
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
                ToolbarItem(placement: .topBarTrailing) { Button("New project", systemImage: "plus") { name = ""; creating = true }.accessibilityIdentifier("projects.new") }
                ToolbarItem(placement: .topBarLeading) { NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") } }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.sitescopeProject]) { result in
                switch result {
                case .success(let url):
                    store.run {
                        let project = try await store.importProjectFile(from: url)
                        query = ""; path.append(project.id)
                    }
                case .failure(let error): store.error = error.localizedDescription
                }
            }
            .alert("New project", isPresented: $creating) {
                TextField("Project name", text: $name)
                Button("Create") { let title = name.trimmingCharacters(in: .whitespacesAndNewlines); guard !title.isEmpty else { return }; store.run {
                    try await store.createProject(name: title);query=""
                } }.disabled(name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || store.busy)
                Button("Cancel", role: .cancel) {}
            }
            .task { do { try await store.loadProjects() } catch { store.error = error.localizedDescription } }
            .refreshable { do { try await store.loadProjects() } catch { store.error = error.localizedDescription } }
        }
    }
}
struct ProjectDetail: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let project: Project
    @State private var name = ""; @State private var email = ""
    @State private var addRoom = false; @State private var rename = false; @State private var deleting = false
    var manager: Bool { project.owner_id == store.userID }
    /// The store's copy, so a rename shows immediately without leaving the screen.
    private var current: Project { store.projects.first(where:{ $0.id == project.id }) ?? project }
    var body: some View {
        List {
            Section("Rooms") {
                if !store.rooms.contains(where:{$0.project_id == project.id}) {
                    Label("Add a room to start scanning",systemImage:"door.left.hand.open").foregroundStyle(.secondary)
                }
                ForEach(store.rooms.filter { $0.project_id == project.id }) { room in
                    NavigationLink { RoomDetail(project: project, initialRoom: room) } label: {
                        HStack(spacing:12) {
                            Image(systemName:room.map_path == nil ? "viewfinder" : "cube.transparent").font(.title3).foregroundStyle(room.map_path == nil ? Color.secondary : Color.teal).frame(width:32)
                            VStack(alignment:.leading,spacing:4) { Text(room.name).font(.headline);Text(room.map_path == nil ? "Ready to scan" : "Room map saved").font(.caption).foregroundStyle(.secondary) }
                        }.padding(.vertical,4)
                    }
                }
                if manager { Button("Add room", systemImage: "plus") { name = ""; addRoom = true }.accessibilityIdentifier("rooms.new") }
            }
            if manager {
                if store.isLocalMode {
                    Section("Share a copy") {
                        ProjectFileShareButton(project: project)
                        Text("Send the file with AirDrop or Files. It includes room maps, instructions and images, including any saved room-view photos. Importing creates an editable copy; later changes are not synchronized.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if !store.isLocalMode { Section("Grant worker access") {
                    TextField("Registered worker email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Share project") { store.run { try await store.client().rpc("share_project", arguments: ["project": project.id.uuidString, "worker_email": email]); email = "" } }.disabled(email.isEmpty)
                    NavigationLink("Manage worker access") { MembersView(project: project) }
                } }
                Section("Project") {
                    Button("Rename project") { name = current.name; rename = true }
                    Button("Delete project and all rooms", role: .destructive) { deleting = true }
                }
            }
        }.navigationTitle(current.name).navigationBarTitleDisplayMode(.inline)
        .task { do { try await store.loadRooms(project) } catch { store.error = error.localizedDescription } }
        .refreshable { do { try await store.loadRooms(project) } catch { store.error = error.localizedDescription } }
        .alert("Add room", isPresented: $addRoom) {
            TextField("Room name", text: $name)
            Button("Add") { let title = name.trimmingCharacters(in: .whitespacesAndNewlines); guard !title.isEmpty else { return }; store.run { try await store.createRoom(in: project, name: title) } }.disabled(name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || store.busy)
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename project", isPresented: $rename) {
            TextField("Name", text: $name)
            Button("Save") { guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }; store.run { try await store.renameProject(project, name: name) } }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.busy)
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Permanently delete this project, its rooms and instructions?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete project", role: .destructive) { store.run { try await store.deleteProject(project); dismiss() } }
        }
    }
}
struct Membership: Decodable, Identifiable { let project_id: UUID; let user_id: UUID; var id: UUID { user_id } }
struct MembersView: View {
    @EnvironmentObject var store: Store
    let project: Project
    @State private var members: [Membership] = []
    var body: some View {
        List(members) { member in
            VStack(alignment: .leading) {
                Text(member.user_id.uuidString).font(.caption).textSelection(.enabled)
                Button("Revoke worker access", role: .destructive) { store.run { try await store.client().rpc("revoke_worker", arguments: ["project": project.id.uuidString, "worker": member.user_id.uuidString]); try await load() } }
            }
        }.navigationTitle("Workers").task { do { try await load() } catch { store.error = error.localizedDescription } }
    }
    func load() async throws { members = try await store.client().list("memberships", query: "&project_id=eq.\(project.id)") }
}
struct RoomDetail: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let project: Project; let initialRoom: Room
    @State private var room: Room?
    @State private var arMode: ARMode?
    @State private var rename = false; @State private var deleting = false; @State private var name = ""
    var current: Room { room ?? initialRoom }
    var manager: Bool { project.owner_id == store.userID }
    var body: some View {
        List {
            let tasks=store.annotations.filter { $0.room_id == current.id }
            if !tasks.isEmpty {
                Section {
                    VStack(alignment:.leading,spacing:10) {
                        HStack { Label("Work progress",systemImage:"checkmark.circle").font(.headline);Spacer();Text("\(tasks.filter{$0.status == .completed}.count) / \(tasks.count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary) }
                        ProgressView(value:Double(tasks.filter{$0.status == .completed}.count),total:Double(tasks.count)).tint(.teal)
                            .accessibilityLabel("Completed tasks")
                        Text("\(tasks.filter{$0.status == .inProgress}.count) in progress · \(tasks.filter{$0.status == .todo}.count) to do").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical,6)
                }
            }
            Section("Spatial room") {
                if current.map_path != nil {
                    Button("Start AR walkthrough", systemImage: "arkit") { arMode = .walkthrough }
                    if manager { Button("Edit AR instructions", systemImage: "pencil.tip.crop.circle") { arMode = .editing } }
                    Text("Scan the room from familiar viewpoints. Your saved drawings appear when the room is recognized.").font(.footnote)
                } else if manager { Button("Map room", systemImage: "camera.viewfinder") { arMode = .mapping } }
                else { Text("Ask the manager to map this room.") }
            }
            NavigationLink { TrackingTipsView() } label: { Label("Scanning tips",systemImage:"lightbulb") }
            Section("Tasks · available without AR") {
                ForEach(TaskStatus.allCases, id: \.self) { status in
                    let tasks = store.annotations.filter { $0.room_id == current.id && $0.status == status }
                    if !tasks.isEmpty {
                        Label(status.label,systemImage:status.symbol).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(tasks) { item in NavigationLink { TaskEditor(item: item, room: current, manager: manager) } label: { VStack(alignment:.leading,spacing:4) { Text(item.title).font(.body.weight(.medium));if !item.detail.isEmpty { Text(item.detail).lineLimit(2).font(.caption).foregroundStyle(.secondary) };if item.priority == 2 { Label("High priority",systemImage:"exclamationmark").font(.caption2).foregroundStyle(.orange) } } } }
                    }
                }
                if !store.annotations.contains(where: { $0.room_id == current.id }) { Text("No instructions yet").foregroundStyle(.secondary) }
            }
            if manager {
                Section {
                    Button("Rename room") { name = current.name; rename = true }
                    Button("Delete room", role: .destructive) { deleting = true }
                }
            }
        }.navigationTitle(current.name).navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }.refreshable { await refresh() }
        .fullScreenCover(item: $arMode, onDismiss: { Task { await refresh() } }) { mode in ARScreen(room: current, mode: mode, manager: manager).environmentObject(store) }
        .alert("Rename room", isPresented: $rename) {
            TextField("Name", text: $name)
            Button("Save") { guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }; store.run { try await store.renameRoom(current, name: name); await refresh() } }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.busy)
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Permanently delete this room and its instructions?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete room", role: .destructive) { store.run { try await store.deleteRoom(current); dismiss() } }
        }
    }
    func refresh() async {
        do {
            let loaded = try await store.room(id: initialRoom.id)
            room = loaded; try await store.loadAnnotations(loaded)
        } catch { store.error = error.localizedDescription }
    }
}
struct TaskEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var item: Annotation
    let room: Room; let manager: Bool
    @State private var deleting = false
    @State private var discarding = false
    private let original: Annotation
    private let onReposition: (() -> Void)?
    init(item: Annotation, room: Room, manager: Bool, onReposition: (() -> Void)? = nil) {
        _item = State(initialValue: item); original = item; self.room = room; self.manager = manager; self.onReposition = onReposition
    }
    var body: some View {
        Form {
            Section("Instruction") {
                if manager { TextField("Title", text: $item.title, axis:.vertical).lineLimit(1...3); TextField("Description", text: $item.detail, axis: .vertical).lineLimit(3...8); Picker("Priority", selection: $item.priority) { Text("Low").tag(0); Text("Normal").tag(1); Text("High").tag(2) } }
                else { Text(item.title).font(.headline); Text(item.detail) }
            }
            Picker("Status", selection: $item.status) { ForEach(TaskStatus.allCases, id: \.self) { Text($0.label).tag($0) } }
            Button("Save task") { store.run {
                try await store.saveTask(item, room: room, manager: manager); dismiss()
            } }.disabled(store.busy || item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || item.title.count>240)
            if manager, let onReposition { Button("Reposition geometry in AR") { onReposition(); dismiss() }.disabled(item != original) }
            if manager { Button("Delete instruction", role: .destructive) { deleting = true } }
        }.navigationTitle("Task").navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled(item != original)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Back") { if item != original { discarding = true } else { dismiss() } }.disabled(store.busy) } }
        .confirmationDialog("Discard unsaved task edits?", isPresented: $discarding, titleVisibility: .visible) { Button("Discard changes", role: .destructive) { dismiss() } }
        .confirmationDialog("Delete this spatial instruction?", isPresented: $deleting) {
            Button("Delete", role: .destructive) { store.run { try await store.deleteTask(item, room: room); dismiss() } }
        }
    }
}
struct SettingsView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        Form {
            if store.isLocalMode { Section("On this device") { Text("No account connected"); Text("Your projects, room maps and instructions are saved on this device. Sharing becomes available when cloud accounts are connected.").font(.footnote) } }
            else { Section("Account") { Text(store.backend?.user?.email ?? "Signed in"); Button("Sign out", role: .destructive) { store.run { await store.backend?.signOut(); store.projects = []; store.rooms = []; store.annotations = []; store.signedIn = false } } } }
            Section { NavigationLink { TrackingTipsView() } label: { Label("Camera-only scanning tips",systemImage:"camera.viewfinder") } }
            Section("sitescope \(Self.version)") { Text("Spatial work instructions · iOS 17+"); Text("Room recognition uses camera features from the saved scan. Lighting and texture affect accuracy. Check drawings against the physical room before work. Exported project files include room maps and images.").font(.footnote) }
        }.navigationTitle("Settings")
    }
    private static var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "–") (\(info?["CFBundleVersion"] as? String ?? "–"))"
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
                Text("sitescope couldn't read the projects saved on this device. Nothing has been deleted. Starting fresh keeps the unreadable file as a backup in the app's data folder.")
            } actions: {
                Button("Start fresh, keep backup") { confirming = true }.buttonStyle(.borderedProminent)
            }
            .navigationTitle("sitescope")
            .confirmationDialog("Start with an empty project list? The unreadable file is moved to a backup, not deleted.", isPresented: $confirming, titleVisibility: .visible) {
                Button("Start fresh") { do { try store.startFreshKeepingBackup() } catch { store.error = error.localizedDescription } }
            }
        }
    }
}
