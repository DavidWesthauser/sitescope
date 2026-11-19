# T-025 (NICE, from mockups) Activity feed and live progress

- Status: todo · Priority: P3 · Estimate: 8 h · Owner: — · Depends on: T-006, T-008
- Requirements: mockup screens "Live progress", "Team member"

## Tasks
- [ ] `activity` table filled by triggers (task status changes, scan started/saved, member joined).
- [ ] Project "Live progress" tab: per-room done/total, recent activity list; member detail with recent activity.
- [ ] Optional realtime updates via Supabase Realtime websocket; otherwise pull-to-refresh.

## Acceptance criteria
- [ ] Status change on phone B appears in A's activity list.
