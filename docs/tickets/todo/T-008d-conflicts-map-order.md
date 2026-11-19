# T-008d Conflict handling and immutable map ordering

- Status: todo · Priority: P0 · Estimate: 4 h · Owner: — · Depends on: T-008a, T-008b
- Requirements: M2, G5

## Goal

Concurrent edits resolve predictably: the latest `updated_at` wins for simple fields, and task status shows both versions for the user to choose. A room mapped offline uploads its map before its metadata.

## Tasks

- [ ] Last-writer-wins on `updated_at` for simple fields.
- [ ] Task status: keep both versions and let the user choose (mockup).
- [ ] Server rejects stale updates via an `updated_at` check; the client handles the rejection.
- [ ] Immutable map rule: a room mapped offline uploads map, then metadata, in that order.
- [ ] Unit tests for conflict resolution with a mocked backend.

## Acceptance criteria

- [ ] Unit test: newer `updated_at` wins for simple fields; stale update is rejected.
- [ ] Unit test: task status conflict yields two versions to choose from.
- [ ] Unit test: offline-mapped room uploads map before metadata.
