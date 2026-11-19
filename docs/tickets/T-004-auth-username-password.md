# T-004 Registration, sign-in and sign-out with username/email + password

- Status: todo · Priority: P0 · Estimate: 6 h · Owner: — · Depends on: T-003
- Requirements: M6, G3, G5

## Goal
Users register and sign in on the phone with credentials; the session survives relaunch and refreshes automatically.

## Tasks
- [ ] Decide "username": use email as login (Supabase default) **or** add a `profiles.username` unique column + sign-in by username via an RPC/Edge Function that resolves to the email. Document the choice; requirement says "Username und Passwort".
- [ ] Create `profiles` table (id → auth.users, display name, username) with RLS; trigger on sign-up.
- [ ] Polish `AuthenticationView` to match the mockup (Sign in / Create account / Use without account); show/hide password; inline validation (email format, password ≥ 8, matching confirm).
- [ ] Clear messages for wrong password, unconfirmed email, network down, rate limit.
- [ ] Sign-out clears Keychain session and in-memory data (exists, verify).
- [ ] Optional: password reset email.

## Acceptance criteria
- [ ] Register → (confirm) → sign in → kill app → relaunch still signed in → sign out returns to login.
- [ ] Wrong credentials and no network show understandable errors; no crash.
- [ ] UI test covers invalid login error case (see T-015).
