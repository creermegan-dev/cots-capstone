-- Monthly site levels: confirmed COTS per site per calendar month (0-15 Low, 16-100 Moderate, 101+ High). Rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('d2300000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.as_user(n integer, q text) returns jsonb language plpgsql as $$
declare j jsonb;
begin
  perform set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true);
  set local role authenticated;
  execute q into j;
  reset role;
  return j;
end $$;
create function pg_temp.site(j jsonb, code text) returns jsonb language sql immutable as $$
  select x from jsonb_array_elements(j) x where x->>'area_code' = code
$$;
-- A finalized record with n COTS at the given confidence, captured at t.
create function pg_temp.rec(n integer, area integer, cots integer, conf numeric, t timestamptz) returns void
language plpgsql as $$
begin
  insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
    model_name,model_sha256,source_width,source_height,gps_source)
  values(pg_temp.uid(n),pg_temp.uid(3),pg_temp.uid(n+500),pg_temp.uid(area),t,'device',
    'synthetic-test',repeat('a',64),2048,1536,'unavailable');
  insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
  select gen_random_uuid(),pg_temp.uid(n),i,conf,10+i,10,20+i,20 from generate_series(0,cots-1) i;
  update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(n);
end $$;

insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'monthly-' || n || '@example.invalid',now() from generate_series(1,4) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
set local role authenticated;
select public.verify_personnel(pg_temp.uid(3),true,true);
reset role;
insert into public.monitoring_areas(id,code,name,geography_version) values
  (pg_temp.uid(10),'M-A','Busy Reef','test-only'), (pg_temp.uid(11),'M-B','Quiet Reef','test-only');

-- This month: 12 + 6 auto-accepted COTS (18 = Moderate) and 2 COTS waiting for the Expert.
-- Two months ago: 3 COTS (Low).
select pg_temp.rec(20,10,12,0.95,now());
select pg_temp.rec(21,10,6,0.95,now());
select pg_temp.rec(22,10,2,0.50,now());
select pg_temp.rec(23,10,3,0.95,now()-interval '62 days');

select is(pg_temp.site(pg_temp.as_user(3,'select public.site_month_levels_json()'),'M-A')->>'level','Moderate',
  'Latest month: 18 confirmed COTS is Moderate');
select is((pg_temp.site(pg_temp.as_user(3,'select public.site_month_levels_json()'),'M-A')->>'confirmed_cots')::int,18,
  'COTS waiting for the Expert do not count');
select is((pg_temp.site(pg_temp.as_user(3,'select public.site_month_levels_json()'),'M-A')->>'waiting_cots')::int,2,
  'but are shown as waiting');
select is((pg_temp.site(pg_temp.as_user(3,'select public.site_month_levels_json()'),'M-A')->>'records')::int,3,
  'Records of the month are counted');
select is(pg_temp.site(pg_temp.as_user(3,format('select public.site_month_levels_json(%L::date)',
  (now() at time zone 'Asia/Manila' - interval '62 days')::date)),'M-A')->>'level','Low',
  'A chosen earlier month shows that month only');
select is(pg_temp.site(pg_temp.as_user(3,format('select public.site_month_levels_json(%L::date)',
  (now() at time zone 'Asia/Manila' - interval '31 days')::date)),'M-A')->>'level',null,
  'A month without records has no level');
select is(pg_temp.site(pg_temp.as_user(3,'select public.site_month_levels_json()'),'M-B')->>'level',null,
  'A site without records has no level');
select is(jsonb_array_length((select jsonb_agg(x) from jsonb_array_elements(
  pg_temp.as_user(1,'select public.site_month_history_json(12)')) x where x->>'area_code'='M-A')),2,
  'History lists each month with records');
select ok(position(pg_temp.uid(3)::text in pg_temp.as_user(3,'select public.site_month_history_json()')::text) = 0,
  'No person IDs in the totals');
select set_config('request.jwt.claim.sub', pg_temp.uid(4)::text, true);
update public.profiles set active = false where id = pg_temp.uid(4);
set local role authenticated;
select throws_ok($q$select public.site_month_levels_json()$q$, '42501', null, 'An inactive account cannot read levels');
reset role;
select ok(not has_function_privilege('anon','public.site_month_levels_json(date)','EXECUTE'), 'Visitors cannot read levels');
select ok(not has_function_privilege('anon','public.site_month_history_json(integer)','EXECUTE'), 'Visitors cannot read history');
select is(cots_private.monthly_level(0),'Low','0 COTS is Low');
select is(cots_private.monthly_level(15),'Low','15 COTS is Low');
select is(cots_private.monthly_level(16),'Moderate','16 COTS is Moderate');
select is(cots_private.monthly_level(100),'Moderate','100 COTS is Moderate');
select is(cots_private.monthly_level(101),'High','101 COTS is High');

select * from finish();
rollback;
