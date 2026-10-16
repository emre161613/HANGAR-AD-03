"""3D KOMPOZİT — Facebook profil resmi üreticisi.

1) kaynak/Layer0_yuzey.obj içindeki kapalı profilden (cloud_deneme parçası)
   orta çizgiyi çıkarır -> parca_profil.json
2) Zemin + yazı katmanını SVG olarak yazar (parça WebGL ile üstüne çizilir).

    python3 branding/generate.py && node branding/render.mjs
"""
import json
import math
from pathlib import Path

OUT = Path(__file__).parent
W = 1080
C = W / 2
CYAN = "#38C8F4"
WHITE = "#F4F7FA"


def centerline_from_obj(path):
    """OBJ'deki kapalı dış hat 10 birim kalınlığında ince bir duvar.
    Karşılıklı (dış/iç) noktaların orta noktası parçanın orta çizgisini verir.
    Sıra: kısa ayak ucu -> eğik ayak -> radyüs -> üst yüzey -> dikey ayak ucu."""
    v = [
        tuple(map(float, ln.split()[1:3]))
        for ln in path.read_text().splitlines()
        if ln.startswith("v ")
    ]
    v = [None] + v  # OBJ indeksleri 1'den başlar

    def mid(a, b):
        return ((v[a][0] + v[b][0]) / 2, (v[a][1] + v[b][1]) / 2)

    pts = [mid(3, 4), mid(2, 5), mid(1, 6)]
    pts += [mid(i, 65 - i) for i in range(7, 31)]  # radyüs: v7..v30 <-> v58..v35
    pts += [mid(31, 34), mid(32, 33)]
    thickness = math.dist(v[3], v[4])
    return pts, thickness


def dial(r_out):
    """Kenarda CAD/iletki tarzı ölçek halkası."""
    ticks = []
    for deg in range(0, 360, 3):
        major = deg % 30 == 0
        mid = deg % 15 == 0
        ln = 26 if major else (16 if mid else 9)
        w = 2.4 if major else 1.3
        o = 0.85 if major else 0.40
        a = math.radians(deg)
        x1, y1 = C + r_out * math.cos(a), C + r_out * math.sin(a)
        x2, y2 = C + (r_out - ln) * math.cos(a), C + (r_out - ln) * math.sin(a)
        ticks.append(
            f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
            f'stroke="{CYAN}" stroke-opacity="{o}" stroke-width="{w}"/>'
        )
    return f"""
  <circle cx="{C}" cy="{C}" r="{r_out + 8}" fill="none" stroke="{CYAN}" stroke-opacity="0.9" stroke-width="3"/>
  <circle cx="{C}" cy="{C}" r="{r_out - 40}" fill="none" stroke="{CYAN}" stroke-opacity="0.18" stroke-width="1.2" stroke-dasharray="4 10"/>
  {''.join(ticks)}"""


def build(tagline: bool):
    text_y = 760 if tagline else 772
    title_size = 106
    if tagline:
        under = (
            f'<text x="{C}" y="{text_y + 70}" text-anchor="middle" '
            f'font-family="Inter" font-weight="600" font-size="30" letter-spacing="7" fill="{CYAN}">'
            f"TASARIM · ÇİZİM · MODELLEME</text>"
        )
    else:
        # Başlığın altında ince ölçü çizgisi (teknik resim göndermesi)
        y, h = text_y + 40, 290
        under = f"""
  <g stroke="{CYAN}" stroke-width="2" stroke-opacity="0.75">
    <line x1="{C - h}" y1="{y}" x2="{C + h}" y2="{y}"/>
    <line x1="{C - h}" y1="{y - 14}" x2="{C - h}" y2="{y + 14}"/>
    <line x1="{C + h}" y1="{y - 14}" x2="{C + h}" y2="{y + 14}"/>
  </g>
  <polygon points="{C - h},{y} {C - h + 18},{y - 6} {C - h + 18},{y + 6}" fill="{CYAN}"/>
  <polygon points="{C + h},{y} {C + h - 18},{y - 6} {C + h - 18},{y + 6}" fill="{CYAN}"/>"""

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}">
  <defs>
    <radialGradient id="bg" cx="50%" cy="40%" r="70%">
      <stop offset="0" stop-color="#16293D"/>
      <stop offset="0.55" stop-color="#0A1420"/>
      <stop offset="1" stop-color="#04080D"/>
    </radialGradient>
    <linearGradient id="weaveH" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#1A2633"/><stop offset="0.5" stop-color="#2A3846"/><stop offset="1" stop-color="#121B25"/>
    </linearGradient>
    <linearGradient id="weaveV" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#121B25"/><stop offset="0.5" stop-color="#202D3A"/><stop offset="1" stop-color="#0D141C"/>
    </linearGradient>
    <!-- 2x2 twill karbon elyaf dokusu -->
    <pattern id="carbon" width="28" height="28" patternUnits="userSpaceOnUse" patternTransform="rotate(45 540 540)">
      <rect x="0" y="0" width="14" height="14" fill="url(#weaveH)"/>
      <rect x="14" y="0" width="14" height="14" fill="url(#weaveV)"/>
      <rect x="0" y="14" width="14" height="14" fill="url(#weaveV)"/>
      <rect x="14" y="14" width="14" height="14" fill="url(#weaveH)"/>
    </pattern>
    <radialGradient id="fade" cx="50%" cy="42%" r="55%">
      <stop offset="0" stop-color="#000" stop-opacity="1"/>
      <stop offset="0.6" stop-color="#000" stop-opacity="0.85"/>
      <stop offset="1" stop-color="#000" stop-opacity="0.15"/>
    </radialGradient>
    <radialGradient id="glow" cx="50%" cy="50%" r="50%">
      <stop offset="0" stop-color="{CYAN}" stop-opacity="0.20"/>
      <stop offset="1" stop-color="{CYAN}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="shadow" cx="50%" cy="50%" r="50%">
      <stop offset="0" stop-color="#000" stop-opacity="0.75"/>
      <stop offset="1" stop-color="#000" stop-opacity="0"/>
    </radialGradient>
  </defs>

  <rect width="{W}" height="{W}" fill="url(#bg)"/>
  <rect width="{W}" height="{W}" fill="url(#carbon)" opacity="0.55"/>
  <rect width="{W}" height="{W}" fill="url(#fade)"/>
  <ellipse cx="{C}" cy="420" rx="360" ry="250" fill="url(#glow)"/>
  <ellipse cx="560" cy="602" rx="330" ry="30" fill="url(#shadow)"/>

  {dial(500)}

  <text x="{C}" y="{text_y}" text-anchor="middle" font-family="Inter Display" font-weight="800"
        font-size="{title_size}" letter-spacing="2" fill="{WHITE}"><tspan fill="{CYAN}">3D</tspan> KOMPOZİT</text>
  {under}
</svg>"""


if __name__ == "__main__":
    pts, t = centerline_from_obj(OUT / "kaynak" / "Layer0_yuzey.obj")
    (OUT / "parca_profil.json").write_text(
        json.dumps({"centerline": [[round(x, 3), round(y, 3)] for x, y in pts], "thickness": round(t, 3)}),
        encoding="utf-8",
    )
    (OUT / "zemin.svg").write_text(build(tagline=False), encoding="utf-8")
    (OUT / "zemin-slogan.svg").write_text(build(tagline=True), encoding="utf-8")
    print(f"{len(pts)} orta çizgi noktası, gerçek kalınlık {t:.2f}. SVG'ler yazıldı.")
