# T-026b Export file name and share button teardown

- Status: todo · Priority: P2 · Estimate: 1.5 h · Owner: — · Depends on: —
- Requirements: G1, G5

## Goal

Name the exported file after the project, and make `ProjectFileShareButton` clean up even when its presenter is torn down without calling the finish callback.

## Tasks

- [ ] Name the export file after the project (sanitized) instead of `sitescope-<id>.sitescope`. The extension stays `.sitescope`.
- [ ] Unit-test the name sanitizer: empty name, slashes and colons, emoji, very long names.
- [ ] `ProjectFileShareButton` resets `shareItem` and `exportedFile` only in the presenter's finish callback. If the presenter is torn down without calling it, the button stays disabled and the temp export is not deleted. Reset state and delete the temp export on teardown too.

## Acceptance criteria

- [ ] Share sheet shows the project name as the file name (screenshot).
- [ ] Leaving the screen with the share sheet still open leaves the button enabled and no temp export file remains.
- [ ] Sanitizer unit tests pass.
