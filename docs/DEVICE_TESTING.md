# Device testing checklist

AR, camera and room recognition cannot be tested in the simulator. Run these on real iPhones, including at least one **without LiDAR** (iPhone 12 mini). Record results in [STATUS.md](STATUS.md) → *Last verification*: date, device, iOS, commit, room, lighting, recognition time, approximate placement error, failures.

Before starting: install via Xcode (Developer Mode on, signing set). **Keep Xcode's device screen mirroring off** — it blocks camera access (black video).

## 1. Single phone: scan → draw → recognize

1. Create project and room → **Map room**. Move slowly over textured walls/floor. Thin outlines appear; Finish stays disabled until ready (4 directions × 3 positions, each held 0.75 s). Spinning in place must not complete it.
2. **Finish** → continues into drawing in the same session.
3. **Lock view** on a wall. Moving the phone must not move the frozen view. Test **Draw** (two separate strokes, no connecting line, Undo removes one), **Area** (3–4 corners), **Image** (photo + transparent PNG, adjust width). Fill work details, save.
4. Close AR, force-quit, relaunch → **Start AR walkthrough**. Drawings stay hidden until "Room recognized", then appear in the right place. Walk around and estimate error (target e.g. ≤ 10 cm).
5. Change a task status without AR; relaunch; status persists.

## 2. Two phones

- **File transfer (works today):** Export project on A → AirDrop/Files → Import on B. Same rooms, images, statuses. Recognize the room on B. Cancelled and corrupted imports leave no partial project.
- **Cloud (H-003):** manager on A, member on B. Create on A, refresh on B, recognize the room on B, complete a task, see it on A. Outsider sees nothing.
- **Offline (H-005, after T-008):** airplane mode on B, change status, relaunch, reconnect → syncs to A.

## 3. Failure and lifecycle cases

| Case | Expected |
|---|---|
| Different room / changed lighting, wait 40 s | No drawings at a wrong origin; Keep searching / Restart recognition work |
| Cover lens or move fast | Drawings hide; return after recognition |
| Background / lock and return | Scan progress kept after relocalization; Control Center does not pause AR |
| Blank or reflective wall | Placement waits, no guessed depth |
| Camera permission denied | Clear message, task list still usable |
| Long scan 2 / 5 / 10 min | No crash; profile CPU/memory with Instruments; collect `.ips`/Jetsam report if it exits |
| Leave with unsaved drawing | Warning before discarding |

## 4. Appearance and accessibility

Dark mode, largest Dynamic Type size, VoiceOver on main screens and AR controls, Reduce Motion (scan animations become static).
