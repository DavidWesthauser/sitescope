# T-023 Export room as 3D file and AR walkthrough as video

- Status: todo · Priority: P3 · Estimate: 8 h · Owner: — · Depends on: T-009
- Requirements: N3

## Goal

Let users export a room as a 3D file and save an AR walkthrough as a video to Photos. The existing project backup export is renamed to match the mockup.

## Tasks

- [ ] Export the 3D viewer scene (surfaces/mesh + notes) as USDZ (and/or OBJ via ModelIO `MDLAsset`) → share sheet; opens in Quick Look.
- [ ] Record the AR walkthrough as video (ReplayKit `RPScreenRecorder` or AVAssetWriter from ARView frames) → save to Photos (permission handling).
- [ ] Keep `.sitescope` project backup export (exists) — rename UI to "Export backup copy" as in mockup.

## Acceptance criteria

- [ ] USDZ opens in Files/Quick Look with notes visible; video saved to Photos.
