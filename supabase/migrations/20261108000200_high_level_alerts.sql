-- High site level notice (user, 2026-11-08): when a site first reaches High in a month (more than 100 confirmed
-- COTS, see 20261108000100_monthly_site_levels.sql), the Expert(s), the Administrator(s) and the site's main Divers
-- get one notice. Only High (not Moderate); once per site per month. Checked every 15 minutes by pg_cron.

create function cots_private.send_high_level_alerts(at_time timestamptz default now()) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  m date := date_trunc('month', at_time at time zone 'Asia/Manila')::date;
  eid uuid;
  sent integer := 0;
begin
  for r in
    select t.area_id, t.confirmed, ma.name as area_name, ma.code,
           (select a.id from public.follow_up_assignments a where a.area_id = t.area_id limit 1) as assignment_id
    from cots_private.site_month_totals() t
    join public.monitoring_areas ma on ma.id = t.area_id and ma.active
    where t.month = m and cots_private.monthly_level(t.confirmed) = 'High'
    order by ma.code
  loop
    continue when exists (select 1 from public.workflow_events e
                          where e.action = 'site_level_high'
                            and e.details->>'area' = r.area_id::text and e.details->>'month' = m::text);
    insert into public.workflow_events(action, details)
    values ('site_level_high', jsonb_build_object(
      'title', r.area_name || ' is now High',
      'body', r.area_name || ' reached High this month: ' || r.confirmed || ' confirmed COTS in '
        || to_char(m, 'FMMonth YYYY') || ' (over 100 is High).',
      'record_id', coalesce(r.assignment_id::text, ''), 'zone', r.area_name,
      'area', r.area_id::text, 'month', m::text, 'confirmed_cots', r.confirmed))
    returning id into eid;
    insert into public.notifications(recipient_id, event_id)
    select distinct x, eid from (
      select s.user_id as x from public.privileged_role_slots s
      join public.profiles p on p.id = s.user_id and p.active
      where s.role in ('expert', 'administrator')
      union
      select unnest(cots_private.main_divers(r.assignment_id)) where r.assignment_id is not null
    ) people
    where x is not null and exists (select 1 from public.profiles p where p.id = x);
    sent := sent + 1;
  end loop;
  return sent;
end $$;
revoke all on function cots_private.send_high_level_alerts(timestamptz) from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(j.jobid) from cron.job j where j.jobname = 'cots-high-level-alerts';
    perform cron.schedule('cots-high-level-alerts', '*/15 * * * *', 'select cots_private.send_high_level_alerts()');
  end if;
end $$;
