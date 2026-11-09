begin;

-- In-app notifications for detections, created by the database itself.
--
-- The app never writes notifications: these triggers create them when a
-- detection is submitted, needs Expert review, is reviewed, or is finalized
-- by the trusted worker. Wording is stored with the event so every screen
-- shows the same text. Notifications are history: people can mark them read
-- or dismiss them from their list, but never delete or edit them.

alter table public.workflow_events
  add column capture_id uuid references public.captures(id);
create index workflow_events_capture_idx on public.workflow_events(capture_id);

alter table public.notifications add column dismissed_at timestamptz;
create index notifications_recipient_idx
  on public.notifications(recipient_id, created_at desc);

-- People may read the event behind each of their own notifications.
create policy events_read_recipient on public.workflow_events
for select to authenticated using (
  exists (
    select 1 from public.notifications n
    where n.event_id = workflow_events.id and n.recipient_id = auth.uid()
  )
);

create function cots_private.capture_label(cid uuid) returns text
language sql stable security definer set search_path = '' as $$
  select 'CAP-' || upper(left(cid::text, 8))
$$;

create function cots_private.notify_capture(
  cid uuid,
  action_name text,
  title text,
  body text,
  recipients uuid[]
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  eid uuid;
  area_name text;
begin
  if coalesce(cardinality(recipients), 0) = 0 then
    return;
  end if;
  select a.name into area_name
  from public.captures c join public.monitoring_areas a on a.id = c.area_id
  where c.id = cid;
  insert into public.workflow_events(capture_id, actor_id, action, details)
  values (
    cid,
    (select p.id from public.profiles p where p.id = auth.uid()),
    action_name,
    jsonb_build_object(
      'title', title,
      'body', body,
      'record_id', cots_private.capture_label(cid),
      'zone', coalesce(area_name, '')
    )
  )
  returning id into eid;
  insert into public.notifications(recipient_id, event_id)
  select distinct x, eid from unnest(recipients) as x
  where x is not null and exists (select 1 from public.profiles p where p.id = x);
end $$;

-- Submission finished (evidence linked): tell the owner, and the Expert when
-- any COTS needs review.
create function cots_private.notify_capture_submitted() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  c public.captures;
  total integer;
  needs_review boolean;
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
  select a.name into area_name from public.monitoring_areas a where a.id = c.area_id;
  where_text := case when area_name is null then '' else ' in ' || area_name end;

  perform cots_private.notify_capture(
    c.id,
    'scan_submitted',
    'Scan submitted',
    'Your report ' || cots_private.capture_label(c.id) || ' was submitted with '
      || total || ' COTS detected' || where_text || '.'
      || case when needs_review then ' It is waiting for Expert review.' else '' end,
    array[c.owner_id]
  );
  if needs_review then
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

create trigger notify_after_capture_evidence
after insert on public.capture_evidence
for each row execute function cots_private.notify_capture_submitted();

-- Expert decision: tell the owner.
create function cots_private.notify_expert_decision() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  c public.captures;
  area_name text;
  for_text text;
begin
  if new.capture_id is null then
    return new;
  end if;
  select * into c from public.captures where id = new.capture_id;
  select a.name into area_name from public.monitoring_areas a where a.id = c.area_id;
  for_text := case when area_name is null then '' else ' for ' || area_name end;
  if new.decision in ('approve', 'correct') then
    perform cots_private.notify_capture(
      c.id, 'review_accepted', 'Report accepted',
      'Your report ' || cots_private.capture_label(c.id) || for_text
        || ' was approved by the Expert.',
      array[c.owner_id]);
  elsif new.decision = 'reject' then
    perform cots_private.notify_capture(
      c.id, 'review_rejected', 'Report rejected',
      'Your report ' || cots_private.capture_label(c.id) || for_text
        || ' was rejected by the Expert. Open the record for details.',
      array[c.owner_id]);
  end if;
  return new;
end $$;

create trigger notify_after_expert_decision
after insert on public.expert_decisions
for each row execute function cots_private.notify_expert_decision();

-- Finalized without an Expert decision (automatic path): tell the owner.
create function cots_private.notify_capture_status() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.status = new.status or old.status <> 'pending' then
    return new;
  end if;
  if exists (select 1 from public.expert_decisions d where d.capture_id = new.id) then
    return new;
  end if;
  if new.status = 'finalized' then
    perform cots_private.notify_capture(
      new.id, 'record_finalized', 'Report verified',
      'Your report ' || cots_private.capture_label(new.id)
        || ' was verified and added to the monitoring records.',
      array[new.owner_id]);
  elsif new.status = 'rejected' then
    perform cots_private.notify_capture(
      new.id, 'record_rejected', 'Report not accepted',
      'Your report ' || cots_private.capture_label(new.id)
        || ' could not be accepted. Open the record for details.',
      array[new.owner_id]);
  end if;
  return new;
end $$;

create trigger notify_after_capture_status
after update of status on public.captures
for each row execute function cots_private.notify_capture_status();

create function public.mark_all_notifications_read() returns integer
language plpgsql security definer set search_path = '' as $$
declare changed integer;
begin
  if auth.uid() is null then
    raise exception 'Authenticated user required' using errcode = '42501';
  end if;
  update public.notifications set read_at = now()
  where recipient_id = auth.uid() and read_at is null and dismissed_at is null;
  get diagnostics changed = row_count;
  return changed;
end $$;

create function public.dismiss_notifications(ids uuid[]) returns integer
language plpgsql security definer set search_path = '' as $$
declare changed integer;
begin
  if auth.uid() is null then
    raise exception 'Authenticated user required' using errcode = '42501';
  end if;
  update public.notifications
  set dismissed_at = now(), read_at = coalesce(read_at, now())
  where recipient_id = auth.uid() and id = any(ids) and dismissed_at is null;
  get diagnostics changed = row_count;
  return changed;
end $$;

revoke all on function cots_private.capture_label(uuid),
  cots_private.notify_capture(uuid, text, text, text, uuid[]),
  cots_private.notify_capture_submitted(),
  cots_private.notify_expert_decision(),
  cots_private.notify_capture_status()
  from public, anon, authenticated;
revoke all on function public.mark_all_notifications_read(),
  public.dismiss_notifications(uuid[]) from public, anon;
grant execute on function public.mark_all_notifications_read(),
  public.dismiss_notifications(uuid[]) to authenticated;

commit;
