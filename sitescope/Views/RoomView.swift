import SwiftUI

/// A room: its scan and drawings, a description and who is responsible. Members scan, draw and edit the
/// description; the room is deleted or shared by its responsible person and handed over by the house's.
struct RoomView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let roomID: UUID
    @State private var arMode: ARMode?
    @State private var renaming = false
    @State private var deleting = false
    @State private var showingPeople = false
    @State private var description = ""
    @FocusState private var editingDescription: Bool

    var body: some View {
        if let room = store.rooms.first(where: { $0.id == roomID }),
            let house = store.houses.first(where: { $0.id == room.house_id }),
            let project = store.projects.first(where: { $0.id == room.project_id })
        {
            content(project, house, room)
        } else {
            ContentUnavailableView(
                "Room Not Available", systemImage: "door.left.hand.open",
                description: Text("It was deleted, or it is no longer shared with you."))
        }
    }

    private func content(_ project: Project, _ house: House, _ room: Room) -> some View {
        let level = store.level(on: .room(project, house, room))
        let drawings = store.annotations.filter { $0.room_id == room.id }.count
        return List {
            Section {
                ResponsibleRow(
                    scope: .room(project, house, room), current: room.responsible_id,
                    canChange: store.level(on: .house(project, house)).canManage)
            } footer: {
                Text(AccessLevelText.footer(level, scope: "room"))
            }
            Section {
                if room.map_path == nil {
                    if level.canContribute {
                        Button("Scan Room", systemImage: "camera.viewfinder") { arMode = .mapping }
                            .accessibilityIdentifier("room.scan")
                    } else {
                        Label("Not scanned yet", systemImage: "viewfinder").foregroundStyle(.secondary)
                    }
                } else {
                    Button("View in AR", systemImage: "arkit") { arMode = .walkthrough }
                        .accessibilityIdentifier("room.view")
                    if level.canContribute {
                        Button("Draw in AR", systemImage: "pencil.tip.crop.circle") { arMode = .editing }
                            .accessibilityIdentifier("room.draw")
                    }
                }
                NavigationLink {
                    TrackingTipsView()
                } label: {
                    Label("Scanning Tips", systemImage: "lightbulb")
                }
            } header: {
                Text("Scan")
            } footer: {
                if room.map_path == nil {
                    Text("Scan the room once; drawings are placed on its walls and surfaces.")
                } else {
                    Text(drawings == 1 ? "1 drawing" : "\(drawings) drawings")
                }
            }
            Section("Description") {
                if level.canContribute {
                    TextField("What should happen in this room?", text: $description, axis: .vertical)
                        .lineLimit(3...12)
                        .focused($editingDescription)
                        .accessibilityIdentifier("room.description")
                } else {
                    Text(room.description.isEmpty ? "No description" : room.description)
                        .foregroundStyle(room.description.isEmpty ? .secondary : .primary)
                }
            }
        }
        .navigationTitle(room.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh() }
        .toolbar {
            if level.canContribute {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("More", systemImage: "ellipsis.circle") {
                        Button("Rename", systemImage: "pencil") { renaming = true }
                        if level.canManage {
                            Button("People", systemImage: "person.2") { showingPeople = true }
                                .disabled(!store.isOnline)
                            Divider()
                            Button("Delete Room", systemImage: "trash", role: .destructive) { deleting = true }
                        }
                    }.accessibilityIdentifier("room.more")
                }
            }
            ToolbarItem(placement: .status) { SyncStatusView() }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { editingDescription = false }
            }
        }
        .onAppear { description = room.description }
        .onChange(of: room.description) { _, saved in
            if !editingDescription { description = saved }
        }
        .onChange(of: editingDescription) { _, editing in
            if !editing { saveDescription(of: room) }
        }
        .onDisappear { saveDescription(of: room) }
        .navigationDestination(isPresented: $showingPeople) { AccessView(scope: .room(project, house, room)) }
        .namePrompt("Rename Room", action: "Rename", isPresented: $renaming, initial: room.name) { name in
            store.run { try await store.renameRoom(room, name: name) }
        }
        .deleteConfirmation(
            room.name, isPresented: $deleting, message: "This deletes the room with its scan and drawings for everyone."
        ) {
            store.run {
                try await store.deleteRoom(room)
                dismiss()
            }
        }
        .fullScreenCover(item: $arMode) { mode in
            ARScreen(room: room, mode: mode, manager: level.canContribute).environmentObject(store)
        }
    }

    /// Saves like Notes: when editing ends or the screen goes away, and only if the text changed. Only people who
    /// may edit get the text field, so for everyone else the text always equals the saved one.
    private func saveDescription(of room: Room) {
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text != room.description else { return }
        store.run { try await store.describeRoom(room, as: text) }
    }
}
