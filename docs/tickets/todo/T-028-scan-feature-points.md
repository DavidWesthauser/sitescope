# T-028 Scan view with feature points

- Status: todo · Priority: P2 · Who: agent · Owner: — · Depends on: —
- Requirements: M3, G4

## Description

While scanning, show the feature points ARKit finds instead of animated surface patches, so users see where the scan is still thin. These are the same kind of points ARKit later matches to recognize the room. Surfaces stay as plain, static outlines because drawing needs them.

## Tasks

- [ ] Collect `frame.rawFeaturePoints` over time by point ID and render all of them as one point cloud.
- [ ] If rendering is slow on a phone, keep a new point only when no kept point is closer than a minimum distance (value found in testing). No fixed total count.
- [ ] Remove the outline animation and the miniature morph and fade-in; surface outlines stay, static.
- [ ] Show the cloud only while scanning, not while drawing or in the walkthrough.
- [ ] No change to what is saved in the map.

## Acceptance criteria

- [ ] Unit tests: the minimum-distance rule keeps and drops the right points; nothing is drawn outside scanning.
- [ ] A human confirms in H-001 that the scan stays smooth and the points are readable.
