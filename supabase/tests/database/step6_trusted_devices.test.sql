-- New-device verification. Synthetic fixtures only; everything is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('60000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.sid(n integer) returns uuid language sql immutable as $$
  select ('61000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
-- Act as a signed-in user. amr mimics the signed JWT issued by Supabase Auth.
create function pg_temp.act(person uuid, session uuid, method text, age interval)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', person, 'role', 'authenticated', 'session_id', session,
    'amr', jsonb_build_array(jsonb_build_object(
      'method', method, 'timestamp', extract(epoch from now() - age)::bigint))
  )::text, true);
  perform set_config('request.path', '/profiles', true);
end $$;
grant execute on function pg_temp.act(uuid,uuid,text,interval) to authenticated;

create function pg_temp.secret(n integer) returns text language sql immutable as $$
  select 'device-secret-' || n || '-' || repeat('x', 40)
$$;

insert into auth.users(id,email,email_confirmed_at)
values (pg_temp.uid(1),'device-a@example.invalid',now()),
       (pg_temp.uid(2),'device-b@example.invalid',now());
-- Fixture approval only (the real path is verify_personnel by the Administrator).
update public.profiles set field_verified=true, verified_by=id, verified_at=now()
where id in (pg_temp.uid(1),pg_temp.uid(2));

-- Structure and privileges.
select is(
  (select count(*)::integer from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r' and c.relrowsecurity
      and not exists(select 1 from pg_policies p where p.schemaname='public'
        and p.tablename=c.relname and p.policyname='trusted_session_required'
        and p.permissive='RESTRICTIVE')),
  0, 'Every RLS-protected public table requires a trusted session');
select ok(exists(select 1 from pg_policies where schemaname='storage' and tablename='objects'
  and policyname='cots_evidence_trusted_session' and permissive='RESTRICTIVE'),
  'Private evidence storage requires a trusted session');
select ok(exists(select 1 from pg_db_role_setting s join pg_roles r on r.oid=s.setrole
  where r.rolname='authenticator'
    and 'pgrst.db_pre_request=cots_private.check_request' = any(s.setconfig)),
  'API pre-request gate is configured');
select ok(not has_function_privilege('anon','public.register_device(text)','EXECUTE'),
  'Anonymous users cannot register devices');
select ok(not has_table_privilege('authenticated','cots_private.trusted_devices','SELECT'),
  'Users cannot read the trusted-device table directly');
select ok(not has_table_privilege('authenticated','cots_private.trusted_sessions','INSERT'),
  'Users cannot mark sessions trusted directly');

-- Password-only session on an unknown device.
select pg_temp.act(pg_temp.uid(1), pg_temp.sid(1), 'password', '1 minute');
set local role authenticated;
select is((select count(*)::integer from public.profiles), 0,
  'Untrusted session cannot read even its own profile');
select ok(not public.current_session_trusted(), 'Password-only session is untrusted');
select ok(not cots_private.eligible(auth.uid()), 'Untrusted session is not field-eligible');
select throws_ok($$select cots_private.check_request()$$, '42501', 'device_verification_required',
  'API gate rejects an untrusted session');
select set_config('request.path', '/rpc/register_device', true);
select lives_ok($$select cots_private.check_request()$$, 'API gate allows device registration');
select throws_ok($$select public.register_device('short')$$, '22023', null,
  'Malformed device secret is rejected');
select is(public.register_device(pg_temp.secret(1)), 'verification_required',
  'Password alone does not trust a new device');

-- The same device then proves email ownership with a one-time code.
select pg_temp.act(pg_temp.uid(1), pg_temp.sid(2), 'otp', '30 seconds');
select is(public.register_device(pg_temp.secret(1)), 'trusted',
  'Password plus email code on the same device trusts it');
select ok(public.current_session_trusted(), 'Verified session is trusted');
select is((select count(*)::integer from public.profiles), 1,
  'Trusted session can read its own profile');
select ok(cots_private.eligible(auth.uid()), 'Trusted approved Diver is field-eligible');
select lives_ok($$select cots_private.check_request()$$, 'API gate allows a trusted session');

-- A later password login on the trusted device needs no code.
select pg_temp.act(pg_temp.uid(1), pg_temp.sid(3), 'password', '2 days');
select is(public.register_device(pg_temp.secret(1)), 'trusted',
  'Known device is trusted without a new code');

-- Email code alone cannot trust a different device.
select pg_temp.act(pg_temp.uid(1), pg_temp.sid(4), 'otp', '10 seconds');
select is(public.register_device(pg_temp.secret(2)), 'verification_required',
  'Email code alone does not trust a new device');
select ok(not public.current_session_trusted(), 'Email-only session stays untrusted');

-- Proofs older than ten minutes do not count.
select pg_temp.act(pg_temp.uid(1), pg_temp.sid(5), 'password', '20 minutes');
select is(public.register_device(pg_temp.secret(3)), 'verification_required',
  'Stale password proof is ignored');
select pg_temp.act(pg_temp.uid(1), pg_temp.sid(6), 'otp', '5 seconds');
select is(public.register_device(pg_temp.secret(3)), 'verification_required',
  'Fresh email code cannot combine with a stale password proof');

-- First-login order: the signup email code is verified before the password.
select pg_temp.act(pg_temp.uid(2), pg_temp.sid(8), 'otp', '20 seconds');
select is(public.register_device(pg_temp.secret(10)), 'verification_required',
  'First-login email code alone is not enough');
select pg_temp.act(pg_temp.uid(2), pg_temp.sid(9), 'password', '5 seconds');
select is(public.register_device(pg_temp.secret(10)), 'trusted',
  'First login trusts the device after code then password');

-- A session identifier cannot be reused by another account.
select pg_temp.act(pg_temp.uid(2), pg_temp.sid(7), 'password', '1 minute');
select is(public.register_device(pg_temp.secret(9)), 'verification_required',
  'Second account starts unverified on its device');
select pg_temp.act(pg_temp.uid(2), pg_temp.sid(2), 'otp', '1 minute');
select throws_ok($$select public.register_device(pg_temp.secret(9))$$, '42501', null,
  'Another account cannot claim a trusted session');
reset role;

-- Revoking a device removes trust from its sessions.
update cots_private.trusted_devices set revoked_at=now() where user_id=pg_temp.uid(1);
select pg_temp.act(pg_temp.uid(1), pg_temp.sid(3), 'password', '2 days');
set local role authenticated;
select ok(not public.current_session_trusted(), 'Revoked device sessions are untrusted');
select is((select count(*)::integer from public.profiles), 0,
  'Revoked device cannot read data');
reset role;

-- Service-role workers are not gated.
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select ok(cots_private.session_is_trusted(), 'Service-role workers are unaffected');

select is((select count(*)::integer from public.audit_events where action='device_trusted'),
  2, 'Trusting a device is audited');

select * from finish();
rollback;
