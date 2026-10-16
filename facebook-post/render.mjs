// slaytlar.html içindeki her slaytı 1080x1350 (4:5) PNG olarak kaydeder (1.5x = 1620x2025).
import { chromium } from "playwright";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const dir = dirname(fileURLToPath(import.meta.url));
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1080, height: 1350 }, deviceScaleFactor: 1.5 });
await page.goto(pathToFileURL(join(dir, "slaytlar.html")).href);
await page.evaluate(() => document.fonts.ready);
await page.waitForLoadState("networkidle");

const ids = await page.$$eval(".slide", (els) => els.map((e) => e.id));
for (const [i, id] of ids.entries()) {
  // Taşma kontrolü: içerik slayt yüksekliğini aşıyorsa uyar
  const over = await page.$eval(`#${id}`, (el) => el.scrollHeight - el.clientHeight);
  if (over > 0) console.warn(`UYARI: ${id} ${over}px taşıyor`);
  await page.locator(`#${id}`).screenshot({ path: join(dir, `slayt-${i + 1}.png`) });
}
await browser.close();
console.log(`${ids.length} slayt kaydedildi.`);
