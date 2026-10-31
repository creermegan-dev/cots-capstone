-- Synthetic confirmation/profile fixtures only; every change is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

create function pg_temp.signup_uid() returns uuid language sql immutable as $$
  select '50000000-0000-4000-8000-000000000001'::uuid
$$;

insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data)
values (
  pg_temp.signup_uid(),
  'confirmation@example.invalid',
  null,
  jsonb_build_object(
    'full_name','Confirmation Diver',
    'phone','+63 900 000 0000',
    'job_title','Volunteer Diver',
    'organization','Reef Unit',
    'account_role','administrator',
    'active',false,
    'field_verified',true
  )
);

select is(
  (select full_name from public.profiles where id=pg_temp.signup_uid()),
  'Confirmation Diver',
  'Signup trigger preserves the ordinary full-name field'
);
select is(
  (select phone from public.profiles where id=pg_temp.signup_uid()),
  '+63 900 000 0000',
  'Signup trigger preserves the ordinary phone field'
);
select ok(
  (select active and not field_verified
    from public.profiles where id=pg_temp.signup_uid()),
  'Client metadata cannot disable, approve, or privilege a new Diver'
);
select is(
  (select count(*)::integer from public.privileged_role_slots
    where user_id=pg_temp.signup_uid()),
  0,
  'Signup metadata cannot appoint a privileged role'
);

select set_config('request.jwt.claim.sub',pg_temp.signup_uid()::text,true);
set local role authenticated;
select throws_ok(
  $$select public.complete_signup_profile()$$,
  '42501',null,
  'Profile completion requires a confirmed email'
);
reset role;

update auth.users
set email_confirmed_at=now(),
    raw_user_meta_data=jsonb_build_object(
      'full_name','Confirmation Diver',
      'phone','metadata phone',
      'job_title','Volunteer Diver',
      'organization','Reef Unit'
    )
where id=pg_temp.signup_uid();
update public.profiles
set phone='user edited phone', organization=''
where id=pg_temp.signup_uid();

set local role authenticated;
select lives_ok(
  $$select public.complete_signup_profile()$$,
  'Confirmed user can complete missing ordinary profile fields'
);
select lives_ok(
  $$select public.complete_signup_profile()$$,
  'Repeated profile completion is idempotent'
);
select is(
  (select phone from public.profiles where id=pg_temp.signup_uid()),
  'user edited phone',
  'Profile completion does not overwrite a later user edit'
);
select is(
  (select organization from public.profiles where id=pg_temp.signup_uid()),
  'Reef Unit',
  'Profile completion fills a missing ordinary field from signup metadata'
);
reset role;

select ok(
  has_function_privilege(
    'authenticated','public.complete_signup_profile()','EXECUTE'
  ),
  'Authenticated users may invoke profile completion'
);
select ok(
  not has_function_privilege(
    'anon','public.complete_signup_profile()','EXECUTE'
  ),
  'Anonymous users cannot invoke profile completion'
);

select * from finish();
rollback;
