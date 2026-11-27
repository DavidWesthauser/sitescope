# Docs index

Start here. This folder is the single source of truth for the sitescope course project (DHBW TIF24A, *Entwicklung mobiler Apps*, team: Leonard Aichele, David Westhauser). It is written so a person or an AI agent can pick up work without reading the whole codebase.

| File | What it holds | Update when |
|---|---|---|
| [REQUIREMENTS.md](REQUIREMENTS.md) | Everything we must deliver: our agreed MUST/NICE list, the course's general MUST-HAVEs, process rules and the grading scheme, in one place | The lecturer agrees a scope change |
| [STATUS.md](STATUS.md) | Where the project stands right now: requirement-by-requirement gaps, known issues, last verified test run | A ticket is finished or a test/device run is recorded |
| [tickets/](tickets/) | One file per ticket with description, tasks and acceptance criteria, in `todo/` or `done/` | Work is planned, started or finished |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Code layout, data flow, spatial/coordinate contract, storage and transfer format | Structure or a core contract changes |
| [CONVENTIONS.md](CONVENTIONS.md) | Code style, comments, naming, layering; formatter/linter commands; ticket rules | A convention is agreed or a lint rule changes |
| [BACKEND_SETUP.md](BACKEND_SETUP.md) | Reproducible Supabase setup, migrations, seed data, test accounts | Migrations, seed or config change |
| [DATABASE_API.md](DATABASE_API.md) | Database model, permission levels and how to read/write it through the Supabase API | The schema, permissions or API usage change |
| [DEVICE_TESTING.md](DEVICE_TESTING.md) | Manual acceptance checklist for real iPhones (AR cannot be tested in the simulator) | A new AR/device feature lands |
| [AI_USAGE.md](AI_USAGE.md) | AI tool use, concrete reviewed/corrected examples, handover topics | Any notable AI correction; before submission |
| [decisions/](decisions/) | Architecture decision records (why, not how) | A significant design choice is made |

## Rules for keeping docs current

1. **Tickets drive work.** Before coding, find the ticket or extend one. When done, set `Status: done`, move it to `done/` and update the order in STATUS.md.
2. **STATUS.md reflects reality.** After finishing a ticket, update the matching row in STATUS.md. Never mark something done that wasn't run or tested; say "implemented, unverified" instead.
3. **Requirements are fixed.** Do not edit the agreed MUST-HAVEs in REQUIREMENTS.md without lecturer agreement. NICE-TO-HAVEs may be added.
4. **Keep files short.** Prefer a table row or bullet over a paragraph. Remove outdated text instead of appending "update" sections; git keeps the history.
5. **Names and paths:** everything is named **sitescope**: app, repository, source folders (`sitescope/`, `sitescopeTests/`, …), Xcode project and scheme, package module `sitescopeCore`. The mockups still say SiteAR, the earlier working name.
6. Dates are absolute (YYYY-MM-DD).
