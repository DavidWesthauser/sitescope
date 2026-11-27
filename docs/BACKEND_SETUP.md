# Backend setup (Supabase)

Database design, rights and API: [DATABASE_API.md](DATABASE_API.md). The app needs a configured backend; without one it shows only the sign-in screen with a hint.

## Hosted project

- Project `sitescope Project` (ref `cnxtzzvedkihcxxwsepo`, EU Frankfurt). It runs the design from DATABASE_API.md, created in the SQL editor on 2026-11-26.
- The design is not in `supabase/migrations/` yet, so never run `supabase db push` or `supabase db reset --linked` against this project. Putting it into Git is the first task of T-029.
- Email/password sign-in: Dashboard → **Authentication → Providers → Email**. *Confirm email* may be off for a test-only project.
- Admins: in the SQL editor, `insert into public.admins (user_id) select id from auth.users where email = '…';`. The app cannot make admins.
- Never put the database password, a secret key or the service-role key into the app or Git.

## Configure the app

1. Copy `sitescope/Resources/Secrets.example.xcconfig` to `sitescope/Resources/Secrets.xcconfig` (git-ignored).
2. Fill in the Project URL and the **publishable** key (`sb_publishable_…`) from the dashboard's **Connect** dialog:
   ```xcconfig
   SUPABASE_URL = https:/$()/cnxtzzvedkihcxxwsepo.supabase.co
   SUPABASE_ANON_KEY = sb_publishable_REPLACE_ME
   ```
   Keep `https:/$()/` exactly: in xcconfig `//` starts a comment. No quotes.
3. Build. The app opens on the sign-in screen; register or sign in (passwords need at least 6 characters, Supabase's default).

## Local stack (CLI + Docker)

`supabase start` runs a local stack (`supabase/config.jsonc`). It has no schema until T-029 adds the design as a migration. The app only accepts `https` URLs, so it cannot use the local stack directly.

## Cloud UI test account

Xcode → Edit Scheme → Test → Environment Variables: `sitescope_TEST_EMAIL`, `sitescope_TEST_PASSWORD` (dedicated test account). The project/house/room UI test skips without them.
