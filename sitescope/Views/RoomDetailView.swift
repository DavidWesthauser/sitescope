import SwiftUI

/// Room screen: name, dimensions and building status, who is responsible, access and, in its own last section,
/// deleting. Members (level ≥ 2) edit the details; deleting and access need level 3; handing the room over needs
/// level 3 on its house.
struct RoomDetail: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let project: Project
    let house: House
    let initialRoom: Room
    @State private var room: Room?
    @State private var level = AccessLevel.none
    @State private var houseLevel = AccessLevel.none
    @State private var nameDraft: String
    @State private var height = ""
    @State private var length = ""
    @State private var width = ""
    @State private var status = RoomStatus.planned
    @State private var deleting = false
    /// Set once the delete succeeded, so the name field's save on disappear does not touch the deleted room.
    @State private var deleted = false
    private var current: Room { room ?? initialRoom }
    private var scope: AccessScope { .room(project, house, current) }

    init(project: Project, house: House, initialRoom: Room) {
        self.project = project
        self.house = house
        self.initialRoom = initialRoom
        _nameDraft = State(initialValue: initialRoom.name)
    }

    var body: some View {
        List {
            if level.canContribute {
                NameSection(
                    placeholder: "Room name", stored: current.name, identifier: "room.name", draft: $nameDraft,
                    save: rename)
            }
            detailsSection
            ResponsibleSection(
                scope: scope, current: current.responsible_id, canChange: houseLevel.canManage,
                changed: { await refresh() })
            Section {
                Label("Room scans and AR instructions", systemImage: "arkit")
            } footer: {
                Text("Scanning and placing instructions come once the database can store them (ticket T-029).")
            }
            if level.canManage {
                Section {
                    NavigationLink {
                        AccessView(scope: scope)
                    } label: {
                        Label("Manage access", systemImage: "person.2")
                    }.accessibilityIdentifier("room.access")
                }
                // HIG (Buttons, Action sheets): destructive action in its own last section, with a confirmation.
                Section {
                    Button("Delete Room", role: .destructive) { deleting = true }
                        .accessibilityIdentifier("room.delete")
                        .confirmationDialog(
                            "Delete “\(current.name)”?", isPresented: $deleting, titleVisibility: .visible
                        ) {
                            Button("Delete Room", role: .destructive) {
                                store.run {
                                    try await store.deleteRoom(current)
                                    deleted = true
                                    dismiss()
                                }
                            }.accessibilityIdentifier("room.delete.confirm")
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This deletes the room and its comments. This can’t be undone.")
                        }
                } footer: {
                    Text("Removes the room for everyone with access.")
                }
            }
            AccessLevelFooter(level: level)
        }
        .navigationTitle(level.canContribute ? nameDraft.titleOrFallback("Untitled Room") : current.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    @ViewBuilder private var detailsSection: some View {
        Section {
            if level.canContribute {
                DimensionField(title: "Length", text: $length)
                DimensionField(title: "Width", text: $width)
                DimensionField(title: "Height", text: $height)
                Picker("Status", selection: $status) {
                    ForEach(RoomStatus.allCases) { Text($0.label).tag($0) }
                }.accessibilityIdentifier("room.status")
            } else {
                LabeledContent("Length", value: Self.metres(current.length))
                LabeledContent("Width", value: Self.metres(current.width))
                LabeledContent("Height", value: Self.metres(current.height))
                LabeledContent("Status", value: current.status.label)
            }
            LabeledContent("Area", value: current.area.map { "\(Self.number($0)) m²" } ?? "–")
            if level.canContribute {
                Button("Save Details") { saveDetails() }
                    .disabled(!detailsChanged || parsedDetails == nil || store.busy)
                    .accessibilityIdentifier("room.saveDetails")
            }
        } header: {
            Text("Details")
        } footer: {
            if level.canContribute {
                Text(
                    parsedDetails == nil
                        ? "Use positive numbers in metres, e.g. 4.25."
                        : "Metres. Leave empty if unknown. The area is calculated from length and width.")
            }
        }
    }

    /// The typed dimensions as numbers; nil while one of them is not a positive number.
    private var parsedDetails: (height: Double?, length: Double?, width: Double?)? {
        guard let h = Self.parse(height), let l = Self.parse(length), let w = Self.parse(width) else { return nil }
        return (h, l, w)
    }
    private var detailsChanged: Bool {
        guard let parsed = parsedDetails else { return true }
        return parsed.height != current.height || parsed.length != current.length || parsed.width != current.width
            || status != current.status
    }
    /// Empty text is "unknown" (`.some(nil)`); text that is not a positive number is invalid (`nil`).
    private static func parse(_ text: String) -> Double?? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if trimmed.isEmpty { return .some(nil) }
        guard let value = Double(trimmed), value > 0 else { return nil }
        return .some(value)
    }
    private static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
    private static func metres(_ value: Double?) -> String { value.map { "\(number($0)) m" } ?? "–" }

    private func showDetails(of room: Room) {
        height = room.height.map(Self.number) ?? ""
        length = room.length.map(Self.number) ?? ""
        width = room.width.map(Self.number) ?? ""
        status = room.status
    }

    private func saveDetails() {
        guard let parsed = parsedDetails else { return }
        var updated = current
        updated.height = parsed.height
        updated.length = parsed.length
        updated.width = parsed.width
        updated.status = status
        store.run {
            try await store.updateRoomDetails(updated)
            await refresh()
        }
    }

    /// Cloud lists keep a deleted room until reload, so the flag covers that case.
    private var roomExists: Bool { !deleted }

    private func rename(_ name: String) {
        guard roomExists else { return }
        store.run {
            // Checked again when the queued rename runs: a delete may have finished in between.
            guard roomExists else { return }
            do {
                try await store.renameRoom(current, name: name)
                await refresh()
                try await store.loadRooms(house)
            } catch {
                nameDraft = current.name
                throw error
            }
        }
    }

    func refresh() async {
        do {
            let previousName = current.name
            let loaded = try await store.room(id: initialRoom.id)
            room = loaded
            // Pick up a name changed elsewhere, but never overwrite what is being typed.
            if nameDraft == previousName { nameDraft = loaded.name }
            showDetails(of: loaded)
            level = try await store.level(on: .room(project, house, loaded))
            houseLevel = try await store.level(on: .house(project, house))
        } catch { store.error = error.localizedDescription }
    }
}

/// A dimension in metres with a decimal keypad.
private struct DimensionField: View {
    let title: String
    @Binding var text: String
    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField("–", text: $text).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .accessibilityLabel("\(title) in metres")
                Text("m").foregroundStyle(.secondary).accessibilityHidden(true)
            }
        }
    }
}
