# Project status

Snapshot: **2026-11-19**. Requirement IDs refer to [REQUIREMENTS.md](REQUIREMENTS.md); ticket IDs to [tickets/](tickets/README.md).

## Summary

- The app is a working **local-only** prototype: projects → rooms, camera-only ARKit scanning, drawing/area/image instructions, task status, AR room recognition via ARWorldMap, and offline file transfer (`.sitescope`, AirDrop/Files).
- Build is green again: `swift test` and the simulator test run pass after the `sitescope` → `SiteAR` rename (T-001).
- `.gitignore` ignores `**/Secrets.xcconfig`, so the secrets file cannot be committed. Artifact entries and the history scan are still open (T-002).
- Supabase client, auth, Keychain, 4 migrations, RLS and a 31-assertion pgTAP suite are **written but never deployed or run**. The cloud requirements (G2, G3, M1 server side, M4, M6) are therefore not met yet.
- Missing entirely: houses level (M9), comments (M8), offline sync queue (M2), 3D viewer (M3 part 2), multi-role permissions (M5), language setting, LiDAR mode, 3D/video export, 2FA.
- Git history is one squashed `init` commit (2026-11-05, David). Both members need regular commits from now on (P2).

## Requirement status

Legend: ✅ done and verified · 🟡 partial / implemented but unverified · ❌ missing

| ID | Requirement | State | What exists / what's missing | Tickets |
|---|---|---|---|---|
| M1 | CRUD room notes, local + server | 🟡 | Local CRUD works (instructions + tasks). Server paths exist in `Store` but untested; no backend connected | T-003, T-007 |
| M2 | Upload later after offline creation | ❌ | No queue. Local mode never uploads; cloud mode fails without network | T-008 |
| M3 | AR view on site + 3D view elsewhere | 🟡 | AR walkthrough with ARWorldMap recognition implemented, physically unverified for latest code. No 3D model viewer (only a scan miniature during scanning) | T-009, T-010 |
| M4 | Accounts and their files on backend | 🟡 | Auth + Storage client (`Backend.swift`), private `room-assets` bucket in migration. Not deployed | T-003, T-007 |
| M5 | Roles with read/write/delete rights | 🟡 | Only owner(manager) + worker (worker may only change task status). Needs distinct read/write/delete roles | T-006 |
| M6 | Login with username + password | 🟡 | Email/password sign-in and sign-up UI and token refresh exist. Never run against live Auth | T-004 |
| M7 | Dark mode | 🟡 | Mostly system colors so dark mode mostly works; a few hard-coded `.white`/`.black`; no in-app setting; never audited | T-012 |
| M8 | Comments (image, audio, text) on project/house/room | ❌ | Not implemented | T-011 |
| M9 | Project → House → Room | ❌ | Only Project → Room | T-005 |
| N1 | Language setting | ❌ | UI strings are English literals, no String Catalog | T-021 |
| N2 | LiDAR 3D models | ❌ | Camera-only plane detection; no RoomPlan/scene reconstruction | T-022 |
| N3 | Export 3D file / video | 🟡 | Project transfer file exists (not a 3D model or video) | T-023 |
| N4 | 2FA | ❌ | Not implemented | T-024 |
| G1 | Mobile-first UI, HIG, accessibility | 🟡 | Native SwiftUI lists/forms/sheets, accessibility labels, Dynamic Type layout fixtures. No VoiceOver/contrast audit | T-017 |
| G2 | Cloud storage | ❌ | Backend not connected | T-003 |
| G3 | Accounts + server-side protection | 🟡 | RLS/storage policies authored, never executed | T-003, T-006, T-018 |
| G4 | Native device feature | ✅ | Camera + ARKit in the core workflow; permission request and denial message. PhotosPicker for images | — |
| G5 | Error handling / lifecycle | 🟡 | Validation, local write failure handling, unreadable-data recovery screen, AR interruption handling. Network/offline errors and permission flows for new features open | T-016 |
| G6 | Automated tests | 🟡 | 92 portable + 113 simulator unit/layout tests pass; 5 of 7 UI flows pass, 2 skip. Cloud flows not run (no test credentials) | T-015 |
| G7 | Architecture / code quality | 🟡 | Folders App/Core/AR/Services/Views. Code is formatted with `swift-format` (`.swift-format`, see `docs/CONVENTIONS.md`) and lint-clean. Remaining gap: `Store` mixes local + cloud + transfer; views call `store.client().rpc` directly | T-013 |
| — | Reproducible backend + seed data | 🟡 | Migrations, local seed (3 users), setup guide exist; need update for new schema and hosted examiner accounts | T-018 |
| P2 | Regular commits by both members | ❌ | Single squashed commit | T-020 |
| P4 | AI reflection per member in README | 🟡 | Tool usage documented in AI_USAGE.md; personal examples per member missing | T-019 |

## What is implemented (code map)

- **Projects/rooms/tasks UI**: `SiteAR/Views/ManagementViews.swift` (Auth, ProjectDashboard, ProjectDetail, MembersView, RoomDetail, TaskEditor, Settings, LocalDataRecoveryView).
- **State + persistence**: `SiteAR/App/Store.swift` — local JSON in Application Support (`sitescope/local.json`, `sitescope/assets/`), atomic serialized writes; cloud branch through `Backend`.
- **Backend client**: `SiteAR/Services/Backend.swift` — Supabase REST/Auth/Storage via URLSession, Keychain session (`Vault`).
- **AR**: `SiteAR/AR/ARController*.swift` — scanning with readiness gates (4 headings × 3 positions), map save, recognition, freehand/area/image drawing on a locked view, bounded rendering.
- **Pure logic**: `SiteAR/Core/*` — models + validation, spatial math, scan coverage, tracking quality, transfer archive codec, render budgets.
- **Backend schema**: `supabase/migrations/2026102*` — projects, memberships, rooms, annotations, RLS, RPCs `share_project`, `revoke_worker`, `set_task_status`, storage bucket `room-assets`.
- **Tests**: `SiteARTests` (core, portable), `SiteARAppTests` (store/backend fixtures, AR layout), `SiteARUITests/WorkflowTests.swift` (7 flows: import cancel, export sheet, auth validation, local project/room create, project rename relaunch, room rename/delete relaunch, cloud CRUD [skips without credentials]); `supabase/tests/access.test.sql`.

## Known issues

- Legacy marker/reference-point fields and constraints remain in models and migration 001 (inactive; cleanup in T-013).
- Release builds require backend config; Debug without config falls into local mode silently.
- Force-quitting the app loses unsaved AR drafts.
- Long-scan crash on iPhone 12 mini reported earlier; mitigations added, never confirmed on device (T-010).
- Only internal compatibility identifiers still say `sitescope`: bundle ID, `.sitescope` file type and extension, temp and local data folders, Keychain service, AR anchor name. App name and in-app text say SiteAR. The `.sitear` extension decision is open (follow-up to T-001).

## Last verification

- 2026-11-19 (after T-001, T-002 and the T-014 formatting pass): `swift test` 92 passed, 0 failed (79 SiteARCoreTests + 13 SiteARServiceTests). Simulator (iPhone 17): unit/layout 113 passed, 0 failed; UI 7 run, 5 passed, 2 skipped (auth validation in unconfigured Debug build; cloud CRUD without `sitescope_TEST_EMAIL`/`PASSWORD`). TEST SUCCEEDED. `swift format lint --strict --recursive` over SiteAR, SiteARTests, SiteARAppTests, SiteARUITests and Package.swift: clean (exit 0).
- 2026-11-19 simulator smoke test (manual, local Debug build, iPhone 17): all main local flows passed, no crash. UI findings are in T-026. Fixed during the run: an unreadable image showed "maximum 30 MB"; it now says the image could not be read (use PNG or JPEG).
- Bug fixed during the rename: transfer archive magic was `sitescope01` (11 bytes) while the reader checked 8 bytes, so every export failed to import. Now `SiteAR01`.
- Earlier (2026-10-31, before rename): 119 tests, 117 passed, 2 skipped. Superseded.
- pgTAP suite: never run. Physical device: last install was commit `88d4de7` on iPhone 12 mini (2026-10-23); latest AR changes not tested on hardware.
