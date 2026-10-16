// Zemin SVG + WebGL parça katmanını Chromium'da birleştirip 2160x2160 PNG üretir,
// ardından Facebook daire kırpma önizlemesi çıkarır.
import { chromium } from "playwright";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const dir = dirname(fileURLToPath(import.meta.url));
const parca = readFileSync(join(dir, "parca_profil.json"), "utf8");
const parcaJs = readFileSync(join(dir, "parca.js"), "utf8");

// Kamera / sahne ayarları
const KAMERA = {
  goz: [1.1, 2.1, 4.9],
  hedef: [0.0, 0.02, 0],
  donus: -24,          // parçanın Y ekseni etrafında dönüşü (derece)
  fov: 30,
  derinlik: 1.15,      // ekstrüzyon boyu (parça genişliği = 2)
  kalinlikCarpani: 4,  // gerçek 10 birimlik kalınlık logoda görünsün diye 4 kat
  tow: 0.034,          // karbon örgü hücresi
};

const outputs = [
  ["zemin.svg", "profil-3d-kompozit.png"],
  ["zemin-slogan.svg", "profil-3d-kompozit-slogan.png"],
];

const browser = await chromium.launch({ args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"] });
const page = await browser.newPage({ viewport: { width: 1080, height: 1080 }, deviceScaleFactor: 2 });
page.on("pageerror", (e) => console.error("Sayfa hatası:", e.message));

for (const [svgName, pngName] of outputs) {
  const svg = readFileSync(join(dir, svgName), "utf8");
  await page.setContent(`<html><body style="margin:0;position:relative;width:1080px;height:1080px">
    ${svg}
    <canvas id="parca" width="2160" height="1400" style="position:absolute;left:0;top:0;width:1080px;height:700px"></canvas>
    <script>window.PARCA=${parca};window.KAMERA=${JSON.stringify(KAMERA)};</script>
    <script>${parcaJs}</script>
  </body></html>`);
  await page.waitForFunction(() => window.PARCA_HAZIR === true);
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: join(dir, pngName), clip: { x: 0, y: 0, width: 1080, height: 1080 } });
}

// Facebook'ta nasıl görüneceği: daire kırpma, büyük ve küçük boy
const imgs = outputs.map(([, p]) => readFileSync(join(dir, p)).toString("base64"));
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
