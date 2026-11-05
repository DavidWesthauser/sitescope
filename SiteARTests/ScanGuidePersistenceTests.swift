import XCTest
import Foundation
#if canImport(sitescopeCore)
@testable import sitescopeCore
#else
@testable import sitescope
#endif

final class ScanGuidePersistenceTests: XCTestCase {
    // JPEG framing stubs exercise metadata validation only; these are not decoded scene photos.
    private let guide = Data([0xff,0xd8,0x11,0xff,0xd9]).base64EncodedString()
    private let otherGuide = Data([0xff,0xd8,0x22,0xff,0xd9]).base64EncodedString()

    func testLegacyRoomDecodesWithoutGuideAndGuideRoundTripsWithCoordinates() throws {
        var room = Room(project_id: UUID(), name: "Legacy room")
        let oldData = try JSONEncoder().encode(room)
        let oldObject = try XCTUnwrap(JSONSerialization.jsonObject(with: oldData) as? [String: Any])
        XCTAssertNil(oldObject["scan_guide_jpeg"])
        let oldRoom = try JSONDecoder().decode(Room.self, from: oldData)
        XCTAssertNil(oldRoom.scan_guide_jpeg)
        XCTAssertEqual(oldRoom.coordinate_id, room.coordinate_id)
        try oldRoom.validate()

        room.scan_guide_jpeg = guide
        try room.validate()
        let restored = try JSONDecoder().decode(Room.self, from: JSONEncoder().encode(room))
        XCTAssertEqual(restored, room)
        XCTAssertEqual(restored.scan_guide_jpeg, guide)
        XCTAssertEqual(restored.coordinate_id, oldRoom.coordinate_id)
    }

    func testGuideRejectsMalformedNoncanonicalBase64AndNonJPEGFraming() throws {
        var room = Room(project_id: UUID(), name: "Validation")
        let invalid = ["", "not base64!", guide + "\n", "/9j/2R==",
                       Data([0xff,0xd8,0xff]).base64EncodedString(),
                       Data([0x00,0xd8,0xff,0xd9]).base64EncodedString(),
                       Data([0xff,0xd8,0xff,0x00]).base64EncodedString()]
        for candidate in invalid {
            room.scan_guide_jpeg = candidate
            XCTAssertThrowsError(try room.validate(), "Accepted invalid guide: \(candidate)")
        }
        room.scan_guide_jpeg = guide
        XCTAssertNoThrow(try room.validate())
    }

    func testGuideDecodedByteLimitIncludesExactBoundary() throws {
        var room = Room(project_id: UUID(), name: "Bounds")
        var maximum = Data([0xff,0xd8])
        maximum.append(Data(repeating: 0, count: 65_532))
        maximum.append(contentsOf: [0xff,0xd9])
        XCTAssertEqual(maximum.count, 65_536)
        room.scan_guide_jpeg = maximum.base64EncodedString()
        XCTAssertEqual(room.scan_guide_jpeg?.utf8.count, 87_384)
        XCTAssertNoThrow(try room.validate())
        maximum.insert(0, at: 2)
        room.scan_guide_jpeg = maximum.base64EncodedString()
        // 65,537 decoded bytes can have the same encoded length as the valid boundary.
        XCTAssertEqual(room.scan_guide_jpeg?.utf8.count, 87_384)
        XCTAssertThrowsError(try room.validate())
        room.scan_guide_jpeg = String(repeating: "A", count: 87_388)
        XCTAssertThrowsError(try room.validate())
    }

    func testMapRetryPreservesGuideAndResetRejectsLateCapture() throws {
        var transaction = MapSaveTransaction()
        let generation = transaction.generation
        let map = Data([1,2,3])
        var room = Room(project_id: UUID(), name: "Saved room")
        room.map_path = "project/room/map.worldmap"
        room.scan_guide_jpeg = guide
        try transaction.capture(map, generation: generation, guide: guide)
        try transaction.stage(room, generation: generation)
        try transaction.validate(generation)
        try transaction.stage(room, generation: generation)
        XCTAssertEqual(transaction.data, map)
        XCTAssertEqual(transaction.guide, guide)
        XCTAssertEqual(transaction.publication, room)
        XCTAssertEqual(transaction.publication?.coordinate_id, room.coordinate_id)
        var mismatched = room
        mismatched.scan_guide_jpeg = otherGuide
        XCTAssertThrowsError(try transaction.stage(mismatched, generation: generation))
        XCTAssertEqual(transaction.publication, room)

        transaction.reset()
        XCTAssertNil(transaction.data)
        XCTAssertNil(transaction.guide)
        XCTAssertNil(transaction.publication)
        XCTAssertThrowsError(try transaction.capture(map, generation: generation, guide: guide))
        XCTAssertNil(transaction.guide)
        try transaction.capture(map, generation: transaction.generation)
        XCTAssertNil(transaction.guide)
    }

    func testProjectArchiveCarriesGuideWithoutChangingRoomCoordinates() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = Project(owner_id: UUID(), name: "Guide transfer")
        var room = Room(project_id: project.id, name: "Mapped room")
        room.scan_guide_jpeg = guide
        room.map_path = "\(project.id.uuidString)/\(room.id.uuidString)/map.worldmap"
        let mapURL = root.appendingPathComponent(room.map_path!)
        try FileManager.default.createDirectory(at: mapURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bytes = Data("Synthetic map fixture for transfer testing only".utf8)
        try bytes.write(to: mapURL)
        let task = Annotation(room: room, kind: .text, pose: .identity, title: "Saved pose", detail: "")
        let archive = root.appendingPathComponent("guide.sitescope")
        try ProjectTransferArchive.write(project: project, rooms: [room], annotations: [task], assetRoot: root, to: archive)
        let extracted = root.appendingPathComponent("extracted")
        let manifest = try ProjectTransferArchive.read(from: archive, extractTo: extracted)
        XCTAssertEqual(manifest.rooms, [room])
        XCTAssertEqual(manifest.rooms.first?.scan_guide_jpeg, guide)
        XCTAssertEqual(manifest.rooms.first?.coordinate_id, room.coordinate_id)
        XCTAssertEqual(manifest.annotations, [task])
        XCTAssertEqual(manifest.assets.count, 1) // The guide is bounded metadata, not a separate marker asset.
        XCTAssertEqual(try Data(contentsOf: extracted.appendingPathComponent(room.map_path!)), bytes)
    }
}
