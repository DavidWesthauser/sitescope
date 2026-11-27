import SwiftUI

/// The app's view model: the state all screens show and the actions they trigger. It validates input, calls the
/// services and updates its state; how and where data is stored is up to the services.
@MainActor final class Store: ObservableObject {
    @Published var projects: [Project] = []
    @Published var rooms: [Room] = []
    @Published var annotations: [Annotation] = []
    @Published private(set) var members: [Membership] = []
    @Published private(set) var signedIn = false
    @Published var busy = false
    @Published var error: String?
    @Published private(set) var isLocalMode = false
    /// Set when on-device data exists but cannot be decoded. The file is left untouched until the user chooses to start fresh.
    @Published private(set) var unreadableLocalData: URL?

    /// Where data is stored. Nil only while nothing is configured or local data is unreadable.
    private(set) var repository: DataRepository?
    private var backend: Backend?
    private var sharing: ProjectSharing?
    private var transfer: ProjectTransferService?

    init() {
        do {
            connect(Backend(config: try .load()))
        } catch {
            #if DEBUG && os(iOS)
                /// UI tests pass a per-run folder name so each test starts with its own empty local store.
                let folder = ProcessInfo.processInfo.environment["SITESCOPE_LOCAL_DATA_DIR"]
                var directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("sitescope")
                if let folder {
                    directory =
                        folder.hasPrefix("/")
                        ? URL(fileURLWithPath: folder)
                        : FileManager.default.temporaryDirectory.appendingPathComponent(folder)
                }
                openLocal(at: directory.appendingPathComponent("local.json"))
            #else
                self.error = error.localizedDescription
            #endif
        }
    }
    /// Explicit local storage entry point; never changes cloud authentication or Keychain.
    init(localURL: URL) {
        openLocal(at: localURL)
    }
    init(backend: Backend) {
        connect(backend)
    }

    private func connect(_ backend: Backend) {
        let cloud = CloudRepository(backend: backend)
        self.backend = backend
        repository = cloud
        sharing = cloud
        signedIn = backend.user != nil
    }
    private func openLocal(at url: URL) {
        do {
            let local = try LocalDataStore(fileURL: url)
            // On-device data is always current: every saved change, also one the AR screen makes, is mirrored here.
            local.onChange = { [weak self] data in self?.show(data) }
            repository = LocalRepository(storage: local)
            transfer = ProjectTransferService(storage: local)
            isLocalMode = true
            signedIn = true
            show(local.data)
        } catch {
            unreadableLocalData = url
            self.error = "Could not open local data: \(error.localizedDescription)"
        }
    }
    private func show(_ data: LocalData) {
        projects = data.projects
        rooms = data.rooms
        annotations = data.annotations
    }

    var userID: UUID? { repository?.userID }
    var hasBackend: Bool { backend != nil }
    var accountEmail: String? { backend?.user?.email }

    /// Actions waiting for the one that is running.
    private var queuedOperations: [@MainActor () async throws -> Void] = []
    /// Runs user actions one at a time, in order. An action started while another runs waits for it instead of
    /// being dropped, so a Delete confirmed during a rename, or a rename typed during another save, still happens.
    /// `busy` stays true until the queue is empty; a failing action reports its error and the next one still runs.
    func run(_ operation: @escaping @MainActor () async throws -> Void) {
        queuedOperations.append(operation)
        guard !busy else { return }
        busy = true
        Task {
            // Main actor: nothing can enqueue between the last check of the loop and resetting `busy`.
            defer { busy = false }
            while !queuedOperations.isEmpty {
                let next = queuedOperations.removeFirst()
                do { try await next() } catch { self.error = error.localizedDescription }
            }
        }
    }
    /// The storage for screens that hand it to their own view model, such as the AR screen.
    func requireRepository() throws -> DataRepository {
        guard let repository else { throw AppError.message("Backend is not configured. See README.") }
        return repository
    }

    // MARK: Account

    /// Returns false when the account was created but still needs email confirmation.
    func signIn(email: String, password: String, register: Bool) async throws -> Bool {
        guard let backend else { throw AppError.message("Backend is not configured. See README.") }
        let active = try await backend.authenticate(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, register: register)
        signedIn = active
        return active
    }
    func signOut() async {
        await backend?.signOut()
        projects = []
        rooms = []
        annotations = []
        members = []
        signedIn = false
    }

    // MARK: Projects, rooms, tasks

    /// On-device data needs no loading: `openLocal` mirrors every saved change.
    func loadProjects() async throws {
        guard !isLocalMode else { return }
        projects = try await requireRepository().loadProjects()
    }
    func loadRooms(_ project: Project) async throws {
        guard !isLocalMode else { return }
        rooms = try await requireRepository().loadRooms(of: project)
    }
    func room(id: UUID) async throws -> Room {
        try await requireRepository().loadRoom(id: id)
    }
    func loadAnnotations(_ room: Room) async throws {
        guard !isLocalMode else { return }
        annotations = try await requireRepository().loadAnnotations(of: room)
    }

    func createProject(name value: String) async throws {
        guard let owner = userID else { throw AppError.message("Please sign in.") }
        try await requireRepository().createProject(Project(owner_id: owner, name: try DisplayName.validated(value)))
        try await loadProjects()
    }
    func renameProject(_ project: Project, name value: String) async throws {
        try await requireRepository().renameProject(project, to: try DisplayName.validated(value))
        try await loadProjects()
    }
    func deleteProject(_ project: Project) async throws {
        try await requireRepository().deleteProject(project)
        try await loadProjects()
    }
    func createRoom(in project: Project, name value: String) async throws {
        try await requireRepository().createRoom(Room(project_id: project.id, name: try DisplayName.validated(value)))
        try await loadRooms(project)
    }
    func renameRoom(_ room: Room, name value: String) async throws {
        try await requireRepository().renameRoom(room, to: try DisplayName.validated(value))
    }
    func deleteRoom(_ room: Room) async throws {
        try await requireRepository().deleteRoom(room)
    }
    func saveTask(_ item: Annotation, room: Room, manager: Bool) async throws {
        try await requireRepository().saveTask(item, in: room, asManager: manager)
        try await loadAnnotations(room)
    }
    func deleteTask(_ item: Annotation, room: Room) async throws {
        try await requireRepository().deleteTask(item)
        try await loadAnnotations(room)
    }
    func uploadAsset(path: String, data: Data, type: String) async throws {
        try await requireRepository().uploadAsset(path: path, data: data, type: type)
    }
    func saveInstruction(_ item: Annotation, room: Room, replacing: Bool) async throws {
        try await requireRepository().saveInstruction(item, in: room, replacing: replacing)
    }

    // MARK: Sharing (cloud only)

    private func requireSharing() throws -> ProjectSharing {
        guard let sharing else {
            throw AppError.message(
                isLocalMode
                    ? "Cloud sharing requires Supabase. Your room data is saved on this device."
                    : "Backend is not configured. See README.")
        }
        return sharing
    }
    func loadMembers(of project: Project) async throws {
        members = try await requireSharing().members(of: project)
    }
    func shareProject(_ project: Project, withEmail email: String) async throws {
        try await requireSharing().share(project, withEmail: email)
    }
    func revokeMember(_ member: Membership, from project: Project) async throws {
        try await requireSharing().revoke(member, from: project)
        try await loadMembers(of: project)
    }

    // MARK: Project files (on-device only)

    func exportProjectFile(_ project: Project) async throws -> URL {
        guard let transfer else {
            throw AppError.message(
                "Project files are available for projects saved on this device. Cloud projects use project sharing.")
        }
        return try await transfer.export(project)
    }
    /// Imports an independent copy; existing projects, identifiers and coordinate systems are never replaced.
    func importProjectFile(from source: URL) async throws -> Project {
        guard let transfer, let owner = userID else {
            throw AppError.message("Import a project file in on-device mode. Cloud projects use project sharing.")
        }
        return try await transfer.importProject(from: source, owner: owner)
    }

    // MARK: Recovery

    /// Moves the unreadable file aside (never deletes it) and opens an empty on-device store. Returns the backup location.
    @discardableResult func startFreshKeepingBackup() throws -> URL {
        guard let url = unreadableLocalData else { throw AppError.message("Local data is already readable.") }
        let backup = try LocalDataStore.moveAside(url)
        unreadableLocalData = nil
        error = nil
        openLocal(at: url)
        return backup
    }
}
