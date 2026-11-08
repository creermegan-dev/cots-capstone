-- Stage 10: site partners (agreed with the user 2026-11-04 21:48-23:39).
-- Each site has up to 2 main Divers:
--   * Main Diver 1 = the first Diver to record COTS at the site (automatic, as before: follow_up_assignments,
--     cots_private.main_diver()).
--   * Main Diver 2 = the "site partner". A Diver becomes a candidate when
--       (a) Main Diver 1 invites them and they ACCEPT the invitation, or
--       (b) they record COTS at the site while the partner place is empty.
--     Every candidate needs the Expert's approval. Candidates are shown oldest first (the time they reached the
--     Expert). Approving one closes the others ("Place already filled"). Declining all leaves the place empty.
--   * Main Diver 1 cannot remove a site partner. (Leaving a site / handover for 2 main Divers = Stage 11.)
--   * With both places filled, every other Diver's record waits for the Expert (unchanged rule, now for 2 Divers).
-- Monthly visits shared by the 2 main Divers come in Stage 11.

-- 1. Site partner requests.
create table public.site_partner_requests (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.follow_up_assignments(id),
  candidate_id uuid not null references public.profiles(id),
  source text not null check (source in ('invited', 'recorded')),
  invited_by uuid references public.profiles(id),
  capture_id uuid references public.captures(id),
  status text not null check (status in
    ('invited', 'invite_declined', 'waiting_expert', 'approved', 'declined', 'closed')),
  created_at timestamptz not null default now(),
  queued_at timestamptz,
  decided_at timestamptz,
  decided_by uuid references public.profiles(id),
  ended_at timestamptz,
  check ((source = 'invited') = (invited_by is not null))
);
-- One open request per Diver and site; one site partner per site.
create unique index site_partner_one_open_per_diver on public.site_partner_requests (assignment_id, candidate_id)
  where status in ('invited', 'waiting_expert');
create unique index site_partner_one_per_site on public.site_partner_requests (assignment_id)
  where status = 'approved' and ended_at is null;
alter table public.site_partner_requests enable row level security;
revoke all on public.site_partner_requests from public, anon, authenticated;
-- Same guard as every other protected table (no other policy: the app reads it only through the functions below).
create policy trusted_session_required on public.site_partner_requests as restrictive for all to authenticated
  using (cots_private.session_is_trusted()) with check (cots_private.session_is_trusted());

alter table public.workflow_events add column partner_request_id uuid references public.site_partner_requests(id);

-- 2. Who the site partner is, and whether a Diver is one of a site's main Divers at a time.
create function cots_private.site_partner(aid uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select r.candidate_id from public.site_partner_requests r
  where r.assignment_id = aid and r.status = 'approved' and r.ended_at is null
  order by r.decided_at desc limit 1
$$;

create function cots_private.partner_at(aid uuid, person uuid, at_time timestamptz) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.site_partner_requests r
    where r.assignment_id = aid and r.candidate_id = person and r.status = 'approved'
      and r.decided_at <= at_time and (r.ended_at is null or r.ended_at > at_time))
$$;

create function cots_private.main_divers(aid uuid) returns uuid[]
language sql stable security definer set search_path = '' as $$
  select array_remove(array[cots_private.main_diver(aid), cots_private.site_partner(aid)], null)
$$;

revoke all on function cots_private.site_partner(uuid) from public, anon, authenticated;
revoke all on function cots_private.partner_at(uuid, uuid, timestamptz) from public, anon, authenticated;
revoke all on function cots_private.main_divers(uuid) from public, anon, authenticated;

-- 3. A record waits for the Expert unless its Diver is Main Diver 1, the site partner (approved before the photo
--    was taken), or this month's accepted replacement. Same as before, plus the site partner.
create or replace function cots_private.zone_review_needed(cid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select c.id <> a.originating_capture_id
      and c.owner_id <> cots_private.main_diver(a.id)
      and not cots_private.partner_at(a.id, c.owner_id, c.captured_at)
      and c.owner_id is distinct from m.responsible_diver_id
      and c.captured_at >= o.captured_at
    from public.captures c
    join public.follow_up_assignments a on a.area_id = c.area_id
    join public.captures o on o.id = a.originating_capture_id
    left join public.monthly_authorizations m
      on m.assignment_id = a.id
     and m.month = date_trunc('month', c.captured_at at time zone 'Asia/Manila')::date
    where c.id = cid
  ), false)
$$;

-- Names of the main Divers for messages, e.g. "Maria Santos and Juan Dela Cruz".
create function cots_private.main_divers_text(aid uuid) returns text
language sql stable security definer set search_path = '' as $$
  select string_agg(cots_private.person_name(x.person), ' and ' order by x.n)
  from unnest(cots_private.main_divers(aid)) with ordinality as x(person, n)
$$;
revoke all on function cots_private.main_divers_text(uuid) from public, anon, authenticated;

create or replace function cots_private.zone_waiting_text(cid uuid) returns text
language sql stable security definer set search_path = '' as $$
  select 'This site is currently assigned to '
    || coalesce((select coalesce(cots_private.person_name(m.responsible_diver_id), cots_private.main_divers_text(a.id))
                 from public.captures c
                 join public.follow_up_assignments a on a.area_id = c.area_id
                 left join public.monthly_authorizations m
                   on m.assignment_id = a.id
                  and m.month = date_trunc('month', c.captured_at at time zone 'Asia/Manila')::date
                 where c.id = cid), 'another Diver')
    || '. Your record was sent to the Expert for review.'
$$;

create or replace function cots_private.notify_zone_review(cid uuid, reminder boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare
  area_name text;
  in_text text;
begin
  select a.name into area_name
  from public.captures c join public.monitoring_areas a on a.id = c.area_id
  where c.id = cid;
  in_text := case when area_name is null then '' else ' in ' || area_name end;
  perform cots_private.notify_capture(
    cid,
    case when reminder then 'zone_review_reminder' else 'zone_review_needed' end,
    case when reminder then 'Reminder: record needs your approval' else 'Record needs your approval' end,
    case when reminder
      then 'Reminder: record ' || cots_private.capture_label(cid) || in_text
        || ' is still waiting for your approval.'
      else 'Record ' || cots_private.capture_label(cid) || in_text
        || ' was submitted by a Diver who is not a main Diver of this site. Please approve or reject it.'
    end,
    array(select r.user_id from public.privileged_role_slots r where r.role = 'expert'));
end $$;

-- 4. Notices about site partners (shown in the normal notification lists).
create function cots_private.notify_partner(rid uuid, action_name text, title text, body text, recipients uuid[])
returns void language plpgsql security definer set search_path = '' as $$
declare eid uuid;
begin
  if coalesce(cardinality(recipients), 0) = 0 then return; end if;
  insert into public.workflow_events(partner_request_id, actor_id, action, details)
  values (rid, (select p.id from public.profiles p where p.id = auth.uid()), action_name,
    jsonb_build_object('title', title, 'body', body, 'record_id', rid::text,
      'zone', coalesce((select cots_private.area_label(r.assignment_id)
                        from public.site_partner_requests r where r.id = rid), '')))
  returning id into eid;
  insert into public.notifications(recipient_id, event_id)
  select distinct x, eid from unnest(recipients) as x
  where x is not null and exists (select 1 from public.profiles p where p.id = x);
end $$;
revoke all on function cots_private.notify_partner(uuid, text, text, text, uuid[]) from public, anon, authenticated;

-- 5. Main Diver 1 invites a Diver.
create function public.invite_site_partner(area_code text, diver uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  aid uuid;
  rid uuid;
begin
  select a.id into aid from public.follow_up_assignments a
  join public.monitoring_areas ma on ma.id = a.area_id where ma.code = area_code
  for update of a;
  if aid is null then
    raise exception 'This site has no main Diver yet' using errcode = '23514';
  end if;
  if uid is null or uid <> cots_private.main_diver(aid) or not cots_private.eligible(uid) then
    raise exception 'Only the site''s Main Diver can invite a site partner' using errcode = '42501';
  end if;
  if cots_private.site_partner(aid) is not null then
    raise exception 'This site already has a site partner' using errcode = '23514';
  end if;
  if diver is null or diver = uid or not exists (
      select 1 from public.profiles p where p.id = diver and p.active and p.field_verified
        and not exists (select 1 from public.privileged_role_slots r where r.user_id = p.id)) then
    raise exception 'Choose a verified Diver' using errcode = '23514';
  end if;
  if exists (select 1 from public.site_partner_requests r
             where r.assignment_id = aid and r.candidate_id = diver and r.status in ('invited', 'waiting_expert')) then
    raise exception 'This Diver already has an open request for this site' using errcode = '23514';
  end if;
  insert into public.site_partner_requests(assignment_id, candidate_id, source, invited_by, status)
  values (aid, diver, 'invited', uid, 'invited') returning id into rid;
  perform cots_private.notify_partner(rid, 'site_partner_invited', 'Site partner invitation',
    cots_private.person_name(uid) || ' invited you to be the site partner of ' || cots_private.area_label(aid)
      || '. Please accept or decline.', array[diver]);
  return rid;
end $$;

-- 6. The invited Diver accepts (goes to the Expert) or declines.
create function public.respond_site_partner_invite(rid uuid, accept boolean) returns text
language plpgsql security definer set search_path = '' as $$
declare r public.site_partner_requests;
begin
  select * into r from public.site_partner_requests where id = rid for update;
  if r.id is null or r.candidate_id <> auth.uid() or not cots_private.eligible(auth.uid()) then
    raise exception 'Only the invited Diver can answer' using errcode = '42501';
  end if;
  if r.status <> 'invited' then
    raise exception 'This invitation is no longer open' using errcode = '23514';
  end if;
  if not accept then
    update public.site_partner_requests set status = 'invite_declined', decided_at = now() where id = rid;
    perform cots_private.notify_partner(rid, 'site_partner_invite_declined', 'Site partner invitation declined',
      cots_private.person_name(r.candidate_id) || ' declined your invitation to be the site partner of '
        || cots_private.area_label(r.assignment_id) || '.', array[r.invited_by]);
    return 'declined';
  end if;
  if cots_private.site_partner(r.assignment_id) is not null then
    update public.site_partner_requests set status = 'closed', queued_at = now(), decided_at = now() where id = rid;
    return 'closed';
  end if;
  update public.site_partner_requests set status = 'waiting_expert', queued_at = now() where id = rid;
  perform cots_private.notify_partner(rid, 'site_partner_needs_approval', 'Site partner needs your approval',
    cots_private.person_name(r.candidate_id) || ' accepted ' || cots_private.person_name(r.invited_by)
      || '''s invitation to be the site partner of ' || cots_private.area_label(r.assignment_id)
      || '. Please approve or decline.', cots_private.experts());
  perform cots_private.notify_partner(rid, 'site_partner_invite_accepted', 'Site partner invitation accepted',
    cots_private.person_name(r.candidate_id) || ' accepted your invitation for '
      || cots_private.area_label(r.assignment_id) || '. The Expert will now approve or decline.',
    array[r.invited_by]);
  return 'waiting_expert';
end $$;

-- 7. A Diver who records COTS at a site with an empty partner place becomes a candidate (runs when the record's
--    photo is linked, the same moment the "record needs your approval" notice is sent).
create function cots_private.offer_partner_place() returns trigger
language plpgsql security definer set search_path = '' as $$
declare c public.captures; aid uuid; rid uuid;
begin
  select * into c from public.captures where id = new.capture_id;
  if c.id is null or not cots_private.zone_review_needed(c.id) then return new; end if;
  select a.id into aid from public.follow_up_assignments a where a.area_id = c.area_id;
  if aid is null or cots_private.site_partner(aid) is not null then return new; end if;
  if exists (select 1 from public.monthly_authorizations m
             where m.assignment_id = aid and m.responsible_diver_id = c.owner_id
               and m.month = date_trunc('month', c.captured_at at time zone 'Asia/Manila')::date) then
    return new;
  end if;
  if exists (select 1 from public.site_partner_requests r
             where r.assignment_id = aid and r.candidate_id = c.owner_id
               and r.status in ('invited', 'waiting_expert', 'approved')) then
    -- An open invitation becomes a candidacy only when the Diver accepts it.
    return new;
  end if;
  insert into public.site_partner_requests(assignment_id, candidate_id, source, capture_id, status, queued_at)
  values (aid, c.owner_id, 'recorded', c.id, 'waiting_expert', now()) returning id into rid;
  perform cots_private.notify_partner(rid, 'site_partner_needs_approval', 'Site partner needs your approval',
    cots_private.person_name(c.owner_id) || ' recorded COTS at ' || cots_private.area_label(aid)
      || ', which has no site partner yet. Approve them as the site partner, or decline.',
    cots_private.experts());
  return new;
end $$;
revoke all on function cots_private.offer_partner_place() from public, anon, authenticated;
create trigger offer_partner_place after insert on public.capture_evidence
  for each row execute function cots_private.offer_partner_place();

-- 8. The Expert approves or declines a candidate. Approving one closes the other open requests for the site.
create function public.decide_site_partner(rid uuid, approve boolean) returns text
language plpgsql security definer set search_path = '' as $$
declare r public.site_partner_requests; o record; main uuid;
begin
  if not cots_private.has_role('expert') then
    raise exception 'Active Expert required' using errcode = '42501';
  end if;
  select * into r from public.site_partner_requests where id = rid;
  if r.id is null then
    raise exception 'Unknown site partner request' using errcode = 'P0002';
  end if;
  perform 1 from public.follow_up_assignments where id = r.assignment_id for update;
  select * into r from public.site_partner_requests where id = rid for update;
  if r.status <> 'waiting_expert' then
    raise exception 'This request is no longer waiting for you' using errcode = '23514';
  end if;
  main := cots_private.main_diver(r.assignment_id);
  if not approve then
    update public.site_partner_requests set status = 'declined', decided_at = now(), decided_by = auth.uid()
    where id = rid;
    perform cots_private.notify_partner(rid, 'site_partner_declined', 'Site partner not approved',
      'The Expert did not approve ' || cots_private.person_name(r.candidate_id) || ' as the site partner of '
        || cots_private.area_label(r.assignment_id) || '.',
      array[r.candidate_id, coalesce(r.invited_by, main)]);
    return 'declined';
  end if;
  if cots_private.site_partner(r.assignment_id) is not null then
    raise exception 'This site already has a site partner' using errcode = '23514';
  end if;
  if r.candidate_id = main or not exists (
      select 1 from public.profiles p where p.id = r.candidate_id and p.active and p.field_verified) then
    raise exception 'This Diver can no longer be the site partner' using errcode = '23514';
  end if;
  update public.site_partner_requests set status = 'approved', decided_at = now(), decided_by = auth.uid()
  where id = rid;
  insert into public.audit_events(action, target_id, details)
  values ('site_partner_approved', rid, jsonb_build_object('assignment', r.assignment_id, 'partner', r.candidate_id));
  perform cots_private.notify_partner(rid, 'site_partner_approved', 'You are now a site partner',
    'You are now the site partner of ' || cots_private.area_label(r.assignment_id) || ', together with '
      || cots_private.person_name(main) || '. Your records there no longer wait for the Expert.',
    array[r.candidate_id]);
  perform cots_private.notify_partner(rid, 'site_partner_approved_main', 'Site partner approved',
    cots_private.person_name(r.candidate_id) || ' is now the site partner of '
      || cots_private.area_label(r.assignment_id) || '.', array[main]);
  for o in select * from public.site_partner_requests
           where assignment_id = r.assignment_id and id <> rid and status in ('invited', 'waiting_expert')
  loop
    update public.site_partner_requests
    set status = 'closed', queued_at = coalesce(queued_at, now()), decided_at = now(), decided_by = auth.uid()
    where id = o.id;
    perform cots_private.notify_partner(o.id, 'site_partner_closed', 'Site partner place already filled',
      'The site partner place of ' || cots_private.area_label(r.assignment_id) || ' was filled by '
        || cots_private.person_name(r.candidate_id) || '. Your request is closed.',
      array[o.candidate_id, o.invited_by]);
  end loop;
  return 'approved';
end $$;

-- 9. What the app shows.
-- The signed-in Diver's sites with both main Divers (for the site page and the "Add site partner" button).
create function public.site_teams_json() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Authenticated user required' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'area_code', ma.code,
      'area_name', ma.name,
      'main_diver_uid', cots_private.main_diver(a.id),
      'main_diver_name', cots_private.person_name(cots_private.main_diver(a.id)),
      'partner_uid', cots_private.site_partner(a.id),
      'partner_name', case when cots_private.site_partner(a.id) is null then null
                           else cots_private.person_name(cots_private.site_partner(a.id)) end,
      'can_invite', cots_private.main_diver(a.id) = uid and cots_private.site_partner(a.id) is null
                    and cots_private.eligible(uid)) order by ma.code)
    from public.follow_up_assignments a
    join public.monitoring_areas ma on ma.id = a.area_id
    where cots_private.is_staff() or uid = any(cots_private.main_divers(a.id))
  ), '[]'::jsonb);
end $$;

-- Requests the caller may see: the Expert/Admin all; a Diver those where they are the candidate, the inviter or
-- Main Diver 1. Oldest first by the time they reached the Expert.
create function public.site_partner_requests_json() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := auth.uid(); staff boolean := cots_private.is_staff();
begin
  if uid is null then raise exception 'Authenticated user required' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', r.id,
      'area_code', ma.code,
      'area_name', ma.name,
      'candidate_uid', r.candidate_id,
      'candidate_name', cots_private.person_name(r.candidate_id),
      'source', r.source,
      'invited_by_name', case when r.invited_by is null then null else cots_private.person_name(r.invited_by) end,
      'main_diver_name', cots_private.person_name(cots_private.main_diver(a.id)),
      'status', r.status,
      'created_at', r.created_at,
      'queued_at', r.queued_at,
      'decided_at', r.decided_at,
      'can_respond', r.status = 'invited' and r.candidate_id = uid,
      'can_decide', r.status = 'waiting_expert' and cots_private.has_role('expert'))
      order by (r.status = 'waiting_expert') desc, coalesce(r.queued_at, r.created_at), r.created_at)
    from public.site_partner_requests r
    join public.follow_up_assignments a on a.id = r.assignment_id
    join public.monitoring_areas ma on ma.id = a.area_id
    where staff or r.candidate_id = uid or r.invited_by = uid or cots_private.main_diver(a.id) = uid
  ), '[]'::jsonb);
end $$;

-- Verified Divers that Main Diver 1 can invite (names only).
create function public.site_partner_choices_json(area_code text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := auth.uid(); aid uuid;
begin
  select a.id into aid from public.follow_up_assignments a
  join public.monitoring_areas ma on ma.id = a.area_id where ma.code = area_code;
  if aid is null or uid is null or uid <> cots_private.main_diver(aid) then
    raise exception 'Only the site''s Main Diver can invite a site partner' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('uid', p.id, 'name', cots_private.person_name(p.id))
                     order by lower(coalesce(p.full_name, '')))
    from public.profiles p
    where p.active and p.field_verified and p.id <> uid
      and not exists (select 1 from public.privileged_role_slots s where s.user_id = p.id)
  ), '[]'::jsonb);
end $$;

revoke all on function public.invite_site_partner(text, uuid) from public, anon;
revoke all on function public.respond_site_partner_invite(uuid, boolean) from public, anon;
revoke all on function public.decide_site_partner(uuid, boolean) from public, anon;
revoke all on function public.site_teams_json() from public, anon;
revoke all on function public.site_partner_requests_json() from public, anon;
revoke all on function public.site_partner_choices_json(text) from public, anon;
grant execute on function public.invite_site_partner(text, uuid) to authenticated;
grant execute on function public.respond_site_partner_invite(uuid, boolean) to authenticated;
grant execute on function public.decide_site_partner(uuid, boolean) to authenticated;
grant execute on function public.site_teams_json() to authenticated;
grant execute on function public.site_partner_requests_json() to authenticated;
grant execute on function public.site_partner_choices_json(text) to authenticated;

-- 10. When the Expert approves another Diver's record, both main Divers get the notice (was: Main Diver 1 only).
--     Same function as 20261031000500 otherwise; only the recipients and the word "site" change.
CREATE OR REPLACE FUNCTION public.finalize_capture(cid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare c public.captures; a public.follow_up_assignments; latest public.expert_decisions; needs_review boolean;
  zone_review boolean; area_name text;
begin
  -- Lock the area BEFORE the capture: competing first captures serialize here.
  perform 1 from public.monitoring_areas where id=(select area_id from public.captures where id=cid) for update;
  select * into strict c from public.captures where id=cid for update;
  if c.status='finalized' then return; end if;
  perform 1 from public.profiles where id=c.owner_id for share;
  if c.status<>'pending' or not cots_private.eligible(c.owner_id) or c.captured_at>now()+interval '5 minutes' then raise exception 'Invalid capture state or actor'; end if;
  if not exists(select 1 from public.capture_evidence e join public.media_variants v on v.id=e.variant_id
    where e.capture_id=cid and v.upload_status='verified' and v.kind in ('evidence','supplement')) then
    raise exception 'Verified image evidence required' using errcode='23514';
  end if;
  select * into latest from public.expert_decisions where capture_id=cid order by decision_sequence desc limit 1;
  select coalesce(bool_or(round(confidence*100) between 20 and 79),false) into needs_review from public.detection_items where capture_id=cid;
  zone_review := cots_private.zone_review_needed(cid);
  if latest.decision='reject' then
    update public.captures set status='rejected' where id=cid;
    return;
  end if;
  if (needs_review or zone_review) and (latest.id is null or latest.decision not in ('approve','correct')) then
    raise exception 'Expert review required' using errcode='23514';
  end if;
  if exists(select 1 from public.detection_items where capture_id=cid)
    and cots_private.accepted_detection_count(cid,coalesce(latest.item_decisions,'[]'::jsonb))=0 then
    update public.captures set status='rejected' where id=cid;
    return;
  end if;
  update public.captures set status='finalized',finalized_at=now() where id=cid;
  -- A zero observation never establishes an originating COTS detection or clearance.
  if cots_private.accepted_detection_count(cid,coalesce(latest.item_decisions,'[]'::jsonb))>0 then
    select * into a from public.follow_up_assignments where area_id=c.area_id;
    if a.id is null then
      insert into public.follow_up_assignments(area_id,primary_diver_id,originating_capture_id)
        values(c.area_id,c.owner_id,cid);
    elsif c.captured_at<(select captured_at from public.captures where id=a.originating_capture_id) then
      update public.captures set origin_review_required=true where id=cid;
      insert into public.audit_events(action,target_id,details)
        values('earlier_offline_origin_pending_review',cid,jsonb_build_object('assignment',a.id));
    end if;
  end if;
  if zone_review then
    select ma.name into area_name from public.monitoring_areas ma where ma.id=c.area_id;
    perform cots_private.notify_capture(cid, 'zone_record_approved', 'COTS recorded at your site',
      'Another Diver recorded COTS at your site' || coalesce(' ' || area_name, '') || ' on '
        || to_char(c.captured_at at time zone 'Asia/Manila', 'FMMonth FMDD, YYYY')
        || '. The Expert approved the record.'
        || cots_private.injection_wait_line(cid),
      coalesce((select cots_private.main_divers(f.id) from public.follow_up_assignments f where f.area_id=c.area_id),
        '{}'::uuid[]));
  end if;
  insert into public.audit_events(action,target_id) values('capture_finalized',cid);
end $function$;
