"""3D KOMPOZİT — Facebook profil resmi üreticisi.

SVG üretir, Chromium (Playwright) ile PNG'ye çevirir:
    python3 branding/generate.py && node branding/render.mjs
"""
import math
from pathlib import Path

OUT = Path(__file__).parent
W = 1080
C = W / 2
CYAN = "#38C8F4"
CYAN_DIM = "#1F6F8C"
WHITE = "#F4F7FA"


def pts(points):
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in points)


def ply(cx, cy, a, t, angle, idx, strength):
    """Tek bir izometrik kompozit katman (ply): üst yüz + iki yan yüz + elyaf taraması."""
    b = a * math.tan(math.radians(30))
    top = [(cx, cy - b), (cx + a, cy), (cx, cy + b), (cx - a, cy)]
    left = [(cx - a, cy), (cx, cy + b), (cx, cy + b + t), (cx - a, cy + t)]
    right = [(cx + a, cy), (cx, cy + b), (cx, cy + b + t), (cx + a, cy + t)]

    # Elyaf yönleri izometrik düzlemde: 0° / 90° rombus kenarlarına paralel,
    # +45° yatay, -45° dikey.
    dirs = {0: (a, -b), 90: (a, b), 45: (1, 0), -45: (0, 1)}
    dx, dy = dirs[angle]
    n = math.hypot(dx, dy)
    dx, dy = dx / n, dy / n
    px, py = -dy, dx
    lines = []
    step = 13
    for k in range(-40, 41):
        ox, oy = cx + px * k * step, cy + py * k * step
        L = 400
        lines.append(
            f'<line x1="{ox - dx * L:.1f}" y1="{oy - dy * L:.1f}" '
            f'x2="{ox + dx * L:.1f}" y2="{oy + dy * L:.1f}"/>'
        )

    op = strength
    return f"""
  <g>
    <clipPath id="clip{idx}"><polygon points="{pts(top)}"/></clipPath>
    <polygon points="{pts(left)}" fill="url(#sideL)" stroke="{CYAN}" stroke-opacity="{op}" stroke-width="2.2" stroke-linejoin="round"/>
    <polygon points="{pts(right)}" fill="url(#sideR)" stroke="{CYAN}" stroke-opacity="{op}" stroke-width="2.2" stroke-linejoin="round"/>
    <polygon points="{pts(top)}" fill="url(#topFill)" fill-opacity="{0.55 + 0.45 * op:.2f}"/>
    <g clip-path="url(#clip{idx})" stroke="{CYAN}" stroke-opacity="{0.30 * op + 0.08:.2f}" stroke-width="1.6">
      {''.join(lines)}
    </g>
    <polygon points="{pts(top)}" fill="none" stroke="{CYAN}" stroke-opacity="{op}" stroke-width="2.6" stroke-linejoin="round"/>
  </g>"""


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
    stack_cy = 330 if tagline else 345
    a = 205
    t = 17
    gap = 46
    orient = [-45, 90, 45, 0]  # alttan üste: klasik [0/45/90/-45] serimi
    plies = "".join(
        ply(C, stack_cy + gap * (3 - i), a, t, orient[i], i, 0.45 + 0.183 * i)
        for i in range(4)
    )

    text_y = 728 if tagline else 748
    title_size = 112 if tagline else 112
    tag = (
        f'<text x="{C}" y="{text_y + 76}" text-anchor="middle" '
        f'font-family="Inter" font-weight="600" font-size="31" letter-spacing="7.5" fill="{CYAN}">'
        f"TASARIM · ÇİZİM · MODELLEME</text>"
        if tagline
        else ""
    )
    # Başlığın altında ince ölçü çizgisi (teknik resim göndermesi)
    dim_y = text_y + 30 if tagline else text_y + 42
    dim_half = 300 if tagline else 300
    dim = "" if tagline else f"""
  <g stroke="{CYAN}" stroke-width="2" stroke-opacity="0.75">
    <line x1="{C - dim_half}" y1="{dim_y}" x2="{C + dim_half}" y2="{dim_y}"/>
    <line x1="{C - dim_half}" y1="{dim_y - 14}" x2="{C - dim_half}" y2="{dim_y + 14}"/>
    <line x1="{C + dim_half}" y1="{dim_y - 14}" x2="{C + dim_half}" y2="{dim_y + 14}"/>
  </g>
  <polygon points="{C - dim_half},{dim_y} {C - dim_half + 18},{dim_y - 6} {C - dim_half + 18},{dim_y + 6}" fill="{CYAN}"/>
  <polygon points="{C + dim_half},{dim_y} {C + dim_half - 18},{dim_y - 6} {C + dim_half - 18},{dim_y + 6}" fill="{CYAN}"/>"""

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}">
  <defs>
    <radialGradient id="bg" cx="50%" cy="42%" r="70%">
      <stop offset="0" stop-color="#14263A"/>
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
    <radialGradient id="fade" cx="50%" cy="45%" r="55%">
      <stop offset="0" stop-color="#000" stop-opacity="1"/>
      <stop offset="0.6" stop-color="#000" stop-opacity="0.85"/>
      <stop offset="1" stop-color="#000" stop-opacity="0.15"/>
    </radialGradient>
    <radialGradient id="glow" cx="50%" cy="50%" r="50%">
      <stop offset="0" stop-color="{CYAN}" stop-opacity="0.22"/>
      <stop offset="1" stop-color="{CYAN}" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="topFill" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#173149"/><stop offset="1" stop-color="#0C1A28"/>
    </linearGradient>
    <linearGradient id="sideL" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#0E2234"/><stop offset="1" stop-color="#16344D"/>
    </linearGradient>
    <linearGradient id="sideR" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#0B1A28"/><stop offset="1" stop-color="#081320"/>
    </linearGradient>
  </defs>

  <rect width="{W}" height="{W}" fill="url(#bg)"/>
  <rect width="{W}" height="{W}" fill="url(#carbon)" opacity="0.55"/>
  <rect width="{W}" height="{W}" fill="url(#fade)"/>
  <ellipse cx="{C}" cy="{stack_cy + 90}" rx="330" ry="260" fill="url(#glow)"/>

  {dial(500)}
  {plies}

  <text x="{C}" y="{text_y}" text-anchor="middle" font-family="Inter Display" font-weight="800"
        font-size="{title_size}" letter-spacing="2" fill="{WHITE}"><tspan fill="{CYAN}">3D</tspan> KOMPOZİT</text>
  {dim}
  {tag}
</svg>"""


if __name__ == "__main__":
    (OUT / "profil-3d-kompozit.svg").write_text(build(tagline=False), encoding="utf-8")
    (OUT / "profil-3d-kompozit-slogan.svg").write_text(build(tagline=True), encoding="utf-8")
    print("SVG'ler yazıldı.")
