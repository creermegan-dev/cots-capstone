# Supabase Step 1: database and security foundation

## Scope and execution status

This is a fresh backend foundation, not a Firebase data migration. The existing
Flutter application, Firebase project/configuration, model asset, packages and
navigation remain unchanged. No hosted resource, Storage bucket or real account
has been created. The three migrations are now applied to the empty hosted
`cots-monitor` test project. No Storage bucket or real account was created.
Production migrations contain no synthetic users, monitoring records, images or
assessments. Only the singleton setup-state row is seeded.

Initial branch: `feature/follow-up-reassignment`. Initial working tree: clean.
No commit, merge, push or branch deletion is part of this work.

The pinned Supabase CLI `2.121.0` was run through `npx`; Docker, WSL and `psql`
remain unavailable. The hosted test project runs PostgreSQL 17.6, while the local
Supabase configuration targets PostgreSQL 15. The three migrations applied without
error. This validates the hosted schema and database authorization tests described
below, but it is not production, device, Storage or Flutter integration verification.

Checks actually executed for this delivery:

| Check | Result |
| --- | --- |
| `node scripts/check_supabase_step1.mjs` | 10 static source-contract checks passed |
| `node --check scripts/test_supabase_concurrency.mjs` | JavaScript syntax passed |
| PowerShell parser on `test_supabase_local.ps1` | Syntax passed |
| `git diff --check` / `git diff --exit-code` | No tracked edits or whitespace errors |
| `scripts/test_supabase_local.ps1` | Stopped before database access: CLI unavailable |
| Hosted migration push | All three migrations applied successfully |
| Hosted migration history | Local and remote versions match: `20261016000100`, `20261016000200`, `20261016000300` |
| Hosted pgTAP suite | 82/82 assertions passed; `finish()` returned `1..82` with no failure diagnostics |
| Hosted two-session concurrency suite | Administrator and Expert races passed; each produced one success and one SQLSTATE 23505 rejection |
| Concurrency cleanup | 0 Auth users, 0 profiles, 0 privileged slots; setup remains unsealed; two immutable test audit events retained |
| Flutter, device, Auth HTTP and Storage integration | Not run; no application source changed |

The database tests establish the checked SQL, RLS and initial-role race behavior on
the empty hosted test project. They do not establish live Auth client behavior,
Storage security, offline synchronization, image verification, device behavior or
compatibility with all future PostgreSQL/Supabase versions.

## Inspected existing contracts

- `UserModel`: user/expert/admin roles; active status and independent personnel
  verification. Signup job title is not an authorization role.
- Firebase collections: captures, individual detection payloads, removal records,
  image documents, profiles, Follow-up assignments/surveys, monthly authorizations,
  reassignment requests/events, eligible-personnel directory and notifications.
- `FollowUpWorkflowStore`: optimistic Firestore commits and revision-based
  reassignment. Replacement acceptance is separate from survey completion.
- Philippine calendar months; no fixed monitoring dates or removal scheduling.
- Per-item rounded confidence: 80–100 auto accepted; 20–79 requires individual
  Expert decisions; below 20 is not counted as an accepted COTS.
- Source-normalized boxes, ONNX model provenance and surface GPS. Existing image
  storage includes base64 Firestore documents; PostgreSQL stores metadata only.
- Windows currently has separate Firebase REST services; none is replaced here.
- New records must not inherit existing simulated GIS metrics or synthetic boxes.

## Schema and relationships

`20261016000100_foundation.sql` creates 23 application tables:

| Group | Tables |
| --- | --- |
| Identity | profiles, privileged_role_slots, setup_state |
| Geography/detection | monitoring_areas, captures, detection_items |
| Field activity | eliminations, follow_up_surveys |
| Images | media_assets, media_variants, capture_evidence, elimination_evidence, survey_evidence |
| Expert review | expert_decisions, infestation_assessments |
| Responsibility | follow_up_assignments, monthly_authorizations, reassignment_requests, replacement_proposals |
| History/delivery/recovery | workflow_events, notifications, audit_events, recovery_requests |

Auth UUIDs reference `auth.users`; restrictive deletion protects historical
actors. A signup trigger creates an ordinary profile and ignores all client role,
active and verification metadata. No Auth passwords/hashes are stored here.

UUID primary keys, owner/idempotency uniqueness and immutable inputs support
future offline retries. A collision must be fetched and compared with the local
manifest, never overwritten with an upsert. Different visits have different UUIDs
even in the same month. Dates captured in the field are distinct from database
submission times. Capture metadata includes model hash, source dimensions,
orientation-normalized box space, timestamp source, GPS source/accuracy/time and
surface-reference status. EXIF text/timezone uncertainty can be retained.

Indexes cover owner/date, area/date, review queue, capture links, assignment/month,
current authorizations, replacement state, evidence relationships, decisions,
unread notifications, assessments, recovery history and audit targets.

## Authorization boundary

`20261016000200_security.sql` enables RLS on every application table and revokes
ordinary table privileges before adding explicit policies and column grants.

- Clients may insert their own immutable pending capture/survey/elimination/media
  inputs after field verification; they cannot insert server lifecycle fields.
- Clients cannot update ownership, timestamps, model results, authorization,
  account status, verification, image verification or completion.
- Profiles expose full personal information only to the owner and Administrator.
  `eligible_personnel()` returns UUID and name to staff, not email or phone.
- Area/assignment access is evaluated from the primary diver or effective current
  accepted replacement. A pending/declined/expired proposal conveys no area or
  evidence access. A former replacement retains their own records, not continued
  access to other people's area records.
- Evidence access follows the authorized linked record. Unlinked uploads are
  private to the owner. No bucket or `storage.objects` policy exists yet.
- Audit, Expert decisions, assessments and workflow history are append-only;
  permanent assignments cannot be rewritten. Row and truncate triggers protect
  history even from accidental trusted DML (database owners can still alter DDL).
- Security-definer functions pin an empty search path, qualify application names,
  derive authenticated actors from `auth.uid()` and revoke PUBLIC execution.
- No Flutter administrative key or public provisioning endpoint is introduced.

### Privileged role setup

Role primary-key uniqueness allows at most one Administrator and one Expert.
Unique occupants require distinct identities. Setup operations serialize on the
singleton row; `complete_initial_setup()` requires both active identities. Once
sealed, slots cannot be changed/deleted, and setup cannot be reopened. Recovery
restores the existing identity rather than replacing a slot.

`appoint_initial_role()` and `complete_initial_setup()` are granted only to the
trusted `service_role` database role (and remain callable by the migration owner).
Authenticated app users cannot invoke them. Table constraints/locks also apply to
trusted inserts; role uniqueness is not a client-side check.

### Function allowlist

| Caller | Operations |
| --- | --- |
| Authenticated, with internal actor checks | request/propose/respond/close reassignment; link evidence; record Expert decisions/assessments; mark own notification read; request/approve supervised recovery |
| Administrator checked in PostgreSQL | verify/unverify or deactivate ordinary personnel; approve ordinary/Expert recovery |
| Staff checked in PostgreSQL | minimal eligible directory |
| Trusted backend only | initial role appointment/setup; record verified-media receipt; finalize capture/survey/elimination |

Profile self-edit grants cover only full name, organization, job title and phone.
All workflow updates go through allowlisted operations. No direct client DELETE,
history mutation or notification creation permission exists.

## Original diver and late offline policy

The first qualifying **server-finalized** detection establishes the permanent
primary diver. The finalizer locks the monitoring area to serialize simultaneous
first detections. It derives ownership from the capture, requires a verified
evidence link, and applies the per-COTS policy. Corrected totals must match
individual decisions. Zero accepted COTS never establishes an assignment or
declares clearance.

An earlier field timestamp arriving later is retained with
`origin_review_required=true` and an audit event. Primary ownership does not
change. Step 1 deliberately supplies no primary-owner override RPC; an exceptional
correction process requires separate review/approval rather than silently changing
existing responsibility. Device timestamps and client AI data are not independently
proven by SQL; the future trusted worker must validate its inputs.

Surveys derive their month from `captured_at AT TIME ZONE 'Asia/Manila'`. Pending
offline work can be preserved even when the actor's cached assignment is stale.
The finalizer locks the assignment/month and checks current persisted authority,
revision, eligibility and verified evidence. Conflicts become
`pending_authorization_review` and cannot be bypassed by Expert late approval.

The proposed seven-day month-end grace period is implemented as review routing,
not a visit deadline: submission at/after local midnight on the eighth day of the
next month requires late review. Original submission time is preserved on retries.
An Expert's `accept_late` decision allows finalization only if all authorization
and evidence checks still pass. Rejected/nonqualifying work may remain
`historical_only`; original inputs are not erased. Future-dated work is held for
authorization review rather than completed. The grace period is a documented
policy default to confirm before hosted rollout.

## Monthly reassignment

All transitions lock the same assignment/month before requests/proposals. The
responsible eligible diver requests unavailability; only the Expert nominates an
eligible, different diver. Proposals expire after at most two days or month-end.
Only the nominee may accept/decline while eligible, current and revision-matched.
Acceptance atomically changes only that month's responsibility, appends an event
and creates notifications. Duplicate acceptance is rejected. Decline/cancellation
retains history; the Expert can close an expired pending proposal before another
nomination. A completed month cannot be reassigned.

Every month defaults to the permanent primary unless separately reassigned. No
cron reset or fixed visit date is required. Acceptance never completes a survey;
multiple survey visits remain separate records.

## Evidence verification: intentionally incomplete integration

Original hashes/references and raw/oriented dimensions are distinct from variant
hashes/dimensions. JPEG is the initial default, with format/MIME metadata ready for
future formats. Intended initial quality experiment: long edge 2048, JPEG 85; this
is not implemented or asserted as image-quality validated here. Original files,
compression, local backups and SQLite queue remain later stages.

`record_verified_media()` accepts a matching trusted receipt, not an ordinary
client assertion. **It does not inspect Storage bytes itself.** No caller should
receive trusted credentials just to invoke it. A future restricted worker must
download and decode actual bytes, check type, dimensions, hash, reservation,
ownership and immutable object identity before issuing a receipt. Clients cannot
set uploaded/verified fields. Thumbnail-only evidence cannot finalize activity.

Buckets, private object policies, byte inspection and Storage-vs-database race
tests are mandatory before real uploads. An object must not be replaceable or
deletable after verification. SQL metadata receipts alone are not end-to-end proof
of real image evidence, scene truth, capture date or original GPS.

## Running checks later

The hosted verification used pinned CLI `2.121.0`. `db push --dry-run` listed only
the three expected migrations; the approved push applied them, and `migration list
--linked` showed matching local and remote versions. The pgTAP file ran through
`db query --linked`; its transaction rolled back all fixtures. A temporary
cloud-only two-session harness raced the initial Administrator and Expert
appointments. Each race produced exactly one committed slot and one SQLSTATE
23505 rejection. The fixed synthetic Auth/profile/slot rows were removed afterward.
The append-only audit design intentionally retained two `initial_role_appointed`
events. The temporary harness was removed and was not added to the repository.

Read-only source checks available without a database:

```powershell
node scripts/check_supabase_step1.mjs
node --check scripts/test_supabase_concurrency.mjs
```

With an approved isolated local stack, these migrations applied and pgTAP
available, run:

```powershell
./scripts/test_supabase_local.ps1
```

The wrapper explicitly selects local; it does not start/reset a database or link
to a project. pgTAP creates only `example.invalid` synthetic Auth identities and
rolls its entire fixture transaction back. It assumes no real accounts/privileged
slots exist in the test stack. Run before real local account setup.

The separate two-session test requires `psql`, a fresh disposable stack at
127.0.0.1:54322 and any necessary password supplied privately through a local
password file, never chat/arguments. It refuses nonempty profiles or sealed setup.

```powershell
node scripts/test_supabase_concurrency.mjs --disposable-local
```

It runs simultaneous appointments for each privileged role and expects exactly
one success plus SQLSTATE 23505. It commits synthetic fixtures to exercise a real
unique-index race, then removes only its fixed synthetic role/profile/Auth rows;
audit history remains. It never drops/resets a database or touches hosted data.
Do not run it against valuable local data, a forwarded remote database or after
real account setup. Review retained fixtures if the runner is interrupted.

## Deployment gates and Step 2

Before application integration: run SQL lint; test actual Auth signup and grants;
review functions/EXPLAIN query plans; complete private Storage/worker integration;
validate image quality; test offline/device integration in later stages; verify
Free capacity and separate database/object backups and restore; obtain deployment
approval. Local confirmation settings do not change any hosted Auth settings.

Step 2 proposal: connect an isolated Supabase Auth adapter only after approval,
with a local setup interface using masked identifier/password inputs. You privately
choose different passwords for the two separate accounts. No generated passwords,
logs, command-line passwords, committed secrets or chat credentials. A trusted
server/owner operation creates Auth identities with confirmation bypass, appoints
the two slots and seals setup. Interrupted setup reconciles existing identities;
it must not create duplicates or automatically delete accounts.

Ordinary/Expert recovery is supervised by the Administrator. Administrator recovery
uses an independent project-owner tool, protected owner access and identity checks.
The `recovery_requests` table stores only approvals/reference IDs, never tokens.
Signed-out request intake, independent-owner approval, Auth password reset,
one-time delivery, expiry/consumption and session revocation are **not implemented**
in Step 1. Do not infer that recovery is functional from its metadata tables.

Stop after Step 1. No account creation, Flutter service replacement, hosted
configuration, Firebase retirement or deployment is authorized by this stage.
