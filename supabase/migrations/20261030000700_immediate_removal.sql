begin;

-- Immediate removal by the Diver who detected the COTS.
--
-- Agreed workflow: the Diver who finds COTS removes them during that same
-- encounter and submits the detection and removal together. There is no
-- scheduled or assigned removal task. Expert assignments apply only to later
-- follow-up monitoring.
--
-- 1. Honest quantities: when the Diver did not record how many were removed
--    (batch submissions do not ask per photo), store "not recorded" (null)
--    instead of assuming every detected COTS was removed.
-- 2. Ownership: a removal outside a follow-up visit must be linked to the
--    Diver's own detection. Previously any detection the Diver could read
--    (for example in a follow-up area) was accepted. The follow-up visit rule
--    is unchanged.
-- No existing rows are changed.

alter table public.eliminations alter column removed_count drop not null;

drop policy eliminations_insert on public.eliminations;
create policy eliminations_insert on public.eliminations for insert to authenticated with check(
  owner_id = auth.uid()
  and cots_private.eligible(auth.uid())
  and status = 'pending'
  and cots_private.can_read_capture(capture_id)
  and (
    -- Initial encounter: only the detecting Diver's own detection.
    (survey_id is null and exists (
      select 1 from public.captures c where c.id = capture_id and c.owner_id = auth.uid()))
    -- Follow-up visit (unchanged): the Diver's own pending visit in the same area.
    or (survey_id is not null and exists (
      select 1 from public.follow_up_surveys s
      join public.captures c on c.id = capture_id
      join public.follow_up_assignments a on a.id = s.assignment_id
      where s.id = survey_id and s.owner_id = auth.uid() and a.area_id = c.area_id
        and s.status = 'pending'))
  ));

commit;
