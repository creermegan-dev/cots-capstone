-- Fresh database only. No production users, monitoring seeds, buckets or Firebase operations.
begin;
create schema if not exists cots_private;
revoke all on schema cots_private from public;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  full_name text not null default '' check (length(full_name) <= 200),
  organization text not null default '',
  job_title text not null default '',
  phone text not null default '',
  active boolean not null default true,
  field_verified boolean not null default false,
  verified_by uuid references public.profiles(id),
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  check (not field_verified or (verified_by is not null and verified_at is not null))
);
create table public.setup_state (
  singleton boolean primary key default true check (singleton),
  completed_at timestamptz
);
insert into public.setup_state(singleton) values (true);
create table public.privileged_role_slots (
  role text primary key check (role in ('administrator','expert')),
  user_id uuid not null unique references public.profiles(id) on delete restrict,
  appointed_at timestamptz not null default now()
);
create table public.monitoring_areas (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  municipality text not null default '',
  barangay text not null default '',
  geography_version text not null,
  geographic_reference jsonb not null default '{}'::jsonb,
  approximate_boundary boolean not null default true,
  active boolean not null default true
);
create table public.captures (
  id uuid primary key,
  owner_id uuid not null references public.profiles(id),
  idempotency_key uuid not null,
  area_id uuid not null references public.monitoring_areas(id),
  captured_at timestamptz not null,
  capture_time_source text not null check (capture_time_source in ('exif','device','manual')),
  original_time_text text,
  timezone_assumed boolean not null default false,
  submitted_at timestamptz not null default now(),
  model_name text not null,
  model_sha256 text not null check (model_sha256 ~ '^[0-9a-f]{64}$'),
  source_width integer not null check (source_width > 0),
  source_height integer not null check (source_height > 0),
  coordinate_space text not null default 'orientation_normalized_source'
    check (coordinate_space = 'orientation_normalized_source'),
  latitude numeric check (latitude between -90 and 90),
  longitude numeric check (longitude between -180 and 180),
  gps_source text not null check (gps_source in ('exif','device_surface','manual_surface','unavailable')),
  gps_accuracy_m numeric check (gps_accuracy_m >= 0),
  gps_captured_at timestamptz,
  surface_reference boolean not null default true check (surface_reference),
  notes text not null default '',
  status text not null default 'pending' check (status in ('pending','finalized','rejected')),
  finalized_at timestamptz,
  origin_review_required boolean not null default false,
  unique(owner_id, idempotency_key),
  check ((latitude is null) = (longitude is null)),
  check ((gps_source = 'unavailable') = (latitude is null)),
  check ((status = 'finalized') = (finalized_at is not null))
);
create table public.detection_items (
  id uuid primary key,
  capture_id uuid not null references public.captures(id),
  item_index integer not null check (item_index >= 0),
  confidence numeric not null check (confidence between 0 and 1),
  x1 numeric not null check (x1 >= 0), y1 numeric not null check (y1 >= 0),
  x2 numeric not null, y2 numeric not null,
  estimated_size_cm numeric check (estimated_size_cm > 0),
  unique(capture_id,item_index),
  check (x2 > x1 and y2 > y1)
);
create table public.follow_up_assignments (
  id uuid primary key default gen_random_uuid(),
  area_id uuid not null unique references public.monitoring_areas(id),
  primary_diver_id uuid not null references public.profiles(id),
  originating_capture_id uuid not null unique references public.captures(id),
  established_at timestamptz not null default now()
);
create table public.monthly_authorizations (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.follow_up_assignments(id),
  month date not null check (extract(day from month) = 1),
  responsible_diver_id uuid not null references public.profiles(id),
  revision integer not null default 0 check (revision >= 0),
  updated_at timestamptz not null default now(),
  unique(assignment_id,month)
);
create table public.follow_up_surveys (
  id uuid primary key,
  owner_id uuid not null references public.profiles(id),
  idempotency_key uuid not null,
  assignment_id uuid not null references public.follow_up_assignments(id),
  captured_at timestamptz not null,
  month date not null check (extract(day from month) = 1),
  submitted_at timestamptz not null default now(),
  authorization_revision integer not null check (authorization_revision >= 0),
  latitude numeric check (latitude between -90 and 90),
  longitude numeric check (longitude between -180 and 180),
  gps_source text not null check (gps_source in ('exif','device_surface','manual_surface','unavailable')),
  gps_accuracy_m numeric check (gps_accuracy_m >= 0),
  gps_captured_at timestamptz,
  surface_reference boolean not null default true check (surface_reference),
  observed_count integer not null default 0 check (observed_count >= 0),
  notes text not null default '',
  status text not null default 'pending' check
    (status in ('pending','pending_late_review','pending_authorization_review','completed','historical_only')),
  completed_at timestamptz,
  unique(owner_id,idempotency_key),
  check (month = date_trunc('month',captured_at at time zone 'Asia/Manila')::date),
  check ((latitude is null) = (longitude is null)),
  check ((gps_source = 'unavailable') = (latitude is null)),
  check ((status = 'completed') = (completed_at is not null))
);
create table public.eliminations (
  id uuid primary key,
  owner_id uuid not null references public.profiles(id),
  idempotency_key uuid not null,
  capture_id uuid not null references public.captures(id),
  survey_id uuid references public.follow_up_surveys(id),
  captured_at timestamptz not null,
  submitted_at timestamptz not null default now(),
  removed_count integer not null check (removed_count >= 0),
  method text not null default '', notes text not null default '',
  latitude numeric check (latitude between -90 and 90),
  longitude numeric check (longitude between -180 and 180),
  gps_source text not null check (gps_source in ('exif','device_surface','manual_surface','unavailable')),
  gps_accuracy_m numeric check (gps_accuracy_m >= 0), gps_captured_at timestamptz,
  surface_reference boolean not null default true check (surface_reference),
  status text not null default 'pending' check (status in ('pending','finalized')),
  unique(owner_id,idempotency_key),
  check ((latitude is null) = (longitude is null)),
  check ((gps_source = 'unavailable') = (latitude is null))
);
create table public.media_assets (
  id uuid primary key,
  owner_id uuid not null references public.profiles(id),
  idempotency_key uuid not null,
  original_name text not null,
  original_sha256 text not null check (original_sha256 ~ '^[0-9a-f]{64}$'),
  original_bytes bigint not null check (original_bytes > 0),
  raw_width integer not null check (raw_width > 0), raw_height integer not null check (raw_height > 0),
  source_width integer not null check (source_width > 0), source_height integer not null check (source_height > 0),
  exif_orientation integer check (exif_orientation between 1 and 8),
  captured_at timestamptz not null,
  capture_time_source text not null check (capture_time_source in ('exif','device','manual')),
  original_time_text text, timezone_assumed boolean not null default false,
  created_at timestamptz not null default now(),
  unique(owner_id,idempotency_key)
);
create table public.media_variants (
  id uuid primary key,
  asset_id uuid not null references public.media_assets(id),
  kind text not null check (kind in ('evidence','thumbnail','supplement')),
  version integer not null check (version > 0),
  bucket text not null check (bucket in ('detection-evidence','elimination-evidence')),
  object_path text not null check (object_path <> '' and object_path !~ '(^/|\.\.)'),
  format text not null default 'jpeg', mime_type text not null default 'image/jpeg',
  width integer not null check (width > 0), height integer not null check (height > 0),
  byte_size bigint not null check (byte_size > 0),
  sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  encoder text not null, encoder_settings jsonb not null default '{}'::jsonb,
  upload_status text not null default 'reserved' check (upload_status in ('reserved','uploaded','verified','failed')),
  uploaded_at timestamptz, verified_at timestamptz,
  verification_receipt text,
  unique(bucket,object_path), unique(asset_id,kind,version),
  check ((format = 'jpeg' and mime_type = 'image/jpeg') or (format = 'webp' and mime_type = 'image/webp')),
  check (upload_status <> 'verified' or (verified_at is not null and uploaded_at is not null and verification_receipt is not null))
);
create table public.capture_evidence (
  capture_id uuid not null references public.captures(id),
  variant_id uuid not null references public.media_variants(id),
  primary key(capture_id,variant_id)
);
create table public.elimination_evidence (
  elimination_id uuid not null references public.eliminations(id),
  variant_id uuid not null references public.media_variants(id),
  primary key(elimination_id,variant_id)
);
create table public.survey_evidence (
  survey_id uuid not null references public.follow_up_surveys(id),
  variant_id uuid not null references public.media_variants(id),
  primary key(survey_id,variant_id)
);
create table public.expert_decisions (
  id uuid primary key default gen_random_uuid(),
  decision_sequence bigint generated always as identity unique,
  capture_id uuid references public.captures(id),
  survey_id uuid references public.follow_up_surveys(id),
  expert_id uuid not null references public.profiles(id),
  decision text not null check (decision in ('approve','correct','reject','accept_late','historical_only')),
  reason text not null check (length(trim(reason)) between 1 and 2000),
  corrected_count integer check (corrected_count >= 0),
  item_decisions jsonb not null default '[]'::jsonb check (jsonb_typeof(item_decisions) = 'array'),
  decided_at timestamptz not null default now(),
  check (num_nonnulls(capture_id,survey_id) = 1),
  check ((decision = 'correct') = (corrected_count is not null))
);
create table public.reassignment_requests (
  id uuid primary key default gen_random_uuid(),
  authorization_id uuid not null references public.monthly_authorizations(id),
  requester_id uuid not null references public.profiles(id),
  reason text not null check (length(trim(reason)) between 1 and 2000),
  status text not null default 'requested' check
    (status in ('requested','awaiting_acceptance','replacement_needed','accepted','cancelled')),
  revision integer not null default 0 check (revision >= 0),
  requested_at timestamptz not null default now()
);
create unique index one_open_reassignment on public.reassignment_requests(authorization_id)
  where status in ('requested','awaiting_acceptance','replacement_needed');
create table public.replacement_proposals (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.reassignment_requests(id),
  expert_id uuid not null references public.profiles(id),
  replacement_id uuid not null references public.profiles(id),
  status text not null default 'pending' check (status in ('pending','accepted','declined','expired','cancelled')),
  request_revision integer not null,
  authorization_revision integer not null,
  expires_at timestamptz not null,
  proposed_at timestamptz not null default now(), responded_at timestamptz,
  check (expires_at > proposed_at)
);
create unique index one_pending_proposal on public.replacement_proposals(request_id) where status = 'pending';
create table public.workflow_events (
  id uuid primary key default gen_random_uuid(),
  request_id uuid references public.reassignment_requests(id),
  survey_id uuid references public.follow_up_surveys(id),
  actor_id uuid references public.profiles(id),
  action text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id),
  event_id uuid not null references public.workflow_events(id),
  read_at timestamptz,
  created_at timestamptz not null default now(),
  unique(recipient_id,event_id)
);
create table public.infestation_assessments (
  id uuid primary key default gen_random_uuid(),
  survey_id uuid not null references public.follow_up_surveys(id),
  expert_id uuid not null references public.profiles(id),
  level text not null check (level in ('Low','Moderate','High')),
  method text not null check (length(trim(method)) > 0),
  rationale text not null check (length(trim(rationale)) > 0),
  assessed_at timestamptz not null default now()
);
create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id),
  action text not null, target_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table public.recovery_requests (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.profiles(id),
  approved_by uuid references public.profiles(id),
  status text not null default 'requested' check (status in ('requested','approved','consumed','denied','expired')),
  verification_reference text,
  independent_owner_recovery boolean not null default false,
  expires_at timestamptz,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  check (status <> 'approved' or (expires_at is not null and verification_reference is not null)),
  check ((status = 'consumed') = (consumed_at is not null))
);

create index captures_owner_date on public.captures(owner_id,captured_at desc);
create index captures_area_date on public.captures(area_id,captured_at desc);
create index captures_review on public.captures(status,submitted_at);
create index surveys_assignment_month on public.follow_up_surveys(assignment_id,month,captured_at);
create index surveys_owner_date on public.follow_up_surveys(owner_id,captured_at desc);
create index eliminations_capture on public.eliminations(capture_id);
create index eliminations_owner_date on public.eliminations(owner_id,captured_at desc);
create index assignments_primary on public.follow_up_assignments(primary_diver_id);
create index authorizations_diver on public.monthly_authorizations(responsible_diver_id,month);
create index proposals_diver on public.replacement_proposals(replacement_id,status);
create index media_owner on public.media_assets(owner_id);
create index capture_evidence_variant on public.capture_evidence(variant_id);
create index elimination_evidence_variant on public.elimination_evidence(variant_id);
create index survey_evidence_variant on public.survey_evidence(variant_id);
create index decisions_capture on public.expert_decisions(capture_id,decision_sequence desc);
create index decisions_survey on public.expert_decisions(survey_id,decision_sequence desc);
create index events_request on public.workflow_events(request_id,created_at);
create index notifications_inbox on public.notifications(recipient_id,created_at desc) where read_at is null;
create index assessments_survey on public.infestation_assessments(survey_id,assessed_at desc);
create index audit_target on public.audit_events(target_id,created_at);
create index recovery_subject on public.recovery_requests(subject_id,created_at);
commit;
