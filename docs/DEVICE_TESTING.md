# Physical-device acceptance runbook

Record phone/iOS/app version, room and coordinate IDs, date, lighting and approximate physical error. Include a camera-only iPhone. Keep Device Hub physical-device screen viewing OFF: mirroring blocks camera access. The USB cable/debugger alone does not require mirroring.

## Local scan and drawing

1. Install an unconfigured Debug build through Xcode on the physical phone. The app opens an empty project list without login. Create your own project/room.
2. Choose Map room. Pan slowly over textured walls, floor and furniture. Verify thin white surface boundaries appear without any filled white faces, the live overview updates, counts represent actual detected planes/features, and Finish remains disabled until map/tracking readiness.
3. Check the floating surface overview and top Cancel/Finish controls. Tap Finish. It must transition directly into drawing in the SAME session. No marker print or reference-dot collection is required.
4. Aim at a wall and choose Lock view. Move/rotate the phone slightly: the editing viewpoint must stay fixed. With **Draw**, draw a curved stroke, lift your finger, then draw elsewhere. There must be no connecting segment, sample dots or angular boxes. Undo must remove only the last stroke. Save and reopen to check both paths persist. Use **Area marking** for three/four coplanar corners. Use **Image**, import a photo and a transparent PNG, adjust width, tap to place and save. Verify proportions and image bytes survive force-quit/reopen and room recovery. Enter a long title/description through Work details and check keyboard dismissal. Try Undo/Clear/Resume camera. Reopen walkthrough and inspect geometry while moving sideways. No filled plane faces or sample dots should obscure the room. Check compact-screen controls, scrolling, large text, sticky Save, import cancellation and leaving with an unsaved draft.
5. Close AR and force-quit the app. Reopen the saved room's walkthrough. From the original viewpoints, look around until Room recognized. Drawings must stay hidden before recovery and then appear automatically, without confirming reference dots.
6. Walk around and compare wall/area placements. Measure approximate error against an agreed target (for example 10 cm); do not infer survey precision. Repeat on another day and under different lighting.
7. Tap a drawing, save In Progress/Completed and refresh/relaunch to verify task persistence. Create/rename/delete unrelated rooms and ensure the saved drawing stays with the correct room.

## Local file / two-phone acceptance (current workflow)

1. Install an unconfigured Debug build on manager A and technician B; at least one phone must have no LiDAR. Keep the backend disconnected and use no fixed markers or reference-dot selection.
2. On A scan a real room, save separate drawing strokes, an area and an image instruction, and update a task status. Relaunch and verify local persistence.
3. Open project details → Export project. AirDrop the `.sitescope` file or Save to Files and transfer it. On B select Import project in Projects, or open the file in sitescope from Files. The native picker must allow cancellation without a partial import.
4. Check B has the expected rooms, images, task statuses and geometry. Existing projects must remain unchanged. A repeated import creates another editable copy. With an active search, opening an external file must clear the filter and report import success without closing an unsaved AR editor.
5. In the actual room use B's walkthrough. From overlapping scanned viewpoints wait for map recovery, then inspect drawing placement from several positions. Record time and physical error; repeat days later and in changed lighting. Before recovery drawings must stay hidden.
6. Update B's copy, export it back and import on A. It must create another independent copy, with no silent overwrite/merge. Local files do not provide role protection, live synchronization or revocation.
7. Try a corrupt/truncated copy and a file with missing assets in a disposable test. Report the error with no partial project/assets; existing data must survive relaunch. Preserve the original valid file. Portable disk tests cover additional structural/path/checksum and metadata-write failures.

## Deferred cloud/two-device acceptance

Do not connect the backend for the current file-transfer test. Use [backend setup](BACKEND_SETUP.md) when cloud work resumes.

1. Apply migrations 001, 002, 003 AND 004 to a development Supabase project. Configure matching backend settings in both phone builds, register two users, and sign in manager on A and worker on B. Local rooms do not migrate automatically; create a new cloud test project/room.
2. Repeat scan/drawing creation on A. Verify the room's map_path and surfaces metadata and its private map object exist. Share with B's registered email and end the session on A.
3. On B refresh Projects, select the shared room and start walkthrough. Recover the map and inspect the intended wall placement from several positions. Complete a task, refresh on A, and verify the status.
4. Repeat with the camera-only phone as both manager and worker. No depth/RoomPlan dependency should occur. Record cross-device physical error separately from single-device results.

## Recovery and failure tests

- **Timeout:** enter a different room or change lighting significantly. Wait 40 seconds. No drawings should appear at a new arbitrary origin. Return to the original viewpoints, choose Restart recognition and recover.
- **Tracking loss:** cover the lens/move too quickly. Drawings must disappear, recognition restarts, and normal tracking plus correct saved-map evidence is required to show them again.
- **Interruption/background:** lock/unlock or background. New scans resume and keep their progress once ARKit relocalizes (point at an already-scanned area); saved rooms recover again. Pulling down Control Center must not pause or reset the scan, and the screen must not auto-lock during a long scan. Draft drawing points stay room-relative while the screen remains alive. Leaving warns before discarding unsaved work.
- **Poor planes:** on a textureless wall, a failed raycast must report/skip placement rather than invent a depth. Explicit measured-distance placement must require a real user measurement.
- **Plane merging:** revisit the same wall; merged plane anchors should replace old patches/counts. Counts are not a promise of unique architectural walls or complete room coverage.
- **Black video:** verify camera permission, stop Device Hub screen viewing, close/reopen AR directly on the phone. Do not attempt to verify live AR through mirroring.
- **Persistence failures:** disconnect during cloud upload/task save. Unsaved work remains available for retry. Room metadata publishes only after the assets exist; lost-response retries must not replace coordinates.
- **Invalid data:** corrupt a development map/version only in a disposable test room. Invalid data blocks rendering with an error. Drawings must remain hidden and task lists remain available; there is no physical-marker fallback.
- **Permissions:** outsider cannot read project/maps/tasks. Workers cannot change drawing geometry or share projects. Revoke worker access and reload; new requests must fail/omit data. Run `supabase test db` too.

Do not mark physical acceptance complete until same-phone persistence and two-phone recognition are recorded. Simulator/Core tests verify state/math/navigation, not camera recognition or physical accuracy. RoomPlan-style classified furniture boxes are not part of the camera-only plane visualization.

## Placement accuracy regression checks

- Aim at an undetected blank wall: placement must wait rather than snap to a guessed depth. Move sideways and inspect the mint highlighted patch before drawing; compare against physical corners.
- Aim the off-centre crosshair at a known measured location and use measured-distance placement. It must follow that crosshair, not the optical centre. Check the result from the side.
- Repeat on a feature-rich wall and a blank/reflective surface. Camera-only ARKit boundaries may remain incomplete or inaccurate; do not treat them as RoomPlan window/furniture recognition. Saving readiness still requires a mapped world map and stable tracking; no shorter scan time is guaranteed.

## Multi-view recognition acceptance (physical testing pending)

1. Create a new room revision. Walk to at least three safe positions 0.5 m apart and view all four horizontal directions. Stand still and rotate first: this must not finish the movement requirement. Scan the same textured details from overlapping viewpoints.
2. Save drawings, end the session and reopen from the entrance, an opposite corner and the middle of the room in separate sessions. Record recovery time and placement error against the same known physical features for each viewpoint; do not label arbitrary-point recognition as accepted.
3. Repeat facing a blank wall, after changed lighting, and after moving furniture. Uncertain recovery must keep drawings hidden. After timeout, continue searching without a session reset, then test the separate restart action.
4. Repeat using an older sparse map. The new capture guidance cannot improve that map retroactively; preserve its annotations and use a new room revision to compare broader capture.

## Animated scan acceptance (not yet run on hardware)

- On first detection, confirm white edges fade in once on iOS 18+ (appear directly on iOS 17), with a subtle halo. Continue scanning the same patch: its outline must refine without repeatedly disappearing/restarting. Check thin outlines leave the camera unobstructed.
- Watch the miniature gain only observed patches, conservatively combining overlapping coplanar patches without bridging unseen gaps, with shaded thin surfaces. Turn the phone across the +/-180-degree heading boundary: it should turn smoothly, not spin the long way. Look at floor/wall junctions and check depth ordering from several headings.
- Enable Settings → Accessibility → Motion → Reduce Motion. New surfaces should appear without the growing/reveal effect. Repeat a scan and background/return to check removed/restarted plane geometry does not linger.
- Compare appearance and performance on the iPhone 12 mini. Classifying windows/furniture like Apple's RoomPlan video is not an acceptance claim for this camera-only path; physical registration/recognition must still pass separately.

## Tracking and usability polish acceptance

- Start with a newly detected plane: Lock view must wait for the brief settling gate. Compare the mint target against actual edges; a settled wrong plane must not be accepted as physically correct merely because it is mint.
- Move too fast, face a blank wall, then return to a textured corner. Verify reason-specific advice and recovery. Cover the camera briefly during a stroke: that stroke must end, saved data must remain, and drawing must require a fresh touch after verified alignment.
- Lock view while moving/turning the phone: the snapshot must be rejected with a hold-steady message if camera pose changes appreciably. Hold still and retry, then check the resulting drawing from a second viewpoint.
- Test interruption/recovery and both explicit restart actions. No drawings may remain visible at an unverified origin. New-scan restart must warn before discarding its unsaved scan.
- Test project search, empty/no-result states, room progress (zero/some/all tasks complete), status changes, long titles, large text and save failures. Task status and progress must persist through relaunch.
- Profile FPS/energy and record wall placement/recovery error on the camera-only iPhone before claiming performance/accuracy improvements.

## Long-scan crash/performance acceptance

1. Keep Device Hub screen viewing off. Record iPhone model, iOS, room size, scan duration, thermal state and whether the failure occurs while scanning or saving. Do not delete the app or saved project to diagnose it.
2. Scan the same room for 2, 5 and 10 minutes, repeatedly revisiting surfaces. Profile CPU, memory, frame pacing and allocations with Xcode Instruments; record values rather than inferring performance from simulator timing. Confirm rendering remains capped and old outlines disappear when their geometry is removed/refined.
3. Simulate a memory warning in the simulator; on hardware observe genuine pressure/thermal changes. Reduced detail must release visual resources while preserving tasks/map references. Check that a real targeted surface remains placeable even when omitted from the displayed overview.
4. Finish/save, close, reopen and recover the same room. Verify each instruction's position and task status. ARKit map memory is independent of the display budget; do not treat a building-sized scan as one room.
5. If the app exits, retrieve the sitescope crash .ips or JetsamEvent report from Xcode/device diagnostics (or iPhone Settings → Privacy & Security → Analytics & Improvements → Analytics Data). Correlate timestamp/process and termination reason. A memory-pressure report, watchdog timeout and exception require different conclusions. Current development cannot label this crash fixed without that evidence and a successful hardware rerun.

## Minimal scan overlay check

Check Cancel/Finish over bright and dark real camera scenes, including disabled Finish. The coaching capsule should stay brief, the miniature should float near the bottom and the lower-left control should open Scan progress, tracking guidance and recovery options. Verify counts remain accessible in that sheet, the reduced-detail leaf has a VoiceOver label, and camera-denied/unsupported states do not incorrectly ask the user to keep moving. Repeat with large text; keep the renderer budgets unchanged.


## Capture and lifecycle regression checks (27 October 2026; physical pending)

- Sweep quickly through all directions: bars must not immediately complete. Pause at a textured view for about a second, move at least 0.5 m, pause again and capture all four directions. Check the guidance on blank/reflective surfaces. Twenty raw feature points is a tunable observation heuristic, not a measured accuracy threshold.
- After a placement target settles, cover the lens or move too quickly. Recover tracking and alignment: the target must settle afresh, rather than reuse the old mint state.
- Force a disposable map-upload failure, then restart scanning and save again. Compare the restored instruction against the newly scanned room; no cached old-origin map may be reused. Background during map capture/upload and repeat. Simulator domain fixtures cover invalidation without pretending to scan a room.
- For a future configured backend test, interrupt while publication is in flight. If the server save succeeds, the app must report that the room was saved and require reopening/recognition, rather than retrying a different map against an immutable room. If the response is lost, reopen and refresh the room to reconcile its state.
- Check the four small direction bars and position hint over bright/dark camera scenes at large text sizes. Bars describe qualified views, not scanned wall percentages. Record time to save, recovery time and physical placement error before claiming better recognition.


## Saved-view guidance and image loading (physical test pending)

- Scan a room with the viewpoint-photo option enabled. After finishing, reopen walkthrough and choose **Show saved viewpoint** while recognition searches. The photo must match a real previously scanned view and remain readable in portrait. Look for those same natural details; it is a guide for the person, not an AR detection target or evidence that the room has aligned.
- Export/import the project to the second phone and check the same photo appears. Disable the option on a new scan and check no viewpoint photo is available. Older rooms remain usable without one. The photo is included in exported files; share them only with the intended recipient.
- Keep searching past the timeout and then point at the captured scene. When ARKit eventually returns valid tracking and the saved room anchor, drawings should appear without requiring the button; missing anchor, unstable tracking or failure must keep them hidden. Record whether this actually succeeds on each device.
- Add and replace several image instructions; check the new images load, that removed/replaced images do not remain visible, and that closing AR during image loading does not resurrect content or overwrite another image. Display textures are limited to 1024 pixels on their longest edge while saved source images remain up to 2048; inspect the visual quality at working distance. Measure actual memory/temperature on the phone; the app still retains the textures of all currently active image instructions.
