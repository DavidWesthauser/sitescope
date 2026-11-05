import Foundation
import simd

/// Each touch-down owns a separate path. Touch-up can never join it to the next path.
public struct FreehandDraft: Sendable {
    public private(set) var strokes: [[Point3]] = []
    public private(set) var isDrawing = false
    public init() {}
    public var points: [Point3] { strokes.flatMap { $0 } }
    public mutating func begin() {
        end()
        guard strokes.count<32, points.count<2048 else { return }
        strokes.append([]); isDrawing=true
    }
    public mutating func append(_ point: Point3) {
        guard isDrawing, let last=strokes.indices.last, strokes[last].count<256, points.count<2048 else { return }
        if let previous=strokes[last].last, simd_distance(previous.vector,point.vector)<0.003 { return }
        strokes[last].append(point)
    }
    public mutating func end() {
        guard isDrawing else { return }
        isDrawing=false
        if let last=strokes.last, last.count<2 { strokes.removeLast() }
    }
    public mutating func undo() { end(); if !strokes.isEmpty { strokes.removeLast() } }
    public mutating func clear() { self=FreehandDraft() }
}

public extension DrawingGeometry {
    /// Corner cutting stays in the captured plane and its convex hull; endpoints remain fixed.
    static func smoothStroke(_ input: [Point3], passes: Int = 2) -> [Point3] {
        var p: [SIMD3<Float>] = []
        for point in input where p.last.map({simd_distance($0,point.vector)>0.0001}) ?? true { p.append(point.vector) }
        guard p.count>=2 else { return p.map(Point3.init) }
        for _ in 0..<max(0,min(passes,3)) {
            var next=[p[0]]
            for (a,b) in zip(p,p.dropFirst()) { next.append(a*0.75+b*0.25); next.append(a*0.25+b*0.75) }
            next.append(p[p.count-1]); p=next
        }
        return p.map(Point3.init)
    }
}
