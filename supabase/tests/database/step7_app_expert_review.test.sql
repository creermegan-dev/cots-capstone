-- Expert review payloads exactly as the Flutter app sends them.
-- Synthetic fixtures only; everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('70000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
-- The app sends approve for confirmed items, reject for rejected ones, and
-- leaves pending items out (buildExpertItemResults).
create function pg_temp.app_items(variadic pairs text[]) returns jsonb
language sql immutable as $$
  select coalesce(jsonb_agg(jsonb_build_object('item_id', pairs[i], 'decision', pairs[i+1])), '[]'::jsonb)
  from generate_subscripts(pairs, 1) as i where i % 2 = 1
$$;

insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'review-' || n || '@example.invalid',now() from generate_series(1,3) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
select public.verify_personnel(pg_temp.uid(3),true,true);
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
reset role;

insert into public.monitoring_areas(id,code,name,geography_version)
values(pg_temp.uid(10),'REVIEW-TEST','Synthetic review area','test-only');
insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
  model_name,model_sha256,source_width,source_height,gps_source,latitude,longitude)
values(pg_temp.uid(20),pg_temp.uid(3),pg_temp.uid(20),pg_temp.uid(10),now()-interval '1 hour','exif',
  'synthetic-test',repeat('a',64),2048,1536,'exif',7.29,125.70),
      (pg_temp.uid(30),pg_temp.uid(3),pg_temp.uid(30),pg_temp.uid(10),now()-interval '1 hour','exif',
  'synthetic-test',repeat('a',64),2048,1536,'device_surface',7.29,125.70);
-- Capture 20: one auto-accepted (92%), one review-band (55%), one too low (12%).
insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2) values
  (pg_temp.uid(21),pg_temp.uid(20),0,0.92,10,10,100,100),
  (pg_temp.uid(22),pg_temp.uid(20),1,0.55,120,120,220,220),
  (pg_temp.uid(23),pg_temp.uid(20),2,0.12,300,300,400,400),
  (pg_temp.uid(31),pg_temp.uid(30),0,0.60,10,10,100,100);

select is((select gps_source from public.captures where id=pg_temp.uid(30)),'device_surface',
  'Phone-sourced location is stored with its true source');

-- The Administrator cannot record Expert decisions.
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
set local role authenticated;
select throws_ok(format($q$select public.record_expert_decision(%L,null,'approve','Admin attempt',null,%L)$q$,
  pg_temp.uid(20), pg_temp.app_items(pg_temp.uid(21)::text,'approve',pg_temp.uid(22)::text,'approve',pg_temp.uid(23)::text,'reject')),
  '42501','Expert required','Administrator cannot record an Expert decision');
reset role;

select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
set local role authenticated;
-- A review-band COTS left pending is refused.
select throws_ok(format($q$select public.record_expert_decision(%L,null,'approve','Missing one',null,%L)$q$,
  pg_temp.uid(20), pg_temp.app_items(pg_temp.uid(21)::text,'approve',pg_temp.uid(23)::text,'reject')),
  '23514',null,'Approval without deciding every 20-79% COTS is refused');
-- The exact approval payload the app sends.
select lives_ok(format($q$select public.record_expert_decision(%L,null,'approve','Approved after per-COTS review.',null,%L)$q$,
  pg_temp.uid(20), pg_temp.app_items(pg_temp.uid(21)::text,'approve',pg_temp.uid(22)::text,'approve',pg_temp.uid(23)::text,'reject')),
  'App approval payload is accepted');
-- The exact rejection payload the app sends (no per-item list).
select lives_ok(format($q$select public.record_expert_decision(%L,null,'reject','Rejected after review.',null,'[]'::jsonb)$q$,
  pg_temp.uid(30)),
  'App rejection payload is accepted');
reset role;

select is((select decision from public.expert_decisions where capture_id=pg_temp.uid(20)),'approve',
  'Approval is stored');
select is((select jsonb_array_length(item_decisions) from public.expert_decisions where capture_id=pg_temp.uid(20)),3,
  'Every on-screen decision is stored');
select is(cots_private.accepted_detection_count(pg_temp.uid(20),
    (select item_decisions from public.expert_decisions where capture_id=pg_temp.uid(20))),2::bigint,
  'Two COTS count as accepted (92% and the approved 55%)');
select is((select status from public.captures where id=pg_temp.uid(20)),'pending',
  'Decision alone does not finalize; the trusted worker does');
select is((select count(*)::integer from public.audit_events where action='expert_decision'),2,
  'Both decisions are audited');

-- The Diver who owns the record can read the decisions (shown in the app).
select set_config('request.jwt.claim.sub',pg_temp.uid(3)::text,true);
set local role authenticated;
select is((select count(*)::integer from public.expert_decisions),2,
  'Owner can read decisions on their own records');
select throws_ok(format($q$select public.record_expert_decision(%L,null,'reject','Self review',null,'[]'::jsonb)$q$,
  pg_temp.uid(20)),'42501','Expert required','Diver cannot review their own record');
reset role;

-- Decisions are permanent history.
select throws_ok($q$update public.expert_decisions set decision='reject'$q$,'23514',null,
  'Recorded decisions cannot be edited');

-- With device verification, an Expert session on an untrusted device is refused.
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', pg_temp.uid(2), 'role', 'authenticated',
  'session_id', '71000000-0000-4000-8000-000000000099')::text, true);
set local role authenticated;
select throws_ok(format($q$select public.record_expert_decision(%L,null,'reject','Untrusted device',null,'[]'::jsonb)$q$,
  pg_temp.uid(20)),'42501','Expert required','Expert on an unverified device cannot decide');
reset role;

select * from finish();
rollback;
