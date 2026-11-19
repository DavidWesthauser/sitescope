# T-026c App icon and asset catalog

- Status: todo · Priority: P2 · Estimate: 1 h · Owner: — · Depends on: — (coordinate with T-012)
- Requirements: G1

## Goal

Add an asset catalog with an app icon and accent color. The share sheet currently shows a blank icon, and CoreUI logs a missing-catalog fault.

## Tasks

- [ ] Add `Assets.xcassets` to the app target with an AppIcon and an accent color (teal).
- [ ] Coordinate with T-012, which adds status and semantic color sets to the same catalog. Agree on the accent value and avoid duplicate sets.
- [ ] Check the run log for the missing-catalog CoreUI fault and confirm it is gone.

## Acceptance criteria

- [ ] Share sheet shows the app icon instead of a blank icon (screenshot).
- [ ] Simulator run logs no missing-catalog CoreUI fault.
- [ ] Teal tint is applied in both light and dark mode (simulator re-check).
