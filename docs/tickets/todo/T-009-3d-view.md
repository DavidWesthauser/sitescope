# T-009 3D view of a saved room

- Status: todo · Priority: P0 · Who: agent · Owner: — · Depends on: —
- Requirements: M3 (second half)

## Description

Open a mapped room anywhere as an interactive 3D model with its notes, without the camera.

## Tasks

- [ ] Mesh code moves to `sitescope/Core/MeshBuilders/` without ARKit and is shared with AR; reuse `RoomSurfaceModel` if it fits.
- [ ] Viewer with orbit, pan, zoom and reset; notes at their AR positions, colored by status; tap opens the task.
- [ ] "View 3D model" on the room screen, empty states, fixture room for the simulator.

## Acceptance criteria

- [ ] Unit tests: builders, note position equals the AR position, status colors, empty room.
- [ ] Layout test with the fixture room; existing AR tests stay green.
