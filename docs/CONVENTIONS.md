# Code conventions

Rules every change follows. `swift format` checks the layout automatically; the rest is checked in review. Grading values readability, consistent style and framework best practices (REQUIREMENTS.md §6).

## Formatting (automatic)

- Tool: `swift format` (bundled with Xcode 16+), configured in `.swift-format`: 4-space indent, 120-character lines, no semicolons, one statement and one variable declaration per line.
- Format: `swift format --in-place --recursive SiteAR SiteARTests SiteARAppTests SiteARUITests Package.swift`
- Lint: `swift format lint --strict --recursive SiteAR SiteARTests SiteARAppTests SiteARUITests Package.swift` must report nothing before a commit.
- Disabled rules and why: `AlwaysUseLowerCamelCase` (model fields such as `owner_id` mirror Supabase columns and JSON keys), `UseSynthesizedInitializer` (public memberwise inits are API of the `SiteARCore` package).

## Language

- Code, identifiers, comments, commit messages and docs are in **English**. User-facing strings are English for now; German comes through a String Catalog (T-021), never hard-coded mixed languages.

## Comments

- Comment *why*, not *what*. Non-trivial parts get a `///` doc comment: spatial math, coordinate transforms, concurrency hand-offs, file formats, security-relevant checks.
- No commented-out code, no `TODO` without a ticket ID (`// TODO(T-008): …`).

## Naming

- Types `UpperCamelCase`; functions, properties and enum cases `lowerCamelCase`. Exception: persisted model fields that match database/JSON keys.
- Names say what something is (`sessionFromRoom`, not `t2`). Booleans read as statements (`isLocalMode`, `canEdit`).

## Structure

- Layers: Views (SwiftUI, no networking or file I/O) → view models / `Store` → repositories and services (`Backend`, local storage) → pure `Core` types. Views never call `Backend` directly (T-013).
- Pure logic lives in `SiteAR/Core/` and has unit tests. No `ARKit`/`UIKit` imports there.
- One screen or one clear responsibility per file; split files that grow past roughly 300 lines.
- No duplicated logic: extract a shared helper instead of copying.

## Swift and SwiftUI practice

- Swift concurrency (`async/await`, `@MainActor` for UI state); `SWIFT_STRICT_CONCURRENCY = complete` with zero warnings. Any `@unchecked Sendable` gets a comment explaining why it is safe.
- No force unwrap (`!`) or `try!` in app code unless a comment explains why it cannot fail. Tests may use them.
- Errors reach the user as readable messages (`AppError.message`); never swallow errors silently.
- Prefer `NavigationStack`, system colors and SF Symbols so dark mode and accessibility work by default. Interactive elements get accessibility labels.
- Secrets never in code or Git (`Secrets.xcconfig` is ignored).

## Tests

- New domain logic comes with unit tests; new user flows with a UI test (see T-015).
- Test names describe behavior: `testDeletingHouseRemovesItsRooms`.
