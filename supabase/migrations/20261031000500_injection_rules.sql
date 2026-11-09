begin;

-- Stage 5: after an injection removal.
--
-- Agreed (claude/agreed_workflow_decisions.md, approved 2026-10-31):
--   * No reminder on the Follow-up page: Divers know injected COTS can take
--     up to 2 days to die.
--   * Which injections count: vinegar or ox bile injections (and the older
--     "Injection Method") anywhere in the zone, from first encounters and
--     monthly visits, by any Diver. Another Diver's record in an assigned
--     zone counts only after the Expert approves it; a rejected record never
--     counts. Times are the removal's photo time.
--   * A monthly visit within 2 days after a counted injection is allowed but
--     flagged for the Expert: "Visit within 2 days of an injection on
--     [date]: injected COTS may still be alive." No extra notice.
--   * A month is excused when the 2-day wait after a counted injection in
--     that month ends after the month is over. An excused month is not
--     missed (like a visited month), so it also ends the "missed in a row"
--     count.
--   * When the Expert approves another Diver's injection record, the main
--     Diver's notice adds: "COTS were injected ([method]) on [date]. Wait
--     until [date] before this month's visit." (only while the wait is not
--     over yet).
--   * Manual removal: no flag, no excused month, no extra line.

-- Vinegar or ox bile injection, as stored by the app.
create function cots_private.is_injection(method text) returns boolean
language sql immutable set search_path = '' as $$
  select lower(trim(coalesce(method, ''))) in
    ('vinegar injection', 'ox bile / bile salts injection', 'injection method')
$$;

-- "Nov 3, 9:40 AM" in Philippine time.
create function cots_private.ph_time_label(t timestamptz) returns text
language sql stable set search_path = '' as $$
  select to_char(t at time zone 'Asia/Manila', 'Mon FMDD, FMHH12:MI AM')
$$;

-- The injections that count for a zone, with the removal's photo time.
-- survey_id is set when the injection was recorded in a monthly visit.
create function cots_private.zone_injections(aid uuid)
returns table(injected_at timestamptz, method text, survey_id uuid)
language sql stable security definer set search_path = '' as $$
  -- Removal records (first encounters; older visit removals).
  select e.captured_at, e.method, e.survey_id
  from public.follow_up_assignments a
  join public.captures c on c.area_id = a.area_id
  join public.eliminations e on e.capture_id = c.id
  where a.id = aid
    and cots_private.is_injection(e.method)
    and coalesce(e.removed_count, 1) > 0
    and c.status <> 'rejected'
    and (not cots_private.zone_review_needed(c.id) or cots_private.capture_expert_approved(c.id))
  union all
  -- Monthly visits: the visit's removal, timed from its last photo.
  select coalesce((select max(c.captured_at) from public.survey_captures x
                   join public.captures c on c.id = x.capture_id
                   where x.survey_id = s.id), s.captured_at),
         s.elimination_method, s.id
  from public.follow_up_surveys s
  where s.assignment_id = aid
    and cots_private.is_injection(s.elimination_method)
    and s.eliminated_count > 0
    and s.status in ('pending', 'pending_late_review', 'completed')
$$;

-- The flag for a monthly visit made within 2 days after a counted injection
-- (the visit's own injection does not count). Null when there is none.
create function cots_private.early_visit_note(sid uuid) returns text
language sql stable security definer set search_path = '' as $$
  with v as (
    select s.id, s.assignment_id,
      coalesce((select min(c.captured_at) from public.survey_captures x
                join public.captures c on c.id = x.capture_id
                where x.survey_id = s.id), s.captured_at) as visited_at
    from public.follow_up_surveys s where s.id = sid
  )
  select 'Visit within 2 days of an injection on '
      || cots_private.ph_time_label(i.injected_at)
      || ': injected COTS may still be alive.'
  from v cross join lateral cots_private.zone_injections(v.assignment_id) i
  where i.survey_id is distinct from v.id
    and i.injected_at < v.visited_at
    and v.visited_at < i.injected_at + interval '2 days'
  order by i.injected_at desc
  limit 1
$$;

-- A month is excused when the 2-day wait after a counted injection in that
-- month ends after the month is over.
create function cots_private.month_excused(aid uuid, m date) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from cots_private.zone_injections(aid) i
    where date_trunc('month', i.injected_at at time zone 'Asia/Manila')::date = m
      and i.injected_at + interval '2 days'
          > ((m + interval '1 month')::timestamp at time zone 'Asia/Manila'))
$$;

-- Stage 4's count, now with excused months: an excused month is not missed.
create or replace function cots_private.missed_months_in_a_row(aid uuid, as_of date default null)
returns integer
language plpgsql stable security definer set search_path = '' as $$
declare
  first_month date;
  last_handover timestamptz;
  this_month date := coalesce(date_trunc('month', as_of)::date, cots_private.current_month());
  m date;
  missed integer := 0;
begin
  select date_trunc('month', o.captured_at at time zone 'Asia/Manila')::date into first_month
  from public.follow_up_assignments a
  join public.captures o on o.id = a.originating_capture_id
  where a.id = aid;
  if first_month is null then
    return 0;
  end if;
  select max(x.responded_at) into last_handover
  from public.handover_offers x join public.area_handovers h on h.id = x.handover_id
  where h.assignment_id = aid and x.status = 'accepted';
  if last_handover is not null then
    first_month := greatest(first_month,
      date_trunc('month', last_handover at time zone 'Asia/Manila')::date);
  end if;
  first_month := (first_month + interval '1 month')::date;
  m := (this_month - interval '1 month')::date;
  while m >= first_month loop
    exit when exists (select 1 from public.follow_up_surveys s
                      where s.assignment_id = aid and s.month = m)
           or cots_private.month_excused(aid, m);
    missed := missed + 1;
    m := (m - interval '1 month')::date;
  end loop;
  return missed;
end $$;

-- Visit details and the Expert's Assessments tab show the flag.
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
      where x.survey_id = s.id order by x.assessed_at desc limit 1),
    'early_visit_note', cots_private.early_visit_note(s.id))
  from public.follow_up_surveys s
  join public.follow_up_assignments a on a.id = s.assignment_id
  join public.monitoring_areas ma on ma.id = a.area_id
  left join public.profiles p on p.id = s.owner_id
  where s.id = sid
$$;

-- The injection line for the main Diver's approval notice; '' when the
-- record was not an injection or the 2-day wait is already over.
create function cots_private.injection_wait_line(cid uuid) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select ' COTS were injected ('
        || case lower(trim(e.method))
             when 'vinegar injection' then 'Vinegar injection'
             when 'ox bile / bile salts injection' then 'Ox bile / bile salts injection'
             else 'Injection'
           end
        || ') on ' || cots_private.ph_time_label(e.captured_at)
        || '. Wait until ' || cots_private.ph_time_label(e.captured_at + interval '2 days')
        || ' before this month''s visit.'
    from public.captures c
    join public.eliminations e
      on e.capture_id = c.id or (c.encounter_id is not null and e.encounter_id = c.encounter_id)
    where c.id = cid
      and cots_private.is_injection(e.method)
      and coalesce(e.removed_count, 1) > 0
      and e.captured_at + interval '2 days' > now()
    order by e.captured_at desc
    limit 1), '')
$$;

-- Stage 4's finalize_capture with the injection line added to the main
-- Diver's approval notice. Everything else is unchanged.
create or replace function public.finalize_capture(cid uuid)
returns void
language plpgsql security definer set search_path = '' as $$
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
    perform cots_private.notify_capture(cid, 'zone_record_approved', 'COTS recorded in your area',
      'Another Diver recorded COTS in your area' || coalesce(' ' || area_name, '') || ' on '
        || to_char(c.captured_at at time zone 'Asia/Manila', 'FMMonth FMDD, YYYY')
        || '. The Expert approved the record.'
        || cots_private.injection_wait_line(cid),
      array(select cots_private.main_diver(f.id) from public.follow_up_assignments f where f.area_id=c.area_id));
  end if;
  insert into public.audit_events(action,target_id) values('capture_finalized',cid);
end $$;

revoke all on function
  cots_private.is_injection(text),
  cots_private.ph_time_label(timestamptz),
  cots_private.zone_injections(uuid),
  cots_private.early_visit_note(uuid),
  cots_private.month_excused(uuid, date),
  cots_private.injection_wait_line(uuid)
from public, anon, authenticated;

commit;
