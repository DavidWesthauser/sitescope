import SwiftUI
import simd

/// A budgeted projection of observed patches. Geometry is cached between AR updates.
struct ScanMiniature: View {
    let surfaces:[SurfacePatch]
    let yaw:Float
    var reducedDetail=false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entries:[UUID:Entry]=[:]
    @State private var shownYaw:Float=0
    @State private var yawFrom:Float=0
    @State private var yawStart=Date.distantPast
    @State private var animating=false
    @State private var revision=0
    @State private var model:[SurfacePatch]=[]
    @State private var modelInitialized=false
    @State private var modelSource:[SurfacePatch]=[]
    @State private var sourceBudget=0
    struct Entry {
        var patch:SurfacePatch
        var from:[SIMD3<Float>]
        var target:[SIMD3<Float>]
        var start:Date
        var birth:Date
        func points(at date:Date,reduced:Bool) -> [SIMD3<Float>] {
            guard !reduced,from.count==target.count else { return target }
            let t=min(1,max(0,Float(date.timeIntervalSince(start))/0.3)),eased=t*t*(3-2*t)
            return zip(from,target).map { $0+($1-$0)*eased }
        }
    }
    private struct Face {
        var points:[CGPoint]
        var depth:Float
        var shade:Float
        var alpha:Double
    }
    var body: some View {
        TimelineView(.animation(minimumInterval:ScanVisualization.animationFrameInterval,paused:reduceMotion || reducedDetail || !animating)) { tick in
            Canvas { context,size in
                let now=tick.date,reduced=reduceMotion || reducedDetail
                let t=reduced ? Float(1) : min(1,max(0,Float(now.timeIntervalSince(yawStart))/0.35))
                let rotation=yawFrom+(shownYaw-yawFrom)*t+0.7,c=cos(rotation),s=sin(rotation)
                let visible=(modelInitialized ? model : RoomSurfaceModel.consolidate(surfaces,maximum:reducedDetail ? 12 : 24)).map { patch in
                    entries[patch.id] ?? entry(patch,at:.distantPast)
                }
                var faces:[Face]=[]
                var minX=CGFloat.infinity,minY=CGFloat.infinity,maxX = -CGFloat.infinity,maxY = -CGFloat.infinity
                for item in visible {
                    let p=item.points(at:now,reduced:reduced)
                    guard !p.isEmpty else { continue }
                    let alpha=reduced ? 1 : min(1,max(0,now.timeIntervalSince(item.birth)/0.55))
                    let center=p.reduce(SIMD3<Float>.zero,+)/Float(p.count)
                    let grown=p.map { center+($0-center)*Float(0.9+0.1*alpha) }
                    for face in ScanVisualization.faces(item.patch,vertices:grown) {
                        var points:[CGPoint]=[],depth:Float=0
                        for v in face.vertices {
                            let x=c*v.x-s*v.z,z=s*v.x+c*v.z
                            let point=CGPoint(x:Double(x),y:Double(-v.y*0.85+z*0.5))
                            points.append(point);depth += z*0.85+v.y*0.5
                            minX=min(minX,point.x);maxX=max(maxX,point.x);minY=min(minY,point.y);maxY=max(maxY,point.y)
                        }
                        faces.append(Face(points:points,depth:depth/Float(max(1,points.count)),shade:face.shade,alpha:alpha))
                    }
                }
                guard minX.isFinite,minY.isFinite else { return }
                let scale=min((size.width-24)/max(0.2,maxX-minX),(size.height-24)/max(0.2,maxY-minY))
                func fit(_ p:CGPoint) -> CGPoint { CGPoint(x:(p.x-(minX+maxX)/2)*scale+size.width/2,y:(p.y-(minY+maxY)/2)*scale+size.height/2) }
                for face in faces.sorted(by:{$0.depth<$1.depth}) {
                    var path=Path();path.addLines(face.points.map(fit));path.closeSubpath()
                    context.fill(path,with:.color(Color(white:Double(face.shade)).opacity(face.alpha)))
                    context.stroke(path,with:.color(.white.opacity(0.65*face.alpha)),lineWidth:0.7)
                }
            }
        }
        .onAppear { update(surfaces,animate:false);shownYaw = -yaw;yawFrom = -yaw }
        .onChange(of:surfaces) { _,value in update(value) }
        .onChange(of:reducedDetail) { _,_ in update(surfaces,animate:false) }
        .onChange(of:yaw) { _,value in
            let target=ScanVisualization.shortAngle(from:shownYaw,to:-value)
            guard abs(target-shownYaw)>0.02 else { return }
            let now=Date(),t=min(1,max(0,Float(now.timeIntervalSince(yawStart))/0.35))
            yawFrom=yawFrom+(shownYaw-yawFrom)*t;shownYaw=target;yawStart=now
            if !reduceMotion && !reducedDetail { animating=true;revision += 1 }
        }
        .task(id:revision) {
            guard animating else { return }
            do { try await Task.sleep(for:.milliseconds(650)) } catch { return }
            animating=false
        }
        .accessibilityLabel("Live model of detected surfaces")
    }
    private func entry(_ input:SurfacePatch,at date:Date) -> Entry {
        var patch=input;patch.vertices=ScanRenderingBudget.displayBoundary(input.vertices,maximum:12)
        let points=patch.worldVertices
        return Entry(patch:patch,from:points,target:points,start:date,birth:date)
    }
    private func update(_ surfaces:[SurfacePatch],animate:Bool=true) {
        let maximum=reducedDetail ? 12 : 24
        let source=surfaces.prefix(24).sorted { $0.id.uuidString<$1.id.uuidString }
        guard !modelInitialized || modelSource != source || sourceBudget != maximum else { return }
        modelSource=source;sourceBudget=maximum
        let now=Date(),selected=RoomSurfaceModel.consolidate(source,maximum:maximum),ids=Set(selected.map(\.id))
        if model != selected { model=selected };modelInitialized=true
        entries=entries.filter { ids.contains($0.key) }
        var changed=false
        for patch in selected {
            var next=entry(patch,at:now)
            if let previous=entries[patch.id] {
                guard previous.patch != next.patch else { continue }
                next.from=previous.points(at:now,reduced:reduceMotion || reducedDetail);next.birth=previous.birth
            } else if !animate { next.birth = .distantPast }
            entries[patch.id]=next;changed=true
        }
        if changed && animate && !reduceMotion && !reducedDetail { animating=true;revision += 1 }
    }
}
