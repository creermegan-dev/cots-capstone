begin;

-- Stage 4: hand over this area.
--
-- Agreed (claude/agreed_workflow_decisions.md, approved 2026-10-31):
--   * The main Diver taps "Hand over this area" and gives a reason (an
--     optional handover note for the next Diver too). The Expert picks a new
--     Diver; the new Diver accepts or declines. On acceptance the new Diver
--     becomes the permanent main Diver at once; past records stay under the
--     original Diver. If they decline, the Expert picks someone else and the
--     original Diver keeps the area meanwhile.
--   * The new Diver sees one of the agreed notes about this month.
--   * After 5 missed months in a row the Expert can start the handover. A
--     month is missed when no visit at all was submitted for the zone; months
--     count from the month after the zone was assigned (or last handed over),
--     and the current month only counts once it is over. No excused months
--     until Stage 5.
--   * The Diver can cancel their own request, and the Expert one they started,
--     until someone accepts. Any verified, active Diver except the current
--     main Diver can be picked. Names are shown (an open handover).
--
-- The zone's permanent record (follow_up_assignments) is never rewritten:
-- handovers have their own history, and every rule that asked "who owns this
-- zone" now asks for the CURRENT main Diver (cots_private.main_diver).

create table public.area_handovers (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.follow_up_assignments(id),
  from_diver_id uuid not null references public.profiles(id),
  started_by uuid not null references public.profiles(id),
  started_reason text not null check (started_reason in ('diver_request', 'missed_months')),
  reason text not null check (length(btrim(reason)) between 1 and 2000),
  handover_note text not null default '' check (length(handover_note) <= 2000),
  status text not null default 'requested'
    check (status in ('requested', 'offered', 'accepted', 'cancelled')),
  requested_at timestamptz not null default now(),
  closed_at timestamptz,
  check ((status in ('accepted', 'cancelled')) = (closed_at is not null))
);
create unique index one_open_handover on public.area_handovers(assignment_id)
  where status in ('requested', 'offered');

create table public.handover_offers (
  id uuid primary key default gen_random_uuid(),
  handover_id uuid not null references public.area_handovers(id),
  to_diver_id uuid not null references public.profiles(id),
  offered_by uuid not null references public.profiles(id),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  offered_at timestamptz not null default now(),
  responded_at timestamptz,
  check ((status = 'pending') = (responded_at is null))
);
create unique index one_pending_handover_offer on public.handover_offers(handover_id)
  where status = 'pending';
create index handover_offers_diver on public.handover_offers(to_diver_id);

-- Read and changed only through the functions below.
alter table public.area_handovers enable row level security;
alter table public.handover_offers enable row level security;
revoke all on public.area_handovers, public.handover_offers from public, anon, authenticated;
create policy trusted_session_required on public.area_handovers as restrictive
  for all to authenticated
  using (cots_private.session_is_trusted()) with check (cots_private.session_is_trusted());
create policy trusted_session_required on public.handover_offers as restrictive
  for all to authenticated
  using (cots_private.session_is_trusted()) with check (cots_private.session_is_trusted());

alter table public.workflow_events
  add column handover_id uuid references public.area_handovers(id);

-- The zone's current main Diver: the latest accepted handover, else the
-- original Diver.
create function cots_private.main_diver(aid uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select o.to_diver_id
    from public.handover_offers o
    join public.area_handovers h on h.id = o.handover_id
    where h.assignment_id = aid and o.status = 'accepted'
    order by o.responded_at desc
    limit 1
  ), (select a.primary_diver_id from public.follow_up_assignments a where a.id = aid))
$$;

-- The agreed note the new Diver sees about this month.
create function cots_private.handover_month_note(aid uuid) returns text
language sql stable security definer set search_path = '' as $$
  select case
    when exists (select 1 from public.follow_up_surveys s
                 where s.assignment_id = aid and s.month = cots_private.current_month())
      then 'This month has already been monitored. Your first visit is next month.'
    when exists (select 1 from public.monthly_authorizations m
                 where m.assignment_id = aid and m.month = cots_private.current_month()
                   and m.responsible_diver_id <> cots_private.main_diver(aid))
      then 'Another Diver is covering this month. Your first visit is next month.'
    else 'This month hasn''t been monitored yet. You can do this month''s visit any day.'
  end
$$;

-- Missed months in a row, ending with the last finished month.
create function cots_private.missed_months_in_a_row(aid uuid, as_of date default null)
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
                      where s.assignment_id = aid and s.month = m);
    missed := missed + 1;
    m := (m - interval '1 month')::date;
  end loop;
  return missed;
end $$;

create function cots_private.area_label(aid uuid) returns text
language sql stable security definer set search_path = '' as $$
  select ma.name from public.follow_up_assignments a
  join public.monitoring_areas ma on ma.id = a.area_id where a.id = aid
$$;

create function cots_private.person_name(person uuid) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce(nullif(btrim(p.full_name), ''), 'a Diver') from public.profiles p where p.id = person
$$;

create function cots_private.notify_handover(
  hid uuid, action_name text, title text, body text, recipients uuid[]
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  eid uuid;
begin
  if coalesce(cardinality(recipients), 0) = 0 then
    return;
  end if;
  insert into public.workflow_events(handover_id, actor_id, action, details)
  values (
    hid,
    (select p.id from public.profiles p where p.id = auth.uid()),
    action_name,
    jsonb_build_object(
      'title', title,
      'body', body,
      'record_id', hid::text,
      'zone', coalesce((select cots_private.area_label(h.assignment_id)
                        from public.area_handovers h where h.id = hid), '')))
  returning id into eid;
  insert into public.notifications(recipient_id, event_id)
  select distinct x, eid from unnest(recipients) as x
  where x is not null and exists (select 1 from public.profiles p where p.id = x);
end $$;

create function cots_private.experts() returns uuid[]
language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(r.user_id), '{}') from public.privileged_role_slots r where r.role = 'expert'
$$;

-- Every rule that asked "who owns this zone" now uses the current main Diver.

-- From 20261016000200_security.sql: original Diver -> current main Diver (1 place).
create or replace function cots_private.can_read_assignment(aid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select cots_private.is_staff() or exists(
    select 1 from public.follow_up_assignments a join public.profiles p on p.id=auth.uid()
    where a.id=aid and p.active and (cots_private.main_diver(a.id)=auth.uid() or exists(
      select 1 from public.monthly_authorizations m where m.assignment_id=a.id
        and m.month=cots_private.current_month() and m.responsible_diver_id=auth.uid()
        and cots_private.eligible(auth.uid()))))
$$;

-- From 20261030000500_follow_up_app_support.sql: original Diver -> current main Diver (3 places).
create or replace function cots_private.assignment_json(aid uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'assignment_id', a.id,
    'area_id', ma.code,
    'area_label', ma.name,
    'barangay', ma.barangay,
    'municipality', ma.municipality,
    'primary_diver_uid', cots_private.main_diver(a.id),
    'primary_diver_name', coalesce(p.full_name, ''),
    'initial_capture_id', a.originating_capture_id,
    'initial_date', c.captured_at,
    'initial_detected_count',
      (select count(*) from public.detection_items i where i.capture_id = a.originating_capture_id),
    'initial_collection', 'captures',
    'responsible_uid', coalesce(m.responsible_diver_id, cots_private.main_diver(a.id)))
  from public.follow_up_assignments a
  join public.monitoring_areas ma on ma.id = a.area_id
  join public.captures c on c.id = a.originating_capture_id
  left join public.profiles p on p.id = cots_private.main_diver(a.id)
  left join public.monthly_authorizations m
    on m.assignment_id = a.id and m.month = cots_private.current_month()
  where a.id = aid
$$;

-- From 20261030000500_follow_up_app_support.sql: original Diver -> current main Diver (1 place).
create or replace function cots_private.can_see_reassignment(rid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select cots_private.can_read_request(rid) or exists (
    select 1 from public.reassignment_requests r
    join public.monthly_authorizations m on m.id = r.authorization_id
    join public.follow_up_assignments a on a.id = m.assignment_id
    join public.profiles p on p.id = auth.uid()
    where r.id = rid and p.active and cots_private.main_diver(a.id) = auth.uid())
$$;

-- From 20261030000500_follow_up_app_support.sql: original Diver -> current main Diver (1 place).
create or replace function cots_private.emit_event(rid uuid,sid uuid,action_name text,payload jsonb,recipients uuid[])
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  eid uuid;
  info jsonb := coalesce(payload, '{}'::jsonb);
  area_text text;
  month_date date;
  primary_name text;
begin
  if rid is not null then
    select ma.name || ' (' || ma.code || ')', m.month, p.full_name
      into area_text, month_date, primary_name
    from public.reassignment_requests r
    join public.monthly_authorizations m on m.id = r.authorization_id
    join public.follow_up_assignments a on a.id = m.assignment_id
    join public.monitoring_areas ma on ma.id = a.area_id
    left join public.profiles p on p.id = cots_private.main_diver(a.id)
    where r.id = rid;
    info := info || jsonb_build_object(
      'title', case action_name
        when 'reassignment_requested' then 'Follow-up replacement requested'
        when 'replacement_proposed' then 'New follow-up assignment'
        when 'replacement_accepted' then 'Replacement accepted'
        when 'replacement_declined' then 'Replacement declined - replacement needed'
        when 'reassignment_closed' then case when coalesce((payload->>'cancelled')::boolean, false)
          then 'Reassignment request cancelled' else 'Pending replacement cancelled' end
        else 'Follow-up reassignment updated' end,
      'body', coalesce(to_char(month_date, 'FMMonth YYYY'), '') || ' · ' || coalesce(area_text, '')
        || E'\nOriginal diver: ' || coalesce(primary_name, '')
        || case when action_name = 'replacement_proposed'
             then E'\nPlease accept or decline this assignment.' else '' end,
      'record_id', rid::text,
      'zone', coalesce(area_text, ''));
  elsif sid is not null then
    select ma.name || ' (' || ma.code || ')', s.month into area_text, month_date
    from public.follow_up_surveys s
    join public.follow_up_assignments a on a.id = s.assignment_id
    join public.monitoring_areas ma on ma.id = a.area_id
    where s.id = sid;
    info := info || jsonb_build_object(
      'title', case action_name
        when 'survey_completed' then 'Follow-up visit completed'
        when 'survey_pending_late_review' then 'Follow-up visit needs late review'
        when 'survey_pending_authorization_review' then 'Follow-up visit needs authorization review'
        else 'Follow-up visit updated' end,
      'body', 'Your ' || coalesce(to_char(month_date, 'FMMonth YYYY'), '') || ' follow-up visit for '
        || coalesce(area_text, 'the monitoring area') || case action_name
          when 'survey_completed' then ' is complete.'
          else ' is waiting for review.' end,
      'record_id', sid::text,
      'zone', coalesce(area_text, ''));
  end if;
  insert into public.workflow_events(request_id,survey_id,actor_id,action,details)
    values(rid,sid,auth.uid(),action_name,info) returning id into eid;
  insert into public.notifications(recipient_id,event_id)
    select distinct x,eid from unnest(recipients) as x where x is not null;
  return eid;
end $$;

-- From 20261016000300_workflows.sql: original Diver -> current main Diver (1 place).
create or replace function cots_private.ensure_month(aid uuid,m date) returns public.monthly_authorizations
language plpgsql security definer set search_path = '' as $$
declare a public.follow_up_assignments; result public.monthly_authorizations;
begin
  select * into strict a from public.follow_up_assignments where id=aid for update;
  insert into public.monthly_authorizations(assignment_id,month,responsible_diver_id)
    values(aid,m,cots_private.main_diver(a.id)) on conflict(assignment_id,month) do nothing;
  select * into strict result from public.monthly_authorizations where assignment_id=aid and month=m for update;
  return result;
end $$;

-- From 20261030000500_follow_up_app_support.sql: original Diver -> current main Diver (2 places).
create or replace function cots_private.reassignment_json(rid uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', r.id,
    'area_id', ma.code,
    'area_label', ma.name,
    'barangay', ma.barangay,
    'municipality', ma.municipality,
    'primary_uid', cots_private.main_diver(a.id),
    'primary_name', coalesce(pp.full_name, ''),
    'year', extract(year from m.month)::integer,
    'month', extract(month from m.month)::integer,
    'responsible_uid', m.responsible_diver_id,
    'requester_uid', r.requester_id,
    'reason', r.reason,
    'status', r.status,
    'revision', r.revision,
    'requested_at', r.requested_at,
    'proposal_id', coalesce(x.id::text, ''),
    'proposal_status', coalesce(x.status, ''),
    'replacement_uid', coalesce(x.replacement_id::text, ''),
    'replacement_name', coalesce(xp.full_name, ''),
    'expert_uid', coalesce(x.expert_id::text, ''))
  from public.reassignment_requests r
  join public.monthly_authorizations m on m.id = r.authorization_id
  join public.follow_up_assignments a on a.id = m.assignment_id
  join public.monitoring_areas ma on ma.id = a.area_id
  left join public.profiles pp on pp.id = cots_private.main_diver(a.id)
  left join lateral (
    select q.* from public.replacement_proposals q where q.request_id = r.id
    order by (q.status = 'pending') desc, q.proposed_at desc limit 1) x on true
  left join public.profiles xp on xp.id = x.replacement_id
  where r.id = rid
$$;

-- From 20261031000200_zone_responsibility.sql: original Diver -> current main Diver (1 place).
create or replace function cots_private.zone_responsible_name(cid uuid) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce(nullif(btrim(p.full_name), ''), 'another Diver')
  from public.captures c
  join public.follow_up_assignments a on a.area_id = c.area_id
  left join public.monthly_authorizations m
    on m.assignment_id = a.id
   and m.month = date_trunc('month', c.captured_at at time zone 'Asia/Manila')::date
  left join public.profiles p on p.id = coalesce(m.responsible_diver_id, cots_private.main_diver(a.id))
  where c.id = cid
$$;

-- From 20261031000200_zone_responsibility.sql: original Diver -> current main Diver (1 place).
create or replace function cots_private.zone_review_needed(cid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select c.id <> a.originating_capture_id
      and c.owner_id <> cots_private.main_diver(a.id)
      and c.owner_id is distinct from m.responsible_diver_id
      and c.captured_at >= o.captured_at
    from public.captures c
    join public.follow_up_assignments a on a.area_id = c.area_id
    join public.captures o on o.id = a.originating_capture_id
    left join public.monthly_authorizations m
      on m.assignment_id = a.id
     and m.month = date_trunc('month', c.captured_at at time zone 'Asia/Manila')::date
    where c.id = cid
  ), false)
$$;

-- From 20261031000200_zone_responsibility.sql: original Diver -> current main Diver (1 place).
create or replace function public.finalize_capture(cid uuid) returns void
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
        || '. The Expert approved the record.',
      array(select cots_private.main_diver(f.id) from public.follow_up_assignments f where f.area_id=c.area_id));
  end if;
  insert into public.audit_events(action,target_id) values('capture_finalized',cid);
end $$;

-- From 20261030000500_follow_up_app_support.sql: original Diver -> current main Diver (1 place).
create or replace function public.follow_up_assignments_json(area_code text default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Authenticated user required' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(cots_private.assignment_json(a.id) order by ma.code)
    from public.follow_up_assignments a
    join public.monitoring_areas ma on ma.id = a.area_id
    where cots_private.can_read_assignment(a.id)
      and (case when area_code is null
             then cots_private.main_diver(a.id) = uid or exists (
               select 1 from public.monthly_authorizations m
               where m.assignment_id = a.id and m.month = cots_private.current_month()
                 and m.responsible_diver_id = uid)
             else ma.code = area_code end)
  ), '[]'::jsonb);
end $$;

-- From 20261030000500_follow_up_app_support.sql: original Diver -> current main Diver (2 places).
create or replace function public.follow_up_can_submit(area_code text, visit_date date) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select cots_private.eligible(auth.uid())
      and coalesce(m.responsible_diver_id, cots_private.main_diver(a.id)) = auth.uid()
      and (auth.uid() = cots_private.main_diver(a.id)
           or date_trunc('month', visit_date)::date = cots_private.current_month())
    from public.follow_up_assignments a
    join public.monitoring_areas ma on ma.id = a.area_id
    left join public.monthly_authorizations m
      on m.assignment_id = a.id and m.month = date_trunc('month', visit_date)::date
    where ma.code = area_code
  ), false)
$$;

-- From 20261030000500_follow_up_app_support.sql: original Diver -> current main Diver (1 place).
create or replace function public.follow_up_surveys_json(area_code text default null, mine_only boolean default false)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Authenticated user required' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(cots_private.survey_json(s.id) order by s.survey_date desc nulls last, s.submitted_at desc)
    from public.follow_up_surveys s
    join public.follow_up_assignments a on a.id = s.assignment_id
    join public.monitoring_areas ma on ma.id = a.area_id
    where cots_private.can_read_survey(s.id)
      and (area_code is null or ma.code = area_code)
      and (case
             when mine_only then s.owner_id = uid
             when area_code is not null then true
             else s.owner_id = uid or cots_private.main_diver(a.id) = uid or exists (
               select 1 from public.monthly_authorizations m
               where m.assignment_id = a.id and m.month = cots_private.current_month()
                 and m.responsible_diver_id = uid)
           end)
  ), '[]'::jsonb);
end $$;

-- From 20261031000100_encounters_photo_counts.sql: original Diver -> current main Diver (1 place).
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

-- The main Diver asks to hand over the area.
create function public.request_area_handover(
  area_code text, reason_text text, note_text text default ''
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  a public.follow_up_assignments;
  hid uuid;
begin
  if not cots_private.eligible(auth.uid()) then
    raise exception 'Verified diver required' using errcode = '42501';
  end if;
  select f.* into a from public.follow_up_assignments f
  join public.monitoring_areas ma on ma.id = f.area_id where ma.code = area_code;
  if a.id is null or cots_private.main_diver(a.id) <> auth.uid() then
    raise exception 'Only the main Diver can hand over this area' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(reason_text, '')), '') is null then
    raise exception 'Give a reason for the handover' using errcode = '23514';
  end if;
  if exists (select 1 from public.area_handovers h
             where h.assignment_id = a.id and h.status in ('requested', 'offered')) then
    raise exception 'A handover is already open for this area' using errcode = '23514';
  end if;
  insert into public.area_handovers(assignment_id, from_diver_id, started_by, started_reason,
    reason, handover_note)
  values (a.id, auth.uid(), auth.uid(), 'diver_request', btrim(reason_text),
    btrim(coalesce(note_text, '')))
  returning id into hid;
  perform cots_private.notify_handover(hid, 'handover_requested', 'Area handover requested',
    cots_private.person_name(auth.uid()) || ' asked to hand over ' || cots_private.area_label(a.id)
      || '. Reason: ' || btrim(reason_text) || ' Please choose a new Diver.',
    cots_private.experts() || array[auth.uid()]);
  return hid;
end $$;

-- The Expert starts a handover after 5 missed months in a row.
create function public.start_area_handover(area_code text, reason_text text default null)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  a public.follow_up_assignments;
  missed integer;
  main uuid;
  why text;
  hid uuid;
begin
  if not cots_private.has_role('expert') then
    raise exception 'Expert required' using errcode = '42501';
  end if;
  select f.* into a from public.follow_up_assignments f
  join public.monitoring_areas ma on ma.id = f.area_id where ma.code = area_code;
  if a.id is null then
    raise exception 'Area not found' using errcode = '23514';
  end if;
  missed := cots_private.missed_months_in_a_row(a.id);
  if missed < 5 then
    raise exception 'A handover can be started after 5 missed months in a row' using errcode = '23514';
  end if;
  if exists (select 1 from public.area_handovers h
             where h.assignment_id = a.id and h.status in ('requested', 'offered')) then
    raise exception 'A handover is already open for this area' using errcode = '23514';
  end if;
  main := cots_private.main_diver(a.id);
  why := coalesce(nullif(btrim(coalesce(reason_text, '')), ''),
    'No monthly visit for ' || missed || ' months in a row.');
  insert into public.area_handovers(assignment_id, from_diver_id, started_by, started_reason, reason)
  values (a.id, main, auth.uid(), 'missed_months', why)
  returning id into hid;
  perform cots_private.notify_handover(hid, 'handover_started', 'Area handover started',
    'No monthly visit was submitted for ' || cots_private.area_label(a.id) || ' for ' || missed
      || ' months in a row. The Expert started a handover of this area.',
    cots_private.experts() || array[main]);
  return hid;
end $$;

-- The Expert offers the area to a Diver.
create function public.offer_area_handover(hid uuid, diver uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  h public.area_handovers;
  oid uuid;
  note text;
begin
  if not cots_private.has_role('expert') then
    raise exception 'Expert required' using errcode = '42501';
  end if;
  select * into h from public.area_handovers where id = hid for update;
  if h.id is null or h.status <> 'requested' then
    raise exception 'This handover is not waiting for a new Diver' using errcode = '23514';
  end if;
  if diver = cots_private.main_diver(h.assignment_id) or not cots_private.eligible(diver) then
    raise exception 'Choose a verified, active Diver who is not the current main Diver'
      using errcode = '23514';
  end if;
  insert into public.handover_offers(handover_id, to_diver_id, offered_by)
  values (hid, diver, auth.uid()) returning id into oid;
  update public.area_handovers set status = 'offered' where id = hid;
  note := cots_private.handover_month_note(h.assignment_id);
  perform cots_private.notify_handover(hid, 'handover_offered', 'Area handover offered',
    cots_private.person_name(h.from_diver_id) || ' is handing over '
      || cots_private.area_label(h.assignment_id) || '. Reason: ' || h.reason
      || case when h.handover_note = '' then '' else ' Note: ' || h.handover_note end
      || ' ' || note || ' Please accept or decline.',
    array[diver]);
  perform cots_private.notify_handover(hid, 'handover_offer_sent', 'Area handover offered',
    cots_private.area_label(h.assignment_id) || ' was offered to ' || cots_private.person_name(diver)
      || '. Waiting for their answer.',
    array[h.from_diver_id]);
  return oid;
end $$;

-- The offered Diver accepts or declines.
create function public.respond_area_handover(oid uuid, accept boolean) returns text
language plpgsql security definer set search_path = '' as $$
declare
  o public.handover_offers;
  h public.area_handovers;
  old_main uuid;
  note text;
  r record;
  recipients uuid[];
begin
  select * into o from public.handover_offers where id = oid for update;
  if o.id is null or o.to_diver_id <> auth.uid() or not cots_private.eligible(auth.uid()) then
    raise exception 'Only the offered Diver can answer' using errcode = '42501';
  end if;
  if o.status <> 'pending' then
    raise exception 'This offer is no longer open' using errcode = '23514';
  end if;
  select * into h from public.area_handovers where id = o.handover_id for update;
  if not accept then
    update public.handover_offers set status = 'declined', responded_at = now() where id = oid;
    update public.area_handovers set status = 'requested' where id = h.id;
    perform cots_private.notify_handover(h.id, 'handover_declined', 'Area handover declined',
      cots_private.person_name(auth.uid()) || ' declined the handover of '
        || cots_private.area_label(h.assignment_id) || '. Please choose another Diver.',
      cots_private.experts() || array[h.from_diver_id]);
    return 'declined';
  end if;

  old_main := cots_private.main_diver(h.assignment_id);
  note := cots_private.handover_month_note(h.assignment_id);
  -- This month moves to the new Diver only when nobody has monitored it and
  -- nobody else is covering it.
  if note like 'This month hasn''t been monitored yet%' then
    for r in
      select q.id, q.requester_id from public.reassignment_requests q
      join public.monthly_authorizations m on m.id = q.authorization_id
      where m.assignment_id = h.assignment_id and m.month = cots_private.current_month()
        and q.status in ('requested', 'replacement_needed', 'awaiting_acceptance')
    loop
      select array_agg(p.replacement_id) into recipients
      from public.replacement_proposals p where p.request_id = r.id and p.status = 'pending';
      update public.replacement_proposals
      set status = case when expires_at <= now() then 'expired' else 'cancelled' end,
          responded_at = now()
      where request_id = r.id and status = 'pending';
      update public.reassignment_requests set status = 'cancelled', revision = revision + 1
      where id = r.id;
      perform cots_private.emit_event(r.id, null, 'reassignment_closed',
        jsonb_build_object('cancelled', true),
        coalesce(recipients, '{}'::uuid[]) || array[r.requester_id] || cots_private.experts());
    end loop;
    update public.monthly_authorizations
    set responsible_diver_id = auth.uid(), revision = revision + 1, updated_at = now()
    where assignment_id = h.assignment_id and month = cots_private.current_month()
      and responsible_diver_id = old_main;
  end if;
  update public.handover_offers set status = 'accepted', responded_at = now() where id = oid;
  update public.area_handovers set status = 'accepted', closed_at = now() where id = h.id;
  insert into public.audit_events(action, target_id, details)
  values ('area_handover_accepted', h.id,
    jsonb_build_object('assignment', h.assignment_id, 'from', old_main, 'to', auth.uid()));
  perform cots_private.notify_handover(h.id, 'handover_accepted', 'Area handover accepted',
    cots_private.person_name(auth.uid()) || ' is now the main Diver for '
      || cots_private.area_label(h.assignment_id) || '. Past records stay under '
      || cots_private.person_name(old_main) || '.',
    cots_private.experts() || array[old_main]);
  perform cots_private.notify_handover(h.id, 'handover_welcome', 'You are now the main Diver',
    'You are now the main Diver for ' || cots_private.area_label(h.assignment_id) || '. ' || note,
    array[auth.uid()]);
  return 'accepted';
end $$;

-- The Diver cancels their own request; the Expert cancels one they started.
create function public.cancel_area_handover(hid uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  h public.area_handovers;
  offered uuid;
begin
  select * into h from public.area_handovers where id = hid for update;
  if h.id is null or h.status not in ('requested', 'offered') then
    raise exception 'This handover is not open' using errcode = '23514';
  end if;
  if not ((h.started_reason = 'diver_request' and h.started_by = auth.uid()
           and exists (select 1 from public.profiles p where p.id = auth.uid() and p.active))
       or (h.started_reason = 'missed_months' and cots_private.has_role('expert'))) then
    raise exception 'Only the Diver who asked, or the Expert for a handover they started, can cancel'
      using errcode = '42501';
  end if;
  select o.to_diver_id into offered from public.handover_offers o
  where o.handover_id = hid and o.status = 'pending';
  update public.handover_offers set status = 'cancelled', responded_at = now()
  where handover_id = hid and status = 'pending';
  update public.area_handovers set status = 'cancelled', closed_at = now() where id = hid;
  perform cots_private.notify_handover(hid, 'handover_cancelled', 'Area handover cancelled',
    'The handover of ' || cots_private.area_label(h.assignment_id) || ' was cancelled.',
    cots_private.experts() || array[h.from_diver_id, offered]);
end $$;

-- Handovers for the app: Experts see all; a Diver sees their own requests
-- and offers made to them.
create function public.area_handovers_json() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  staff boolean := cots_private.is_staff();
begin
  if uid is null then
    raise exception 'Authenticated user required' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(x.item order by x.open desc, x.requested_at desc)
    from (
      select h.status in ('requested', 'offered') as open, h.requested_at,
        jsonb_build_object(
          'id', h.id,
          'area_code', ma.code,
          'area_name', ma.name,
          'from_diver_uid', h.from_diver_id,
          'from_diver_name', cots_private.person_name(h.from_diver_id),
          'started_reason', h.started_reason,
          'reason', h.reason,
          'note', h.handover_note,
          'status', h.status,
          'requested_at', h.requested_at,
          'closed_at', h.closed_at,
          'offer_id', o.id,
          'offer_status', o.status,
          'to_diver_uid', o.to_diver_id,
          'to_diver_name', case when o.id is null then null else cots_private.person_name(o.to_diver_id) end,
          'month_note', case when o.status = 'pending' then cots_private.handover_month_note(h.assignment_id) end,
          'can_respond', o.status = 'pending' and o.to_diver_id = uid,
          'can_cancel', h.status in ('requested', 'offered') and (
            (h.started_reason = 'diver_request' and h.started_by = uid)
            or (h.started_reason = 'missed_months' and cots_private.has_role('expert'))),
          'can_offer', h.status = 'requested' and cots_private.has_role('expert')) as item
      from public.area_handovers h
      join public.follow_up_assignments a on a.id = h.assignment_id
      join public.monitoring_areas ma on ma.id = a.area_id
      left join lateral (
        select q.* from public.handover_offers q where q.handover_id = h.id
        order by (q.status = 'pending') desc, q.offered_at desc limit 1) o on true
      where staff or h.from_diver_id = uid
        or exists (select 1 from public.handover_offers q2
                   where q2.handover_id = h.id and q2.to_diver_id = uid)
    ) x
  ), '[]'::jsonb);
end $$;

-- Areas and their missed months, for the Expert (Experts and Administrators).
create function public.area_missed_months_json() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not cots_private.is_staff() then
    raise exception 'Staff only' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(x.item order by x.missed desc, x.code)
    from (
      select ma.code, cots_private.missed_months_in_a_row(a.id) as missed,
        jsonb_build_object(
          'area_code', ma.code,
          'area_name', ma.name,
          'main_diver_uid', cots_private.main_diver(a.id),
          'main_diver_name', cots_private.person_name(cots_private.main_diver(a.id)),
          'missed_months', cots_private.missed_months_in_a_row(a.id),
          'open_handover', exists (select 1 from public.area_handovers h
            where h.assignment_id = a.id and h.status in ('requested', 'offered'))) as item
      from public.follow_up_assignments a
      join public.monitoring_areas ma on ma.id = a.area_id
    ) x
  ), '[]'::jsonb);
end $$;

revoke all on function
  cots_private.main_diver(uuid),
  cots_private.handover_month_note(uuid),
  cots_private.missed_months_in_a_row(uuid, date),
  cots_private.area_label(uuid),
  cots_private.person_name(uuid),
  cots_private.notify_handover(uuid, text, text, text, uuid[]),
  cots_private.experts()
from public, anon, authenticated;
revoke all on function
  public.request_area_handover(text, text, text),
  public.start_area_handover(text, text),
  public.offer_area_handover(uuid, uuid),
  public.respond_area_handover(uuid, boolean),
  public.cancel_area_handover(uuid),
  public.area_handovers_json(),
  public.area_missed_months_json()
from public, anon;
grant execute on function
  public.request_area_handover(text, text, text),
  public.start_area_handover(text, text),
  public.offer_area_handover(uuid, uuid),
  public.respond_area_handover(uuid, boolean),
  public.cancel_area_handover(uuid),
  public.area_handovers_json(),
  public.area_missed_months_json()
to authenticated;

commit;
