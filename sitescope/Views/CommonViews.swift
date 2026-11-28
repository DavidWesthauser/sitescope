import SwiftUI

/// Where a list row leads. Values, not views, so navigation state stays small and restorable.
enum Route: Hashable {
    case project(UUID)
    case house(UUID)
    case room(UUID)
}

/// The same name prompt for creating and renaming projects, houses and rooms: an alert with one text field.
/// Renaming stays disabled until the name actually changes.
struct NamePrompt: ViewModifier {
    let title: String
    let placeholder: String
    let action: String
    @Binding var isPresented: Bool
    let initial: String
    let save: (String) -> Void
    @State private var text = ""

    private var canSave: Bool {
        guard let name = DisplayName.normalized(text) else { return false }
        return name != initial
    }
    func body(content: Content) -> some View {
        content.alert(title, isPresented: $isPresented) {
            TextField(placeholder, text: $text).textInputAutocapitalization(.words)
            Button(action) { save(text) }.disabled(!canSave)
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: isPresented) { _, shown in
            if shown { text = initial }
        }
    }
}

extension View {
    func namePrompt(
        _ title: String, placeholder: String, action: String, isPresented: Binding<Bool>, initial: String = "",
        save: @escaping (String) -> Void
    ) -> some View {
        modifier(
            NamePrompt(
                title: title, placeholder: placeholder, action: action, isPresented: isPresented, initial: initial,
                save: save))
    }

    /// Confirms deleting something by name, as an alert: its action can come from a menu, a swipe or a context
    /// menu, so there is no single button a popover could point at. Cancel is always offered.
    func deleteConfirmation(
        _ name: String, isPresented: Binding<Bool>, message: String, delete: @escaping () -> Void
    ) -> some View {
        alert("Delete “\(name)”?", isPresented: isPresented) {
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(message + " This can’t be undone.")
        }
    }
}

/// A list row: icon, title and a secondary line, with the record's sync state at the trailing edge.
struct RecordRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let state: ItemSyncState
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // At accessibility sizes the badge goes under the text, so long names keep the full row width.
        let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())
        layout {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage).foregroundStyle(.tint).accessibilityHidden(true)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            SyncBadge(state: state)
        }
        .accessibilityElement(children: .combine)
    }
}
