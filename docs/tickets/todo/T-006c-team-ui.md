# T-006c Team UI with roles

- Status: todo · Priority: P0 · Estimate: 3 h · Owner: — · Depends on: T-006a, T-006b
- Requirements: M5, G3

## Goal

Admins and owners manage project members and roles from the Team section, as in the mockup.

## Tasks

- [ ] Team section in ProjectDetail (per mockup): members with role and email.
- [ ] Invite sheet with email and role picker; calls `share_project`.
- [ ] Member detail: change role (`set_member_role`) and remove (`revoke_member`), with confirmation.
- [ ] Hide invite, change and remove for roles without `canManageMembers`; others see a read-only list.

## Acceptance criteria

- [ ] UI test `sitescopeUITests/TeamTests.swift`: invite with a role, change the role, remove the member.
- [ ] UI test: a viewer sees the member list without invite, change or remove controls.
