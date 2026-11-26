# H-001 Phone test: accuracy, moved furniture and sharing

- Status: todo · Priority: P0 · Who: human · Owner: — · Depends on: T-010 (readout step only)
- Requirements: M3, G4, G5

## Description

Find out on real iPhones whether the core idea works: scan a room, place notes, find them again later, after furniture moved, and on a second phone. The result decides whether the ARWorldMap foundation stays.

## Tasks

Run everything in local mode, **before** adding `Secrets.xcconfig` (cloud mode blocks file export and import). Follow DEVICE_TESTING.md. Place three notes on walls: near the scan start, about 3 m away, and on the far side. Mark their true position with tape and measure the error in cm.

- [ ] Install over the existing app on the 12 mini: old projects and maps still open. Note whether old data has text, arrow or marker notes (T-027 needs this).
- [ ] **Same phone:** force-quit and recognize again, 10 tries.
- [ ] **Later:** recognize the next day, and with different light (daylight, lamps), 5 tries each.
- [ ] **Furniture:** 5 tries after each step: one chair moved; table cleared and several chairs moved; a large piece moved (sofa or cupboard). Record whether wall notes stay correct, and what happens to a note placed on furniture that moved.
- [ ] **Sharing:** send the project by AirDrop from A to B and recognize on B, 10 tries. Repeat from B to A.
- [ ] **Different phones:** include a LiDAR iPhone in both directions if one can be borrowed, and two iOS versions if available.
- [ ] **Point cloud (T-028):** the feature points shown while scanning are readable and do not slow the scan.
- [ ] **Rooms:** one room with many details, one with mostly blank walls, one large room.
- [ ] **Robustness:** scan for 2, 5 and 10 minutes (an earlier long-scan crash was reported; collect the `.ips` file), deny camera access, background and return.

## Acceptance criteria

- [ ] Results table in STATUS.md: phones, iOS, commit, room, change made, tries recognized, time, error at each note, anchor offset from the T-010 readout.
- [ ] Decision written in ADR 0001 using the table in Notes.
- [ ] Every blocking bug has a ticket.

## Notes

Proposed bar: at least 8 of 10 tries recognized within 40 s, error at most 10 cm.

| Result | What to do |
|---|---|
| Bar reached, also after moved furniture | Keep ARWorldMap |
| Fails only after furniture or light changed | T-010, "Update scan" |
| Recognized, but notes are offset | T-010, use the anchor position first, then repeat |
| Often not recognized, or only fails on the second phone | T-010, update the scan or rescan the room, before building more features |
