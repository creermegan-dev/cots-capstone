begin;

-- Stage 2: zone responsibility.
--
-- Agreed rules (claude/agreed_workflow_decisions.md, approved 2026-10-31):
--   * A zone counts as assigned from the original Diver's first COTS photo
--     (the photo time of the capture that created the zone's assignment).
--   * The original Diver, and the Diver who accepted a month as replacement,
--     submit there normally.
--   * Another Diver's record whose photo was taken at or after that time
--     always needs an Expert decision, even when every COTS is 80% or above.
--     That Diver is told: "This zone is currently assigned to [Diver name].
--     Your record was sent to the Expert for review." Photos taken before the
--     zone was assigned are accepted normally.
--   * Experts are notified, and reminded every 3 days until they decide.
--     Rejecting such a record needs a reason; approving does not.
--   * While it waits, its COTS count as waiting, not confirmed. After approval
--     it counts under the other Diver's name; it is not the original Diver's
--     monthly visit and never changes who owns the zone. The original Diver is
--     then notified without the other Diver's name. After a rejection the
--     original Diver is not notified.

-- Is this capture another Diver's record in an assigned zone?
create function cots_private.zone_review_needed(cid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select c.id <> a.originating_capture_id
      and c.owner_id <> a.primary_diver_id
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

-- The Diver responsible for the zone in the photo's month.
create function cots_private.zone_responsible_name(cid uuid) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce(nullif(btrim(p.full_name), ''), 'another Diver')
  from public.captures c
  join public.follow_up_assignments a on a.area_id = c.area_id
  left join public.monthly_authorizations m
    on m.assignment_id = a.id
   and m.month = date_trunc('month', c.captured_at at time zone 'Asia/Manila')::date
  left join public.profiles p on p.id = coalesce(m.responsible_diver_id, a.primary_diver_id)
  where c.id = cid
$$;

-- Has the Expert approved this capture (whole record)?
create function cots_private.capture_expert_approved(cid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((cots_private.latest_capture_decision(cid)).decision in ('approve', 'correct'), false)
$$;

-- The agreed message for the other Diver.
create function cots_private.zone_waiting_text(cid uuid) returns text
language sql stable security definer set search_path = '' as $$
  select 'This zone is currently assigned to '
    || coalesce(cots_private.zone_responsible_name(cid), 'another Diver')
    || '. Your record was sent to the Expert for review.'
$$;

-- Notice to every Expert: first notice, or the 3-day reminder.
create function cots_private.notify_zone_review(cid uuid, reminder boolean) returns void
language plpgsql security definer set search_path = '' as $$
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
        || ' was submitted by another Diver in an assigned zone. Please approve or reject it.'
    end,
    array(select r.user_id from public.privileged_role_slots r where r.role = 'expert'));
end $$;

-- Readable by the app as a computed column: captures?select=*,zone_review_assigned_to
-- Returns who the zone is assigned to when this is another Diver's record in
-- an assigned zone; otherwise null.
create function public.zone_review_assigned_to(c public.captures) returns text
language sql stable security definer set search_path = '' as $$
  select case
    when cots_private.can_read_capture(c.id) and cots_private.zone_review_needed(c.id)
    then coalesce(cots_private.zone_responsible_name(c.id), 'another Diver')
  end
$$;

-- Waiting records count as waiting, not confirmed, until the Expert approves.
create or replace function cots_private.capture_confirmed_count(cid uuid) returns integer
language plpgsql stable security definer set search_path = '' as $$
declare
  c public.captures;
  latest public.expert_decisions;
begin
  select * into c from public.captures where id = cid;
  if not found or c.status = 'rejected' then
    return 0;
  end if;
  latest := cots_private.latest_capture_decision(cid);
  if latest.decision = 'reject' then
    return 0;
  end if;
  if cots_private.zone_review_needed(cid) and not cots_private.capture_expert_approved(cid) then
    return 0;
  end if;
  return cots_private.accepted_detection_count(cid, coalesce(latest.item_decisions, '[]'::jsonb))::integer;
end $$;

create or replace function cots_private.capture_waiting_count(cid uuid) returns integer
language plpgsql stable security definer set search_path = '' as $$
declare
  c public.captures;
  latest public.expert_decisions;
  decisions jsonb;
begin
  select * into c from public.captures where id = cid;
  if not found or c.status = 'rejected' then
    return 0;
  end if;
  latest := cots_private.latest_capture_decision(cid);
  if latest.decision = 'reject' then
    return 0;
  end if;
  if cots_private.zone_review_needed(cid) and not cots_private.capture_expert_approved(cid) then
    return (select count(*)::integer from public.detection_items i
      where i.capture_id = cid and round(i.confidence * 100) >= 20);
  end if;
  decisions := coalesce(latest.item_decisions, '[]'::jsonb);
  return (select count(*)::integer from public.detection_items i
    where i.capture_id = cid and round(i.confidence * 100) between 20 and 79
      and not decisions @> jsonb_build_array(jsonb_build_object('item_id', i.id::text, 'decision', 'approve'))
      and not decisions @> jsonb_build_array(jsonb_build_object('item_id', i.id::text, 'decision', 'reject')));
end $$;

-- Finalize: another Diver's record in an assigned zone needs an Expert
-- decision; after approval the original Diver is told (no name).
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
      array(select f.primary_diver_id from public.follow_up_assignments f where f.area_id=c.area_id));
  end if;
  insert into public.audit_events(action,target_id) values('capture_finalized',cid);
end $$;

-- Rejecting another Diver's record in an assigned zone needs a reason.
create function cots_private.require_zone_reject_reason() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.capture_id is not null and new.decision = 'reject'
    and cots_private.zone_review_needed(new.capture_id)
    and nullif(btrim(coalesce(new.reason, '')), '') is null then
    raise exception 'Give a reason to reject this record' using errcode = '23514';
  end if;
  return new;
end $$;

create trigger require_zone_reject_reason
before insert on public.expert_decisions
for each row execute function cots_private.require_zone_reject_reason();

-- Submission notices: the other Diver is told who the zone is assigned to,
-- and Experts get an approval notice instead of the per-COTS review notice.
create or replace function cots_private.notify_capture_submitted() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  c public.captures;
  total integer;
  needs_review boolean;
  zone_review boolean;
  area_name text;
  where_text text;
begin
  select * into c from public.captures where id = new.capture_id;
  if not found then
    return new;
  end if;
  -- One notice per capture, even if more evidence is linked later.
  if exists (
    select 1 from public.workflow_events e
    where e.capture_id = c.id and e.action = 'scan_submitted'
  ) then
    return new;
  end if;
  select count(*), coalesce(bool_or(round(i.confidence * 100) between 20 and 79), false)
    into total, needs_review
  from public.detection_items i where i.capture_id = c.id;
  zone_review := cots_private.zone_review_needed(c.id);
  select a.name into area_name from public.monitoring_areas a where a.id = c.area_id;
  where_text := case when area_name is null then '' else ' in ' || area_name end;

  perform cots_private.notify_capture(
    c.id,
    'scan_submitted',
    'Scan submitted',
    'Your report ' || cots_private.capture_label(c.id) || ' was submitted with '
      || total || ' COTS detected' || where_text || '.'
      || case
           when zone_review then ' ' || cots_private.zone_waiting_text(c.id)
           when needs_review then ' It is waiting for Expert review.'
           else ''
         end,
    array[c.owner_id]
  );
  if zone_review then
    perform cots_private.notify_zone_review(c.id, false);
  elsif needs_review then
    perform cots_private.notify_capture(
      c.id,
      'review_needed',
      'Detection needs review',
      'Report ' || cots_private.capture_label(c.id) || where_text
        || ' has COTS that need your review.',
      array(select r.user_id from public.privileged_role_slots r where r.role = 'expert')
    );
  end if;
  return new;
end $$;

-- Reminders, run every hour by pg_cron. Each waiting record: a reminder to
-- the Experts every 3 days until an Expert decides. A record that became
-- "another Diver's" only after it was submitted (the zone was assigned in
-- between) gets its first notices here.
create function cots_private.send_zone_review_reminders(at_time timestamptz default now())
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  last_notice timestamptz;
  sent integer := 0;
begin
  for r in
    select c.id, c.owner_id from public.captures c
    where c.status = 'pending'
      and exists (select 1 from public.capture_evidence e where e.capture_id = c.id)
      and not exists (select 1 from public.expert_decisions d where d.capture_id = c.id)
      and cots_private.zone_review_needed(c.id)
    order by c.submitted_at
  loop
    select max(e.created_at) into last_notice from public.workflow_events e
    where e.capture_id = r.id and e.action in ('zone_review_needed', 'zone_review_reminder');
    if last_notice is null then
      perform cots_private.notify_zone_review(r.id, false);
      perform cots_private.notify_capture(r.id, 'zone_review_waiting', 'Waiting for Expert approval',
        'Report ' || cots_private.capture_label(r.id) || ': ' || cots_private.zone_waiting_text(r.id),
        array[r.owner_id]);
      sent := sent + 1;
    elsif last_notice <= at_time - interval '3 days' then
      perform cots_private.notify_zone_review(r.id, true);
      sent := sent + 1;
    end if;
  end loop;
  return sent;
end $$;

-- Schedule the reminders on the hosted project (pg_cron is not available in
-- every local test database).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(j.jobid) from cron.job j where j.jobname = 'cots-zone-review-reminders';
    perform cron.schedule('cots-zone-review-reminders', '23 * * * *',
      'select cots_private.send_zone_review_reminders()');
  end if;
end $$;

revoke all on function
  cots_private.zone_review_needed(uuid),
  cots_private.zone_responsible_name(uuid),
  cots_private.capture_expert_approved(uuid),
  cots_private.zone_waiting_text(uuid),
  cots_private.notify_zone_review(uuid, boolean),
  cots_private.capture_confirmed_count(uuid),
  cots_private.capture_waiting_count(uuid),
  cots_private.require_zone_reject_reason(),
  cots_private.notify_capture_submitted(),
  cots_private.send_zone_review_reminders(timestamptz)
from public, anon, authenticated;
revoke all on function public.zone_review_assigned_to(public.captures) from public, anon;
grant execute on function public.zone_review_assigned_to(public.captures) to authenticated;

commit;
