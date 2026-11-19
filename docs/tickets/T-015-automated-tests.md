# T-015 Automated tests meeting the grading scheme

- Status: todo · Priority: P0 · Estimate: 12 h · Owner: — · Depends on: T-001; grows with every feature ticket
- Requirements: G6, grading "Automatisierte Tests" (10 pts)

## Grading needs
Unit tests for domain logic · **≥ 3 central user flows as UI/E2E tests incl. ≥ 1 error case** · tests pass and are reproducible via README · edge cases (empty data, invalid input) · reading/writing persistent data · backend mocked or local emulator.

## Tasks
- [x] Get existing suites running again after T-001; record counts in STATUS.md (done 2026-11-19).
- [ ] Mock backend for UI tests: launch argument that injects a fake `URLProtocol`/in-memory repository so cloud flows run without credentials (instead of skipping).
- [ ] UI flows (target set): 1) sign in (+ wrong password error) 2) create project → house → room, rename, delete, relaunch 3) open task without AR, change status, relaunch 4) add comment (+ empty comment rejected) 5) offline change then sync (mocked connectivity).
- [ ] Unit tests for new logic: roles/capabilities, hierarchy cascade, outbox/sync, comment validation, local-data migration.
- [ ] pgTAP tests for new tables/roles; run with local Supabase.
- [ ] README "Tests" section with exact commands (`swift test`, `xcodebuild test`, `supabase test db`).

## Acceptance criteria
- [ ] All suites green from a clean clone following README.
- [ ] At least 3 UI flows run without skipping, at least one asserts an error message.
