# T-007 Room notes CRUD on the server (incl. maps and images)

- Status: todo · Priority: P0 · Estimate: 6 h · Owner: — · Depends on: T-003, T-006
- Requirements: M1, M4

## Goal
Creating, editing, saving and deleting instructions (drawing, area, image) works against Supabase exactly like locally.

## Tasks
- [ ] Verify `Store.saveInstruction`, `saveTask`, `deleteTask`, `publishRoom`, `uploadAsset`, `downloadAsset` against the live backend.
- [ ] Delete also removes the image object from Storage (today: orphan objects). Same for room/house/project deletes (Edge Function or client-side cleanup).
- [ ] Map upload order: assets first, then room metadata (exists) — test failure in between.
- [ ] Respect roles from T-006 in UI (hide edit tools for viewers).
- [ ] Show upload progress / busy state for large world maps.

## Acceptance criteria
- [ ] Each CRUD operation round-trips between two phones.
- [ ] Deleting an image instruction leaves no Storage object.
- [ ] Network failure mid-save leaves no half-saved state and shows an error (until T-008 queues it).
