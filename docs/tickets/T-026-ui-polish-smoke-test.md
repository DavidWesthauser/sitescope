# T-026 UI polish from simulator smoke test (2026-11-19)

- Status: todo · Priority: P2 · Estimate: 4 h · Owner: — · Depends on: T-001
- Requirements: G1, G5, quality UI/UX

## Goal

Fix the rough edges found in an iPhone 17 simulator run of the local Debug build. No crash was seen, and the main flows passed (create, rename and delete project and room; Map room shows the unsupported-AR alert; export share sheet; empty name rejected; dark mode readable). This ticket covers only the polish items.

## Tasks

- [ ] Project detail: attach the "Delete project and all rooms" confirmation to the tapped button. Right now it opens as a popover anchored at the room row near the top, covering the room name.
- [ ] Export: name the file after the project (sanitized) instead of `sitescope-<id>.sitescope`. The extension change to `.sitear` is a separate open decision from T-001; do not change it here.
- [ ] App icon: add an asset catalog (`Assets.xcassets`) with an AppIcon and an accent color. The share sheet currently shows a blank icon and CoreUI logs a missing-catalog fault. Coordinate with T-012.
- [ ] AR unsupported state:
  - [ ] Make the close control consistent. The button says "Cancel", its VoiceOver label is "Close", and the confirm button says "Close AR".
  - [ ] Fix the "AR unavailable" pill, whose accessibility label is longer and may be clipped.
  - [ ] Do not show "Live scan" with a grey dot when the device is unsupported.
  - [ ] Rename the alert title "AR guidance" to something specific to an unsupported device.
  - [ ] Do not ask "Leave this unsaved scan?" when nothing could be scanned.
- [ ] Settings: reword "Sharing becomes available when cloud accounts are connected". It contradicts the working Export project feature.
- [ ] VoiceOver:
  - [ ] Settings gear reads "Gear Shape". Give it the label "Settings".
  - [ ] Hide decorative SF Symbols from accessibility. Currently read out: "Ar", "Business", "Open Left-Hand Door", "Screenshot", "Light Bulb".
- [ ] Project list: every row subtitle says "Rooms and instructions". Show the room count instead (mockup: "2 rooms · shared with Alex").
- [ ] Tint glitch: the "Export project" button text turned black after the share sheet closed. It should stay teal. Find the cause and fix it.
- [ ] Code review: `ProjectFileShareButton` resets `shareItem` and `exportedFile` only in the presenter's finish callback. If the presenter is torn down without calling it, the button stays disabled and the temp export is not deleted. Reset and delete on teardown too.

## Acceptance criteria

- [ ] Each finding above is fixed.
- [ ] Each fix is re-checked in the simulator, with screenshots for the delete dialog, export file name, app icon and AR unsupported screen.
- [ ] VoiceOver pass on Projects, project detail, room and the AR unsupported screen. Labels are human-readable and no decorative icons are read out.
- [ ] Export button tint stays teal after the share sheet closes.
- [ ] Unit or UI tests still pass after the changes.
