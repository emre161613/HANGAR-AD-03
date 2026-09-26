# HANGAR_AD_03

**Format:** 9:16 Instagram Reels, 1080×1920, 30 fps, 19,5 sn, H.264 MP4
**Çıktı:** `output/HANGAR_AD_03_v01.mp4`

Tamamen kodla üretilmiş, programatik ve sinematik bir otomotiv reklam filmi. Stok video, stok fotoğraf ya da yapay zekâyla üretilmiş görsel **yoktur**. Her kare WebGL2 ile gerçek zamanlı 3D ışın yürütme (SDF raymarching ve analitik kesişimler) kullanılarak render edilir, her ses kodla sentezlenir.

## Akış

| Zaman | Sahne |
|---|---|
| 0,0 – 2,6 | Tam karanlık. START düğmesinin krom çerçevesine ışık yalar. Ağır bir basış ve mekanik klik, ardından marş motoru ve motorun ateşlenmesi. |
| 2,6 – 3,4 | Panel uyanır: röle tıkları, ikaz lambaları, toggle anahtarlar. |
| 3,4 – 7,2 | Gösterge paneli, kahraman devir saati. Arka ışık titreyerek yanar, ibre self-test turu atar, sesle senkron gaz vuruşları olur. Kamera çapraz açılar değiştirir ve göbeğe dalar. |
| 7,2 – 10,0 | Mekanik dünya: kanallı H vites kapısı, N→1 vites geçişi, dönen dişli takımı, delikli gaz pedalı. Ortamda duman var. |
| 10,0 – 14,2 | Gece sürüşü: asfalt seviyesinden kalkan kamera, ıslak asfalt, şeritler, sodyum lambalar, bariyer, kırmızı reflektörler, önde giden araçların stop lambaları, sollama, vites büyütme. |
| 14,2 – 14,6 | Devir saati kırmızı bölgede, rev-limiter vuruşları. |
| 14,6 | SERT KESME: siyah ekran ve sessizlik (yalnızca reverb kuyruğu). |
| 15,0 – 16,4 | **YOLA ÇIKTIK.** ve bas darbesi. |
| 16,4 – 17,0 | Karanlık ve sessizlik. |
| 17,0 – 19,5 | HANGAR (logo **placeholder**), GEMLİK • 2026, ÇOK YAKINDA. |

## Yapı

```
src/timeline.js     tek zaman kaynağı: işaret noktaları (cue), devir/gaz/hız eğrileri, ibre yay fiziği
src/director.js     her t için kamera yolu, sarsıntılar, ışık/animasyon parametreleri
src/shaders/        dash (panel), mech (vites/dişli/pedal), road (gece yolu), end (yazı), post
src/textures.js     gösterge kadranları, START gravürü ve final tipografisi (Canvas2D → doku)
src/main.js         render hattı: motion blur (alt-kare birikimi), DOF, bloom, ton eşleme, grain
tools/render.mjs    headless Chromium ile kare render
tools/audio.mjs     ses tasarımı: V8 ateşleme modeli, marş, klikler, vites, yol, darbe, müzik
tools/sheet.mjs     test kareleri için kontak föy
assets/fonts/       Liberation Sans (SIL OFL 1.1)
render.json         değiştirildiğinde GitHub Actions final render alır
```

## Kullanım

```bash
node tools/render.mjs --frames 60,140,330 --out test_frames --scale 0.5 --sub 1   # hızlı test kareleri
node tools/render.mjs --out output/frames --jpg                                    # tüm kareler
node tools/audio.mjs output/audio.wav                                              # ses
ffmpeg -framerate 30 -i output/frames/%04d.jpg -i output/audio.wav -c:v libx264 -crf 16 \
  -pix_fmt yuv420p -af loudnorm=I=-14:TP=-1:LRA=11 -c:a aac -b:a 320k -movflags +faststart output/HANGAR_AD_03_v01.mp4
```

Final render GitHub Actions'ta çalışır (`.github/workflows/hangar-ad-03.yml`). Kareler 8 paralel işte render edilir, ardından ses sentezlenir, H.264 + AAC olarak kodlanır ve MP4 bu dala commit edilir.

## Logo

`src/textures.js` içindeki `drawEndcard` fonksiyonu şu an nötr, kesik çizgili bir çerçeve ve "HANGAR LOGO / PLACEHOLDER" etiketi çiziyor. Gerçek logo `assets/logo/` klasörüne geldiğinde bu alanın yerine konacak.
