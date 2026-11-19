# T-024 Two-factor authentication

- Status: todo · Priority: P3 · Estimate: 6 h · Owner: — · Depends on: T-004
- Requirements: N4

## Goal

Add TOTP two-factor authentication so an account with it enabled cannot sign in without the code. Face ID unlock of the stored session is optional.

## Tasks

- [ ] Use Supabase Auth MFA (TOTP): enroll (`/auth/v1/factors`, show QR/secret), challenge + verify on sign-in, unenroll in Settings.
- [ ] Respect AAL2 in RLS for sensitive actions (e.g. delete project) if feasible.
- [ ] Optional: Face ID to unlock the stored session.

## Acceptance criteria

- [ ] Account with TOTP enabled cannot sign in without the code.
