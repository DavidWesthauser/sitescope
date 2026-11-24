# T-008 Room notes on phone and server, with offline sync

- Status: todo · Priority: P0 · Who: together · Owner: — · Depends on: T-003, H-002
- Requirements: M1, M2, M4, G5, G7

## Description

Every change is saved on the phone first and uploaded when online. One storage path replaces the `isLocalMode` branches; houses, roles and comments build on it.

## Tasks

- [ ] Local storage per user is what screens read and write; existing local data opens unchanged.
- [ ] Persistent upload queue for create, edit, delete and files: ordered, retried, no duplicates, survives app kill. Files before records; deletes also remove server files.
- [ ] Sync on reconnect, foreground and refresh; conflicts and local projects on sign-in as decided in H-002.
- [ ] Offline banner, per-item state with retry, progress for large maps.

## Acceptance criteria

- [ ] Unit tests with a fake server: create, edit, delete of every note kind; queue order, retry, relaunch, conflict rule, data separated per user.
- [ ] Unit test: existing local data opens unchanged; a human confirms it on a phone with real projects.
- [ ] UI test: an offline change shows as waiting; a failed one can be retried.
