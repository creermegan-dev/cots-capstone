-- Follow-up monitoring as the app uses it: original Diver, monthly visits,
-- replacement for one month, back to the original Diver next month.
-- Synthetic fixtures only; everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('90000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.act(n integer) returns void language sql as $$
  select set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true)
$$;
create function pg_temp.today() returns date language sql stable as $$
  select (now() at time zone 'Asia/Manila')::date
$$;

-- 1 Admin, 2 Expert, 3 Diver A (original), 4 Diver B (replacement), 5 Diver C.
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'follow-' || n || '@example.invalid',now() from generate_series(1,5) n;
update public.profiles set full_name = case id
  when pg_temp.uid(3) then 'Diver A' when pg_temp.uid(4) then 'Diver B'
  when pg_temp.uid(5) then 'Diver C' when pg_temp.uid(2) then 'Expert E' else full_name end;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select pg_temp.act(1);
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
select public.verify_personnel(pg_temp.uid(n),true,true) from generate_series(3,5) n;
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
reset role;

insert into public.monitoring_areas(id,code,name,municipality,barangay,geography_version)
values(pg_temp.uid(10),'FU-TEST','Test Reef','Samal','Test Barangay','test-only');

-- Diver A's first detection (finalized) made A the original Diver.
insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
  model_name,model_sha256,source_width,source_height,gps_source)
select pg_temp.uid(n), pg_temp.uid(o), pg_temp.uid(n), pg_temp.uid(10), now() - interval '2 days', 'device',
  'synthetic-test', repeat('a',64), 2048, 1536, 'unavailable'
from (values (20,3),(30,3),(31,3),(40,4),(41,4)) v(n,o);
insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
select pg_temp.uid(n+1), pg_temp.uid(n), 0, 0.95, 10, 10, 100, 100
from unnest(array[20,30,40]) n;
update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(20);
insert into public.follow_up_assignments(id,area_id,primary_diver_id,originating_capture_id)
values(pg_temp.uid(50),pg_temp.uid(10),pg_temp.uid(3),pg_temp.uid(20));

-- Visibility of the area.
select pg_temp.act(3);
set local role authenticated;
select is(jsonb_array_length(public.follow_up_assignments_json()),1,'Original Diver sees the area');
select is(public.follow_up_assignments_json()->0->>'primary_diver_name','Diver A','Area shows the original Diver');
select is(public.follow_up_assignments_json()->0->>'area_id','FU-TEST','Area is identified by its code');
select ok(public.follow_up_can_submit('FU-TEST',pg_temp.today()),'Original Diver may submit this month');
reset role;
select pg_temp.act(5);
set local role authenticated;
select is(jsonb_array_length(public.follow_up_assignments_json()),0,'Another Diver does not see the area');
select ok(not public.follow_up_can_submit('FU-TEST',pg_temp.today()),'Another Diver may not submit');
select throws_ok(format($q$select public.submit_follow_up_survey(%L,'FU-TEST',%L,1,0,'',null,array[%L]::uuid[],null,null,'')$q$,
  pg_temp.uid(60),pg_temp.today(),pg_temp.uid(41)),'42501',null,'Another Diver cannot submit a visit');
reset role;

-- Monthly visit by the original Diver.
select pg_temp.act(3);
set local role authenticated;
select throws_ok(format($q$select public.submit_follow_up_survey(%L,'FU-TEST',%L,1,0,'',null,array[%L]::uuid[],null,null,'')$q$,
  pg_temp.uid(60),pg_temp.today(),pg_temp.uid(40)),'23514',null,'A visit cannot use another Diver''s record');
select throws_ok(format($q$select public.submit_follow_up_survey(%L,'FU-TEST',%L,2,1,'',null,array[%L]::uuid[],null,null,'')$q$,
  pg_temp.uid(60),pg_temp.today(),pg_temp.uid(30)),'23514',null,'A removal method is required when COTS were removed');
select throws_ok(format($q$select public.submit_follow_up_survey(%L,'FU-TEST',%L,1,0,'',null,array[%L]::uuid[],null,null,'')$q$,
  pg_temp.uid(60),pg_temp.today()+1,pg_temp.uid(30)),'23514',null,'A future date is refused');
select is(public.submit_follow_up_survey(pg_temp.uid(60),'FU-TEST',pg_temp.today(),2,1,'Injection',25,
  array[pg_temp.uid(30),pg_temp.uid(31)],7.1,125.7,'Calm water'),'pending','Visit is saved and waits for its records');
select is(public.submit_follow_up_survey(pg_temp.uid(60),'FU-TEST',pg_temp.today(),2,1,'Injection',25,
  array[pg_temp.uid(30),pg_temp.uid(31)],7.1,125.7,'Calm water'),'pending','Retrying the same visit is safe');
select is((select count(*)::integer from public.follow_up_surveys),1,'Retry does not create a duplicate visit');
select is(jsonb_array_length(public.follow_up_surveys_json()->0->'capture_ids'),2,'Visit lists its two records');
select is(public.follow_up_surveys_json()->0->>'field_eliminated_count','1','Visit keeps the removed count');
select is(public.follow_up_surveys_json()->0->>'survey_calendar_date',to_char(pg_temp.today(),'YYYY-MM-DD'),
  'Visit keeps its calendar date');
select is((public.follow_up_surveys_json()->0->>'ai_detected_count')::integer,1,'AI count comes from stored detections');
select throws_ok(format($q$select public.submit_follow_up_survey(%L,'FU-TEST',%L,1,0,'',null,array[%L]::uuid[],null,null,'')$q$,
  pg_temp.uid(61),pg_temp.today(),pg_temp.uid(30)),'23514',null,'A record cannot belong to two visits');
reset role;

-- The trusted worker finalizes the records; the visit completes.
update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(30);
select is((select status from public.follow_up_surveys where id=pg_temp.uid(60)),'pending',
  'Visit waits until every record is finalized');
update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(31);
select is((select status from public.follow_up_surveys where id=pg_temp.uid(60)),'completed',
  'Visit completes when all records are finalized');
select ok(exists(select 1 from public.notifications n join public.workflow_events e on e.id=n.event_id
  where n.recipient_id=pg_temp.uid(3) and e.action='survey_completed'
    and e.details->>'title'='Follow-up visit completed'),'Diver is told the visit is complete');
select throws_ok($q$delete from public.survey_captures$q$,'23514',null,'Visit records cannot be removed');

-- Unavailable this month: request, cancel, request again.
select pg_temp.act(3);
set local role authenticated;
select throws_ok($q$select public.request_follow_up_reassignment('FU-TEST','')$q$,'23514',null,'A reason is required');
reset role;
-- The completed visit blocks a replacement this month; a fresh month has none.
select pg_temp.act(3);
set local role authenticated;
select throws_ok($q$select public.request_follow_up_reassignment('FU-TEST','Sick')$q$,'23514',null,
  'No replacement once this month''s visit is completed');
reset role;
-- (Use a second area for the replacement flow.)
insert into public.monitoring_areas(id,code,name,municipality,barangay,geography_version)
values(pg_temp.uid(11),'FU-TWO','Second Reef','Samal','Other Barangay','test-only');
insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
  model_name,model_sha256,source_width,source_height,gps_source,status,finalized_at)
values(pg_temp.uid(70),pg_temp.uid(3),pg_temp.uid(70),pg_temp.uid(11),now()-interval '40 days','device',
  'synthetic-test',repeat('a',64),2048,1536,'unavailable','pending',null),
      (pg_temp.uid(80),pg_temp.uid(4),pg_temp.uid(80),pg_temp.uid(11),now()-interval '1 hour','device',
  'synthetic-test',repeat('a',64),2048,1536,'unavailable','pending',null);
update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(70);
insert into public.follow_up_assignments(id,area_id,primary_diver_id,originating_capture_id)
values(pg_temp.uid(51),pg_temp.uid(11),pg_temp.uid(3),pg_temp.uid(70));

select pg_temp.act(3);
set local role authenticated;
select lives_ok($q$select public.request_follow_up_reassignment('FU-TWO','Sick this month')$q$,'Original Diver asks for a replacement');
reset role;
select pg_temp.act(5);
set local role authenticated;
select throws_ok(format($q$select public.cancel_reassignment(%L)$q$,(select id from public.reassignment_requests limit 1)),
  '42501',null,'Another Diver cannot cancel the request');
reset role;
select pg_temp.act(3);
set local role authenticated;
select lives_ok(format($q$select public.cancel_reassignment(%L)$q$,(select id from public.reassignment_requests limit 1)),
  'The Diver who asked can cancel it');
select is((select status from public.reassignment_requests limit 1),'cancelled','Request is cancelled');
select lives_ok($q$select public.request_follow_up_reassignment('FU-TWO','Still sick')$q$,'A new request is allowed after cancelling');
reset role;

select pg_temp.act(2);
set local role authenticated;
select is(jsonb_array_length(public.follow_up_reassignments_json()),2,'Expert sees both requests');
select is((select x->>'reason' from jsonb_array_elements(public.follow_up_reassignments_json()) x
  where x->>'status'='requested'),'Still sick','The open request carries its reason');
select ok(exists(select 1 from public.notifications n join public.workflow_events e on e.id=n.event_id
  where n.recipient_id=pg_temp.uid(2) and e.action='reassignment_requested'
    and e.details->>'title'='Follow-up replacement requested'
    and e.details->>'body' like '%Second Reef (FU-TWO)%Original diver: Diver A%'),
  'Expert is told with readable wording');
select lives_ok(format($q$select public.propose_replacement(%L,%L)$q$,
  (select id from public.reassignment_requests where status='requested'),pg_temp.uid(4)),'Expert proposes Diver B');
reset role;

select pg_temp.act(4);
set local role authenticated;
select is(jsonb_array_length(public.follow_up_reassignments_json()),1,'Diver B sees only the request proposed to them');
select is(public.follow_up_reassignments_json()->0->>'status','awaiting_acceptance','Diver B sees the proposal');
select is(public.follow_up_reassignments_json()->0->>'replacement_name','Diver B','Proposal names the replacement');
select ok(not public.follow_up_can_submit('FU-TWO',pg_temp.today()),'Diver B cannot submit before accepting');
select lives_ok(format($q$select public.respond_replacement(%L,true)$q$,
  public.follow_up_reassignments_json()->0->>'proposal_id'),'Diver B accepts');
select ok(public.follow_up_can_submit('FU-TWO',pg_temp.today()),'Diver B may submit this month');
select is(jsonb_array_length(public.follow_up_assignments_json()),1,'Diver B sees the area this month');
select is(public.submit_follow_up_survey(pg_temp.uid(62),'FU-TWO',pg_temp.today(),0,0,'',100,
  array[pg_temp.uid(80)],null,null,''),'pending','Diver B submits this month''s visit');
select throws_ok(format($q$select public.submit_follow_up_survey(%L,'FU-TWO',%L,0,0,'',null,array[%L]::uuid[],null,null,'')$q$,
  pg_temp.uid(63),(date_trunc('month',pg_temp.today()) - interval '1 day')::date,pg_temp.uid(80)),'42501',null,
  'A replacement cannot submit for another month');
select is(jsonb_array_length(public.follow_up_reassignment_history(
  (public.follow_up_reassignments_json()->0->>'id')::uuid)),3,'History shows request, proposal and acceptance');
reset role;

select pg_temp.act(3);
set local role authenticated;
select ok(not public.follow_up_can_submit('FU-TWO',pg_temp.today()),'Original Diver cannot submit while replaced this month');
select is(jsonb_array_length(public.follow_up_reassignments_json()),2,'Original Diver still sees the requests');
reset role;

-- Next month returns to the original Diver.
select is((cots_private.ensure_month(pg_temp.uid(51),(cots_private.current_month() + interval '1 month')::date)).responsible_diver_id,
  pg_temp.uid(3),'Next month starts with the original Diver again');

-- Assessment shown in the app.
select pg_temp.act(3);
set local role authenticated;
select is(public.latest_area_assessment('FU-TEST'),null,'No assessment yet');
reset role;
select pg_temp.act(2);
set local role authenticated;
select lives_ok(format($q$select public.record_assessment(%L,'High','Count per surveyed area','Many COTS seen')$q$,
  pg_temp.uid(60)),'Expert records an assessment on a completed visit');
reset role;
select pg_temp.act(4);
set local role authenticated;
select is(public.latest_area_assessment('FU-TEST')->>'level','High','The level is shown to divers');
reset role;

select ok(not has_function_privilege('anon','public.follow_up_surveys_json(text,boolean)','EXECUTE'),
  'Visitors who are not signed in cannot read visits');
select ok(not has_function_privilege('authenticated','cots_private.refresh_follow_up_survey(uuid)','EXECUTE'),
  'People cannot force a visit to complete');

select * from finish();
rollback;
