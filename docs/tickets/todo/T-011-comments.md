# T-011 Comments with text, image and audio

- Status: todo · Priority: P0 · Who: together · Owner: — · Depends on: T-006, T-008
- Requirements: M8, G4, G5

## Description

Members discuss a project, house or room with text, photos and voice messages, also offline. Camera and microphone need a phone check.

## Tasks

- [ ] Migration: `comments` table with RLS by role, storage path, JPEG and m4a allowed.
- [ ] One `CommentsSection` on all three levels: list, post, delete, pending state; empty text rejected.
- [ ] Photo from camera or library; voice up to 2 minutes with playback; denied permissions explained with a Settings link.

## Acceptance criteria

- [ ] pgTAP: viewer cannot post; own comments only, admin any; wrong file type rejected.
- [ ] Unit tests: validation, row mapping, 2-minute limit.
- [ ] UI test: add a comment; an empty comment shows the error.
- [ ] A human recorded, played and took a photo on a phone.
