# sitescope

Room notes that stay where the work is. You scan a room once with the iPhone camera, then draw instructions, mark areas and pin images onto walls and surfaces. Later a colleague opens the same room: when the phone recognizes it, every note appears in place. Tasks also work without AR.

Native iOS 17+ (SwiftUI, ARKit, RealityKit), LiDAR not required, no third-party iOS dependencies. Backend: Supabase. DHBW TIF24A course project by Leonard Aichele and David Westhauser. Repository: <https://github.com/DavidWesthauser/sitescope>.

> **Current state:** a local-only prototype. The cloud backend is not connected yet. See [docs/STATUS.md](docs/STATUS.md).

## Documentation

| | |
|---|---|
| [docs/README.md](docs/README.md) | Docs index |
| [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) | Requirements and grading |
| [docs/STATUS.md](docs/STATUS.md) | What is done and what is missing |
| [docs/tickets/](docs/tickets/README.md) | Work items |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Code structure and spatial contract |
| [docs/BACKEND_SETUP.md](docs/BACKEND_SETUP.md) | Supabase setup and seed data |
| [docs/DEVICE_TESTING.md](docs/DEVICE_TESTING.md) | Manual iPhone tests |
| [docs/AI_USAGE.md](docs/AI_USAGE.md) | AI usage and reflection |

## Install on an iPhone

1. In Xcode, sign in under **Settings → Accounts**. Connect the iPhone and trust the Mac. Turn on **Developer Mode** on the phone.
2. Open `sitescope.xcodeproj`. In **Signing & Capabilities**, choose your team and a unique bundle ID.
3. Use a **Debug** build without `Secrets.xcconfig` for local-only mode, or set up the backend first (see BACKEND_SETUP.md). Then run on the phone.
4. Allow camera access when you open **Map room**. Keep Xcode's device screen mirroring off, because it blocks the camera.

## Quick usage

1. Create a project and a room, then tap **Map room**. Walk slowly and look in all four directions from three spots, pausing briefly at each view. Then tap **Finish**.
2. Aim at a surface and tap **Lock view**. Use **Draw**, **Area** or **Image**, add a title, description and priority, then **Save**.
3. Later, tap **Start AR walkthrough**. Match the saved view photo and look at familiar details. Your notes appear once the room is recognized.
4. To share without a backend, use **Export project** (AirDrop or Files) and **Import project** on the other phone.

## Tests

```sh
swift test                                   # core logic, portable
xcodebuild -project sitescope.xcodeproj -scheme sitescope \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
supabase start && supabase db reset && supabase test db   # RLS policies
```

(Ticket T-015 extends the tests.)

## AI usage

See [docs/AI_USAGE.md](docs/AI_USAGE.md). Each team member's personal reflection is still to be written (ticket T-019).
