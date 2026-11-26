# T-021 NICE-TO-HAVEs

- Status: todo · Priority: P3 · Who: together · Owner: — · Depends on: H-002, T-015
- Requirements: N1, N2, N3, N4

## Description

Optional extras; they count only with at least 40 of 50 MUST points. H-002 picks which to build, and unpicked ones are deleted here.

## Tasks

- [ ] **Language (N1):** String Catalog, German translation including permission texts, language setting.
- [ ] **LiDAR (N2):** optional mesh as an extra file in room coordinates, shown in the 3D view and as a triangle mesh while scanning; camera-only phones keep the feature points (T-028). Curved drawing on Pro phones: freehand points land on the scene mesh and are saved as ordinary room-coordinate points, so non-LiDAR phones show them unchanged. A Debug-only "Draw on mesh" developer toggle tries this out first; it still has to be checked on a Pro iPhone, including viewing the stroke on a non-LiDAR iPhone after it recognizes a room scanned on a Pro.
- [ ] **Export (N3):** USDZ of the 3D view; AR walkthrough video to Photos.
- [ ] **2FA (N4):** Supabase TOTP enroll, verify on sign-in, remove.
- [ ] **Live progress (mockup):** activity feed and progress per room.

## Acceptance criteria

- [ ] Each built extra has a test and an entry in the README list.
- [ ] LiDAR, if built, was checked by a human on a Pro iPhone and a non-LiDAR iPhone.
