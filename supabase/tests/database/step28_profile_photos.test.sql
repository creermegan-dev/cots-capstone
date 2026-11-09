-- Synthetic local fixtures only.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
-- Emulate the Storage API's transaction marker for the DELETE policy checks.
-- Row-level security and authenticated roles remain active; rollback clears it.
select set_config('storage.allow_delete_query', 'true', true);
select no_plan();
create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('d2800000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.act(n integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', pg_temp.uid(n), 'role', 'authenticated',
    'session_id', pg_temp.uid(n+10))::text, true);
end $$;
create function pg_temp.p(owner_n integer, file_n integer) returns text language sql immutable as $$
  select pg_temp.uid(owner_n)::text || '/' || pg_temp.uid(100+file_n)::text || '.jpg'
$$;
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'photo-' || n || '@example.invalid',now() from generate_series(1,4) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
-- 3 and 4 are Divers. 5 has no trusted session.
insert into auth.users(id,email,email_confirmed_at) values(pg_temp.uid(5),'photo-5@example.invalid',now());
insert into cots_private.trusted_devices(id,user_id,device_hash)
select pg_temp.uid(n+20),pg_temp.uid(n),repeat(md5('photo-device-' || n),2) from generate_series(1,4) n;
insert into cots_private.trusted_sessions(session_id,user_id,device_id)
select pg_temp.uid(n+10),pg_temp.uid(n),pg_temp.uid(n+20) from generate_series(1,4) n;

select is((select public from storage.buckets where id='profile-photos'),false,'Photo folder is private');
select is((select file_size_limit from storage.buckets where id='profile-photos'),1048576::bigint,'1 MB limit');

select pg_temp.act(3);
set local role authenticated;
select lives_ok(format($$insert into storage.objects(bucket_id,name,owner) values('profile-photos',%L,auth.uid())$$,
  pg_temp.p(3,1)),'Diver uploads own photo');
select throws_ok(format($$insert into storage.objects(bucket_id,name,owner) values('profile-photos',%L,auth.uid())$$,
  pg_temp.p(4,2)),'42501',null,'Diver cannot upload into another person folder');
select throws_ok($$insert into storage.objects(bucket_id,name) values('profile-photos','x/evil.png')$$,
  '42501',null,'Odd file names are refused');
select lives_ok(format($$update public.profiles set avatar_path=%L where id=auth.uid()$$,pg_temp.p(3,1)),
  'Diver saves photo on own profile');
select is((select avatar_path from public.profiles where id=auth.uid()),pg_temp.p(3,1),'Photo path reloads');
select throws_ok(format($$update public.profiles set avatar_path=%L where id=auth.uid()$$,pg_temp.p(4,9)),
  '23514',null,'Profile cannot point at another person photo');
select is((select count(*)::integer from storage.objects where bucket_id='profile-photos'),1,'Diver sees own photo');
reset role;

select pg_temp.act(4);
set local role authenticated;
select is((select count(*)::integer from storage.objects where bucket_id='profile-photos'),0,'Other Diver cannot see it');
delete from storage.objects where bucket_id='profile-photos';
reset role;
select is((select count(*)::integer from storage.objects where bucket_id='profile-photos'),1,'Other Diver cannot delete it');
select pg_temp.act(5);
set local role authenticated;
select throws_ok(format($$insert into storage.objects(bucket_id,name,owner) values('profile-photos',%L,auth.uid())$$,
  pg_temp.p(5,3)),'42501',null,'Untrusted session cannot upload');
reset role;

select pg_temp.act(2);
set local role authenticated;
select is((select count(*)::integer from storage.objects where bucket_id='profile-photos'),1,'Expert can see it');
reset role;
select pg_temp.act(1);
set local role authenticated;
select is((select count(*)::integer from storage.objects where bucket_id='profile-photos'),1,'Admin can see it');
reset role;

select pg_temp.act(3);
set local role authenticated;
select lives_ok($$update public.profiles set avatar_path=null where id=auth.uid()$$,'Diver removes photo from profile');
delete from storage.objects where bucket_id='profile-photos';
reset role;
select is((select count(*)::integer from storage.objects where bucket_id='profile-photos'),0,'Diver deletes own photo file');

select ok(not has_column_privilege('anon','public.profiles','avatar_path','UPDATE'),'Visitors cannot set photos');
select * from finish();
rollback;
