// Stores the App Store Connect key as encrypted GitHub repository secrets. Nothing secret is printed.
//   cd tools && npm install && node set-secrets.mjs <AuthKey.p8> <keyId> <issuerId>
// The GitHub token comes from the git credential helper already signed in on this computer.
import fs from 'node:fs';
import { execSync } from 'node:child_process';
import sodium from 'libsodium-wrappers';

const REPO = 'barakatiass-alt/lumo-hop';
const [keyPath, keyId, issuer] = process.argv.slice(2);
if (!keyPath || !keyId || !issuer) { console.error('usage: node set-secrets.mjs <AuthKey.p8> <keyId> <issuerId>'); process.exit(2); }

const cred = execSync('git credential fill', { input: 'protocol=https\nhost=github.com\n\n', env: { ...process.env, GIT_TERMINAL_PROMPT: '0' } }).toString();
const ghToken = (cred.match(/^password=(.*)$/m) || [])[1];
if (!ghToken) { console.error('no GitHub sign-in found'); process.exit(1); }
const gh = (path, init = {}) => fetch(`https://api.github.com/repos/${REPO}/${path}`, { ...init, headers: { Authorization: `Bearer ${ghToken}`, Accept: 'application/vnd.github+json' } });

await sodium.ready;
const pk = await (await gh('actions/secrets/public-key')).json();
if (!pk.key) { console.error('could not read the repository key:', pk.message); process.exit(1); }
const secrets = { ASC_KEY_ID: keyId, ASC_ISSUER_ID: issuer, ASC_KEY_P8: fs.readFileSync(keyPath, 'utf8').trim() };
for (const [name, value] of Object.entries(secrets)) {
  const sealed = sodium.crypto_box_seal(sodium.from_string(value), sodium.from_base64(pk.key, sodium.base64_variants.ORIGINAL));
  const res = await gh(`actions/secrets/${name}`, { method: 'PUT', body: JSON.stringify({ encrypted_value: sodium.to_base64(sealed, sodium.base64_variants.ORIGINAL), key_id: pk.key_id }) });
  console.log(name, res.status === 201 ? 'created' : res.status === 204 ? 'updated' : `failed (${res.status})`);
}
