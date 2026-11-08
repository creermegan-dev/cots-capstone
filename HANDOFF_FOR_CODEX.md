# COTS Monitor: handoff for Codex (as of 2026-11-05 11:50 Philippine time)

Read this whole file before changing anything. It replaces the 2026-11-01 version
(old copy: `.backup_before_codex_handoff_2026-11-05/HANDOFF_FOR_CODEX.md`, which still
has useful detail on Stages 1-7).

## 1. The project

Flutter capstone app for monitoring crown-of-thorns starfish (COTS) at 3 dive sites in
Samal. Roles: Administrator, Expert, Diver. A Diver photographs COTS, an on-phone AI
counts them, the Expert reviews. Backend: hosted Supabase (ref `kgfehorbjzhooxnnkfac`).
Firebase is kept only as a rollback (`--dart-define=USE_FIREBASE=true`); Supabase is the default.

- PC folder: `C:\dev\Capstone Flutter`, git branch `supabase-migration` (local only).
- Last commit: `939e060` (Stage 7). **Everything after it is uncommitted** (Stages 8-11, 13,
  practice sites). The user said "not yet" to committing.
- Live on hosted: every migration up to `20261105000400_practice_sites.sql`.
- Latest APK: built 2026-11-05 11:46 from the current code (316 tests passed).

## 2. Rules the user set (follow exactly)

1. Budget is zero. Free tools only; never make a paid service a requirement without free alternatives.
2. Never expose credentials or put privileged keys (service role, Firebase admin) in the app.
3. Do not delete data, reset databases, remove existing work, deploy, or commit/push without the user's OK.
4. Keep Firebase rollback until the Supabase move is validated.
5. Do not expand scope. Label optional ideas separately.
6. Back up every file before changing it (`.backup_before_<name>_<date>` folders).
7. Test database changes on a LOCAL copy first. Never reset or run destructive fixtures on hosted.
8. Before any hosted change: show the dry run and wait for the user's OK.
9. Do not commit or push unless the user says "commit".
10. Never claim phone/device testing that did not happen.
11. Only one AI tool changes the project at a time (Claude is now stopped).
12. Use the word **"site"** everywhere in the app (not "area"/"zone" in user-facing text).
13. Keep summaries to the user short and plain.

Way of working: plan -> user OK -> backup -> local DB test -> app change -> tests -> dry run ->
user OK -> push -> read-only check -> commit only when told -> update this file.

## 3. Helper scripts (`tool\`, double-click; Supabase CLI 3.0.0 targets LOCAL unless `--remote`)

| Script | What it does |
|---|---|
| `test_only.bat` | app tests only -> `tool\last_test.txt` |
| `test_and_build_apk.bat` | tests, then release APKs (split per ABI) -> `tool\last_build.txt`; phone APK = `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk` |
| `supabase_backup.bat` | dumps hosted schema/data/roles to `backups\<STAMP>_*.sql`; edit STAMP first (last: 2026-11-05_1130); Docker Desktop must run |
| `supabase_dry_run_hosted.bat` | read-only: which migrations would go to hosted |
| `supabase_push.bat` | push to hosted, ONLY after dry run + user OK |
| `supabase_stage9/10/11/13_check.bat` | read-only checks after each stage |
| `supabase_dry_run.bat` | OLD, targets LOCAL - do not use for hosted |

Rename old `tool\last_*.txt` outputs before a new run. Database tests (pgTAP) are in
`supabase/tests/database/` (step1 ... step21). `step3_storage_security` always fails on
plain Postgres (needs Supabase storage) - known.

## 4. What exists now (decided with the user)

**Sites (Stage 9):** S1 "Site 1 · Tambo" 347.8 ha, S2 "Site 2 · Adecor" 339.5 ha, S3 "Site 3 · Linosutan"
105.0 ha; one zone "Samal"; version `cots-samal-sites-v1`; 30 m lookup grid in
`cots_private.area_cells` (x=(lon-125.7)*110582.25626663613, y=(lat-6.6)*110574, cell=30 m,
15 m allowance in `area_at()`). App copy: `assets/map/{parts.json,areas.json,part_outlines.json,lookup.bin}`.
Map source + scripts: `zone_maps\samal_sites\`. Expert confirmed the sites.

**Photo location (Stage 7 + 2026-11-05):** photo GPS first; else the phone's GPS if the photo was
taken within **2 hours**; else refused. Photos outside every site are refused.

**Site partners (Stage 10):** Main Diver 1 = first Diver to record at a site. Main Diver 1 invites
a "site partner" (verified Diver); partner must accept, then Expert approves/declines on the
"Needs your action" card. Partners cannot be removed by Main Diver 1. Table `site_partner_requests`.

**Shared monthly visits (Stage 11):** either main Diver records the monthly visit; both visits
count; month missed only if neither visits. Reminders only on the 1st and 16th (pg_cron
`cots-visit-reminders`). Partner can "Leave site". Main Diver 1 "Hand over this site": with a
partner -> partner takes over at once; without -> Expert offers it to a Diver who accepts/declines.

**Map with real data (Stage 13):** density levels **Low <=15, Moderate 16-100, High >100 COTS/ha**
(`cots_private.density_level`, `lib/models/cots_density.dart`). `public.site_levels_json()` gives each
site's latest Expert-confirmed level. Sites coloured by level (grey = no data), the Diver's own
sites have a dark border + "Your site". Record dots: red = confirmed COTS, orange = waiting.
A Diver sees only their own records; Admin sees all. Sample map data removed.

**Practice sites (TEMPORARY, migration 20261105000400; trip plan: SAMAL_TRIP_PLAN_2026-11-06.md):** P1 "Practice · Home" (75 m around
7.311361,125.690736) and P2 "Practice · DNSC" (200 m around 7.313715,125.670413), zone "Practice".
For rehearsing before the Samal trip on 2026-11-06 (they record a defense video there).
**Remove after the trip** with a NEW migration + new assets/map files (regenerate without P1/P2;
revert step17/step21 tests, area_map_test, zone_directory_test). Practice records must be
deleted first - only with the user's OK, and history tables have immutable triggers
(`immutable_history`) that must be disabled/re-enabled inside the migration as Stage 9 did.

## 5. Open items (ask the user before doing any)

1. After the trip: remove practice sites and practice records (see above).
2. Commit everything when the user says "commit". Leave out: website/, promotional-website/,
   .codex-attachments/, .gps_review_2026-11-03/, data/skills/, analyze_report.txt,
   step6_hosted_result.txt, backups/.
3. Stage 12: phone test of everything + admin desktop layout check on screen.
4. Optional: older database messages still say "area" (e.g. "Area handover requested").
5. Optional: delete 4 orphan photo files in Supabase Storage (user does it).
6. Codex migration `20261102000100_expert_personnel_verification.sql` (only the Expert verifies
   Divers) is live; the user never confirmed it was agreed - ask.
7. Later: Firebase removal; delete old Firebase admin key file (with OK).

## 6. Gotchas

- Every RLS table needs the restrictive policy `trusted_session_required` (step6 test checks it).
- Detection items cannot be added to a finalized capture (insert pending, then finalize).
- `supabase db query --remote` needs `--yes`; `--read-only` cannot call cots_private functions.
- Backups of changed files from recent work: `.backup_before_stage9_samal_2026-11-04`,
  `.backup_before_stage10_partners_2026-11-05`, `.backup_before_stage11_visits_2026-11-05`,
  `.backup_before_stage13_map_2026-11-05`, `.backup_before_practice_sites_2026-11-05`.
