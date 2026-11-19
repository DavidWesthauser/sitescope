# T-020 Git workflow and regular contributions by both members

- Status: todo · Priority: P0 · Estimate: ongoing · Owner: both · Depends on: —
- Requirements: P1, P2, P3, P5

## Goal

Show regular, individual contributions from both members in git history. The history was squashed into one `init` commit on 2026-11-05. Since then, work goes through branches and PRs (first PR: docs, tickets, rename, formatting). Graders use git history to judge individual contribution.

## Tasks

- [ ] Each ticket on its own branch `t-XXX-short-name`, merged via PR; the ticket ID in commit messages (`T-005: add houses migration`).
- [ ] Small commits with meaningful messages; each member commits their own work.
- [ ] Split tickets between Leonard and David (fill `Owner` in each ticket); each member owns complete features they can explain at the handover.
- [ ] Hand-write parts and ask AI for explanations, not only code (course rule against vibe coding); note examples for the AI reflection (T-019) as they happen.
- [ ] Repo stays readable by `behrends` (currently public).

## Acceptance criteria

- [ ] Both members have regular commits every week until submission.
