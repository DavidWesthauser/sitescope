# T-021 Language setting German / English

- Status: todo · Priority: P3 · Estimate: 5 h · Owner: — · Depends on: T-001
- Requirements: N1

## Goal

Let users switch the app language between German and English. All UI and permission texts get German translations, so the main flows show no English leftovers.

## Tasks

- [ ] Add `Localizable.xcstrings` String Catalog; convert UI literals (SwiftUI `Text("…")` is localizable automatically; `String` messages in Store/Backend need `String(localized:)`).
- [ ] German translations for all strings incl. permission texts (`InfoPlist.xcstrings`).
- [ ] In-app: Settings row opening iOS app language settings (`UIApplication.openSettingsURLString`) — Apple's recommended per-app language mechanism — or an in-app picker.
- [ ] README NICE list entry.

## Acceptance criteria

- [ ] Switching to German shows no English leftovers in main flows.
