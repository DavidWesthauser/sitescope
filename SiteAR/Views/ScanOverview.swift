import SwiftUI
import simd

/// A floating miniature of observed surfaces. Detailed scan statistics live in Options.
struct ScanOverview: View {
    let progress: ScanProgress
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(.black.opacity(0.18))
                    .frame(width: typeSize.isAccessibilitySize ? 72 : 100, height: 10)
                    .blur(radius: 7)
                    .offset(y: 2)
                    .accessibilityHidden(true)
                ScanMiniature(surfaces:progress.surfaces,yaw:progress.cameraYaw,reducedDetail:progress.renderingReduced)
                    .frame(width:typeSize.isAccessibilitySize ? 160 : 210,height:typeSize.isAccessibilitySize ? 140 : 190)
            }
            HStack(spacing: 6) {
                Circle()
                    .fill(progress.normalTracking ? Color.mint : Color.white.opacity(0.65))
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text("Live scan").font(.caption.weight(.medium)).foregroundStyle(.white)
                if progress.renderingReduced {
                    Image(systemName: "leaf")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                        .accessibilityLabel("Reduced scan detail")
                }
            }
        }.frame(maxWidth: 240).padding(.bottom, 4)
    }
}
