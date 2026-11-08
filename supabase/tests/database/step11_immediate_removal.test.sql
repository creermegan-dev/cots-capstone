-- Immediate removal by the detecting Diver; no assignment or review needed first.
-- Synthetic fixtures only; everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('b0000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.act(n integer) returns void language sql as $$
  select set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true)
$$;
create function pg_temp.removal(id integer, owner integer, cap integer, removed integer)
returns text language sql as $$
  select format($q$insert into public.eliminations(id,owner_id,idempotency_key,capture_id,captured_at,
    removed_count,method,latitude,longitude,gps_source) values(%L,%L,%L,%L,now(),%s,'Injection',null,null,'unavailable')$q$,
    pg_temp.uid(id), pg_temp.uid(owner), pg_temp.uid(id + 500), pg_temp.uid(cap),
    coalesce(removed::text, 'null'))
$$;

-- 1 Admin, 2 Expert, 3 Diver A (detects), 4 Diver B.
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'removal-' || n || '@example.invalid',now() from generate_series(1,4) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select pg_temp.act(1);
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
select public.verify_personnel(pg_temp.uid(n),true,true) from generate_series(3,4) n;
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
reset role;
insert into public.monitoring_areas(id,code,name,geography_version)
values(pg_temp.uid(10),'REMOVAL-TEST','Removal Reef','test-only');

-- Diver A's detection: three COTS, one in the Expert-review band, still pending.
insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
  model_name,model_sha256,source_width,source_height,gps_source)
values(pg_temp.uid(20),pg_temp.uid(3),pg_temp.uid(20),pg_temp.uid(10),now(),'device',
  'synthetic-test',repeat('a',64),2048,1536,'unavailable');
insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2) values
  (pg_temp.uid(21),pg_temp.uid(20),0,0.95,10,10,100,100),
  (pg_temp.uid(22),pg_temp.uid(20),1,0.55,120,120,220,220),
  (pg_temp.uid(23),pg_temp.uid(20),2,0.90,300,300,400,400);

select pg_temp.act(3);
set local role authenticated;
select lives_ok(pg_temp.removal(30,3,20,1),
  'The detecting Diver records the immediate removal without any assignment');
reset role;
select is((select status from public.captures where id=pg_temp.uid(20)),'pending',
  'Removal does not wait for the detection to be finalized or reviewed');
select is((select removed_count from public.eliminations where id=pg_temp.uid(30)),1,
  'A partial removal keeps the actual quantity (1 of 3 detected)');
select is((select count(*)::integer from public.follow_up_assignments),0,
  'A removal does not create a follow-up assignment');

select pg_temp.act(3);
set local role authenticated;
select lives_ok(pg_temp.removal(31,3,20,null),
  'A removal without a recorded quantity is stored as not recorded');
reset role;
select is((select removed_count from public.eliminations where id=pg_temp.uid(31)),null,
  'No quantity is assumed when none was recorded');

select pg_temp.act(3);
set local role authenticated;
select throws_ok(pg_temp.removal(36,3,20,-1),'23514',null,'A negative removed quantity is refused');
reset role;

-- Another Diver cannot attach a removal to Diver A's detection.
select pg_temp.act(4);
set local role authenticated;
select throws_ok(pg_temp.removal(32,4,20,1),'42501',null,
  'Another Diver cannot link a removal to someone else''s detection');
select throws_ok(pg_temp.removal(33,3,20,1),'42501',null,
  'A Diver cannot record a removal in someone else''s name');
reset role;

-- Even if Diver B can read the detection through a follow-up area,
-- an initial-encounter removal on it is refused.
update public.captures set status='finalized', finalized_at=now() where id=pg_temp.uid(20);
insert into public.follow_up_assignments(id,area_id,primary_diver_id,originating_capture_id)
values(pg_temp.uid(50),pg_temp.uid(10),pg_temp.uid(4),pg_temp.uid(20));
select pg_temp.act(4);
set local role authenticated;
select ok(exists(select 1 from public.captures where id=pg_temp.uid(20)),
  'Diver B can see the detection through the follow-up area');
select throws_ok(pg_temp.removal(34,4,20,1),'42501',null,
  'A follow-up area does not allow an initial-encounter removal on another Diver''s detection');
reset role;

-- The follow-up visit rule is unchanged: Diver B's own pending visit in the area.
insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
  model_name,model_sha256,source_width,source_height,gps_source)
values(pg_temp.uid(40),pg_temp.uid(4),pg_temp.uid(40),pg_temp.uid(10),now(),'device',
  'synthetic-test',repeat('a',64),2048,1536,'unavailable');
select pg_temp.act(4);
set local role authenticated;
select is(public.submit_follow_up_survey(pg_temp.uid(60),'REMOVAL-TEST',
  (now() at time zone 'Asia/Manila')::date,1,1,'Injection',50,array[pg_temp.uid(40)],null,null,''),
  'pending','Diver B submits a follow-up visit');
select lives_ok(format($q$insert into public.eliminations(id,owner_id,idempotency_key,capture_id,survey_id,
  captured_at,removed_count,method,gps_source) values(%L,%L,%L,%L,%L,now(),1,'Injection','unavailable')$q$,
  pg_temp.uid(35),pg_temp.uid(4),pg_temp.uid(535),pg_temp.uid(20),pg_temp.uid(60)),
  'A removal during the Diver''s own follow-up visit is still allowed');
reset role;

-- Retrying the same submission does not create a duplicate.
select pg_temp.act(3);
set local role authenticated;
select throws_ok(pg_temp.removal(30,3,20,1),'23505',null,'A retried removal is refused as a duplicate');
reset role;
select is((select count(*)::integer from public.eliminations where owner_id=pg_temp.uid(3)),2,
  'Diver A has exactly the two removals submitted');
select is((select primary_diver_id from public.follow_up_assignments where id=pg_temp.uid(50)),pg_temp.uid(4),
  'Follow-up assignments are unaffected');

select * from finish();
rollback;
