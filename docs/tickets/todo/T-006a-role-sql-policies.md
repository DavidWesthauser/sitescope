# T-006a Role SQL: policies, helpers and RPCs

- Status: todo · Priority: P0 · Estimate: 4 h · Owner: — · Depends on: T-003, T-005a
- Requirements: M5, G3

## Goal

The database enforces the roles from the epic table for every table and storage bucket.

## Tasks

- [ ] A new timestamped migration (`YYYYMMDDHHMM_name.sql`): `memberships.role text check (role in ('viewer','technician','editor','admin'))`, default `viewer`; owner stays `projects.owner_id`.
- [ ] SQL helper `has_role(project, min_role)`; rewrite policies on projects, houses, rooms, annotations, comments and storage objects to use it.
- [ ] RPCs `share_project(project, email, role)`, `set_member_role`, `revoke_member`: only Admin/Owner may call; cannot demote the owner.
- [ ] pgTAP per role: allowed and denied for each action, run as `authenticated` with JWT claims (same path as REST).

## Acceptance criteria

- [ ] pgTAP `supabase/tests/roles.test.sql`: each role's allowed and denied actions match the roles table.
- [ ] pgTAP: viewer insert, update and delete are denied through the REST path.
- [ ] pgTAP: after `revoke_member`, the removed user's next select returns no rows.
