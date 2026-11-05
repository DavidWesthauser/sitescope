# Deferred backend setup

The current user-selected workflow uses local `.sitescope` export/import. **Do not perform these steps for the current local test.** This retained guide makes the existing backend schema and policies reproducible when cloud work resumes. Live deployment and policy acceptance are pending. Local projects and file imports do not automatically upload to cloud mode.

## Hosted development instance (future setup)

Using the hosted dashboard is the simplest first test; no Supabase CLI, Docker or local server is needed.

1. Open [Supabase Dashboard](https://supabase.com/dashboard), sign in and create a **new development project**, for example `sitescope-test`. Choose a nearby European region, such as Frankfurt if offered. Wait for provisioning to finish.
2. Open the project's **SQL Editor** and create a new query.
3. On the Mac, open `supabase/migrations/202610230001_sitescope.sql` in a text editor. Copy **the entire file**, paste it into the SQL Editor, and click **Run**. Then run `supabase/migrations/202610230002_scan_and_draw.sql` the same way. Then run `supabase/migrations/202610230003_images_and_strokes.sql` and `supabase/migrations/202610270004_scan_guide.sql`. Run these migrations once each, in order, on the new project. It creates the tables, access policies, functions and private `room-assets` bucket. If it reports an error, resolve that before continuing; do not repeatedly rerun parts at random.
4. In **Table Editor**, check that `projects`, `memberships`, `rooms` and `annotations` exist. In **Storage**, check that `room-assets` exists and is **private**. The bucket starts empty.
5. Open **Authentication → Sign In / Providers** (or **Providers**, depending on the dashboard version), select **Email**, and allow email/password sign-up.
6. For a dedicated first-test project, you can turn **Confirm Email** off and save. This lets you create test accounts without configuring email delivery. For production, enable confirmation and configure SMTP. If confirmation stays on, confirm the email before signing in. See [Supabase's email settings](https://supabase.com/docs/guides/auth/general-configuration).
7. Open the project's **Connect** dialog and copy its **Project URL** and **publishable key**. Alternatively, find the key under **Settings → API Keys**. The URL looks like `https://abcdefghijklmnopqrst.supabase.co`; a new publishable key starts with `sb_publishable_`. See [Supabase's URL/key instructions](https://supabase.com/docs/guides/api/creating-routes).

Do **not** run `supabase/seed.sql` on this hosted project. It is for the local development stack only. Create your test users through the app. Do not copy a database password, secret API key or service-role key into the iOS app.

## Configure the app for that instance

1. In Finder, open this repository, then `sitescope/Resources`.
2. Duplicate **`Secrets.example.xcconfig`** and name the copy exactly **`Secrets.xcconfig`**. Check that the filename is not `Secrets.xcconfig.txt`. Use a plain-text editor such as Xcode to edit it.
3. Replace the two settings with your actual project values:

   ```xcconfig
   SUPABASE_URL = https:/$()/abcdefghijklmnopqrst.supabase.co
   SUPABASE_ANON_KEY = sb_publishable_REPLACE_WITH_YOUR_ACTUAL_KEY
   ```

   Replace the example project reference and key. **Keep `https:/$()/` exactly as written**: Xcode expands it into `https://`; a literal `//` starts an xcconfig comment. Do not add quotes. The setting name `SUPABASE_ANON_KEY` is retained by this app even when its value is a newer publishable key. A legacy `anon` key is also supported.
4. Save the file. `Config.xcconfig` already includes it; you do not need to add it to Copy Bundle Resources. It is ignored by Git.


## Local test instance and seed

Local Supabase (requires CLI and Docker):

```sh
supabase start
supabase db reset
supabase test db
```

The seed creates `manager@sitescope.test`, `worker@sitescope.test`, `outsider@sitescope.test` with password `sitescope-local-2026!` and an **unmapped** fixture room. These identities are only for the local development stack. Never run seed.sql in production. No fake map or simulated AR event is used in the real application. The pgTAP test supplies synthetic spatial metadata inside a rolled-back SQL transaction exclusively to test access rules.

To connect a physical iPhone to a local Supabase stack, expose it through a trusted HTTPS development endpoint and configure that URL. `localhost` on the phone is the phone itself. Prefer a separate hosted development project for the two-device AR test. Do not disable App Transport Security globally.


## Cloud UI test account

In Xcode Edit Scheme → Test → Arguments → Environment Variables, set `sitescope_TEST_EMAIL` and `sitescope_TEST_PASSWORD` for a dedicated test account. Tests create/delete their own uniquely named project. The cloud test explicitly skips when credentials are absent; the local login bypass is not authentication verification. Sign out before testing login validation. Do not use a production account.
