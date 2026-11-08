-- Stage 13 (with the user's density rule of 2026-11-05 11:10) and real data on the map.
-- 1. Density levels: Low up to and including 15 COTS/ha, Moderate above 15 up to 100, High above 100
--    (user: "15 low, 16-100 moderate, 100 more is high"; adapted from Dumas et al. 2020, where Low is below 15).
--    Keep identical to lib/models/cots_density.dart.
create or replace function cots_private.density_level(per_ha numeric) returns text
language sql immutable set search_path = '' as $$
  select case when per_ha is null then null
              when per_ha <= 15 then 'Low'
              when per_ha <= 100 then 'Moderate'
              else 'High' end
$$;

-- 2. The map's site colours: each active site with its latest Expert-confirmed level (from monthly visits),
--    and how many records and confirmed COTS it has. Totals only, no names: every signed-in active person
--    may read it (the record dots themselves follow the Records page rules: own records, or all for staff).
create function public.site_levels_json() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.profiles me where me.id = auth.uid() and me.active) then
    raise exception 'Active account required' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'area_code', ma.code,
      'area_name', ma.name,
      'level', l.level,
      'density_per_ha', l.density,
      'assessed_at', l.assessed_at,
      'visit_date', l.visit_date,
      'records', coalesce(r.records, 0),
      'confirmed_cots', coalesce(r.confirmed, 0)) order by ma.code)
    from public.monitoring_areas ma
    left join lateral (
      select x.level, x.assessed_at, s.captured_at as visit_date,
             cots_private.density_per_ha(s.observed_count, s.surveyed_area_m2) as density
      from public.infestation_assessments x
      join public.follow_up_surveys s on s.id = x.survey_id
      join public.follow_up_assignments a on a.id = s.assignment_id
      where a.area_id = ma.id
      order by s.captured_at desc, x.assessed_at desc
      limit 1) l on true
    left join lateral (
      select count(*)::integer as records,
             coalesce(sum(cots_private.capture_confirmed_count(c.id)), 0)::integer as confirmed
      from public.captures c where c.area_id = ma.id and c.status = 'finalized') r on true
    where ma.active
  ), '[]'::jsonb);
end $$;
revoke all on function public.site_levels_json() from public, anon;
grant execute on function public.site_levels_json() to authenticated;
