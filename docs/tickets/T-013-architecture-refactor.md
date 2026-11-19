# T-013 Architecture: split Store into repositories and view models

- Status: todo · Priority: P1 · Estimate: 10 h · Owner: — · Depends on: T-001 (do before or together with T-005/T-008)
- Requirements: G7, quality "Aufbau", "Clean Code"

## Problem
`Store.swift` is one main-actor class for local persistence, cloud calls, transfer import/export and UI error state, with `if isLocalMode … else …` in every method. Views call the backend directly (`store.client().rpc("share_project")`, `rpc("revoke_worker")` in ManagementViews.swift). Legacy marker/reference fields are still in models and validation.

## Tasks
- [ ] Introduce protocols `ProjectRepository`, `RoomRepository`, `NoteRepository`, `CommentRepository`, `MemberRepository` with `Local*` and `Remote*` implementations (+ sync layer from T-008).
- [ ] One `@Observable` view model per screen (ProjectList, ProjectDetail, HouseDetail, RoomDetail, TaskEditor, Team, Settings); views only bind to them.
- [ ] Move transfer import/export into `ProjectTransferService`.
- [ ] Split `ManagementViews.swift` (310 lines, 8 screens) into one file per screen under `Views/Projects`, `Views/Rooms`, ...
- [ ] Remove or isolate legacy marker/reference-point code paths (keep decoding).
- [ ] Update ARCHITECTURE.md with a diagram of the layers.
- [ ] Code review: `ARScreen.saveDrawing` uploads the image asset before `saveInstruction`, so a failed save orphans the PNG. Save in an order that cleans up on failure.
- [ ] Code review: `Backend.download` checks the 100 MB limit only after downloading the whole body. Check the limit while reading.
- [ ] Code review: `Backend.authenticate` uses `try?` on decode and returns false on register, which hides malformed responses. Surface the decode error.
- [ ] Code review: `ARController+Drawing` `hit()` and `updateTarget()` duplicate raycast and settle logic. Extract one shared helper.
- [ ] Code review: FreehandDraft limits (32 strokes, 2048 samples, 256 per stroke, 3 mm) are duplicated as literals in `Models.swift`. Extract shared constants.
- [ ] Code review: `Scanning` thresholds (2 s, 0.3, 0.35, 0.5 m) are magic numbers. Name them.

## Acceptance criteria
- [ ] No view references `Backend` or `store.client()`.
- [ ] Existing tests pass; repositories are unit-testable with fakes.
