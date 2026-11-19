# T-009 3D view of a saved room usable anywhere (no AR)

- Status: todo · Priority: P0 · Estimate: 12 h · Owner: — · Depends on: T-001
- Requirements: M3 (second half)

## Goal
Open a mapped room off site and inspect its notes in an interactive 3D model.

## Tasks
- [ ] Build geometry from saved data: `Room.surfaces` (plane patches) as thin slabs + annotations (strokes, areas, images) at `roomFromAnnotation` poses. Reuse `ScanVisualization`/`DrawingGeometry`/`ARController+Rendering` mesh code — extract shared builders, don't duplicate.
- [ ] Viewer: RealityKit `ARView(cameraMode: .nonAR)` or `RealityView` (iOS 18) with orbit, pan, pinch-zoom, reset camera.
- [ ] Tap a note → opens TaskEditor; status colors (completed = green).
- [ ] Entry point "View 3D model" on RoomDetail (works without camera permission and in the simulator).
- [ ] Empty state for unmapped rooms / rooms without surfaces.
- [ ] (Optional link to N2) use LiDAR mesh if captured.

## Acceptance criteria
- [ ] Viewer works in the simulator with a fixture room and on device off site.
- [ ] Notes appear at the same relative positions as in AR.
- [ ] Snapshot/layout test for the viewer.
