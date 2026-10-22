"""5 loft yerleşim alternatifini tek sayfada yan yana gösteren karşılaştırma SVG'si üretir.

Önce her alternatifin PNG'si üretilmiş olmalı (loft_yerlesim.png, loft_yerlesim_v2..v5.png);
SVG bu PNG'lere göreli yolla bağlanır, PNG'ye çevirmek için tarayıcıda render edilir.
"""

import pathlib

BG = "#212830"
TXT = "#e8e8e8"
DIM = "#8a93a0"
GREEN = "#7fe08a"
WARN = "#f0c080"

CW, CH = 1500, 1150
TW, TH = 470, 510               # küçük resim boyutu
CROP = (40, 30, 1050, 1140)     # her PNG'den alınan plan bölgesi (x, y, w, h)

ALTS = [
    ("loft_yerlesim.png", "V1 · Kapalı banyo + köşe jakuzi", False),
    ("loft_yerlesim_v2.png", "V2 · Manzaraya bakan açık jakuzi", False),
    ("loft_yerlesim_v3.png", "V3 · Yatak manzaraya bakar", True),
    ("loft_yerlesim_v4.png", "V4 · Jakuzi pencere önünde", False),
    ("loft_yerlesim_v5.png", "V5 · Kapalı spa banyo", False),
]

ROWS = [
    ("V1", "Jakuzi köşede, banyoyla birlikte; cam bölme", "Banyo 5.4 m² · jakuzide manzara zayıf"),
    ("V2", "Jakuzi manzara köşesinde, yanları açık", "Banyo 2.1 m² (küçük) · buhar yatağa gelir"),
    ("V3", "Jakuzi manzarada + yatak manzaraya bakar", "Banyo 3 m² · iki ayrı tesisat hattı"),
    ("V4", "Jakuzi boydan pencerenin önünde", "Banyo 2.3 m² · yatak tek taraftan inişli"),
    ("V5", "Her şey kapalı spa banyoda, oda kuru", "Banyo 5.7 m² · jakuzide manzara YOK"),
]


def build():
    sx, sy = TW / CROP[2], TH / CROP[3]
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
         f'width="{CW}" height="{CH}" viewBox="0 0 {CW} {CH}" font-family="Arial, Helvetica, sans-serif">',
         f'<rect width="100%" height="100%" fill="{BG}"/>',
         f'<text x="{CW / 2}" y="40" font-size="22" font-weight="bold" fill="{TXT}" text-anchor="middle">'
         'LOFT KAT — TÜM YERLEŞİM ALTERNATİFLERİ</text>']
    cells = [(20 + c * (TW + 25), 80 + r * (TH + 45)) for r in range(2) for c in range(3)]
    for (png, title, best), (x, y) in zip(ALTS, cells):
        o.append(f'<svg x="{x}" y="{y}" width="{TW}" height="{TH}" '
                 f'viewBox="{CROP[0]} {CROP[1]} {CROP[2]} {CROP[3]}">'
                 f'<image href="{png}" xlink:href="{png}" width="1480" height="1180"/></svg>')
        o.append(f'<rect x="{x + 1}" y="{y + 1}" width="{TW - 2}" height="44" fill="{BG}"/>')
        o.append(f'<rect x="{x}" y="{y}" width="{TW}" height="{TH}" fill="none" '
                 f'stroke="{GREEN if best else "#3a4552"}" stroke-width="{3 if best else 1}"/>')
        o.append(f'<text x="{x + TW / 2}" y="{y + TH + 24}" font-size="16" font-weight="bold" '
                 f'fill="{GREEN if best else TXT}" text-anchor="middle">{title}{"  ★ ÖNERİM" if best else ""}</text>')

    x, y = cells[5]
    o.append(f'<text x="{x}" y="{y + 18}" font-size="17" font-weight="bold" fill="{TXT}">KARŞILAŞTIRMA</text>')
    yy = y + 52
    for k, plus, minus in ROWS:
        col = GREEN if k == "V3" else TXT
        o.append(f'<text x="{x}" y="{yy}" font-size="15" font-weight="bold" fill="{col}">{k}</text>')
        o.append(f'<text x="{x + 40}" y="{yy}" font-size="13" fill="{TXT}">+ {plus}</text>')
        o.append(f'<text x="{x + 40}" y="{yy + 19}" font-size="13" fill="{WARN}">– {minus}</text>')
        yy += 58
    notes = [
        "Önerim V3: jakuzi de yatak da manzaraya bakıyor,",
        "banyo rahat (klozet önü 85 cm), geçişler 80+ cm.",
        "Buhar istemiyorsan V5, en büyük banyo için V1.",
        "Ölçüler ekran görüntüsünden tahminidir.",
    ]
    for i, n in enumerate(notes):
        o.append(f'<text x="{x}" y="{yy + 6 + i * 19}" font-size="12" '
                 f'fill="{DIM if i == 3 else TXT}">{n}</text>')
    o.append("</svg>")
    return "\n".join(o)


if __name__ == "__main__":
    path = pathlib.Path(__file__).with_name("loft_alternatifler_hepsi.svg")
    path.write_text(build(), encoding="utf-8")
    print(path)
