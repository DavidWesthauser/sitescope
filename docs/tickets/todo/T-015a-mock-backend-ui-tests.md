# T-015a Mock backend for UI tests

- Status: todo · Priority: P0 · Estimate: 3 h · Owner: — · Depends on: T-003, T-004 (the backend and login must exist before they are tested)
- Requirements: G6, grading "Automatisierte Tests"

## Goal

Let UI tests run cloud flows without credentials or network: a launch argument (`-uiTestMockBackend`) swaps the hosted Supabase for a fake `URLProtocol` session. Cloud UI tests then run instead of skipping, and the README gets the exact test commands.

## Tasks

- [ ] Read the `-uiTestMockBackend` launch argument at app start and select a fake-`URLProtocol` session in `Backend`.
- [ ] Fake the Supabase endpoints for auth, projects, houses, rooms, notes, comments and members with JSON fixtures. Return 401 for a wrong password.
- [ ] Add a UI test helper in `sitescopeUITests/` that launches with the argument and resets fixture state per test.
- [ ] Turn the two tests that skip today into running tests: `testAuthenticationValidation` (needs the login screen from T-004) and `testCreateProjectRoomRenameAndDelete` (needs cloud CRUD from T-003). Remove their `XCTSkip` paths.
- [ ] Add a README "Tests" section with `swift test`, `xcodebuild test -scheme sitescope …` and `supabase test db`.

## Acceptance criteria

- [ ] Smoke UI test: launch with the mock, sign in, and reach the project list with no network.
- [ ] `xcodebuild test` output shows no skipped cloud UI tests.
- [ ] Unit test: the JSON fixtures decode into the same models as real responses.
