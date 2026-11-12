-- Add validation only. Keep every existing observation, including historical
-- duplicates, and leave the COTS submission/verification pipeline unchanged.
create or replace function cots_private.site_month_has_cots_report(aid uuid, m date,
 not_before timestamptz default null)
returns boolean language sql stable security definer set search_path='' as $$
 select exists (
   select 1 from public.captures c
   where c.area_id=aid and c.status<>'rejected'
     and (not_before is null or c.submitted_at>=not_before)
     and date_trunc('month',c.captured_at at time zone 'Asia/Manila')::date=m
     and exists(select 1 from public.detection_items i where i.capture_id=c.id)
     -- An unfinished reservation without uploaded evidence is not a submission.
     and (c.status='finalized' or exists(
       select 1 from public.capture_evidence e
       join public.media_variants v on v.id=e.variant_id
       where e.capture_id=c.id and v.upload_status in ('uploaded','verified')))
 );
$$;
revoke all on function cots_private.site_month_has_cots_report(uuid,date,timestamptz)
 from public,anon,authenticated;

create or replace function cots_private.guard_no_cots_site_month()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 -- Serialize competing absence reports for the site, across all Divers/kinds.
 -- This avoids deleting old duplicates to build a new unique index.
 perform 1 from public.monitoring_areas where id=new.area_id for update;
 -- The RPC still validates every original field for idempotent retries.
 if exists(select 1 from public.no_cots_surveys n where n.id=new.id) then
   return new;
 end if;
 if cots_private.site_month_has_cots_report(new.area_id,new.month) then
   raise exception 'COTS have already been reported at this site for this month. A no-COTS survey cannot be submitted.'
     using errcode='NC002';
 end if;
 if exists(select 1 from public.no_cots_surveys n
           where n.area_id=new.area_id and n.month=new.month) then
   raise exception 'A no-COTS survey already completes this site for this month. Another no-COTS survey cannot be submitted.'
     using errcode='NC001';
 end if;
 return new;
end $$;
revoke all on function cots_private.guard_no_cots_site_month()
 from public,anon,authenticated;
create trigger guard_no_cots_site_month before insert on public.no_cots_surveys
 for each row execute function cots_private.guard_no_cots_site_month();

-- Derived display flag only: the original observation is never rewritten.
create or replace function public.no_cots_surveys_json(
 p_area_code text default null,p_mine_only boolean default false)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not cots_private.session_is_trusted() or not exists(
   select 1 from public.profiles where id=auth.uid() and active) then
   raise exception 'Active trusted account required' using errcode='42501';
 end if;
 return coalesce((select jsonb_agg(to_jsonb(q) order by q.submitted_at desc) from (
   select n.*,ma.code as area_code,ma.name as area_name,p.full_name as submitted_by,
     'diver_reported'::text as report_status,
     'No COTS observed during this survey'::text as observation,
     cots_private.site_month_has_cots_report(n.area_id,n.month,n.submitted_at) as cots_reported_later
   from public.no_cots_surveys n
   join public.monitoring_areas ma on ma.id=n.area_id
   join public.profiles p on p.id=n.owner_id
   where (p_area_code is null or ma.code=p_area_code)
     and (n.owner_id=auth.uid() or
       (not coalesce(p_mine_only,false) and cots_private.is_staff()))
 ) q),'[]'::jsonb);
end $$;
