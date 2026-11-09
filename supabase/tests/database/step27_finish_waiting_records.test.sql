-- Records stuck in "Processing evidence": finished by the database after the Expert's decision. Rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('d2700000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.act(n integer) returns void language sql as $$
  select set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true)
$$;
-- Capture n by Diver o in area a, photo taken "age" ago, with COTS confidences.
create function pg_temp.capture(n integer, o integer, a integer, age interval, variadic conf numeric[])
returns void language sql as $$
  insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
    model_name,model_sha256,source_width,source_height,gps_source)
  values(pg_temp.uid(n),pg_temp.uid(o),pg_temp.uid(n+500),pg_temp.uid(a),now()-age,'device',
    'synthetic-test',repeat('a',64),2048,1536,'unavailable');
  insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
  select ('d2710000-0000-4000-' || lpad(n::text,4,'0') || '-' || lpad(i::text,12,'0'))::uuid,
    pg_temp.uid(n), i - 1, conf[i], 10 + i * 120, 10, 100 + i * 120, 100
  from generate_subscripts(conf, 1) i;
$$;
-- Verified photo evidence for capture n (this is what "submitted" means).
create function pg_temp.evidence(n integer, o integer) returns void language sql as $$
  insert into public.media_assets(id,owner_id,idempotency_key,original_name,original_sha256,original_bytes,
    raw_width,raw_height,source_width,source_height,captured_at,capture_time_source)
  values(pg_temp.uid(n+1000),pg_temp.uid(o),pg_temp.uid(n+1000),'synthetic.jpg',repeat('b',64),1000,
    2048,1536,2048,1536,now(),'device');
  insert into public.media_variants(id,asset_id,kind,version,bucket,object_path,width,height,byte_size,sha256,encoder,
    upload_status,uploaded_at,verified_at,verification_receipt)
  values(pg_temp.uid(n+2000),pg_temp.uid(n+1000),'evidence',1,'detection-evidence',
    pg_temp.uid(o)::text || '/' || pg_temp.uid(n+1000)::text || '/' || pg_temp.uid(n+2000)::text,
    2048,1536,400,repeat('c',64),'synthetic','verified',now(),now(),'synthetic-receipt');
  insert into public.capture_evidence values(pg_temp.uid(n),pg_temp.uid(n+2000));
$$;
create function pg_temp.status(n integer) returns text language sql as $$
  select status from public.captures where id = pg_temp.uid(n)
$$;
create function pg_temp.job(n integer) returns text language sql as $$
  select state from cots_private.evidence_verification_jobs where variant_id = pg_temp.uid(n+2000)
$$;

-- 1 Admin, 2 Expert, 3 Diver.
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'finish-' || n || '@example.invalid',now() from generate_series(1,3) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select pg_temp.act(2);
set local role authenticated;
select public.verify_personnel(pg_temp.uid(3),true,true);
reset role;
insert into public.monitoring_areas(id,code,name,geography_version) values (pg_temp.uid(10),'F-A','Finish Reef','test-only');

-- Capture 20: COTS at 90% and 50% (needs the Expert), photo verified, the worker left it waiting.
select pg_temp.capture(20,3,10,interval '1 hour',0.90,0.50);
select pg_temp.evidence(20,3);
update cots_private.evidence_verification_jobs set state='waiting_prerequisite', next_attempt_at=now()+interval '6 hours'
where variant_id = pg_temp.uid(2020);
select is(pg_temp.status(20), 'pending', 'Before: the record waits ("Processing evidence")');
select is(cots_private.finish_waiting_records(), 0, 'The 10-minute run cannot finish it before the Expert decides');
select is(pg_temp.status(20), 'pending', 'still waiting for the Expert');

-- The Expert accepts both COTS: the record finishes at once (no worker needed).
select pg_temp.act(2);
set local role authenticated;
select public.record_expert_decision(pg_temp.uid(20), null, 'approve', 'ok', null,
  (select jsonb_agg(jsonb_build_object('item_id', id, 'decision', 'approve')) from public.detection_items where capture_id = pg_temp.uid(20)));
reset role;
select is(pg_temp.status(20), 'finalized', 'After the Expert decides, the record is finished immediately');
select is(pg_temp.job(20), 'verified', 'and its photo-check job is closed');

-- Capture 21: 95% only (no Expert needed), photo verified, job left waiting by an earlier problem.
select pg_temp.capture(21,3,10,interval '50 minutes',0.95);
select pg_temp.evidence(21,3);
update cots_private.evidence_verification_jobs set state='waiting_prerequisite' where variant_id = pg_temp.uid(2021);
select is(cots_private.finish_waiting_records(), 1, 'The 10-minute run finishes a record whose prerequisites are now met');
select is(pg_temp.status(21), 'finalized', 'that record is finished');

-- Capture 22: photo NOT verified: never finished by the database.
select pg_temp.capture(22,3,10,interval '40 minutes',0.95);
insert into public.media_assets(id,owner_id,idempotency_key,original_name,original_sha256,original_bytes,
  raw_width,raw_height,source_width,source_height,captured_at,capture_time_source)
values(pg_temp.uid(1022),pg_temp.uid(3),pg_temp.uid(1022),'synthetic.jpg',repeat('b',64),1000,2048,1536,2048,1536,now(),'device');
insert into public.media_variants(id,asset_id,kind,version,bucket,object_path,width,height,byte_size,sha256,encoder,upload_status)
values(pg_temp.uid(2022),pg_temp.uid(1022),'evidence',1,'detection-evidence',
  pg_temp.uid(3)::text || '/' || pg_temp.uid(1022)::text || '/' || pg_temp.uid(2022)::text,
  2048,1536,400,repeat('c',64),'synthetic','reserved');
insert into public.capture_evidence values(pg_temp.uid(22),pg_temp.uid(2022));
select is(cots_private.finish_waiting_records(), 0, 'A record whose photo is not verified is left for the photo check');
select is(pg_temp.status(22), 'pending', 'and stays pending');

select ok(not has_function_privilege('authenticated','cots_private.finish_waiting_records(integer)','EXECUTE'),
  'The app cannot run it');
select * from finish();
rollback;
