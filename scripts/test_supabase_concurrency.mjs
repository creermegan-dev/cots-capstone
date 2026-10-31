// Real two-session test for a FRESH, DISPOSABLE local Supabase stack only.
// Requires psql and a local password file if password authentication is enabled.
// Never accepts a URL/host/password argument and never resets/drops a database.
import { spawn } from 'node:child_process';
import assert from 'node:assert/strict';
if (process.argv[2] !== '--disposable-local') throw new Error('Explicit --disposable-local acknowledgement required');
const args = ['-X','--no-password','-h','127.0.0.1','-p','54322','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-v','VERBOSITY=verbose','-At'];
const a = '11111111-1111-4111-8111-111111111111';
const b = '22222222-2222-4222-8222-222222222222';
function run(sql, onText = () => {}) {
  const child = spawn('psql', args, { windowsHide: true, env: { ...process.env, PGHOST:'127.0.0.1', PGPORT:'54322', PGDATABASE:'postgres', PGUSER:'postgres', PGOPTIONS:'' } });
  let out='', err='';
  const done = new Promise((resolve,reject) => {
    child.on('error',reject);
    child.stdout.on('data',x => { out+=x; onText(out); });
    child.stderr.on('data',x => { err+=x; });
    child.on('close',code => resolve({code,out,err}));
  });
  child.stdin.end(sql); return done;
}
async function good(sql) { const r=await run(sql); assert.equal(r.code,0,r.err); return r; }
// Fail closed rather than alter an existing local application database.
await good(`do $$ begin if (select completed_at is not null from public.setup_state where singleton)
 or exists(select 1 from public.profiles) or exists(select 1 from public.privileged_role_slots)
 then raise exception 'Requires empty, disposable local stack'; end if; end $$;`);
await good(`insert into auth.users(id,email) values('${a}','concurrency-a@example.invalid'),('${b}','concurrency-b@example.invalid');`);
try {
  for (const role of ['administrator','expert']) {
    let signal;
    const locked = new Promise(r => { signal=r; });
    const first=run(`begin; select public.appoint_initial_role('${role}','${a}');
      \\echo COTS_LOCK_HELD
      select pg_sleep(2); commit;`, out => { if(out.includes('COTS_LOCK_HELD')) signal(); });
    // A failed first session must not leave the runner waiting indefinitely.
    await Promise.race([locked,first.then(r => { if(r.code!==0) throw new Error(r.err); throw new Error('Lock signal missing'); })]);
    const second=run(`begin; select public.appoint_initial_role('${role}','${b}'); commit;`);
    const [one,two]=await Promise.all([first,second]);
    assert.equal(one.code,0,one.err); assert.notEqual(two.code,0);
    assert(two.err.includes('23505'),two.err);
    assert.equal((await good(`select count(*) from public.privileged_role_slots where role='${role}';`)).out.trim(),'1');
    process.stdout.write(`PASS concurrent ${role} appointment: exactly one succeeds\n`);
    await good(`delete from public.privileged_role_slots where role='${role}' and user_id='${a}';`);
  }
} finally {
  // Only fixed synthetic identities in the previously verified empty local stack.
  // Retain the audit trail. No real identity, database, schema or file is deleted.
  await good(`delete from public.privileged_role_slots where user_id in ('${a}','${b}');
    delete from public.profiles where id in ('${a}','${b}');
    delete from auth.users where id in ('${a}','${b}');`);
}
