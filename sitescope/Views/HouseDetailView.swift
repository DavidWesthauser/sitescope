import SwiftUI

/// House screen: name, rooms, who is responsible, access and, in its own last section, deleting.
/// Controls follow the caller's level on the house; handing the house over needs level 3 on the project.
struct HouseDetail: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let project: Project
    let house: House
    @State private var level = AccessLevel.none
    @State private var projectLevel = AccessLevel.none
    @State private var nameDraft: String
    @State private var roomName = ""
    @State private var addRoom = false
    @State private var deleting = false
    /// Set once the delete succeeded, so the name field's save on disappear does not touch the deleted house.
    @State private var deleted = false
    private var current: House { store.houses.first(where: { $0.id == house.id }) ?? house }
    private var scope: AccessScope { .house(project, current) }

    init(project: Project, house: House) {
        self.project = project
        self.house = house
        _nameDraft = State(initialValue: house.name)
    }

    var body: some View {
        List {
            if level.canManage {
                NameSection(
                    placeholder: "House name", stored: current.name, identifier: "house.name", draft: $nameDraft,
                    save: rename)
            }
            Section("Rooms") {
                let rooms = store.rooms.filter { $0.house_id == house.id }
                if rooms.isEmpty {
                    Label(
                        level.canContribute ? "Add the first room" : "No rooms you can see",
                        systemImage: "door.left.hand.open"
                    )
                    .foregroundStyle(.secondary)
                }
                ForEach(rooms) { room in
                    NavigationLink {
                        RoomDetail(project: project, house: current, initialRoom: room)
                    } label: {
                        RoomRow(room: room)
                    }
                }
                if level.canContribute {
                    Button("Add room", systemImage: "plus") {
                        roomName = ""
                        addRoom = true
                    }.accessibilityIdentifier("rooms.new")
                }
            }
            ResponsibleSection(
                scope: scope, current: current.responsible_id, canChange: projectLevel.canManage,
                changed: { try await store.loadHouses(project) })
            if level.canManage {
                Section {
                    NavigationLink {
                        AccessView(scope: scope)
                    } label: {
                        Label("Manage access", systemImage: "person.2")
                    }.accessibilityIdentifier("house.access")
                }
                Section {
                    Button("Delete House", role: .destructive) { deleting = true }
                        .accessibilityIdentifier("house.delete")
                        .confirmationDialog(
                            "Delete “\(current.name)”?", isPresented: $deleting, titleVisibility: .visible
                        ) {
                            Button("Delete House", role: .destructive) {
                                store.run {
                                    try await store.deleteHouse(current)
                                    deleted = true
                                    dismiss()
                                }
                            }.accessibilityIdentifier("house.delete.confirm")
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This deletes the house with all its rooms and comments. This can’t be undone.")
                        }
                } footer: {
                    Text("Removes the house for everyone with access.")
                }
            }
            AccessLevelFooter(level: level)
        }
        .navigationTitle(level.canManage ? nameDraft.titleOrFallback("Untitled House") : current.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await reload() }
        .alert("Add room", isPresented: $addRoom) {
            TextField("Room name", text: $roomName)
            Button("Add") {
                store.run { try await store.createRoom(in: current, name: roomName) }
            }.disabled(DisplayName.normalized(roomName) == nil || store.busy)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var houseExists: Bool { !deleted && store.houses.contains(where: { $0.id == house.id }) }

    private func reload() async {
        do {
            level = try await store.level(on: scope)
            projectLevel = try await store.level(on: .project(project))
            try await store.loadRooms(current)
        } catch { store.error = error.localizedDescription }
    }

    private func rename(_ name: String) {
        guard houseExists else { return }
        store.run {
            guard houseExists else { return }
            do {
                try await store.renameHouse(current, name: name)
            } catch {
                nameDraft = current.name
                throw error
            }
        }
    }
}

/// One room in a house's list: name, building status and area when known.
private struct RoomRow: View {
    let room: Room
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(room.name).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 2)
    }
    private var subtitle: String {
        guard let area = room.area else { return room.status.label }
        return "\(room.status.label) · \(area.formatted(.number.precision(.fractionLength(0...2)))) m²"
    }
}
