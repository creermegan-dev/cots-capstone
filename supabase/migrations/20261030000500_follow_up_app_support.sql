begin;

-- Follow-up monitoring for the Flutter app on Supabase.
--
-- Agreed workflow (unchanged; the database already enforces most of it):
--   * The Diver whose detection is first confirmed in a reef area becomes that
--     area's original Diver (created by finalize_capture).
--   * Each calendar month starts with the original Diver responsible.
--   * A responsible Diver may say they are unavailable for the month; the
--     Expert proposes a replacement for that month only; the replacement
--     accepts or declines. The next month returns to the original Diver.
--
-- This migration adds what the app needs to use it:
--   1. A monthly follow-up visit linked to the detection records the Diver
--      submitted during the visit, with the field counts the app records.
--   2. The visit becomes "completed" once all its detection records are
--      finalized by the trusted worker, using the existing authorization and
--      late-submission rules from finalize_survey.
--   3. Read functions that return assignments, visits and replacement requests
--      with display names (profiles are otherwise private).
--   4. A Diver can cancel their own open replacement request.
--   5. Replacement notifications carry readable titles and wording.

-- 1. Visit details recorded by the app.
alter table public.follow_up_surveys
  add column eliminated_count integer not null default 0 check (eliminated_count >= 0),
  add column elimination_method text not null default '',
  add column surveyed_area_m2 numeric check (surveyed_area_m2 > 0),
  add column survey_date date;

-- Detection records submitted during a visit. A record belongs to one visit.
create table public.survey_captures (
  survey_id uuid not null references public.follow_up_surveys(id),
  capture_id uuid not null unique references public.captures(id),
  primary key (survey_id, capture_id)
);
alter table public.survey_captures enable row level security;
revoke all on public.survey_captures from public, anon, authenticated;
grant select on public.survey_captures to authenticated;
create policy survey_captures_read on public.survey_captures
  for select to authenticated using (cots_private.can_read_survey(survey_id));
create policy trusted_session_required on public.survey_captures as restrictive
  for all to authenticated
  using (cots_private.session_is_trusted()) with check (cots_private.session_is_trusted());
create trigger immutable_history before update or delete on public.survey_captures
  for each row execute function cots_private.reject_history_change();
create trigger immutable_history_truncate before truncate on public.survey_captures
  for each statement execute function cots_private.reject_history_change();

-- 5. Readable wording for follow-up notifications (same signature as before).
create or replace function cots_private.emit_event(rid uuid,sid uuid,action_name text,payload jsonb,recipients uuid[])
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  eid uuid;
  info jsonb := coalesce(payload, '{}'::jsonb);
  area_text text;
  month_date date;
  primary_name text;
begin
  if rid is not null then
    select ma.name || ' (' || ma.code || ')', m.month, p.full_name
      into area_text, month_date, primary_name
    from public.reassignment_requests r
    join public.monthly_authorizations m on m.id = r.authorization_id
    join public.follow_up_assignments a on a.id = m.assignment_id
    join public.monitoring_areas ma on ma.id = a.area_id
    left join public.profiles p on p.id = a.primary_diver_id
    where r.id = rid;
    info := info || jsonb_build_object(
      'title', case action_name
        when 'reassignment_requested' then 'Follow-up replacement requested'
        when 'replacement_proposed' then 'New follow-up assignment'
        when 'replacement_accepted' then 'Replacement accepted'
        when 'replacement_declined' then 'Replacement declined - replacement needed'
        when 'reassignment_closed' then case when coalesce((payload->>'cancelled')::boolean, false)
          then 'Reassignment request cancelled' else 'Pending replacement cancelled' end
        else 'Follow-up reassignment updated' end,
      'body', coalesce(to_char(month_date, 'FMMonth YYYY'), '') || ' · ' || coalesce(area_text, '')
        || E'\nOriginal diver: ' || coalesce(primary_name, '')
        || case when action_name = 'replacement_proposed'
             then E'\nPlease accept or decline this assignment.' else '' end,
      'record_id', rid::text,
      'zone', coalesce(area_text, ''));
  elsif sid is not null then
    select ma.name || ' (' || ma.code || ')', s.month into area_text, month_date
    from public.follow_up_surveys s
    join public.follow_up_assignments a on a.id = s.assignment_id
    join public.monitoring_areas ma on ma.id = a.area_id
    where s.id = sid;
    info := info || jsonb_build_object(
      'title', case action_name
        when 'survey_completed' then 'Follow-up visit completed'
        when 'survey_pending_late_review' then 'Follow-up visit needs late review'
        when 'survey_pending_authorization_review' then 'Follow-up visit needs authorization review'
        else 'Follow-up visit updated' end,
      'body', 'Your ' || coalesce(to_char(month_date, 'FMMonth YYYY'), '') || ' follow-up visit for '
        || coalesce(area_text, 'the monitoring area') || case action_name
          when 'survey_completed' then ' is complete.'
          else ' is waiting for review.' end,
      'record_id', sid::text,
      'zone', coalesce(area_text, ''));
  end if;
  insert into public.workflow_events(request_id,survey_id,actor_id,action,details)
    values(rid,sid,auth.uid(),action_name,info) returning id into eid;
  insert into public.notifications(recipient_id,event_id)
    select distinct x,eid from unnest(recipients) as x where x is not null;
  return eid;
end $$;

-- 2. A visit is completed once every linked detection record is finalized.
-- Same authorization and grace rules as finalize_survey.
create function cots_private.refresh_follow_up_survey(sid uuid) returns void
language plpgsql security definer set search_path = '' as $$
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
      or m.responsible_diver_id <> s.owner_id or m.revision <> s.authorization_revision then
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
end $$;

create function cots_private.refresh_surveys_for_capture() returns trigger
language plpgsql security definer set search_path = '' as $$
declare sid uuid;
begin
  for sid in select x.survey_id from public.survey_captures x where x.capture_id = new.id loop
    perform cots_private.refresh_follow_up_survey(sid);
  end loop;
  return new;
end $$;

create trigger refresh_follow_up_after_capture
after update of status on public.captures
for each row when (old.status is distinct from new.status)
execute function cots_private.refresh_surveys_for_capture();

-- Submit a monthly follow-up visit. Retrying the same visit returns its status.
create function public.submit_follow_up_survey(
  sid uuid,
  area_code text,
  visit_date date,
  observed integer,
  eliminated integer,
  method text,
  surveyed_m2 numeric,
  capture_ids uuid[],
  lat numeric,
  lng numeric,
  notes_text text
) returns text
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  a public.follow_up_assignments;
  m public.monthly_authorizations;
  existing public.follow_up_surveys;
  visit_month date;
  today date := (now() at time zone 'Asia/Manila')::date;
  origin_date date;
  n integer := coalesce(cardinality(capture_ids), 0);
begin
  if uid is null or not cots_private.eligible(uid) then
    raise exception 'Verified diver required' using errcode = '42501';
  end if;
  select x.* into a from public.follow_up_assignments x
  join public.monitoring_areas ma on ma.id = x.area_id where ma.code = area_code;
  if a.id is null then
    raise exception 'This reef monitoring zone has no follow-up assignment' using errcode = '23514';
  end if;
  select * into existing from public.follow_up_surveys where id = sid;
  if found then
    if existing.owner_id <> uid or existing.assignment_id <> a.id then
      raise exception 'This visit belongs to another diver or zone' using errcode = '42501';
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
  if uid <> a.primary_diver_id and visit_month <> cots_private.current_month() then
    raise exception 'Only the authorized diver for this calendar month can submit' using errcode = '42501';
  end if;
  m := cots_private.ensure_month(a.id, visit_month);
  if m.responsible_diver_id <> uid then
    raise exception 'Only the authorized diver for this calendar month can submit' using errcode = '42501';
  end if;
  if n not between 1 and 8 or (select count(distinct x) from unnest(capture_ids) x) <> n then
    raise exception 'Include between 1 and 8 distinct image records per visit' using errcode = '23514';
  end if;
  if exists (
    select 1 from unnest(capture_ids) x
    left join public.captures c on c.id = x
    where c.id is null or c.owner_id <> uid or c.area_id <> a.area_id
  ) then
    raise exception 'An image record is missing or belongs to another diver or zone' using errcode = '23514';
  end if;
  if exists (select 1 from public.survey_captures x where x.capture_id = any(capture_ids)) then
    raise exception 'An image record already belongs to another visit' using errcode = '23514';
  end if;
  if observed is null or eliminated is null or observed < 0 or eliminated < 0 or eliminated > observed then
    raise exception 'Field observations and eliminated counts are invalid' using errcode = '23514';
  end if;
  if eliminated > 0 and length(trim(coalesce(method, ''))) = 0 then
    raise exception 'Record the actual elimination method' using errcode = '23514';
  end if;
  if surveyed_m2 is not null and surveyed_m2 <= 0 then
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
    observed, coalesce(notes_text, ''),
    eliminated, trim(coalesce(method, '')), surveyed_m2, visit_date);
  insert into public.survey_captures(survey_id, capture_id)
  select sid, x from unnest(capture_ids) x;
  perform cots_private.refresh_follow_up_survey(sid);
  return (select status from public.follow_up_surveys where id = sid);
end $$;

-- 3. Read functions (display names come from private profiles).
create function cots_private.assignment_json(aid uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'assignment_id', a.id,
    'area_id', ma.code,
    'area_label', ma.name,
    'barangay', ma.barangay,
    'municipality', ma.municipality,
    'primary_diver_uid', a.primary_diver_id,
    'primary_diver_name', coalesce(p.full_name, ''),
    'initial_capture_id', a.originating_capture_id,
    'initial_date', c.captured_at,
    'initial_detected_count',
      (select count(*) from public.detection_items i where i.capture_id = a.originating_capture_id),
    'initial_collection', 'captures',
    'responsible_uid', coalesce(m.responsible_diver_id, a.primary_diver_id))
  from public.follow_up_assignments a
  join public.monitoring_areas ma on ma.id = a.area_id
  join public.captures c on c.id = a.originating_capture_id
  left join public.profiles p on p.id = a.primary_diver_id
  left join public.monthly_authorizations m
    on m.assignment_id = a.id and m.month = cots_private.current_month()
  where a.id = aid
$$;

-- No area: the caller's areas (original Diver, or this month's replacement).
-- With an area: that area, if the caller may see it.
create function public.follow_up_assignments_json(area_code text default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
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
             then a.primary_diver_id = uid or exists (
               select 1 from public.monthly_authorizations m
               where m.assignment_id = a.id and m.month = cots_private.current_month()
                 and m.responsible_diver_id = uid)
             else ma.code = area_code end)
  ), '[]'::jsonb);
end $$;

create function cots_private.survey_json(sid uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', s.id,
    'area_id', ma.code,
    'area_label', ma.name,
    'barangay', ma.barangay,
    'municipality', ma.municipality,
    'uid', s.owner_id,
    'submitted_by', coalesce(p.full_name, ''),
    'survey_calendar_date',
      to_char(coalesce(s.survey_date, (s.captured_at at time zone 'Asia/Manila')::date), 'YYYY-MM-DD'),
    'field_observed_count', s.observed_count,
    'field_eliminated_count', s.eliminated_count,
    'capture_ids', coalesce((select jsonb_agg(x.capture_id order by x.capture_id)
      from public.survey_captures x where x.survey_id = s.id), '[]'::jsonb),
    'ai_detected_count', (select count(*) from public.survey_captures x
      join public.detection_items i on i.capture_id = x.capture_id where x.survey_id = s.id),
    'submitted_at', s.submitted_at,
    'gps', jsonb_build_object('latitude', s.latitude, 'longitude', s.longitude),
    'surveyed_area_square_meters', s.surveyed_area_m2,
    'elimination_method', s.elimination_method,
    'notes', s.notes,
    'status', s.status)
  from public.follow_up_surveys s
  join public.follow_up_assignments a on a.id = s.assignment_id
  join public.monitoring_areas ma on ma.id = a.area_id
  left join public.profiles p on p.id = s.owner_id
  where s.id = sid
$$;

-- mine_only: the caller's own visits. Otherwise: with an area, that area's
-- visits; without, the caller's visits plus visits in the caller's areas.
create function public.follow_up_surveys_json(area_code text default null, mine_only boolean default false)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Authenticated user required' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(cots_private.survey_json(s.id) order by s.survey_date desc nulls last, s.submitted_at desc)
    from public.follow_up_surveys s
    join public.follow_up_assignments a on a.id = s.assignment_id
    join public.monitoring_areas ma on ma.id = a.area_id
    where cots_private.can_read_survey(s.id)
      and (area_code is null or ma.code = area_code)
      and (case
             when mine_only then s.owner_id = uid
             when area_code is not null then true
             else s.owner_id = uid or a.primary_diver_id = uid or exists (
               select 1 from public.monthly_authorizations m
               where m.assignment_id = a.id and m.month = cots_private.current_month()
                 and m.responsible_diver_id = uid)
           end)
  ), '[]'::jsonb);
end $$;

-- True when the caller may submit a visit for this area and date.
create function public.follow_up_can_submit(area_code text, visit_date date) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select cots_private.eligible(auth.uid())
      and coalesce(m.responsible_diver_id, a.primary_diver_id) = auth.uid()
      and (auth.uid() = a.primary_diver_id
           or date_trunc('month', visit_date)::date = cots_private.current_month())
    from public.follow_up_assignments a
    join public.monitoring_areas ma on ma.id = a.area_id
    left join public.monthly_authorizations m
      on m.assignment_id = a.id and m.month = date_trunc('month', visit_date)::date
    where ma.code = area_code
  ), false)
$$;

create function cots_private.can_see_reassignment(rid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select cots_private.can_read_request(rid) or exists (
    select 1 from public.reassignment_requests r
    join public.monthly_authorizations m on m.id = r.authorization_id
    join public.follow_up_assignments a on a.id = m.assignment_id
    join public.profiles p on p.id = auth.uid()
    where r.id = rid and p.active and a.primary_diver_id = auth.uid())
$$;

create function cots_private.reassignment_json(rid uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', r.id,
    'area_id', ma.code,
    'area_label', ma.name,
    'barangay', ma.barangay,
    'municipality', ma.municipality,
    'primary_uid', a.primary_diver_id,
    'primary_name', coalesce(pp.full_name, ''),
    'year', extract(year from m.month)::integer,
    'month', extract(month from m.month)::integer,
    'responsible_uid', m.responsible_diver_id,
    'requester_uid', r.requester_id,
    'reason', r.reason,
    'status', r.status,
    'revision', r.revision,
    'requested_at', r.requested_at,
    'proposal_id', coalesce(x.id::text, ''),
    'proposal_status', coalesce(x.status, ''),
    'replacement_uid', coalesce(x.replacement_id::text, ''),
    'replacement_name', coalesce(xp.full_name, ''),
    'expert_uid', coalesce(x.expert_id::text, ''))
  from public.reassignment_requests r
  join public.monthly_authorizations m on m.id = r.authorization_id
  join public.follow_up_assignments a on a.id = m.assignment_id
  join public.monitoring_areas ma on ma.id = a.area_id
  left join public.profiles pp on pp.id = a.primary_diver_id
  left join lateral (
    select q.* from public.replacement_proposals q where q.request_id = r.id
    order by (q.status = 'pending') desc, q.proposed_at desc limit 1) x on true
  left join public.profiles xp on xp.id = x.replacement_id
  where r.id = rid
$$;

create function public.follow_up_reassignments_json(request_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'Authenticated user required' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(cots_private.reassignment_json(r.id) order by r.requested_at desc)
    from public.reassignment_requests r
    where (follow_up_reassignments_json.request_id is null or r.id = follow_up_reassignments_json.request_id)
      and cots_private.can_see_reassignment(r.id)
  ), '[]'::jsonb);
end $$;

create function public.follow_up_reassignment_history(request_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not cots_private.can_see_reassignment(request_id) then
    raise exception 'Reassignment request unavailable' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(h.item order by h.n)
    from (
      select row_number() over (order by e.created_at, e.id) as n,
        jsonb_build_object(
          'revision', row_number() over (order by e.created_at, e.id),
          'action', e.action,
          'cancelled', coalesce((e.details->>'cancelled')::boolean, false),
          'actor_uid', coalesce(ap.full_name, 'System'),
          'at', e.created_at,
          'replacement_name', coalesce(rp.full_name, '')) as item
      from public.workflow_events e
      left join public.profiles ap on ap.id = e.actor_id
      left join public.replacement_proposals q
        on q.id = case when e.details->>'proposal' ~ '^[0-9a-f-]{36}$'
                       then (e.details->>'proposal')::uuid end
      left join public.profiles rp on rp.id = q.replacement_id
      where e.request_id = follow_up_reassignment_history.request_id
    ) h
  ), '[]'::jsonb);
end $$;

-- Request a replacement for the current month by area code.
create function public.request_follow_up_reassignment(area_code text, reason_text text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare aid uuid;
begin
  if length(trim(coalesce(reason_text, ''))) not between 1 and 2000 then
    raise exception 'Enter a reason of up to 2,000 characters' using errcode = '23514';
  end if;
  select a.id into aid from public.follow_up_assignments a
  join public.monitoring_areas ma on ma.id = a.area_id where ma.code = area_code;
  if aid is null then
    raise exception 'This reef monitoring zone has no follow-up assignment' using errcode = '23514';
  end if;
  return public.request_reassignment(aid, trim(reason_text));
end $$;

-- 4. The Diver who asked (or the Expert) can cancel an open request.
create function public.cancel_reassignment(rid uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  r public.reassignment_requests;
  recipients uuid[];
  expert uuid;
begin
  if cots_private.has_role('expert') then
    perform public.close_reassignment(rid, true);
    return;
  end if;
  select * into r from public.reassignment_requests where id = rid for update;
  if not found or r.requester_id <> auth.uid()
      or not exists (select 1 from public.profiles p where p.id = auth.uid() and p.active) then
    raise exception 'Only the Diver who asked or the Expert can cancel' using errcode = '42501';
  end if;
  if r.status not in ('requested', 'replacement_needed', 'awaiting_acceptance') then
    raise exception 'Request is not open' using errcode = '23514';
  end if;
  if (select m.month from public.monthly_authorizations m where m.id = r.authorization_id)
      <> cots_private.current_month() then
    raise exception 'This calendar month has ended' using errcode = '23514';
  end if;
  select array_agg(replacement_id) into recipients
  from public.replacement_proposals where request_id = rid and status = 'pending';
  update public.replacement_proposals
  set status = case when expires_at <= now() then 'expired' else 'cancelled' end, responded_at = now()
  where request_id = rid and status = 'pending';
  update public.reassignment_requests set status = 'cancelled', revision = revision + 1 where id = rid;
  select user_id into expert from public.privileged_role_slots where role = 'expert';
  perform cots_private.emit_event(rid, null, 'reassignment_closed', jsonb_build_object('cancelled', true),
    coalesce(recipients, '{}'::uuid[]) || array[r.requester_id, expert]);
end $$;

-- Latest Expert assessment for an area (level only; shown in the app).
create function public.latest_area_assessment(area_code text) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'level', x.level,
    'validated_by', coalesce(p.full_name, 'Expert'),
    'validated_at', x.assessed_at,
    'survey_date', s.captured_at)
  from public.infestation_assessments x
  join public.follow_up_surveys s on s.id = x.survey_id
  join public.follow_up_assignments a on a.id = s.assignment_id
  join public.monitoring_areas ma on ma.id = a.area_id
  left join public.profiles p on p.id = x.expert_id
  where ma.code = area_code
    and exists (select 1 from public.profiles me where me.id = auth.uid() and me.active)
  order by s.captured_at desc, x.assessed_at desc
  limit 1
$$;

revoke all on function
  cots_private.refresh_follow_up_survey(uuid),
  cots_private.refresh_surveys_for_capture(),
  cots_private.assignment_json(uuid),
  cots_private.survey_json(uuid),
  cots_private.can_see_reassignment(uuid),
  cots_private.reassignment_json(uuid)
from public, anon, authenticated;
revoke all on function
  public.submit_follow_up_survey(uuid,text,date,integer,integer,text,numeric,uuid[],numeric,numeric,text),
  public.follow_up_assignments_json(text),
  public.follow_up_surveys_json(text,boolean),
  public.follow_up_can_submit(text,date),
  public.follow_up_reassignments_json(uuid),
  public.follow_up_reassignment_history(uuid),
  public.request_follow_up_reassignment(text,text),
  public.cancel_reassignment(uuid),
  public.latest_area_assessment(text)
from public, anon;
grant execute on function
  public.submit_follow_up_survey(uuid,text,date,integer,integer,text,numeric,uuid[],numeric,numeric,text),
  public.follow_up_assignments_json(text),
  public.follow_up_surveys_json(text,boolean),
  public.follow_up_can_submit(text,date),
  public.follow_up_reassignments_json(uuid),
  public.follow_up_reassignment_history(uuid),
  public.request_follow_up_reassignment(text,text),
  public.cancel_reassignment(uuid),
  public.latest_area_assessment(text)
to authenticated;

commit;
