begin;

-- Signup metadata contains only ordinary editable profile fields. Privileged
-- roles, activation, and field verification remain server-controlled.
create or replace function cots_private.new_auth_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(
    id, full_name, phone, job_title, organization
  ) values (
    new.id,
    left(trim(coalesce(new.raw_user_meta_data->>'full_name', '')), 200),
    left(trim(coalesce(new.raw_user_meta_data->>'phone', '')), 40),
    left(trim(coalesce(new.raw_user_meta_data->>'job_title', '')), 120),
    left(trim(coalesce(new.raw_user_meta_data->>'organization', '')), 200)
  );
  return new;
end $$;

-- Confirmation callbacks may be delivered more than once. This operation is
-- idempotent and fills only blank editable fields, so it cannot overwrite a
-- later user edit or grant any account privilege.
create function public.complete_signup_profile() returns void
language plpgsql security definer set search_path = '' as $$
declare
  metadata jsonb;
  confirmed_at timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Authenticated user required' using errcode = '42501';
  end if;

  select u.raw_user_meta_data, u.email_confirmed_at
    into strict metadata, confirmed_at
    from auth.users u
    where u.id = auth.uid();

  if confirmed_at is null then
    raise exception 'Confirmed email required' using errcode = '42501';
  end if;

  update public.profiles p set
    full_name = case when trim(p.full_name) = ''
      then left(trim(coalesce(metadata->>'full_name', '')), 200)
      else p.full_name end,
    phone = case when trim(p.phone) = ''
      then left(trim(coalesce(metadata->>'phone', '')), 40)
      else p.phone end,
    job_title = case when trim(p.job_title) = ''
      then left(trim(coalesce(metadata->>'job_title', '')), 120)
      else p.job_title end,
    organization = case when trim(p.organization) = ''
      then left(trim(coalesce(metadata->>'organization', '')), 200)
      else p.organization end
  where p.id = auth.uid();

  if not found then
    raise exception 'Profile unavailable' using errcode = 'P0002';
  end if;
end $$;

revoke all on function public.complete_signup_profile() from public, anon;
grant execute on function public.complete_signup_profile() to authenticated;

commit;
