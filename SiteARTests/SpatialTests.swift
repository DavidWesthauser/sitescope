import XCTest
import simd
#if canImport(sitescopeCore)
@testable import sitescopeCore
#else
@testable import sitescope
#endif

final class SpatialTests: XCTestCase {
    func transform(_ translation: SIMD3<Float>, yaw: Float = 0) throws -> Pose {
        var m = simd_float4x4(simd_quatf(angle: yaw, axis: SIMD3(0,1,0)))
        m.columns.3 = SIMD4(translation,1); return try Pose(m)
    }
    func assertMatrix(_ a: Pose, _ b: Pose, file: StaticString = #filePath, line: UInt = #line) {
        for (x,y) in zip(a.elements,b.elements) { XCTAssertEqual(x,y,accuracy: 0.0001,file:file,line:line) }
    }
    func testViewCaptureRejectsDuplicatesAndStaleCallbacks() throws {
        var request=ViewCaptureRequest()
        let first=try XCTUnwrap(request.begin());XCTAssertTrue(request.isPending)
        XCTAssertNil(request.begin())
        request.cancel();let second=try XCTUnwrap(request.begin())
        XCTAssertFalse(request.accepts(first));XCTAssertFalse(request.finish(first))
        XCTAssertTrue(request.isPending);XCTAssertTrue(request.accepts(second))
        XCTAssertTrue(request.finish(second));XCTAssertFalse(request.isPending)
        XCTAssertFalse(request.finish(second))
    }
    func testSurfaceSettlingDistinguishesDepthFromTangentialOriginChanges() throws {
        var quality=SurfaceStability()
        XCTAssertFalse(quality.isReady(at:1))
        quality.observe(.identity,at:0)
        XCTAssertFalse(quality.isReady(at:0.59));XCTAssertTrue(quality.isReady(at:0.6))
        quality.observe(try transform(SIMD3(0.4,0,0.5)),at:0.7)
        XCTAssertTrue(quality.isReady(at:0.7)) // The same plane with a shifted origin.
        quality.observe(try transform(SIMD3(0,0.03,0)),at:0.8)
        XCTAssertFalse(quality.isReady(at:1));XCTAssertTrue(quality.isReady(at:1.5))
        let tilted=try Pose(simd_float4x4(simd_quatf(angle:0.1,axis:SIMD3(1,0,0))))
        quality.observe(tilted,at:1.6)
        XCTAssertFalse(quality.isReady(at:1.7));XCTAssertTrue(quality.isReady(at:2.3))
        quality.observe(.identity,at:0) // A fresh session clock cannot reuse old evidence.
        XCTAssertFalse(quality.isReady(at:0.1))
        quality.observe(.identity,at:.nan);XCTAssertFalse(quality.isReady(at:10))
    }
    func testFrozenCaptureRejectsCameraMotionAndRotation() throws {
        XCTAssertTrue(CameraCaptureQuality.isSteady(from:.identity,to:try transform(SIMD3(0.005,0,0),yaw:0.01)))
        XCTAssertFalse(CameraCaptureQuality.isSteady(from:.identity,to:try transform(SIMD3(0.1,0,0))))
        XCTAssertFalse(CameraCaptureQuality.isSteady(from:.identity,to:try transform(.zero,yaw:0.1)))
    }
    func testMiniatureSlabsKeepRoomPoseAndDoNotInventSurfaces() throws {
        let pose=try transform(SIMD3(3,2,-1))
        let patch=SurfacePatch(id:UUID(),pose:pose,vertices:[Point3(.zero),Point3(SIMD3(2,0,0)),Point3(SIMD3(2,0,1)),Point3(SIMD3(0,0,1))],vertical:false)
        let faces=ScanVisualization.faces(patch)
        XCTAssertEqual(faces.count,6)
        XCTAssertEqual(faces[0].vertices[0].x,3,accuracy:0.0001)
        XCTAssertEqual(faces[0].vertices[0].y,2.0125,accuracy:0.0001)
        XCTAssertEqual(faces[0].vertices[0].z,-1,accuracy:0.0001)
        XCTAssertTrue(faces.allSatisfy { (0...1).contains($0.shade) })
        XCTAssertTrue(ScanVisualization.faces(patch,vertices:[]).isEmpty)
        let moved=patch.worldVertices.map { $0+SIMD3<Float>(0,1,0) }
        XCTAssertEqual(ScanVisualization.faces(patch,vertices:moved)[0].vertices[0].y,3.0125,accuracy:0.0001)
    }
    func testMiniatureRotationUsesShortestTurnAcrossPi() {
        let from=Float.pi-0.05,to = -Float.pi+0.05
        XCTAssertEqual(ScanVisualization.shortAngle(from:from,to:to)-from,0.1,accuracy:0.0001)
        let p=ScanVisualization.rotate(SIMD3(1,2,0),yaw:Float.pi/2)
        XCTAssertEqual(p.x,0,accuracy:0.0001);XCTAssertEqual(p.y,2);XCTAssertEqual(p.z,1,accuracy:0.0001)
    }
    func testCoverageNeedsTranslationAndDifferentDirections() {
        var coverage=ScanCoverage()
        for i in 0..<4 {
            let angle=Float(i)*Float.pi/2+0.2
            for offset in [0.0, 0.75] {
                coverage.observe(position:.zero,forward:SIMD3(sin(angle),0,cos(angle)),reliable:true,at:Double(i) + offset)
            }
        }
        XCTAssertEqual(coverage.headings.count,4); XCTAssertEqual(coverage.positions.count,1)
        XCTAssertFalse(coverage.ready) // Qualified turns on the spot are still insufficient.
        for time in [4.0, 4.75] {
            coverage.observe(position:SIMD3(0.2,0,0),forward:SIMD3(1,0,0),reliable:true,at:time)
        }
        XCTAssertEqual(coverage.positions.count,1)
        coverage.observe(position:SIMD3(1,0,0),forward:SIMD3(1,0,0),reliable:false,at:5)
        XCTAssertEqual(coverage.positions.count,1)
        for (i,x) in [Float(0.6),1.2].enumerated() {
            for offset in [0.0, 0.75] {
                coverage.observe(position:SIMD3(x,0,0),forward:SIMD3(1,0,0),reliable:true,at:6 + Double(i) + offset)
            }
        }
        XCTAssertTrue(coverage.ready)
        var oneDirection=ScanCoverage()
        for (i,x) in [Float(0),0.6,1.2].enumerated() {
            for offset in [0.0, 0.75] {
                oneDirection.observe(position:SIMD3(x,0,0),forward:SIMD3(0,0,-1),reliable:true,at:Double(i) + offset)
            }
        }
        XCTAssertEqual(oneDirection.positions.count,3)
        XCTAssertFalse(oneDirection.ready)
    }
    func testMeasuredDistanceUsesOffCentreScreenDirection() throws {
        let camera=SIMD3<Float>(1,2,3), direction=SIMD3<Float>(1,0,-1)
        let point=try XCTUnwrap(DrawingGeometry.measuredPoint(camera:camera,direction:direction,distance:2))
        XCTAssertEqual(simd_distance(point,camera),2,accuracy:0.0001)
        XCTAssertGreaterThan(point.x,camera.x)
        XCTAssertEqual(point.y,camera.y)
        XCTAssertNil(DrawingGeometry.measuredPoint(camera:camera,direction:.zero,distance:2))
        XCTAssertNil(DrawingGeometry.measuredPoint(camera:camera,direction:direction,distance:.nan))
    }
    func testMarkerRecoveryAcrossDifferentOriginsAndYaw() throws {
        let roomFromMarker = try transform(SIMD3(3,1,-4),yaw: 0.3)
        let expected = try transform(SIMD3(-7,0.2,5),yaw: -1.2)
        let sessionFromMarker = try Pose(expected.matrix * roomFromMarker.matrix)
        let result = try AlignmentMath.marker(sessionFromMarker: sessionFromMarker, roomFromMarker: roomFromMarker)
        assertMatrix(result,expected)
        let point = SIMD4<Float>(1,2,-3,1)
        XCTAssertLessThan(simd_length(result.matrix * point - expected.matrix * point),0.0001)
    }
    func testManualTwoPointRecovery() throws {
        let expected = try transform(SIMD3(4,0.5,-2),yaw: 0.9)
        let points = [Point3(SIMD3(1,0,-2)),Point3(SIMD3(3,0.2,-1))]
        let session = points.map { Point3((expected.matrix * SIMD4($0.vector,1)).xyz) }
        assertMatrix(try AlignmentMath.manual(room: points,session: session),expected)
    }
    func testManualRejectsVerticalAndInconsistentPoints() {
        let room = [Point3(.zero),Point3(SIMD3(0,1,0))]
        XCTAssertThrowsError(try AlignmentMath.manual(room:room, session:room))
        XCTAssertThrowsError(try AlignmentMath.manual(room:[Point3(.zero),Point3(SIMD3(1,0,0))], session:[Point3(.zero),Point3(SIMD3(3,0,0))]))
    }
    func testPoseRejectsScaleReflectionNaNAndMalformedJSON() throws {
        var m = matrix_identity_float4x4; m.columns.0.x = 2
        XCTAssertThrowsError(try Pose(m))
        m.columns.0.x = -1; XCTAssertThrowsError(try Pose(m))
        m.columns.0.x = .nan; XCTAssertThrowsError(try Pose(m))
        XCTAssertThrowsError(try JSONDecoder().decode(Pose.self, from: Data("[1,2]".utf8)))
    }
    func testPoseColumnMajorSerializationRoundTrip() throws {
        let original = try transform(SIMD3(2,4,-8),yaw: 0.7)
        let data = try JSONEncoder().encode(original)
        let array = try JSONDecoder().decode([Float].self,from:data)
        XCTAssertEqual(Array(array[12...14]),[2,4,-8])
        XCTAssertEqual(try JSONDecoder().decode(Pose.self,from:data), original)
    }
    func testNoOverlaysBeforeConfirmationOrAfterTrackingLoss() {
        var state = Localization(); XCTAssertNil(state.roomToSession)
        state.searching(); state.confirm(normalTracking:true); XCTAssertNil(state.roomToSession)
        state.propose(.identity,method:.marker); XCTAssertNil(state.roomToSession)
        state.confirm(normalTracking:false); XCTAssertNil(state.roomToSession)
        state.confirm(normalTracking:true); XCTAssertEqual(state.roomToSession,.identity)
        state.lose(); XCTAssertNil(state.roomToSession); XCTAssertNil(state.candidate)
        state.confirm(normalTracking:true); XCTAssertNil(state.roomToSession)
    }
    func testTimeoutAndRestartInvalidateCandidates() {
        var state = Localization(); state.propose(.identity,method:.map); state.fail()
        XCTAssertEqual(state.state,.failed); XCTAssertNil(state.roomToSession)
        state.propose(.identity,method:.manual); state.confirm(normalTracking:true); state.searching()
        XCTAssertNil(state.candidate); XCTAssertEqual(state.state,.relocalizing)
    }
    func testAnnotationSerializationAndRoomIsolation() throws {
        let room = Room(project_id: UUID(),name:"Kitchen")
        var item = Annotation(room:room,kind:.text,pose:try transform(SIMD3(1,2,3)),title:"Paint wall",detail:"Blue")
        item.status = .inProgress
        let restored = try JSONDecoder().decode(Annotation.self,from:JSONEncoder().encode(item))
        XCTAssertEqual(restored,item); try restored.validate(room:room)
        XCTAssertThrowsError(try restored.validate(room:Room(project_id:room.project_id,name:"Other")))
        var remapped = room; remapped.coordinate_id = UUID()
        XCTAssertThrowsError(try restored.validate(room:remapped))
    }
    func testAreaMustHavePlanarNoncollinearGeometry() throws {
        let room = Room(project_id:UUID(),name:"Room")
        var item = Annotation(room:room,kind:.area,pose:.identity,points:[Point3(.zero),Point3(SIMD3(1,0,0)),Point3(SIMD3(1,1,0))],title:"Wall",detail:"")
        try item.validate(room:room)
        item.points.append(Point3(SIMD3(0,0,1)))
        XCTAssertThrowsError(try item.validate(room:room))
        item.points = [Point3(.zero),Point3(SIMD3(1,0,0)),Point3(SIMD3(2,0,0))]
        XCTAssertThrowsError(try item.validate(room:room))
    }
    func testTaskStatusAndPriorityPersist() throws {
        let room = Room(project_id:UUID(),name:"Room")
        for status in TaskStatus.allCases {
            var task = Annotation(room:room,kind:.marker,pose:.identity,title:"Repair",detail:"Check pipe")
            task.status = status; task.priority = 2
            XCTAssertEqual(try JSONDecoder().decode(Annotation.self,from:JSONEncoder().encode(task)),task)
        }
    }
    func testRoomMetadataRoundtripAndVersionRejection() throws {
        var room = Room(project_id:UUID(),name:"Kitchen")
        room.marker = Marker(id:UUID(),image_path:"project/room/marker.png",width:0.2,height:0.3,room_from_marker:.identity)
        room.reference_points = [Point3(.zero),Point3(SIMD3(1,0,0))]
        XCTAssertEqual(try JSONDecoder().decode(Room.self,from:JSONEncoder().encode(room)),room)
        room.spatial_version = 2; XCTAssertThrowsError(try room.validate())
    }
    func testProjectAndRoomIDsRemainStableOnRename() throws {
        var project = Project(owner_id:UUID(),name:"Old"); let projectID = project.id
        var room = Room(project_id:projectID,name:"Old"); let coordinate = room.coordinate_id
        project.name = "New"; room.name = "New"
        XCTAssertEqual(project.id,projectID); XCTAssertEqual(room.project_id,projectID); XCTAssertEqual(room.coordinate_id,coordinate)
    }
}

extension SpatialTests {
    func testTimedOutMapSearchStillRequiresAllEvidenceBeforeLateRecovery() {
        var state=Localization();state.searching();state.timedOut()
        XCTAssertEqual(state.state,.failed);XCTAssertTrue(state.searchTimedOut)
        XCTAssertNil(state.roomToSession)
        XCTAssertFalse(state.recoverMap(restoredRoomAnchor:false,normalTracking:true,stableSeconds:5,mapAvailable:true))
        XCTAssertFalse(state.recoverMap(restoredRoomAnchor:true,normalTracking:false,stableSeconds:5,mapAvailable:true))
        XCTAssertFalse(state.recoverMap(restoredRoomAnchor:true,normalTracking:true,stableSeconds:1.99,mapAvailable:true))
        XCTAssertFalse(state.recoverMap(restoredRoomAnchor:true,normalTracking:true,stableSeconds:5,mapAvailable:false))
        XCTAssertEqual(state.state,.failed);XCTAssertTrue(state.searchTimedOut)
        XCTAssertNil(state.roomToSession)
        XCTAssertTrue(state.recoverMap(restoredRoomAnchor:true,normalTracking:true,stableSeconds:2,mapAvailable:true))
        XCTAssertEqual(state.state,.aligned);XCTAssertEqual(state.roomToSession,.identity)
        XCTAssertFalse(state.searchTimedOut)
    }
    func testHardMapFailureCannotAutoRecoverOrBeConvertedIntoTimeout() {
        var state=Localization();state.searching();state.timedOut();state.fail()
        XCTAssertEqual(state.state,.failed);XCTAssertFalse(state.searchTimedOut)
        state.timedOut()
        XCTAssertFalse(state.searchTimedOut)
        XCTAssertFalse(state.recoverMap(restoredRoomAnchor:true,normalTracking:true,stableSeconds:10,mapAvailable:true))
        XCTAssertNil(state.roomToSession)
    }
    func testTimeoutEvidenceIsClearedWhenSearchOrAlignmentChanges() {
        var state=Localization();state.searching();state.timedOut();state.searching()
        XCTAssertFalse(state.searchTimedOut);XCTAssertEqual(state.state,.relocalizing)
        state.timedOut();state.propose(.identity,method:.manual)
        XCTAssertFalse(state.searchTimedOut);XCTAssertEqual(state.state,.verifying)
        state.searching();state.timedOut();state.lose()
        XCTAssertFalse(state.searchTimedOut);XCTAssertEqual(state.state,.lost)
        XCTAssertFalse(state.recoverMap(restoredRoomAnchor:true,normalTracking:true,stableSeconds:10,mapAvailable:true))
    }
    func testMapRecoveryNeedsRestoredRoomAnchorStableTrackingAndMappedEvidence() {
        var state = Localization(); state.searching()
        XCTAssertFalse(state.recoverMap(restoredRoomAnchor:false, normalTracking:true, stableSeconds:5, mapAvailable:true))
        XCTAssertFalse(state.recoverMap(restoredRoomAnchor:true, normalTracking:false, stableSeconds:5, mapAvailable:true))
        XCTAssertFalse(state.recoverMap(restoredRoomAnchor:true, normalTracking:true, stableSeconds:1, mapAvailable:true))
        XCTAssertFalse(state.recoverMap(restoredRoomAnchor:true, normalTracking:true, stableSeconds:5, mapAvailable:false))
        XCTAssertNil(state.roomToSession)
        XCTAssertTrue(state.recoverMap(restoredRoomAnchor:true, normalTracking:true, stableSeconds:2, mapAvailable:true))
        XCTAssertEqual(state.state,.aligned); XCTAssertEqual(state.roomToSession,.identity)
        state.lose(); XCTAssertNil(state.roomToSession)
        XCTAssertFalse(state.recoverMap(restoredRoomAnchor:true, normalTracking:true, stableSeconds:5, mapAvailable:true))
        state.searching()
        XCTAssertTrue(state.recoverMap(restoredRoomAnchor:true, normalTracking:true, stableSeconds:2, mapAvailable:true))
    }
    func testScanReadinessRequiresRealSurfacesAndStableTracking() throws {
        var progress = ScanProgress()
        progress.normalTracking = true; progress.mapReady = true; progress.stableSeconds = 3
        progress.featureCount = ScanProgress.minimumFeatureCount
        XCTAssertFalse(progress.canFinish)
        let surface = SurfacePatch(id:UUID(),pose:.identity,vertices:[Point3(.zero),Point3(SIMD3(1,0,0)),Point3(SIMD3(1,0,1))],vertical:false)
        try surface.validate(); progress.surfaces = [surface]
        for i in 0..<4 {
            let angle=Float(i)*Float.pi/2+0.2
            for offset in [0.0, 0.75] {
                progress.coverage.observe(position:SIMD3(Float(i)*0.6,0,0),forward:SIMD3(sin(angle),0,cos(angle)),reliable:true,at:Double(i) + offset)
            }
        }
        XCTAssertTrue(progress.canFinish); XCTAssertEqual(progress.stage,3); XCTAssertEqual(progress.horizontalCount,1)
        progress.featureCount = 19
        XCTAssertFalse(progress.hasUsefulFeatures); XCTAssertFalse(progress.canFinish)
        progress.featureCount = 20
        XCTAssertTrue(progress.hasUsefulFeatures); XCTAssertTrue(progress.canFinish)
        progress.normalTracking = false; XCTAssertFalse(progress.canFinish); XCTAssertEqual(progress.stage,0)
        progress.normalTracking = true; progress.mapReady = false; XCTAssertFalse(progress.canFinish)
    }
    func testRoomMapDoesNotRequireManualDotsOrMarkerAndOldRecordsStillDecode() throws {
        var room = Room(project_id:UUID(),name:"Scanned room"); room.map_path = "test.worldmap"
        try room.validate()
        let json = try JSONEncoder().encode(room)
        XCTAssertFalse(String(decoding:json,as:UTF8.self).contains("surfaces"))
        XCTAssertEqual(try JSONDecoder().decode(Room.self,from:json),room)
        room.surfaces = [SurfacePatch(id:UUID(),pose:try transform(SIMD3(2,1,-3)),vertices:[Point3(.zero),Point3(SIMD3(1,0,0)),Point3(SIMD3(1,0,1))],vertical:true)]
        try room.validate()
        XCTAssertEqual(try JSONDecoder().decode(Room.self,from:JSONEncoder().encode(room)),room)
        XCTAssertEqual(room.surfaces?.first?.worldVertices.first,SIMD3(2,1,-3))
    }
}

extension SpatialTests {
    func testLockedPlaneRayProjectionHasKnownFixedCoordinates() throws {
        let projection = simd_float4x4(columns:(SIMD4(1,0,0,0),SIMD4(0,1,0,0),SIMD4(0,0,-10.0/9,-1),SIMD4(0,0,-10.0/9,0)))
        let plane = try DrawingGeometry.plane(at:SIMD3(0,0,-2),normal:SIMD3(0,0,1),camera:.zero,preferredRight:SIMD3(1,0,0))
        let screen = try XCTUnwrap(DrawingGeometry.project(SIMD3(0.5,0,-2),viewProjection:projection))
        XCTAssertEqual(screen.x,0.625,accuracy:0.0001); XCTAssertEqual(screen.y,0.5,accuracy:0.0001)
        let ray = try XCTUnwrap(DrawingGeometry.ray(screen:screen,inverseViewProjection:simd_inverse(projection)))
        let point = try XCTUnwrap(DrawingGeometry.intersection(ray,plane:plane))
        XCTAssertLessThan(simd_distance(point,SIMD3(0.5,0,-2)),0.0001)
        for p in [SIMD2<Float>(0.3,0.2),SIMD2(0.8,0.7),SIMD2(0.5,0.5)] {
            let r = try XCTUnwrap(DrawingGeometry.ray(screen:p,inverseViewProjection:simd_inverse(projection)))
            let hit = try XCTUnwrap(DrawingGeometry.intersection(r,plane:plane))
            XCTAssertEqual(hit.z,-2,accuracy:0.0001)
            let projected = try XCTUnwrap(DrawingGeometry.project(hit,viewProjection:projection))
            XCTAssertLessThan(simd_distance(p,projected),0.0001)
        }
        XCTAssertNil(DrawingGeometry.intersection(SpatialRay(origin:.zero,direction:SIMD3(1,0,0)),plane:plane))
        XCTAssertNil(DrawingGeometry.intersection(SpatialRay(origin:.zero,direction:SIMD3(0,0,1)),plane:plane))
    }
    func testWallOrientationKeepsTextUprightAndDoesNotFollowCameraRotation() throws {
        let a = try DrawingGeometry.plane(at:SIMD3(2,1,0),normal:SIMD3(-1,0,0),camera:.zero,preferredRight:SIMD3(1,0,0))
        let b = try DrawingGeometry.plane(at:SIMD3(2,1,0),normal:SIMD3(-1,0,0),camera:SIMD3(0,0.5,1),preferredRight:SIMD3(0,1,0))
        assertMatrix(a,b)
        XCTAssertLessThan(simd_distance(a.matrix.columns.1.xyz,SIMD3(0,1,0)),0.0001)
        XCTAssertLessThan(simd_distance(a.matrix.columns.2.xyz,SIMD3(-1,0,0)),0.0001)
        let moved = try transform(SIMD3(4,0,-3),yaw:0.8)
        let local = SIMD4<Float>(0.4,0.2,0,1)
        XCTAssertLessThan(simd_length(moved.matrix*a.matrix*local - moved.matrix*(a.matrix*local)),0.0001)
    }
    func testArrowHasHeadInDrawingPlaneAndPointsToExactTip() throws {
        let tail = SIMD3<Float>(0,0,0), tip = SIMD3<Float>(0.8,0.4,0)
        let arrow = try XCTUnwrap(DrawingGeometry.arrow(tail:tail,tip:tip,normal:SIMD3(0,0,1)))
        XCTAssertEqual(arrow.tip,tip); XCTAssertEqual(arrow.tail,tail)
        XCTAssertEqual(arrow.left.z,0,accuracy:0.0001); XCTAssertEqual(arrow.right.z,0,accuracy:0.0001)
        let base = (arrow.left+arrow.right)/2
        XCTAssertGreaterThan(simd_dot(tip-base,tip-tail),0)
        XCTAssertGreaterThan(simd_distance(arrow.left,arrow.right),0.05)
        XCTAssertLessThan(simd_length(simd_cross(tip-base,tip-tail)),0.0001)
        XCTAssertNil(DrawingGeometry.arrow(tail:tail,tip:tail,normal:SIMD3(0,0,1)))
    }
    func testSurfaceOutlineRemovesSmallCollinearSamplesWithoutInventingFaces() {
        let p: [SIMD3<Float>] = [SIMD3(0,0,0),SIMD3(0.5,0,0),SIMD3(1,0,0),SIMD3(1,0,0.5),SIMD3(1,0,1),SIMD3(0.5,0,1),SIMD3(0,0,1),SIMD3(0,0,0.5)]
        let result = DrawingGeometry.outline(p.map(Point3.init))
        XCTAssertEqual(result.count,4)
        for corner in [SIMD3<Float>(0,0,0),SIMD3(1,0,0),SIMD3(1,0,1),SIMD3(0,0,1)] { XCTAssertTrue(result.contains(Point3(corner))) }
    }
}

extension SpatialTests {
    func testTypedLabelLengthMatchesCloudLimit() throws {
        let room=Room(project_id:UUID(),name:"Room")
        var note=Annotation(room:room,kind:.text,pose:.identity,title:String(repeating:"a",count:240),detail:"")
        try note.validate(room:room)
        note.title.append("b"); XCTAssertThrowsError(try note.validate(room:room))
    }
}

extension SpatialTests {
    func testFingerLiftSeparatesStrokesAndDropsSingleTaps() {
        var draft=FreehandDraft()
        draft.begin(); draft.append(Point3(SIMD3(0,0,0))); draft.append(Point3(SIMD3(1,0,0))); draft.end()
        draft.append(Point3(SIMD3(5,5,0))) // Movement without a touch-down must never extend the old path.
        draft.begin(); draft.append(Point3(SIMD3(5,5,0))); draft.append(Point3(SIMD3(6,5,0))); draft.end()
        XCTAssertEqual(draft.strokes.count,2); XCTAssertEqual(draft.strokes.map(\.count),[2,2])
        XCTAssertEqual(draft.strokes[0].last?.vector,SIMD3(1,0,0)); XCTAssertEqual(draft.strokes[1].first?.vector,SIMD3(5,5,0))
        draft.begin(); draft.append(Point3(SIMD3(9,9,0))); draft.end()
        XCTAssertEqual(draft.strokes.count,2)
        draft.undo(); XCTAssertEqual(draft.strokes.count,1)
        draft.clear(); XCTAssertTrue(draft.strokes.isEmpty); XCTAssertFalse(draft.isDrawing)
    }
    func testStrokeSmoothingPreservesEndpointsPlaneAndDoesNotOvershoot() {
        let controls=[Point3(SIMD3<Float>(0,0,0)),Point3(SIMD3(1,0,0)),Point3(SIMD3(1,1,0))]
        let curve=DrawingGeometry.smoothStroke(controls)
        XCTAssertEqual(curve.first,controls.first); XCTAssertEqual(curve.last,controls.last)
        XCTAssertGreaterThan(curve.count,controls.count)
        XCTAssertTrue(curve.allSatisfy { $0.z == 0 && (0...1).contains($0.x) && (0...1).contains($0.y) })
        XCTAssertFalse(curve.contains(controls[1])) // The hard right-angle corner is rounded.
    }
    func testSeparateStrokeAndImageMetadataRoundTripAndLegacyCompatibility() throws {
        let room=Room(project_id:UUID(),name:"Room")
        let a=[Point3(SIMD3<Float>(0,0,0)),Point3(SIMD3(1,0,0))]
        let b=[Point3(SIMD3<Float>(5,5,0)),Point3(SIMD3(6,5,0))]
        var drawing=Annotation(room:room,kind:.line,pose:.identity,points:a,title:"Zeichnung",detail:"")
        drawing.strokes=[a,b]; try drawing.validate(room:room)
        XCTAssertEqual(try JSONDecoder().decode(Annotation.self,from:JSONEncoder().encode(drawing)),drawing)
        drawing.strokes=nil
        let legacy=try JSONDecoder().decode(Annotation.self,from:JSONEncoder().encode(drawing))
        XCTAssertNil(legacy.strokes); XCTAssertNil(legacy.image); try legacy.validate(room:room)
        var image=Annotation(room:room,kind:.image,pose:.identity,points:[Point3(.zero)],title:"Bild",detail:"")
        XCTAssertThrowsError(try image.validate(room:room))
        image.image=SpatialImage(path:"project/room/image.png",width:0.4,height:0.3)
        try image.validate(room:room)
        XCTAssertEqual(try JSONDecoder().decode(Annotation.self,from:JSONEncoder().encode(image)),image)
        image.image?.width = .nan; XCTAssertThrowsError(try image.validate(room:room))
        image.image=SpatialImage(path:"../secret",width:0.4,height:0.3); XCTAssertThrowsError(try image.validate(room:room))
    }
}
