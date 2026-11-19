# T-011a Comment data model, RLS and repository

- Status: todo · Priority: P0 · Estimate: 4 h · Owner: — · Depends on: T-005, T-006, T-013a
- Requirements: M8, G5

## Goal

Store comments on a project, house or room, with access rules enforced on the server.

## Tasks

- [ ] New migration: allow `image/jpeg` and `audio/mp4` (m4a) in the `room-assets` bucket, which today allows only `application/octet-stream` and `image/png` (migration 202610230001_sitescope.sql).
- [ ] Migration: `comments { id, project_id, target_type (project|house|room), target_id, author_id, text?, attachment_path?, attachment_type (image|audio)?, duration?, created_at, updated_at }`.
- [ ] RLS: read = project access; create per role (viewer cannot); edit/delete own; admins delete any.
- [ ] Storage paths under `<project>/comments/...` with a storage policy that matches the RLS.
- [ ] Implement `CommentRepository` (list, create, delete) with Local/Remote following T-013a's pattern, and a Codable model that maps Supabase rows.

## Acceptance criteria

- [ ] Viewer insert is rejected by RLS; a member can delete own comment but not another's (scripted check against Supabase).
- [ ] Unit test: row-to-model mapping for text, image and audio rows, including nil fields.
- [ ] pgTAP or upload test: a JPEG and an m4a comment attachment upload succeeds; another type is rejected.
