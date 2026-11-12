// Local preview server for Lumo Hop: wraps index.html in a page skeleton.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const dir = path.dirname(fileURLToPath(import.meta.url));
http.createServer((req, res) => {
  const body = fs.readFileSync(path.join(dir, 'index.html'), 'utf8');
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end('<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><style>body{margin:0}[hidden]{display:none!important}</style></head><body>' + body + '</body></html>');
}).listen(4173, () => console.log('Lumo Hop on http://localhost:4173'));
