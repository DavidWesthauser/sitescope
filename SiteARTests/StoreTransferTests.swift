import XCTest
import simd
#if canImport(sitescopeCore)
@testable import sitescopeCore
#else
@testable import sitescope
#endif

@MainActor final class StoreTransferTests: XCTestCase {
    private func folder() throws -> URL {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("sitescope-StoreTransferTests-\(UUID().uuidString)",isDirectory:true)
        try FileManager.default.createDirectory(at:url,withIntermediateDirectories:false)
        return url
    }
    private func fixture(at root:URL) async throws -> (store:Store,project:Project,rooms:[Room],items:[Annotation],map:Data,image:Data) {
        let store=Store(localURL:root.appendingPathComponent("local.json"))
        try await store.createProject(name:"Shared apartment")
        let project=try XCTUnwrap(store.projects.first)
        try await store.createRoom(in:project,name:"Kitchen")
        try await store.createRoom(in:project,name:"Hallway")
        // Deterministic disk fixtures, deliberately not real ARWorldMap/image decodes.
        let map=Data((0..<1_100_000).map { UInt8($0 % 251) }),image=Data([137,80,78,71,13,10,26,10])
        var rooms=store.rooms
        for index in rooms.indices {
            let path="\(project.id.uuidString)/\(rooms[index].id.uuidString)/room.worldmap"
            try await store.uploadAsset(path:path,data:map,type:"application/octet-stream")
            rooms[index].map_path=path
            rooms[index].marker=Marker(id:UUID(),image_path:"obsolete-missing-marker.png",width:0.2,height:0.2,room_from_marker:.identity)
            rooms[index].reference_points=[Point3(.zero),Point3(SIMD3(1,0,0))];rooms[index].reference_notes="Legacy references"
            try await store.publishRoom(rooms[index])
        }
        var matrix=matrix_identity_float4x4;matrix.columns.3=SIMD4(1,2,-3,1)
        let pose=try Pose(matrix)
        var photo=Annotation(room:rooms[0],kind:.image,pose:pose,points:[Point3(.zero)],title:"Install panel",detail:"Keep original placement")
        let path="\(project.id.uuidString)/\(rooms[0].id.uuidString)/panel.png"
        try await store.uploadAsset(path:path,data:image,type:"image/png")
        photo.image=SpatialImage(path:path,width:0.4,height:0.3);photo.priority=2
        var line=Annotation(room:rooms[1],kind:.line,pose:pose,points:[Point3(.zero),Point3(SIMD3(0.2,0,0))],title:"Repair wall",detail:"")
        line.strokes=[line.points,[Point3(SIMD3(1,0,0)),Point3(SIMD3(1.2,0,0))]];line.status = .completed
        try await store.saveInstruction(photo,room:rooms[0],replacing:false)
        try await store.saveInstruction(line,room:rooms[1],replacing:false)
        return (store,project,rooms,[photo,line],map,image)
    }
    func testProjectFileRoundTripPreservesAssetsAndCoordinatesWithIndependentIDs() async throws {
        let sourceRoot=try folder(),targetRoot=try folder()
        defer { try? FileManager.default.removeItem(at:sourceRoot);try? FileManager.default.removeItem(at:targetRoot) }
        let source=try await fixture(at:sourceRoot)
        let archive=try await source.store.exportProjectFile(source.project)
        defer { try? FileManager.default.removeItem(at:archive.deletingLastPathComponent()) }
        XCTAssertEqual(archive.pathExtension,"sitescope")
        XCTAssertTrue(archive.deletingLastPathComponent().lastPathComponent.hasPrefix("sitescope-Export-"))
        let targetURL=targetRoot.appendingPathComponent("local.json"),target=Store(localURL:targetURL)
        try await target.createProject(name:"Existing project")
        let originalProjects=target.projects
        let imported=try await target.importProjectFile(from:archive)
        let repeated=try await target.importProjectFile(from:archive)
        XCTAssertNotEqual(imported.id,source.project.id);XCTAssertNotEqual(imported.id,repeated.id)
        XCTAssertEqual(imported.owner_id,target.userID);XCTAssertEqual(imported.name,source.project.name)
        XCTAssertEqual(target.projects.count,3);XCTAssertEqual(target.projects.first,originalProjects.first)
        XCTAssertEqual(target.rooms.count,4);XCTAssertEqual(target.annotations.count,4)
        let importedRooms=target.rooms.filter { $0.project_id == imported.id }
        let secondRooms=target.rooms.filter { $0.project_id == repeated.id }
        XCTAssertTrue(Set(importedRooms.map(\.id)).isDisjoint(with:secondRooms.map(\.id)))
        XCTAssertTrue(Set(importedRooms.map(\.id)).isDisjoint(with:source.rooms.map(\.id)))
        XCTAssertTrue(Set(target.annotations.map(\.id)).isDisjoint(with:source.items.map(\.id)))
        for original in source.rooms {
            let room=try XCTUnwrap(importedRooms.first { $0.name == original.name })
            XCTAssertEqual(room.coordinate_id,original.coordinate_id);XCTAssertEqual(room.surfaces,original.surfaces)
            XCTAssertNil(room.marker);XCTAssertTrue(room.reference_points.isEmpty);XCTAssertTrue(room.reference_notes.isEmpty)
            let path=try XCTUnwrap(room.map_path)
            XCTAssertTrue(path.hasPrefix("\(imported.id.uuidString.lowercased())/\(room.id.uuidString.lowercased())/"))
            let bytes=try await target.downloadAsset(path:path);XCTAssertEqual(bytes,source.map)
            let originalItem=try XCTUnwrap(source.items.first { $0.room_id == original.id })
            var expected=originalItem
            let actual=try XCTUnwrap(target.annotations.first { $0.room_id == room.id })
            expected.id=actual.id;expected.room_id=room.id
            if var image=expected.image {
                image.path=try XCTUnwrap(actual.image?.path);expected.image=image
                XCTAssertTrue(image.path.hasPrefix("\(imported.id.uuidString.lowercased())/\(room.id.uuidString.lowercased())/"))
                let bytes=try await target.downloadAsset(path:image.path);XCTAssertEqual(bytes,source.image)
            }
            XCTAssertEqual(actual,expected) // Pose, coordinate ID, geometry, task status and dimensions stay unchanged.
        }
        let reopened=Store(localURL:targetURL)
        XCTAssertEqual(reopened.projects,target.projects);XCTAssertEqual(reopened.rooms,target.rooms);XCTAssertEqual(reopened.annotations,target.annotations)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath:targetRoot.path).contains { $0.hasPrefix(".sitescope-transfer-") })
        XCTAssertEqual(source.store.rooms,source.rooms) // Export never strips legacy data from the source itself.
    }
    func testMalformedImportLeavesExistingDataAndAssetsUntouched() async throws {
        let root=try folder(),targetRoot=try folder()
        defer { try? FileManager.default.removeItem(at:root);try? FileManager.default.removeItem(at:targetRoot) }
        let source=try await fixture(at:root),archive=try await source.store.exportProjectFile(source.project)
        defer { try? FileManager.default.removeItem(at:archive.deletingLastPathComponent()) }
        var corrupt=try Data(contentsOf:archive);corrupt[corrupt.count-1] ^= 255
        let bad=root.appendingPathComponent("corrupt.sitescope");try corrupt.write(to:bad)
        let url=targetRoot.appendingPathComponent("local.json"),target=Store(localURL:url)
        try await target.createProject(name:"Keep this project")
        let projects=target.projects,bytes=try Data(contentsOf:url)
        do { _ = try await target.importProjectFile(from:bad);XCTFail("A corrupt asset must reject the entire import") } catch {}
        XCTAssertEqual(target.projects,projects);XCTAssertTrue(target.rooms.isEmpty);XCTAssertTrue(target.annotations.isEmpty)
        XCTAssertEqual(try Data(contentsOf:url),bytes)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath:targetRoot.path),["local.json"])
    }
    func testMetadataWriteFailureRollsBackCopiedAssets() async throws {
        let root=try folder(),targetRoot=try folder()
        defer { try? FileManager.default.removeItem(at:root);try? FileManager.default.removeItem(at:targetRoot) }
        let source=try await fixture(at:root),archive=try await source.store.exportProjectFile(source.project)
        defer { try? FileManager.default.removeItem(at:archive.deletingLastPathComponent()) }
        let url=targetRoot.appendingPathComponent("local.json"),target=Store(localURL:url)
        try await target.createProject(name:"Keep this project")
        let projects=target.projects,bytes=try Data(contentsOf:url)
        // Deliberately make this test's metadata destination unwritable as a file, after Store loaded it.
        try FileManager.default.removeItem(at:url);try FileManager.default.createDirectory(at:url,withIntermediateDirectories:false)
        do { _ = try await target.importProjectFile(from:archive);XCTFail("The metadata write must fail") } catch {}
        XCTAssertEqual(target.projects,projects);XCTAssertTrue(target.rooms.isEmpty);XCTAssertTrue(target.annotations.isEmpty)
        let assets=targetRoot.appendingPathComponent("assets")
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath:assets.path).isEmpty)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath:targetRoot.path).contains { $0.hasPrefix(".sitescope-transfer-") })
        try FileManager.default.removeItem(at:url);try bytes.write(to:url,options:.atomic)
        XCTAssertEqual(Store(localURL:url).projects,projects)
    }
    func testEmptyLocalProjectCanBeTransferredBeforeAnyAssetsExist() async throws {
        let root=try folder(),targetRoot=try folder()
        defer { try? FileManager.default.removeItem(at:root);try? FileManager.default.removeItem(at:targetRoot) }
        let source=Store(localURL:root.appendingPathComponent("local.json"))
        try await source.createProject(name:"Empty project")
        let file=try await source.exportProjectFile(try XCTUnwrap(source.projects.first))
        defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        let target=Store(localURL:targetRoot.appendingPathComponent("local.json"))
        let imported=try await target.importProjectFile(from:file)
        XCTAssertEqual(imported.name,"Empty project");XCTAssertTrue(target.rooms.isEmpty);XCTAssertTrue(target.annotations.isEmpty)
    }
}
