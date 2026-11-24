# T-027 Clean up: abandoned code, bugs and large files

- Status: todo · Priority: P0 · Who: agent · Owner: — · Depends on: H-001
- Requirements: G5, G7, quality "Clean Code", "Lesbarkeit"

## Description

A smaller code base that both members can read and explain. Waits for H-001, which gives a working baseline to compare with.

## Tasks

- [ ] **Delete:** printed markers and reference points (`Marker`, three `Room` fields, `AlignmentMath`, `AlignmentMethod`); keep `AlignmentMath.manual` if T-010 uses it. Old JSON keys are ignored, so no legacy types are needed.
- [ ] **Delete:** drawing kinds `marker`, `text`, `arrow` with `draftText`, `addArrow`, `ArrowGeometry`. Convert such notes on load first if H-001 found any: an unknown kind makes the whole local file unreadable.
- [ ] **Delete:** code only tests use (`ARController.confirm()`, `ScanVisualization.rotate`, `ScanProgress.stage`, `horizontalCount`, `verticalCount`) and AR extras dropped in H-002. Move test fixtures off `.text`.
- [ ] **Database:** merge the four migrations into one clean schema without those fields (they were never deployed; confirm first); run the pgTAP suite for the first time.
- [ ] **Bugs:** files left behind after deleting rooms or projects, replacing images or failed saves; `Store.run` ignores actions while busy; any unreadable sign-up reply shows "check your email"; the 100 MB limit is checked after the download; the export button stays disabled if the share sheet is torn down; export file named after the project.
- [ ] **Split:** `ARScreen`, `ManagementViews` and the import/export part of `Store`, without behavior change. Share one raycast helper, name the limits. Views do not call `Backend`.

## Acceptance criteria

- [ ] Unit test: an old local file and an old archive with removed fields still open.
- [ ] One test per bug; no file another note uses is removed.
- [ ] Lint, `swift test`, simulator tests and `supabase test db` pass.
