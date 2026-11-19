# T-026 UI polish from simulator smoke test

- Status: todo · Priority: P2 · Estimate: 9 h · Owner: — · Depends on: —
- Requirements: G1, G5, quality UI/UX

## Goal

Fix the polish items from an iPhone 17 simulator smoke test of the local Debug build on 2026-11-19. No crash was seen and the main flows passed (create, rename and delete project and room; Map room alert; export share sheet; empty name rejected; dark mode readable), so this epic covers only the polish items.

## Sub-tickets

- [T-026a](T-026a-project-screens-polish.md) Project screens: delete dialog, room count, Settings text, export tint (3 h)
- [T-026b](T-026b-export-file-name-teardown.md) Export file name and share button teardown (1.5 h)
- [T-026c](T-026c-app-icon-asset-catalog.md) App icon and asset catalog (1 h)
- [T-026d](T-026d-ar-unsupported-state.md) AR unsupported state copy and controls (2 h)
- [T-026e](T-026e-voiceover-labels.md) VoiceOver labels and decorative icons (1.5 h)

## Acceptance criteria

- [ ] All five sub-tickets are done, each finding is fixed and re-checked in the simulator.
- [ ] Unit and UI tests still pass after the changes.
