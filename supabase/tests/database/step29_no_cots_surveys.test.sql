begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions,pg_temp;
select no_plan();
create function pg_temp.uid(n int) returns uuid language sql immutable as $$
 select ('d2900000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid $$;
insert into auth.users(id,email,email_confirmed_at)
 select pg_temp.uid(n),'no-cots-'||n||'@example.invalid',now() from generate_series(1,5)n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
set local role authenticated;
select public.verify_personnel(pg_temp.uid(3),true,true);
select public.verify_personnel(pg_temp.uid(4),true,true);
reset role;
create temp table point as
 select ma.id,ma.code, 6.6+c.iy*30.0/110574.0 as lat,
 125.7+c.ix_start*30.0/110582.25626663613 as lon
 from cots_private.area_cells c join public.monitoring_areas ma on ma.id=c.area_id
 where ma.code='S4' and cots_private.area_at((6.6+c.iy*30.0/110574.0)::float8,
 (125.7+c.ix_start*30.0/110582.25626663613)::float8)=ma.id limit 1;
create temp table baseline as select
 (select count(*) from public.captures) as captures,
 (select count(*) from public.follow_up_assignments) as assignments,
 (select count(*) from public.expert_decisions) as decisions,
 public.site_month_levels_json() as levels;
create function pg_temp.submit_as(person int, rid int, site text default 'S4', kind text default 'initial',
 tick boolean default true, accuracy float8 default 8, age interval default interval '0') returns uuid
 language plpgsql as $$ declare result uuid; la float8;lo float8; begin
 select lat,lon into la,lo from pg_temp.point;
 perform set_config('request.jwt.claim.sub',pg_temp.uid(person)::text,true);
 set local role authenticated;
 result:=public.submit_no_cots_survey(pg_temp.uid(rid),site,kind,now(),la,lo,now()-age,accuracy,100,'Survey notes',tick);
 reset role; return result; end $$;
create function pg_temp.read_as(person int) returns jsonb language plpgsql as $$ declare j jsonb;begin
 perform set_config('request.jwt.claim.sub',pg_temp.uid(person)::text,true);
 set local role authenticated; j:=public.no_cots_surveys_json('S4');reset role;return j;end $$;
select is((select count(*) from pg_temp.point),1::bigint,'A real site GPS fixture is available');
select is(pg_temp.submit_as(3,20),pg_temp.uid(20),'First no-COTS survey saves without photos or approval');
select is(pg_temp.submit_as(3,20),pg_temp.uid(20),'Retry is idempotent');
select is((select count(*) from public.no_cots_surveys where id=pg_temp.uid(20)),1::bigint,'Retry does not duplicate visit');
select is((select gps_source from public.no_cots_surveys where id=pg_temp.uid(20)),'device_surface','Source is phone GPS');
select is((select count(*) from cots_private.surveys_for_completion where area_id=(select id from pg_temp.point)
 and month=date_trunc('month',now() at time zone 'Asia/Manila')::date and status='completed'),1::bigint,'First report counts as a completed site visit');
select is((select count(*) from public.captures),(select captures from pg_temp.baseline),'No detection record fabricated');
select is((select count(*) from public.follow_up_assignments),(select assignments from pg_temp.baseline),'No site assignment created');
select is((select count(*) from public.expert_decisions),(select decisions from pg_temp.baseline),'No Expert decision created');
select is(public.site_month_levels_json(),(select levels from pg_temp.baseline),'Site levels and COTS totals unchanged');
select is(jsonb_array_length(pg_temp.read_as(3)),1,'Owner sees report');
select is(pg_temp.read_as(3)->0->>'report_status','diver_reported','Clearly labelled Diver-reported');
select is(jsonb_array_length(pg_temp.read_as(4)),0,'Another Diver cannot see private report');
select is(jsonb_array_length(pg_temp.read_as(1)),1,'Admin can see report');
select throws_ok($q$select pg_temp.submit_as(4,20)$q$,'23514',null,'Another owner cannot reuse survey ID');
select throws_ok($q$select pg_temp.submit_as(5,21)$q$,'42501',null,'Unverified Diver refused');
select throws_ok($q$select pg_temp.submit_as(1,21)$q$,'42501',null,'Admin cannot file Diver report');
select throws_ok($q$select pg_temp.submit_as(3,21,'S1')$q$,'23514',null,'Wrong site refused');
select throws_ok($q$select pg_temp.submit_as(3,21,'S4','initial',false)$q$,'23514',null,'Confirmation required');
select throws_ok($q$select pg_temp.submit_as(3,21,'S4','initial',true,-1)$q$,'23514',null,'Invalid accuracy refused');
select throws_ok($q$select pg_temp.submit_as(3,21,'S4','initial',true,8,interval '1 hour')$q$,'23514',null,'Stale GPS refused');
select throws_ok($q$select pg_temp.submit_as(3,21,'S4','invalid')$q$,'23514',null,'Invalid kind refused');
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
set local role authenticated;
select is((public.monthly_report_json(date_trunc('month',now())::date,'S4')->>'no_cots_surveys')::int,1,'Admin report has separate survey count');
select is((public.monthly_report_json(date_trunc('month',now())::date,'S4')->'sites'->0->>'visits')::int,1,'Admin visit history includes first survey without assignment');
select throws_ok($q$update public.no_cots_surveys set notes='Changed' where id=pg_temp.uid(20)$q$,'42501',null,'Direct update refused');
select throws_ok($q$delete from public.no_cots_surveys where id=pg_temp.uid(20)$q$,'42501',null,'Direct deletion refused');
reset role;
select set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',pg_temp.uid(3))::text,true);
select throws_ok($q$select pg_temp.submit_as(3,22)$q$,'42501',null,'Untrusted session refused');
-- Existing assignment: no-COTS visits also satisfy monthly coverage without changing COTS.
reset role;
select set_config('request.jwt.claims','{}',true);
select set_config('request.jwt.claim.sub',pg_temp.uid(3)::text,true);
insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
 model_name,model_sha256,source_width,source_height,gps_source,latitude,longitude,gps_captured_at,gps_accuracy_m)
 select pg_temp.uid(40),pg_temp.uid(3),pg_temp.uid(41),id,now()-interval '2 months','device',
 'synthetic-test',repeat('a',64),640,640,'device_surface',lat,lon,now()-interval '2 months',8 from pg_temp.point;
insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
 values(pg_temp.uid(42),pg_temp.uid(40),0,.95,1,1,20,20);
update public.captures set status='finalized',finalized_at=now() where id=pg_temp.uid(40);
insert into public.follow_up_assignments(id,area_id,primary_diver_id,originating_capture_id)
 select pg_temp.uid(43),id,pg_temp.uid(3),pg_temp.uid(40) from pg_temp.point;
select throws_ok($q$select pg_temp.submit_as(3,44,'S4','monthly')$q$,'NC001',null,'Initial survey already completes the site month; monthly entry cannot duplicate it');
select throws_ok($q$select pg_temp.submit_as(4,45,'S4','monthly')$q$,'42501',null,'Unassigned Diver cannot use monthly assignment flow');
select is((select count(*) from cots_private.surveys_for_completion where assignment_id=pg_temp.uid(43)
 and month=date_trunc('month',now() at time zone 'Asia/Manila')::date),1::bigint,
 'Earlier first survey remains a completed visit after assignment is created');
select is(cots_private.missed_months_in_a_row(pg_temp.uid(43)),1,'Fixture starts with one previously missed month');
create function pg_temp.past_visit() returns uuid language plpgsql as $$ declare la float8;lo float8;result uuid;t timestamptz;
begin
 select lat,lon into la,lo from pg_temp.point;
 t:=date_trunc('month',now())-interval '10 days';
 perform set_config('request.jwt.claim.sub',pg_temp.uid(3)::text,true);
 set local role authenticated;
 result:=public.submit_no_cots_survey(pg_temp.uid(46),'S4','monthly',t,la,lo,t,8,100,'Offline visit',true);
 reset role;return result;end $$;
select is(pg_temp.past_visit(),pg_temp.uid(46),'Offline visit uses original survey and GPS time');
select is(cots_private.missed_months_in_a_row(pg_temp.uid(43)),0,'No-COTS visit stops the missed-month streak');
select lives_ok($q$select cots_private.send_visit_reminders()$q$,'Reminders handle no-COTS completion');
select is((select count(*) from public.workflow_events where action in ('visit_reminder_first','visit_reminder_second')
 and details->>'assignment'=pg_temp.uid(43)::text),0::bigint,'No reminder sent for completed no-COTS month');
select throws_ok($q$update public.no_cots_surveys set notes='Changed' where id=pg_temp.uid(20)$q$,'42501',null,'Survey history is immutable even through direct maintenance writes');
create function pg_temp.practice_visit() returns uuid language plpgsql as $$ declare la float8;lo float8;result uuid;
begin
 select 6.6+c.iy*30.0/110574.0,125.7+c.ix_start*30.0/110582.25626663613 into la,lo
 from cots_private.area_cells c join public.monitoring_areas a on a.id=c.area_id where a.code='P1' limit 1;
 perform set_config('request.jwt.claim.sub',pg_temp.uid(3)::text,true);
 set local role authenticated;
 result:=public.submit_no_cots_survey(pg_temp.uid(48),'P1','initial',now(),la,lo,now(),8,100,'Practice survey',true);
 reset role;return result;end $$;
select is(pg_temp.practice_visit(),pg_temp.uid(48),'Practice survey can be saved for rehearsals');
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
set local role authenticated;
select is((public.monthly_report_json(date_trunc('month',now())::date,null)->>'no_cots_surveys')::int,1,
 'Monthly report excludes practice surveys and earlier months from its survey count');
reset role;
insert into public.monthly_authorizations(assignment_id,month,responsible_diver_id,revision)
 values(pg_temp.uid(43),date_trunc('month',now() at time zone 'Asia/Manila')::date,pg_temp.uid(4),1)
 on conflict(assignment_id,month) do update set responsible_diver_id=excluded.responsible_diver_id;
select is(pg_temp.submit_as(3,20,'S4','initial'),pg_temp.uid(20),'Retry of saved survey remains idempotent after coverage changes');
select throws_ok($q$select pg_temp.submit_as(3,49,'S4','monthly')$q$,'42501',null,'Coverage change still blocks new unauthorized monthly reports');
select * from finish();
rollback;
