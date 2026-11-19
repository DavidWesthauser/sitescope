# T-008 Offline-first: queue changes and upload when back online

- Status: todo · Priority: P0 · Estimate: 16 h · Owner: — · Depends on: T-007
- Requirements: M2, G5

## Goal

Everything keeps working without signal (mockup "No signal"). Changes are stored locally, marked "Waiting to sync", and uploaded automatically once the phone is back online.

## Sub-tickets

- [T-008a](T-008a-local-cache.md) Local cache of cloud data, cache-first reads (3 h)
- [T-008b](T-008b-persistent-outbox.md) Persistent outbox, retry and reconnect processing (5 h)
- [T-008c](T-008c-offline-ui.md) Offline UI: banner, sync badges, pending count (4 h)
- [T-008d](T-008d-conflicts-map-order.md) Conflict handling and immutable map ordering (4 h)

## Acceptance criteria

- [ ] Airplane mode: create room note + change status + take image → relaunch → still there, marked pending → disable airplane mode → uploaded, visible on second phone.
- [ ] Failed upload is retried and never duplicated.
- [ ] Conflict scenario from mockup reproducible and resolvable.
