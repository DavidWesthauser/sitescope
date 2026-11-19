# T-001 Name everything sitescope so the project builds

- Status: done · Priority: P0 · Estimate: 3 h · Owner: — · Depends on: —
- Requirements: G6, G7 (nothing could be built or tested before this)

## Goal

Make the project build and test under one name, sitescope. The code was half-renamed: folders used one name, while `Package.swift`, the Xcode project, scheme and generator used the other, so nothing built.

## Tasks

- [x] Folders `sitescope/`, `sitescopeTests/`, `sitescopeAppTests/`, `sitescopeUITests/`; generator produces `sitescope.xcodeproj` with scheme and targets `sitescope*`.
- [x] `Package.swift`: module `sitescopeCore`, test targets `sitescopeCoreTests`, `sitescopeServiceTests`.
- [x] App struct `SitescopeApp`; Info.plist display name, bundle name, camera text and all in-app text say "sitescope".
- [x] Migration `202610230001_sitescope.sql` (never deployed, so renaming is safe).
- [x] Persisted identifiers unchanged: bundle ID `de.davidwesthauser.sitescope`, AR anchor `sitescope.room.<id>`, data folder `sitescope/`, Keychain `sitescope.auth`, `.sitescope` file type.
- [x] Bug fixed: the archive magic had become 11 bytes while the reader checks 8, so every import failed. Now `sscope01`.
- [x] README, AGENTS.md and docs updated.

## Acceptance criteria

- [x] `swift test` passes from repo root.
- [x] `xcodebuild -project sitescope.xcodeproj -scheme sitescope ... test` passes on a simulator.
- [x] App shows "sitescope" on every screen (simulator).

## Notes

Decision (2026-11-19): the project is called **sitescope** everywhere. The mockups use SiteAR, the earlier working name.
