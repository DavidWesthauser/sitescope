# T-003 Cloud backend and accounts

- Status: in progress · Priority: P0 · Who: together · Owner: — · Depends on: H-002
- Requirements: M4, M6, G2, G3, G5

## Description

Users register, sign in and stay signed in against Supabase, and the app is only usable while signed in. The app follows the database design in DATABASE_API.md (projects → houses → rooms, access levels, organizations), which runs on the hosted project. A human reviews the access rules.

## Tasks

- [x] Login required: the app shows only the sign-in screen until someone is signed in. On-device mode and `.sitescope` file export/import are removed (decided 2026-11-27).
- [x] App talks to the design in DATABASE_API.md: `CloudRepository`, request bodies in `CloudRecords.swift`, `scope_level` per screen, `Core/Access.swift` for the permission table.
- [x] Settings: own display name, email, sign out; administration for admins (activate/deactivate people, organizations).
- [ ] Register, sign in, sign out with the login name decided in H-002; validation and clear errors (wrong password, unconfirmed email, offline).
- [x] Session refresh and Keychain cleared on sign-out (existing `Backend`).
- [x] Update BACKEND_SETUP.md.

## Acceptance criteria

- [ ] pgTAP: outsiders read nothing; a profile is only changed by its owner (needs the design as a migration, T-029).
- [ ] Unit tests with a fake server: register, refresh, sign-out.
- [x] Unit tests with a fake server: `scope_level` arguments, room insert columns, grants query (`BackendTests`).
- [ ] UI tests: sign-in required (`testAppRequiresSignIn`), invalid login error; run them on the simulator.
- [ ] Sign in from the app against the hosted project (needs `Secrets.xcconfig`).
- [ ] A human reviewed the RLS policies.
