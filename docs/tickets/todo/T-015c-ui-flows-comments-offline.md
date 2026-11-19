# T-015c UI flows: comments and offline sync

- Status: todo · Priority: P0 · Estimate: 3 h · Owner: — · Depends on: T-015a; T-008, T-011
- Requirements: G6, M2, M8

## Goal

Add four UI tests for flows 4 and 5: adding comments (including rejection of empty comments) and an offline change that syncs after reconnecting. Connectivity is mocked.

## Tasks

- [ ] Comment flow: add a text comment to a room and see it in the list.
- [ ] Empty-comment flow: send an empty comment and see the validation message; nothing is added.
- [ ] Offline flow: launch with `-uiTestOffline`, change a note, and check the pending-changes indicator.
- [ ] Reconnect flow: switch the mock to online, trigger sync, and check the pending count reaches 0 and the change is on the mock server.

## Acceptance criteria

- [ ] The four UI tests (comment, empty comment, offline, reconnect) pass with no skips.
- [ ] The empty-comment test asserts the validation message.
- [ ] The offline test asserts the change is queued before reconnect and delivered after.
