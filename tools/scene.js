// HANGAR launch — frame-deterministic scene renderer (1080x1920 canvas).
// drawFrame(t) paints the frame at time t (seconds). Assets: window.LOGO (Image), window.CAR (Image|null), window.ENV.
'use strict';
const WIDTH = 1080, HEIGHT = 1920, FPS = 30;
const C = {
  bg: '#060607', anth: '#16171a', anth2: '#202226',
  text: '#ECEDEF', mute: '#8B8E94', line: '#3A3C41',
  magenta: '#E6007E',
};
const FONT = '"Liberation Sans", Arial, sans-serif';
const MONO = '"Liberation Mono", monospace';

// music map (seconds) — 808 downbeats of each 2-bar phrase
const HIT = [0, 3.37, 6.76, 10.0, 13.22, 16.48, 19.75, 23.0, 26.31, 29.63, 32.68, 35.89];
const END = 37.33;

const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const lin = (t, a, b) => clamp((t - a) / (b - a));
const easeOutExpo = x => (x >= 1 ? 1 : 1 - Math.pow(2, -10 * x));
const easeInOutCubic = x => (x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2);
const easeOutCubic = x => 1 - Math.pow(1 - x, 3);
const easeInCubic = x => x * x * x;
const mix = (a, b, k) => a + (b - a) * k;

function env(name, t) {
  const a = window.ENV[name]; const f = t * FPS; const i = Math.floor(f);
  if (i < 0) return 0; if (i >= a.length - 1) return a[a.length - 1];
  return mix(a[i], a[i + 1], f - i);
}

// ---------- drawing primitives ----------
let ctx;
function chromeFill(y0, y1) {
  // brushed-metal vertical gradient echoing the logo
  const g = ctx.createLinearGradient(0, y0, 0, y1);
  g.addColorStop(0.00, '#F4F5F6');
  g.addColorStop(0.42, '#C9CCD0');
  g.addColorStop(0.55, '#6E7278');
  g.addColorStop(0.70, '#9DA1A7');
  g.addColorStop(1.00, '#E2E4E7');
  return g;
}
function setFont(size, weight = 700, family = FONT) { ctx.font = `${weight} ${size}px ${family}`; }
function spacedWidth(str, size, tracking, weight = 700, family = FONT) {
  setFont(size, weight, family); ctx.letterSpacing = `${tracking}px`;
  return ctx.measureText(str).width - tracking; // trailing spacing not visible
}
// draw text with letterSpacing, anchored: align 'center' | 'left'
function text(str, x, y, { size = 100, weight = 700, family = FONT, tracking = 0, fill = C.text, align = 'center', alpha = 1, baseline = 'alphabetic' } = {}) {
  if (alpha <= 0) return;
  ctx.save();
  setFont(size, weight, family); ctx.letterSpacing = `${tracking}px`;
  ctx.textBaseline = baseline; ctx.textAlign = 'left';
  const w = ctx.measureText(str).width - tracking;
  const x0 = align === 'center' ? x - w / 2 : align === 'right' ? x - w : x;
  ctx.globalAlpha *= alpha; ctx.fillStyle = fill;
  ctx.fillText(str, x0, y);
  ctx.restore();
  return w;
}
function rect(x, y, w, h, fill, alpha = 1) { if (alpha <= 0) return; ctx.save(); ctx.globalAlpha *= alpha; ctx.fillStyle = fill; ctx.fillRect(x, y, w, h); ctx.restore(); }

// ---------- background ----------
function background(t) {
  ctx.fillStyle = C.bg; ctx.fillRect(0, 0, WIDTH, HEIGHT);
  const low = env('low', t);
  const intro = easeInOutCubic(lin(t, 0, 1.2));
  const outro = 1 - lin(t, 35.55, 35.62);                // hard black in the pre-logo silence
  const k = intro * outro * (0.55 + 0.45 * low);
  // soft anthracite pool of light, slowly drifting
  const cy = 930 + Math.sin(t * 0.35) * 60;
  const g = ctx.createRadialGradient(540, cy, 40, 540, cy, 1150);
  g.addColorStop(0, `rgba(44,46,52,${0.95 * k})`);
  g.addColorStop(0.45, `rgba(26,27,31,${0.85 * k})`);
  g.addColorStop(1, 'rgba(6,6,7,0)');
  ctx.fillStyle = g; ctx.fillRect(0, 0, WIDTH, HEIGHT);
  // top/bottom vignette
  const v = ctx.createLinearGradient(0, 0, 0, HEIGHT);
  v.addColorStop(0, 'rgba(0,0,0,0.55)'); v.addColorStop(0.2, 'rgba(0,0,0,0)');
  v.addColorStop(0.8, 'rgba(0,0,0,0)'); v.addColorStop(1, 'rgba(0,0,0,0.6)');
  ctx.fillStyle = v; ctx.fillRect(0, 0, WIDTH, HEIGHT);
}

// flash on downbeats (very short exposure lift)
function flash(t) {
  let a = 0;
  for (const h of [3.37, 6.76, 10.0, 13.22, 16.48, 19.75, 23.0, 26.31, 29.63]) {
    const d = t - h; if (d >= 0 && d < 0.3) a = Math.max(a, 0.16 * (1 - d / 0.3) ** 2);
  }
  if (a > 0) rect(0, 0, WIDTH, HEIGHT, '#ffffff', a);
}

// ---------- subtitles (Turkish) ----------
const SUBS = [
  [0.55, 3.15, 'Her makinenin bir hikâyesi vardır.'],
  [3.45, 6.55, 'Bizimki burada başlıyor.'],
  [6.85, 9.80, 'Hassasiyet. Hiçbir şey şansa bırakılmaz.'],
  [10.10, 13.00, 'Ustalık. Her detay bilinçli.'],
  [13.30, 16.25, 'Performans. Sürülmek için yapıldı.'],
  [16.55, 19.55, 'Tutku. Asla bitmez.'],
  [19.85, 22.80, 'Bir garaj değil.'],
  [23.10, 26.10, 'Makineler için bir yuva.'],
  [26.40, 29.45, 'Sürmek için yaşayanlara.'],
  [29.75, 32.50, 'Kapılar açılıyor.'],
  [34.90, 35.55, 'Hoş geldiniz…'],
  [35.95, 37.20, 'Hangar’a hoş geldiniz.'],
];
function subtitles(t) {
  for (const [a, b, s] of SUBS) {
    if (t < a || t > b) continue;
    const al = Math.min(lin(t, a, a + 0.18), 1 - lin(t, b - 0.18, b));
    const rise = (1 - easeOutCubic(lin(t, a, a + 0.35))) * 10;
    ctx.save();
    ctx.shadowColor = 'rgba(0,0,0,0.85)'; ctx.shadowBlur = 18;
    text(s, WIDTH / 2, 1575 + rise, { size: 44, weight: 400, tracking: 0.5, fill: '#F2F2F4', alpha: 0.94 * al });
    ctx.restore();
  }
}

// ---------- persistent frame UI ----------
function frameUI(t) {
  const a = lin(t, 0.8, 1.6) * (1 - lin(t, 32.3, 32.68));
  if (a <= 0) return;
  // progress hairline at top safe area
  const p = clamp(t / 35.89);
  rect(90, 250, 900, 1, C.line, a * 0.9);
  rect(90, 250, 900 * p, 1, '#9A9DA3', a * 0.9);
}

// chapter tag: small index + tiny magenta square
function chapterTag(t, start, idx, label) {
  const a = lin(t, start + 0.1, start + 0.45) * (1 - lin(t, start + 3.0, start + 3.2));
  if (a <= 0) return;
  rect(90, 300, 10, 10, C.magenta, a);
  text(idx, 116, 311, { size: 26, weight: 400, family: MONO, tracking: 2, fill: C.mute, align: 'left', alpha: a, baseline: 'alphabetic' });
  text(label, 990, 311, { size: 22, weight: 700, tracking: 7, fill: C.mute, align: 'right', alpha: a });
}

// big chrome word with mask reveal from the centre line
function bigWord(t, str, start, end, { y = 980, maxW = 930, size = 230, tracking = -4, exit = 0.28 } = {}) {
  if (t < start || t > end) return;
  let s = size; let w = spacedWidth(str, s, tracking);
  if (w > maxW) { s = Math.floor(s * maxW / w); w = spacedWidth(str, s, tracking); }
  const rin = easeOutExpo(lin(t, start, start + 0.45));
  const rout = easeInCubic(lin(t, end - exit, end));
  const open = rin * (1 - rout);
  const scale = 1 + 0.045 * lin(t, start, end) + 0.02 * (1 - easeOutCubic(lin(t, start, start + 0.5)));
  const capH = s * 0.72;
  ctx.save();
  ctx.translate(WIDTH / 2, y - capH / 2); ctx.scale(scale, scale); ctx.translate(-WIDTH / 2, -(y - capH / 2));
  const half = (capH / 2 + s * 0.12) * open;
  ctx.beginPath(); ctx.rect(0, y - capH / 2 - half, WIDTH, half * 2); ctx.clip();
  text(str, WIDTH / 2, y, { size: s, tracking, fill: chromeFill(y - capH, y + s * 0.05) });
  ctx.restore();
  return { size: s, width: w * scale, open };
}

// thin rules framing a word
function rules(t, start, end, y, w) {
  const g = easeOutExpo(lin(t, start + 0.1, start + 0.9)) * (1 - easeInCubic(lin(t, end - 0.3, end)));
  if (g <= 0) return;
  rect(WIDTH / 2 - (w / 2) * g, y, w * g, 1, C.line, 1);
}

// ---------- scenes ----------
function scene0(t) { // 0 – 3.37: EVERY MACHINE / HAS A STORY
  if (t > 3.4) return;
  const lineW = 560 * easeOutExpo(lin(t, 0.3, 1.7)) * (1 - easeInOutCubic(lin(t, 2.5, 3.2)));
  const dot = lin(t, 2.9, 3.2) * (1 - lin(t, 3.3, 3.37));
  rect(WIDTH / 2 - lineW / 2, 959, lineW, 2, C.magenta, 1);
  if (dot > 0) { ctx.save(); ctx.globalAlpha = dot; ctx.fillStyle = C.magenta; ctx.beginPath(); ctx.arc(WIDTH / 2, 960, 5, 0, Math.PI * 2); ctx.fill(); ctx.restore(); }
  const fadeOut = 1 - easeInOutCubic(lin(t, 2.45, 3.0));
  const a1 = easeOutCubic(lin(t, 0.5, 1.2)) * fadeOut;
  const a2 = easeOutCubic(lin(t, 1.35, 2.0)) * fadeOut;
  const spread = 10 * easeOutCubic(lin(t, 0.5, 3.0));
  text('EVERY MACHINE', WIDTH / 2, 905 - 12 * (1 - a1), { size: 58, tracking: 14 + spread, fill: C.text, alpha: a1 });
  text('HAS A STORY', WIDTH / 2, 1060 + 12 * (1 - a2), { size: 58, tracking: 14 + spread, fill: C.mute, alpha: a2 });
}

function scene1(t) { // 3.37 – 6.76: OURS / BEGINS / HERE.
  if (t < 3.37 || t > 6.76) return;
  const out = easeInCubic(lin(t, 6.45, 6.74));
  const words = [['OURS', 3.37], ['BEGINS', 4.55], ['HERE.', 5.70]];
  const size = 205, x = 92, y0 = 760, lh = 196;
  words.forEach(([w, st], i) => {
    if (t < st) return;
    const k = easeOutExpo(lin(t, st, st + 0.5));
    const y = y0 + i * lh;
    ctx.save();
    ctx.beginPath(); ctx.rect(0, y - size * 0.78, WIDTH, size * 0.9); ctx.clip();
    const dy = (1 - k) * size * 0.8 - out * size * 0.9;
    text(w, x, y + dy, { size, tracking: -6, fill: chromeFill(y - size * 0.75, y), align: 'left' });
    ctx.restore();
  });
  // magenta period accent on HERE.
  if (t >= 5.70) {
    const k = easeOutExpo(lin(t, 5.75, 6.1)) * (1 - out);
    setFont(205); ctx.letterSpacing = '-6px';
    const w = ctx.measureText('HERE').width - 6;
    rect(x + w + 14, y0 + 2 * lh - 36, 34 * k, 36, C.magenta, 1);
  }
  // small caption line
  const ca = lin(t, 3.6, 4.0) * (1 - out);
  rect(92, 1215, 180 * easeOutExpo(lin(t, 3.6, 4.4)), 1, '#8B8E94', ca);
}

const CHAPTERS = [
  { start: 6.76, end: 10.0, idx: '01', word: 'PRECISION', line: 'NOTHING LEFT TO CHANCE' },
  { start: 10.0, end: 13.22, idx: '02', word: 'CRAFT', line: 'EVERY DETAIL BY DESIGN' },
  { start: 13.22, end: 16.48, idx: '03', word: 'PERFORMANCE', line: 'BUILT TO BE DRIVEN' },
  { start: 16.48, end: 19.75, idx: '04', word: 'OBSESSION', line: 'IT NEVER ENDS' },
];
function chapters(t) {
  for (const ch of CHAPTERS) {
    if (t < ch.start || t > ch.end) continue;
    chapterTag(t, ch.start, ch.idx + ' / 04', 'HANGAR');
    const r = bigWord(t, ch.word, ch.start, ch.end, { size: ch.word.length > 6 ? 230 : 300 });
    if (ch.word === 'OBSESSION') obsessionStutter(t, ch, r);
    rules(t, ch.start, ch.end, 1085, 520);
    const la = easeOutCubic(lin(t, ch.start + 0.35, ch.start + 0.9)) * (1 - lin(t, ch.end - 0.35, ch.end - 0.1));
    text(ch.line, WIDTH / 2, 1160, { size: 30, weight: 700, tracking: 9, fill: C.mute, alpha: la });
  }
}
// rolling hi-hats 18.1–19.5: horizontal slice displacement + magenta underline
function obsessionStutter(t, ch, r) {
  if (t < 18.1 || t > 19.6) return;
  const env_ = env('low', t);
  const step = Math.floor((t - 18.1) * 14);
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  const n = 3;
  for (let i = 0; i < n; i++) {
    const seed = Math.sin((step + 1) * (i + 3) * 12.9898) * 43758.5453; const rnd = seed - Math.floor(seed);
    const y = 880 + rnd * 180; const h = 8 + 26 * rnd;
    const dx = (rnd - 0.5) * 60 * env_;
    ctx.save(); ctx.beginPath(); ctx.rect(0, y, WIDTH, h); ctx.clip();
    ctx.globalAlpha = 0.35;
    text('OBSESSION', WIDTH / 2 + dx, 980, { size: r ? r.size : 230, tracking: -4, fill: '#9aa0a6' });
    ctx.restore();
  }
  ctx.restore();
  const u = easeOutExpo(lin(t, 18.1, 19.3)) * (1 - lin(t, 19.45, 19.7));
  rect(WIDTH / 2 - 260 * u, 1045, 520 * u, 3, C.magenta, 1);
}

function scene6(t) { // 19.75 – 23.0: NOT A GARAGE.
  if (t < 19.75 || t > 23.0) return;
  const out = easeInCubic(lin(t, 22.7, 22.98));
  const a1 = easeOutCubic(lin(t, 19.8, 20.3)) * (1 - out);
  text('NOT A', WIDTH / 2, 850, { size: 54, tracking: 22, fill: C.mute, alpha: a1 });
  bigWord(t, 'GARAGE.', 20.38, 23.0, { size: 250, y: 1060 });
  // strike line on the hi hit
  const s = easeOutExpo(lin(t, 21.31, 21.7)) * (1 - out);
  if (s > 0) rect(WIDTH / 2 - 440, 972, 880 * s, 6, C.text, 0.9);
}
function scene7(t) { // 23.0 – 26.31: A HOME / FOR MACHINES.
  if (t < 23.0 || t > 26.31) return;
  const out = easeInCubic(lin(t, 26.0, 26.29));
  const a1 = easeOutCubic(lin(t, 23.05, 23.5)) * (1 - out);
  text('A HOME', WIDTH / 2, 860, { size: 54, tracking: 22, fill: C.mute, alpha: a1 });
  bigWord(t, 'FOR MACHINES.', 23.0, 26.31, { size: 150, y: 1030, maxW: 960 });
  rules(t, 23.0, 26.31, 1110, 360);
}
function scene8(t) { // 26.31 – 29.63: FOR THOSE WHO / LIVE TO DRIVE.
  if (t < 26.31 || t > 29.63) return;
  const out = lin(t, 29.43, 29.62);
  const a1 = easeOutCubic(lin(t, 26.35, 26.8)) * (1 - out);
  text('FOR THOSE WHO', WIDTH / 2, 850, { size: 50, tracking: 18, fill: C.mute, alpha: a1 });
  // motion: speed-streak exit on the hat roll
  const dx = -easeInCubic(out) * 900;
  ctx.save(); ctx.translate(dx, 0);
  bigWord(t, 'LIVE TO DRIVE.', 26.31, 29.9, { size: 140, y: 1030, maxW: 960 });
  ctx.restore();
  if (t > 28.75) {
    const k = lin(t, 28.75, 29.6);
    for (let i = 0; i < 5; i++) {
      const y = 940 + i * 28; const len = 300 + 500 * k * ((i * 37) % 5) / 5;
      rect(WIDTH - (t - 28.75) * 2400 % (WIDTH + len) , y, len, 1, '#6d7076', 0.5 * (1 - out * 0.5));
    }
  }
}
function scene9(t) { // 29.63 – 32.68: THE DOORS / ARE OPENING — hangar doors part
  if (t < 29.63 || t > 32.9) return;
  const a1 = easeOutCubic(lin(t, 29.63, 30.1)) * (1 - lin(t, 32.2, 32.6));
  const a2 = easeOutCubic(lin(t, 30.86, 31.3)) * (1 - lin(t, 32.2, 32.6));
  // door seam light
  const open = easeInOutCubic(lin(t, 30.86, 32.68));
  const seam = lin(t, 29.8, 30.4);
  const gap = 4 + open * 1076;
  const glow = ctx.createLinearGradient(WIDTH / 2 - gap / 2 - 60, 0, WIDTH / 2 + gap / 2 + 60, 0);
  glow.addColorStop(0, 'rgba(210,214,220,0)');
  glow.addColorStop(0.5, `rgba(210,214,220,${0.10 + 0.25 * seam * (1 - open)})`);
  glow.addColorStop(1, 'rgba(210,214,220,0)');
  const sceneOut = 1 - lin(t, 32.2, 32.68);
  ctx.save(); ctx.globalAlpha = sceneOut;
  ctx.fillStyle = glow; ctx.fillRect(0, 300, WIDTH, 1320);
  // soft light spilling through the opening (horizontal falloff, vertical fade at ends)
  const sl = ctx.createLinearGradient(WIDTH / 2 - gap / 2, 0, WIDTH / 2 + gap / 2, 0);
  const la = (0.08 + 0.30 * seam) * (1 - 0.8 * open);
  sl.addColorStop(0, 'rgba(214,217,222,0)'); sl.addColorStop(0.5, `rgba(214,217,222,${la})`); sl.addColorStop(1, 'rgba(214,217,222,0)');
  ctx.fillStyle = sl; ctx.fillRect(WIDTH / 2 - gap / 2, 300, gap, 1320);
  const vf = ctx.createLinearGradient(0, 300, 0, 1620);
  vf.addColorStop(0, 'rgba(6,6,7,1)'); vf.addColorStop(0.15, 'rgba(6,6,7,0)'); vf.addColorStop(0.85, 'rgba(6,6,7,0)'); vf.addColorStop(1, 'rgba(6,6,7,1)');
  ctx.fillStyle = vf; ctx.fillRect(0, 299, WIDTH, 1322);
  ctx.restore();
  // door panels: vertical ribs sliding apart
  for (const side of [-1, 1]) {
    const edge = WIDTH / 2 + side * gap / 2;
    for (let i = 0; i < 9; i++) {
      const x = edge + side * (i * 64 + 32);
      if (x < 0 || x > WIDTH) continue;
      rect(x, 300, 1, 1320, '#2c2e33', (1 - open) * 0.9);
    }
  }
  text('THE DOORS', WIDTH / 2, 760, { size: 118, tracking: 4, fill: chromeFill(660, 770), alpha: a1 });
  text('ARE OPENING', WIDTH / 2, 1250, { size: 70, tracking: 20, fill: C.text, alpha: a2 });
}

// ---------- finale: car + logo ----------
function finale(t) {
  if (t < 32.68) return;
  const car = window.CAR;
  if (car && t < 35.6) {
    const a = easeOutCubic(lin(t, 32.68, 33.4)) * (1 - lin(t, 35.52, 35.6));
    const lift = 0.55 + 0.45 * easeOutCubic(lin(t, 34.47, 34.9));
    const z = 1.08 - 0.06 * easeOutCubic(lin(t, 32.68, 35.6));
    const iw = car.naturalWidth || car.width, ih = car.naturalHeight || car.height;
    const s = (car.isPlaceholder ? 1000 / iw : Math.max(WIDTH / iw, 1100 / ih)) * z;
    const dw = iw * s, dh = ih * s;
    ctx.save();
    ctx.globalAlpha = a;
    ctx.filter = `brightness(${lift}) contrast(1.08) saturate(0.85)`;
    ctx.drawImage(car, WIDTH / 2 - dw / 2, 960 - dh / 2, dw, dh);
    ctx.filter = 'none';
    // light sweep on the hi-hat roll
    const sx = mix(-400, WIDTH + 400, easeInOutCubic(lin(t, 33.08, 34.2)));
    if (t > 33.0 && t < 34.3) {
      ctx.globalCompositeOperation = 'screen';
      const g = ctx.createLinearGradient(sx - 220, 0, sx + 220, 0);
      g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(0.5, `rgba(255,255,255,${car.isPlaceholder ? 0.35 : 0.22})`); g.addColorStop(1, 'rgba(255,255,255,0)');
      if (car.isPlaceholder) maskedSweep(car, WIDTH / 2 - dw / 2, 960 - dh / 2, dw, dh, g);
      else { ctx.fillStyle = g; ctx.fillRect(0, 960 - dh / 2, WIDTH, dh); }
    }
    ctx.restore();
    // edge fades to blend a photo into black (the drawn placeholder is already transparent)
    if (!car.isPlaceholder) {
    const fe = ctx.createLinearGradient(0, 960 - dh / 2, 0, 960 + dh / 2);
    fe.addColorStop(0, 'rgba(6,6,7,1)'); fe.addColorStop(0.18, 'rgba(6,6,7,0)'); fe.addColorStop(0.82, 'rgba(6,6,7,0)'); fe.addColorStop(1, 'rgba(6,6,7,1)');
    ctx.fillStyle = fe; ctx.fillRect(0, 960 - dh / 2 - 1, WIDTH, dh + 2);
    rect(0, 0, WIDTH, 960 - dh / 2, C.bg, 1); rect(0, 960 + dh / 2, WIDTH, HEIGHT, C.bg, 1);
    }
  }
  // stabs: WELCOME / TO THE
  const st = [[34.95, 'WELCOME'], [35.14, 'TO THE']];
  if (t >= 34.95 && t < 35.6) {
    const cur = t >= 35.14 ? 1 : 0;
    const [s0, w] = st[cur];
    const k = easeOutExpo(lin(t, s0, s0 + 0.12));
    text(w, WIDTH / 2, 1290, { size: 96, tracking: 18, fill: C.text, alpha: k * (1 - lin(t, 35.5, 35.6)) });
  }
  // logo slam at 35.89
  if (t >= 35.89) {
    const L = window.LOGO; const k = easeOutExpo(lin(t, 35.89, 36.5));
    const s = (1.10 - 0.10 * k) * 880 / L.naturalWidth;
    const dw = L.naturalWidth * s, dh = L.naturalHeight * s;
    const fadeEnd = 1 - lin(t, 37.0, 37.33) * 0.0;
    ctx.save();
    ctx.globalAlpha = lin(t, 35.89, 35.95) * fadeEnd;
    ctx.globalCompositeOperation = 'lighten';
    ctx.drawImage(L, WIDTH / 2 - dw / 2, 900 - dh / 2, dw, dh);
    ctx.restore();
    // specular sweep across the chrome
    const sx = mix(-300, WIDTH + 300, easeInOutCubic(lin(t, 36.0, 36.9)));
    if (t > 36.0 && t < 36.95) {
      ctx.save();
      ctx.beginPath(); ctx.rect(WIDTH / 2 - dw / 2, 900 - dh / 2, dw, dh); ctx.clip();
      ctx.globalCompositeOperation = 'lighter';
      const g = ctx.createLinearGradient(sx - 120, 0, sx + 120, 0);
      g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(0.5, 'rgba(255,255,255,0.28)'); g.addColorStop(1, 'rgba(255,255,255,0)');
      // restrict sweep to the lettering by using the logo as a mask
      ctx.fillStyle = g; ctx.globalAlpha = 1;
      maskedSweep(L, WIDTH / 2 - dw / 2, 900 - dh / 2, dw, dh, g);
      ctx.restore();
    }
    const u = easeOutExpo(lin(t, 36.05, 36.8));
    rect(WIDTH / 2 - 150 * u, 900 + dh / 2 + 46, 300 * u, 3, C.magenta, 1);
    const ta = easeOutCubic(lin(t, 36.2, 36.7));
    text('LAUNCHING NOW', WIDTH / 2, 900 + dh / 2 + 118, { size: 28, tracking: 14, fill: C.mute, alpha: ta });
  }
}
// sweep only where the logo is bright: draw gradient into an offscreen canvas masked by the logo
let sweepCanvas = null;
function maskedSweep(L, x, y, w, h, grad) {
  if (!sweepCanvas) { sweepCanvas = document.createElement('canvas'); sweepCanvas.width = WIDTH; sweepCanvas.height = HEIGHT; }
  const s = sweepCanvas.getContext('2d');
  s.globalCompositeOperation = 'source-over'; s.clearRect(0, 0, WIDTH, HEIGHT);
  s.drawImage(L, x, y, w, h);
  s.globalCompositeOperation = 'source-in';
  s.fillStyle = grad; s.fillRect(x, y, w, h);
  ctx.drawImage(sweepCanvas, 0, 0);
}

function drawFrame(t) {
  ctx = ctx || document.getElementById('c').getContext('2d');
  ctx.save();
  background(t);
  scene0(t); scene1(t); chapters(t); scene6(t); scene7(t); scene8(t); scene9(t);
  finale(t);
  frameUI(t);
  flash(t);
  subtitles(t);
  ctx.restore();
}
window.drawFrame = drawFrame;

// ---------- placeholder car: minimal side-profile silhouette drawn to an offscreen canvas ----------
function makeCarPlaceholder() {
  const cv = document.createElement('canvas'); cv.width = 1600; cv.height = 700;
  const x = cv.getContext('2d');
  const body = new Path2D();
  body.moveTo(120, 505);
  body.bezierCurveTo(95, 480, 100, 445, 190, 425);        // nose
  body.lineTo(560, 372);                                   // hood
  body.bezierCurveTo(640, 330, 700, 268, 790, 248);        // windshield
  body.bezierCurveTo(900, 232, 1010, 236, 1090, 262);      // roof
  body.bezierCurveTo(1240, 315, 1390, 360, 1480, 392);     // fastback
  body.bezierCurveTo(1510, 405, 1515, 450, 1500, 500);     // tail
  body.lineTo(1395, 510);
  body.arc(1270, 510, 125, 0, Math.PI, true);              // rear arch
  body.lineTo(505, 510);
  body.arc(380, 510, 125, 0, Math.PI, true);               // front arch
  body.closePath();
  // ground shadow
  const sh = x.createRadialGradient(800, 640, 20, 800, 640, 760);
  sh.addColorStop(0, 'rgba(0,0,0,0.9)'); sh.addColorStop(1, 'rgba(0,0,0,0)');
  x.save(); x.scale(1, 0.12); x.fillStyle = sh; x.fillRect(0, 640 / 0.12 - 700, 1600, 1400); x.restore();
  // body
  const g = x.createLinearGradient(0, 240, 0, 520);
  g.addColorStop(0, '#3a3d43'); g.addColorStop(0.35, '#1d1f23'); g.addColorStop(0.6, '#2b2e33'); g.addColorStop(1, '#0d0e10');
  x.fillStyle = g; x.fill(body);
  // glasshouse
  const glass = new Path2D();
  glass.moveTo(640, 360); glass.bezierCurveTo(700, 320, 740, 285, 800, 270);
  glass.bezierCurveTo(900, 256, 1000, 258, 1070, 280); glass.bezierCurveTo(1150, 310, 1200, 335, 1230, 352); glass.closePath();
  x.fillStyle = '#0b0c0e'; x.fill(glass);
  // shoulder crease
  x.strokeStyle = 'rgba(200,204,210,0.35)'; x.lineWidth = 2;
  x.beginPath(); x.moveTo(210, 440); x.bezierCurveTo(700, 400, 1100, 400, 1480, 420); x.stroke();
  // rim light along the roofline
  const rim = x.createLinearGradient(100, 0, 1500, 0);
  rim.addColorStop(0, 'rgba(255,255,255,0)'); rim.addColorStop(0.45, 'rgba(235,238,242,0.95)'); rim.addColorStop(1, 'rgba(255,255,255,0.1)');
  x.strokeStyle = rim; x.lineWidth = 3;
  x.beginPath(); x.moveTo(190, 425); x.lineTo(560, 372); x.bezierCurveTo(640, 330, 700, 268, 790, 248);
  x.bezierCurveTo(900, 232, 1010, 236, 1090, 262); x.bezierCurveTo(1240, 315, 1390, 360, 1480, 392); x.stroke();
  // wheels
  for (const cx of [380, 1270]) {
    x.fillStyle = '#050506'; x.beginPath(); x.arc(cx, 510, 110, 0, Math.PI * 2); x.fill();
    const rg = x.createRadialGradient(cx, 510, 20, cx, 510, 80);
    rg.addColorStop(0, '#2f3237'); rg.addColorStop(0.8, '#16171a'); rg.addColorStop(1, '#5c6066');
    x.fillStyle = rg; x.beginPath(); x.arc(cx, 510, 78, 0, Math.PI * 2); x.fill();
    x.strokeStyle = 'rgba(180,184,190,0.5)'; x.lineWidth = 2;
    for (let k = 0; k < 5; k++) { const a = k * Math.PI * 2 / 5; x.beginPath(); x.moveTo(cx + Math.cos(a) * 18, 510 + Math.sin(a) * 18); x.lineTo(cx + Math.cos(a) * 72, 510 + Math.sin(a) * 72); x.stroke(); }
  }
  // headlight + tail light
  x.fillStyle = '#f4f6f8'; x.fillRect(150, 432, 110, 5);
  x.fillStyle = C.magenta; x.fillRect(1440, 402, 60, 4);
  return cv;
}
window.makeCarPlaceholder = makeCarPlaceholder;
