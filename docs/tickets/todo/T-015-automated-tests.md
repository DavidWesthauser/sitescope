# T-015 Automated tests meeting the grading scheme

- Status: todo · Priority: P0 · Estimate: 12 h · Owner: — · Depends on: T-001; grows with every feature ticket
- Requirements: G6, grading "Automatisierte Tests" (10 pts)

## Goal

Build the shared test setup and the grading-required UI flows, so unit, UI and database tests all run from a clean clone.

## Sub-tickets

- [T-015a](T-015a-mock-backend-ui-tests.md) Mock backend for UI tests and README test commands (3 h)
- [T-015b](T-015b-ui-flows-auth-hierarchy-status.md) UI flows: sign in, hierarchy CRUD, task status with relaunch (3 h)
- [T-015c](T-015c-ui-flows-comments-offline.md) UI flows: comments and offline change then sync (3 h)
- [T-015d](T-015d-pgtap-unit-tests.md) pgTAP and unit tests for roles, cascade, outbox, comments, migration (3 h)

## Acceptance criteria

- [ ] All suites green from a clean clone following README.
- [ ] At least 3 UI flows run without skipping, and at least one asserts an error message.
- [ ] Shared test infrastructure from T-015a is in place before the other sub-tickets.

## Notes

Grading needs: unit tests for domain logic · **≥ 3 central user flows as UI/E2E tests incl. ≥ 1 error case** · tests pass and are reproducible via README · edge cases (empty data, invalid input) · reading/writing persistent data · backend mocked or local emulator.

Rule: every feature ticket includes its own tests in its acceptance criteria. T-015 covers shared test infrastructure and the grading-required UI flows. Tests are written only for features that exist.

Done so far:

- [x] Get existing suites running again after T-001; record counts in STATUS.md (done 2026-11-19).
