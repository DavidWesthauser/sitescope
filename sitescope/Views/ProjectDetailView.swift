import SwiftUI

/// Project screen: name, houses, who is responsible, access and, kept apart in the last section, deleting.
/// Controls follow the caller's level on the project (docs/DATABASE_API.md, "Permissions").
struct ProjectDetail: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let project: Project
    @State private var level = AccessLevel.none
    @State private var nameDraft: String
    @State private var houseName = ""
    @State private var addHouse = false
    @State private var deleting = false
    /// Set once the delete succeeded, so the name field's save on disappear does not touch the deleted project.
    @State private var deleted = false
    /// The store's copy, so a rename shows immediately without leaving the screen.
    private var current: Project { store.projects.first(where: { $0.id == project.id }) ?? project }

    init(project: Project) {
        self.project = project
        _nameDraft = State(initialValue: project.name)
    }

    var body: some View {
        List {
            if level.canManage {
                NameSection(
                    placeholder: "Project name", stored: current.name, identifier: "project.name", draft: $nameDraft,
                    save: rename)
            }
            Section("Houses") {
                let houses = store.houses.filter { $0.project_id == project.id }
                if houses.isEmpty {
                    Label(
                        level.canManage ? "Add a house to start adding rooms" : "No houses you can see",
                        systemImage: "house"
                    ).foregroundStyle(.secondary)
                }
                ForEach(houses) { house in
                    NavigationLink {
                        HouseDetail(project: current, house: house)
                    } label: {
                        Label(house.name, systemImage: "house")
                    }
                }
                if level.canManage {
                    Button("Add house", systemImage: "plus") {
                        houseName = ""
                        addHouse = true
                    }.accessibilityIdentifier("houses.new")
                }
            }
            ResponsibleSection(
                scope: .project(current), current: current.responsible_id, canChange: store.isAdmin,
                changed: { try await store.loadProjects() })
            if level.canManage {
                Section {
                    NavigationLink {
                        AccessView(scope: .project(current))
                    } label: {
                        Label("Manage access", systemImage: "person.2")
                    }.accessibilityIdentifier("project.access")
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
                                "This deletes the project with all its houses, rooms and comments. This can’t be undone."
                            )
                        }
                } footer: {
                    Text("Removes the project for everyone with access.")
                }
            }
            AccessLevelFooter(level: level)
        }
        .navigationTitle(level.canManage ? nameDraft.titleOrFallback("Untitled Project") : current.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await reload() }
        .alert("Add house", isPresented: $addHouse) {
            TextField("House name", text: $houseName)
            Button("Add") {
                store.run { try await store.createHouse(in: project, name: houseName) }
            }.disabled(DisplayName.normalized(houseName) == nil || store.busy)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var projectExists: Bool { !deleted && store.projects.contains(where: { $0.id == project.id }) }

    private func reload() async {
        do {
            level = try await store.level(on: .project(current))
            try await store.loadHouses(project)
        } catch { store.error = error.localizedDescription }
    }

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
