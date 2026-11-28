import SwiftUI

/// A project: its houses and who is responsible. Actions follow the caller's level (DATABASE_API.md): houses are
/// added, and the project renamed, shared or deleted, by its responsible person.
struct ProjectView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let projectID: UUID
    @State private var adding = false
    @State private var renaming = false
    @State private var deleting = false
    @State private var showingPeople = false
    @State private var renamingHouse: House?
    @State private var deletingHouse: House?

    var body: some View {
        if let project = store.projects.first(where: { $0.id == projectID }) {
            content(project)
        } else {
            ContentUnavailableView(
                "Project Not Available", systemImage: "building.2",
                description: Text("It was deleted, or it is no longer shared with you."))
        }
    }

    private func content(_ project: Project) -> some View {
        let level = store.level(on: .project(project))
        let houses = store.houses.filter { $0.project_id == project.id }
        return List {
            // Who is responsible sits first on every level, so it is in the same place everywhere.
            Section {
                ResponsibleRow(scope: .project(project), current: project.responsible_id, canChange: store.isAdmin)
            } footer: {
                Text(AccessLevelText.footer(level, scope: "project"))
            }
            Section {
                if houses.isEmpty {
                    ContentUnavailableView {
                        Label("No Houses", systemImage: "house")
                    } description: {
                        Text(
                            level.canManage
                                ? "Add the buildings of this project." : "No houses are shared with you yet.")
                    } actions: {
                        if level.canManage { Button("New House") { adding = true }.buttonStyle(.borderedProminent) }
                    }
                }
                ForEach(houses) { house in
                    NavigationLink(value: Route.house(house.id)) {
                        RecordRow(
                            title: house.name, subtitle: roomCount(house), systemImage: "house",
                            state: store.syncState(of: RecordKey(.house, house.id)))
                    }
                    .contextMenu {
                        RetryMenuButton(key: RecordKey(.house, house.id))
                        if store.level(on: .house(project, house)).canManage {
                            Button("Rename", systemImage: "pencil") { renamingHouse = house }
                            Button("Delete", systemImage: "trash", role: .destructive) { deletingHouse = house }
                        }
                    }
                    .swipeActions {
                        if store.level(on: .house(project, house)).canManage {
                            Button("Delete", systemImage: "trash", role: .destructive) { deletingHouse = house }
                        }
                    }
                    .retrySwipe(RecordKey(.house, house.id), store: store)
                }
            } header: {
                Text("Houses")
            }
        }
        .navigationTitle(project.name)
        .refreshable { await store.refresh() }
        .toolbar {
            if level.canManage {
                ToolbarItem(placement: .primaryAction) {
                    Button("New House", systemImage: "plus") { adding = true }.accessibilityIdentifier("houses.new")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("More", systemImage: "ellipsis.circle") {
                        RetryMenuButton(key: RecordKey(.project, project.id))
                        Button("Rename", systemImage: "pencil") { renaming = true }
                        Button("People", systemImage: "person.2") { showingPeople = true }
                            .disabled(!store.isOnline)
                        Divider()
                        Button("Delete Project", systemImage: "trash", role: .destructive) { deleting = true }
                    }.accessibilityIdentifier("project.more")
                }
            }
            ToolbarItem(placement: .status) { SyncStatusView() }
        }
        .navigationDestination(isPresented: $showingPeople) { AccessView(scope: .project(project)) }
        .namePrompt("New House", action: "Create", isPresented: $adding) { name in
            store.run { try await store.createHouse(in: project, name: name) }
        }
        .namePrompt("Rename Project", action: "Rename", isPresented: $renaming, initial: project.name) { name in
            store.run { try await store.renameProject(project, name: name) }
        }
        .namePrompt(
            "Rename House", action: "Rename",
            isPresented: Binding(get: { renamingHouse != nil }, set: { if !$0 { renamingHouse = nil } }),
            initial: renamingHouse?.name ?? ""
        ) { name in
            guard let house = renamingHouse else { return }
            store.run { try await store.renameHouse(house, name: name) }
        }
        .deleteConfirmation(
            project.name, isPresented: $deleting,
            message: "This deletes the project with its houses, rooms, scans and drawings for everyone."
        ) {
            store.run {
                try await store.deleteProject(project)
                dismiss()
            }
        }
        .deleteConfirmation(
            deletingHouse?.name ?? "",
            isPresented: Binding(get: { deletingHouse != nil }, set: { if !$0 { deletingHouse = nil } }),
            message: "This deletes the house with its rooms, scans and drawings for everyone."
        ) {
            guard let house = deletingHouse else { return }
            store.run { try await store.deleteHouse(house) }
        }
    }

    private func roomCount(_ house: House) -> String {
        let count = store.rooms.filter { $0.house_id == house.id }.count
        return count == 1 ? "1 room" : "\(count) rooms"
    }
}
