# T-009b 3D viewer screen

- Status: todo · Priority: P0 · Estimate: 4 h · Owner: — · Depends on: T-009a
- Requirements: M3 (second half)

## Goal

Show a saved room as an interactive 3D model off site, without camera permission. It is reachable from RoomDetail and works in the simulator.

## Tasks

- [ ] Create the viewer in `sitescope/Viewer3D/` using RealityKit `ARView(cameraMode: .nonAR)` (iOS 17 target; `RealityView` only behind `#available(iOS 18, *)`, if at all), building entities from the T-009a builders.
- [ ] Camera controls: orbit (one-finger drag), pan (two-finger drag), pinch-zoom and a reset-camera button.
- [ ] Add a "View 3D model" entry on RoomDetail that does not request camera permission.
- [ ] Empty state for unmapped rooms and rooms without surfaces.
- [ ] Provide a fixture room so the viewer runs in the simulator.

## Acceptance criteria

- [ ] Unit test: a room without surfaces yields the empty-state model, not a scene.
- [ ] Unit test: reset-camera helper returns the default pose after orbit, pan and zoom.
- [ ] Manual check in the simulator: fixture room opens from RoomDetail, can be orbited, zoomed and reset.
