import ARKit
import RealityKit
import UIKit
import simd

/// RealityKit entities for saved instructions and the draft preview. Every overlay is unlit.
extension ARController {
    func clearVisuals() {
        for anchor in [content, preview].compactMap({ $0 }) { view.scene.removeAnchor(anchor) }
        content = nil; preview = nil
    }
    private func dot(_ position: SIMD3<Float>, color: UIColor, radius: Float = 0.035) -> ModelEntity {
        // Unlit like every other overlay: readable in any room lighting and no lighting cost.
        let model = ModelEntity(mesh: .generateSphere(radius: radius), materials: [UnlitMaterial(color: color)])
        model.position = position; return model
    }
    private func label(_ text: String, at point: SIMD3<Float>, color: UIColor) -> ModelEntity {
        let mesh = MeshResource.generateText(String(text.prefix(240)), extrusionDepth: 0.001, font: .systemFont(ofSize: 0.045), containerFrame: CGRect(x: 0,y: 0,width: 0.7,height: 0.6), alignment: .left, lineBreakMode: .byWordWrapping)
        let model = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: color)])
        model.position = point + SIMD3(0.05,0.04,0); return model
    }
    func renderDraft(throttled: Bool=false) {
        let now=CACurrentMediaTime()
        if throttled && now-lastDraftRender<1.0/30 { return }; lastDraftRender=now
        // Mid-stroke, finished strokes are unchanged: only re-mesh the stroke under the finger.
        if throttled, tool == .line, let preview, lineDraft.isDrawing, let live=lineDraft.strokes.last {
            preview.findEntity(named:"live")?.removeFromParent()
            addSmoothStroke(live,normal:drawingPlane?.matrix.columns.2.xyz ?? SIMD3(0,0,1),to:preview,color:.systemOrange,name:"live")
            return
        }
        if let preview { view.scene.removeAnchor(preview) }; preview=nil
        guard let alignment=localization.roomToSession, let first=draft.first else { return }
        let anchor=AnchorEntity(world:alignment.matrix)
        switch tool {
        case .line:
            for (index,path) in lineDraft.strokes.enumerated() where path.count>=2 {
                let live=lineDraft.isDrawing && index == lineDraft.strokes.count-1
                addSmoothStroke(path,normal:drawingPlane?.matrix.columns.2.xyz ?? SIMD3(0,0,1),to:anchor,color:.systemOrange,name:live ? "live" : "")
            }
        case .area:
            for (a,b) in zip(draft,draft.dropFirst()) { addSegment(a.vector,b.vector,to:anchor,color:.systemOrange) }
            if draft.count>=3,let last=draft.last { addSegment(last.vector,first.vector,to:anchor,color:.systemOrange) }
        case .image:
            if let texture=draftImageTexture {
                let root=Entity(); var pose=drawingPlane?.matrix ?? matrix_identity_float4x4; pose.columns.3=SIMD4(first.vector,1)
                root.transform=Transform(matrix:pose); addImage(texture,width:imageWidth,height:imageHeight,to:root); anchor.addChild(root)
            }
        case .arrow:
            if let last=draft.last,draft.count>=2 { addArrow(first.vector,last.vector,normal:drawingPlane?.matrix.columns.2.xyz ?? SIMD3(0,0,1),to:anchor,color:.systemOrange) }
        case .marker: anchor.addChild(dot(first.vector,color:.systemOrange,radius:0.025))
        case .text:
            let text=Entity(); var pose=drawingPlane?.matrix ?? matrix_identity_float4x4; pose.columns.3=SIMD4(first.vector,1)
            text.transform=Transform(matrix:pose); text.addChild(label(draftText.isEmpty ? "Text" : draftText,at:.zero,color:.systemOrange)); anchor.addChild(text)
        }
        preview=anchor; view.scene.addAnchor(anchor)
    }
    func render() {
        guard !stopped else { return }
        if let content { view.scene.removeAnchor(content) }; content = nil
        guard let alignment = localization.roomToSession, trackingNormal else { return }
        // Text meshes and collision shapes are expensive. Re-attach the last build when nothing changed,
        // so recovering tracking does not hitch at the moment drawings reappear.
        let key = RenderedContent.Key(annotations: annotations, textures: Set(imageTextures.keys), alignment: alignment)
        if let renderedContent, renderedContent.key == key {
            content = renderedContent.anchor; view.scene.addAnchor(renderedContent.anchor); return
        }
        let anchor = AnchorEntity(world: alignment.matrix)
        for item in annotations {
            let root = Entity(); root.name = item.id.uuidString; root.transform = Transform(matrix: item.pose.matrix)
            let color: UIColor = item.status == .completed ? .systemGreen : .systemCyan
            if item.kind == .marker { root.addChild(dot(.zero,color:color,radius:0.025)) }
            if item.kind == .text || !["Drawing","Zeichnung","Area marking","Fläche","Bild","Image"].contains(item.title) { root.addChild(label(item.title,at:.zero,color:color)) }
            let p = item.points.map(\.vector)
            if item.kind == .arrow, let first = p.first, let last = p.last, p.count>=2 {
                addArrow(first,last,normal:SIMD3(0,0,1),to:root,color:color)
            } else if item.kind == .image,let image=item.image {
                if let texture=imageTextures[image.path] { addImage(texture,width:image.width,height:image.height,to:root) }
                else { addImageOutline(width:image.width,height:image.height,to:root,color:color) } // Loading or over the texture budget.
            } else if item.kind == .line {
                for path in item.strokes ?? [item.points] { addSmoothStroke(path,normal:SIMD3(0,0,1),to:root,color:color) }
            } else if item.kind == .area,p.count>=2 {
                for (a,b) in zip(p,p.dropFirst()) { addSegment(a,b,to:root,color:color) }
                if item.kind == .area, let last = p.last, let first = p.first { addSegment(last,first,to:root,color:color) }
            }
            root.generateCollisionShapes(recursive: true); anchor.addChild(root)
        }
        content = anchor; view.scene.addAnchor(anchor); renderedContent = RenderedContent(key: key, anchor: anchor)
    }
    private func addSegment(_ a: SIMD3<Float>, _ b: SIMD3<Float>, to entity: Entity, color: UIColor, thickness: Float = 0.008) {
        let length = simd_distance(a,b); guard length > 0.002 else { return }
        let segment = ModelEntity(mesh: .generateBox(size: SIMD3(thickness,thickness,length)), materials: [UnlitMaterial(color: color)])
        segment.position = (a+b)/2; segment.orientation = simd_quatf(from: SIMD3(0,0,1), to: (b-a)/length); entity.addChild(segment)
    }
    private func addSmoothStroke(_ controls:[Point3],normal:SIMD3<Float>,to entity:Entity,color:UIColor,name:String="") {
        let p=DrawingGeometry.smoothStroke(controls).map(\.vector)
        guard p.count>=2 else { return }
        let sides=8, radius:Float=0.0035
        var vertices:[SIMD3<Float>]=[],indices:[UInt32]=[]
        for i in p.indices {
            var tangent=p[min(i+1,p.count-1)]-p[max(i-1,0)]
            if simd_length(tangent)<0.00001 { tangent=i>0 ? p[i]-p[i-1] : p[1]-p[0] }
            guard simd_length(tangent)>0.00001 else { return }
            tangent=simd_normalize(tangent)
            var side=simd_cross(normal,tangent)
            if simd_length(side)<0.001 { side=simd_cross(abs(tangent.x)<0.9 ? SIMD3(1,0,0) : SIMD3(0,1,0),tangent) }
            side=simd_normalize(side); let up=simd_normalize(simd_cross(tangent,side))
            for j in 0..<sides { let a=Float(j)*2*Float.pi/Float(sides); vertices.append(p[i]+radius*(cos(a)*side+sin(a)*up)) }
        }
        for i in 0..<(p.count-1) { for j in 0..<sides {
            let a=UInt32(i*sides+j),b=UInt32(i*sides+(j+1)%sides),c=a+UInt32(sides),d=b+UInt32(sides)
            indices += [a,b,c,b,d,c]
        } }
        let start=UInt32(vertices.count); vertices.append(p[0]); let end=UInt32(vertices.count); vertices.append(p[p.count-1])
        for j in 0..<sides { indices += [start,UInt32((j+1)%sides),UInt32(j),end,UInt32((p.count-1)*sides+j),UInt32((p.count-1)*sides+(j+1)%sides)] }
        var descriptor=MeshDescriptor(name:"Smooth independent stroke"); descriptor.positions=MeshBuffers.Positions(vertices); descriptor.primitives = .triangles(indices)
        if let mesh=try? MeshResource.generate(from:[descriptor]) {
            let model=ModelEntity(mesh:mesh,materials:[UnlitMaterial(color:color)]); model.name=name; entity.addChild(model)
        }
    }
    private func addImageOutline(width:Float,height:Float,to entity:Entity,color:UIColor) {
        let w=width/2,h=height/2
        let corners=[SIMD3<Float>(-w,-h,0.002),SIMD3(w,-h,0.002),SIMD3(w,h,0.002),SIMD3(-w,h,0.002)]
        for (a,b) in zip(corners,corners.dropFirst()+[corners[0]]) { addSegment(a,b,to:entity,color:color,thickness:0.006) }
    }
    private func addImage(_ texture:TextureResource,width:Float,height:Float,to entity:Entity) {
        var descriptor=MeshDescriptor(name:"Spatial image")
        descriptor.positions=MeshBuffers.Positions([SIMD3(-width/2,-height/2,0.002),SIMD3(width/2,-height/2,0.002),SIMD3(width/2,height/2,0.002),SIMD3(-width/2,height/2,0.002)])
        descriptor.textureCoordinates=MeshBuffers.TextureCoordinates([SIMD2(0,1),SIMD2(1,1),SIMD2(1,0),SIMD2(0,0)])
        descriptor.primitives = .triangles([0,1,2,0,2,3,0,2,1,0,3,2])
        var material=UnlitMaterial(); material.color = .init(tint:.white,texture:.init(texture)); material.blending = .transparent(opacity:.init(floatLiteral:1))
        if let mesh=try? MeshResource.generate(from:[descriptor]) { entity.addChild(ModelEntity(mesh:mesh,materials:[material])) }
    }
    private func addArrow(_ tail: SIMD3<Float>, _ tip: SIMD3<Float>, normal: SIMD3<Float>, to entity: Entity, color: UIColor) {
        let delta = tip-tail
        let normal = simd_length(simd_cross(normal,delta))<0.001 ? SIMD3<Float>(0,1,0) : normal
        guard let arrow = DrawingGeometry.arrow(tail:tail,tip:tip,normal:normal) else { return }
        let base = (arrow.left+arrow.right)/2
        addSegment(tail,base,to:entity,color:color,thickness:0.012)
        var descriptor = MeshDescriptor(name:"Arrowhead")
        descriptor.positions = MeshBuffers.Positions([arrow.tip,arrow.left,arrow.right])
        descriptor.primitives = .triangles([0,1,2,0,2,1])
        if let mesh = try? MeshResource.generate(from:[descriptor]) { entity.addChild(ModelEntity(mesh:mesh,materials:[UnlitMaterial(color:color)])) }
    }
}
