import SwiftUI

struct DrawingWorkDetails: View {
    @Binding var title:String
    @Binding var details:String
    @Binding var priority:Int
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Work details (optional)") {
                    TextField("Title",text:$title,axis:.vertical).lineLimit(1...3).accessibilityIdentifier("drawing.title")
                    TextField("Description",text:$details,axis:.vertical).lineLimit(3...8)
                    Text("\(title.count) / 240 characters in title").font(.caption).foregroundStyle(title.count>240 ? .red : .secondary)
                    Picker("Priority",selection:$priority) { Text("Low").tag(0); Text("Normal").tag(1); Text("High").tag(2) }
                }
            }.navigationTitle("Work details").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() }.disabled(title.count>240) } }
        }
    }
}
struct DrawingPlacementSettings: View {
    @Binding var measured:Bool
    @Binding var distance:Double
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Toggle("Use a measured distance",isOn:$measured)
                if measured { TextField("Distance in metres",value:$distance,format:.number).keyboardType(.decimalPad) }
                Text("Use only if a surface cannot be detected. Measure the distance from the camera yourself. The drawing plane stays fixed after the first placement.").font(.footnote)
            }.navigationTitle("Placement").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() }.disabled(measured && (!distance.isFinite || distance<0.1 || distance>10)) } }
        }
    }
}
