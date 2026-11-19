# T-008c Offline UI: banner, sync badges, pending count

- Status: todo · Priority: P0 · Estimate: 4 h · Owner: — · Depends on: T-008b
- Requirements: M2, G5

## Goal

The user always sees whether they are offline and which items are not yet synced. Failed items can be retried from the item.

## Tasks

- [ ] Global offline banner, shown while `NWPathMonitor` reports no connection.
- [ ] Per-item sync badge: Synced / Waiting to sync / Failed – retry (tap retries).
- [ ] "Synced just now" label in Projects and Settings; pending change count.
- [ ] Optional (mockup): "Download room maps on Wi-Fi only" setting.

## Acceptance criteria

- [ ] UI test: offline stub shows the banner; badges show Synced, Waiting to sync, and Failed for seeded items.
- [ ] UI test (error case): tapping "Failed – retry" starts a new upload attempt.
- [ ] If the Wi-Fi-only setting is built, unit test: it persists and blocks map download on cellular.
