-- Per-photo policy protects historical totals while new photos use 85 percent.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('85000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'confidence-' || n || '@example.invalid',now() from generate_series(1,3) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
set local role authenticated;
select public.verify_personnel(pg_temp.uid(3),true,true);
reset role;

insert into public.monitoring_areas(id,code,name,geography_version)
values(pg_temp.uid(10),'CONFIDENCE-TEST','Confidence test site','test-only');
insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
  model_name,model_sha256,source_width,source_height,gps_source,latitude,longitude)
values(pg_temp.uid(20),pg_temp.uid(3),pg_temp.uid(20),pg_temp.uid(10),now()-interval '1 hour','exif',
  'synthetic-test',repeat('a',64),2048,1536,'exif',7.29,125.70);
-- Represents a pre-upgrade photo. Only the test superuser can set this column.
insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
  model_name,model_sha256,source_width,source_height,gps_source,latitude,longitude,auto_approve_min)
values(pg_temp.uid(30),pg_temp.uid(3),pg_temp.uid(30),pg_temp.uid(10),now()-interval '2 days','exif',
  'synthetic-test',repeat('a',64),2048,1536,'exif',7.29,125.70,80);
insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
select pg_temp.uid((100+n)::integer),pg_temp.uid(20),(n-1)::integer,score,10,10,100,100
from unnest(array[0, .19, .20, .79, .80, .84, .85, 1]::numeric[]) with ordinality as x(score,n);
insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
values(pg_temp.uid(31),pg_temp.uid(30),0,.82,10,10,100,100);

select is((select auto_approve_min::integer from public.captures where id=pg_temp.uid(20)),85,
  'New photos receive the server-controlled 85 percent policy');
select ok(not has_column_privilege('authenticated','public.captures','auto_approve_min','INSERT'),
  'Clients cannot choose a lower acceptance threshold');
select ok(not has_column_privilege('authenticated','public.captures','auto_approve_min','UPDATE'),
  'Clients cannot change the historical policy');
select is(cots_private.accepted_detection_count(pg_temp.uid(20),'[]'),2::bigint,
  'Only 85 and 100 percent count automatically');
select is(cots_private.capture_waiting_count(pg_temp.uid(20)),4,
  '20, 79, 80 and 84 percent wait for Expert review');
select is(cots_private.accepted_detection_count(pg_temp.uid(30),'[]'),1::bigint,
  'An old 82 percent detection keeps its original accepted count');
select is(cots_private.capture_waiting_count(pg_temp.uid(30)),0,
  'An old 82 percent detection does not newly require review');

select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
set local role authenticated;
select throws_ok(format($q$select public.record_expert_decision(%L,null,'approve','Missing new review band',null,
  jsonb_build_array(jsonb_build_object('item_id',%L,'decision','approve'),jsonb_build_object('item_id',%L,'decision','approve')))$q$,
  pg_temp.uid(20),pg_temp.uid(103),pg_temp.uid(104)),
  '23514',null,'Approval cannot skip the 80 and 84 percent detections');
select throws_ok(format($q$select public.record_expert_decision(%L,null,'approve','Cannot accept low confidence',null,
  (select jsonb_agg(jsonb_build_object('item_id',id::text,'decision','approve')) from public.detection_items where capture_id=%L))$q$,
  pg_temp.uid(20),pg_temp.uid(20)),
  '23514',null,'0 and 19 percent cannot be accepted by an Expert');
select lives_ok(format($q$select public.record_expert_decision(%L,null,'approve','Reviewed all uncertain items',null,
  (select jsonb_agg(jsonb_build_object('item_id',id::text,'decision',case when item_index=4 then 'reject' else 'approve' end))
   from public.detection_items where capture_id=%L and item_index between 2 and 5))$q$,
  pg_temp.uid(20),pg_temp.uid(20)),
  'Expert can approve or reject each item from 20 through 84 percent');
reset role;
select is(cots_private.capture_confirmed_count(pg_temp.uid(20)),5,
  'Totals include two automatic and three Expert-accepted detections');
select is(cots_private.capture_waiting_count(pg_temp.uid(20)),0,
  'No items remain waiting after complete review');
select is(cots_private.capture_confirmed_count(pg_temp.uid(30)),1,
  'Review of new photos does not change historical totals');

-- Exercise the full submission path at 84 and 85, including notifications.
insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
  model_name,model_sha256,source_width,source_height,gps_source)
select pg_temp.uid(n),pg_temp.uid(3),pg_temp.uid(n),pg_temp.uid(10),now()-interval '1 hour','device',
  'synthetic-test',repeat('a',64),2048,1536,'unavailable' from unnest(array[40,50]) n;
insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
values(pg_temp.uid(41),pg_temp.uid(40),0,.84,10,10,100,100),
      (pg_temp.uid(51),pg_temp.uid(50),0,.85,10,10,100,100);
insert into public.media_assets(id,owner_id,idempotency_key,original_name,original_sha256,original_bytes,
  raw_width,raw_height,source_width,source_height,captured_at,capture_time_source)
select pg_temp.uid(n+1000),pg_temp.uid(3),pg_temp.uid(n+1000),'synthetic.jpg',repeat('b',64),1000,
  2048,1536,2048,1536,now(),'device' from unnest(array[40,50]) n;
insert into public.media_variants(id,asset_id,kind,version,bucket,object_path,width,height,byte_size,sha256,encoder,
  upload_status,uploaded_at,verified_at,verification_receipt)
select pg_temp.uid(n+2000),pg_temp.uid(n+1000),'evidence',1,'detection-evidence',
  pg_temp.uid(3)::text || '/' || pg_temp.uid(n+1000)::text || '/' || pg_temp.uid(n+2000)::text,
  2048,1536,400,repeat('c',64),'synthetic','verified',now(),now(),'synthetic-receipt'
from unnest(array[40,50]) n;
insert into public.capture_evidence
select pg_temp.uid(n),pg_temp.uid(n+2000) from unnest(array[40,50]) n;
select ok(exists(select 1 from public.workflow_events where capture_id=pg_temp.uid(40) and action='review_needed'),
  'An 84 percent submission notifies the Expert');
select ok(not exists(select 1 from public.workflow_events where capture_id=pg_temp.uid(50) and action='review_needed'),
  'An 85 percent submission needs no confidence-review notice');
select throws_ok(format('select public.finalize_capture(%L)',pg_temp.uid(40)),
  '23514','Expert review required','An 84 percent photo cannot finalize without review');
select lives_ok(format('select public.finalize_capture(%L)',pg_temp.uid(50)),
  'An 85 percent photo can finalize after its evidence is verified');
select is((select status from public.captures where id=pg_temp.uid(50)),'finalized',
  'The 85 percent photo is finalized');
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
set local role authenticated;
select lives_ok(format($q$select public.record_expert_decision(%L,null,'approve','Confirmed by Expert',null,
  jsonb_build_array(jsonb_build_object('item_id',%L,'decision','approve')))$q$,pg_temp.uid(40),pg_temp.uid(41)),
  'Expert approval permits the 84 percent photo');
reset role;
select is((select status from public.captures where id=pg_temp.uid(40)),'finalized',
  'The reviewed 84 percent photo is finalized by the existing finish trigger');
select * from finish();
rollback;
