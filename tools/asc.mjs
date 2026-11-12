// App Store Connect helper. The key file is read at run time and never printed.
//   node tools/asc.mjs check    <AuthKey.p8> <keyId> <issuerId>   -> does the key work, is the bundle id / app there
//   node tools/asc.mjs register <AuthKey.p8> <keyId> <issuerId>   -> register the bundle id com.barak.lumohop
import fs from 'node:fs';
import crypto from 'node:crypto';

const BUNDLE = 'com.barak.lumohop';
const [cmd, keyPath, keyId, issuer] = process.argv.slice(2);
if (!cmd || !keyPath || !keyId || !issuer) { console.error('usage: node tools/asc.mjs check|register <AuthKey.p8> <keyId> <issuerId>'); process.exit(2); }

const b64 = o => Buffer.from(typeof o === 'string' ? o : JSON.stringify(o)).toString('base64url');
function token() {
  const now = Math.floor(Date.now() / 1000);
  const head = b64({ alg: 'ES256', kid: keyId, typ: 'JWT' }) + '.' + b64({ iss: issuer, iat: now, exp: now + 600, aud: 'appstoreconnect-v1' });
  const sig = crypto.sign('sha256', Buffer.from(head), { key: fs.readFileSync(keyPath, 'utf8'), dsaEncoding: 'ieee-p1363' });
  return head + '.' + sig.toString('base64url');
}
async function api(path, init = {}) {
  const res = await fetch('https://api.appstoreconnect.apple.com' + path, { ...init, headers: { Authorization: 'Bearer ' + token(), 'Content-Type': 'application/json' } });
  const body = await res.json().catch(() => ({}));
  return { status: res.status, body };
}
const errs = r => (r.body.errors || []).map(e => e.detail || e.title).join('; ');

const ids = await api(`/v1/bundleIds?filter[identifier]=${BUNDLE}`);
if (ids.status !== 200) { console.log('key rejected:', ids.status, errs(ids)); process.exit(1); }
const existing = (ids.body.data || []).find(d => d.attributes.identifier === BUNDLE);
console.log('key works. bundle id registered:', !!existing);

if (cmd === 'register' && !existing) {
  const r = await api('/v1/bundleIds', { method: 'POST', body: JSON.stringify({ data: { type: 'bundleIds', attributes: { identifier: BUNDLE, name: 'Lumo Hop', platform: 'IOS' } } }) });
  console.log(r.status === 201 ? 'bundle id registered now' : `could not register: ${r.status} ${errs(r)}`);
}
const apps = await api(`/v1/apps?filter[bundleId]=${BUNDLE}`);
console.log('app record exists:', apps.status === 200 ? (apps.body.data || []).length > 0 : `unknown (${apps.status} ${errs(apps)})`);
