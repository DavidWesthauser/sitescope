# T-029 Database: minimal changes for the app

- Status: todo · Priority: P0 · Who: together · Owner: — · Depends on: T-003
- Requirements: M1, M2, M3, M4, G3

## Description

The hosted database runs the design in DATABASE_API.md (created in the SQL editor on 2026-11-26). The app (T-003, T-008) needs the changes below and nothing else; until they exist, rooms, drawings and scans stay on the phone ("couldn't upload"). The columns are the ones in `SyncEntity.insertFields` and `writableFields` (`sitescope/Core/Sync.swift`); the calls are in `sitescope/Services/RemoteStore.swift` and `Backend.swift`.

Nothing runs on the hosted project before a human reviewed the SQL. No existing function, policy or grant is replaced.

## Changes

1. **`revision`** (`bigint not null default 1`) on `projects`, `houses` and `rooms`, plus a `before update` trigger that raises it by 1 on every update. Clients never set it. The app writes and deletes with `…&revision=eq.<n>`.
2. **`rooms`** gets `description`, `coordinate_id`, `map_path`, `scan_guide_jpeg`, `surfaces` and `spatial_version`. Insert may set `coordinate_id`, `description` and the scan columns; update grants for `name`, `description`, `map_path`, `scan_guide_jpeg`, `surfaces` and `spatial_version` (not `coordinate_id`).
3. **New table `drawings`**: `id` (from the client), `room_id` (references `rooms`, cascade delete), `coordinate_id`, `kind` (`line`, `area` or `image`), `pose`, `points`, `strokes`, `image` and `revision` (with the same trigger). Read with level ≥ 1 on the room, insert, update and delete with level ≥ 2 (`scope_level` through the room's ids). Update grants for `pose`, `points`, `strokes` and `image`.
4. **Storage**: private bucket `room-assets`, paths `<project_id>/<room_id>/<file>`. Read from level ≥ 1, upload from level ≥ 2, by the room's level.

## Order

- [ ] Put the current design into Git as the first migration in `supabase/migrations/`, marked as applied on the hosted project.
- [ ] Put changes 1–4 into a second migration.
- [ ] A human reviews the SQL.
- [ ] Only then run it on the hosted project.

## Acceptance criteria

- [ ] `supabase db reset` rebuilds design plus changes locally.
- [ ] A human reviewed the SQL; afterwards the hosted schema equals `supabase/migrations/`.
- [ ] The app syncs a room with its scan and drawings to the hosted project and back to a second phone (H-003).
