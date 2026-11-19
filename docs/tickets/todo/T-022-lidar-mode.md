# T-022 Optional LiDAR mode for precise 3D models

- Status: todo · Priority: P3 · Estimate: 10 h · Owner: — · Depends on: T-009
- Requirements: N2

## Goal

Use the LiDAR scanner on supported iPhones to capture a precise room mesh for the 3D viewer. Camera-only phones keep the current flow unchanged.

## Tasks

- [ ] Detect support: `ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)`; show "LiDAR" badge in scan (mockup).
- [ ] Enable scene reconstruction during scan; save the mesh (simplified, bounded) as a room asset next to the world map.
- [ ] Use the mesh in the 3D viewer (T-009) and optionally for raycasts/occlusion in AR.
- [ ] Camera-only phones keep the current flow unchanged.

## Acceptance criteria

- [ ] On a LiDAR iPhone the 3D viewer shows a room mesh; on iPhone 12 mini nothing breaks.
