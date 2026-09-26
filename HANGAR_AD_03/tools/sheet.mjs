#!/usr/bin/env node
// Contact sheet from rendered frames (no ffmpeg/PIL needed): node tools/sheet.mjs out.png cols f1.png f2.png ...
import fs from 'node:fs';
import path from 'node:path';
const [outFile, colsArg, ...files] = process.argv.slice(2);
let chromium;
for (const c of [process.env.PLAYWRIGHT_MODULE, 'playwright', 'playwright-core', '/opt/node22/lib/node_modules/playwright/index.mjs'].filter(Boolean)) { try { const m = await import(c); chromium = m.chromium || m.default.chromium; break; } catch {} }
const b = await chromium.launch();
const p = await b.newPage();
const imgs = files.map((f) => ({ name: path.basename(f), data: 'data:image/png;base64,' + fs.readFileSync(f).toString('base64') }));
const data = await p.evaluate(async ({ imgs, cols }) => {
  const els = await Promise.all(imgs.map((m) => new Promise((r) => { const i = new Image(); i.onload = () => r(i); i.src = m.data; })));
  const w = 360, h = Math.round(w * els[0].height / els[0].width), rows = Math.ceil(els.length / cols);
  const c = document.createElement('canvas'); c.width = cols * w + (cols - 1) * 6; c.height = rows * h + (rows - 1) * 6;
  const g = c.getContext('2d'); g.fillStyle = '#333'; g.fillRect(0, 0, c.width, c.height);
  els.forEach((e, k) => { const x = (k % cols) * (w + 6), y = Math.floor(k / cols) * (h + 6); g.drawImage(e, x, y, w, h); g.fillStyle = '#ff0'; g.font = 'bold 20px sans-serif'; g.fillText(imgs[k].name, x + 8, y + 26); });
  return c.toDataURL('image/png');
}, { imgs, cols: Number(colsArg) });
fs.writeFileSync(outFile, Buffer.from(data.split(',')[1], 'base64'));
await b.close();
