# T-013a Repository protocols with Local and Remote implementations

- Status: todo · Priority: P1 · Estimate: 3 h · Owner: — · Depends on: T-001 (coordinate with T-008 sync layer)
- Requirements: G7, quality "Aufbau"

## Goal

Move persistence out of `Store.swift` into three repository protocols (`ProjectRepository`, `RoomRepository`, `NoteRepository`), each with `Local*` and `Remote*` implementations. Import/export moves to `ProjectTransferService`, and no `isLocalMode` branches remain in Store.

## Tasks

- [ ] Define the three repository protocols (async throws) and the models they use.
- [ ] Implement `Local*` repositories on the existing local storage.
- [ ] Implement `Remote*` repositories on `Backend`.
- [ ] Move transfer import/export into `ProjectTransferService`.
- [ ] Pick the repository set by mode in one composition point; delete the `isLocalMode` branches.

## Acceptance criteria

- [ ] Unit test per repository protocol with a fake, plus a `LocalProjectRepository` write-then-read round trip on disk.
- [ ] Unit test: export then import with `ProjectTransferService` gives an equal project.
- [ ] `grep -rn "Backend\|client()" sitescope/Views` returns nothing; existing suites stay green.

## Notes

Comment and member repositories are created in T-011a and T-006b using the same protocol pattern.
