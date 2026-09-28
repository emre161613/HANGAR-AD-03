# HANGAR-AD-03 — Motion Graphic Stüdyosu

Bu depo bir motion graphic stüdyosudur. Aşağıdaki kurallar **kalıcıdır** ve her
oturumda, her video için geçerlidir. Kullanıcı açıkça aksini söylemedikçe esnetme.

## Araç: HyperFrames

- Bütün videolar **HyperFrames** ile yapılır (HTML kompozisyon → video). Başka
  bir render aracı (Remotion, After Effects script'i, elle ffmpeg animasyonu vb.)
  kullanma.
- Kurulum: `bash scripts/setup.sh` (HyperFrames + ffmpeg). Oturum başında hook
  ile otomatik çalışır. CLI sözdiziminden emin değilsen önce
  `npx hyperframes --help` ile doğrula; tahmin etme.
- Her video `videos/<video-adı>/` altında ayrı bir proje olur.
- Çıktı her zaman **MP4**'tür ve `renders/<video-adı>.mp4` olarak kaydedilir.

## Tasarım yasakları

1. **Ortalanmış yazı yasak.** Metin sola (veya bilinçli olarak sağa) hizalanır,
   ızgaraya oturur. `text-align: center`, flex/grid ile yatay+dikey ortalanmış
   başlık blokları kullanılmaz.
2. **Gradyan zemin yasak.** Zemin düz renk, fotoğraf/doku ya da grafik
   elemanlardan oluşur. `linear-gradient` / `radial-gradient` /
   `conic-gradient` arka plan olarak kullanılmaz.
3. **"Her şey yavaşça belirsin" yasak.** Elemanların tek tek opacity 0→1
   fade-in ile gelmesi yasak. Giriş hareketleri; kayma, maske/wipe, ölçek,
   kesme (hard cut), yazı yazılması gibi net, ritmik hareketlerle yapılır.
   Opacity animasyonu tek başına giriş efekti olamaz.

## İlk kare kuralı

- **İlk kare (t=0) açık renkli olmalı** — açık zemin (beyaz / krem / açık ton).
- **Başlık ilk karede okunur olmalı.** Başlık t=0'da ekranda, tam opak ve
  tam okunur konumda durur; giriş animasyonu başlığı gizleyerek başlamaz.

## Türkçe karakterler

- Kompozisyonda `<html lang="tr">` kullan (büyük harf dönüşümünde i→İ, ı→I
  doğru olsun diye).
- Yalnızca Türkçe glifleri (ı İ ş Ş ğ Ğ ü Ü ö Ö ç Ç) destekleyen fontlar
  kullan (latin-ext). Mümkünse fontu `videos/<ad>/fonts/` altına yerel koy;
  render sırasında ağdan font çekmeye güvenme.

## Her render'dan sonra zorunlu kontrol

Her MP4 üretildikten sonra, kullanıcıya "bitti" demeden önce:

1. `bash scripts/check-frames.sh renders/<video-adı>.mp4` çalıştır. Videodan
   eşit aralıklı **12 kare** çıkarır (1. kare = t=0) ve
   `renders/<video-adı>_frames/` altına kaydeder.
2. 12 karenin hepsini **Read ile tek tek aç ve kendin bak.** Kontrol listesi:
   - [ ] Kare 01 açık renkli mi, başlık okunuyor mu?
   - [ ] Türkçe karakterler (**ı, İ, ş, ğ** ve ü ö ç) doğru görünüyor mu?
         Kutu (tofu), yanlış glif, noktasız/noktalı i karışması yok mu?
   - [ ] Ortalanmış yazı yok mu?
   - [ ] Gradyan zemin yok mu?
   - [ ] Yarı saydam "fade ile beliren" eleman görünmüyor mu?
   - [ ] Taşan, kesilen, üst üste binen yazı yok mu?
3. Bir madde bile başarısızsa kompozisyonu düzelt, yeniden render al ve
   kontrolü baştan yap.
4. Kullanıcıya MP4 yolunu ve kısa kontrol sonucunu (madde madde) raporla.
