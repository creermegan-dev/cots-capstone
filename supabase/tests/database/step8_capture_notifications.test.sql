-- Database-created notifications for detections. Synthetic; rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('80000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.notices(person uuid) returns text[] language sql as $$
  select coalesce(array_agg(e.action order by e.created_at, e.action), '{}')
  from public.notifications n join public.workflow_events e on e.id = n.event_id
  where n.recipient_id = person
$$;

insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'notice-' || n || '@example.invalid',now() from generate_series(1,4) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
select public.verify_personnel(pg_temp.uid(3),true,true);
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
select public.verify_personnel(pg_temp.uid(4),true,true);
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
reset role;

insert into public.monitoring_areas(id,code,name,geography_version)
values(pg_temp.uid(10),'NOTICE-TEST','Test Reef','test-only');

-- Capture 20 needs review (55%); capture 40 is automatic (95%).
insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
  model_name,model_sha256,source_width,source_height,gps_source)
values
  (pg_temp.uid(20),pg_temp.uid(3),pg_temp.uid(20),pg_temp.uid(10),now()-interval '1 hour','device',
   'synthetic-test',repeat('a',64),2048,1536,'unavailable'),
  (pg_temp.uid(40),pg_temp.uid(3),pg_temp.uid(40),pg_temp.uid(10),now()-interval '1 hour','device',
   'synthetic-test',repeat('a',64),2048,1536,'unavailable');
insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2) values
  (pg_temp.uid(21),pg_temp.uid(20),0,0.55,10,10,100,100),
  (pg_temp.uid(41),pg_temp.uid(40),0,0.95,10,10,100,100);
insert into public.media_assets(id,owner_id,idempotency_key,original_name,original_sha256,original_bytes,
  raw_width,raw_height,source_width,source_height,captured_at,capture_time_source)
select pg_temp.uid(n),pg_temp.uid(3),pg_temp.uid(n),'synthetic.jpg',repeat('b',64),1000,2048,1536,2048,1536,now(),'device'
from unnest(array[30,50]) n;
insert into public.media_variants(id,asset_id,kind,version,bucket,object_path,width,height,byte_size,sha256,encoder)
select pg_temp.uid(n+1),pg_temp.uid(n),'evidence',1,'detection-evidence',
  pg_temp.uid(3)::text || '/' || pg_temp.uid(n)::text || '/' || pg_temp.uid(n+1)::text,2048,1536,400,repeat('c',64),'synthetic'
from unnest(array[30,50]) n;

insert into public.capture_evidence values(pg_temp.uid(20),pg_temp.uid(31));
insert into public.capture_evidence values(pg_temp.uid(40),pg_temp.uid(51));

select is(pg_temp.notices(pg_temp.uid(3)), array['scan_submitted','scan_submitted'],
  'Owner is told each submission arrived');
select is(pg_temp.notices(pg_temp.uid(2)), array['review_needed'],
  'Expert is told only about the detection that needs review');
select is(pg_temp.notices(pg_temp.uid(1)), '{}'::text[],
  'Administrator is not notified about routine submissions');
select ok((select e.details->>'body' from public.workflow_events e
  where e.capture_id=pg_temp.uid(20) and e.action='scan_submitted') like '%waiting for Expert review%',
  'Owner is told the detection waits for review');
select is((select e.details->>'record_id' from public.workflow_events e
  where e.capture_id=pg_temp.uid(20) and e.action='scan_submitted'),
  'CAP-' || upper(left(pg_temp.uid(20)::text,8)),
  'Record label matches the app''s CAP- label');

-- Expert approves: the owner is told.
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
set local role authenticated;
select public.record_expert_decision(pg_temp.uid(20),null,'approve','Clear photo',null,
  jsonb_build_array(jsonb_build_object('item_id',pg_temp.uid(21)::text,'decision','approve')));
reset role;
select ok('review_accepted' = any(pg_temp.notices(pg_temp.uid(3))), 'Owner is told the Expert approved');

-- Worker finalizes: automatic record notifies; reviewed one does not repeat.
update public.captures set status='finalized', finalized_at=now() where id in (pg_temp.uid(20),pg_temp.uid(40));
select is((select count(*)::integer from public.workflow_events where action='record_finalized'),1,
  'Only the automatic record gets a separate "verified" notice');

-- Reading and privacy.
select set_config('request.jwt.claim.sub',pg_temp.uid(3)::text,true);
set local role authenticated;
select is((select count(*)::integer from public.notifications),4,'Owner sees their 4 notifications');
select is((select count(*)::integer from public.workflow_events where capture_id is not null),4,
  'Owner can read the events behind their notifications');
select is(public.mark_all_notifications_read(),4,'Mark all as read');
select is((select count(*)::integer from public.notifications where read_at is null),0,'Nothing unread');
select is(public.dismiss_notifications(array(select id from public.notifications limit 2)),2,
  'Dismiss two notifications');
select is((select count(*)::integer from public.notifications where dismissed_at is null),2,
  'Two remain in the list');
select throws_ok($q$delete from public.notifications$q$,'42501',null,'Notifications cannot be deleted');
select throws_ok($q$insert into public.notifications(recipient_id,event_id)
  select recipient_id,event_id from public.notifications limit 1$q$,'42501',null,
  'People cannot create notifications');
reset role;

-- A session from an unverified device sees nothing.
select set_config('request.jwt.claims', jsonb_build_object('sub',pg_temp.uid(3)::text,'role','authenticated',
  'session_id','80000000-0000-4000-8000-000000000999')::text, true);
set local role authenticated;
select is((select count(*)::integer from public.notifications),0,'Unverified device sees no notifications');
reset role;
select set_config('request.jwt.claims', '', true);

select set_config('request.jwt.claim.sub',pg_temp.uid(4)::text,true);
set local role authenticated;
select is((select count(*)::integer from public.notifications),0,'Another Diver sees none of them');
select is((select count(*)::integer from public.workflow_events where capture_id is not null),0,
  'Another Diver cannot read the events');
select is(public.dismiss_notifications(array(select n.id from public.notifications n)),0,
  'Another Diver cannot dismiss them');
reset role;

-- A second evidence link does not repeat the submission notice.
insert into public.media_assets(id,owner_id,idempotency_key,original_name,original_sha256,original_bytes,
  raw_width,raw_height,source_width,source_height,captured_at,capture_time_source)
values(pg_temp.uid(60),pg_temp.uid(3),pg_temp.uid(60),'extra.jpg',repeat('b',64),1000,2048,1536,2048,1536,now(),'device');
insert into public.media_variants(id,asset_id,kind,version,bucket,object_path,width,height,byte_size,sha256,encoder)
values(pg_temp.uid(61),pg_temp.uid(60),'supplement',1,'detection-evidence',
  pg_temp.uid(3)::text || '/' || pg_temp.uid(60)::text || '/' || pg_temp.uid(61)::text,2048,1536,400,repeat('c',64),'synthetic');
insert into public.capture_evidence values(pg_temp.uid(20),pg_temp.uid(61));
select is((select count(*)::integer from public.workflow_events
  where capture_id=pg_temp.uid(20) and action='scan_submitted'),1,'Submission notice is sent once');

select ok(not has_function_privilege('authenticated',
  'cots_private.notify_capture(uuid,text,text,text,uuid[])','EXECUTE'),
  'People cannot call the notification writer directly');

select * from finish();
rollback;
