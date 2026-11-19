# T-006 Role management with read / write / delete rights per project

- Status: todo · Priority: P0 · Estimate: 10 h · Owner: — · Depends on: T-003, T-005
- Requirements: M5, G3

## Goal
Each project member has a role that determines what they may do, enforced by RLS — not only hidden buttons.

## Proposed roles (confirm with team)
| Role | Read | Change task status | Create/edit notes, rooms, houses, comments | Delete rooms/houses/notes | Manage members | Delete project |
|---|---|---|---|---|---|---|
| Viewer | ✓ | | | | | |
| Technician | ✓ | ✓ | comments only | | | |
| Editor | ✓ | ✓ | ✓ | | | |
| Admin | ✓ | ✓ | ✓ | ✓ | ✓ | |
| Owner | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

## Tasks
- [ ] Migration: `memberships.role text check (role in (...))`, default `viewer`; owner remains `projects.owner_id`.
- [ ] SQL helpers `has_role(project, min_role)`; rewrite policies on projects, houses, rooms, annotations, comments, storage objects to use them.
- [ ] RPCs: `share_project(project, email, role)`, `set_member_role`, `revoke_member`; only Admin/Owner; cannot demote owner.
- [ ] Swift: `ProjectRole` enum with capability helpers (`canEdit`, `canDelete`, ...); load current user's role per project; replace the `manager: Bool` flag in views.
- [ ] UI: Team section in ProjectDetail (mockup): members with role + email, invite with role picker, member detail with change role / remove.
- [ ] pgTAP tests per role (allowed + denied for each action).

## Acceptance criteria
- [ ] Viewer cannot change anything — verified via direct REST call (not only UI).
- [ ] Editor can create but not delete; Admin can delete rooms; only Owner deletes project.
- [ ] Removing a member revokes access on next request.
- [ ] Unit tests for `ProjectRole` capability mapping.
