# T-013b One @Observable view model per screen

- Status: todo · Priority: P1 · Estimate: 3 h · Owner: — · Depends on: T-013a, T-005c, T-006b
- Requirements: G7, quality "Clean Code"

## Goal

Give each screen (ProjectList, ProjectDetail, HouseDetail, RoomDetail, TaskEditor, Team, Settings) one `@Observable` view model that takes repository protocols in its `init`. Views bind only to their view model, never to Store or the backend.

## Tasks

- [ ] Add the seven view models under `sitescope/ViewModels/`, each taking repository protocols in `init`.
- [ ] Move loading, error and validation state from Store into the matching view model.
- [ ] Switch each screen view to read and call only its view model.
- [ ] Reduce Store to app-level state (mode, session) or remove it.

## Acceptance criteria

- [ ] Each view model has a unit test with fake repositories for load success and load failure.
- [ ] Team view model test: revoking a worker calls `MemberRepository` once and refreshes the member list.
- [ ] Simulator walk through all seven screens shows the same behavior as before (noted in the PR).
