# T-014 Consistent code style: formatter + linter

- Status: done · Priority: P1 · Estimate: 4 h · Owner: — · Depends on: T-001
- Requirements: quality "Lesbarkeit", "Programmierstil"

## Problem
Much code is packed into single lines with `;` separators (e.g. `Models.swift`, `Store.swift`, `ManagementViews.swift`), hard for outsiders to read.

## Tasks
- [x] Add `swift-format` (bundled with Xcode 16+) config `.swift-format` (4 spaces, 120 columns). Two rules are disabled, with reasons in `docs/CONVENTIONS.md`. Commands are in `AGENTS.md` and `docs/CONVENTIONS.md`.
- [x] Reformat the codebase in one dedicated commit (no behavior change; normalized diff checked). Commit pending.
- [x] Add doc comments on non-trivial parts (spatial math, archive format, map-save generation checks, AR lifecycle, rendering budgets, token refresh, Keychain).
- [ ] Optional, open: pre-commit hook or CI step (GitHub Actions `swift test` + lint). Not done.

## Acceptance criteria
- [x] Lint runs clean (`swift format lint --strict --recursive` exits 0); one-statement-per-line style, no semicolons.
- [x] Format/lint commands documented in `AGENTS.md` and `docs/CONVENTIONS.md`. The root README was not changed.
- [x] Tests pass after the reformat: `swift test` 92; simulator 113 unit/layout, UI 5 passed, 2 skipped.
