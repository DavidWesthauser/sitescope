# sitescope

Drawings that stay where the work is. You scan a room once with the iPhone camera, then draw lines, mark areas and pin photos onto walls and surfaces, and describe the work in the room's description. Later a colleague opens the same room: when the phone recognizes it, every drawing appears in place.

Native iOS 17+ (SwiftUI, ARKit, RealityKit), LiDAR not required, no third-party iOS dependencies. Backend: Supabase. DHBW TIF24A course project by Leonard Aichele and David Westhauser. Repository: <https://github.com/DavidWesthauser/sitescope>.

> **Current state:** sign-in required, then the app works offline and syncs in the background. Accounts, projects and houses sync with Supabase; rooms, scans and drawings stay on the phone until the database has T-029. See [docs/STATUS.md](docs/STATUS.md).

## Documentation

| | |
|---|---|
| [docs/README.md](docs/README.md) | Docs index |
| [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) | Requirements and grading |
| [docs/STATUS.md](docs/STATUS.md) | What is done and what is missing |
| [docs/tickets/](docs/tickets/) | Work items |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Code structure and spatial contract |
| [docs/BACKEND_SETUP.md](docs/BACKEND_SETUP.md) | Supabase setup and app configuration |
| [docs/DEVICE_TESTING.md](docs/DEVICE_TESTING.md) | Manual iPhone tests |
| [docs/AI_USAGE.md](docs/AI_USAGE.md) | AI usage and reflection |

## Install on an iPhone

1. In Xcode, sign in under **Settings → Accounts**. Connect the iPhone and trust the Mac. Turn on **Developer Mode** on the phone.
2. Open `sitescope.xcodeproj`. In **Signing & Capabilities**, choose your team and a unique bundle ID.
3. Add `Secrets.xcconfig` with the Supabase URL and publishable key (see BACKEND_SETUP.md). Then run on the phone and sign in.

## Quick usage

1. Register or sign in. The app is only usable with an account.
2. Create a project with **+** (you become responsible for it), add houses, then rooms.
3. In a room, tap **Scan Room**, walk slowly and look in all four directions from three spots. Then **Draw in AR**: lines, areas or photos. Write what to do in the room's **Description**.
4. Under **… → People**, give people a role on a project, house or room: *member* (adds rooms, scans, draws) or *external* (views). Access on a project or house covers everything inside it.
5. Everything works offline. The bottom bar shows when changes wait or couldn't upload; swipe a row to the right to retry.
6. Administrators manage people and organizations under **Settings → Administration**.

## Tests

```sh
swift test                                   # core logic, portable
xcodebuild -project sitescope.xcodeproj -scheme sitescope \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

The database design has no pgTAP tests in the repository yet (T-029).

(Ticket T-015 extends the tests.)

## AI usage

See [docs/AI_USAGE.md](docs/AI_USAGE.md). Each team member's personal reflection is still to be written (ticket H-006).
