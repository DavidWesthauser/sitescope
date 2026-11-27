# Backend setup (Supabase)

Status: schema and policies are **not deployed yet** (T-003, H-003). The pgTAP suite passes on the local stack (2026-11-27, T-027). New tables for houses, roles and comments will come as new timestamped migrations (`YYYYMMDDHHMM_name.sql`, run in filename order) (T-005, T-006, T-011). Keep this file in sync with `supabase/`.

## Hosted development project (dashboard, no CLI needed)

1. [Supabase Dashboard](https://supabase.com/dashboard) → new project (EU region, e.g. Frankfurt).
2. **SQL Editor**: run each file in `supabase/migrations/` once, in filename order (today only `202610230001_sitescope.sql`). Stop and fix on any error.
3. Check **Table Editor**: `projects`, `memberships`, `rooms`, `annotations`. **Storage**: bucket `room-assets` exists and is **private**.
4. **Authentication → Providers → Email**: enable email/password sign-up. For a test-only project you may disable *Confirm email*.
5. **Connect** dialog: copy Project URL and **publishable** key (`sb_publishable_…`).

Never put a database password, secret key or service-role key into the app. Do not run `seed.sql` on the hosted project.

## Configure the app

1. Copy `sitescope/Resources/Secrets.example.xcconfig` to `sitescope/Resources/Secrets.xcconfig` (it is git-ignored).
2. Fill in:
   ```xcconfig
   SUPABASE_URL = https:/$()/abcdefghijklmnopqrst.supabase.co
   SUPABASE_ANON_KEY = sb_publishable_REPLACE_ME
   ```
   Keep `https:/$()/` exactly — in xcconfig `//` starts a comment. No quotes. `Config.xcconfig` already includes the file.

## Local stack with seed data (CLI + Docker)

```sh
supabase start
supabase db reset   # applies migrations + supabase/seed.sql
supabase test db    # runs supabase/tests/access.test.sql (pgTAP, 33 assertions)
```

Seed users (local only): `manager@sitescope.test`, `worker@sitescope.test`, `outsider@sitescope.test`, password `sitescope-local-2026!`, plus one unmapped fixture room. A real ARWorldMap cannot be seeded; maps come from scanning on a phone. A phone cannot reach `localhost` on the Mac; use the hosted project for device tests.

## Cloud UI test account

Xcode → Edit Scheme → Test → Environment Variables: `sitescope_TEST_EMAIL`, `sitescope_TEST_PASSWORD` (dedicated test account). The cloud UI test skips without them. T-015 replaces this with a mocked backend.

## Access model (current)

| Actor | Rights |
|---|---|
| Owner (`projects.owner_id`) | Everything on own projects, `share_project(email)`, `revoke_worker` |
| Member (`memberships`) | Read project, rooms, notes, files; change task status via `set_task_status` |
| Anyone else | Nothing (RLS on tables and storage) |

Published room maps are immutable (trigger `preserve_coordinates`); notes require a mapped room (`require_mapped_room`). Read/write/delete roles are planned in T-006.
