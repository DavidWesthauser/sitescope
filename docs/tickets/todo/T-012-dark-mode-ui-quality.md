# T-012 Dark mode and UI quality

- Status: todo · Priority: P1 · Who: agent · Owner: — · Depends on: —
- Requirements: M7, G1, G5, quality "Bedienung und UI/UX"

## Description

Every screen is readable in both modes, accessible, and shows clear loading, empty and error states. The last pass happens after T-011.

## Tasks

- [ ] Asset catalog with app icon, accent and status colors; appearance setting System, Light, Dark; no hard-coded colors outside AR overlays.
- [ ] Readable messages for server errors, offline and denied permissions; loading and empty states; input survives background.
- [ ] Smoke test findings: delete dialog anchored to its button, room count in rows, Settings sharing text, export button tint; AR unsupported screen (one close label, clipped pill, no "Live scan" dot, alert title, no unsaved-scan prompt, view-update warning).
- [ ] VoiceOver labels ("Settings" gear, hidden decorative icons, AR controls), Dynamic Type, contrast 4.5:1, 44 pt targets.
- [ ] Short in-app guide and first-run hints for scanning.

## Acceptance criteria

- [ ] Layout tests in dark mode and large text; accessibility audit in the simulator is clean.
- [ ] Unit tests: error mapping and draft restore.
- [ ] UI tests: appearance survives relaunch, an error state, delete confirmation, unsupported AR screen.
