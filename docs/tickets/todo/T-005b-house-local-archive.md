# T-005b Local house model, transfer archive and store methods

- Status: todo · Priority: P0 · Estimate: 3 h · Owner: — · Depends on: T-001, T-005a
- Requirements: M9, G7

## Goal

Local JSON files and transfer archives understand houses; old files and old archives open into a default house.

## Tasks

- [ ] Local JSON: add `houses` to the local project file in `sitescope/App/Store.swift` (or its repository); keep decoding of old files.
- [ ] On load, migrate old files: create a default house "Main building", assign all rooms to it, write back.
- [ ] Transfer archive (`sitescope/Core/ProjectTransferArchive.swift`): include houses, bump the archive version; old archives import into a default house.
- [ ] Store methods `createHouse`, `renameHouse`, `deleteHouse` (cascade removes rooms, instructions and assets); name validation 1–120 chars.

## Acceptance criteria

- [ ] Unit tests in `sitescopeTests/`: an old local JSON file loads and gains a default house with all its rooms.
- [ ] Unit tests: an old archive version imports into a default house; a new archive round-trips houses.
- [ ] Unit tests: create, rename and cascade delete (rooms and their assets removed).
