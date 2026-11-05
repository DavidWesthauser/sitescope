# Marker-free localization for shared work instructions

Status: native ARWorldMap with local file transfer; external providers deferred research. Updated 25 October 2026. The user's current requirement excludes physical markers, stickers, QR targets and selected reference dots. Their earlier marker-fallback requirement is superseded; legacy serialized fields remain readable without being used for current room alignment.

## Two different problems

1. Geometry: capture/estimate surfaces on which drawings can be placed, and show a useful room model.
2. Localization: a technician's phone recovers the same physical coordinate frame days later.

A detailed mesh alone does not solve localization. LiDAR improves geometry/depth, but camera-based visual positioning can establish a shared frame without it. No candidate guarantees matching from every position, under all lighting or after arbitrary room changes.

## Options checked against primary documentation

| Approach | Marker-free / camera-only | Fit and limitations |
|---|---|---|
| ARKit ARWorldMap | Yes, compatible iPhones | Already implemented. Maps can be shared and restored, but require recognizable previously observed views. No extra positioning service; physical two-device acceptance still pending |
| Google ARCore Cloud Anchors | Yes, ARKit-compatible iOS devices; Android SDK also supported | Strong room-scale candidate to prototype for shared localization. Host visual features, share anchor ID, resolve on technician phone. Internet and ARCore API setup required; additional CPU/memory/network work needs profiling on the 12 mini |
| Immersal visual positioning | Camera-based; mapped spaces can support on-device/offline localization | Potential larger-space option. Mapping/service/license/native integration evaluation needed. Current product docs emphasize Unity/web; native samples also exist. Avoid changing the SwiftUI app to Unity merely to obtain this feature |
| Fixed visual reference targets | Excluded | Removed from current UI/capture/recovery; not a fallback for the new design |
| ARKit/RoomPlan depth reconstruction | LiDAR-dependent native capture capabilities | Useful optional geometry on supported hardware, not a replacement for marker-free shared localization on camera-only phones |

## Current decision: local map transfer, no backend

Keep native ARWorldMap recovery and transfer the saved map, room metadata, instructions and image assets in a single `.sitescope` file. Do not connect Supabase or a positioning provider for the current test. The manager chooses **Export project** in project details and uses the native AirDrop/Files share sheet. The technician uses **Import project** on the dashboard or opens the file in sitescope. Both phones require a separately installed local Debug build. See the [installation and exact transfer acceptance steps](../../README.md).

Import creates new project, room and annotation IDs with rewritten asset paths. It preserves `coordinate_id`, the matching map anchor, instruction poses/vertices and image dimensions. It creates an editable independent copy. Technician edits do not update the manager's original; a returned export imports as another copy. There is no live sync, merge, remote revocation or server authorization. This workflow does not meet the course cloud-persistence/account requirements.

The transfer codec streams raw assets in at most 1 MiB chunks with SHA256, preceded by a bounded manifest. Limits are 16 MiB manifest, 256 MiB per asset, 1 GiB total assets, 256 rooms, 2,000 annotations and 100,000 geometry points. It rejects unsafe paths/symlinks, missing files, invalid associations, corruption, truncation, trailing bytes and unsupported versions. Inactive legacy marker images are excluded. Export/import roundtrip tests establish file integrity, not physical room-recognition success.

New scans can optionally save a bounded JPEG of the manager’s current view with the room metadata. The technician can open this photo to find recognizable previously mapped details; it is only a human guide and is included in the project file. It does not act as a fixed marker, provide an AR transform or prove alignment. Older rooms work without it. The technician still needs to observe recognizable previously mapped views until ARKit restores the matching anchor and stable tracking. Measured-distance placement supports drawing placement only; it cannot recover a saved coordinate frame. Failed recovery leaves spatial overlays hidden.

## Future provider prototype, deferred

Cloud Anchors remains a candidate to evaluate alongside native ARKit on the iPhone 12 mini if local world-map recovery proves insufficient. No SDK or provider integration is part of this decision's current implementation. A future authorized prototype would host a visual anchor, persist its provider/version/expiry and room-to-provider transform, then resolve it on another phone before rendering. Its coordinate relationship must be verified rather than assuming provider and ARKit origins coincide.

Future application authentication, project membership and private asset access would still need a backend; an external localization provider does not replace them. Supabase code exists, but activating it is deferred. Renewing an expired localization reference must preserve a verified relationship to saved drawings rather than silently moving their coordinate frame.

## Important integration facts

- Google's iOS guide supports ARKit-compatible devices and integrates with their ARSession; this is not Android ARCore world tracking substituted into the Swift app.
- Persistent anchors can have TTL up to 365 days. **TTL over one day requires keyless authorization**; an API-key-only prototype expires within 24 hours and does not satisfy days-later use.
- Hosting/resolving sends visual data to Google's service. Consent/privacy documentation, quotas, authorization and the service account lifecycle must be designed and tested before shipping. Private service credentials belong server-side, not in app code or Git.
- Google documents increased memory, battery/network and CPU usage. This is a candidate to measure, not a claim that a heavier SDK will automatically fix this phone's crash or tracking issues.
- Immersal's documentation includes offline/on-device positioning of prebuilt maps, but adoption still requires license/integration and real-space validation.
- sitescope is currently an iPhone app. Cross-platform support of a positioning service does not create an Android sitescope client.

## Actual implementation status

Current app: native ARWorldMap recovery, explicit measured-distance placement, local `.sitescope` project transfer and bounded rendering. Physical-marker capture/detection, printing and manual reference-dot recovery are removed; legacy JSON fields still decode without enabling recovery. RoomSurfaceModel conservatively consolidates near-coplanar overlapping patches for the miniature only. It does not reconstruct a complete room, mesh or semantic objects, and does not change original map/annotation coordinates. New outlines use native 0.45-second opacity fades on iOS 18+ (immediate display on iOS 17) without a CPU-stepped trace. The active miniature targets 60 Hz for up to eight surfaces and 30 Hz otherwise, remaining static when idle, under pressure or with Reduce Motion. No measured phone FPS improvement is claimed. No Cloud Anchors or Immersal SDK is installed; no hosted provider, provider credentials, service account or backend integration has been activated by this research.

Supabase client/sharing/RLS code exists, but the current unconfigured Debug build is local-only and the backend is deliberately unconnected. File transfer can be tested independently of cloud authorization; physical two-phone recovery is still pending. Cloud sharing/account acceptance remains separate deferred work. A provider prototype must prove useful recovery rates/time/placement error and acceptable memory before replacing the current method.

## Required acceptance before external-provider adoption

The current local two-phone test is specified in the README. The following is future provider acceptance, not evidence of an integrated service.

Use manager A and technician B, including at least one camera-only iPhone. Host/save, end both sessions, return on another day, load from a different previously observed part of the room, resolve, walk around and complete a task. Record resolve time, physical error, failures and memory/thermal behavior. Repeat with changed lighting, expired/revoked access, network loss and an unrelated room. Unverified positions must never appear aligned.

## Primary sources

- [Apple: sharing ARWorldMaps](https://developer.apple.com/documentation/arkit/arworldmap)
- [Apple: multiuser map recovery and overlapping views](https://developer.apple.com/documentation/arkit/creating-a-multiuser-ar-experience)
- [Google: Cloud Anchors, visual feature maps and hosting/resolving](https://developers.google.com/ar/develop/cloud-anchors)
- [Google: iOS integration, keyless authorization and performance](https://developers.google.com/ar/develop/ios/cloud-anchors/developer-guide)
- [Google: iOS quickstart and persistent TTL](https://developers.google.com/ar/develop/ios/cloud-anchors/quickstart)
- [Immersal: mapping, positioning and offline localization](https://developers.immersal.com/docs/immersal-sdk/howdoesitwork/)
- [Immersal: compatibility](https://developers.immersal.com/docs/immersal-sdk/compatibility/)
