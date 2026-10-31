-- Synthetic Step 2 Auth fixtures only; every change is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('20000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
$$;
insert into auth.users(id,email,raw_user_meta_data)
select pg_temp.uid(n),'step2-' || n || '@example.invalid',
  jsonb_build_object('full_name','Step 2 User ' || n)
from generate_series(1,5) as n;

select lives_ok(
  $$select public.appoint_initial_role('administrator',pg_temp.uid(1))$$,
  'Initial Administrator can be appointed'
);
select throws_ok(
  $$select public.complete_initial_setup()$$,
  '23514',null,
  'Initial setup cannot be sealed before both privileged roles exist'
);
select lives_ok(
  $$select public.appoint_initial_role('expert',pg_temp.uid(2))$$,
  'Initial Expert can be appointed'
);
select lives_ok(
  $$select public.complete_initial_setup()$$,
  'Exactly one Administrator and one Expert can seal initial setup'
);

select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
set local role authenticated;
select is(
  (select count(*)::integer from public.administrator_personnel_directory()),
  5,
  'Administrator can read the personnel directory'
);
select is(
  (select email from public.administrator_personnel_directory()
    where id=pg_temp.uid(3)),
  'step2-3@example.invalid',
  'Administrator directory contains the account email needed for support'
);
select lives_ok(
  $$select public.verify_personnel(pg_temp.uid(3),true,true)$$,
  'Administrator retains field-verification control'
);
select ok(
  (select field_verified from public.profiles where id=pg_temp.uid(3)),
  'Verified flag is persisted by the backend operation'
);
select lives_ok(
  $$select public.begin_supervised_recovery(
    pg_temp.uid(3),'Synthetic in-person identity check')$$,
  'Administrator can create a short-lived supervised recovery approval'
);
select is(
  (select status from public.recovery_requests where subject_id=pg_temp.uid(3)),
  'approved',
  'Supervised request starts approved after the Administrator identity check'
);
select ok(
  (select expires_at>now() and expires_at<=now()+interval '15 minutes 5 seconds'
    from public.recovery_requests where subject_id=pg_temp.uid(3)),
  'Supervised recovery has a short expiry'
);
select throws_ok(
  $$select public.begin_supervised_recovery(pg_temp.uid(3),'Duplicate')$$,
  '23505',null,
  'Only one open recovery request is allowed per account'
);
select throws_ok(
  $$select public.begin_supervised_recovery(pg_temp.uid(1),'Wrong procedure')$$,
  '42501',null,
  'Administrator recovery cannot use the supervised ordinary-user path'
);
reset role;

select set_config('request.jwt.claim.sub',pg_temp.uid(3)::text,true);
set local role authenticated;
select throws_ok(
  $$select * from public.administrator_personnel_directory()$$,
  '42501',null,
  'Ordinary users cannot read the Administrator directory'
);
select throws_ok(
  $$select public.begin_supervised_recovery(pg_temp.uid(4),'Forged')$$,
  '42501',null,
  'Ordinary users cannot approve password recovery'
);
reset role;

select ok(
  not has_function_privilege('authenticated',
    'public.consume_supervised_recovery(uuid,uuid)','EXECUTE'),
  'Authenticated clients cannot consume recovery approvals'
);
select ok(
  has_function_privilege('service_role',
    'public.consume_supervised_recovery(uuid,uuid)','EXECUTE'),
  'Trusted owner tool can consume recovery approvals'
);
select ok(
  not has_function_privilege('authenticated',
    'public.record_independent_administrator_recovery(uuid,text)','EXECUTE'),
  'Authenticated clients cannot record Administrator recovery'
);
select ok(
  has_function_privilege('service_role',
    'public.record_independent_administrator_recovery(uuid,text)','EXECUTE'),
  'Trusted owner tool can record independent Administrator recovery'
);

set local role service_role;
select lives_ok(
  $$select public.consume_supervised_recovery(
    (select id from public.recovery_requests where subject_id=pg_temp.uid(3)),
    pg_temp.uid(3))$$,
  'Trusted owner tool can consume a valid approval'
);
select is(
  (select status from public.recovery_requests where subject_id=pg_temp.uid(3)),
  'consumed',
  'Consumed approval is permanently marked consumed'
);
select ok(
  (select consumed_at is not null from public.recovery_requests
    where subject_id=pg_temp.uid(3)),
  'Consumed approval records its completion time'
);
select throws_ok(
  $$select public.consume_supervised_recovery(
    (select id from public.recovery_requests where subject_id=pg_temp.uid(3)),
    pg_temp.uid(3))$$,
  '23514',null,
  'A consumed approval cannot be replayed'
);
select lives_ok(
  $$select public.record_independent_administrator_recovery(
    pg_temp.uid(1),'Synthetic project-owner identity check')$$,
  'Trusted owner tool can record independent Administrator recovery'
);
select ok(
  (select independent_owner_recovery and status='consumed'
    from public.recovery_requests where subject_id=pg_temp.uid(1)),
  'Administrator recovery is recorded as independent and consumed'
);
select throws_ok(
  $$select public.record_independent_administrator_recovery(
    pg_temp.uid(3),'Wrong target')$$,
  '23514',null,
  'Independent Administrator procedure rejects a non-Administrator target'
);
reset role;

set local role anon;
select throws_ok(
  $$select * from public.administrator_personnel_directory()$$,
  '42501',null,
  'Anonymous callers cannot read the personnel directory'
);
select throws_ok(
  $$select public.begin_supervised_recovery(pg_temp.uid(3),'Anonymous')$$,
  '42501',null,
  'Anonymous callers cannot begin recovery'
);
reset role;

select * from finish();
rollback;
