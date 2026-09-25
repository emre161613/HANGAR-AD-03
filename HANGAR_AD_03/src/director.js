// Director: for any time t returns the scene, camera and all animated
// parameters. Pure functions of t — any frame can be rendered independently.
import {
  CUE, DURATION, LAMP_TIMES, sceneAt, clamp, mix, smooth, easeInOut, easeOut, easeIn, noise1,
  needleRpm, engineRpm, roadSpeed, roadDist,
} from './timeline.js';

const v3 = (a, b, k) => [mix(a[0], b[0], k), mix(a[1], b[1], k), mix(a[2], b[2], k)];
const deg = (d) => (d * Math.PI) / 180;

// Keyframed camera track with per-segment easing (Catmull-Rom through positions).
function track(keys, t) {
  if (t <= keys[0].t) return keys[0];
  for (let i = 0; i < keys.length - 1; i++) {
    const a = keys[i], b = keys[i + 1];
    if (t <= b.t) {
      const e = (b.ease || easeInOut)((t - a.t) / (b.t - a.t));
      const p0 = (keys[i - 1] || a), p3 = (keys[i + 2] || b);
      const cr = (k, x0, x1, x2, x3) => 0.5 * ((2 * x1) + (-x0 + x2) * k + (2 * x0 - 5 * x1 + 4 * x2 - x3) * k * k + (-x0 + 3 * x1 - 3 * x2 + x3) * k * k * k);
      const pos = [0, 1, 2].map((j) => cr(e, p0.pos[j], a.pos[j], b.pos[j], p3.pos[j]));
      return { pos, target: v3(a.target, b.target, e), fov: mix(a.fov, b.fov, e), roll: mix(a.roll || 0, b.roll || 0, e) };
    }
  }
  return keys[keys.length - 1];
}

// handheld-ish micro motion + impulse shakes
function shake(t, amp, freq = 1.3) {
  return [noise1(t * freq + 11.3) * amp, noise1(t * freq + 47.9) * amp, noise1(t * freq * 0.7 + 91.1) * amp * 0.4];
}
function impulse(t, t0, amp, decay = 0.12, f = 38) {
  if (t < t0) return 0;
  const k = t - t0;
  return amp * Math.exp(-k / decay) * Math.sin(k * f);
}
const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];

// ------------------------------------------------------------------ DASH
const DASH_KEYS = [
  { t: 0.0,  pos: [-0.30, -1.13, -0.70], target: [-0.60, -0.87, 0.0], fov: deg(30) },
  { t: 2.55, pos: [-0.36, -1.08, -0.60], target: [-0.61, -0.86, 0.0], fov: deg(28), ease: (k) => k },
  { t: 3.45, pos: [-0.05, -1.05, -2.05], target: [-0.25, -0.40, 0.0], fov: deg(40), roll: deg(-3) },
  { t: 4.3,  pos: [0.62, -0.55, -2.45], target: [0.05, 0.02, 0.0], fov: deg(36), roll: deg(-4) },
  { t: 5.6,  pos: [0.42, -0.30, -1.55], target: [0.03, 0.08, 0.03], fov: deg(34), roll: deg(-2) },
  { t: 6.45, pos: [-0.34, 0.02, -1.0], target: [0.0, 0.06, 0.06], fov: deg(33), roll: deg(3) },
  { t: 6.85, pos: [-0.12, 0.0, -0.5], target: [0.0, 0.05, 0.09], fov: deg(40), roll: deg(5) },
  { t: 7.2,  pos: [0.0, 0.05, -0.035], target: [0.0, 0.05, 0.1], fov: deg(76), roll: deg(14), ease: easeIn },
];
const INSERT_KEYS = [
  { t: CUE.insert, pos: [-0.05, -0.38, -0.78], target: [0.33, -0.02, 0.09], fov: deg(30), roll: deg(-6) },
  { t: CUE.cut, pos: [0.03, -0.3, -0.62], target: [0.35, -0.02, 0.09], fov: deg(27), roll: deg(-8), ease: (k) => k },
];

function flicker(t, t0) {
  // fluorescent-style strike: on/off chatter then settle with a small overshoot
  const k = t - t0;
  if (k < 0) return 0;
  const seq = [[0.0, 0.04, 0.8], [0.04, 0.09, 0.0], [0.09, 0.12, 1.0], [0.12, 0.17, 0.15], [0.17, 0.2, 0.9], [0.2, 0.26, 0.3]];
  for (const [a, b, v] of seq) if (k >= a && k < b) return v;
  return 1 + 0.12 * Math.exp(-(k - 0.26) / 0.25);
}

function dash(t, insert) {
  const cam = track(insert ? INSERT_KEYS : DASH_KEYS, t);
  let pos = cam.pos.slice();
  const s = shake(t, insert ? 0.006 : 0.0025, insert ? 9 : 1.1);
  const clickJolt = impulse(t, CUE.click, 0.004, 0.08, 55);
  const fireJolt = impulse(t, CUE.fire, 0.009, 0.16, 30);
  const crank = t > CUE.crank && t < CUE.fire ? Math.sin((t - CUE.crank) * Math.PI * 2 * 4.6) * 0.0018 : 0;
  const idleShake = t > CUE.fire && !insert ? noise1(t * 28) * 0.0009 * (1 + engineRpm(t) / 2500) : 0;
  pos = add(pos, [s[0], s[1] + clickJolt + fireJolt + crank + idleShake, s[2]]);
  if (insert) pos = add(pos, [noise1(t * 60) * 0.004, noise1(t * 55 + 3) * 0.004, 0]);

  const crankSag = t > CUE.crank && t < CUE.fire ? 0.35 + 0.3 * Math.sin((t - CUE.crank) * Math.PI * 2 * 4.6) : 0;
  const rim = smooth(CUE.rimOn, CUE.rimOn + 0.9, t);
  let ring = 0.08 * rim;
  if (t >= CUE.click) ring = 0.75 * (1 - crankSag * 0.8);
  if (t >= CUE.fire) ring = 0.95 + 0.9 * Math.exp(-(t - CUE.fire) / 0.18);
  const press = t < CUE.press ? 0 : t < CUE.click ? easeIn((t - CUE.press) / (CUE.click - CUE.press))
    : t < 1.95 ? 1 : Math.max(0, 1 - easeOut((t - 1.95) / 0.25));
  const lamps = LAMP_TIMES.map((lt, i) => {
    const on = flicker(t, lt);
    return Math.min(on, 1.15) * (i === 1 || i === 5 ? 0.9 : 1) * (1 - 0.3 * crankSag);
  });
  const toggles = [2.78, 2.93, 3.08, 3.2].map((tt) => easeOut(clamp((t - tt) / 0.05)));
  const back = flicker(t, CUE.clusterOn);
  const needleDeg = -135 + (clamp(needleRpm(t), -100, 8300) / 8000) * 270;
  const kmh = insert ? roadSpeed(t) * 3.6 : 0;
  const temp = t < CUE.clusterOn ? 0 : 20 + 55 * smooth(CUE.clusterOn, 7, t);
  const redline = insert ? 0.7 + 0.3 * Math.sin(t * 70) : 0;

  const focus = Math.hypot(...cam.target.map((x, i) => x - pos[i]));
  const macro = t < CUE.lamps ? 1 : 0;
  return {
    scene: 'dash', cam: { ...cam, pos },
    u: {
      uNeedle: deg(needleDeg), uSpeedNeedle: deg(-135 + (kmh / 240) * 270), uTempNeedle: deg(-90 + (temp / 120) * 180),
      uBacklight: back * (insert ? 1.35 : 1), uRing: ring, uPress: press, uLamps: { fv: lamps.concat([0]).slice(0, 8) }, uToggles: { fv: toggles },
      uKey: 0.5 * smooth(CUE.rimOn + 0.2, 2.2, t) + 0.25 * smooth(CUE.fire, 3.4, t) * (insert ? 0.2 : 1),
      uRedRim: 0.9 * rim * (1 - 0.3 * crankSag) + (insert ? 0.8 : 0),
      uHaze: 0.2, uRedline: redline, uEnv: smooth(CUE.rimOn - 0.2, CUE.rimOn + 1.0, t),
    },
    post: {
      focus, aperture: macro ? 60 : 34, maxCoc: 22,
      exposure: 1.0, bloom: 0.45, threshold: 1.2, streak: 0.08,
      flash: Math.max(0.35 * Math.exp(-Math.max(0, t - CUE.fire) / 0.06) * (t >= CUE.fire ? 1 : 0), smooth(7.02, 7.2, t) * 0.9 * (insert ? 0 : 1)),
    },
    subframes: insert ? 3 : 2,
  };
}

// ------------------------------------------------------------------ MECH
const MECH_KEYS = [
  { t: CUE.mech, pos: [0.02, 0.36, -0.22], target: [0.0, 0.0, 0.03], fov: deg(62), roll: deg(14) },
  { t: 7.7,  pos: [0.3, 0.24, -0.42], target: [-0.03, 0.1, 0.03], fov: deg(40), roll: deg(2), ease: easeOut },
  { t: 8.45, pos: [0.16, 0.24, -0.3], target: [-0.1, 0.14, 0.12], fov: deg(34), roll: deg(-2) },
  { t: 9.0,  pos: [0.3, -0.5, -0.5], target: [0.02, -0.95, 0.12], fov: deg(42), roll: deg(-6) },
  { t: 9.35, pos: [0.2, -0.98, -0.38], target: [0.0, -1.07, 0.16], fov: deg(36), roll: deg(-2) },
  { t: 9.85, pos: [0.1, -1.07, -0.24], target: [0.0, -1.08, 0.25], fov: deg(44), roll: deg(4) },
  { t: CUE.road, pos: [0.06, -1.09, -0.12], target: [0.0, -1.1, 0.4], fov: deg(72), roll: deg(22), ease: easeIn },
];

function knobAt(t) {
  const s = CUE.shift1;
  const wob = [noise1(t * 30) * 0.0015 * (1 + engineRpm(t) / 3000), noise1(t * 27 + 5) * 0.0015];
  let k;
  if (t < s - 0.1) k = [0, 0];
  else if (t < s - 0.02) k = [mix(0, -0.1, easeInOut((t - (s - 0.1)) / 0.08)), 0];
  else if (t < s + 0.08) k = [-0.1, mix(0, 0.12, easeIn((t - (s - 0.02)) / 0.1))];
  else k = [-0.1, 0.12 + 0.006 * Math.exp(-(t - s - 0.08) / 0.05) * Math.cos((t - s - 0.08) * 90)];
  return [k[0] + wob[0], k[1] + wob[1]];
}

function mech(t) {
  const cam = track(MECH_KEYS, t);
  let pos = add(cam.pos, shake(t, 0.004, 0.9));
  pos = add(pos, [0, impulse(t, CUE.shift1 + 0.08, 0.006, 0.1, 45) + impulse(t, CUE.pedal + 0.2, 0.004, 0.12, 30), 0]);
  pos = add(pos, [noise1(t * 40) * 0.0008, noise1(t * 37 + 2) * 0.0008, 0]);
  const pedal = 0.3 * easeInOut(clamp((t - CUE.pedal) / 0.22));
  const rpm = engineRpm(t);
  const focus = Math.hypot(...cam.target.map((x, i) => x - pos[i]));
  return {
    scene: 'mech', cam: { ...cam, pos },
    u: { uKnob: knobAt(t), uGearAng: t * (0.6 + rpm / 1000) * 1.1, uPedal: pedal, uKey: 0.6, uRedRim: 0.7, uHaze: 0.8, uLamp: smooth(8.5, 8.9, t) },
    post: {
      focus, aperture: 38, maxCoc: 22, exposure: 1.0, bloom: 0.45, threshold: 1.2, streak: 0.08,
      flash: Math.max(0.9 * Math.exp(-(t - CUE.mech) / 0.09), smooth(9.9, CUE.road, t) * 0.8),
    },
    subframes: 3,
  };
}

// ------------------------------------------------------------------ ROAD
import { ROAD } from './timeline.js';
const curveX = (Z) => 5.5 * Math.sin(Z * 0.0065) + 2.0 * Math.sin(Z * 0.017 + 1.3);

function road(t) {
  const dist = roadDist(t), v = roadSpeed(t);
  const rise = easeInOut(clamp((t - CUE.rise) / 0.9));
  const h = mix(0.16, 1.1, rise);
  const look = mix(8, 34, rise);
  const yaw = curveX(dist + look) - curveX(dist);
  const k = clamp((t - CUE.road) / (CUE.insert - CUE.road));
  const amp = 0.003 + v * 0.00018;
  const s = [noise1(t * 11) * amp, noise1(t * 13 + 4) * amp * 1.4, 0];
  const bump = impulse(t, CUE.shiftUp, 0.02, 0.12, 26);
  const pos = [s[0], h + s[1] + bump, 0];
  const target = [yaw + s[0] * 3, mix(-0.25, 0.86, rise) + bump * 0.5, look];
  return {
    scene: 'road', cam: { pos, target, fov: deg(mix(52, 68, easeIn(k))), roll: deg(noise1(t * 0.7) * 1.2 + (yaw / look) * -6) },
    u: {
      uDist: dist, uSpeed: v, uLead: mix(46, 21, k), uPass: 16 - (t - CUE.overtake) * 30, uHead: 1.0,
    },
    post: {
      focus: 10, aperture: 0, maxCoc: 1, exposure: 1.05, bloom: 0.6, threshold: 1.0, streak: 0.25,
      flash: 0.8 * Math.exp(-(t - CUE.road) / 0.08) + 0.12 * Math.exp(-Math.max(0, t - CUE.shiftUp) / 0.05) * (t > CUE.shiftUp ? 1 : 0),
    },
    subframes: 5,
  };
}

// ------------------------------------------------------------------ END
function end(t) {
  const impact = t >= CUE.title && t < CUE.title + 0.1 ? Math.exp(-(t - CUE.title) / 0.03) : 0;
  return {
    scene: 'end', cam: { pos: [0, 0, -1], target: [0, 0, 0], fov: 1, roll: 0 }, u: {},
    post: { focus: 1, aperture: 0, maxCoc: 1, exposure: 1.0, bloom: 0.55, threshold: 0.55, streak: 0.0, flash: impact * 0.25 },
    subframes: 1,
  };
}

export const SCENE_FN = { dash, mech, road, end };
export function direct(t) {
  const s = sceneAt(t);
  const fn = SCENE_FN[s.id];
  if (!fn) return end(t);
  const r = fn(t, !!s.insert);
  r.fade = t >= CUE.cut && t < CUE.title ? 0 : 1;
  return r;
}
export { CUE, DURATION };
