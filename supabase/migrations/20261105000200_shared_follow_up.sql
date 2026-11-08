-- Stage 11: monthly visits shared by the 2 main Divers (agreed with the user 2026-11-04 22:05 and 2026-11-05 09:49-09:52).
--   * Either main Diver (Main Diver 1 or the site partner) sees the site and records its monthly visit. The month is
--     done at the first visit; if both visit, BOTH visits are saved and counted.
--   * A month is missed only if neither visits (already per site). After 5 missed months the Expert can start a
--     handover; when the new Diver accepts, BOTH main Divers leave the site and the partner place opens.
--   * Either main Diver can ask for a monthly replacement; the accepted replacement covers that month.
--   * The site partner can "Leave site": takes effect at once, Main Diver 1 and the Expert are told, the place opens.
--   * Main Diver 1 hands over while there is a site partner: the partner becomes Main Diver 1 at once (no Expert step),
--     the Expert is told, the place opens. Without a partner: the Stage 4 handover (the Expert offers the site to a Diver
--     who accepts or declines).
--   * Monthly visit reminders to both main Divers (or the month's replacement): on the 1st and on the 16th of the month,
--     only while nobody has visited and the month is not excused (Stage 5).
--   * History is never rewritten: past records and visits stay under the Diver who made them.

-- 1. May this Diver record the visit for this month? The month's responsible Diver, or either main Diver when the
--    month is not covered by a replacement.
create function cots_private.month_ok(aid uuid, person uuid, m date) returns boolean
language sql stable security definer set search_path = '' as $$
  with r as (
    select coalesce((select x.responsible_diver_id from public.monthly_authorizations x
                     where x.assignment_id = aid and x.month = m), cots_private.main_diver(aid)) as resp)
  select person is not null and (person = r.resp
    or (r.resp = any(cots_private.main_divers(aid)) and person = any(cots_private.main_divers(aid))))
  from r
$$;
revoke all on function cots_private.month_ok(uuid, uuid, date) from public, anon, authenticated;


-- 2. Both main Divers can read the site's follow-up.
CREATE OR REPLACE FUNCTION cots_private.can_read_assignment(aid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select cots_private.is_staff() or exists(
    select 1 from public.follow_up_assignments a join public.profiles p on p.id=auth.uid()
    where a.id=aid and p.active and (auth.uid() = any(cots_private.main_divers(a.id)) or exists(
      select 1 from public.monthly_authorizations m where m.assignment_id=a.id
        and m.month=cots_private.current_month() and m.responsible_diver_id=auth.uid()
        and cots_private.eligible(auth.uid()))))
$function$;

CREATE OR REPLACE FUNCTION public.follow_up_assignments_json(area_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Authenticated user required' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(cots_private.assignment_json(a.id) order by ma.code)
    from public.follow_up_assignments a
    join public.monitoring_areas ma on ma.id = a.area_id
    where cots_private.can_read_assignment(a.id)
      and (case when area_code is null
             then uid = any(cots_private.main_divers(a.id)) or exists (
               select 1 from public.monthly_authorizations m
               where m.assignment_id = a.id and m.month = cots_private.current_month()
                 and m.responsible_diver_id = uid)
             else ma.code = area_code end)
  ), '[]'::jsonb);
end $function$;

CREATE OR REPLACE FUNCTION cots_private.can_see_reassignment(rid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select cots_private.can_read_request(rid) or exists (
    select 1 from public.reassignment_requests r
    join public.monthly_authorizations m on m.id = r.authorization_id
    join public.follow_up_assignments a on a.id = m.assignment_id
    join public.profiles p on p.id = auth.uid()
    where r.id = rid and p.active and auth.uid() = any(cots_private.main_divers(a.id)))
$function$;

CREATE OR REPLACE FUNCTION cots_private.assignment_json(aid uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select jsonb_build_object(
    'assignment_id', a.id,
    'area_id', ma.code,
    'area_label', ma.name,
    'barangay', ma.barangay,
    'municipality', ma.municipality,
    'primary_diver_uid', cots_private.main_diver(a.id),
    'primary_diver_name', coalesce(p.full_name, ''),
    'initial_capture_id', a.originating_capture_id,
    'initial_date', c.captured_at,
    'initial_detected_count',
      (select count(*) from public.detection_items i where i.capture_id = a.originating_capture_id),
    'initial_collection', 'captures',
    'responsible_uid', coalesce(m.responsible_diver_id, cots_private.main_diver(a.id)),
    'partner_uid', cots_private.site_partner(a.id),
    'partner_name', case when cots_private.site_partner(a.id) is null then null
                         else cots_private.person_name(cots_private.site_partner(a.id)) end)
  from public.follow_up_assignments a
  join public.monitoring_areas ma on ma.id = a.area_id
  join public.captures c on c.id = a.originating_capture_id
  left join public.profiles p on p.id = cots_private.main_diver(a.id)
  left join public.monthly_authorizations m
    on m.assignment_id = a.id and m.month = cots_private.current_month()
  where a.id = aid
$function$;

-- 3. Who may submit a visit.
CREATE OR REPLACE FUNCTION public.follow_up_can_submit(area_code text, visit_date date)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select coalesce((
    select cots_private.eligible(auth.uid())
      and cots_private.month_ok(a.id, auth.uid(), date_trunc('month', visit_date)::date)
      and (auth.uid() = any(cots_private.main_divers(a.id))
           or date_trunc('month', visit_date)::date = cots_private.current_month())
    from public.follow_up_assignments a
    join public.monitoring_areas ma on ma.id = a.area_id
    left join public.monthly_authorizations m
      on m.assignment_id = a.id and m.month = date_trunc('month', visit_date)::date
    where ma.code = area_code
  ), false)
$function$;

CREATE OR REPLACE FUNCTION public.submit_follow_up_survey(sid uuid, area_code text, visit_date date, observed integer, eliminated integer, method text, surveyed_m2 numeric, capture_ids uuid[], lat numeric, lng numeric, notes_text text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  uid uuid := auth.uid();
  a public.follow_up_assignments;
  m public.monthly_authorizations;
  existing public.follow_up_surveys;
  visit_month date;
  today date := (now() at time zone 'Asia/Manila')::date;
  origin_date date;
  n integer := coalesce(cardinality(capture_ids), 0);
  photo_cots integer;
begin
  if uid is null or not cots_private.eligible(uid) then
    raise exception 'Verified diver required' using errcode = '42501';
  end if;
  select x.* into a from public.follow_up_assignments x
  join public.monitoring_areas ma on ma.id = x.area_id where ma.code = area_code;
  if a.id is null then
    raise exception 'This site has no follow-up assignment' using errcode = '23514';
  end if;
  select * into existing from public.follow_up_surveys where id = sid;
  if found then
    if existing.owner_id <> uid or existing.assignment_id <> a.id then
      raise exception 'This visit belongs to another diver or area' using errcode = '42501';
    end if;
    return existing.status;
  end if;
  if visit_date is null then
    raise exception 'Monitoring date is required' using errcode = '23514';
  end if;
  visit_month := date_trunc('month', visit_date)::date;
  select (c.captured_at at time zone 'Asia/Manila')::date into origin_date
  from public.captures c where c.id = a.originating_capture_id;
  if visit_date > today or visit_date < origin_date then
    raise exception 'Monitoring date must be between the initial detection and today' using errcode = '23514';
  end if;
  -- A replacement Diver may only submit for the current month.
  if not (uid = any(cots_private.main_divers(a.id))) and visit_month <> cots_private.current_month() then
    raise exception 'Only the authorized diver for this calendar month can submit' using errcode = '42501';
  end if;
  m := cots_private.ensure_month(a.id, visit_month);
  if not cots_private.month_ok(a.id, uid, visit_month) then
    raise exception 'Only the authorized diver for this calendar month can submit' using errcode = '42501';
  end if;
  if n not between 1 and 10 or (select count(distinct x) from unnest(capture_ids) x) <> n then
    raise exception 'Include between 1 and 10 distinct image records per visit' using errcode = '23514';
  end if;
  if exists (
    select 1 from unnest(capture_ids) x
    left join public.captures c on c.id = x
    where c.id is null or c.owner_id <> uid or c.area_id <> a.area_id
  ) then
    raise exception 'An image record is missing or belongs to another diver or area' using errcode = '23514';
  end if;
  if exists (select 1 from public.survey_captures x where x.capture_id = any(capture_ids)) then
    raise exception 'An image record already belongs to another visit' using errcode = '23514';
  end if;
  -- "COTS found and removed" comes from the detections stored for the visit
  -- photos (each COTS photographed once). Typed numbers sent by older app
  -- versions are ignored.
  select count(*)::integer into photo_cots
  from public.detection_items i where i.capture_id = any(capture_ids);
  if photo_cots > 0 and length(trim(coalesce(method, ''))) = 0 then
    raise exception 'Record the removal method' using errcode = '23514';
  end if;
  -- The surveyed area is required so the density can be calculated.
  if surveyed_m2 is null then
    raise exception 'Enter the surveyed reef area in square meters' using errcode = '23514';
  end if;
  if surveyed_m2 <= 0 then
    raise exception 'Surveyed reef area must be greater than zero' using errcode = '23514';
  end if;
  if (lat is null) <> (lng is null) then
    raise exception 'Provide a valid coordinate pair or leave both blank' using errcode = '23514';
  end if;

  insert into public.follow_up_surveys(
    id, owner_id, idempotency_key, assignment_id, captured_at, month, authorization_revision,
    latitude, longitude, gps_source, observed_count, notes,
    eliminated_count, elimination_method, surveyed_area_m2, survey_date)
  values (
    sid, uid, sid, a.id, visit_date::timestamp at time zone 'Asia/Manila', visit_month, m.revision,
    lat, lng, case when lat is null then 'unavailable' else 'manual_surface' end,
    photo_cots, coalesce(notes_text, ''),
    photo_cots, trim(coalesce(method, '')), surveyed_m2, visit_date);
  insert into public.survey_captures(survey_id, capture_id)
  select sid, x from unnest(capture_ids) x;
  perform cots_private.refresh_follow_up_survey(sid);
  return (select status from public.follow_up_surveys where id = sid);
end $function$;

CREATE OR REPLACE FUNCTION cots_private.refresh_follow_up_survey(sid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  s public.follow_up_surveys;
  m public.monthly_authorizations;
  latest public.expert_decisions;
  total integer;
  open_records integer;
  rejected_records integer;
  next_status text;
  grace_end timestamptz;
begin
  select * into s from public.follow_up_surveys where id = sid for update;
  if not found or s.status in ('completed', 'historical_only') then
    return;
  end if;
  select count(*),
         count(*) filter (where c.status = 'pending'),
         count(*) filter (where c.status = 'rejected')
    into total, open_records, rejected_records
  from public.survey_captures x join public.captures c on c.id = x.capture_id
  where x.survey_id = sid;
  -- Waiting for records, or a rejected record needs correction.
  if total = 0 or open_records > 0 or rejected_records > 0 then
    return;
  end if;
  select * into m from public.monthly_authorizations
  where assignment_id = s.assignment_id and month = s.month;
  grace_end := (s.month + interval '1 month 7 days')::timestamp at time zone 'Asia/Manila';
  select * into latest from public.expert_decisions
  where survey_id = sid order by decision_sequence desc limit 1;
  if latest.decision in ('historical_only', 'reject') then
    next_status := 'historical_only';
  elsif not cots_private.eligible(s.owner_id) or m.id is null
      or not cots_private.month_ok(s.assignment_id, s.owner_id, s.month)
      or (m.responsible_diver_id = s.owner_id and m.revision <> s.authorization_revision) then
    next_status := 'pending_authorization_review';
  elsif s.submitted_at >= grace_end and latest.decision is distinct from 'accept_late' then
    next_status := 'pending_late_review';
  else
    next_status := 'completed';
  end if;
  if next_status = s.status then
    return;
  end if;
  update public.follow_up_surveys
  set status = next_status, completed_at = case when next_status = 'completed' then now() end
  where id = sid;
  perform cots_private.emit_event(null, sid, 'survey_' || next_status, '{}'::jsonb, array[s.owner_id]);
end $function$;

-- 4. Either main Diver can ask for this month's replacement.
CREATE OR REPLACE FUNCTION public.request_reassignment(aid uuid, reason_text text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.monthly_authorizations; rid uuid; expert uuid;
begin
  if not cots_private.eligible(auth.uid()) then raise exception 'Verified diver required' using errcode='42501'; end if;
  m := cots_private.ensure_month(aid,cots_private.current_month());
  if not cots_private.month_ok(aid, auth.uid(), m.month) then raise exception 'Not responsible this month' using errcode='42501'; end if;
  if exists(select 1 from public.follow_up_surveys where assignment_id=aid and month=m.month and status='completed') then
    raise exception 'Monitoring already completed this month' using errcode='23514';
  end if;
  insert into public.reassignment_requests(authorization_id,requester_id,reason) values(m.id,auth.uid(),reason_text) returning id into rid;
  select user_id into expert from public.privileged_role_slots where role='expert';
  perform cots_private.emit_event(rid,null,'reassignment_requested',jsonb_build_object('month',m.month),array[auth.uid(),expert] || cots_private.main_divers(aid));
  return rid;
end $function$;

-- 5. The missed-months list names both main Divers.
CREATE OR REPLACE FUNCTION public.area_missed_months_json()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not cots_private.is_staff() then
    raise exception 'Staff only' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(x.item order by x.missed desc, x.code)
    from (
      select ma.code, cots_private.missed_months_in_a_row(a.id) as missed,
        jsonb_build_object(
          'area_code', ma.code,
          'area_name', ma.name,
          'main_diver_uid', cots_private.main_diver(a.id),
          'main_diver_name', cots_private.main_divers_text(a.id),
          'missed_months', cots_private.missed_months_in_a_row(a.id),
          'open_handover', exists (select 1 from public.area_handovers h
            where h.assignment_id = a.id and h.status in ('requested', 'offered'))) as item
      from public.follow_up_assignments a
      join public.monitoring_areas ma on ma.id = a.area_id
    ) x
  ), '[]'::jsonb);
end $function$;

-- 6. Main Diver 1 hands over.
CREATE OR REPLACE FUNCTION public.request_area_handover(area_code text, reason_text text, note_text text DEFAULT ''::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  a public.follow_up_assignments;
  hid uuid;
  partner uuid;
begin
  if not cots_private.eligible(auth.uid()) then
    raise exception 'Verified diver required' using errcode = '42501';
  end if;
  select f.* into a from public.follow_up_assignments f
  join public.monitoring_areas ma on ma.id = f.area_id where ma.code = area_code;
  if a.id is null or cots_private.main_diver(a.id) <> auth.uid() then
    raise exception 'Only the main Diver can hand over this area' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(reason_text, '')), '') is null then
    raise exception 'Give a reason for the handover' using errcode = '23514';
  end if;
  if exists (select 1 from public.area_handovers h
             where h.assignment_id = a.id and h.status in ('requested', 'offered')) then
    raise exception 'A handover is already open for this area' using errcode = '23514';
  end if;
  -- Stage 11: with a site partner, the partner becomes Main Diver 1 at once (no Expert step).
  partner := cots_private.site_partner(a.id);
  if partner is not null then
    insert into public.area_handovers(assignment_id, from_diver_id, started_by, started_reason,
      reason, handover_note, status, closed_at)
    values (a.id, auth.uid(), auth.uid(), 'diver_request', btrim(reason_text),
      btrim(coalesce(note_text, '')), 'accepted', now())
    returning id into hid;
    update public.site_partner_requests set ended_at = now()
    where assignment_id = a.id and candidate_id = partner and status = 'approved' and ended_at is null;
    insert into public.handover_offers(handover_id, to_diver_id, offered_by, status, responded_at)
    values (hid, partner, auth.uid(), 'accepted', now());
    -- This month and later months that were Main Diver 1's go to the new Main Diver 1.
    update public.monthly_authorizations
    set responsible_diver_id = partner, revision = revision + 1, updated_at = now()
    where assignment_id = a.id and month >= cots_private.current_month() and responsible_diver_id = auth.uid();
    insert into public.audit_events(action, target_id, details)
    values ('area_handover_to_partner', hid,
      jsonb_build_object('assignment', a.id, 'from', auth.uid(), 'to', partner));
    perform cots_private.notify_handover(hid, 'handover_to_partner', 'You are now Main Diver 1',
      cots_private.person_name(auth.uid()) || ' handed over ' || cots_private.area_label(a.id)
        || '. You are now Main Diver 1. You can add a new site partner.', array[partner]);
    perform cots_private.notify_handover(hid, 'handover_to_partner_info', 'Site handed over to the site partner',
      cots_private.person_name(auth.uid()) || ' handed over ' || cots_private.area_label(a.id) || ' to '
        || cots_private.person_name(partner) || ', who is now Main Diver 1. Reason: ' || btrim(reason_text)
        || ' Past records stay under ' || cots_private.person_name(auth.uid()) || '.',
      cots_private.experts() || array[auth.uid()]);
    return hid;
  end if;
  insert into public.area_handovers(assignment_id, from_diver_id, started_by, started_reason,
    reason, handover_note)
  values (a.id, auth.uid(), auth.uid(), 'diver_request', btrim(reason_text),
    btrim(coalesce(note_text, '')))
  returning id into hid;
  perform cots_private.notify_handover(hid, 'handover_requested', 'Area handover requested',
    cots_private.person_name(auth.uid()) || ' asked to hand over ' || cots_private.area_label(a.id)
      || '. Reason: ' || btrim(reason_text) || ' Please choose a new Diver.',
    cots_private.experts() || array[auth.uid()]);
  return hid;
end $function$;


-- 7. When a handover is accepted through the Expert (Stage 4): after missed months BOTH main Divers leave; and the
--    new Main Diver 1 can no longer also be the site partner.
create function cots_private.end_partner_after_handover() returns trigger
language plpgsql security definer set search_path = '' as $$
declare h public.area_handovers; partner uuid;
begin
  if new.status <> 'accepted' or old.status = 'accepted' then return new; end if;
  select * into h from public.area_handovers where id = new.handover_id;
  partner := cots_private.site_partner(h.assignment_id);
  if partner is null then return new; end if;
  if h.started_reason = 'missed_months' or partner = new.to_diver_id then
    update public.site_partner_requests set ended_at = now()
    where assignment_id = h.assignment_id and candidate_id = partner and status = 'approved' and ended_at is null;
    if partner <> new.to_diver_id then
      perform cots_private.notify_handover(h.id, 'site_partner_ended', 'You are no longer a main Diver',
        cots_private.area_label(h.assignment_id) || ' was handed over to ' || cots_private.person_name(new.to_diver_id)
          || ' after months without a visit. Your past records stay under your name.', array[partner]);
    end if;
  end if;
  return new;
end $$;
revoke all on function cots_private.end_partner_after_handover() from public, anon, authenticated;
create trigger end_partner_after_handover after update on public.handover_offers
  for each row execute function cots_private.end_partner_after_handover();

-- 8. The site partner leaves the site.
create function public.leave_site(area_code text) returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); aid uuid; rid uuid;
begin
  select a.id into aid from public.follow_up_assignments a
  join public.monitoring_areas ma on ma.id = a.area_id where ma.code = area_code
  for update of a;
  if aid is null or uid is null or cots_private.site_partner(aid) is distinct from uid then
    raise exception 'Only the site partner can leave the site this way' using errcode = '42501';
  end if;
  update public.site_partner_requests set ended_at = now()
  where assignment_id = aid and candidate_id = uid and status = 'approved' and ended_at is null
  returning id into rid;
  -- This month and later months that were the partner's (a replacement month) go back to Main Diver 1.
  update public.monthly_authorizations
  set responsible_diver_id = cots_private.main_diver(aid), revision = revision + 1, updated_at = now()
  where assignment_id = aid and month >= cots_private.current_month() and responsible_diver_id = uid;
  insert into public.audit_events(action, target_id, details)
  values ('site_partner_left', rid, jsonb_build_object('assignment', aid, 'partner', uid));
  perform cots_private.notify_partner(rid, 'site_partner_left', 'Site partner left the site',
    cots_private.person_name(uid) || ' left ' || cots_private.area_label(aid)
      || '. The site partner place is open again. Past records stay under ' || cots_private.person_name(uid) || '.',
    array[cots_private.main_diver(aid)] || cots_private.experts());
end $$;
revoke all on function public.leave_site(text) from public, anon;
grant execute on function public.leave_site(text) to authenticated;

-- site_teams_json: also say whether the caller is the site partner (for the "Leave site" button).
create or replace function public.site_teams_json() returns jsonb
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
                    and cots_private.eligible(uid),
      'can_leave', cots_private.site_partner(a.id) = uid) order by ma.code)
    from public.follow_up_assignments a
    join public.monitoring_areas ma on ma.id = a.area_id
    where cots_private.is_staff() or uid = any(cots_private.main_divers(a.id))
  ), '[]'::jsonb);
end $$;

-- 9. Monthly visit reminders: on the 1st and on the 16th, to both main Divers (or the month's replacement), only while
--    nobody has visited this month and the month is not excused. Runs every hour (pg_cron on the hosted project).
create function cots_private.send_visit_reminders(at_time timestamptz default now()) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  m date := date_trunc('month', at_time at time zone 'Asia/Manila')::date;
  day integer := extract(day from at_time at time zone 'Asia/Manila')::integer;
  which text;
  resp uuid;
  recipients uuid[];
  eid uuid;
  sent integer := 0;
begin
  for r in
    select a.id, ma.name as area_name,
           date_trunc('month', o.captured_at at time zone 'Asia/Manila')::date as first_month
    from public.follow_up_assignments a
    join public.monitoring_areas ma on ma.id = a.area_id
    join public.captures o on o.id = a.originating_capture_id
    order by ma.code
  loop
    continue when m <= r.first_month;
    continue when cots_private.month_excused(r.id, m);
    continue when exists (select 1 from public.follow_up_surveys s
                          where s.assignment_id = r.id and s.month = m and s.status <> 'historical_only');
    which := case when day >= 16 then 'visit_reminder_second' else 'visit_reminder_first' end;
    continue when exists (select 1 from public.workflow_events e
                          where e.action in (which, case when which = 'visit_reminder_first' then 'visit_reminder_second' end)
                            and e.details->>'assignment' = r.id::text and e.details->>'month' = m::text);
    select coalesce((select x.responsible_diver_id from public.monthly_authorizations x
                     where x.assignment_id = r.id and x.month = m), cots_private.main_diver(r.id)) into resp;
    recipients := case when resp = any(cots_private.main_divers(r.id)) then cots_private.main_divers(r.id)
                       else array[resp] end;
    insert into public.workflow_events(action, details)
    values (which, jsonb_build_object(
      'title', case when which = 'visit_reminder_first' then 'Monthly visit due'
                    else 'Reminder: monthly visit not done yet' end,
      'body', case when which = 'visit_reminder_first'
                then 'This month''s visit for ' || r.area_name || ' is due (' || to_char(m, 'FMMonth YYYY') || ').'
                else 'Nobody has done this month''s visit for ' || r.area_name || ' yet ('
                  || to_char(m, 'FMMonth YYYY') || '). Please visit before the month ends.' end,
      'record_id', r.id::text, 'zone', r.area_name, 'assignment', r.id::text, 'month', m::text))
    returning id into eid;
    insert into public.notifications(recipient_id, event_id)
    select distinct x, eid from unnest(recipients) x
    where x is not null and exists (select 1 from public.profiles p where p.id = x);
    sent := sent + 1;
  end loop;
  return sent;
end $$;
revoke all on function cots_private.send_visit_reminders(timestamptz) from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(j.jobid) from cron.job j where j.jobname = 'cots-visit-reminders';
    perform cron.schedule('cots-visit-reminders', '37 * * * *', 'select cots_private.send_visit_reminders()');
  end if;
end $$;

