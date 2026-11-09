-- Run only after these Vault secrets exist in the hosted project:
--   project_url: https://<project-ref>.supabase.co
--   evidence_verifier_secret_key: a hosted Supabase secret API key
-- Never commit either secret value.

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

do $$
declare existing_job bigint;
begin
  select jobid into existing_job from cron.job
    where jobname = 'cots-evidence-verifier' limit 1;
  if existing_job is not null then
    perform cron.unschedule(existing_job);
  end if;
end $$;

select cron.schedule(
  'cots-evidence-verifier',
  '* * * * *',
  $job$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets
        where name = 'project_url') || '/functions/v1/verify-evidence',
      headers := jsonb_build_object(
        'content-type', 'application/json',
        'apikey', (select decrypted_secret from vault.decrypted_secrets
          where name = 'evidence_verifier_secret_key')
      ),
      body := '{"batch_limit":5}'::jsonb,
      timeout_milliseconds := 50000
    );
  $job$
);
