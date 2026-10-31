-- Infestation level from COTS density (Dumas et al., 2020); Expert confirms.
-- Synthetic fixtures only; everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('a0000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.act(n integer) returns void language sql as $$
  select set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true)
$$;
create function pg_temp.today() returns date language sql stable as $$
  select (now() at time zone 'Asia/Manila')::date
$$;

-- The calculation and thresholds.
select is(cots_private.density_per_ha(12, 2500), 48.00, '12 COTS over 2,500 m² is 48 COTS/ha');
select is(cots_private.density_per_ha(120, 10000), 120.00, '120 COTS over 1 ha is 120 COTS/ha');
select is(cots_private.density_per_ha(5, null), null, 'No surveyed area, no density');
select is(cots_private.density_level(14.99), 'Low', 'Below 15 is Low');
select is(cots_private.density_level(15), 'Moderate', 'Exactly 15 is Moderate');
select is(cots_private.density_level(100), 'Moderate', 'Exactly 100 is Moderate');
select is(cots_private.density_level(100.01), 'High', 'Above 100 is High');
select is(cots_private.density_level(0), 'Low', 'Zero COTS is Low');

-- 1 Admin, 2 Expert, 3 Diver.
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'density-' || n || '@example.invalid',now() from generate_series(1,3) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select pg_temp.act(1);
set local role authenticated;
select public.verify_personnel(pg_temp.uid(3),true,true);
reset role;
insert into public.monitoring_areas(id,code,name,geography_version)
values(pg_temp.uid(10),'DENSITY-TEST','Density Reef','test-only');
insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
  model_name,model_sha256,source_width,source_height,gps_source)
select pg_temp.uid(n), pg_temp.uid(3), pg_temp.uid(n), pg_temp.uid(10), now() - interval '2 days', 'device',
  'synthetic-test', repeat('a',64), 2048, 1536, 'unavailable'
from unnest(array[20,30,31]) n;
-- The visit photo (capture 30) shows 12 COTS at 95%.
insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
select ('a1000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid, pg_temp.uid(30), n, 0.95,
  10 + n * 100, 10, 90 + n * 100, 90
from generate_series(0,11) n;
update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(20);
insert into public.follow_up_assignments(id,area_id,primary_diver_id,originating_capture_id)
values(pg_temp.uid(50),pg_temp.uid(10),pg_temp.uid(3),pg_temp.uid(20));

-- The surveyed area is now required.
select pg_temp.act(3);
set local role authenticated;
select throws_ok(format($q$select public.submit_follow_up_survey(%L,'DENSITY-TEST',%L,12,0,'Vinegar injection',null,array[%L]::uuid[],null,null,'')$q$,
  pg_temp.uid(60),pg_temp.today(),pg_temp.uid(30)),'23514','Enter the surveyed reef area in square meters',
  'A visit without the surveyed area is refused');
select is(public.submit_follow_up_survey(pg_temp.uid(60),'DENSITY-TEST',pg_temp.today(),12,0,'Vinegar injection',2500,
  array[pg_temp.uid(30)],null,null,''),'pending','A visit with the surveyed area is saved');
select is(public.follow_up_surveys_json()->0->>'calculated_level','Moderate','The Diver sees the calculated level');
select is((public.follow_up_surveys_json()->0->>'density_per_ha')::numeric,48.00,'The Diver sees the density');
select throws_ok($q$select public.follow_up_visits_to_assess()$q$,'42501',null,'Divers cannot open the assessment list');
select throws_ok(format($q$select public.confirm_follow_up_assessment(%L,'Low','')$q$,pg_temp.uid(60)),
  '42501',null,'Divers cannot confirm a level');
reset role;

-- Visit completes; the Expert confirms.
update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(30);
select pg_temp.act(2);
set local role authenticated;
select is(jsonb_array_length(public.follow_up_visits_to_assess()),1,'The completed visit waits for the Expert');
select throws_ok(format($q$select public.confirm_follow_up_assessment(%L,'High','')$q$,pg_temp.uid(60)),
  '23514',null,'A different level needs a reason');
select throws_ok(format($q$select public.confirm_follow_up_assessment(%L,'Severe','')$q$,pg_temp.uid(60)),
  '23514',null,'Only Low, Moderate or High');
select lives_ok(format($q$select public.confirm_follow_up_assessment(%L,'Moderate','')$q$,pg_temp.uid(60)),
  'The Expert confirms the calculated level');
select is(jsonb_array_length(public.follow_up_visits_to_assess()),0,'The visit leaves the list once confirmed');
select ok((select method from public.infestation_assessments where survey_id=pg_temp.uid(60))
  like 'COTS density (Dumas et al., 2020): 48.00 COTS/ha%','The calculation is recorded with the assessment');
select is((select rationale from public.infestation_assessments where survey_id=pg_temp.uid(60)),
  'Confirmed the calculated level','Confirming without a reason is recorded as such');
select lives_ok(format($q$select public.confirm_follow_up_assessment(%L,'High','Dense cluster near the drop-off')$q$,
  pg_temp.uid(60)),'The Expert can record a different level with a reason');
reset role;

select is((select count(*)::integer from public.infestation_assessments where survey_id=pg_temp.uid(60)),2,
  'Both assessments are kept as history');
select is((select rationale from public.infestation_assessments where level='High'),'Dense cluster near the drop-off',
  'The reason is recorded');
select pg_temp.act(3);
set local role authenticated;
-- (Both assessments share one timestamp inside this test, so either may be latest.)
select ok(public.latest_area_assessment('DENSITY-TEST')->>'level' in ('Moderate','High'),'Divers see the confirmed level');
select ok(public.follow_up_surveys_json()->0->>'assessed_level' in ('Moderate','High'),'The visit shows the confirmed level');
reset role;

select ok(not has_function_privilege('anon','public.confirm_follow_up_assessment(uuid,text,text)','EXECUTE'),
  'Visitors who are not signed in cannot confirm levels');

select * from finish();
rollback;
