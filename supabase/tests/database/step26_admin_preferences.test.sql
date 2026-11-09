-- Synthetic local fixtures only. No preference or identity data is retained.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();
create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('d2600000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.act(n integer) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', pg_temp.uid(n), 'role', 'authenticated',
    'session_id', pg_temp.uid(n+10))::text, true);
end $$;
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'prefs-' || n || '@example.invalid',now() from generate_series(1,3) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
insert into cots_private.trusted_devices(id,user_id,device_hash)
select pg_temp.uid(n+20),pg_temp.uid(n),repeat(md5('prefs-device-' || n),2) from generate_series(1,3) n;
insert into cots_private.trusted_sessions(session_id,user_id,device_id)
select pg_temp.uid(n+10),pg_temp.uid(n),pg_temp.uid(n+20) from generate_series(1,3) n;

select pg_temp.act(1);
set local role authenticated;
select lives_ok($$insert into public.admin_preferences(uid,weekly_reports)
  values(auth.uid(),true)$$, 'Admin can create own preferences');
select is((select weekly_reports from public.admin_preferences),true,'Saved value reloads');
select lives_ok($$update public.admin_preferences set weekly_reports=false where uid=auth.uid()$$,
  'Admin can update own preferences');
select is((select weekly_reports from public.admin_preferences),false,'Updated value reloads');
select throws_ok($$insert into public.admin_preferences(uid) values(pg_temp.uid(2))$$,
  '42501',null,'Admin cannot write another user preferences');
reset role;
select pg_temp.act(2);
set local role authenticated;
select is((select count(*)::integer from public.admin_preferences),0,'Expert cannot read Admin preferences');
select throws_ok($$insert into public.admin_preferences(uid) values(auth.uid())$$,
  '42501',null,'Expert cannot create Admin preferences');
reset role;
select pg_temp.act(3);
set local role authenticated;
select throws_ok($$insert into public.admin_preferences(uid) values(auth.uid())$$,
  '42501',null,'Diver cannot create Admin preferences');
reset role;
select pg_temp.act(1);
delete from cots_private.trusted_sessions where session_id=pg_temp.uid(11);
set local role authenticated;
select is((select count(*)::integer from public.admin_preferences),0,'Untrusted Admin cannot read preferences');
reset role;
update public.profiles set active=false where id=pg_temp.uid(1);
insert into cots_private.trusted_sessions(session_id,user_id,device_id)
values(pg_temp.uid(11),pg_temp.uid(1),pg_temp.uid(21));
set local role authenticated;
select is((select count(*)::integer from public.admin_preferences),0,'Inactive Admin cannot read preferences');
reset role;
select ok(not has_table_privilege('anon','public.admin_preferences','SELECT'),'Visitors cannot read preferences');
select ok(not has_table_privilege('authenticated','public.admin_preferences','DELETE'),'App cannot delete preferences');
select * from finish();
rollback;
