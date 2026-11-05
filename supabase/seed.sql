-- LOCAL DEVELOPMENT ONLY. Fixed identities are fixtures, never production credentials.
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change)
select '00000000-0000-0000-0000-000000000000', id::uuid, 'authenticated','authenticated',email,extensions.crypt('sitescope-local-2026!',extensions.gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now(),'','','',''
from (values ('10000000-0000-0000-0000-000000000001','manager@sitescope.test'),('10000000-0000-0000-0000-000000000002','worker@sitescope.test'),('10000000-0000-0000-0000-000000000003','outsider@sitescope.test')) as u(id,email)
on conflict(id) do nothing;
insert into auth.identities(id,user_id,provider_id,identity_data,provider,last_sign_in_at,created_at,updated_at)
select id,id,id::text,jsonb_build_object('sub',id::text,'email',email,'email_verified',true),'email',now(),now(),now() from auth.users where email like '%@sitescope.test' on conflict(provider_id,provider) do nothing;
insert into public.projects(id,owner_id,name) values('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Fixture apartment') on conflict do nothing;
insert into public.memberships values('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002',now()) on conflict do nothing;
insert into public.rooms(id,project_id,name) values('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Kitchen — map on a real iPhone') on conflict do nothing;
-- No fake ARWorldMap: a real map can only be generated on hardware.
