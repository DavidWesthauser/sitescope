# T-018 Reproducible backend setup, seed data and examiner accounts

- Status: todo · Priority: P1 · Estimate: 4 h · Owner: — · Depends on: T-005, T-006, T-011
- Requirements: technical rules "Bereitstellung des Backends", "Reproduzierbares Backend-Setup"

## Goal

Make the backend reproducible from the docs alone: ordered migrations, seed data for every role, and a fresh Supabase setup that works from BACKEND_SETUP.md.

## Tasks

- [ ] Keep all schema changes as ordered migrations (each a new timestamped `YYYYMMDDHHMM_name.sql` file); update `supabase/seed.sql` with users for every role (owner, admin, editor, technician, viewer, outsider), a project with 2 houses, rooms, comments.
- [ ] Hosted instance stays running until grading with test accounts; credentials handed over outside Git.
- [ ] Update BACKEND_SETUP.md: step-by-step from zero, CLI + dashboard variants.

## Acceptance criteria

- [ ] A team member sets up a fresh Supabase project from the docs alone and the app works with it.

## Notes

A real ARWorldMap cannot be faked. Provide a demo export file, or document that the examiner scans a room (or ship a recorded map from a real scan as a fixture asset).
