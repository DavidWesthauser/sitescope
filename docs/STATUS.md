# Project status

Snapshot: **2026-11-27**. Requirement IDs refer to [REQUIREMENTS.md](REQUIREMENTS.md); ticket IDs to [tickets/](tickets/).

## Summary

- The app needs an account and works against Supabase: projects → houses → rooms (name, size, status), the person responsible, access grants (member/external per project, house or room) and administration (people, organizations), all following DATABASE_API.md. On-device mode and `.sitescope` file transfer were removed (T-003, 2026-11-27).
- The AR code (camera-only scanning, drawing/area/image instructions, ARWorldMap recognition) is still in the app, but not reachable: the database has nowhere to store scans and instructions yet (T-029).
- Build is green: `swift test` and the simulator test run pass. Everything is named `sitescope` (T-001).
- `.gitignore` ignores `**/Secrets.xcconfig` and build artifacts; no secret was ever committed (history checked 2026-11-19, T-002).
- The hosted project runs the design from DATABASE_API.md (created in the SQL editor on 2026-11-26). It is not in `supabase/migrations/` and has no pgTAP tests in the repo yet (T-029).
- Missing entirely: comments UI (M8), offline sync queue (M2), 3D viewer (M3 part 2), multi-role permissions (M5), language setting, LiDAR mode, 3D/video export, 2FA.
- History was squashed into one `init` commit on 2026-11-05; regular small commits by both members from now on (P2, H-004).

## Ticket order

T-010 readout → H-001 → rest of T-010 → T-027 → T-003 → T-029 → H-003 → T-008 → T-005 → T-006 → T-011 → T-015 → H-005 → H-006 → H-007. Any time: H-002, H-004, T-009, T-012, T-028. T-021 only if time remains.

## Requirement status

Legend: ✅ done and verified · 🟡 partial / implemented but unverified · ❌ missing

| ID | Requirement | State | What exists / what's missing | Tickets |
|---|---|---|---|---|
| M1 | CRUD room notes, local + server | ❌ | Room notes need tables in the database (T-029); on-device storage was removed | T-029, T-008 |
| M2 | Upload later after offline creation | ❌ | No queue; the app needs the network | T-008 |
| M3 | AR view on site + 3D view elsewhere | 🟡 | AR walkthrough with ARWorldMap recognition implemented but not reachable until scans can be stored (T-029); physically unverified. No 3D model viewer | T-029, T-009, T-010, H-001 |
| M4 | Accounts and their files on backend | 🟡 | Accounts and records on the hosted project; no file storage yet | T-029, H-003 |
| M5 | Roles with read/write/delete rights | 🟡 | Levels admin / responsible / member / external from DATABASE_API.md, granted per project, house or room; screens show controls by level. Not reviewed by a human, no pgTAP in the repo | T-006, T-029 |
| M6 | Login with username + password | 🟡 | Email/password sign-in required; the hosted Auth accepted the test account through the API. Not yet signed in from the app; login name decision open (H-002) | T-003 |
| M7 | Dark mode | 🟡 | System colors plus asset-catalog `AccentColor`/`Warning` (light, dark, high contrast, ≥ 4.5:1); Appearance setting System/Light/Dark in Settings (UI test: survives relaunch). Fixed white/black only in AR overlays. Simulator screenshots 2026-11-26 readable in both modes; no app icon, no full audit of AR screens | T-012 |
| M8 | Comments (image, audio, text) on project/house/room | ❌ | Not implemented | T-011 |
| M9 | Project → House → Room | 🟡 | Screens for all three levels against the hosted design; not yet run in the simulator | T-005 |
| N1 | Language setting | ❌ | UI strings are English literals, no String Catalog | T-021 |
| N2 | LiDAR 3D models | ❌ | Camera-only plane detection; no RoomPlan/scene reconstruction | T-021 |
| N3 | Export 3D file / video | ❌ | Not implemented (the project transfer file was removed) | T-021 |
| N4 | 2FA | ❌ | Not implemented | T-021 |
| G1 | Mobile-first UI, HIG, accessibility | 🟡 | Native SwiftUI lists/forms/sheets; HIG pass on Project, Room, Task, Settings (inline names, destructive actions in own section with named confirmation, footers). New project, house, room, access and administration screens follow the same patterns. No VoiceOver audit; the screenshot tour was removed with on-device mode | T-012 |
| G2 | Cloud storage | 🟡 | Records on the hosted project; files and AR data not yet (T-029) | T-003, T-029 |
| G3 | Accounts + server-side protection | 🟡 | RLS, guards and column privileges of the design run on the hosted project; checked by hand against the API on a local copy (2026-11-27). No pgTAP in the repo, not reviewed by a human | T-003, T-006, T-029 |
| G4 | Native device feature | 🟡 | Camera + ARKit in the core workflow; permission request and denial message. Not verified on a phone since the latest changes. PhotosPicker for images | H-001 |
| G5 | Error handling / lifecycle | 🟡 | Validation, server errors as readable messages, AR interruption handling. Network/offline errors and permission flows for new features open | T-012 |
| G6 | Automated tests | 🟡 | `swift test`: 83 pass (2026-11-27). Simulator unit/layout and the 2 UI flows compile but were not run after T-003 | T-015 |
| G7 | Architecture / code quality | 🟡 | Folders App/Core/AR/Services/Views. Code is formatted with `swift-format` (`.swift-format`, see `docs/CONVENTIONS.md`) and lint-clean. `Store` is a view model only; cloud calls live in `Services/`. Compiles without warnings (2026-11-27) | T-008, T-027 |
| — | Reproducible backend + seed data | ❌ | The design exists only on the hosted project; migration, seed and examiner accounts missing | T-029, T-015, H-007 |
| P2 | Regular commits by both members | 🟡 | History squashed into one `init` commit on 2026-11-05; work since then goes through branches and PRs. Both members still need regular commits | H-004 |
| P4 | AI reflection per member in README | 🟡 | Tool usage documented in AI_USAGE.md; personal examples per member missing | H-006 |

## What is implemented (code map)

- **Screens**: `ManagementViews.swift` (sign-in, project list), `ProjectDetailView`, `HouseDetailView`, `RoomDetailView`, `AccessViews` (grants, responsible person), `AdministrationView`, `SettingsView`; AR screens (`ARScreen`, `TaskEditor`) wait for T-029.
- **State**: `sitescope/App/Store.swift` (view model). **Server**: `CloudRepository` (tables and RPCs of DATABASE_API.md), request bodies in `CloudRecords.swift`, client `Backend.swift` (REST/Auth via URLSession, Keychain session `Vault`).
- **AR**: `sitescope/AR/ARController*.swift` — scanning with readiness gates (4 headings × 3 positions), map save, recognition, freehand/area/image drawing on a locked view, bounded rendering.
- **Pure logic**: `sitescope/Core/*` — models + validation, access levels and the permission table (`Access.swift`), spatial math, scan coverage, tracking quality, render budgets.
- **Tests**: `sitescopeTests` (core, portable), `sitescopeAppTests` (store/backend fixtures, `InMemoryRepository`, AR layout), `sitescopeUITests/WorkflowTests.swift` (sign-in required; project → house → room flow, skips without test credentials).

## Known issues

- Legacy marker/reference-point fields and constraints remain in models and migration 001 (inactive; deleted in T-027).
- Without `Secrets.xcconfig` the app shows only the sign-in screen with a hint; nothing works offline.
- Projects saved on phones in the old on-device mode stay in `local.json` but are no longer shown.
- In the design, creating a project accepts any `responsible_id` (see T-029).
- Force-quitting the app loses unsaved AR drafts.
- Long-scan crash on iPhone 12 mini reported earlier; mitigations added, never confirmed on device (H-001).
- The AR core is unproven on phones: accuracy, moved furniture and sharing between phones (H-001). A room map cannot be replaced, so a changed room means a new room without its notes (T-010).
- Bugs found by reading the code, including files left behind after deletes, are listed in T-027.

## Last verification

- 2026-11-27 (T-003, branch `T-003-cloud-accounts`):
  - Lint clean; `swift test`: 83 passed. App and test targets compile for the simulator without warnings (`build-for-testing`); simulator tests were not run.
  - The app's requests checked against a local copy of the design: create project, house, room; room details; `scope_level` 3 (responsible) and 2 (member); member cannot delete rooms or create houses; outsider sees nothing; only admins hand over projects; nobody changes their own active flag.
  - Hosted project: sign-in with the test account works through the API.
- Physical device: last install was commit `88d4de7` (pre-squash, not in this repo) on iPhone 12 mini (2026-10-23); latest AR changes not tested on hardware.
