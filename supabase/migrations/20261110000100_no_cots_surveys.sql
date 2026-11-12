-- Diver-reported absence surveys. No photos, model results, Expert approval,
-- capture counts, site levels, or assignment creation. Existing records stay intact.
create table public.no_cots_surveys (
 id uuid primary key,
 owner_id uuid not null references public.profiles(id),
 area_id uuid not null references public.monitoring_areas(id),
 survey_kind text not null check(survey_kind in ('initial','monthly')),
 surveyed_at timestamptz not null,
 month date not null check(extract(day from month)=1),
 submitted_at timestamptz not null default now(),
 latitude double precision not null check(latitude between -90 and 90),
 longitude double precision not null check(longitude between -180 and 180),
 gps_source text not null default 'device_surface' check(gps_source='device_surface'),
 gps_captured_at timestamptz not null,
 gps_accuracy_m double precision not null check(gps_accuracy_m between 0 and 100000),
 surveyed_area_m2 numeric not null check(surveyed_area_m2 > 0 and surveyed_area_m2 < 'Infinity'::numeric),
 notes text not null default '' check(length(notes)<=2000),
 confirmed_observation boolean not null check(confirmed_observation),
 check(month=date_trunc('month',surveyed_at at time zone 'Asia/Manila')::date)
);
create index no_cots_site_month on public.no_cots_surveys(area_id,month);
create index no_cots_owner on public.no_cots_surveys(owner_id,submitted_at desc);
alter table public.no_cots_surveys enable row level security;
revoke all on public.no_cots_surveys from public, anon, authenticated;
grant select on public.no_cots_surveys to authenticated;
create policy trusted_session_required on public.no_cots_surveys as restrictive for all to authenticated
 using(cots_private.session_is_trusted()) with check(cots_private.session_is_trusted());
create policy no_cots_read on public.no_cots_surveys for select to authenticated
 using(exists(select 1 from public.profiles p where p.id=auth.uid() and p.active)
   and (owner_id=auth.uid() or cots_private.is_staff()));
create function cots_private.keep_no_cots_history() returns trigger
language plpgsql set search_path='' as $$ begin
 raise exception 'Survey history is immutable' using errcode='42501'; end $$;
revoke all on function cots_private.keep_no_cots_history() from public, anon, authenticated;
create trigger keep_no_cots_history before update or delete on public.no_cots_surveys
 for each row execute function cots_private.keep_no_cots_history();

create function public.submit_no_cots_survey(
 p_id uuid, p_area_code text, p_kind text, p_surveyed_at timestamptz,
 p_latitude double precision, p_longitude double precision,
 p_gps_at timestamptz, p_accuracy double precision, p_area_m2 numeric,
 p_notes text, p_confirmed boolean
) returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); aid uuid; assignment uuid; saved public.no_cots_surveys; m date;
begin
 if uid is null or not cots_private.eligible(uid) then
   raise exception 'Verified Diver required' using errcode='42501'; end if;
 if p_id is null or p_kind is null or p_kind not in ('initial','monthly') or p_confirmed is distinct from true
   or p_surveyed_at is null or p_surveyed_at < '2000-01-01'::timestamptz
   or p_surveyed_at > now()+interval '5 minutes'
   or p_gps_at is null or abs(extract(epoch from (p_surveyed_at-p_gps_at))) > 300
   or p_latitude is null or not(p_latitude between -90 and 90)
   or p_longitude is null or not(p_longitude between -180 and 180)
   or p_accuracy is null or not(p_accuracy between 0 and 100000)
   or p_area_m2 is null or p_area_m2<=0 or p_area_m2 >= 'Infinity'::numeric
   or length(coalesce(p_notes,''))>2000 then
   raise exception 'Valid survey details, a contemporaneous phone GPS fix and confirmation are required' using errcode='23514'; end if;
 select id into aid from public.monitoring_areas where code=p_area_code and active;
 if aid is null or cots_private.area_at(p_latitude,p_longitude) is distinct from aid then
   raise exception 'Phone location is outside the selected monitoring site' using errcode='23514'; end if;
 m:=date_trunc('month',p_surveyed_at at time zone 'Asia/Manila')::date;
 select * into saved from public.no_cots_surveys where id=p_id;
 if saved.id is null then
 select id into assignment from public.follow_up_assignments where area_id=aid;
 if p_kind='monthly' and assignment is not null and not cots_private.month_ok(assignment,uid,m) then
   raise exception 'Only a responsible Diver may submit this monthly visit' using errcode='42501'; end if;
 insert into public.no_cots_surveys(id,owner_id,area_id,survey_kind,surveyed_at,month,
 latitude,longitude,gps_captured_at,gps_accuracy_m,surveyed_area_m2,notes,confirmed_observation)
 values(p_id,uid,aid,p_kind,p_surveyed_at,m,p_latitude,p_longitude,p_gps_at,p_accuracy,p_area_m2,coalesce(p_notes,''),true)
 on conflict(id) do nothing;
 select * into saved from public.no_cots_surveys where id=p_id;
 end if;
 if saved.owner_id<>uid or saved.area_id<>aid or saved.survey_kind<>p_kind
 or saved.surveyed_at<>p_surveyed_at or saved.latitude<>p_latitude or saved.longitude<>p_longitude
 or saved.gps_captured_at<>p_gps_at or saved.gps_accuracy_m<>p_accuracy
 or saved.surveyed_area_m2<>p_area_m2 or saved.notes<>coalesce(p_notes,'') then
   raise exception 'This survey ID already contains different details; original preserved' using errcode='23514'; end if;
 return saved.id;
end $$;
revoke all on function public.submit_no_cots_survey(uuid,text,text,timestamptz,double precision,double precision,timestamptz,double precision,numeric,text,boolean) from public,anon;
grant execute on function public.submit_no_cots_survey(uuid,text,text,timestamptz,double precision,double precision,timestamptz,double precision,numeric,text,boolean) to authenticated;

-- Read API is role-scoped. These reports never enter Expert decision queues.
create function public.no_cots_surveys_json(p_area_code text default null, p_mine_only boolean default false)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not cots_private.session_is_trusted() or not exists(
 select 1 from public.profiles where id=auth.uid() and active) then
 raise exception 'Active trusted account required' using errcode='42501'; end if;
 return coalesce((select jsonb_agg(to_jsonb(q) order by q.submitted_at desc) from (
 select n.*,ma.code as area_code,ma.name as area_name,p.full_name as submitted_by,
 'diver_reported'::text as report_status,'No COTS observed during this survey'::text as observation
 from public.no_cots_surveys n join public.monitoring_areas ma on ma.id=n.area_id
 join public.profiles p on p.id=n.owner_id
 where (p_area_code is null or ma.code=p_area_code)
 and (n.owner_id=auth.uid() or (not coalesce(p_mine_only,false) and cots_private.is_staff()))
 ) q),'[]'::jsonb);
end $$;
revoke all on function public.no_cots_surveys_json(text,boolean) from public,anon;
grant execute on function public.no_cots_surveys_json(text,boolean) to authenticated;

-- Only completion/history consumers use this view. COTS levels and totals do not.
-- A first survey has no assignment; a later assignment can still see that site's visit.
create view cots_private.surveys_for_completion as
 select s.assignment_id,a.area_id,s.month,s.status,s.captured_at
 from public.follow_up_surveys s join public.follow_up_assignments a on a.id=s.assignment_id
 union all
 select a.id,n.area_id,n.month,'completed',n.surveyed_at
 from public.no_cots_surveys n left join public.follow_up_assignments a on a.area_id=n.area_id;
revoke all on cots_private.surveys_for_completion from public,anon,authenticated;

CREATE OR REPLACE FUNCTION cots_private.missed_months_in_a_row(aid uuid, as_of date DEFAULT NULL::date)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    exit when exists (select 1 from cots_private.surveys_for_completion s
                      where s.assignment_id = aid and s.month = m)
           or cots_private.month_excused(aid, m);
    missed := missed + 1;
    m := (m - interval '1 month')::date;
  end loop;
  return missed;
end $function$

;

CREATE OR REPLACE FUNCTION cots_private.send_visit_reminders(at_time timestamp with time zone DEFAULT now())
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  r record;
  m date := date_trunc('month', at_time at time zone 'Asia/Manila')::date;
  day integer := extract(day from at_time at time zone 'Asia/Manila')::integer;
  which text;
  resp uuid;
  recipients uuid[];
  eid uuid;
  sent integer := 0;
begin
  for r in
    select a.id, ma.name as area_name,
           date_trunc('month', o.captured_at at time zone 'Asia/Manila')::date as first_month
    from public.follow_up_assignments a
    join public.monitoring_areas ma on ma.id = a.area_id
    join public.captures o on o.id = a.originating_capture_id
    order by ma.code
  loop
    continue when m <= r.first_month;
    continue when cots_private.month_excused(r.id, m);
    continue when exists (select 1 from cots_private.surveys_for_completion s
                          where s.assignment_id = r.id and s.month = m and s.status <> 'historical_only');
    which := case when day >= 16 then 'visit_reminder_second' else 'visit_reminder_first' end;
    continue when exists (select 1 from public.workflow_events e
                          where e.action in (which, case when which = 'visit_reminder_first' then 'visit_reminder_second' end)
                            and e.details->>'assignment' = r.id::text and e.details->>'month' = m::text);
    select coalesce((select x.responsible_diver_id from public.monthly_authorizations x
                     where x.assignment_id = r.id and x.month = m), cots_private.main_diver(r.id)) into resp;
    recipients := case when resp = any(cots_private.main_divers(r.id)) then cots_private.main_divers(r.id)
                       else array[resp] end;
    insert into public.workflow_events(action, details)
    values (which, jsonb_build_object(
      'title', case when which = 'visit_reminder_first' then 'Monthly visit due'
                    else 'Reminder: monthly visit not done yet' end,
      'body', case when which = 'visit_reminder_first'
                then 'This month''s visit for ' || r.area_name || ' is due (' || to_char(m, 'FMMonth YYYY') || ').'
                else 'Nobody has done this month''s visit for ' || r.area_name || ' yet ('
                  || to_char(m, 'FMMonth YYYY') || '). Please visit before the month ends.' end,
      'record_id', r.id::text, 'zone', r.area_name, 'assignment', r.id::text, 'month', m::text))
    returning id into eid;
    insert into public.notifications(recipient_id, event_id)
    select distinct x, eid from unnest(recipients) x
    where x is not null and exists (select 1 from public.profiles p where p.id = x);
    sent := sent + 1;
  end loop;
  return sent;
end $function$

;

CREATE OR REPLACE FUNCTION public.monthly_report_json(p_month date DEFAULT NULL::date, p_area_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
      where ps.area_id is not null or a.id is not null or exists(select 1 from public.no_cots_surveys n where n.area_id=sel_areas.id and n.month=month_start)
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
      'no_cots_surveys', (select count(*) from public.no_cots_surveys n where n.month=month_start and n.area_id in (select id from sel_areas)),
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
            from cots_private.surveys_for_completion v
            where v.area_id = s.id
              and (v.captured_at at time zone 'Asia/Manila')::date < month_end),
          'visits', (select count(*)::integer from cots_private.surveys_for_completion v
            where v.area_id = s.id and v.month = month_start),
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
end $function$

;

