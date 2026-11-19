# T-026d AR unsupported state copy and controls

- Status: todo · Priority: P2 · Estimate: 2 h · Owner: — · Depends on: —
- Requirements: G1, G5

## Goal

Make the AR unsupported screen (Map room on a device without AR) consistent, readable and free of misleading prompts.

## Tasks

- [ ] Make the close control consistent. The button says "Cancel", its VoiceOver label is "Close", and the confirm button says "Close AR". Use one label across all three.
- [ ] Fix the "AR unavailable" pill: its accessibility label is longer than the visible text and may be clipped.
- [ ] Do not show "Live scan" with a grey dot when the device is unsupported.
- [ ] Rename the alert title "AR guidance" to something specific to an unsupported device.
- [ ] Do not ask "Leave this unsaved scan?" when nothing could be scanned.
- [ ] Fix the SwiftUI runtime warning "Publishing changes from within view updates is not allowed" logged when the unsupported AR screen opens (seen in the 2026-11-19 smoke test and UI test runs).

## Acceptance criteria

- [ ] Simulator re-check of the AR unsupported screen, with screenshot: no "Live scan" dot, pill fully visible, specific alert title.
- [ ] Close label is the same on the button, its VoiceOver label and the confirm action.
- [ ] UI test: Map room on an unsupported device shows the new alert title and closes without the unsaved-scan prompt.
