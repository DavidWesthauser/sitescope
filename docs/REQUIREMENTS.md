# Requirements (combined)

Sources, condensed: our submitted requirements document (Anforderungen Projekt, incl. mockups), the Moodle *Projektbeschreibung* and the Moodle *Bewertungsschema* (both last changed 2026-10-23). Team of two → ~80 h per person, ~160 h total.

**IDs** (`M*`, `N*`, `G*`, `P*`) are referenced from tickets and STATUS.md.

## 1. Project idea

sitescope scans a room in 3D. In that 3D space users place digital notes (drawings, area markings, images with title/description/priority/status). Notes are saved and can be reopened later: on site as an **AR view** through the camera, or anywhere else as a **3D model**.

Technology: **Swift, native iOS (SwiftUI, ARKit, RealityKit)** · Backend: **Supabase**.

Name: **sitescope**. The submitted requirements and mockups use SiteAR, the earlier working name.

## 2. Project MUST-HAVEs (agreed with lecturer)

| ID | Requirement (original German wording, shortened) | Meaning for us |
|---|---|---|
| M1 | Erstellen, Bearbeiten, Speichern sowie Löschen (lokal und auf einem Server) von digitalen Raumnotizen | Full CRUD of room notes, both on device and in Supabase |
| M2 | Nachträgliches Hochladen von Dateien, die ohne Internetzugang erstellt wurden | Offline-first: changes made offline queue up and upload automatically when back online |
| M3 | Aufrufen von Raumnotizen als AR-Ansicht (vor Ort) sowie als 3D-Ansicht | AR walkthrough in the real room **and** a 3D model viewer usable anywhere |
| M4 | Verwaltung von Accounts und deren Dateien auf einem Backend-Server | Accounts plus their maps/images/files stored in Supabase Auth/Storage |
| M5 | Rollenverwaltung mit unterschiedlichen Rechten (Lesen, Schreiben, Löschen) bzgl. eines Projekts | Per-project roles with distinct read / write / delete rights, enforced server-side |
| M6 | Einloggen auf einem Smartphone per Username und Passwort | Sign-in with username (email) and password |
| M7 | Darkmode | Whole app usable and readable in dark appearance |
| M8 | Kommentarfunktion zu Projekten, Häusern, Räumen (Bilder, Audio, Text) | Comments with text, image and audio on each hierarchy level |
| M9 | Navigierbare Ordnerstruktur (Projekt – Häuser – Räume) | Three-level hierarchy: Project → House → Room |

## 3. Project NICE-TO-HAVEs (no approval needed; list them in README with what/where)

| ID | Item |
|---|---|
| N1 | Language setting (at least German + English) |
| N2 | Use LiDAR for precise 3D models of a room (optional mode; camera-only must keep working) |
| N3 | Export function (3D file, video) |
| N4 | Two-factor authentication |

Further candidates from the mockups (only count if not already a MUST): live progress / activity feed, "download room maps on Wi-Fi only", backup export (already implemented as `.sitescope` file transfer), saved-view photo for recognition.

## 4. General MUST-HAVEs (course, apply to every project)

| ID | Requirement | Key points |
|---|---|---|
| G1 | Mobile-first design, UI/UX | Follow Apple HIG; native navigation/controls; accessibility basics: readable font sizes, sufficient contrast, large enough touch targets |
| G2 | Cloud data storage | Relevant app data persisted in the cloud backend |
| G3 | User accounts and access protection | Registration + login; cloud data protected **server-side** (RLS / storage policies), not only in the app |
| G4 | At least one native device feature | Integrated into a real workflow (we use camera/ARKit; plus photos, microphone). Permissions requested and denial handled |
| G5 | Error handling and state management | Robust against no network, invalid input, unreachable API, denied permissions; clear feedback; loading states; no data/input loss on background or rotation |
| G6 | Automated tests | Unit tests and UI/E2E tests covering relevant logic and main flows; reproducible |
| G7 | Code quality and architecture | Understandable, maintainable; MVVM or comparable; UI, logic and data access clearly separated; reusable components; no duplication |

Technical rules: installable native app (no web app/PWA); BaaS preferred; Edge Functions allowed; no secret keys in the app or in Git (Supabase publishable/anon key is fine); `.gitignore` excludes build artifacts. Backend must be running with test data at grading time; setup reproducible from repo (schema, policies, settings, **seed data**) and documented in README. iOS install/testing arranged early with the lecturer.

## 5. Process rules

| ID | Rule |
|---|---|
| P1 | Git with a remote repo; lecturer (GitHub `behrends`) has read access (repo is public) |
| P2 | **Both members commit regularly** from the technical start; small, meaningful commits and messages. Git history is used to judge individual contribution |
| P3 | AI tools allowed, but no pure "vibe coding". AI code must be understood, reviewed and adapted |
| P4 | README reflects AI use: tools, typical uses, and **per member at least one concrete example** where AI code was checked, corrected or rejected (with commit if possible) |
| P5 | Handover meeting: every member explains architecture, decisions and their own code |
| P6 | Milestones: mockups → requirements agreed → technical start → development/QA → in-class demo → handover meeting → submission via Moodle |

## 6. Grading (100 points = 1.0)

| Points | Category | What counts |
|---:|---|---|
| 50 | MUST-HAVEs (project + general) | Correct and complete; usable in the app; edge cases (invalid input, no data) handled without errors. Partial credit possible. Tests, code quality and UI/UX are graded only in their own categories |
| 20 | NICE-TO-HAVEs | Only counted if MUST-HAVEs ≥ 40/50. Judged on usefulness, non-triviality, integration, stability. Must be described in README (what, where in the app). Trivial variants count less |
| 10 | Automated tests | Meaningful unit tests for domain logic; **≥ 3 central user flows as UI/E2E tests, including ≥ 1 error case**; tests pass and are reproducible per README; cover edge cases and reading/writing persistent data; backend mocked or local emulator |
| 20 | Quality and overall impression | See below |

Quality aspects: **readability** (outsiders can follow; comments on non-trivial parts) · **structure** (clear responsibilities, folders, components) · **clean code & framework best practices** · **consistent style** (formatter/linter or consistent manual) · **development process** (continuous git history, transparent AI reflection) · **UI/UX** (intuitive, stable, platform conventions, loading/error states, accessibility; a **short user guide for non-obvious flows** like scanning/AR) · **overall impression** (no unfinished screens or makeshift solutions).

A defect is deducted once, in the category it belongs to. Grade is per team; individual deductions only for clearly lower contribution.

## 7. Mockup summary (target UX)

Screens from the submitted mockups, used as the UI reference for tickets:

1. **Sign in**: email, password, Sign in, Create account, "Use without an account on this iPhone". Camera access only requested when opening AR.
2. **Projects**: searchable list with room count and sharing info ("shared with Alex", "3 people", "only you"). Sync status ("Synced just now").
3. **Project detail**: rooms (with "Not mapped" / task count), Add room; **Team** (members with role and last activity), invite by email; Rename, Export backup (`.sitescope` file), Delete project and all rooms.
4. **Room (unmapped)**: "Map this room first" → Map room, scanning tips; empty task list; Rename/Delete room.
5. **Scan**: Cancel/Finish, "Walk around the room – 2/3 positions", LiDAR badge when available, "Room map saved".
6. **Room (mapped)**: work progress (1 of 3), Start AR walkthrough, task list available without AR (title, kind, priority, status).
7. **Recognition**: "Recognizing room…", saved view photo to match, then "Room recognized" and drawings appear.
8. **Drawing**: Draw / Area / Image tools on a locked view; work details (title, description, priority).
9. **Task detail**: instruction text, priority, status To do / In progress / Completed; offline save syncs later; completed drawings show green in AR.
10. **Live progress** (manager): per-room progress, who is on site, activity feed.
11. **Offline**: "No signal" banner, per-task "Waiting to sync"/"Synced"; conflicts show both versions after sync.
12. **Team member**: role, "Can edit instructions", recent activity, Remove from project.
13. **Settings**: account, sync status, Wi-Fi-only map downloads, projects saved on device, scanning tips, sign out.
