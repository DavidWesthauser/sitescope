#if DEBUG
    import ARKit
    import Combine
    import RealityKit
    import SwiftUI
    import UIKit

    /// Developer toggles for the AR screen. Debug builds only. Everything is off at every launch, so a forgotten
    /// toggle never changes a later test. None of these change what is saved in a room map; the mesh only changes the
    /// session configuration.
    @MainActor final class ARDebugSettings: ObservableObject {
        static let shared = ARDebugSettings()
        /// Sent after a toggle that changes the AR view or the session has its new value.
        let changed = PassthroughSubject<Void, Never>()
        @Published var readout = false
        @Published var featurePoints = false { didSet { changed.send() } }
        /// Needs a LiDAR phone. Applied when the session next starts, because it changes the configuration.
        @Published var sceneMesh = false { didSet { changed.send() } }
        @Published var anchorGeometry = false { didSet { changed.send() } }
        @Published var anchorOrigins = false { didSet { changed.send() } }
        @Published var worldOrigin = false { didSet { changed.send() } }
        @Published var statistics = false { didSet { changed.send() } }
        var meshSupported: Bool { ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) }
        private init() {}
        var debugOptions: ARView.DebugOptions {
            var options: ARView.DebugOptions = []
            if featurePoints { options.insert(.showFeaturePoints) }
            if sceneMesh && meshSupported { options.insert(.showSceneUnderstanding) }
            if anchorGeometry { options.insert(.showAnchorGeometry) }
            if anchorOrigins { options.insert(.showAnchorOrigins) }
            if worldOrigin { options.insert(.showWorldOrigin) }
            if statistics { options.insert(.showStatistics) }
            return options
        }
    }

    /// Collects the live numbers shown in the panel. Published twice a second, not per frame.
    @MainActor final class ARDebugMonitor: ObservableObject {
        @Published private(set) var readout = DebugReadout()
        private var meter = FrameRateMeter()
        private var lastPublish: TimeInterval = 0
        /// Call when the session pauses or restarts, so the first new frame is not timed against an old one.
        func resetFrameRate() { meter.reset() }
        func observe(_ frame: ARFrame, planes: Int) {
            meter.tick(frame.timestamp)
            guard frame.timestamp - lastPublish >= 0.5 else { return }
            lastPublish = frame.timestamp
            var next = DebugReadout()
            next.fps = meter.fps
            switch frame.camera.trackingState {
            case .normal: next.tracking = "normal"
            case .notAvailable: next.tracking = "not available"
            case .limited(let reason): next.tracking = "limited (\(reason))"
            }
            next.mappingStatus = String(describing: frame.worldMappingStatus)
            next.featurePoints = frame.rawFeaturePoints?.points.count ?? 0
            next.planes = planes
            next.meshAnchors = frame.anchors.reduce(0) { $0 + ($1 is ARMeshAnchor ? 1 : 0) }
            next.thermal = String(describing: ProcessInfo.processInfo.thermalState)
            next.memoryMB = Self.memoryMB()
            next.device = Self.machine
            next.system = "iOS " + UIDevice.current.systemVersion
            if next != readout { readout = next }
        }
        private static func memoryMB() -> Double {
            var info = task_vm_info_data_t()
            var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
                }
            }
            return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
        }
        private static var machine: String {
            var system = utsname()
            uname(&system)
            let machine = system.machine
            return withUnsafeBytes(of: machine) { raw in
                String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
            }
        }
    }

    /// Small button on the AR screen that opens the developer panel, plus the optional live readout.
    struct ARDebugOverlay: View {
        @ObservedObject var ar: ARController
        @ObservedObject private var settings = ARDebugSettings.shared
        @ObservedObject private var monitor: ARDebugMonitor
        @State private var open = false
        init(ar: ARController) {
            self.ar = ar
            _monitor = ObservedObject(wrappedValue: ar.debug)
        }
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    open = true
                } label: {
                    Image(systemName: "ladybug").font(.system(size: 18, weight: .semibold)).frame(width: 40, height: 40)
                        .background(.regularMaterial, in: Circle())
                }.accessibilityLabel("Developer options")
                if settings.readout {
                    Text(monitor.readout.text).font(.system(size: 10, design: .monospaced)).padding(6)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)).allowsHitTesting(false)
                }
            }
            .padding(.leading, 8)
            .sheet(isPresented: $open) { ARDebugPanel(monitor: monitor) }
        }
    }

    struct ARDebugPanel: View {
        @ObservedObject var monitor: ARDebugMonitor
        @ObservedObject private var settings = ARDebugSettings.shared
        @Environment(\.dismiss) private var dismiss
        var body: some View {
            NavigationStack {
                Form {
                    Section("Performance") {
                        Toggle("Live readout", isOn: $settings.readout)
                        Toggle("Render statistics", isOn: $settings.statistics)
                        Button("Copy readout", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = monitor.readout.text
                        }.disabled(!settings.readout)
                    }
                    Section("Scene") {
                        Toggle("Feature points", isOn: $settings.featurePoints)
                        Toggle("LiDAR mesh", isOn: $settings.sceneMesh).disabled(!settings.meshSupported)
                        Text(
                            settings.meshSupported
                                ? "The mesh starts with the next AR session: close and reopen AR. Restarting a scan would discard it."
                                : "This phone has no LiDAR scanner."
                        ).font(.footnote).foregroundStyle(.secondary)
                        Toggle("Plane geometry", isOn: $settings.anchorGeometry)
                        Toggle("Anchor origins", isOn: $settings.anchorOrigins)
                        Toggle("World origin", isOn: $settings.worldOrigin)
                    }
                }
                .navigationTitle("Developer options").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            }
            .presentationDetents([.medium, .large])
        }
    }
#endif
