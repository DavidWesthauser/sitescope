# T-015d pgTAP and unit tests for domain logic

- Status: todo · Priority: P0 · Estimate: 3 h · Owner: — · Depends on: T-003, T-005, T-006, T-008, T-011
- Requirements: G6, grading "Unit tests" and "reading/writing persistent data"

## Goal

Cover the new database tables and roles with pgTAP, and the domain logic with unit tests: roles and capabilities, hierarchy cascade, outbox and sync, comment validation, and local-data migration.

## Tasks

- [ ] pgTAP tests in `supabase/tests/` for the new tables and their RLS policies.
- [ ] Unit tests for the role matrix (read, write, delete per role).
- [ ] Unit test for the hierarchy cascade: deleting a project removes its houses, rooms and notes.
- [ ] Unit tests for the outbox and comment validation (empty, whitespace-only, too long).
- [ ] Unit test for local-data migration (old store to new schema).

## Acceptance criteria

- [ ] `supabase test db` is green against the local Supabase.
- [ ] A viewer role cannot delete (asserted in pgTAP and in a unit test).
- [ ] Running the migration twice does not duplicate data.
