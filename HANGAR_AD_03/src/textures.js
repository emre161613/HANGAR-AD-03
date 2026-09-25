// Procedural 2D artwork used as *textures* on 3D objects (gauge dials, button
// cap engraving) and the end-card typography layer. Masks are packed in
// channels: R = lit markings, G = redline paint, B = secondary print.

const FONT = '"HangarSans", "Liberation Sans", sans-serif';

function dial(size, { max, step, minor, major, labels, redFrom, sub, labelScale = 1, labelR = 0.64, sweep = 270 }) {
  const c = document.createElement('canvas');
  c.width = c.height = size;
  const g = c.getContext('2d');
  g.fillStyle = '#000'; g.fillRect(0, 0, size, size);
  g.globalCompositeOperation = 'lighter';
  const R = size / 2, cx = R, cy = R;
  const ang = (v) => ((-sweep / 2 + (v / max) * sweep) * Math.PI) / 180;
  const pt = (a, r) => [cx + r * R * Math.sin(a), cy - r * R * Math.cos(a)];
  const tick = (v, r0, r1, w, col) => {
    const a = ang(v); const [x0, y0] = pt(a, r0), [x1, y1] = pt(a, r1);
    g.strokeStyle = col; g.lineWidth = w; g.lineCap = 'butt';
    g.beginPath(); g.moveTo(x0, y0); g.lineTo(x1, y1); g.stroke();
  };
  // redline band
  if (redFrom !== undefined) {
    g.strokeStyle = 'rgb(0,255,0)'; g.lineWidth = R * 0.075;
    g.beginPath(); g.arc(cx, cy, R * 0.885, ang(redFrom) - Math.PI / 2, ang(max) - Math.PI / 2); g.stroke();
  }
  // outer thin ring
  g.strokeStyle = 'rgb(0,0,200)'; g.lineWidth = R * 0.006;
  g.beginPath(); g.arc(cx, cy, R * 0.94, ang(0) - Math.PI / 2, ang(max) - Math.PI / 2); g.stroke();
  for (let v = 0; v <= max + 1e-6; v += minor) {
    const isMajor = Math.abs(v / major - Math.round(v / major)) < 1e-6;
    const isMid = !isMajor && Math.abs(v / step - Math.round(v / step)) < 1e-6;
    const red = redFrom !== undefined && v >= redFrom;
    const col = red ? 'rgb(0,255,0)' : isMajor || isMid ? 'rgb(255,0,0)' : 'rgb(0,0,255)';
    if (isMajor) tick(v, 0.78, 0.94, R * 0.028, col);
    else if (isMid) tick(v, 0.84, 0.94, R * 0.016, col);
    else tick(v, 0.88, 0.94, R * 0.008, col);
  }
  g.textAlign = 'center'; g.textBaseline = 'middle';
  for (const [v, txt] of labels) {
    const [x, y] = pt(ang(v), labelR);
    const red = redFrom !== undefined && v >= redFrom;
    g.fillStyle = red ? 'rgb(0,255,0)' : 'rgb(255,0,0)';
    g.save(); g.translate(x, y); g.scale(0.82, 1);
    g.font = `700 ${Math.round(R * 0.2 * labelScale)}px ${FONT}`;
    g.fillText(txt, 0, 0); g.restore();
  }
  if (sub) {
    g.fillStyle = 'rgb(0,0,255)';
    g.font = `400 ${Math.round(R * 0.07)}px ${FONT}`;
    if ('letterSpacing' in g) g.letterSpacing = `${Math.round(R * 0.02)}px`;
    sub.forEach((s, i) => g.fillText(s, cx, cy + R * (0.34 + i * 0.1)));
    if ('letterSpacing' in g) g.letterSpacing = '0px';
  }
  return c;
}

export function makeTextures() {
  const tach = dial(2048, {
    max: 8000, step: 500, minor: 250, major: 1000, redFrom: 6500,
    labels: [0, 1, 2, 3, 4, 5, 6, 7, 8].map((n) => [n * 1000, String(n)]), sub: ['×1000', 'r/min'],
  });
  const speedo = dial(1024, {
    max: 240, step: 10, minor: 5, major: 20, labelScale: 0.6, labelR: 0.66,
    labels: [0, 40, 80, 120, 160, 200, 240].map((n) => [n, String(n)]), sub: ['km/h'],
  });
  const small = dial(512, {
    max: 120, step: 20, minor: 10, major: 40, labelScale: 0.9, labelR: 0.6, sweep: 180,
    labels: [[0, 'C'], [120, 'H']], sub: ['TEMP'],
  });
  // START cap engraving
  const cap = document.createElement('canvas');
  cap.width = cap.height = 512;
  const g = cap.getContext('2d');
  g.fillStyle = '#000'; g.fillRect(0, 0, 512, 512);
  g.fillStyle = 'rgb(255,0,0)'; g.textAlign = 'center'; g.textBaseline = 'middle';
  g.save(); g.translate(256, 256); g.scale(0.86, 1);
  g.font = `700 108px ${FONT}`; g.fillText('START', 0, 0);
  g.font = `400 40px ${FONT}`; if ('letterSpacing' in g) g.letterSpacing = '8px';
  g.fillStyle = 'rgb(0,0,255)'; g.fillText('ENGINE', 0, -92); g.fillText('STOP', 0, 92);
  g.restore();
  g.strokeStyle = 'rgb(0,0,255)'; g.lineWidth = 5;
  g.beginPath(); g.moveTo(150, 200); g.lineTo(362, 200); g.moveTo(150, 312); g.lineTo(362, 312); g.stroke();
  return { tach, speedo, small, cap };
}

// ---------------------------------------------------------------- end card
// Drawn in linear "light" values; composited in the scene pass as emission so
// bloom and grain treat it like everything else.
export function drawEndcard(g, t, CUE, Wc = 1080, Hc = 1920) {
  g.clearRect(0, 0, Wc, Hc);
  g.fillStyle = '#000'; g.fillRect(0, 0, Wc, Hc);
  g.textAlign = 'center'; g.textBaseline = 'alphabetic';
  const metal = (y0, y1, a) => {
    const gr = g.createLinearGradient(0, y0, 0, y1);
    gr.addColorStop(0, `rgba(236,233,226,${a})`);
    gr.addColorStop(0.48, `rgba(196,192,186,${a})`);
    gr.addColorStop(0.52, `rgba(150,146,141,${a})`);
    gr.addColorStop(1, `rgba(214,210,203,${a})`);
    return gr;
  };
  const spaced = (px) => { if ('letterSpacing' in g) g.letterSpacing = `${px}px`; };

  // YOLA ÇIKTIK. — hard in, hard out
  if (t >= CUE.title && t < CUE.titleOff) {
    const k = t - CUE.title;
    const a = 1;
    g.save();
    const jolt = k < 1 / 30 ? 6 : k < 2 / 30 ? -3 : 0; // one-frame mechanical jolt
    g.translate(Wc / 2, Hc / 2 + 52 + jolt);
    g.scale(0.8, 1);
    g.font = `700 172px "HangarSans", sans-serif`;
    spaced(4);
    g.fillStyle = metal(-150, 10, a);
    g.fillText('YOLA ÇIKTIK.', 0, 0);
    // a single light glint travelling across the letters
    const sx = -700 + Math.min(1, k / 0.9) * 1400;
    const gl = g.createLinearGradient(sx - 60, 0, sx + 60, 0);
    gl.addColorStop(0, 'rgba(255,240,225,0)'); gl.addColorStop(0.5, 'rgba(255,240,225,0.28)'); gl.addColorStop(1, 'rgba(255,240,225,0)');
    g.globalCompositeOperation = 'lighter';
    g.fillStyle = gl; g.fillText('YOLA ÇIKTIK.', 0, 0);
    g.restore();
  }

  const fadeOut = 1 - Math.min(1, Math.max(0, (t - CUE.fadeOut) / (19.5 - CUE.fadeOut)));
  const ease = (t0, d) => Math.min(1, Math.max(0, (t - t0) / d)) ** 1.6 * fadeOut;

  // LOGO PLACEHOLDER — neutral frame only; the real logo will replace it.
  const la = ease(CUE.logo, 0.7);
  if (la > 0) {
    g.save();
    g.strokeStyle = `rgba(120,118,114,${0.9 * la})`; g.lineWidth = 2;
    g.setLineDash([10, 8]);
    g.strokeRect(Wc / 2 - 330, Hc / 2 - 220, 660, 200);
    g.setLineDash([]);
    g.fillStyle = `rgba(150,147,142,${la})`;
    g.font = `400 26px "HangarSans", sans-serif`; spaced(9);
    g.fillText('HANGAR LOGO', Wc / 2, Hc / 2 - 112);
    g.font = `400 16px "HangarSans", sans-serif`; spaced(5);
    g.fillStyle = `rgba(110,108,104,${la})`;
    g.fillText('PLACEHOLDER', Wc / 2, Hc / 2 - 78);
    g.restore();
  }
  const pa = ease(CUE.place, 0.5);
  if (pa > 0) {
    g.save();
    g.font = `700 64px "HangarSans", sans-serif`; spaced(24);
    g.fillStyle = metal(Hc / 2 + 40, Hc / 2 + 104, pa);
    g.fillText('GEMLİK • 2026', Wc / 2 + 12, Hc / 2 + 100);
    // controlled red rule
    g.fillStyle = `rgba(170,24,18,${pa})`;
    g.fillRect(Wc / 2 - 44, Hc / 2 + 142, 88 * Math.min(1, (t - CUE.place) / 0.4), 4);
    g.restore();
  }
  const sa = ease(CUE.soon, 0.5);
  if (sa > 0) {
    g.save();
    g.font = `400 40px "HangarSans", sans-serif`; spaced(20);
    g.fillStyle = `rgba(190,186,180,${0.8 * sa})`;
    g.fillText('ÇOK YAKINDA', Wc / 2 + 10, Hc / 2 + 224);
    g.restore();
  }
  spaced(0);
}
