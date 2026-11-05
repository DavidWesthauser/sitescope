-- Marker and reference points become optional. Existing room coordinate systems remain immutable.
begin;
alter table public.rooms add column if not exists surfaces jsonb;
do $$
declare item record;
begin
 for item in select conname from pg_constraint where conrelid='public.rooms'::regclass and contype='c'
   and pg_get_constraintdef(oid) like '%marker IS NOT NULL%'
   and pg_get_constraintdef(oid) like '%reference_notes%' loop
   execute format('alter table public.rooms drop constraint %I', item.conname);
 end loop;
end;
$$;
alter table public.rooms drop constraint if exists rooms_reference_pair;
alter table public.rooms add constraint rooms_reference_pair check (
  jsonb_array_length(reference_points)=0 or (jsonb_array_length(reference_points)=2 and length(trim(reference_notes))>0)
);
alter table public.rooms drop constraint if exists rooms_surface_geometry;
alter table public.rooms add constraint rooms_surface_geometry check (
  surfaces is null or (jsonb_typeof(surfaces)='array' and jsonb_array_length(surfaces)<=128)
);
create or replace function public.preserve_coordinates() returns trigger language plpgsql set search_path = '' as $$
begin
 if tg_table_name = 'projects' then
   if new.owner_id <> old.owner_id then raise exception 'Owner is immutable'; end if;
 end if;
 if tg_table_name = 'rooms' then
   if new.project_id <> old.project_id or new.coordinate_id <> old.coordinate_id or new.spatial_version <> old.spatial_version then raise exception 'Room coordinate system is immutable'; end if;
   if old.map_path is not null and (new.map_path is distinct from old.map_path or new.marker is distinct from old.marker or new.reference_points <> old.reference_points or new.reference_notes <> old.reference_notes or new.surfaces is distinct from old.surfaces) then raise exception 'Published spatial maps are immutable; create a new room for remapping'; end if;
 end if;
 if tg_table_name = 'annotations' then
   if new.room_id <> old.room_id or new.coordinate_id <> old.coordinate_id then raise exception 'Instruction cannot move between coordinate systems'; end if;
 end if;
 new.updated_at=now(); return new;
end;
$$;
commit;
