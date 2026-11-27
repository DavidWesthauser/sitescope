-- Access rules from docs/DATABASE_API.md that, if broken, leak data or let someone raise their own rights.
-- Runs on its own fixtures (not seed.sql) inside one rolled-back transaction.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Acts as a signed-in user for the following statements.
create function pg_temp.act_as(uid uuid) returns void language plpgsql as $$
begin
    perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
end;
$$;
-- Back to the test owner with no user: clears the claims too, or auth.uid() would still return the last user.
create function pg_temp.act_as_owner() returns void language plpgsql as $$
begin
    execute 'reset role';
    perform set_config('request.jwt.claims', '', true);
end;
$$;

-- Fixtures: A is run by boss with a member, an external and a room-only external; B belongs to outsider.
insert into auth.users (id, email) values
    ('a0000000-0000-0000-0000-000000000001', 'boss@test.local'),
    ('a0000000-0000-0000-0000-000000000002', 'member@test.local'),
    ('a0000000-0000-0000-0000-000000000003', 'external@test.local'),
    ('a0000000-0000-0000-0000-000000000004', 'outsider@test.local'),
    ('a0000000-0000-0000-0000-000000000005', 'admin@test.local'),
    ('a0000000-0000-0000-0000-000000000006', 'roomonly@test.local');
insert into public.admins (user_id) values ('a0000000-0000-0000-0000-000000000005');
insert into public.projects (id, name, responsible_id) values
    ('b0000000-0000-0000-0000-000000000001', 'Project A', 'a0000000-0000-0000-0000-000000000001'),
    ('b0000000-0000-0000-0000-000000000002', 'Project B', 'a0000000-0000-0000-0000-000000000004');
insert into public.houses (id, project_id, name, responsible_id) values
    ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'House A',
        'a0000000-0000-0000-0000-000000000001'),
    ('c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'House B',
        'a0000000-0000-0000-0000-000000000004');
insert into public.rooms (id, house_id, project_id, name, responsible_id, map_path) values
    ('d0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001',
        'b0000000-0000-0000-0000-000000000001', 'Mapped room', 'a0000000-0000-0000-0000-000000000001', 'map.worldmap'),
    ('d0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001',
        'b0000000-0000-0000-0000-000000000001', 'Unmapped room', 'a0000000-0000-0000-0000-000000000001', null);
insert into public.access_grants (user_id, role, project_id, house_id, room_id) values
    ('a0000000-0000-0000-0000-000000000002', 'member', 'b0000000-0000-0000-0000-000000000001', null, null),
    ('a0000000-0000-0000-0000-000000000003', 'external', 'b0000000-0000-0000-0000-000000000001', null, null),
    ('a0000000-0000-0000-0000-000000000006', 'external', 'b0000000-0000-0000-0000-000000000001',
        'c0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000002');
insert into public.annotations (id, room_id, coordinate_id, kind, pose, title)
select 'e0000000-0000-0000-0000-000000000001', id, coordinate_id, 'text', '{}', 'Drill here'
from public.rooms where id = 'd0000000-0000-0000-0000-000000000001';

-- Without a session nothing is readable.
set local role anon;
select throws_ok('select * from public.projects', '42501', null, 'anon cannot read projects');
select throws_ok('select * from public.profiles', '42501', null, 'anon cannot read profiles');
select pg_temp.act_as_owner();

-- Outsider: sees nothing of A and cannot get in through ids it controls.
select pg_temp.act_as('a0000000-0000-0000-0000-000000000004');
select is((select count(*)::int from public.projects where id = 'b0000000-0000-0000-0000-000000000001'), 0,
    'outsider does not see project A');
select is((select count(*)::int from public.rooms where project_id = 'b0000000-0000-0000-0000-000000000001'), 0,
    'outsider sees no rooms of project A');
select is((select count(*)::int from public.annotations), 0, 'outsider sees no notes');
select is((select count(*)::int from public.access_grants), 0, 'outsider sees no grants');
select is(public.scope_level('b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001'), 0,
    'own project paired with a foreign house gives no rights');
select is(public.asset_level('b0000000-0000-0000-0000-000000000002/d0000000-0000-0000-0000-000000000001/map.worldmap'),
    0, 'own project id in a storage path does not open a foreign room file');
select throws_ok($$select public.grant_access('outsider@test.local', 'member', 'b0000000-0000-0000-0000-000000000001')$$,
    '42501', null, 'outsider cannot share themselves into project A');
update public.profiles set display_name = 'Hacked' where user_id = 'a0000000-0000-0000-0000-000000000001';
select pg_temp.act_as_owner();
select is((select display_name from public.profiles where user_id = 'a0000000-0000-0000-0000-000000000001'), 'boss',
    'a profile is only changed by its owner');

-- External: reads and updates task status, nothing else.
select pg_temp.act_as('a0000000-0000-0000-0000-000000000003');
select throws_ok($$insert into public.rooms (house_id, project_id, name)
    values ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'New')$$,
    '42501', null, 'external cannot create rooms');
update public.annotations set title = 'Changed' where id = 'e0000000-0000-0000-0000-000000000001';
select lives_ok($$select public.set_task_status('e0000000-0000-0000-0000-000000000001', 'completed')$$,
    'external can change task status');
select pg_temp.act_as_owner();
select results_eq($$select title, status from public.annotations where id = 'e0000000-0000-0000-0000-000000000001'$$,
    $$values ('Drill here', 'completed')$$, 'external changed the status but not the title');

-- A room grant opens one room, not its siblings.
select pg_temp.act_as('a0000000-0000-0000-0000-000000000006');
select is((select array_agg(name) from public.rooms), array['Unmapped room'], 'a room grant shows only that room');
select is((select count(*)::int from public.annotations), 0, 'notes of sibling rooms stay hidden');
select pg_temp.act_as_owner();

-- Member: edits content but cannot delete what someone else is responsible for or create houses.
select pg_temp.act_as('a0000000-0000-0000-0000-000000000002');
delete from public.rooms where id = 'd0000000-0000-0000-0000-000000000002';
select throws_ok($$insert into public.houses (project_id, name) values ('b0000000-0000-0000-0000-000000000001', 'H')$$,
    '42501', null, 'member cannot create houses');
select throws_ok($$update public.rooms set map_path = 'other' where id = 'd0000000-0000-0000-0000-000000000001'$$,
    null, 'Published room maps cannot be replaced. Create a new room for remapping.',
    'a published map stays fixed, so placed notes keep their position');
select throws_ok($$insert into public.annotations (room_id, coordinate_id, kind, pose, title)
    select id, coordinate_id, 'text', '{}', 'x' from public.rooms where id = 'd0000000-0000-0000-0000-000000000002'$$,
    null, 'Map the room before placing instructions.', 'notes need a mapped room');
select pg_temp.act_as_owner();
select is((select count(*)::int from public.rooms where id = 'd0000000-0000-0000-0000-000000000002'), 1,
    'member cannot delete a room');

-- Responsible: cannot forge authorship or hand the project over; sharing and revoking take effect.
select pg_temp.act_as('a0000000-0000-0000-0000-000000000001');
select throws_ok($$insert into public.projects (name, created_by)
    values ('Forged', 'a0000000-0000-0000-0000-000000000004')$$, '42501', null, 'created_by cannot be forged');
select throws_ok($$update public.projects set responsible_id = 'a0000000-0000-0000-0000-000000000002'
    where id = 'b0000000-0000-0000-0000-000000000001'$$, '42501', null, 'only an admin changes the project responsible');
select throws_ok($$select public.grant_access('nobody@test.local', 'member', 'b0000000-0000-0000-0000-000000000001')$$,
    null, 'No active account uses this email.', 'sharing with an unknown email fails');
select public.grant_access('Outsider@Test.local', 'external', 'b0000000-0000-0000-0000-000000000001');
select pg_temp.act_as('a0000000-0000-0000-0000-000000000004');
select is((select count(*)::int from public.annotations), 1, 'a shared user sees the notes');
select pg_temp.act_as('a0000000-0000-0000-0000-000000000001');
select public.revoke_access(id) from public.access_grants where user_id = 'a0000000-0000-0000-0000-000000000004';
select pg_temp.act_as('a0000000-0000-0000-0000-000000000004');
select is((select count(*)::int from public.annotations), 0, 'after revoking, the notes are gone again');
select pg_temp.act_as_owner();

-- Comments: replies stay in scope, hiding is admin-only and hides for everyone else.
select pg_temp.act_as('a0000000-0000-0000-0000-000000000003');
insert into public.comments (id, project_id, house_id, room_id, body) values
    ('f0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001',
        'c0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'Tiles?');
select throws_ok($$insert into public.comments (project_id, parent_id, body) values
    ('b0000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'Reply')$$,
    null, 'A reply must have the same scope as its parent comment.',
    'a reply cannot move a room comment to project level');
select throws_ok($$select public.set_comment_hidden('f0000000-0000-0000-0000-000000000001', true)$$,
    '42501', null, 'only admins hide comments');
select pg_temp.act_as('a0000000-0000-0000-0000-000000000005');
select public.set_comment_hidden('f0000000-0000-0000-0000-000000000001', true);
select pg_temp.act_as('a0000000-0000-0000-0000-000000000003');
select is((select count(*)::int from public.comments), 0, 'a hidden comment is invisible to non-admins');
select pg_temp.act_as_owner();

-- A deactivated user loses access everywhere at once.
update public.profiles set is_active = false where user_id = 'a0000000-0000-0000-0000-000000000002';
select pg_temp.act_as('a0000000-0000-0000-0000-000000000002');
select is((select count(*)::int from public.projects), 0, 'an inactive user sees nothing');
select throws_ok($$update public.profiles set is_active = true where user_id = 'a0000000-0000-0000-0000-000000000002'$$,
    '42501', null, 'a deactivated user cannot reactivate themselves');
select pg_temp.act_as_owner();

select * from finish();
rollback;
