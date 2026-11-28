# T-029 Database: scans, drawings, revisions and hardening

- Status: todo · Priority: P0 · Who: together · Owner: — · Depends on: T-003
- Requirements: M1, M2, M3, M4, G3

## Description

The hosted database runs the design in DATABASE_API.md (projects → houses → rooms, access grants, comments), created in the SQL editor on 2026-11-26. The app is being built against the target described here (T-003, T-008); until the database has it, sign-in, rights and grants work, but syncing projects, houses, rooms and drawings fails and the app keeps them on the phone.

Decided 2026-11-28: a room has a name, a description, a scan and drawings. No room dimensions or building status, no notes or tasks with title, status or priority. A drawing is only geometry: a freehand line, a marked area or a pinned photo.

Nothing here runs on the hosted project before a human reviewed the SQL. All changes come on top of the design; no existing function, policy or grant is replaced unless listed.

## Target, compared with the hosted design

**Keep the design in Git first.** The design (as on the hosted project) becomes `supabase/migrations/<timestamp>_design.sql`, marked applied with `supabase migration repair --status applied`. Every change below is a second migration.

**Revisions on every synced table.** `projects`, `houses`, `rooms`, `drawings` get:
- `revision bigint not null default 1`, raised by 1 on every update by a trigger (`bump_revision`, `before update`). Clients never set it.
- `updated_at timestamptz not null default now()`, set by the same trigger (server clock; the app never compares device clocks).
- Clients write with a condition: `PATCH /rooms?id=eq.<id>&revision=eq.<n>` and `DELETE …&revision=eq.<n>` with `Prefer: return=representation`. An empty result means someone else changed or deleted the row; the app then reads the row and merges (T-008). Creating uses the client's UUID (`id`), so a retried insert is detected as a conflict (`409`), never duplicated.

**`rooms`.**
- Drop `height`, `length`, `width`, `area`, `status` (with their checks and the `update` grant on them).
- Add `description text not null default ''` (≤ 4000 characters).
- Add the scan: `coordinate_id uuid not null default gen_random_uuid()`, `map_path text`, `scan_guide_jpeg text` (≤ 87 384 characters, a base64 JPEG of ≤ 64 KiB), `surfaces jsonb` (array, ≤ 128 entries), `spatial_version int not null default 1 check (spatial_version = 1)`.
- `update` grant: `name, description, responsible_id, map_path, scan_guide_jpeg, surfaces, spatial_version`. `coordinate_id` only on insert.
- Trigger `preserve_room_map` (`before update`): once `map_path` is set, `map_path`, `scan_guide_jpeg`, `surfaces`, `spatial_version` and `coordinate_id` never change. A changed room becomes a new room (the app does this, T-008).

**New table `drawings`** (replaces the app's former tasks).
- Columns: `id uuid primary key` (from the client), `room_id uuid not null references rooms on delete cascade`, `coordinate_id uuid not null`, `kind text not null check (kind in ('line', 'area', 'image'))`, `pose jsonb not null` (4×4 column-major matrix), `points jsonb not null default '[]'` (≤ 128 points), `strokes jsonb` (≤ 32 strokes, ≤ 2048 points in total; only for `line`), `image jsonb` (`{path, width, height}`; only for `image`), `created_by` (trigger), `created_at`, `revision`, `updated_at`.
- Trigger `require_mapped_room` (`before insert`): the room must have a `map_path` and the same `coordinate_id`.
- RLS: read with level ≥ 1 on the room, insert/update/delete with ≥ 2 (`scope_level(project, house, room)` through the room's ids).
- Grants: `select, insert, delete`; `update (pose, points, strokes, image)`.

**Storage.** Private bucket `room-assets`, files at `<project_id>/<room_id>/<file>` (`.worldmap` scans, `.png` images). Policies by the room's level: read ≥ 1, upload ≥ 2, delete ≥ 3. Files are never overwritten (no `update` policy). Deleting a room or drawing does not delete files yet; a clean-up job is a separate task.

**Hardening** (gaps found while reading the design).
- Creating a project may only make the creator responsible; today any `responsible_id` is accepted on insert.
- Column lists for `insert` instead of whole tables, so clients cannot send `created_by`, `created_at`, `is_hidden` or `revision`.
- `scope_level` returns 0 when the house is not in the project or the room not in the house; today only the foreign keys prevent misuse.

## Tasks

- [ ] Design as first migration, marked applied on the hosted project.
- [ ] Second migration with every change above.
- [ ] pgTAP tests: each permission-table row, revision bump and conditional update, map immutability, drawings need a mapped room, storage paths, hardening.
- [ ] Update DATABASE_API.md once the migration is applied.

## Acceptance criteria

- [ ] `supabase db reset` rebuilds design + changes locally; the pgTAP suite passes.
- [ ] A human reviewed the SQL; afterwards the hosted schema equals `supabase/migrations/`.
- [ ] The app syncs a project with houses, rooms, a scan and drawings to the hosted project and back to a second phone (H-003).
