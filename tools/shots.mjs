// Uploads the App Store screenshots (store/shots/<lang>-N-*.png) to the draft version. Nothing is submitted.
//   node tools/shots.mjs <AuthKey.p8> <keyId> <issuerId>
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const BUNDLE = 'com.barak.lumohop';
const DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'store', 'shots');
const LOCALES = { 'en-US': 'en', he: 'he' };
const TYPE = 'APP_IPHONE_67'; // the 6.9" / 6.7" slot, accepts 1320x2868
const [keyPath, keyId, issuer] = process.argv.slice(2);
if (!keyPath || !keyId || !issuer) { console.error('usage: node tools/shots.mjs <AuthKey.p8> <keyId> <issuerId>'); process.exit(2); }

const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
function token() {
  const now = Math.floor(Date.now() / 1000);
  const head = b64({ alg: 'ES256', kid: keyId, typ: 'JWT' }) + '.' + b64({ iss: issuer, iat: now, exp: now + 600, aud: 'appstoreconnect-v1' });
  return head + '.' + crypto.sign('sha256', Buffer.from(head), { key: fs.readFileSync(keyPath, 'utf8'), dsaEncoding: 'ieee-p1363' }).toString('base64url');
}
async function api(p, method = 'GET', body) {
  const res = await fetch('https://api.appstoreconnect.apple.com' + p, { method, headers: { Authorization: 'Bearer ' + token(), 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
  const json = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, json, errors: (json.errors || []).map(e => e.detail || e.title).join(' | ') };
}

const appId = (await api(`/v1/apps?filter[bundleId]=${BUNDLE}`)).json.data[0].id;
const ver = (await api(`/v1/apps/${appId}/appStoreVersions`)).json.data[0];
const locs = (await api(`/v1/appStoreVersions/${ver.id}/appStoreVersionLocalizations`)).json.data;

for (const [locale, prefix] of Object.entries(LOCALES)) {
  const loc = locs.find(l => l.attributes.locale === locale);
  if (!loc) { console.log('SKIP  no localization for', locale); continue; }
  const files = fs.readdirSync(DIR).filter(f => f.startsWith(prefix + '-') && f.endsWith('.png')).sort();
  const sets = (await api(`/v1/appStoreVersionLocalizations/${loc.id}/appScreenshotSets`)).json.data || [];
  let set = sets.find(s => s.attributes.screenshotDisplayType === TYPE);
  if (!set) {
    const r = await api('/v1/appScreenshotSets', 'POST', { data: { type: 'appScreenshotSets', attributes: { screenshotDisplayType: TYPE },
      relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: loc.id } } } } });
    if (!r.ok) { console.log('FAIL  set', locale, r.status, r.errors); continue; }
    set = r.json.data;
  }
  const have = ((await api(`/v1/appScreenshotSets/${set.id}/appScreenshots`)).json.data || []).map(s => s.attributes.fileName);
  for (const f of files) {
    if (have.includes(f)) { console.log('OK    already there', locale, f); continue; }
    const buf = fs.readFileSync(path.join(DIR, f));
    const made = await api('/v1/appScreenshots', 'POST', { data: { type: 'appScreenshots', attributes: { fileName: f, fileSize: buf.length },
      relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: set.id } } } } });
    if (!made.ok) { console.log('FAIL  reserve', locale, f, made.status, made.errors); continue; }
    const shot = made.json.data;
    let sent = true;
    for (const op of shot.attributes.uploadOperations || []) {
      const headers = Object.fromEntries((op.requestHeaders || []).map(h => [h.name, h.value]));
      const res = await fetch(op.url, { method: op.method, headers, body: buf.subarray(op.offset, op.offset + op.length) });
      if (!res.ok) { sent = false; console.log('FAIL  upload part', locale, f, res.status); }
    }
    if (!sent) continue;
    const done = await api(`/v1/appScreenshots/${shot.id}`, 'PATCH', { data: { type: 'appScreenshots', id: shot.id,
      attributes: { uploaded: true, sourceFileChecksum: crypto.createHash('md5').update(buf).digest('hex') } } });
    console.log(done.ok ? 'OK   ' : 'FAIL ', 'uploaded', locale, f, done.ok ? '' : `${done.status} ${done.errors}`);
  }
}

// processing state after a short wait
await new Promise(r => setTimeout(r, 20000));
for (const [locale] of Object.entries(LOCALES)) {
  const loc = locs.find(l => l.attributes.locale === locale);
  if (!loc) continue;
  for (const s of (await api(`/v1/appStoreVersionLocalizations/${loc.id}/appScreenshotSets`)).json.data || []) {
    for (const x of (await api(`/v1/appScreenshotSets/${s.id}/appScreenshots`)).json.data || [])
      console.log('state', locale, x.attributes.fileName, x.attributes.assetDeliveryState?.state, (x.attributes.assetDeliveryState?.errors || []).map(e => e.description).join(' | '));
  }
}
