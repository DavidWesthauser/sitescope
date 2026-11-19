# T-011 Comments with text, image and audio on projects, houses and rooms

- Status: todo · Priority: P0 · Estimate: 14 h · Owner: — · Depends on: T-005, T-006
- Requirements: M8, G4, G5

## Goal

Members can discuss a project, a house or a room with text, photos and voice messages. Each sub-ticket is one PR.

## Sub-tickets

- [T-011a](T-011a-comments-data-model.md) Data model, RLS, storage paths, repository (4 h)
- [T-011b](T-011b-comments-text-section.md) Reusable CommentsSection with text comments (4 h)
- [T-011c](T-011c-comments-image.md) Image comments: camera and photo picker (3 h)
- [T-011d](T-011d-comments-audio.md) Audio comments: record and play (3 h)

## Acceptance criteria

- [ ] Text, image and audio comments can be added and deleted on project, house and room; other members see them.
- [ ] Denied mic/camera permission shows explanation + Settings link.
- [ ] Viewer role cannot post (enforced server-side).
