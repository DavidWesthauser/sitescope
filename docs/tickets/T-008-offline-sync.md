# T-008 Offline-first: queue changes and upload when back online

- Status: todo · Priority: P0 · Estimate: 16 h · Owner: — · Depends on: T-007
- Requirements: M2, G5

## Goal
Everything keeps working without signal (mockup "No signal"). Changes are stored locally, marked "Waiting to sync", and uploaded automatically once the phone is online again.

## Tasks
- [ ] Local cache of cloud data per user (reuse local JSON/assets store), read from cache first.
- [ ] Persistent outbox: ordered operations (create/update/delete + asset uploads) with idempotent IDs (client-generated UUIDs already exist); survives app kill.
- [ ] `NWPathMonitor` connectivity service; retry with backoff; process outbox on reconnect / app foreground.
- [ ] Conflict policy: last-writer-wins on `updated_at` for simple fields; for task status show both versions and let user choose (mockup). Server rejects stale updates via `updated_at` check.
- [ ] Immutable map rule: a room mapped offline uploads map + metadata in the right order.
- [ ] UI: global offline banner, per-item sync badge (Synced / Waiting to sync / Failed – retry), "Synced just now" in Projects and Settings, pending change count.
- [ ] Optional (mockup): "Download room maps on Wi-Fi only".
- [ ] Unit tests for outbox ordering, retry, conflict resolution with mocked backend.

## Acceptance criteria
- [ ] Airplane mode: create room note + change status + take image → relaunch → still there, marked pending → disable airplane mode → uploaded, visible on second phone.
- [ ] Failed upload is retried and never duplicated.
- [ ] Conflict scenario from mockup reproducible and resolvable.
