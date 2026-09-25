// MECH world — gated H-shifter, spinning gear train, drilled throttle pedal, smoke.
// y is up; the camera travels from the gate down past the gears to the pedal box.
import { COMMON } from './common.js';

export const MECH = COMMON + /* glsl */ `
uniform vec2 uKnob;        // shifter knob position in gate plane (x, z)
uniform float uGearAng;    // gear train rotation
uniform float uPedal;      // pedal press angle (rad)
uniform float uKey, uRedRim, uHaze, uLamp;

vec2 opU(vec2 a, vec2 b){ return a.x < b.x ? a : b; }
float sdSeg2(vec2 p, vec2 a, vec2 b){ vec2 pa = p - a, ba = b - a; float h = sat(dot(pa, ba) / dot(ba, ba)); return length(pa - ba * h); }

// spur gear in local XY plane (axis z)
float gearSD(vec3 p, float R, float n, float th, float ang){
  float r = length(p.xy);
  if (r > R * 1.25 + 0.03) return max(r - R * 1.2, abs(p.z) - th);
  float a = atan(p.y, p.x) + ang;
  float tooth = clamp(cos(a * n) * 2.2 + 0.3, -1.0, 1.0);
  float d = r - (R + R * 0.075 * tooth);
  // lightening holes + bore
  float sec = TAU / 5.0;
  float aa = mod(a + sec * 0.5, sec) - sec * 0.5;
  vec2 hp = vec2(cos(aa), sin(aa)) * r - vec2(R * 0.58, 0.0);
  d = max(d, -(length(hp) - R * 0.2));
  d = max(d, -(r - R * 0.13));
  float web = max(d, abs(p.z) - th * 0.55);                 // thinner web
  float rim = max(max(d, abs(p.z) - th), -(r - R * 0.82));  // thick toothed rim
  float hub = max(r - R * 0.26, abs(p.z) - th * 1.3);
  hub = max(hub, -(r - R * 0.13));
  return min(min(web, rim), hub) * 0.7;
}

// throttle pedal: pad with drilled holes + arm, rotating about a pivot on X
float pedalSD(vec3 p, vec3 pivot, float ang, float wide, out float isArm){
  vec3 q = p - pivot;
  q.yz = rot(-ang) * q.yz;
  // pad hangs below the pivot, tilted back toward the driver
  vec3 pc = vec3(0.0, -0.37, -0.14);
  vec3 lp = q - pc;
  lp.yz = rot(0.38) * lp.yz;
  float pad = sdRoundBox(lp, vec3(0.055 * wide, 0.08, 0.007), 0.006);
  vec2 cell = vec2(0.026, 0.028);
  vec2 id = clamp(floor(lp.xy / cell + 0.5), vec2(-1.0, -2.0), vec2(1.0, 2.0));
  vec2 hq = lp.xy - id * cell;
  pad = max(pad, -(length(hq) - 0.0085));
  float arm = sdCapsule(q, vec3(0.0, 0.0, 0.0), pc + vec3(0.0, 0.07, 0.03), 0.011);
  isArm = arm < pad ? 1.0 : 0.0;
  return min(pad, arm);
}

vec2 map(vec3 p){
  // console surface + gate plate
  vec2 res = vec2(sdBox(p - vec3(0.0, -0.06, 0.2), vec3(0.5, 0.036, 0.55)), 1.0);
  if (p.y > -0.3) {
    float plate = sdRoundBox(p - vec3(0.0, -0.012, 0.0), vec3(0.17, 0.013, 0.2), 0.004);
    float slot = 1e9;
    for (int i = 0; i < 3; i++) { float x = -0.1 + 0.1 * float(i); slot = min(slot, sdSeg2(p.xz, vec2(x, -0.13), vec2(x, 0.13))); }
    slot = min(slot, sdSeg2(p.xz, vec2(-0.1, 0.0), vec2(0.1, 0.0)));
    plate = max(plate, -(slot - 0.0125));
    res = opU(res, vec2(plate, 2.0));
    // bolts
    for (int i = 0; i < 4; i++) {
      vec2 bp = vec2(i < 2 ? -0.145 : 0.145, (i == 0 || i == 2) ? -0.175 : 0.175);
      res = opU(res, vec2(length(p - vec3(bp.x, 0.0, bp.y)) - 0.011, 3.0));
    }
    // lever + knob
    vec3 knob = vec3(uKnob.x * 1.54, 0.19, uKnob.y * 1.54);
    res = opU(res, vec2(sdCapsule(p, vec3(0.0, -0.35, 0.0), knob - vec3(0.0, 0.02, 0.0), 0.0085), 3.0));
    res = opU(res, vec2(length(p - knob) - 0.034, 4.0));
    res = opU(res, vec2(sdTorus((p - knob + vec3(0.0, 0.03, 0.0)).xzy, vec2(0.016, 0.005)), 3.0));
  }
  // gear train (behind the gate and along the crane path)
  res = opU(res, vec2(gearSD(p - vec3(0.02, 0.1, 0.62), 0.24, 28.0, 0.025, uGearAng), 5.0));
  res = opU(res, vec2(gearSD(p - vec3(0.3, 0.26, 0.62), 0.13, 15.0, 0.025, -uGearAng * 28.0 / 15.0 + 0.11), 5.0));
  res = opU(res, vec2(gearSD(p - vec3(-0.5, -0.18, 1.0), 0.36, 42.0, 0.03, uGearAng * 0.7), 5.0));
  res = opU(res, vec2(gearSD((p - vec3(0.34, -0.5, 0.02)).zyx, 0.13, 16.0, 0.02, -uGearAng * 1.6), 5.0));
  res = opU(res, vec2(gearSD(p - vec3(-0.2, -0.78, 0.42), 0.22, 30.0, 0.025, uGearAng * 1.1), 5.0));
  // pedal box
  if (p.y < -0.6) {
    res = opU(res, vec2(p.y + 1.26, 6.0));
    float arm;
    float thr = pedalSD(p, vec3(0.0, -0.7, 0.34), uPedal, 1.0, arm);
    res = opU(res, vec2(thr, arm > 0.5 ? 8.0 : 7.0));
    float brk = pedalSD(p, vec3(-0.17, -0.7, 0.34), 0.0, 1.5, arm);
    res = opU(res, vec2(brk, arm > 0.5 ? 8.0 : 7.0));
  }
  return res;
}

vec3 calcNormal(vec3 p){
  const vec2 k = vec2(1.0, -1.0); const float e = 0.0005;
  return normalize(k.xyy * map(p + k.xyy * e).x + k.yyx * map(p + k.yyx * e).x + k.yxy * map(p + k.yxy * e).x + k.xxx * map(p + k.xxx * e).x);
}
float calcAO(vec3 p, vec3 n){
  float o = 0.0, s = 1.0;
  for (int i = 1; i <= 4; i++){ float h = 0.015 * float(i); o += (h - map(p + n * h).x) * s; s *= 0.7; }
  return sat(1.0 - 7.0 * o);
}
float softShadow(vec3 ro, vec3 rd){
  float r = 1.0, t = 0.01;
  for (int i = 0; i < 16; i++){ float h = map(ro + rd * t).x; r = min(r, 8.0 * h / t); t += clamp(h, 0.01, 0.15); if (r < 0.02 || t > 1.5) break; }
  return sat(r);
}

void main(){
  vec3 ro, rd; cameraRay(ro, rd);
  float t = 0.0; vec2 h = vec2(0.0); bool hit = false;
  for (int i = 0; i < 150; i++){
    h = map(ro + rd * t);
    if (h.x < 0.0003 * t + 0.00006) { hit = true; break; }
    t += h.x * 0.85;
    if (t > 6.0) break;
  }
  vec3 col = vec3(0.0); float depth = 60.0;
  vec3 L1 = normalize(vec3(-0.3, 1.0, -0.55)); vec3 C1 = vec3(1.0, 0.86, 0.7) * uKey * 1.8;
  vec3 L2 = normalize(vec3(0.8, 0.35, 0.9));    vec3 C2 = vec3(1.0, 0.07, 0.03) * uRedRim * 1.6;
  if (hit) {
    depth = t;
    vec3 p = ro + rd * t; vec3 n = calcNormal(p); vec3 v = -rd; float mat = h.y;
    float ao = calcAO(p, n);
    vec3 base; float rough; float metal = 1.0;
    if (mat < 1.5) {           // matte console (fine leather grain)
      float g = vnoise(p.xz * 180.0) * 0.5 + vnoise(p.xz * 40.0) * 0.5;
      base = vec3(0.02, 0.019, 0.018) * (0.8 + 0.4 * g); rough = 0.6; metal = 0.0;
    } else if (mat < 2.5) {    // gate plate: machined aluminium with concentric/linear brushing
      float br = vnoise(vec2(p.x * 900.0, p.z * 6.0)) * 0.6 + vnoise(vec2(p.x * 200.0, p.z * 2.0)) * 0.4;
      base = vec3(0.78, 0.77, 0.75) * (0.8 + 0.25 * br); rough = 0.16 + 0.12 * br;
    } else if (mat < 3.5) {    // polished steel (lever, bolts)
      base = vec3(0.9, 0.88, 0.85); rough = 0.06;
    } else if (mat < 4.5) {    // knob: bead-blasted titanium with polished band
      base = vec3(0.62, 0.6, 0.58); rough = 0.22;
    } else if (mat < 5.5) {    // gears: dark machined steel, bright tooth flanks
      float fl = vnoise(p.xy * 300.0);
      base = vec3(0.34, 0.33, 0.32) * (0.7 + 0.3 * fl); rough = 0.28;
    } else if (mat < 6.5) {    // ribbed floor mat
      float rib = smoothstep(0.35, 0.5, abs(fract(p.x * 45.0) - 0.5));
      base = vec3(0.012) * (1.0 + rib); rough = 0.7; metal = 0.0; n = normalize(n + vec3(0.0, 0.0, 0.0));
    } else if (mat < 7.5) {    // pedal pad: drilled aluminium
      float br = vnoise(vec2(p.x * 700.0, p.y * 7.0));
      base = vec3(0.8, 0.79, 0.77) * (0.85 + 0.2 * br); rough = 0.14 + 0.1 * br;
    } else {                   // pedal arm: black powder-coat
      base = vec3(0.025); rough = 0.35; metal = 0.0;
    }
    float sh = softShadow(p + n * 0.002, L1);
    vec3 f0 = mix(vec3(0.04), base, metal), diffC = base * (1.0 - metal);
    vec3 lit = vec3(0.0);
    for (int k = 0; k < 2; k++) {
      vec3 L = k == 0 ? L1 : L2; vec3 C = k == 0 ? C1 * sh : C2;
      vec3 hv = normalize(L + v); float ndl = sat(dot(n, L));
      float spec = ggx(sat(dot(n, hv)), max(rough, 0.05));
      lit += C * ndl * (diffC / PI + f0 * min(spec, 80.0) * 0.25);
    }
    // amber work lamp near the pedal box
    vec3 lp = vec3(0.3, -1.1, -0.05) - p; float dl = dot(lp, lp);
    vec3 Ll = normalize(lp);
    lit += vec3(1.0, 0.45, 0.12) * uLamp * 0.02 / (dl + 0.01) * sat(dot(n, Ll)) * (diffC / PI + f0 * min(ggx(sat(dot(n, normalize(Ll + v))), max(rough, 0.05)), 60.0) * 0.25);
    vec3 env = studioEnv(reflect(rd, n), rough, uRedRim) * (0.3 + 0.7 * uKey);
    lit += env * mix(vec3(fresnel(sat(dot(n, v)), 0.04)), f0, metal) * ao;
    col = lit * ao;
  }
  // procedural smoke: slow curling layers lit by the red rim and key
  {
    float tm = min(depth, 3.0); float acc = 0.0, accR = 0.0;
    for (int i = 0; i < 8; i++) {
      float s = (float(i) + hash12(gl_FragCoord.xy + float(i) * 7.1)) / 8.0 * tm;
      vec3 q = ro + rd * s;
      vec3 w = q * 2.6 + vec3(0.0, -uTime * 0.12, uTime * 0.05);
      w.xz += vec2(fbm3(q * 1.3 + uTime * 0.07), fbm3(q * 1.3 - uTime * 0.05)) * 1.4;
      float dens = smoothstep(0.45, 0.85, fbm3(w));
      acc += dens * (tm / 8.0);
      accR += dens * (tm / 8.0) * sat(0.5 + 0.5 * dot(normalize(q - vec3(-0.8, 0.4, -1.0)), L2));
    }
    col = col * exp(-acc * uHaze * 0.25) + uHaze * (accR * vec3(0.9, 0.06, 0.03) * uRedRim * 0.1 + acc * vec3(0.5, 0.42, 0.35) * uKey * 0.05);
  }
  fragColor = vec4(col, depth);
}
`;
