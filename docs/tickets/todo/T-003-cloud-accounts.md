# T-003 Cloud backend and accounts

- Status: todo · Priority: P0 · Who: together · Owner: — · Depends on: T-027, H-002
- Requirements: M4, M6, G2, G3, G5

## Description

Users register, sign in and stay signed in, against Supabase. A human creates the hosted project in H-003 and reviews the access rules.

## Tasks

- [ ] Start-up: sign-in screen with "Use without an account on this iPhone", also in Release; local projects stay usable after `Secrets.xcconfig` is added.
- [ ] Register, sign in, sign out with the login name decided in H-002; validation and clear errors (wrong password, unconfirmed email, offline).
- [ ] `profiles` table with RLS; session refresh and Keychain cleared on sign-out.
- [ ] Update BACKEND_SETUP.md.

## Acceptance criteria

- [ ] pgTAP: outsiders read nothing; a profile is only changed by its owner.
- [ ] Unit tests with a fake server: register, refresh, sign-out.
- [ ] UI tests: local mode button, invalid login error.
- [ ] A human reviewed the RLS policies.
