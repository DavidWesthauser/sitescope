import SwiftUI

/// The app's view model: the state all screens show and the actions they trigger. It validates input, calls the
/// services and updates its state; storage and rights live on the server (docs/DATABASE_API.md).
/// The app is only usable while signed in.
@MainActor final class Store: ObservableObject {
    @Published var projects: [Project] = []
    @Published var houses: [House] = []
    @Published var rooms: [Room] = []
    @Published var annotations: [Annotation] = []
    /// Every profile; signed-in users may read names and organizations of all people.
    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var organizations: [Organization] = []
    @Published private(set) var isAdmin = false
    @Published private(set) var signedIn = false
    @Published var busy = false
    @Published var error: String?

    private(set) var repository: DataRepository?
    private var access: AccessManagement?
    private var backend: Backend?

    init() {
        do {
            connect(Backend(config: try .load()))
        } catch {
            self.error = error.localizedDescription
        }
    }
    init(backend: Backend) {
        connect(backend)
    }
    /// For tests: a signed-in store on any storage, without account management.
    init(repository: DataRepository) {
        self.repository = repository
        signedIn = true
    }
    private func connect(_ backend: Backend) {
        let cloud = CloudRepository(backend: backend)
        self.backend = backend
        repository = cloud
        access = cloud
        signedIn = backend.user != nil
    }

    var userID: UUID? { repository?.userID }
    var hasBackend: Bool { backend != nil }
    var accountEmail: String? { backend?.user?.email }
    var myProfile: Profile? { profiles.first { $0.user_id == userID } }
    func name(of person: UUID?) -> String {
        guard let person else { return "Nobody" }
        return profiles.first { $0.user_id == person }?.display_name ?? "Unknown person"
    }

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
        guard let repository else { throw Self.notConfigured }
        return repository
    }
    private func requireAccess() throws -> AccessManagement {
        guard let access else { throw Self.notConfigured }
        return access
    }
    private static let notConfigured = AppError.message(
        "No server is configured. Add the Supabase URL and publishable key to Secrets.xcconfig (docs/BACKEND_SETUP.md)."
    )

    // MARK: Account

    /// Returns false when the account was created but still needs email confirmation.
    func signIn(email: String, password: String, register: Bool) async throws -> Bool {
        guard let backend else { throw Self.notConfigured }
        let active = try await backend.authenticate(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, register: register)
        signedIn = active
        return active
    }
    func signOut() async {
        await backend?.signOut()
        projects = []
        houses = []
        rooms = []
        annotations = []
        profiles = []
        organizations = []
        isAdmin = false
        signedIn = false
    }
    /// Names of all people and whether the user is an admin; screens ask for their own scope's level.
    func loadAccount() async throws {
        let access = try requireAccess()
        profiles = try await access.profiles()
        isAdmin = try await access.isAdmin()
    }
    func setDisplayName(_ value: String) async throws {
        guard let me = myProfile else { throw AppError.message("Your profile could not be loaded.") }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...80).contains(text.count) else { throw AppError.message("Use a name between 1 and 80 characters.") }
        try await requireAccess().setDisplayName(text, of: me)
        profiles = try await requireAccess().profiles()
    }

    // MARK: Projects, houses, rooms

    func loadProjects() async throws {
        projects = try await requireRepository().loadProjects()
    }
    func loadHouses(_ project: Project) async throws {
        houses = try await requireRepository().loadHouses(of: project)
    }
    func loadRooms(_ house: House) async throws {
        rooms = try await requireRepository().loadRooms(of: house)
    }
    func room(id: UUID) async throws -> Room {
        try await requireRepository().loadRoom(id: id)
    }
    func loadAnnotations(_ room: Room) async throws {
        annotations = try await requireRepository().loadAnnotations(of: room)
    }

    func createProject(name value: String) async throws {
        try await requireRepository().createProject(Project(name: try DisplayName.validated(value)))
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

    func createHouse(in project: Project, name value: String) async throws {
        try await requireRepository().createHouse(House(project_id: project.id, name: try DisplayName.validated(value)))
        try await loadHouses(project)
    }
    func renameHouse(_ house: House, name value: String) async throws {
        try await requireRepository().renameHouse(house, to: try DisplayName.validated(value))
        houses = try await requireRepository().loadHouses(of: Project(id: house.project_id, name: ""))
    }
    func deleteHouse(_ house: House) async throws {
        try await requireRepository().deleteHouse(house)
        houses.removeAll { $0.id == house.id }
    }

    func createRoom(in house: House, name value: String) async throws {
        let room = Room(project_id: house.project_id, house_id: house.id, name: try DisplayName.validated(value))
        try await requireRepository().createRoom(room)
        try await loadRooms(house)
    }
    func renameRoom(_ room: Room, name value: String) async throws {
        try await requireRepository().renameRoom(room, to: try DisplayName.validated(value))
    }
    /// Dimensions are metres with at most 4 digits before the point (`numeric(6,2)`); empty means unknown.
    func updateRoomDetails(_ room: Room) async throws {
        for value in [room.height, room.length, room.width].compactMap({ $0 }) {
            guard value > 0, value < 10_000 else {
                throw AppError.message("Use positive dimensions in metres, below 10,000.")
            }
        }
        try await requireRepository().updateRoomDetails(room)
    }
    func deleteRoom(_ room: Room) async throws {
        try await requireRepository().deleteRoom(room)
        rooms.removeAll { $0.id == room.id }
    }

    // MARK: AR data (kept for the AR screens; the server has no tables for it yet, T-029)

    func saveTask(_ item: Annotation, room: Room, manager: Bool) async throws {
        try await requireRepository().saveTask(item, in: room, canEdit: manager)
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

    // MARK: Rights

    func level(on scope: AccessScope) async throws -> AccessLevel {
        try await requireAccess().level(on: scope)
    }
    func grants(on scope: AccessScope) async throws -> [AccessGrant] {
        try await requireAccess().grants(on: scope)
    }
    func grant(_ role: AccessRole, on scope: AccessScope, toEmail email: String) async throws {
        try await requireAccess().grant(role, on: scope, toEmail: email)
    }
    func revoke(_ grant: AccessGrant) async throws {
        try await requireAccess().revoke(grant)
    }
    func setResponsible(_ person: UUID, of scope: AccessScope) async throws {
        try await requireAccess().setResponsible(person, of: scope)
    }

    // MARK: Administration

    func loadPeople() async throws {
        profiles = try await requireAccess().profiles()
        organizations = try await requireAccess().organizations()
    }
    func setActive(_ active: Bool, of profile: Profile) async throws {
        guard profile.user_id != userID || active else {
            throw AppError.message("You cannot deactivate your own account.")
        }
        try await requireAccess().setActive(active, of: profile)
        try await loadPeople()
    }
    func setOrganization(_ organization: UUID?, of profile: Profile) async throws {
        try await requireAccess().setOrganization(organization, of: profile)
        try await loadPeople()
    }
    func saveOrganization(_ organization: Organization, isNew: Bool) async throws {
        var value = organization
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...160).contains(value.name.count) else {
            throw AppError.message("Use an organization name between 1 and 160 characters.")
        }
        try await requireAccess().saveOrganization(value, isNew: isNew)
        try await loadPeople()
    }
}
