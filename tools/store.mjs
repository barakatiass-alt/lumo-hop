// Fills the App Store page draft for Lumo Hop (texts, categories, age rating, copyright, free price). Nothing is submitted.
//   node tools/store.mjs <AuthKey.p8> <keyId> <issuerId>
import fs from 'node:fs';
import crypto from 'node:crypto';

const BUNDLE = 'com.barak.lumohop';
const SITE = 'https://barakatiass-alt.github.io/lumo-hop/';
const [keyPath, keyId, issuer] = process.argv.slice(2);
if (!keyPath || !keyId || !issuer) { console.error('usage: node tools/store.mjs <AuthKey.p8> <keyId> <issuerId>'); process.exit(2); }

const TEXT = {
  'en-US': {
    name: 'Lumo Hop',
    subtitle: 'One-tap lantern leaping',
    promotionalText: 'One firefly, a sky full of lanterns, and a single tap. How high can you climb before the light goes out?',
    keywords: 'firefly,lantern,one tap,arcade,casual,jump,orbit,timing,reflex,endless,glow,night,relax,offline',
    description: `A firefly circles a glowing paper lantern. Tap once to let it go, and catch the next light before its glow fades.

That is the whole game. It takes a second to learn and it is very hard to put down.

HOW IT PLAYS
• Tap anywhere to send the firefly flying in a straight line.
• Land on the next lantern to score. Miss, and the light goes out.
• Every lantern slowly burns down, so you cannot wait forever.
• Hop quickly to build a combo of up to ×5.
• Skip a lantern or grab a star on the way for bonus points.

A SKY THAT CHANGES AS YOU CLIMB
Start on a tropical shore at dusk and rise through deep night, aurora green, orchid and dawn. Lanterns shrink, drift and spread apart the higher you go.

MADE TO FEEL GOOD
• Every catch plays a note, and the notes climb with your combo.
• Soft taps of vibration on each landing.
• Five firefly colors to unlock with your best score.
• Challenge a friend with your score in one tap.

NO CLUTTER
No ads. No accounts. No data collected. Works without an internet connection.`
  },
  he: {
    name: 'Lumo Hop',
    subtitle: 'גחלילית אחת, שמיים של פנסים',
    promotionalText: 'גחלילית אחת, שמיים מלאים פנסים ונגיעה אחת. כמה גבוה תגיעו לפני שהאור כבה?',
    keywords: 'גחלילית,פנסים,משחק קליל,ארקייד,קפיצות,תזמון,רפלקסים,אינסופי,לילה,נגיעה אחת,בלי אינטרנט',
    description: `גחלילית מסתובבת סביב פנס נייר זוהר. נגיעה אחת משחררת אותה, והמטרה לתפוס את הפנס הבא לפני שהאור שלה דועך.

זה כל המשחק. לומדים אותו בשנייה, וקשה מאוד להניח אותו.

איך משחקים
• נגיעה בכל מקום במסך שולחת את הגחלילית בקו ישר.
• נוחתים על הפנס הבא וצוברים נקודות. מפספסים, והאור כבה.
• כל פנס נשרף לאט, אז אי אפשר לחכות לנצח.
• קפיצות מהירות בונות רצף של עד ×5.
• דילוג על פנס או כוכב בדרך נותנים בונוס.

שמיים שמשתנים ככל שעולים
מתחילים בחוף טרופי בשקיעה ועולים דרך לילה עמוק, זוהר ירוק, סגול וזריחה. ככל שעולים הפנסים קטנים, זזים ומתרחקים.

נעים לשחק
• כל תפיסה מנגנת תו, והתווים עולים עם הרצף.
• רטט עדין בכל נחיתה.
• חמישה צבעי גחלילית שנפתחים לפי השיא.
• אתגר לחבר עם התוצאה שלכם בנגיעה אחת.

בלי רעש
בלי פרסומות. בלי חשבונות. בלי איסוף מידע. עובד גם בלי אינטרנט.`
  }
};
for (const [loc, t] of Object.entries(TEXT)) {
  if (t.name.length > 30 || t.subtitle.length > 30 || t.keywords.length > 100 || t.promotionalText.length > 170 || t.description.length > 4000)
    { console.error('text too long for', loc, t.subtitle.length, t.keywords.length, t.promotionalText.length); process.exit(1); }
}

const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
function token() {
  const now = Math.floor(Date.now() / 1000);
  const head = b64({ alg: 'ES256', kid: keyId, typ: 'JWT' }) + '.' + b64({ iss: issuer, iat: now, exp: now + 600, aud: 'appstoreconnect-v1' });
  return head + '.' + crypto.sign('sha256', Buffer.from(head), { key: fs.readFileSync(keyPath, 'utf8'), dsaEncoding: 'ieee-p1363' }).toString('base64url');
}
async function api(path, method = 'GET', body) {
  const res = await fetch('https://api.appstoreconnect.apple.com' + path, { method, headers: { Authorization: 'Bearer ' + token(), 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
  const json = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, json, errors: (json.errors || []).map(e => `${e.detail || e.title}${e.source?.pointer ? ' @' + e.source.pointer : ''}`) };
}
const say = (what, r) => console.log(r.ok ? 'OK    ' : 'FAIL  ', what, r.ok ? '' : `${r.status} ${r.errors.join(' | ')}`);

const app = (await api(`/v1/apps?filter[bundleId]=${BUNDLE}`)).json.data?.[0];
if (!app) { console.error('app record not found'); process.exit(1); }
const appId = app.id;

// app-level info: name, subtitle, privacy link, categories
const info = (await api(`/v1/apps/${appId}/appInfos`)).json.data[0];
const infoLocs = (await api(`/v1/appInfos/${info.id}/appInfoLocalizations`)).json.data;
for (const [locale, t] of Object.entries(TEXT)) {
  const attrs = { name: t.name, subtitle: t.subtitle, privacyPolicyUrl: SITE + 'privacy.html' };
  const have = infoLocs.find(l => l.attributes.locale === locale);
  say(`name and subtitle (${locale})`, have
    ? await api(`/v1/appInfoLocalizations/${have.id}`, 'PATCH', { data: { type: 'appInfoLocalizations', id: have.id, attributes: attrs } })
    : await api('/v1/appInfoLocalizations', 'POST', { data: { type: 'appInfoLocalizations', attributes: { locale, ...attrs }, relationships: { appInfo: { data: { type: 'appInfos', id: info.id } } } } }));
}
const cat = id => ({ data: { type: 'appCategories', id } });
say('category Games / Casual + Action', await api(`/v1/appInfos/${info.id}`, 'PATCH', { data: { type: 'appInfos', id: info.id,
  relationships: { primaryCategory: cat('GAMES'), primarySubcategoryOne: cat('GAMES_CASUAL'), primarySubcategoryTwo: cat('GAMES_ACTION') } } }));

// age rating: nothing sensitive in the game
const age = (await api(`/v1/appInfos/${info.id}/ageRatingDeclaration`)).json.data;
if (age) {
  const attrs = {};
  for (const k of ['alcoholTobaccoOrDrugUseOrReferences', 'contests', 'gamblingSimulated', 'horrorOrFearThemes', 'matureOrSuggestiveThemes', 'medicalOrTreatmentInformation',
    'profanityOrCrudeHumor', 'sexualContentGraphicAndNudity', 'sexualContentOrNudity', 'violenceCartoonOrFantasy', 'violenceRealistic',
    'violenceRealisticProlongedGraphicOrSadistic', 'gunsOrOtherWeapons']) attrs[k] = 'NONE';
  for (const k of ['gambling', 'unrestrictedWebAccess', 'lootBox', 'messagingAndChat', 'userGeneratedContent', 'advertising', 'parentalControls', 'ageAssurance', 'healthOrWellnessTopics']) attrs[k] = false;
  let r;
  for (let i = 0; i < 12; i++) {
    r = await api(`/v1/ageRatingDeclarations/${age.id}`, 'PATCH', { data: { type: 'ageRatingDeclarations', id: age.id, attributes: attrs } });
    if (r.ok) break;
    const missing = (r.json.errors || []).filter(e => /must provide a value/.test(e.detail || '')).map(e => (e.source?.pointer || '').split('/').pop()).filter(Boolean);
    if (missing.length) { missing.forEach(k => { attrs[k] = attrs[k] === false ? 'NONE' : false; }); continue; }
    const bad = (r.json.errors || []).map(e => (e.source?.pointer || '').split('/').pop()).filter(k => k in attrs);
    const named = Object.keys(attrs).filter(k => r.errors.join(' ').includes(`'${k}'`));
    const drop = [...new Set([...bad, ...named])];
    if (!drop.length) break;
    drop.forEach(k => delete attrs[k]);
  }
  say('age rating answers (all "none")', r);
} else console.log('SKIP   age rating: no declaration found');

// version-level: copyright and store texts
const ver = (await api(`/v1/apps/${appId}/appStoreVersions`)).json.data[0];
say('copyright', await api(`/v1/appStoreVersions/${ver.id}`, 'PATCH', { data: { type: 'appStoreVersions', id: ver.id, attributes: { copyright: '2026 Barak Atias' } } }));
const verLocs = (await api(`/v1/appStoreVersions/${ver.id}/appStoreVersionLocalizations`)).json.data;
for (const [locale, t] of Object.entries(TEXT)) {
  const attrs = { description: t.description, keywords: t.keywords, promotionalText: t.promotionalText, supportUrl: SITE + 'support.html', marketingUrl: SITE };
  const have = verLocs.find(l => l.attributes.locale === locale);
  say(`description and keywords (${locale})`, have
    ? await api(`/v1/appStoreVersionLocalizations/${have.id}`, 'PATCH', { data: { type: 'appStoreVersionLocalizations', id: have.id, attributes: attrs } })
    : await api('/v1/appStoreVersionLocalizations', 'POST', { data: { type: 'appStoreVersionLocalizations', attributes: { locale, ...attrs }, relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: ver.id } } } } }));
}

say('content rights (no third-party content)', await api(`/v1/apps/${appId}`, 'PATCH', { data: { type: 'apps', id: appId, attributes: { contentRightsDeclaration: 'DOES_NOT_USE_THIRD_PARTY_CONTENT' } } }));

// price: free
const points = await api(`/v1/apps/${appId}/appPricePoints?filter[territory]=USA&limit=200`);
const free = (points.json.data || []).find(p => Number(p.attributes.customerPrice) === 0);
if (free) {
  say('price: free', await api('/v1/appPriceSchedules', 'POST', {
    data: { type: 'appPriceSchedules', relationships: { app: { data: { type: 'apps', id: appId } }, baseTerritory: { data: { type: 'territories', id: 'USA' } }, manualPrices: { data: [{ type: 'appPrices', id: '${price1}' }] } } },
    included: [{ type: 'appPrices', id: '${price1}', attributes: { startDate: null }, relationships: { appPricePoint: { data: { type: 'appPricePoints', id: free.id } } } }]
  }));
} else console.log('SKIP   price: free price point not found', points.status, points.errors.join(' | '));
console.log('app id', appId, 'version', ver.attributes.versionString, ver.attributes.appStoreState || ver.attributes.appVersionState);
