-- Stage 13: site colours on the map come from the latest Expert-confirmed level. Rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('d2000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.levels_as(n integer) returns jsonb language plpgsql as $$
declare j jsonb;
begin
  perform set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true);
  set local role authenticated;
  j := public.site_levels_json();
  reset role;
  return j;
end $$;
create function pg_temp.site(j jsonb, code text) returns jsonb language sql immutable as $$
  select x from jsonb_array_elements(j) x where x->>'area_code' = code
$$;

insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'stage13-' || n || '@example.invalid',now() from generate_series(1,4) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
set local role authenticated;
select public.verify_personnel(pg_temp.uid(3),true,true);
reset role;
insert into public.monitoring_areas(id,code,name,geography_version) values
  (pg_temp.uid(10),'S13-A','Level Reef','test-only'), (pg_temp.uid(11),'S13-B','Quiet Reef','test-only');

-- A finalized record with 2 COTS, a monthly visit (6 COTS on 400 m² = 150 COTS/ha) and the Expert's level.
insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
  model_name,model_sha256,source_width,source_height,gps_source)
values(pg_temp.uid(20),pg_temp.uid(3),pg_temp.uid(520),pg_temp.uid(10),now()-interval '40 days','device',
  'synthetic-test',repeat('a',64),2048,1536,'unavailable');
insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2) values
  (pg_temp.uid(30),pg_temp.uid(20),0,0.95,10,10,100,100),(pg_temp.uid(31),pg_temp.uid(20),1,0.95,200,10,300,100);
update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(20);
insert into public.follow_up_assignments(id,area_id,primary_diver_id,originating_capture_id)
values(pg_temp.uid(60),pg_temp.uid(10),pg_temp.uid(3),pg_temp.uid(20));
set local session_replication_role = replica;
insert into public.follow_up_surveys(id,owner_id,idempotency_key,assignment_id,captured_at,month,authorization_revision,
  gps_source,observed_count,eliminated_count,elimination_method,surveyed_area_m2,survey_date,status,completed_at)
values(pg_temp.uid(70),pg_temp.uid(3),pg_temp.uid(570),pg_temp.uid(60),now()-interval '2 days',
  date_trunc('month', (now()-interval '2 days') at time zone 'Asia/Manila')::date,0,'unavailable',6,6,'Manual Removal',400,
  ((now()-interval '2 days') at time zone 'Asia/Manila')::date,'completed',now());
insert into public.infestation_assessments(survey_id,expert_id,level,method,rationale)
values(pg_temp.uid(70),pg_temp.uid(2),'High','calculated','Synthetic test level');
set local session_replication_role = origin;

select is(pg_temp.site(pg_temp.levels_as(3),'S13-A')->>'level', 'High', 'A Diver sees the site''s confirmed level');
select is((pg_temp.site(pg_temp.levels_as(3),'S13-A')->>'density_per_ha')::numeric, 150.00, 'with its density');
select is((pg_temp.site(pg_temp.levels_as(3),'S13-A')->>'confirmed_cots')::integer, 2, 'and its confirmed COTS');
select is((pg_temp.site(pg_temp.levels_as(1),'S13-A')->>'records')::integer, 1, 'The Admin sees the same totals');
select is(pg_temp.site(pg_temp.levels_as(3),'S13-B')->>'level', null, 'A site with no visit has no level yet');
select ok(position('Diver' in pg_temp.levels_as(3)::text) = 0 and position(pg_temp.uid(3)::text in pg_temp.levels_as(3)::text) = 0,
  'No names or person IDs in the map totals');
select set_config('request.jwt.claim.sub', pg_temp.uid(4)::text, true);
update public.profiles set active = false where id = pg_temp.uid(4);
set local role authenticated;
select throws_ok($q$select public.site_levels_json()$q$, '42501', null, 'An inactive account cannot read it');
reset role;
select ok(not has_function_privilege('anon','public.site_levels_json()','EXECUTE'), 'Visitors cannot read it');
select is(cots_private.density_level(15), 'Low', '15 COTS/ha is Low');
select is(cots_private.density_level(16), 'Moderate', '16 COTS/ha is Moderate');
select is(cots_private.density_level(100), 'Moderate', '100 COTS/ha is Moderate');
select is(cots_private.density_level(101), 'High', 'Over 100 COTS/ha is High');

select * from finish();
rollback;
