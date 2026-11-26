# Project status

Snapshot: **2026-11-19**. Requirement IDs refer to [REQUIREMENTS.md](REQUIREMENTS.md); ticket IDs to [tickets/](tickets/).

## Summary

- The app is a working **local-only** prototype: projects → rooms, camera-only ARKit scanning, drawing/area/image instructions, task status, AR room recognition via ARWorldMap, and offline file transfer (`.sitescope`, AirDrop/Files).
- Build is green: `swift test` and the simulator test run pass. Everything is named `sitescope` (T-001).
- `.gitignore` ignores `**/Secrets.xcconfig` and build artifacts; no secret was ever committed (history checked 2026-11-19, T-002).
- Supabase client, auth, Keychain, 4 migrations, RLS and a 31-assertion pgTAP suite are **written but never deployed or run**. The cloud requirements (G2, G3, M1 server side, M4, M6) are therefore not met yet.
- Missing entirely: houses level (M9), comments (M8), offline sync queue (M2), 3D viewer (M3 part 2), multi-role permissions (M5), language setting, LiDAR mode, 3D/video export, 2FA.
- History was squashed into one `init` commit on 2026-11-05; regular small commits by both members from now on (P2, H-004).

## Ticket order

T-010 readout → H-001 → rest of T-010 → T-027 → T-003 → H-003 → T-008 → T-005 → T-006 → T-011 → T-015 → H-005 → H-006 → H-007. Any time: H-002, H-004, T-009, T-012, T-028. T-021 only if time remains.

## Requirement status

Legend: ✅ done and verified · 🟡 partial / implemented but unverified · ❌ missing

| ID | Requirement | State | What exists / what's missing | Tickets |
|---|---|---|---|---|
| M1 | CRUD room notes, local + server | 🟡 | Local CRUD works (instructions + tasks). Server paths exist in `Store` but untested; no backend connected | T-003, T-008 |
| M2 | Upload later after offline creation | ❌ | No queue. Local mode never uploads; cloud mode fails without network | T-008 |
| M3 | AR view on site + 3D view elsewhere | 🟡 | AR walkthrough with ARWorldMap recognition implemented, physically unverified for latest code. No 3D model viewer (only a scan miniature during scanning) | T-009, T-010, H-001 |
| M4 | Accounts and their files on backend | 🟡 | Auth + Storage client (`Backend.swift`), private `room-assets` bucket in migration. Not deployed | H-003, T-008 |
| M5 | Roles with read/write/delete rights | 🟡 | Only owner(manager) + worker (worker may only change task status). Needs distinct read/write/delete roles | T-006 |
| M6 | Login with username + password | 🟡 | Email/password sign-in and sign-up UI and token refresh exist. Never run against live Auth | T-003 |
| M7 | Dark mode | 🟡 | Mostly system colors so dark mode mostly works; a few hard-coded `.white`/`.black`; simulator smoke test 2026-11-19 found Projects and project detail readable in dark mode; no full audit and no in-app setting yet | T-012 |
| M8 | Comments (image, audio, text) on project/house/room | ❌ | Not implemented | T-011 |
| M9 | Project → House → Room | ❌ | Only Project → Room | T-005 |
| N1 | Language setting | ❌ | UI strings are English literals, no String Catalog | T-021 |
| N2 | LiDAR 3D models | ❌ | Camera-only plane detection; no RoomPlan/scene reconstruction | T-021 |
| N3 | Export 3D file / video | 🟡 | Project transfer file exists (not a 3D model or video) | T-021 |
| N4 | 2FA | ❌ | Not implemented | T-021 |
| G1 | Mobile-first UI, HIG, accessibility | 🟡 | Native SwiftUI lists/forms/sheets, accessibility labels, Dynamic Type layout fixtures. No VoiceOver/contrast audit | T-012 |
| G2 | Cloud storage | ❌ | Backend not connected | T-003, H-003 |
| G3 | Accounts + server-side protection | 🟡 | RLS/storage policies authored, never executed | T-003, T-006 |
| G4 | Native device feature | 🟡 | Camera + ARKit in the core workflow; permission request and denial message. Not verified on a phone since the latest changes. PhotosPicker for images | H-001 |
| G5 | Error handling / lifecycle | 🟡 | Validation, local write failure handling, unreadable-data recovery screen, AR interruption handling. Network/offline errors and permission flows for new features open | T-012 |
| G6 | Automated tests | 🟡 | 92 portable + 113 simulator unit/layout tests pass; 5 of 7 UI flows pass, 2 skip. Cloud flows not run (no test credentials) | T-015 |
| G7 | Architecture / code quality | 🟡 | Folders App/Core/AR/Services/Views. Code is formatted with `swift-format` (`.swift-format`, see `docs/CONVENTIONS.md`) and lint-clean. Remaining gap: `Store` mixes local + cloud + transfer; views call `store.client().rpc` directly | T-008, T-027 |
| — | Reproducible backend + seed data | 🟡 | Migrations, local seed (3 users), setup guide exist; need update for new schema and hosted examiner accounts | T-015, H-007 |
| P2 | Regular commits by both members | 🟡 | History squashed into one `init` commit on 2026-11-05; work since then goes through branches and PRs. Both members still need regular commits | H-004 |
| P4 | AI reflection per member in README | 🟡 | Tool usage documented in AI_USAGE.md; personal examples per member missing | H-006 |

## What is implemented (code map)

- **Projects/rooms/tasks UI**: `sitescope/Views/ManagementViews.swift` (Auth, ProjectDashboard, ProjectDetail, MembersView, RoomDetail, TaskEditor, Settings, LocalDataRecoveryView).
- **State + persistence**: `sitescope/App/Store.swift` — local JSON in Application Support (`sitescope/local.json`, `sitescope/assets/`), atomic serialized writes; cloud branch through `Backend`.
- **Backend client**: `sitescope/Services/Backend.swift` — Supabase REST/Auth/Storage via URLSession, Keychain session (`Vault`).
- **AR**: `sitescope/AR/ARController*.swift` — scanning with readiness gates (4 headings × 3 positions), map save, recognition, freehand/area/image drawing on a locked view, bounded rendering.
- **Pure logic**: `sitescope/Core/*` — models + validation, spatial math, scan coverage, tracking quality, transfer archive codec, render budgets.
- **Backend schema**: `supabase/migrations/2026102*` — projects, memberships, rooms, annotations, RLS, RPCs `share_project`, `revoke_worker`, `set_task_status`, storage bucket `room-assets`.
- **Tests**: `sitescopeTests` (core, portable), `sitescopeAppTests` (store/backend fixtures, AR layout), `sitescopeUITests/WorkflowTests.swift` (7 flows: import cancel, export sheet, auth validation, local project/room create, project rename relaunch, room rename/delete relaunch, cloud CRUD [skips without credentials]); `supabase/tests/access.test.sql`.

## Known issues

- Legacy marker/reference-point fields and constraints remain in models and migration 001 (inactive; deleted in T-027).
- Release builds require backend config; Debug without config falls into local mode silently.
- Force-quitting the app loses unsaved AR drafts.
- Long-scan crash on iPhone 12 mini reported earlier; mitigations added, never confirmed on device (H-001).
- The AR core is unproven on phones: accuracy, moved furniture and sharing between phones (H-001). A room map cannot be replaced, so a changed room means a new room without its notes (T-010).
- Bugs found by reading the code, including files left behind after deletes, are listed in T-027.

## Last verification

- 2026-11-19, renamed `sitescope` project (after T-001, T-002 and the T-014 formatting pass):
  - Lint: `swift format lint --strict --recursive` clean.
  - `swift test`: 92 passed (79 core + 13 service).
  - Simulator (iPhone 17): unit/layout 113 passed. UI 7 run: 5 passed, 2 skipped (they need a backend: login and cloud CRUD, see T-015). UI tests are isolated (each test gets its own local data folder) and run with animations off: 135 s instead of 167 s.
  - Manual simulator smoke test after the rename passed: create project/room, AR unsupported message, export and re-import of a `.sitescope` file; all text says sitescope. UI findings in T-012.
- Bug fixed during the rename: transfer archive magic was 11 bytes (`sitescope01`) while the reader checked 8 bytes, so every export failed to import. Now `sscope01` (8 bytes).
- Earlier (2026-10-31, before rename): 119 tests, 117 passed, 2 skipped. Superseded.
- pgTAP suite: never run. Physical device: last install was commit `88d4de7` (pre-squash, not in this repo) on iPhone 12 mini (2026-10-23); latest AR changes not tested on hardware.
