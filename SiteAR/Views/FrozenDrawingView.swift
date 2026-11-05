import SwiftUI
import simd
import CoreImage.CIFilterBuiltins

/// An editing snapshot of the actual camera view. Gestures still produce room-space 3D geometry.
struct FrozenDrawingView: View {
    @ObservedObject var ar: ARController
    let frame: FrozenDrawingFrame
    private static let imageContext=CIContext(options:[.cacheIntermediates:false])
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(uiImage: frame.image).resizable().scaledToFill().frame(width:geometry.size.width,height:geometry.size.height).clipped()
                Canvas { context,size in
                    func project(_ point: SIMD3<Float>) -> CGPoint? {
                        let world = (frame.sessionFromRoom.matrix*SIMD4(point,1)).xyz
                        guard let p = DrawingGeometry.project(world,viewProjection:frame.viewProjection) else { return nil }
                        return CGPoint(x:CGFloat(p.x)*size.width,y:CGFloat(p.y)*size.height)
                    }
                    let p = ar.draft.compactMap { project($0.vector) }
                    guard let first = p.first else { return }
                    switch ar.tool {
                    case .text:
                        context.draw(Text(ar.draftText.isEmpty ? "Text" : ar.draftText).font(.system(size:22,weight:.semibold)).foregroundStyle(.orange),at:first,anchor:.topLeading)
                    case .marker:
                        context.stroke(Path(ellipseIn:CGRect(x:first.x-7,y:first.y-7,width:14,height:14)),with:.color(.orange),lineWidth:3)
                    case .arrow:
                        guard let tail=ar.draft.first, let tip=ar.draft.last, ar.draft.count>=2,
                              let arrow=DrawingGeometry.arrow(tail:tail.vector,tip:tip.vector,normal:ar.drawingPlane?.matrix.columns.2.xyz ?? SIMD3(0,0,1)),
                              let tipPoint=project(arrow.tip),let left=project(arrow.left),let right=project(arrow.right),let base=project((arrow.left+arrow.right)/2) else { return }
                        var shaft=Path(); shaft.move(to:first); shaft.addLine(to:base)
                        context.stroke(shaft,with:.color(.orange),style:StrokeStyle(lineWidth:4,lineCap:.round))
                        var head=Path(); head.addLines([tipPoint,left,right]); head.closeSubpath(); context.fill(head,with:.color(.orange))
                    case .line:
                        for stroke in ar.lineDraft.strokes where stroke.count>=2 {
                            var path=Path(); path.addLines(DrawingGeometry.smoothStroke(stroke).compactMap { project($0.vector) })
                            context.stroke(path,with:.color(.orange),style:StrokeStyle(lineWidth:3,lineCap:.round,lineJoin:.round))
                        }
                    case .area:
                        var path=Path(); path.addLines(p); if p.count>=3 { path.closeSubpath() }
                        context.stroke(path,with:.color(.orange),style:StrokeStyle(lineWidth:3,lineCap:.round,lineJoin:.round))
                    case .image:
                        guard let cg=ar.draftImage?.cgImage,let point=ar.draft.first else { return }
                        var pose=ar.drawingPlane?.matrix ?? matrix_identity_float4x4; pose.columns.3=SIMD4(point.vector,1)
                        let w=ar.imageWidth/2,h=ar.imageHeight/2
                        let corners=[SIMD3(-w,h,0),SIMD3(w,h,0),SIMD3(w,-h,0),SIMD3(-w,-h,0)].compactMap { project((pose*SIMD4($0,1)).xyz) }
                        guard corners.count==4 else { return }
                        let filter=CIFilter.perspectiveTransform(); filter.inputImage=CIImage(cgImage:cg)
                        func vector(_ p:CGPoint)->CGPoint { CGPoint(x:p.x,y:size.height-p.y) }
                        filter.topLeft=vector(corners[0]); filter.topRight=vector(corners[1]); filter.bottomRight=vector(corners[2]); filter.bottomLeft=vector(corners[3])
                        let bounds=CGRect(origin:.zero,size:size)
                        if let output=filter.outputImage,let result=Self.imageContext.createCGImage(output,from:bounds) {
                            context.draw(Image(decorative:result,scale:1),in:bounds)
                        }
                    }
                }
            }.contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance:0).onChanged { value in
                    if ar.tool == .line || ar.tool == .arrow { ar.beginStroke(); capture(value.location,in:geometry.size) }
                }.onEnded { value in capture(value.location,in:geometry.size); ar.endStroke() })
                .onDisappear { ar.endStroke() }
        }
    }
    private func capture(_ point: CGPoint,in size: CGSize) {
        guard size.width>0,size.height>0 else { return }
        ar.captureScreenPoint(CGPoint(x:point.x*frame.viewport.width/size.width,y:point.y*frame.viewport.height/size.height),reportMiss:false)
    }
}
