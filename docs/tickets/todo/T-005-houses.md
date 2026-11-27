# T-005 Project → House → Room

- Status: in progress · Priority: P0 · Who: agent · Owner: — · Depends on: T-003
- Requirements: M9, M1

## Description

A project contains houses, a house contains rooms (DATABASE_API.md).

## Tasks

- [x] `House` model; the hosted design already has `houses` with RLS and cascade.
- [x] Screens to browse, create, rename and delete houses, with empty states (`HouseDetailView`, T-003).
- [ ] Deleting a house says how many rooms go.
- [ ] Offline sync includes houses (T-008). Local data and the transfer archive were removed in T-003.

## Acceptance criteria

- [ ] pgTAP: outsiders see no houses; delete cascades (needs the design as a migration, T-029).
- [ ] UI test: create project → house → room and delete (`testCreateProjectHouseRoomRenameAndDelete`, needs a test account); run it.
