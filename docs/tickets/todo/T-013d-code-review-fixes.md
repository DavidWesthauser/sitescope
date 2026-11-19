# T-013d Code review fixes

- Status: todo · Priority: P1 · Estimate: 2 h · Owner: — · Depends on: T-001
- Requirements: G7, quality "Clean Code"

## Goal

Fix the five items from the code review, adding a test for each behavior change. Pure refactors must keep the existing tests green.

## Tasks

- [ ] `ARScreen.saveDrawing`: save the instruction before uploading the PNG, or delete the PNG if the save fails, so no orphan is left.
- [ ] `Backend.download`: count bytes while reading and stop once the 100 MB limit is passed.
- [ ] `Backend.authenticate`: surface the decode error on register instead of `try?` returning false.
- [ ] `ARController+Drawing`: extract one shared raycast and settle helper used by `hit()` and `updateTarget()`.
- [ ] Put the FreehandDraft limits (32 strokes, 2048 samples, 256 per stroke, 3 mm) in one constants type used by `Models.swift`. Name the Scanning thresholds (2 s, 0.3, 0.35, 0.5 m).

## Acceptance criteria

- [ ] Test: a failed save leaves no uploaded PNG behind (fake storage).
- [ ] Test: a download larger than the limit fails early with a size error, using a fake `URLProtocol`.
- [ ] Test: a malformed register response throws the decode error.
- [ ] No duplicated FreehandDraft literals remain (grep for `2048` finds only the constant); existing tests stay green.
