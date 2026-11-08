-- Stage 3: honest reports. Synthetic fixtures only; everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('e0000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.act(n integer) returns void language sql as $$
  select set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true)
$$;
create function pg_temp.today() returns date language sql stable as $$
  select (now() at time zone 'Asia/Manila')::date
$$;
create function pg_temp.photo(n integer, o integer, a integer, e integer) returns text language sql as $$
  select format($q$insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
    model_name,model_sha256,source_width,source_height,gps_source,encounter_id)
    values(%L,%L,%L,%L,now(),'device','synthetic-test',repeat('a',64),2048,1536,'unavailable',%L)$q$,
    pg_temp.uid(n), pg_temp.uid(o), pg_temp.uid(n + 300), pg_temp.uid(a),
    case when e is null then null else pg_temp.uid(e) end)
$$;
create function pg_temp.encounter(n integer, o integer) returns text language sql as $$
  select format($q$insert into public.encounters(id,owner_id,idempotency_key) values(%L,%L,%L)$q$,
    pg_temp.uid(n), pg_temp.uid(o), pg_temp.uid(n + 300))
$$;
create function pg_temp.removal(id integer, o integer, cap integer, e integer, removed integer, how text) returns text language sql as $$
  select format($q$insert into public.eliminations(id,owner_id,idempotency_key,capture_id,encounter_id,captured_at,
    removed_count,method,gps_source) values(%L,%L,%L,%L,%L,now(),%s,%L,'unavailable')$q$,
    pg_temp.uid(id), pg_temp.uid(o), pg_temp.uid(id + 300), pg_temp.uid(cap),
    case when e is null then null else pg_temp.uid(e) end, removed, how)
$$;
create function pg_temp.items(cap integer, variadic conf numeric[]) returns void language sql as $$
  insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
  select ('e1000000-0000-4000-' || lpad(cap::text,4,'0') || '-' || lpad(i::text,12,'0'))::uuid,
    pg_temp.uid(cap), i - 1, conf[i], 10 + i * 120, 10, 100 + i * 120, 100
  from generate_subscripts(conf, 1) i
$$;
create function pg_temp.item(cap integer, i integer) returns text language sql immutable as $$
  select 'e1000000-0000-4000-' || lpad(cap::text,4,'0') || '-' || lpad(i::text,12,'0')
$$;
create function pg_temp.counts(cap integer) returns integer[] language sql as $$
  select array[public.confirmed_cots(c), public.waiting_cots(c)] from public.captures c where c.id = pg_temp.uid(cap)
$$;

-- 1 Admin, 2 Expert, 3 Diver A, 4 Diver B.
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'stage3-' || n || '@example.invalid',now() from generate_series(1,4) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select pg_temp.act(1);
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
select public.verify_personnel(pg_temp.uid(n),true,true) from generate_series(3,4) n;
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
reset role;
insert into public.monitoring_areas(id,code,name,geography_version) values
  (pg_temp.uid(10),'STAGE3-TEST','Stage Three Reef','test-only'),
  (pg_temp.uid(11),'STAGE3-OTHER','Other Reef','test-only');

-- Diver A's zone (area 10), assigned from an earlier finalized photo.
select pg_temp.act(3);
set local role authenticated;
select lives_ok(pg_temp.photo(24,3,10,null),'Zone origin photo');
reset role;
update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(24);
insert into public.follow_up_assignments(id,area_id,primary_diver_id,originating_capture_id)
values(pg_temp.uid(60),pg_temp.uid(10),pg_temp.uid(3),pg_temp.uid(24));

-- Diver A's records.
select pg_temp.act(3);
set local role authenticated;
select lives_ok(pg_temp.encounter(50,3),'Encounter 1 (vinegar)');
select lives_ok(pg_temp.photo(20,3,10,50),'Encounter 1 photo 1');
select lives_ok(pg_temp.photo(21,3,10,50),'Encounter 1 photo 2');
select lives_ok(pg_temp.encounter(51,3),'Encounter 2 (manual, will be rejected)');
select lives_ok(pg_temp.photo(22,3,10,51),'Encounter 2 photo');
select lives_ok(pg_temp.encounter(52,3),'Encounter 3 (ox bile, other reef)');
select lives_ok(pg_temp.photo(23,3,11,52),'Encounter 3 photo');
select lives_ok(pg_temp.photo(25,3,10,null),'An older single-photo record');
select lives_ok(pg_temp.photo(70,3,10,null),'Monthly visit photo');
reset role;
select pg_temp.items(20, 0.95, 0.55);
select pg_temp.items(21, 0.90);
select pg_temp.items(22, 0.85);
select pg_temp.items(23, 0.95, 0.92);
select pg_temp.items(25, 0.95);
select pg_temp.items(70, 0.95, 0.10);
select pg_temp.act(3);
set local role authenticated;
select lives_ok(pg_temp.removal(30,3,20,50,3,'Vinegar Injection'),'Encounter 1 removal');
select lives_ok(pg_temp.removal(31,3,22,51,1,'Manual Removal'),'Encounter 2 removal');
select lives_ok(pg_temp.removal(32,3,23,52,2,'Ox Bile / Bile Salts Injection'),'Encounter 3 removal');
select lives_ok(pg_temp.removal(33,3,25,null,1,'Community Cleanup'),'Older removal with an old method');
select is(public.submit_follow_up_survey(pg_temp.uid(90),'STAGE3-TEST',pg_temp.today(),0,0,'Vinegar Injection',100,
  array[pg_temp.uid(70)],null,null,''),'pending','Monthly visit with vinegar');

-- Per-photo numbers the app reads.
select is(pg_temp.counts(20),array[1,1],'Photo 1 before review: 1 confirmed (95%), 1 waiting (55%)');
select is(pg_temp.counts(70),array[1,0],'Visit photo: the 10% box is not accepted');
reset role;

-- Diver B's record in Diver A's zone waits for the Expert (Stage 2).
select pg_temp.act(4);
set local role authenticated;
select lives_ok(pg_temp.encounter(53,4),'Diver B encounter in A''s zone');
select lives_ok(pg_temp.photo(26,4,10,53),'Diver B photo');
reset role;
select pg_temp.items(26, 0.95);
select pg_temp.act(4);
set local role authenticated;
select lives_ok(pg_temp.removal(34,4,26,53,1,'Manual Removal'),'Diver B removal');
select is(pg_temp.counts(26),array[0,1],'Another Diver''s record: 0 confirmed, 1 waiting until approved');
reset role;

-- Expert review changes the confirmed numbers.
select pg_temp.act(2);
set local role authenticated;
select lives_ok(format($q$select public.record_expert_decision(%L,null,'approve','Reviewed',null,%L)$q$,
  pg_temp.uid(20), jsonb_build_array(jsonb_build_object('item_id',pg_temp.item(20,2),'decision','approve'))),
  'Expert approves the 55% COTS');
select lives_ok(format($q$select public.record_expert_decision(%L,null,'reject','Not COTS',null,'[]'::jsonb)$q$,
  pg_temp.uid(22)),'Expert rejects encounter 2''s photo');
select is(pg_temp.counts(20),array[2,0],'Photo 1 after review: 2 confirmed');
select is(pg_temp.counts(22),array[0,0],'Rejected photo: 0 confirmed, 0 waiting');

-- Removal methods: confirmed COTS and number of removals per method.
select is(public.removal_method_summary(),
  jsonb_build_array(
    jsonb_build_object('method','Vinegar Injection','cots',4,'removals',2),
    jsonb_build_object('method','Ox Bile / Bile Salts Injection','cots',2,'removals',1),
    jsonb_build_object('method','Community Cleanup','cots',1,'removals',1)),
  'Vinegar 4 (encounter 3 + visit 1), Ox bile 2, old method kept; rejected and waiting removals are not counted');
select is(public.removal_method_summary(null,null,'Other Reef'),
  jsonb_build_array(jsonb_build_object('method','Ox Bile / Bile Salts Injection','cots',2,'removals',1)),
  'The zone filter applies');
select is(public.removal_method_summary(pg_temp.today() + 1, null, null),'[]'::jsonb,'The date filter applies');
select is(jsonb_array_length(public.removal_method_summary(pg_temp.today(), pg_temp.today(), null)),3,
  'Today''s removals are included');
reset role;

-- After approval, Diver B's removal counts under Manual.
select pg_temp.act(2);
set local role authenticated;
select lives_ok(format($q$select public.record_expert_decision(%L,null,'approve','Right place, real COTS',null,'[]'::jsonb)$q$,
  pg_temp.uid(26)),'Expert approves Diver B''s record');
select is(pg_temp.counts(26),array[1,0],'Approved: 1 confirmed');
select is((select e->>'cots' from jsonb_array_elements(public.removal_method_summary()) e where e->>'method'='Manual Removal'),
  '1','Diver B''s approved removal now counts');
reset role;

-- Who may read.
select pg_temp.act(3);
set local role authenticated;
select throws_ok($q$select public.removal_method_summary()$q$,'42501',null,'Divers cannot read the method summary');
reset role;
select pg_temp.act(1);
set local role authenticated;
select lives_ok($q$select public.removal_method_summary()$q$,'Administrators can read the method summary');
reset role;
select ok(not has_function_privilege('anon','public.removal_method_summary(date,date,text)','EXECUTE'),
  'Visitors who are not signed in cannot read the summary');
select ok(not has_function_privilege('anon','public.confirmed_cots(public.captures)','EXECUTE'),
  'Visitors who are not signed in cannot read counts');

select * from finish();
rollback;
