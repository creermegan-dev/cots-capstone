-- Isolated synthetic identities; never run against the hosted project.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();
create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('92000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
create function pg_temp.act(n integer, trusted boolean default true) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', pg_temp.uid(n)::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub',pg_temp.uid(n),
    'role','authenticated','session_id',pg_temp.uid(case when trusted then n+100 else 999 end))::text,true);
end $$;
insert into auth.users(id,email,email_confirmed_at)
select pg_temp.uid(n),'role-stage2-' || n || '@example.invalid',now() from generate_series(1,4) n;
select public.appoint_initial_role('administrator',pg_temp.uid(1));
select public.appoint_initial_role('expert',pg_temp.uid(2));
select public.complete_initial_setup();
insert into cots_private.trusted_devices(id,user_id,device_hash)
select pg_temp.uid(n+200),pg_temp.uid(n),repeat(n::text,64) from generate_series(1,4) n;
insert into cots_private.trusted_sessions(session_id,user_id,device_id)
select pg_temp.uid(n+100),pg_temp.uid(n),pg_temp.uid(n+200) from generate_series(1,4) n;
update public.profiles set active=false where id=pg_temp.uid(4);
create temp table original_profiles as select id,to_jsonb(p)-array['field_verified','verified_by','verified_at'] as kept
  from public.profiles p where id in (pg_temp.uid(3),pg_temp.uid(4));

set local role authenticated;
select pg_temp.act(1);
select throws_ok($$select public.verify_personnel(pg_temp.uid(3),true,true)$$,
  '42501','Active Expert required','Administrator cannot verify personnel');
select lives_ok($$select * from public.administrator_personnel_directory()$$,'Admin read-only directory is preserved');
select pg_temp.act(3);
select throws_ok($$select public.verify_personnel(pg_temp.uid(3),true,true)$$,
  '42501','Active Expert required','Diver cannot self-verify');
select throws_ok($$update public.profiles set field_verified=true where id=pg_temp.uid(3)$$,
  '42501',null,'Direct profile verification is still denied');
select pg_temp.act(2,false);
select throws_ok($$select public.verify_personnel(pg_temp.uid(3),true,true)$$,
  '42501','Active Expert required','Untrusted expert session is denied');
select pg_temp.act(2);
select lives_ok($$select public.verify_personnel(pg_temp.uid(3),true,true)$$,'Trusted active expert verifies personnel');
select is((select field_verified from public.expert_personnel_directory() where id=pg_temp.uid(3)),true,'Expert directory sees saved verification');
select ok(cots_private.eligible(pg_temp.uid(3)),'Verified active diver becomes eligible');
select throws_ok($$select public.verify_personnel(pg_temp.uid(3),true,false)$$,
  '23514','Personnel verification cannot change account activation','Expert cannot disable account through verification');
select throws_ok($$select public.verify_personnel(pg_temp.uid(4),true,true)$$,
  '23514','Personnel verification cannot change account activation','Expert cannot enable inactive account');
select throws_ok($$select public.verify_personnel(pg_temp.uid(4),true,false)$$,
  '23514','Inactive personnel cannot be verified','Inactive account cannot be field verified');
select throws_ok($$select public.verify_personnel(pg_temp.uid(1),true,true)$$,
  '23514','Personnel operation cannot modify privileged accounts','Expert cannot change administrator');
select throws_ok($$select public.verify_personnel(pg_temp.uid(2),true,true)$$,
  '23514','Personnel operation cannot modify privileged accounts','Expert cannot field-verify their own privileged account');
select throws_ok($$select public.verify_personnel(pg_temp.uid(99),true,true)$$,
  'P0002','Unknown personnel','Unknown target is rejected');
select throws_ok($$select public.verify_personnel(null,true,true)$$,
  '22004','Personnel and verification values are required','Missing target is rejected');
select throws_ok($$select public.verify_personnel(pg_temp.uid(3),null,true)$$,
  '22004','Personnel and verification values are required','Null decision is rejected');
select throws_ok($$select public.verify_personnel(pg_temp.uid(3),true,null)$$,
  '22004','Personnel and verification values are required','Null activation argument cannot bypass protection');
reset role;
select is((select verified_by from public.profiles where id=pg_temp.uid(3)),pg_temp.uid(2),'Verifier identity is derived from authenticated expert');
create temp table first_verification as select verified_at from public.profiles where id=pg_temp.uid(3);
select is((select count(*) from public.audit_events where action='personnel_verified' and target_id=pg_temp.uid(3)),1::bigint,'Verification is audited once');
set local role authenticated;
select lives_ok($$select public.verify_personnel(pg_temp.uid(3),true,true)$$,'Repeated verification is safe');
reset role;
select is((select verified_at from public.profiles where id=pg_temp.uid(3)),(select verified_at from first_verification),'Repeat preserves original verification time');
select is((select count(*) from public.audit_events where action='personnel_verified' and target_id=pg_temp.uid(3)),1::bigint,'Repeat does not duplicate audit event');
set local role authenticated;
select pg_temp.act(1);
select throws_ok($$select public.verify_personnel(pg_temp.uid(3),false,true)$$,
  '42501','Active Expert required','Administrator cannot revoke verification');
select pg_temp.act(2);
select lives_ok($$select public.verify_personnel(pg_temp.uid(3),false,true)$$,'Expert can revoke verification');
select ok(not cots_private.eligible(pg_temp.uid(3)),'Revoked diver is no longer eligible');
reset role;
select ok((select not field_verified and verified_by is null and verified_at is null from public.profiles where id=pg_temp.uid(3)),'Revocation clears only verification fields');
select is((select count(*) from public.audit_events where action='personnel_verified' and target_id=pg_temp.uid(3)),2::bigint,'Revocation is audited');
select is((select count(*) from original_profiles o join public.profiles p using(id)
  where o.kept is distinct from to_jsonb(p)-array['field_verified','verified_by','verified_at']),0::bigint,
  'Activation, identity, contact details, and creation timestamps are unchanged');
update public.profiles set active=false where id=pg_temp.uid(2);
set local role authenticated;
select throws_ok($$select public.verify_personnel(pg_temp.uid(3),true,true)$$,
  '42501','Active Expert required','Inactive expert is denied');
reset role;
select ok(not has_function_privilege('anon','public.verify_personnel(uuid,boolean,boolean)','execute'),'Anonymous execution denied');
select * from finish();
rollback;
