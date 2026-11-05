-- Optional scene photograph for human orientation, not a visual localization target.
begin;
alter table public.rooms add column if not exists scan_guide_jpeg text;
alter table public.rooms add constraint rooms_scan_guide_length check (
 scan_guide_jpeg is null or length(scan_guide_jpeg) <= 87384
);
-- Preserve all coordinate/owner/instruction protections from migration 002.
create or replace function public.preserve_coordinates() returns trigger language plpgsql set search_path = '' as $$
begin
 if tg_table_name = 'projects' then
   if new.owner_id <> old.owner_id then raise exception 'Owner is immutable'; end if;
 end if;
 if tg_table_name = 'rooms' then
   if new.project_id <> old.project_id or new.coordinate_id <> old.coordinate_id or new.spatial_version <> old.spatial_version then raise exception 'Room coordinate system is immutable'; end if;
   if old.map_path is not null and (new.map_path is distinct from old.map_path or new.scan_guide_jpeg is distinct from old.scan_guide_jpeg or new.marker is distinct from old.marker or new.reference_points <> old.reference_points or new.reference_notes <> old.reference_notes or new.surfaces is distinct from old.surfaces) then raise exception 'Published spatial maps are immutable; create a new room for remapping'; end if;
 end if;
 if tg_table_name = 'annotations' then
   if new.room_id <> old.room_id or new.coordinate_id <> old.coordinate_id then raise exception 'Instruction cannot move between coordinate systems'; end if;
 end if;
 new.updated_at=now(); return new;
end;
$$;
commit;
