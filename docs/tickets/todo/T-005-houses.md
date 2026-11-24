# T-005 Project → House → Room

- Status: todo · Priority: P0 · Who: agent · Owner: — · Depends on: T-008
- Requirements: M9, M1

## Description

A project contains houses, a house contains rooms. Old local data and old export files still open.

## Tasks

- [ ] `House` model, new migration with RLS and cascade; existing rooms go into "Main building".
- [ ] Local data, sync and transfer archive include houses (new archive version).
- [ ] Screens to browse, create, rename and delete houses, with empty states; deleting says how many rooms go.

## Acceptance criteria

- [ ] pgTAP: outsiders see no houses; delete cascades; every old room gets a house.
- [ ] Unit tests: old file and old archive open; migrating twice changes nothing.
- [ ] UI test: create project → house → room, relaunch, delete the house.
