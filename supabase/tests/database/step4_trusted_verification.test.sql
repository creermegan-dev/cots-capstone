-- Synthetic fixtures only; the complete suite is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, storage, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('20000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$$;

insert into auth.users(id, email, raw_user_meta_data)
select pg_temp.uid(n), 'verify-' || n || '@example.invalid',
  '{"full_name":"Verification fixture"}'::jsonb
from generate_series(1, 3) as n;
select public.appoint_initial_role('administrator', pg_temp.uid(1));
select public.appoint_initial_role('expert', pg_temp.uid(2));
select public.complete_initial_setup();
select set_config('request.jwt.claim.sub', pg_temp.uid(1)::text, true);
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
select public.verify_personnel(pg_temp.uid(3), true, true);
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
reset role;

insert into public.monitoring_areas(id, code, name, geography_version)
values(pg_temp.uid(10), 'VERIFY-TEST', 'Verification test area', 'test-only');

select set_config('request.jwt.claim.sub', pg_temp.uid(3)::text, true);
set local role authenticated;
insert into public.captures(
  id, owner_id, idempotency_key, area_id, captured_at,
  capture_time_source, model_name, model_sha256,
  source_width, source_height, gps_source
) values (
  pg_temp.uid(20), pg_temp.uid(3), pg_temp.uid(20), pg_temp.uid(10), now(),
  'device', 'verify-test', repeat('a', 64), 4, 3, 'unavailable'
);
insert into public.detection_items(
  id, capture_id, item_index, confidence, x1, y1, x2, y2
) values(pg_temp.uid(21), pg_temp.uid(20), 0, 0.60, 0, 0, 2, 2);
insert into public.eliminations(
  id, owner_id, idempotency_key, capture_id, captured_at,
  removed_count, method, gps_source
) values(
  pg_temp.uid(22), pg_temp.uid(3), pg_temp.uid(22), pg_temp.uid(20), now(),
  1, 'manual removal', 'unavailable'
);
insert into public.media_assets(
  id, owner_id, idempotency_key, original_name, original_sha256,
  original_bytes, raw_width, raw_height, source_width, source_height,
  captured_at, capture_time_source
) values
  (pg_temp.uid(30), pg_temp.uid(3), pg_temp.uid(30), 'detection.jpg', repeat('b',64), 100, 4, 3, 4, 3, now(), 'device'),
  (pg_temp.uid(32), pg_temp.uid(3), pg_temp.uid(32), 'elimination.jpg', repeat('b',64), 100, 4, 3, 4, 3, now(), 'device'),
  (pg_temp.uid(34), pg_temp.uid(3), pg_temp.uid(34), 'invalid.jpg', repeat('b',64), 100, 4, 3, 4, 3, now(), 'device');
insert into public.media_variants(
  id, asset_id, kind, version, bucket, object_path, width, height,
  byte_size, sha256, encoder
) values
  (pg_temp.uid(31), pg_temp.uid(30), 'evidence', 1, 'detection-evidence',
    pg_temp.uid(3)::text || '/' || pg_temp.uid(30)::text || '/' || pg_temp.uid(31)::text,
    4, 3, 90, repeat('c',64), 'fixture'),
  (pg_temp.uid(33), pg_temp.uid(32), 'evidence', 1, 'elimination-evidence',
    pg_temp.uid(3)::text || '/' || pg_temp.uid(32)::text || '/' || pg_temp.uid(33)::text,
    4, 3, 90, repeat('c',64), 'fixture'),
  (pg_temp.uid(35), pg_temp.uid(34), 'evidence', 1, 'detection-evidence',
    pg_temp.uid(3)::text || '/' || pg_temp.uid(34)::text || '/' || pg_temp.uid(35)::text,
    4, 3, 90, repeat('d',64), 'fixture');
insert into storage.objects(bucket_id, name) values
  ('detection-evidence', pg_temp.uid(3)::text || '/' || pg_temp.uid(30)::text || '/' || pg_temp.uid(31)::text),
  ('elimination-evidence', pg_temp.uid(3)::text || '/' || pg_temp.uid(32)::text || '/' || pg_temp.uid(33)::text),
  ('detection-evidence', pg_temp.uid(3)::text || '/' || pg_temp.uid(34)::text || '/' || pg_temp.uid(35)::text);
select public.link_evidence('capture', pg_temp.uid(20), pg_temp.uid(31));
select public.link_evidence('elimination', pg_temp.uid(22), pg_temp.uid(33));
reset role;

select is(
  (select count(*)::integer from cots_private.evidence_verification_jobs),
  3,
  'Storage inserts enqueue all reserved evidence variants'
);
select is(
  (select file_size_limit from storage.buckets where id='detection-evidence'),
  5242880::bigint,
  'Detection bucket matches the hosted verifier five MiB limit'
);
select is(
  (select file_size_limit from storage.buckets where id='elimination-evidence'),
  5242880::bigint,
  'Elimination bucket matches the hosted verifier five MiB limit'
);
select ok(
  not has_function_privilege('authenticated', 'public.claim_evidence_verification_jobs(uuid,integer)', 'EXECUTE'),
  'Authenticated callers cannot claim trusted jobs'
);
select ok(
  not has_function_privilege('authenticated', 'public.finalize_linked_evidence(uuid)', 'EXECUTE'),
  'Authenticated callers cannot invoke trusted finalization'
);
select ok(
  has_function_privilege('service_role', 'public.claim_evidence_verification_jobs(uuid,integer)', 'EXECUTE'),
  'Service role can claim trusted jobs'
);

set local role service_role;
create temporary table first_claim as
  select * from public.claim_evidence_verification_jobs(pg_temp.uid(31), 1);
select is((select count(*)::integer from first_claim), 1,
  'Trusted worker claims one requested variant');
select is(
  (select count(*)::integer from public.claim_evidence_verification_jobs(pg_temp.uid(31), 1)),
  0,
  'Concurrent worker cannot claim the active lease'
);
select public.record_verified_media(pg_temp.uid(31), repeat('c',64), 90, 4, 3, 'fixture-receipt');
create temporary table capture_finalization as
  select public.finalize_linked_evidence(pg_temp.uid(31)) result;
select is((select status from public.captures where id=pg_temp.uid(20)), 'pending',
  'Valid bytes do not bypass required Expert review');
select is((select result->>'state' from capture_finalization), 'waiting_prerequisite',
  'Trusted finalization reports the outstanding prerequisite');
select public.record_evidence_verification_outcome(
  pg_temp.uid(31), (select lock_token from first_claim),
  'waiting_prerequisite', 'record_prerequisite_pending', 'Expert review required',
  (select result from capture_finalization), 60
);
reset role;

select set_config('request.jwt.claim.sub', pg_temp.uid(2)::text, true);
set local role authenticated;
select public.record_expert_decision(
  pg_temp.uid(20), null, 'correct', 'Reviewed fixture', 1,
  jsonb_build_array(jsonb_build_object(
    'item_id', pg_temp.uid(21)::text, 'decision', 'approve'))
);
reset role;
select is(
  (select state from cots_private.evidence_verification_jobs where variant_id=pg_temp.uid(31)),
  'verified',
  'Expert decision finishes already-verified evidence at once (20261108000500)'
);

set local role service_role;
create temporary table second_claim as
  select * from public.claim_evidence_verification_jobs(pg_temp.uid(31), 1);
create temporary table completed_capture as
  select public.finalize_linked_evidence(pg_temp.uid(31)) result;
select is((select status from public.captures where id=pg_temp.uid(20)), 'finalized',
  'Capture finalizes after byte verification and required Expert decision');
-- 20261108000500: nothing left for the worker to record (the job is already closed).
select is(
  (select count(*)::integer from public.claim_evidence_verification_jobs(pg_temp.uid(31), 1)),
  0,
  'Completed verification is idempotent and is not claimed again'
);

create temporary table elimination_claim as
  select * from public.claim_evidence_verification_jobs(pg_temp.uid(33), 1);
select public.record_verified_media(pg_temp.uid(33), repeat('c',64), 90, 4, 3, 'elimination-receipt');
create temporary table completed_elimination as
  select public.finalize_linked_evidence(pg_temp.uid(33)) result;
select is((select status from public.eliminations where id=pg_temp.uid(22)), 'finalized',
  'Elimination record finalizes after integrity verification under its existing contract');
select public.record_evidence_verification_outcome(
  pg_temp.uid(33), (select lock_token from elimination_claim),
  'verified', null, null, (select result from completed_elimination), 60
);

create temporary table rejected_claim as
  select * from public.claim_evidence_verification_jobs(pg_temp.uid(35), 1);
select public.reject_evidence_media(
  pg_temp.uid(35), (select lock_token from rejected_claim),
  'sha256_mismatch', 'edge-reject-fixture'
);
select public.record_evidence_verification_outcome(
  pg_temp.uid(35), (select lock_token from rejected_claim),
  'rejected', 'sha256_mismatch', 'Stored hash does not match.', '{}'::jsonb, 60
);
select is((select upload_status from public.media_variants where id=pg_temp.uid(35)), 'failed',
  'Permanent integrity rejection marks only the media variant failed');
reset role;
select is((select state from cots_private.evidence_verification_jobs where variant_id=pg_temp.uid(35)), 'rejected',
  'Permanent integrity rejection completes its job accurately');
select throws_ok(
  format('select public.record_verified_media(%L,%L,90,4,3,%L)',
    pg_temp.uid(35), repeat('d',64), 'forged-recovery'),
  '23514', null,
  'Rejected evidence cannot be changed by an untrusted retry payload'
);

select * from finish();
rollback;
