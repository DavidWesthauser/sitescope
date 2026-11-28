import XCTest

#if canImport(sitescopeCore)
    @testable import sitescopeCore
#else
    @testable import sitescope
#endif

/// A server like the database target of T-029: rows have a revision that rises on every write, and writes only go
/// through when they name the current revision.
@MainActor final class FakeServer: RemoteSyncing {
    var rows: [RecordKey: JSONObject] = [:]
    var files: [String: Data] = [:]
    var offline = false
    /// Tables whose writes the server refuses (as RLS would).
    var refused: Set<SyncEntity> = []
    private(set) var inserts: [SyncEntity] = []

    private func checkOnline() throws { if offline { throw URLError(.notConnectedToInternet) } }
    func fetchAll(_ entity: SyncEntity) async throws -> [JSONObject] {
        try checkOnline()
        return rows.filter { $0.key.entity == entity }.map(\.value)
    }
    func fetch(_ key: RecordKey) async throws -> JSONObject? {
        try checkOnline()
        return rows[key]
    }
    func insert(_ entity: SyncEntity, _ fields: JSONObject) async throws -> JSONObject {
        try checkOnline()
        guard !refused.contains(entity) else { throw HTTPFailure(status: 403, message: "Not allowed.") }
        guard case .string(let text)? = fields["id"], let id = UUID(uuidString: text) else {
            throw HTTPFailure(status: 400, message: "No id.")
        }
        let key = RecordKey(entity, id)
        guard rows[key] == nil else { throw HTTPFailure(status: 409, message: "Duplicate key.") }
        var row = fields
        row["revision"] = .number(1)
        rows[key] = row
        inserts.append(entity)
        return row
    }
    func update(_ key: RecordKey, revision: Int, _ fields: JSONObject) async throws -> JSONObject? {
        try checkOnline()
        guard !refused.contains(key.entity) else { throw HTTPFailure(status: 403, message: "Not allowed.") }
        guard var row = rows[key], row["revision"]?.integer == revision else { return nil }
        row.merge(fields) { _, new in new }
        row["revision"] = .number(Double(revision + 1))
        rows[key] = row
        return row
    }
    func delete(_ key: RecordKey, revision: Int) async throws -> Bool {
        try checkOnline()
        guard rows[key]?["revision"]?.integer == revision else { return false }
        rows[key] = nil
        return true
    }
    func upload(path: String, data: Data, type: String) async throws {
        try checkOnline()
        files[path] = data
    }
    func download(path: String) async throws -> Data {
        try checkOnline()
        guard let data = files[path] else { throw HTTPFailure(status: 404, message: "Not found.") }
        return data
    }

    /// Another phone changes a row: its revision rises.
    func editElsewhere(_ key: RecordKey, _ fields: JSONObject) {
        guard var row = rows[key] else { return }
        row.merge(fields) { _, new in new }
        row["revision"] = .number(Double((row["revision"]?.integer ?? 0) + 1))
        rows[key] = row
    }
}

/// The rules of T-008: offline queue, order, relaunch, per-field merge, last change wins, edit beats delete,
/// a published scan is never overwritten, refused changes can be retried, accounts stay apart.
@MainActor final class SyncTests: XCTestCase {
    private var file: URL!
    private var server: FakeServer!

    override func setUp() async throws {
        file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("data.json")
        server = FakeServer()
    }

    private func phone() throws -> (LocalDataStore, LocalRepository, SyncEngine) {
        let storage = try LocalDataStore(fileURL: file)
        return (storage, LocalRepository(storage: storage), SyncEngine(storage: storage, remote: server))
    }
    /// A project → house → room that is already on the server.
    private func syncedRoom() async throws -> (LocalDataStore, LocalRepository, SyncEngine, Room) {
        let (storage, repository, engine) = try phone()
        let project = Project(name: "Site")
        let house = House(project_id: project.id, name: "House")
        let room = Room(project_id: project.id, house_id: house.id, name: "Kitchen")
        try await repository.createProject(project)
        try await repository.createHouse(house)
        try await repository.createRoom(room)
        await engine.sync()
        XCTAssertTrue(storage.data.outbox.isEmpty)
        return (storage, repository, engine, room)
    }
    private func current(_ room: Room, in storage: LocalDataStore) throws -> Room {
        try XCTUnwrap(storage.data.rooms.first { $0.id == room.id })
    }

    func testOfflineChangesWaitSurviveRelaunchAndUploadParentsFirst() async throws {
        server.offline = true
        do {
            let (storage, repository, engine) = try phone()
            let project = Project(name: "Site")
            let house = House(project_id: project.id, name: "House")
            try await repository.createRoom(Room(project_id: project.id, house_id: house.id, name: "Kitchen"))
            try await repository.createHouse(house)
            try await repository.createProject(project)
            await engine.sync()
            XCTAssertTrue(engine.isOffline)
            XCTAssertEqual(storage.data.outbox.count, 3, "Nothing is lost or blocked while offline")
        }
        // The app was killed; a new launch reads the same file.
        server.offline = false
        let (storage, _, engine) = try phone()
        XCTAssertEqual(storage.data.outbox.count, 3)
        await engine.sync()
        XCTAssertEqual(server.inserts, [.project, .house, .room], "Parents reach the server before their children")
        XCTAssertTrue(storage.data.outbox.isEmpty)
    }

    func testDeletingSomethingThatNeverUploadedLeavesNothingToSend() async throws {
        server.offline = true
        let (storage, repository, _) = try phone()
        let project = Project(name: "Draft")
        try await repository.createProject(project)
        try await repository.deleteProject(project)
        XCTAssertTrue(storage.data.outbox.isEmpty)
    }

    func testDifferentFieldsChangedOnBothSidesAreBothKept() async throws {
        let (storage, repository, engine, room) = try await syncedRoom()
        server.editElsewhere(RecordKey(.room, room.id), ["name": .string("Kitchen East")])
        try await repository.describeRoom(room, as: "Tiles first")
        await engine.sync()
        let row = try XCTUnwrap(server.rows[RecordKey(.room, room.id)])
        XCTAssertEqual(row["name"], .string("Kitchen East"))
        XCTAssertEqual(row["description"], .string("Tiles first"))
        XCTAssertEqual(try current(room, in: storage).name, "Kitchen East")
        XCTAssertTrue(storage.data.notices.isEmpty, "Nothing was overwritten, so nothing to report")
    }

    func testSameFieldChangedOnBothSidesLastChangeWinsAndIsReported() async throws {
        let (storage, repository, engine, room) = try await syncedRoom()
        server.editElsewhere(RecordKey(.room, room.id), ["name": .string("Theirs")])
        try await repository.renameRoom(room, to: "Mine")
        await engine.sync()
        XCTAssertEqual(server.rows[RecordKey(.room, room.id)]?["name"], .string("Mine"))
        XCTAssertEqual(storage.data.notices.count, 1, "The overwritten change is never dropped silently")
    }

    func testEditWinsOverDeleteOnAnotherDevice() async throws {
        let (storage, repository, engine, room) = try await syncedRoom()
        server.rows[RecordKey(.room, room.id)] = nil
        try await repository.describeRoom(room, as: "Still needed")
        await engine.sync()
        XCTAssertEqual(server.rows[RecordKey(.room, room.id)]?["description"], .string("Still needed"))
        XCTAssertEqual(storage.data.notices.count, 1)
    }

    func testDeleteOfARecordEditedElsewhereIsUndone() async throws {
        let (storage, repository, engine, room) = try await syncedRoom()
        server.editElsewhere(RecordKey(.room, room.id), ["name": .string("Renamed elsewhere")])
        try await repository.deleteRoom(room)
        await engine.sync()
        XCTAssertNotNil(server.rows[RecordKey(.room, room.id)])
        XCTAssertEqual(try current(room, in: storage).name, "Renamed elsewhere", "The edit wins over the delete")
        XCTAssertEqual(storage.data.notices.count, 1)
    }

    func testServerScanStaysAndThePhonesScanBecomesANewRoomWithItsDrawings() async throws {
        let (storage, repository, engine, room) = try await syncedRoom()
        let key = RecordKey(.room, room.id)
        server.editElsewhere(key, ["map_path": .string("elsewhere.worldmap")])
        var scanned = room
        scanned.map_path = "\(room.project_id.uuidString.lowercased())/\(room.id.uuidString.lowercased())/mine.worldmap"
        try await repository.uploadAsset(
            path: scanned.map_path!, data: Data([1, 2, 3]), type: "application/octet-stream")
        try await repository.publishRoom(scanned)
        let drawing = Annotation(
            room: scanned, kind: .line, pose: .identity, points: [Point3(.zero), Point3(SIMD3(1, 0, 0))])
        try await repository.saveDrawing(drawing, in: scanned)
        await engine.sync()

        XCTAssertEqual(server.rows[key]?["map_path"], .string("elsewhere.worldmap"), "The server's scan stays")
        XCTAssertEqual(try current(room, in: storage).map_path, "elsewhere.worldmap")
        let copy = try XCTUnwrap(storage.data.rooms.first { $0.name == "Kitchen (new scan)" })
        XCTAssertEqual(
            copy.coordinate_id, scanned.coordinate_id, "Drawings keep the coordinate system they were placed in")
        XCTAssertNotNil(server.rows[RecordKey(.room, copy.id)], "The phone's scan reached the server as a new room")
        XCTAssertEqual(storage.data.drawings.first { $0.id == drawing.id }?.room_id, copy.id)
        XCTAssertNotNil(copy.map_path.flatMap { server.files[$0] }, "The scan file went up for the new room")
        XCTAssertEqual(storage.data.notices.count, 1)
    }

    func testRefusedChangeIsMarkedFailedUntilRetried() async throws {
        let (storage, repository, engine) = try phone()
        server.refused = [.project]
        let project = Project(name: "Site")
        try await repository.createProject(project)
        await engine.sync()
        XCTAssertEqual(storage.data.outbox.first?.lastError, "Not allowed.")
        await engine.sync()
        XCTAssertEqual(storage.data.outbox.first?.failures, 1, "A failed change is not retried on its own")
        server.refused = []
        await engine.retry(RecordKey(.project, project.id))
        XCTAssertTrue(storage.data.outbox.isEmpty)
        XCTAssertNotNil(server.rows[RecordKey(.project, project.id)])
    }

    func testChangesMadeElsewhereArriveAndRemovedRecordsDisappear() async throws {
        let (storage, _, engine, room) = try await syncedRoom()
        server.editElsewhere(RecordKey(.room, room.id), ["description": .string("From the other phone")])
        await engine.sync()
        XCTAssertEqual(try current(room, in: storage).description, "From the other phone")
        server.rows[RecordKey(.room, room.id)] = nil
        await engine.sync()
        XCTAssertNil(storage.data.rooms.first { $0.id == room.id })
    }

    func testEachAccountHasItsOwnCopy() async throws {
        let root = file.deletingLastPathComponent()
        let first = LocalDataStore.accountFile(for: UUID(), in: root)
        let second = LocalDataStore.accountFile(for: UUID(), in: root)
        XCTAssertNotEqual(first, second)
        let repository = LocalRepository(storage: try LocalDataStore(fileURL: first))
        try await repository.createProject(Project(name: "Only mine"))
        XCTAssertTrue(try LocalDataStore(fileURL: second).data.projects.isEmpty)
    }
}
