-- Run with `supabase test db` after `supabase db reset`. All changes roll back.
begin;
set local search_path = public, extensions;
create extension if not exists pgtap with schema extensions;
select plan(31);
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select is((select count(*) from public.projects where id='20000000-0000-0000-0000-000000000001'),1::bigint,'Manager reads own project');
select lives_ok($$insert into public.rooms(id,project_id,name) values('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','Test room')$$,'Manager adds room');
select lives_ok($$update public.rooms set name='Renamed' where id='30000000-0000-0000-0000-000000000002'$$,'Manager renames room');
select is((select name from public.rooms where id='30000000-0000-0000-0000-000000000002'),'Renamed','Rename persists');
select lives_ok($$delete from public.rooms where id='30000000-0000-0000-0000-000000000002'$$,'Manager deletes room');
select is((select count(*) from public.rooms where id='30000000-0000-0000-0000-000000000002'),0::bigint,'Deleted room absent');
-- Synthetic spatial metadata is used ONLY to exercise database permissions, never downloaded by the app.
select lives_ok($$update public.rooms set map_path='20000000-0000-0000-0000-000000000001/30000000-0000-0000-0000-000000000001/test.worldmap',
 marker='{"id":"40000000-0000-0000-0000-000000000001","image_path":"20000000-0000-0000-0000-000000000001/30000000-0000-0000-0000-000000000001/test.png","width":0.2,"height":0.2,"room_from_marker":[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]}',
 reference_points='[{"x":0,"y":0,"z":0},{"x":1,"y":0,"z":0}]',reference_notes='Two corners'
 where id='30000000-0000-0000-0000-000000000001'$$,'Publish spatial metadata');
select throws_ok($$update public.rooms set map_path=null where id='30000000-0000-0000-0000-000000000001'$$,'P0001','Published spatial maps are immutable; create a new room for remapping','Cannot silently change coordinate map');
select lives_ok($$insert into public.annotations(id,room_id,coordinate_id,kind,pose,title)
 select '50000000-0000-0000-0000-000000000001',id,coordinate_id,'marker','[1,0,0,0,0,1,0,0,0,0,1,0,1,2,3,1]','Paint wall' from public.rooms where id='30000000-0000-0000-0000-000000000001'$$,'Manager creates task');
select lives_ok($$insert into storage.objects(bucket_id,name) values('room-assets','20000000-0000-0000-0000-000000000001/30000000-0000-0000-0000-000000000001/test.worldmap')$$,'Manager uploads private asset metadata');
select lives_ok($$insert into public.rooms(id,project_id,name,map_path,scan_guide_jpeg) values('30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','Map without mandatory references','20000000-0000-0000-0000-000000000001/30000000-0000-0000-0000-000000000003/test.worldmap','/9gR/9k=')$$,'Room map can be saved without a marker or manual dots');
select ok((select marker is null and reference_points='[]'::jsonb from public.rooms where id='30000000-0000-0000-0000-000000000003'),'Recovery references are optional');
select is((select scan_guide_jpeg from public.rooms where id='30000000-0000-0000-0000-000000000003'),'/9gR/9k=','Viewpoint guide persists with the room');
select throws_ok($$update public.rooms set scan_guide_jpeg=null where id='30000000-0000-0000-0000-000000000003'$$,'P0001','Published spatial maps are immutable; create a new room for remapping','Published viewpoint cannot silently change');
select lives_ok($$insert into public.annotations(id,room_id,coordinate_id,kind,pose,title,image)
 select '50000000-0000-0000-0000-000000000002',id,coordinate_id,'image','[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]','Bild','{"path":"20000000-0000-0000-0000-000000000001/30000000-0000-0000-0000-000000000001/image.png","width":0.4,"height":0.3}' from public.rooms where id='30000000-0000-0000-0000-000000000001'$$,'Manager saves image metadata');
select lives_ok($$insert into public.annotations(id,room_id,coordinate_id,kind,pose,points,title,strokes)
 select '50000000-0000-0000-0000-000000000003',id,coordinate_id,'line','[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]','[{"x":0,"y":0,"z":0},{"x":1,"y":0,"z":0}]','Zeichnung','[[{"x":0,"y":0,"z":0},{"x":1,"y":0,"z":0}],[{"x":3,"y":3,"z":0},{"x":4,"y":3,"z":0}]]' from public.rooms where id='30000000-0000-0000-0000-000000000001'$$,'Manager saves disconnected strokes');
select is((select jsonb_array_length(strokes) from public.annotations where id='50000000-0000-0000-0000-000000000003'),2,'Stroke boundaries persist');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
select is((select count(*) from public.annotations where id='50000000-0000-0000-0000-000000000001'),1::bigint,'Assigned worker reads task');
select is((select scan_guide_jpeg from public.rooms where id='30000000-0000-0000-0000-000000000003'),'/9gR/9k=','Assigned worker can read viewpoint guide');
select is((select count(*) from storage.objects where bucket_id='room-assets' and name like '%/test.worldmap'),1::bigint,'Assigned worker reads private map');
select lives_ok($$select public.set_task_status('50000000-0000-0000-0000-000000000001','completed')$$,'Worker completes task');
select is((select status from public.annotations where id='50000000-0000-0000-0000-000000000001'),'completed','Status persists');
update public.annotations set title='Hacked' where id='50000000-0000-0000-0000-000000000001';
select is((select title from public.annotations where id='50000000-0000-0000-0000-000000000001'),'Paint wall','Worker cannot edit instructions');
select throws_ok($$select public.share_project('20000000-0000-0000-0000-000000000001','outsider@sitescope.test')$$,'42501','Manager access required','Worker cannot share');
select throws_ok($$select public.set_task_status('50000000-0000-0000-0000-000000000001','invalid')$$,'P0001','Invalid status','Invalid status rejected');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
select is((select count(*) from public.projects where id='20000000-0000-0000-0000-000000000001'),0::bigint,'Outsider cannot read project');
select is((select count(*) from public.rooms where id='30000000-0000-0000-0000-000000000001'),0::bigint,'Outsider cannot read room');
select is((select count(*) from public.annotations where id='50000000-0000-0000-0000-000000000001'),0::bigint,'Outsider cannot read instruction');
select is((select count(*) from storage.objects where bucket_id='room-assets' and name like '%/test.worldmap'),0::bigint,'Outsider cannot read map');
select throws_ok($$select public.set_task_status('50000000-0000-0000-0000-000000000001','todo')$$,'42501','Task unavailable or access denied','Outsider cannot complete task');
set local role anon;
select throws_ok($$select * from public.projects$$,'42501','permission denied for table projects','Anonymous reads blocked');
select * from finish();
rollback;
