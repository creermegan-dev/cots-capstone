-- EMERGENCY ROLLBACK for 20261030000200_trusted_devices.sql.
-- Run only with group approval, e.g. if nobody can receive verification
-- emails during a demonstration. It removes enforcement but keeps the
-- trusted-device records so the feature can be re-enabled later.
-- Re-enable by re-running the policy, helper, and pre-request sections of
-- the migration.
begin;

alter role authenticator reset pgrst.db_pre_request;

do $$
declare t text;
begin
  for t in
    select tablename from pg_policies
    where schemaname = 'public' and policyname = 'trusted_session_required'
  loop
    execute format('drop policy trusted_session_required on public.%I', t);
  end loop;
end $$;

drop policy if exists cots_evidence_trusted_session on storage.objects;

create or replace function cots_private.has_role(wanted text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.privileged_role_slots r join public.profiles p on p.id=r.user_id
    where r.role=wanted and r.user_id=auth.uid() and p.active)
$$;

create or replace function cots_private.eligible(person uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles p where p.id=person and p.active and p.field_verified
    and not exists(select 1 from public.privileged_role_slots r where r.user_id=p.id))
$$;

-- Let current app builds continue without asking new devices for a code.
create or replace function public.register_device(device_secret text) returns text
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'Authenticated session required' using errcode = '42501';
  end if;
  return 'trusted';
end $$;

notify pgrst, 'reload config';
commit;
