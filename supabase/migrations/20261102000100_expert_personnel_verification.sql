begin;

-- Keep the existing RPC signature for compatibility, but separate professional
-- verification from account activation. No table policies or other RPCs change.
create or replace function public.verify_personnel(person uuid, verified boolean, enabled boolean)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  personnel public.profiles;
begin
  -- has_role also enforces an active account and the existing trusted session.
  if not cots_private.has_role('expert') then
    raise exception 'Active Expert required' using errcode = '42501';
  end if;
  if person is null or verified is null or enabled is null then
    raise exception 'Personnel and verification values are required' using errcode = '22004';
  end if;
  if exists (select 1 from public.privileged_role_slots where user_id = person) then
    raise exception 'Personnel operation cannot modify privileged accounts' using errcode = '23514';
  end if;

  select * into personnel from public.profiles where id = person for update;
  if not found then
    raise exception 'Unknown personnel' using errcode = 'P0002';
  end if;
  if enabled is distinct from personnel.active then
    raise exception 'Personnel verification cannot change account activation' using errcode = '23514';
  end if;
  if verified and not personnel.active then
    raise exception 'Inactive personnel cannot be verified' using errcode = '23514';
  end if;

  -- A repeated request is safe and preserves the original verification time.
  if personnel.field_verified = verified then return; end if;
  update public.profiles set
    field_verified = verified,
    verified_by = case when verified then auth.uid() end,
    verified_at = case when verified then now() end
  where id = person;
  insert into public.audit_events(actor_id, action, target_id, details)
    values(auth.uid(), 'personnel_verified', person,
      jsonb_build_object('verified', verified, 'active', personnel.active));
end $$;

revoke all on function public.verify_personnel(uuid, boolean, boolean) from public, anon;
grant execute on function public.verify_personnel(uuid, boolean, boolean) to authenticated;

commit;
