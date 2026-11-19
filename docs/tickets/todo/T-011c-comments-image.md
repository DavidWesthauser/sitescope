# T-011c Image comments: camera and photo picker

- Status: todo · Priority: P0 · Estimate: 3 h · Owner: — · Depends on: T-011b
- Requirements: M8, G4

## Goal

Members can attach a photo from the camera or the photo library to a comment.

## Tasks

- [ ] Attach menu in composer: "Take photo" (camera) and "Choose photo" (`PhotosPicker`).
- [ ] Downscale with `SpatialImageAsset.prepare` (≤ 2048 px PNG, same as instruction images).
- [ ] Upload to `<project>/comments/...` and create the row with `attachment_type = image`.
- [ ] Thumbnail in the comment list; tap opens the full image.
- [ ] Denied camera permission: explanation text + "Open Settings" button (`NSCameraUsageDescription` already set).

## Acceptance criteria

- [ ] Unit test: `SpatialImageAsset.prepare` caps the long side at 2048 px and outputs PNG.
- [ ] Denied camera permission shows explanation and Settings link (manual check on device).
- [ ] Image comment can be added and deleted on project, house and room.
