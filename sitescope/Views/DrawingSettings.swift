import SwiftUI

/// Fallback when ARKit cannot detect a surface: the user supplies the distance.
/// The 0.1–10 m range rejects implausible values.
struct DrawingPlacementSettings: View {
    @Binding var measured: Bool
    @Binding var distance: Double
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Toggle("Use a measured distance", isOn: $measured)
                if measured {
                    TextField("Distance in metres", value: $distance, format: .number).keyboardType(.decimalPad)
                }
                Text(
                    "Use only if a surface cannot be detected. Measure the distance from the camera yourself. The drawing plane stays fixed after the first placement."
                ).font(.footnote)
            }.navigationTitle("Placement").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }.disabled(
                            measured && (!distance.isFinite || distance < 0.1 || distance > 10))
                    }
                }
        }
    }
}
