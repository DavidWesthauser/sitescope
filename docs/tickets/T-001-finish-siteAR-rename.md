# T-001 Finish the sitescope → SiteAR rename so the project builds

- Status: done · Priority: P0 · Estimate: 3 h · Owner: — · Depends on: —
- Requirements: G6, G7 (nothing can be tested until this is done)

## Problem
Folders were renamed to `SiteAR/` but `Package.swift`, the Xcode project, scheme, generator and app struct still used `sitescope`, so nothing built.

## Tasks
- [x] Update `scripts/generate_project.py` to the SiteAR names and regenerate the project (`DEVELOPMENT_TEAM` and bundle id kept).
- [x] Update `Package.swift` paths/targets (`SiteARCore`, `SiteARCoreTests`, `SiteARServiceTests`).
- [x] Rename app struct to `SiteARApp`; Info.plist display and bundle name and camera text say "SiteAR".
- [x] Bundle id kept as `de.davidwesthauser.sitescope`: changing it would create a new app and hide local data on installed phones.
- [x] Compatibility identifiers kept: Application Support folder `sitescope/`, AR anchor `sitescope.room.<id>` (saved maps depend on it), Keychain service `sitescope.auth`, UTI `de.davidwesthauser.sitescope.project`, archive magic `SiteAR01` (was `sitescope01`, which broke every import; fixed).
- [x] Update README build/test commands.
- [ ] Rename user-facing strings in Swift views ("sitescope" in navigation titles, alert title, Settings section).
- [ ] Decide whether the export extension becomes `.sitear` (as in mockups); if so, still accept `.sitescope` on import.

Follow-up: in-app strings still say "sitescope"; `.sitear` extension decision open.

## Acceptance criteria
- [x] `swift test` passes from repo root (92 passed).
- [x] `xcodebuild -project SiteAR.xcodeproj -scheme SiteAR ... test` passes on a simulator (unit/layout 113 passed; UI 5 passed, 2 skipped).
- [ ] App launches showing "SiteAR" in all screens (display name done; in-app strings open).
- [ ] Existing local data on a test phone is still visible after updating (not verified on device).
- [x] STATUS.md "Last verification" updated with the new test counts.
