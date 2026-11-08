begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;
select no_plan();

select ok(has_schema_privilege('service_role','cots_private','USAGE'), 'Worker can reach request gate schema');
select ok(has_function_privilege('service_role','cots_private.check_request()','EXECUTE'), 'Worker can execute request gate');
select ok(not has_table_privilege('authenticated','cots_private.evidence_verification_jobs','UPDATE'), 'Users still cannot change jobs');
select ok(not has_function_privilege('authenticated','public.claim_evidence_verification_jobs(uuid,integer)','EXECUTE'), 'Users still cannot claim jobs');
select ok(not has_function_privilege('anon','public.claim_evidence_verification_jobs(uuid,integer)','EXECUTE'), 'Anonymous callers cannot claim jobs');
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select lives_ok('select cots_private.check_request()', 'Actual worker role passes API gate');
select lives_ok('select * from public.claim_evidence_verification_jobs(null,1)', 'Worker can reach job claiming through the gate');
reset role;

select set_config('request.jwt.claims','{"role":"authenticated","sub":"99000000-0000-4000-8000-000000000001","session_id":"99000000-0000-4000-8000-000000000002"}',true);
select set_config('request.path','/rpc/claim_evidence_verification_jobs',true);
set local role authenticated;
select throws_ok('select cots_private.check_request()', '42501','device_verification_required','Untrusted user still fails the gate');
reset role;
select * from finish();
rollback;
