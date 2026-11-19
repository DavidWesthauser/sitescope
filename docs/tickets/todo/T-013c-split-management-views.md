# T-013c Split ManagementViews.swift and isolate legacy code

- Status: todo · Priority: P1 · Estimate: 2 h · Owner: — · Depends on: T-013b
- Requirements: G7, quality "Aufbau", "Lesbarkeit"

## Goal

Split `sitescope/Views/ManagementViews.swift` (560 lines, 8 screens) into one file per screen under folders such as `sitescope/Views/Projects/` and `sitescope/Views/Rooms/`. Remove or isolate the legacy marker and reference-point code, keeping its `Codable` decoding so old project files still load.

## Tasks

- [ ] Split the 8 screens into one file each and delete `ManagementViews.swift`.
- [ ] Remove legacy marker/reference-point code, or move it to a clearly named `Legacy` folder with a doc comment.
- [ ] Keep `Codable` decoding for the legacy fields.
- [ ] Add the layer diagram (Views → ViewModels → Repositories → Backend/Local storage) to `docs/ARCHITECTURE.md`.

## Acceptance criteria

- [ ] `ManagementViews.swift` no longer exists; each screen lives in its own file.
- [ ] Unit test: a fixture with legacy marker fields still decodes into the current models.
- [ ] The diagram in ARCHITECTURE.md matches the real folder layout.
