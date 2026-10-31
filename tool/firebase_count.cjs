// READ-ONLY Firebase inventory for the Supabase migration.
// Prints only counts and dates: never names, emails, field values or photos.
// The service-account key is read from GOOGLE_APPLICATION_CREDENTIALS (set by
// tool\firebase_count.bat from your Downloads folder) and is never printed.
const path = require('path');
const fs = require('fs');
const admin = require(path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin'));

const EXPECTED_PROJECT = 'cots-monitor';
const BUCKET = 'cots-monitor.firebasestorage.app';
const out = (line = '') => console.log(line);
const day = (d) => d.toISOString().slice(0, 10);

function perMonth(dates) {
  const m = {};
  for (const d of dates) { const k = d.toISOString().slice(0, 7); m[k] = (m[k] || 0) + 1; }
  return Object.keys(m).sort().map((k) => `${k}: ${m[k]}`).join(', ');
}

async function firestoreInventory(db) {
  out('== Firestore (database records)');
  const top = await db.listCollections();
  if (top.length === 0) out('  (no collections)');
  const subNames = new Set();
  for (const col of top.sort((a, b) => a.id.localeCompare(b.id))) {
    try {
      const snap = await col.select().get(); // document ids and times only
      const times = snap.docs.map((d) => d.createTime.toDate());
      const range = times.length
        ? `, created ${day(new Date(Math.min(...times)))} to ${day(new Date(Math.max(...times)))}`
        : '';
      out(`  ${col.id}: ${snap.size}${range}`);
      if (times.length) out(`      by month: ${perMonth(times)}`);
      for (const doc of snap.docs.slice(0, 30)) {
        for (const sub of await doc.ref.listCollections()) subNames.add(sub.id);
      }
    } catch (e) {
      out(`  ${col.id}: could not count (${e.code || e.message})`);
    }
  }
  for (const name of [...subNames].sort()) {
    try {
      const c = await db.collectionGroup(name).count().get();
      out(`  (inside records) ${name}: ${c.data().count}`);
    } catch (e) {
      out(`  (inside records) ${name}: could not count (${e.code || e.message})`);
    }
  }
}

async function authInventory() {
  out('');
  out('== Firebase login accounts');
  let total = 0, verified = 0, disabled = 0, recent = 0, token;
  const created = [];
  const monthAgo = Date.now() - 30 * 24 * 3600 * 1000;
  do {
    const page = await admin.auth().listUsers(1000, token);
    for (const u of page.users) {
      total++;
      if (u.emailVerified) verified++;
      if (u.disabled) disabled++;
      const last = Date.parse(u.metadata.lastSignInTime || '');
      if (last && last > monthAgo) recent++;
      const c = Date.parse(u.metadata.creationTime || '');
      if (c) created.push(new Date(c));
    }
    token = page.pageToken;
  } while (token);
  out(`  accounts: ${total} (email verified: ${verified}, disabled: ${disabled}, signed in during the last 30 days: ${recent})`);
  if (created.length) out(`  created by month: ${perMonth(created)}`);
}

async function storageInventory() {
  out('');
  out('== Firebase Storage (photos)');
  const bucket = admin.storage().bucket(BUCKET);
  const folders = {};
  let files = 0, bytes = 0, query = { autoPaginate: false, maxResults: 1000 };
  while (query) {
    const [list, next] = await bucket.getFiles(query);
    for (const f of list) {
      files++;
      const size = Number(f.metadata.size || 0);
      bytes += size;
      const top = f.name.includes('/') ? f.name.split('/')[0] : '(top level)';
      folders[top] = folders[top] || { files: 0, bytes: 0 };
      folders[top].files++;
      folders[top].bytes += size;
    }
    query = next;
  }
  const mb = (b) => (b / 1024 / 1024).toFixed(1) + ' MB';
  out(`  files: ${files}, total ${mb(bytes)}`);
  for (const k of Object.keys(folders).sort()) out(`    ${k}/: ${folders[k].files} files, ${mb(folders[k].bytes)}`);
}

(async () => {
  const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!keyPath || !fs.existsSync(keyPath)) {
    out('NO KEY FOUND. Put the downloaded key (cots-monitor-....json) in your Downloads folder and run again.');
    process.exit(2);
  }
  let projectId;
  try { projectId = JSON.parse(fs.readFileSync(keyPath, 'utf8')).project_id; } catch (_) {
    out('The key file could not be read.'); process.exit(2);
  }
  if (projectId !== EXPECTED_PROJECT) {
    out(`This key is for project "${projectId}", not ${EXPECTED_PROJECT}. Stopped.`); process.exit(2);
  }
  admin.initializeApp({ credential: admin.credential.applicationDefault(), projectId, storageBucket: BUCKET });
  out(`Firebase inventory for ${projectId} at ${new Date().toISOString()} (read-only)`);
  out('');
  for (const [name, step] of [['Firestore', () => firestoreInventory(admin.firestore())],
                              ['Login accounts', authInventory],
                              ['Storage', storageInventory]]) {
    try { await step(); } catch (e) { out(`  ${name}: could not read (${e.code || e.message})`); }
  }
  out('');
  out('Finished. Nothing was changed.');
})();
