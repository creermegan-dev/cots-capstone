-- Synthetic fixtures only; the complete suite is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, storage, extensions, pg_temp;
select no_plan();

create function pg_temp.uid(n integer) returns uuid language sql immutable as $$
  select ('10000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
$$;

insert into auth.users(id, email, raw_user_meta_data)
select pg_temp.uid(n), 'storage-' || n || '@example.invalid',
  '{"full_name":"Storage fixture"}'::jsonb
from generate_series(1, 5) as n;

select public.appoint_initial_role('administrator', pg_temp.uid(1));
select public.appoint_initial_role('expert', pg_temp.uid(2));
select public.complete_initial_setup();

select set_config('request.jwt.claim.sub', pg_temp.uid(1)::text, true);
set local role authenticated;
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
select public.verify_personnel(pg_temp.uid(3), true, true);
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
select public.verify_personnel(pg_temp.uid(4), true, true);
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
select set_config('request.jwt.claim.sub',pg_temp.uid(2)::text,true);
select public.verify_personnel(pg_temp.uid(5), true, true);
select set_config('request.jwt.claim.sub',pg_temp.uid(1)::text,true);
reset role;

insert into public.monitoring_areas(id, code, name, geography_version)
values(pg_temp.uid(10), 'STORAGE-TEST', 'Storage test area', 'test-only');

select set_config('request.jwt.claim.sub', pg_temp.uid(3)::text, true);
set local role authenticated;
insert into public.captures(
  id, owner_id, idempotency_key, area_id, captured_at,
  capture_time_source, model_name, model_sha256,
  source_width, source_height, gps_source
)
values(
  pg_temp.uid(20), pg_temp.uid(3), pg_temp.uid(20), pg_temp.uid(10), now(),
  'device', 'storage-test', repeat('a', 64), 2048, 1536, 'unavailable'
);
insert into public.eliminations(
  id, owner_id, idempotency_key, capture_id, captured_at,
  removed_count, method, gps_source
)
values(
  pg_temp.uid(21), pg_temp.uid(3), pg_temp.uid(21), pg_temp.uid(20), now(),
  1, 'manual removal', 'unavailable'
);
insert into public.media_assets(
  id, owner_id, idempotency_key, original_name, original_sha256,
  original_bytes, raw_width, raw_height, source_width, source_height,
  captured_at, capture_time_source
)
values
  (pg_temp.uid(30), pg_temp.uid(3), pg_temp.uid(30), 'detection.jpg', repeat('b', 64), 600000, 2048, 1536, 2048, 1536, now(), 'device'),
  (pg_temp.uid(32), pg_temp.uid(3), pg_temp.uid(32), 'elimination.jpg', repeat('c', 64), 600000, 2048, 1536, 2048, 1536, now(), 'device'),
  (pg_temp.uid(34), pg_temp.uid(3), pg_temp.uid(34), 'oversized.jpg', repeat('2', 64), 22000000, 4096, 3072, 4096, 3072, now(), 'device');
insert into public.media_variants(
  id, asset_id, kind, version, bucket, object_path, width, height,
  byte_size, sha256, encoder
)
values
  (pg_temp.uid(31), pg_temp.uid(30), 'evidence', 1, 'detection-evidence',
    pg_temp.uid(3)::text || '/' || pg_temp.uid(30)::text || '/' || pg_temp.uid(31)::text,
    2048, 1536, 500000, repeat('d', 64), 'storage-test'),
  (pg_temp.uid(33), pg_temp.uid(32), 'evidence', 1, 'elimination-evidence',
    pg_temp.uid(3)::text || '/' || pg_temp.uid(32)::text || '/' || pg_temp.uid(33)::text,
    2048, 1536, 500000, repeat('e', 64), 'storage-test'),
  (pg_temp.uid(35), pg_temp.uid(34), 'evidence', 1, 'detection-evidence',
    pg_temp.uid(3)::text || '/' || pg_temp.uid(34)::text || '/' || pg_temp.uid(35)::text,
    4096, 3072, 22000000, repeat('3', 64), 'storage-test');

select lives_ok(
  format(
    'insert into storage.objects(bucket_id,name) values(%L,%L)',
    'detection-evidence',
    pg_temp.uid(3)::text || '/' || pg_temp.uid(30)::text || '/' || pg_temp.uid(31)::text
  ),
  'Eligible owner uploads an exactly reserved detection object'
);
select lives_ok(
  format(
    'insert into storage.objects(bucket_id,name) values(%L,%L)',
    'elimination-evidence',
    pg_temp.uid(3)::text || '/' || pg_temp.uid(32)::text || '/' || pg_temp.uid(33)::text
  ),
  'Eligible owner uploads an exactly reserved elimination object'
);
select public.link_evidence('capture', pg_temp.uid(20), pg_temp.uid(31));
select public.link_evidence('elimination', pg_temp.uid(21), pg_temp.uid(33));
select is(
  (select count(*)::integer from storage.objects
    where bucket_id in ('detection-evidence', 'elimination-evidence')),
  2,
  'Owner can read and list only the two authorized evidence objects'
);

select throws_ok(
  format(
    'insert into storage.objects(bucket_id,name) values(%L,%L)',
    'detection-evidence',
    pg_temp.uid(3)::text || '/' || pg_temp.uid(30)::text || '/' || pg_temp.uid(31)::text
  ),
  '23505', null,
  'Immutable object cannot be inserted again or overwritten'
);
select results_eq(
  $$with changed as (
    update storage.objects set metadata = '{"forged":true}'::jsonb
    where bucket_id = 'detection-evidence'
      and name = pg_temp.uid(3)::text || '/' || pg_temp.uid(30)::text || '/' || pg_temp.uid(31)::text
    returning 1
  ) select count(*)::integer from changed$$,
  array[0],
  'Owner cannot update an evidence object'
);
select throws_ok(
  format(
    'delete from storage.objects where bucket_id = %L and name = %L',
    'detection-evidence',
    pg_temp.uid(3)::text || '/' || pg_temp.uid(30)::text || '/' || pg_temp.uid(31)::text
  ),
  '42501',
  'Direct deletion from storage tables is not allowed. Use the Storage API instead.',
  'Owner cannot delete an evidence object'
);
select throws_ok(
  format(
    'insert into storage.objects(bucket_id,name) values(%L,%L)',
    'detection-evidence', 'unreserved/object/path'
  ),
  '42501', null,
  'Unreserved object path is denied'
);
select throws_ok(
  format(
    'insert into storage.objects(bucket_id,name) values(%L,%L)',
    'detection-evidence',
    pg_temp.uid(3)::text || '/' || pg_temp.uid(30)::text || '/wrong-variant'
  ),
  '42501', null,
  'Wrong variant path is denied'
);
select throws_ok(
  format(
    'insert into storage.objects(bucket_id,name) values(%L,%L)',
    'elimination-evidence',
    pg_temp.uid(3)::text || '/' || pg_temp.uid(30)::text || '/' || pg_temp.uid(31)::text
  ),
  '42501', null,
  'Reservation cannot be uploaded to the wrong bucket'
);
select throws_ok(
  format(
    'insert into storage.objects(bucket_id,name) values(%L,%L)',
    'detection-evidence',
    pg_temp.uid(3)::text || '/' || pg_temp.uid(34)::text || '/' || pg_temp.uid(35)::text
  ),
  '42501', null,
  'Reserved object above the 20 MiB transport limit is denied'
);
reset role;

select set_config('request.jwt.claim.sub', pg_temp.uid(4)::text, true);
set local role authenticated;
select is(
  (select count(*)::integer from storage.objects
    where bucket_id in ('detection-evidence', 'elimination-evidence')),
  0,
  'Unrelated user cannot list or read evidence'
);
select throws_ok(
  format(
    'insert into storage.objects(bucket_id,name) values(%L,%L)',
    'detection-evidence',
    pg_temp.uid(3)::text || '/' || pg_temp.uid(30)::text || '/' || pg_temp.uid(31)::text
  ),
  '42501', null,
  'Unrelated user cannot upload another owner reservation'
);
reset role;

select set_config('request.jwt.claim.sub', pg_temp.uid(2)::text, true);
set local role authenticated;
select is(
  (select count(*)::integer from storage.objects
    where bucket_id in ('detection-evidence', 'elimination-evidence')),
  2,
  'Expert reads evidence only through authorized linked records'
);
reset role;

select set_config('request.jwt.claim.sub', pg_temp.uid(5)::text, true);
set local role authenticated;
insert into public.media_assets(
  id, owner_id, idempotency_key, original_name, original_sha256,
  original_bytes, raw_width, raw_height, source_width, source_height,
  captured_at, capture_time_source
)
values(
  pg_temp.uid(50), pg_temp.uid(5), pg_temp.uid(50), 'disabled.jpg', repeat('f', 64),
  600000, 2048, 1536, 2048, 1536, now(), 'device'
);
insert into public.media_variants(
  id, asset_id, kind, version, bucket, object_path, width, height,
  byte_size, sha256, encoder
)
values(
  pg_temp.uid(51), pg_temp.uid(50), 'evidence', 1, 'detection-evidence',
  pg_temp.uid(5)::text || '/' || pg_temp.uid(50)::text || '/' || pg_temp.uid(51)::text,
  2048, 1536, 500000, repeat('1', 64), 'storage-test'
);
reset role;
select set_config('request.jwt.claim.sub', pg_temp.uid(1)::text, true);
set local role authenticated;
reset role;
-- Owner-only inactive fixture; verification never changes account activation.
update public.profiles set active=false where id=pg_temp.uid(5);
set local role authenticated;
reset role;
select set_config('request.jwt.claim.sub', pg_temp.uid(5)::text, true);
set local role authenticated;
select throws_ok(
  format(
    'insert into storage.objects(bucket_id,name) values(%L,%L)',
    'detection-evidence',
    pg_temp.uid(5)::text || '/' || pg_temp.uid(50)::text || '/' || pg_temp.uid(51)::text
  ),
  '42501', null,
  'Disabled user cannot upload a reserved object'
);
select is(
  (select count(*)::integer from storage.objects
    where bucket_id in ('detection-evidence', 'elimination-evidence')),
  0,
  'Disabled user cannot list or read evidence'
);
reset role;

set local role anon;
select is(
  (select count(*)::integer from storage.objects
    where bucket_id in ('detection-evidence', 'elimination-evidence')),
  0,
  'Anonymous user cannot list or read evidence'
);
select throws_ok(
  $$insert into storage.objects(bucket_id,name)
    values('detection-evidence','anonymous/object/path')$$,
  '42501', null,
  'Anonymous user cannot upload evidence'
);
reset role;

select is(
  (select public from storage.buckets where id = 'detection-evidence'),
  false,
  'Detection evidence bucket is private'
);
select is(
  (select public from storage.buckets where id = 'elimination-evidence'),
  false,
  'Elimination evidence bucket is private'
);
select is(
  (select file_size_limit from storage.buckets where id = 'detection-evidence'),
  5242880::bigint,
  'Detection evidence bucket enforces the hosted verifier five MiB limit'
);
select is(
  (select allowed_mime_types from storage.buckets where id = 'detection-evidence'),
  array['image/jpeg', 'image/webp']::text[],
  'Detection evidence bucket allows only reserved output formats'
);
select is(
  (select file_size_limit from storage.buckets where id = 'elimination-evidence'),
  5242880::bigint,
  'Elimination evidence bucket enforces the hosted verifier five MiB limit'
);
select is(
  (select allowed_mime_types from storage.buckets where id = 'elimination-evidence'),
  array['image/jpeg', 'image/webp']::text[],
  'Elimination evidence bucket allows only reserved output formats'
);

select * from finish();
rollback;
