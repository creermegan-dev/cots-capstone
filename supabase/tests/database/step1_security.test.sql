-- Synthetic fixtures only; the complete suite is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();
create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
insert into auth.users(id,email,raw_user_meta_data)
select pg_temp.uid(n),'synthetic-' || n || '@example.invalid',
  '{"full_name":"Synthetic fixture","accountRole":"admin","fieldPersonnelVerified":true}'::jsonb
from generate_series(1,6) as n;
select is((select count(*)::integer from public.profiles where id in (pg_temp.uid(1),pg_temp.uid(2),pg_temp.uid(3),pg_temp.uid(4),pg_temp.uid(5),pg_temp.uid(6))),6,'Auth trigger creates ordinary profiles');
select ok(not (select field_verified from public.profiles where id=pg_temp.uid(3)),'Signup metadata cannot field-verify user');
select is((select count(*)::integer from public.privileged_role_slots),0,'Signup metadata cannot create privileged roles');
select throws_ok('select public.complete_initial_setup()','23514',null,'Setup requires both privileged roles');
select lives_ok('select public.appoint_initial_role(''administrator'',pg_temp.uid(1))','First Administrator assigned');
select throws_ok('select public.appoint_initial_role(''administrator'',pg_temp.uid(3))','23505',null,'Second Administrator rejected by unique role');
select throws_ok('select public.appoint_initial_role(''expert'',pg_temp.uid(1))','23505',null,'Same person cannot occupy both slots');
select lives_ok('select public.appoint_initial_role(''expert'',pg_temp.uid(2))','First Expert assigned');
select throws_ok('select public.appoint_initial_role(''expert'',pg_temp.uid(4))','23505',null,'Second Expert rejected');
select lives_ok('select public.complete_initial_setup()','Both roles seal setup');
select throws_ok('delete from public.privileged_role_slots where role=''expert''','23514',null,'Sealed role cannot be deleted');
select throws_ok('update public.setup_state set completed_at=null','23514',null,'Setup cannot be reopened');
select throws_ok('delete from public.profiles where id=pg_temp.uid(1)','23503',null,'Privileged identity is protected by foreign keys');
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
set local role authenticated;
select lives_ok('select public.verify_personnel(pg_temp.uid(3),true,true)','Administrator verifies Diver A');
select lives_ok('select public.verify_personnel(pg_temp.uid(4),true,true)','Administrator verifies Diver B');
select lives_ok('select public.verify_personnel(pg_temp.uid(5),true,true)','Administrator verifies Diver C');
select throws_ok('select public.verify_personnel(pg_temp.uid(2),true,true)',null,null,'Personnel verification cannot modify Expert');
reset role;
insert into public.monitoring_areas(id,code,name,geography_version)
values(pg_temp.uid(10),'SYNTHETIC','Synthetic local area','test-only');
select set_config('request.jwt.claim.sub',pg_temp.uid(3)::text,true);
set local role authenticated;
select throws_ok('select public.appoint_initial_role(''expert'',pg_temp.uid(3))','42501',null,'Diver cannot call provisioning RPC');
select throws_ok('update public.profiles set field_verified=true where id=pg_temp.uid(3)','42501',null,'Diver cannot self-verify');
select throws_ok('update public.profiles set active=false where id=pg_temp.uid(3)','42501',null,'Diver cannot change account status');
select throws_ok('select public.verify_personnel(pg_temp.uid(3),true,true)','42501',null,'Diver cannot call verification RPC');
select throws_ok('insert into public.privileged_role_slots values(''administrator'',pg_temp.uid(3),now())','42501',null,'Direct self-promotion denied');
select lives_ok('update public.profiles set full_name=''Diver A'' where id=pg_temp.uid(3)','Own ordinary profile fields editable');
insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,model_name,model_sha256,source_width,source_height,gps_source)
values(pg_temp.uid(20),pg_temp.uid(3),pg_temp.uid(20),pg_temp.uid(10),now()-interval '1 hour','device','synthetic-test',repeat('a',64),2048,1536,'unavailable');
select throws_ok($q$insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,model_name,model_sha256,source_width,source_height,gps_source)
values(pg_temp.uid(21),pg_temp.uid(3),pg_temp.uid(20),pg_temp.uid(10),now(),'device','test',repeat('a',64),2048,1536,'unavailable')$q$,'23505',null,'Duplicate client key cannot create another capture');
select throws_ok($q$insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,model_name,model_sha256,source_width,source_height,gps_source,latitude,longitude)
values(pg_temp.uid(21),pg_temp.uid(3),pg_temp.uid(21),pg_temp.uid(10),now(),'device','test',repeat('a',64),2048,1536,'manual_surface',91,125)$q$,'23514',null,'Invalid GPS rejected');
select throws_ok('update public.captures set status=''finalized'',finalized_at=now() where id=pg_temp.uid(20)','42501',null,'Diver cannot finalize capture directly');
insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
values(pg_temp.uid(22),pg_temp.uid(20),0,0.9,10,10,100,100);
select throws_ok($q$insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
values(pg_temp.uid(23),pg_temp.uid(20),1,0.9,10,10,3000,100)$q$,'23514',null,'Boxes cannot exceed source frame');
insert into public.media_assets(id,owner_id,idempotency_key,original_name,original_sha256,original_bytes,raw_width,raw_height,source_width,source_height,captured_at,capture_time_source)
values(pg_temp.uid(30),pg_temp.uid(3),pg_temp.uid(30),'synthetic.jpg',repeat('b',64),1000000,2048,1536,2048,1536,now(),'device');
insert into public.media_variants(id,asset_id,kind,version,bucket,object_path,width,height,byte_size,sha256,encoder)
values(pg_temp.uid(31),pg_temp.uid(30),'evidence',1,'detection-evidence',pg_temp.uid(3)::text || '/' || pg_temp.uid(30)::text || '/' || pg_temp.uid(31)::text,2048,1536,400000,repeat('c',64),'synthetic-test');
select throws_ok('update public.media_variants set upload_status=''verified'' where id=pg_temp.uid(31)','42501',null,'Diver cannot verify image');
select throws_ok('select public.record_verified_media(pg_temp.uid(31),repeat(''c'',64),400000,2048,1536,''fixture'')','42501',null,'Diver cannot invoke byte-verification RPC');
select lives_ok('select public.link_evidence(''capture'',pg_temp.uid(20),pg_temp.uid(31))','Owner links pending evidence');
select throws_ok('select public.finalize_capture(pg_temp.uid(20))','42501',null,'Diver cannot invoke trusted finalizer');
reset role;
select throws_ok('select public.finalize_capture(pg_temp.uid(20))','23514',null,'Unverified evidence cannot finalize capture');
select throws_ok('select public.record_verified_media(pg_temp.uid(31),repeat(''d'',64),400000,2048,1536,''fixture'')','23514',null,'Hash mismatch rejects receipt');
select lives_ok('select public.record_verified_media(pg_temp.uid(31),repeat(''c'',64),400000,2048,1536,''synthetic-local-receipt'')','Trusted verifier records matching receipt');
select lives_ok('select public.finalize_capture(pg_temp.uid(20))','Trusted finalizer establishes first qualifying detection');
select is((select primary_diver_id from public.follow_up_assignments where area_id=pg_temp.uid(10)),pg_temp.uid(3),'Original detector becomes primary');
create temporary table fixture_ids(k text primary key,id uuid);
insert into fixture_ids select 'assignment',id from public.follow_up_assignments where area_id=pg_temp.uid(10);
grant select,insert on fixture_ids to authenticated;
select set_config('request.jwt.claim.sub',pg_temp.uid(5)::text,true);
set local role authenticated;
select is((select count(*)::integer from public.captures where id=pg_temp.uid(20)),0,'Unrelated diver cannot read private capture');
select is((select count(*)::integer from public.media_variants where id=pg_temp.uid(31)),0,'Unrelated diver cannot read private media');
select throws_ok('select public.record_expert_decision(pg_temp.uid(20),null,''reject'',''forged'')','42501',null,'Diver cannot make Expert decision');
select throws_ok('update public.expert_decisions set reason=''forged''','42501',null,'Diver cannot rewrite Expert history');
select throws_ok('update public.audit_events set action=''forged''','42501',null,'Diver cannot edit audit');
select throws_ok('insert into public.notifications(recipient_id,event_id) values(pg_temp.uid(5),gen_random_uuid())','42501',null,'Diver cannot forge notifications');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.uid(3)::text,true);
set local role authenticated;
insert into fixture_ids select 'request',public.request_reassignment((select id from fixture_ids where k='assignment'),'Synthetic unavailable');
select throws_ok('select public.request_reassignment((select id from fixture_ids where k=''assignment''),''Duplicate'')','23505',null,'Duplicate open reassignment blocked');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
set local role authenticated;
select is((select count(*)::integer from public.profiles where id=pg_temp.uid(3)),0,'Expert does not receive full Diver profile');
select is((select count(*)::integer from public.eligible_personnel()),3,'Expert receives eligible directory only');
insert into fixture_ids select 'proposal',public.propose_replacement((select id from fixture_ids where k='request'),pg_temp.uid(4));
reset role;
select is((select responsible_diver_id from public.monthly_authorizations),pg_temp.uid(3),'Expert nomination does not activate replacement');
select set_config('request.jwt.claim.sub',pg_temp.uid(5)::text,true);
set local role authenticated;
select throws_ok('select public.respond_replacement((select id from fixture_ids where k=''proposal''),true)','42501',null,'Only selected replacement can respond');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.uid(4)::text,true);
set local role authenticated;
select lives_ok('select public.respond_replacement((select id from fixture_ids where k=''proposal''),true)','Selected replacement accepts');
select throws_ok('select public.respond_replacement((select id from fixture_ids where k=''proposal''),true)','23514',null,'Duplicate acceptance rejected');
select is((select count(*)::integer from public.follow_up_assignments),1,'Accepted area appears in replacement assignment query');
select is((select count(*)::integer from public.follow_up_surveys),0,'Acceptance does not create or complete survey');
reset role;
select is((select primary_diver_id from public.follow_up_assignments),pg_temp.uid(3),'Acceptance preserves permanent primary');
select is((select responsible_diver_id from cots_private.ensure_month((select id from fixture_ids where k='assignment'),(cots_private.current_month()+interval '1 month')::date)),pg_temp.uid(3),'Next month defaults to original diver');
select set_config('request.jwt.claim.sub',pg_temp.uid(4)::text,true);
set local role authenticated;
insert into public.follow_up_surveys(id,owner_id,idempotency_key,assignment_id,captured_at,month,authorization_revision,gps_source)
select pg_temp.uid(40),pg_temp.uid(4),pg_temp.uid(40),id,now(),cots_private.current_month(),1,'unavailable' from fixture_ids where k='assignment';
insert into public.follow_up_surveys(id,owner_id,idempotency_key,assignment_id,captured_at,month,authorization_revision,gps_source)
select pg_temp.uid(41),pg_temp.uid(4),pg_temp.uid(41),id,now(),cots_private.current_month(),1,'unavailable' from fixture_ids where k='assignment';
select is((select count(*)::integer from public.follow_up_surveys where owner_id=pg_temp.uid(4)),2,'Multiple same-month visits retained');
select throws_ok('update public.follow_up_surveys set status=''completed'',completed_at=now() where id=pg_temp.uid(40)','42501',null,'Diver cannot complete survey directly');
select throws_ok('select public.finalize_survey(pg_temp.uid(40))','42501',null,'Diver cannot invoke trusted survey finalizer');
select throws_ok($q$insert into public.eliminations(id,owner_id,idempotency_key,capture_id,captured_at,removed_count,gps_source)
values(pg_temp.uid(50),pg_temp.uid(4),pg_temp.uid(50),pg_temp.uid(20),now(),-1,'unavailable')$q$,'42501',null,'Removal on another diver''s detection rejected (negative count: step11)');
reset role;
select throws_ok('select public.finalize_survey(pg_temp.uid(40))','23514',null,'Missing evidence cannot finalize survey');
-- Receipt fixtures are metadata only: no claim of actual Storage-byte verification.
insert into public.media_assets(id,owner_id,idempotency_key,original_name,original_sha256,original_bytes,raw_width,raw_height,source_width,source_height,captured_at,capture_time_source)
values(pg_temp.uid(32),pg_temp.uid(4),pg_temp.uid(32),'synthetic.jpg',repeat('e',64),1000000,2048,1536,2048,1536,now(),'device');
insert into public.media_variants(id,asset_id,kind,version,bucket,object_path,width,height,byte_size,sha256,encoder)
values(pg_temp.uid(33),pg_temp.uid(32),'evidence',1,'detection-evidence','fixture-only',2048,1536,400000,repeat('f',64),'synthetic-test');
select set_config('request.jwt.claim.sub',pg_temp.uid(4)::text,true);
set local role authenticated;
select public.link_evidence('survey',pg_temp.uid(40),pg_temp.uid(33));
reset role;
select throws_ok('select public.finalize_survey(pg_temp.uid(40))','23514',null,'Linked but unverified image still blocks completion');
select public.record_verified_media(pg_temp.uid(33),repeat('f',64),400000,2048,1536,'synthetic-local-receipt');
select is(public.finalize_survey(pg_temp.uid(40)),'completed','Verified authorized visit can complete');
-- Preserve an earlier offline origin without silently changing primary ownership.
insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,model_name,model_sha256,source_width,source_height,gps_source)
values(pg_temp.uid(60),pg_temp.uid(4),pg_temp.uid(60),pg_temp.uid(10),now()-interval '3 days','device','synthetic-test',repeat('a',64),2048,1536,'unavailable');
insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
values(pg_temp.uid(61),pg_temp.uid(60),0,0.95,10,10,100,100);
insert into public.capture_evidence values(pg_temp.uid(60),pg_temp.uid(33));
select lives_ok('select public.finalize_capture(pg_temp.uid(60))','Earlier offline detection retained');
select ok((select origin_review_required from public.captures where id=pg_temp.uid(60)),'Earlier origin flagged for review');
select is((select primary_diver_id from public.follow_up_assignments),pg_temp.uid(3),'Earlier offline detector cannot silently replace primary');
insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,model_name,model_sha256,source_width,source_height,gps_source)
values(pg_temp.uid(70),pg_temp.uid(4),pg_temp.uid(70),pg_temp.uid(10),now(),'device','synthetic-test',repeat('a',64),2048,1536,'unavailable');
insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
values(pg_temp.uid(71),pg_temp.uid(70),0,0.5,10,10,100,100),(pg_temp.uid(72),pg_temp.uid(70),1,0.1,100,100,200,200);
insert into public.capture_evidence values(pg_temp.uid(70),pg_temp.uid(33));
select throws_ok('select public.finalize_capture(pg_temp.uid(70))','23514',null,'Review-band detection cannot finalize without Expert');
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
set local role authenticated;
select throws_ok('select public.record_expert_decision(pg_temp.uid(70),null,''approve'',''Missing per-item decisions'')','23514',null,'Blanket approval cannot skip individual review');
select throws_ok($q$select public.record_expert_decision(pg_temp.uid(70),null,'approve','Forged low-confidence approval',null,
  jsonb_build_array(jsonb_build_object('item_id',pg_temp.uid(71),'decision','approve'),jsonb_build_object('item_id',pg_temp.uid(72),'decision','approve')))$q$,
  '23514',null,'Below-20-percent detections cannot be approved');
select lives_ok($q$select public.record_expert_decision(pg_temp.uid(70),null,'correct','One valid detection',1,
  jsonb_build_array(jsonb_build_object('item_id',pg_temp.uid(71),'decision','approve'),jsonb_build_object('item_id',pg_temp.uid(72),'decision','reject')))$q$,
  'Expert supplies individual valid decisions');
reset role;
select lives_ok('select public.finalize_capture(pg_temp.uid(70))','Per-item corrected capture can finalize');
-- Old primary work is retained but cannot complete the replacement month.
insert into public.follow_up_surveys(id,owner_id,idempotency_key,assignment_id,captured_at,month,authorization_revision,gps_source)
select pg_temp.uid(42),pg_temp.uid(3),pg_temp.uid(42),id,now(),cots_private.current_month(),0,'unavailable' from fixture_ids where k='assignment';
insert into public.survey_evidence values(pg_temp.uid(42),pg_temp.uid(31));
select is(public.finalize_survey(pg_temp.uid(42)),'pending_authorization_review','Stale offline authority never completes monitoring');
-- Timestamp classification uses the immutable first server submission, not retry time.
insert into public.follow_up_surveys(id,owner_id,idempotency_key,assignment_id,captured_at,month,authorization_revision,gps_source,submitted_at)
select pg_temp.uid(43),pg_temp.uid(3),pg_temp.uid(43),id,
  ((cots_private.current_month()-interval '1 month')::timestamp at time zone 'Asia/Manila'),
  (cots_private.current_month()-interval '1 month')::date,0,'unavailable',
  (cots_private.current_month()+interval '8 days')::timestamp at time zone 'Asia/Manila'
from fixture_ids where k='assignment';
insert into public.survey_evidence values(pg_temp.uid(43),pg_temp.uid(31));
select is(public.finalize_survey(pg_temp.uid(43)),'pending_late_review','Late record preserved for Expert review');
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
set local role authenticated;
select lives_ok('select public.record_expert_decision(null,pg_temp.uid(43),''accept_late'',''Synthetic supervised late review'')','Expert records late-review approval');
reset role;
select is(public.finalize_survey(pg_temp.uid(43)),'completed','Late approval completes only still-authorized evidence');
select set_config('request.jwt.claim.sub',pg_temp.uid(4)::text,true);
set local role authenticated;
select throws_ok('select public.request_reassignment((select id from fixture_ids where k=''assignment''),''Already completed'')','23514',null,'Completed month cannot be reassigned');
reset role;
-- Expired proposals cannot become permissions, even when the stale row exists.
update public.replacement_proposals set status='pending',expires_at=now()-interval '1 second',proposed_at=now()-interval '2 days' where id=(select id from fixture_ids where k='proposal');
update public.reassignment_requests set status='awaiting_acceptance' where id=(select id from fixture_ids where k='request');
select set_config('request.jwt.claim.sub',pg_temp.uid(4)::text,true);
set local role authenticated;
select throws_ok('select public.respond_replacement((select id from fixture_ids where k=''proposal''),true)','23514',null,'Expired/stale proposal cannot grant authority');
reset role;
select set_config('request.jwt.claim.sub',pg_temp.uid(6)::text,true);
set local role authenticated;
select throws_ok('select public.request_reassignment((select id from fixture_ids where k=''assignment''),''Unverified'')','42501',null,'Unverified user cannot request official reassignment');
select throws_ok('select public.record_assessment(pg_temp.uid(40),''High'',''count'',''forged'')','42501',null,'Diver cannot infer/publish infestation');
reset role;
set local role anon;
select throws_ok('select * from public.captures','42501',null,'Anonymous private record access denied');
select throws_ok('select public.request_reassignment(gen_random_uuid(),''anonymous'')','42501',null,'Anonymous workflow execution denied');
reset role;
select ok(not has_function_privilege('authenticated','public.record_verified_media(uuid,text,bigint,integer,integer,text)','EXECUTE'),'Authenticated cannot execute media verification');
select ok(has_function_privilege('service_role','public.record_verified_media(uuid,text,bigint,integer,integer,text)','EXECUTE'),'Trusted role may record byte verification');
select ok(not has_function_privilege('authenticated','cots_private.ensure_month(uuid,date)','EXECUTE'),'Client cannot initialize arbitrary month authority');
select ok(not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'
  and c.relname in ('profiles','setup_state','privileged_role_slots','monitoring_areas','captures','detection_items',
  'follow_up_assignments','monthly_authorizations','follow_up_surveys','eliminations','media_assets','media_variants',
  'capture_evidence','elimination_evidence','survey_evidence','expert_decisions','reassignment_requests','replacement_proposals',
  'workflow_events','notifications','infestation_assessments','audit_events','recovery_requests') and not c.relrowsecurity),'RLS enabled on every application table');
select * from finish();
rollback;
