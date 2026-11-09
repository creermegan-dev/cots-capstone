-- Records stuck in "Processing evidence" (2026-11-08). A record whose photo is already VERIFIED can only finish
-- when its prerequisites are met (for example the Expert's review of 20-79% COTS). The photo-check worker
-- re-tries such records later, but nothing schedules that re-try, so they could stay pending forever.
-- Fix (database only, no keys or extra services):
-- 1. Right after an Expert decision, finish the record's verified evidence immediately.
-- 2. Every 10 minutes, finish any waiting record whose photo is already verified (other prerequisites, such as a
--    later approval). The photo itself is NOT re-checked here; only records with verified photos are finished.

create function cots_private.finish_verified_variant(requested_variant uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare fin jsonb;
begin
  if not exists (select 1 from public.media_variants
                 where id = requested_variant and upload_status = 'verified') then
    return false;
  end if;
  begin
    fin := public.finalize_linked_evidence(requested_variant);
    if not coalesce((fin->>'all_terminal')::boolean, false) then
      return false;
    end if;
    update cots_private.evidence_verification_jobs j
    set state = 'verified', completed_at = now(), locked_at = null, lock_token = null,
        last_error_code = null, last_error_detail = null, updated_at = now(),
        result = j.result || jsonb_build_object('finished_by', 'database')
    where j.variant_id = requested_variant and j.state <> 'rejected';
    return true;
  exception when others then
    return false;  -- Leave the record waiting; never break the caller (e.g. the Expert's decision).
  end;
end $$;
revoke all on function cots_private.finish_verified_variant(uuid) from public, anon, authenticated;

create function cots_private.finish_after_expert_decision() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v uuid;
begin
  for v in
    select e.variant_id from public.capture_evidence e where new.capture_id is not null and e.capture_id = new.capture_id
    union
    select e.variant_id from public.survey_evidence e where new.survey_id is not null and e.survey_id = new.survey_id
  loop
    perform cots_private.finish_verified_variant(v);
  end loop;
  return new;
end $$;
revoke all on function cots_private.finish_after_expert_decision() from public, anon, authenticated;

-- Named to run AFTER queue_evidence_after_expert_decision (triggers fire in name order).
create trigger zz_finish_after_expert_decision
after insert on public.expert_decisions
for each row execute function cots_private.finish_after_expert_decision();

create function cots_private.finish_waiting_records(max_records integer default 50) returns integer
language plpgsql security definer set search_path = '' as $$
declare v uuid; done integer := 0;
begin
  for v in
    select j.variant_id from cots_private.evidence_verification_jobs j
    join public.media_variants m on m.id = j.variant_id and m.upload_status = 'verified'
    where j.state in ('waiting_prerequisite', 'retry', 'pending')
    order by j.updated_at
    limit greatest(least(coalesce(max_records, 50), 200), 1)
  loop
    if cots_private.finish_verified_variant(v) then done := done + 1; end if;
  end loop;
  return done;
end $$;
revoke all on function cots_private.finish_waiting_records(integer) from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(j.jobid) from cron.job j where j.jobname = 'cots-finish-waiting-records';
    perform cron.schedule('cots-finish-waiting-records', '*/10 * * * *', 'select cots_private.finish_waiting_records()');
  end if;
end $$;
