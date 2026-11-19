# T-005c House navigation and UI

- Status: todo · Priority: P0 · Estimate: 3 h · Owner: — · Depends on: T-005a, T-005b
- Requirements: M9, G7

## Goal

Users navigate project → house → room and manage houses from the app.

## Tasks

- [ ] ProjectDetail lists houses → tap opens HouseDetail (rooms) → tap opens RoomDetail. Breadcrumb-like navigation titles.
- [ ] Create and rename house (sheet with name validation).
- [ ] Delete house with confirmation that states "deletes N rooms".
- [ ] Empty states: project without houses, house without rooms.

## Acceptance criteria

- [ ] UI test `sitescopeUITests/HouseHierarchyTests.swift`: create project → house → room, navigate back and forth, relaunch, structure still shown.
- [ ] UI test: delete house shows the confirmation with the room count and removes its rooms.
- [ ] UI test: empty-state screens are shown for a project without houses and a house without rooms.
