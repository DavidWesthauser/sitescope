# T-008a Local cache of cloud data, cache-first reads

- Status: todo · Priority: P0 · Estimate: 3 h · Owner: — · Depends on: T-007
- Requirements: M2, G5

## Goal

Cloud data (projects, houses, rooms, notes) is cached per user on the phone. Screens read the cache first and refresh from the cloud when online, so they work without signal.

## Tasks

- [ ] Add a local cache of cloud data per user (reuse the local JSON/assets store).
- [ ] Read from cache first, then refresh from the cloud when online.
- [ ] Write fetched data to the cache so it survives relaunch.
- [ ] Unit test for cache-first reads with a mocked backend that is unreachable.

## Acceptance criteria

- [ ] Unit test: cached data is returned when the backend throws or is offline.
- [ ] Unit test: cache is per user (user B never sees user A's cache).
- [ ] Projects and rooms still show after relaunch in airplane mode.
