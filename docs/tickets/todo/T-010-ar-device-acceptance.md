# T-010 Physical AR acceptance on real iPhones

- Status: todo · Priority: P1 · Estimate: 6 h · Owner: — · Depends on: T-001 (T-003 for the cloud run)
- Requirements: M3, G4, G5

## Goal

Prove on hardware that scan → draw → close → recognize → notes in place works, on one and on two phones. Fix what breaks.

## Tasks

- [ ] Follow DEVICE_TESTING.md sections 1–3 on a camera-only iPhone (12 mini) and, if available, a LiDAR iPhone.
- [ ] Record: device, iOS, recognition time, approx. placement error, failures.
- [ ] Reproduce/diagnose the long-scan crash (collect `.ips`/Jetsam report).
- [ ] Check camera-permission denial and background/foreground.
- [ ] Install the renamed build over an existing install and check local projects and maps are still there (bundle ID unchanged).

## Acceptance criteria

- [ ] Results table added to STATUS.md "Last verification".
- [ ] Blocking bugs filed as new tickets.
