// Run against the isolated local emulator only:
// java -jar <firestore-emulator.jar> --host 127.0.0.1 --port 8088
//   --project_id demo-cots-follow-up --rules firebase/firestore.rules
// node test/firestore_follow_up_rules_test.cjs
const assert = require('node:assert/strict');
const root = 'http://127.0.0.1:8088/v1/projects/demo-cots-follow-up/databases/(default)/documents';
const suffix = Date.now().toString();
const a = `diver-a-${suffix}`, b = `diver-b-${suffix}`, expert = `expert-${suffix}`;
const area = `reef-${suffix}`, visit = `visit-${suffix}`, image = `image-${suffix}`;
let checks = 0;
const encode = value => value === null ? {nullValue: null}
  : value instanceof Date ? {timestampValue: value.toISOString()}
  : Array.isArray(value) ? {arrayValue: {values: value.map(encode)}}
  : typeof value === 'object' ? {mapValue: {fields: fields(value)}}
  : typeof value === 'boolean' ? {booleanValue: value}
  : Number.isInteger(value) ? {integerValue: `${value}`}
  : typeof value === 'number' ? {doubleValue: value} : {stringValue: value};
const fields = data => Object.fromEntries(Object.entries(data).map(([key, value]) => [key, encode(value)]));
function token(uid) {
  const now = Math.floor(Date.now() / 1000);
  const payload = {sub: uid, user_id: uid, aud: 'demo-cots-follow-up',
    iss: 'https://securetoken.google.com/demo-cots-follow-up', iat: now, exp: now + 3600,
    firebase: {sign_in_provider: 'custom'}};
  return `${Buffer.from(JSON.stringify({alg: 'none', typ: 'JWT'})).toString('base64url')}.${Buffer.from(JSON.stringify(payload)).toString('base64url')}.`;
}
async function request(path, uid = 'owner', method = 'GET', data) {
  return fetch(`${root}/${path}`, {method,
    headers: {'Authorization': `Bearer ${uid === 'owner' ? uid : token(uid)}`, 'Content-Type': 'application/json'},
    body: data ? JSON.stringify(data) : undefined});
}
async function seed(path, data) {
  const response = await request(path, 'owner', 'PATCH', {fields: fields(data)});
  assert.equal(response.status, 200, await response.text());
}
async function expectStatus(label, response, status) {
  assert.equal(response.status, status, `${label}: ${await response.text()}`);
  checks++;
}
const create = (collection, id, uid, data) => request(`${collection}?documentId=${id}`, uid, 'POST', {fields: fields(data)});
const date = new Date('2025-09-15T00:00:00Z');
const capture = {uid: a, submitted_by: 'Diver A', capture_source: 'GoPro Underwater Image',
  citizen_contribution: true, has_processed_image: true, ai_detected_count: 2,
  confidence: .9, processed_at: date, submitted_at: date, monitoring_area_id: area,
  gps: {latitude: 7.1, longitude: 125.6}};
const assignment = {area_id: area, area_name: 'Reef A-01', barangay: 'Barangay', municipality: 'Town',
  primary_diver_uid: a, primary_diver_name: 'Diver A', initial_capture_id: `initial-${suffix}`,
  initial_collection: 'captures', initial_date: date, initial_detected_count: 2, created_at: date};
const survey = {area_id: area, area_name: 'Reef A-01', barangay: 'Barangay', municipality: 'Town',
  uid: a, submitted_by: 'Diver A', survey_date: date, survey_calendar_date: '2025-09-15',
  field_observed_count: 3, field_eliminated_count: 1, capture_ids: [image],
  gps: {latitude: 7.1, longitude: 125.6}, elimination_method: 'Injection', notes: '',
  ai_detected_count: 2, submitted_at: date};
async function main() {
  await seed(`users/${a}`, {accountRole: 'user', isActive: true});
  await seed(`users/${b}`, {accountRole: 'user', isActive: true});
  await seed(`users/${expert}`, {accountRole: 'expert', isActive: true});
  await seed(`captures/${assignment.initial_capture_id}`, capture);
  await expectStatus('diver cannot claim another diver’s original detection',
    await create('follow_up_assignments', area, b, {...assignment, primary_diver_uid: b}), 403);
  await expectStatus('original diver creates the primary assignment', await create('follow_up_assignments', area, a, assignment), 200);
  await expectStatus('duplicate primary document is refused', await create('follow_up_assignments', area, a, assignment), 409);
  await expectStatus('reassignment is refused', await request(`follow_up_assignments/${area}`, a, 'PATCH', {fields: fields({...assignment, primary_diver_uid: b})}), 403);
  const phNow = new Date(Date.now() + 8 * 3600000);
  for (const [year, month] of [[2025, 9], [phNow.getUTCFullYear(), phNow.getUTCMonth() + 1]]) {
    await seed('follow_up_month_authorizations/' + area + '_' + year + '_' + month,
      {area_id: area, year, month, primary_uid: a, responsible_uid: a});
  }
  await expectStatus('another diver cannot submit a survey', await create('follow_up_surveys', visit, b, {...survey, uid: b}), 403);
  await expectStatus('missing survey can be read for create-only transaction', await request(`follow_up_surveys/${visit}`, a), 404);
  await expectStatus('assigned diver can create a linked processed capture', await create('captures', image, a, {...capture, follow_up_survey_id: visit}), 200);
  await expectStatus('another diver cannot create a capture for this zone’s survey', await create('captures', `bad-${suffix}`, b, {...capture, uid: b, follow_up_survey_id: visit}), 403);
  await expectStatus('unlinked image is refused', await create('follow_up_surveys', visit, a, {...survey, capture_ids: [assignment.initial_capture_id]}), 403);
  await expectStatus('a valid linked visit is saved', await create('follow_up_surveys', visit, a, survey), 200);
  await expectStatus('another diver cannot read the visit', await request(`follow_up_surveys/${visit}`, b), 403);
  await expectStatus('expert can read the visit', await request(`follow_up_surveys/${visit}`, expert), 200);
  await expectStatus('survey history cannot be overwritten', await request(`follow_up_surveys/${visit}`, a, 'PATCH', {fields: fields({...survey, field_observed_count: 999})}), 403);
  await expectStatus('survey history cannot be deleted', await request(`follow_up_surveys/${visit}`, a, 'DELETE'), 403);
  const nextVisit = `${visit}-second`, nextImage = `${image}-second`;
  await seed(`captures/${nextImage}`, {...capture, follow_up_survey_id: nextVisit});
  await expectStatus('second visit in the same month is separate', await create('follow_up_surveys', nextVisit, a, {...survey, capture_ids: [nextImage]}), 200);
  const eightVisit = `${visit}-eight`, eight = Array.from({length: 8}, (_, i) => `${image}-eight-${i}`);
  for (const id of eight) await seed(`captures/${id}`, {...capture, follow_up_survey_id: eightVisit});
  await expectStatus('eight linked images stay within rule access limits', await create('follow_up_surveys', eightVisit, a, {...survey, capture_ids: eight, ai_detected_count: 16}), 200);
  await expectStatus('future visit is refused', await create('follow_up_surveys', `${visit}-future`, a, {...survey, survey_date: new Date('2099-01-01')}), 403);
  await expectStatus('legacy original detection is supported', await (async () => {
    const legacyArea = `${area}-legacy`, legacyId = `${image}-legacy`;
    await seed(`scan_records/${legacyId}`, {...capture, monitoring_area_id: legacyArea});
    return create('follow_up_assignments', legacyArea, a, {...assignment, area_id: legacyArea, initial_capture_id: legacyId, initial_collection: 'scan_records'});
  })(), 200);
  await expectStatus('expert can create original assignment without changing original diver', await (async () => {
    const expertArea = `${area}-expert`, initial = `${image}-expert`;
    await seed(`captures/${initial}`, {...capture, monitoring_area_id: expertArea});
    return create('follow_up_assignments', expertArea, expert, {...assignment, area_id: expertArea, initial_capture_id: initial});
  })(), 200);
  await expectStatus('ordinary Detect capture creation still works', await create('captures', `${image}-ordinary`, b, {...capture, uid: b}), 200);
  await expectStatus('original elimination workflow still creates linked evidence', await create('removal_records', `${image}-removal`, a, {
    uid: a, capture_id: assignment.initial_capture_id, has_processed_image: true,
    removed_quantity: 1, processed_at: date, submitted_at: date,
  }), 200);
  await expectStatus('elimination cannot be claimed by another diver', await create('removal_records', `${image}-invalid-removal`, b, {
    uid: b, capture_id: assignment.initial_capture_id, has_processed_image: true,
    removed_quantity: 1, processed_at: date, submitted_at: date,
  }), 403);
  const original = await request(`captures/${assignment.initial_capture_id}`, a);
  const originalData = await original.json();
  const originalExpected = fields(capture);
  for (const key of ['processed_at', 'submitted_at']) originalExpected[key].timestampValue = date.toISOString().replace('.000Z', 'Z');
  assert.deepEqual(originalData.fields, originalExpected, 'Follow-up did not alter original detection');
  checks++;
  const queryResponse = await fetch(`${root}:runQuery`, {method: 'POST', headers: {
    Authorization: `Bearer ${token(a)}`, 'Content-Type': 'application/json',
  }, body: JSON.stringify({structuredQuery: {
    from: [{collectionId: 'follow_up_assignments'}],
    where: {fieldFilter: {field: {fieldPath: 'primary_diver_uid'}, op: 'EQUAL', value: {stringValue: a}}},
  }})});
  await expectStatus('diver assignment query is permitted with ownership filter', queryResponse, 200);
  console.log(`${checks} local Firestore rules checks passed.`);
}
main().catch(error => { console.error(error); process.exitCode = 1; });
