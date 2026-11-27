# Backend setup (Supabase)

Schema, rules and API: [DATABASE_API.md](DATABASE_API.md). Everything lives in `supabase/`: one migration (`migrations/20261127120000_schema.sql`), local seed data (`seed.sql`) and the access tests (`tests/access.test.sql`). New tables come as new migrations named `YYYYMMDDHHMMSS_name.sql`. Never edit a migration that has already been pushed to the hosted project.

## Local stack (CLI + Docker)

```sh
supabase start      # first run downloads the images
supabase db reset   # applies the migration and seed.sql
supabase test db    # pgTAP access tests
```

Seed accounts (local only), password `sitescope-local-2026!`: `manager@sitescope.test` (responsible for "Demo project"), `worker@sitescope.test` (external on it), `outsider@sitescope.test` (no access). The seed room is unmapped; a real ARWorldMap only comes from scanning on a phone. Studio runs at http://127.0.0.1:54323.

The simulator can use the local stack, but the app only accepts `https` URLs, so a phone or simulator test of the app needs the hosted project.

## Hosted project (H-003)

1. `supabase login`, then create the project in the EU region (dashboard, or `supabase projects create`).
2. `supabase link --project-ref <ref>` and `supabase db push` (applies the migrations; never run `seed.sql` there).
3. Dashboard → **Authentication → Providers → Email**: email/password sign-up on. *Confirm email* may be off for a test-only project.
4. Check **Table Editor** (9 tables, RLS on) and **Storage** (`room-assets`, private).
5. Make yourself admin if needed, in the SQL editor: `insert into public.admins (user_id) select id from auth.users where email = '…';`
6. **Connect** dialog: copy the Project URL and the **publishable** key (`sb_publishable_…`).

Never put the database password, a secret key or the service-role key into the app or Git.

## Configure the app

1. Copy `sitescope/Resources/Secrets.example.xcconfig` to `sitescope/Resources/Secrets.xcconfig` (git-ignored).
2. Fill in:
   ```xcconfig
   SUPABASE_URL = https:/$()/abcdefghijklmnopqrst.supabase.co
   SUPABASE_ANON_KEY = sb_publishable_REPLACE_ME
   ```
   Keep `https:/$()/` exactly: in xcconfig `//` starts a comment. No quotes.

With a backend configured the app starts on the sign-in screen. **Use Without an Account** opens the projects saved on the iPhone (they are never uploaded); Settings → **Sign In or Create Account** goes back.

## Cloud UI test account

Xcode → Edit Scheme → Test → Environment Variables: `sitescope_TEST_EMAIL`, `sitescope_TEST_PASSWORD` (dedicated test account). The cloud UI test skips without them.
