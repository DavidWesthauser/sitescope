# T-006 Roles per project

- Status: todo · Priority: P0 · Who: together · Owner: — · Depends on: T-005, H-002
- Requirements: M5, G3

## Description

Each member has a role that decides what they may do, enforced on the server. A human reviews the policies.

## Tasks

- [ ] Migration: `memberships.role`, policies for all tables and storage, RPCs to share, change role and remove.
- [ ] Swift `ProjectRole` replaces the `manager` flag; changes the server rejects show a clear message.
- [ ] Team section: members by email, invite, change role, remove.

## Acceptance criteria

- [ ] pgTAP: allowed and denied actions match the table; a removed member reads nothing.
- [ ] Unit tests: capabilities match the table; unknown role falls back to viewer.
- [ ] UI test: invite, change role, remove; a viewer sees no controls.
- [ ] A human reviewed the policies.

## Notes

Proposed roles (H-002 confirms). Anyone who may comment can edit and delete their own comments; admin and owner can delete any.

| Role | Read | Change status | Create/edit | Delete rooms, houses, notes | Manage members | Delete project |
|---|---|---|---|---|---|---|
| Viewer | ✓ | | | | | |
| Technician | ✓ | ✓ | comments only | | | |
| Editor | ✓ | ✓ | ✓ | | | |
| Admin | ✓ | ✓ | ✓ | ✓ | ✓ | |
| Owner | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
