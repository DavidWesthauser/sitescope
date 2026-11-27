-- sitescope schema: organizations, profiles, projects → houses → rooms, access grants, comments,
-- AR annotations and the private room-assets bucket. Specification: docs/DATABASE_API.md.
--
-- Access levels per scope: 4 admin · 3 responsible · 2 member · 1 external · 0 none (highest wins).
-- Responsibility and grants are inherited downwards (project → house → room).
-- Every check runs in the database (RLS, column privileges, triggers); clients only hold the publishable key.

-- ---------------------------------------------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------------------------------------------

create table public.organizations (
    id uuid primary key default gen_random_uuid(),
    name text not null check (char_length(btrim(name)) between 1 and 160),
    status text not null default 'active' check (status in ('active', 'inactive')),
    responsible_id uuid,
    created_by uuid,
    created_at timestamptz not null default now()
);

create table public.profiles (
    user_id uuid primary key references auth.users (id) on delete cascade,
    display_name text not null check (char_length(btrim(display_name)) between 1 and 80),
    organization_id uuid references public.organizations (id) on delete set null,
    is_active boolean not null default true,
    created_by uuid references public.profiles (user_id) on delete set null,
    created_at timestamptz not null default now()
);

alter table public.organizations
    add foreign key (responsible_id) references public.profiles (user_id) on delete set null,
    add foreign key (created_by) references public.profiles (user_id) on delete set null;

-- Global administrators. No client access at all; maintained in the dashboard or SQL editor.
create table public.admins (
    user_id uuid primary key references public.profiles (user_id) on delete cascade,
    created_at timestamptz not null default now()
);

create table public.projects (
    id uuid primary key default gen_random_uuid(),
    name text not null check (char_length(btrim(name)) between 1 and 120),
    responsible_id uuid not null references public.profiles (user_id),
    created_by uuid references public.profiles (user_id) on delete set null,
    created_by_org uuid references public.organizations (id) on delete set null,
    created_at timestamptz not null default now()
);

create table public.houses (
    id uuid primary key default gen_random_uuid(),
    project_id uuid not null references public.projects (id) on delete cascade,
    name text not null check (char_length(btrim(name)) between 1 and 120),
    responsible_id uuid not null references public.profiles (user_id),
    created_by uuid references public.profiles (user_id) on delete set null,
    created_by_org uuid references public.organizations (id) on delete set null,
    created_at timestamptz not null default now(),
    -- Target of composite foreign keys, so a child row cannot name a house of another project.
    unique (id, project_id)
);

create table public.rooms (
    id uuid primary key default gen_random_uuid(),
    house_id uuid not null,
    project_id uuid not null,
    name text not null check (char_length(btrim(name)) between 1 and 120),
    height numeric(6, 2) check (height > 0),
    length numeric(6, 2) check (length > 0),
    width numeric(6, 2) check (width > 0),
    area numeric generated always as (length * width) stored,
    status text not null default 'planned' check (status in ('planned', 'in_progress', 'built')),
    responsible_id uuid not null references public.profiles (user_id),
    created_by uuid references public.profiles (user_id) on delete set null,
    created_by_org uuid references public.organizations (id) on delete set null,
    created_at timestamptz not null default now(),
    -- AR data, mirrors `Room` in sitescope/Core/Models.swift. Fixed once a map is published (trigger below).
    spatial_version integer not null default 1 check (spatial_version = 1),
    coordinate_id uuid not null default gen_random_uuid(),
    map_path text check (map_path is null or char_length(map_path) <= 512),
    scan_guide_jpeg text check (scan_guide_jpeg is null or char_length(scan_guide_jpeg) <= 87384),
    marker jsonb,
    reference_points jsonb not null default '[]' check (jsonb_typeof(reference_points) = 'array'),
    reference_notes text not null default '' check (char_length(reference_notes) <= 2000),
    surfaces jsonb check (surfaces is null or (jsonb_typeof(surfaces) = 'array' and jsonb_array_length(surfaces) <= 128)),
    foreign key (house_id, project_id) references public.houses (id, project_id) on delete cascade,
    unique (id, house_id, project_id)
);

create table public.access_grants (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles (user_id) on delete cascade,
    role text not null check (role in ('member', 'external')),
    project_id uuid not null references public.projects (id) on delete cascade,
    house_id uuid,
    room_id uuid,
    created_by uuid references public.profiles (user_id) on delete set null,
    created_at timestamptz not null default now(),
    check (room_id is null or house_id is not null),
    foreign key (house_id, project_id) references public.houses (id, project_id) on delete cascade,
    foreign key (room_id, house_id, project_id) references public.rooms (id, house_id, project_id) on delete cascade,
    -- One grant per user and scope.
    unique nulls not distinct (user_id, project_id, house_id, room_id)
);

create table public.comments (
    id uuid primary key default gen_random_uuid(),
    author_id uuid references public.profiles (user_id) on delete set null,
    project_id uuid not null references public.projects (id) on delete cascade,
    house_id uuid,
    room_id uuid,
    parent_id uuid references public.comments (id) on delete cascade,
    body text check (body is null or char_length(btrim(body)) between 1 and 2000),
    image_path text check (image_path is null or char_length(image_path) <= 512),
    audio_path text check (audio_path is null or char_length(audio_path) <= 512),
    is_hidden boolean not null default false,
    hidden_by uuid references public.profiles (user_id) on delete set null,
    hidden_at timestamptz,
    created_at timestamptz not null default now(),
    check (room_id is null or house_id is not null),
    check (body is not null or image_path is not null or audio_path is not null),
    foreign key (house_id, project_id) references public.houses (id, project_id) on delete cascade,
    foreign key (room_id, house_id, project_id) references public.rooms (id, house_id, project_id) on delete cascade
);

-- Spatial instructions and tasks in a room; mirrors `Annotation` in sitescope/Core/Models.swift.
create table public.annotations (
    id uuid primary key default gen_random_uuid(),
    room_id uuid not null references public.rooms (id) on delete cascade,
    coordinate_id uuid not null,
    kind text not null check (kind in ('marker', 'text', 'area', 'line', 'arrow', 'image')),
    pose jsonb not null,
    points jsonb not null default '[]' check (jsonb_typeof(points) = 'array' and jsonb_array_length(points) <= 128),
    strokes jsonb check (strokes is null or (jsonb_typeof(strokes) = 'array' and jsonb_array_length(strokes) <= 32)),
    image jsonb,
    title text not null check (char_length(btrim(title)) between 1 and 240),
    detail text not null default '' check (char_length(detail) <= 4000),
    status text not null default 'todo' check (status in ('todo', 'in_progress', 'completed')),
    priority integer not null default 1 check (priority between 0 and 2),
    created_by uuid references public.profiles (user_id) on delete set null,
    created_at timestamptz not null default now()
);

create index on public.houses (project_id);
create index on public.rooms (project_id);
create index on public.rooms (house_id);
create index on public.access_grants (user_id);
create index on public.access_grants (project_id);
create index on public.comments (project_id, house_id, room_id);
create index on public.comments (parent_id);
create index on public.annotations (room_id);

-- ---------------------------------------------------------------------------------------------------------------
-- Access functions. Security definer so they can read rows the caller cannot; empty search_path against hijacking.
-- ---------------------------------------------------------------------------------------------------------------

-- The caller has an active profile in an active (or no) organization.
create function public.is_active_user() returns boolean
language sql stable security definer set search_path = '' as $$
    select exists (
        select 1
        from public.profiles p
        left join public.organizations o on o.id = p.organization_id
        where p.user_id = auth.uid() and p.is_active and (o.id is null or o.status = 'active')
    );
$$;

create function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
    select public.is_active_user() and exists (select 1 from public.admins a where a.user_id = auth.uid());
$$;

-- The caller's level (0–4) on a scope: project p, optionally house h, optionally room r.
-- Ids that do not belong together give 0, so a caller cannot borrow rights from a project they own
-- by pairing it with someone else's house or room.
create function public.scope_level(p uuid, h uuid default null, r uuid default null) returns integer
language plpgsql stable security definer set search_path = '' as $$
declare
    uid uuid := auth.uid();
    level integer := 0;
begin
    if uid is null or p is null or (r is not null and h is null) or not public.is_active_user() then
        return 0;
    end if;
    if h is not null and not exists (select 1 from public.houses where id = h and project_id = p) then
        return 0;
    end if;
    if r is not null and not exists (select 1 from public.rooms where id = r and house_id = h) then
        return 0;
    end if;
    if public.is_admin() then
        return 4;
    end if;
    if exists (select 1 from public.projects where id = p and responsible_id = uid)
        or (h is not null and exists (select 1 from public.houses where id = h and responsible_id = uid))
        or (r is not null and exists (select 1 from public.rooms where id = r and responsible_id = uid))
    then
        return 3;
    end if;
    select coalesce(max(case g.role when 'member' then 2 when 'external' then 1 end), 0) into level
    from public.access_grants g
    where g.user_id = uid and g.project_id = p
        and (
            (g.house_id is null and g.room_id is null)
            or (h is not null and g.house_id = h and g.room_id is null)
            or (r is not null and g.room_id = r)
        );
    return level;
end;
$$;

create function public.project_level(p uuid) returns integer
language sql stable security definer set search_path = '' as $$
    select public.scope_level(p, null, null);
$$;

-- Level on a room, looked up from its own project and house.
create function public.room_level(r uuid) returns integer
language sql stable security definer set search_path = '' as $$
    select coalesce((select public.scope_level(project_id, house_id, id) from public.rooms where id = r), 0);
$$;

-- A project is visible with any level in it, or with a grant or responsibility somewhere below it (navigation only).
create function public.can_see_project(p uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select public.project_level(p) >= 1
        or (public.is_active_user() and (
            exists (select 1 from public.access_grants where project_id = p and user_id = auth.uid())
            or exists (select 1 from public.houses where project_id = p and responsible_id = auth.uid())
            or exists (select 1 from public.rooms where project_id = p and responsible_id = auth.uid())
        ));
$$;

create function public.can_see_house(p uuid, h uuid) returns boolean
language sql stable security definer set search_path = '' as $$
    select public.scope_level(p, h, null) >= 1
        or (public.is_active_user() and (
            exists (select 1 from public.access_grants where house_id = h and user_id = auth.uid())
            or exists (select 1 from public.rooms where house_id = h and responsible_id = auth.uid())
        ));
$$;

-- ---------------------------------------------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------------------------------------------

-- Creates the profile for every new account. display_name comes from sign-up metadata or the email prefix.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
    wanted text := btrim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));
begin
    if wanted = '' then
        wanted := btrim(split_part(coalesce(new.email, ''), '@', 1));
    end if;
    if wanted = '' then
        wanted := 'User';
    end if;
    insert into public.profiles (user_id, display_name) values (new.id, left(wanted, 80));
    return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

-- Sets created_by / created_by_org / created_at from the session, so clients cannot forge them.
create function public.stamp_creator() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
    new.created_by := auth.uid();
    new.created_at := now();
    if tg_table_name in ('projects', 'houses', 'rooms') then
        new.created_by_org := (select organization_id from public.profiles where user_id = auth.uid());
        new.responsible_id := coalesce(new.responsible_id, auth.uid());
    end if;
    return new;
end;
$$;

create trigger t1_stamp_creator before insert on public.organizations for each row execute function public.stamp_creator();
create trigger t1_stamp_creator before insert on public.projects for each row execute function public.stamp_creator();
create trigger t1_stamp_creator before insert on public.houses for each row execute function public.stamp_creator();
create trigger t1_stamp_creator before insert on public.rooms for each row execute function public.stamp_creator();
create trigger t1_stamp_creator before insert on public.access_grants for each row execute function public.stamp_creator();
create trigger t1_stamp_creator before insert on public.annotations for each row execute function public.stamp_creator();

-- Who may set or change `responsible_id`: project → admin only (a new project always belongs to its creator);
-- house → responsible of the project; room → responsible of the house.
create function public.check_responsible() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
    allowed boolean;
begin
    if tg_op = 'UPDATE' and new.responsible_id is not distinct from old.responsible_id then
        return new;
    end if;
    if tg_op = 'INSERT' and new.responsible_id = auth.uid() then
        return new;
    end if;
    -- Separate branches: a plpgsql expression may only name columns of the table that fired the trigger.
    if tg_table_name = 'projects' then
        allowed := public.is_admin();
    elsif tg_table_name = 'houses' then
        allowed := public.scope_level(new.project_id) >= 3;
    else
        allowed := public.scope_level(new.project_id, new.house_id) >= 3;
    end if;
    if auth.uid() is not null and not allowed then
        raise exception 'You may not change who is responsible here.' using errcode = '42501';
    end if;
    return new;
end;
$$;

create trigger t2_check_responsible before insert or update on public.projects for each row execute function public.check_responsible();
create trigger t2_check_responsible before insert or update on public.houses for each row execute function public.check_responsible();
create trigger t2_check_responsible before insert or update on public.rooms for each row execute function public.check_responsible();

-- A published room map is immutable: notes are anchored to its coordinate system. A changed room becomes a new room.
create function public.preserve_room_map() returns trigger
language plpgsql set search_path = '' as $$
begin
    if old.map_path is not null and (
        new.map_path, new.scan_guide_jpeg, new.marker, new.reference_points, new.reference_notes, new.surfaces,
        new.spatial_version, new.coordinate_id
    ) is distinct from (
        old.map_path, old.scan_guide_jpeg, old.marker, old.reference_points, old.reference_notes, old.surfaces,
        old.spatial_version, old.coordinate_id
    ) then
        raise exception 'Published room maps cannot be replaced. Create a new room for remapping.';
    end if;
    return new;
end;
$$;

create trigger preserve_room_map before update on public.rooms for each row execute function public.preserve_room_map();

-- Notes need a mapped room and must use its coordinate system.
create function public.require_mapped_room() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
    if not exists (
        select 1 from public.rooms where id = new.room_id and coordinate_id = new.coordinate_id and map_path is not null
    ) then
        raise exception 'Map the room before placing instructions.';
    end if;
    return new;
end;
$$;

create trigger require_mapped_room before insert on public.annotations for each row execute function public.require_mapped_room();

-- Comments: the author comes from the session; a reply has the same scope as its parent.
create function public.prepare_comment() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
    new.author_id := auth.uid();
    new.created_at := now();
    new.is_hidden := false;
    new.hidden_by := null;
    new.hidden_at := null;
    if new.parent_id is not null and not exists (
        select 1 from public.comments c
        where c.id = new.parent_id
            and c.project_id = new.project_id
            and c.house_id is not distinct from new.house_id
            and c.room_id is not distinct from new.room_id
    ) then
        raise exception 'A reply must have the same scope as its parent comment.';
    end if;
    return new;
end;
$$;

create trigger prepare_comment before insert on public.comments for each row execute function public.prepare_comment();

-- ---------------------------------------------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------------------------------------------

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.admins enable row level security;
alter table public.projects enable row level security;
alter table public.houses enable row level security;
alter table public.rooms enable row level security;
alter table public.access_grants enable row level security;
alter table public.comments enable row level security;
alter table public.annotations enable row level security;

create policy "read own organization" on public.organizations for select to authenticated
    using (public.is_admin() or id = (select organization_id from public.profiles where user_id = auth.uid()));
create policy "admins create organizations" on public.organizations for insert to authenticated
    with check (public.is_admin());
create policy "admins edit organizations" on public.organizations for update to authenticated
    using (public.is_admin()) with check (public.is_admin());

create policy "signed-in users read profiles" on public.profiles for select to authenticated using (true);
create policy "edit own profile" on public.profiles for update to authenticated
    using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "admins edit profiles" on public.profiles for update to authenticated
    using (public.is_admin()) with check (public.is_admin());

create policy "see project" on public.projects for select to authenticated using (public.can_see_project(id));
create policy "create project" on public.projects for insert to authenticated with check (public.is_active_user());
create policy "edit project" on public.projects for update to authenticated
    using (public.project_level(id) >= 3) with check (public.project_level(id) >= 3);
create policy "delete project" on public.projects for delete to authenticated using (public.project_level(id) >= 3);

create policy "see house" on public.houses for select to authenticated using (public.can_see_house(project_id, id));
create policy "create house" on public.houses for insert to authenticated
    with check (public.project_level(project_id) >= 3);
create policy "edit house" on public.houses for update to authenticated
    using (public.scope_level(project_id, id) >= 3) with check (public.scope_level(project_id, id) >= 3);
create policy "delete house" on public.houses for delete to authenticated
    using (public.scope_level(project_id, id) >= 3);

create policy "see room" on public.rooms for select to authenticated
    using (public.scope_level(project_id, house_id, id) >= 1);
create policy "create room" on public.rooms for insert to authenticated
    with check (public.scope_level(project_id, house_id) >= 2);
create policy "edit room" on public.rooms for update to authenticated
    using (public.scope_level(project_id, house_id, id) >= 2)
    with check (public.scope_level(project_id, house_id, id) >= 2);
create policy "delete room" on public.rooms for delete to authenticated
    using (public.scope_level(project_id, house_id, id) >= 3);

-- Grants are written only through grant_access / revoke_access.
create policy "see grants" on public.access_grants for select to authenticated
    using (user_id = auth.uid() or public.scope_level(project_id, house_id, room_id) >= 3);

create policy "read comments" on public.comments for select to authenticated
    using (public.scope_level(project_id, house_id, room_id) >= 1 and (not is_hidden or public.is_admin()));
create policy "write comments" on public.comments for insert to authenticated
    with check (public.scope_level(project_id, house_id, room_id) >= 1);
create policy "delete comments" on public.comments for delete to authenticated
    using (
        (author_id = auth.uid() and public.scope_level(project_id, house_id, room_id) >= 1)
        or public.scope_level(project_id, house_id, room_id) >= 3
    );

-- Notes: everyone with access reads and updates status (set_task_status); members edit content.
create policy "read notes" on public.annotations for select to authenticated using (public.room_level(room_id) >= 1);
create policy "create notes" on public.annotations for insert to authenticated with check (public.room_level(room_id) >= 2);
create policy "edit notes" on public.annotations for update to authenticated
    using (public.room_level(room_id) >= 2) with check (public.room_level(room_id) >= 2);
create policy "delete notes" on public.annotations for delete to authenticated using (public.room_level(room_id) >= 2);

-- ---------------------------------------------------------------------------------------------------------------
-- Privileges. Supabase grants everything to anon/authenticated by default; replace that with column lists,
-- so ids, authors and timestamps are fixed after insert.
-- ---------------------------------------------------------------------------------------------------------------

revoke all on all tables in schema public from anon, authenticated;

grant select on public.organizations, public.profiles, public.projects, public.houses, public.rooms,
    public.access_grants, public.comments, public.annotations to authenticated;

grant insert (id, name, status, responsible_id) on public.organizations to authenticated;
grant update (name, status, responsible_id) on public.organizations to authenticated;

grant update (display_name) on public.profiles to authenticated;

grant insert (id, name, responsible_id) on public.projects to authenticated;
grant update (name, responsible_id) on public.projects to authenticated;
grant delete on public.projects to authenticated;

grant insert (id, project_id, name, responsible_id) on public.houses to authenticated;
grant update (name, responsible_id) on public.houses to authenticated;
grant delete on public.houses to authenticated;

grant insert (
    id, house_id, project_id, name, height, length, width, status, responsible_id,
    spatial_version, coordinate_id, map_path, scan_guide_jpeg, marker, reference_points, reference_notes, surfaces
) on public.rooms to authenticated;
grant update (
    name, height, length, width, status, responsible_id,
    spatial_version, map_path, scan_guide_jpeg, marker, reference_points, reference_notes, surfaces
) on public.rooms to authenticated;
grant delete on public.rooms to authenticated;

grant insert (id, project_id, house_id, room_id, parent_id, body, image_path, audio_path) on public.comments
    to authenticated;
grant delete on public.comments to authenticated;

grant insert (id, room_id, coordinate_id, kind, pose, points, strokes, image, title, detail, status, priority)
    on public.annotations to authenticated;
grant update (kind, pose, points, strokes, image, title, detail, status, priority) on public.annotations
    to authenticated;
grant delete on public.annotations to authenticated;

-- Admins only for profile flags; the column grant above covers display_name for everyone.
grant update (organization_id, is_active) on public.profiles to authenticated;

-- Only admins may change organization or active flag, even on their own profile.
create function public.protect_profile_flags() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
    if (new.organization_id, new.is_active) is distinct from (old.organization_id, old.is_active)
        and auth.uid() is not null and not public.is_admin()
    then
        raise exception 'Only an administrator can change organization or active state.' using errcode = '42501';
    end if;
    return new;
end;
$$;

create trigger protect_profile_flags before update on public.profiles
for each row execute function public.protect_profile_flags();

-- ---------------------------------------------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------------------------------------------

-- Adds or changes a grant for a registered, active user. Needs level 3 on the scope.
create function public.grant_access(
    target_email text, new_role text, p uuid, h uuid default null, r uuid default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
    target uuid;
    grant_id uuid;
begin
    if new_role not in ('member', 'external') then
        raise exception 'Role must be member or external.' using errcode = '22023';
    end if;
    if public.scope_level(p, h, r) < 3 then
        raise exception 'Only the person responsible can share this.' using errcode = '42501';
    end if;
    select u.id into target
    from auth.users u join public.profiles pr on pr.user_id = u.id
    where lower(u.email) = lower(btrim(target_email)) and pr.is_active;
    if target is null then
        raise exception 'No active account uses this email.';
    end if;
    insert into public.access_grants (user_id, role, project_id, house_id, room_id)
    values (target, new_role, p, h, r)
    on conflict (user_id, project_id, house_id, room_id) do update set role = excluded.role
    returning id into grant_id;
    return grant_id;
end;
$$;

create function public.revoke_access(grant_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
    delete from public.access_grants g
    where g.id = grant_id and public.scope_level(g.project_id, g.house_id, g.room_id) >= 3;
    if not found then
        raise exception 'Access was not found or you may not revoke it.' using errcode = '42501';
    end if;
end;
$$;

-- Anyone who can see the room may update a task's status; content stays with members.
create function public.set_task_status(task uuid, new_status text) returns void
language plpgsql security definer set search_path = '' as $$
begin
    update public.annotations a set status = new_status
    where a.id = task and public.room_level(a.room_id) >= 1;
    if not found then
        raise exception 'Task not found or you have no access.' using errcode = '42501';
    end if;
end;
$$;

create function public.set_comment_hidden(comment uuid, hidden boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
    if not public.is_admin() then
        raise exception 'Only an administrator can hide comments.' using errcode = '42501';
    end if;
    update public.comments
    set is_hidden = hidden,
        hidden_by = case when hidden then auth.uid() end,
        hidden_at = case when hidden then now() end
    where id = comment;
    if not found then
        raise exception 'Comment not found.';
    end if;
end;
$$;

-- Functions are callable by signed-in users only; trigger functions by nobody directly.
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
    public.is_active_user(), public.is_admin(), public.scope_level(uuid, uuid, uuid), public.project_level(uuid),
    public.room_level(uuid), public.can_see_project(uuid), public.can_see_house(uuid, uuid),
    public.grant_access(text, text, uuid, uuid, uuid), public.revoke_access(uuid),
    public.set_task_status(uuid, text), public.set_comment_hidden(uuid, boolean)
    to authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- Storage: private bucket, paths `<project_id>/<room_id>/<file>`. Rights follow the room level.
-- ---------------------------------------------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit)
values ('room-assets', 'room-assets', false, 104857600)
on conflict (id) do nothing;

-- Level on the room named by a storage path; 0 for malformed paths or a room outside the named project.
create function public.asset_level(object_name text) returns integer
language plpgsql stable security definer set search_path = '' as $$
declare
    parts text[] := string_to_array(object_name, '/');
    uuid_pattern text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
begin
    if coalesce(array_length(parts, 1), 0) <> 3 or parts[1] !~* uuid_pattern or parts[2] !~* uuid_pattern or parts[3] = '' then
        return 0;
    end if;
    if not exists (select 1 from public.rooms where id = parts[2]::uuid and project_id = parts[1]::uuid) then
        return 0;
    end if;
    return public.room_level(parts[2]::uuid);
end;
$$;

revoke execute on function public.asset_level(text) from public, anon;
grant execute on function public.asset_level(text) to authenticated;

create policy "read room assets" on storage.objects for select to authenticated
    using (bucket_id = 'room-assets' and public.asset_level(name) >= 1);
create policy "upload room assets" on storage.objects for insert to authenticated
    with check (bucket_id = 'room-assets' and public.asset_level(name) >= 2);
create policy "delete room assets" on storage.objects for delete to authenticated
    using (bucket_id = 'room-assets' and public.asset_level(name) >= 3);
