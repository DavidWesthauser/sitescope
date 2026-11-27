# T-003 Cloud backend and accounts

- Status: in progress · Priority: P0 · Who: together · Owner: — · Depends on: T-027, H-002
- Requirements: M4, M6, G2, G3, G5

## Description

Users register, sign in and stay signed in, against Supabase. A human creates the hosted project in H-003 and reviews the access rules.

## Tasks

- [x] Schema from DATABASE_API.md as a fresh migration (old `supabase/` folder removed); app cloud paths use it (`CloudRecords.swift`, one default house per project until T-005, sharing via `grant_access` as `external`).
- [x] Start-up: sign-in screen with "Use Without an Account"; local projects stay usable after `Secrets.xcconfig` is added (choice remembered, Settings leads back to sign-in). Release builds without config still stop with an error.
- [ ] Register, sign in, sign out with the login name decided in H-002; validation and clear errors (wrong password, unconfirmed email, offline).
- [x] `profiles` table with RLS; session refresh and Keychain cleared on sign-out (existing `Backend`).
- [x] Update BACKEND_SETUP.md.
- [ ] Push the migration to the hosted project and sign in from the simulator.

## Acceptance criteria

- [x] pgTAP: outsiders read nothing; a profile is only changed by its owner (`supabase/tests/access.test.sql`, passes locally 2026-11-27).
- [ ] Unit tests with a fake server: register, refresh, sign-out.
- [ ] UI tests: local mode button, invalid login error.
- [ ] A human reviewed the RLS policies.
