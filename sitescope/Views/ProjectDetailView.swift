import SwiftUI

/// Project screen: name, rooms, sharing and, kept apart in the last section, deleting the project.
struct ProjectDetail: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let project: Project
    @State private var nameDraft: String
    @State private var roomName = ""
    @State private var email = ""
    @State private var addRoom = false
    @State private var deleting = false
    /// Set once the delete succeeded, so the name field's save on disappear does not touch the deleted project.
    @State private var deleted = false
    var manager: Bool { project.owner_id == store.userID }
    /// The store's copy, so a rename shows immediately without leaving the screen.
    private var current: Project { store.projects.first(where: { $0.id == project.id }) ?? project }

    init(project: Project) {
        self.project = project
        _nameDraft = State(initialValue: project.name)
    }

    var body: some View {
        List {
            if manager {
                NameSection(
                    placeholder: "Project name", stored: current.name, identifier: "project.name", draft: $nameDraft,
                    save: rename)
            }
            Section("Rooms") {
                if !store.rooms.contains(where: { $0.project_id == project.id }) {
                    Label("Add a room to start scanning", systemImage: "door.left.hand.open").foregroundStyle(
                        .secondary)
                }
                ForEach(store.rooms.filter { $0.project_id == project.id }) { room in
                    NavigationLink {
                        RoomDetail(project: project, initialRoom: room)
                    } label: {
                        RoomRow(room: room)
                    }
                }
                if manager {
                    Button("Add room", systemImage: "plus") {
                        roomName = ""
                        addRoom = true
                    }.accessibilityIdentifier("rooms.new")
                }
            }
            if manager {
                if store.isLocalMode {
                    Section {
                        ProjectFileShareButton(project: project)
                    } header: {
                        Text("Share a copy")
                    } footer: {
                        Text(
                            "Send the file with AirDrop or Files. It includes room maps, instructions and images, including any saved room-view photos. Importing creates an editable copy; later changes are not synchronized."
                        )
                    }
                } else {
                    Section("Grant worker access") {
                        TextField("Registered worker email", text: $email).keyboardType(.emailAddress)
                            .textContentType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("Share project", systemImage: "person.badge.plus") {
                            store.run {
                                try await store.client().rpc(
                                    "share_project",
                                    arguments: ["project": project.id.uuidString, "worker_email": email])
                                email = ""
                            }
                        }.disabled(email.isEmpty)
                        NavigationLink {
                            MembersView(project: project)
                        } label: {
                            Label("Manage worker access", systemImage: "person.2")
                        }
                    }
                }
                // HIG (Buttons, Action sheets): keep the destructive action apart from safe ones, in its own
                // last section, and confirm it because it can't be undone.
                Section {
                    Button("Delete Project", role: .destructive) { deleting = true }
                        .accessibilityIdentifier("project.delete")
                        .confirmationDialog(
                            "Delete “\(current.name)”?", isPresented: $deleting, titleVisibility: .visible
                        ) {
                            Button("Delete Project", role: .destructive) {
                                store.run {
                                    try await store.deleteProject(project)
                                    deleted = true
                                    dismiss()
                                }
                            }.accessibilityIdentifier("project.delete.confirm")
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text(
                                "This deletes the project and all of its rooms, including scans and photos. This can’t be undone."
                            )
                        }
                } footer: {
                    Text("Removes the project and all its rooms.")
                }
            }
        }
        .navigationTitle(manager ? nameDraft.titleOrFallback("Untitled Project") : current.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { do { try await store.loadRooms(project) } catch { store.error = error.localizedDescription } }
        .refreshable {
            do {
                try await store.loadProjects()
                try await store.loadRooms(project)
            } catch { store.error = error.localizedDescription }
        }
        // Pick up a name changed elsewhere (another device, a reverted save), but never overwrite what is typed.
        .onChange(of: current.name) { previous, stored in
            if nameDraft == previous { nameDraft = stored }
        }
        .alert("Add room", isPresented: $addRoom) {
            TextField("Room name", text: $roomName)
            Button("Add") {
                let title = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return }
                store.run { try await store.createRoom(in: project, name: title) }
            }.disabled(roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.busy)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var projectExists: Bool { !deleted && store.projects.contains(where: { $0.id == project.id }) }

    private func rename(_ name: String) {
        guard projectExists else { return }
        store.run {
            // Checked again when the queued rename runs: a delete may have finished in between.
            guard projectExists else { return }
            do {
                try await store.renameProject(project, name: name)
            } catch {
                nameDraft = current.name
                throw error
            }
        }
    }
}

/// One room in the project's list: scan state icon, name and scan state.
private struct RoomRow: View {
    let room: Room
    @ScaledMetric(relativeTo: .title3) private var iconWidth = 32
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        // At accessibility sizes the icon goes above the name, so long names keep the full row width.
        let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Image(systemName: room.map_path == nil ? "viewfinder" : "cube.transparent").font(.title3)
                .foregroundStyle(room.map_path == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                .frame(width: iconWidth).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(room.name).font(.headline)
                Text(room.map_path == nil ? "Ready to scan" : "Room map saved").font(.caption)
                    .foregroundStyle(.secondary)
            }
        }.padding(.vertical, 4)
    }
}
