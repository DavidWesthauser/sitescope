import XCTest
#if canImport(sitescopeCore)
@testable import sitescopeCore
#else
@testable import sitescope
#endif

final class MapSaveTransactionTests: XCTestCase {
    func testSuccessfulLatePublicationRequiresRecoveryInsteadOfAnUnsavedRetry() throws {
        var transaction=MapSaveTransaction()
        let original=transaction.generation
        try transaction.validateCompletion(original)
        transaction.reset()
        XCTAssertThrowsError(try transaction.validate(original)) { error in
            guard case MapSaveTransaction.Failure.sessionChanged = error else { return XCTFail("Expected interrupted capture") }
        }
        XCTAssertThrowsError(try transaction.validateCompletion(original)) { error in
            guard case MapSaveTransaction.Failure.savedSessionChanged = error else { return XCTFail("Expected saved-room recovery") }
        }
    }
    private func room() -> Room {
        var room = Room(project_id: UUID(), name: "Kitchen")
        room.map_path = "project/room/immutable.worldmap"
        return room
    }

    func testResetRejectsLateCaptureAndPublicationWithoutPollutingCurrentSession() throws {
        var transaction = MapSaveTransaction()
        let previous = transaction.generation
        transaction.reset()
        XCTAssertNotEqual(transaction.generation, previous)
        XCTAssertThrowsError(try transaction.capture(Data([1]), generation: previous))
        XCTAssertThrowsError(try transaction.stage(room(), generation: previous))
        XCTAssertNil(transaction.data)
        XCTAssertNil(transaction.publication)

        let current = transaction.generation
        let bytes = Data([2, 3])
        try transaction.capture(bytes, generation: current)
        let publication = room()
        try transaction.stage(publication, generation: current)
        XCTAssertThrowsError(try transaction.capture(Data([9]), generation: previous))
        XCTAssertThrowsError(try transaction.stage(room(), generation: previous))
        XCTAssertEqual(transaction.data, bytes)
        XCTAssertEqual(transaction.publication, publication)
    }

    func testRetryRetainsExactSnapshotAndRoomCoordinateSystemWithinSession() throws {
        var transaction = MapSaveTransaction()
        let generation = transaction.generation
        let publication = room()
        let bytes = Data([0, 1, 255])
        try transaction.capture(bytes, generation: generation)
        try transaction.stage(publication, generation: generation)

        // A failed network request does not reset or mutate retry state.
        try transaction.validate(generation)
        XCTAssertEqual(transaction.data, bytes)
        XCTAssertEqual(transaction.publication, publication)
        XCTAssertEqual(transaction.publication?.coordinate_id, publication.coordinate_id)
        XCTAssertEqual(transaction.publication?.map_path, publication.map_path)
        try transaction.stage(publication, generation: generation)
        XCTAssertEqual(transaction.publication, publication)
    }

    func testResetClearsPartialUploadAndStagedPublication() throws {
        var transaction = MapSaveTransaction()
        try transaction.capture(Data([1]), generation: transaction.generation)
        transaction.reset()
        XCTAssertNil(transaction.data)
        XCTAssertNil(transaction.publication)
        try transaction.capture(Data([2]), generation: transaction.generation)
        try transaction.stage(room(), generation: transaction.generation)
        transaction.reset()
        XCTAssertNil(transaction.data)
        XCTAssertNil(transaction.publication)
    }

    func testStageRequiresSnapshotPathAndValidRoomWithoutReplacingPendingPublication() throws {
        var transaction = MapSaveTransaction()
        let generation = transaction.generation
        XCTAssertThrowsError(try transaction.stage(room(), generation: generation))
        try transaction.capture(Data([1]), generation: generation)
        var missingPath = room()
        missingPath.map_path = nil
        XCTAssertThrowsError(try transaction.stage(missingPath, generation: generation))
        XCTAssertNil(transaction.publication)
        let valid = room()
        try transaction.stage(valid, generation: generation)
        var invalid = room()
        invalid.spatial_version = 999
        XCTAssertThrowsError(try transaction.stage(invalid, generation: generation))
        XCTAssertEqual(transaction.publication, valid)
    }
}
