"""Loft kat yerleşim alternatifleri 3-4-5 — her biri için SVG üretir.

Ölçüler cm cinsindendir; iç köşe (sol üst) = (0, 0).
Mevcut plan ekran görüntüsünden tahmini: iç genişlik ~410, merdivene kadar derinlik ~375.
Sabitler: dış duvarlar, kolonlar, P1 penceresi (sağ duvar, 150-230), merdiven boşluğu
(sağ alt, x 200-410, y 375+), merdiven çıkış sahanlığı (sol alt), manzara sağ tarafta.
"""

import pathlib

S = 2.0            # px / cm
OX, OY = 110, 150  # çizim orijini (px)
W, D = 410, 375    # iç genişlik, merdiven kenarına kadar derinlik
CUT = 485          # görünen alt sınır
CW, CH = 1480, 1180
LX = 1090          # lejant / not sütunu (px)

BG = "#212830"
WALL = "#d6d6d6"
FURN = "#e0a462"
NEW = "#ff5a5a"
GLASS = "#5cc8ff"
DIM = "#8a93a0"
TXT = "#e8e8e8"
GREEN = "#7fe08a"
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


def vtext(x, y, s, size=9, fill=TXT):
    text(x, y, s, size, fill, extra=f'transform="rotate(-90 {X(x)} {Y(y)})"')


def hdim(x1, x2, y, label):
    line(x1, y, x2, y, DIM, 0.8)
    for x in (x1, x2):
        line(x - 3, y + 3, x + 3, y - 3, DIM, 1)
        line(x, y - 4, x, y + 4, DIM, 0.6)
    text((x1 + x2) / 2, y - 3, label, 11, DIM)


def vdim(y1, y2, x, label):
    line(x, y1, x, y2, DIM, 0.8)
    for y in (y1, y2):
        line(x - 3, y + 3, x + 3, y - 3, DIM, 1)
        line(x - 4, y, x + 4, y, DIM, 0.6)
    cx, cy = X(x) - 4, Y((y1 + y2) / 2)
    out.append(f'<text x="{cx}" y="{cy}" font-size="11" fill="{DIM}" text-anchor="middle" '
               f'transform="rotate(-90 {cx} {cy})">{label}</text>')


def wall(x, y, w, h):
    rect(x, y, w, h, NEW, NEW, 0.5)


def wet(x, y, w, h):
    rect(x, y, w, h, "none", "url(#wet)", 0)


# ---------------------------------------------------------------- vitrifiye / mobilya
def wc(face, a, b):
    """Asma klozet + gömme rezervuar. face: 'down' (üst duvarda, a=merkez x, b=duvar y),
    'right' (sol duvarda, a=duvar x, b=merkez y), 'left' (sağ duvarda, a=duvar x, b=merkez y)."""
    if face == "down":
        rect(a - 22, b, 44, 14, FURN, "none", 1)
        d1 = (f"M{X(a - 17)} {Y(b + 14)} L{X(a - 17)} {Y(b + 48)} A{p(17)} {p(17)} 0 0 0 "
              f"{X(a + 17)} {Y(b + 48)} L{X(a + 17)} {Y(b + 14)}")
        d2 = (f"M{X(a - 12)} {Y(b + 18)} L{X(a - 12)} {Y(b + 46)} A{p(12)} {p(12)} 0 0 0 "
              f"{X(a + 12)} {Y(b + 46)} L{X(a + 12)} {Y(b + 18)}")
    elif face == "right":
        rect(a, b - 22, 14, 44, FURN, "none", 1)
        d1 = (f"M{X(a + 14)} {Y(b - 17)} L{X(a + 48)} {Y(b - 17)} A{p(17)} {p(17)} 0 0 1 "
              f"{X(a + 48)} {Y(b + 17)} L{X(a + 14)} {Y(b + 17)}")
        d2 = (f"M{X(a + 18)} {Y(b - 12)} L{X(a + 46)} {Y(b - 12)} A{p(12)} {p(12)} 0 0 1 "
              f"{X(a + 46)} {Y(b + 12)} L{X(a + 18)} {Y(b + 12)}")
    else:
        rect(a - 14, b - 22, 14, 44, FURN, "none", 1)
        d1 = (f"M{X(a - 14)} {Y(b - 17)} L{X(a - 48)} {Y(b - 17)} A{p(17)} {p(17)} 0 0 0 "
              f"{X(a - 48)} {Y(b + 17)} L{X(a - 14)} {Y(b + 17)}")
        d2 = (f"M{X(a - 18)} {Y(b - 12)} L{X(a - 46)} {Y(b - 12)} A{p(12)} {p(12)} 0 0 0 "
              f"{X(a - 46)} {Y(b + 12)} L{X(a - 18)} {Y(b + 12)}")
    out.append(f'<path d="{d1}" stroke="{FURN}" fill="none" stroke-width="1.4"/>')
    out.append(f'<path d="{d2}" stroke="{FURN}" fill="none" stroke-width="1"/>')


def shower(x, y, w, h, glass, label_at=None):
    """glass: [(x1, y1, x2, y2), ...] cam parçaları."""
    rect(x, y, w, h)
    line(x + 8, y + h - 8, x + w - 8, y + 8, FURN, 0.8)
    line(x + 8, y + 8, x + w - 8, y + h - 8, FURN, 0.8)
    rect(x + w / 2 - 4, y + h / 2 - 4, 8, 8, FURN, "none", 1)
    for g in glass:
        line(*g, GLASS, 2)
    lx, ly = label_at or (x + w / 2, y + 22)
    text(lx, ly, f"DUŞ {w}x{h}", 10, TXT)


def sink(x, y, w, h, mirror=None, label="LAVABO", label_at=None):
    rect(x, y, w, h)
    out.append(f'<ellipse cx="{X(x + w / 2)}" cy="{Y(y + h / 2)}" rx="{p(w / 2 - 8)}" '
               f'ry="{p(h / 2 - 8)}" stroke="{FURN}" fill="none"/>')
    if mirror:
        line(*mirror, GLASS, 2)
    lx, ly = label_at or (x + w / 2, y + h + 12)
    text(lx, ly, label, 9, TXT)


def jacuzzi(x, y, w, h, head, sub):
    """Dikdörtgen jakuzi; head: başlık tarafı 'left' | 'top'."""
    rect(x, y, w, h, FURN, "none", 1.8)
    out.append(f'<rect x="{X(x + 10)}" y="{Y(y + 10)}" width="{p(w - 20)}" height="{p(h - 20)}" '
               f'rx="{p(min(w, h) / 2 - 12)}" stroke="{FURN}" fill="none" stroke-width="1.1"/>')
    if head == "left":
        out.append(f'<ellipse cx="{X(x + 26)}" cy="{Y(y + h / 2)}" rx="{p(8)}" ry="{p(16)}" '
                   f'stroke="{FURN}" fill="none"/>')
        jets = [(x + w * f, y + 17) for f in (0.35, 0.58, 0.81)] + \
               [(x + w * f, y + h - 17) for f in (0.35, 0.58, 0.81)] + [(x + w - 16, y + h / 2)]
    else:
        out.append(f'<ellipse cx="{X(x + w / 2)}" cy="{Y(y + 26)}" rx="{p(16)}" ry="{p(8)}" '
                   f'stroke="{FURN}" fill="none"/>')
        jets = [(x + 17, y + h * f) for f in (0.35, 0.58, 0.81)] + \
               [(x + w - 17, y + h * f) for f in (0.35, 0.58, 0.81)] + [(x + w / 2, y + h - 16)]
    for jx, jy in jets:
        out.append(f'<circle cx="{X(jx)}" cy="{Y(jy)}" r="3" fill="{FURN}"/>')
    if head == "left":
        text(x + w / 2 + 6, y + h / 2 - 2, f"JAKUZİ {w}x{h}", 13, TXT, weight="bold")
        text(x + w / 2 + 6, y + h / 2 + 14, sub, 10, TXT)
    else:
        vtext(x + w / 2 - 4, y + h / 2 + 8, f"JAKUZİ {h}x{w}", 13, TXT)
        vtext(x + w / 2 + 14, y + h / 2 + 8, sub, 10, TXT)


def bed(x, y, w, h, head, label="YATAK"):
    """w x h dış ölçü; head: başlık tarafı 'top' | 'left' | 'right'."""
    rect(x, y, w, h, FURN, "none", 1.6)
    if head == "top":
        rect(x, y, w, 8, FURN, "none", 1.2)
        pw = (w - 28) / 2
        rect(x + 10, y + 14, pw, 30, FURN, "none", 1)
        rect(x + 18 + pw, y + 14, pw, 30, FURN, "none", 1)
        line(x, y + 62, x + w, y + 62, FURN, 1)
        line(x, y + 62, x + 40, y + 95, FURN, 0.8)
        cx, cy = x + w / 2, y + h * 0.62
    elif head == "left":
        rect(x, y, 8, h, FURN, "none", 1.2)
        ph = (h - 28) / 2
        rect(x + 14, y + 10, 30, ph, FURN, "none", 1)
        rect(x + 14, y + 18 + ph, 30, ph, FURN, "none", 1)
        line(x + 62, y, x + 62, y + h, FURN, 1)
        line(x + 62, y, x + 95, y + 40, FURN, 0.8)
        cx, cy = x + w * 0.62, y + h / 2
    else:
        rect(x + w - 8, y, 8, h, FURN, "none", 1.2)
        ph = (h - 28) / 2
        rect(x + w - 44, y + 10, 30, ph, FURN, "none", 1)
        rect(x + w - 44, y + 18 + ph, 30, ph, FURN, "none", 1)
        line(x + w - 62, y, x + w - 62, y + h, FURN, 1)
        line(x + w - 62, y, x + w - 95, y + 40, FURN, 0.8)
        cx, cy = x + w * 0.38, y + h / 2
    dims = f"{min(w, h)}x{max(w, h)}"
    text(cx, cy, label, 14, TXT, weight="bold")
    text(cx, cy + 16, dims, 11, TXT)


def nightstand(x, y, w=40, h=40):
    rect(x, y, w, h)
    text(x + w / 2, y + h / 2 + 3, "KOMODİN", 7, TXT)


def wardrobe(x, y, w, h, label="GARDIROP"):
    rect(x, y, w, h)
    if h >= w:
        line(x + w / 2, y + 5, x + w / 2, y + h - 5, FURN, 0.6, 'stroke-dasharray="4 3"')
        vtext(x + w / 2 - 4, y + h / 2, label, 9)
    else:
        line(x + 5, y + h / 2, x + w - 5, y + h / 2, FURN, 0.6, 'stroke-dasharray="4 3"')
        text(x + w / 2, y + h / 2 - 4, label, 9)


def pocket_door(x1, y1, x2, y2, pocket, label, label_at, vertical_label=False):
    """Sürgülü (cebe giren) kapı: açıklık (x1,y1)-(x2,y2), pocket: cep rect (x, y, w, h)."""
    line(x1, y1, x2, y2, NEW, 1, 'stroke-dasharray="5 3"')
    rect(*pocket, NEW, "none", 1, 'stroke-dasharray="4 3"')
    if vertical_label:
        vtext(*label_at, label, 9, NEW)
    else:
        text(*label_at, label, 9, NEW)


def swing_door(hx, hy, r, start_deg, end_deg, label=None, label_at=None):
    """Menteşeli kapı: menteşe (hx,hy), yarıçap r; kanat start_deg açısında, yay end_deg'e."""
    import math
    a1, a2 = math.radians(start_deg), math.radians(end_deg)
    x1, y1 = hx + r * math.cos(a1), hy + r * math.sin(a1)
    x2, y2 = hx + r * math.cos(a2), hy + r * math.sin(a2)
    line(hx, hy, x1, y1, NEW, 1.2)
    sweep = 1 if (end_deg - start_deg) % 360 < 180 else 0
    out.append(f'<path d="M{X(x1)} {Y(y1)} A{p(r)} {p(r)} 0 0 {sweep} {X(x2)} {Y(y2)}" '
               f'stroke="{NEW}" fill="none" stroke-width="0.8" stroke-dasharray="4 3"/>')
    if label:
        text(*label_at, label, 9, NEW)


# ---------------------------------------------------------------- sabit kabuk
def shell(title, guard=True):
    out.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{CW}" height="{CH}" '
               f'viewBox="0 0 {CW} {CH}" font-family="Arial, Helvetica, sans-serif">')
    out.append(f'<rect width="100%" height="100%" fill="{BG}"/>')
    out.append('<defs><pattern id="hatch" width="6" height="6" patternUnits="userSpaceOnUse" '
               'patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="6" '
               f'stroke="{WALL}" stroke-width="1"/></pattern>'
               '<pattern id="wet" width="16" height="16" patternUnits="userSpaceOnUse">'
               f'<rect width="16" height="16" fill="{FLOOR_WET}"/>'
               '<path d="M16 0 L0 0 0 16" fill="none" stroke="#33404e" stroke-width="1"/></pattern>'
               '<marker id="arr" markerWidth="10" markerHeight="10" refX="8" refY="5" orient="auto">'
               f'<path d="M0 0 L10 5 L0 10 z" fill="{TXT}"/></marker>'
               '<marker id="arrg" markerWidth="10" markerHeight="10" refX="8" refY="5" orient="auto">'
               f'<path d="M0 0 L10 5 L0 10 z" fill="{GREEN}"/></marker></defs>')
    text(W / 2, -44, title, 18, TXT, weight="bold")

    # dış duvarlar (20 cm) + P1 pencere 80/220
    rect(-20, -20, W + 40, 20, WALL, "none", 1.2)
    rect(-20, 0, 20, CUT, WALL, "none", 1.2)
    rect(W, 0, 20, 150, WALL, "none", 1.2)
    rect(W, 230, 20, CUT - 230, WALL, "none", 1.2)
    for dx in (0, 7, 13, 20):
        line(W + dx, 150, W + dx, 230, FURN if dx in (7, 13) else WALL, 1)
    out.append(f'<circle cx="{X(W + 48)}" cy="{Y(190)}" r="13" stroke="{DIM}" fill="none"/>')
    text(W + 48, 194, "P1", 11, DIM)
    text(W + 48, 172, "80/220", 11, DIM)
    for cx, cy in ((-22, -22), (W - 6, -22), (-22, 361), (W - 6, 361)):
        rect(cx, cy, 28, 28, WALL, "url(#hatch)", 1.2)

    # manzara
    out.append(f'<path d="M{X(W + 28)} {Y(300)} L{X(W + 75)} {Y(300)}" stroke="{GREEN}" '
               'stroke-width="2.5" marker-end="url(#arrg)"/>')
    text(W + 52, 290, "MANZARA", 12, GREEN, weight="bold")

    out.append(f'<path d="M{X(-40)} {Y(CUT)} L{X(W + 40)} {Y(CUT)}" stroke="{DIM}" '
               'stroke-dasharray="10 4 2 4" stroke-width="1"/>')
    text(-30, CUT + 16, "plan aşağı doğru devam ediyor", 11, DIM, anchor="start")

    # mevcut merdiven
    line(200, 375, 200, CUT, FURN, 1.4)
    line(200, 375, W, 375, FURN, 1.4)
    for x1, x2, n in ((200, 225, "14"), (225, 250, "13"), (250, 275, "12"), (275, 300, "11")):
        line(x2, 375, x2, CUT, FURN, 1)
        text((x1 + x2) / 2, 400, n, 10, FURN)
    for ax, ay in ((350, 375), (410, 400), (410, 440)):
        line(300, CUT, ax, ay, FURN, 1)
    text(330, 398, "10", 10, FURN)
    text(395, 470, "9", 10, FURN)
    out.append(f'<path d="M{X(330)} {Y(460)} L{X(215)} {Y(460)}" stroke="{TXT}" stroke-width="1" '
               'marker-end="url(#arr)"/>')
    text(272, 455, "ÇIKIŞ", 10, TXT)
    text(305, 425, "MERDİVEN (mevcut)", 11, DIM)
    rect(5, 390, 185, 85, DIM, "none", 0.8, 'stroke-dasharray="6 4"')
    text(97, 437, "MERDİVEN ÇIKIŞ / SAHANLIK", 11, DIM)
    text(97, 452, "(boş bırakıldı)", 10, DIM)
    if guard:
        line(200, 368, W, 368, GLASS, 1.6)
        line(200, 373, W, 373, GLASS, 1.6)
        text(250, 364, "cam korkuluk h:110", 9, GLASS, anchor="start")

    hdim(0, W, -32, "410 (tahmini)")
    vdim(0, D, -48, "375 (tahmini)")


def legend(notes, heads):
    items = [
        (WALL, "Mevcut duvar / kolon"),
        (NEW, "Yeni bölme duvarı (10 cm) / kapı"),
        (GLASS, "Cam / korkuluk / ayna"),
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
    yy += 44
    for n in notes:
        bold = n in heads
        col = "#f0c080" if n.startswith("•") else TXT
        out.append(f'<text x="{LX}" y="{yy}" font-size="{14 if bold else 12}" fill="{col}" '
                   f'font-weight="{"bold" if bold else "normal"}" xml:space="preserve">{n}</text>')
        yy += 19


# ---------------------------------------------------------------- ALTERNATİF 3
def alt3():
    """Yatak manzaraya bakar: banyo sol üstte yatak başının arkasında, açık jakuzi sağ altta."""
    shell("LOFT KAT — ALTERNATİF 3: YATAK MANZARAYA BAKAR")

    # kapalı banyo 150x200 (sol üst); doğu duvarı = yatak başı duvarı
    wet(0, 0, 150, 200)
    wall(150, 0, 10, 210)
    wall(0, 200, 10, 10)
    wall(140, 200, 10, 10)
    rect(80, 200, 60, 10, NEW, NEW, 0.5)
    line(10, 205, 80, 205, NEW, 1, 'stroke-dasharray="5 3"')
    rect(82, 202, 56, 6, BG, "none", 1, 'stroke-dasharray="4 3"')
    text(45, 222, "SÜRGÜLÜ KAPI 70", 9, NEW)
    shower(0, 0, 90, 90, [(90, 0, 90, 90), (0, 90, 45, 90)])
    sink(95, 0, 55, 45, mirror=(97, 1, 148, 1))
    wc("right", 0, 145)
    text(40, 185, "WC", 10, TXT)
    rect(60, 95, 90, 103, GREEN, "none", 0.8, 'stroke-dasharray="3 3"')
    text(110, 115, "BANYO", 12, TXT, weight="bold")
    text(110, 129, "~3 m²", 10, DIM)
    text(105, 185, "klozet önü 85", 9, GREEN)

    # yatak 160x200 — başı banyo duvarında, ayak ucu pencereye / manzaraya
    bed(160, 45, 200, 160, "left")
    nightstand(160, 2)
    nightstand(160, 208)
    hdim(360, 410, 120, "50")

    # açık jakuzi 170x90 — sağ alt, manzara tarafı
    wet(230, 240, 180, 125)
    rect(240, 250, 170, 25, FURN, "none", 0.8, 'stroke-dasharray="6 3"')
    text(325, 266, "basamak (+20)", 9, DIM)
    jacuzzi(240, 275, 170, 90, "left", "yüz manzaraya · yanları açık")
    hdim(240, 410, 240, "170")

    wardrobe(0, 225, 60, 130)
    text(150, 300, "YATAK ODASI", 14, TXT, weight="bold")
    text(150, 316, "geçiş min. 80 cm", 10, DIM)

    legend([
        "ALTERNATİF 3 — FİKİR",
        "",
        "1. Yatağın ayak ucu pencereye bakıyor:",
        "   uyanınca ilk gördüğün MANZARA.",
        "2. Banyo sol üstte, yatak başı duvarının",
        "   arkasında; tesisat sol dış duvarda.",
        "3. Banyo ~3 m²: v2'den büyük, klozet önü",
        "   85 cm, lavabo + 90x90 duş rahat.",
        "4. Jakuzi yine manzara köşesinde, açık;",
        "   cam korkuluk ile merdivenden ayrılır.",
        "5. Gardırop sol duvarda, merdiven çıkışı",
        "   ve banyo kapısı ortak geçişte.",
        "",
        "DİKKAT",
        "• Yatak ayak ucunda 50 cm kalıyor (dar).",
        "• Banyo ile jakuzi ayrı köşelerde → iki",
        "  ayrı tesisat hattı, maliyet biraz artar.",
        "• Açık jakuzi: aspiratör / nem alma şart.",
        "• Jakuzi merdiven kenarında: statik kontrol.",
    ], ("ALTERNATİF 3 — FİKİR", "DİKKAT"))


# ---------------------------------------------------------------- ALTERNATİF 4
def alt4():
    """Jakuzi pencerenin önünde: banyo üstte boydan, niş yatak solda manzaraya bakar."""
    shell("LOFT KAT — ALTERNATİF 4: JAKUZİ PENCERE ÖNÜNDE")

    # kapalı banyo 200x115 (sol üst, boydan)
    wet(0, 0, 200, 115)
    wall(0, 115, 210, 10)
    wall(200, 0, 10, 40)
    swing_door(210, 115, 75, 0, 270, "KAPI 75", (262, 132))
    shower(0, 0, 90, 115, [(90, 0, 90, 60)], label_at=(45, 22))
    wc("down", 120, 0)
    text(120, 82, "WC", 10, TXT)
    sink(150, 0, 50, 45, mirror=(152, 1, 198, 1))
    text(150, 100, "BANYO ~2.3 m²", 10, DIM)

    # niş yatak 160x200 — başı sol duvarda, ayak ucu jakuziye / manzaraya
    bed(0, 127, 200, 160, "left")
    text(100, 304, "asma raf / aplik (komodin yerine)", 9, DIM)

    # jakuzi 90x170 — P1 penceresinin önünde, açık
    wet(285, 105, 125, 190)
    rect(295, 110, 25, 170, FURN, "none", 0.8, 'stroke-dasharray="6 3"')
    vtext(306, 195, "basamak (+20)", 9, DIM)
    jacuzzi(320, 110, 90, 170, "top", "pencere önünde")
    vdim(110, 280, 290, "")

    # gardırop — sağ üst köşe
    wardrobe(290, 0, 120, 60)

    text(250, 330, "AÇIK ALAN", 13, TXT, weight="bold")
    text(250, 346, "geçiş 80+ cm", 10, DIM)

    legend([
        "ALTERNATİF 4 — FİKİR",
        "",
        "1. Jakuzi tam P1 penceresinin önünde:",
        "   yatarken yanında boydan pencere.",
        "2. Banyo üst duvar boyunca (duş, WC,",
        "   lavabo yan yana), kapı sağa açılır.",
        "3. Yatak sol duvarda NİŞ gibi: ayak ucu",
        "   jakuziye ve pencereye bakıyor.",
        "4. Gardırop sağ üst köşede, jakuzinin",
        "   arkasında; sağ alt köşe tamamen boş.",
        "5. Merdiven çıkışından her yere 80+ cm.",
        "",
        "DİKKAT",
        "• Yatak bir uzun kenarıyla banyo duvarına",
        "  dayalı → tek taraftan inilir, komodin yok.",
        "• Jakuzi pencereyi kapatır: P1 kapı/Fransız",
        "  balkon ise kullanılamaz, sadece manzara.",
        "• Banyo dar (~2.3 m²) ama 3 parça sığıyor.",
        "• Açık jakuzi: aspiratör / nem alma şart.",
    ], ("ALTERNATİF 4 — FİKİR", "DİKKAT"))


# ---------------------------------------------------------------- ALTERNATİF 5
def alt5():
    """Kapalı spa banyo: jakuzi banyonun içinde (solda), yatak sağda pencere yanında."""
    shell("LOFT KAT — ALTERNATİF 5: KAPALI SPA BANYO")

    # spa banyo 200x285 (sol), jakuzi içeride
    wet(0, 0, 200, 285)
    wall(200, 0, 10, 295)
    wall(0, 285, 20, 10)
    wall(180, 285, 20, 10)
    line(100, 290, 180, 290, NEW, 1, 'stroke-dasharray="5 3"')
    rect(20, 285, 80, 10, NEW, NEW, 0.5)
    rect(22, 287, 78, 6, BG, "none", 1, 'stroke-dasharray="4 3"')
    text(140, 305, "SÜRGÜLÜ KAPI 80", 9, NEW)
    jacuzzi(0, 0, 80, 170, "top", "banyo içinde")
    shower(110, 0, 90, 90, [(110, 0, 110, 90), (155, 90, 200, 90)], label_at=(155, 22))
    wc("left", 200, 210)
    text(140, 214, "WC", 10, TXT, anchor="end")
    sink(0, 185, 45, 65, mirror=(1, 187, 1, 248), label_at=(22, 262))
    text(115, 135, "SPA BANYO", 13, TXT, weight="bold")
    text(115, 150, "~5.7 m²", 10, DIM)

    # yatak 160x200 — başı üst duvarda, pencere yanında
    bed(230, 0, 160, 200, "top")
    text(220, 92, "raf", 8, DIM)
    text(400, 92, "raf", 8, DIM)

    # gardırop + TV — merdiven korkuluğu önünde, yatağa bakar
    wardrobe(260, 305, 140, 60, "GARDIROP + TV")
    text(330, 262, "yatak ↔ dolap 105", 9, DIM)

    text(105, 335, "GEÇİŞ", 11, DIM)

    legend([
        "ALTERNATİF 5 — FİKİR",
        "",
        "1. Jakuzi, duş, WC, lavabo hepsi tek büyük",
        "   KAPALI spa banyoda (~5.7 m²).",
        "2. Buhar / nem / ses yatağa geçmez,",
        "   yatak odası tamamen kuru kalır.",
        "3. Yatak sağda, P1 penceresinin yanında;",
        "   karşısında gardırop + TV duvarı.",
        "4. Tüm tesisat sol dış duvar boyunca,",
        "   tek gider hattı → en ucuz çözüm.",
        "5. Merdivenden çıkınca banyo kapısı",
        "   ve yatak odası ayrı ayrı erişilir.",
        "",
        "DİKKAT",
        "• Jakuzide manzara YOK (iç tarafta).",
        "• Yatağın iki yanında sadece 20 cm:",
        "  komodin yerine duvara asma raf.",
        "• Jakuzi dolu ~400 kg: sol dış duvar",
        "  boyunca, statik açıdan en güvenli yer.",
    ], ("ALTERNATİF 5 — FİKİR", "DİKKAT"))


if __name__ == "__main__":
    here = pathlib.Path(__file__).parent
    for name, fn in (("loft_yerlesim_v3.svg", alt3), ("loft_yerlesim_v4.svg", alt4),
                     ("loft_yerlesim_v5.svg", alt5)):
        out.clear()
        fn()
        out.append("</svg>")
        (here / name).write_text("\n".join(out), encoding="utf-8")
        print(here / name)
