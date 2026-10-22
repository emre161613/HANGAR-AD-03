"""Alt kat yerleşim önerisi (çocuk odası, salon, L mutfak + bar) — SVG üretir.

Ölçüler cm cinsindendir; iç köşe (sol üst) = (0, 0). Plan ekran görüntüsünden tahmini:
iç genişlik 410, banyo ~195x195, koridor 200, çocuk odası ~200x362,
merdiven x 200-410 / y 386-602 (loft merdiven boşluğuyla aynı), salon 410x310.
Çizim yardımcıları loft alternatiflerinden alınır.
"""

import pathlib

import gen_loft_alternatifler as g
from gen_loft_alternatifler import (DIM, FURN, GLASS, GREEN, NEW, TXT, WALL, bed, hdim, line,
                                    rect, shower, sink, swing_door, text, vdim, vtext, wardrobe,
                                    wc, wet)

g.S, g.OX, g.OY = 1.05, 90, 110
g.LX, g.CW = 720, 1180
W, H = 410, 912          # iç genişlik, toplam iç derinlik
SALON_Y = 602            # salonun başladığı çizgi (merdiven altı)
X, Y, p, out = g.X, g.Y, g.p, g.out


def iwall(x, y, w, h):
    """Mevcut iç duvar (10 cm)."""
    rect(x, y, w, h, WALL, "#3a4350", 1)


def stool(cx, cy):
    out.append(f'<circle cx="{X(cx)}" cy="{Y(cy)}" r="{p(18)}" stroke="{FURN}" fill="none" stroke-width="1.2"/>')
    out.append(f'<circle cx="{X(cx)}" cy="{Y(cy)}" r="{p(12)}" stroke="{FURN}" fill="none" stroke-width="0.6"/>')


def base_cabinet(y, label, kind):
    """Sol duvardaki 60x60 tezgah modülü (y = üst kenar)."""
    rect(0, y, 60, 60, FURN, "none", 1.2)
    if kind == "hob":
        for dx, dy in ((15, 15), (45, 15), (15, 45), (45, 45)):
            out.append(f'<circle cx="{X(dx)}" cy="{Y(y + dy)}" r="{p(9)}" stroke="{FURN}" fill="none"/>')
    elif kind == "sink":
        out.append(f'<rect x="{X(8)}" y="{Y(y + 10)}" width="{p(40)}" height="{p(40)}" rx="{p(5)}" '
                   f'stroke="{FURN}" fill="none"/>')
        out.append(f'<circle cx="{X(28)}" cy="{Y(y + 30)}" r="2" fill="{FURN}"/>')
    elif kind == "drawer":
        for dy in (20, 40):
            line(4, y + dy, 56, y + dy, FURN, 0.6)
    elif kind == "fridge":
        rect(5, y + 5, 50, 50, GLASS, "none", 1)
        text(30, y + 34, "MB", 11, GLASS, weight="bold")
    text(66, y + 34, label, 9, TXT, anchor="start")


def build():
    out.clear()
    out.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{g.CW}" height="{g.CH}" '
               f'viewBox="0 0 {g.CW} {g.CH}" font-family="Arial, Helvetica, sans-serif">')
    out.append(f'<rect width="100%" height="100%" fill="{g.BG}"/>')
    out.append('<defs><pattern id="hatch" width="6" height="6" patternUnits="userSpaceOnUse" '
               'patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="6" '
               f'stroke="{WALL}" stroke-width="1"/></pattern>'
               '<pattern id="wet" width="16" height="16" patternUnits="userSpaceOnUse">'
               f'<rect width="16" height="16" fill="{g.FLOOR_WET}"/>'
               '<path d="M16 0 L0 0 0 16" fill="none" stroke="#33404e" stroke-width="1"/></pattern></defs>')
    text(W / 2 + 60, -62, "ALT KAT — ÇOCUK ODASI / SALON / L MUTFAK YERLEŞİMİ", 18, TXT, weight="bold")

    # ------------------------------------------------------------ dış duvarlar, kolonlar, cephe
    rect(-20, -20, W + 40, 20, WALL, "none", 1.2)
    rect(-20, 0, 20, H, WALL, "none", 1.2)
    rect(W, 0, 20, H, WALL, "none", 1.2)
    rect(-20, H, 25, 20, WALL, "none", 1.2)
    rect(W - 5, H, 25, 20, WALL, "none", 1.2)
    for dy in (0, 7, 13, 20):                       # cam cephe 400/250
        line(5, H + dy, W - 5, H + dy, FURN if dy in (7, 13) else WALL, 1)
    text(W / 2, H + 38, "CAM CEPHE 400/250", 11, DIM)
    for cx, cy in ((-22, -22), (W - 6, -22), (-22, 362), (W - 6, 362),
                   (-22, SALON_Y - 12), (W - 6, SALON_Y - 12), (-22, H - 6), (W - 6, H - 6)):
        rect(cx, cy, 28, 28, WALL, "url(#hatch)", 1.2)

    # bahçe merdiveni (dış)
    rect(W + 20, 386, 100, H - 386, DIM, "none", 0.8, 'stroke-dasharray="6 4"')
    for yy in range(406, H, 30):
        line(W + 20, yy, W + 120, yy, DIM, 0.5)
    vtext(W + 74, 650, "BAHÇE MERDİVENİ (dış)", 11, DIM)

    # ------------------------------------------------------------ mevcut iç duvarlar + kapılar
    iwall(200, 0, 10, 233)                          # banyo / çocuk odası — koridor
    iwall(200, 318, 10, 68)
    iwall(0, 195, 110, 10)                          # banyo alt duvarı
    iwall(190, 195, 10, 10)
    iwall(210, 362, 200, 10)                        # çocuk odası alt duvarı
    iwall(190, 386, 10, 111)                        # merdiven batı duvarı (üst kol)
    iwall(200, SALON_Y, 210, 10)                    # merdiven altı duvarı (TV duvarı)
    swing_door(210, 233, 85, 0, 90, "90/210", (250, 228))         # çocuk odası kapısı (içe)

    # ------------------------------------------------------------ banyo (mevcut)
    wet(0, 0, 200, 195)
    shower(0, 0, 80, 85, [(80, 0, 80, 85), (0, 85, 40, 85)], label_at=(40, 20))
    sink(120, 0, 70, 45, mirror=(122, 1, 188, 1))
    wc("right", 0, 140)
    text(130, 120, "BANYO", 13, TXT, weight="bold")
    text(130, 135, "3.8 m² (mevcut)", 9, DIM)
    swing_door(190, 205, 80, 270, 180, "80/210", (150, 225))      # banyo kapısı (içe)

    # ------------------------------------------------------------ merdiven (mevcut)
    rect(200, 386, 210, 216, FURN, "none", 1.2)
    for i, x in enumerate((200, 225, 250, 275, 300)):
        line(x, 497, x, SALON_Y, FURN, 1)
        if i < 4:
            text(x + 12, 590, str(i + 1), 9, FURN)
    for i, x in enumerate((300, 275, 250, 225, 200)):
        line(x, 386, x, 487, FURN, 1)
    line(200, 492, 330, 492, FURN, 1)
    for ex, ey in ((330, 386), (370, 386), (410, 420), (410, 492), (410, 560), (370, 602), (330, 602)):
        line(330, 492, ex, ey, FURN, 0.8)
    text(305, 450, "MERDİVEN (mevcut)", 10, DIM)
    text(228, 470, "15 x 18 = 270", 8, DIM)
    out.append(f'<path d="M{X(160)} {Y(585)} L{X(205)} {Y(585)}" stroke="{TXT}" stroke-width="1.2"/>')
    text(156, 588, "merdiven girişi", 8, TXT, anchor="end")

    # ------------------------------------------------------------ ÇOCUK ODASI
    text(262, 330, "ÇOCUK ODASI", 12, TXT, weight="bold")
    text(262, 345, "~7.3 m²", 9, DIM)
    bed(215, 0, 190, 90, "right", "YATAK 1")
    bed(320, 95, 90, 200, "top", "YATAK 2")
    wardrobe(300, 302, 110, 60)
    rect(215, 95, 100, 100, GREEN, "none", 0.8, 'stroke-dasharray="3 3"')
    text(265, 140, "oyun alanı", 9, GREEN)
    text(265, 153, "~1 x 1 m", 9, GREEN)

    # ------------------------------------------------------------ L MUTFAK + BAR
    out.append(f'<rect x="{X(0)}" y="{Y(470)}" width="{p(60)}" height="{p(300)}" fill="#2a3440"/>')
    base_cabinet(470, "DOLAP 1 + OCAK", "hob")
    base_cabinet(530, "DOLAP 2 (çekmeceli)", "drawer")
    base_cabinet(590, "DOLAP 3 + EVYE", "sink")
    base_cabinet(650, "MİNİ BUZDOLABI (tezgah altı)", "fridge")
    rect(0, 710, 60, 60, FURN, "none", 1.2)
    line(0, 710, 60, 770, FURN, 0.6)
    text(66, 744, "köşe", 9, TXT, anchor="start")
    # bar / yemek tezgahı: köşeden doğuya döner, tabla güneye 15 cm taşar
    rect(60, 710, 160, 75, FURN, "none", 1.6)
    line(60, 770, 220, 770, FURN, 0.6, 'stroke-dasharray="4 3"')
    text(140, 735, "BAR / YEMEK TEZGAHI", 10, TXT, weight="bold")
    text(140, 750, "160 x 75 · h:90", 9, TXT)
    for cx in (85, 140, 195):
        stool(cx, 808)
    text(140, 845, "3 bar taburesi", 9, DIM)
    line(0, 470, 0, 710, FURN, 0)
    rect(0, 470, 35, 240, FURN, "none", 0.6, 'stroke-dasharray="8 4"')   # üst dolaplar
    text(17, 462, "üst dolap", 8, DIM)
    rect(0, 240, 40, 200, DIM, "none", 0.8, 'stroke-dasharray="5 4"')
    vtext(24, 340, "boy dolabı / vestiyer (ops.)", 9, DIM)
    text(125, 448, "MUTFAK", 13, TXT, weight="bold")
    vdim(612, 710, 176, "~100")

    # ------------------------------------------------------------ SALON: TV + L KOLTUK
    rect(257, 612, 120, 38, FURN, "none", 1.4)
    text(317, 636, "TV ÜNİTESİ 120x40", 9, TXT)
    rect(287, 610, 60, 4, GLASS, GLASS, 0.5)
    # L koltuk: uzun kol güney (cephe önü), kısa kol sağ duvar boyunca
    pts = [(225, 820), (320, 820), (320, 660), (410, 660), (410, 910), (225, 910)]
    d = "M" + " L".join(f"{X(a)} {Y(b)}" for a, b in pts) + " Z"
    out.append(f'<path d="{d}" stroke="{FURN}" fill="none" stroke-width="1.8"/>')
    inner = [(235, 830), (330, 830), (330, 670), (395, 670), (395, 895), (235, 895)]
    d = "M" + " L".join(f"{X(a)} {Y(b)}" for a, b in inner) + " Z"
    out.append(f'<path d="{d}" stroke="{FURN}" fill="none" stroke-width="0.8"/>')
    for yy in (720, 775):
        line(330, yy, 395, yy, FURN, 0.6)
    for xx in (285,):
        line(xx, 830, xx, 895, FURN, 0.6)
    text(300, 870, "L KOLTUK 250 x 185", 11, TXT, weight="bold")
    line(317, 652, 317, 818, GREEN, 0.8, 'stroke-dasharray="4 4"')
    text(310, 745, "izleme ~2 m", 9, GREEN, anchor="end")
    rect(232, 720, 70, 80, DIM, "none", 0.6, 'stroke-dasharray="2 4"')
    text(267, 764, "halı", 8, DIM)
    text(110, 885, "SALON", 14, TXT, weight="bold")
    text(110, 900, "giriş / cephe önü geçiş", 9, DIM)
    hdim(220, 320, 700, "100")

    # ------------------------------------------------------------ ölçüler
    hdim(0, W, -36, "410")
    vdim(0, 362, -48, "~362")
    vdim(SALON_Y, H, -48, "310")

    g.legend([
        "YERLEŞİM",
        "",
        "ÇOCUK ODASI",
        "• 2 yatak L düzende: üst duvarda 90x190,",
        "  sağ duvarda 90x200 → ortada oyun alanı.",
        "• Gardırop 110x60 alt duvarda, kapı",
        "  açılışına çarpmıyor.",
        "",
        "MUTFAK (L)",
        "• Sol duvar: Dolap1+ocak · Dolap2 çekmece",
        "  · Dolap3+evye · Mini buzdolabı (tezgah altı)",
        "• Köşeden BAR döner: 160 cm, 3 tabure,",
        "  yemek masası yerine kullanılır.",
        "• Bar ile merdiven arası ~100 cm geçiş.",
        "",
        "SALON",
        "• L koltuk sağ alt köşede, TV merdiven",
        "  altı duvarında; izleme mesafesi ~2 m.",
        "• Bar ile koltuk arası 100 cm ana geçiş.",
        "",
        "DİKKAT",
        "• Evye mevcut yerinden ~2.5 m aşağı kayıyor",
        "  → su/gider hattı uzatılmalı.",
        "• Ocak üstüne aspiratör (salon açık).",
        "• Çocuk odası genişliği tahmini ~200 →",
        "  1. yatak 90x190. Daha fazla yer: RANZA.",
        "• Ölçüler ekran görüntüsünden tahminidir.",
    ], ("YERLEŞİM", "ÇOCUK ODASI", "MUTFAK (L)", "SALON", "DİKKAT"))
    out.append("</svg>")
    return "\n".join(out)


if __name__ == "__main__":
    path = pathlib.Path(__file__).with_name("alt_kat_yerlesim.svg")
    path.write_text(build(), encoding="utf-8")
    print(path)
