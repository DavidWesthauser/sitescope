import SwiftUI

/// Edits one spatial instruction. Managers can change its content; everyone can update its status.
struct TaskEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var item: Annotation
    let room: Room
    let manager: Bool
    @State private var deleting = false
    @State private var discarding = false
    // Snapshot of the saved task; comparing against it detects unsaved edits.
    private let original: Annotation
    private let onReposition: (() -> Void)?
    init(item: Annotation, room: Room, manager: Bool, onReposition: (() -> Void)? = nil) {
        _item = State(initialValue: item)
        original = item
        self.room = room
        self.manager = manager
        self.onReposition = onReposition
    }
    var body: some View {
        Form {
            Section("Instruction") {
                if manager {
                    TextField("Title", text: $item.title, axis: .vertical).lineLimit(1...3)
                    TextField("Description", text: $item.detail, axis: .vertical).lineLimit(3...8)
                    Picker("Priority", selection: $item.priority) {
                        Text("Low").tag(0)
                        Text("Normal").tag(1)
                        Text("High").tag(2)
                    }
                } else {
                    Text(item.title).font(.headline)
                    Text(item.detail)
                }
            }
            Picker("Status", selection: $item.status) {
                ForEach(TaskStatus.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Button("Save task") {
                store.run {
                    try await store.saveTask(item, room: room, manager: manager)
                    dismiss()
                }
            }.disabled(
                store.busy || item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || item.title.count > 240)
            if manager, let onReposition {
                Button("Reposition geometry in AR") {
                    onReposition()
                    dismiss()
                }.disabled(item != original)
            }
            if manager {
                Section {
                    Button("Delete Instruction", role: .destructive) { deleting = true }
                        .accessibilityIdentifier("task.delete")
                        .confirmationDialog(
                            "Delete “\(original.title)”?", isPresented: $deleting, titleVisibility: .visible
                        ) {
                            Button("Delete Instruction", role: .destructive) {
                                store.run {
                                    try await store.deleteTask(item, room: room)
                                    dismiss()
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Its drawing is removed from the room too. This can’t be undone.")
                        }
                }
            }
        }.navigationTitle(original.title).navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .interactiveDismissDisabled(item != original)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { if item != original { discarding = true } else { dismiss() } }.disabled(store.busy)
                        .confirmationDialog(
                            "Discard unsaved task edits?", isPresented: $discarding, titleVisibility: .visible
                        ) {
                            Button("Discard Changes", role: .destructive) { dismiss() }
                            Button("Keep Editing", role: .cancel) {}
                        }
                }
            }
    }
}
