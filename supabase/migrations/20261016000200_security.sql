begin;
-- SECURITY DEFINER routines are owned by the migration owner, use no mutable search_path,
-- derive client actors from auth.uid(), and receive explicit grants at the end.
create function cots_private.has_role(wanted text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.privileged_role_slots r join public.profiles p on p.id=r.user_id
    where r.role=wanted and r.user_id=auth.uid() and p.active)
$$;
create function cots_private.is_staff() returns boolean
language sql stable security definer set search_path = '' as $$
  select cots_private.has_role('administrator') or cots_private.has_role('expert')
$$;
create function cots_private.eligible(person uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles p where p.id=person and p.active and p.field_verified
    and not exists(select 1 from public.privileged_role_slots r where r.user_id=p.id))
$$;
create function cots_private.current_month() returns date
language sql stable set search_path = '' as $$
  select date_trunc('month',now() at time zone 'Asia/Manila')::date
$$;
create function cots_private.can_read_assignment(aid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select cots_private.is_staff() or exists(
    select 1 from public.follow_up_assignments a join public.profiles p on p.id=auth.uid()
    where a.id=aid and p.active and (a.primary_diver_id=auth.uid() or exists(
      select 1 from public.monthly_authorizations m where m.assignment_id=a.id
        and m.month=cots_private.current_month() and m.responsible_diver_id=auth.uid()
        and cots_private.eligible(auth.uid()))))
$$;
create function cots_private.can_read_capture(cid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select cots_private.is_staff() or exists(select 1 from public.captures c
    join public.profiles p on p.id=auth.uid() where c.id=cid and p.active and
    (c.owner_id=auth.uid() or exists(select 1 from public.follow_up_assignments a
      where a.area_id=c.area_id and cots_private.can_read_assignment(a.id))))
$$;
create function cots_private.can_read_survey(sid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select cots_private.is_staff() or exists(select 1 from public.follow_up_surveys s
    join public.profiles p on p.id=auth.uid() where s.id=sid and p.active and
    (s.owner_id=auth.uid() or cots_private.can_read_assignment(s.assignment_id)))
$$;
create function cots_private.can_read_elimination(eid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select cots_private.is_staff() or exists(select 1 from public.eliminations e
    join public.profiles p on p.id=auth.uid() where e.id=eid and p.active and
    (e.owner_id=auth.uid() or (e.survey_id is not null and cots_private.can_read_survey(e.survey_id))))
$$;
create function cots_private.can_read_media(mid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles p where p.id=auth.uid() and p.active) and (
    exists(select 1 from public.media_assets a where a.id=mid and a.owner_id=auth.uid()) or exists(
      select 1 from public.media_variants v where v.asset_id=mid and (
        exists(select 1 from public.capture_evidence e where e.variant_id=v.id and cots_private.can_read_capture(e.capture_id)) or
        exists(select 1 from public.survey_evidence e where e.variant_id=v.id and cots_private.can_read_survey(e.survey_id)) or
        exists(select 1 from public.elimination_evidence e where e.variant_id=v.id and cots_private.can_read_elimination(e.elimination_id)))))
$$;
create function cots_private.can_read_request(rid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select cots_private.is_staff() or exists(select 1 from public.reassignment_requests r
    join public.profiles p on p.id=auth.uid() where r.id=rid and p.active and
    (r.requester_id=auth.uid() or exists(select 1 from public.replacement_proposals x
      where x.request_id=r.id and x.replacement_id=auth.uid())))
$$;

create function cots_private.new_auth_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- No role, active flag or verification field is taken from user metadata.
  insert into public.profiles(id,full_name) values(new.id,left(coalesce(new.raw_user_meta_data->>'full_name',''),200));
  return new;
end $$;
create trigger cots_new_auth_profile after insert on auth.users
for each row execute function cots_private.new_auth_profile();

create function cots_private.guard_slots() returns trigger
language plpgsql security definer set search_path = '' as $$
declare done timestamptz;
begin
  select completed_at into done from public.setup_state where singleton for update;
  if done is not null then raise exception 'Privileged slots are sealed; use approved independent recovery of the same identity' using errcode='23514'; end if;
  return coalesce(new,old);
end $$;
create trigger guard_privileged_slots before insert or update or delete on public.privileged_role_slots
for each row execute function cots_private.guard_slots();
create function cots_private.guard_setup() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op='DELETE' or old.completed_at is not null then
    raise exception 'Setup cannot be removed or reopened' using errcode='23514';
  end if;
  if new.completed_at is not null and (select count(*) from public.privileged_role_slots) <> 2 then
    raise exception 'Both separate privileged accounts are required' using errcode='23514';
  end if;
  return new;
end $$;
create trigger guard_setup before update or delete on public.setup_state
for each row execute function cots_private.guard_setup();

create function cots_private.reject_history_change() returns trigger
language plpgsql set search_path = '' as $$
begin raise exception 'Append-only history or permanent assignment cannot be rewritten' using errcode='23514'; end $$;
do $$ declare t text; begin
  foreach t in array array['audit_events','workflow_events','expert_decisions','infestation_assessments','follow_up_assignments'] loop
    execute format('create trigger immutable_history before update or delete on public.%I for each row execute function cots_private.reject_history_change()',t);
    execute format('create trigger immutable_history_truncate before truncate on public.%I for each statement execute function cots_private.reject_history_change()',t);
  end loop;
end $$;
create trigger no_slots_truncate before truncate on public.privileged_role_slots
for each statement execute function cots_private.reject_history_change();
create trigger no_setup_truncate before truncate on public.setup_state
for each statement execute function cots_private.reject_history_change();

create function public.appoint_initial_role(wanted text,person uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.setup_state where singleton for update;
  insert into public.privileged_role_slots(role,user_id) values(wanted,person);
  insert into public.audit_events(action,target_id,details) values('initial_role_appointed',person,jsonb_build_object('role',wanted));
end $$;
create function public.complete_initial_setup() returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.setup_state where singleton for update;
  if exists(select 1 from public.privileged_role_slots r join public.profiles p on p.id=r.user_id where not p.active) then
    raise exception 'Privileged accounts must be active';
  end if;
  update public.setup_state set completed_at=now() where singleton;
  insert into public.audit_events(action) values('setup_completed');
end $$;
create function public.verify_personnel(person uuid,verified boolean,enabled boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not cots_private.has_role('administrator') then raise exception 'Administrator required' using errcode='42501'; end if;
  if exists(select 1 from public.privileged_role_slots where user_id=person) then
    raise exception 'Personnel operation cannot modify privileged accounts';
  end if;
  update public.profiles set active=enabled,field_verified=verified,
    verified_by=case when verified then auth.uid() end,verified_at=case when verified then now() end where id=person;
  if not found then raise exception 'Unknown personnel'; end if;
  insert into public.audit_events(actor_id,action,target_id,details)
    values(auth.uid(),'personnel_verified',person,jsonb_build_object('verified',verified,'active',enabled));
end $$;
create function public.eligible_personnel() returns table(id uuid,full_name text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not cots_private.is_staff() then raise exception 'Staff required' using errcode='42501'; end if;
  return query select p.id,p.full_name from public.profiles p where cots_private.eligible(p.id) order by p.full_name;
end $$;

-- Enforce source dimensions and lifecycle even through trusted insertion routines.
create function cots_private.validate_item() returns trigger
language plpgsql security definer set search_path = '' as $$
declare c public.captures;
begin
  select * into strict c from public.captures where id=new.capture_id for update;
  if c.status <> 'pending' or new.x2 > c.source_width or new.y2 > c.source_height
    or exists(select 1 from public.expert_decisions where capture_id=c.id) then
    raise exception 'Invalid source box or frozen capture' using errcode='23514';
  end if;
  return new;
end $$;
create trigger validate_detection_item before insert on public.detection_items
for each row execute function cots_private.validate_item();

-- All tables default deny. Explicit writes below only permit immutable pending inputs.
do $$ declare t text; begin
  foreach t in array array['profiles','setup_state','privileged_role_slots','monitoring_areas','captures',
    'detection_items','follow_up_assignments','monthly_authorizations','follow_up_surveys','eliminations',
    'media_assets','media_variants','capture_evidence','elimination_evidence','survey_evidence','expert_decisions',
    'reassignment_requests','replacement_proposals','workflow_events','notifications','infestation_assessments','audit_events','recovery_requests'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from public, anon, authenticated',t);
    execute format('grant select on public.%I to authenticated',t);
  end loop;
end $$;
create policy profiles_read on public.profiles for select to authenticated
  using (id=auth.uid() or cots_private.has_role('administrator'));
grant update(full_name,organization,job_title,phone) on public.profiles to authenticated;
create policy profiles_edit on public.profiles for update to authenticated using(id=auth.uid() and active) with check(id=auth.uid() and active);
create policy slots_read on public.privileged_role_slots for select to authenticated using(user_id=auth.uid() or cots_private.has_role('administrator'));
create policy setup_read on public.setup_state for select to authenticated using(cots_private.has_role('administrator'));
create policy areas_read on public.monitoring_areas for select to authenticated using(exists(select 1 from public.profiles where id=auth.uid() and active));
create policy captures_read on public.captures for select to authenticated using(cots_private.can_read_capture(id));
create policy captures_insert on public.captures for insert to authenticated with check(owner_id=auth.uid() and cots_private.eligible(auth.uid()) and status='pending');
grant insert(id,owner_id,idempotency_key,area_id,captured_at,capture_time_source,original_time_text,timezone_assumed,
  model_name,model_sha256,source_width,source_height,latitude,longitude,gps_source,gps_accuracy_m,gps_captured_at,notes)
  on public.captures to authenticated;
create policy items_read on public.detection_items for select to authenticated using(cots_private.can_read_capture(capture_id));
create policy items_insert on public.detection_items for insert to authenticated with check(exists(
  select 1 from public.captures c where c.id=capture_id and c.owner_id=auth.uid() and c.status='pending' and cots_private.eligible(auth.uid())));
grant insert(id,capture_id,item_index,confidence,x1,y1,x2,y2,estimated_size_cm) on public.detection_items to authenticated;
create policy assignments_read on public.follow_up_assignments for select to authenticated using(cots_private.can_read_assignment(id));
create policy authorizations_read on public.monthly_authorizations for select to authenticated
  using(cots_private.can_read_assignment(assignment_id));
create policy surveys_read on public.follow_up_surveys for select to authenticated using(cots_private.can_read_survey(id));
-- Capture even stale/unauthorized offline work, but only as pending private evidence.
create policy surveys_insert on public.follow_up_surveys for insert to authenticated
  with check(owner_id=auth.uid() and cots_private.eligible(auth.uid()) and status='pending');
grant insert(id,owner_id,idempotency_key,assignment_id,captured_at,month,authorization_revision,latitude,longitude,
  gps_source,gps_accuracy_m,gps_captured_at,observed_count,notes) on public.follow_up_surveys to authenticated;
create policy eliminations_read on public.eliminations for select to authenticated using(cots_private.can_read_elimination(id));
create policy eliminations_insert on public.eliminations for insert to authenticated with check(
  owner_id=auth.uid() and cots_private.eligible(auth.uid()) and status='pending' and cots_private.can_read_capture(capture_id)
  and (survey_id is null or exists(select 1 from public.follow_up_surveys s join public.captures c on c.id=capture_id
    join public.follow_up_assignments a on a.id=s.assignment_id
    where s.id=survey_id and s.owner_id=auth.uid() and a.area_id=c.area_id and s.status='pending')));
grant insert(id,owner_id,idempotency_key,capture_id,survey_id,captured_at,removed_count,method,notes,
  latitude,longitude,gps_source,gps_accuracy_m,gps_captured_at) on public.eliminations to authenticated;
create policy assets_read on public.media_assets for select to authenticated using(cots_private.can_read_media(id));
create policy assets_insert on public.media_assets for insert to authenticated with check(owner_id=auth.uid() and cots_private.eligible(auth.uid()));
grant insert(id,owner_id,idempotency_key,original_name,original_sha256,original_bytes,raw_width,raw_height,
  source_width,source_height,exif_orientation,captured_at,capture_time_source,original_time_text,timezone_assumed) on public.media_assets to authenticated;
create policy variants_read on public.media_variants for select to authenticated using(cots_private.can_read_media(asset_id));
create policy variants_insert on public.media_variants for insert to authenticated with check(
  upload_status='reserved' and cots_private.eligible(auth.uid()) and exists(select 1 from public.media_assets a
    where a.id=asset_id and a.owner_id=auth.uid()) and object_path=auth.uid()::text || '/' || asset_id::text || '/' || id::text);
grant insert(id,asset_id,kind,version,bucket,object_path,format,mime_type,width,height,byte_size,sha256,encoder,encoder_settings)
  on public.media_variants to authenticated;
create policy capture_links_read on public.capture_evidence for select to authenticated using(cots_private.can_read_capture(capture_id));
create policy elimination_links_read on public.elimination_evidence for select to authenticated using(cots_private.can_read_elimination(elimination_id));
create policy survey_links_read on public.survey_evidence for select to authenticated using(cots_private.can_read_survey(survey_id));
create policy decisions_read on public.expert_decisions for select to authenticated using(
  (capture_id is not null and cots_private.can_read_capture(capture_id)) or (survey_id is not null and cots_private.can_read_survey(survey_id)));
create policy requests_read on public.reassignment_requests for select to authenticated using(cots_private.can_read_request(id));
create policy proposals_read on public.replacement_proposals for select to authenticated using(cots_private.can_read_request(request_id));
create policy events_read on public.workflow_events for select to authenticated using(cots_private.is_staff()
  or (request_id is not null and cots_private.can_read_request(request_id)) or (survey_id is not null and cots_private.can_read_survey(survey_id)));
create policy notifications_read on public.notifications for select to authenticated using(recipient_id=auth.uid());
create policy assessments_read on public.infestation_assessments for select to authenticated using(cots_private.can_read_survey(survey_id));
create policy audit_read on public.audit_events for select to authenticated using(cots_private.has_role('administrator'));
create policy recovery_read on public.recovery_requests for select to authenticated using(subject_id=auth.uid() or cots_private.has_role('administrator'));

-- Default PUBLIC function execution would expose mutation helpers; revoke it explicitly.
revoke all on all functions in schema cots_private from public,anon,authenticated;
grant usage on schema cots_private to authenticated;
grant execute on function cots_private.has_role(text),cots_private.is_staff(),cots_private.eligible(uuid),
  cots_private.current_month(),cots_private.can_read_assignment(uuid),cots_private.can_read_capture(uuid),
  cots_private.can_read_survey(uuid),cots_private.can_read_elimination(uuid),cots_private.can_read_media(uuid),
  cots_private.can_read_request(uuid) to authenticated;
revoke all on function public.appoint_initial_role(text,uuid),public.complete_initial_setup(),
  public.verify_personnel(uuid,boolean,boolean),public.eligible_personnel() from public,anon,authenticated;
grant execute on function public.appoint_initial_role(text,uuid),public.complete_initial_setup() to service_role;
grant execute on function public.verify_personnel(uuid,boolean,boolean),public.eligible_personnel() to authenticated;
commit;
