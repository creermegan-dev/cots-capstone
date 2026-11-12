-- Monthly report (staff only): totals, not-accepted, sites, month and site filters, Expert review. Rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('d2900000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
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
  select x from jsonb_array_elements(j -> 'sites') x where x->>'area_code' = code
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
select pg_temp.uid(n),'report-' || n || '@example.invalid',now() from generate_series(1,4) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
set local role authenticated;
select public.verify_personnel(pg_temp.uid(3),true,true);
reset role;
insert into public.monitoring_areas(id,code,name,geography_version) values
  (pg_temp.uid(10),'R-A','Busy Reef','test-only'), (pg_temp.uid(11),'R-B','Quiet Reef','test-only');
insert into public.monitoring_areas(id,code,name,geography_version,geographic_reference)
  values (pg_temp.uid(12),'R-P','Practice Test','test-only','{"practice": true}'::jsonb);

-- This month at R-A: 12 + 6 auto-accepted, 2 waiting for the Expert, 3 below 20% (not accepted).
-- R-B: 4 auto-accepted. The practice site: 9 auto-accepted (must be left out).
-- Two months ago at R-A: 3 auto-accepted.
select pg_temp.rec(20,10,12,0.95,now());
select pg_temp.rec(21,10,6,0.95,now());
select pg_temp.rec(22,10,2,0.50,now());
select pg_temp.rec(24,10,3,0.10,now());
select pg_temp.rec(25,11,4,0.95,now());
select pg_temp.rec(26,12,9,0.95,now());
select pg_temp.rec(23,10,3,0.95,now()-interval '62 days');

create temp table rep as select pg_temp.as_user(2,'select public.monthly_report_json()') as j;

select is((select (j->>'confirmed_cots')::int from rep),22,'Confirmed COTS add up for the month, practice site left out');
select is((select (j->>'waiting_cots')::int from rep),2,'Waiting COTS are shown separately');
select is((select (j->>'not_accepted_cots')::int from rep),3,'Not accepted = AI boxes that are neither confirmed nor waiting');
select is((select (j->>'records')::int from rep),5,'Records of the month are counted');
select is((select jsonb_array_length(j->'sites') from rep),2,'Only real sites with records are listed');
select is((select pg_temp.site(j,'R-A')->>'level' from rep),'Moderate','18 confirmed COTS is Moderate');
select is((select (pg_temp.site(j,'R-A')->>'confirmed_cots')::int from rep),18,'Site row matches the confirmed count');
select is((select (pg_temp.site(j,'R-A')->>'waiting_cots')::int from rep),2,'Site row shows waiting COTS');
select is((select pg_temp.site(j,'R-B')->>'level' from rep),'Low','4 confirmed COTS is Low');
select is((select pg_temp.site(j,'R-P') from rep),null,'Practice sites are not in the report');
select is((select (j->>'photos_at_80')::int from rep),0,'New photos use the 85% rule');
select is((select jsonb_typeof(j->'methods') from rep),'array','Removal methods are a list');
select is((select (j->'expert_review'->>'reviewed')::int from rep),0,'No Expert decision yet');
select is((select (j->'expert_review'->>'still_waiting')::int from rep),1,'One photo is still waiting for the Expert');

-- One site only.
select is((pg_temp.as_user(2,$q$select public.monthly_report_json(null,'R-B')$q$)->>'confirmed_cots')::int,4,
  'A chosen site limits the totals');
select is(jsonb_array_length(pg_temp.as_user(2,$q$select public.monthly_report_json(null,'R-B')$q$)->'sites'),1,
  'and the site list');
select is(pg_temp.as_user(2,$q$select public.monthly_report_json(null,'R-B')$q$)->>'area_name','Quiet Reef',
  'and carries the site name');

-- A chosen earlier month.
select is((pg_temp.as_user(1,format('select public.monthly_report_json(%L::date)',
  (now() at time zone 'Asia/Manila' - interval '62 days')::date))->>'confirmed_cots')::int,3,
  'A chosen earlier month shows that month only');

-- Expert review: the Expert decides on the waiting photo.
select pg_temp.as_user(2,format($q$select to_jsonb(public.record_expert_decision(%L::uuid,null,'approve','Checked',null,
  (select jsonb_agg(jsonb_build_object('item_id',id::text,'decision','approve'))
   from public.detection_items where capture_id=%L)))$q$,
  pg_temp.uid(22),pg_temp.uid(22)));
select is((pg_temp.as_user(2,'select public.monthly_report_json()')->'expert_review'->>'reviewed')::int,1,
  'An Expert decision is counted as reviewed');
select is((pg_temp.as_user(2,'select public.monthly_report_json()')->'expert_review'->>'approved')::int,1,
  'Approved decisions are counted');
select ok((pg_temp.as_user(2,'select public.monthly_report_json()')->'expert_review'->>'avg_wait_days') is not null,
  'The average wait is shown once a decision exists');

-- Access.
select set_config('request.jwt.claim.sub', pg_temp.uid(3)::text, true);
set local role authenticated;
select throws_ok($q$select public.monthly_report_json()$q$, '42501', null, 'A Diver cannot read the report');
reset role;
select set_config('request.jwt.claim.sub', pg_temp.uid(2)::text, true);
set local role authenticated;
select throws_ok($q$select public.monthly_report_json(null,'NOPE')$q$, '22023', null, 'An unknown site is refused');
reset role;
select ok(not has_function_privilege('anon','public.monthly_report_json(date,text)','EXECUTE'), 'Visitors cannot read the report');
select ok(position(pg_temp.uid(3)::text in pg_temp.as_user(2,'select public.monthly_report_json()')::text) = 0,
  'No person IDs in the report');

select * from finish();
rollback;
