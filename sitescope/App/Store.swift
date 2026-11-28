import SwiftUI

/// The app's view model: the state all screens show and the actions they trigger. It validates input and calls the
/// services. Screens read the phone's copy only (T-008): it is shown at once and works offline, and the sync engine
/// keeps it in step with the server in the background. Sign-in is required.
@MainActor final class Store: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published var houses: [House] = []
    @Published var rooms: [Room] = []
    /// The drawings of every room on the phone; screens filter by room.
    @Published var annotations: [Annotation] = []
    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var organizations: [Organization] = []
    @Published private(set) var isAdmin = false
    @Published private(set) var signedIn = false
    @Published private(set) var isOnline = true
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSync: Date?
    /// Why part of the server could not be read in the last sync, if anything.
    @Published private(set) var syncProblem: String?
    @Published private(set) var notices: [SyncNotice] = []
    @Published private(set) var outbox: [OutboxItem] = []
    @Published private(set) var levels: [String: Int] = [:]
    @Published var busy = false
    @Published var error: String?

    private var backend: Backend?
    private var remote: RemoteStore?
    private(set) var repository: DataRepository?
    private var storage: LocalDataStore?
    private var engine: SyncEngine?
    private let connectivity = Connectivity()
    /// Where account folders live; tests pass their own.
    private let dataRoot: URL?

    init(dataRoot: URL? = nil) {
        self.dataRoot = dataRoot
        do {
            let backend = Backend(config: try .load())
            self.backend = backend
            remote = RemoteStore(backend: backend)
            if let user = backend.user { openAccount(user.id) }
        } catch {
            self.error = error.localizedDescription
        }
        connectivity.onChange = { [weak self] online in
            self?.isOnline = online
            if online { self?.syncSoon() }
        }
        connectivity.start()
    }
    /// For tests and previews: signed in on a local file, without a server.
    init(offlineFileURL: URL) {
        dataRoot = nil
        open(try? LocalDataStore(fileURL: offlineFileURL))
    }

    /// Opens the phone's storage of one account and starts syncing it.
    private func openAccount(_ user: UUID) {
        do {
            open(try LocalDataStore(fileURL: LocalDataStore.accountFile(for: user, in: dataRoot)))
        } catch {
            self.error = "This iPhone's copy could not be opened: \(error.localizedDescription)"
        }
        if let storage, let remote {
            let engine = SyncEngine(storage: storage, remote: remote)
            engine.onStateChange = { [weak self] in self?.showSyncState() }
            self.engine = engine
            (repository as? LocalRepository)?.fetchAsset = { [weak remote] path in
                guard let remote else { throw AppError.message("Not signed in.") }
                return try await remote.download(path: path)
            }
        }
        syncSoon()
    }
    private func open(_ storage: LocalDataStore?) {
        guard let storage else { return }
        self.storage = storage
        let repository = LocalRepository(storage: storage)
        repository.changed = { [weak self] in self?.syncSoon() }
        self.repository = repository
        storage.onChange = { [weak self] data in self?.show(data) }
        show(storage.data)
        signedIn = true
    }
    private func show(_ data: LocalData) {
        projects = data.projects.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        houses = data.houses.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        rooms = data.rooms.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        annotations = data.drawings
        profiles = data.profiles
        isAdmin = data.isAdmin
        notices = data.notices
        outbox = data.outbox
        levels = data.levels
        lastSync = data.lastSync
    }
    private func showSyncState() {
        isSyncing = engine?.isSyncing ?? false
        syncProblem = engine?.problem
        if engine?.isOffline == true { isOnline = false } else if connectivity.isOnline { isOnline = true }
    }

    var hasBackend: Bool { backend != nil }
    var accountEmail: String? { backend?.user?.email }
    var userID: UUID? { backend?.user?.id }
    var myProfile: Profile? { profiles.first { $0.user_id == userID } }
    func name(of person: UUID?) -> String {
        guard let person else { return "Nobody" }
        return profiles.first { $0.user_id == person }?.display_name ?? "Unknown person"
    }

    /// Actions waiting for the one that is running.
    private var queuedOperations: [@MainActor () async throws -> Void] = []
    /// Runs user actions one at a time, in order. An action started while another runs waits for it instead of
    /// being dropped. `busy` stays true until the queue is empty; a failing action reports its error and the next
    /// one still runs.
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
        guard let repository else { throw AppError.message("Please sign in.") }
        return repository
    }
    private func requireRemote() throws -> RemoteStore {
        guard let remote else {
            throw AppError.message("No server is configured. Add it to Secrets.xcconfig (docs/BACKEND_SETUP.md).")
        }
        guard isOnline else { throw AppError.message("You are offline. Sharing and rights need a connection.") }
        return remote
    }

    // MARK: Account

    /// Returns false when the account was created but still needs email confirmation.
    func signIn(email: String, password: String, register: Bool) async throws -> Bool {
        guard let backend else {
            throw AppError.message("No server is configured. Add it to Secrets.xcconfig (docs/BACKEND_SETUP.md).")
        }
        let active = try await backend.authenticate(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, register: register)
        if active, let user = backend.user { openAccount(user.id) }
        return active
    }
    /// Signs out. The account's copy and its waiting changes stay on the phone for the next sign-in.
    func signOut() async {
        await backend?.signOut()
        storage?.onChange = nil
        storage = nil
        repository = nil
        engine = nil
        show(LocalData())
        organizations = []
        signedIn = false
    }

    // MARK: Sync

    /// Starts a sync in the background; changes made meanwhile are picked up by a follow-up pass.
    func syncSoon() {
        guard let engine else { return }
        Task {
            await engine.sync()
            await refreshAccount()
        }
    }
    /// "Sync Now" in Settings: something the user asks for, so failed changes are tried again too.
    func syncNow() async {
        await engine?.retry()
        await refreshAccount()
    }
    /// Pull to refresh: waits for the sync, so the spinner shows how long it takes.
    func refresh() async {
        await engine?.sync()
        await refreshAccount()
    }
    func retry(_ key: RecordKey? = nil) async {
        await engine?.retry(key)
    }
    func dismissNotice(_ notice: SyncNotice) {
        Task { try? await storage?.change { $0.notices.removeAll { $0.id == notice.id } } }
    }
    func syncState(of key: RecordKey) -> ItemSyncState {
        guard let item = outbox.first(where: { $0.key == key }) else { return .synced }
        return item.lastError.map(ItemSyncState.failed) ?? .waiting
    }
    /// Changes the server refused, with a name for each (also for records deleted here) and the reason.
    var failedItems: [(key: RecordKey, name: String, reason: String)] {
        outbox.compactMap { item in
            guard let reason = item.lastError else { return nil }
            let kind =
                ["project": "Project", "house": "House", "room": "Room", "drawing": "Drawing"][
                    item.key.entity.rawValue] ?? "Item"
            let name =
                item.action == .delete
                ? "\(kind) deleted on this iPhone" : (storage?.data.name(of: item.key) ?? kind)
            return (item.key, name, reason)
        }
    }
    var waitingChanges: Int { outbox.count }
    var failedChanges: Int { outbox.filter { $0.lastError != nil }.count }

    /// Names, admin state and the level on every scope, cached so they work offline.
    private func refreshAccount() async {
        guard let remote, isOnline, let storage else { return }
        do {
            let people = try await remote.profiles()
            let admin = try await remote.isAdmin()
            var levels: [String: Int] = [:]
            for scope in allScopes() { levels[scope.cacheKey] = try await remote.level(on: scope).rawValue }
            let found = levels
            try await storage.change { data in
                data.profiles = people
                data.isAdmin = admin
                data.levels.merge(found) { _, new in new }
            }
        } catch {
            // Rights stay as last known; the next sync tries again.
        }
    }
    private func allScopes() -> [AccessScope] {
        var scopes = projects.map(AccessScope.project)
        for house in houses {
            guard let project = projects.first(where: { $0.id == house.project_id }) else { continue }
            scopes.append(.house(project, house))
        }
        for room in rooms {
            guard let project = projects.first(where: { $0.id == room.project_id }),
                let house = houses.first(where: { $0.id == room.house_id })
            else { continue }
            scopes.append(.room(project, house, room))
        }
        return scopes
    }

    // MARK: Rights (from the phone's cache; the server decides when changes upload)

    /// The caller's level on a scope. Something created on this phone that has not reached the server yet belongs
    /// to its creator, who is responsible for it.
    func level(on scope: AccessScope) -> AccessLevel {
        if let value = levels[scope.cacheKey] { return AccessLevel(serverValue: value) }
        let key: RecordKey
        switch scope {
        case .project(let project): key = RecordKey(.project, project.id)
        case .house(_, let house): key = RecordKey(.house, house.id)
        case .room(_, _, let room): key = RecordKey(.room, room.id)
        }
        return storage?.data.isOnServer(key) == false ? .responsible : .none
    }

    // MARK: Projects, houses, rooms

    func createProject(name value: String) async throws -> Project {
        let project = Project(name: try DisplayName.validated(value), responsible_id: userID)
        try await requireRepository().createProject(project)
        try await ownCreated(.project(project))
        return project
    }
    /// The creator is responsible for what they create (trigger `set_creator`), also before the server answers.
    private func ownCreated(_ scope: AccessScope) async throws {
        try await storage?.change { $0.levels[scope.cacheKey] = AccessLevel.responsible.rawValue }
    }
    func renameProject(_ project: Project, name value: String) async throws {
        try await requireRepository().renameProject(project, to: try DisplayName.validated(value))
    }
    func deleteProject(_ project: Project) async throws {
        try await requireRepository().deleteProject(project)
    }

    func createHouse(in project: Project, name value: String) async throws {
        let house = House(project_id: project.id, name: try DisplayName.validated(value), responsible_id: userID)
        try await requireRepository().createHouse(house)
        try await ownCreated(.house(project, house))
    }
    func renameHouse(_ house: House, name value: String) async throws {
        try await requireRepository().renameHouse(house, to: try DisplayName.validated(value))
    }
    func deleteHouse(_ house: House) async throws {
        try await requireRepository().deleteHouse(house)
    }

    func createRoom(in house: House, name value: String) async throws {
        var room = Room(project_id: house.project_id, house_id: house.id, name: try DisplayName.validated(value))
        room.responsible_id = userID
        try await requireRepository().createRoom(room)
        if let project = projects.first(where: { $0.id == house.project_id }) {
            try await ownCreated(.room(project, house, room))
        }
    }
    func renameRoom(_ room: Room, name value: String) async throws {
        try await requireRepository().renameRoom(room, to: try DisplayName.validated(value))
    }
    func describeRoom(_ room: Room, as text: String) async throws {
        try await requireRepository().describeRoom(room, as: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    func deleteRoom(_ room: Room) async throws {
        try await requireRepository().deleteRoom(room)
    }

    // MARK: Drawings (used by the AR screen)

    func loadAnnotations(_ room: Room) async throws {
        // The phone's copy is always current; nothing to load.
    }
    func saveDrawing(_ item: Annotation, room: Room) async throws {
        try await requireRepository().saveDrawing(item, in: room)
    }
    func deleteDrawing(_ item: Annotation) async throws {
        try await requireRepository().deleteDrawing(item)
    }
    func uploadAsset(path: String, data: Data, type: String) async throws {
        try await requireRepository().uploadAsset(path: path, data: data, type: type)
    }

    // MARK: Sharing and responsibility (need the network)

    func grants(on scope: AccessScope) async throws -> [AccessGrant] {
        try await requireRemote().grants(on: scope)
    }
    func grant(_ role: AccessRole, on scope: AccessScope, toEmail email: String) async throws {
        try await requireRemote().grant(role, on: scope, toEmail: email)
    }
    func revoke(_ grant: AccessGrant) async throws {
        try await requireRemote().revoke(grant)
    }
    func setResponsible(_ person: UUID, of scope: AccessScope) async throws {
        try await requireRemote().setResponsible(person, of: scope)
        await refresh()
    }
    func setDisplayName(_ value: String) async throws {
        guard let me = myProfile else { throw AppError.message("Your profile is not loaded yet.") }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...80).contains(text.count) else { throw AppError.message("Use a name between 1 and 80 characters.") }
        try await requireRemote().setDisplayName(text, of: me)
        await refreshAccount()
    }

    // MARK: Administration (admins only, need the network)

    func loadPeople() async throws {
        let remote = try requireRemote()
        let people = try await remote.profiles()
        organizations = try await remote.organizations()
        try await storage?.change { $0.profiles = people }
    }
    func setActive(_ active: Bool, of profile: Profile) async throws {
        guard profile.user_id != userID || active else {
            throw AppError.message("You cannot deactivate your own account.")
        }
        try await requireRemote().setActive(active, of: profile)
        try await loadPeople()
    }
    func setOrganization(_ organization: UUID?, of profile: Profile) async throws {
        try await requireRemote().setOrganization(organization, of: profile)
        try await loadPeople()
    }
    func saveOrganization(_ organization: Organization, isNew: Bool) async throws {
        var value = organization
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...160).contains(value.name.count) else {
            throw AppError.message("Use an organization name between 1 and 160 characters.")
        }
        try await requireRemote().saveOrganization(value, isNew: isNew)
        try await loadPeople()
    }
}
