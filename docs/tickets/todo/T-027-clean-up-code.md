# T-027 Clean up: abandoned code, bugs and large files

- Status: todo · Priority: P0 · Who: agent · Owner: — · Depends on: H-001
- Requirements: G5, G7, quality "Clean Code", "Lesbarkeit"

## Description

A smaller code base that both members can read and explain. Waits for H-001, which gives a working baseline to compare with.

## Tasks

- [x] **Delete:** printed markers and reference points (`Marker`, three `Room` fields, `AlignmentMath` including `AlignmentMath.manual`, `AlignmentMethod`). Old JSON keys are ignored, so no legacy types are needed.
- [ ] **Delete:** drawing kinds `marker`, `text`, `arrow` with `draftText`, `addArrow`, `ArrowGeometry`. Convert such notes on load first if H-001 found any: an unknown kind makes the whole local file unreadable. *Done so far (2026-11-27): `draftText` and all draft paths for these kinds are gone. The enum cases, saved-note rendering, `addArrow` and `ArrowGeometry` stay until H-001 reports.*
- [ ] **Delete:** code only tests use (`ARController.confirm()`, `ScanVisualization.rotate`, `ScanProgress.stage`, `horizontalCount`, `verticalCount`) and AR extras dropped in H-002. Move test fixtures off `.text`. *Done except the AR extras: H-002 has not decided on measured-distance placement and "Scan more surfaces".*
- [x] **Database:** merge the four migrations into one clean schema without those fields (they were never deployed; confirm first); run the pgTAP suite for the first time.
- [x] **Bugs:** files left behind after deleting rooms or projects, replacing images or failed saves; the Project screen never reloads its name field from the store (a rename from another device or a failed save leaves the draft in the title); in cloud mode a room rename does not reload `store.rooms`, so the project's room list keeps the old name until refresh; any unreadable sign-up reply shows "check your email"; the 100 MB limit is checked after the download; the export button stays disabled if the share sheet is torn down; export file named after the project. *Cloud storage files are still not removed on delete (T-008).*
- [ ] **Split:** `ARScreen`, `ManagementViews` and the import/export part of `Store`, without behavior change. Share one raycast helper, name the limits. Views do not call `Backend`. Move the "item still exists" checks for rename and delete from `ProjectDetailView` and `RoomDetailView` into `Store`, so the views only call `store.renameProject` / `store.deleteProject`.
- [ ] **Separate UI and logic:** `ProjectDetailView` and `RoomDetailView` decide themselves how to rename and delete (they call `store.run` with backend operations and check whether the item still exists), and the name trimming sits in `NameSection.swift`. Goal: views only show data and call `Store` methods; the `Store` owns the logic.
  - Move rename and delete for projects and rooms into `Store` (for example `renameProject(id:name:)`, `deleteProject(id:)`). The `Store` handles queuing, trimming and the "already deleted" check.
  - Views only call these methods and react to the result: no backend calls or existence checks in views.
  - Move the name trimming (`titleOrFallback` and the trim logic in `NameSection.commit`) into `Core/` with a unit test.
  - No UI or behavior change. Keep it small: no new layers such as a view model per screen unless clearly needed.

## Acceptance criteria

- [ ] Unit test: an old local file and an old archive with removed fields still open.
- [ ] One test per bug; no file another note uses is removed.
- [ ] Unit tests: name trimming in `Core/`; `Store` skips renaming a deleted project or room.
- [ ] Existing UI tests pass unchanged after separating UI and logic.
- [ ] Lint, `swift test`, simulator tests and `supabase test db` pass.
