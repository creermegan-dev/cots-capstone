begin;

-- Stage 3: honest reports.
--
-- Agreed (claude/agreed_workflow_decisions.md, approved 2026-10-31):
--   * Every total uses CONFIRMED counts, with the rest shown as "Waiting for
--     Expert" and "Not accepted" (together they add up to the AI total).
--   * Confirmed follows the Stage 1-2 rules: COTS the Expert rejected come
--     off, a rejected record counts 0, another Diver's record in an assigned
--     zone counts 0 until the Expert approves it.
--   * The app reads these numbers from the database instead of guessing.
--   * Removal methods on the Analytics page: confirmed COTS and number of
--     removals per method, for first encounters and monthly visits.

-- Computed columns for the app: captures?select=*,confirmed_cots,waiting_cots
create function public.confirmed_cots(c public.captures) returns integer
language sql stable security definer set search_path = '' as $$
  select case when cots_private.can_read_capture(c.id)
    then cots_private.capture_confirmed_count(c.id) end
$$;

create function public.waiting_cots(c public.captures) returns integer
language sql stable security definer set search_path = '' as $$
  select case when cots_private.can_read_capture(c.id)
    then cots_private.capture_waiting_count(c.id) end
$$;

-- Confirmed COTS and number of removals per removal method (staff only).
-- Dates are Philippine calendar days of submission; area_name filters by
-- monitoring area name (null = all). A removal counts once it has at least
-- one confirmed COTS.
create function public.removal_method_summary(
  from_date date default null,
  to_date date default null,
  area_name text default null
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not cots_private.is_staff() then
    raise exception 'Removal method summary is for Experts and Administrators'
      using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('method', g.method, 'cots', g.cots, 'removals', g.removals)
      order by g.cots desc, g.method)
    from (
      select x.method, sum(x.cots)::integer as cots, count(*)::integer as removals
      from (
        -- First encounters: one removal per encounter, all of its photos.
        select coalesce(nullif(btrim(e.method), ''), 'Not recorded') as method,
          (select coalesce(sum(cots_private.capture_confirmed_count(c.id)), 0)
             from public.captures c where c.encounter_id = e.encounter_id) as cots,
          e.submitted_at as at_time,
          ma.name as area
        from public.eliminations e
        join public.captures first_photo on first_photo.id = e.capture_id
        join public.monitoring_areas ma on ma.id = first_photo.area_id
        where e.encounter_id is not null
        union all
        -- Older removals linked to a single photo.
        select coalesce(nullif(btrim(e.method), ''), 'Not recorded'),
          cots_private.capture_confirmed_count(e.capture_id),
          e.submitted_at,
          ma.name
        from public.eliminations e
        join public.captures photo on photo.id = e.capture_id
        join public.monitoring_areas ma on ma.id = photo.area_id
        where e.encounter_id is null and e.survey_id is null
        union all
        -- Monthly visits: COTS found and removed in the visit photos.
        select coalesce(nullif(btrim(s.elimination_method), ''), 'Not recorded'),
          cots_private.survey_confirmed_count(s.id),
          s.submitted_at,
          ma.name
        from public.follow_up_surveys s
        join public.follow_up_assignments a on a.id = s.assignment_id
        join public.monitoring_areas ma on ma.id = a.area_id
      ) x
      where x.cots > 0
        and (from_date is null or (x.at_time at time zone 'Asia/Manila')::date >= from_date)
        and (to_date is null or (x.at_time at time zone 'Asia/Manila')::date <= to_date)
        and (area_name is null or x.area = area_name)
      group by x.method
    ) g
  ), '[]'::jsonb);
end $$;

revoke all on function
  public.confirmed_cots(public.captures),
  public.waiting_cots(public.captures),
  public.removal_method_summary(date, date, text)
from public, anon;
grant execute on function
  public.confirmed_cots(public.captures),
  public.waiting_cots(public.captures),
  public.removal_method_summary(date, date, text)
to authenticated;

commit;
