# T-011b Reusable CommentsSection with text comments

- Status: todo · Priority: P0 · Estimate: 4 h · Owner: — · Depends on: T-011a, T-008 (offline task only)
- Requirements: M8, G5

## Goal

One `CommentsSection` view lists and posts text comments on project, house and room.

## Tasks

- [ ] `CommentsSection(target:)` view: list with author, time and text, newest first.
- [ ] Composer with text field and send button; trims whitespace.
- [ ] Empty-comment validation: send disabled, and an error message if submitted empty.
- [ ] Delete own comment (swipe or menu); admins can delete any.
- [ ] Offline: queue text posts in the T-008 outbox and show a "pending" state.
- [ ] Place the section on project, house and room detail screens.

## Acceptance criteria

- [ ] Unit test: validator rejects empty and whitespace-only text.
- [ ] UI test: add a text comment; posting an empty comment shows the error.
- [ ] Text comment on project, house and room is visible to a second member.
