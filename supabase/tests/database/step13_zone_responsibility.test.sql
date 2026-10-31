-- Stage 2: zone responsibility. Synthetic fixtures only; everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('d0000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
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
  select ('d1000000-0000-4000-' || lpad(n::text,4,'0') || '-' || lpad(i::text,12,'0'))::uuid,
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
create function pg_temp.notices(person integer) returns text[] language sql as $$
  select coalesce(array_agg(e.action order by e.created_at, e.action), '{}')
  from public.notifications n join public.workflow_events e on e.id = n.event_id
  where n.recipient_id = pg_temp.uid(person)
$$;
-- Zone notices only (setting up the fixtures sends unrelated notices).
create function pg_temp.zone_notices(person integer) returns text[] language sql as $$
  select coalesce(array_agg(e.action order by e.created_at, e.action), '{}')
  from public.notifications n join public.workflow_events e on e.id = n.event_id
  where n.recipient_id = pg_temp.uid(person) and e.action like 'zone%'
$$;
create function pg_temp.body(cap integer, action_name text) returns text language sql as $$
  select e.details->>'body' from public.workflow_events e
  where e.capture_id = pg_temp.uid(cap) and e.action = action_name order by e.created_at desc limit 1
$$;
create function pg_temp.month_start(age interval) returns date language sql stable as $$
  select date_trunc('month', (now() - age) at time zone 'Asia/Manila')::date
$$;

-- 1 Admin, 2 Expert, 3 Diver A (original), 4 Diver B (other), 5 Diver C (replacement).
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'stage2-' || n || '@example.invalid',now() from generate_series(1,5) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select pg_temp.act(1);
set local role authenticated;
select public.verify_personnel(pg_temp.uid(n),true,true) from generate_series(3,5) n;
reset role;
update public.profiles set full_name = case id
  when pg_temp.uid(3) then 'Diver Alpha' when pg_temp.uid(4) then 'Diver Bravo'
  when pg_temp.uid(5) then 'Diver Charlie' else full_name end;
insert into public.monitoring_areas(id,code,name,geography_version) values
  (pg_temp.uid(10),'STAGE2-TEST','Stage Two Reef','test-only'),
  (pg_temp.uid(11),'STAGE2-LATE','Late Reef','test-only');

-- Diver A's first COTS photo (60 days ago) assigned the zone.
select pg_temp.capture(20,3,10,interval '60 days',0.95);
update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(20);
insert into public.follow_up_assignments(id,area_id,primary_diver_id,originating_capture_id)
values(pg_temp.uid(60),pg_temp.uid(10),pg_temp.uid(3),pg_temp.uid(20));
-- Diver C accepted the month of 35 days ago as replacement.
insert into public.monthly_authorizations(assignment_id,month,responsible_diver_id)
values(pg_temp.uid(60),pg_temp.month_start(interval '35 days'),pg_temp.uid(5));

-- Who needs approval.
select pg_temp.capture(30,4,10,interval '70 days',0.95);   -- B, before the zone was assigned
select pg_temp.capture(31,4,10,interval '1 hour',0.95);    -- B, after (AI very sure)
select pg_temp.capture(32,3,10,interval '35 days',0.95);   -- A during C's month
select pg_temp.capture(33,5,10,interval '35 days',0.95);   -- C in the month C covers
select pg_temp.capture(34,5,10,interval '1 hour',0.95);    -- C outside that month
select pg_temp.capture(35,4,10,interval '35 days',0.95);   -- B during C's month
select is(cots_private.zone_review_needed(pg_temp.uid(30)),false,'A photo taken before the zone was assigned is accepted normally');
select is(cots_private.zone_review_needed(pg_temp.uid(31)),true,'Another Diver''s later photo needs Expert approval, even at 95%');
select is(cots_private.zone_review_needed(pg_temp.uid(20)),false,'The zone''s first photo is not another Diver''s record');
select is(cots_private.zone_review_needed(pg_temp.uid(32)),false,'The original Diver submits normally, even in a replacement month');
select is(cots_private.zone_review_needed(pg_temp.uid(33)),false,'The replacement submits normally in the month they cover');
select is(cots_private.zone_review_needed(pg_temp.uid(34)),true,'The replacement needs approval outside that month');
select is(cots_private.zone_responsible_name(pg_temp.uid(31)),'Diver Alpha','This month the zone is assigned to Diver A');
select is(cots_private.zone_responsible_name(pg_temp.uid(35)),'Diver Charlie','In the replacement month it is assigned to Diver C');

-- Submitting: B is told who the zone is assigned to; Experts get an approval notice.
select pg_temp.evidence(31,4);
select is(pg_temp.body(31,'scan_submitted'),
  'Your report ' || cots_private.capture_label(pg_temp.uid(31)) || ' was submitted with 1 COTS detected in Stage Two Reef. '
  || 'This zone is currently assigned to Diver Alpha. Your record was sent to the Expert for review.',
  'Diver B sees the agreed message');
select ok('zone_review_needed' = any(pg_temp.notices(2)),'The Expert is notified');
select ok(not ('review_needed' = any(pg_temp.notices(2))),'No separate per-COTS notice for the same record');
select is(pg_temp.body(31,'zone_review_needed'),
  'Record ' || cots_private.capture_label(pg_temp.uid(31)) || ' in Stage Two Reef was submitted by another Diver in an assigned zone. Please approve or reject it.',
  'Expert notice wording');
select is(pg_temp.zone_notices(3),'{}'::text[],'Diver A is not told anything while it waits');

-- B and A can see the waiting state through the app's computed column.
select pg_temp.act(4);
set local role authenticated;
select is((select public.zone_review_assigned_to(c) from public.captures c where c.id=pg_temp.uid(31)),
  'Diver Alpha','The app can show Diver B who the zone is assigned to');
reset role;
select pg_temp.act(3);
set local role authenticated;
select is((select public.zone_review_assigned_to(c) from public.captures c where c.id=pg_temp.uid(32)),
  null,'Diver A''s own record is not marked');
reset role;

-- While it waits, nothing counts as confirmed.
select is(cots_private.capture_confirmed_count(pg_temp.uid(31)),0,'Waiting record: 0 confirmed');
select is(cots_private.capture_waiting_count(pg_temp.uid(31)),1,'Waiting record: 1 waiting');
select throws_ok($q$select public.finalize_capture('d0000000-0000-4000-8000-000000000031')$q$,
  '23514','Expert review required','It cannot be finalized without the Expert');

-- The Expert must give a reason to reject; approving does not need one.
select pg_temp.act(2);
set local role authenticated;
select throws_ok($q$select public.record_expert_decision('d0000000-0000-4000-8000-000000000031',null,'reject','   ',null,'[]'::jsonb)$q$,
  '23514','Give a reason to reject this record','Rejecting needs a reason');
select throws_ok($q$select public.record_expert_decision('d0000000-0000-4000-8000-000000000031',null,'reject',null,null,'[]'::jsonb)$q$,
  '23514','Give a reason to reject this record','Rejecting with no reason at all is refused');
-- The app sends its standard note when the Expert approves without comments.
select lives_ok($q$select public.record_expert_decision('d0000000-0000-4000-8000-000000000031',null,'approve','Approved after per-COTS review.',null,'[]'::jsonb)$q$,
  'Approving needs no typed reason');
reset role;
select lives_ok($q$select public.finalize_capture('d0000000-0000-4000-8000-000000000031')$q$,'The approved record is finalized');
select is((select status from public.captures where id=pg_temp.uid(31)),'finalized','It counts');
select is((select owner_id from public.captures where id=pg_temp.uid(31)),pg_temp.uid(4),'It stays under Diver B''s name');
select is(cots_private.capture_confirmed_count(pg_temp.uid(31)),1,'After approval: 1 confirmed');
select is((select primary_diver_id from public.follow_up_assignments where area_id=pg_temp.uid(10)),pg_temp.uid(3),
  'The zone still belongs to Diver A');
select is((select originating_capture_id from public.follow_up_assignments where area_id=pg_temp.uid(10)),pg_temp.uid(20),
  'The zone''s origin is unchanged');
select is((select count(*)::integer from public.follow_up_surveys),0,'It is not a monthly visit');
select is(pg_temp.zone_notices(3),array['zone_record_approved'],'Diver A is notified after approval');
select is(pg_temp.body(31,'zone_record_approved'),
  'Another Diver recorded COTS in your area Stage Two Reef on '
  || to_char((now() - interval '1 hour') at time zone 'Asia/Manila','FMMonth FMDD, YYYY')
  || '. The Expert approved the record.','Agreed wording for Diver A');
select ok(position('Bravo' in (select string_agg(e.details::text,' ') from public.workflow_events e
  join public.notifications n on n.event_id=e.id where n.recipient_id=pg_temp.uid(3))) = 0,
  'Diver A''s notice does not name Diver B');
select ok('review_accepted' = any(pg_temp.notices(4)),'Diver B is told it was approved');

-- A rejected record: not counted, and Diver A is not told.
select pg_temp.capture(36,4,10,interval '2 hours',0.55);
select pg_temp.evidence(36,4);
select pg_temp.act(2);
set local role authenticated;
select lives_ok($q$select public.record_expert_decision('d0000000-0000-4000-8000-000000000036',null,'reject','Duplicate of an earlier record',null,'[]'::jsonb)$q$,
  'The Expert rejects with a reason');
reset role;
select lives_ok($q$select public.finalize_capture('d0000000-0000-4000-8000-000000000036')$q$,'The worker closes it');
select is((select status from public.captures where id=pg_temp.uid(36)),'rejected','The rejected record is not counted');
select is(cots_private.capture_confirmed_count(pg_temp.uid(36)),0,'Rejected: 0 confirmed');
select is(pg_temp.zone_notices(3),array['zone_record_approved'],'Diver A gets nothing after a rejection');
select ok('review_rejected' = any(pg_temp.notices(4)),'Diver B is told it was rejected');

-- Ordinary rejections still work without a typed reason.
select pg_temp.act(2);
set local role authenticated;
select lives_ok($q$select public.record_expert_decision('d0000000-0000-4000-8000-000000000032',null,'reject','Rejected after review.',null,'[]'::jsonb)$q$,
  'Diver A''s own record can still be rejected with the standard note');
reset role;

-- Reminders every 3 days until the Expert decides.
select pg_temp.capture(37,4,10,interval '3 hours',0.95);
select pg_temp.evidence(37,4);
-- Late case: B submitted in area 11 before Diver A's earlier photo assigned it.
select pg_temp.capture(40,3,11,interval '5 days',0.95);
select pg_temp.capture(41,4,11,interval '2 days',0.95);
select pg_temp.evidence(41,4);
select is(cots_private.zone_review_needed(pg_temp.uid(41)),false,'No zone yet when B submitted');
update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(40);
insert into public.follow_up_assignments(id,area_id,primary_diver_id,originating_capture_id)
values(pg_temp.uid(61),pg_temp.uid(11),pg_temp.uid(3),pg_temp.uid(40));
select is(cots_private.zone_review_needed(pg_temp.uid(41)),true,'Now it needs approval (photo after A''s first photo)');

select is(cots_private.send_zone_review_reminders(now()),1,'First run: first notices for the late record only');
select ok('zone_review_waiting' = any(pg_temp.notices(4)),'Diver B is told the late record waits for the Expert');
select is(pg_temp.body(41,'zone_review_waiting'),
  'Report ' || cots_private.capture_label(pg_temp.uid(41)) || ': This zone is currently assigned to Diver Alpha. Your record was sent to the Expert for review.',
  'Late-record message for Diver B');
-- Pretend the first notice was sent 4 days ago (history is append-only, so
-- the protection is bypassed for this test update only).
set local session_replication_role = replica;
update public.workflow_events set created_at = now() - interval '4 days'
where capture_id = pg_temp.uid(37) and action = 'zone_review_needed';
set local session_replication_role = origin;
select is(cots_private.send_zone_review_reminders(now()),1,'After 3 days the Expert is reminded');
select is(pg_temp.body(37,'zone_review_reminder'),
  'Reminder: record ' || cots_private.capture_label(pg_temp.uid(37)) || ' in Stage Two Reef is still waiting for your approval.',
  'Reminder wording');
select is(cots_private.send_zone_review_reminders(now()),0,'No second reminder on the same day');
select is(cots_private.send_zone_review_reminders(now() + interval '3 days 1 minute'),2,
  'Both waiting records are reminded again 3 days later');
select pg_temp.act(2);
set local role authenticated;
select lives_ok($q$select public.record_expert_decision('d0000000-0000-4000-8000-000000000037',null,'approve','Approved after per-COTS review.',null,'[]'::jsonb)$q$,
  'The Expert decides');
reset role;
select is(cots_private.send_zone_review_reminders(now() + interval '7 days'),1,'A decided record gets no more reminders');

-- Privileges.
select ok(not has_function_privilege('authenticated','cots_private.zone_review_needed(uuid)','EXECUTE'),
  'The rule runs only inside the database');
select ok(not has_function_privilege('authenticated','cots_private.send_zone_review_reminders(timestamptz)','EXECUTE'),
  'Only the scheduled job sends reminders');
select ok(not has_function_privilege('anon','public.zone_review_assigned_to(public.captures)','EXECUTE'),
  'Visitors who are not signed in cannot read zone assignments');
select ok(has_function_privilege('authenticated','public.zone_review_assigned_to(public.captures)','EXECUTE'),
  'Signed-in people can read it for records they can see');

select * from finish();
rollback;
