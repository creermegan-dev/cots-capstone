-- Stage 6: messages say "area" (the barangay unit a Diver owns) instead of "zone".
-- Same functions as before (latest definitions from 20261031000400/20261031000200); only the wording changes.

CREATE OR REPLACE FUNCTION cots_private.notify_zone_review(cid uuid, reminder boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
        || ' was submitted by another Diver in an assigned area. Please approve or reject it.'
    end,
    array(select r.user_id from public.privileged_role_slots r where r.role = 'expert'));
end $function$
;

CREATE OR REPLACE FUNCTION public.request_follow_up_reassignment(area_code text, reason_text text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare aid uuid;
begin
  if length(trim(coalesce(reason_text, ''))) not between 1 and 2000 then
    raise exception 'Enter a reason of up to 2,000 characters' using errcode = '23514';
  end if;
  select a.id into aid from public.follow_up_assignments a
  join public.monitoring_areas ma on ma.id = a.area_id where ma.code = area_code;
  if aid is null then
    raise exception 'This monitoring area has no follow-up assignment' using errcode = '23514';
  end if;
  return public.request_reassignment(aid, trim(reason_text));
end $function$
;

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
    raise exception 'This monitoring area has no follow-up assignment' using errcode = '23514';
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
  if uid <> cots_private.main_diver(a.id) and visit_month <> cots_private.current_month() then
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
end $function$
;

CREATE OR REPLACE FUNCTION cots_private.zone_waiting_text(cid uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select 'This area is currently assigned to '
    || coalesce(cots_private.zone_responsible_name(cid), 'another Diver')
    || '. Your record was sent to the Expert for review.'
$function$
;

