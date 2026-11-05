# Verification record — latest update 2026-10-31

## Scan performance and lifecycle states — 31 October 2026

- Best-practice follow-up: ARController split into five files without behaviour change; strict concurrency enabled (`complete`) with zero app warnings; local saves encode/write off the main actor through a serial queue (concurrent edits covered by a test); image textures capped at 32 with outline fallback (covered by a test); unreadable `local.json` gets a recovery screen that moves the file to a backup (covered by a test).
- Latest simulator run: **119 tests, 117 passed, 2 skipped** (camera-only UI flows), 0 failed. Portable `swift test`: **92 passed**.

- Main-thread work during scanning is bounded: existing outlines re-mesh at most four per tick (sub-centimetre refinements are skipped), scan progress republishes only when a displayed value changes, the miniature refreshes surfaces at most once per second and animates at 30 Hz, and mid-stroke drawing re-meshes only the active stroke. Unused scene depth, environment texturing and camera post-processing (motion blur, depth of field, grain, HDR, grounding shadows) are disabled. Recovered drawings re-attach their cached scene instead of regenerating text meshes and collision shapes.
- State audit: `.inactive` (Control Center, banners) no longer pauses AR; backgrounding resumes the same session without a reset so an unsaved scan survives via ARKit relocalization; a locked drawing view survives brief tracking loss; Finish accepts `.mapped` or `.extending` per Apple's world-map guidance. The unreachable alignment-confirmation panel and dead mapping-only branches in the non-mapping layout were removed.
- Polish: idle timer disabled while AR is open, haptics for recorded directions/positions, scan-ready and room recognition, inline saved-view photo during recognition, animated progress bars, live project rename.
- Simulator (iPhone 17): **110 unit/layout tests passed**, including new tests for the refinement budget and scene re-attachment; UI workflow **5 passed, 2 skipped** (camera required). Portable `swift test` passed. Frame rate, haptics, lifecycle resume and relocalization were **not** measured on a phone.


## Visual recovery guide and image lifecycle — 27 October 2026

- New room scans may save a small optional room-view JPEG in the immutable room metadata. The manager can disable it in Scan options. It travels in `.sitescope` exports; the sharing UI and README disclose that the file can include a room photo. It is a human visual guide, not an image anchor or a source of alignment. Old rooms decode with no photo. A simulated pixel buffer verified JPEG encoding, 65,536-byte limit, portrait orientation and thumbnail decoding; no real camera image was fabricated in a production workflow.
- A map-search timeout is nonterminal while the same AR session keeps running. Late recognition still requires the saved sentinel, normal tracking, a stable interval and usable mapping status. Hard session/map failures do not automatically align. Deterministic localization tests cover both paths.
- AR recognition now starts before image textures finish loading. Saved images are decoded without PNG re-encoding, off the main actor, with display textures limited to 1024 pixels per side. Removed/replaced textures are pruned; stopped/stale loads cannot publish or render. Image-selection request tokens prevent stale or failed restores from silently using an older image. Active images still have no total texture count/byte cap; this is not proof that a reported phone crash is fixed.
- Portable tests: **91 passed** (79 core and 12 service/store fixtures). Initial simulator run: **15 tests passed** across 10 AR/layout, 2 viewpoint-image and 3 image-loader tests; the scan-entry UI workflow passed too. A focused follow-up passed image editing/cache checks and the 1024-pixel texture limit after the rendering change. The recovery button was visually reviewed on a compact simulator screenshot. The final compact layout and scan-entry UI tests passed after adding the optional-photo switch. A final focused iOS run passed **9 tests** for saved-view capture, image-request ordering, texture pruning, the 1024-pixel limit and saved-image/drawing rendering.
- Migration 004 and three additional pgTAP assertions were authored for future cloud setup; the **31-assertion** SQL suite has not been run or deployed. The backend remains disconnected by request. An arm64 iPhone build reached code signing but failed with `errSecInternalComponent`; the iPhone was unavailable. Real camera-image orientation, room recognition, rendering detail, memory/thermal behavior and the two-phone workflow remain physical-device acceptance tasks.

## Capture quality and coordinate-origin fixes — 27 October 2026

- Code review identified three reproducible mechanisms: instantaneous direction/position credit, stale plane-settling evidence after observation gaps/tracking loss, and map-save retry state surviving an AR coordinate-origin reset. Invalid surface updates could also retain old outlines/metadata. These mechanisms are fixed; this does not establish the cause of the earlier phone crash.
- Scan progress now requires qualified steady observations and provides four small direction bars plus a position hint. The feature-count threshold is an explicit, uncalibrated coaching heuristic. Mapping is still ARKit plane/feature tracking, without new reconstruction, semantic room recognition, a backend connection or fixed markers.
- Portable suite: **82 passed** (71 Core/transfer/quality tests and 11 service/store tests), zero failures. New tests cover view dwell, unreliable observations, clock gaps, bounded positions, stability expiry, cumulative plane drift, reset/callback ordering and successful late publication versus an interrupted unsaved capture.
- Simulator: **8 AR/layout tests passed**, including placement reset, invalid refinement cleanup, lost-room-anchor hiding, long-scan rendering limits and drawing/image preservation. The scan-entry workflow with the explicit unsupported-AR error passed. The final map-save suite passed **5 tests** after the late-publication correction. The expanded layout fixture captures 45 states, including partial progress at compact/large text sizes; the scan progress display was visually reviewed. These are simulated events and deterministic state fixtures, not real room scans.
- The latest code is not installed on the physical phone. Recognition success rates, surface accuracy, scan time, FPS, thermal/memory behavior and the new heuristics require physical camera-only testing; use DEVICE_TESTING.md. Existing maps are not retroactively improved by the new capture guidance.

## Current marker-free scan and portable projects

- The active scan and recovery workflow has no physical-marker capture, printing, image-target detection or manual reference-dot selection. Legacy serialized marker/reference fields still decode for compatibility; they are not used to align current sessions. Saved ARWorldMaps and their coordinate sentinels remain the alignment authority. A map that cannot be recognized leaves drawings hidden and tasks readable.
- Nearby overlapping, near-coplanar observed patches are conservatively consolidated for the miniature only. Disjoint patches and unobserved gaps are not joined into invented walls. Original mapping data, raycasts and instruction coordinates are preserved. This is an estimated surface model, not full room reconstruction or RoomPlan semantic recognition.
- Outlines now fade using a reused native RealityKit animation resource on iOS 18+, avoiding CPU-driven partial-mesh reveal steps. The miniature targets 30 Hz while animating, and pauses when settled or reduced by pressure/Reduce Motion. These are presentation targets, not measured hardware FPS.
- Local Debug projects can be exported as streamed `.sitescope` files and imported as separate editable copies. Import regenerates record IDs and asset paths while preserving each room's coordinate ID, all spatial transforms and drawing geometry. SHA-256, structural/size/path checks and staged atomic persistence protect against incomplete or unsafe files. There is no backend connection, live synchronization or file-access revocation.
- Portable deterministic suite: **61 passed** (50 Core/transfer tests and 11 service/store fixture tests), zero failures. The four Store transfer tests also passed in the iOS Simulator: repeated imports preserve coordinate IDs/geometry/assets, survive disk reopen, keep existing data unchanged and roll back copied assets when metadata writes fail. Synthetic map/image bytes exist only in disk-format tests, not production workflows.
- Simulator AR/layout suite: **6 passed**; local navigation/room/unsupported-AR/import-picker workflows: **4 passed**, Auth/cloud tests **2 explicitly skipped**. The native export sheet was confirmed in the captured UI; its initial test used a container identifier hidden by the system extension. The selector was corrected to the observed native activity collection and Save to Files action. A subsequent dismissal check exposed a SwiftUI wrapper issue: presentation now uses UIKit directly with sheet/popover dismissal callbacks. The final native export/cancel regression **passed**, with Save to Files available and Export re-enabled afterward. The captured native share presentation was visually reviewed. This brings interactive local UI flows to **5 passed** across the focused runs.
- Physical two-phone file transfer, days-later room recognition, AR accuracy and long-scan memory/thermal profiling remain pending. This revision is not installed on the iPhone. File sharing does not satisfy the course's mandatory cloud persistence/access protection requirement.

## Previous scan presentation refinement

- Simplified the live overlay toward the supplied promotional reference: plain controls, a short coaching capsule, lighter miniature faces/contact shadow and one compact live-status label. Detailed progress moved to Options; the visual budgets and real geometry contract are unchanged.
- Deterministic suite: **46 passed**, zero failures. Initial renderer/layout/navigation run: **7 passed** (six AR fixtures including the 600-surface stress case plus one scan UI workflow). Final layout/startup-error/navigation checks were repeated after finishing control states, and the scan UI test passed with explicit assertions that Directions/Positions remain accessible in Options. Compact and large-text scan screenshots were visually reviewed.
- These changes are **not installed on the phone**. Camera appearance, readability over real scenes and physical performance still require hardware acceptance; this is not a claim of RoomPlan recognition parity.

## Current long-scan fix and project polish

- User reported lag followed by a crash during extended room scanning on iPhone 12 mini. Code review identified unbounded per-edge render entities, recursive edge lookups, repeated visibility sweeps and continuous miniature geometry/sort allocations. **No crash/Jetsam report was retrieved:** devicectl reported the phone unavailable, so the actual termination cause remains unconfirmed.
- Replaced live visualization with bounded batched meshes and a cached, throttled miniature. Memory/thermal fallback releases only visuals. Actual AR maps and annotation coordinates are unchanged. Follow-up review separated active raycast stability from the display cache and fixed stale outlines after invalid geometry.
- macOS deterministic tests: **46 passed**, zero failures. Includes rendering budgets, reveal/geometry validity, stable placement, capture request ordering, spatial/localization math, real disk persistence and backend fixtures.
- Simulator renderer/layout suite: **6 passed**, zero failures. The long-scan fixture feeds **600 surfaces with 256 input vertices each** and verifies 128 cached metadata patches, 24 outline anchors/48 drawables normally, and 12 anchors/12 drawables after memory fallback, with instructions retained and off-cache placement stability working.
- Three interactive local UI flows passed: project rename/relaunch, room rename/delete/relaunch, and scan entry with an explicitly asserted unsupported-AR error. Empty project input is rejected. Auth and configured-cloud UI tests **explicitly skipped**; these are not evidence of live Auth/cloud success.
- UI polish includes searchable projects, room progress, readable statuses, native tips, English main controls, busy feedback and capture-race prevention. Expanded layout fixtures export 42 screenshots; final reduced-detail/accessibility and empty-project sizing are visually reviewed after correction. Tests do not substitute for VoiceOver or physical AR verification.
- Current changes have **not been installed on the iPhone**. Earlier installation evidence below applies to commit 88d4de7, not this revision. Hardware performance/accuracy and hosted backend acceptance remain pending.
- Course requirement audit and AI-use notes are in COURSE_AUDIT.md and AI_USAGE.md. Team size two is user-reported; lecturer approval and individual understanding/contributions are not asserted.

## Earlier records — 2026-10-23

## Latest iPhone installation

Source commit `88d4de7` built and signed successfully, installed over the existing app on the connected iPhone 12 mini, and launched successfully using devicectl. Existing app data was preserved. This supersedes the earlier simulator-only deployment notes below; physical AR accuracy, animation performance and room-recovery acceptance still require testing.

## Current animated scan update

- Reviewed the supplied 6.5-second RoomPlan promotional clip at **three timestamps** (0.6, 3.2 and 5.8 seconds). No video/frames are included in the repository. The local Floor Planner app was inspected and is a separate 2D web tool, not an AR scanner.
- Added progressive RealityKit outline tracing/halos, stable outline-entity reuse, and a shaded, camera-oriented miniature with patch appearance/refinement animations and Reduce Motion support.
- Deterministic suite: **38 tests passed**, zero failures, including slab geometry/pose preservation and shortest-angle turning. Simulator: **4 tests passed**, zero failures: 30 compact/large-text layout captures, image/stroke persistence/rendering, outline anchor reuse/refinement, and a pixel-level check that the miniature renders without animation ticks. Final scan screenshots were visually reviewed.
- Visual review found and fixed an initially invisible miniature: pre-existing geometry now renders immediately, with appearance animation reserved for new detections. A pixel regression test covers the first frame.
- This revision has **not been deployed to the phone**. Live animation quality, performance, physical boundary alignment and recognition quality remain hardware checks. Animated patches are not RoomPlan window/furniture recognition.

## Multi-view recognition update

- Capture now requires four heading sectors and three positions at least 0.5 m apart, in addition to map/tracking/surface readiness. Regression tests distinguish walking with one viewing direction from spinning in place; neither alone completes capture.
- Deterministic suite: **36 passed**, zero failures. Simulator layout/rendering and project/room/scan navigation: **3 focused tests passed**; the final layout-only rerun also passed, with compact and large-text scan screenshots visually checked after the last display adjustment.
- Recovery offers continued searching without resetting the session. No mesh-based matching or viewpoint-independent recognition is claimed. Existing sparse maps are preserved, not automatically expanded.
- At the user's request this revision is **not installed or tested on the phone**. A signing attempt for the earlier scan-screen changes failed with macOS errSecInternalComponent; simulator compilation/testing is independent of that keychain issue.

## Scan and placement update

- Removed the silent estimated-surface fallback, corrected measured-distance placement to use the actual screen ray, retained finer boundary corners and added a targeted-surface preview.
- Replaced the scan dashboard with a camera-first Cancel/Finish overlay and floating live surface overview. This remains camera-only ARKit plane detection, not RoomPlan semantic geometry.
- Deterministic suite: **36 tests passed**, including the new off-centre measured-distance fixture. Simulator layout/rendering and navigation checks are recorded below; live wall accuracy and scan duration cannot be verified in the simulator.

## Drawing, area and image update

- Signed iPhone Debug build: **succeeded** with Xcode 27.1. Installed over the existing app on the physical **iPhone 12 mini (iOS 27.0.1)**, preserving local data.
- macOS deterministic suite: **36 tests passed**, zero failures. Covers transforms, localization evidence, serialization, stroke boundaries, smoothing without overshoot, image metadata, persistence and Store/backend behavior.
- Simulator: **four focused tests passed** across the final two runs: layout states, image/separate-stroke persistence and rendering, legacy shape rendering, and local project/room/scan navigation. The final layout/persistence rerun passed both tests after the last edits.
- **30 layout screenshots** were exported and visually reviewed: empty projects, login, settings, task views, placement/work-detail forms, scanning, recognition, tracking loss, recovery, worker view and all three editor tools. Includes compact 375-point widths, 667/812-point heights and accessibility text sizes. Fixes include a fixed Save bar, compact header, adaptive controls, keyboard-safe sheets and a crosshair in the unobstructed camera region. These fixtures cannot prove every possible interactive or keyboard state.
- A real normalized PNG and two independent paths were saved, the local Store reopened, bytes/metadata checked, texture decoded and separate RealityKit entities rendered. Simulator fixtures do not validate real camera capture, touch-to-wall accuracy or frozen-view projection on hardware.
- The user reported earlier scan/draw builds mostly working. Full physical scan → draw/image → close → recover acceptance of this update still requires the checks in DEVICE_TESTING.md. Cross-device alignment and cloud behavior remain unverified.
- Supabase is unconfigured. At that earlier point there were three migrations and 28 policy assertions; the current setup has four migrations and 31 assertions. Run the current suite against a development backend; no CLI/PostgreSQL/Docker server was available here. Compiled client code is not proof of server policy behavior.
- Keep Device Hub physical-device screen viewing OFF during AR testing; it previously coincided with a black camera and blocks camera access. Keep Developer Mode and pairing enabled.

## Known limits

- ARWorldMap recovery is probabilistic. Stable normal tracking plus matching restored room anchor and extending/mapped evidence gates automatic display. It is not survey-grade recognition. Users should inspect physical drawing placement; tracking loss hides annotations and retries recovery.
- New room scans require no dots/print. Optional marker fallback still needs explicit confirmation because a moved print produces a wrong transform. Legacy two-point manual recovery is gravity-aligned yaw/translation, not six-axis precision alignment.
- Live boundaries, counts and the isometric overview show detected ARKit plane patches. No whole-room coverage percentage, classified furniture boxes, reconstructed room model or RoomPlan capability is claimed on the camera-only iPhone 12 mini.
- Area drawings are planar outlines with non-collinear first three vertices. Freehand drawings have up to 32 independent paths, 256 samples per path and 2,048 total samples. Legacy single paths retain their older format. Explicit distance placement depends on measurement; no automatic guessed depth or depth occlusion is provided.
- Published spatial maps/metadata are immutable. Remapping requires a new room revision; annotations are not automatically migrated between coordinate systems.
- Local Debug data remains on one device and does not automatically upload when Supabase is configured. Cloud mode uses explicit refresh, with no offline synchronization queue or realtime revocation/conflict resolution.
- Force-quitting loses unsaved scans/drawing/form drafts. Backgrounding pauses AR; returning resumes the same session and ARKit relocalizes against its in-memory map, so a scan in progress is kept (if relocalization does not succeed, use Restart scan). Control Center, notification banners and system alerts no longer pause AR.
- Failed uploads/deleted rooms may leave private orphan Storage objects requiring administrative cleanup through the Storage API. Never delete only storage metadata in SQL.
- Cloud lists use the backend row limit (local config: 1,000). Large-project pagination, account deletion/password recovery UI and operational monitoring remain follow-up work.

Follow DEVICE_TESTING.md to record same-phone and two-phone physical acceptance. This is not yet a hardware-accepted release.
