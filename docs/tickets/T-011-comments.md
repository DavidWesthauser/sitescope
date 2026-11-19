# T-011 Comments with text, image and audio on projects, houses and rooms

- Status: todo · Priority: P0 · Estimate: 14 h · Owner: — · Depends on: T-005, T-006
- Requirements: M8, G4, G5

## Goal
Members can discuss a project, a house or a room with text, photos and voice messages.

## Tasks
- [ ] Model + migration: `comments { id, project_id, target_type (project|house|room), target_id, author_id, text?, attachment_path?, attachment_type (image|audio)?, duration?, created_at, updated_at }`; RLS (read = project access; create per role; edit/delete own, admins delete any). Storage paths under `<project>/comments/...`.
- [ ] Reusable `CommentsSection` view (one component for all three levels): list (author, time, content), composer with text field, photo (camera + PhotosPicker), audio record button.
- [ ] Audio: `AVAudioRecorder` (AAC .m4a, max length e.g. 2 min), playback with `AVAudioPlayer`, `NSMicrophoneUsageDescription`, denied-permission handling.
- [ ] Camera capture for photos (`NSCameraUsageDescription` exists) + image downscaling like instruction images.
- [ ] Works offline through T-008 outbox.
- [ ] Unit tests (validation, mapping), UI test (add text comment, error on empty comment).

## Acceptance criteria
- [ ] Add/delete text, image and audio comment on each level; visible to other member.
- [ ] Denied mic/camera permission shows explanation + Settings link.
- [ ] Viewer role cannot post (server-side).
