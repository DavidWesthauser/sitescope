# T-010 Scan, recognize and share a room

- Status: todo · Priority: P0 · Who: together · Owner: — · Depends on: —
- Requirements: M3, G4, G5

## Description

The core of the app: scan a room, find the notes again later, also after the room changed and on another phone. An agent builds; H-001 measures on real phones.

## Tasks

- [ ] **Before H-001:** Debug-only readout with a copy button: scan time, map size and feature points, seconds until recognized, and how far the restored anchor is from the assumed position (today the app ignores its position), phone model and iOS version. Debug builds also get a developer panel with toggles for ARKit's built-in debug views (feature points, LiDAR mesh preview, plane geometry, anchor and world origins, render statistics). No change to AR behavior in Release builds.
- [ ] **After H-001, if notes are offset:** place notes relative to the restored anchor instead of the identity.
- [ ] **After H-001:** "Update scan" for changed rooms: recognize with the old map, keep scanning, save a new map version with the same `coordinate_id`, keep notes and allow undo. Today a map can never be replaced; adjust the local rule and the database trigger.
- [ ] Tell users to place notes on walls and fixed objects; suggest "Update scan" after slow recognition.

## Acceptance criteria

- [ ] Unit tests: offset math, readout text, new map version keeps notes and `coordinate_id`, undo, saving without recognition refused.
- [ ] A Release build contains no readout.
- [ ] A human repeats the failed parts of H-001; result in STATUS.md.
