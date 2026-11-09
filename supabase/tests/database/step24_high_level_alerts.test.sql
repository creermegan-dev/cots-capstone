-- High site level notice: once per site per month, only High, to Expert, Administrator and main Divers. Rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('d2400000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.rec(n integer, area integer, cots integer, t timestamptz) returns void
language plpgsql as $$
begin
  insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
    model_name,model_sha256,source_width,source_height,gps_source)
  values(pg_temp.uid(n),pg_temp.uid(3),pg_temp.uid(n+500),pg_temp.uid(area),t,'device',
    'synthetic-test',repeat('a',64),2048,1536,'unavailable');
  insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
  select gen_random_uuid(),pg_temp.uid(n),i,0.95,10+i,10,20+i,20 from generate_series(0,cots-1) i;
  update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(n);
end $$;
create function pg_temp.notices(area integer) returns integer language sql as $$
  select count(*)::integer from public.notifications n join public.workflow_events e on e.id = n.event_id
  where e.action = 'site_level_high' and e.details->>'area' = pg_temp.uid(area)::text
$$;

insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'high-' || n || '@example.invalid',now() from generate_series(1,4) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
set local role authenticated;
select public.verify_personnel(pg_temp.uid(3),true,true);
reset role;
insert into public.monitoring_areas(id,code,name,geography_version) values
  (pg_temp.uid(10),'H-A','Outbreak Reef','test-only'), (pg_temp.uid(11),'H-B','Busy Reef','test-only');

-- Site H-A: 101 confirmed COTS this month (High), with Diver 3 as main Diver. Site H-B: exactly 100 (Moderate).
select pg_temp.rec(20,10,60,now());
select pg_temp.rec(21,10,41,now());
insert into public.follow_up_assignments(id,area_id,primary_diver_id,originating_capture_id)
values(pg_temp.uid(60),pg_temp.uid(10),pg_temp.uid(3),pg_temp.uid(20));
select pg_temp.rec(22,11,100,now());

select is(cots_private.send_high_level_alerts(), 1, 'One site reached High: one notice');
select is(pg_temp.notices(10), 3, 'Sent to the Expert, the Administrator and the main Diver');
select ok(exists(select 1 from public.notifications n join public.workflow_events e on e.id=n.event_id
  where e.action='site_level_high' and n.recipient_id = pg_temp.uid(3)), 'The site''s main Diver is told');
select ok(not exists(select 1 from public.notifications n join public.workflow_events e on e.id=n.event_id
  where e.action='site_level_high' and n.recipient_id = pg_temp.uid(4)), 'Other people are not told');
select is(pg_temp.notices(11), 0, 'Exactly 100 COTS is Moderate: no notice');
select is((select e.details->>'title' from public.workflow_events e where e.action='site_level_high' limit 1),
  'Outbreak Reef is now High', 'The notice names the site');
select is(cots_private.send_high_level_alerts(), 0, 'Running again sends nothing (once per site per month)');
select is(pg_temp.notices(10), 3, 'Still one notice per person');
select is(cots_private.send_high_level_alerts(now() + interval '40 days'), 0,
  'A new month without High records sends nothing');
select ok(not has_function_privilege('authenticated','cots_private.send_high_level_alerts(timestamptz)','EXECUTE'),
  'The app cannot trigger notices itself');

select * from finish();
rollback;
