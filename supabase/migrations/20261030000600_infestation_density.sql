begin;

-- Infestation level from COTS density (Dumas et al., 2020).
--
--   density (COTS/ha) = field-observed COTS / (surveyed reef area m² / 10,000)
--   Low       : below 15 COTS/ha          (non-outbreak)
--   Moderate  : 15 to 100 COTS/ha         (potential outbreak)
--   High      : above 100 COTS/ha         (confirmed outbreak)
--
-- The system calculates the level for every follow-up visit; the Expert
-- confirms it, or records a different level with a reason. Thresholds are
-- research guidance: change them here (and in lib/models/cots_density.dart)
-- if the project's marine biologist chooses another rule.

create function cots_private.density_per_ha(observed integer, area_m2 numeric) returns numeric
language sql immutable set search_path = '' as $$
  select case when area_m2 is null or area_m2 <= 0 or observed is null then null
              else round(observed / (area_m2 / 10000.0), 2) end
$$;

create function cots_private.density_level(per_ha numeric) returns text
language sql immutable set search_path = '' as $$
  select case when per_ha is null then null
              when per_ha < 15 then 'Low'
              when per_ha <= 100 then 'Moderate'
              else 'High' end
$$;

-- New visits must record the surveyed area so density can be calculated.
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
    observed, coalesce(notes_text, ''),
    eliminated, trim(coalesce(method, '')), surveyed_m2, visit_date);
  insert into public.survey_captures(survey_id, capture_id)
  select sid, x from unnest(capture_ids) x;
  perform cots_private.refresh_follow_up_survey(sid);
  return (select status from public.follow_up_surveys where id = sid);
end $$;

-- Visit details now include the calculated density and level, and the
-- Expert-confirmed level for that visit (if any).
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
    'density_per_ha', cots_private.density_per_ha(s.observed_count, s.surveyed_area_m2),
    'calculated_level',
      cots_private.density_level(cots_private.density_per_ha(s.observed_count, s.surveyed_area_m2)),
    'assessed_level', (select x.level from public.infestation_assessments x
      where x.survey_id = s.id order by x.assessed_at desc limit 1))
  from public.follow_up_surveys s
  join public.follow_up_assignments a on a.id = s.assignment_id
  join public.monitoring_areas ma on ma.id = a.area_id
  left join public.profiles p on p.id = s.owner_id
  where s.id = sid
$$;

-- Expert: completed visits that still need a confirmed level.
create function public.follow_up_visits_to_assess() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not cots_private.has_role('expert') then
    raise exception 'Expert required' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(cots_private.survey_json(s.id) order by s.survey_date desc nulls last, s.submitted_at desc)
    from public.follow_up_surveys s
    where s.status = 'completed'
      and not exists (select 1 from public.infestation_assessments x where x.survey_id = s.id)
  ), '[]'::jsonb);
end $$;

-- Expert: confirm the calculated level, or choose another with a reason.
-- The calculation is recorded with the assessment.
create function public.confirm_follow_up_assessment(sid uuid, chosen_level text, reason_text text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  s public.follow_up_surveys;
  per_ha numeric;
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
  per_ha := cots_private.density_per_ha(s.observed_count, s.surveyed_area_m2);
  calculated := cots_private.density_level(per_ha);
  if calculated is distinct from chosen_level and length(reason) = 0 then
    raise exception 'Give a reason when the level differs from the calculated level' using errcode = '23514';
  end if;
  if length(reason) > 2000 then
    raise exception 'Reason is too long' using errcode = '23514';
  end if;
  method_text := case
    when per_ha is null then 'Expert judgement (no surveyed area recorded)'
    else format('COTS density (Dumas et al., 2020): %s COTS/ha from %s field-observed COTS over %s m²; calculated level %s',
      per_ha, s.observed_count, s.surveyed_area_m2, calculated) end;
  return public.record_assessment(sid, chosen_level, method_text,
    case when length(reason) = 0 then 'Confirmed the calculated level' else reason end);
end $$;

revoke all on function cots_private.density_per_ha(integer,numeric), cots_private.density_level(numeric)
  from public, anon, authenticated;
revoke all on function public.follow_up_visits_to_assess(),
  public.confirm_follow_up_assessment(uuid,text,text) from public, anon;
grant execute on function public.follow_up_visits_to_assess(),
  public.confirm_follow_up_assessment(uuid,text,text) to authenticated;

commit;
