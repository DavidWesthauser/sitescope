# T-009c Notes in 3D: tap to edit and status colors

- Status: todo · Priority: P0 · Estimate: 4 h · Owner: — · Depends on: T-009b
- Requirements: M3 (second half)

## Goal

Place notes in the 3D model where they are in AR, color them by status, and let a tap open the note in TaskEditor.

## Tasks

- [ ] Place annotation entities (strokes, areas, images) at their `roomFromAnnotation` poses so they match AR.
- [ ] Give annotation entities input and collision components; a tap opens TaskEditor for that note.
- [ ] Status colours: completed = green, other statuses from the palette used in T-012 (checked for contrast in both modes).

## Acceptance criteria

- [ ] Unit test: `roomFromAnnotation` pose maps to the same relative position as the AR pose for a fixture (within a small epsilon).
- [ ] Unit test: status-to-colour mapping returns green for completed.
- [ ] Snapshot/layout test of the viewer with the fixture room in `sitescopeAppTests/`.
- [ ] Manual check in the simulator: tapping a note opens TaskEditor.

## Notes

The optional LiDAR mesh link is tracked in T-022, not here.
