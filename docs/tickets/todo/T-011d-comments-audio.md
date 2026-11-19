# T-011d Audio comments: record and play

- Status: todo · Priority: P0 · Estimate: 3 h · Owner: — · Depends on: T-011a, T-011b
- Requirements: M8, G4

## Goal

Members can record a voice message (max 2 min) on a comment and play it back.

## Tasks

- [ ] Add `NSMicrophoneUsageDescription` to Info.plist with a clear reason (voice comments).
- [ ] Record with `AVAudioRecorder` (AAC .m4a), stop automatically at 2 min, show elapsed time.
- [ ] Upload to `<project>/comments/...` with content type `audio/mp4` (allowed by T-011a's migration), `attachment_type = audio` and `duration`.
- [ ] Playback with `AVAudioPlayer` (play/pause, progress) in the comment row.
- [ ] Denied mic permission: explanation + Settings link; record button stays safe (no crash).

## Acceptance criteria

- [ ] Unit test: 2-min limit helper stops at 120 s and clamps duration.
- [ ] Denied mic permission shows explanation and Settings link (manual check on device).
- [ ] Voice comment can be recorded, played back and deleted on project, house and room.
