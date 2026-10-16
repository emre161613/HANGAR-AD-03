// Kapak SVG'sini 3280x1848 PNG'ye çevirir ve masaüstü / mobil Facebook önizlemesi üretir.
import { chromium } from "playwright";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const dir = dirname(fileURLToPath(import.meta.url));
const W = 1640, H = 924;
// Önizlemede kullanılacak profil resmi (varsa ilk argüman, yoksa repodaki sloganlı sürüm)
const profilPath = process.argv[2] ?? join(dir, "profil-3d-kompozit-slogan.png");
const profilMime = profilPath.endsWith(".webp") ? "image/webp" : "image/png";

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 2 });

const svg = readFileSync(join(dir, "kapak-3d-kompozit.svg"), "utf8");
await page.setContent(`<html><body style="margin:0">${svg}</body></html>`);
await page.evaluate(() => document.fonts.ready);
// Başlığın gerçek genişliğini raporla (ölçü çizgisi hizası için)
const titleW = await page.evaluate(() => [...document.querySelectorAll("text")].find((t) => t.querySelector("tspan")).getBBox().width);
console.log("Başlık genişliği:", titleW.toFixed(1));
await page.screenshot({ path: join(dir, "kapak-3d-kompozit.png"), clip: { x: 0, y: 0, width: W, height: H } });

const cover = readFileSync(join(dir, "kapak-3d-kompozit.png")).toString("base64");
const prof = readFileSync(profilPath).toString("base64");
// Masaüstü: 820x312 görünür alan (yüksekliğin ortası); mobil: 16:9 tamamı
await page.setViewportSize({ width: 1000, height: 820 });
await page.setContent(`<html><body style="margin:0;background:#f0f2f5;font-family:Inter;padding:30px;display:flex;flex-direction:column;gap:18px">
  <div style="font-weight:700;color:#65676b;font-size:15px">MASAÜSTÜ</div>
  <div style="position:relative;width:820px;height:390px">
    <div style="width:820px;height:312px;border-radius:0 0 8px 8px;overflow:hidden;background:url(data:image/png;base64,${cover}) center/820px auto no-repeat"></div>
    <img src="data:${profilMime};base64,${prof}" style="position:absolute;left:24px;top:232px;width:150px;height:150px;border-radius:50%;border:4px solid #fff">
    <div style="position:absolute;left:192px;top:326px;font-size:26px;font-weight:700;color:#050505">3D Kompozit</div>
  </div>
  <div style="font-weight:700;color:#65676b;font-size:15px">MOBİL</div>
  <div style="width:360px;height:203px;background:url(data:image/png;base64,${cover}) center/cover no-repeat;border-radius:6px"></div>
</body></html>`);
await page.waitForTimeout(300);
await page.screenshot({ path: join(dir, "kapak-onizleme.png") });

await browser.close();
console.log("Kapak hazır.");
