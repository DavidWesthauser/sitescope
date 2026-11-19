# T-026a Project screens polish

- Status: todo · Priority: P2 · Estimate: 3 h · Owner: — · Depends on: —
- Requirements: G1

## Goal

Fix the project list, project detail and Settings copy found in the 2026-11-19 smoke test, including the export button tint that turns black after the share sheet closes.

## Tasks

- [ ] Project detail: attach the "Delete project and all rooms" confirmation to the tapped button. It currently opens as a popover anchored at the room row near the top, covering the room name.
- [ ] Project list: every row subtitle says "Rooms and instructions". Show the room count instead (mockup: "2 rooms · shared with Alex").
- [ ] Settings: reword "Sharing becomes available when cloud accounts are connected". It contradicts the working Export project feature.
- [ ] Tint glitch: the "Export project" button text turns black after the share sheet closes; it should stay teal. Find the cause and fix it.

## Acceptance criteria

- [ ] Delete confirmation opens anchored to its button and no longer covers the room name (screenshot).
- [ ] Each project row shows its room count, and the Settings sharing text no longer contradicts the export feature.
- [ ] Export button stays teal after the share sheet closes (simulator re-check).
- [ ] UI test covers the delete-project confirmation.
