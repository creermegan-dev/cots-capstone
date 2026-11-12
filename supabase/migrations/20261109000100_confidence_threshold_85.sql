begin;

-- Freeze the policy for each photo. Existing rows keep 80; new rows get 85.
-- A constant default fills old rows without rewriting their decisions or counts.
alter table public.captures add column auto_approve_min smallint not null default 80
  constraint captures_auto_approve_min_check check (auto_approve_min in (80, 85));
alter table public.captures alter column auto_approve_min set default 85;
comment on column public.captures.auto_approve_min is
  'Rounded confidence percent required for automatic acceptance at submission time';
-- Insert permissions remain restricted to the existing column list. Clients
-- cannot choose a lower threshold or change a historical record policy.

create function cots_private.capture_auto_approve_min(cid uuid) returns integer
language sql stable security definer set search_path = '' as $$
  select c.auto_approve_min::integer from public.captures c where c.id = cid
$$;
revoke all on function cots_private.capture_auto_approve_min(uuid) from public, anon, authenticated;

-- Preserves the workflow from 20261016000300_workflows.sql; only the confidence boundary changes.
create or replace function cots_private.accepted_detection_count(cid uuid,decisions jsonb) returns bigint
language sql stable security definer set search_path = '' as $$
  select count(*) from public.detection_items i where i.capture_id=cid and (
    (round(i.confidence*100)>=cots_private.capture_auto_approve_min(cid) and not decisions @> jsonb_build_array(jsonb_build_object('item_id',i.id::text,'decision','reject')))
    or (round(i.confidence*100) between 20 and cots_private.capture_auto_approve_min(cid) - 1 and decisions @> jsonb_build_array(jsonb_build_object('item_id',i.id::text,'decision','approve'))))
$$;

-- Preserves the workflow from 20261016000300_workflows.sql; only the confidence boundary changes.
create or replace function public.record_expert_decision(cid uuid,sid uuid,outcome text,reason_text text,
  corrected integer default null,item_results jsonb default '[]'::jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare result uuid;
begin
  if not cots_private.has_role('expert') then raise exception 'Expert required' using errcode='42501'; end if;
  if cid is not null then
    perform 1 from public.captures where id=cid for update;
    if not found or outcome not in ('approve','correct','reject') then raise exception 'Invalid capture decision'; end if;
    if outcome in ('approve','correct') then
      if jsonb_typeof(item_results)<>'array' or exists(select 1 from jsonb_array_elements(item_results) j
        where coalesce(j->>'decision','') not in ('approve','reject') or not exists(
          select 1 from public.detection_items i where i.capture_id=cid and i.id::text=j->>'item_id'
            and (round(i.confidence*100)>=20 or j->>'decision'='reject')))
        or (select count(distinct j->>'item_id') from jsonb_array_elements(item_results) j) <> jsonb_array_length(item_results)
        or exists(select 1 from public.detection_items i where i.capture_id=cid and round(i.confidence*100) between 20 and cots_private.capture_auto_approve_min(cid) - 1
          and not exists(select 1 from jsonb_array_elements(item_results) j where j->>'item_id'=i.id::text)) then
        raise exception 'Each review-band COTS needs a unique decision; below-20 percent cannot be accepted' using errcode='23514';
      end if;
      if outcome='correct' and corrected is distinct from cots_private.accepted_detection_count(cid,item_results) then
        raise exception 'Corrected count must match per-COTS decisions' using errcode='23514';
      end if;
    end if;
  else
    perform 1 from public.follow_up_surveys where id=sid for update;
    if not found or outcome not in ('accept_late','historical_only','reject') then raise exception 'Invalid survey decision'; end if;
  end if;
  insert into public.expert_decisions(capture_id,survey_id,expert_id,decision,reason,corrected_count,item_decisions)
    values(cid,sid,auth.uid(),outcome,reason_text,corrected,item_results) returning id into result;
  insert into public.audit_events(actor_id,action,target_id,details)
    values(auth.uid(),'expert_decision',coalesce(cid,sid),jsonb_build_object('decision_id',result));
  return result;
end $$;

-- Preserves the workflow from 20261031000200_zone_responsibility.sql; only the confidence boundary changes.
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
    where i.capture_id = cid and round(i.confidence * 100) between 20 and cots_private.capture_auto_approve_min(cid) - 1
      and not decisions @> jsonb_build_array(jsonb_build_object('item_id', i.id::text, 'decision', 'approve'))
      and not decisions @> jsonb_build_array(jsonb_build_object('item_id', i.id::text, 'decision', 'reject')));
end $$;

-- Preserves the workflow from 20261105000100_site_partners.sql; only the confidence boundary changes.
create or replace function public.finalize_capture(cid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  select coalesce(bool_or(round(confidence*100) between 20 and cots_private.capture_auto_approve_min(cid) - 1),false) into needs_review from public.detection_items where capture_id=cid;
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
    perform cots_private.notify_capture(cid, 'zone_record_approved', 'COTS recorded at your site',
      'Another Diver recorded COTS at your site' || coalesce(' ' || area_name, '') || ' on '
        || to_char(c.captured_at at time zone 'Asia/Manila', 'FMMonth FMDD, YYYY')
        || '. The Expert approved the record.'
        || cots_private.injection_wait_line(cid),
      coalesce((select cots_private.main_divers(f.id) from public.follow_up_assignments f where f.area_id=c.area_id),
        '{}'::uuid[]));
  end if;
  insert into public.audit_events(action,target_id) values('capture_finalized',cid);
end $function$;

-- Preserves the workflow from 20261031000200_zone_responsibility.sql; only the confidence boundary changes.
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
  select count(*), coalesce(bool_or(round(i.confidence * 100) between 20 and cots_private.capture_auto_approve_min(c.id) - 1), false)
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

notify pgrst, 'reload schema';
commit;
