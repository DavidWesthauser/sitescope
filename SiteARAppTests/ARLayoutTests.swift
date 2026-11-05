#if canImport(UIKit) && !canImport(sitescopeCore)
import XCTest
import UIKit
import SwiftUI
import ARKit
import RealityKit
@testable import sitescope

@MainActor final class ARLayoutTests: XCTestCase {
    private func sampleImage() -> UIImage {
        UIGraphicsImageRenderer(size:CGSize(width:160,height:100)).image { c in
            UIColor.systemBlue.setFill(); c.fill(CGRect(x:0,y:0,width:160,height:100))
            UIColor.systemYellow.setFill(); c.fill(CGRect(x:0,y:0,width:80,height:100))
        }
    }
    func testScreenStatesAtCompactSizesAndLargeText() async throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:folder) }
        let store=Store(localURL:folder.appendingPathComponent("local.json"))
        let project=Project(owner_id:store.userID!,name:"Layout fixture")
        var room=Room(project_id:project.id,name:"Ein langer Raumname für die Layoutprüfung")
        room.map_path="test-only.worldmap"
        room.scan_guide_jpeg=sampleImage().jpegData(compressionQuality:0.5)?.base64EncodedString()
        let patch=SurfacePatch(id:UUID(),pose:.identity,vertices:[Point3(.zero),Point3(SIMD3(2,0,0)),Point3(SIMD3(2,0,2))],vertical:false)
        let wallPose=try Pose(simd_float4x4(simd_quatf(angle:-Float.pi/2,axis:SIMD3(1,0,0))))
        let wall=SurfacePatch(id:UUID(),pose:wallPose,vertices:[Point3(.zero),Point3(SIMD3(2,0,0)),Point3(SIMD3(2,0,2.4)),Point3(SIMD3(0,0,2.4))],vertical:true)
        let sidePose=try Pose(simd_float4x4(simd_quatf(angle:Float.pi/2,axis:SIMD3(0,0,1))))
        let side=SurfacePatch(id:UUID(),pose:sidePose,vertices:[Point3(.zero),Point3(SIMD3(2.4,0,0)),Point3(SIMD3(2.4,0,2)),Point3(SIMD3(0,0,2))],vertical:true)
        var ready=ScanProgress(); ready.normalTracking=true; ready.mapReady=true; ready.stableSeconds=3; ready.featureCount=620; ready.surfaces=[patch,wall,side]

        for i in 0..<4 {
            let angle=Float(i)*Float.pi/2+0.2
            for offset in [0.0, 0.75] {
                ready.coverage.observe(position:SIMD3(Float(i)*0.6,0,0),forward:SIMD3(sin(angle),0,cos(angle)),reliable:true,at:Double(i) + offset)
            }
        }
        let configurations:[(String,ARMode)] = [("scan-start",.mapping),("scan-partial",.mapping),("scan-ready",.mapping),("scan-reduced",.mapping),("recognizing",.walkthrough),("tracking-lost",.editing),("draw-editor",.editing),("area-editor",.editing),("image-empty",.editing),("image-loaded",.editing),("worker-aligned",.walkthrough),("recovery",.walkthrough),("motion-limited",.editing),("features-limited",.editing)]
        for (name,mode) in configurations {
            let ar=ARController(room:room,mode:mode)
            if name=="scan-partial" {
                var partial=ready;partial.coverage=ScanCoverage()
                partial.coverage.observe(position:.zero,forward:SIMD3(0,0,1),reliable:true,at:0)
                partial.coverage.observe(position:.zero,forward:SIMD3(0,0,1),reliable:true,at:0.375)
                ar.ready=true;ar.updateTracking(.none);ar.scan=partial;ar.mapped=true
                ar.guidance=partial.coverage.instruction
            }
            if name=="scan-ready" || name=="scan-reduced" {
                ar.scan=ready; ar.trackingNormal=true; ar.mapped=true
                if name=="scan-reduced" { ar.scan.renderingReduced=true;ar.scan.observedSurfaceCount=128 }
            }
            if ["draw-editor","area-editor","image-empty","image-loaded","worker-aligned"].contains(name) {
                ar.trackingNormal=true; ar.localization.propose(.identity,method:.map); ar.confirm()
            }
            if name=="tracking-lost" { ar.localization.lose() }
            if name=="motion-limited" || name=="features-limited" {
                let issue:TrackingIssue=name=="motion-limited" ? .excessiveMotion : .insufficientFeatures
                ar.ready=true;ar.updateTracking(issue);ar.localization.searching();ar.guidance=issue.instruction
            }
            if name=="recognizing" { ar.localization.searching() }
            if name=="area-editor" { ar.tool = .area }
            if name.hasPrefix("image-") { ar.tool = .image }
            if name=="image-loaded" { try await ar.setImage(sampleImage().pngData()!) }
            if name=="recovery" { ar.ready=true;ar.updateTracking(.none);ar.localization.searching();ar.localization.timedOut() } // Search timed out; "Keep searching" path.
            for size in [CGSize(width:375,height:667),CGSize(width:375,height:812)] {
                try await snapshot(AnyView(ARScreen(controller:ar,manager:mode != .walkthrough)),store:store,name:"\(name)-\(Int(size.height))",size:size)
            }
            if ["draw-editor","image-loaded","scan-partial","scan-ready","scan-reduced"].contains(name) {
                try await snapshot(AnyView(ARScreen(controller:ar,manager:true).environment(\.dynamicTypeSize,.accessibility1)),store:store,name:"\(name)-large-text",size:CGSize(width:375,height:667))
            }
            ar.stop()
        }
        let note=Annotation(room:room,kind:.line,pose:.identity,points:[Point3(.zero),Point3(SIMD3(1,0,0))],title:"Eine längere Arbeitsanweisung für die Wand",detail:"Mehrzeilige Beschreibung einer Aufgabe für den Techniker.")
        for manager in [true,false] {
            try await snapshot(AnyView(NavigationStack { TaskEditor(item:note,room:room,manager:manager) }),store:store,name:manager ? "task-manager" : "task-worker",size:CGSize(width:375,height:667))
        }
        try await snapshot(AnyView(DrawingWorkDetails(title:.constant("Eine längere Anweisung"),details:.constant("Mehrzeiliger Inhalt für die Prüfung."),priority:.constant(1))),store:store,name:"work-details-sheet",size:CGSize(width:375,height:667))
        try await snapshot(AnyView(DrawingPlacementSettings(measured:.constant(true),distance:.constant(1.5))),store:store,name:"placement-sheet",size:CGSize(width:375,height:667))
        try await snapshot(AnyView(AuthenticationView()),store:store,name:"login",size:CGSize(width:375,height:667))
        try await snapshot(AnyView(NavigationStack { SettingsView() }),store:store,name:"settings",size:CGSize(width:375,height:667))
        try await snapshot(AnyView(ProjectDashboard()),store:store,name:"empty-projects",size:CGSize(width:375,height:667))
        store.projects=[project];store.rooms=[room]
        var complete=note;complete.id=UUID();complete.status = .completed;complete.title="Finished instruction"
        var active=note;active.id=UUID();active.status = .inProgress;active.priority=2;active.title="High priority instruction"
        store.annotations=[note,complete,active]
        try await snapshot(AnyView(ProjectDashboard()),store:store,name:"populated-projects",size:CGSize(width:375,height:667))
        try await snapshot(AnyView(NavigationStack { ProjectDetail(project:project) }),store:store,name:"project-rooms",size:CGSize(width:375,height:667))
        try await snapshot(AnyView(NavigationStack { RoomDetail(project:project,initialRoom:room) }),store:store,name:"room-progress",size:CGSize(width:375,height:667))
        try await snapshot(AnyView(NavigationStack { RoomDetail(project:project,initialRoom:room) }.environment(\.dynamicTypeSize,.accessibility1)),store:store,name:"room-progress-large-text",size:CGSize(width:375,height:667))
        try await snapshot(AnyView(NavigationStack { TrackingTipsView() }),store:store,name:"tracking-tips",size:CGSize(width:375,height:667))
    }
    func testFinishingAScanIsNotReportedAsRecognition() {
        var room=Room(project_id:UUID(),name:"Fresh scan fixture")
        let ar=ARController(room:room,mode:.mapping)
        XCTAssertFalse(ar.scannedThisSession)
        room.map_path="test-only.worldmap"
        ar.beginEditing(room)
        XCTAssertEqual(ar.mode,.editing)
        XCTAssertTrue(ar.scannedThisSession) // Status reads "Room map saved", not "Room recognized".
        ar.stop()
    }
    func testTrackingLossEndsAnActiveStrokeWithoutDiscardingRoomData() {
        let room=Room(project_id:UUID(),name:"Tracking fixture")
        let ar=ARController(room:room,mode:.editing)
        let item=Annotation(room:room,kind:.line,pose:.identity,points:[Point3(.zero),Point3(SIMD3(1,0,0))],title:"Saved drawing",detail:"")
        ar.annotations=[item];ar.updateTracking(.none);ar.beginStroke()
        XCTAssertTrue(ar.lineDraft.isDrawing)
        ar.updateTracking(.insufficientFeatures)
        XCTAssertFalse(ar.lineDraft.isDrawing);XCTAssertFalse(ar.trackingNormal)
        XCTAssertEqual(ar.annotations,[item]);XCTAssertEqual(ar.trackingIssue,.insufficientFeatures)
        ar.updateTracking(.none)
        XCTAssertTrue(ar.trackingNormal);XCTAssertFalse(ar.lineDraft.isDrawing) // Must start a fresh touch.
        ar.stop()
    }
    func testFailedOrSupersededImageRestoreCannotUseAnOlderDraft() async throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:folder) }
        let store=Store(localURL:folder.appendingPathComponent("local.json"))
        let room=Room(project_id:UUID(),name:"Image fixture")
        let ar=ARController(room:room,mode:.editing)
        let data=try XCTUnwrap(sampleImage().pngData())
        try await ar.setImage(data)
        XCTAssertNotNil(ar.imageData)
        var missing=Annotation(room:room,kind:.image,pose:.identity,title:"Other image",detail:"")
        missing.image=SpatialImage(path:"missing/fixture.png",width:0.4,height:0.25)
        let restore=ar.beginImageRequest(clearExisting:true)
        do { try await ar.restoreImageDraft(missing,store:store,request:restore);XCTFail("Missing image must fail") } catch {}
        XCTAssertNil(ar.imageData);XCTAssertNil(ar.draftImage)
        ar.finishImageRequest(restore);XCTAssertFalse(ar.imageLoading)
        let older=ar.beginImageRequest(),newer=ar.beginImageRequest()
        do { try await ar.setImage(data,request:older);XCTFail("Superseded image must not be applied") } catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        ar.finishImageRequest(older);XCTAssertTrue(ar.imageLoading)
        try await ar.setImage(data,request:newer);ar.finishImageRequest(newer)
        XCTAssertNotNil(ar.imageData);XCTAssertFalse(ar.imageLoading)
        ar.stop()
    }
    func testImageReloadPrunesOldTexturesAndCannotRenderAfterStop() async throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:folder) }
        let store=Store(localURL:folder.appendingPathComponent("local.json"))
        let room=Room(project_id:UUID(),name:"Texture fixture")
        let data=try XCTUnwrap(sampleImage().pngData())
        var items:[Annotation]=[]
        for index in 0..<2 {
            let path="fixture/room/\(index).png"
            try await store.uploadAsset(path:path,data:data,type:"image/png")
            var item=Annotation(room:room,kind:.image,pose:.identity,title:"Image \(index)",detail:"")
            item.image=SpatialImage(path:path,width:0.4,height:0.25);items.append(item)
        }
        let ar=ARController(room:room,mode:.walkthrough)
        ar.trackingNormal=true;ar.localization.propose(.identity,method:.map);ar.confirm()
        await ar.reload(items,store:store);XCTAssertEqual(ar.cachedImageTextureCount,2)
        await ar.reload([items[1]],store:store);XCTAssertEqual(ar.cachedImageTextureCount,1)
        ar.stop();XCTAssertEqual(ar.cachedImageTextureCount,0);XCTAssertTrue(ar.view.scene.anchors.isEmpty)
        await ar.reload(items,store:store)
        XCTAssertEqual(ar.cachedImageTextureCount,0);XCTAssertTrue(ar.view.scene.anchors.isEmpty)
    }
    func testLongScanRenderingAndMemoryFallbackStayBounded() throws {
        let room=Room(project_id:UUID(),name:"Long scan fixture")
        let ar=ARController(room:room,mode:.mapping);ar.trackingNormal=true
        let vertices=(0..<256).map { i -> Point3 in
            let angle=Float(i)*2*Float.pi/256
            return Point3(SIMD3(cos(angle),0,sin(angle)))
        }
        for i in 0..<600 {
            var matrix=matrix_identity_float4x4;matrix.columns.3.x=Float(i)*0.1
            ar.updateSurfacePatch(SurfacePatch(id:UUID(),pose:try Pose(matrix),vertices:vertices,vertical:false))
        }
        XCTAssertEqual(ar.cachedSurfaceCount,128)
        ar.renderScanSurfaces()
        XCTAssertEqual(ar.view.scene.anchors.count,24)
        XCTAssertEqual(ar.view.scene.anchors.reduce(0,{$0+$1.children.count}),48)
        let instruction=Annotation(room:room,kind:.line,pose:.identity,points:[Point3(.zero),Point3(SIMD3(1,0,0))],title:"Keep this drawing",detail:"")
        ar.annotations=[instruction]
        var distantPose=matrix_identity_float4x4;distantPose.columns.3.x=1000
        let targetID=UUID(),pose=try Pose(distantPose)
        ar.updateSurfacePatch(SurfacePatch(id:targetID,pose:pose,vertices:vertices,vertical:false)) // Excluded from the nearest metadata cache.
        XCTAssertEqual(ar.cachedSurfaceCount,128)
        XCTAssertFalse(ar.placementSurfaceIsReady(id:targetID,pose:pose,at:0))
        XCTAssertTrue(ar.placementSurfaceIsReady(id:targetID,pose:pose,at:0.7))
        ar.reduceScanLoad()
        XCTAssertTrue(ar.view.scene.anchors.isEmpty);XCTAssertTrue(ar.renderingReduced)
        XCTAssertEqual(ar.annotations,[instruction]);XCTAssertEqual(ar.cachedSurfaceCount,128)
        ar.renderScanSurfaces()
        XCTAssertEqual(ar.view.scene.anchors.count,12)
        XCTAssertEqual(ar.view.scene.anchors.reduce(0,{$0+$1.children.count}),12)
        ar.stop()
    }
    func testMiniatureRendersWithoutAnAnimationClock() throws {
        let patch=SurfacePatch(id:UUID(),pose:.identity,vertices:[Point3(.zero),Point3(SIMD3(2,0,0)),Point3(SIMD3(2,0,2)),Point3(SIMD3(0,0,2))],vertical:false)
        let renderer=ImageRenderer(content:ScanMiniature(surfaces:[patch],yaw:0).frame(width:220,height:220).background(.black))
        renderer.scale=1
        let image=try XCTUnwrap(renderer.uiImage?.cgImage)
        let bytesPerRow=image.width*4
        var pixels=[UInt8](repeating:0,count:image.height*bytesPerRow)
        let count=pixels.withUnsafeMutableBytes { buffer -> Int in
            guard let context=CGContext(data:buffer.baseAddress,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:bytesPerRow,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
            context.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))
            let bytes=buffer.bindMemory(to:UInt8.self)
            return stride(from:0,to:bytes.count,by:4).filter { bytes[$0]>100 && bytes[$0+1]>100 && bytes[$0+2]>100 }.count
        }
        XCTAssertGreaterThan(count,1000,"Observed geometry must be visible before any animation tick")
    }
    func testLostTrackingAndInvalidRefinementDiscardPlacementEvidence() throws {
        let room=Room(project_id:UUID(),name:"Placement recovery fixture")
        let ar=ARController(room:room,mode:.mapping)
        ar.updateTracking(.none)
        var patch=SurfacePatch(id:UUID(),pose:.identity,vertices:[Point3(.zero),Point3(SIMD3(1,0,0)),Point3(SIMD3(1,0,1))],vertical:false)
        ar.updateSurfacePatch(patch);ar.renderScanSurfaces();ar.scan.surfaces=[patch]
        XCTAssertFalse(ar.placementSurfaceIsReady(id:patch.id,pose:.identity,at:0))
        XCTAssertTrue(ar.placementSurfaceIsReady(id:patch.id,pose:.identity,at:0.7))
        ar.updateTracking(.excessiveMotion);ar.updateTracking(.none)
        XCTAssertFalse(ar.placementSurfaceIsReady(id:patch.id,pose:.identity,at:0.8))
        XCTAssertTrue(ar.placementSurfaceIsReady(id:patch.id,pose:.identity,at:1.5))
        patch.vertices=[];ar.updateSurfacePatch(patch)
        XCTAssertEqual(ar.cachedSurfaceCount,0);XCTAssertTrue(ar.view.scene.anchors.isEmpty)
        XCTAssertTrue(ar.scan.surfaces.isEmpty)
        XCTAssertFalse(ar.placementSurfaceIsReady(id:patch.id,pose:.identity,at:1.6))
        ar.stop()
    }
    func testRemovingSavedRoomAnchorHidesInstructions() {
        let room=Room(project_id:UUID(),name:"Anchor loss fixture")
        let ar=ARController(room:room,mode:.walkthrough)
        ar.updateTracking(.none)
        ar.annotations=[Annotation(room:room,kind:.text,pose:.identity,title:"Wall instruction",detail:"")]
        ar.localization.propose(.identity,method:.map);ar.confirm()
        XCTAssertFalse(ar.view.scene.anchors.isEmpty)
        let sentinel=ARAnchor(name:"sitescope.room.\(room.coordinate_id.uuidString)",transform:matrix_identity_float4x4)
        ar.session(ar.view.session,didRemove:[sentinel])
        XCTAssertNil(ar.localization.roomToSession);XCTAssertTrue(ar.view.scene.anchors.isEmpty)
        ar.stop()
    }
    func testSurfaceOutlineKeepsAnchorAcrossRefinements() async throws {
        let room=Room(project_id:UUID(),name:"Test-only scan renderer")
        let ar=ARController(room:room,mode:.mapping);ar.trackingNormal=true
        var patch=SurfacePatch(id:UUID(),pose:.identity,vertices:[Point3(.zero),Point3(SIMD3(1,0,0)),Point3(SIMD3(1,0,1)),Point3(SIMD3(0,0,1))],vertical:false)
        ar.updateSurfacePatch(patch);ar.renderScanSurfaces()
        let root=try XCTUnwrap(ar.view.scene.anchors.first)
        XCTAssertEqual(root.children.count,2) // One batched outline plus one halo, regardless of edge count.
        ar.updateSurfacePatch(patch);ar.renderScanSurfaces()
        XCTAssertTrue(root === ar.view.scene.anchors.first)
        try await Task.sleep(for:.milliseconds(720))
        patch.vertices[1]=Point3(SIMD3(2,0,0));patch.vertices[2]=Point3(SIMD3(2,0,1))
        ar.updateSurfacePatch(patch);ar.renderScanSurfaces()
        XCTAssertEqual(ar.view.scene.anchors.count,1)
        XCTAssertTrue(root === ar.view.scene.anchors.first)
        let edge=try XCTUnwrap(root.findEntity(named:"edge"))
        XCTAssertEqual(edge.visualBounds(relativeTo:root).extents.x,2,accuracy:0.01)
        patch.vertices=[Point3(.zero),Point3(SIMD3(1,0,0)),Point3(SIMD3(2,0,0))]
        ar.updateSurfacePatch(patch);ar.renderScanSurfaces()
        XCTAssertTrue(root.children.isEmpty) // Invalid refinement cannot leave a stale valid outline.
        ar.showSurfaceGuides=false;XCTAssertFalse(root.isEnabled)
        ar.stop();XCTAssertTrue(ar.view.scene.anchors.isEmpty)
    }
    func testImageTexturesStayWithinBudgetAndOverflowShowsOutlines() async throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:folder) }
        let store=Store(localURL:folder.appendingPathComponent("local.json"))
        let room=Room(project_id:UUID(),name:"Texture budget fixture")
        let data=try XCTUnwrap(sampleImage().pngData())
        let total=ARController.maximumImageTextures+3
        var items:[Annotation]=[]
        for index in 0..<total {
            let path="fixture/room/\(String(format:"%03d",index)).png"
            try await store.uploadAsset(path:path,data:data,type:"image/png")
            var item=Annotation(room:room,kind:.image,pose:.identity,title:"Image \(index)",detail:"")
            item.image=SpatialImage(path:path,width:0.4,height:0.25);items.append(item)
        }
        let ar=ARController(room:room,mode:.walkthrough)
        ar.trackingNormal=true;ar.localization.propose(.identity,method:.map);ar.confirm()
        await ar.reload(items,store:store)
        XCTAssertEqual(ar.cachedImageTextureCount,ARController.maximumImageTextures);XCTAssertEqual(ar.hiddenImageCount,3)
        let content=try XCTUnwrap(ar.view.scene.anchors.first)
        XCTAssertEqual(content.children.count,total) // Every instruction is still placed; overflow renders as an outline.
        XCTAssertTrue(content.children.allSatisfy { !$0.children.isEmpty })
        await ar.reload(Array(items.prefix(2)),store:store);XCTAssertEqual(ar.hiddenImageCount,0)
        ar.stop()
    }
    func testRecoveredDrawingsReuseTheirBuiltScene() throws {
        let room=Room(project_id:UUID(),name:"Render cache fixture")
        let ar=ARController(room:room,mode:.walkthrough)
        ar.updateTracking(.none)
        ar.annotations=[Annotation(room:room,kind:.text,pose:.identity,title:"Wall instruction",detail:"")]
        ar.localization.propose(.identity,method:.map);ar.confirm()
        let built=try XCTUnwrap(ar.view.scene.anchors.first)
        let sentinel=ARAnchor(name:"sitescope.room.\(room.coordinate_id.uuidString)",transform:matrix_identity_float4x4)
        ar.session(ar.view.session,didRemove:[sentinel])
        XCTAssertTrue(ar.view.scene.anchors.isEmpty)
        ar.localization.propose(.identity,method:.map);ar.confirm()
        XCTAssertTrue(ar.view.scene.anchors.first === built) // Recovery re-attaches; no mesh regeneration.
        ar.annotations.append(Annotation(room:room,kind:.text,pose:.identity,title:"Second instruction",detail:""));ar.render()
        XCTAssertEqual(ar.view.scene.anchors.count,1);XCTAssertFalse(ar.view.scene.anchors.first === built)
        ar.stop()
    }
    func testOutlineRefinementsAreSpreadAcrossTicks() throws {
        let room=Room(project_id:UUID(),name:"Refinement budget fixture")
        let ar=ARController(room:room,mode:.mapping);ar.trackingNormal=true
        func square(_ size:Float) -> [Point3] { [Point3(.zero),Point3(SIMD3(size,0,0)),Point3(SIMD3(size,0,1)),Point3(SIMD3(0,0,1))] }
        var patches=try (0..<10).map { i -> SurfacePatch in
            var matrix=matrix_identity_float4x4;matrix.columns.3.x=Float(i)*3
            return SurfacePatch(id:UUID(),pose:try Pose(matrix),vertices:square(1),vertical:false)
        }
        patches.forEach(ar.updateSurfacePatch);ar.renderScanSurfaces()
        XCTAssertEqual(ar.view.scene.anchors.count,10) // New outlines are never deferred.
        func widened() -> Int { ar.view.scene.anchors.filter { ($0.findEntity(named:"edge")?.visualBounds(relativeTo:$0).extents.x ?? 0)>1.5 }.count }
        for i in patches.indices { patches[i].vertices[1].x+=0.004 };patches.forEach(ar.updateSurfacePatch);ar.renderScanSurfaces()
        XCTAssertEqual(widened(),0) // Sub-centimetre jitter keeps the existing meshes.
        for i in patches.indices { patches[i].vertices=square(2) };patches.forEach(ar.updateSurfacePatch)
        ar.renderScanSurfaces();XCTAssertEqual(widened(),4)
        ar.renderScanSurfaces();ar.renderScanSurfaces();XCTAssertEqual(widened(),10)
        ar.stop()
    }
    func testSmoothSeparatedStrokeAndImageRendering() async throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:folder) }
        let url=folder.appendingPathComponent("local.json")
        let store=Store(localURL:url)
        try await store.createProject(name:"Storage fixture")
        let project=try XCTUnwrap(store.projects.first)
        try await store.createRoom(in:project,name:"Rendering fixture")
        var room=try XCTUnwrap(store.rooms.first); room.map_path="test-only.worldmap"
        try await store.publishRoom(room)
        let ar=ARController(room:room,mode:.walkthrough); ar.trackingNormal=true
        let a=[Point3(SIMD3<Float>(0,0,0)),Point3(SIMD3(0.3,0,0)),Point3(SIMD3(0.4,0.3,0))]
        let b=[Point3(SIMD3<Float>(2,2,0)),Point3(SIMD3(2.5,2,0))]
        var drawing=Annotation(room:room,kind:.line,pose:.identity,points:a,title:"Zeichnung",detail:""); drawing.strokes=[a,b]
        try await ar.setImage(sampleImage().pngData()!)
        let path="\(project.id.uuidString.lowercased())/\(room.id.uuidString.lowercased())/fixture.png"
        let bytes=try XCTUnwrap(ar.imageData); try await store.uploadAsset(path:path,data:bytes,type:"image/png")
        var image=Annotation(room:room,kind:.image,pose:.identity,points:[Point3(.zero)],title:"Bild",detail:"")
        image.image=SpatialImage(path:path,width:0.4,height:0.25)
        try await store.saveInstruction(image,room:room,replacing:false)
        try await store.saveInstruction(drawing,room:room,replacing:false)
        let reopened=Store(localURL:url)
        XCTAssertEqual(reopened.annotations.first(where:{$0.id==image.id}),image)
        XCTAssertEqual(reopened.annotations.first(where:{$0.id==drawing.id})?.strokes?.count,2)
        let restoredBytes=try await reopened.downloadAsset(path:path)
        XCTAssertEqual(restoredBytes,bytes)
        let restored=try await SpatialImageAsset.prepare(restoredBytes)
        XCTAssertEqual(restored.image.size,ar.draftImage?.size)
        ar.localization.propose(.identity,method:.map); ar.confirm()
        await ar.reload([drawing,image],store:store)
        let roots=ar.view.scene.anchors.flatMap { Array($0.children) }
        XCTAssertEqual(roots.first(where:{$0.name==drawing.id.uuidString})?.children.count,2) // Two disconnected tube meshes.
        XCTAssertEqual(roots.first(where:{$0.name==image.id.uuidString})?.children.count,1) // One textured image, no pin.
        XCTAssertNotNil(ar.imageData); XCTAssertNotNil(ar.draftImage)
        ar.stop()
    }
    private func snapshot(_ content:AnyView,store:Store,name:String,size:CGSize) async throws {
        let host=UIHostingController(rootView:content.environmentObject(store))
        let window=UIWindow(frame:CGRect(origin:.zero,size:size))
        if let scene=UIApplication.shared.connectedScenes.first as? UIWindowScene { window.windowScene=scene }
        window.frame=CGRect(origin:.zero,size:size); window.rootViewController=host; window.makeKeyAndVisible()
        defer { window.isHidden=true; window.rootViewController=nil }
        host.view.frame=window.bounds; host.view.setNeedsLayout(); host.view.layoutIfNeeded()
        try await Task.sleep(for:.milliseconds(name.hasPrefix("scan-") ? 650 : 180))
        XCTAssertFalse(host.view.hasAmbiguousLayout,name)
        XCTAssertEqual(host.view.bounds.width,size.width,accuracy:1,name)
        let image=UIGraphicsImageRenderer(size:size).image { _ in host.view.drawHierarchy(in:CGRect(origin:.zero,size:size),afterScreenUpdates:true) }
        if name.hasPrefix("scan-partial"),let cg=image.cgImage {
            let width=Int(size.width),height=Int(size.height)
            var bytes=[UInt8](repeating:0,count:width*height*4)
            let visible=bytes.withUnsafeMutableBytes { buffer -> Int in
                guard let context=CGContext(data:buffer.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
                context.draw(cg,in:CGRect(origin:.zero,size:size))
                let pixels=buffer.bindMemory(to:UInt8.self)
                return stride(from:(height/2)*width*4,to:pixels.count,by:4).filter { pixels[$0]>120 && pixels[$0+1]>120 && pixels[$0+2]>120 }.count
            }
            XCTAssertGreaterThan(visible,500,"Partial-scan miniature and lower controls must stay visible: \(name)")
        }
        let attachment=XCTAttachment(image:image); attachment.name=name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
#endif
