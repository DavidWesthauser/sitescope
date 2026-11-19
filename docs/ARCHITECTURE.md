# Architecture

Native iOS 17+ app: SwiftUI, ARKit, RealityKit, no third-party iOS dependencies. Backend: Supabase (Postgres + RLS, Auth, Storage) via plain `URLSession`. Target architecture changes are planned in T-013.

## Layout

| Path | Responsibility |
|---|---|
| `SiteAR/App/SiteARApp.swift` | Entry point; picks login / dashboard / data-recovery screen; handles opened project files |
| `SiteAR/App/Store.swift` | Main-actor app state. Local JSON persistence **or** cloud calls (`if isLocalMode`), project file import/export |
| `SiteAR/Services/Backend.swift` | Supabase REST/Auth/Storage client, token refresh, Keychain session (`Vault`). Only the publishable key; RLS applies to every call |
| `SiteAR/Core/` | Pure, testable value types: `Models` (+ validation), `Spatial` (poses, alignment), `Scanning` (coverage gates), `TrackingQuality`, `DrawingGeometry`, `FreehandDraft`, `MapSaveTransaction`, `ProjectTransferArchive`, `RoomSurfaceModel`, `ScanRenderingBudget`, `ScanVisualization` |
| `SiteAR/AR/` | `ARController` (session lifecycle, tracking) with extensions `+Drawing`, `+Persistence` (map save, image load), `+Rendering` (instructions), `+Surfaces` (plane outlines); image/scan-guide helpers |
| `SiteAR/Views/` | `ManagementViews` (auth, projects, rooms, tasks, members, settings), `ARScreen`, drawing/scan overlays, transfer UI, tips |
| `SiteAR/Resources/` | `Info.plist`, `Config.xcconfig` (+ git-ignored `Secrets.xcconfig`) |
| `supabase/` | Migrations, local seed, pgTAP access tests |
| `SiteARTests/` | Portable core tests (`swift test`) |
| `SiteARAppTests/` | Store/backend fixtures, AR layout/render tests (simulator) |
| `SiteARUITests/` | UI workflows |
| `scripts/generate_project.py` | Regenerates the Xcode project deterministically |

## Data model

`Project (id, owner_id, name)` → `Room (id, project_id, name, coordinate_id, map_path, surfaces, scan_guide_jpeg)` → `Annotation (room_id, coordinate_id, kind, pose, points/strokes/image, title, detail, status, priority)`.
Annotation kinds created today: drawing (`line` with `strokes`), `area`, `image`. Legacy `marker/text/arrow` and room `marker/reference_points` still decode but are inactive.
Cloud adds `memberships (project_id, user_id)`: owner = manager (full rights), member = worker (read + `set_task_status` RPC only).

## Persistence

- **Local mode** (Debug build without backend config): `Application Support/sitescope/local.json` plus `assets/<project>/<room>/...` (world maps, PNG images). Writes are encoded off the main actor, serialized, atomic, and applied in memory only after success. Unreadable JSON → recovery screen that moves the file to a backup.
- **Cloud mode**: tables via PostgREST, files in the private `room-assets` bucket at `<project>/<room>/...`. No offline cache or queue yet (T-008).
- **Transfer file** (`.sitescope`): magic `SiteAR01` (8 bytes), UInt64 manifest length, JSON manifest, raw assets streamed in ≤ 1 MiB chunks with SHA-256. Limits: 16 MiB manifest, 256 MiB/asset, 1 GiB total, 256 rooms, 2,000 annotations, 100,000 points. Import validates everything, creates new IDs, keeps `coordinate_id` and poses, and rolls back on failure.

## Spatial contract

- Units: metres, ARKit right-handed gravity-aligned coordinates. `Pose` = column-major 4×4 rigid matrix (no scale/reflection/NaN).
- Each room has an immutable `coordinate_id`. A scan saves an `ARWorldMap` containing an anchor `sitescope.room.<coordinate_id>` at the room origin (**do not rename** — saved maps depend on it).
- Annotations store `roomFromAnnotation` + local vertices. Rendering: `sessionFromRoom × roomFromAnnotation`; placement uses `inverse(sessionFromRoom)`.
- Published maps are immutable (enforced locally and by a DB trigger). Remapping = new room.
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
