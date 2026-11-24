# T-015 Tests, README and seed data

- Status: todo · Priority: P0 · Who: agent · Owner: — · Depends on: T-005, T-006, T-008, T-009, T-011
- Requirements: G6, P4, grading "Automatisierte Tests", technical rules "README", "Reproduzierbares Backend-Setup"

## Description

A grader can set up, test and use the app from a clean clone. Features bring their own tests; this adds the central flows and the documentation. Personal reflections are H-006.

## Tasks

- [ ] Mock backend for UI tests (`-uiTestMockBackend`); no skipped tests.
- [ ] UI flows: sign in, wrong password, hierarchy with relaunch, task status with relaunch, comment, offline change that syncs.
- [ ] README: install, tests, user guide, NICE-TO-HAVE list, limitations, AI tools; every command tried.
- [ ] Seed data with a user per role, two houses, rooms and comments; BACKEND_SETUP.md from zero; how to get a real room map.

## Acceptance criteria

- [ ] All suites green from a clean clone, at least three flows and one error case.
- [ ] `supabase db reset` loads the seed and `supabase test db` passes.
