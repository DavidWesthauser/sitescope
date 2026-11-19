# T-006b ProjectRole in Swift

- Status: todo · Priority: P0 · Estimate: 3 h · Owner: — · Depends on: T-006a, T-013a
- Requirements: M5, G3

## Goal

The app knows the current user's role per project and gates UI through one enum instead of the `manager: Bool` flag.

## Tasks

- [ ] `ProjectRole` enum (viewer, technician, editor, admin, owner) with raw values matching the DB check.
- [ ] Capability helpers `canChangeStatus`, `canComment`, `canEdit`, `canDelete`, `canManageMembers`, `canDeleteProject`, mirroring the roles table.
- [ ] Load the current user's role per project from the membership row (in `sitescope/App/Store.swift` or its repository).
- [ ] Replace the `manager: Bool` flag in views with `ProjectRole` capabilities.
- [ ] Implement `MemberRepository` (list members, share project, set role, revoke) with Local/Remote following T-013a's pattern.

## Acceptance criteria

- [ ] Unit tests `sitescopeTests/ProjectRoleTests.swift`: every capability matches the roles table.
- [ ] Unit tests: an unknown role string falls back to viewer; a missing membership row means no access.
