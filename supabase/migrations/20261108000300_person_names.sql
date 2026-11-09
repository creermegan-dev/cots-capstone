-- Diver names on the Expert's pages (user, 2026-11-08). Profiles stay private (only the person and the Administrator
-- can read a profile row); this function gives ONLY the full name. The Expert and the Administrator get the names of
-- the people they ask for; anyone else gets only their own name.
create function public.person_names_json(ids uuid[]) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.profiles me where me.id = auth.uid() and me.active) then
    raise exception 'Active account required' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'full_name', p.full_name))
    from public.profiles p
    where p.id = any(coalesce(ids, '{}'::uuid[]))
      and (cots_private.is_staff() or p.id = auth.uid())
  ), '[]'::jsonb);
end $$;
revoke all on function public.person_names_json(uuid[]) from public, anon;
grant execute on function public.person_names_json(uuid[]) to authenticated;
