import SwiftUI

/// Where a list row leads. Values, not views, so navigation state stays small and restorable.
enum Route: Hashable {
    case project(UUID)
    case house(UUID)
    case room(UUID)
}

/// The same name prompt for creating and renaming projects, houses and rooms: an alert with one text field.
struct NamePrompt: ViewModifier {
    let title: String
    let action: String
    @Binding var isPresented: Bool
    let initial: String
    let save: (String) -> Void
    @State private var text = ""

    func body(content: Content) -> some View {
        content.alert(title, isPresented: $isPresented) {
            TextField("Name", text: $text).textInputAutocapitalization(.words)
            Button(action) { save(text) }.disabled(DisplayName.normalized(text) == nil)
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: isPresented) { _, shown in
            if shown { text = initial }
        }
    }
}

extension View {
    func namePrompt(
        _ title: String, action: String, isPresented: Binding<Bool>, initial: String = "",
        save: @escaping (String) -> Void
    ) -> some View {
        modifier(NamePrompt(title: title, action: action, isPresented: isPresented, initial: initial, save: save))
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
            Text(message)
        }
    }
}

/// A list row: icon, title and a secondary line, with the record's sync state at the trailing edge.
struct RecordRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let state: ItemSyncState

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage).foregroundStyle(.tint)
            }
            Spacer(minLength: 8)
            SyncBadge(state: state)
        }
        .accessibilityElement(children: .combine)
    }
}
