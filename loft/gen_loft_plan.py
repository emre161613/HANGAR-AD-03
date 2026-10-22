"""Loft kat yerleşim önerisi (yatak + banyo + jakuzi) — SVG üretir.

Ölçüler cm cinsindendir; iç köşe (sol üst) = (0, 0).
Mevcut plan ekran görüntüsünden tahmini: iç genişlik ~410, merdivene kadar derinlik ~375.
"""

S = 2.0          # px / cm
OX, OY = 110, 150  # çizim orijini (px)
W, D = 410, 375    # iç genişlik, merdiven kenarına kadar derinlik
CUT = 485          # görünen alt sınır

BG = "#212830"
WALL = "#d6d6d6"
FURN = "#e0a462"
NEW = "#ff5a5a"
GLASS = "#5cc8ff"
DIM = "#8a93a0"
TXT = "#e8e8e8"
FLOOR_WET = "#2a3440"

out = []


def p(v):
    return round(v * S, 1)


def X(x):
    return round(OX + x * S, 1)


def Y(y):
    return round(OY + y * S, 1)


def rect(x, y, w, h, stroke=FURN, fill="none", sw=1.4, extra=""):
    out.append(f'<rect x="{X(x)}" y="{Y(y)}" width="{p(w)}" height="{p(h)}" '
               f'stroke="{stroke}" fill="{fill}" stroke-width="{sw}" {extra}/>')


def line(x1, y1, x2, y2, stroke=FURN, sw=1.2, extra=""):
    out.append(f'<line x1="{X(x1)}" y1="{Y(y1)}" x2="{X(x2)}" y2="{Y(y2)}" '
               f'stroke="{stroke}" stroke-width="{sw}" {extra}/>')


def text(x, y, s, size=12, fill=TXT, anchor="middle", weight="normal", extra=""):
    out.append(f'<text x="{X(x)}" y="{Y(y)}" font-size="{size}" fill="{fill}" '
               f'text-anchor="{anchor}" font-weight="{weight}" {extra}>{s}</text>')


def hdim(x1, x2, y, label, off=0):
    line(x1, y, x2, y, DIM, 0.8)
    for x in (x1, x2):
        line(x - 3, y + 3, x + 3, y - 3, DIM, 1)
        line(x, y - 4, x, y + 4, DIM, 0.6)
    text((x1 + x2) / 2, y - 3 + off, label, 11, DIM)


def vdim(y1, y2, x, label):
    line(x, y1, x, y2, DIM, 0.8)
    for y in (y1, y2):
        line(x - 3, y + 3, x + 3, y - 3, DIM, 1)
        line(x - 4, y, x + 4, y, DIM, 0.6)
    cx, cy = X(x) - 4, Y((y1 + y2) / 2)
    out.append(f'<text x="{cx}" y="{cy}" font-size="11" fill="{DIM}" text-anchor="middle" '
               f'transform="rotate(-90 {cx} {cy})">{label}</text>')


# ---------------------------------------------------------------- canvas
CW, CH = 1480, 1180
out.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{CW}" height="{CH}" '
           f'viewBox="0 0 {CW} {CH}" font-family="Arial, Helvetica, sans-serif">')
out.append(f'<rect width="100%" height="100%" fill="{BG}"/>')
out.append('<defs><pattern id="hatch" width="6" height="6" patternUnits="userSpaceOnUse" '
           'patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="6" '
           f'stroke="{WALL}" stroke-width="1"/></pattern>'
           '<pattern id="wet" width="16" height="16" patternUnits="userSpaceOnUse">'
           f'<rect width="16" height="16" fill="{FLOOR_WET}"/>'
           '<path d="M16 0 L0 0 0 16" fill="none" stroke="#33404e" stroke-width="1"/></pattern>'
           '</defs>')

text(W / 2, -44, "LOFT KAT — YATAK / BANYO / JAKUZİ YERLEŞİM ÖNERİSİ", 18, TXT, weight="bold")

# ---------------------------------------------------------------- ıslak hacim zemini
rect(260, 0, 150, 365, "none", "url(#wet)", 0)

# ---------------------------------------------------------------- dış duvarlar (20 cm)
rect(-20, -20, W + 40, 20, WALL, "none", 1.2)          # üst
rect(-20, 0, 20, CUT, WALL, "none", 1.2)               # sol
rect(W, 0, 20, 150, WALL, "none", 1.2)                 # sağ (pencere üstü)
rect(W, 230, 20, CUT - 230, WALL, "none", 1.2)         # sağ (pencere altı)
# P1 pencere 80/220
for dx in (0, 7, 13, 20):
    line(W + dx, 150, W + dx, 230, FURN if dx in (7, 13) else WALL, 1)
out.append(f'<circle cx="{X(W + 48)}" cy="{Y(190)}" r="13" stroke="{DIM}" fill="none"/>')
text(W + 48, 194, "P1", 11, DIM)
text(W + 48, 172, "80/220", 11, DIM)

# kolonlar
for cx, cy in ((-22, -22), (W - 6, -22), (-22, 361), (W - 6, 361)):
    rect(cx, cy, 28, 28, WALL, "url(#hatch)", 1.2)

# kesit / devamı çizgisi
out.append(f'<path d="M{X(-40)} {Y(CUT)} L{X(W + 40)} {Y(CUT)}" stroke="{DIM}" '
           'stroke-dasharray="10 4 2 4" stroke-width="1"/>')
text(-30, CUT + 16, "plan aşağı doğru devam ediyor", 11, DIM, anchor="start")

# ---------------------------------------------------------------- mevcut merdiven
line(200, 375, 200, CUT, FURN, 1.4)
line(200, 375, W, 375, FURN, 1.4)
rect(200, 370, 50, 5, WALL, "none", 1)                 # korkuluk (yatak tarafı)
steps = [(200, 225, "14"), (225, 250, "13"), (250, 275, "12"), (275, 300, "11")]
for x1, x2, n in steps:
    line(x2, 375, x2, CUT, FURN, 1)
    text((x1 + x2) / 2, 400, n, 10, FURN)
for ang_x, ang_y in ((350, 375), (410, 400), (410, 440)):
    line(300, CUT, ang_x, ang_y, FURN, 1)
text(330, 398, "10", 10, FURN)
text(395, 470, "9", 10, FURN)
out.append(f'<path d="M{X(330)} {Y(460)} L{X(215)} {Y(460)}" stroke="{TXT}" stroke-width="1" '
           'marker-end="url(#arr)"/>')
out.append('<defs><marker id="arr" markerWidth="10" markerHeight="10" refX="8" refY="5" '
           f'orient="auto"><path d="M0 0 L10 5 L0 10 z" fill="{TXT}"/></marker></defs>')
text(272, 455, "ÇIKIŞ", 10, TXT)
text(305, 425, "MERDİVEN (mevcut)", 11, DIM)

# merdiven çıkış sahanlığı
rect(5, 390, 185, 85, DIM, "none", 0.8, 'stroke-dasharray="6 4"')
text(97, 437, "MERDİVEN ÇIKIŞ / SAHANLIK", 11, DIM)
text(97, 452, "(boş bırakıldı)", 10, DIM)

# ---------------------------------------------------------------- yeni bölme duvarları (10 cm)
# banyo-yatak arası: 0-150 CAM (jakuzi görünümü), 150-275 dolu, 275-355 sürgülü kapı, 355-365 dolu
rect(250, 0, 10, 2, NEW, NEW, 0.5)
line(253, 0, 253, 150, GLASS, 1.6)
line(257, 0, 257, 150, GLASS, 1.6)
rect(250, 150, 10, 125, NEW, NEW, 0.5)
rect(250, 355, 10, 20, NEW, NEW, 0.5)
# banyo alt duvarı (merdiven boşluğu kenarı)
rect(260, 365, 150, 10, NEW, NEW, 0.5)
# sürgülü kapı (cebe giren) — açık konum kesikli
line(255, 275, 255, 355, NEW, 1, 'stroke-dasharray="5 3"')
rect(252, 197, 6, 78, NEW, "none", 1, 'stroke-dasharray="4 3"')
text(236, 318, "SÜRGÜLÜ", 9, NEW, extra=f'transform="rotate(-90 {X(236)} {Y(318)})"')
text(244, 318, "KAPI 80", 9, NEW, extra=f'transform="rotate(-90 {X(244)} {Y(318)})"')

# ---------------------------------------------------------------- JAKUZİ (köşe 150x150)
jx, jy = 260, 0
out.append(f'<path d="M{X(260)} {Y(0)} L{X(410)} {Y(0)} L{X(410)} {Y(150)} L{X(345)} {Y(150)} '
           f'A{p(85)} {p(85)} 0 0 1 {X(260)} {Y(65)} Z" stroke="{FURN}" fill="none" stroke-width="1.6"/>')
out.append(f'<path d="M{X(275)} {Y(12)} L{X(398)} {Y(12)} L{X(398)} {Y(135)} L{X(350)} {Y(135)} '
           f'A{p(72)} {p(72)} 0 0 1 {X(275)} {Y(60)} Z" stroke="{FURN}" fill="none" stroke-width="1"/>')
for jx_, jy_ in ((300, 22), (340, 22), (385, 40), (385, 80), (385, 115), (285, 45)):
    out.append(f'<circle cx="{X(jx_)}" cy="{Y(jy_)}" r="3" fill="{FURN}"/>')
out.append(f'<ellipse cx="{X(370)} " cy="{Y(110)}" rx="{p(14)}" ry="{p(8)}" stroke="{FURN}" fill="none"/>')
text(338, 70, "JAKUZİ", 13, TXT, weight="bold")
text(338, 86, "köşe 150x150", 11, TXT)

# ---------------------------------------------------------------- LAVABO (80x50) — paylaşımlı duvarda
rect(260, 160, 50, 80)
out.append(f'<ellipse cx="{X(283)}" cy="{Y(200)}" rx="{p(15)}" ry="{p(22)}" stroke="{FURN}" fill="none"/>')
out.append(f'<circle cx="{X(266)}" cy="{Y(200)}" r="2.5" fill="{FURN}"/>')
line(261, 162, 261, 238, GLASS, 2)  # ayna
text(285, 252, "LAVABO 80x50", 10, TXT)

# ---------------------------------------------------------------- WC (asma klozet + gömme rezervuar)
rect(395, 228, 15, 50, FURN, "none", 1)
out.append(f'<path d="M{X(395)} {Y(234)} L{X(360)} {Y(234)} A{p(18)} {p(18)} 0 0 0 {X(360)} {Y(270)} '
           f'L{X(395)} {Y(270)} Z" stroke="{FURN}" fill="none" stroke-width="1.4"/>')
out.append(f'<path d="M{X(390)} {Y(240)} L{X(363)} {Y(240)} A{p(12)} {p(12)} 0 0 0 {X(363)} {Y(264)} '
           f'L{X(390)} {Y(264)} Z" stroke="{FURN}" fill="none" stroke-width="1"/>')
text(345, 256, "WC", 11, TXT, anchor="end")

# ---------------------------------------------------------------- DUŞ (90x90, walk-in)
rect(320, 275, 90, 90)
line(320, 275, 320, 325, GLASS, 2)      # sabit cam
line(320, 275, 360, 275, GLASS, 2)
line(328, 357, 402, 283, FURN, 0.8)
line(328, 283, 402, 357, FURN, 0.8)
rect(361, 316, 8, 8, FURN, "none", 1)
text(365, 352, "DUŞ 90x90", 10, TXT)

text(335, 185, "BANYO", 14, TXT, weight="bold")
text(335, 201, "~5.4 m²", 10, DIM)

# ---------------------------------------------------------------- YATAK 160x200
bx, by = 45, 0
rect(bx, by, 160, 200, FURN, "none", 1.6)
rect(bx, by, 160, 8, FURN, "none", 1.2)               # başlık
rect(bx + 10, 14, 66, 30, FURN, "none", 1)
rect(bx + 84, 14, 66, 30, FURN, "none", 1)
line(bx, 62, bx + 160, 62, FURN, 1)
line(bx, 62, bx + 40, 95, FURN, 0.8)
text(125, 130, "YATAK", 14, TXT, weight="bold")
text(125, 146, "160x200", 11, TXT)
# komodinler
rect(0, 0, 40, 40)
rect(210, 0, 40, 40)
text(20, 54, "KOMODİN", 8, TXT)
text(230, 54, "KOMODİN", 8, TXT)

# yatak ucu bank
rect(75, 212, 120, 38)
text(135, 235, "BANK / PUF", 9, TXT)

# halı
rect(30, 140, 190, 120, DIM, "none", 0.6, 'stroke-dasharray="2 4"')

# ---------------------------------------------------------------- GARDIROP 60x130
rect(0, 225, 60, 130)
line(30, 230, 30, 350, FURN, 0.6, 'stroke-dasharray="4 3"')
line(58, 225, 58, 355, FURN, 1)
text(30, 285, "GARDIROP", 9, TXT, extra=f'transform="rotate(-90 {X(30)} {Y(290)})"')
text(30, 300, "", 9, TXT)

# ---------------------------------------------------------------- yatak odası etiketi + geçiş okları
text(155, 300, "YATAK ODASI", 14, TXT, weight="bold")
text(155, 316, "geçiş min. 80 cm", 10, DIM)

# ---------------------------------------------------------------- ölçüler
hdim(0, W, -32, "410 (tahmini)")
vdim(0, D, -48, "375 (tahmini)")
hdim(260, 410, 160 - 12, "150", 0)
hdim(205, 250, 110, "45")
hdim(0, 45, 110, "45")

# ---------------------------------------------------------------- lejant / notlar
LX = 1090
items = [
    (WALL, "Mevcut duvar / kolon"),
    (NEW, "Yeni bölme duvarı (10 cm)"),
    (GLASS, "Cam bölme / duş camı / ayna"),
    (FURN, "Mobilya / vitrifiye"),
]
yy = 170
out.append(f'<text x="{LX}" y="{yy}" font-size="15" fill="{TXT}" font-weight="bold">LEJANT</text>')
for c, t in items:
    yy += 26
    out.append(f'<rect x="{LX}" y="{yy - 11}" width="26" height="12" fill="none" stroke="{c}" stroke-width="2"/>')
    out.append(f'<text x="{LX + 36}" y="{yy}" font-size="12" fill="{TXT}">{t}</text>')
yy += 26
out.append(f'<rect x="{LX}" y="{yy - 11}" width="26" height="12" fill="url(#wet)" stroke="#33404e"/>')
out.append(f'<text x="{LX + 36}" y="{yy}" font-size="12" fill="{TXT}">Islak hacim (seramik)</text>')

notes = [
    "NEDEN BU YERLEŞİM?",
    "",
    "1. Tüm ıslak hacimler (jakuzi, duş, WC, lavabo)",
    "   tek blokta, sağ şeritte → tesisat kısa,",
    "   tek gider hattı, tek havalandırma.",
    "2. Jakuzi sağ üst KÖŞEDE, kolonun dibinde.",
    "   Dolu jakuzi ~500-600 kg → yük kolon/kirişe",
    "   en yakın noktada. Statik kontrol şart.",
    "3. Jakuzi ile yatak arası CAM bölme:",
    "   yataktan jakuzi görünür (suit hissi).",
    "   İstenirse buzlu / akıllı cam / perde.",
    "4. P1 penceresi banyoda → doğal ışık +",
    "   havalandırma; önü boş bırakıldı.",
    "5. Merdiven çıkışı (sol alt) tamamen boş,",
    "   banyo kapısına ve yatağa direkt geçiş.",
    "6. Banyo kapısı sürgülü (cebe giren) →",
    "   açılma alanı kaybı yok.",
    "7. Yatak başı dış duvara (üst) dayalı,",
    "   iki yanda 45 cm komodin + geçiş.",
    "",
    "DİKKAT",
    "• Ölçüler ekran görüntüsünden tahminidir",
    "  (iç ~410 x 375). Net ölçüyle revize edilir.",
    "• Jakuzi için ayrı sigortalı hat + topraklama.",
    "• Islak hacimde su yalıtımı + 2 cm kot farkı.",
    "• 180'lik yatak istenirse: sağ komodin",
    "  kaldırılır, duvara asma raf konur.",
]
yy += 44
for i, n in enumerate(notes):
    bold = n in ("NEDEN BU YERLEŞİM?", "DİKKAT")
    col = TXT if not n.startswith("•") else "#f0c080"
    out.append(f'<text x="{LX}" y="{yy}" font-size="{14 if bold else 12}" fill="{col}" '
               f'font-weight="{"bold" if bold else "normal"}" xml:space="preserve">{n}</text>')
    yy += 19

out.append("</svg>")

if __name__ == "__main__":
    import pathlib
    path = pathlib.Path(__file__).with_name("loft_yerlesim.svg")
    path.write_text("\n".join(out), encoding="utf-8")
    print(path)
