# Database and API reference (draft schema)

How a client or AI agent reads and writes sitescope data through the Supabase API.

**Status (2026-11-26):** describes the **draft** schema (projects → houses → rooms, roles, comments; the draft SQL file `database_schema_draft.sql` is not in the repository yet). It is **not a migration yet** and not deployed; the app still uses `supabase/migrations/` (projects → rooms, owner/member), which is only a placeholder. Verified on plain PostgreSQL 16 with a stubbed `auth` schema only. Open product decisions are listed at the end. Storage policies for the new model are not written yet. Turning this into migrations belongs to T-005/T-006.

## Rules for agents

- Use only the **publishable key** (`sb_publishable_…`) plus a user's access token. Never use or ask for the secret/service-role key or the database password: they bypass RLS.
- Every permission is enforced by RLS in the database. Do not reimplement access checks in the client; read the server's answer.
- Never send `created_by`, `created_by_org`, `created_at`, `author_id`, `is_hidden`, `hidden_by`, `hidden_at` or `area`. Triggers overwrite them or the database rejects them.
- Never write `access_grants` or `admins` directly. Use the RPCs below.
- Users are deactivated (`profiles.is_active = false`), never deleted.

## Connection

| Item | Value |
|---|---|
| Base URL | `https://<project-ref>.supabase.co` (from `Secrets.xcconfig`, key `SUPABASE_URL`) |
| Every request | header `apikey: <publishable key>` |
| Signed-in requests | header `Authorization: Bearer <access_token>` |
| JSON bodies | header `Content-Type: application/json` |
| Tables | `/rest/v1/<table>` (PostgREST) |
| Functions | `POST /rest/v1/rpc/<function>` with named JSON arguments |
| Auth | `/auth/v1/...` |

Without a valid access token the role is `anon`, which has no rights on any table.

## Authentication

| Action | Request | Result |
|---|---|---|
| Sign up | `POST /auth/v1/signup` `{"email","password","data":{"display_name":"…"}}` | Session, or no session if email confirmation is on. A `profiles` row is created by trigger; `display_name` defaults to the email prefix |
| Sign in | `POST /auth/v1/token?grant_type=password` `{"email","password"}` | `{access_token, refresh_token, expires_at, user:{id,email}}`; wrong credentials → `400 invalid_credentials` |
| Refresh | `POST /auth/v1/token?grant_type=refresh_token` `{"refresh_token"}` | New session. Refresh tokens are single-use |
| Sign out | `POST /auth/v1/logout` with Bearer token | `204` |

The app implements these in `sitescope/Services/Backend.swift`. `auth.uid()` in SQL is the `sub` of the access token.

## Data model

```
organizations ─┬─ profiles (user_id = auth.users.id)
               │
projects ── houses ── rooms
   │          │        │
   └── access_grants (scope: project | house | room)
   └── comments      (scope: project | house | room, replies via parent_id)
admins (global, no client access)
```

All ids are `uuid`, all timestamps `timestamptz`. "auto" = set by the server.

**organizations**: `id`, `name` (1–160), `status` (`active`|`inactive`), `responsible_id` → profiles, `created_by` → profiles, `created_at` auto.

**profiles**: `user_id` (PK, = `auth.users.id`), `display_name` (1–80), `organization_id` → organizations, `is_active`, `created_by` → profiles, `created_at` auto. Created by trigger on sign-up; never inserted by clients. Email is not stored here.

**projects**: `id`, `name` (1–120), `responsible_id` (defaults to creator), `created_by` auto, `created_by_org` auto (creator's organization at creation time), `created_at` auto.

**houses**: `id`, `project_id`, `name` (1–120), `responsible_id` (defaults to creator; may be set to another user at creation), `created_by`/`created_by_org`/`created_at` auto.

**rooms**: `id`, `house_id`, `project_id` (must match the house's project), `name` (1–120), `height`/`length`/`width` (metres, `numeric(6,2)`, > 0, nullable), `area` (generated: `length * width`, read-only), `status` (`planned`|`in_progress`|`built`, default `planned`), `responsible_id` (defaults to creator), `created_by`/`created_by_org`/`created_at` auto. The existing AR columns (`coordinate_id`, `map_path`, `marker`, `surfaces`, …) are not merged yet.

**access_grants**: `id`, `user_id`, `role` (`member`|`external`), `project_id`, `house_id`, `room_id`, `created_by`, `created_at`. Scope: only `project_id` set → whole project; `house_id` set → whole house; `room_id` set → one room. Grants on a project or house also cover houses and rooms created later. One grant per user and scope.

**comments**: `id`, `author_id` auto, `project_id`, `house_id`, `room_id` (same scope rule; set the ids of the level the comment belongs to, e.g. all three for a room), `parent_id` (null = top-level; a reply must have the same scope as its parent), `body` (1–2000, optional), `image_path`, `audio_path` (at least one of body/image/audio), `is_hidden`/`hidden_by`/`hidden_at` (admin only, via RPC), `created_at` auto. No editing; deleting a comment deletes its replies.

Counts are not stored. Ask for them: `houses?select=*,rooms(count)`.

## Permissions

Levels per scope: **4 admin** (global, table `admins`) · **3 responsible** (`responsible_id` of the project, the house or the room, inherited downwards) · **2 member** · **1 external** (from `access_grants`, inherited downwards) · **0 none**. The highest applicable level wins. Inactive profiles and profiles of inactive organizations have level 0 everywhere.

| Action | Needed |
|---|---|
| See project / house | any level in it, or any grant or responsibility below it (read-only, for navigation) |
| See room | level ≥ 1 on the room |
| Create project | any active user (becomes responsible) |
| Edit / delete project | ≥ 3 on the project |
| Change project responsible | admin |
| Create house | ≥ 3 on the project |
| Edit / delete house | ≥ 3 on the house |
| Change house responsible | ≥ 3 on the project |
| Create room | ≥ 2 on the house |
| Edit room (name, dimensions, status) | ≥ 2 on the room |
| Delete room | ≥ 3 on the room |
| Change room responsible | ≥ 3 on the house |
| Grant / revoke access at a scope | ≥ 3 on that scope (roles `member`, `external` only) |
| See grants | own grants, or ≥ 3 on the grant's scope |
| Read / write comments | ≥ 1 on the comment's scope; hidden comments only for admins |
| Delete comment | own comment, or ≥ 3 on its scope |
| Hide comment | admin |
| Read profiles | every signed-in user (name and organization) |
| Edit own profile | `display_name` only |
| Change `organization_id` / `is_active` | admin |
| Read organizations | own organization; admins all |
| Create / edit organizations | admin |

## Reading data (PostgREST)

RLS filters silently: rows you may not see are simply missing, not an error.

```
GET /rest/v1/projects?select=*&order=created_at.desc
GET /rest/v1/houses?select=*,rooms(count)&project_id=eq.<id>
GET /rest/v1/rooms?select=*&house_id=eq.<id>&status=eq.in_progress
GET /rest/v1/comments?select=*,author:profiles!author_id(display_name)&room_id=eq.<id>&order=created_at.asc
GET /rest/v1/comments?select=*&project_id=eq.<id>&house_id=is.null     (project-level comments only)
GET /rest/v1/access_grants?select=*,user:profiles!user_id(display_name)&house_id=eq.<id>
```

`comments`, `access_grants` and `organizations` have more than one foreign key to `profiles`; name the column in the embed (`profiles!author_id(...)`).

## Writing data

```
POST   /rest/v1/projects   {"name":"Neubau Nord"}
POST   /rest/v1/houses     {"project_id":"…","name":"Haus A","responsible_id":"<optional user id>"}
POST   /rest/v1/rooms      {"project_id":"…","house_id":"…","name":"Küche","length":4,"width":3.5}
PATCH  /rest/v1/rooms?id=eq.<id>   {"status":"built"}
DELETE /rest/v1/rooms?id=eq.<id>
POST   /rest/v1/comments   {"project_id":"…","house_id":"…","room_id":"…","parent_id":null,"body":"Fliesen prüfen"}
```

Add header `Prefer: return=representation` to get the written row back. A `PATCH` or `DELETE` that the user may not perform affects 0 rows and still returns `200`/`204`: check that the returned array is not empty. An `INSERT` that violates a policy returns `403` with code `42501`.

Updatable columns: projects and houses `name`, `responsible_id`; rooms `name`, `height`, `length`, `width`, `status`, `responsible_id`; profiles `display_name`; organizations `name`, `status`, `responsible_id`. Everything else is fixed after insert.

## RPCs

| Function | Arguments | Effect / errors |
|---|---|---|
| `grant_access` | `target_email`, `new_role` (`member`\|`external`), `p` project id, `h` house id or null, `r` room id or null | Adds or changes a grant. Errors: not responsible (`42501`), no active account with this email, ids that do not belong together |
| `revoke_access` | `grant_id` | Deletes a grant. Error `42501` if not allowed or not found |
| `set_comment_hidden` | `comment`, `hidden` (bool) | Admin only |
| `scope_level` | `p`, `h`, `r` | The caller's level (0–4) on that scope; use it to show or hide UI controls |
| `project_level` | `p` | Same for a project |
| `is_admin`, `is_active_user` | none | Booleans for the caller |

Example: `POST /rest/v1/rpc/grant_access` `{"target_email":"anna@firma.de","new_role":"external","p":"…","h":"…","r":"…"}`.

## Errors

| Response | Meaning |
|---|---|
| `401` | Missing or expired token: refresh, then retry once |
| `403`, code `42501` | Not allowed (policy, column privilege or RPC check) |
| `400`, code `23514` | A check constraint failed (empty name, wrong status value, comment without content) |
| `409`, code `23503` / `23505` | Foreign key (ids do not belong together) / duplicate |
| `400`, code `P0001` | Raised by a trigger or RPC; `message` is readable text |

PostgREST error bodies are `{"code","message","details","hint"}`.

## Open decisions (H-002)

- Who may create projects (now: every active user).
- Who may change the project responsible (now: admins only).
- Whether every user may read all profiles (now: yes).
- Final room `status` values.
- Rights of an organization's `responsible_id` (now: none).
- Storage: paths must start with `<room_id>/` and policies must use `scope_level`; not written yet.
