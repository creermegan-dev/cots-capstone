begin;

-- Evidence remains private. The 20 MiB transport cap matches the Flutter
-- picker limit; trusted verification must still inspect the actual bytes,
-- dimensions, hash, and encoding before finalization.
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values
  (
    'detection-evidence',
    'detection-evidence',
    false,
    20971520,
    array['image/jpeg', 'image/webp']::text[]
  ),
  (
    'elimination-evidence',
    'elimination-evidence',
    false,
    20971520,
    array['image/jpeg', 'image/webp']::text[]
  )
on conflict (id) do update
set
  name = excluded.name,
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create function cots_private.can_upload_evidence_object(
  requested_bucket text,
  requested_path text
) returns boolean
language sql stable security definer set search_path = '' as $$
  select cots_private.eligible(auth.uid()) and exists (
    select 1
    from public.media_variants v
    join public.media_assets a on a.id = v.asset_id
    where v.bucket = requested_bucket
      and v.object_path = requested_path
      and v.upload_status = 'reserved'
      and v.kind in ('evidence', 'supplement')
      and v.mime_type in ('image/jpeg', 'image/webp')
      and v.byte_size <= 20971520
      and a.owner_id = auth.uid()
      and v.object_path = auth.uid()::text || '/' || v.asset_id::text || '/' || v.id::text
  )
$$;

create function cots_private.can_read_evidence_object(
  requested_bucket text,
  requested_path text
) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.media_variants v
    where v.bucket = requested_bucket
      and v.object_path = requested_path
      and cots_private.can_read_media(v.asset_id)
  )
$$;

revoke all on function cots_private.can_upload_evidence_object(text, text)
  from public, anon, authenticated;
revoke all on function cots_private.can_read_evidence_object(text, text)
  from public, anon, authenticated;
grant execute on function cots_private.can_upload_evidence_object(text, text)
  to authenticated;
grant execute on function cots_private.can_read_evidence_object(text, text)
  to authenticated;

create policy cots_evidence_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id in ('detection-evidence', 'elimination-evidence')
  and cots_private.can_upload_evidence_object(bucket_id, name)
);

create policy cots_evidence_select
on storage.objects
for select
to authenticated
using (
  bucket_id in ('detection-evidence', 'elimination-evidence')
  and cots_private.can_read_evidence_object(bucket_id, name)
);

-- There are intentionally no authenticated UPDATE or DELETE policies.
-- A timed-out retry may read the immutable object it already inserted. If the
-- object is absent, the same still-reserved path can be inserted once.

commit;
