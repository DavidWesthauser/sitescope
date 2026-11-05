# sitescope

[Public GitHub repository](https://github.com/DavidWesthauser/sitescope)

Native iPhone spatial work instructions built with SwiftUI, ARKit and RealityKit. iOS 17+, A12 or newer recommended; **LiDAR is not required**. Open `sitescope.xcodeproj` and choose the **sitescope** scheme. There are no third-party iOS dependencies.

**The current workflow is local-only. Do not connect a backend for this test.** An unconfigured Debug build opens an empty project list without login and stores real world maps, instruction images and tasks in Application Support (`sitescope/local.json` and `sitescope/assets/`). Export/import transfers a separate editable project copy in one `.sitescope` file. There is no live synchronization or remote revocation. Deleting the app deletes its local data.

Cross-device room recovery and physical placement accuracy still require hardware acceptance. Compilation, mathematical tests and file roundtrips do not establish real-world localization accuracy. See [verification status](docs/VERIFICATION.md).

## Install on a manager or technician iPhone

Each phone needs the app installed separately. For the current local test use a **Debug** build without Supabase settings; Release builds still require backend configuration.

1. On the Mac, open Xcode, accept its licence and finish installing the iOS platform components. Open **Xcode → Settings → Apple Accounts** (Accounts in older versions) and sign in with your Apple Account.
2. Connect the unlocked iPhone with a data-capable USB cable. Accept accessory access on the Mac and **Trust This Computer? / Diesem Computer vertrauen?** on the phone.
3. Open **Window → Device Hub** (or **Devices and Simulators**), select the phone and finish pairing/device preparation.
4. Enable **Settings → Privacy & Security → Developer Mode** / **Einstellungen → Datenschutz & Sicherheit → Entwicklermodus** on the iPhone. Restart, unlock and confirm **Enable / Aktivieren**. If the setting is missing, initiate Xcode pairing first. See [Apple's Developer Mode instructions](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).
5. Open `sitescope.xcodeproj`. Select the **sitescope** target → **Signing & Capabilities**, enable **Automatically manage signing** and choose your Personal Team or paid team. Use a unique bundle identifier, for example `de.yourname.sitescope.dev`. The checked-in bundle identifier is `de.davidwesthauser.sitescope`; choose one your team can sign. If editing settings directly, change `PRODUCT_BUNDLE_IDENTIFIER` in `sitescope/Resources/Config.xcconfig`.
6. Select the **sitescope** scheme, **Debug** configuration and the physical phone as destination. Leave `sitescope/Resources/Secrets.xcconfig` absent/unconfigured. Click **▶ Run** / **Command-R** and allow signing/device registration if prompted.
7. If iOS reports an untrusted developer, follow its trust prompt under **Settings → General → VPN & Device Management**. Otherwise no extra trust step is needed. The app should open Projects directly, without registration.
8. Allow camera access when opening **Map room** or a walkthrough. Test using the actual phone screen. Keep Device Hub's physical-device **View Screen/mirroring off**: [Apple documents that it blocks camera access](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub). USB debugging may remain connected.
9. Repeat these steps for the technician's iPhone. Keep the same team and bundle identifier when renewing each existing installation so its local data survives.

Germany uses this same Xcode workflow. A free Apple Account / Personal Team is enough for initial local testing; its provisioning expires after seven days. Reconnect and Run over the existing app, rather than deleting it. See [Apple's account guidance](https://developer.apple.com/help/account/basics/about-your-developer-account) and [physical-device installation](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices). Do not assume a development `.app` can be sent by AirDrop and installed on an unsigned technician phone.

The simulator can exercise lists and file handling, but cannot map or recognize a room through a real camera. If the app asks for backend configuration, check that you selected Debug and left backend secrets unconfigured. Camera permission can be restored in iPhone Settings → Privacy & Security → Camera.

## Scan, draw and recognize the room again

1. Create a project and room, then choose **Map room**. Move slowly around textured walls, corners and the floor. Thin boundaries indicate detected plane patches. The shaded miniature is an overview of observed surfaces; Options shows direction/position evidence and map readiness.
2. Observe all four horizontal heading sectors from at least three positions separated by 0.5 m. Pause for about a second at each textured view: the four small bars fill only after 0.75 seconds of continuous usable observations, with no more than 0.35 m horizontal drift during that pause. A quick sweep does not count. Spinning in place is insufficient. The current implementation uses at least 20 tracking feature points as a conservative observation heuristic; this is not calibrated physical accuracy or a room-coverage score. Once tracking is stable, the map is ready and at least one plane is detected, choose **Finish**. By default, sitescope saves a small photo of the current view to help someone find the same viewpoint later; turn it off under **Scan options → Room recognition** before saving if preferred. This saves the map and continues drawing in the same session. These gates do not prove complete coverage.
3. Aim at a detected surface. **Lock view** holds the image and drawing plane while ARKit continues tracking. Choose **Draw**, **Area marking** or **Image**. Lifting your finger ends a freehand stroke; the next stroke remains separate. Undo removes the last stroke. Areas use tapped coplanar corners.
4. For an image, select a photo or PNG/JPEG file, adjust its physical width and tap to place it. Work details hold the title, description and priority. Save from the fixed bottom bar. Up to 32 strokes, 256 samples per stroke and 2,048 samples total are supported per drawing; use multiple instructions for longer work.
5. Initial raycast placement requires stable detected plane geometry within 0.15–5 m. Placement evidence expires after a one-second observation gap and resets after tracking loss. Mint highlighting indicates a placement gate, not measured physical accuracy. Explicit measured-distance placement is available when surface detection is poor. It affects drawing placement; it does not recover a room coordinate frame.
6. Close AR, force-quit, relaunch and choose **Start AR walkthrough**. Match the saved view shown in the status card (tap it to enlarge) against the real room, then look around familiar details. Older rooms or scans with the photo disabled have no photo. Saved drawings appear only after ARKit restores the matching room anchor and stable tracking. On failure use **Keep searching** or explicitly restart it with **Restart recognition**. Tracking loss hides overlays; the task list stays available.
7. Walk around the instructions and update task status. Save before leaving; force-quitting loses unsaved drafts. To replace a map after major physical changes, create a new room revision rather than moving existing instructions silently.

If a scan is restarted or interrupted, its old map-save retry snapshot is discarded. Delayed callbacks cannot attach that map to the new session. If publication already succeeded, close AR and reopen the saved room for recognition.

There are no fixed markers, printed targets, stickers, QR references or selected reference dots. Marker capture/detection and manual-reference recovery have been removed. Older serialized fields still decode for compatibility but are inactive. Native ARWorldMap recovery is the current localization method. Recognition is not guaranteed from any position, blank walls, changed lighting or rearranged furniture.

## Transfer a project to the technician without a backend

1. On manager phone A, save a real mapped room, a drawing/area and an image instruction. Change a task's status. Close and reopen the project to check that the saved data is present.
2. In **project details**, choose **Export project**. Use the native share sheet to **AirDrop** the `.sitescope` file to phone B or **Save to Files** and transfer it through Files. Export contains that project's records and referenced world-map/image files, including any saved room-view photo.
3. On phone B, with the local Debug app installed, choose **Import project** on the Projects dashboard and select the file. Alternatively open the `.sitescope` file from Files/AirDrop in sitescope. The backend remains unconnected throughout.
4. Confirm the imported project contains the expected room names, instructions, image, task status and physical dimensions. Import creates new project, room and annotation IDs. It preserves each room's `coordinate_id`, map anchor relationship and instruction poses/vertices, and rewrites asset paths for the new copy.
5. In the same physical room, start the imported room's walkthrough. Observe previously scanned details until recovery succeeds; compare each instruction against the real surface. Record recovery time and physical error. End the session and repeat after relaunch. **This two-phone physical test is still pending.**
6. Edit a title/status or add a drawing on B, then verify A remains unchanged. Export B's edited project and import it on A: it becomes another independent copy, not a merge or update of the original.
7. Cancel an import and check the existing projects remain unchanged. Try a truncated/corrupted copy and confirm an error leaves no partial project. Keep the original file intact for comparison. Automated disk tests additionally cover traversal, symlinks, duplicate IDs, coordinate mismatch and cleanup.

The file uses a bounded JSON manifest followed by raw asset bytes, streamed in chunks of at most 1 MiB; assets are not base64-encoded. Limits are **16 MiB manifest, 256 MiB per asset, 1 GiB total assets, 256 rooms, 2,000 annotations and 100,000 total geometry points**. SHA256 verifies each asset. Missing files, invalid paths or associations, unsupported versions, corruption, truncation and trailing bytes are rejected. Legacy inactive marker images are not included.

Anyone who receives a copy can retain and edit it. Local transfer has no server authorization, live status updates, merge, synchronization or remote revocation. It does **not** satisfy the course's cloud-persistence/account requirements.

## Surface appearance and performance limits

`RoomSurfaceModel` conservatively consolidates near-coplanar overlapping patches for the miniature only. It does not reconstruct a full room, mesh, furniture, windows or other semantic objects. Original ARKit raycast geometry, saved map coordinates and annotation poses remain unchanged. LiDAR/RoomPlan and Gaussian Splatting are not integrated.

RealityKit displays at most 24 nearby outlines, using a batched edge mesh and optional halo per outline; new outlines use a native **0.45-second opacity fade** on iOS 18+ (immediate display on iOS 17), without a CPU-stepped boundary trace. The miniature caches up to 24 patches with 12 samples each. While animating it targets **30 Hz**; it is static when settled, under reduced-detail pressure or with Reduce Motion. These are scheduling targets, **not measured phone FPS**.

Memory warnings or serious thermal pressure reduce outlines to 12 without halos and simplify the miniature. Metadata stays bounded to 128 patches with 64 samples each; active placement has a separate bounded stability tracker. These measures limit visualization work, not ARKit's internal map memory. A 600-surface simulator stress fixture verifies budgets and preservation of instructions, not a fix for a physical crash. Camera-only recovery, long scans, thermal behavior and memory still need device measurements.

The earlier animation revision `88d4de7` was installed and launched on an iPhone 12 mini. That historical result does not validate the current transfer/rendering changes or physical AR accuracy. See [verification](docs/VERIFICATION.md) for current evidence.

## Tests

Portable macOS tests use disk fixtures and injected network fixtures, without credentials or backend connection:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

In a restricted environment set `CLANG_MODULE_CACHE_PATH=/tmp/sitescope-module-cache` and `SWIFTPM_MODULECACHE_OVERRIDE=/tmp/sitescope-module-cache`, then use `--disable-sandbox --scratch-path /tmp/sitescope-swift-build` if needed.

Build app/test bundles without running a simulator:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project sitescope.xcodeproj -scheme sitescope \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/sitescope-derived CODE_SIGNING_ALLOWED=NO build-for-testing
```

Run iOS tests against an installed simulator runtime, replacing the device name as needed:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project sitescope.xcodeproj -scheme sitescope \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Local UI suites exercise project/room persistence and unsupported simulator AR. Cloud tests explicitly skip without dedicated test credentials. The deferred [backend setup guide](docs/BACKEND_SETUP.md) preserves hosted configuration, all four migrations, local seed data and policy-test commands. Supabase migrations, policy tests and client code remain in the repository for future work; they have not been connected for this local workflow. Do not infer live authentication or policy acceptance from mocked network tests.

## Repository and course scope

- `sitescope/App`: entry point and application Store.
- `sitescope/Core`: spatial models, validation, transfer codec and display geometry.
- `sitescope/AR`: ARKit lifecycle, secure world-map archive, raycasts and RealityKit geometry.
- `sitescope/Services`: existing Supabase client, token refresh and Keychain code; deferred for this workflow.
- `sitescope/Views`: native project/room/task lists, file transfer and AR tools.
- `supabase`: existing migrations, private Storage/RLS policies and test fixtures.
- `sitescopeTests`, `sitescopeAppTests`, `sitescopeUITests`: deterministic, service and UI tests.
- `scripts/generate_project.py`: deterministic project regeneration.

See [architecture](docs/ARCHITECTURE.md), [requirements](docs/REQUIREMENTS.md), [localization decision](docs/decisions/0001-marker-free-shared-localization.md), [hardware runbook](docs/DEVICE_TESTING.md) and [verification](docs/VERIFICATION.md). Cloud Anchors/Immersal remain research options; no provider SDK is integrated.

The [course audit](docs/COURSE_AUDIT.md) separates implementation from accepted requirements. Local export/import does not close mandatory cloud persistence or account acceptance. Backend activation, live policy testing, physical AR evidence and lecturer-approved two-person scope remain future work.

OpenAI Codex generated substantial implementation, tests and documentation, including focused subagent work. Earlier corrections included the invisible miniature (`88d4de7`), frozen-view capture races and excessive per-edge rendering. See [AI handover notes](docs/AI_USAGE.md). Each student still needs a truthful individual reflection and concrete review example; generated documentation is not evidence of individual understanding. Count extras only when outside the lecturer-approved MUST-HAVEs.
