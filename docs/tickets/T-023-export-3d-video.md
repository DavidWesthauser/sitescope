# T-023 (NICE N3) Export room as 3D file and AR walkthrough as video

- Status: todo · Priority: P3 · Estimate: 8 h · Owner: — · Depends on: T-009
- Requirements: N3

## Tasks
- [ ] Export the 3D viewer scene (surfaces/mesh + notes) as USDZ (and/or OBJ via ModelIO `MDLAsset`) → share sheet; opens in Quick Look.
- [ ] Record the AR walkthrough as video (ReplayKit `RPScreenRecorder` or AVAssetWriter from ARView frames) → save to Photos (permission handling).
- [ ] Keep `.sitescope`/`.sitear` project backup export (exists) — rename UI to "Export backup copy" as in mockup.

## Acceptance criteria
- [ ] USDZ opens in Files/Quick Look with notes visible; video saved to Photos.
