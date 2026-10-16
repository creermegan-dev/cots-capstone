**Step 2 implementation report**

The approved Follow-up Reassignment and Expert Approval workflow is implemented locally. Existing Step 1 work was extended in place. Unrelated uncommitted changes were retained. No Firebase deployment, production database operation, application publication, dependency upgrade, or historical detection/elimination migration was performed.

**Completed behavior**

- The responsible diver can submit an Unavailable This Month request with a required reason. The form displays the signed-in diver, monitoring area, and current Philippine calendar month.
- A deterministic area/month request ID prevents duplicate pending requests. The original primary assignment remains immutable. If an accepted replacement later becomes unavailable, that currently responsible diver can request another replacement; the previous acceptance and responsibility remain effective until another proposal is accepted.
- The Expert workspace now has Verification and Reassignments tabs. Reassignments displays the zone, barangay, original diver, month, reason, request date, status, last valid monitoring date, separate monitoring completion state, and available validated infestation assessment.
- Experts select from the minimal eligible personnel directory and confirm a proposal before it is sent. They can cancel a pending proposal and select another diver, or cancel a pending request.
- A proposed diver can accept or decline through the existing Notifications page. Acceptance activates the month-specific responsibility. Decline records an immutable Declined event and returns the request to Replacement Needed.
- Accepted replacement areas appear in the replacement diver's Follow-up page with Temporary Assignment, the monitoring month, and original diver. The primary diver continues to see the area but cannot start that month's survey while another diver is responsible.
- Survey capture and final submission authorization use the survey month. Evidence and surveys retain the actual submitting diver's identity. Replacement eligibility is checked again by Firestore when evidence/surveys are submitted.
- The next calendar month defaults to the original primary diver unless that month has its own accepted reassignment. No expiration job or fixed visit date is needed.
- Acceptance never implies completed monitoring. Existing linked-capture validation determines Monitored / Follow-up Completed. An unfinished past month remains Not Recorded.
- Request, proposal, acceptance, decline, pending proposal cancellation, and request cancellation notifications are written atomically with the state change and immutable audit event. Deterministic notification IDs and revision/update-time checks prevent duplicates and conflicting transitions.
- Experts have a shared in-app workflow inbox. The authorizing Expert's UID is preserved in every proposal snapshot, and every response retains its actor and server timestamp.
- Infestation labels use only explicit Expert-validated assessment records. High assessments display a textual High-risk area label and danger color. Missing assessments display Not available; detection counts and confidence do not determine risk.

**Authorization and data changes**

| Collection | Purpose and protection |
| --- | --- |
| `follow_up_reassignments/{area_year_month}` | Canonical monthly request, current responsible diver, primary identity, proposed replacement, authorizing Expert, reason, participants, revision and server timestamps. Participants/Experts can read; role-checked transitions require matching audit and notification writes. |
| `follow_up_month_authorizations/{area_year_month}` | Effective monthly responsibility. Initialized for the primary diver before survey evidence is saved and synchronized atomically with reassignment decisions. Keeps eight-image surveys within Firestore rule read limits. |
| `follow_up_reassignment_events/{request_revision}` | Immutable full state snapshots, action, actor and timestamp. Participants can inspect the complete request history. |
| `follow_up_personnel/{uid}` | Admin-published name and eligibility only. Experts can query eligible entries; private user profiles remain inaccessible. Ineligible entries are removed during directory publication. |
| `follow_up_assessments/{id}` | Optional immutable, Expert-authored infestation assessments linked to an existing survey and its area/date. Historical survey fields are not rewritten. |
| Existing `notifications` | Adds `follow_up_reassignment` events and `event_revision`, with deterministic IDs and recipient checks. |
| Existing `captures` | Adds optional `follow_up_year` and `follow_up_month` for survey evidence. Ordinary detections and elimination workflows retain their existing behavior. |

Replacement eligibility uses the existing authoritative profile attributes: `accountRole == user`, `isActive == true`, and `fieldPersonnelVerified == true`. Job titles are not treated as authorization. Only active Experts approve proposals; only the proposed diver responds. Primary assignment updates/deletes and survey history updates/deletes remain forbidden. The rules reject forged calendar-date/month combinations and cross-month evidence linkage.

No index or Storage rule changes were needed. Queries use single-field indexes and client-side sorting. The new workflow uses authenticated Firestore REST commits on both native Firebase sessions and Windows REST sessions; existing native/Windows survey persistence paths remain in use.

**Files changed for Step 2**

This list identifies this implementation's edits, rather than attributing every existing working-tree change to Step 2.

| File | Change |
| --- | --- |
| `firebase/firestore.rules` | Monthly authorization, state transitions, immutable events, minimal directory, notifications, assessment protections and survey checks. |
| `lib/models/follow_up_reassignment.dart` | Reassignment state and Philippine calendar-month identity. New. |
| `lib/models/follow_up_infestation_assessment.dart` | Explicit validated assessment parser. New. |
| `lib/models/follow_up_monitoring_model.dart` | Consistent Philippine survey calendar-day timestamp serialization. |
| `lib/services/follow_up_workflow_store.dart` | Authenticated REST queries and atomic writes with update-time preconditions and server timestamps. New. |
| `lib/services/follow_up_reassignment_repository.dart` | Requests, proposals, responses, cancellations, history, directory publication, assessment reads and deduplicated notifications. New. |
| `lib/services/follow_up_monitoring_repository.dart` | Replacement assignments, shared area monitoring history and monthly submission authorization. |
| `lib/services/capture_service.dart` | Native evidence month metadata and retry consistency. |
| `lib/services/windows_capture_rest_service.dart` | Matching Windows evidence metadata and retry checks. |
| `lib/services/scan_record_service.dart` | Passes follow-up calendar date to evidence persistence. |
| `lib/widgets/follow_up_reassignment_controls.dart` | Request form, temporary assignment controls, accept/decline, Expert proposal dialogs, audit history and validated risk display. New. |
| `lib/features/user/follow_up_page.dart` | Monthly responsibility controls, temporary areas, cross-diver monitoring history and assessment display. |
| `lib/features/user/scan_detection_page.dart` | Responsible-diver checks, monthly authorization initialization and evidence date propagation. |
| `lib/features/user/notifications_screen.dart` | Opens actionable reassignment details with error handling. |
| `lib/features/expert/screens/expert_shell_screen.dart` | Adds Reassignments navigation while preserving verification. |
| `lib/features/expert/screens/expert_reassignments_screen.dart` | Expert request queue, oversight, history filter and workflow inbox. New. |
| `lib/features/admin/screens/admin_users_screen.dart` | Explicit initial directory publication and directory refresh following field verification changes. |
| `test/follow_up_reassignment_test.dart` | Calendar, repository, completion, form, proposal, acceptance, visibility and responsive widget tests. New. |
| `test/firestore_reassignment_rules_test.cjs` | Isolated local emulator workflow/privacy/concurrency/security assertions. New. |
| `test/firestore_follow_up_rules_test.cjs` | Extends the existing Step 1 fixtures with monthly authorization records. |
| `test/follow_up_capture_retry_test.dart` | Verifies Windows month metadata and rejects a changed-month retry. |
| `STEP2_IMPLEMENTATION_REPORT.md` | This report. New. |

**Validation results**

| Check | Result |
| --- | --- |
| Full `flutter test --no-pub` | **41 tests passed.** |
| `node test/firestore_reassignment_rules_test.cjs` | **88 local emulator assertions passed**, using the October 2026 calendar month. |
| `node test/firestore_follow_up_rules_test.cjs` | **24 Step 1 security checks passed**, including eight images, immutable records and existing detection/elimination paths. |
| `flutter analyze --no-pub` | Completed with **0 errors, 8 warnings and 108 informational findings** in existing code. Nonzero exit reflects these remaining repository findings. No findings remain in the new reassignment files/tests. |
| Dart formatting | Changed Dart files formatted. |
| `git diff --check` | No whitespace errors. |

Flutter commands were run using the installed SDK's `dart.exe flutter_tools.snapshot` entry point because the batch wrappers stalled in this environment. Analysis and tests required access to the SDK cache outside the workspace. They were not replaced by live Firebase testing.

The requested A → Expert → B October scenario was verified across repository, widget and local security-rule tests: request, notification, proposal confirmation, inactive proposal before acceptance, acceptance, Follow-up assignment visibility, B-owned survey submission, valid October completion, and November fallback to A. Additional coverage includes decline/re-proposal, cancellation, concurrent proposal races, duplicate requests, stale responses, revoked eligibility, unauthorized responses, restricted profile/directory access, immutable history, forged months, missing evidence and eight-image submissions. Layout tests cover 360- and 1100-pixel controls with enlarged text and a narrow Expert proposal dialog; existing navigation tests cover 320/768 widths and 1x/2x text.

The rules were tested only against Firestore emulator project `demo-cots-follow-up` on `127.0.0.1:8088`. To repeat them, start the cached Firestore emulator JAR with `--host 127.0.0.1 --port 8088 --project_id demo-cots-follow-up --rules firebase/firestore.rules`, then run the two Node scripts above. The Step 2 script reloads local rules and creates uniquely named emulator-only fixtures.

**Remaining setup and verification limits**

- Firebase rules are prepared locally but **not deployed**. Deploying the matching rules requires separate approval before using Step 2 against the live backend. Existing eligible users must be published through the administrator's Publish follow-up personnel directory button; no live backfill was run.
- Explicit assessment records are supported and protected, but Step 2 does not add a separate infestation-assessment authoring screen. Existing areas without such records show Not available. No risk values were invented or migrated from counts.
- Request and joined assignment lists refresh on a 15-second polling interval. The Expert inbox is shared; it does not add per-Expert read receipts or external push delivery.
- Completion remains derived from valid survey evidence rather than a stored reassignment status. No separate completion notification was added; Expert monitoring summaries expose the completion state.
- Physical native/Windows application runs, real authentication delivery, photo inference/upload through a device, and a complete UI-to-live-Firebase end-to-end run were not performed. Passing unit/widget/emulator tests does not establish deployed end-to-end functionality.
- Existing analyzer warnings and style/deprecation notices were left outside this feature's scope. The full analyzer output is in `.dart_tool/step2_flutter_analyze_final.log`.
