-- Stage 1: one encounter, removed count taken from the photos.
-- Synthetic fixtures only; everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('c0000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.act(n integer) returns void language sql as $$
  select set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true)
$$;
create function pg_temp.today() returns date language sql stable as $$
  select (now() at time zone 'Asia/Manila')::date
$$;
-- Photo n owned by Diver o in area 10, optionally in encounter e.
create function pg_temp.photo(n integer, o integer, e integer) returns text language sql as $$
  select format($q$insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
    model_name,model_sha256,source_width,source_height,gps_source,encounter_id)
    values(%L,%L,%L,%L,now(),'device','synthetic-test',repeat('a',64),2048,1536,'unavailable',%L)$q$,
    pg_temp.uid(n), pg_temp.uid(o), pg_temp.uid(n + 300), pg_temp.uid(10),
    case when e is null then null else pg_temp.uid(e) end)
$$;
create function pg_temp.removal(id integer, o integer, cap integer, e integer, removed integer) returns text language sql as $$
  select format($q$insert into public.eliminations(id,owner_id,idempotency_key,capture_id,encounter_id,captured_at,
    removed_count,method,gps_source) values(%L,%L,%L,%L,%L,now(),%s,'Vinegar injection','unavailable')$q$,
    pg_temp.uid(id), pg_temp.uid(o), pg_temp.uid(id + 300), pg_temp.uid(cap),
    case when e is null then null else pg_temp.uid(e) end, removed)
$$;
create function pg_temp.items(cap integer, variadic conf numeric[]) returns void language sql as $$
  insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
  select ('c1000000-0000-4000-' || lpad(cap::text,4,'0') || '-' || lpad(i::text,12,'0'))::uuid,
    pg_temp.uid(cap), i - 1, conf[i], 10 + i * 120, 10, 100 + i * 120, 100
  from generate_subscripts(conf, 1) i
$$;

-- 1 Admin, 2 Expert, 3 Diver A, 4 Diver B.
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'stage1-' || n || '@example.invalid',now() from generate_series(1,4) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select pg_temp.act(1);
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
select public.verify_personnel(pg_temp.uid(n),true,true) from generate_series(3,4) n;
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
reset role;
insert into public.monitoring_areas(id,code,name,geography_version)
values(pg_temp.uid(10),'STAGE1-TEST','Stage One Reef','test-only');

-- Diver A: one encounter with three photos of different COTS.
select pg_temp.act(3);
set local role authenticated;
select lives_ok(format($q$insert into public.encounters(id,owner_id,idempotency_key) values(%L,%L,%L)$q$,
  pg_temp.uid(50),pg_temp.uid(3),pg_temp.uid(51)),'A Diver starts an encounter');
select lives_ok(pg_temp.photo(20,3,50),'Photo 1 joins the encounter');
select lives_ok(pg_temp.photo(21,3,50),'Photo 2 joins the encounter');
select lives_ok(pg_temp.photo(22,3,50),'Photo 3 joins the encounter');
reset role;
-- Photo 1: 95% and 55%; photo 2: 90%; photo 3: 85% and 60%. Photo total 5.
select pg_temp.items(20, 0.95, 0.55);
select pg_temp.items(21, 0.90);
select pg_temp.items(22, 0.85, 0.60);

select pg_temp.act(3);
set local role authenticated;
select throws_ok(pg_temp.removal(30,3,20,50,0),'23514',null,'An encounter removal needs at least 1 COTS');
select lives_ok(pg_temp.removal(30,3,20,50,5),'One removal record with the photo total (5)');
select throws_ok(pg_temp.removal(31,3,21,50,5),'23505',null,'Only one removal record per encounter');
select throws_ok(pg_temp.removal(30,3,20,50,5),'23505',null,'A retried removal is not duplicated');
select is((select count(*)::integer from public.eliminations where encounter_id=pg_temp.uid(50)),1,
  'The encounter has exactly one removal record');
select is(public.encounter_summary(pg_temp.uid(50))->>'photo_count','5','Photo total is 5');
select is(public.encounter_summary(pg_temp.uid(50))->>'confirmed_count','3','3 COTS at 80% or above count before review');
select is(public.encounter_summary(pg_temp.uid(50))->>'waiting_count','2','2 COTS wait for the Expert');
reset role;

-- Another Diver cannot join or remove from Diver A's encounter.
select pg_temp.act(4);
set local role authenticated;
select throws_ok(pg_temp.photo(23,4,50),'42501',null,'A photo cannot join another Diver''s encounter');
select throws_ok($q$select public.encounter_summary('c0000000-0000-4000-8000-000000000050')$q$,'42501',null,
  'Another Diver cannot read the encounter');
reset role;

-- The removal must link to a photo of the same encounter.
select pg_temp.act(3);
set local role authenticated;
select lives_ok(format($q$insert into public.encounters(id,owner_id,idempotency_key) values(%L,%L,%L)$q$,
  pg_temp.uid(52),pg_temp.uid(3),pg_temp.uid(53)),'A second encounter');
select lives_ok(pg_temp.photo(24,3,null),'A photo outside any encounter');
select throws_ok(pg_temp.removal(32,3,24,52,1),'42501',null,'A removal cannot link to a photo outside its encounter');
reset role;

-- Expert review changes the confirmed count.
select pg_temp.act(2);
set local role authenticated;
select lives_ok(format($q$select public.record_expert_decision(%L,null,'approve','Reviewed',null,%L)$q$,
  pg_temp.uid(20), jsonb_build_array(
    jsonb_build_object('item_id','c1000000-0000-4000-0020-000000000001','decision','approve'),
    jsonb_build_object('item_id','c1000000-0000-4000-0020-000000000002','decision','approve'))),
  'Expert approves both COTS in photo 1');
select lives_ok(format($q$select public.record_expert_decision(%L,null,'approve','One is a rock',null,%L)$q$,
  pg_temp.uid(22), jsonb_build_array(
    jsonb_build_object('item_id','c1000000-0000-4000-0022-000000000001','decision','reject'),
    jsonb_build_object('item_id','c1000000-0000-4000-0022-000000000002','decision','approve'))),
  'Expert rejects the 85% box (a rock) and approves the 60% one in photo 3');
select is(public.encounter_summary(pg_temp.uid(50))->>'confirmed_count','4',
  'Confirmed count after review: 5 photo COTS minus 1 rejected');
select is(public.encounter_summary(pg_temp.uid(50))->>'waiting_count','0','Nothing waits for the Expert');
select is(public.encounter_summary(pg_temp.uid(50))->>'reported_removed','5','The reported photo total is kept as submitted');
select lives_ok(format($q$select public.record_expert_decision(%L,null,'reject','Not COTS',null,'[]'::jsonb)$q$,
  pg_temp.uid(21)),'Expert rejects photo 2 entirely');
select is(public.encounter_summary(pg_temp.uid(50))->>'confirmed_count','3','A rejected photo counts 0');
reset role;

-- The removal ownership rule (own detection) still applies.
select pg_temp.act(4);
set local role authenticated;
select throws_ok(pg_temp.removal(33,4,24,null,1),'42501',null,'A removal on another Diver''s photo is refused');
reset role;

-- Monthly visit: count from the visit photos, zero allowed, up to 10 photos.
update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(24);
insert into public.follow_up_assignments(id,area_id,primary_diver_id,originating_capture_id)
values(pg_temp.uid(60),pg_temp.uid(10),pg_temp.uid(3),pg_temp.uid(24));
select pg_temp.act(3);
set local role authenticated;
select lives_ok(pg_temp.photo(n,3,null),'Visit photo ' || n) from generate_series(70,80) n;
reset role;
select pg_temp.items(70, 0.95, 0.40);
select pg_temp.act(3);
set local role authenticated;
select throws_ok(format($q$select public.submit_follow_up_survey(%L,'STAGE1-TEST',%L,0,0,'Vinegar injection',100,%L::uuid[],null,null,'')$q$,
  pg_temp.uid(90),pg_temp.today(),array(select pg_temp.uid(n) from generate_series(70,80) n)),'23514',null,
  'A visit with 11 photos is refused');
select throws_ok(format($q$select public.submit_follow_up_survey(%L,'STAGE1-TEST',%L,0,0,'',100,%L::uuid[],null,null,'')$q$,
  pg_temp.uid(90),pg_temp.today(),array[pg_temp.uid(70)]),'23514','Record the removal method',
  'A visit with COTS needs a removal method');
select is(public.submit_follow_up_survey(pg_temp.uid(90),'STAGE1-TEST',pg_temp.today(),99,99,'Vinegar injection',100,
  array(select pg_temp.uid(n) from generate_series(70,79) n),null,null,''),'pending','A visit with 10 photos is saved');
select is((public.follow_up_surveys_json()->0->>'field_observed_count')::integer,2,
  'COTS found and removed comes from the photos (typed 99 is ignored)');
select is((public.follow_up_surveys_json()->0->>'field_eliminated_count')::integer,2,'Found equals removed');
select is((public.follow_up_surveys_json()->0->>'confirmed_count')::integer,1,'1 confirmed (95%), 1 waiting (40%)');
select is((public.follow_up_surveys_json()->0->>'waiting_count')::integer,1,'The 40% COTS waits for the Expert');
select is((public.follow_up_surveys_json()->0->>'density_per_ha')::numeric,100.00,
  'Density uses the confirmed count: 1 COTS over 100 m² is 100 COTS/ha');
reset role;

-- A visit with no COTS is accepted.
select pg_temp.act(3);
set local role authenticated;
select is(public.submit_follow_up_survey(pg_temp.uid(91),'STAGE1-TEST',pg_temp.today(),0,0,'',100,
  array[pg_temp.uid(80)],null,null,''),'pending','A visit with zero COTS is accepted');
reset role;

select ok(not has_function_privilege('anon','public.encounter_summary(uuid)','EXECUTE'),
  'Visitors who are not signed in cannot read encounters');
select ok(not has_function_privilege('authenticated','cots_private.capture_confirmed_count(uuid)','EXECUTE'),
  'Confirmed counts are only computed inside the database');

select * from finish();
rollback;
