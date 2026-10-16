// SVG'leri Chromium ile PNG'ye çevirir (2160x2160) ve daire kırpma önizlemesi üretir.
import { chromium } from "playwright";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const dir = dirname(fileURLToPath(import.meta.url));
const names = ["profil-3d-kompozit", "profil-3d-kompozit-slogan"];

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1080, height: 1080 }, deviceScaleFactor: 2 });

for (const name of names) {
  const svg = readFileSync(join(dir, `${name}.svg`), "utf8");
  await page.setContent(`<html><body style="margin:0">${svg}</body></html>`);
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: join(dir, `${name}.png`), clip: { x: 0, y: 0, width: 1080, height: 1080 } });
}

// Facebook'ta nasıl görüneceği: daire kırpma, büyük ve küçük boy
const imgs = names.map((n) => readFileSync(join(dir, `${n}.png`)).toString("base64"));
await page.setViewportSize({ width: 1080, height: 520 });
await page.setContent(`<html><body style="margin:0;background:#f0f2f5;font-family:Inter;display:flex;gap:40px;padding:40px;align-items:center">
  ${imgs.map((b) => `
    <div style="display:flex;flex-direction:column;align-items:center;gap:16px">
      <img src="data:image/png;base64,${b}" style="width:340px;height:340px;border-radius:50%;border:5px solid #fff;box-shadow:0 2px 8px rgba(0,0,0,.2)">
      <div style="display:flex;gap:14px;align-items:center">
        <img src="data:image/png;base64,${b}" style="width:60px;height:60px;border-radius:50%">
        <img src="data:image/png;base64,${b}" style="width:40px;height:40px;border-radius:50%">
        <span style="color:#050505;font-weight:600">3D Kompozit</span>
      </div>
    </div>`).join("")}
</body></html>`);
await page.waitForTimeout(300);
await page.screenshot({ path: join(dir, "onizleme-facebook.png") });

await browser.close();
console.log("PNG'ler hazır.");
