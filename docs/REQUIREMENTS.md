# Verifiable scope and effort

The current flow is scan → draw → save → export/import a local copy → recognize the room → restore drawings. There are no fixed markers or selected reference dots. Marker capture/detection and manual-reference recovery are removed; legacy JSON fields still decode. Plane outlines and the miniature show observed surfaces rather than whole-room coverage.

**No backend is connected for the current workflow.** Local Debug installs and `.sitescope` transfers are the active scope. Supabase implementation remains in the repository for future activation; file sharing does not satisfy the course's mandatory cloud/account requirements. Implementation alone does not close physical or live-backend acceptance. See [verification](VERIFICATION.md).

| Requirement | Observable acceptance | Current evidence / remaining work |
|---|---|---|
| Native iPhone app | Local Debug installation opens Projects on iOS 17+ without backend login | Build/simulator evidence; install the current revision on each physical phone |
| Project/room management | Create, rename, delete and relaunch with correct project associations | Deterministic/UI persistence tests; current-device acceptance remains |
| Camera-only mapping | Real map generated without scene depth on a compatible non-LiDAR iPhone | Physical camera-only test required |
| Room world maps | Save/restore securely; imported map retains its matching sentinel coordinate anchor | Archive/state tests; physical cross-device recovery pending |
| Drawings, areas and images | Room-relative poses/vertices and physical image dimensions survive save/relaunch/transfer | Geometry/serialization/disk tests; physical placement pending |
| Task status | Editable local copy persists status through relaunch and export/import | Local tests; phone acceptance pending; no cross-copy live updates |
| Map localization | Hide overlays until matching anchor and stable tracking; hide on loss; retry after timeout | State tests; physical recovery accuracy and failure testing pending |
| Measured-distance placement | Explicit distance positions drawings when plane detection is insufficient | Geometry tests; physical placement pending; not a localization fallback |
| Surface overview | Consolidate only near-coplanar overlapping miniature patches without moving saved coordinates | Model/budget tests; no full reconstruction or semantic room claim |
| Scan animation | Native 0.45-second outline fade; miniature targets 30 Hz; static idle/pressure/Reduce Motion; outline re-meshing bounded per tick | Scheduling/budget tests; no measured phone FPS or crash-resolution claim |
| Offline project transfer | Project details Export project → native AirDrop/Files; dashboard Import project or open `.sitescope`; separate editable copy | Disk/Store tests and [exact phone procedure](../README.md#transfer-a-project-to-the-technician-without-a-backend); two-phone physical test pending |
| Transfer integrity | Reject unsafe/missing assets, corruption, invalid associations and oversized files; leave no partial project | Automated disk tests; imported real maps must still recover physically |
| Accounts (course cloud scope) | Register, confirm, sign in, refresh and sign out against live service | Client fixtures exist; backend connection/live Auth deferred |
| Secure cloud persistence (course scope) | Authorized two-user map/image/task access; outsider blocked; sharing/revocation enforced | Migrations/policy suite exist; live execution deferred; local files provide none of these guarantees |
| Tests and documentation | Deterministic proof plus reproducible local installation and physical acceptance record | See VERIFICATION.md; do not count unperformed phone/backend steps as passed |

## Local transfer contract

A `.sitescope` file contains a bounded UTF-8 manifest and raw map/image assets, streamed in chunks no larger than 1 MiB and checked with SHA256. Limits: 16 MiB manifest, 256 MiB per asset, 1 GiB total assets, 256 rooms, 2,000 annotations and 100,000 total geometry points. Inactive legacy marker files are excluded.

Import assigns new project/room/annotation IDs and rewrites asset paths, preserving each room's `coordinate_id`, world-map anchor relationship, annotation poses and vertices. Reimport creates another editable copy, not a merge. Existing projects remain separate. Recipients can retain/export their copies; there is no live sync, server authorization or remote revocation. Both phones need their own installed local Debug app. See the [README installation and transfer steps](../README.md).

## Deferred work

Cloud Anchors and Immersal are researched options only; no SDK, provider credentials or hosted/resolved anchors are integrated. Native ARWorldMap remains the active recovery method. A provider prototype, backend connection, live authorization, cloud synchronization, Android support, mesh reconstruction/occlusion, semantic room objects, push notifications and progress dashboards remain future scope. Scene depth is not requested on any device (nothing consumed it); a future LiDAR/RoomPlan mode would be optional and must not add a LiDAR requirement.

Legacy pin/text/arrow records remain readable, but current creation tools are Draw, Area marking and Image. Do not count removed marker/manual recovery UI as a current feature. Preserve honest history of earlier work without claiming it as active acceptance.

## 160–240 hour team budget

The earlier 200-hour planning estimate included work on marker/manual recovery and cloud integration. Those are historical planning assumptions, superseded by the current marker-free local-file scope. The following remains a planning allocation, not measured time or proof of completed contributions:

| Work | Hours |
|---|---:|
| Setup, existing auth/Keychain and local navigation | 22 |
| Projects, rooms and task forms | 26 |
| Real map lifecycle and bounded local transfer | 28 |
| Persistent annotations and observed surface geometry | 24 |
| Marker-free relocalization and tracking verification | 34 |
| Placement, interruptions and recovery errors | 16 |
| Existing backend/policy work and deferred integration | 22 |
| Two-device acceptance, documentation and fixes | 28 |
| Total | 200 |

Use reviewable changes and record actual individual effort separately. The public sitescope repository is independent of unrelated parent-directory projects. Course cloud acceptance, physical two-phone accuracy and lecturer-approved scope still require evidence before submission.
