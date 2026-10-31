-- Stage 4: hand over this area. Synthetic fixtures only; everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('f0000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.act(n integer) returns void language sql as $$
  select set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true)
$$;
create function pg_temp.this_month() returns date language sql stable as $$
  select cots_private.current_month()
$$;
create function pg_temp.today() returns date language sql stable as $$
  select (now() at time zone 'Asia/Manila')::date
$$;
-- Photo n by Diver o in area a, taken "age" ago, with one 95% COTS.
create function pg_temp.photo(n integer, o integer, a integer, age interval) returns void language sql as $$
  insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
    model_name,model_sha256,source_width,source_height,gps_source)
  values(pg_temp.uid(n),pg_temp.uid(o),pg_temp.uid(n+500),pg_temp.uid(a),now()-age,'device',
    'synthetic-test',repeat('a',64),2048,1536,'unavailable');
  insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
  values(pg_temp.uid(n+700),pg_temp.uid(n),0,0.95,10,10,100,100);
$$;
-- Zone a assigned to Diver A from photo n taken mid-month, k months ago.
create function pg_temp.zone(a integer, n integer, k integer) returns void language sql as $$
  select pg_temp.photo(n,3,a,now() - (((cots_private.current_month() - make_interval(months => k))::timestamp
    + interval '14 days') at time zone 'Asia/Manila'));
  update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(n);
  insert into public.follow_up_assignments(id,area_id,primary_diver_id,originating_capture_id)
  values(pg_temp.uid(a+40),pg_temp.uid(a),pg_temp.uid(3),pg_temp.uid(n));
$$;
create function pg_temp.notices(person integer) returns text[] language sql as $$
  select coalesce(array_agg(e.action order by e.created_at, e.action), '{}')
  from public.notifications n join public.workflow_events e on e.id = n.event_id
  where n.recipient_id = pg_temp.uid(person) and e.action like 'handover%'
$$;
create function pg_temp.body(person integer, action_name text) returns text language sql as $$
  select e.details->>'body' from public.notifications n join public.workflow_events e on e.id = n.event_id
  where n.recipient_id = pg_temp.uid(person) and e.action = action_name
  order by e.created_at desc limit 1
$$;
-- Test lookups run with test privileges (the tables are not readable by Divers).
create function pg_temp.open_handover(a integer) returns uuid language sql security definer as $$
  select h.id from public.area_handovers h where h.assignment_id = pg_temp.uid(a+40)
    and h.status in ('requested','offered')
$$;
create function pg_temp.pending_offer(a integer) returns uuid language sql security definer as $$
  select o.id from public.handover_offers o join public.area_handovers h on h.id = o.handover_id
  where h.assignment_id = pg_temp.uid(a+40) and o.status = 'pending'
$$;

-- 1 Admin, 2 Expert, 3 Diver A (original), 4 Diver B, 5 Diver C, 6 Diver D.
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'stage4-' || n || '@example.invalid',now() from generate_series(1,6) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select pg_temp.act(1);
set local role authenticated;
select public.verify_personnel(pg_temp.uid(n),true,true) from generate_series(3,6) n;
reset role;
update public.profiles set full_name = case id
  when pg_temp.uid(3) then 'Diver Alpha' when pg_temp.uid(4) then 'Diver Bravo'
  when pg_temp.uid(5) then 'Diver Charlie' when pg_temp.uid(6) then 'Diver Delta' else full_name end;
insert into public.monitoring_areas(id,code,name,geography_version) values
  (pg_temp.uid(10),'S4-MAIN','Stage Four Reef','test-only'),
  (pg_temp.uid(11),'S4-MISSED','Quiet Reef','test-only'),
  (pg_temp.uid(12),'S4-VISITED','Visited Reef','test-only'),
  (pg_temp.uid(13),'S4-COVERED','Covered Reef','test-only');
select pg_temp.zone(10, 20, 3);
select pg_temp.zone(11, 21, 8);
select pg_temp.zone(12, 22, 2);
select pg_temp.zone(13, 23, 3);
select is(cots_private.main_diver(pg_temp.uid(50)),pg_temp.uid(3),'Diver A starts as the main Diver');

-- Diver A asks to hand over.
select pg_temp.act(4);
set local role authenticated;
select throws_ok($q$select public.request_area_handover('S4-MAIN','Busy')$q$,'42501',null,
  'Only the main Diver can hand over the area');
reset role;
select pg_temp.act(3);
set local role authenticated;
select throws_ok($q$select public.request_area_handover('S4-MAIN','   ')$q$,'23514','Give a reason for the handover',
  'A reason is required');
select lives_ok($q$select public.request_area_handover('S4-MAIN','Moving to another city',
  'Reef access is from the barangay pier')$q$,'Diver A asks with a reason and a note');
select throws_ok($q$select public.request_area_handover('S4-MAIN','Again')$q$,'23514',
  'A handover is already open for this area','Only one open handover per area');
select throws_ok(format($q$select public.offer_area_handover(%L,%L)$q$,pg_temp.open_handover(10),pg_temp.uid(5)),
  '42501',null,'Divers cannot choose the new Diver');
reset role;
select ok('handover_requested' = any(pg_temp.notices(2)),'The Expert is notified');

-- The Expert picks a Diver; the first one declines.
select pg_temp.act(2);
set local role authenticated;
select throws_ok(format($q$select public.offer_area_handover(%L,%L)$q$,pg_temp.open_handover(10),pg_temp.uid(3)),
  '23514',null,'The current main Diver cannot be picked');
select throws_ok(format($q$select public.offer_area_handover(%L,%L)$q$,pg_temp.open_handover(10),pg_temp.uid(1)),
  '23514',null,'Only verified, active Divers can be picked');
select lives_ok(format($q$select public.offer_area_handover(%L,%L)$q$,pg_temp.open_handover(10),pg_temp.uid(5)),
  'The Expert offers the area to Diver C');
reset role;
select is(pg_temp.body(5,'handover_offered'),
  'Diver Alpha is handing over Stage Four Reef. Reason: Moving to another city Note: Reef access is from the barangay pier '
  || 'This month hasn''t been monitored yet. You can do this month''s visit any day. Please accept or decline.',
  'Diver C sees the reason, the note and the agreed month note');
select ok('handover_offer_sent' = any(pg_temp.notices(3)),'Diver A is told who it was offered to');
select pg_temp.act(4);
set local role authenticated;
select throws_ok(format($q$select public.respond_area_handover(%L,true)$q$,pg_temp.pending_offer(10)),
  '42501',null,'Only the offered Diver can answer');
reset role;
select pg_temp.act(5);
set local role authenticated;
select is((select (x->>'can_respond')::boolean from jsonb_array_elements(public.area_handovers_json()) x
  where x->>'area_code'='S4-MAIN'),true,'Diver C sees the offer and can answer');
select is(public.respond_area_handover(pg_temp.pending_offer(10),false),'declined','Diver C declines');
reset role;
select is(cots_private.main_diver(pg_temp.uid(50)),pg_temp.uid(3),'Diver A keeps the area meanwhile');
select ok('handover_declined' = any(pg_temp.notices(2)),'The Expert is told to choose another Diver');

-- The next Diver accepts.
select pg_temp.act(2);
set local role authenticated;
select lives_ok(format($q$select public.offer_area_handover(%L,%L)$q$,pg_temp.open_handover(10),pg_temp.uid(4)),
  'The Expert offers the area to Diver B');
reset role;
select pg_temp.act(4);
set local role authenticated;
select is(public.respond_area_handover(pg_temp.pending_offer(10),true),'accepted','Diver B accepts');
reset role;
select is(cots_private.main_diver(pg_temp.uid(50)),pg_temp.uid(4),'Diver B is now the main Diver');
select is((select primary_diver_id from public.follow_up_assignments where id=pg_temp.uid(50)),pg_temp.uid(3),
  'The zone''s permanent record is untouched');
select is((select owner_id from public.captures where id=pg_temp.uid(20)),pg_temp.uid(3),
  'Past records stay under Diver A');
select is(pg_temp.body(3,'handover_accepted'),
  'Diver Bravo is now the main Diver for Stage Four Reef. Past records stay under Diver Alpha.',
  'Diver A is told, with names');
select is(pg_temp.body(4,'handover_welcome'),
  'You are now the main Diver for Stage Four Reef. This month hasn''t been monitored yet. You can do this month''s visit any day.',
  'Diver B gets the agreed note');
select is((select count(*)::integer from public.audit_events where action='area_handover_accepted'),1,
  'The handover is in the audit history');

-- Every "who owns this zone" rule follows the current main Diver.
select pg_temp.act(4);
set local role authenticated;
select is(public.follow_up_can_submit('S4-MAIN',pg_temp.today()),true,'Diver B can do this month''s visit');
select is((select count(*)::integer from jsonb_array_elements(public.follow_up_assignments_json())),1,
  'The area is on Diver B''s Follow-up page');
reset role;
select pg_temp.act(3);
set local role authenticated;
select is(public.follow_up_can_submit('S4-MAIN',pg_temp.today()),false,'Diver A can no longer do the visit');
select is((select count(*)::integer from jsonb_array_elements(public.follow_up_assignments_json())
  where value->>'area_id'='S4-MAIN'),0,'The area left Diver A''s Follow-up page');
reset role;
select pg_temp.photo(30,3,10,interval '1 hour');
select pg_temp.photo(31,4,10,interval '1 hour');
select is(cots_private.zone_review_needed(pg_temp.uid(30)),true,'A new record by Diver A now needs Expert approval (Stage 2)');
select is(cots_private.zone_review_needed(pg_temp.uid(31)),false,'Diver B submits normally');

-- Month notes: already monitored / another Diver covering.
select pg_temp.photo(32,3,12,interval '1 hour');
select pg_temp.act(3);
set local role authenticated;
select is(public.submit_follow_up_survey(pg_temp.uid(90),'S4-VISITED',pg_temp.today(),0,0,'Manual Removal',100,
  array[pg_temp.uid(32)],null,null,''),'pending','Diver A already visited Visited Reef this month');
select lives_ok($q$select public.request_area_handover('S4-VISITED','Health reasons')$q$,'Handover asked for Visited Reef');
select lives_ok($q$select public.request_area_handover('S4-COVERED','Health reasons')$q$,'Handover asked for Covered Reef');
reset role;
insert into public.monthly_authorizations(assignment_id,month,responsible_diver_id)
values(pg_temp.uid(53),pg_temp.this_month(),pg_temp.uid(6));
select is(cots_private.handover_month_note(pg_temp.uid(52)),
  'This month has already been monitored. Your first visit is next month.','Already monitored note');
select is(cots_private.handover_month_note(pg_temp.uid(53)),
  'Another Diver is covering this month. Your first visit is next month.','Replacement covering note');
select pg_temp.act(2);
set local role authenticated;
select lives_ok(format($q$select public.offer_area_handover(%L,%L)$q$,pg_temp.open_handover(13),pg_temp.uid(4)),
  'Covered Reef offered to Diver B');
reset role;
select pg_temp.act(4);
set local role authenticated;
select is(public.respond_area_handover(pg_temp.pending_offer(13),true),'accepted','Diver B accepts Covered Reef');
reset role;
select is((select responsible_diver_id from public.monthly_authorizations
  where assignment_id=pg_temp.uid(53) and month=pg_temp.this_month()),pg_temp.uid(6),
  'The replacement keeps this month');

-- Cancelling.
select pg_temp.act(2);
set local role authenticated;
select throws_ok(format($q$select public.cancel_area_handover(%L)$q$,pg_temp.open_handover(12)),'42501',null,
  'The Expert cannot cancel a Diver''s own request');
reset role;
select pg_temp.act(3);
set local role authenticated;
select lives_ok(format($q$select public.cancel_area_handover(%L)$q$,pg_temp.open_handover(12)),
  'Diver A cancels their own request');
reset role;
select is(pg_temp.open_handover(12),null,'No open handover for Visited Reef');

-- Missed months.
select is(cots_private.missed_months_in_a_row(pg_temp.uid(51)),7,'Quiet Reef: 7 missed months in a row');
select is(cots_private.missed_months_in_a_row(pg_temp.uid(52)),1,'Visited Reef: last month missed');
select is(cots_private.missed_months_in_a_row(pg_temp.uid(52),(pg_temp.this_month()+interval '2 months')::date),1,
  'A visit breaks the streak (next month missed, this month visited)');
select is(cots_private.missed_months_in_a_row(pg_temp.uid(52),(pg_temp.this_month()+interval '1 month')::date),0,
  'The visited month is not missed');
select pg_temp.act(2);
set local role authenticated;
select throws_ok($q$select public.start_area_handover('S4-VISITED')$q$,'23514',
  'A handover can be started after 5 missed months in a row','Not before 5 missed months');
select lives_ok($q$select public.start_area_handover('S4-MISSED')$q$,'The Expert starts the handover of Quiet Reef');
reset role;
select is((select reason from public.area_handovers where id=pg_temp.open_handover(11)),
  'No monthly visit for 7 months in a row.','The reason says how many months');
select ok('handover_started' = any(pg_temp.notices(3)),'Diver A is told');
select pg_temp.act(3);
set local role authenticated;
select throws_ok(format($q$select public.cancel_area_handover(%L)$q$,pg_temp.open_handover(11)),'42501',null,
  'Diver A cannot cancel the Expert''s handover');
reset role;
select pg_temp.act(2);
set local role authenticated;
select lives_ok(format($q$select public.offer_area_handover(%L,%L)$q$,pg_temp.open_handover(11),pg_temp.uid(5)),
  'Quiet Reef offered to Diver C');
reset role;
select pg_temp.act(5);
set local role authenticated;
select is(public.respond_area_handover(pg_temp.pending_offer(11),true),'accepted','Diver C accepts');
reset role;
select is(cots_private.missed_months_in_a_row(pg_temp.uid(51)),0,'Counting starts again after the handover');

-- Lists and privileges.
select pg_temp.act(6);
set local role authenticated;
select is(public.area_handovers_json(),'[]'::jsonb,'An unrelated Diver sees no handovers');
select throws_ok($q$select public.area_missed_months_json()$q$,'42501',null,'Divers cannot see missed months');
select throws_ok($q$select count(*) from public.area_handovers$q$,'42501',null,'The tables are not readable directly');
reset role;
select pg_temp.act(2);
set local role authenticated;
select is((select (x->>'missed_months')::integer from jsonb_array_elements(public.area_missed_months_json()) x
  where x->>'area_code'='S4-VISITED'),1,'The Expert sees missed months per area');
reset role;
select ok(not has_function_privilege('anon','public.request_area_handover(text,text,text)','EXECUTE'),
  'Visitors who are not signed in cannot hand over');
select ok(not has_function_privilege('authenticated','cots_private.main_diver(uuid)','EXECUTE'),
  'The main-Diver rule runs only inside the database');

select * from finish();
rollback;
