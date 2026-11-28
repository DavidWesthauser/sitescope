# T-008 Offline use and sync

- Status: in progress · Priority: P0 · Who: together · Owner: — · Depends on: T-003, T-029 (server side), H-002
- Requirements: M1, M2, M4, G5, G7

## Description

Sign-in stays required, but a signed-in user can work fully offline. Every change is saved on the phone first and uploaded later; screens only read the phone's copy. Until the database has the target of T-029, uploads of projects, houses, rooms and drawings fail and stay queued.

## Tasks

- [ ] Offline use: local data stays readable and writable without network, the session is cached, no blocking error screens.
- [ ] Local-first storage per account (`sitescope/accounts/<user>/`); existing local data of that account keeps opening after updates. The old on-device file (`sitescope/local.json`, before T-003) is left untouched and not imported.
- [ ] Persistent queue: changes save on the device first and go into a queue that uploads on reconnect, on foreground and on refresh, in order (parents before children, files before records), retried, without duplicates, surviving app kill.
- [ ] Conflicts: detected with the server revision (T-029), never device clocks; merged per field. Default rule: last change wins, behind one swappable policy (H-002 is open). An edit beats a delete. A published room map is never overwritten: if the server already has a different scan, the local scan becomes a new room with its drawings. No local change is dropped silently; what was resolved shows as a notice.
- [ ] UI: offline/sync status in the lists, per-item state (waiting, failed with retry), sync status and notices in Settings.

## Acceptance criteria

- [ ] Unit tests with a fake server: create, edit, delete for projects, houses, rooms and drawings; queue order, retry, relaunch; each conflict rule; data separated per account.
- [ ] Simulator: offline changes show as waiting and upload when back online (needs T-029 on the server).
- [ ] A human confirms on a phone: airplane mode, edits, back online, second phone sees them.
