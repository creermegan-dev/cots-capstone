begin;

-- The hosted Edge runtime documents that image processing above roughly 5 MiB
-- can exceed its resource limits. Keep transport and verification limits
-- aligned so an accepted upload is processable by the trusted worker.
update storage.buckets
set file_size_limit = 5242880
where id in ('detection-evidence', 'elimination-evidence');

create table cots_private.evidence_verification_jobs (
  variant_id uuid primary key references public.media_variants(id) on delete cascade,
  state text not null default 'pending'
    check (state in ('pending', 'processing', 'retry', 'waiting_prerequisite', 'verified', 'rejected')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  locked_at timestamptz,
  lock_token uuid,
  last_error_code text,
  last_error_detail text,
  result jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  check ((state = 'processing') = (lock_token is not null and locked_at is not null)),
  check ((state in ('verified', 'rejected')) = (completed_at is not null))
);

create index evidence_verification_jobs_ready
  on cots_private.evidence_verification_jobs(next_attempt_at, updated_at)
  where state in ('pending', 'retry', 'waiting_prerequisite', 'processing');

revoke all on cots_private.evidence_verification_jobs from public, anon, authenticated;

-- Preserve the existing trusted RPC contract while making a permanent
-- rejection terminal. A later retry may re-run a verified receipt, but it may
-- never turn rejected immutable bytes into verified evidence.
create or replace function public.record_verified_media(
  variant uuid, actual_sha256 text, actual_bytes bigint,
  actual_width integer, actual_height integer, receipt text
) returns void
language plpgsql security definer set search_path = '' as $$
declare v public.media_variants;
begin
  select * into strict v from public.media_variants where id=variant for update;
  if v.upload_status = 'failed' then
    raise exception 'Rejected evidence cannot be verified' using errcode='23514';
  end if;
  if v.sha256<>actual_sha256 or v.byte_size<>actual_bytes
      or v.width<>actual_width or v.height<>actual_height
      or length(trim(coalesce(receipt,'')))=0 then
    raise exception 'Verified bytes do not match reservation' using errcode='23514';
  end if;
  if v.upload_status='verified' then return; end if;
  update public.media_variants
    set upload_status='verified', uploaded_at=now(), verified_at=now(),
      verification_receipt=receipt
    where id=variant;
  insert into public.audit_events(action,target_id) values('media_verified',variant);
end $$;

create function cots_private.enqueue_evidence_verification(
  requested_variant uuid,
  reason text default 'evidence_available'
) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.media_variants v where v.id = requested_variant
  ) then
    return;
  end if;

  insert into cots_private.evidence_verification_jobs(
    variant_id, state, next_attempt_at, last_error_code, last_error_detail,
    result, completed_at
  ) values (
    requested_variant, 'pending', now(), null, null,
    jsonb_build_object('enqueue_reason', left(coalesce(reason, ''), 80)), null
  )
  on conflict (variant_id) do update set
    state = case
      when (select upload_status from public.media_variants where id = requested_variant) = 'failed'
        then 'rejected'
      else 'pending'
    end,
    next_attempt_at = now(),
    locked_at = null,
    lock_token = null,
    last_error_code = null,
    last_error_detail = null,
    result = cots_private.evidence_verification_jobs.result ||
      jsonb_build_object('enqueue_reason', left(coalesce(reason, ''), 80)),
    completed_at = case
      when (select upload_status from public.media_variants where id = requested_variant) = 'failed'
        then coalesce(cots_private.evidence_verification_jobs.completed_at, now())
      else null
    end,
    updated_at = now();
end $$;

revoke all on function cots_private.enqueue_evidence_verification(uuid, text)
  from public, anon, authenticated;

create function cots_private.queue_evidence_storage_object() returns trigger
language plpgsql security definer set search_path = '' as $$
declare reserved_variant uuid;
begin
  if new.bucket_id not in ('detection-evidence', 'elimination-evidence') then
    return new;
  end if;
  select v.id into reserved_variant
  from public.media_variants v
  where v.bucket = new.bucket_id and v.object_path = new.name;
  if reserved_variant is not null then
    perform cots_private.enqueue_evidence_verification(reserved_variant, 'storage_insert');
  end if;
  return new;
end $$;

create trigger queue_evidence_after_storage_insert
after insert on storage.objects
for each row execute function cots_private.queue_evidence_storage_object();

create function cots_private.queue_linked_evidence() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform cots_private.enqueue_evidence_verification(new.variant_id, tg_table_name || '_insert');
  return new;
end $$;

create trigger queue_capture_evidence_after_link
after insert on public.capture_evidence
for each row execute function cots_private.queue_linked_evidence();
create trigger queue_elimination_evidence_after_link
after insert on public.elimination_evidence
for each row execute function cots_private.queue_linked_evidence();
create trigger queue_survey_evidence_after_link
after insert on public.survey_evidence
for each row execute function cots_private.queue_linked_evidence();

create function cots_private.queue_after_expert_decision() returns trigger
language plpgsql security definer set search_path = '' as $$
declare evidence_variant uuid;
begin
  if new.capture_id is not null then
    for evidence_variant in
      select e.variant_id from public.capture_evidence e where e.capture_id = new.capture_id
    loop
      perform cots_private.enqueue_evidence_verification(evidence_variant, 'expert_decision');
    end loop;
  else
    for evidence_variant in
      select e.variant_id from public.survey_evidence e where e.survey_id = new.survey_id
    loop
      perform cots_private.enqueue_evidence_verification(evidence_variant, 'expert_decision');
    end loop;
  end if;
  return new;
end $$;

create trigger queue_evidence_after_expert_decision
after insert on public.expert_decisions
for each row execute function cots_private.queue_after_expert_decision();

create function public.claim_evidence_verification_jobs(
  requested_variant uuid default null,
  requested_limit integer default 5
) returns table(variant_id uuid, lock_token uuid, attempts integer)
language plpgsql security definer set search_path = '' as $$
begin
  if current_user not in ('service_role', 'postgres') then
    raise exception 'Trusted evidence worker required' using errcode = '42501';
  end if;
  if requested_limit < 1 or requested_limit > 10 then
    raise exception 'Claim limit must be between 1 and 10' using errcode = '22023';
  end if;

  return query
  with candidates as (
    select j.variant_id
    from cots_private.evidence_verification_jobs j
    where (requested_variant is null or j.variant_id = requested_variant)
      and (
        (j.state in ('pending', 'retry', 'waiting_prerequisite') and j.next_attempt_at <= now())
        or (j.state = 'processing' and j.locked_at < now() - interval '5 minutes')
      )
    order by case when j.variant_id = requested_variant then 0 else 1 end,
      j.next_attempt_at, j.updated_at
    for update skip locked
    limit requested_limit
  ), claimed as (
    update cots_private.evidence_verification_jobs j
    set state = 'processing', attempts = j.attempts + 1,
      lock_token = gen_random_uuid(), locked_at = now(), updated_at = now(),
      completed_at = null
    from candidates c
    where j.variant_id = c.variant_id
    returning j.variant_id, j.lock_token, j.attempts
  )
  select c.variant_id, c.lock_token, c.attempts from claimed c;
end $$;

create function public.record_evidence_verification_outcome(
  requested_variant uuid,
  requested_lock_token uuid,
  requested_state text,
  error_code text default null,
  error_detail text default null,
  result_details jsonb default '{}'::jsonb,
  retry_after_seconds integer default 60
) returns void
language plpgsql security definer set search_path = '' as $$
declare variant_status text;
begin
  if current_user not in ('service_role', 'postgres') then
    raise exception 'Trusted evidence worker required' using errcode = '42501';
  end if;
  if requested_state not in ('retry', 'waiting_prerequisite', 'verified', 'rejected') then
    raise exception 'Invalid evidence job outcome' using errcode = '22023';
  end if;
  if retry_after_seconds < 5 or retry_after_seconds > 86400 then
    raise exception 'Invalid retry interval' using errcode = '22023';
  end if;
  select upload_status into strict variant_status
    from public.media_variants where id = requested_variant;
  if requested_state = 'verified' and variant_status <> 'verified' then
    raise exception 'Media must be verified before completing its job' using errcode = '23514';
  end if;
  if requested_state = 'rejected' and variant_status <> 'failed' then
    raise exception 'Rejected jobs require failed media' using errcode = '23514';
  end if;

  update cots_private.evidence_verification_jobs
  set state = requested_state,
    next_attempt_at = case
      when requested_state in ('retry', 'waiting_prerequisite')
        then now() + make_interval(secs => retry_after_seconds)
      else next_attempt_at
    end,
    locked_at = null,
    lock_token = null,
    last_error_code = nullif(left(coalesce(error_code, ''), 80), ''),
    last_error_detail = nullif(left(coalesce(error_detail, ''), 500), ''),
    result = coalesce(result_details, '{}'::jsonb),
    completed_at = case when requested_state in ('verified', 'rejected') then now() else null end,
    updated_at = now()
  where variant_id = requested_variant
    and state = 'processing'
    and lock_token = requested_lock_token;
  if not found then
    raise exception 'Evidence job lease is stale' using errcode = '40001';
  end if;
end $$;

create function public.reject_evidence_media(
  requested_variant uuid,
  requested_lock_token uuid,
  rejection_code text,
  rejection_receipt text
) returns void
language plpgsql security definer set search_path = '' as $$
declare current_status text;
begin
  if current_user not in ('service_role', 'postgres') then
    raise exception 'Trusted evidence worker required' using errcode = '42501';
  end if;
  perform 1 from cots_private.evidence_verification_jobs
    where variant_id = requested_variant and state = 'processing'
      and lock_token = requested_lock_token for update;
  if not found then
    raise exception 'Evidence job lease is stale' using errcode = '40001';
  end if;
  if length(trim(coalesce(rejection_code, ''))) = 0
      or length(trim(coalesce(rejection_receipt, ''))) = 0 then
    raise exception 'A rejection code and receipt are required' using errcode = '23514';
  end if;
  select upload_status into strict current_status
    from public.media_variants where id = requested_variant for update;
  if current_status = 'verified' then
    raise exception 'Verified evidence cannot be rejected' using errcode = '23514';
  end if;
  update public.media_variants
    set upload_status = 'failed', uploaded_at = coalesce(uploaded_at, now()),
      verified_at = null, verification_receipt = null
    where id = requested_variant;
  insert into public.audit_events(action, target_id, details)
    values('media_rejected', requested_variant,
      jsonb_build_object('code', left(rejection_code, 80), 'receipt', left(rejection_receipt, 200)));
end $$;

create function public.finalize_linked_evidence(requested_variant uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare capture_row record; elimination_row record; survey_row record;
  target_results jsonb := '[]'::jsonb; target_state text; survey_state text;
  all_terminal boolean := true; linked_count integer := 0;
begin
  if current_user not in ('service_role', 'postgres') then
    raise exception 'Trusted evidence worker required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.media_variants
    where id = requested_variant and upload_status = 'verified'
  ) then
    raise exception 'Verified evidence required' using errcode = '23514';
  end if;

  for capture_row in
    select c.id from public.capture_evidence e
      join public.captures c on c.id = e.capture_id
      where e.variant_id = requested_variant
  loop
    linked_count := linked_count + 1;
    begin
      perform public.finalize_capture(capture_row.id);
    exception when check_violation then
      null;
    end;
    select case status
      when 'finalized' then 'finalized'
      when 'rejected' then 'rejected'
      else 'awaiting_expert_or_record_prerequisite'
    end into target_state from public.captures where id = capture_row.id;
    all_terminal := all_terminal and target_state in ('finalized', 'rejected');
    target_results := target_results || jsonb_build_array(jsonb_build_object(
      'kind', 'capture', 'id', capture_row.id, 'state', target_state));
  end loop;

  for elimination_row in
    select e.id from public.elimination_evidence x
      join public.eliminations e on e.id = x.elimination_id
      where x.variant_id = requested_variant
  loop
    linked_count := linked_count + 1;
    begin
      perform public.finalize_elimination(elimination_row.id);
    exception when check_violation then
      null;
    end;
    select case status when 'finalized' then 'finalized'
      else 'awaiting_record_prerequisite' end
      into target_state from public.eliminations where id = elimination_row.id;
    all_terminal := all_terminal and target_state = 'finalized';
    target_results := target_results || jsonb_build_array(jsonb_build_object(
      'kind', 'elimination', 'id', elimination_row.id, 'state', target_state));
  end loop;

  for survey_row in
    select s.id from public.survey_evidence e
      join public.follow_up_surveys s on s.id = e.survey_id
      where e.variant_id = requested_variant
  loop
    linked_count := linked_count + 1;
    begin
      survey_state := public.finalize_survey(survey_row.id);
    exception when check_violation then
      select status into survey_state from public.follow_up_surveys where id = survey_row.id;
    end;
    target_state := case
      when survey_state in ('completed', 'historical_only') then survey_state
      else survey_state
    end;
    all_terminal := all_terminal and target_state in ('completed', 'historical_only');
    target_results := target_results || jsonb_build_array(jsonb_build_object(
      'kind', 'survey', 'id', survey_row.id, 'state', target_state));
  end loop;

  if linked_count = 0 then
    return jsonb_build_object('all_terminal', false, 'state', 'awaiting_evidence_link', 'targets', target_results);
  end if;
  return jsonb_build_object(
    'all_terminal', all_terminal,
    'state', case when all_terminal then 'finalized' else 'waiting_prerequisite' end,
    'targets', target_results
  );
end $$;

revoke all on function public.claim_evidence_verification_jobs(uuid, integer)
  from public, anon, authenticated;
revoke all on function public.record_evidence_verification_outcome(uuid, uuid, text, text, text, jsonb, integer)
  from public, anon, authenticated;
revoke all on function public.reject_evidence_media(uuid, uuid, text, text)
  from public, anon, authenticated;
revoke all on function public.finalize_linked_evidence(uuid)
  from public, anon, authenticated;
grant execute on function public.claim_evidence_verification_jobs(uuid, integer) to service_role;
grant execute on function public.record_evidence_verification_outcome(uuid, uuid, text, text, text, jsonb, integer) to service_role;
grant execute on function public.reject_evidence_media(uuid, uuid, text, text) to service_role;
grant execute on function public.finalize_linked_evidence(uuid) to service_role;

-- Backfill uploaded objects that predate this worker. Linking triggers also
-- enqueue objects that were uploaded before their record association existed.
insert into cots_private.evidence_verification_jobs(variant_id, state, next_attempt_at)
select v.id, 'pending', now()
from public.media_variants v
join storage.objects o on o.bucket_id = v.bucket and o.name = v.object_path
where v.upload_status in ('reserved', 'uploaded', 'verified')
on conflict (variant_id) do nothing;

commit;
