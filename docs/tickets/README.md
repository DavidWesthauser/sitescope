# Tickets

One file per work item: `T-XXX-short-name.md`. Each has status, priority, estimate, owner, dependencies, the requirement IDs it serves ([REQUIREMENTS.md](../REQUIREMENTS.md)), tasks and acceptance criteria.

**Priority:** P0 = required for MUST-HAVEs / blocks others · P1 = needed for a good grade (quality, tests, docs) · P2 = polish · P3 = NICE-TO-HAVE.
**Status:** `todo` → `in-progress` → `done` (all acceptance criteria ticked and STATUS.md updated) · `blocked`.

Budget: ~160 h for two people. P0 + P1 ≈ 145 h, so NICE-TO-HAVEs only after the MUST-HAVEs are solid (they count only with ≥ 40/50 MUST points).

## Index

| ID | Title | Prio | Est. | Req. | Depends | Status | Owner |
|---|---|---|---:|---|---|---|---|
| [T-001](T-001-finish-siteAR-rename.md) | Finish sitescope → SiteAR rename | P0 | 3 h | G6, G7 | — | done | |
| [T-002](T-002-gitignore-secrets.md) | Fix .gitignore for Secrets.xcconfig | P0 | 0.5 h | rules | — | in-progress | |
| [T-003](T-003-connect-supabase.md) | Connect hosted Supabase, cloud mode default | P0 | 6 h | G2, G3, M1, M4 | 001, 002 | todo | |
| [T-004](T-004-auth-username-password.md) | Register / sign in / sign out | P0 | 6 h | M6, G3 | 003 | todo | |
| [T-005](T-005-house-hierarchy.md) | Project → House → Room hierarchy | P0 | 10 h | M9 | 001 | todo | |
| [T-006](T-006-role-management.md) | Roles with read/write/delete rights | P0 | 10 h | M5, G3 | 003, 005 | todo | |
| [T-007](T-007-server-crud-room-notes.md) | Room notes CRUD on server | P0 | 6 h | M1, M4 | 003, 006 | todo | |
| [T-008](T-008-offline-sync.md) | Offline queue + upload on reconnect | P0 | 16 h | M2, G5 | 007 | todo | |
| [T-009](T-009-3d-viewer.md) | 3D model viewer (off site) | P0 | 12 h | M3 | 001 | todo | |
| [T-010](T-010-ar-device-acceptance.md) | Physical AR acceptance on iPhones | P1 | 6 h | M3, G4 | 001 | todo | |
| [T-011](T-011-comments.md) | Comments: text, image, audio | P0 | 14 h | M8, G4 | 005, 006 | todo | |
| [T-012](T-012-dark-mode.md) | Dark mode audit + appearance setting | P1 | 3 h | M7, G1 | 001 | todo | |
| [T-013](T-013-architecture-refactor.md) | Split Store into repositories + view models | P1 | 10 h | G7 | 001 | todo | |
| [T-014](T-014-code-style-lint.md) | Formatter + linter, readable style | P1 | 4 h | quality | 001 | done | |
| [T-015](T-015-automated-tests.md) | Tests per grading scheme | P0 | 12 h | G6 | 001 | todo | |
| [T-016](T-016-error-handling-lifecycle.md) | Error, loading, lifecycle handling | P1 | 5 h | G5 | 003, 008 | todo | |
| [T-017](T-017-accessibility-hig.md) | Accessibility + HIG audit, in-app guide | P2 | 4 h | G1 | UI tickets | todo | |
| [T-018](T-018-seed-data-backend-setup.md) | Seed data, reproducible backend, examiner accounts | P1 | 4 h | rules | 005, 006, 011 | todo | |
| [T-019](T-019-readme-submission.md) | README for submission (incl. AI reflection) | P1 | 4 h | P4 | end | todo | both |
| [T-020](T-020-git-process.md) | Git workflow, regular commits by both | P0 | ongoing | P1–P3 | — | todo | both |
| [T-021](T-021-language-setting.md) | NICE: language setting DE/EN | P3 | 5 h | N1 | 001 | todo | |
| [T-022](T-022-lidar-mode.md) | NICE: optional LiDAR mode | P3 | 10 h | N2 | 009 | todo | |
| [T-023](T-023-export-3d-video.md) | NICE: export 3D file + video | P3 | 8 h | N3 | 009 | todo | |
| [T-024](T-024-two-factor-auth.md) | NICE: two-factor authentication | P3 | 6 h | N4 | 004 | todo | |
| [T-025](T-025-activity-live-progress.md) | NICE: activity feed / live progress | P3 | 8 h | mockups | 006, 008 | todo | |
| [T-026](T-026-ui-polish-smoke-test.md) | UI polish from simulator smoke test | P2 | 4 h | G1, G5 | 001 | todo | |

## Suggested order

1. T-001, T-002, T-020 (unblock everything)
2. T-013 together with T-005 (refactor while adding houses, avoids doing it twice)
3. T-003 → T-004 → T-006 → T-007 → T-008
4. T-009, T-011, T-012 in parallel (good split between the two members)
5. T-015 continuously; T-016, T-010, T-018, T-014, T-017
6. NICE-TO-HAVEs, then T-019

## New ticket template

```markdown
# T-XXX Title

- Status: todo · Priority: Px · Estimate: N h · Owner: — · Depends on: —
- Requirements: Mx, Gx

## Goal / Problem
## Tasks
- [ ] ...
## Acceptance criteria
- [ ] ...
```
