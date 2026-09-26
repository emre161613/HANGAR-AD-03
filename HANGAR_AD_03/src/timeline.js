// HANGAR_AD_03 — single source of truth for time.
// Shared by the renderer (browser) and the sound synthesizer (Node), so every
// visual event and every sound event is derived from the same curves and cues.

export const FPS = 30;
export const W = 1080;
export const H = 1920;
export const DURATION = 19.5;
export const FRAMES = Math.round(DURATION * FPS); // 585

// Cue sheet (seconds). Frame-exact: every cue is used by both picture and sound.
export const CUE = {
  rimOn: 0.55,        // first light grazes the START bezel
  press: 1.40,        // finger pressure starts, button begins to travel
  click: 1.56,        // button bottoms out: heavy mechanical click
  crank: 1.62,        // starter motor engages
  fire: 2.62,         // engine catches
  lamps: 2.70,        // indicator lamps / relays wake one after another
  clusterOn: 3.40,    // cluster backlight flickers on
  sweep: 3.55,        // needle self-test sweep
  sweepEnd: 4.45,
  blip1: 5.00,        // throttle blip
  blip2: 5.85,        // bigger blip
  dive: 6.75,         // camera dives into the tachometer hub
  mech: 7.20,         // mechanical world
  shift1: 8.05,       // lever N -> 1 (gated shifter)
  crane: 8.55,        // camera cranes down past the gears
  pedal: 9.30,        // throttle pedal pressed
  road: 10.00,        // night drive
  rise: 11.30,        // camera rises from asphalt level
  shiftUp: 12.30,     // upshift
  overtake: 12.85,    // red tail lights stream past
  insert: 14.20,      // cut back to tach — needle hits the limiter
  cut: 14.60,         // HARD CUT to black + silence
  title: 15.00,       // "YOLA ÇIKTIK." + impact
  titleOff: 16.40,
  logo: 17.00,        // HANGAR (placeholder)
  place: 17.60,       // GEMLİK • 2026
  soon: 18.20,        // ÇOK YAKINDA
  fadeOut: 19.10,
};

export const SCENES = [
  { id: 'dash', t0: 0.0, t1: CUE.mech },
  { id: 'mech', t0: CUE.mech, t1: CUE.road },
  { id: 'road', t0: CUE.road, t1: CUE.insert },
  { id: 'dash', t0: CUE.insert, t1: CUE.cut, insert: true },
  { id: 'end', t0: CUE.cut, t1: DURATION },
];
export const sceneAt = (t) => SCENES.find((s) => t >= s.t0 && t < s.t1) || SCENES[SCENES.length - 1];

// ---------------------------------------------------------------- helpers
export const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
export const mix = (a, b, k) => a + (b - a) * k;
export const smooth = (a, b, x) => { const k = clamp((x - a) / (b - a)); return k * k * (3 - 2 * k); };
export const easeInOut = (k) => (k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2);
export const easeOut = (k) => 1 - Math.pow(1 - k, 3);
export const easeIn = (k) => k * k * k;
// deterministic value noise (same result in browser and Node)
export function hash1(n) { const s = Math.sin(n * 127.1 + 311.7) * 43758.5453; return s - Math.floor(s); }
export function noise1(x) { const i = Math.floor(x), f = x - i, u = f * f * (3 - 2 * f); return mix(hash1(i), hash1(i + 1), u) * 2 - 1; }

function blip(t, t0, peak, rise = 0.15, fall = 0.75) {
  if (t < t0) return 0;
  const k = t - t0;
  return k < rise ? peak * smooth(0, 1, k / rise) : peak * Math.exp(-(k - rise) / (fall * 0.45));
}

// ---------------------------------------------------------------- engine
// Engine speed the SOUND follows (rpm) and throttle (0..1).
export function engineRpm(t) {
  if (t < CUE.crank) return 0;
  if (t < CUE.fire) return 190 + 70 * Math.sin((t - CUE.crank) * Math.PI * 2 * 4.6); // starter cranking
  if (t >= CUE.cut) return 0;
  const idle = 930 + 25 * noise1(t * 7);
  if (t < CUE.mech) {
    const k = t - CUE.fire; // catch flare then settle
    const flare = 1150 * (1 - Math.exp(-k / 0.05)) * Math.exp(-k / 0.42);
    return idle + flare + blip(t, CUE.blip1, 3300) + blip(t, CUE.blip2, 5300, 0.17, 0.9);
  }
  if (t < CUE.pedal) {
    return idle - 120 * smooth(CUE.shift1 - 0.1, CUE.shift1, t) * (1 - smooth(CUE.shift1 + 0.1, CUE.shift1 + 0.5, t));
  }
  if (t < CUE.road) return mix(idle, 5200, easeOut(clamp((t - CUE.pedal) / 0.65)));
  if (t < CUE.shiftUp) return mix(5200, 6900, (t - CUE.road) / (CUE.shiftUp - CUE.road));
  if (t < CUE.shiftUp + 0.14) return mix(6900, 4500, smooth(0, 1, (t - CUE.shiftUp) / 0.14));
  if (t < CUE.insert) return mix(4500, 7250, Math.pow((t - CUE.shiftUp - 0.14) / (CUE.insert - CUE.shiftUp - 0.14), 0.85));
  // limiter bounce
  return 7350 + 220 * Math.sin((t - CUE.insert) * Math.PI * 2 * 11);
}

export function throttle(t) {
  if (t < CUE.fire || t >= CUE.cut) return 0;
  const b = (t0, d) => (t >= t0 && t < t0 + d ? 1 : 0);
  if (t < CUE.mech) return Math.max(0.15 * Math.exp(-(t - CUE.fire) / 0.3), b(CUE.blip1, 0.18), b(CUE.blip2, 0.2)) + 0.06;
  if (t < CUE.pedal) return 0.06;
  if (t < CUE.shiftUp) return 0.95;
  if (t < CUE.shiftUp + 0.16) return 0.0;
  return 1.0;
}

// Needle position (rpm units) — follows engine rpm through a damped spring
// (mass + needle damping), plus the self-test sweep. Precomputed at 1 kHz.
const STEP = 1 / 1000;
const N = Math.ceil(DURATION / STEP) + 2;
const NEEDLE = new Float32Array(N);
const DIST = new Float32Array(N);
(function precompute() {
  let x = 0, v = 0, d = 0;
  for (let i = 0; i < N; i++) {
    const t = i * STEP;
    let target = t < CUE.clusterOn ? 0 : engineRpm(t);
    if (t >= CUE.sweep && t < CUE.sweepEnd) {
      const k = (t - CUE.sweep) / (CUE.sweepEnd - CUE.sweep);
      target = 8000 * Math.sin(Math.PI * clamp(k * 1.05)) ;
    }
    if (t >= CUE.cut) target = 0;
    const w = 26, z = 0.62; // natural freq (rad/s), damping ratio -> slight overshoot
    const a = w * w * (target - x) - 2 * z * w * v;
    v += a * STEP; x += v * STEP;
    NEEDLE[i] = x;
    d += roadSpeed(t) * STEP; DIST[i] = d;
  }
})();
const sample = (arr, t) => { const f = clamp(t, 0, DURATION) / STEP, i = Math.floor(f), k = f - i; return mix(arr[i], arr[Math.min(i + 1, N - 1)], k); };
export const needleRpm = (t) => sample(NEEDLE, t);

// ---------------------------------------------------------------- road
// Vehicle speed (m/s) and distance travelled (m). Speed is felt only on the road.
export function roadSpeed(t) {
  if (t < CUE.road) return 18;
  const base = mix(21, 62, Math.pow(clamp((t - CUE.road) / (CUE.insert - CUE.road)), 1.25));
  const shiftDip = -3.5 * smooth(CUE.shiftUp, CUE.shiftUp + 0.08, t) * (1 - smooth(CUE.shiftUp + 0.1, CUE.shiftUp + 0.45, t));
  return base + shiftDip;
}
export const roadDist = (t) => sample(DIST, t);

export const ROAD = {
  lampSpacing: 34,   // overhead sodium lamps (m)
  lampOffset: 18,
  postSpacing: 12,   // red delineator posts
  dashLen: 4, dashGap: 8,
};
// times at which the camera passes an overhead lamp (for whoosh sounds)
export function lampPasses() {
  const out = [];
  for (let t = CUE.road; t < CUE.insert; t += 1 / 1000) {
    const a = roadDist(t) - ROAD.lampOffset, b = roadDist(t + 1 / 1000) - ROAD.lampOffset;
    if (Math.floor(a / ROAD.lampSpacing) !== Math.floor(b / ROAD.lampSpacing)) out.push(t);
  }
  return out;
}

// Indicator lamps waking up (index -> time); relay ticks in the sound follow these.
export const LAMP_TIMES = [0, 0.09, 0.2, 0.27, 0.41, 0.5, 0.62].map((d) => CUE.lamps + d);
