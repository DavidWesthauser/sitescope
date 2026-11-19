# T-016 Error, loading and lifecycle handling for all flows

- Status: todo · Priority: P1 · Estimate: 5 h · Owner: — · Depends on: T-003, T-008
- Requirements: G5

## Goal

Make every flow show a clear message for backend errors, loading, empty lists, denied permissions and invalid input, instead of raw errors or crashes. In-progress input should survive backgrounding and force-quit.

## Tasks

- [ ] Map backend errors (401, 403, 404, 409, 5xx, timeout, offline) to clear user messages; avoid raw "Request failed (0)".
- [ ] Loading states: skeleton/ProgressView on lists, disabled buttons while saving (one global overlay today).
- [ ] Empty states for every list (projects, houses, rooms, tasks, comments, members).
- [ ] Permissions: camera, photos, microphone — explain + "Open Settings" button.
- [ ] Preserve in-progress input (task editor, comment draft, new project name) across background/foreground; consider autosaving AR drafts so force-quit loses less.
- [ ] Input validation feedback inline (name length, email format).

## Acceptance criteria

- [ ] Checklist walk-through with airplane mode, denied permissions and invalid input: no crash, every case has a readable message.
