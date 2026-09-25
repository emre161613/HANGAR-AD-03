# HANGAR_AD_03

**Format:** 9:16 Instagram Reels, 1080×1920, 30 fps
**Süre:** 19,5 sn
**Çıktı:** `output/HANGAR_AD_03_v01.mp4`

Bu film bir tesis tanıtımı değil, bir marka filmi. Konusu araba kültürü, gece sürüşü, garaj ruhu ve mekanik karakter.

Başka hiçbir HANGAR projesine (HANGAR_TEASER_01–05 vb.) bağlı değildir, onlara dokunmaz.

## Değişmez kurallar

1. Hikâye sırası sabittir: karanlık → kontak/START → motorun uyanması → gerçek gösterge paneli → vites/pedal/direksiyon → gece yolculuğu → **YOLA ÇIKTIK.** → kısa karanlık → HANGAR → GEMLİK • 2026 → ÇOK YAKINDA.
2. Otomobil görüntüleri **gerçek çekimdir**: ücretsiz, yasal stok ya da kendi çekimimiz. Bulunamayan bir sahne yapay grafikle doldurulmaz.
3. Gösterge panelini sıfırdan kodla çizmek son tercihtir. Kod yalnızca gerçek görüntünün üstüne ışık, titreşim, motion blur, renk ve geçiş ekler.
4. Kodun işi kesmek, kadrajlamak, renk vermek, film dokusu eklemek, sesi miksleyip kapanışı yazmaktır. Kodun kendisi görsel malzeme olmaz. Şunlar yok: fotoğraf slaytı, bölünmüş ekran, kart sistemi, web animasyonu, HUD/oyun arayüzü.
5. Renk paleti siyah, fırçalanmış metal, koyu bordo ve kontrollü kırmızı/amber. Neon ya da cyberpunk yok.
6. Logo kullanıcıdan gelir. O gelene kadar nötr bir placeholder kullanılır, yeni logo tasarlanmaz.
7. Görsel yaklaşımda önemli bir değişiklik kullanıcı onayı olmadan yapılmaz.

## Yapı

```
config/timeline.json   sahne/zaman çizelgesi, grade, kapanış, ses olayları (tek doğruluk kaynağı)
config/assets.json     asset listesi: aday kaynaklar, lisans, durum (candidate/verified/gap/code)
tools/build.mjs        tüm filmi tek bir ffmpeg filtergraph olarak kurar (npm bağımlılığı yok)
assets/video/          V01…V10 klipleri   (git dışı — lisanslı stok)
assets/audio/sfx|music ses efektleri / müzik (git dışı)
assets/logo/           HANGAR_logo.png (kullanıcı yükleyecek)
assets/fonts/          HEADLINE.ttf / SECONDARY.ttf (opsiyonel, yoksa Liberation Sans)
docs/ASSET_PLAN.md     sahne bazında asset planı ve açık riskler
output/                render çıktıları (git dışı)
```

## Kullanım

```bash
node tools/build.mjs check             # ortam + eksik asset raporu
node tools/build.mjs plan --preview    # filtergraph'ı yaz (eksikler yazılı slate olur)
node tools/build.mjs render --preview  # taslak render (HANGAR_AD_03_v01_PREVIEW.mp4)
node tools/build.mjs render            # final — zorunlu asset eksikse REDDEDER
```

Gereksinimler: Node 18 veya üstü, `libx264` + `aac` + `drawtext` destekli ffmpeg (`FFMPEG=/yol/ffmpeg` ile de gösterilebilir).

## Render pipeline

1. **Sahne kurgusu:** her klip `timeline.json`'daki giriş noktası ve süreyle kesilir. 9:16'ya kırpılır, kırpma noktası `crop.cx/cy` ile ayarlanır. İsteğe bağlı yavaş bir optik yaklaşma (`push`) eklenir. Geçişler otomotiv reklamı diliyle sert kesmedir.
2. **Ortak renk düzenlemesi:** kontrast, siyahların ezilmesi, gölgede bordo, desatürasyon ve kırmızı halation. Vinyet eklenir.
3. **Kapanış:** siyah zemin üzerinde "YOLA ÇIKTIK." sert gelir. Ardından kısa karanlık boşluk, logo, GEMLİK • 2026 ve ÇOK YAKINDA. Kapanışa renk düzenlemesi uygulanmaz.
4. **Film dokusu:** tüm filme zamanla değişen grain uygulanır, sonunda siyaha kısa bir fade gelir.
5. **Ses:** SFX veriyolu öndedir. Müzik SFX'e göre sidechain ducking alır. 14,5 sn'de sert kesme olur, geriye yalnızca bir reverb kuyruğu kalır. Loudness hedefi -14 LUFS, true peak -1 dBTP.
