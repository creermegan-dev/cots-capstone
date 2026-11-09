-- Match auth.users.email (varchar) to the directory function's text contract.
begin;

create or replace function public.administrator_personnel_directory()
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
    select p.id,p.full_name,coalesce(u.email::text,''::text),p.phone,p.job_title,
      p.organization,p.active,p.field_verified,p.verified_by,p.verified_at,
      p.created_at,coalesce(s.role,'user')
    from public.profiles p
    join auth.users u on u.id=p.id
    left join public.privileged_role_slots s on s.user_id=p.id
    order by lower(p.full_name),p.id;
end $$;

commit;
