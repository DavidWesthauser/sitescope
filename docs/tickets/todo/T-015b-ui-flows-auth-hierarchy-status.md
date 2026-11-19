# T-015b UI flows: sign in, hierarchy CRUD, task status

- Status: todo · Priority: P0 · Estimate: 3 h · Owner: — · Depends on: T-015a; T-004, T-005, T-007
- Requirements: G6, grading "≥ 3 central user flows incl. ≥ 1 error case"

## Goal

Add four UI tests covering the first three central UI flows (sign in, hierarchy CRUD, task status) against the mock backend. They include the wrong-password error case and check persistence with a relaunch.

## Tasks

- [ ] Sign-in flow: sign in with valid credentials, reach the project list, sign out.
- [ ] Wrong-password flow: sign in with a wrong password and see the error message.
- [ ] Hierarchy flow: create project → house → room, rename the room, delete it, then relaunch and check the state.
- [ ] Task flow: open a task without AR, change its status, relaunch and check the new status.

## Acceptance criteria

- [ ] The four UI tests pass with no skips.
- [ ] The wrong-password test asserts the visible error text.
- [ ] The relaunch assertions read data from persistent storage, not only from memory.
