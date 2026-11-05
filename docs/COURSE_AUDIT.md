# DHBW mobile-app course audit

Audit basis: project description and grading rubric supplied by the user, last changed 23 October 2026. Team: two students (user reported). Lecturer approval of sitescope's specific MUST-HAVEs and iOS installation/testing arrangements has not been established. This is an evidence checklist, not a grade or a claim of complete course compliance.

| Requirement | Current evidence | Remaining acceptance |
|---|---|---|
| Installable native smartphone app | SwiftUI/ARKit/RealityKit, iOS 17+; earlier signed build installed and launched on iPhone 12 mini | Latest changes need physical acceptance; agree iOS testing with lecturer |
| Mobile-first UI/accessibility | Native navigation/forms, 44-point main controls, Dynamic Type layouts, accessibility labels, scan/task feedback | Physical VoiceOver/contrast/large-text and long-scan performance checks |
| Persistent cloud data | Supabase client, private assets, four migrations and setup instructions implemented | **Not met in current unconfigured local build.** Configure hosted Supabase and verify cross-device reads/writes |
| Registration/login | Auth UI, token refresh and Keychain implemented; network fixtures supplied | **Not demonstrated in current build.** Run registration, confirmation, login/relaunch/sign-out against hosted Auth, unless lecturer grants an exemption |
| Server-side access protection | Table/Storage RLS, restricted manager/worker RPCs, 31-assertion pgTAP suite | Apply migrations and execute policies; record manager/worker/outsider tests. Authored SQL is not proof of deployed protection |
| Meaningful native function | Camera permission and real ARWorldMaps/room-relative annotations; camera-only workflow | Physical placement/recovery acceptance including permission denial and interruptions |
| Errors/state/lifecycle | Validation, loading/error views, denied-camera/unsupported-AR handling, preserved local data on write failure, tracking-loss gates | Live network/auth failures and physical background/recovery checks. Unsaved new scans resume after interruption via ARKit relocalization; process termination loses unsaved drafts |
| Automated domain tests | Spatial math, localization, serialization, actual disk reopen/assets/status persistence, failure handling and rendering-budget fixtures | Reproduce current test run; extend configured cloud coverage |
| Three UI/e2e flows + error | Separate local project-rename/relaunch, room-rename/delete/relaunch, and scan entry/unsupported-AR workflows supplied | Successful execution is recorded in VERIFICATION.md. Auth/cloud tests explicitly skip when unavailable and do not count as passes |
| Architecture/maintainability | Views, Store, backend client, AR controller (split into lifecycle, drawing, persistence, rendering and surface files) and pure spatial/quality/rendering types separated; strict concurrency checking enabled with no warnings | Dense older code and physical behavior need team review. No claim that all quality criteria are closed |
| Reproducible backend/test data | README, config, migrations, local-only seed and policy tests | Hosted examiner accounts and real demonstration maps/images/tasks still needed; never use local fixture passwords in hosted production |
| Git remote/access | Public https://github.com/DavidWesthauser/sitescope; readable by lecturer without invitation | Regular individual contributions by both students must be genuine and visible |
| AI transparency/own contribution | README reflection and AI_USAGE.md describe actual tool use and corrected code | Each student must provide their own concrete review example and explain their code. AI-written summaries cannot establish personal understanding |
| Agreed scope/team process | Project-specific MUST/NICE list and 160–240-hour planning document | Two-person baseline, lecturer approval, mockup/course presentation, milestones and submission details remain team responsibilities |
| Secrets/build artifacts | Secrets.xcconfig ignored; public client config distinguished from secrets; reviewed reachable history has no common credential patterns | Bounded inspection is not an absolute guarantee. Never commit hosted passwords, service-role keys or signing files |

The quiz-specific categories/question types are an alternative example, not requirements to add to sitescope. sitescope needs its own lecturer-approved, concrete scope. A visible 3D mesh or RoomPlan-like animation does not prove persistent alignment.

## Grading implications

- MUST-HAVEs: 50 points. Missing functioning cloud persistence/auth/server protection and unverified core AR acceptance prevent an honest claim of full completion.
- NICE-TO-HAVEs: 20 points, only considered once MUST-HAVEs reach at least 40/50. Do not double-count agreed MUST-HAVEs as extras. No point estimate is asserted here.
- Tests: 10 points. Three named interactive local workflows and relevant failure assertions are separate from screenshots and unit tests. Mocked/disabled cloud flows must be disclosed.
- Quality: 20 points. Current polish, automated checks and review help; the reported long-scan crash still requires device diagnosis/acceptance.

## Practical next steps

1. Verify local `.sitescope` export/import on two phones and record room recovery, physical error and long-scan/crash diagnostics. This transfer is an independent editable copy, not cloud persistence or access protection.
2. Backend connection is deliberately deferred for the current user-requested file workflow. Before course submission, connect a development Supabase project, run migrations/policies and prove manager-A/worker-B persistence and access denial; use BACKEND_SETUP.md.
3. Record the actual two-person MUST-HAVEs and lecturer/iOS agreement.
4. Each student reviews, changes, tests and commits understandable work; complete the individual AI reflection and handover preparation honestly.
