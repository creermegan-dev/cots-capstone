-- Stage 5: after an injection removal. Synthetic fixtures only; everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('e5000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.act(n integer) returns void language sql as $$
  select set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true)
$$;
-- A Philippine date and time.
create function pg_temp.ph(d date, h interval) returns timestamptz language sql immutable as $$
  select (d::timestamp + h) at time zone 'Asia/Manila'
$$;
create function pg_temp.last_month() returns date language sql stable as $$
  select (cots_private.current_month() - interval '1 month')::date
$$;
-- The last day of last month, 10:00 AM: the 2-day wait ends after the month.
create function pg_temp.late() returns timestamptz language sql stable as $$
  select pg_temp.ph((cots_private.current_month() - interval '1 day')::date, interval '10 hours')
$$;
-- Photo n by Diver o in area a, taken at t, with one 95% COTS.
create function pg_temp.photo(n integer, o integer, a integer, t timestamptz) returns void language sql as $$
  insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
    model_name,model_sha256,source_width,source_height,gps_source)
  values(pg_temp.uid(n),pg_temp.uid(o),pg_temp.uid(n+500),pg_temp.uid(a),t,'device',
    'synthetic-test',repeat('a',64),2048,1536,'unavailable');
  insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
  values(pg_temp.uid(n+700),pg_temp.uid(n),0,0.95,10,10,100,100);
$$;
-- Verified photo evidence for photo n (needed before a record is finalized).
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
-- Zone a assigned to Diver A from photo n taken mid-month, k months ago.
create function pg_temp.zone(a integer, n integer, k integer) returns void language sql as $$
  select pg_temp.photo(n,3,a,pg_temp.ph((cots_private.current_month() - make_interval(months => k))::date,
    interval '14 days'));
  update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(n);
  insert into public.follow_up_assignments(id,area_id,primary_diver_id,originating_capture_id)
  values(pg_temp.uid(a+40),pg_temp.uid(a),pg_temp.uid(3),pg_temp.uid(n));
$$;
-- Removal r of photo n by Diver o with a method, at the photo time t.
create function pg_temp.removal(r integer, n integer, o integer, method text, t timestamptz) returns void
language sql as $$
  insert into public.eliminations(id,owner_id,idempotency_key,capture_id,captured_at,removed_count,method,gps_source)
  values(pg_temp.uid(r),pg_temp.uid(o),pg_temp.uid(r+500),pg_temp.uid(n),t,1,method,'unavailable');
$$;
-- Completed monthly visit v by Diver o in zone a, with photo n taken at t.
create function pg_temp.visit(v integer, o integer, a integer, n integer, t timestamptz, method text, removed integer)
returns void language sql as $$
  select pg_temp.photo(n,o,a,t);
  insert into public.follow_up_surveys(id,owner_id,idempotency_key,assignment_id,captured_at,month,
    authorization_revision,gps_source,observed_count,eliminated_count,elimination_method,surveyed_area_m2,
    status,completed_at,survey_date)
  values(pg_temp.uid(v),pg_temp.uid(o),pg_temp.uid(v+500),pg_temp.uid(a+40),t,
    date_trunc('month', t at time zone 'Asia/Manila')::date,0,'unavailable',removed,removed,method,100,
    'completed',now(),(t at time zone 'Asia/Manila')::date);
  insert into public.survey_captures(survey_id,capture_id) values(pg_temp.uid(v),pg_temp.uid(n));
$$;
-- Runs with test privileges, so it can also be compared while acting as a person.
create function pg_temp.note(v integer) returns text language sql security definer as $$
  select cots_private.survey_json(pg_temp.uid(v))->>'early_visit_note'
$$;
create function pg_temp.missed(a integer) returns integer language sql as $$
  select cots_private.missed_months_in_a_row(pg_temp.uid(a+40))
$$;
create function pg_temp.body(cap integer) returns text language sql as $$
  select e.details->>'body' from public.workflow_events e
  where e.capture_id = pg_temp.uid(cap) and e.action = 'zone_record_approved'
  order by e.created_at desc limit 1
$$;

-- 1 Admin, 2 Expert, 3 Diver A (main Diver), 4 Diver B (another Diver).
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'stage5-' || n || '@example.invalid',now() from generate_series(1,4) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select pg_temp.act(1);
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
select public.verify_personnel(pg_temp.uid(n),true,true) from generate_series(3,4) n;
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
reset role;
update public.profiles set full_name = case id
  when pg_temp.uid(3) then 'Diver Alpha' when pg_temp.uid(4) then 'Diver Bravo' else full_name end;
insert into public.monitoring_areas(id,code,name,geography_version)
select pg_temp.uid(a), 'S5-' || a, 'Reef ' || a, 'test-only' from generate_series(10,22) a;
update public.monitoring_areas set name = 'Notice Reef' where id = pg_temp.uid(15);
update public.monitoring_areas set name = 'Manual Reef' where id = pg_temp.uid(16);

-- Which removals are injections.
select ok(cots_private.is_injection('Vinegar Injection'),'Vinegar injection is an injection');
select ok(cots_private.is_injection('Ox Bile / Bile Salts Injection'),'Ox bile injection is an injection');
select ok(cots_private.is_injection('Injection Method'),'The older "Injection Method" is an injection');
select ok(not cots_private.is_injection('Manual Removal'),'Manual removal is not');
select ok(not cots_private.is_injection(''),'No method is not');
select is(cots_private.ph_time_label('2026-11-03 01:40:00+00'),'Nov 3, 9:40 AM','Times read like "Nov 3, 9:40 AM"');
select is(cots_private.ph_time_label('2026-11-12 06:00:00+00'),'Nov 12, 2:00 PM','Afternoon times read like "Nov 12, 2:00 PM"');

-- Excused months. Every zone below was assigned 4 months ago and has no visits:
-- without an excused month, 3 months are missed in a row.
select pg_temp.zone(10,110,4);   -- Diver A injects on the last day of last month
select pg_temp.photo(111,3,10,pg_temp.late());
select pg_temp.removal(211,111,3,'Vinegar Injection',pg_temp.late());
select pg_temp.zone(11,112,4);   -- the same, but manual removal
select pg_temp.photo(113,3,11,pg_temp.late());
select pg_temp.removal(213,113,3,'Manual Removal',pg_temp.late());
select pg_temp.zone(12,114,4);   -- injection on day 10 of last month
select pg_temp.photo(115,3,12,pg_temp.ph(pg_temp.last_month() + 9, interval '10 hours'));
select pg_temp.removal(215,115,3,'Ox Bile / Bile Salts Injection',pg_temp.ph(pg_temp.last_month() + 9, interval '10 hours'));

select ok(cots_private.month_excused(pg_temp.uid(50),pg_temp.last_month()),
  'An injection whose 2-day wait ends after the month excuses that month');
select ok(not cots_private.month_excused(pg_temp.uid(50),(pg_temp.last_month() - interval '1 month')::date),
  'Other months are not excused');
select is(pg_temp.missed(10),0,'The excused month is not missed and ends the count');
select is(cots_private.missed_months_in_a_row(pg_temp.uid(50),(cots_private.current_month() + interval '1 month')::date),1,
  'Once this month is over without a visit, it is missed; the excused month still ends the count');
select is(pg_temp.missed(11),3,'Manual removal excuses nothing');
select is(pg_temp.missed(12),3,'An injection with time left in the month excuses nothing');

-- Another Diver's injection counts only after the Expert approves it.
select pg_temp.zone(13,116,4);
select pg_temp.photo(117,4,13,pg_temp.late());
select pg_temp.evidence(117,4);
select pg_temp.removal(217,117,4,'Vinegar Injection',pg_temp.late());
select is(pg_temp.missed(13),3,'Waiting for the Expert: the injection does not count yet');
select pg_temp.act(2);
set local role authenticated;
select public.record_expert_decision(pg_temp.uid(117),null,'approve','Approved after per-COTS review.',null,'[]'::jsonb);
reset role;
select public.finalize_capture(pg_temp.uid(117));
select is((select status from public.captures where id=pg_temp.uid(117)),'finalized','Diver B''s record is approved');
select is(pg_temp.missed(13),0,'After approval the month is excused');

select pg_temp.zone(14,118,4);
select pg_temp.photo(119,4,14,pg_temp.late());
select pg_temp.evidence(119,4);
select pg_temp.removal(219,119,4,'Vinegar Injection',pg_temp.late());
select pg_temp.act(2);
set local role authenticated;
select public.record_expert_decision(pg_temp.uid(119),null,'reject','Duplicate of an earlier record',null,'[]'::jsonb);
reset role;
select public.finalize_capture(pg_temp.uid(119));
select is((select status from public.captures where id=pg_temp.uid(119)),'rejected','Diver B''s record is rejected');
select is(pg_temp.missed(14),3,'A rejected record never counts');

-- That month's replacement Diver submits without approval, so it counts at once.
select pg_temp.zone(17,124,4);
insert into public.monthly_authorizations(assignment_id,month,responsible_diver_id)
values(pg_temp.uid(57),pg_temp.last_month(),pg_temp.uid(4));
select pg_temp.photo(125,4,17,pg_temp.late());
select pg_temp.removal(225,125,4,'Vinegar Injection',pg_temp.late());
select is(pg_temp.missed(17),0,'The replacement''s injection counts without approval');

-- The Expert sees the new count.
select pg_temp.act(2);
set local role authenticated;
select is((select (x->>'missed_months')::integer from jsonb_array_elements(public.area_missed_months_json()) x
  where x->>'area_code'='S5-10'),0,'The Expert''s missed-month list uses excused months');
select is((select (x->>'missed_months')::integer from jsonb_array_elements(public.area_missed_months_json()) x
  where x->>'area_code'='S5-11'),3,'Other areas are unchanged');
reset role;

-- The approval notice: another Diver's injection adds the wait.
select pg_temp.zone(15,120,2);
select pg_temp.photo(121,4,15,now() - interval '3 hours');
select pg_temp.evidence(121,4);
select pg_temp.removal(221,121,4,'Ox Bile / Bile Salts Injection',now() - interval '3 hours');
select pg_temp.act(2);
set local role authenticated;
select public.record_expert_decision(pg_temp.uid(121),null,'approve','Approved after per-COTS review.',null,'[]'::jsonb);
reset role;
select public.finalize_capture(pg_temp.uid(121));
select is(pg_temp.body(121),
  'Another Diver recorded COTS at your site Notice Reef on '
  || to_char((now() - interval '3 hours') at time zone 'Asia/Manila', 'FMMonth FMDD, YYYY')
  || '. The Expert approved the record. COTS were injected (Ox bile / bile salts injection) on '
  || cots_private.ph_time_label(now() - interval '3 hours') || '. Wait until '
  || cots_private.ph_time_label(now() - interval '3 hours' + interval '2 days') || ' before this month''s visit.',
  'The main Diver is told the method and until when to wait');
select ok(exists(select 1 from public.notifications n join public.workflow_events e on e.id = n.event_id
  where e.capture_id = pg_temp.uid(121) and e.action = 'zone_record_approved' and n.recipient_id = pg_temp.uid(3)),
  'The notice goes to the main Diver');

select pg_temp.zone(16,122,2);
select pg_temp.photo(123,4,16,now() - interval '3 hours');
select pg_temp.evidence(123,4);
select pg_temp.removal(223,123,4,'Manual Removal',now() - interval '3 hours');
select pg_temp.act(2);
set local role authenticated;
select public.record_expert_decision(pg_temp.uid(123),null,'approve','Approved after per-COTS review.',null,'[]'::jsonb);
reset role;
select public.finalize_capture(pg_temp.uid(123));
select is(pg_temp.body(123),
  'Another Diver recorded COTS at your site Manual Reef on '
  || to_char((now() - interval '3 hours') at time zone 'Asia/Manila', 'FMMonth FMDD, YYYY')
  || '. The Expert approved the record.',
  'Manual removal: the Stage 2 notice is unchanged');

-- Early visits are flagged for the Expert.
select pg_temp.zone(18,126,2);
select pg_temp.photo(127,3,18,now() - interval '30 hours');
select pg_temp.removal(227,127,3,'Vinegar Injection',now() - interval '30 hours');
select pg_temp.visit(300,3,18,128,now() - interval '1 hour','Manual Removal',0);
select pg_temp.visit(305,3,18,138,now() - interval '40 hours','Manual Removal',0);
select is(pg_temp.note(300),
  'Visit within 2 days of an injection on ' || cots_private.ph_time_label(now() - interval '30 hours')
  || ': injected COTS may still be alive.',
  'A visit within 2 days after an injection is flagged');
select is(pg_temp.note(305),null,'A visit before the injection is not flagged');
select pg_temp.act(2);
set local role authenticated;
select is((select x->>'early_visit_note' from jsonb_array_elements(public.follow_up_visits_to_assess()) x
  where x->>'id' = pg_temp.uid(300)::text),pg_temp.note(300),'The Expert''s Assessments list carries the flag');
reset role;

select pg_temp.zone(19,129,2);
select pg_temp.photo(130,3,19,now() - interval '3 days');
select pg_temp.removal(230,130,3,'Vinegar Injection',now() - interval '3 days');
select pg_temp.visit(301,3,19,131,now() - interval '1 hour','Manual Removal',0);
select is(pg_temp.note(301),null,'A visit more than 2 days later is not flagged');

select pg_temp.zone(20,132,2);
select pg_temp.visit(302,3,20,133,now() - interval '5 hours','Vinegar Injection',1);
select pg_temp.visit(303,3,20,134,now() - interval '1 hour','Manual Removal',0);
select is(pg_temp.note(302),null,'A visit is not flagged by its own injection');
select is(pg_temp.note(303),
  'Visit within 2 days of an injection on ' || cots_private.ph_time_label(now() - interval '5 hours')
  || ': injected COTS may still be alive.',
  'An injection recorded in a monthly visit counts too');

select pg_temp.zone(21,135,2);
select pg_temp.photo(136,3,21,now() - interval '30 hours');
select pg_temp.removal(236,136,3,'Manual Removal',now() - interval '30 hours');
select pg_temp.visit(304,3,21,137,now() - interval '1 hour','Manual Removal',0);
select is(pg_temp.note(304),null,'Manual removal flags nothing');

select pg_temp.zone(22,139,2);
select pg_temp.photo(140,4,22,now() - interval '30 hours');
select pg_temp.evidence(140,4);
select pg_temp.removal(240,140,4,'Vinegar Injection',now() - interval '30 hours');
select pg_temp.visit(306,3,22,141,now() - interval '1 hour','Manual Removal',0);
select is(pg_temp.note(306),null,'Another Diver''s injection waiting for the Expert flags nothing yet');
select pg_temp.act(2);
set local role authenticated;
select public.record_expert_decision(pg_temp.uid(140),null,'approve','Approved after per-COTS review.',null,'[]'::jsonb);
reset role;
select public.finalize_capture(pg_temp.uid(140));
select is(pg_temp.note(306),
  'Visit within 2 days of an injection on ' || cots_private.ph_time_label(now() - interval '30 hours')
  || ': injected COTS may still be alive.',
  'Once approved, the visit is flagged');

-- The rules run only inside the database.
select ok(not has_function_privilege('authenticated','cots_private.zone_injections(uuid)','EXECUTE'),
  'Divers cannot call the injection list');
select ok(not has_function_privilege('authenticated','cots_private.month_excused(uuid,date)','EXECUTE'),
  'Divers cannot call the excused-month rule');
select ok(not has_function_privilege('authenticated','cots_private.early_visit_note(uuid)','EXECUTE'),
  'Divers cannot call the early-visit rule');
select ok(not has_function_privilege('authenticated','cots_private.injection_wait_line(uuid)','EXECUTE'),
  'Divers cannot call the notice line');
select ok(not has_function_privilege('anon','cots_private.is_injection(text)','EXECUTE'),
  'Visitors cannot call the injection check');

select * from finish();
rollback;
