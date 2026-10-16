"""3D KOMPOZİT — Facebook kapak fotoğrafı (profil resmindeki katman simgesiyle uyumlu).

1640x924 tasarım: masaüstünde ortadaki ~1640x624 bant, mobilde tamamı görünür.
Tüm yazılar her iki kırpmada da kalacak şekilde ortadaki banda yerleştirildi.

    python3 branding/kapak.py && node branding/kapak_render.mjs
"""
import math
from pathlib import Path

OUT = Path(__file__).parent
W, H = 1640, 924
CYAN = "#38C8F4"
WHITE = "#F4F7FA"
GRAY = "#9FB0C0"
# "3D KOMPOZİT" başlığının 104px Inter Display 800 ile Chromium'da ölçülen genişliği
TITLE_W = 714

# Katman yığınının merkezi
SX, SY = 1245, 432


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
    step = 15
    for k in range(-45, 46):
        ox, oy = cx + px * k * step, cy + py * k * step
        L = 500
        lines.append(
            f'<line x1="{ox - dx * L:.1f}" y1="{oy - dy * L:.1f}" '
            f'x2="{ox + dx * L:.1f}" y2="{oy + dy * L:.1f}"/>'
        )

    op = strength
    return f"""
  <g>
    <clipPath id="clip{idx}"><polygon points="{pts(top)}"/></clipPath>
    <polygon points="{pts(left)}" fill="url(#sideL)" stroke="{CYAN}" stroke-opacity="{op}" stroke-width="2.4" stroke-linejoin="round"/>
    <polygon points="{pts(right)}" fill="url(#sideR)" stroke="{CYAN}" stroke-opacity="{op}" stroke-width="2.4" stroke-linejoin="round"/>
    <polygon points="{pts(top)}" fill="url(#topFill)" fill-opacity="{0.55 + 0.45 * op:.2f}"/>
    <g clip-path="url(#clip{idx})" stroke="{CYAN}" stroke-opacity="{0.30 * op + 0.08:.2f}" stroke-width="1.7">
      {''.join(lines)}
    </g>
    <polygon points="{pts(top)}" fill="none" stroke="{CYAN}" stroke-opacity="{op}" stroke-width="2.8" stroke-linejoin="round"/>
  </g>"""


def dial(cx, cy, r_out):
    """Profil resmindeki CAD/iletki halkasının aynısı (biraz daha sönük)."""
    ticks = []
    for deg in range(0, 360, 3):
        major = deg % 30 == 0
        mid = deg % 15 == 0
        ln = 26 if major else (16 if mid else 9)
        w = 2.4 if major else 1.3
        o = 0.7 if major else 0.32
        a = math.radians(deg)
        x1, y1 = cx + r_out * math.cos(a), cy + r_out * math.sin(a)
        x2, y2 = cx + (r_out - ln) * math.cos(a), cy + (r_out - ln) * math.sin(a)
        ticks.append(
            f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
            f'stroke="{CYAN}" stroke-opacity="{o}" stroke-width="{w}"/>'
        )
    return f"""
  <circle cx="{cx}" cy="{cy}" r="{r_out + 8}" fill="none" stroke="{CYAN}" stroke-opacity="0.75" stroke-width="3"/>
  <circle cx="{cx}" cy="{cy}" r="{r_out - 40}" fill="none" stroke="{CYAN}" stroke-opacity="0.16" stroke-width="1.2" stroke-dasharray="4 10"/>
  {''.join(ticks)}"""


def stack():
    a, t, gap = 220, 18, 48
    b = a * math.tan(math.radians(30))
    cy_top = SY - (3 * gap + t) / 2
    orient = [-45, 90, 45, 0]  # alttan üste: [0/45/90/-45] serimi
    out = []
    labels = []
    for i in range(4):
        cy = cy_top + gap * (3 - i)
        out.append(ply(SX, cy, a, t, orient[i], i, 0.45 + 0.183 * i))
        # Sağ köşeden katman açısı etiketi
        y = cy + t / 2
        x0 = SX + a + 10
        lab = f"{orient[i]}°".replace("-", "−")
        labels.append(
            f'<line x1="{x0}" y1="{y:.1f}" x2="{x0 + 22}" y2="{y:.1f}" stroke="{CYAN}" stroke-opacity="0.6" stroke-width="1.6"/>'
            f'<circle cx="{x0}" cy="{y:.1f}" r="3" fill="{CYAN}"/>'
            f'<text x="{x0 + 30}" y="{y + 8:.1f}" font-family="Inter" font-weight="600" font-size="23" fill="{CYAN}" fill-opacity="{0.55 + 0.15 * i:.2f}">{lab}</text>'
        )
    return "".join(out) + "".join(labels)


def grid():
    lines = []
    for x in range(0, W + 1, 40):
        major = x % 200 == 0
        lines.append(f'<line x1="{x}" y1="0" x2="{x}" y2="{H}" stroke-opacity="{0.10 if major else 0.045}"/>')
    for y in range(2, H + 1, 40):
        major = (y - 2) % 200 == 0
        lines.append(f'<line x1="0" y1="{y}" x2="{W}" y2="{y}" stroke-opacity="{0.10 if major else 0.045}"/>')
    return f'<g stroke="{CYAN}" stroke-width="1" mask="url(#gridMask)">{"".join(lines)}</g>'


def text_block():
    x = 130
    title_w = TITLE_W
    y_dim = 470
    return f"""
  <g>
    <line x1="{x}" y1="258" x2="{x + 44}" y2="258" stroke="{CYAN}" stroke-width="3"/>
    <text x="{x + 60}" y="267" font-family="Inter" font-weight="700" font-size="24" letter-spacing="6" fill="{CYAN}">KOMPOZİT ÜRETİCİLERİ İÇİN</text>

    <text x="{x - 5}" y="372" font-family="Inter Display" font-weight="800" font-size="104" letter-spacing="2"
          fill="{WHITE}"><tspan fill="{CYAN}">3D</tspan> KOMPOZİT</text>

    <text x="{x}" y="428" font-family="Inter" font-weight="600" font-size="28" letter-spacing="6.6" fill="{CYAN}">TASARIM · ÇİZİM · MODELLEME</text>

    <g stroke="{CYAN}" stroke-width="2" stroke-opacity="0.7">
      <line x1="{x}" y1="{y_dim}" x2="{x + title_w}" y2="{y_dim}"/>
      <line x1="{x}" y1="{y_dim - 13}" x2="{x}" y2="{y_dim + 13}"/>
      <line x1="{x + title_w}" y1="{y_dim - 13}" x2="{x + title_w}" y2="{y_dim + 13}"/>
    </g>
    <polygon points="{x},{y_dim} {x + 17},{y_dim - 6} {x + 17},{y_dim + 6}" fill="{CYAN}"/>
    <polygon points="{x + title_w},{y_dim} {x + title_w - 17},{y_dim - 6} {x + title_w - 17},{y_dim + 6}" fill="{CYAN}"/>

    <text x="{x}" y="522" font-family="Inter" font-weight="500" font-size="24" fill="{GRAY}">Kalıp tasarımı  ·  Laminasyon planı  ·  Teknik resim  ·  3D model</text>
  </g>"""


def build():
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
  <defs>
    <radialGradient id="bg" cx="{SX / W:.3f}" cy="0.48" r="0.75">
      <stop offset="0" stop-color="#16293D"/>
      <stop offset="0.5" stop-color="#0A1420"/>
      <stop offset="1" stop-color="#04080D"/>
    </radialGradient>
    <linearGradient id="weaveH" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#1A2633"/><stop offset="0.5" stop-color="#2A3846"/><stop offset="1" stop-color="#121B25"/>
    </linearGradient>
    <linearGradient id="weaveV" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#121B25"/><stop offset="0.5" stop-color="#202D3A"/><stop offset="1" stop-color="#0D141C"/>
    </linearGradient>
    <!-- 2x2 twill karbon elyaf dokusu -->
    <pattern id="carbon" width="28" height="28" patternUnits="userSpaceOnUse" patternTransform="rotate(45 820 462)">
      <rect x="0" y="0" width="14" height="14" fill="url(#weaveH)"/>
      <rect x="14" y="0" width="14" height="14" fill="url(#weaveV)"/>
      <rect x="0" y="14" width="14" height="14" fill="url(#weaveV)"/>
      <rect x="14" y="14" width="14" height="14" fill="url(#weaveH)"/>
    </pattern>
    <!-- Yazı tarafını koyulaştır, okunurluk için -->
    <linearGradient id="leftShade" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#03070B" stop-opacity="0.85"/>
      <stop offset="0.5" stop-color="#03070B" stop-opacity="0.55"/>
      <stop offset="0.75" stop-color="#03070B" stop-opacity="0"/>
    </linearGradient>
    <radialGradient id="stackFade" cx="{SX / W:.3f}" cy="0.5" r="0.32">
      <stop offset="0" stop-color="#000" stop-opacity="0.9"/>
      <stop offset="1" stop-color="#000" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glow" cx="50%" cy="50%" r="50%">
      <stop offset="0" stop-color="{CYAN}" stop-opacity="0.22"/>
      <stop offset="1" stop-color="{CYAN}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="gridFade" cx="{SX / W:.3f}" cy="0.5" r="0.55">
      <stop offset="0" stop-color="#fff" stop-opacity="1"/>
      <stop offset="1" stop-color="#fff" stop-opacity="0"/>
    </radialGradient>
    <mask id="gridMask"><rect width="{W}" height="{H}" fill="url(#gridFade)"/></mask>
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

  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  <rect width="{W}" height="{H}" fill="url(#carbon)" opacity="0.55"/>
  <rect width="{W}" height="{H}" fill="url(#stackFade)"/>
  {grid()}
  <rect width="{W}" height="{H}" fill="url(#leftShade)"/>
  <ellipse cx="{SX}" cy="{SY + 30}" rx="340" ry="250" fill="url(#glow)"/>

  {dial(SX, SY, 340)}
  {stack()}
  {text_block()}
</svg>"""


if __name__ == "__main__":
    (OUT / "kapak-3d-kompozit.svg").write_text(build(), encoding="utf-8")
    print("Kapak SVG yazıldı.")
