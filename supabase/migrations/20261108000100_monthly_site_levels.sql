-- Monthly site levels (user + project expert, 2026-11-08).
-- A site's infestation level is now the number of CONFIRMED COTS recorded at the whole site in one calendar month
-- (Asia/Manila): 0-15 Low, 16-100 Moderate, 101 or more High. It is automatic: no surveyed area and no Expert
-- confirmation step. Confirmed COTS follow the existing rules (auto-accepted 80%+, Expert-accepted COTS, another
-- Diver's record only after Expert approval). The old per-hectare site_levels_json() stays for older app versions.

create function cots_private.monthly_level(n integer) returns text
language sql immutable set search_path = '' as $$
  select case when n <= 15 then 'Low' when n <= 100 then 'Moderate' else 'High' end
$$;
revoke all on function cots_private.monthly_level(integer) from public, anon, authenticated;

-- One row per site and month that has records.
create function cots_private.site_month_totals()
returns table(area_id uuid, month date, records integer, confirmed integer, waiting integer)
language sql stable security definer set search_path = '' as $$
  select c.area_id,
         date_trunc('month', c.captured_at at time zone 'Asia/Manila')::date,
         count(*)::integer,
         coalesce(sum(cots_private.capture_confirmed_count(c.id)), 0)::integer,
         coalesce(sum(cots_private.capture_waiting_count(c.id)), 0)::integer
  from public.captures c
  where c.status = 'finalized' and c.area_id is not null
  group by 1, 2
$$;
revoke all on function cots_private.site_month_totals() from public, anon, authenticated;

-- Map: each active site for one month (p_month), or each site's latest month with records (p_month null).
create function public.site_month_levels_json(p_month date default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.profiles me where me.id = auth.uid() and me.active) then
    raise exception 'Active account required' using errcode = '42501';
  end if;
  return coalesce((
    with t as (select * from cots_private.site_month_totals())
    select jsonb_agg(jsonb_build_object(
      'area_code', ma.code,
      'area_name', ma.name,
      'map_zone', ma.map_zone,
      'month', x.month,
      'records', coalesce(x.records, 0),
      'confirmed_cots', coalesce(x.confirmed, 0),
      'waiting_cots', coalesce(x.waiting, 0),
      'level', case when x.records > 0 then cots_private.monthly_level(x.confirmed) end) order by ma.code)
    from public.monitoring_areas ma
    left join lateral (
      select t.month, t.records, t.confirmed, t.waiting from t
      where t.area_id = ma.id
        and (p_month is null or t.month = date_trunc('month', p_month)::date)
      order by t.month desc limit 1) x on true
    where ma.active
  ), '[]'::jsonb);
end $$;
revoke all on function public.site_month_levels_json(date) from public, anon;
grant execute on function public.site_month_levels_json(date) to authenticated;

-- Analytics: every site and month with records in the last p_months months (newest first).
create function public.site_month_history_json(p_months integer default 12) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.profiles me where me.id = auth.uid() and me.active) then
    raise exception 'Active account required' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'area_code', ma.code,
      'area_name', ma.name,
      'map_zone', ma.map_zone,
      'month', t.month,
      'records', t.records,
      'confirmed_cots', t.confirmed,
      'waiting_cots', t.waiting,
      'level', cots_private.monthly_level(t.confirmed)) order by t.month desc, ma.code)
    from cots_private.site_month_totals() t
    join public.monitoring_areas ma on ma.id = t.area_id and ma.active
    where t.month >= (date_trunc('month', now() at time zone 'Asia/Manila')
                      - make_interval(months => greatest(least(coalesce(p_months, 12), 60), 1) - 1))::date
  ), '[]'::jsonb);
end $$;
revoke all on function public.site_month_history_json(integer) from public, anon;
grant execute on function public.site_month_history_json(integer) to authenticated;
