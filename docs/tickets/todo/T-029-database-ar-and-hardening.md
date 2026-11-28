# T-029 Database: scans and drawings

- Status: todo · Priority: P0 · Who: together · Owner: — · Depends on: T-003
- Requirements: M1, M2, M3, M4, G3

## Description

The hosted database runs the design in DATABASE_API.md (projects → houses → rooms, access grants, comments), created in the SQL editor on 2026-11-26. The app is built against the target below (T-003, T-008); until the database has it, sign-in, rights and grants work, but syncing rooms, drawings and scans fails and the app keeps them on the phone.

Decided 2026-11-28: a room has a name, a description, a scan and drawings. A drawing is only geometry: a freehand line, a marked area or a pinned photo.

Only what the app needs is in this ticket. Everything else (immutability triggers, size limits, hardening, clean-up of unused columns, file clean-up) is left out on purpose and gets its own ticket if it turns out to matter.

Nothing here runs on the hosted project before a human reviewed the SQL. All changes come on top of the design; no existing function, policy or grant is replaced.

## Target, compared with the hosted design

**Revisions.** `projects`, `houses`, `rooms` and `drawings` get `revision bigint not null default 1` and `updated_at timestamptz not null default now()`, both set by a `before update` trigger (revision + 1, server clock). Clients never set them. The app writes with `PATCH …&revision=eq.<n>` and `DELETE …&revision=eq.<n>` (T-008 conflict detection).

**`rooms`.** Add `description text not null default ''`, `coordinate_id uuid not null default gen_random_uuid()`, `map_path text`, `scan_guide_jpeg text`, `surfaces jsonb`, `spatial_version int not null default 1`. Members (level ≥ 2) may update `description`, `map_path`, `scan_guide_jpeg`, `surfaces` and `spatial_version`; `coordinate_id` is set on insert only.

**New table `drawings`.** `id uuid primary key` (from the client), `room_id uuid not null references rooms on delete cascade`, `coordinate_id uuid not null`, `kind text not null check (kind in ('line', 'area', 'image'))`, `pose jsonb not null`, `points jsonb not null default '[]'`, `strokes jsonb`, `image jsonb`, `created_at`, `revision`, `updated_at`. RLS: read with level ≥ 1 on the room, insert/update/delete with ≥ 2 (`scope_level` through the room's ids).

**Storage.** Private bucket `room-assets`, files at `<project_id>/<room_id>/<file>` (`.worldmap` scans, `.png` images). By the room's level: read ≥ 1, upload ≥ 2, delete ≥ 3.

## Tasks

- [ ] Design as first migration in `supabase/migrations/`, marked applied on the hosted project.
- [ ] Second migration with every change above.
- [ ] pgTAP tests: the new permission rows (drawings, storage paths) and the revision bump.
- [ ] Update DATABASE_API.md once the migration is applied.

## Acceptance criteria

- [ ] `supabase db reset` rebuilds design + changes locally; the pgTAP suite passes.
- [ ] A human reviewed the SQL; afterwards the hosted schema equals `supabase/migrations/`.
- [ ] The app syncs a room with its scan and drawings to the hosted project and back to a second phone (H-003).
