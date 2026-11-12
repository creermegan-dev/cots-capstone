begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions,pg_temp;
select no_plan();
create function pg_temp.uid(n int) returns uuid language sql immutable as $$
 select ('d3000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid $$;
insert into auth.users(id,email,email_confirmed_at)
 select pg_temp.uid(n),'month-rule-'||n||'@example.invalid',now() from generate_series(1,5)n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
set local role authenticated;
select public.verify_personnel(pg_temp.uid(3),true,true);
select public.verify_personnel(pg_temp.uid(4),true,true);
reset role;
create temp table point as
 select ma.id,ma.code,6.6+c.iy*30.0/110574.0 as lat,
 125.7+c.ix_start*30.0/110582.25626663613 as lon
 from cots_private.area_cells c join public.monitoring_areas ma on ma.id=c.area_id
 where ma.code='S4' and cots_private.area_at((6.6+c.iy*30.0/110574.0)::float8,
 (125.7+c.ix_start*30.0/110582.25626663613)::float8)=ma.id limit 1;
create function pg_temp.submit_as(person int,rid int, t timestamptz default now(), kind text default 'initial')
returns uuid language plpgsql as $$ declare r uuid; la float8;lo float8;begin
 select lat,lon into la,lo from pg_temp.point;
 perform set_config('request.jwt.claim.sub',pg_temp.uid(person)::text,true);
 set local role authenticated;
 r:=public.submit_no_cots_survey(pg_temp.uid(rid),'S4',kind,t,la,lo,t,8,100,'Month rule',true);
 reset role;return r;
end $$;
create function pg_temp.capture(rid int, t timestamptz, done boolean default true)
returns void language plpgsql as $$ begin
 insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
 model_name,model_sha256,source_width,source_height,gps_source,latitude,longitude,gps_captured_at,gps_accuracy_m)
 select pg_temp.uid(rid),pg_temp.uid(4),pg_temp.uid(rid+1),id,t,'device',
 'synthetic-test',repeat('a',64),640,640,'device_surface',lat,lon,t,8 from pg_temp.point;
 insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
 values(pg_temp.uid(rid+2),pg_temp.uid(rid),0,.95,1,1,20,20);
 if done then update public.captures set status='finalized',finalized_at=now() where id=pg_temp.uid(rid);end if;
end $$;
select is(pg_temp.submit_as(3,20),pg_temp.uid(20),'First no-COTS survey allowed');
select is(pg_temp.submit_as(3,20),pg_temp.uid(20),'Exact retry allowed');
select throws_ok($q$select pg_temp.submit_as(3,21)$q$,'NC001',null,'Same Diver cannot duplicate site month');
select throws_ok($q$select pg_temp.submit_as(4,22)$q$,'NC001',null,'Another Diver cannot duplicate site month');
select throws_ok($q$select pg_temp.submit_as(3,23,now(),'monthly')$q$,'NC001',null,'Monthly and initial entry points share the rule');
select lives_ok($q$select pg_temp.capture(30,now())$q$,'Another Diver can submit COTS after no-COTS survey');
select is((select count(*) from public.no_cots_surveys where id=pg_temp.uid(20)),1::bigint,'Original survey history remains');
select is(pg_temp.submit_as(3,20),pg_temp.uid(20),'Retry of saved survey remains valid after later COTS report');
select throws_ok($q$select pg_temp.submit_as(4,24)$q$,'NC002',null,'Later no-COTS survey blocked after COTS submitted');
select set_config('request.jwt.claim.sub',pg_temp.uid(3)::text,true);
set local role authenticated;
select is((public.no_cots_surveys_json('S4',true)->0->>'cots_reported_later')::boolean,true,'Original survey displays later COTS flag');
select is(jsonb_array_length(public.no_cots_surveys_json('S4',true)),1,'Owner sees one original survey');
reset role;
select is((select count(*) from cots_private.surveys_for_completion where area_id=(select id from pg_temp.point)
 and month=date_trunc('month',now() at time zone 'Asia/Manila')::date),1::bigint,'Visit remains completed once');
-- A different month is independent; unfinished reservations do not block it.
select lives_ok($q$select pg_temp.capture(40,date_trunc('month',now())-interval '10 days',false)$q$,'Unfinished upload reservation fixture');
select is(pg_temp.submit_as(3,50,date_trunc('month',now())-interval '10 days'),pg_temp.uid(50),'Unfinished reservation does not block a survey in another month');
-- A linked upload can still fail trusted verification. It must not be counted
-- merely because it has a link or a local AI result.
select lives_ok($q$select pg_temp.capture(100,date_trunc('month',now())-interval '5 months',false)$q$,'Failed evidence fixture capture');
insert into public.media_assets(id,owner_id,idempotency_key,original_name,original_sha256,
 original_bytes,raw_width,raw_height,source_width,source_height,captured_at,capture_time_source)
 values(pg_temp.uid(103),pg_temp.uid(4),pg_temp.uid(104),'fixture.jpg',repeat('b',64),100,640,640,640,640,now(),'device');
insert into public.media_variants(id,asset_id,kind,version,bucket,object_path,width,height,byte_size,sha256,encoder,upload_status)
 values(pg_temp.uid(105),pg_temp.uid(103),'evidence',1,'detection-evidence','test/month-rule/failed',640,640,100,repeat('b',64),'fixture','failed');
insert into public.capture_evidence(capture_id,variant_id) values(pg_temp.uid(100),pg_temp.uid(105));
select is(pg_temp.submit_as(3,106,date_trunc('month',now())-interval '5 months'),pg_temp.uid(106),'Failed linked evidence does not block a no-COTS survey');
update public.media_variants set upload_status='uploaded',uploaded_at=now()
 where id=pg_temp.uid(105);
select throws_ok($q$select pg_temp.submit_as(3,107,date_trunc('month',now())-interval '5 months')$q$,
 'NC002',null,'Uploaded linked evidence blocks no-COTS while finalization or review is pending');
select lives_ok($q$select pg_temp.capture(60,date_trunc('month',now())-interval '2 months')$q$,'Prior-month successful COTS fixture');
select throws_ok($q$select pg_temp.submit_as(3,70,date_trunc('month',now())-interval '2 months')$q$,'NC002',null,'COTS-first month cannot submit no-COTS even through initial entry');
select throws_ok($q$select pg_temp.submit_as(4,71,date_trunc('month',now())-interval '2 months','monthly')$q$,'NC002',null,'COTS-first month blocked through monthly entry across Divers');
select is(cots_private.capture_confirmed_count(pg_temp.uid(30)),1,'Later COTS retain their confirmed count');
-- Check Philippine month boundaries independently from UTC month boundaries.
select is(cots_private.site_month_has_cots_report((select id from pg_temp.point),date_trunc('month',now() at time zone 'Asia/Manila')::date),true,'Site matching uses Manila calendar month');
select lives_ok($q$select pg_temp.capture(80,
 (date_trunc('month',now() at time zone 'Asia/Manila')-interval '3 months'+interval '30 minutes') at time zone 'Asia/Manila')$q$,
 'Boundary fixture is first Philippine day but previous UTC day');
select throws_ok($q$select pg_temp.submit_as(3,90,
 (date_trunc('month',now() at time zone 'Asia/Manila')-interval '3 months'+interval '1 hour') at time zone 'Asia/Manila')$q$,
 'NC002',null,'Photo and survey use Philippine month even when UTC month differs');
select throws_ok($q$update public.no_cots_surveys set notes='Overwrite' where id=pg_temp.uid(20)$q$,'42501',null,'Original history stays immutable');
select * from finish();
rollback;
