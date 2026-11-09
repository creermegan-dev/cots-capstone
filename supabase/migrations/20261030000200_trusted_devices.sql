begin;

-- New-device verification (Option B).
--
-- A password alone no longer grants data access. Each authenticated session
-- must be marked trusted, which happens only when:
--   * the session presents the secret of a device already trusted for that
--     account, or
--   * the same device proves BOTH the account password and ownership of the
--     account email (a one-time email code) within ten minutes.
--
-- Enforcement is server-side so it cannot be skipped by calling the API
-- directly:
--   1. a restrictive RLS policy on every public table and on the private
--      evidence buckets,
--   2. the role/eligibility helpers used by SECURITY DEFINER functions,
--   3. a PostgREST pre-request gate on every API call except the two
--      functions needed to establish trust.
--
-- Only sessions whose JWT role is "authenticated" are gated. Service-role
-- workers (evidence verifier, Cron) and owner tooling are unaffected.
-- Device secrets are never stored; only their SHA-256 hashes are kept.

create table cots_private.trusted_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_hash text not null check (device_hash ~ '^[0-9a-f]{64}$'),
  trusted_at timestamptz not null default now(),
  last_used_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (user_id, device_hash)
);

create table cots_private.trusted_sessions (
  session_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid not null references cots_private.trusted_devices(id) on delete cascade,
  trusted_at timestamptz not null default now()
);
create index trusted_sessions_user_idx on cots_private.trusted_sessions(user_id);

-- Short-lived evidence that a device completed one of the two required
-- checks. Rows are consumed when the device becomes trusted.
create table cots_private.device_proofs (
  user_id uuid not null references auth.users(id) on delete cascade,
  device_hash text not null check (device_hash ~ '^[0-9a-f]{64}$'),
  method text not null check (method in ('password', 'email')),
  proven_at timestamptz not null,
  session_id uuid not null,
  primary key (user_id, device_hash, method)
);

revoke all on cots_private.trusted_devices, cots_private.trusted_sessions,
  cots_private.device_proofs from public, anon, authenticated;

-- True for every non-user context (service role, owner tooling, internal
-- jobs). For an authenticated user session it is true only when the session
-- has been marked trusted on a device that has not been revoked.
create function cots_private.session_is_trusted() returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare
  claims jsonb := auth.jwt();
  sid uuid;
begin
  if coalesce(claims->>'role', '') <> 'authenticated' then
    return true;
  end if;
  begin
    sid := nullif(claims->>'session_id', '')::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  if sid is null or auth.uid() is null then
    return false;
  end if;
  return exists (
    select 1
    from cots_private.trusted_sessions s
    join cots_private.trusted_devices d on d.id = s.device_id
    where s.session_id = sid
      and s.user_id = auth.uid()
      and d.user_id = auth.uid()
      and d.revoked_at is null
  );
end $$;

revoke all on function cots_private.session_is_trusted() from public, anon, authenticated;
grant execute on function cots_private.session_is_trusted() to authenticated;

-- Called by the app right after every sign-in (and on session restore).
-- Returns 'trusted' or 'verification_required'.
create function public.register_device(device_secret text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  claims jsonb := auth.jwt();
  sid uuid;
  hash text;
  dev_id uuid;
  entry jsonb;
  proof_method text;
  proven timestamptz;
  window_start timestamptz := now() - interval '10 minutes';
  proof_count integer;
begin
  if uid is null or coalesce(claims->>'role', '') <> 'authenticated' then
    raise exception 'Authenticated session required' using errcode = '42501';
  end if;
  begin
    sid := nullif(claims->>'session_id', '')::uuid;
  exception when invalid_text_representation then
    sid := null;
  end;
  if sid is null then
    raise exception 'Session identifier unavailable' using errcode = '42501';
  end if;
  if device_secret is null or device_secret !~ '^[A-Za-z0-9_-]{43,128}$' then
    raise exception 'Invalid device identifier' using errcode = '22023';
  end if;
  if not exists (select 1 from public.profiles p where p.id = uid and p.active) then
    raise exception 'Account disabled' using errcode = '42501';
  end if;

  hash := encode(pg_catalog.sha256(convert_to(device_secret, 'UTF8')), 'hex');

  select d.id into dev_id
  from cots_private.trusted_devices d
  where d.user_id = uid and d.device_hash = hash and d.revoked_at is null;

  if dev_id is null then
    -- Record any fresh password or email-code proof carried by this session.
    -- The amr claim is part of the signed JWT issued by Supabase Auth.
    for entry in
      select value from jsonb_array_elements(
        case when jsonb_typeof(claims->'amr') = 'array'
          then claims->'amr' else '[]'::jsonb end)
    loop
      proof_method := case
        when entry->>'method' = 'password' then 'password'
        when entry->>'method' in ('otp', 'magiclink', 'email', 'email/signup', 'signup')
          then 'email'
        else null
      end;
      begin
        proven := to_timestamp((entry->>'timestamp')::double precision);
      exception when others then
        proven := null;
      end;
      if proof_method is not null and proven is not null
         and proven >= window_start and proven <= now() + interval '1 minute' then
        insert into cots_private.device_proofs(user_id, device_hash, method, proven_at, session_id)
        values (uid, hash, proof_method, proven, sid)
        on conflict (user_id, device_hash, method) do update
          set proven_at = greatest(cots_private.device_proofs.proven_at, excluded.proven_at),
              session_id = excluded.session_id;
      end if;
    end loop;

    select count(distinct p.method) into proof_count
    from cots_private.device_proofs p
    where p.user_id = uid and p.device_hash = hash and p.proven_at >= window_start;

    if proof_count < 2 then
      return 'verification_required';
    end if;

    insert into cots_private.trusted_devices(user_id, device_hash)
    values (uid, hash)
    on conflict (user_id, device_hash) do update
      set revoked_at = null, trusted_at = now(), last_used_at = now()
    returning id into dev_id;

    delete from cots_private.device_proofs
    where user_id = uid and device_hash = hash;

    insert into public.audit_events(actor_id, action, target_id)
    values (uid, 'device_trusted', dev_id);
  end if;

  insert into cots_private.trusted_sessions(session_id, user_id, device_id)
  values (sid, uid, dev_id)
  on conflict (session_id) do nothing;

  if not exists (
    select 1 from cots_private.trusted_sessions s
    where s.session_id = sid and s.user_id = uid
  ) then
    raise exception 'Session ownership mismatch' using errcode = '42501';
  end if;

  update cots_private.trusted_devices set last_used_at = now() where id = dev_id;
  return 'trusted';
end $$;

create function public.current_session_trusted() returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and cots_private.session_is_trusted()
$$;

revoke all on function public.register_device(text), public.current_session_trusted()
  from public, anon, authenticated;
grant execute on function public.register_device(text), public.current_session_trusted()
  to authenticated;

-- 1. Restrictive policies: ANDed with every existing permissive policy.
do $$
declare t text;
begin
  for t in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity
  loop
    execute format(
      'create policy trusted_session_required on public.%I as restrictive '
      'for all to authenticated using (cots_private.session_is_trusted()) '
      'with check (cots_private.session_is_trusted())', t);
  end loop;
end $$;

create policy cots_evidence_trusted_session
on storage.objects
as restrictive
for all
to authenticated
using (
  bucket_id not in ('detection-evidence', 'elimination-evidence')
  or cots_private.session_is_trusted()
)
with check (
  bucket_id not in ('detection-evidence', 'elimination-evidence')
  or cots_private.session_is_trusted()
);

-- 2. Role and eligibility helpers (same rules as before, plus trust).
create or replace function cots_private.has_role(wanted text) returns boolean
language sql stable security definer set search_path = '' as $$
  select cots_private.session_is_trusted() and exists(
    select 1 from public.privileged_role_slots r join public.profiles p on p.id=r.user_id
    where r.role=wanted and r.user_id=auth.uid() and p.active)
$$;

create or replace function cots_private.eligible(person uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select cots_private.session_is_trusted() and exists(
    select 1 from public.profiles p where p.id=person and p.active and p.field_verified
    and not exists(select 1 from public.privileged_role_slots r where r.user_id=p.id))
$$;

-- 3. API gate. Runs before every PostgREST request (tables and functions).
create function cots_private.check_request() returns void
language plpgsql stable security definer set search_path = '' as $$
declare
  request_path text := coalesce(current_setting('request.path', true), '');
begin
  if coalesce(auth.jwt()->>'role', '') <> 'authenticated' then
    return;
  end if;
  if request_path like '%/rpc/register_device'
     or request_path like '%/rpc/current_session_trusted' then
    return;
  end if;
  if not cots_private.session_is_trusted() then
    raise exception 'device_verification_required'
      using errcode = '42501',
            hint = 'Verify this device with the code sent to your email.';
  end if;
end $$;

revoke all on function cots_private.check_request() from public;
grant execute on function cots_private.check_request() to anon, authenticated;

alter role authenticator set pgrst.db_pre_request = 'cots_private.check_request';
notify pgrst, 'reload config';

commit;
