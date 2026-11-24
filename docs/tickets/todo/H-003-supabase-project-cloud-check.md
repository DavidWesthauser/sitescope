# H-003 Create the Supabase project and check cloud sharing on two phones

- Status: todo · Priority: P0 · Who: human · Owner: — · Depends on: H-001, T-003
- Requirements: G2, G3, M1, M4

## Description

A hosted backend exists, and a room created on phone A can be recognized on phone B through it.

## Tasks

- [ ] Create a Supabase project in the EU region and enable email and password sign-up.
- [ ] Apply the migrations (BACKEND_SETUP.md).
- [ ] Create `sitescope/Resources/Secrets.xcconfig` on both Macs with the URL and publishable key. Never commit it.
- [ ] Phone A: project, room, scan, instruction, share with B. Phone B: refresh, recognize the room, complete the task. Phone A sees it.
- [ ] Sign in with a third account and check it sees nothing.

## Acceptance criteria

- [ ] The two-phone check passes; result recorded in STATUS.md.
- [ ] The outsider account sees nothing.
- [ ] A configured Release build runs on a phone.
