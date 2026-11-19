# T-005 Project → House → Room folder structure

- Status: todo · Priority: P0 · Estimate: 10 h · Owner: — · Depends on: T-001 (T-003 for cloud part)
- Requirements: M9, M1, G7

## Goal

A navigable three-level hierarchy: a project contains houses (buildings), a house contains rooms.

## Sub-tickets

- [T-005a](T-005a-house-model-migration.md) House model + migration 005 + pgTAP (4 h)
- [T-005b](T-005b-house-local-archive.md) Local JSON migration, transfer archive, store methods + unit tests (3 h)
- [T-005c](T-005c-house-ui.md) UI: project → house → room, create/rename/delete, empty states + UI test (3 h)

## Acceptance criteria

- [ ] Create project → house → room, navigate back and forth, relaunch: structure persists (local and cloud).
- [ ] Deleting a house removes its rooms, instructions and assets.
- [ ] Old local data and old export files still open.
