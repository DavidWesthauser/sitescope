# T-029 Database: AR data and hardening

- Status: todo · Priority: P1 · Who: together · Owner: — · Depends on: T-003
- Requirements: M1, M3, M4, G3

## Description

The hosted database runs the design in DATABASE_API.md (projects → houses → rooms, access grants, comments). It has nowhere to store scans and AR instructions yet, so the app cannot save them to the cloud. This ticket adds that on top of the design, without replacing any of it, and closes a few gaps found while reading it. A human decides which parts to do before anything runs on the hosted project.

The design exists only on the hosted project (created in the SQL editor on 2026-11-26) and in DATABASE_API.md. It is not in `supabase/migrations/`.

## Tasks

- [ ] Keep the design in Git: add it as the first migration, so `supabase db reset` rebuilds it and `supabase db push` knows it is applied (`supabase migration repair --status applied`).
- [ ] AR columns on `rooms`: `coordinate_id`, `map_path`, `scan_guide_jpeg`, `surfaces`, `spatial_version`; members (level ≥ 2) may set them, and a published map can never be replaced (trigger).
- [ ] `annotations` table for instructions and tasks, readable with level ≥ 1 on the room, editable with ≥ 2; notes need a mapped room and its coordinate system.
- [ ] RPC `set_task_status`: anyone with level ≥ 1 on the room changes only a task's status.
- [ ] Private storage bucket `room-assets`; paths `<project_id>/<room_id>/<file>`, read ≥ 1, upload ≥ 2, delete ≥ 3 on the room. Decide the path format first.
- [ ] Hardening: creating a project may only make the creator responsible (today any `responsible_id` is accepted on insert; changing it later is admin-only).
- [ ] Hardening: column lists for `insert` privileges instead of whole tables, so clients cannot send `created_by`, `created_at` or `is_hidden` at all (triggers overwrite them today).
- [ ] Hardening: `scope_level` returns 0 when the house is not in the project or the room not in the house. Today the foreign keys prevent misuse, but the function itself trusts its arguments.
- [ ] Update DATABASE_API.md for every change.

## Acceptance criteria

- [ ] pgTAP tests for each new rule and for the permission table in DATABASE_API.md pass on the local stack.
- [ ] A human reviewed the SQL before it runs on the hosted project; the hosted schema equals `supabase/migrations/` afterwards.
- [ ] A room scanned on a phone is recognized on a second phone through the cloud (H-003).
