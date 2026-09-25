# HANGAR_AD_03 — Asset planı

**Durum:** tüm video adayları web aramasıyla belirlendi ama **görsel olarak doğrulanmadı**. Bu cloud ortamından pexels.com ve freesound.org erişimi engelli, klipler izlenemedi ve indirilemedi. Kesin liste ve lisans bilgisi `config/assets.json` dosyasındadır.

## Seçim kriterleri (her klip için)

- Gerçek çekim olmalı. CGI veya render görünümlü klip kabul edilmez.
- Gece ya da düşük ışık, karanlık ton.
- **Yatay klipte en az 4K kaynak.** 9:16 kırpımda 1080p kaynak 607 px genişliğe düşer ve yumuşar. Dikey 1080p kaynak yeterlidir.
- Kadrajda okunabilir marka logosu ya da plaka olmamalı (Pexels lisansı ticari marka kullanımını kapsamaz). Olursa kırpılarak çıkarılır.
- Dijital ekranlı modern kokpit olmamalı. Retro-mekanik dil gerekir.
- Renkli LED veya neon ağırlıklı görüntü olmamalı.

## Sahne bazında

| Sahne | Slot | Aday | Durum / risk |
|---|---|---|---|
| S01 START (1.2–2.4) | V01 | Pexels 4707144 · 6636563 · 6421467 (anahtarlı kontak) | Aday var. 6421467 retro karaktere daha yakın olabilir. |
| S02 Gösterge uyanışı (2.4–4.0) | V02 | Pexels 3752531 · 6312479 | ⚠️ Analog ibrenin "sweep" açılışını gösteren klip doğrulanamadı. Klip ibreyi gösterip açılışı göstermiyorsa açılış ışığını kod ekleyebilir (gerçek görüntünün üstüne, kural 3). |
| S03 Devir ibresi (4.0–5.5) | V03 | Pexels 3752531 (farklı bölüm) | Aday var. İbre hareketi klipte yoksa yalnızca kamera titreşimi ve ışık eklenir, ibre çizilmez. |
| S04 Vites (5.5–6.5) | V04 | Pexels 4707185 · 4118546 | Aday var. |
| S05 Pedal (6.5–7.3) | V05 | — | ❌ **Boşluk.** Somut aday bulunamadı. Grafikle doldurulmayacak. Seçenekler: (a) kullanıcı çekimi, (b) Pexels "gas pedal" araması tarayıcıdan elle taranır, (c) sahne kısaltılıp süre S04/S06'ya verilir (onay gerekir). |
| S06 Direksiyon (7.3–8.5) | V06 | Pexels 8388280 (gece) · 5520046 | Aday var. |
| S07 Islak asfalt (8.5–10.0) | V07 | Pexels 6408465 · 31940805 | Aday var. Asıl hedef çok alçak açıdır, doğrulanmalı. |
| S08 Kırmızı yansıma (10.0–11.5) | V08 | Pexels 11785816 · 30169690 | ⚠️ Zayıf. Stop lambası detay videosu yok, bulunanlar fotoğraf. Renkler neon'a kaçıyorsa reddedilir. |
| S09 Ön cam (11.5–13.0) | V09 | Pexels 29900067 · 12680281 · 15283975 | Aday güçlü. |
| S10 Hız / tünel (13.0–14.5) | V10 | Pexels 31196468 · 28267046 | Aday var. 33938671 renkli ışık nedeniyle reddedildi. |

## Ses

| Slot | Aday | Durum |
|---|---|---|
| Marş + çalışma | Freesound 328122 (1984 Mercedes) · 50897 · 379914 (CC0) | Lisanslar doğrulanacak |
| Rölanti / devir | Freesound 232272 (Lotus, CC BY 4.0) | Künye zorunlu |
| Kontak kliği, vites, yükte motor, yol, silecek, anahtar, egzoz tıkırtısı | — | Aranacak (Freesound CC0 öncelikli) |
| Oda tonu, final impact, müzik altyapısı | Kodla üretilecek | Onaylı yöntem |

## Marka

- **Logo:** kullanıcı yükleyecek. Tercihen SVG ve şeffaf PNG, açık renkli varyant. `assets/logo/HANGAR_logo.png`.
- **Font:** kurumsal font varsa `assets/fonts/` klasörüne konur. Yoksa placeholder olarak Liberation Sans kullanılır. Final için bir kondanse grotesk önerilir (OFL lisanslı, örneğin Barlow Condensed).
