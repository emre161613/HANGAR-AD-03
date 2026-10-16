"""PDF sayfalarından (220 dpi PNG) post görsellerini kırpar.
Koordinatlar 1168 px genişlikteki sayfa görünümüne göre; k ile ölçeklenir."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

src = Path(sys.argv[1])          # pdftoppm çıktısı klasörü (s-01.png ...)
out = Path(__file__).parent / "img"
out.mkdir(exist_ok=True)

def page(n):
    return Image.open(src / f"s-{n:02d}.png").convert("RGB")

k = page(1).width / 1168

def crop(n, box, name, white=()):
    im = page(n)
    d = ImageDraw.Draw(im)
    for wb in white:  # kişisel/ilgisiz notları gizle
        d.rectangle([int(v * k) for v in wb], fill="white")
    im.crop(tuple(int(v * k) for v in box)).save(out / f"{name}.png", optimize=True)

crop(1, (117, 327, 586, 438), "render-gunduz")
crop(14, (56, 345, 587, 465), "render-gece")
crop(2, (30, 86, 990, 336), "panel-tanim")
crop(7, (38, 76, 1135, 312), "acilim-u40")
crop(8, (38, 82, 1095, 500), "acilim-u40t")
# Tabaka yerleşimi: iki sütunu aradaki boşluk olmadan yan yana birleştir
crop(4, (45, 76, 340, 312), "_sol")
crop(4, (605, 76, 900, 312), "_sag")
sol, sag = Image.open(out / "_sol.png"), Image.open(out / "_sag.png")
gap = int(24 * k)
birlesik = Image.new("RGB", (sol.width + gap + sag.width, sol.height), "white")
birlesik.paste(sol, (0, 0)); birlesik.paste(sag, (sol.width + gap, 0))
birlesik.save(out / "tabaka-ust.png", optimize=True)
(out / "_sol.png").unlink(); (out / "_sag.png").unlink()
crop(5, (60, 160, 1112, 760), "doseme-plan", white=[(490, 225, 870, 340)])
crop(13, (120, 138, 790, 735), "aydinlatma-kesit")
print("ok", k)
