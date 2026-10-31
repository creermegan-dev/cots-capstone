begin;

-- A deliberately limited directory; account management remains administrator-only.
create function public.expert_personnel_directory()
returns table(id uuid, full_name text, organization text, job_title text,
  active boolean, field_verified boolean, account_role text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not cots_private.has_role('expert') then
    raise exception 'Active Expert required' using errcode = '42501';
  end if;
  return query
    select p.id, p.full_name, p.organization, p.job_title, p.active,
      p.field_verified, coalesce(s.role, 'user')
    from public.profiles p
    left join public.privileged_role_slots s on s.user_id = p.id
    order by lower(p.full_name), p.id;
end $$;

revoke all on function public.expert_personnel_directory() from public, anon;
grant execute on function public.expert_personnel_directory() to authenticated;
commit;
