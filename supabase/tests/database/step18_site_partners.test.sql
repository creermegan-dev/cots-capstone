-- Stage 10: site partners (2 main Divers per site). Synthetic fixtures only; everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('d1800000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.act(n integer) returns void language sql as $$
  select set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true)
$$;
create function pg_temp.capture(n integer, o integer, a integer, age interval) returns void language sql as $$
  insert into public.captures(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,
    model_name,model_sha256,source_width,source_height,gps_source)
  values(pg_temp.uid(n),pg_temp.uid(o),pg_temp.uid(n+500),pg_temp.uid(a),now()-age,'device',
    'synthetic-test',repeat('a',64),2048,1536,'unavailable');
  insert into public.detection_items(id,capture_id,item_index,confidence,x1,y1,x2,y2)
  values(pg_temp.uid(n+3000),pg_temp.uid(n),0,0.95,10,10,100,100);
$$;
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
create function pg_temp.partner_notices(person integer) returns text[] language sql as $$
  select coalesce(array_agg(e.action order by e.action), '{}')
  from public.notifications n join public.workflow_events e on e.id = n.event_id
  where n.recipient_id = pg_temp.uid(person) and e.action like 'site_partner%'
$$;
create function pg_temp.req(candidate integer, site integer) returns public.site_partner_requests
language sql security definer as $$
  select r.* from public.site_partner_requests r
  join public.follow_up_assignments a on a.id = r.assignment_id
  where r.candidate_id = pg_temp.uid(candidate) and a.area_id = pg_temp.uid(site)
  order by r.created_at desc limit 1
$$;
-- The app's JSON, as person n.
create function pg_temp.json_as(n integer, fn text) returns jsonb language plpgsql as $$
declare j jsonb;
begin
  perform pg_temp.act(n);
  set local role authenticated;
  execute 'select public.' || fn || '()' into j;
  reset role;
  return j;
end $$;

-- 1 Admin, 2 Expert, 3 Maria (Main Diver 1), 4 Juan, 5 Pedro, 6 Ana, 7 unverified Diver.
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'stage10-' || n || '@example.invalid',now() from generate_series(1,7) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select pg_temp.act(2);
set local role authenticated;
select public.verify_personnel(pg_temp.uid(n),true,true) from generate_series(3,6) n;
reset role;
update public.profiles set full_name = case id
  when pg_temp.uid(3) then 'Maria Santos' when pg_temp.uid(4) then 'Juan Dela Cruz'
  when pg_temp.uid(5) then 'Pedro Reyes' when pg_temp.uid(6) then 'Ana Cruz'
  when pg_temp.uid(7) then 'Not Verified' else full_name end;
insert into public.monitoring_areas(id,code,name,geography_version) values
  (pg_temp.uid(10),'STAGE10-A','Test Site A','test-only'),
  (pg_temp.uid(11),'STAGE10-B','Test Site B','test-only');

-- Maria's first COTS photo made her Main Diver 1 of both sites (as before Stage 10).
select pg_temp.capture(20,3,10,interval '60 days');
select pg_temp.capture(21,3,11,interval '60 days');
update public.captures set status='finalized', finalized_at=now() where id in (pg_temp.uid(20),pg_temp.uid(21));
insert into public.follow_up_assignments(id,area_id,primary_diver_id,originating_capture_id) values
  (pg_temp.uid(60),pg_temp.uid(10),pg_temp.uid(3),pg_temp.uid(20)),
  (pg_temp.uid(61),pg_temp.uid(11),pg_temp.uid(3),pg_temp.uid(21));

-- The site page: Maria can invite; nobody is site partner yet.
select is((select x->>'partner_uid' from jsonb_array_elements(pg_temp.json_as(3,'site_teams_json')) x
           where x->>'area_code'='STAGE10-A'), null, 'No site partner at first');
select is((select (x->>'can_invite')::boolean from jsonb_array_elements(pg_temp.json_as(3,'site_teams_json')) x
           where x->>'area_code'='STAGE10-A'), true, 'Main Diver 1 can invite a site partner');
select is(jsonb_array_length(pg_temp.json_as(4,'site_teams_json')), 0, 'Juan sees no site of his own yet');

-- Who may invite whom.
select pg_temp.act(4);
set local role authenticated;
select throws_ok($q$select public.invite_site_partner('STAGE10-A','d1800000-0000-4000-8000-000000000005')$q$,
  '42501', null, 'Only Main Diver 1 can invite');
select throws_ok($q$select public.site_partner_choices_json('STAGE10-A')$q$,
  '42501', null, 'Only Main Diver 1 sees the list of Divers to invite');
reset role;
select pg_temp.act(3);
set local role authenticated;
select is((select array_agg(x->>'name' order by x->>'name') from jsonb_array_elements(public.site_partner_choices_json('STAGE10-A')) x),
  array['Ana Cruz','Juan Dela Cruz','Pedro Reyes'], 'The list has verified Divers only, without Maria herself');
select throws_ok($q$select public.invite_site_partner('STAGE10-A','d1800000-0000-4000-8000-000000000003')$q$,
  '23514', null, 'Maria cannot invite herself');
select throws_ok($q$select public.invite_site_partner('STAGE10-A','d1800000-0000-4000-8000-000000000007')$q$,
  '23514', null, 'An unverified Diver cannot be invited');
select lives_ok($q$select public.invite_site_partner('STAGE10-A','d1800000-0000-4000-8000-000000000004')$q$,
  'Maria invites Juan');
select throws_ok($q$select public.invite_site_partner('STAGE10-A','d1800000-0000-4000-8000-000000000004')$q$,
  '23514', 'This Diver already has an open request for this site', 'No second invitation while one is open');
reset role;
select is((pg_temp.req(4,10)).status, 'invited', 'Juan''s invitation waits for Juan, not the Expert');
select is(pg_temp.partner_notices(4), array['site_partner_invited'], 'Juan is told about the invitation');
select is(pg_temp.partner_notices(2), '{}'::text[], 'The Expert is not asked until Juan accepts');
select is((select (x->>'can_respond')::boolean from jsonb_array_elements(pg_temp.json_as(4,'site_partner_requests_json')) x
           where x->>'area_code'='STAGE10-A'), true, 'Juan can answer the invitation in the app');

-- Pedro records COTS at the site: he becomes a candidate at once (no invitation needed).
select pg_temp.capture(30,5,10,interval '2 hours');
select pg_temp.evidence(30,5);
select is((pg_temp.req(5,10)).status, 'waiting_expert', 'Pedro, who recorded at the site, waits for the Expert');
select is((pg_temp.req(5,10)).source, 'recorded', 'Pedro''s request comes from his record');
select ok('site_partner_needs_approval' = any(pg_temp.partner_notices(2)), 'The Expert is asked to approve Pedro');
select is(cots_private.zone_review_needed(pg_temp.uid(30)), true, 'Pedro''s record itself still waits for the Expert');
-- Pedro records again: still one request.
select pg_temp.capture(31,5,10,interval '1 hour');
select pg_temp.evidence(31,5);
select is((select count(*)::integer from public.site_partner_requests where candidate_id=pg_temp.uid(5)), 1,
  'A second record does not make a second request');
-- Pretend Pedro reached the Expert an hour before Juan (all of this runs in one transaction, at one time).
update public.site_partner_requests set queued_at = now() - interval '1 hour' where id = (pg_temp.req(5,10)).id;

-- Juan accepts: now he also waits for the Expert. Only Juan can answer.
select pg_temp.act(5);
set local role authenticated;
select throws_ok(format($q$select public.respond_site_partner_invite(%L,true)$q$, (pg_temp.req(4,10)).id),
  '42501', null, 'Another Diver cannot answer Juan''s invitation');
reset role;
select pg_temp.act(4);
set local role authenticated;
select is(public.respond_site_partner_invite((pg_temp.req(4,10)).id, true), 'waiting_expert', 'Juan accepts');
reset role;
select ok('site_partner_invite_accepted' = any(pg_temp.partner_notices(3)), 'Maria is told Juan accepted');

-- The Expert sees both candidates, oldest first.
select is((select array_agg(x->>'candidate_name' order by o) from jsonb_array_elements(pg_temp.json_as(2,'site_partner_requests_json')) with ordinality t(x,o)
           where x->>'area_code'='STAGE10-A' and (x->>'can_decide')::boolean),
  array['Pedro Reyes','Juan Dela Cruz'], 'The Expert sees both candidates, the one who came first on top');

-- Only the Expert decides.
select pg_temp.act(3);
set local role authenticated;
select throws_ok(format($q$select public.decide_site_partner(%L,true)$q$, (pg_temp.req(4,10)).id),
  '42501', 'Active Expert required', 'Maria cannot approve her own partner');
reset role;
select pg_temp.act(2);
set local role authenticated;
select is(public.decide_site_partner((pg_temp.req(4,10)).id, true), 'approved', 'The Expert approves Juan');
select throws_ok(format($q$select public.decide_site_partner(%L,true)$q$, (pg_temp.req(5,10)).id),
  '23514', 'This request is no longer waiting for you', 'Pedro''s request can no longer be approved');
reset role;
select is((pg_temp.req(5,10)).status, 'closed', 'Approving Juan closed Pedro''s request (place already filled)');
select ok('site_partner_approved' = any(pg_temp.partner_notices(4)), 'Juan is told he is the site partner');
select ok('site_partner_approved_main' = any(pg_temp.partner_notices(3)), 'Maria is told Juan is her site partner');
select ok('site_partner_closed' = any(pg_temp.partner_notices(5)), 'Pedro is told the place was filled');
select is(cots_private.main_divers(pg_temp.uid(60)), array[pg_temp.uid(3),pg_temp.uid(4)], 'The site has 2 main Divers');

-- The site page now shows both, and Maria can invite no one else (and cannot remove Juan).
select is((select x->>'partner_name' from jsonb_array_elements(pg_temp.json_as(3,'site_teams_json')) x
           where x->>'area_code'='STAGE10-A'), 'Juan Dela Cruz', 'Maria''s site page names Juan');
select is((select (x->>'can_invite')::boolean from jsonb_array_elements(pg_temp.json_as(3,'site_teams_json')) x
           where x->>'area_code'='STAGE10-A'), false, 'No more invitations once the place is filled');
select is((select x->>'main_diver_name' from jsonb_array_elements(pg_temp.json_as(4,'site_teams_json')) x
           where x->>'area_code'='STAGE10-A'), 'Maria Santos', 'Juan''s site page names Maria');
select pg_temp.act(3);
set local role authenticated;
select throws_ok($q$select public.invite_site_partner('STAGE10-A','d1800000-0000-4000-8000-000000000006')$q$,
  '23514', 'This site already has a site partner', 'A third main Diver cannot be invited');
reset role;
select ok(not exists (select 1 from pg_proc where proname ilike '%remove%partner%'), 'There is no way to remove a site partner');

-- Records after approval: Juan's go straight through; other Divers' still wait; no new candidates.
select pg_temp.capture(40,4,10,interval '1 minute' * -0);
update public.captures set captured_at = now() + interval '1 second' where id = pg_temp.uid(40);
select is(cots_private.zone_review_needed(pg_temp.uid(40)), false, 'Juan''s record after approval does not wait');
select pg_temp.capture(41,4,10,interval '1 day');
select is(cots_private.zone_review_needed(pg_temp.uid(41)), true, 'A photo Juan took before he was approved still waits');
select pg_temp.capture(42,6,10,interval '1 minute');
select pg_temp.evidence(42,6);
select is(cots_private.zone_review_needed(pg_temp.uid(42)), true, 'Ana''s record waits for the Expert');
select is((select count(*)::integer from public.site_partner_requests where candidate_id=pg_temp.uid(6)), 0,
  'Ana does not become a candidate: the place is filled');

-- When the Expert approves Ana's record, both main Divers are told.
select pg_temp.act(2);
set local role authenticated;
select lives_ok($q$select public.record_expert_decision('d1800000-0000-4000-8000-000000000042',null,'approve','Approved after per-COTS review.',null,'[]'::jsonb)$q$,
  'The Expert approves Ana''s record');
reset role;
select lives_ok($q$select public.finalize_capture('d1800000-0000-4000-8000-000000000042')$q$, 'It is finalized');
select is((select array_agg(n.recipient_id order by n.recipient_id) from public.notifications n
           join public.workflow_events e on e.id = n.event_id
           where e.capture_id = pg_temp.uid(42) and e.action = 'zone_record_approved'),
  array[pg_temp.uid(3),pg_temp.uid(4)], 'Both main Divers get the notice');
select is((select e.details->>'title' from public.workflow_events e
           where e.capture_id = pg_temp.uid(42) and e.action = 'zone_record_approved'),
  'COTS recorded at your site', 'The notice says "site"');
select is(cots_private.zone_waiting_text(pg_temp.uid(42)),
  'This site is currently assigned to Maria Santos and Juan Dela Cruz. Your record was sent to the Expert for review.',
  'Ana is told both main Divers'' names');

-- Site B: an invitation declined by the Diver, and a candidate declined by the Expert.
select pg_temp.act(3);
set local role authenticated;
select lives_ok($q$select public.invite_site_partner('STAGE10-B','d1800000-0000-4000-8000-000000000006')$q$, 'Maria invites Ana to site B');
reset role;
select pg_temp.act(6);
set local role authenticated;
select is(public.respond_site_partner_invite((pg_temp.req(6,11)).id, false), 'declined', 'Ana declines');
select throws_ok(format($q$select public.respond_site_partner_invite(%L,true)$q$, (pg_temp.req(6,11)).id),
  '23514', 'This invitation is no longer open', 'A declined invitation cannot be accepted later');
reset role;
select ok('site_partner_invite_declined' = any(pg_temp.partner_notices(3)), 'Maria is told Ana declined');
select pg_temp.capture(50,5,11,interval '1 hour');
select pg_temp.evidence(50,5);
select pg_temp.act(2);
set local role authenticated;
select is(public.decide_site_partner((pg_temp.req(5,11)).id, false), 'declined', 'The Expert declines Pedro for site B');
reset role;
select ok('site_partner_declined' = any(pg_temp.partner_notices(5)), 'Pedro is told');
select is(cots_private.site_partner(pg_temp.uid(61)), null, 'Site B still has no site partner');
select is((select (x->>'can_invite')::boolean from jsonb_array_elements(pg_temp.json_as(3,'site_teams_json')) x
           where x->>'area_code'='STAGE10-B'), true, 'Maria can still invite someone to site B');

-- Privacy and privileges.
select is(jsonb_array_length(pg_temp.json_as(6,'site_partner_requests_json')), 1, 'Ana sees only her own request');
select ok(not has_table_privilege('authenticated','public.site_partner_requests','SELECT'), 'The app cannot read the table directly');
select ok(not has_function_privilege('anon','public.invite_site_partner(text,uuid)','EXECUTE'), 'Visitors cannot invite');
select ok(not has_function_privilege('authenticated','cots_private.site_partner(uuid)','EXECUTE'), 'The rule runs only inside the database');

select * from finish();
rollback;
