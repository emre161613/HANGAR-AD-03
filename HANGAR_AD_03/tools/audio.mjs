#!/usr/bin/env node
// HANGAR_AD_03 sound design — fully synthesized, sample-accurate to src/timeline.js.
//   node tools/audio.mjs [out.wav]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { CUE, DURATION, LAMP_TIMES, engineRpm, throttle, roadSpeed, lampPasses, clamp, smooth, mix } from '../src/timeline.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT = path.resolve(ROOT, process.argv[2] || 'output/audio.wav');
const SR = 48000;
const N = Math.ceil(DURATION * SR);
const TAU = Math.PI * 2;
const at = (t) => Math.round(t * SR);
const dB = (d) => Math.pow(10, d / 20);

// ------------------------------------------------------------ DSP building blocks
let seed = 1234567;
const rand = () => { seed = (seed + 0x6D2B79F5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t ^= t + Math.imul(t ^ (t >>> 7), 61 | t); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
const white = () => rand() * 2 - 1;

class Biquad {
  constructor(type, f, q = 0.707, gain = 0) { this.x1 = this.x2 = this.y1 = this.y2 = 0; this.set(type, f, q, gain); }
  set(type, f, q = 0.707, gain = 0) {
    f = Math.min(Math.max(f, 10), SR * 0.45);
    const w = TAU * f / SR, c = Math.cos(w), s = Math.sin(w), a = s / (2 * q), A = Math.pow(10, gain / 40);
    let b0, b1, b2, a0, a1, a2;
    if (type === 'lp') { b0 = (1 - c) / 2; b1 = 1 - c; b2 = b0; a0 = 1 + a; a1 = -2 * c; a2 = 1 - a; }
    else if (type === 'hp') { b0 = (1 + c) / 2; b1 = -(1 + c); b2 = b0; a0 = 1 + a; a1 = -2 * c; a2 = 1 - a; }
    else if (type === 'bp') { b0 = a; b1 = 0; b2 = -a; a0 = 1 + a; a1 = -2 * c; a2 = 1 - a; }
    else { b0 = 1 + a * A; b1 = -2 * c; b2 = 1 - a * A; a0 = 1 + a / A; a1 = -2 * c; a2 = 1 - a / A; } // peak
    this.b0 = b0 / a0; this.b1 = b1 / a0; this.b2 = b2 / a0; this.a1 = a1 / a0; this.a2 = a2 / a0;
  }
  p(x) { const y = this.b0 * x + this.b1 * this.x1 + this.b2 * this.x2 - this.a1 * this.y1 - this.a2 * this.y2; this.x2 = this.x1; this.x1 = x; this.y2 = this.y1; this.y1 = y; return y; }
}
class OnePole { constructor(f) { this.y = 0; this.set(f); } set(f) { this.a = Math.exp(-TAU * f / SR); } p(x) { this.y = x + (this.y - x) * this.a; return this.y; } }

// stereo buses
const bus = () => [new Float32Array(N), new Float32Array(N)];
const SFX = bus(), ENG = bus(), MUS = bus(), SEND = bus();
function put(b, i, v, pan = 0) { if (i < 0 || i >= N) return; const l = Math.cos((pan + 1) * Math.PI / 4), r = Math.sin((pan + 1) * Math.PI / 4); b[0][i] += v * l * 1.414; b[1][i] += v * r * 1.414; }

// decaying resonant modes (metal)
function modes(t0, list, gain, pan = 0, send = 0.2) {
  const i0 = at(t0);
  for (const [f, dec, g] of list) {
    const len = Math.min(N - i0, Math.round(dec * 6 * SR));
    for (let k = 0; k < len; k++) {
      const v = Math.sin(TAU * f * k / SR + g) * Math.exp(-k / (dec * SR)) * gain * (Math.abs(g) + 0.2) * 0.5;
      put(SFX, i0 + k, v, pan); put(SEND, i0 + k, v * send, pan);
    }
  }
}
function noiseBurst(t0, dur, type, f, q, gain, pan = 0, attack = 0.0005, send = 0.15, b = SFX) {
  const i0 = at(t0), len = Math.round(dur * SR); const flt = new Biquad(type, f, q);
  for (let k = 0; k < len; k++) {
    const e = Math.min(1, k / (attack * SR + 1)) * Math.exp(-k / (dur * SR * 0.25));
    const v = flt.p(white()) * e * gain; put(b, i0 + k, v, pan); put(SEND, i0 + k, v * send, pan);
  }
}
function thump(t0, f0, f1, dur, gain, pan = 0, send = 0.1) {
  const i0 = at(t0), len = Math.round(dur * SR * 4); let ph = 0;
  for (let k = 0; k < len; k++) {
    const x = k / SR; const f = f1 + (f0 - f1) * Math.exp(-x / (dur * 0.5)); ph += TAU * f / SR;
    const v = Math.sin(ph) * Math.exp(-x / dur) * Math.min(1, k / 48) * gain; put(SFX, i0 + k, v, pan); put(SEND, i0 + k, v * send, pan);
  }
}

// ------------------------------------------------------------ 1. room tone + rain bed (until the cut)
{
  const lp = new Biquad('lp', 380, 0.6), lp2 = new OnePole(3000), hp = new Biquad('hp', 2500, 0.7);
  for (let i = 0; i < at(CUE.cut); i++) {
    const t = i / SR; const e = smooth(0, 0.6, t) * (t < CUE.road ? 1 : 0.35);
    const room = lp.p(white()) * 0.05;
    const drops = rand() < 0.0009 ? white() * 0.25 : 0; // sparse drops on the roof
    const rain = hp.p(lp2.p(white() * 0.4 + drops)) * 0.012;
    put(SFX, i, (room + rain) * e * dB(-6), 0);
  }
}

// ------------------------------------------------------------ 2. START: press creak, heavy click, release
noiseBurst(CUE.press, CUE.click - CUE.press, 'bp', 1800, 3, 0.02, -0.1, 0.05);
noiseBurst(CUE.click, 0.004, 'hp', 2500, 0.7, 0.9, -0.1, 0.0001, 0.3);
modes(CUE.click, [[2150, 0.03, 1], [3420, 0.022, 0.8], [5230, 0.014, 0.6], [7100, 0.009, 0.5]], 0.5, -0.1, 0.35);
thump(CUE.click, 160, 85, 0.06, 0.55, -0.1);
noiseBurst(2.2, 0.003, 'hp', 3000, 0.7, 0.35, -0.1, 0.0001, 0.3);
modes(2.2, [[2600, 0.018, 1], [4100, 0.012, 0.7]], 0.2, -0.1);

// ------------------------------------------------------------ 3. starter motor + compression chugs
{
  const i0 = at(CUE.crank), i1 = at(CUE.fire + 0.06);
  const bp = new Biquad('bp', 900, 1.2), lp = new Biquad('lp', 400, 0.8), hp = new Biquad('hp', 60, 0.7);
  let ph = 0, cph = 0;
  // relay + solenoid engage
  noiseBurst(CUE.crank - 0.02, 0.004, 'hp', 2000, 0.7, 0.5, 0.05, 0.0001);
  modes(CUE.crank - 0.02, [[1200, 0.03, 1], [2900, 0.02, 0.6]], 0.35, 0.05);
  for (let i = i0; i < i1; i++) {
    const t = i / SR, k = t - CUE.crank;
    const comp = 0.5 + 0.5 * Math.sin(TAU * 9.2 * k);         // compression strokes
    const load = Math.pow(comp, 3);
    const f = (175 + 40 * smooth(0, 0.9, k)) * (1 - 0.12 * load);
    ph += TAU * f / SR; cph += TAU * 9.2 / SR;
    let whine = 0; for (let h = 1; h <= 7; h++) whine += Math.sin(ph * h) / h;
    const env = smooth(0, 0.05, k) * (1 - smooth(CUE.fire - CUE.crank, CUE.fire - CUE.crank + 0.06, k));
    const w = bp.p(whine) * 0.22 + whine * 0.05;
    const chug = lp.p(white()) * load * 0.9 + Math.sin(cph * 0.5 + Math.sin(cph) * 2) * load * 0.25;
    put(SFX, i, hp.p(w + chug) * env * dB(-3), 0);
  }
}

// ------------------------------------------------------------ 4. engine — V8 firing model driven by rpm(t) & throttle(t)
{
  const pattern = [1.0, 0.78, 1.12, 0.7, 1.05, 0.82, 1.18, 0.74];      // cross-plane unevenness
  const f1 = new Biquad('bp', 105, 2.2), f2 = new Biquad('bp', 240, 3), f3 = new Biquad('bp', 540, 4), f4 = new Biquad('bp', 1400, 5);
  const body = new Biquad('lp', 900, 0.7), dc = new Biquad('hp', 28, 0.7), air = new Biquad('bp', 2600, 1.5);
  const loadLP = new Biquad('lp', 2000, 0.6), thrS = new OnePole(12), rpmS = new OnePole(40);
  let ph = 0, fireIdx = 0, pulse = 0, pulseAmp = 0, whPh = 0;
  let popT = -1; const pops = [];
  const i0 = at(CUE.fire - 0.02), i1 = at(CUE.cut);
  for (let i = i0; i < i1; i++) {
    const t = i / SR;
    const rpm = rpmS.p(Math.max(0, engineRpm(t)));
    const thr = thrS.p(throttle(t));
    const f = rpm / 60 * 4;
    ph += f / SR;
    if (ph >= 1) {
      ph -= 1; fireIdx++;
      let a = pattern[fireIdx % 8] * (0.55 + 0.9 * thr) * (0.9 + 0.2 * rand());
      if (t < CUE.fire + 0.25 && rand() < 0.3) a *= 2.2;                   // rough first catches
      if (t >= CUE.insert && Math.sin(t * TAU * 11) > 0.55) { a *= 0.05; if (rand() < 0.4) pops.push(t); } // limiter cut
      pulseAmp = a; pulse = 0;
      if (thr < 0.1 && rpm > 2200 && rand() < 0.08) pops.push(t + rand() * 0.02); // overrun crackle
    }
    // per-firing pressure pulse (sharp attack, exponential decay within the firing interval)
    pulse += 1 / SR;
    const decay = Math.exp(-pulse * (60 + rpm * 0.05));
    const exc = pulseAmp * decay * (Math.sin(pulse * TAU * 90) * 0.6 + 0.4) + white() * pulseAmp * decay * 0.25;
    loadLP.set('lp', 700 + thr * 3200 + rpm * 0.35, 0.6);
    let y = f1.p(exc) * 1.6 + f2.p(exc) * 1.1 + f3.p(exc) * (0.5 + thr * 0.6) + f4.p(exc) * (0.1 + thr * 0.5 * rpm / 7000);
    y += body.p(exc) * 0.8;
    y = loadLP.p(y);
    // valvetrain / intake whine
    whPh += TAU * (rpm / 60 * 12) / SR;
    y += Math.sin(whPh) * 0.012 * (rpm / 7000) + air.p(white()) * 0.02 * thr * rpm / 7000;
    // drive into a soft clipper — more grit under load
    const drive = 1.4 + thr * 2.2;
    y = Math.tanh(dc.p(y) * drive) / Math.tanh(drive);
    let g = dB(-6) * (0.45 + 0.55 * Math.min(1, rpm / 3000)) * (0.7 + 0.3 * thr);
    if (t >= CUE.road) g *= 1.08;
    put(ENG, i, y * g, 0);
    put(SEND, i, y * g * 0.08, 0);
  }
  // exhaust pops
  for (const pt of pops) { noiseBurst(pt, 0.03, 'bp', 700 + rand() * 900, 1.2, 0.35, (rand() - 0.5) * 0.4, 0.0002, 0.25, ENG); thump(pt, 140, 70, 0.02, 0.2); }
}

// ------------------------------------------------------------ 5. dash waking: relay ticks, toggle clicks, cluster buzz, needle servo
LAMP_TIMES.forEach((lt, k) => { noiseBurst(lt, 0.002, 'hp', 4000, 0.7, 0.18, -0.3 + k * 0.1, 0.0001, 0.2); modes(lt, [[4200 + k * 150, 0.008, 1]], 0.06, -0.3 + k * 0.1); });
[2.78, 2.93, 3.08, 3.2].forEach((tt, k) => {
  noiseBurst(tt + 0.045, 0.003, 'hp', 2200, 0.7, 0.55, 0.1 + k * 0.08, 0.0001, 0.3);
  modes(tt + 0.045, [[3100, 0.02, 1], [5600, 0.012, 0.7], [410, 0.03, 0.5]], 0.28, 0.1 + k * 0.08, 0.3);
});
{
  const i0 = at(CUE.clusterOn), i1 = at(CUE.clusterOn + 0.4); const bp = new Biquad('bp', 3000, 3);
  for (let i = i0; i < i1; i++) { const k = i / SR - CUE.clusterOn; const e = Math.exp(-k / 0.12) * (Math.sin(k * 200) > 0 ? 1 : 0.4); put(SFX, i, (Math.sin(TAU * 100 * k) * 0.3 + Math.sin(TAU * 300 * k) * 0.2 + bp.p(white()) * 0.3) * e * 0.05, 0.1); }
  const j0 = at(CUE.sweep), j1 = at(CUE.sweepEnd); const lp = new Biquad('bp', 1600, 2);
  for (let i = j0; i < j1; i++) { const k = (i - j0) / (j1 - j0); put(SFX, i, lp.p(white()) * Math.sin(Math.PI * k) * 0.025, 0.05); }
}

// ------------------------------------------------------------ 6. transitions: dive riser + hit, whip + hit
function riser(t0, t1, f0, f1, gain, pan = 0) {
  const i0 = at(t0), i1 = at(t1); const bp = new Biquad('bp', f0, 1.4);
  for (let i = i0; i < i1; i++) { const k = (i - i0) / (i1 - i0); bp.set('bp', f0 * Math.pow(f1 / f0, k), 1.4); const v = bp.p(white()) * Math.pow(k, 2.2) * gain; put(SFX, i, v, pan); put(SEND, i, v * 0.4, pan); }
}
riser(CUE.dive, CUE.mech, 300, 5000, 0.4);
thump(CUE.mech, 110, 42, 0.18, 0.6); noiseBurst(CUE.mech, 0.25, 'hp', 3500, 0.8, 0.12, 0, 0.001, 0.5);
riser(9.82, CUE.road, 400, 6000, 0.5);
thump(CUE.road, 90, 38, 0.2, 0.7); noiseBurst(CUE.road, 0.3, 'bp', 900, 0.8, 0.2, 0, 0.001, 0.5);

// ------------------------------------------------------------ 7. mechanical world: gear whir, gated shift, pedal
{
  const i0 = at(CUE.mech), i1 = at(CUE.road); let p1 = 0, p2 = 0; const bp = new Biquad('bp', 2500, 6);
  for (let i = i0; i < i1; i++) {
    const t = i / SR; const rpm = engineRpm(t); const r = Math.sqrt(Math.max(rpm, 500) / 1000);
    p1 += TAU * 310 * r / SR; p2 += TAU * 517 * r / SR;
    const e = smooth(CUE.mech, CUE.mech + 0.3, t) * (1 - smooth(9.9, CUE.road, t));
    const tick = Math.pow(Math.max(0, Math.sin(p1 * 0.05)), 40);
    put(SFX, i, (Math.sin(p1) * 0.03 + Math.sin(p2) * 0.018 + bp.p(white()) * 0.02 * tick) * e, 0.25);
  }
  const s = CUE.shift1;
  noiseBurst(s - 0.1, 0.08, 'hp', 3000, 0.7, 0.07, -0.2, 0.01);      // lever leaves neutral (slide)
  noiseBurst(s - 0.02, 0.003, 'hp', 2500, 0.7, 0.35, -0.25, 0.0001);   // knock on the cross-gate
  modes(s - 0.02, [[1900, 0.02, 1], [3300, 0.012, 0.6]], 0.2, -0.25);
  // THE CLUNK: gate stop + dog engagement
  noiseBurst(s + 0.08, 0.006, 'hp', 1500, 0.7, 0.8, -0.2, 0.0001, 0.35);
  modes(s + 0.08, [[820, 0.09, 1], [1330, 0.07, 0.8], [2110, 0.05, 0.7], [3170, 0.035, 0.5], [4400, 0.02, 0.4]], 0.55, -0.2, 0.4);
  thump(s + 0.08, 140, 62, 0.11, 0.8, -0.2, 0.2);
  // pedal: spring creak down, bottoming thud
  noiseBurst(CUE.pedal, 0.2, 'bp', 1100, 6, 0.03, 0.15, 0.03);
  thump(CUE.pedal + 0.22, 100, 55, 0.08, 0.45, 0.15);
  modes(CUE.pedal + 0.22, [[1500, 0.03, 1], [2600, 0.02, 0.6]], 0.12, 0.15);
}

// ------------------------------------------------------------ 8. road: tyre roar, wet hiss, wind, lamp whooshes, overtake, upshift
{
  const i0 = at(CUE.road - 0.05), i1 = at(CUE.insert);
  const roarL = new Biquad('lp', 300, 0.7), roarR = new Biquad('lp', 300, 0.7), hissL = new Biquad('bp', 4500, 0.8), hissR = new Biquad('bp', 4500, 0.8);
  const windL = new Biquad('lp', 700, 0.5), windR = new Biquad('lp', 700, 0.5), mod = new OnePole(0.7);
  for (let i = i0; i < i1; i++) {
    const t = i / SR; const v = roadSpeed(t); const k = v / 60;
    roarL.set('lp', 160 + v * 7, 0.7); roarR.set('lp', 160 + v * 7, 0.7);
    const m = 0.8 + 0.4 * mod.p(white() * 4);
    const e = smooth(CUE.road - 0.05, CUE.road + 0.15, t);
    const low = CUE.rise > t ? 1.3 : 1;   // camera at asphalt level: more tyre, more hiss
    const L = roarL.p(white()) * 0.22 * k * low + hissL.p(white()) * 0.05 * k * k * low + windL.p(white()) * 0.12 * k * k * m;
    const R = roarR.p(white()) * 0.22 * k * low + hissR.p(white()) * 0.05 * k * k * low + windR.p(white()) * 0.12 * k * k * m;
    SFX[0][i] += L * e; SFX[1][i] += R * e;
  }
  for (const lt of lampPasses()) {
    const i0 = at(lt - 0.12), len = Math.round(0.45 * SR); const bp = new Biquad('bp', 1200, 1.2);
    for (let k = 0; k < len; k++) { const x = k / len; bp.set('bp', 1400 * (1 - 0.6 * x), 1.2); const v = bp.p(white()) * Math.sin(Math.PI * x) ** 2 * 0.05 * (roadSpeed(lt) / 50); put(SFX, i0 + k, v, 0.35 - 0.7 * x); }
  }
  // overtaken car: doppler whoosh + its engine, left side passing front -> back
  const tp = CUE.overtake + 16 / 30;
  {
    const i0 = at(tp - 0.7), len = Math.round(1.3 * SR); const bp = new Biquad('bp', 600, 1.0); let ph = 0;
    for (let k = 0; k < len; k++) {
      const x = k / len; const dt = (k / SR) - 0.7; const prox = 1 / (1 + (dt * 30 / 3.7) ** 2);
      const f = 180 * (1 + (dt < 0 ? 0.08 : -0.08)); ph += TAU * f / SR;
      const v = (bp.p(white()) * 0.35 + Math.tanh(Math.sin(ph) * 3) * 0.08) * prox;
      put(SFX, i0 + k, v * 0.8, -0.2 - 0.6 * x);
    }
  }
  noiseBurst(CUE.shiftUp, 0.004, 'hp', 1800, 0.7, 0.4, -0.2, 0.0001, 0.2);
  modes(CUE.shiftUp + 0.12, [[900, 0.06, 1], [1450, 0.05, 0.7], [2300, 0.03, 0.5]], 0.28, -0.2, 0.25);
  thump(CUE.shiftUp + 0.12, 120, 60, 0.08, 0.5, -0.2);
}

// ------------------------------------------------------------ 9. music: dark drone + sub pulse + riser (kept under the SFX)
{
  const i0 = at(CUE.fire), i1 = at(CUE.cut);
  const lp = new Biquad('lp', 260, 0.9), lp2 = new Biquad('lp', 260, 0.9);
  const notes = [36.71, 55.0, 73.42, 36.71 * 1.004];
  const ph = notes.map(() => 0); let sub = 0;
  for (let i = i0; i < i1; i++) {
    const t = i / SR;
    let saw = 0; notes.forEach((f, k) => { ph[k] += f / SR; ph[k] %= 1; saw += (ph[k] * 2 - 1) * (k === 2 ? 0.5 : 1); });
    const intensity = smooth(CUE.fire, 4.5, t) * 0.6 + smooth(CUE.road, CUE.insert, t) * 0.6;
    const cutoff = 140 + 520 * intensity;
    lp.set('lp', cutoff, 0.9); lp2.set('lp', cutoff * 1.03, 0.9);
    // heartbeat pulse: 84 bpm, doubling on the road
    const bpm = t < CUE.road ? 84 : 168;
    const beat = ((t - CUE.fire) * bpm / 60) % 1;
    const kick = Math.exp(-beat * 9) * Math.sin(TAU * 48 * beat / 0.9);
    sub = kick * (0.4 + 0.5 * intensity);
    const drone = 0.08 * intensity + 0.03;
    const L = lp.p(saw) * drone + sub * 0.3, R = lp2.p(saw * 0.98) * drone + sub * 0.3;
    MUS[0][i] += L; MUS[1][i] += R;
  }
  riser(12.6, CUE.cut, 200, 7000, 0.18, 0);
}

// ------------------------------------------------------------ 10. finale: title impact, logo swell, cooling-exhaust ticks
{
  const t0 = CUE.title;
  thump(t0, 64, 30, 0.42, 1.1, 0, 0.25);
  noiseBurst(t0, 0.035, 'bp', 2200, 0.7, 0.9, 0, 0.0001, 0.6);
  noiseBurst(t0, 0.5, 'lp', 400, 0.7, 0.35, 0, 0.001, 0.4);
  modes(t0, [[182, 0.45, 1], [431, 0.32, 0.6], [777, 0.22, 0.45], [1290, 0.14, 0.3]], 0.35, 0, 0.5);
  // title out: soft air
  noiseBurst(CUE.titleOff, 0.2, 'hp', 3000, 0.7, 0.03, 0, 0.05, 0.6);
  // logo: low swell
  const i0 = at(CUE.logo), i1 = N; let ph = 0;
  for (let i = i0; i < i1; i++) {
    const t = i / SR; ph += TAU * 41.2 / SR;
    const e = smooth(CUE.logo, CUE.logo + 0.8, t) * (1 - smooth(CUE.fadeOut - 0.4, DURATION, t));
    put(MUS, i, (Math.sin(ph) + 0.3 * Math.sin(ph * 2.01)) * 0.13 * e, 0);
  }
  [17.25, 17.9, 18.35, 18.7, 19.05].forEach((tt, k) => {
    modes(tt, [[5200 + k * 330, 0.03, 1], [7900 - k * 210, 0.02, 0.6]], 0.07, k % 2 ? 0.4 : -0.4, 0.7);
  });
}

// ------------------------------------------------------------ mix: ducking, hard cut, reverb, limiter
const out = bus();
{
  // sidechain: music ducks under SFX + engine
  const env = new OnePole(8);
  for (let i = 0; i < N; i++) {
    const t = i / SR;
    const key = Math.abs(SFX[0][i]) + Math.abs(ENG[0][i]) * 0.5;
    const e = env.p(key);
    const duck = 1 / (1 + 4 * e);
    const cut = t >= CUE.cut && t < CUE.title ? 0 : 1;
    const preCut = t < CUE.cut;
    for (let c = 0; c < 2; c++) {
      // before the cut: everything; after: only finale material (which starts after the cut)
      const s = (SFX[c][i] + ENG[c][i] * 1.0) * (preCut ? 1 : 1) + MUS[c][i] * dB(-3) * duck;
      out[c][i] = s * cut;
    }
  }
  // hard cut edge: 3 ms fade to avoid a click
  const ic = at(CUE.cut); for (let k = 0; k < 144; k++) for (let c = 0; c < 2; c++) out[c][ic - 144 + k] *= 1 - k / 144;
  // reverb (Schroeder/Freeverb style): tail keeps ringing through the cut
  const combs = [[1557, 1617, 1491, 1422], [1277, 1356, 1188, 1116]].map((ls, c) => ls.map((l) => ({ buf: new Float32Array(l + c * 23), i: 0, fb: 0.84, lp: 0 })));
  const aps = [[556, 441], [579, 464]].map((ls) => ls.map((l) => ({ buf: new Float32Array(l), i: 0 })));
  for (let i = 0; i < N; i++) {
    for (let c = 0; c < 2; c++) {
      const x = SEND[c][i] * 0.5 + (i < at(CUE.cut) ? 0 : 0);
      let y = 0;
      for (const cb of combs[c]) { const o = cb.buf[cb.i]; cb.lp = o * 0.7 + cb.lp * 0.3; cb.buf[cb.i] = x + cb.lp * cb.fb; cb.i = (cb.i + 1) % cb.buf.length; y += o; }
      for (const ap of aps[c]) { const o = ap.buf[ap.i]; const v = y + o * 0.5; ap.buf[ap.i] = v; ap.i = (ap.i + 1) % ap.buf.length; y = o - v * 0.5; }
      out[c][i] += y * 0.22;
    }
  }
  // soft limiter + normalise to -1 dBFS peak
  let peak = 0;
  for (let c = 0; c < 2; c++) for (let i = 0; i < N; i++) { out[c][i] = Math.tanh(out[c][i] * 1.2) / 1.2; peak = Math.max(peak, Math.abs(out[c][i])); }
  const g = dB(-1) / (peak || 1);
  for (let c = 0; c < 2; c++) for (let i = 0; i < N; i++) out[c][i] *= g;
  // silence between the title and the logo (let the impact ring out, then true quiet)
  { const a = at(CUE.titleOff - 0.2), b = at(CUE.titleOff + 0.35), c2 = at(CUE.logo);
    for (let i = a; i < c2; i++) { const k = i < b ? 1 - (i - a) / (b - a) : 0; const g2 = k * k; out[0][i] *= g2; out[1][i] *= g2; } }
  // final fade
  const f0 = at(CUE.fadeOut); for (let i = f0; i < N; i++) { const k = 1 - (i - f0) / (N - f0); out[0][i] *= k; out[1][i] *= k; }
}

// ------------------------------------------------------------ write 24-bit WAV
{
  const bytes = 3, data = Buffer.alloc(N * 2 * bytes);
  let o = 0;
  for (let i = 0; i < N; i++) for (let c = 0; c < 2; c++) { const v = Math.max(-1, Math.min(1, out[c][i])); data.writeIntLE(Math.round(v * 8388607), o, 3); o += 3; }
  const h = Buffer.alloc(44);
  h.write('RIFF', 0); h.writeUInt32LE(36 + data.length, 4); h.write('WAVE', 8); h.write('fmt ', 12); h.writeUInt32LE(16, 16);
  h.writeUInt16LE(1, 20); h.writeUInt16LE(2, 22); h.writeUInt32LE(SR, 24); h.writeUInt32LE(SR * 2 * bytes, 28); h.writeUInt16LE(2 * bytes, 32); h.writeUInt16LE(24, 34);
  h.write('data', 36); h.writeUInt32LE(data.length, 40);
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, Buffer.concat([h, data]));
  console.log(`wrote ${OUT} (${DURATION}s, ${SR} Hz, 24-bit stereo)`);
}
