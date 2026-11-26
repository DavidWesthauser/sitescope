import SwiftUI

/// Edits a name in place instead of through a separate "Rename" action. Saves on Return, when the field loses
/// focus and when the screen goes away. An empty name is never saved; the stored name comes back instead.
struct NameSection: View {
    let placeholder: String
    /// The saved name; a commit with the same value does nothing.
    let stored: String
    let identifier: String
    @Binding var draft: String
    let save: (String) -> Void
    @FocusState private var focused: Bool

    var body: some View {
        Section("Name") {
            TextField(placeholder, text: $draft)
                .focused($focused)
                .submitLabel(.done)
                .textInputAutocapitalization(.words)
                .onSubmit(commit)
                .accessibilityIdentifier(identifier)
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { commit() }
        }
        .onDisappear(perform: commit)
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            draft = stored
            return
        }
        if draft != trimmed { draft = trimmed }
        if trimmed != stored { save(trimmed) }
    }
}

extension String {
    /// The text to show as a navigation title while a name is edited; never an empty title.
    func titleOrFallback(_ fallback: String) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
