# T-002 Fix .gitignore so Secrets.xcconfig can never be committed

- Status: done · Priority: P0 · Estimate: 0.5 h · Owner: — · Depends on: —
- Requirements: technical rule "no secrets in Git"

## Goal

Make sure `sitescope/Resources/Secrets.xcconfig` can never be committed. The old entry pointed at a path from before the rename, so the file would not have been ignored.

## Tasks

- [x] Replace the entry with `**/Secrets.xcconfig` (keep `Secrets.example.xcconfig` tracked).
- [x] Add common Xcode/Swift artifacts: `*.xcresult`, `.swiftpm/`, `build/`, `supabase/.temp/`, `.env*`.
- [x] Run `git check-ignore -v sitescope/Resources/Secrets.xcconfig` to confirm.
- [x] Scan history once for keys (`git log -p | grep -E "sb_secret|service_role|eyJhbGci"`).

## Acceptance criteria

- [x] A created `sitescope/Resources/Secrets.xcconfig` does not appear in `git status`.
- [x] No secret key in history (checked 2026-11-19; no Secrets.xcconfig was ever committed).
