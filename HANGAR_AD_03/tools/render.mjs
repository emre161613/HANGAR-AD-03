#!/usr/bin/env node
// Render frames with headless Chromium (WebGL2).
//   node tools/render.mjs --frames 0,45,120 --out test_frames [--scale 0.5] [--sub 1]
//   node tools/render.mjs --range 0:585 --out output/frames
// Env: CHROME_PATH (optional executable), PLAYWRIGHT_MODULE (optional module path)
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = Object.fromEntries(process.argv.slice(2).reduce((a, x, i, all) => (x.startsWith('--') ? [...a, [x.slice(2), all[i + 1] && !all[i + 1].startsWith('--') ? all[i + 1] : true]] : a), []));
const out = path.resolve(ROOT, args.out || 'test_frames');
fs.mkdirSync(out, { recursive: true });

async function loadPlaywright() {
  const cands = [process.env.PLAYWRIGHT_MODULE, 'playwright', 'playwright-core', '/opt/node22/lib/node_modules/playwright/index.mjs'].filter(Boolean);
  for (const c of cands) { try { const m = await import(c); return m.chromium || m.default.chromium; } catch {} }
  throw new Error('playwright not found');
}

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.ttf': 'font/ttf', '.png': 'image/png', '.json': 'application/json' };
const server = http.createServer((req, res) => {
  const p = path.join(ROOT, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (!p.startsWith(ROOT) || !fs.existsSync(p) || fs.statSync(p).isDirectory()) { res.statusCode = 404; return res.end('nf'); }
  res.setHeader('content-type', MIME[path.extname(p)] || 'application/octet-stream');
  fs.createReadStream(p).pipe(res);
}).listen(0);
const port = server.address().port;

const chromium = await loadPlaywright();
const browser = await chromium.launch({
  executablePath: process.env.CHROME_PATH || undefined,
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--disable-gpu-watchdog', '--disable-renderer-backgrounding'],
});
const page = await browser.newPage({ viewport: { width: 400, height: 700 } });
page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') console.log('[page]', m.text()); });
page.setDefaultTimeout(0);
const q = new URLSearchParams();
if (args.scale) q.set('scale', args.scale);
if (args.sub) q.set('sub', args.sub);
await page.goto(`http://localhost:${port}/src/index.html?${q}`);
const status = await page.evaluate(() => window.ready);
if (status !== 'ok') { console.error(status); await browser.close(); server.close(); process.exit(1); }
const total = await page.evaluate(() => window.FRAMES);

let frames;
if (args.frames) frames = String(args.frames).split(',').map(Number);
else { const [a, b] = String(args.range || `0:${total}`).split(':').map(Number); frames = Array.from({ length: b - a }, (_, k) => a + k); }
// interleaved split for parallel jobs: --part k --parts n
if (args.parts) frames = frames.filter((f) => f % Number(args.parts) === Number(args.part));
const fmt = args.jpg ? 'jpeg' : 'png';

const t0 = Date.now();
for (const f of frames) {
  const s = Date.now();
  const info = await page.evaluate((i) => window.renderFrame(i), f);
  const data = await page.evaluate((m) => document.getElementById('c').toDataURL(`image/${m}`, 0.98), fmt);
  fs.writeFileSync(path.join(out, `${String(f).padStart(4, '0')}.${fmt === 'jpeg' ? 'jpg' : 'png'}`), Buffer.from(data.split(',')[1], 'base64'));
  console.log(`frame ${f} t=${info.t.toFixed(3)} ${info.scene} ${Date.now() - s}ms`);
}
console.log(`done ${frames.length} frames in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
await browser.close();
server.close();
