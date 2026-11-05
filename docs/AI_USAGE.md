# AI use and handover preparation

OpenAI Codex and, from 31 October 2026, Claude Code were used extensively for Swift/SwiftUI/ARKit implementation, Supabase migrations, tests, debugging and documentation. Focused subagents reviewed UI and tracking changes and implemented a small pure rendering-budget helper. Generated code was checked with compilation, deterministic tests, UI automation, screenshots and code review; physical AR and live backend acceptance remain separate.

Concrete examples of generated code that needed correction:

- Commit `88d4de7`: the first animated miniature could be invisible before its animation clock advanced. Screenshot review exposed this despite passing layout assertions. Existing geometry now renders immediately; `testMiniatureRendersWithoutAnAnimationClock` checks actual rendered pixels.
- Commit `ece3928`: the frozen-view workflow allowed concurrent snapshot requests. Focused review identified a stale callback that could clear a valid drawing plane. `ViewCaptureRequest` now rejects duplicate/stale requests and cancels them on reset, resume, stop and tracking loss; a deterministic test covers the ordering.
- Commit `ece3928`: a long-scan review found per-edge render entities, repeated searches and continuous unbounded miniature work. Display geometry is now sampled/bounded and batched, with pressure-driven detail reduction. Stress tests do not prove that the user's device crash is fixed.

- 27 October 2026: focused review found that pending map bytes/publication survived a new AR coordinate origin. The fix adds MapSaveTransaction generation checks around asynchronous results, clears retry state on interruption/reset and distinguishes an already-saved late response from an unsaved failure. Deterministic tests cover the callback ordering; physical room accuracy is still unverified.

- 27 October 2026: review found that a failed image reposition could reuse a previously selected photo, and that slow earlier selections could overwrite newer ones. Image request tokens, explicit draft clearing and simulator tests were added; this is a factual code-review example, not evidence of an individual student’s contribution.

- 31 October 2026: Claude Code (Anthropic) reviewed scan performance, lifecycle states and best practices against Apple's RealityKit/ARKit documentation (PR #1). Corrections made during that work: an inline `ViewThatFits` for the AR tools card was rejected before commit because its two view copies would reset an expanded disclosure and could oscillate; a measured-height scroll view keeps one identity. A modifier chain that exceeded the Swift type-checker was split into `ARSessionFeedback`. A recovery test first called a non-existent helper and was rewritten against the real async API. Simulator tests pass; phone frame rate, haptics and background resume remain unmeasured.

These are factual development examples, **not claims that either student personally performed the review or understands the code**. Both students' individual reflections are pending and must be written from their actual experience. Do not invent contribution histories, reviews or earlier commits.

For each student, record before submission:

- Actual name, owned feature/files and genuine commits.
- Which AI tool was used and for what.
- One concrete suggestion/code fragment they personally checked, corrected or rejected; include the commit when available.
- Their reasoning, test evidence and what they learned.

Handover topics to understand and explain:

1. Room coordinates, session coordinates and why transforms must be multiplied in the right order.
2. Why loading an ARWorldMap alone does not prove alignment, and why drawings hide on tracking loss.
3. Why imported project/room IDs change while coordinate IDs and room-relative poses remain unchanged; why ARWorldMap evidence is still needed before showing drawings. Physical-marker fallback has been removed from the current workflow.
4. Which data lives in private Storage versus Postgres, and how RLS blocks outsiders.
5. Local Debug mode versus required cloud persistence; what each automated test actually proves.
6. Why bounded visualization can reduce workload without improving ARKit's recognition algorithm or changing annotation positions.
7. Failure/lifecycle handling, remaining limitations and the physical acceptance procedure.
