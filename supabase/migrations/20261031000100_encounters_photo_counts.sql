begin;

-- Stage 1: one encounter, removed count taken from the photos.
--
-- Agreed rules (claude/agreed_workflow_decisions.md):
--   * A Diver photographs every COTS once (a photo can show many COTS, but the
--     same COTS is never photographed twice), then removes all of them.
--   * One encounter groups the photos. Each photo stays its own detection with
--     its own boxes, evidence and per-COTS Expert review.
--   * Exactly one removal record per encounter, owned by the detecting Diver,
--     linked to the encounter and its first photo. No typed removed number:
--     the app sends the photo total (at least 1).
--   * The final removed number is the CONFIRMED count: COTS at 80% or above
--     unless the Expert rejects them, plus 20-79% COTS the Expert approves.
--   * Monthly visits use the same rule: "COTS found and removed" is taken from
--     the stored detections of the visit photos (zero allowed), up to 10
--     photos, and density uses the confirmed count.
-- Older records without an encounter keep working unchanged.

create table public.encounters (
  id uuid primary key,
  owner_id uuid not null references public.profiles(id),
  idempotency_key uuid not null,
  created_at timestamptz not null default now(),
  unique (owner_id, idempotency_key)
);
alter table public.encounters enable row level security;
revoke all on public.encounters from public, anon, authenticated;
grant select on public.encounters to authenticated;
grant insert (id, owner_id, idempotency_key) on public.encounters to authenticated;
create policy encounters_read on public.encounters for select to authenticated
  using (owner_id = auth.uid() or cots_private.is_staff());
create policy encounters_insert on public.encounters for insert to authenticated
  with check (owner_id = auth.uid() and cots_private.eligible(auth.uid()));
create policy trusted_session_required on public.encounters as restrictive
  for all to authenticated
  using (cots_private.session_is_trusted()) with check (cots_private.session_is_trusted());
create trigger immutable_history before update or delete on public.encounters
  for each row execute function cots_private.reject_history_change();
create trigger immutable_history_truncate before truncate on public.encounters
  for each statement execute function cots_private.reject_history_change();

alter table public.captures add column encounter_id uuid references public.encounters(id);
create index captures_encounter_idx on public.captures(encounter_id);
grant insert (encounter_id) on public.captures to authenticated;

alter table public.eliminations add column encounter_id uuid unique references public.encounters(id);
alter table public.eliminations add constraint eliminations_encounter_count
  check (encounter_id is null or removed_count >= 1);
grant insert (encounter_id) on public.eliminations to authenticated;

-- A photo can only join its own Diver's encounter.
create function cots_private.check_capture_encounter() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.encounter_id is not null and not exists (
    select 1 from public.encounters e where e.id = new.encounter_id and e.owner_id = new.owner_id
  ) then
    raise exception 'This photo belongs to another Diver''s encounter' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger check_capture_encounter before insert on public.captures
  for each row execute function cots_private.check_capture_encounter();

-- The encounter's removal belongs to the same Diver and links to one of the
-- encounter's own photos.
create function cots_private.check_elimination_encounter() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.encounter_id is not null and not exists (
    select 1 from public.encounters e
    join public.captures c on c.encounter_id = e.id
    where e.id = new.encounter_id and e.owner_id = new.owner_id and c.id = new.capture_id
  ) then
    raise exception 'The removal must link to a photo of the Diver''s own encounter' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger check_elimination_encounter before insert on public.eliminations
  for each row execute function cots_private.check_elimination_encounter();

-- Confirmed and waiting counts per photo.
create function cots_private.latest_capture_decision(cid uuid) returns public.expert_decisions
language sql stable security definer set search_path = '' as $$
  select d.* from public.expert_decisions d where d.capture_id = cid
  order by d.decision_sequence desc limit 1
$$;

create function cots_private.capture_confirmed_count(cid uuid) returns integer
language plpgsql stable security definer set search_path = '' as $$
declare
  c public.captures;
  latest public.expert_decisions;
begin
  select * into c from public.captures where id = cid;
  if not found or c.status = 'rejected' then
    return 0;
  end if;
  latest := cots_private.latest_capture_decision(cid);
  if latest.decision = 'reject' then
    return 0;
  end if;
  return cots_private.accepted_detection_count(cid, coalesce(latest.item_decisions, '[]'::jsonb))::integer;
end $$;

create function cots_private.capture_waiting_count(cid uuid) returns integer
language plpgsql stable security definer set search_path = '' as $$
declare
  c public.captures;
  latest public.expert_decisions;
  decisions jsonb;
begin
  select * into c from public.captures where id = cid;
  if not found or c.status = 'rejected' then
    return 0;
  end if;
  latest := cots_private.latest_capture_decision(cid);
  if latest.decision = 'reject' then
    return 0;
  end if;
  decisions := coalesce(latest.item_decisions, '[]'::jsonb);
  return (select count(*)::integer from public.detection_items i
    where i.capture_id = cid and round(i.confidence * 100) between 20 and 79
      and not decisions @> jsonb_build_array(jsonb_build_object('item_id', i.id::text, 'decision', 'approve'))
      and not decisions @> jsonb_build_array(jsonb_build_object('item_id', i.id::text, 'decision', 'reject')));
end $$;

create function cots_private.survey_confirmed_count(sid uuid) returns integer
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(cots_private.capture_confirmed_count(x.capture_id)), 0)::integer
  from public.survey_captures x where x.survey_id = sid
$$;

create function cots_private.survey_waiting_count(sid uuid) returns integer
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(cots_private.capture_waiting_count(x.capture_id)), 0)::integer
  from public.survey_captures x where x.survey_id = sid
$$;

-- Encounter summary for the app and later stages (reports use "confirmed").
create function public.encounter_summary(eid uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  e public.encounters;
begin
  select * into e from public.encounters where id = eid;
  if not found or not (e.owner_id = auth.uid() or cots_private.is_staff()) then
    raise exception 'Encounter unavailable' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'encounter_id', e.id,
    'photos', (select count(*) from public.captures c where c.encounter_id = eid),
    'photo_count', (select count(*) from public.detection_items i
      join public.captures c on c.id = i.capture_id where c.encounter_id = eid),
    'confirmed_count', (select coalesce(sum(cots_private.capture_confirmed_count(c.id)), 0)
      from public.captures c where c.encounter_id = eid),
    'waiting_count', (select coalesce(sum(cots_private.capture_waiting_count(c.id)), 0)
      from public.captures c where c.encounter_id = eid),
    'reported_removed', (select x.removed_count from public.eliminations x where x.encounter_id = eid));
end $$;

-- Monthly visit: count from the visit photos, up to 10 photos.
create or replace function public.submit_follow_up_survey(
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
  photo_cots integer;
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
  if n not between 1 and 10 or (select count(distinct x) from unnest(capture_ids) x) <> n then
    raise exception 'Include between 1 and 10 distinct image records per visit' using errcode = '23514';
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
end $$;

-- Visit details show the confirmed count; density uses it.
create or replace function cots_private.survey_json(sid uuid) returns jsonb
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
    'status', s.status,
    'confirmed_count', cots_private.survey_confirmed_count(s.id),
    'waiting_count', cots_private.survey_waiting_count(s.id),
    'density_per_ha', cots_private.density_per_ha(cots_private.survey_confirmed_count(s.id), s.surveyed_area_m2),
    'calculated_level',
      cots_private.density_level(cots_private.density_per_ha(cots_private.survey_confirmed_count(s.id), s.surveyed_area_m2)),
    'assessed_level', (select x.level from public.infestation_assessments x
      where x.survey_id = s.id order by x.assessed_at desc limit 1))
  from public.follow_up_surveys s
  join public.follow_up_assignments a on a.id = s.assignment_id
  join public.monitoring_areas ma on ma.id = a.area_id
  left join public.profiles p on p.id = s.owner_id
  where s.id = sid
$$;

-- The Expert's assessment uses the confirmed count.
create or replace function public.confirm_follow_up_assessment(sid uuid, chosen_level text, reason_text text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  s public.follow_up_surveys;
  per_ha numeric;
  confirmed integer;
  calculated text;
  reason text := trim(coalesce(reason_text, ''));
  method_text text;
begin
  if not cots_private.has_role('expert') then
    raise exception 'Expert required' using errcode = '42501';
  end if;
  if chosen_level not in ('Low', 'Moderate', 'High') then
    raise exception 'Choose Low, Moderate or High' using errcode = '23514';
  end if;
  select * into s from public.follow_up_surveys where id = sid;
  if not found then
    raise exception 'Follow-up visit not found' using errcode = '23514';
  end if;
  confirmed := cots_private.survey_confirmed_count(sid);
  per_ha := cots_private.density_per_ha(confirmed, s.surveyed_area_m2);
  calculated := cots_private.density_level(per_ha);
  if calculated is distinct from chosen_level and length(reason) = 0 then
    raise exception 'Give a reason when the level differs from the calculated level' using errcode = '23514';
  end if;
  if length(reason) > 2000 then
    raise exception 'Reason is too long' using errcode = '23514';
  end if;
  method_text := case
    when per_ha is null then 'Expert judgement (no surveyed area recorded)'
    else format('COTS density (Dumas et al., 2020): %s COTS/ha from %s confirmed COTS in the visit photos over %s m²; calculated level %s',
      per_ha, confirmed, s.surveyed_area_m2, calculated) end;
  return public.record_assessment(sid, chosen_level, method_text,
    case when length(reason) = 0 then 'Confirmed the calculated level' else reason end);
end $$;

revoke all on function
  cots_private.check_capture_encounter(),
  cots_private.check_elimination_encounter(),
  cots_private.latest_capture_decision(uuid),
  cots_private.capture_confirmed_count(uuid),
  cots_private.capture_waiting_count(uuid),
  cots_private.survey_confirmed_count(uuid),
  cots_private.survey_waiting_count(uuid)
from public, anon, authenticated;
revoke all on function public.encounter_summary(uuid) from public, anon;
grant execute on function public.encounter_summary(uuid) to authenticated;

commit;
