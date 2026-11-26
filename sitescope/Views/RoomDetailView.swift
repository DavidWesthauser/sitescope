import SwiftUI

/// Room screen: name, task progress, AR entry points, tasks by status and, in its own last section, deleting.
struct RoomDetail: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let project: Project
    let initialRoom: Room
    @State private var room: Room?
    @State private var arMode: ARMode?
    @State private var deleting = false
    @State private var nameDraft: String
    var current: Room { room ?? initialRoom }
    var manager: Bool { project.owner_id == store.userID }

    init(project: Project, initialRoom: Room) {
        self.project = project
        self.initialRoom = initialRoom
        _nameDraft = State(initialValue: initialRoom.name)
    }

    var body: some View {
        List {
            if manager {
                NameSection(
                    placeholder: "Room name", stored: current.name, identifier: "room.name", draft: $nameDraft,
                    save: rename)
            }
            let tasks = store.annotations.filter { $0.room_id == current.id }
            if !tasks.isEmpty {
                Section { WorkProgress(tasks: tasks) }
            }
            spatialSection
            Section {
                NavigationLink {
                    TrackingTipsView()
                } label: {
                    Label("Scanning tips", systemImage: "lightbulb")
                }
            }
            if tasks.isEmpty {
                Section {
                    Text("No instructions yet").foregroundStyle(.secondary)
                    addTaskRow
                } header: {
                    Text("Tasks")
                } footer: {
                    Text("Tasks are available without AR.")
                }
            }
            ForEach(TaskStatus.allCases, id: \.self) { status in
                let group = tasks.filter { $0.status == status }
                if !group.isEmpty {
                    Section {
                        ForEach(group) { item in
                            NavigationLink {
                                TaskEditor(item: item, room: current, manager: manager)
                            } label: {
                                TaskRow(item: item)
                            }
                        }
                    } header: {
                        Label(status.label, systemImage: status.symbol)
                    }
                }
            }
            if manager && !tasks.isEmpty {
                Section { addTaskRow }
            }
            if manager {
                // HIG (Buttons, Action sheets): destructive action in its own last section, with a confirmation.
                Section {
                    Button("Delete Room", role: .destructive) { deleting = true }
                        .accessibilityIdentifier("room.delete")
                        .confirmationDialog(
                            "Delete “\(current.name)”?", isPresented: $deleting, titleVisibility: .visible
                        ) {
                            Button("Delete Room", role: .destructive) {
                                store.run {
                                    try await store.deleteRoom(current)
                                    dismiss()
                                }
                            }.accessibilityIdentifier("room.delete.confirm")
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text(
                                "This deletes the room, its room map and all of its instructions. This can’t be undone."
                            )
                        }
                } footer: {
                    Text("Removes the room and all its instructions.")
                }
            }
        }
        .navigationTitle(manager ? nameDraft.titleOrFallback("Untitled Room") : current.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }.refreshable { await refresh() }
        .fullScreenCover(
            item: $arMode, onDismiss: { Task { await refresh() } },
            content: { mode in ARScreen(room: current, mode: mode, manager: manager).environmentObject(store) })
    }

    /// Tasks are pinned to a spot in the room, so adding one opens the AR editor; an unmapped room must be mapped first.
    @ViewBuilder private var addTaskRow: some View {
        if manager {
            if current.map_path != nil {
                Button("Add task", systemImage: "plus") { arMode = .editing }.accessibilityIdentifier("tasks.new")
            } else {
                Label("Map the room to add tasks", systemImage: "plus").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var spatialSection: some View {
        if current.map_path != nil {
            Section {
                Button("Start AR walkthrough", systemImage: "arkit") { arMode = .walkthrough }
                if manager {
                    Button("Edit AR instructions", systemImage: "pencil.tip.crop.circle") { arMode = .editing }
                }
            } header: {
                Text("Spatial room")
            } footer: {
                Text("Scan the room from familiar viewpoints. Your saved drawings appear when the room is recognized.")
            }
        } else if manager {
            Section("Spatial room") {
                Button("Map room", systemImage: "camera.viewfinder") { arMode = .mapping }
            }
        } else {
            Section("Spatial room") {
                Text("Ask the manager to map this room.")
            }
        }
    }

    private func rename(_ name: String) {
        store.run {
            do {
                try await store.renameRoom(current, name: name)
                await refresh()
            } catch {
                nameDraft = current.name
                throw error
            }
        }
    }

    func refresh() async {
        do {
            let previousName = current.name
            let loaded = try await store.room(id: initialRoom.id)
            room = loaded
            // Pick up a name changed elsewhere, but never overwrite what is being typed.
            if nameDraft == previousName { nameDraft = loaded.name }
            try await store.loadAnnotations(loaded)
        } catch { store.error = error.localizedDescription }
    }
}

/// Completed / total bar with the in-progress and to-do counts.
private struct WorkProgress: View {
    let tasks: [Annotation]
    var body: some View {
        let completed = tasks.filter { $0.status == .completed }.count
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Work progress", systemImage: "checkmark.circle").font(.headline)
                Spacer()
                Text("\(completed) / \(tasks.count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(completed), total: Double(tasks.count))
                .accessibilityLabel("Completed tasks")
            Text(
                "\(tasks.filter{$0.status == .inProgress}.count) in progress · \(tasks.filter{$0.status == .todo}.count) to do"
            ).font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 6)
    }
}

private struct TaskRow: View {
    let item: Annotation
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title).font(.body.weight(.medium))
            if !item.detail.isEmpty {
                Text(item.detail).lineLimit(2).font(.caption).foregroundStyle(.secondary)
            }
            if item.priority == 2 {
                // Named asset color: the system orange is 2.3:1 on white, below the 4.5:1 text minimum.
                Label("High priority", systemImage: "exclamationmark.triangle.fill").font(.caption2)
                    .foregroundStyle(Color("Warning"))
            }
        }
    }
}
