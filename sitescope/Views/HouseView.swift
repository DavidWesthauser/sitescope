import SwiftUI

/// A house: its rooms and who is responsible. Members add rooms; the house is renamed, shared or deleted by its
/// responsible person, and handed over by the project's.
struct HouseView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let houseID: UUID
    @State private var adding = false
    @State private var renaming = false
    @State private var deleting = false
    @State private var showingPeople = false
    @State private var renamingRoom: Room?
    @State private var deletingRoom: Room?

    var body: some View {
        if let house = store.houses.first(where: { $0.id == houseID }),
            let project = store.projects.first(where: { $0.id == house.project_id })
        {
            content(project, house)
        } else {
            ContentUnavailableView(
                "House Not Available", systemImage: "house",
                description: Text("It was deleted, or it is no longer shared with you."))
        }
    }

    private func content(_ project: Project, _ house: House) -> some View {
        let level = store.level(on: .house(project, house))
        let rooms = store.rooms.filter { $0.house_id == house.id }
        return List {
            Section {
                ResponsibleRow(
                    scope: .house(project, house), current: house.responsible_id,
                    canChange: store.level(on: .project(project)).canManage)
            } footer: {
                Text(AccessLevelText.footer(level, scope: "house"))
            }
            Section {
                if rooms.isEmpty {
                    ContentUnavailableView {
                        Label("No Rooms", systemImage: "door.left.hand.open")
                    } description: {
                        Text(level.canContribute ? "Add a room, then scan it." : "No rooms are shared with you yet.")
                    } actions: {
                        if level.canContribute {
                            Button("New Room") { adding = true }.buttonStyle(.borderedProminent)
                        }
                    }
                }
                ForEach(rooms) { room in
                    let scope = AccessScope.room(project, house, room)
                    NavigationLink(value: Route.room(room.id)) {
                        RecordRow(
                            title: room.name, subtitle: room.map_path == nil ? "Not scanned" : drawingCount(room),
                            systemImage: room.map_path == nil ? "viewfinder" : "cube.transparent",
                            state: store.syncState(of: RecordKey(.room, room.id)))
                    }
                    .contextMenu {
                        RetryMenuButton(key: RecordKey(.room, room.id))
                        if store.level(on: scope).canContribute {
                            Button("Rename", systemImage: "pencil") { renamingRoom = room }
                        }
                        if store.level(on: scope).canManage {
                            Button("Delete", systemImage: "trash", role: .destructive) { deletingRoom = room }
                        }
                    }
                    .swipeActions {
                        if store.level(on: scope).canManage {
                            Button("Delete", systemImage: "trash", role: .destructive) { deletingRoom = room }
                        }
                    }
                    .retrySwipe(RecordKey(.room, room.id), store: store)
                }
            } header: {
                Text("Rooms")
            }
        }
        .navigationTitle(house.name)
        .refreshable { await store.refresh() }
        .toolbar {
            if level.canContribute {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Room", systemImage: "plus") { adding = true }.accessibilityIdentifier("rooms.new")
                }
            }
            if level.canManage {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("More", systemImage: "ellipsis.circle") {
                        RetryMenuButton(key: RecordKey(.house, house.id))
                        Button("Rename", systemImage: "pencil") { renaming = true }
                        Button("People", systemImage: "person.2") { showingPeople = true }
                            .disabled(!store.isOnline)
                        Divider()
                        Button("Delete House", systemImage: "trash", role: .destructive) { deleting = true }
                    }.accessibilityIdentifier("house.more")
                }
            }
            ToolbarItem(placement: .status) { SyncStatusView() }
        }
        .navigationDestination(isPresented: $showingPeople) { AccessView(scope: .house(project, house)) }
        .namePrompt("New Room", action: "Create", isPresented: $adding) { name in
            store.run { try await store.createRoom(in: house, name: name) }
        }
        .namePrompt("Rename House", action: "Rename", isPresented: $renaming, initial: house.name) { name in
            store.run { try await store.renameHouse(house, name: name) }
        }
        .namePrompt(
            "Rename Room", action: "Rename",
            isPresented: Binding(get: { renamingRoom != nil }, set: { if !$0 { renamingRoom = nil } }),
            initial: renamingRoom?.name ?? ""
        ) { name in
            guard let room = renamingRoom else { return }
            store.run { try await store.renameRoom(room, name: name) }
        }
        .deleteConfirmation(
            house.name, isPresented: $deleting,
            message: "This deletes the house with its rooms, scans and drawings for everyone."
        ) {
            store.run {
                try await store.deleteHouse(house)
                dismiss()
            }
        }
        .deleteConfirmation(
            deletingRoom?.name ?? "",
            isPresented: Binding(get: { deletingRoom != nil }, set: { if !$0 { deletingRoom = nil } }),
            message: "This deletes the room with its scan and drawings for everyone."
        ) {
            guard let room = deletingRoom else { return }
            store.run { try await store.deleteRoom(room) }
        }
    }

    private func drawingCount(_ room: Room) -> String {
        let count = store.annotations.filter { $0.room_id == room.id }.count
        return count == 1 ? "Scanned · 1 drawing" : "Scanned · \(count) drawings"
    }
}
