# ADR 0001: Marker-free room localization with ARWorldMap

Status: accepted (2026-10-25). Supersedes an earlier marker/reference-point fallback.

## Context

A technician's phone must find the same room coordinate frame days after the manager scanned it, without printed markers, QR codes or stickers, and on camera-only iPhones (no LiDAR required). Two separate problems: **geometry** (surfaces to draw on) and **localization** (recovering the shared frame). A detailed mesh alone does not solve localization.

## Options

| Option | Fit |
|---|---|
| ARKit `ARWorldMap` | Native, camera-only, no extra service; maps can be shared as files/cloud blobs. Needs overlapping, recognizable viewpoints. **Chosen** |
| Google ARCore Cloud Anchors (iOS SDK) | Good room-scale candidate; needs Google service, keyless auth for TTL > 1 day, sends visual data to Google, more CPU/memory. Deferred |
| Immersal VPS | Larger spaces, offline maps possible; licensing and Unity-centric tooling. Deferred |
| Printed markers / reference dots | Excluded by product decision; removed from UI |
| LiDAR / RoomPlan | Better geometry on supported phones only; does not replace localization. Possible NICE-TO-HAVE (T-021) |

## Decision

- Use `ARWorldMap` with a named room anchor `sitescope.room.<coordinate_id>` at the room origin.
- Show notes only after the anchor is restored and tracking is stable; hide them on tracking loss; never fall back to an arbitrary origin.
- An optional saved-view photo helps the user find the viewpoint; it is not a matching input.
- Maps are shared through the project file today and through Supabase Storage once H-003 is done.

## Consequences

- Recognition is probabilistic: fails on blank walls, very different lighting, moved furniture. Users must check placement before consequential work.
- Remapping a room requires a new room (maps are immutable), so notes never silently move.
- Legacy marker/reference fields remain decodable but unused (deleted in T-027).
- Physical tests (H-001) decide whether this stays, including moved furniture and sharing. If the room changes, T-010 refreshes the map; if recognition is insufficient, T-010 compares fallbacks (recovery rate, time, error, memory).

Sources: [Apple ARWorldMap](https://developer.apple.com/documentation/arkit/arworldmap), [Apple multiuser AR](https://developer.apple.com/documentation/arkit/creating-a-multiuser-ar-experience), [Google Cloud Anchors iOS](https://developers.google.com/ar/develop/ios/cloud-anchors/developer-guide), [Immersal](https://developers.immersal.com/docs/immersal-sdk/howdoesitwork/).
