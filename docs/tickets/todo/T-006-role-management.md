# T-006 Role management with read / write / delete rights per project

- Status: todo · Priority: P0 · Estimate: 10 h · Owner: — · Depends on: T-003, T-005
- Requirements: M5, G3

## Goal

Each project member has a role that determines what they may do, enforced by RLS — not only hidden buttons.

## Sub-tickets

- [T-006a](T-006a-role-sql-policies.md) SQL: memberships.role, has_role, policies, RPCs, pgTAP per role (4 h)
- [T-006b](T-006b-project-role-swift.md) Swift ProjectRole, capability helpers, replace manager flag, unit tests (3 h)
- [T-006c](T-006c-team-ui.md) Team UI: members, invite with role, change role / remove + UI test (3 h)

## Acceptance criteria

- [ ] Viewer cannot change anything — verified via direct REST call (not only UI).
- [ ] Editor can create but not delete; Admin can delete rooms; only Owner deletes project.
- [ ] Removing a member revokes access on next request.

## Notes

Proposed roles (confirm with team):

| Role | Read | Change task status | Create/edit notes, rooms, houses, comments | Delete rooms/houses/notes | Manage members | Delete project |
|---|---|---|---|---|---|---|
| Viewer | ✓ | | | | | |
| Technician | ✓ | ✓ | comments only | | | |
| Editor | ✓ | ✓ | ✓ | | | |
| Admin | ✓ | ✓ | ✓ | ✓ | ✓ | |
| Owner | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

Comments: anyone who may post can edit and delete their own; Admin and Owner can delete any comment (see T-011a).
