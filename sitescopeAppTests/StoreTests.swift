import XCTest

#if canImport(sitescopeCore)
    @testable import sitescopeCore
#else
    @testable import sitescope
#endif

@MainActor final class StoreTests: XCTestCase {
    func testUnconfiguredStoreReportsUsefulError() throws {
        let store = Store()
        // Config.xcconfig intentionally ships unconfigured. Run configured integration tests separately.
        if store.isLocalMode {
            XCTAssertTrue(store.signedIn)
            XCTAssertNil(store.error)
        } else if store.backend == nil {
            XCTAssertFalse(store.signedIn)
            XCTAssertTrue(store.error?.contains("Configure") == true)
            XCTAssertThrowsError(try store.client())
        }
    }
    func testOperationFailureReleasesBusyAndPreservesData() async {
        let store = Store()
        let project = Project(owner_id: UUID(), name: "Keep me")
        store.projects = [project]
        store.run { throw AppError.message("Network offline fixture") }
        XCTAssertTrue(store.busy)
        for _ in 0..<100 where store.busy { await Task.yield() }
        XCTAssertFalse(store.busy)
        XCTAssertEqual(store.projects, [project])
        XCTAssertEqual(store.error, "Network offline fixture")
    }
    func testActionStartedWhileBusyWaitsAndRuns() async {
        let store = Store()
        var order: [String] = []
        store.run {
            for _ in 0..<5 { await Task.yield() }  // Still running when the next action arrives.
            order.append("rename")
        }
        store.run { order.append("delete") }
        XCTAssertTrue(store.busy)
        for _ in 0..<200 where store.busy { await Task.yield() }
        XCTAssertFalse(store.busy)
        XCTAssertEqual(order, ["rename", "delete"], "The second action is queued, not dropped")
    }
    func testQueuedActionRunsAfterAFailure() async {
        let store = Store()
        var saved = false
        store.run { throw AppError.message("Save failed fixture") }
        store.run { saved = true }
        for _ in 0..<200 where store.busy { await Task.yield() }
        XCTAssertTrue(saved)
        XCTAssertEqual(store.error, "Save failed fixture")
    }
}

extension StoreTests {
    func testLocalStorageStartsEmptyAndPersistsRealRoomAssets() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("local.json")
        let store = Store(localURL: url)
        XCTAssertTrue(store.signedIn)
        XCTAssertTrue(store.isLocalMode)
        XCTAssertNil(store.backend)
        XCTAssertNil(store.error)
        XCTAssertThrowsError(try store.client())
        XCTAssertTrue(store.projects.isEmpty)
        XCTAssertTrue(store.rooms.isEmpty)
        XCTAssertTrue(store.annotations.isEmpty)
        try await store.createProject(name: "Test project")
        let project = try XCTUnwrap(store.projects.first)
        try await store.createRoom(in: project, name: "Test room")
        var room = try XCTUnwrap(store.rooms.first)
        let path = "\(project.id)/\(room.id)/fixture.worldmap"
        let fixture = Data("Archive fixture for storage test only, not an ARWorldMap".utf8)
        try await store.uploadAsset(path: path, data: fixture, type: "application/octet-stream")
        room.map_path = path
        try await store.publishRoom(room)
        var task = Annotation(
            room: room, kind: .line, pose: .identity, points: [Point3(.zero), Point3(SIMD3(0.5, 0, 0))],
            title: "Captured instruction fixture", detail: "Unit test only")
        try await store.saveInstruction(task, room: room, replacing: false)
        task.status = .completed
        try await store.saveTask(task, room: room, manager: true)
        let reopened = Store(localURL: url)
        XCTAssertEqual(reopened.rooms.first, room)
        XCTAssertEqual(reopened.annotations.first, task)
        let bytes = try await reopened.downloadAsset(path: path)
        XCTAssertEqual(bytes, fixture)
        var movedRoom = room
        movedRoom.map_path = "another.worldmap"
        do {
            try await reopened.publishRoom(movedRoom)
            XCTFail("Should reject replacing a published map")
        } catch {}
    }
    func testSavedScanGuidePersistsAndCannotBeChangedWithPublishedMap() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("local.json")
        let store = Store(localURL: url)
        try await store.createProject(name: "Guide persistence fixture")
        let project = try XCTUnwrap(store.projects.first)
        try await store.createRoom(in: project, name: "Room")
        var room = try XCTUnwrap(store.rooms.first)
        // Framed JPEG byte stub and synthetic map bytes are test fixtures, not camera assets.
        room.scan_guide_jpeg = Data([0xff, 0xd8, 0x11, 0xff, 0xd9]).base64EncodedString()
        room.map_path = "\(project.id)/\(room.id)/test.worldmap"
        try await store.uploadAsset(path: room.map_path!, data: Data([1, 2, 3]), type: "application/octet-stream")
        try await store.publishRoom(room)
        let reopened = Store(localURL: url)
        XCTAssertEqual(reopened.rooms.first, room)
        XCTAssertEqual(reopened.rooms.first?.coordinate_id, room.coordinate_id)
        for guide in [nil, Data([0xff, 0xd8, 0x22, 0xff, 0xd9]).base64EncodedString()] as [String?] {
            var changed = room
            changed.scan_guide_jpeg = guide
            do {
                try await reopened.publishRoom(changed)
                XCTFail("Published guide must remain bound to its map")
            } catch {}
            XCTAssertEqual(reopened.rooms.first, room)
        }
        var renamed = room
        renamed.name = "Renamed room"
        try await reopened.publishRoom(renamed)
        XCTAssertEqual(Store(localURL: url).rooms.first, renamed)
    }
    func testLocalProjectAndRoomCRUDPersistsAndCascadesOnlyOwnedRecords() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("local.json")
        let store = Store(localURL: url)
        let originalProjects = store.projects
        let originalRooms = store.rooms
        let originalTasks = store.annotations
        try await store.createProject(name: "  My site  ")
        let project = try XCTUnwrap(store.projects.first(where: { $0.name == "My site" }))
        try await store.renameProject(project, name: "Renamed site")
        try await store.createRoom(in: project, name: "Office")
        let room = try XCTUnwrap(store.rooms.first(where: { $0.project_id == project.id }))
        try await store.renameRoom(room, name: "New office")
        let reopened = Store(localURL: url)
        let loaded = try await reopened.room(id: room.id)
        XCTAssertEqual(loaded.name, "New office")
        XCTAssertEqual(reopened.projects.first(where: { $0.id == project.id })?.name, "Renamed site")
        try await reopened.deleteRoom(room)
        XCTAssertFalse(reopened.rooms.contains(where: { $0.id == room.id }))
        try await reopened.createRoom(in: project, name: "Another room")
        try await reopened.deleteProject(project)
        let final = Store(localURL: url)
        XCTAssertEqual(final.projects, originalProjects)
        XCTAssertEqual(final.rooms, originalRooms)
        XCTAssertEqual(final.annotations, originalTasks)
    }
    func testConcurrentLocalChangesAreAllPersisted() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("local.json")
        let store = Store(localURL: url)
        async let a: Void = store.createProject(name: "A")
        async let b: Void = store.createProject(name: "B")
        async let c: Void = store.createProject(name: "C")
        _ = try await (a, b, c)
        XCTAssertEqual(Set(store.projects.map(\.name)), ["A", "B", "C"])  // Queued writes; none overwrites another.
        XCTAssertEqual(Set(Store(localURL: url).projects.map(\.name)), ["A", "B", "C"])
    }
    /// A `local.json` written before T-027: rooms with marker fields and text, arrow and marker notes.
    func testLocalFileFromBeforeCleanupStillOpens() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let project = UUID()
        let room = UUID()
        let coordinate = UUID()
        let pose = Pose.identity.elements
        let old: [String: Any] = [
            "projects": [["id": project.uuidString, "owner_id": UUID().uuidString, "name": "Old site"]],
            "rooms": [
                [
                    "id": room.uuidString, "project_id": project.uuidString, "name": "Kitchen", "spatial_version": 1,
                    "coordinate_id": coordinate.uuidString, "map_path": "\(project)/\(room)/old.worldmap",
                    "marker": [
                        "id": UUID().uuidString, "image_path": "\(project)/\(room)/marker.png", "width": 0.2,
                        "height": 0.2, "room_from_marker": pose,
                    ],
                    "reference_points": [["x": 0, "y": 0, "z": 0], ["x": 1, "y": 0, "z": 0]],
                    "reference_notes": "Two corners",
                ]
            ],
            "annotations": [("text", 0), ("arrow", 2), ("marker", 0)].map { kind, points in
                [
                    "id": UUID().uuidString, "room_id": room.uuidString, "coordinate_id": coordinate.uuidString,
                    "kind": kind, "pose": pose, "points": (0..<points).map { ["x": Float($0), "y": 0, "z": 0] },
                    "title": "Old \(kind) note", "detail": "", "status": "todo", "priority": 1,
                ] as [String: Any]
            },
        ]
        let url = directory.appendingPathComponent("local.json")
        try JSONSerialization.data(withJSONObject: old).write(to: url)
        let store = Store(localURL: url)
        XCTAssertNil(store.unreadableLocalData)
        XCTAssertEqual(store.rooms.map(\.id), [room])
        XCTAssertEqual(store.annotations.map(\.kind), [.text, .arrow, .marker])
        for annotation in store.annotations { XCTAssertNoThrow(try annotation.validate(room: store.rooms[0])) }
    }
    func testCorruptLocalDataIsReportedWithoutDiscardingFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("local.json")
        let bytes = Data("corrupt fixture".utf8)
        try bytes.write(to: url)
        let store = Store(localURL: url)
        XCTAssertFalse(store.signedIn)
        XCTAssertFalse(store.isLocalMode)
        XCTAssertNotNil(store.error)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
        XCTAssertEqual(store.unreadableLocalData, url)
        let backup = try store.startFreshKeepingBackup()
        XCTAssertEqual(try Data(contentsOf: backup), bytes)  // Moved aside, never discarded.
        XCTAssertTrue(store.isLocalMode)
        XCTAssertTrue(store.signedIn)
        XCTAssertNil(store.unreadableLocalData)
        XCTAssertNil(store.error)
        XCTAssertTrue(store.projects.isEmpty)
        try await store.createProject(name: "After recovery")
        XCTAssertEqual(Store(localURL: url).projects.map(\.name), ["After recovery"])
    }
}

#if !canImport(sitescopeCore) && targetEnvironment(simulator)
    extension StoreTests {
        func testSavedShapesRenderCleanEdgesAndArrowHeadWithoutControlDots() throws {
            let room = Room(project_id: UUID(), name: "Rendering fixture")
            let ar = ARController(room: room, mode: .walkthrough)
            ar.trackingNormal = true
            ar.localization.propose(.identity)
            let points = [Point3(SIMD3<Float>(0, 0, 0)), Point3(SIMD3(1, 0, 0)), Point3(SIMD3(1, 1, 0))]
            let line = Annotation(
                room: room, kind: .line, pose: .identity, points: points, title: "Drawing", detail: "")
            let area = Annotation(
                room: room, kind: .area, pose: .identity, points: points, title: "Area marking", detail: "")
            let arrow = Annotation(
                room: room, kind: .arrow, pose: .identity, points: [points[0], points[2]], title: "Drawing", detail: "")
            ar.annotations = [line, area, arrow]
            ar.confirm()
            let roots = ar.view.scene.anchors.flatMap { Array($0.children) }
            XCTAssertEqual(roots.first(where: { $0.name == line.id.uuidString })?.children.count, 1)
            XCTAssertEqual(roots.first(where: { $0.name == area.id.uuidString })?.children.count, 3)
            XCTAssertEqual(roots.first(where: { $0.name == arrow.id.uuidString })?.children.count, 2)
            XCTAssertFalse(ar.showSurfaceGuides)
            ar.stop()
        }
    }
#endif
