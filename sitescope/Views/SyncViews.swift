import SwiftUI

/// A record's way to the server: nothing when it is there, a cloud with an arrow while it waits, a warning when the
/// server refused it.
struct SyncBadge: View {
    let state: ItemSyncState
    var body: some View {
        switch state {
        case .synced:
            EmptyView()
        case .waiting:
            Image(systemName: "icloud.and.arrow.up").foregroundStyle(.secondary)
                .accessibilityLabel(Self.text(for: state))
        case .failed:
            Image(systemName: "exclamationmark.icloud").foregroundStyle(Color("Warning"))
                .accessibilityLabel(Self.text(for: state))
        }
    }
    static func text(for state: ItemSyncState) -> String {
        switch state {
        case .synced: return "Up to date"
        case .waiting: return "Waiting to upload"
        case .failed(let reason): return "Upload failed: \(reason)"
        }
    }
}

/// One line in the bottom toolbar, like Mail's "Updated just now": offline, syncing, waiting or failed changes.
struct SyncStatusView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        VStack(spacing: 1) {
            if !store.isOnline {
                Text("Offline").font(.caption.weight(.semibold))
                Text(store.waitingChanges == 0 ? "Changes are saved on this iPhone" : waitingText)
                    .font(.caption2).foregroundStyle(.secondary)
            } else if store.isSyncing {
                Text("Syncing…").font(.caption)
            } else if store.failedChanges > 0 {
                Text(
                    store.failedChanges == 1
                        ? "1 change couldn’t upload" : "\(store.failedChanges) changes couldn’t upload"
                )
                .font(.caption).foregroundStyle(Color("Warning"))
            } else if store.waitingChanges > 0 {
                Text(waitingText).font(.caption)
            } else if let date = store.lastSync {
                Text("Updated \(date, format: .relative(presentation: .named))").font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sync.status")
    }
    private var waitingText: String {
        store.waitingChanges == 1 ? "1 change waiting to upload" : "\(store.waitingChanges) changes waiting to upload"
    }
}

/// What sync resolved on the user's behalf (T-008: no change is dropped silently), until they dismiss it.
struct SyncNoticesSection: View {
    @EnvironmentObject var store: Store
    var body: some View {
        if !store.notices.isEmpty {
            Section {
                ForEach(store.notices) { notice in
                    Label(notice.text, systemImage: "arrow.triangle.merge")
                        .swipeActions { Button("Dismiss") { store.dismissNotice(notice) } }
                }
            } header: {
                Text("Resolved while syncing")
            } footer: {
                Text("Swipe to dismiss.")
            }
        }
    }
}

extension View {
    /// Swipe to retry a change the server refused.
    func retrySwipe(_ key: RecordKey, store: Store) -> some View {
        swipeActions(edge: .leading) {
            if case .failed = store.syncState(of: key) {
                Button("Retry", systemImage: "arrow.clockwise") { Task { await store.retry(key) } }.tint(.accentColor)
            }
        }
    }
}
