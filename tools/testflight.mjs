// TestFlight helper: shows build status, makes an internal group and adds the account's own users to it.
//   node tools/testflight.mjs <AuthKey.p8> <keyId> <issuerId>
import fs from 'node:fs';
import crypto from 'node:crypto';

const BUNDLE = 'com.barak.lumohop';
const [keyPath, keyId, issuer] = process.argv.slice(2);
const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
function token() {
  const now = Math.floor(Date.now() / 1000);
  const head = b64({ alg: 'ES256', kid: keyId, typ: 'JWT' }) + '.' + b64({ iss: issuer, iat: now, exp: now + 600, aud: 'appstoreconnect-v1' });
  return head + '.' + crypto.sign('sha256', Buffer.from(head), { key: fs.readFileSync(keyPath, 'utf8'), dsaEncoding: 'ieee-p1363' }).toString('base64url');
}
async function api(path, method = 'GET', body) {
  const res = await fetch('https://api.appstoreconnect.apple.com' + path, { method, headers: { Authorization: 'Bearer ' + token(), 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
  const json = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, json, errors: (json.errors || []).map(e => e.detail || e.title).join(' | ') };
}

const appId = (await api(`/v1/apps?filter[bundleId]=${BUNDLE}`)).json.data[0].id;
const builds = (await api(`/v1/builds?filter[app]=${appId}&sort=-uploadedDate&limit=5`)).json.data || [];
for (const b of builds) console.log('build', b.attributes.version, b.attributes.processingState, 'expired:', b.attributes.expired);
if (!builds.length) console.log('no builds visible yet (Apple is still processing)');

let group = ((await api(`/v1/apps/${appId}/betaGroups`)).json.data || []).find(g => g.attributes.isInternalGroup);
if (!group) {
  const r = await api('/v1/betaGroups', 'POST', { data: { type: 'betaGroups', attributes: { name: 'Team', isInternalGroup: true, hasAccessToAllBuilds: true }, relationships: { app: { data: { type: 'apps', id: appId } } } } });
  console.log(r.ok ? 'internal group created' : `group failed: ${r.status} ${r.errors}`);
  group = r.json.data;
}
if (group) {
  const users = (await api('/v1/users?limit=50')).json.data || [];
  const inGroup = ((await api(`/v1/betaGroups/${group.id}/betaTesters?limit=50`)).json.data || []).map(t => (t.attributes.email || '').toLowerCase());
  for (const u of users) {
    const email = u.attributes.username;
    if (inGroup.includes(email.toLowerCase())) { console.log('tester already in group:', u.attributes.firstName); continue; }
    const r = await api('/v1/betaTesters', 'POST', { data: { type: 'betaTesters', attributes: { email, firstName: u.attributes.firstName, lastName: u.attributes.lastName },
      relationships: { betaGroups: { data: [{ type: 'betaGroups', id: group.id }] } } } });
    console.log(r.ok ? `tester added: ${u.attributes.firstName}` : `tester failed (${u.attributes.firstName}): ${r.status} ${r.errors}`);
  }
}
