# T-005a House model and schema migration

- Status: todo · Priority: P0 · Estimate: 4 h · Owner: — · Depends on: T-001, T-003
- Requirements: M9, M1

## Goal

The cloud schema has houses under projects, rooms belong to a house, and RLS protects houses like rooms.

## Tasks

- [ ] Swift model `House { id, project_id, name, created_at }` in `sitescope/Core/Models.swift`; `Room.house_id` (required). Name validation like other names (1–120 chars).
- [ ] A new timestamped migration (`YYYYMMDDHHMM_name.sql`) in `supabase/migrations/`: `houses` table, FK `rooms.house_id → houses.id on delete cascade`.
- [ ] RLS on `houses` mirroring rooms: read = project access; write = same rule as rooms (role rules come in T-006a).
- [ ] Backfill: one "Main building" house per existing project; existing rooms are assigned to it.

## Acceptance criteria

- [ ] pgTAP `supabase/tests/houses.test.sql`: outsider cannot read or create houses.
- [ ] pgTAP: backfill gives every existing project a "Main building" and assigns its rooms.
- [ ] pgTAP: deleting a house cascades to its rooms (and through them instructions and assets).
