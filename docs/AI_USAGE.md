# AI usage and handover preparation

Course rule: AI tools are allowed, but every member must understand, review and be able to explain the code; the README must contain a short reflection and **one concrete example per member** (see REQUIREMENTS.md P3–P5, ticket T-019).

## Tools used so far

- **OpenAI Codex** (until 2026-10-31): large parts of the Swift/SwiftUI/ARKit implementation, Supabase migrations, tests and docs.
- **Claude Code** (from 2026-10-31): performance/lifecycle review, refactoring, documentation and ticket planning.

Checks used on generated code: compilation with strict concurrency, deterministic unit tests, UI tests, screenshot review, code review. Physical AR and live backend behavior were **not** verified by these checks.

## Recorded corrections of AI-generated code

Commit hashes refer to the pre-squash history (the current repo has a single `init` commit, so they are not reachable here).

| When / commit | Problem in generated code | Fix |
|---|---|---|
| `88d4de7` | Animated scan miniature was invisible before its animation clock advanced; layout assertions still passed | Render existing geometry immediately; pixel test `testMiniatureRendersWithoutAnAnimationClock` |
| `ece3928` | Concurrent snapshot requests in the locked-view flow; stale callback could clear a valid drawing plane | `ViewCaptureRequest` rejects stale/duplicate requests; ordering test |
| `ece3928` | One render entity per edge, repeated searches, unbounded miniature work during long scans | Batched, bounded meshes and pressure-based detail reduction |
| 2026-10-27 | Pending map bytes survived a reset of the AR coordinate origin | `MapSaveTransaction` generation checks; callback-ordering tests |
| 2026-10-27 | Failed image reposition could reuse an old photo; slow selections overwrote newer ones | Image request tokens, explicit draft clearing |
| 2026-10-31 | `ViewThatFits` for the AR tools card would reset state and oscillate; a modifier chain exceeded the type checker; a test called a non-existent helper | Rejected before commit; split into `ARSessionFeedback`; test rewritten against real API |

These are factual project examples, **not** personal reflections. Each member must still write their own (T-019):

- name, owned features/files, own commits
- which AI tool, for what
- one suggestion they personally checked, corrected or rejected (+ commit), their reasoning and what they learned

## Handover topics every member should be able to explain

1. Room vs. session coordinates and the transform order `sessionFromRoom × roomFromAnnotation`.
2. Why loading an ARWorldMap is not proof of alignment; why notes hide on tracking loss.
3. Why import creates new IDs but keeps `coordinate_id` and poses.
4. What lives in Postgres vs. Storage, and how RLS blocks outsiders and limits roles.
5. Local mode vs. cloud mode vs. offline sync; what each test suite actually proves.
6. Error handling and lifecycle (background, interruption, permission denial).
7. The layer structure (views → view models → repositories → backend/local store) after T-013.
