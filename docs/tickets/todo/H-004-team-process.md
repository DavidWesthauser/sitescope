# H-004 Team process: owners, commits and understanding the code

- Status: todo · Priority: P0 · Who: human · Owner: both · Depends on: —
- Requirements: P1, P2, P3, P5

## Description

Both members contribute visibly and can explain the code. AI may write it, but each member must understand it.

## Tasks

- [ ] Fill `Owner` in every ticket; each member owns complete features.
- [ ] Both members commit every week under their own name, on ticket branches merged by PR.
- [ ] Merge PRs with a normal merge commit. PR #1 was squashed, so its six commits are not on `main`.
- [ ] Each member reads the code they own and can explain the handover topics in AI_USAGE.md.
- [ ] Note AI mistakes you caught as they happen (needed for H-006).
- [ ] Arrange installation and testing on iOS with the lecturer early; check that `behrends` can read the repo.

## Acceptance criteria

- [ ] `git shortlog -sn main` shows regular commits from both members.
- [ ] Each member has explained their area to the other once.
