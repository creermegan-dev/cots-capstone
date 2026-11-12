begin;

-- Monthly report (user + Expert, 2026-11-09).
-- One staff-only function that supplies every number in the PDF report, so the report matches the map,
-- Analytics and the records list (same counting rules, no guessing in the app):
--   * Photos are counted by the month they were taken (Asia/Manila), like the monthly site levels.
--   * Confirmed / waiting come from cots_private.capture_confirmed_count / capture_waiting_count.
--     Not accepted = every COTS box the AI found in the photo that is neither confirmed nor waiting.
--   * Practice sites (geographic_reference.practice = true) are left out.
--   * Removal methods count removals submitted in the month (same sources as removal_method_summary).
--   * Expert review: photos of the month with an Expert decision (approved = approve or correct),
--     photos still waiting, average days from submission to the first decision, oldest wait.
-- p_month is any date in the month (null = this month). p_area_code limits everything to one site.

create function public.monthly_report_json(
  p_month date default null,
  p_area_code text default null
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  month_start date := coalesce(date_trunc('month', p_month)::date, cots_private.current_month());
  month_end date;
  missed_as_of date;
  area_filter uuid;
begin
  if not cots_private.is_staff() then
    raise exception 'The monthly report is for Experts and Administrators' using errcode = '42501';
  end if;
  month_end := (month_start + interval '1 month')::date;
  -- The month being reported only counts as missed once it is over.
  missed_as_of := case when month_start >= cots_private.current_month() then null else month_end end;
  if p_area_code is not null then
    select a.id into area_filter from public.monitoring_areas a where a.code = p_area_code;
    if area_filter is null then
      raise exception 'Unknown site %', p_area_code using errcode = '22023';
    end if;
  end if;

  return (
    with sel_areas as (
      select a.id, a.code, a.name
      from public.monitoring_areas a
      where a.active
        and coalesce(a.geographic_reference ->> 'practice', 'false') <> 'true'
        and (area_filter is null or a.id = area_filter)
    ),
    photos as (
      select c.id, c.area_id, c.submitted_at, c.auto_approve_min,
        cots_private.capture_confirmed_count(c.id) as confirmed,
        cots_private.capture_waiting_count(c.id) as waiting,
        (select count(*)::integer from public.detection_items i where i.capture_id = c.id) as ai_total
      from public.captures c
      join sel_areas on sel_areas.id = c.area_id
      where c.status = 'finalized'
        and date_trunc('month', c.captured_at at time zone 'Asia/Manila')::date = month_start
    ),
    totals as (
      select coalesce(sum(p.confirmed), 0)::integer as confirmed,
        coalesce(sum(p.waiting), 0)::integer as waiting,
        coalesce(sum(greatest(p.ai_total - p.confirmed - p.waiting, 0)), 0)::integer as not_accepted,
        count(*)::integer as records,
        count(*) filter (where p.auto_approve_min = 80)::integer as photos_at_80
      from photos p
    ),
    sites as (
      select sel_areas.id, sel_areas.code, sel_areas.name, a.id as assignment_id,
        coalesce(ps.records, 0) as records,
        coalesce(ps.confirmed, 0) as confirmed,
        coalesce(ps.waiting, 0) as waiting
      from sel_areas
      left join (
        select p.area_id, count(*)::integer as records, sum(p.confirmed)::integer as confirmed,
          sum(p.waiting)::integer as waiting
        from photos p group by p.area_id
      ) ps on ps.area_id = sel_areas.id
      left join public.follow_up_assignments a on a.area_id = sel_areas.id
      where ps.area_id is not null or a.id is not null
    ),
    methods as (
      select x.method, sum(x.cots)::integer as cots, count(*)::integer as removals
      from (
        select coalesce(nullif(btrim(e.method), ''), 'Not recorded') as method,
          (select coalesce(sum(cots_private.capture_confirmed_count(c.id)), 0)
             from public.captures c where c.encounter_id = e.encounter_id) as cots,
          e.submitted_at as at_time, first_photo.area_id
        from public.eliminations e
        join public.captures first_photo on first_photo.id = e.capture_id
        where e.encounter_id is not null
        union all
        select coalesce(nullif(btrim(e.method), ''), 'Not recorded'),
          cots_private.capture_confirmed_count(e.capture_id),
          e.submitted_at, photo.area_id
        from public.eliminations e
        join public.captures photo on photo.id = e.capture_id
        where e.encounter_id is null and e.survey_id is null
        union all
        select coalesce(nullif(btrim(s.elimination_method), ''), 'Not recorded'),
          cots_private.survey_confirmed_count(s.id),
          s.submitted_at, fa.area_id
        from public.follow_up_surveys s
        join public.follow_up_assignments fa on fa.id = s.assignment_id
      ) x
      join sel_areas on sel_areas.id = x.area_id
      where x.cots > 0
        and date_trunc('month', x.at_time at time zone 'Asia/Manila')::date = month_start
      group by x.method
    ),
    review as (
      select count(*) filter (where d.first_at is not null)::integer as reviewed,
        count(*) filter (where d.latest in ('approve', 'correct'))::integer as approved,
        count(*) filter (where d.latest = 'reject')::integer as rejected,
        count(*) filter (where p.waiting > 0)::integer as still_waiting,
        round((avg(extract(epoch from (d.first_at - p.submitted_at)) / 86400.0)
               filter (where d.first_at is not null))::numeric, 1) as avg_wait_days,
        round((max(extract(epoch from (now() - p.submitted_at)) / 86400.0)
               filter (where p.waiting > 0))::numeric, 1) as oldest_waiting_days
      from photos p
      left join lateral (
        select
          (select min(x.decided_at) from public.expert_decisions x where x.capture_id = p.id) as first_at,
          (cots_private.latest_capture_decision(p.id)).decision as latest
      ) d on true
    )
    select jsonb_build_object(
      'month', month_start,
      'area_code', p_area_code,
      'area_name', (select a.name from public.monitoring_areas a where a.id = area_filter),
      'generated_at', now(),
      'confirmed_cots', t.confirmed,
      'waiting_cots', t.waiting,
      'not_accepted_cots', t.not_accepted,
      'records', t.records,
      'photos_at_80', t.photos_at_80,
      'sites', coalesce((
        select jsonb_agg(jsonb_build_object(
          'area_code', s.code,
          'area_name', s.name,
          'level', case when s.records > 0 then cots_private.monthly_level(s.confirmed) end,
          'records', s.records,
          'confirmed_cots', s.confirmed,
          'waiting_cots', s.waiting,
          'main_diver', case when s.assignment_id is not null
            then cots_private.main_divers_text(s.assignment_id) end,
          'last_visit', (select max((v.captured_at at time zone 'Asia/Manila')::date)
            from public.follow_up_surveys v
            where v.assignment_id = s.assignment_id
              and (v.captured_at at time zone 'Asia/Manila')::date < month_end),
          'visits', (select count(*)::integer from public.follow_up_surveys v
            where v.assignment_id = s.assignment_id and v.month = month_start),
          'missed_months', case when s.assignment_id is not null
            then cots_private.missed_months_in_a_row(s.assignment_id, missed_as_of) end
        ) order by s.confirmed desc, s.code)
        from sites s), '[]'::jsonb),
      'methods', coalesce((
        select jsonb_agg(jsonb_build_object('method', x.method, 'cots', x.cots, 'removals', x.removals)
          order by x.cots desc, x.method)
        from methods x), '[]'::jsonb),
      'expert_review', jsonb_build_object(
        'reviewed', r.reviewed,
        'approved', r.approved,
        'rejected', r.rejected,
        'still_waiting', r.still_waiting,
        'avg_wait_days', r.avg_wait_days,
        'oldest_waiting_days', r.oldest_waiting_days)
    )
    from totals t, review r
  );
end $$;

revoke all on function public.monthly_report_json(date, text) from public, anon;
grant execute on function public.monthly_report_json(date, text) to authenticated;

commit;
