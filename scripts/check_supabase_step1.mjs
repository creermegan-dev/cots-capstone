// Read-only source-contract checks. These do NOT execute PostgreSQL or prove RLS.
import { readFileSync, readdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const migrations = readdirSync(resolve(root, 'supabase/migrations')).filter(x => x.endsWith('.sql')).sort();
const sql = migrations.map(x => readFileSync(resolve(root, 'supabase/migrations', x), 'utf8')).join('\n');
const tests = readFileSync(resolve(root, 'supabase/tests/database/step1_security.test.sql'), 'utf8');
let passed = 0;
function check(name, fn) { fn(); passed++; process.stdout.write(`PASS ${name}\n`); }
const tables = [...sql.matchAll(/create table public\.(\w+)\s*\(/gi)].map(x => x[1]);
check('23 application tables including setup state and evidence links', () => assert.equal(tables.length, 23));
check('every application table is in the RLS enable/revoke list', () => {
  const rls = sql.slice(sql.indexOf('-- All tables default deny.'), sql.indexOf('create policy profiles_read'));
  for (const t of tables) assert(rls.includes(`'${t}'`), t);
  assert(rls.includes('enable row level security'));
});
check('no monitoring or real-user seeds in migrations', () => {
  assert(!/insert into (?:auth\.users|public\.(?:profiles|monitoring_areas|captures))\s*(?:\([^;]*?\))?\s*values/gi.test(sql.split('create function')[0]));
  assert(!/[a-z0-9._+-]+@[a-z0-9.-]+\.[a-z]{2,}/i.test(sql));
});
check('security-definer routines pin search_path', () => {
  for (const m of sql.matchAll(/create function[\s\S]*?\bas \$\$/gi)) {
    if (/security definer/i.test(m[0])) assert(/set search_path = ''/i.test(m[0]), m[0].split('\n')[0]);
  }
});
check('privileged slots have unique role, unique identity and setup seal', () => {
  assert(sql.includes('role text primary key')); assert(sql.includes('user_id uuid not null unique'));
  assert(sql.includes('guard_privileged_slots')); assert(sql.includes('Both separate privileged accounts are required'));
});
check('no client mutation grants on histories, roles, completion or verification', () => {
  assert(!/grant (?:insert|update|delete)[\s\S]*?on public\.(?:audit_events|expert_decisions|privileged_role_slots|workflow_events) to authenticated/i.test(
    sql.split('\n').filter(x => /^grant /i.test(x)).join('\n')));
  assert(!/grant update\([^)]*(?:field_verified|upload_status|status|completed_at)/i.test(sql));
});
check('trusted finalizers explicitly granted only to service role', () => {
  assert(/grant execute on function public\.record_verified_media[\s\S]*?public\.finalize_elimination\(uuid\) to service_role/.test(sql));
});
check('offline identifiers, source timestamps and Philippine month contract', () => {
  for (const x of ['idempotency_key','captured_at','submitted_at','Asia/Manila','authorization_revision','gps_accuracy_m','surface_reference']) assert(sql.includes(x));
});
check('no Storage bucket creation, deployment, Firebase writes or plaintext credentials', () => {
  assert(!/insert into storage\.buckets|firebase deploy|supabase db push|service_role\s*[:=]\s*['"]/i.test(sql));
});
check('pgTAP suite rolls back synthetic fixtures', () => {
  assert(tests.trimEnd().endsWith('rollback;')); assert(tests.includes('@example.invalid'));
  for (const x of ['Second Administrator','Second Expert','Duplicate acceptance','Expired/stale','Multiple same-month','Negative elimination','Missing evidence','Unrelated diver','Signup metadata']) assert(tests.includes(x));
});
process.stdout.write(`${passed} static checks passed. PostgreSQL/Auth/Storage runtime tests are separate.\n`);
