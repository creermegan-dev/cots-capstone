import fs from 'node:fs';
import assert from 'node:assert/strict';

const read = (path) => fs.readFileSync(path, 'utf8');
const migration = read('supabase/migrations/20261016000400_auth.sql');
const provider = read('lib/providers/auth_provider.dart');
const config = read('lib/core/supabase_config.dart');
const secureStorage = read('lib/core/secure_supabase_local_storage.dart');
const setup = read('scripts/setup_supabase_privileged_accounts.ps1');
const recovery = read('scripts/complete_supabase_password_recovery.ps1');
const cloudTest = read('scripts/test_supabase_auth_cloud.ps1');

const parameterBlock = (script) =>
  script.match(/^\[CmdletBinding[^\n]*\]\r?\nparam\(([\s\S]*?)\r?\n\)/)?.[1] ?? '';

const checks = [
  ['client config uses compile-time public values',
    config.includes("'SUPABASE_URL'") &&
    config.includes("'SUPABASE_PUBLISHABLE_KEY'")],
  ['client config contains no service-role key', !config.toLowerCase().includes('service_role')],
  ['sessions persist and refresh', config.includes('autoRefreshToken: true') && config.includes('persistSession: true')],
  ['sessions use protected platform storage',
    config.includes('SecureSupabaseLocalStorage()') &&
    secureStorage.includes('FlutterSecureStorage') &&
    secureStorage.includes('removePersistedSession')],
  ['provider supports Supabase auth', provider.includes('SupabaseAuthService') && provider.includes('_applySupabaseSession')],
  ['roles come from privileged slots', migration.includes('left join public.privileged_role_slots')],
  ['initial setup requires both privileged roles',
    migration.includes('Exactly one Administrator and one Expert are required')],
  ['administrator directory checks backend role', migration.includes("has_role('administrator')")],
  ['ordinary recovery excludes Administrator', migration.includes('independent owner procedure')],
  ['open recovery requests are unique', migration.includes('recovery_one_open_per_subject')],
  ['recovery consumption is service-role only',
    /grant execute on function[\s\S]*consume_supervised_recovery\(uuid,uuid\)[\s\S]*to service_role;/.test(migration)],
  ['privileged setup uses masked inputs', setup.includes('-AsSecureString')],
  ['privileged setup confirms both users', (setup.match(/email_confirm = \$true/g) ?? []).length === 2],
  ['recovery tool uses masked inputs', recovery.includes('-AsSecureString')],
  ['scripts do not accept password parameters',
    !/\$\w*Password/i.test(parameterBlock(setup)) &&
    !/\$\w*Password/i.test(parameterBlock(recovery))],
  ['cloud test reads keys privately',
    (cloudTest.match(/Read-PrivateText '[^']+key'/g) ?? []).length === 2],
  ['cloud test removes synthetic identities',
    cloudTest.includes("DELETE \"/auth/v1/admin/users/$userId\"")],
];

for (const [name, passed] of checks) {
  assert.ok(passed, name);
  process.stdout.write(`PASS ${name}\n`);
}
process.stdout.write(`${checks.length} Step 2 static security checks passed\n`);
