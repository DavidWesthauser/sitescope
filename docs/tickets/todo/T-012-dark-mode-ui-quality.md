# T-012 Dark mode and UI quality

- Status: todo · Priority: P1 · Who: agent · Owner: — · Depends on: —
- Requirements: M7, G1, G5, quality "Bedienung und UI/UX"

## Description

Every screen is readable in both modes, accessible, and shows clear loading, empty and error states. The last pass happens after T-011.

## Tasks

- [x] Appearance setting System (default), Light, Dark in Settings; applied at the root and to the window, so sheets, alerts and UIKit views follow; stored as `appearance` in UserDefaults.
- [x] Asset catalog with `AccentColor` and `Warning`, each with light, dark and high-contrast values (all ≥ 4.5:1, see CONVENTIONS.md); no hard-coded colors outside AR overlays.
- [ ] App icon in the asset catalog.
- [ ] Readable messages for server errors, offline and denied permissions; loading and empty states; input survives background.
- [x] HIG pass on Project, Room, Task and Settings: names edited inline, destructive actions in their own last section with a footer and a named confirmation anchored to their button, explanations in section footers, real names as titles.
- [ ] Smoke test findings: room count in rows; AR unsupported screen (one close label, clipped pill, no "Live scan" dot, alert title, no unsaved-scan prompt, view-update warning).
- [ ] VoiceOver labels ("Settings" gear, hidden decorative icons, AR controls), Dynamic Type, contrast 4.5:1, 44 pt targets.
- [ ] Short in-app guide and first-run hints for scanning.

## Acceptance criteria

- [ ] Layout tests in dark mode and large text; accessibility audit in the simulator is clean. The screenshot tour needed on-device data and was removed in T-003; a new one needs a test account.
- [ ] Unit tests: error mapping and draft restore.
- [ ] UI tests: an error state, unsupported AR screen. Done: appearance survives relaunch (`testAppearanceSettingAppliesAndSurvivesRelaunch`), delete waits for confirmation (`deleteProject` helper).
