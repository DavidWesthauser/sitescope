import XCTest

#if canImport(sitescopeCore)
    @testable import sitescopeCore
#else
    @testable import sitescope
#endif

@MainActor final class StoreTests: XCTestCase {
    static func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("data.json")
    }
    /// Without a server nobody can sign in, so the app shows only the sign-in screen with the reason.
    func testUnconfiguredStoreStaysSignedOutAndExplainsWhy() async throws {
        let store = Store()
        guard !store.hasBackend else { throw XCTSkip("A Secrets.xcconfig is configured on this machine.") }
        XCTAssertFalse(store.signedIn)
        XCTAssertTrue(store.error?.contains("Secrets.xcconfig") == true)
        do {
            _ = try await store.signIn(email: "a@b.test", password: "password", register: false)
            XCTFail("Expected an error without a server")
        } catch { XCTAssertFalse(store.signedIn) }
    }
    func testOperationFailureReleasesBusyAndPreservesData() async throws {
        let store = Store(offlineFileURL: Self.temporaryFile())
        let project = try await store.createProject(name: "Keep me")
        store.run { throw AppError.message("Network offline fixture") }
        XCTAssertTrue(store.busy)
        for _ in 0..<100 where store.busy { await Task.yield() }
        XCTAssertFalse(store.busy)
        XCTAssertEqual(store.projects.map(\.id), [project.id])
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

#if !canImport(sitescopeCore) && targetEnvironment(simulator)
    extension StoreTests {
        func testSavedShapesRenderCleanEdgesAndArrowHeadWithoutControlDots() throws {
            let room = Room(project_id: UUID(), house_id: UUID(), name: "Rendering fixture")
            let ar = ARController(room: room, mode: .walkthrough)
            ar.trackingNormal = true
            ar.localization.propose(.identity, method: .map)
            let points = [Point3(SIMD3<Float>(0, 0, 0)), Point3(SIMD3(1, 0, 0)), Point3(SIMD3(1, 1, 0))]
            let line = Annotation(
                room: room, kind: .line, pose: .identity, points: points)
            let area = Annotation(
                room: room, kind: .area, pose: .identity, points: points)
            let arrow = Annotation(
                room: room, kind: .arrow, pose: .identity, points: [points[0], points[2]])
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
