# Project status

Snapshot: **2026-11-28**. Requirement IDs refer to [REQUIREMENTS.md](REQUIREMENTS.md); ticket IDs to [tickets/](tickets/).

## Summary

- Sign-in is required; signed in, the app works offline (T-008): projects → houses → rooms with a description, a scan and drawings are saved on the phone first and synced in the background with revisions and per-field merge. Rights per project, house or room follow DATABASE_API.md (T-003).
- Rooms have no dimensions or status and drawings carry no text: no tasks (decided 2026-11-28).
- The hosted database does not have the target of T-029 yet, so projects and houses upload, while rooms, drawings, scans, renames and deletes stay on the phone marked "couldn't upload".
- Everything is named `sitescope` (T-001).
- `.gitignore` ignores `**/Secrets.xcconfig` and build artifacts; no secret was ever committed (history checked 2026-11-19, T-002).
- The hosted project runs the design from DATABASE_API.md (created in the SQL editor on 2026-11-26). It is not in `supabase/migrations/` and has no pgTAP tests in the repo yet (T-029).
- Missing entirely: comments UI (M8), 3D viewer (M3 part 2), multi-role permissions (M5), language setting, LiDAR mode, 3D/video export, 2FA.
- History was squashed into one `init` commit on 2026-11-05; regular small commits by both members from now on (P2, H-004).

## Ticket order

T-010 readout → H-001 → rest of T-010 → T-027 → T-003 → T-029 → H-003 → T-008 → T-005 → T-006 → T-011 → T-015 → H-005 → H-006 → H-007. Any time: H-002, H-004, T-009, T-012, T-028. T-021 only if time remains.

## Requirement status

Legend: ✅ done and verified · 🟡 partial / implemented but unverified · ❌ missing

| ID | Requirement | State | What exists / what's missing | Tickets |
|---|---|---|---|---|
| M1 | CRUD room notes, local + server | 🟡 | Drawings and the room description are created, changed and deleted on the phone and queued; the server side needs T-029 | T-029, T-008 |
| M2 | Upload later after offline creation | 🟡 | Persistent queue, upload on reconnect/foreground/refresh, conflicts by revision; covered by `SyncTests` with a fake server. Not yet possible against the hosted project (T-029) | T-008 |
| M3 | AR view on site + 3D view elsewhere | 🟡 | Scanning, drawing and the AR walkthrough are reachable again and save on the phone; uploading scans needs T-029. Physically unverified. No 3D model viewer | T-029, T-009, T-010, H-001 |
| M4 | Accounts and their files on backend | 🟡 | Accounts and records on the hosted project; no file storage yet | T-029, H-003 |
| M5 | Roles with read/write/delete rights | 🟡 | Levels admin / responsible / member / external from DATABASE_API.md, granted per project, house or room; screens show controls by level, checked in the simulator for member, external and a single-room grant (2026-11-27). Admin screens unchecked (no admin), not reviewed by a human, no pgTAP in the repo | T-006, T-029 |
| M6 | Login with username + password | 🟡 | Email/password sign-in required; sign-in, wrong-password error and sign-out checked in the simulator against the hosted project (2026-11-27). Login name decision open (H-002) | T-003 |
| M7 | Dark mode | 🟡 | System colors plus asset-catalog `AccentColor`/`Warning` (light, dark, high contrast, ≥ 4.5:1); Appearance setting System/Light/Dark in Settings (UI test: survives relaunch). Fixed white/black only in AR overlays. Simulator screenshots 2026-11-26 readable in both modes; no app icon, no full audit of AR screens | T-012 |
| M8 | Comments (image, audio, text) on project/house/room | ❌ | Not implemented | T-011 |
| M9 | Project → House → Room | 🟡 | All three levels on the phone; projects and houses sync, rooms need T-029 | T-005, T-029 |
| N1 | Language setting | ❌ | UI strings are English literals, no String Catalog | T-021 |
| N2 | LiDAR 3D models | ❌ | Camera-only plane detection; no RoomPlan/scene reconstruction | T-021 |
| N3 | Export 3D file / video | ❌ | Not implemented (the project transfer file was removed) | T-021 |
| N4 | 2FA | ❌ | Not implemented | T-021 |
| G1 | Mobile-first UI, HIG, accessibility | 🟡 | Native SwiftUI lists/forms/sheets; HIG pass on Project, Room, Task, Settings (inline names, destructive actions in own section with named confirmation, footers). New project, house, room, access and administration screens follow the same patterns. No VoiceOver audit; the screenshot tour was removed with on-device mode | T-012 |
| G2 | Cloud storage | 🟡 | Records on the hosted project; files and AR data not yet (T-029) | T-003, T-029 |
| G3 | Accounts + server-side protection | 🟡 | RLS, guards and column privileges of the design run on the hosted project; checked by hand against the API on a local copy (2026-11-27). No pgTAP in the repo, not reviewed by a human | T-003, T-006, T-029 |
| G4 | Native device feature | 🟡 | Camera + ARKit in the core workflow; permission request and denial message. Not verified on a phone since the latest changes. PhotosPicker for images | H-001 |
| G5 | Error handling / lifecycle | 🟡 | Validation, readable server errors, no blocking errors offline (status in the bottom bar, failed badge with retry), sync on foreground, AR interruption handling | T-008, T-012 |
| G6 | Automated tests | 🟡 | `swift test`: 82 core + 21 service tests pass, among them `SyncTests` (fake server with revisions, every T-008 rule). App and test targets compile without warnings; simulator unit/layout tests and UI flows were not run after T-008 | T-015 |
| G7 | Architecture / code quality | 🟡 | Folders App/Core/AR/Services/Views. Code is formatted with `swift-format` (`.swift-format`, see `docs/CONVENTIONS.md`) and lint-clean. Model (Core) → services → view model (`Store`) → views; no deprecated APIs; compiles without warnings (2026-11-28) | T-008, T-027 |
| — | Reproducible backend + seed data | ❌ | The design exists only on the hosted project; migration, seed and examiner accounts missing | T-029, T-015, H-007 |
| P2 | Regular commits by both members | 🟡 | History squashed into one `init` commit on 2026-11-05; work since then goes through branches and PRs. Both members still need regular commits | H-004 |
| P4 | AI reflection per member in README | 🟡 | Tool usage documented in AI_USAGE.md; personal examples per member missing | H-006 |

## What is implemented (code map)

See ARCHITECTURE.md for the layers. In short: screens in `sitescope/Views/` (`ProjectListView`, `ProjectView`, `HouseView`, `RoomView`, `AccessViews`, `SyncViews`, `SettingsView`, `ARScreen`), the view model `sitescope/App/Store.swift`, storage and sync in `sitescope/Services/` (`LocalDataStore`, `LocalRepository`, `SyncEngine`, `RemoteStore`), rules in `sitescope/Core/` (`Models`, `Access`, `Sync`, spatial math). Tests: `sitescopeTests` (core), `sitescopeAppTests` (backend, sync with a fake server, AR layout), `sitescopeUITests/WorkflowTests.swift`.

## Known issues

- Legacy marker/reference-point fields and constraints remain in models and migration 001 (inactive; deleted in T-027).
- Without `Secrets.xcconfig` the app shows only the sign-in screen with a hint.
- Until T-029 is on the server, deleting a project or house in the app cannot reach the server; the record stays there.
- Projects saved on phones in the old on-device mode stay in `local.json` but are no longer shown.
- In the design, creating a project accepts any `responsible_id` (see T-029).
- Force-quitting the app loses unsaved AR drafts.
- Long-scan crash on iPhone 12 mini reported earlier; mitigations added, never confirmed on device (H-001).
- The AR core is unproven on phones: accuracy, moved furniture and sharing between phones (H-001). A room map cannot be replaced, so a changed room means a new room without its notes (T-010).
- Bugs found by reading the code, including files left behind after deletes, are listed in T-027.

## Last verification

- 2026-11-28 (T-008, branch `T-003-cloud-accounts`):
  - Lint clean; `swift test` passes; app and tests compile without warnings; no deprecated APIs.
  - Simulator (iPhone 18 Pro) against the hosted project, test account as owner: sign-in; create project and house (uploaded); room saved on the phone and shown as "couldn't upload" with a readable reason (the server lacks the T-029 columns); description saved on the phone; rename; context menus, swipe to retry, Settings list of failed changes; people screen; delete alerts with Cancel; one-tap "…" menus; sign-out warning about waiting changes. Test projects removed from the server afterwards.
  - Not checked yet: offline mode in the simulator, conflict handling against a real server (needs T-029), AR on a phone.
- 2026-11-27 (T-003): rights as owner, member, external and room-only grant checked in the simulator.
- Physical device: last install was commit `88d4de7` (pre-squash, not in this repo) on iPhone 12 mini (2026-10-23); latest AR changes not tested on hardware.
