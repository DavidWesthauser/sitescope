import XCTest
import Foundation
import CryptoKit
#if canImport(sitescopeCore)
@testable import sitescopeCore
#else
@testable import sitescope
#endif

final class ProjectTransferArchiveTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    private func fixture() throws -> (Project, Room, Annotation, Data) {
        let project = Project(owner_id: UUID(), name: "Offline site")
        var room = Room(project_id: project.id, name: "Room")
        let prefix = "\(project.id.uuidString)/\(room.id.uuidString)/"
        room.map_path = prefix + "worldmap.bin"
        // Synthetic map bytes belong only to this disk-format test.
        let map = Data((0..<1_100_000).map { UInt8($0 % 251) })
        var task = Annotation(room: room, kind: .image, pose: .identity, title: "Install panel", detail: "Reference image")
        task.image = SpatialImage(path: prefix + "instruction.jpg", width: 1, height: 1)
        let dir = root.appendingPathComponent(prefix)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try map.write(to: root.appendingPathComponent(room.map_path!))
        try Data([1,2,3,4]).write(to: root.appendingPathComponent(task.image!.path))
        return (project, room, task, map)
    }

    private func encode(_ manifest: ProjectTransferManifest, body: Data = Data()) throws -> URL {
        let json = try JSONEncoder().encode(manifest)
        var result = Data("sitescope01".utf8)
        var size = UInt64(json.count).littleEndian
        withUnsafeBytes(of: &size) { result.append(contentsOf: $0) }
        result.append(json); result.append(body)
        let file = root.appendingPathComponent(UUID().uuidString + ".sitescope")
        try result.write(to: file)
        return file
    }

    func testRoundTripStreamsDiskAssetsAndOmitsLegacyMarker() throws {
        let (project, original, task, map) = try fixture()
        var room = original
        room.marker = Marker(id: UUID(), image_path: "old-missing-marker.png", width: 0.1, height: 0.1, room_from_marker: .identity)
        let archive = root.appendingPathComponent("project.sitescope")
        try ProjectTransferArchive.write(project: project, rooms: [room], annotations: [task], assetRoot: root, to: archive)
        let output = root.appendingPathComponent("imported")
        let manifest = try ProjectTransferArchive.read(from: archive, extractTo: output)
        XCTAssertEqual(manifest.version, 1)
        XCTAssertEqual(manifest.project, project)
        XCTAssertEqual(manifest.rooms, [room])
        XCTAssertEqual(manifest.annotations, [task])
        XCTAssertEqual(manifest.assets.map(\.path), [room.map_path!, task.image!.path].sorted())
        XCTAssertEqual(try Data(contentsOf: output.appendingPathComponent(room.map_path!)), map)
        XCTAssertEqual(try Data(contentsOf: output.appendingPathComponent(task.image!.path)), Data([1,2,3,4]))
        XCTAssertThrowsError(try ProjectTransferArchive.read(from: archive, extractTo: output))
        XCTAssertEqual(try Data(contentsOf: output.appendingPathComponent(room.map_path!)), map)
        XCTAssertThrowsError(try ProjectTransferArchive.write(project: project, rooms: [room], annotations: [task], assetRoot: root, to: archive))
    }

    func testCorruptTruncatedAndTrailingBytesRollBack() throws {
        let (project, room, task, _) = try fixture()
        let archive = root.appendingPathComponent("project.sitescope")
        try ProjectTransferArchive.write(project: project, rooms: [room], annotations: [task], assetRoot: root, to: archive)
        let original = try Data(contentsOf: archive)
        var corrupt = original; corrupt[corrupt.count - 1] ^= 255
        var trailing = original; trailing.append(0)
        for bytes in [Data("badmagic".utf8), corrupt, Data(original.dropLast()), trailing] {
            try bytes.write(to: archive)
            let output = root.appendingPathComponent("imported")
            XCTAssertThrowsError(try ProjectTransferArchive.read(from: archive, extractTo: output))
            XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
            XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: root.path).contains(where: { $0.hasPrefix(".sitescope-import-") }))
        }
    }

    func testRejectsMissingAssetsDuplicatesAndCoordinateMismatch() throws {
        let (project, room, task, _) = try fixture()
        let output = root.appendingPathComponent("project.sitescope")
        XCTAssertThrowsError(try ProjectTransferArchive.write(project: project, rooms: [room, room], annotations: [task], assetRoot: root, to: output))
        XCTAssertThrowsError(try ProjectTransferArchive.write(project: project, rooms: [room], annotations: [task, task], assetRoot: root, to: output))
        var bad = task; bad.coordinate_id = UUID()
        XCTAssertThrowsError(try ProjectTransferArchive.write(project: project, rooms: [room], annotations: [bad], assetRoot: root, to: output))
        var wrongProject = room; wrongProject.project_id = UUID()
        XCTAssertThrowsError(try ProjectTransferArchive.write(project: project, rooms: [wrongProject], annotations: [], assetRoot: root, to: output))
        try FileManager.default.removeItem(at: root.appendingPathComponent(room.map_path!))
        XCTAssertThrowsError(try ProjectTransferArchive.write(project: project, rooms: [room], annotations: [task], assetRoot: root, to: output))
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: root.path).contains(where: { $0.hasPrefix(".sitescope-export-") }))
    }

    func testRejectsTraversalSymlinksAndUnreferencedAssets() throws {
        let (project, original, task, _) = try fixture()
        for path in ["../escape", "/absolute", "\(project.id)/\(original.id)/../escape", "\(project.id)/\(original.id)/bad\\file", "\(UUID())/\(original.id)/map"] {
            var room = original; room.map_path = path
            let manifest = ProjectTransferManifest(project: project, rooms: [room], annotations: [task], assets: [])
            let file = try encode(manifest)
            XCTAssertThrowsError(try ProjectTransferArchive.read(from: file, extractTo: root.appendingPathComponent("imported")))
        }
        let mapURL = root.appendingPathComponent(original.map_path!)
        try FileManager.default.removeItem(at: mapURL)
        try FileManager.default.createSymbolicLink(at: mapURL, withDestinationURL: root.appendingPathComponent(task.image!.path))
        XCTAssertThrowsError(try ProjectTransferArchive.write(project: project, rooms: [original], annotations: [task], assetRoot: root, to: root.appendingPathComponent("link.sitescope")))
        let extra = ProjectTransferAsset(path: "unexpected", byteCount: 0, sha256: String(repeating: "0", count: 64))
        let file = try encode(ProjectTransferManifest(project: project, rooms: [], annotations: [], assets: [extra]))
        XCTAssertThrowsError(try ProjectTransferArchive.read(from: file, extractTo: root.appendingPathComponent("imported")))
    }

    func testRejectsUnsupportedVersionAndOversizeManifest() throws {
        let project = Project(owner_id: UUID(), name: "Project")
        let file = try encode(ProjectTransferManifest(version: 2, project: project, rooms: [], annotations: [], assets: []))
        XCTAssertThrowsError(try ProjectTransferArchive.read(from: file, extractTo: root.appendingPathComponent("imported")))
        var data = Data("sitescope01".utf8)
        var length = UInt64(16 * 1_048_576 + 1).littleEndian
        withUnsafeBytes(of: &length) { data.append(contentsOf: $0) }
        try data.write(to: file)
        XCTAssertThrowsError(try ProjectTransferArchive.read(from: file, extractTo: root.appendingPathComponent("imported")))
    }
}
