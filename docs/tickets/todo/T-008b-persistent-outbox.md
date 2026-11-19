# T-008b Persistent outbox, retry and reconnect processing

- Status: todo · Priority: P0 · Estimate: 5 h · Owner: — · Depends on: T-008a
- Requirements: M2, G5

## Goal

Local changes go into a persistent, ordered outbox. The outbox sends them to the server with retry and backoff, and resumes on reconnect or app foreground.

## Tasks

- [ ] Outbox of ordered operations (create/update/delete, asset uploads) using client-generated UUIDs as idempotency keys; saved to disk.
- [ ] Outbox survives app kill and is reloaded on launch.
- [ ] `NWPathMonitor` connectivity service; process the outbox on reconnect and app foreground.
- [ ] Retry with exponential backoff; a retried operation never creates a duplicate on the server.
- [ ] Unit tests for outbox ordering and retry with a mocked backend.

## Acceptance criteria

- [ ] Unit test: operations replay in enqueue order.
- [ ] Unit test: failed operation is retried with backoff, succeeds once, and the mock backend sees no duplicate.
- [ ] Unit test: outbox contents are still there after the store is recreated (simulated relaunch).
