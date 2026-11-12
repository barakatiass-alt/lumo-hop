// Paints the 1024px app icon (a lit lantern with the firefly on its orbit) and writes the asset catalog. Run: node make-icon.mjs
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const N = 1024, SS = 2;
const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), 'LumoHop', 'Assets.xcassets');
const lerp = (a, b, t) => a + (b - a) * t;
const mix = (c1, c2, t) => [lerp(c1[0], c2[0], t), lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t)];
const stops = (list, t) => {
  if (t <= list[0][0]) return list[0][1];
  for (let i = 1; i < list.length; i++) if (t <= list[i][0]) return mix(list[i - 1][1], list[i][1], (t - list[i - 1][0]) / (list[i][0] - list[i - 1][0]));
  return list[list.length - 1][1];
};
const hash = (x, y) => { const s = Math.sin(x * 127.1 + y * 311.7) * 43758.5453; return s - Math.floor(s); };

const SKY = [[0, [26, 20, 70]], [0.6, [98, 44, 112]], [1, [255, 128, 92]]];
const PAPER = [[0, [255, 251, 224]], [0.3, [255, 214, 102]], [0.75, [250, 140, 36]], [1, [194, 62, 10]]];
const CX = 0.5, CY = 0.53, R = 0.29;           // lantern centre and orbit radius, in icon units
const FA = -0.72;                               // firefly angle on the orbit

function pixel(u, v) {
  let c = stops(SKY, v);
  // stars
  const gx = Math.floor(u * 40), gy = Math.floor(v * 40), h = hash(gx, gy);
  if (h > 0.93 && v < 0.75) {
    const sx = (gx + 0.5 + (hash(gy, gx) - 0.5) * 0.6) / 40, sy = (gy + 0.5) / 40, d = Math.hypot(u - sx, v - sy);
    if (d < 0.0032) c = mix(c, [255, 255, 255], 0.75 * (1 - v));
  }
  const x = (u - CX) / R, y = (v - CY) / R, d = Math.hypot(x, y);
  // halo
  const halo = Math.exp(-Math.pow(d / 1.25, 2)) * 0.8;
  c = [c[0] + 255 * halo, c[1] + 150 * halo, c[2] + 50 * halo];
  // orbit ring, dashed
  const ang = Math.atan2(y, x);
  if (Math.abs(d - 1) < 0.022 && ((ang + Math.PI) * 9) % 1 < 0.55) c = mix(c, [255, 243, 214], 0.6);
  // paper body
  const hh = 0.74, top = -hh * 1.06, shoulder = -0.12, tw = 0.74, bw = 0.42;
  if (y > top && y < hh) {
    const hw = y < shoulder ? tw * Math.sqrt(Math.max(0, 1 - Math.pow((y - shoulder) / (top - shoulder), 2)))
                            : lerp(tw, bw, Math.pow((y - shoulder) / (hh - shoulder), 1.6));
    if (Math.abs(x) < hw) {
      c = stops(PAPER, Math.hypot(x, y - 0.5) / 1.15);
      const rib = Math.abs(Math.abs(x) - hw * 0.42);
      if (rib < 0.012) c = mix(c, [120, 40, 10], 0.22);
      if (y > hh - 0.05) c = mix(c, [90, 30, 10], 0.65);
    }
  }
  // flame light
  const fl = Math.exp(-Math.pow(Math.hypot(x, y - 0.5) / 0.3, 2)) * 0.7;
  c = [c[0] + 255 * fl, c[1] + 240 * fl, c[2] + 180 * fl];
  // firefly
  const fd = Math.hypot(x - Math.cos(FA), y - Math.sin(FA));
  const fg = Math.exp(-Math.pow(fd / 0.2, 2));
  c = [c[0] + 255 * fg, c[1] + 235 * fg, c[2] + 150 * fg];
  if (fd < 0.055) c = [255, 255, 255];
  return c;
}

const raw = Buffer.alloc(N * (N * 3 + 1));
for (let py = 0; py < N; py++) {
  const row = py * (N * 3 + 1); raw[row] = 0;
  for (let px = 0; px < N; px++) {
    let r = 0, g = 0, b = 0;
    for (let sy = 0; sy < SS; sy++) for (let sx = 0; sx < SS; sx++) {
      const c = pixel((px + (sx + 0.5) / SS) / N, (py + (sy + 0.5) / SS) / N);
      r += Math.min(255, c[0]); g += Math.min(255, c[1]); b += Math.min(255, c[2]);
    }
    const o = row + 1 + px * 3, k = SS * SS;
    raw[o] = Math.round(r / k); raw[o + 1] = Math.round(g / k); raw[o + 2] = Math.round(b / k);
  }
}

const crcTable = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
const crc = buf => { let c = 0xffffffff; for (const b of buf) c = crcTable[(c ^ b) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
const chunk = (type, data) => {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type), data]), sum = Buffer.alloc(4); sum.writeUInt32BE(crc(body));
  return Buffer.concat([len, body, sum]);
};
const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(N, 0); ihdr.writeUInt32BE(N, 4); ihdr[8] = 8; ihdr[9] = 2;
const png = Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);

const iconDir = path.join(dir, 'AppIcon.appiconset');
fs.mkdirSync(iconDir, { recursive: true });
fs.writeFileSync(path.join(iconDir, 'icon-1024.png'), png);
fs.writeFileSync(path.join(iconDir, 'Contents.json'), JSON.stringify({ images: [{ filename: 'icon-1024.png', idiom: 'universal', platform: 'ios', size: '1024x1024' }], info: { author: 'xcode', version: 1 } }, null, 2));
fs.writeFileSync(path.join(dir, 'Contents.json'), JSON.stringify({ info: { author: 'xcode', version: 1 } }, null, 2));
console.log('icon written', png.length, 'bytes');
