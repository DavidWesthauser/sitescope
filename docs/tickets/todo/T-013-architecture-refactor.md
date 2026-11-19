# T-013 Architecture: split Store into repositories and view models

- Status: todo · Priority: P1 · Estimate: 10 h · Owner: — · Depends on: T-001 (do before or together with T-005/T-008)
- Requirements: G7, quality "Aufbau", "Clean Code"

## Goal

Split `sitescope/App/Store.swift`, which mixes local persistence, cloud calls, transfer import/export and UI error state behind `isLocalMode` checks, into repositories and per-screen view models. Views stop calling the backend directly (e.g. `rpc("share_project")` in `sitescope/Views/ManagementViews.swift`), and legacy marker/reference fields are removed.

## Sub-tickets

- [T-013a](T-013a-repositories.md) Repository protocols with Local and Remote implementations (3 h)
- [T-013b](T-013b-view-models.md) One `@Observable` view model per screen (3 h)
- [T-013c](T-013c-split-management-views.md) Split ManagementViews.swift, remove legacy code, layer diagram (2 h)
- [T-013d](T-013d-code-review-fixes.md) Code review fixes: save order, download limit, auth errors, constants, raycast helper (2 h)

## Acceptance criteria

- [ ] No view references `Backend` or `store.client()` (grep is empty).
- [ ] Existing tests pass; repositories and view models are unit-testable with fakes.
- [ ] All sub-tickets done, with their tests in the same PRs.
