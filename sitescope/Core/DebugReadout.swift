#if DEBUG
    import Foundation

    /// Smoothed frames per second from ARKit frame timestamps. Debug builds only.
    public struct FrameRateMeter: Equatable, Sendable {
        private var last: TimeInterval?
        public private(set) var fps: Double = 0
        public init() {}
        public mutating func tick(_ timestamp: TimeInterval) {
            defer { last = timestamp }
            guard let last, timestamp > last else { return }
            let instant = 1 / (timestamp - last)
            fps = fps == 0 ? instant : fps * 0.9 + instant * 0.1
        }
        public mutating func reset() {
            last = nil
            fps = 0
        }
    }

    /// Live numbers for the developer panel. `text` is what the copy button puts on the clipboard.
    public struct DebugReadout: Equatable, Sendable {
        public var fps = 0.0
        public var tracking = "-"
        public var mappingStatus = "-"
        public var featurePoints = 0
        public var planes = 0
        public var meshAnchors = 0
        public var thermal = "-"
        public var memoryMB = 0.0
        public var device = "-"
        public var system = "-"
        public init() {}
        public var lines: [String] {
            [
                String(format: "FPS %.0f", fps),
                "Tracking \(tracking)",
                "Map \(mappingStatus)",
                "Feature points \(featurePoints) (this frame)",
                "Planes \(planes)",
                "Mesh anchors \(meshAnchors)",
                "Thermal \(thermal)",
                String(format: "Memory %.0f MB", memoryMB),
                "\(device) · \(system)",
            ]
        }
        public var text: String { lines.joined(separator: "\n") }
    }
#endif
