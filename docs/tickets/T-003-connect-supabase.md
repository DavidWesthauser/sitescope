# T-003 Connect a hosted Supabase project and make cloud mode the default

- Status: todo · Priority: P0 · Estimate: 6 h · Owner: — · Depends on: T-001, T-002
- Requirements: G2, G3, M1, M4

## Goal
The app talks to a real Supabase project. Data created on phone A is visible on phone B for an authorized user.

## Tasks
- [ ] Create a hosted dev project (EU region). Apply migrations 001–004 in order (see BACKEND_SETUP.md).
- [ ] Add `SiteAR/Resources/Secrets.xcconfig` locally with URL + publishable key (never commit).
- [ ] Run `supabase test db` against a local stack (`supabase start`); fix failing assertions.
- [ ] Startup: if configured → sign-in screen; "Use without an account on this iPhone" (mockup) becomes an explicit button that enters local mode — not only a Debug-without-config fallback.
- [ ] Decide how local-only projects relate to cloud (upload on sign-in, or keep separate) — feeds into T-008.
- [ ] Check maps/images upload to the private `room-assets` bucket and download for a second user.

## Acceptance criteria
- [ ] Manager on phone A creates project + room + mapped room + instruction; worker on phone B sees it after refresh.
- [ ] Outsider account sees nothing (verified in app and by pgTAP).
- [ ] Configured Release build runs.
- [ ] BACKEND_SETUP.md and STATUS.md updated.
