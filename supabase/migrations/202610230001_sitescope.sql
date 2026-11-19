begin;
create table public.projects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id),
  name text not null check (length(trim(name)) between 1 and 120),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.memberships (
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(), primary key(project_id,user_id)
);
create table public.rooms (
  id uuid primary key default gen_random_uuid(), project_id uuid not null references public.projects(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 120),
  spatial_version integer not null default 1 check (spatial_version = 1),
  coordinate_id uuid not null default gen_random_uuid(), map_path text,
  marker jsonb,
  reference_points jsonb not null default '[]'::jsonb,
  reference_notes text not null default '',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(id,coordinate_id),
  check (jsonb_typeof(reference_points) = 'array'),
  check (map_path is null or (marker is not null and jsonb_array_length(reference_points) = 2 and length(trim(reference_notes)) > 0)),
  check (map_path is null or split_part(map_path,'/',1) = project_id::text),
  check (map_path is null or split_part(map_path,'/',2) = id::text),
  check (marker is null or (jsonb_typeof(marker) = 'object' and marker ?& array['id','image_path','width','height','room_from_marker'])),
  check (marker is null or (marker->>'width')::numeric between 0.05 and 2),
  check (marker is null or split_part(marker->>'image_path','/',1) = project_id::text),
  check (marker is null or split_part(marker->>'image_path','/',2) = id::text)
);
create table public.annotations (
  id uuid primary key default gen_random_uuid(), room_id uuid not null, coordinate_id uuid not null,
  kind text not null check (kind in ('marker','text','area','line','arrow')),
  pose jsonb not null check (jsonb_typeof(pose) = 'array' and jsonb_array_length(pose) = 16),
  points jsonb not null default '[]'::jsonb check (jsonb_typeof(points) = 'array' and jsonb_array_length(points) <= 128),
  title text not null check (length(trim(title)) between 1 and 240), detail text not null default '',
  status text not null default 'todo' check (status in ('todo','in_progress','completed')),
  priority integer not null default 1 check (priority between 0 and 2),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  foreign key(room_id,coordinate_id) references public.rooms(id,coordinate_id) on delete cascade,
  check (kind <> 'area' or jsonb_array_length(points) >= 3),
  check (kind not in ('line','arrow') or jsonb_array_length(points) >= 2)
);
create index on public.projects(owner_id);
create index on public.memberships(user_id);
create index on public.rooms(project_id);
create index on public.annotations(room_id);

create function public.manages(project uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.projects p where p.id = project and p.owner_id = auth.uid());
$$;
create function public.can_access(project uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select public.manages(project) or exists(select 1 from public.memberships m where m.project_id = project and m.user_id = auth.uid());
$$;
create function public.room_access(room uuid, manager_only boolean default false) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.rooms r where r.id = room and (case when manager_only then public.manages(r.project_id) else public.can_access(r.project_id) end));
$$;
create function public.preserve_coordinates() returns trigger language plpgsql set search_path = '' as $$
begin
 if tg_table_name = 'projects' then
   if new.owner_id <> old.owner_id then raise exception 'Owner is immutable'; end if;
 end if;
 if tg_table_name = 'rooms' then
   if new.project_id <> old.project_id or new.coordinate_id <> old.coordinate_id or new.spatial_version <> old.spatial_version then raise exception 'Room coordinate system is immutable'; end if;
   if old.map_path is not null and (new.map_path is distinct from old.map_path or new.marker is distinct from old.marker or new.reference_points <> old.reference_points or new.reference_notes <> old.reference_notes) then raise exception 'Published spatial maps are immutable; create a new room for remapping'; end if;
 end if;
 if tg_table_name = 'annotations' then
   if new.room_id <> old.room_id or new.coordinate_id <> old.coordinate_id then raise exception 'Instruction cannot move between coordinate systems'; end if;
 end if;
 new.updated_at = now(); return new;
end;
$$;
create trigger projects_preserve before update on public.projects for each row execute function public.preserve_coordinates();
create trigger rooms_preserve before update on public.rooms for each row execute function public.preserve_coordinates();
create trigger annotations_preserve before update on public.annotations for each row execute function public.preserve_coordinates();
create function public.require_mapped_room() returns trigger language plpgsql set search_path = '' as $$
begin
 if not exists(select 1 from public.rooms r where r.id = new.room_id and r.map_path is not null) then raise exception 'Map this room before placing instructions'; end if;
 return new;
end;
$$;
create trigger annotation_mapped before insert on public.annotations for each row execute function public.require_mapped_room();

alter table public.projects enable row level security;
alter table public.memberships enable row level security;
alter table public.rooms enable row level security;
alter table public.annotations enable row level security;
create policy project_read on public.projects for select to authenticated using(public.can_access(id));
create policy project_create on public.projects for insert to authenticated with check(owner_id = auth.uid());
create policy project_update on public.projects for update to authenticated using(public.manages(id)) with check(public.manages(id));
create policy project_delete on public.projects for delete to authenticated using(public.manages(id));
create policy membership_read on public.memberships for select to authenticated using(public.manages(project_id) or user_id = auth.uid());
create policy room_read on public.rooms for select to authenticated using(public.can_access(project_id));
create policy room_create on public.rooms for insert to authenticated with check(public.manages(project_id));
create policy room_update on public.rooms for update to authenticated using(public.manages(project_id)) with check(public.manages(project_id));
create policy room_delete on public.rooms for delete to authenticated using(public.manages(project_id));
create policy annotation_read on public.annotations for select to authenticated using(public.room_access(room_id));
create policy annotation_create on public.annotations for insert to authenticated with check(public.room_access(room_id,true));
create policy annotation_update on public.annotations for update to authenticated using(public.room_access(room_id,true)) with check(public.room_access(room_id,true));
create policy annotation_delete on public.annotations for delete to authenticated using(public.room_access(room_id,true));

create function public.share_project(project uuid, worker_email text) returns void language plpgsql security definer set search_path = '' as $$
declare worker uuid;
begin
 if not public.manages(project) then raise exception 'Manager access required' using errcode = '42501'; end if;
 select id into worker from auth.users where lower(email) = lower(trim(worker_email)) and email_confirmed_at is not null;
 if worker is null then raise exception 'No confirmed registered account with this email'; end if;
 insert into public.memberships(project_id,user_id) values(project,worker) on conflict do nothing;
end;
$$;
create function public.revoke_worker(project uuid, worker uuid) returns void language plpgsql security definer set search_path = '' as $$
begin
 if not public.manages(project) then raise exception 'Manager access required' using errcode = '42501'; end if;
 delete from public.memberships where project_id = project and user_id = worker;
end;
$$;
create function public.set_task_status(task uuid, new_status text) returns void language plpgsql security definer set search_path = '' as $$
begin
 if new_status not in ('todo','in_progress','completed') or new_status is null then raise exception 'Invalid status'; end if;
 update public.annotations a set status = new_status where a.id = task and public.room_access(a.room_id);
 if not found then raise exception 'Task unavailable or access denied' using errcode = '42501'; end if;
end;
$$;

-- No anonymous table access or membership self-enrolment. Workers change status only via RPC.
revoke all on public.projects,public.memberships,public.rooms,public.annotations from anon,authenticated;
grant select,insert,update,delete on public.projects,public.rooms,public.annotations to authenticated;
grant select on public.memberships to authenticated;
revoke all on function public.manages(uuid),public.can_access(uuid),public.room_access(uuid,boolean),public.share_project(uuid,text),public.revoke_worker(uuid,uuid),public.set_task_status(uuid,text),public.preserve_coordinates(),public.require_mapped_room() from public,anon;
grant execute on function public.manages(uuid),public.can_access(uuid),public.room_access(uuid,boolean),public.share_project(uuid,text),public.revoke_worker(uuid,uuid),public.set_task_status(uuid,text) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('room-assets','room-assets',false,100000000,array['application/octet-stream','image/png']) on conflict(id) do nothing;
create function public.asset_project(path text) returns uuid language sql immutable set search_path = '' as $$
 select case when split_part(path,'/',1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then split_part(path,'/',1)::uuid else null end;
$$;
revoke all on function public.asset_project(text) from public,anon;
grant execute on function public.asset_project(text) to authenticated;
create policy room_asset_read on storage.objects for select to authenticated using(bucket_id = 'room-assets' and public.can_access(public.asset_project(name)));
create policy room_asset_insert on storage.objects for insert to authenticated with check(bucket_id = 'room-assets' and public.manages(public.asset_project(name)));
-- Never permit overwrite: maps and marker image files are immutable, unique upload objects.
create policy room_asset_delete on storage.objects for delete to authenticated using(bucket_id = 'room-assets' and public.manages(public.asset_project(name)));
commit;
