# sitescope

Native iOS 17+ app (SwiftUI, ARKit, RealityKit) with a Supabase backend. DHBW course project by Leonard Aichele and David Westhauser.

State: `docs/STATUS.md`. Tickets: `docs/tickets/todo/` and `docs/tickets/done/`, order in `docs/STATUS.md`. Other docs: `docs/README.md`.

## Commands
- Core tests: `swift test`
- App and UI tests: `xcodebuild -project sitescope.xcodeproj -scheme sitescope -destination 'platform=iOS Simulator,name=iPhone 17' test`
- Before committing: `swift format --in-place --recursive sitescope sitescopeTests sitescopeAppTests sitescopeUITests Package.swift`, then the same with `lint --strict` instead of `--in-place`
- RLS tests: `supabase start && supabase db reset && supabase test db`
- Xcode project: change `scripts/generate_project.py` and regenerate, never edit `project.pbxproj`

## Workflow
- Work from a ticket; follow `docs/CONVENTIONS.md`. Extend a ticket before adding one.
- Never tick or fake `H-XXX` tickets or "by a human" steps.
- Small commits with the ticket ID (`T-005: ...`).
- Only write tests for features that exist.
- Replace outdated doc text instead of appending.

## Gotchas
- Never change persisted identifiers, or users lose data: bundle ID `de.davidwesthauser.sitescope`, AR anchor `sitescope.room.<id>`, data folder `sitescope/`, Keychain service `sitescope.auth`, file type `.sitescope`, 8-byte archive magic `sscope01`.
- Never commit `sitescope/Resources/Secrets.xcconfig`. Only the publishable Supabase key goes in the app.
- Enforce access with RLS, not only in the UI.
- Pure logic goes in `sitescope/Core/`, with unit tests.
- AR only counts as working after a test on a real iPhone (`docs/DEVICE_TESTING.md`).
