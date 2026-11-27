-- Local development data only (`supabase db reset`). Never run on the hosted project.
-- Accounts (password for all: sitescope-local-2026!):
--   manager@sitescope.test   responsible for "Demo project"
--   worker@sitescope.test    external on "Demo project" (reads, changes task status)
--   outsider@sitescope.test  no access

insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
)
select
    '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email,
    extensions.crypt('sitescope-local-2026!', extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}', jsonb_build_object('display_name', u.display_name), now(), now(),
    '', '', '', ''
from (values
    ('11111111-1111-1111-1111-111111111111'::uuid, 'manager@sitescope.test', 'Manager'),
    ('22222222-2222-2222-2222-222222222222'::uuid, 'worker@sitescope.test', 'Worker'),
    ('33333333-3333-3333-3333-333333333333'::uuid, 'outsider@sitescope.test', 'Outsider')
) as u (id, email, display_name);

insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), id, id::text, jsonb_build_object('sub', id::text, 'email', email), 'email', now(), now(), now()
from auth.users
where email like '%@sitescope.test';

insert into public.projects (id, name, responsible_id)
values ('aaaaaaaa-0000-0000-0000-000000000001', 'Demo project', '11111111-1111-1111-1111-111111111111');

insert into public.houses (id, project_id, name, responsible_id)
values (
    'bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Main building',
    '11111111-1111-1111-1111-111111111111'
);

-- Unmapped: a real ARWorldMap only comes from scanning on a phone.
insert into public.rooms (id, house_id, project_id, name, responsible_id)
values (
    'cccccccc-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000001', 'Kitchen', '11111111-1111-1111-1111-111111111111'
);

insert into public.access_grants (user_id, role, project_id)
values ('22222222-2222-2222-2222-222222222222', 'external', 'aaaaaaaa-0000-0000-0000-000000000001');
