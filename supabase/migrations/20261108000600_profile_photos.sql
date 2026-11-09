-- Optional profile photo for each person (added 2026-11-08).
-- * Private bucket `profile-photos`, JPEG only, at most 1 MiB (the app shrinks the picture first).
-- * Each person may upload or delete files only in their own folder: <their id>/<random id>.jpg
-- * Like the rest of the app, a trusted (verified-device) session is required.
-- * The person, Experts and Administrators may view a photo. Other Divers cannot.
-- * profiles.avatar_path points to the current photo; only the owner can set it, and only to a
--   path in their own folder.
begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-photos', 'profile-photos', false, 1048576, array['image/jpeg']::text[])
on conflict (id) do update
set name = excluded.name,
    public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

alter table public.profiles add column avatar_path text;
alter table public.profiles add constraint profiles_avatar_path_own_folder check (
  avatar_path is null or (
    avatar_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'
    and split_part(avatar_path, '/', 1) = id::text
  )
);
grant update(avatar_path) on public.profiles to authenticated;

create function cots_private.is_own_profile_photo(requested_path text)
returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null
    and cots_private.session_is_trusted()
    and requested_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'
    and split_part(requested_path, '/', 1) = auth.uid()::text
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.active)
$$;

create function cots_private.can_view_profile_photo(requested_path text)
returns boolean
language sql stable security definer set search_path = '' as $$
  select cots_private.is_own_profile_photo(requested_path)
    or (cots_private.is_staff()
        and cots_private.session_is_trusted()
        and requested_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$')
$$;

revoke all on function cots_private.is_own_profile_photo(text) from public, anon, authenticated;
revoke all on function cots_private.can_view_profile_photo(text) from public, anon, authenticated;
grant execute on function cots_private.is_own_profile_photo(text) to authenticated;
grant execute on function cots_private.can_view_profile_photo(text) to authenticated;

create policy cots_profile_photo_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'profile-photos' and cots_private.is_own_profile_photo(name));

create policy cots_profile_photo_select on storage.objects
for select to authenticated
using (bucket_id = 'profile-photos' and cots_private.can_view_profile_photo(name));

create policy cots_profile_photo_delete on storage.objects
for delete to authenticated
using (bucket_id = 'profile-photos' and cots_private.is_own_profile_photo(name));

-- No UPDATE policy: a new photo is always a new file name, so old cached copies never show.

commit;
