import SwiftUI

/// The projects the signed-in user is part of. Empty until they create one or someone shares one with them.
/// The root of the navigation: project → house → room.
struct ProjectListView: View {
    @EnvironmentObject var store: Store
    @State private var path: [Route] = []
    @State private var query = ""
    @State private var creating = false
    @State private var renaming: Project?
    @State private var deleting: Project?

    private var shown: [Project] {
        query.isEmpty ? store.projects : store.projects.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                SyncNoticesSection()
                ForEach(shown) { project in
                    NavigationLink(value: Route.project(project.id)) {
                        RecordRow(
                            title: project.name, subtitle: "Responsible: \(store.name(of: project.responsible_id))",
                            systemImage: "building.2", state: store.syncState(of: RecordKey(.project, project.id)))
                    }
                    .contextMenu {
                        RetryMenuButton(key: RecordKey(.project, project.id))
                        actions(for: project)
                    }
                    .swipeActions {
                        if store.level(on: .project(project)).canManage {
                            Button("Delete", systemImage: "trash", role: .destructive) { deleting = project }
                        }
                    }
                    .retrySwipe(RecordKey(.project, project.id), store: store)
                }
            }
            .overlay {
                if store.projects.isEmpty {
                    ContentUnavailableView {
                        Label("No Projects", systemImage: "building.2")
                    } description: {
                        Text("Create a project, or wait until someone shares one with you.")
                    } actions: {
                        Button("New Project") { creating = true }.buttonStyle(.borderedProminent)
                    }
                } else if shown.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Projects")
            .searchable(text: $query, prompt: "Search Projects")
            .refreshable { await store.refresh() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }.accessibilityIdentifier("settings.open")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Project", systemImage: "plus") { creating = true }
                        .accessibilityIdentifier("projects.new")
                }
                ToolbarItem(placement: .status) { SyncStatusView() }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .project(let id): ProjectView(projectID: id)
                case .house(let id): HouseView(houseID: id)
                case .room(let id): RoomView(roomID: id)
                }
            }
            .namePrompt("New Project", placeholder: "Project Name", action: "Create", isPresented: $creating) { name in
                store.run {
                    // Like houses and rooms, the new project appears in the list; it does not open by itself.
                    _ = try await store.createProject(name: name)
                    query = ""
                }
            }
            .namePrompt(
                "Rename Project", placeholder: "Project Name", action: "Rename",
                isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }),
                initial: renaming?.name ?? ""
            ) { name in
                guard let project = renaming else { return }
                store.run { try await store.renameProject(project, name: name) }
            }
            .deleteConfirmation(
                deleting?.name ?? "",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                message: "This deletes the project with its houses, rooms, scans and drawings for everyone."
            ) {
                guard let project = deleting else { return }
                store.run { try await store.deleteProject(project) }
            }
        }
    }

    @ViewBuilder private func actions(for project: Project) -> some View {
        if store.level(on: .project(project)).canManage {
            Button("Rename", systemImage: "pencil") { renaming = project }
            Button("Delete", systemImage: "trash", role: .destructive) { deleting = project }
        }
    }
}
