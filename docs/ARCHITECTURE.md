# Architecture

Native iOS 17+ app: SwiftUI, ARKit, RealityKit, no third-party iOS dependencies. Backend: Supabase (Postgres + RLS, Auth, Storage) via plain `URLSession`. Sign-in is required; signed in, the app works offline and syncs in the background (T-008). The database target it is built against is T-029; the hosted design is DATABASE_API.md.

## Layers

Model → service → view model → view, as in the rest of the code:

- **Model** (`sitescope/Core/`): pure value types and rules, no I/O, unit-tested. `Models` (project, house, room, drawing + validation), `Access` (levels and the permission table), `Sync` (field merge, conflict policy, queue rules), spatial and scanning math.
- **Services** (`sitescope/Services/`): storage and network. `LocalDataStore` (the account's file), `LocalRepository` (writes to the phone and queues), `SyncEngine` (upload queue, conflicts, download), `RemoteStore` (Supabase rows, files, rights), `Backend` (HTTP, Auth, Keychain session), `Connectivity` (network path).
- **View model** (`sitescope/App/Store.swift`): the state all screens show, input validation, the actions they trigger. No file or network code.
- **Views** (`sitescope/Views/`): SwiftUI only. They read the `Store` and call its actions.

| Path | Responsibility |
|---|---|
| `App/SitescopeApp.swift` | Sign-in until signed in, then the project list; syncs when the app becomes active |
| `Views/ProjectListView`, `ProjectView`, `HouseView`, `RoomView` | Project → house → room, navigated by `Route` values |
| `Views/AccessViews` | People per scope, adding a person, the responsible person |
| `Views/SyncViews` | Row badge, bottom-bar status, notices |
| `Views/CommonViews` | Name prompt, delete confirmation, list row |
| `Views/SignInView`, `SettingsView`, `AdministrationView` | Account, sync, appearance; admin tools |
| `Views/ARScreen` + `sitescope/AR/` | Scanning and drawing (`ARController` with `+Drawing`, `+Persistence`, `+Rendering`, `+Surfaces`) |
| `sitescopeTests/` | Core tests (`swift test`) |
| `sitescopeAppTests/` | Service, sync (fake server with revisions) and AR layout tests |
| `supabase/` | CLI config; the design becomes a migration in T-029 |

## Screen pattern (HIG)

Every list screen works the same: rows with icon, title and subtitle and a sync badge; "+" adds; the "…" menu holds Rename, People and Delete for the item on screen; rows offer the same through swipe and context menus; one name prompt for creating and renaming; deleting always asks with the item's name; empty lists show a `ContentUnavailableView` with the action; the bottom toolbar shows the sync status. Controls appear only if the caller's level allows them.

## Data model

`Project` → `House` → `Room` → drawings (`Annotation`). A room has a name, a description, a responsible person and a scan (`coordinate_id`, `map_path`, `scan_guide_jpeg`, `surfaces`). A drawing is geometry only: `line` (strokes), `area` or `image`, with `pose` and points in the room's coordinate system. No tasks, titles, status or priority (decided 2026-11-28).

## Persistence and sync (T-008)

- Each account has `Application Support/sitescope/accounts/<user>/data.json` plus `assets/` (scans, photos). Writes are atomic and serialized; an unreadable file is moved aside, never deleted. The pre-account `sitescope/local.json` is left untouched.
- A change is written to the phone, then queued (`OutboxItem`, one per record). The queue uploads on reconnect, foreground, refresh and after each change: parents first, deletes children first, files right before the record that needs them.
- Writes name the server revision they are based on (T-029). On a mismatch the engine reads the row and merges per field against the last synced version: only one side changed → that side; both changed → `ConflictPolicy` (default `LastChangeWins`, the phone's upload). Deleted on the server but edited here → recreated. Deleted here but edited there → restored. A different scan on the server → the phone's scan and its drawings move to a new room. Every such case leaves a `SyncNotice`.
- A change the server refuses is marked failed with its reason and retried only when the user asks. Being offline just waits.
- Rights (`scope_level`) are cached per scope; something created on the phone and not yet uploaded belongs to its creator. Sharing and handing over need the network.

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
