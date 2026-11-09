begin;

-- Preferences only: these values do not grant privileges, enroll MFA,
-- send mail or change the existing notification delivery workflow.
create table public.admin_preferences (
  uid uuid primary key references public.profiles(id) on delete cascade,
  email_notifications boolean not null default true,
  high_risk_alerts boolean not null default true,
  system_updates boolean not null default true,
  weekly_reports boolean not null default false,
  two_factor_auth boolean not null default false,
  login_alerts boolean not null default true,
  session_timeout boolean not null default true
);

alter table public.admin_preferences enable row level security;
revoke all on public.admin_preferences from public, anon, authenticated;
grant select, insert, update on public.admin_preferences to authenticated;

create policy own_admin_preferences on public.admin_preferences
  for all to authenticated
  using (uid = auth.uid() and cots_private.has_role('administrator'))
  with check (uid = auth.uid() and cots_private.has_role('administrator'));
create policy trusted_session_required on public.admin_preferences as restrictive
  for all to authenticated
  using (cots_private.session_is_trusted())
  with check (cots_private.session_is_trusted());

commit;
