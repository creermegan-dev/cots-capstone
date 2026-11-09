begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select plan(5);
insert into auth.users(id, email, raw_user_meta_data) values
 ('71000000-0000-4000-8000-000000000001', 'directory-admin@example.invalid', '{"full_name":"Directory Admin"}'),
 ('71000000-0000-4000-8000-000000000002', 'directory-expert@example.invalid', '{"full_name":"Directory Expert"}'),
 ('71000000-0000-4000-8000-000000000003', 'directory-diver@example.invalid', '{"full_name":"Directory Diver"}');
select public.appoint_initial_role('administrator', '71000000-0000-4000-8000-000000000001');
select public.appoint_initial_role('expert', '71000000-0000-4000-8000-000000000002');
select public.complete_initial_setup();
set local role authenticated;
select set_config('request.jwt.claim.sub', '71000000-0000-4000-8000-000000000003', true);
select throws_ok('select * from public.expert_personnel_directory()', '42501', 'Active Expert required', 'Diver denied');
select set_config('request.jwt.claim.sub', '71000000-0000-4000-8000-000000000002', true);
select lives_ok('select * from public.expert_personnel_directory()', 'Expert can read directory');
select is((select account_role from public.expert_personnel_directory() where id='71000000-0000-4000-8000-000000000001'), 'administrator', 'Directory includes administrators');
reset role;
update public.profiles set active=false where id='71000000-0000-4000-8000-000000000002';
set local role authenticated;
select throws_ok('select * from public.expert_personnel_directory()', '42501', 'Active Expert required', 'Disabled Expert denied');
reset role;
select ok(not has_function_privilege('anon', 'public.expert_personnel_directory()', 'execute'), 'Anonymous denied');
select * from finish();
rollback;
