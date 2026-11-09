-- Stage 11: monthly visits shared by the 2 main Divers. Synthetic fixtures only; everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('d1900000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.act(n integer) returns void language sql as $$
  select set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true)
$$;
create function pg_temp.today() returns date language sql stable as $$
  select (now() at time zone 'Asia/Manila')::date
$$;
-- A time in Manila: day d of the month k months from now, at 09:00.
create function pg_temp.manila(k integer, d integer) returns timestamptz language sql stable as $$
  select ((cots_private.current_month() + make_interval(months => k) + make_interval(days => d - 1))::timestamp
          + interval '9 hours') at time zone 'Asia/Manila'
$$;
create function pg_temp.photo(n integer, o integer, a integer, age interval) returns void language sql as $$
  insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
    model_name,model_sha256,source_width,source_height,gps_source)
  values(pg_temp.uid(n),pg_temp.uid(o),pg_temp.uid(n+500),pg_temp.uid(a),now()-age,'device',
    'synthetic-test',repeat('a',64),2048,1536,'unavailable');
  insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
  values(pg_temp.uid(n+700),pg_temp.uid(n),0,0.95,10,10,100,100);
$$;
-- Site a: Maria is Main Diver 1 from a photo taken mid-month, k months ago.
create function pg_temp.site(a integer, n integer, k integer) returns void language sql as $$
  select pg_temp.photo(n,3,a,now() - (((cots_private.current_month() - make_interval(months => k))::timestamp
    + interval '14 days') at time zone 'Asia/Manila'));
  update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(n);
  insert into public.follow_up_assignments(id,area_id,primary_diver_id,originating_capture_id)
  values(pg_temp.uid(a+40),pg_temp.uid(a),pg_temp.uid(3),pg_temp.uid(n));
$$;
-- Diver p is the approved site partner of site a since yesterday (as if the Expert had approved, Stage 10).
create function pg_temp.partner(a integer, p integer) returns void language sql as $$
  insert into public.site_partner_requests(assignment_id,candidate_id,source,capture_id,status,queued_at,decided_at,decided_by)
  values(pg_temp.uid(a+40),pg_temp.uid(p),'recorded',null,'approved',now()-interval '1 day',now()-interval '1 day',pg_temp.uid(2));
$$;
create function pg_temp.has_notice(person integer, action_name text) returns boolean language sql security definer as $$
  select exists (select 1 from public.notifications n join public.workflow_events e on e.id = n.event_id
                 where n.recipient_id = pg_temp.uid(person) and e.action = action_name)
$$;
create function pg_temp.reminder_to(person integer, action_name text, a integer) returns integer language sql security definer as $$
  select count(*)::integer from public.notifications n join public.workflow_events e on e.id = n.event_id
  where n.recipient_id = pg_temp.uid(person) and e.action = action_name and e.details->>'assignment' = pg_temp.uid(a+40)::text
$$;
create function pg_temp.can_submit(person integer, code text) returns boolean language plpgsql as $$
declare ok boolean;
begin
  perform pg_temp.act(person);
  set local role authenticated;
  ok := public.follow_up_can_submit(code, (now() at time zone 'Asia/Manila')::date);
  reset role;
  return ok;
end $$;
create function pg_temp.sees(person integer, code text) returns boolean language plpgsql as $$
declare j jsonb;
begin
  perform pg_temp.act(person);
  set local role authenticated;
  j := public.follow_up_assignments_json(null);
  reset role;
  return exists (select 1 from jsonb_array_elements(j) x where x->>'area_id' = code);
end $$;
create function pg_temp.open_handover(a integer) returns uuid language sql security definer as $$
  select h.id from public.area_handovers h where h.assignment_id = pg_temp.uid(a+40) and h.status in ('requested','offered')
$$;
create function pg_temp.pending_offer(a integer) returns uuid language sql security definer as $$
  select o.id from public.handover_offers o join public.area_handovers h on h.id = o.handover_id
  where h.assignment_id = pg_temp.uid(a+40) and o.status = 'pending'
$$;

-- 1 Admin, 2 Expert, 3 Maria (Main Diver 1), 4 Juan, 5 Pedro, 6 Ana.
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'stage11-' || n || '@example.invalid',now() from generate_series(1,6) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select pg_temp.act(2);
set local role authenticated;
select public.verify_personnel(pg_temp.uid(n),true,true) from generate_series(3,6) n;
reset role;
update public.profiles set full_name = case id
  when pg_temp.uid(3) then 'Maria Santos' when pg_temp.uid(4) then 'Juan Dela Cruz'
  when pg_temp.uid(5) then 'Pedro Reyes' when pg_temp.uid(6) then 'Ana Cruz' else full_name end;
insert into public.monitoring_areas(id,code,name,geography_version) values
  (pg_temp.uid(10),'S11-A','Shared Reef','test-only'),
  (pg_temp.uid(11),'S11-B','Quiet Reef','test-only'),
  (pg_temp.uid(12),'S11-C','Moving Reef','test-only');
select pg_temp.site(10, 20, 2);
select pg_temp.site(11, 21, 8);
select pg_temp.site(12, 22, 2);
select pg_temp.partner(10, 4);   -- Juan is site partner of Shared Reef
select pg_temp.partner(11, 5);   -- Pedro is site partner of Quiet Reef
select pg_temp.partner(12, 6);   -- Ana is site partner of Moving Reef

-- Both main Divers see the site and may record its visit; another Diver may not.
select ok(pg_temp.sees(4,'S11-A'), 'The site partner sees the site''s follow-up');
select ok(pg_temp.sees(3,'S11-A'), 'Main Diver 1 still sees it');
select ok(not pg_temp.sees(5,'S11-A'), 'Another Diver does not');
select ok(pg_temp.can_submit(4,'S11-A'), 'The site partner may record this month''s visit');
select ok(pg_temp.can_submit(3,'S11-A'), 'Main Diver 1 may too');
select ok(not pg_temp.can_submit(5,'S11-A'), 'Another Diver may not');
select is((select cots_private.assignment_json(pg_temp.uid(50))->>'partner_name'), 'Juan Dela Cruz',
  'The site''s data names the site partner');

-- Both visit this month: both visits are saved and counted.
select pg_temp.photo(30,4,10,interval '1 hour');
select pg_temp.photo(31,3,10,interval '1 hour');
select pg_temp.act(4);
set local role authenticated;
select is(public.submit_follow_up_survey(pg_temp.uid(90),'S11-A',pg_temp.today(),0,0,'Manual Removal',100,
  array[pg_temp.uid(30)],null,null,''), 'pending', 'Juan records the visit (waits for its records, as before)');
reset role;
select pg_temp.act(3);
set local role authenticated;
select is(public.submit_follow_up_survey(pg_temp.uid(91),'S11-A',pg_temp.today(),0,0,'Manual Removal',100,
  array[pg_temp.uid(31)],null,null,''), 'pending', 'Maria also records a visit the same month');
reset role;
select is((select count(*)::integer from public.follow_up_surveys where assignment_id = pg_temp.uid(50)
           and month = cots_private.current_month()), 2, 'Both visits are saved');
select is((select array_agg(owner_id order by owner_id) from public.follow_up_surveys where assignment_id = pg_temp.uid(50)),
  array[pg_temp.uid(3), pg_temp.uid(4)], 'Each visit stays under the Diver who made it');
-- When the records are approved, both visits complete (Juan is authorized like Maria).
update public.captures set status='finalized', finalized_at=now() where id in (pg_temp.uid(30), pg_temp.uid(31));
select cots_private.refresh_follow_up_survey(pg_temp.uid(90));
select cots_private.refresh_follow_up_survey(pg_temp.uid(91));
select is((select array_agg(status order by id) from public.follow_up_surveys where assignment_id = pg_temp.uid(50)),
  array['completed','completed'], 'Both visits are complete, not sent for an authorization review');

-- Either main Diver can ask for a replacement.
select pg_temp.act(6);
set local role authenticated;
select lives_ok(format($q$select public.request_reassignment(%L,'Away this month')$q$, pg_temp.uid(52)),
  'The site partner can ask for this month''s replacement');
reset role;

-- Reminders: the 1st and the 16th of the month, to both main Divers, only while nobody has visited.
select ok(cots_private.send_visit_reminders(pg_temp.manila(0, 20)) >= 0, 'The reminder job runs');
select is(pg_temp.reminder_to(4,'visit_reminder_second',10), 0, 'No reminder this month for a site already visited');
select ok(cots_private.send_visit_reminders(pg_temp.manila(1, 1)) >= 3, 'Next month, on the 1st: reminders are sent');
select is(pg_temp.reminder_to(3,'visit_reminder_first',10), 1, 'Main Diver 1 gets the first reminder');
select is(pg_temp.reminder_to(4,'visit_reminder_first',10), 1, 'The site partner gets it too');
select is(pg_temp.reminder_to(5,'visit_reminder_first',10), 0, 'Another Diver does not');
select is(cots_private.send_visit_reminders(pg_temp.manila(1, 3)), 0, 'No more reminders until the 16th');
select ok(cots_private.send_visit_reminders(pg_temp.manila(1, 16)) >= 3, 'On the 16th: the second reminder');
select is(pg_temp.reminder_to(4,'visit_reminder_second',10), 1, 'The site partner gets the second reminder');
select is(cots_private.send_visit_reminders(pg_temp.manila(1, 25)), 0, 'Only 2 reminders a month');
select is((select e.details->>'body' from public.workflow_events e where e.action = 'visit_reminder_first'
           and e.details->>'assignment' = pg_temp.uid(50)::text),
  'This month''s visit for Shared Reef is due (' || to_char(cots_private.current_month() + interval '1 month', 'FMMonth YYYY') || ').',
  'Reminder wording');

-- The missed-months list names both main Divers.
select pg_temp.act(2);
set local role authenticated;
select is((select x->>'main_diver_name' from jsonb_array_elements(public.area_missed_months_json()) x
           where x->>'area_code' = 'S11-B'), 'Maria Santos and Pedro Reyes', 'Both main Divers are named');
reset role;

-- The site partner leaves the site.
select pg_temp.act(5);
set local role authenticated;
select throws_ok($q$select public.leave_site('S11-A')$q$, '42501', null, 'Only the site partner can leave this way');
reset role;
select pg_temp.act(3);
set local role authenticated;
select throws_ok($q$select public.leave_site('S11-A')$q$, '42501', null, 'Main Diver 1 cannot "leave"; Main Diver 1 hands over');
reset role;
select pg_temp.act(4);
set local role authenticated;
select lives_ok($q$select public.leave_site('S11-A')$q$, 'Juan leaves Shared Reef');
reset role;
select is(cots_private.site_partner(pg_temp.uid(50)), null, 'The site partner place is open again');
select ok(pg_temp.has_notice(3,'site_partner_left'), 'Maria is told');
select ok(pg_temp.has_notice(2,'site_partner_left'), 'The Expert is told');
select ok(not pg_temp.can_submit(4,'S11-A'), 'Juan no longer records this site''s visits');
select is((select owner_id from public.follow_up_surveys where id = pg_temp.uid(90)), pg_temp.uid(4),
  'Juan''s past visit stays under his name');
select pg_temp.photo(32,4,10,interval '-1 minute');  -- a photo taken after he left
select is(cots_private.zone_review_needed(pg_temp.uid(32)), true, 'Juan''s new records there wait for the Expert again');

-- Main Diver 1 hands over while there is a site partner: the partner becomes Main Diver 1 at once.
select pg_temp.act(3);
set local role authenticated;
select lives_ok($q$select public.request_area_handover('S11-C','Moving to Manila')$q$, 'Maria hands over Moving Reef');
reset role;
select is(cots_private.main_diver(pg_temp.uid(52)), pg_temp.uid(6), 'Ana is now Main Diver 1');
select is(cots_private.site_partner(pg_temp.uid(52)), null, 'The partner place is open again');
select is(pg_temp.open_handover(12), null, 'No Expert step: nothing is left open');
select ok(pg_temp.has_notice(6,'handover_to_partner'), 'Ana is told she is Main Diver 1');
select ok(pg_temp.has_notice(2,'handover_to_partner_info'), 'The Expert is told');
select ok(not pg_temp.can_submit(3,'S11-C'), 'Maria no longer records this site''s visits');
select ok(pg_temp.can_submit(6,'S11-C'), 'Ana does');
select is((select count(*)::integer from public.captures where owner_id = pg_temp.uid(3) and area_id = pg_temp.uid(12)), 1,
  'Maria''s past record stays under her name');

-- After 5+ missed months: the Expert's handover replaces BOTH main Divers.
select is(cots_private.missed_months_in_a_row(pg_temp.uid(51)) >= 5, true, 'Quiet Reef has 5 or more missed months');
select pg_temp.act(2);
set local role authenticated;
select lives_ok($q$select public.start_area_handover('S11-B','No visit for months')$q$, 'The Expert starts a handover');
select lives_ok(format($q$select public.offer_area_handover(%L,%L)$q$, pg_temp.open_handover(11), pg_temp.uid(6)),
  'The Expert offers Quiet Reef to Ana');
reset role;
select pg_temp.act(6);
set local role authenticated;
select is(public.respond_area_handover(pg_temp.pending_offer(11), true), 'accepted', 'Ana accepts');
reset role;
select is(cots_private.main_diver(pg_temp.uid(51)), pg_temp.uid(6), 'Ana is Main Diver 1 of Quiet Reef');
select is(cots_private.site_partner(pg_temp.uid(51)), null, 'Pedro, the old site partner, left too');
select ok(pg_temp.has_notice(5,'site_partner_ended'), 'Pedro is told');

-- Privileges.
select ok(not has_function_privilege('anon','public.leave_site(text)','EXECUTE'), 'Visitors cannot leave a site');
select ok(not has_function_privilege('authenticated','cots_private.send_visit_reminders(timestamptz)','EXECUTE'),
  'Only the scheduled job sends visit reminders');
select ok(not has_function_privilege('authenticated','cots_private.month_ok(uuid,uuid,date)','EXECUTE'),
  'The rule runs only inside the database');

select * from finish();
rollback;
