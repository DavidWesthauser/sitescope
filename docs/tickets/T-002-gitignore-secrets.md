# T-002 Fix .gitignore so Secrets.xcconfig can never be committed

- Status: in-progress · Priority: P0 · Estimate: 0.5 h · Owner: — · Depends on: —
- Requirements: technical rule "no secrets in Git"

## Problem
`.gitignore` listed `sitescope/Resources/Secrets.xcconfig`, but the file lives at `SiteAR/Resources/Secrets.xcconfig`, so it could be committed.

## Tasks
- [x] Replace the entry with `**/Secrets.xcconfig` (keep `Secrets.example.xcconfig` tracked).
- [ ] Add common Xcode/Swift artifacts: `*.xcresult`, `.swiftpm/`, `build/`, `supabase/.temp/`, `.env*`.
- [x] Run `git check-ignore -v SiteAR/Resources/Secrets.xcconfig` to confirm.
- [ ] Scan history once for keys (`git log -p | grep -E "sb_secret|service_role|eyJhbGci"`).

## Acceptance criteria
- [x] A created `SiteAR/Resources/Secrets.xcconfig` does not appear in `git status`.
- [ ] No secret key in history.
