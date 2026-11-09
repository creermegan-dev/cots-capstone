begin;
create function cots_private.emit_event(rid uuid,sid uuid,action_name text,payload jsonb,recipients uuid[])
returns uuid language plpgsql security definer set search_path = '' as $$
declare eid uuid;
begin
  insert into public.workflow_events(request_id,survey_id,actor_id,action,details)
    values(rid,sid,auth.uid(),action_name,payload) returning id into eid;
  insert into public.notifications(recipient_id,event_id)
    select distinct x,eid from unnest(recipients) as x where x is not null;
  return eid;
end $$;
create function cots_private.ensure_month(aid uuid,m date) returns public.monthly_authorizations
language plpgsql security definer set search_path = '' as $$
declare a public.follow_up_assignments; result public.monthly_authorizations;
begin
  select * into strict a from public.follow_up_assignments where id=aid for update;
  insert into public.monthly_authorizations(assignment_id,month,responsible_diver_id)
    values(aid,m,a.primary_diver_id) on conflict(assignment_id,month) do nothing;
  select * into strict result from public.monthly_authorizations where assignment_id=aid and month=m for update;
  return result;
end $$;

create function public.request_reassignment(aid uuid,reason_text text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare m public.monthly_authorizations; rid uuid; expert uuid;
begin
  if not cots_private.eligible(auth.uid()) then raise exception 'Verified diver required' using errcode='42501'; end if;
  m := cots_private.ensure_month(aid,cots_private.current_month());
  if m.responsible_diver_id <> auth.uid() then raise exception 'Not responsible this month' using errcode='42501'; end if;
  if exists(select 1 from public.follow_up_surveys where assignment_id=aid and month=m.month and status='completed') then
    raise exception 'Monitoring already completed this month' using errcode='23514';
  end if;
  insert into public.reassignment_requests(authorization_id,requester_id,reason) values(m.id,auth.uid(),reason_text) returning id into rid;
  select user_id into expert from public.privileged_role_slots where role='expert';
  perform cots_private.emit_event(rid,null,'reassignment_requested',jsonb_build_object('month',m.month),array[auth.uid(),expert]);
  return rid;
end $$;
create function public.propose_replacement(rid uuid,replacement uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare r public.reassignment_requests; m public.monthly_authorizations; pid uuid;
begin
  if not cots_private.has_role('expert') then raise exception 'Expert required' using errcode='42501'; end if;
  select a.* into strict m from public.monthly_authorizations a join public.reassignment_requests x on x.authorization_id=a.id where x.id=rid;
  m := cots_private.ensure_month(m.assignment_id,m.month);
  select * into strict r from public.reassignment_requests where id=rid for update;
  perform 1 from public.profiles where id=replacement for share;
  if m.month <> cots_private.current_month() or r.status not in ('requested','replacement_needed')
      or not cots_private.eligible(replacement) or replacement=m.responsible_diver_id then
    raise exception 'Invalid month, state or replacement' using errcode='23514';
  end if;
  if exists(select 1 from public.follow_up_surveys where assignment_id=m.assignment_id and month=m.month and status='completed') then
    raise exception 'Monitoring already completed this month' using errcode='23514';
  end if;
  update public.reassignment_requests set status='awaiting_acceptance',revision=revision+1 where id=rid returning * into r;
  insert into public.replacement_proposals(request_id,expert_id,replacement_id,request_revision,authorization_revision,expires_at)
    values(rid,auth.uid(),replacement,r.revision,m.revision,
      least(now()+interval '2 days',(m.month+interval '1 month')::timestamp at time zone 'Asia/Manila')) returning id into pid;
  perform cots_private.emit_event(rid,null,'replacement_proposed',jsonb_build_object('proposal',pid,'revision',r.revision),array[r.requester_id,replacement,auth.uid()]);
  return pid;
end $$;
create function public.respond_replacement(pid uuid,accept_proposal boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare p public.replacement_proposals; r public.reassignment_requests; m public.monthly_authorizations;
begin
  select * into strict p from public.replacement_proposals where id=pid;
  -- Check identity before locks/changes. Replaying an accepted response does not re-grant authority.
  if p.replacement_id <> auth.uid() or not cots_private.eligible(auth.uid()) then
    raise exception 'Only the eligible proposed diver can respond' using errcode='42501';
  end if;
  select a.* into strict m from public.monthly_authorizations a join public.reassignment_requests x on x.authorization_id=a.id where x.id=p.request_id;
  m := cots_private.ensure_month(m.assignment_id,m.month);
  select * into strict r from public.reassignment_requests where id=p.request_id for update;
  select * into strict p from public.replacement_proposals where id=pid for update;
  perform 1 from public.profiles where id=auth.uid() for share;
  if not cots_private.eligible(auth.uid()) then raise exception 'Replacement eligibility changed' using errcode='42501'; end if;
  if p.status <> 'pending' or p.expires_at <= now() or m.month <> cots_private.current_month()
    or r.status <> 'awaiting_acceptance' or p.request_revision <> r.revision or p.authorization_revision <> m.revision then
    raise exception 'Proposal is stale, expired or already answered' using errcode='23514';
  end if;
  if exists(select 1 from public.follow_up_surveys where assignment_id=m.assignment_id and month=m.month and status='completed') then
    raise exception 'Monitoring already completed this month' using errcode='23514';
  end if;
  update public.replacement_proposals set status=case when accept_proposal then 'accepted' else 'declined' end,responded_at=now() where id=pid;
  update public.reassignment_requests set status=case when accept_proposal then 'accepted' else 'replacement_needed' end,revision=revision+1 where id=r.id;
  if accept_proposal then
    update public.monthly_authorizations set responsible_diver_id=auth.uid(),revision=revision+1,updated_at=now() where id=m.id;
  end if;
  perform cots_private.emit_event(r.id,null,case when accept_proposal then 'replacement_accepted' else 'replacement_declined' end,
    jsonb_build_object('proposal',pid),array[r.requester_id,p.expert_id,p.replacement_id]);
end $$;
create function public.close_reassignment(rid uuid,cancel_request boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare r public.reassignment_requests; m public.monthly_authorizations; recipients uuid[];
begin
  if not cots_private.has_role('expert') then raise exception 'Expert required' using errcode='42501'; end if;
  select a.* into strict m from public.monthly_authorizations a join public.reassignment_requests x on x.authorization_id=a.id where x.id=rid;
  m := cots_private.ensure_month(m.assignment_id,m.month);
  select * into strict r from public.reassignment_requests where id=rid for update;
  if r.status not in ('requested','replacement_needed','awaiting_acceptance') then raise exception 'Request is not open'; end if;
  select array_agg(replacement_id) into recipients from public.replacement_proposals where request_id=rid and status='pending';
  update public.replacement_proposals set status=case when expires_at<=now() then 'expired' else 'cancelled' end,responded_at=now()
    where request_id=rid and status='pending';
  update public.reassignment_requests set status=case when cancel_request then 'cancelled' else 'replacement_needed' end,revision=revision+1 where id=rid;
  perform cots_private.emit_event(rid,null,'reassignment_closed',jsonb_build_object('cancelled',cancel_request),
    coalesce(recipients,'{}'::uuid[]) || array[r.requester_id,auth.uid()]);
end $$;

create function public.link_evidence(target_kind text,target uuid,variant uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); v public.media_variants; a public.media_assets; cid uuid;
begin
  if not cots_private.eligible(actor) then raise exception 'Verified diver required' using errcode='42501'; end if;
  select * into strict v from public.media_variants where id=variant;
  select * into strict a from public.media_assets where id=v.asset_id;
  if a.owner_id<>actor or v.kind='thumbnail' then raise exception 'Evidence owner or kind mismatch' using errcode='42501'; end if;
  if target_kind='capture' then
    perform 1 from public.captures c where c.id=target and c.owner_id=actor and c.status='pending'
      and c.source_width=a.source_width and c.source_height=a.source_height for update;
    if not found or v.bucket<>'detection-evidence' then raise exception 'Capture evidence mismatch'; end if;
    insert into public.capture_evidence values(target,variant) on conflict do nothing;
  elsif target_kind='survey' then
    perform 1 from public.follow_up_surveys where id=target and owner_id=actor
      and status in ('pending','pending_late_review','pending_authorization_review') for update;
    if not found or v.bucket<>'detection-evidence' then raise exception 'Survey evidence mismatch'; end if;
    insert into public.survey_evidence values(target,variant) on conflict do nothing;
  elsif target_kind='elimination' then
    perform 1 from public.eliminations where id=target and owner_id=actor and status='pending' for update;
    if not found or v.bucket<>'elimination-evidence' then raise exception 'Elimination evidence mismatch'; end if;
    insert into public.elimination_evidence values(target,variant) on conflict do nothing;
  else raise exception 'Unknown evidence target'; end if;
end $$;

-- Receipt is supplied ONLY by a future trusted byte-inspection worker. SQL does not
-- download/decode Storage objects, and no Storage buckets are created in Step 1.
create function public.record_verified_media(variant uuid,actual_sha256 text,actual_bytes bigint,
  actual_width integer,actual_height integer,receipt text) returns void
language plpgsql security definer set search_path = '' as $$
declare v public.media_variants;
begin
  select * into strict v from public.media_variants where id=variant for update;
  if v.sha256<>actual_sha256 or v.byte_size<>actual_bytes or v.width<>actual_width or v.height<>actual_height
    or length(trim(coalesce(receipt,'')))=0 then raise exception 'Verified bytes do not match reservation' using errcode='23514'; end if;
  if v.upload_status='verified' then return; end if;
  update public.media_variants set upload_status='verified',uploaded_at=now(),verified_at=now(),verification_receipt=receipt where id=variant;
  insert into public.audit_events(action,target_id) values('media_verified',variant);
end $$;

create function cots_private.accepted_detection_count(cid uuid,decisions jsonb) returns bigint
language sql stable security definer set search_path = '' as $$
  select count(*) from public.detection_items i where i.capture_id=cid and (
    (round(i.confidence*100)>=80 and not decisions @> jsonb_build_array(jsonb_build_object('item_id',i.id::text,'decision','reject')))
    or (round(i.confidence*100) between 20 and 79 and decisions @> jsonb_build_array(jsonb_build_object('item_id',i.id::text,'decision','approve'))))
$$;
create function public.record_expert_decision(cid uuid,sid uuid,outcome text,reason_text text,
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
        or exists(select 1 from public.detection_items i where i.capture_id=cid and round(i.confidence*100) between 20 and 79
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

create function public.finalize_capture(cid uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare c public.captures; a public.follow_up_assignments; latest public.expert_decisions; needs_review boolean;
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
  if latest.decision='reject' then
    update public.captures set status='rejected' where id=cid;
    return;
  end if;
  if needs_review and (latest.id is null or latest.decision not in ('approve','correct')) then
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
  insert into public.audit_events(action,target_id) values('capture_finalized',cid);
end $$;

create function public.finalize_survey(sid uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare s public.follow_up_surveys; m public.monthly_authorizations; latest public.expert_decisions;
  next_status text; grace_end timestamptz;
begin
  select * into strict s from public.follow_up_surveys where id=sid;
  m := cots_private.ensure_month(s.assignment_id,s.month);
  select * into strict s from public.follow_up_surveys where id=sid for update;
  if s.status in ('completed','historical_only') then return s.status; end if;
  perform 1 from public.profiles where id=s.owner_id for share;
  if not exists(select 1 from public.survey_evidence e join public.media_variants v on v.id=e.variant_id
    where e.survey_id=sid and v.upload_status='verified' and v.kind in ('evidence','supplement')) then
    raise exception 'Verified image evidence required' using errcode='23514';
  end if;
  grace_end := (s.month+interval '1 month 7 days')::timestamp at time zone 'Asia/Manila';
  select * into latest from public.expert_decisions where survey_id=sid order by decision_sequence desc limit 1;
  if latest.decision in ('historical_only','reject') then next_status := 'historical_only';
  elsif not cots_private.eligible(s.owner_id) or m.responsible_diver_id<>s.owner_id or m.revision<>s.authorization_revision
    or s.captured_at>now()+interval '5 minutes' then next_status := 'pending_authorization_review';
  elsif s.submitted_at>=grace_end and latest.decision is distinct from 'accept_late' then next_status := 'pending_late_review';
  else next_status := 'completed'; end if;
  update public.follow_up_surveys set status=next_status,completed_at=case when next_status='completed' then now() end where id=sid;
  perform cots_private.emit_event(null,sid,'survey_' || next_status,'{}'::jsonb,array[s.owner_id]);
  return next_status;
end $$;

create function public.finalize_elimination(eid uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare e public.eliminations;
begin
  select * into strict e from public.eliminations where id=eid for update;
  if e.status='finalized' then return; end if;
  perform 1 from public.profiles where id=e.owner_id for share;
  if not cots_private.eligible(e.owner_id) or not exists(select 1 from public.elimination_evidence x
    join public.media_variants v on v.id=x.variant_id where x.elimination_id=eid and v.upload_status='verified' and v.kind in ('evidence','supplement')) then
    raise exception 'Eligible actor and verified elimination evidence required' using errcode='23514';
  end if;
  update public.eliminations set status='finalized' where id=eid;
  insert into public.audit_events(action,target_id) values('elimination_finalized',eid);
end $$;
create function public.record_assessment(sid uuid,assessment_level text,assessment_method text,reason_text text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare result uuid;
begin
  if not cots_private.has_role('expert') then raise exception 'Expert required' using errcode='42501'; end if;
  if not exists(select 1 from public.follow_up_surveys where id=sid and status='completed') then raise exception 'Completed survey required'; end if;
  insert into public.infestation_assessments(survey_id,expert_id,level,method,rationale)
    values(sid,auth.uid(),assessment_level,assessment_method,reason_text) returning id into result;
  insert into public.audit_events(actor_id,action,target_id) values(auth.uid(),'assessment_recorded',result);
  return result;
end $$;
create function public.mark_notification_read(nid uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.notifications set read_at=coalesce(read_at,now()) where id=nid and recipient_id=auth.uid();
  if not found then raise exception 'Notification unavailable' using errcode='42501'; end if;
end $$;

-- Recovery metadata only: no passwords, recovery links, tokens or secret keys.
create function public.request_supervised_recovery() returns uuid
language plpgsql security definer set search_path = '' as $$
declare result uuid;
begin
  if auth.uid() is null then raise exception 'Authenticated request required; signed-out requests use the supervisor' using errcode='42501'; end if;
  insert into public.recovery_requests(subject_id) values(auth.uid()) returning id into result;
  return result;
end $$;
create function public.approve_supervised_recovery(rid uuid,verification_ref text) returns void
language plpgsql security definer set search_path = '' as $$
declare r public.recovery_requests;
begin
  if not cots_private.has_role('administrator') then raise exception 'Administrator required' using errcode='42501'; end if;
  select * into strict r from public.recovery_requests where id=rid for update;
  if r.status<>'requested' or exists(select 1 from public.privileged_role_slots where role='administrator' and user_id=r.subject_id)
    or length(trim(coalesce(verification_ref,'')))=0 then raise exception 'Independent owner procedure required or invalid recovery'; end if;
  update public.recovery_requests set status='approved',approved_by=auth.uid(),verification_reference=verification_ref,expires_at=now()+interval '15 minutes' where id=rid;
  insert into public.audit_events(actor_id,action,target_id) values(auth.uid(),'recovery_approved',rid);
end $$;

revoke all on function cots_private.emit_event(uuid,uuid,text,jsonb,uuid[]),cots_private.ensure_month(uuid,date),
  cots_private.accepted_detection_count(uuid,jsonb) from public,anon,authenticated;
-- Explicit function allowlists: no default PUBLIC execution on any application RPC.
do $$ declare f record; begin
  for f in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname=any(array['request_reassignment','propose_replacement','respond_replacement',
      'close_reassignment','link_evidence','record_verified_media','record_expert_decision','finalize_capture',
      'finalize_survey','finalize_elimination','record_assessment','mark_notification_read',
      'request_supervised_recovery','approve_supervised_recovery']) loop
    execute format('revoke all on function %s from public,anon,authenticated',f.signature);
  end loop;
end $$;
grant execute on function public.request_reassignment(uuid,text),public.propose_replacement(uuid,uuid),
  public.respond_replacement(uuid,boolean),public.close_reassignment(uuid,boolean),public.link_evidence(text,uuid,uuid),
  public.record_expert_decision(uuid,uuid,text,text,integer,jsonb),public.record_assessment(uuid,text,text,text),
  public.mark_notification_read(uuid),public.request_supervised_recovery(),public.approve_supervised_recovery(uuid,text) to authenticated;
grant execute on function public.record_verified_media(uuid,text,bigint,integer,integer,text),
  public.finalize_capture(uuid),public.finalize_survey(uuid),public.finalize_elimination(uuid) to service_role;
commit;
