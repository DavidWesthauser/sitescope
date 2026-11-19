# T-009a Extract shared mesh builders

- Status: todo · Priority: P0 · Estimate: 4 h · Owner: — · Depends on: T-001
- Requirements: M3 (second half)

## Goal

Move the mesh code for surfaces, strokes, areas and images out of the AR-only files into plain, reusable builders. The 3D viewer and AR then share one implementation.

## Tasks

- [ ] Inventory mesh code in `sitescope/AR/ARController+Rendering.swift`, `ScanVisualization` and `DrawingGeometry`; mark which functions use ARKit types.
- [ ] Move the pure geometry (slab from a plane patch, stroke tube, area fill, image quad) into `sitescope/Core/MeshBuilders/` taking plain values (no ARKit import).
- [ ] Add a slab builder for `Room.surfaces` (plane patches as thin boxes).
- [ ] Point the AR rendering at the shared builders; no visible behaviour change.

## Acceptance criteria

- [ ] Unit tests in `sitescopeTests/` for slab, stroke, area and image builders (vertex count, bounds, normals) using fixtures without ARKit.
- [ ] `grep -rn "import ARKit" sitescope/Core/MeshBuilders` returns nothing.
- [ ] Build and existing tests pass after the move (`xcodebuild test`).
