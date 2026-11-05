begin;
alter table public.annotations add column if not exists strokes jsonb;
alter table public.annotations add column if not exists image jsonb;
alter table public.annotations drop constraint if exists annotations_kind_check;
alter table public.annotations add constraint annotations_kind_check check (kind in ('marker','text','area','line','arrow','image'));
alter table public.annotations add constraint annotations_stroke_groups check (
 strokes is null or (kind='line' and jsonb_typeof(strokes)='array' and jsonb_array_length(strokes) between 1 and 32)
);
alter table public.annotations add constraint annotations_image_metadata check (
 kind<>'image' or (image is not null and jsonb_typeof(image)='object' and image ?& array['path','width','height']
 and length(image->>'path')>0 and (image->>'width')::numeric>0.001 and (image->>'width')::numeric<=5
 and (image->>'height')::numeric>0.001 and (image->>'height')::numeric<=5)
);
-- Image files use the same private project/room Storage paths and access policies as world maps.
-- Optional columns preserve compatibility with previously saved single-path drawings.
commit;
