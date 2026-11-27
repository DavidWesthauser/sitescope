# Architecture

Native iOS 17+ app: SwiftUI, ARKit, RealityKit, no third-party iOS dependencies. Backend: Supabase (Postgres + RLS, Auth) via plain `URLSession`; the app is only usable while signed in. The database design is DATABASE_API.md; storing scans and AR instructions there comes with T-029, offline work with T-008.

## Layout

| Path | Responsibility |
|---|---|
| `sitescope/App/SitescopeApp.swift` | Entry point: sign-in screen until signed in, then the project list |
| `sitescope/App/Store.swift` | The app's view model: state all screens show, input validation, actions that call the services. No file or network code |
| `sitescope/Services/DataRepository.swift` | `DataRepository` (projects, houses, rooms, AR data) used by `Store` and `ARController`; `AccessManagement` (levels, grants, responsible, profiles, organizations) |
| `sitescope/Services/CloudRepository.swift` | Both protocols on Supabase: table and RPC names. AR calls report T-029 until the database stores them |
| `sitescope/Services/CloudRecords.swift` | Request bodies: only the columns clients may set, optionals as `null` |
| `sitescope/Services/Backend.swift` | Supabase REST/Auth/Storage client, token refresh, Keychain session (`Vault`). Only the publishable key; RLS applies to every call |
| `sitescope/Core/` | Pure, testable value types: `Models` (+ validation), `Spatial` (poses, alignment), `Scanning` (coverage gates), `TrackingQuality`, `DrawingGeometry`, `FreehandDraft`, `MapSaveTransaction`, `Access` (levels and the permission table), `RoomSurfaceModel`, `ScanRenderingBudget`, `ScanVisualization` |
| `sitescope/AR/` | `ARController` (session lifecycle, tracking) with extensions `+Drawing`, `+Persistence` (map save, image load), `+Rendering` (instructions), `+Surfaces` (plane outlines); image/scan-guide helpers |
| `sitescope/Views/` | `ManagementViews` (sign-in, project list), `ProjectDetailView`, `HouseDetailView`, `RoomDetailView`, `AccessViews` (grants, responsible), `AdministrationView`, `SettingsView`, `TaskEditor`, `ARScreen`, drawing/scan overlays, tips |
| `sitescope/Resources/` | `Info.plist`, `Config.xcconfig` (+ git-ignored `Secrets.xcconfig`) |
| `supabase/` | CLI config only; the design is not a migration yet (T-029) |
| `sitescopeTests/` | Portable core tests (`swift test`) |
| `sitescopeAppTests/` | Store/backend fixtures, `InMemoryRepository` for tests without a server, AR layout/render tests (simulator) |
| `sitescopeUITests/` | UI workflows |
| `scripts/generate_project.py` | Regenerates the Xcode project deterministically |

## Data model

`Project` → `House` → `Room` as in DATABASE_API.md (names, `responsible_id`; rooms also dimensions, `area`, `status`). `Room` also carries the AR fields (`coordinate_id`, `map_path`, `surfaces`, `scan_guide_jpeg`); they have no columns yet, decode as defaults and are never sent (T-029). `Annotation (room_id, coordinate_id, kind, pose, points/strokes/image, title, detail, status, priority)` exists only in the app until T-029.
Rights: each screen asks `scope_level` for the caller's level (0 none … 4 admin) and `AccessLevel` maps it to the permission table in DATABASE_API.md to show or hide controls. The database enforces the same rules.

## Persistence

- Everything lives on the server: tables via PostgREST, the session in the Keychain. No offline cache or queue yet (T-008), no file storage yet (T-029).
- On-device mode and `.sitescope` file export/import were removed on 2026-11-27 (T-003). Old `local.json` files stay on phones but are no longer read.

## Spatial contract

- Units: metres, ARKit right-handed gravity-aligned coordinates. `Pose` = column-major 4×4 rigid matrix (no scale/reflection/NaN).
- Each room has an immutable `coordinate_id`. A scan saves an `ARWorldMap` containing an anchor `sitescope.room.<coordinate_id>` at the room origin (**do not rename** — saved maps depend on it).
- Annotations store `roomFromAnnotation` + local vertices. Rendering: `sessionFromRoom × roomFromAnnotation`; placement uses `inverse(sessionFromRoom)`.
- Published maps are immutable. Remapping = new room. The database trigger for this comes with T-029.
- Recognition: notes are shown only after the room anchor is restored **and** tracking is normal for ≥ 2 s with mapping status mapped/extending. Tracking loss hides them. Never falls back to an arbitrary origin. 40 s timeout is a warning; search continues; explicit restart available.

## Scanning and drawing

- Scan readiness: normal tracking ≥ 2 s, world mapping mapped/extending, ≥ 1 plane, all 4 heading sectors and 3 positions ≥ 0.5 m apart, each view held 0.75 s. This is a coaching heuristic, not coverage.
- Optional saved-view photo (≤ 512 px JPEG, ≤ 64 KB) helps a human find the viewpoint; it is never used for matching.
- Drawing happens on a **locked view**: camera snapshot + matrices; touches unproject onto a plane fixed in room coordinates. Strokes: ≤ 32 per drawing, ≤ 256 samples each, ≤ 2,048 total, Chaikin-smoothed tubes. Areas: coplanar tapped corners. Images: normalized to ≤ 2,048 px PNG, rendered as textured quads with physical size.
- Placement requires an existing plane settled for 0.6 s, 0.15–5 m away; explicit measured-distance placement as alternative.
- Rendering is bounded: ≤ 24 outlines, ≤ 4 re-meshes per 0.25 s tick, ≤ 32 image textures (1,024 px), reduced mode on memory/thermal pressure.

## Lifecycle

`.background` pauses AR; returning resumes without reset so ARKit relocalizes (scan in progress is kept). `.inactive` does not pause. Idle timer off while AR is open. Unsaved drafts are lost on force-quit. Map-save callbacks are generation-checked (`MapSaveTransaction`) so a reset session can never publish a stale map.

## Concurrency

`SWIFT_STRICT_CONCURRENCY = complete`, no warnings (as of 2026-10-31). Two documented `@unchecked Sendable` hand-offs (new world map, read-only camera buffer).

See [decisions/0001](decisions/0001-marker-free-shared-localization.md) for why ARWorldMap is used instead of markers or cloud anchors.
