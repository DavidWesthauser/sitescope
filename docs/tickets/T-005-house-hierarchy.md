# T-005 Project → House → Room folder structure

- Status: todo · Priority: P0 · Estimate: 10 h · Owner: — · Depends on: T-001 (T-003 for cloud part)
- Requirements: M9, M1, G7

## Goal
A navigable three-level hierarchy: a project contains houses (buildings), a house contains rooms.

## Tasks
- [ ] Model: `House { id, project_id, name, created_at }`; `Room.house_id` (required). Validation like other names (1–120 chars).
- [ ] Migration 005: `houses` table, FK `rooms.house_id → houses.id on delete cascade`, RLS mirroring rooms (read = project access; create/update/delete per role, see T-006), backfill: one "Main building" house per existing project.
- [ ] Local JSON: add `houses`, migrate old files on load (create default house, assign rooms). Keep decoding of old files.
- [ ] Transfer archive: include houses; bump/handle version; old archives import into a default house.
- [ ] UI: ProjectDetail lists houses → HouseDetail lists rooms → RoomDetail. Create/rename/delete house with confirmation ("deletes N rooms"). Empty states. Breadcrumb-like navigation titles.
- [ ] Store/repository methods + unit tests (create, rename, cascade delete, migration of old local file).

## Acceptance criteria
- [ ] Create project → house → room, navigate back and forth, relaunch: structure persists (local and cloud).
- [ ] Deleting a house removes its rooms, instructions and assets.
- [ ] Old local data and old export files still open.
- [ ] pgTAP: outsider cannot read/create houses.
