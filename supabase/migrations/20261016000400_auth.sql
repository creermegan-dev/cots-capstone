-- Step 2: Supabase Auth-facing directory and supervised recovery operations.
begin;

create unique index recovery_one_open_per_subject
on public.recovery_requests(subject_id)
where status in ('requested','approved');

-- The bootstrap operation must not be able to seal a partial privileged setup.
create or replace function public.complete_initial_setup() returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.setup_state where singleton for update;
  if (select count(*) from public.privileged_role_slots) <> 2
      or not exists(select 1 from public.privileged_role_slots where role='administrator')
      or not exists(select 1 from public.privileged_role_slots where role='expert') then
    raise exception 'Exactly one Administrator and one Expert are required'
      using errcode='23514';
  end if;
  if exists(select 1 from public.privileged_role_slots r
      join public.profiles p on p.id=r.user_id where not p.active) then
    raise exception 'Privileged accounts must be active' using errcode='23514';
  end if;
  update public.setup_state set completed_at=now() where singleton;
  insert into public.audit_events(action) values('setup_completed');
end $$;

create function public.administrator_personnel_directory()
returns table(
  id uuid,
  full_name text,
  email text,
  phone text,
  job_title text,
  organization text,
  active boolean,
  field_verified boolean,
  verified_by uuid,
  verified_at timestamptz,
  created_at timestamptz,
  account_role text
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not cots_private.has_role('administrator') then
    raise exception 'Administrator required' using errcode='42501';
  end if;
  return query
    select p.id,p.full_name,coalesce(u.email,''),p.phone,p.job_title,
      p.organization,p.active,p.field_verified,p.verified_by,p.verified_at,
      p.created_at,coalesce(s.role,'user')
    from public.profiles p
    join auth.users u on u.id=p.id
    left join public.privileged_role_slots s on s.user_id=p.id
    order by lower(p.full_name),p.id;
end $$;

create function public.begin_supervised_recovery(person uuid,verification_ref text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare result uuid;
begin
  if not cots_private.has_role('administrator') then
    raise exception 'Administrator required' using errcode='42501';
  end if;
  if length(trim(coalesce(verification_ref,'')))=0
      or length(verification_ref)>200 then
    raise exception 'A short verification reference is required' using errcode='23514';
  end if;
  if not exists(select 1 from public.profiles where id=person and active) then
    raise exception 'Active account required' using errcode='23514';
  end if;
  if exists(select 1 from public.privileged_role_slots
      where role='administrator' and user_id=person) then
    raise exception 'Administrator recovery requires the independent owner procedure'
      using errcode='42501';
  end if;

  update public.recovery_requests
    set status='expired'
    where subject_id=person and status='approved' and expires_at<=now();
  insert into public.recovery_requests(
    subject_id,approved_by,status,verification_reference,expires_at
  ) values(
    person,auth.uid(),'approved',trim(verification_ref),now()+interval '15 minutes'
  ) returning id into result;
  insert into public.audit_events(actor_id,action,target_id)
    values(auth.uid(),'recovery_approved',result);
  return result;
end $$;

create function public.consume_supervised_recovery(rid uuid,person uuid)
returns void
language plpgsql security definer set search_path = '' as $$
declare request public.recovery_requests;
begin
  select * into strict request from public.recovery_requests
    where id=rid for update;
  if request.subject_id<>person or request.status<>'approved'
      or request.expires_at<=now() then
    raise exception 'Recovery approval is invalid or expired' using errcode='23514';
  end if;
  if exists(select 1 from public.privileged_role_slots
      where role='administrator' and user_id=person) then
    raise exception 'Administrator recovery requires the independent owner procedure'
      using errcode='42501';
  end if;
  update public.recovery_requests set status='consumed',consumed_at=now()
    where id=rid;
  insert into public.audit_events(action,target_id)
    values('recovery_consumed',rid);
end $$;

create function public.record_independent_administrator_recovery(
  person uuid,verification_ref text
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare result uuid;
begin
  if length(trim(coalesce(verification_ref,'')))=0
      or length(verification_ref)>200 then
    raise exception 'A short independent verification reference is required'
      using errcode='23514';
  end if;
  if not exists(select 1 from public.privileged_role_slots
      where role='administrator' and user_id=person) then
    raise exception 'Target is not the Administrator' using errcode='23514';
  end if;
  insert into public.recovery_requests(
    subject_id,status,verification_reference,independent_owner_recovery,
    expires_at,consumed_at
  ) values(
    person,'consumed',trim(verification_ref),true,now(),now()
  ) returning id into result;
  insert into public.audit_events(action,target_id)
    values('independent_administrator_recovery',result);
  return result;
end $$;

revoke all on function public.administrator_personnel_directory(),
  public.begin_supervised_recovery(uuid,text),
  public.consume_supervised_recovery(uuid,uuid),
  public.record_independent_administrator_recovery(uuid,text)
  from public,anon,authenticated;
grant execute on function public.administrator_personnel_directory(),
  public.begin_supervised_recovery(uuid,text) to authenticated;
grant execute on function public.consume_supervised_recovery(uuid,uuid),
  public.record_independent_administrator_recovery(uuid,text) to service_role;

commit;
