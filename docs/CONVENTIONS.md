# Code conventions

Rules every change follows. `swift format` checks the layout automatically; the rest is checked in review. Grading values readability, consistent style and framework best practices (REQUIREMENTS.md §6).

## Formatting (automatic)

- Tool: `swift format` (bundled with Xcode 16+), configured in `.swift-format`: 4-space indent, 120-character lines, no semicolons, one statement and one variable declaration per line.
- Format: `swift format --in-place --recursive sitescope sitescopeTests sitescopeAppTests sitescopeUITests Package.swift`
- Lint: `swift format lint --strict --recursive sitescope sitescopeTests sitescopeAppTests sitescopeUITests Package.swift` must report nothing before a commit.
- Disabled rules and why: `AlwaysUseLowerCamelCase` (model fields such as `owner_id` mirror Supabase columns and JSON keys), `UseSynthesizedInitializer` (public memberwise inits are API of the `sitescopeCore` package).

## Language

- Code, identifiers, comments, commit messages and docs are in **English**. User-facing strings are English for now; German comes through a String Catalog (T-021), never hard-coded mixed languages.

## Comments

- Comment *why*, not *what*. Non-trivial parts get a `///` doc comment: spatial math, coordinate transforms, concurrency hand-offs, file formats, security-relevant checks.
- No commented-out code, no `TODO` without a ticket ID (`// TODO(T-008): …`).

## Naming

- Types `UpperCamelCase`; functions, properties and enum cases `lowerCamelCase`. Exception: persisted model fields that match database/JSON keys.
- Names say what something is (`sessionFromRoom`, not `t2`). Booleans read as statements (`isLocalMode`, `canEdit`).

## Structure

- Layers: Views (SwiftUI, no networking or file I/O) → view models / `Store` → repositories and services (`Backend`, local storage) → pure `Core` types. Views never call `Backend` directly (T-027).
- Pure logic lives in `sitescope/Core/` and has unit tests. No `ARKit`/`UIKit` imports there.
- One screen or one clear responsibility per file; split files that grow past roughly 300 lines.
- No duplicated logic: extract a shared helper instead of copying.

## Swift and SwiftUI practice

- Swift concurrency (`async/await`, `@MainActor` for UI state); `SWIFT_STRICT_CONCURRENCY = complete` with zero warnings. Any `@unchecked Sendable` gets a comment explaining why it is safe.
- No force unwrap (`!`) or `try!` in app code unless a comment explains why it cannot fail. Tests may use them.
- Errors reach the user as readable messages (`AppError.message`); never swallow errors silently.
- Prefer `NavigationStack`, system colors and SF Symbols so dark mode and accessibility work by default. Interactive elements get accessibility labels.
- Colors: semantic system colors (`.primary`, `.secondary`, grouped backgrounds) or a named color from `sitescope/Resources/Assets.xcassets`; never a fixed RGB value. Only AR overlays on the camera image may use fixed white/black, and they force the dark scheme. Destructive buttons use `role: .destructive`. Brand colors, with WCAG contrast on rows (white / `#1C1C1E`):

  | Asset | Light | Dark | High contrast (light / dark) |
  |---|---|---|---|
  | `AccentColor` | `#00727F` 5.7:1 (5.1:1 on `#F2F2F7`) | `#4FD1DC` 9.3:1 | `#00585F` 8.2:1 / `#8BE4EA` 11.7:1 |
  | `Warning` | `#A84B00` 5.7:1 | `#FFA94D` 8.9:1 | `#8A3D00` 7.6:1 / `#FFC285` 10.8:1 |
- HIG layout: a destructive action sits alone in the last section of its screen, with a footer, and asks through a `confirmationDialog` attached to its button (title names the item, Cancel has `role: .cancel`). Explanations go in section footers, not in rows. Names are edited inline (`NameSection`), and titles show the real name.
- Secrets never in code or Git (`Secrets.xcconfig` is ignored).

## Tests

- New domain logic comes with unit tests; new user flows with a UI test (see T-015).
- Test names describe behavior: `testDeletingHouseRemovesItsRooms`.

## Tickets

Plain text files in `docs/tickets/todo/` and `docs/tickets/done/`. The folder and the `Status:` line must agree; the work order is in STATUS.md.

- One ticket per key feature; extend a ticket before adding one. No estimates, no sub-tickets.
- Each has a description, tasks and acceptance criteria. Copy an existing one to start a new one.
- `Who`: `agent` = AI alone · `together` = AI builds, a human checks · `human` (`H-XXX`) = only a human. Agents never tick or close human work.
- Finished: set `Status: done`, move the file to `done/`, update STATUS.md.
