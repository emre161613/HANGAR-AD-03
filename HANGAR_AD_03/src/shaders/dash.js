// DASH world — a retro instrument panel modelled with signed distance fields.
// Dash surface is the plane z = 0 (solid behind, z > 0); the camera sits at z < 0.
import { COMMON } from './common.js';

export const DASH = COMMON + /* glsl */ `
uniform sampler2D uTach, uSpeedo, uSmall, uCap;
uniform float uNeedle, uSpeedNeedle, uTempNeedle; // radians, clockwise from 12 o'clock
uniform float uBacklight;   // cluster illumination (with flicker)
uniform float uRing;        // START ring glow
uniform float uPress;       // START travel 0..1
uniform float uLamps[8];    // indicator lamps
uniform float uToggles[4];  // toggle positions 0 (down) .. 1 (up)
uniform float uKey, uRedRim, uHaze, uRedline, uEnv;

const vec2 TACH_C = vec2(0.0, 0.05);  const float TACH_R = 0.50; const float TACH_D = 0.09;
const vec2 SPD_C  = vec2(1.20, 0.0);  const float SPD_R  = 0.40; const float SPD_D  = 0.075;
const vec2 SML_C  = vec2(-1.10, 0.14); const float SML_R = 0.25; const float SML_D  = 0.06;
const vec2 BTN_C  = vec2(-0.62, -0.86);
const vec3 WHEEL_C = vec3(0.0, -0.62, -0.88);

vec2 lampPos(int i){
  if (i == 0) return vec2(-0.30, 0.66); if (i == 1) return vec2(-0.11, 0.70);
  if (i == 2) return vec2(0.11, 0.70);  if (i == 3) return vec2(0.30, 0.66);
  if (i == 4) return vec2(-0.36, -0.66); if (i == 5) return vec2(0.66, -0.64);
  if (i == 6) return vec2(-1.10, -0.30); return vec2(1.20, -0.56);
}
vec3 lampCol(int i){ return (i == 1 || i == 5) ? vec3(1.0, 0.06, 0.02) : vec3(1.0, 0.42, 0.08); }
float toggleX(int i){ return -0.14 + float(i) * 0.19; }

vec2 opU(vec2 a, vec2 b){ return a.x < b.x ? a : b; }

float needleSD(vec3 p, vec2 c, float R, float depth, float ang, float len){
  vec2 q = rot(-ang) * (p.xy - c);
  float y0 = -0.18 * R, y1 = len * R;
  float k = sat((q.y - y0) / (y1 - y0));
  float hw = mix(0.024, 0.006, k) * R;
  vec3 d = vec3(abs(q.x) - hw, abs(q.y - 0.5 * (y0 + y1)) - 0.5 * (y1 - y0), abs(p.z - (depth - 0.032 * R / 0.5)) - 0.0035);
  return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

vec2 map(vec3 p){
  // --- panel with gauge wells
  float d = -p.z;
  vec2 qT = p.xy - TACH_C, qS = p.xy - SPD_C, qM = p.xy - SML_C, qB = p.xy - BTN_C;
  float rT = length(qT), rS = length(qS), rM = length(qM), rB = length(qB);
  d = max(d, -max(rT - TACH_R, p.z - TACH_D));
  d = max(d, -max(rS - SPD_R, p.z - SPD_D));
  d = max(d, -max(rM - SML_R, p.z - SML_D));
  d = max(d, -max(rB - 0.118, p.z - 0.03));
  vec2 res = vec2(d, 1.0);

  // --- chrome bezels (stepped: outer torus + inner lip)
  if (rT < TACH_R + 0.08) {
    res = opU(res, vec2(sdTorus(vec3(qT, p.z + 0.006), vec2(TACH_R + 0.02, 0.03)), 2.0));
    res = opU(res, vec2(sdTorus(vec3(qT, p.z - 0.018), vec2(TACH_R - 0.004, 0.009)), 2.0));
    if (rT < TACH_R) {
      res = opU(res, vec2(needleSD(p, TACH_C, TACH_R, TACH_D, uNeedle, 0.9), 4.0));
      res = opU(res, vec2(sdCylZ(p - vec3(TACH_C, TACH_D - 0.03), 0.042, 0.012) - 0.004, 2.0));
    }
  }
  if (rS < SPD_R + 0.07) {
    res = opU(res, vec2(sdTorus(vec3(qS, p.z + 0.005), vec2(SPD_R + 0.017, 0.026)), 2.0));
    if (rS < SPD_R) {
      res = opU(res, vec2(needleSD(p, SPD_C, SPD_R, SPD_D, uSpeedNeedle, 0.86), 4.0));
      res = opU(res, vec2(sdCylZ(p - vec3(SPD_C, SPD_D - 0.025), 0.034, 0.01) - 0.003, 2.0));
    }
  }
  if (rM < SML_R + 0.06) {
    res = opU(res, vec2(sdTorus(vec3(qM, p.z + 0.004), vec2(SML_R + 0.014, 0.02)), 2.0));
    if (rM < SML_R) {
      res = opU(res, vec2(needleSD(p, SML_C, SML_R, SML_D, uTempNeedle, 0.8), 4.0));
      res = opU(res, vec2(sdCylZ(p - vec3(SML_C, SML_D - 0.02), 0.026, 0.008) - 0.003, 2.0));
    }
  }
  // --- START button: bezel + travelling cap
  if (rB < 0.2) {
    res = opU(res, vec2(sdTorus(vec3(qB, p.z + 0.004), vec2(0.124, 0.02)), 2.0));
    float zc = -0.012 + uPress * 0.022;
    res = opU(res, vec2(sdCylZ(p - vec3(BTN_C, zc + 0.02), 0.094, 0.036) - 0.006, 5.0));
  }
  // --- indicator lamps (glass domes in chrome rings)
  for (int i = 0; i < 8; i++) {
    vec2 lq = p.xy - lampPos(i);
    if (dot(lq, lq) < 0.01) {
      res = opU(res, vec2(length(vec3(lq, p.z - 0.012)) - 0.026, 6.0 + float(i) * 0.01));
      res = opU(res, vec2(sdTorus(vec3(lq, p.z + 0.002), vec2(0.031, 0.0065)), 2.0));
    }
  }
  // --- toggle switches
  if (abs(p.y + 0.9) < 0.2 && p.x > -0.3 && p.x < 0.6) {
    for (int i = 0; i < 4; i++) {
      vec3 b = vec3(toggleX(i), -0.9, 0.0);
      vec3 lp = p - b;
      if (dot(lp.xy, lp.xy) < 0.02) {
        res = opU(res, vec2(sdCylZ(lp + vec3(0.0, 0.0, 0.006), 0.03, 0.007) - 0.002, 2.0));
        float s = mix(-1.0, 1.0, uToggles[i]);
        vec3 tip = vec3(0.0, 0.055 * s, -0.1);
        res = opU(res, vec2(sdCapsule(lp, vec3(0.0, 0.0, -0.01), tip, mix(0.011, 0.007, 0.5)), 2.0));
        res = opU(res, vec2(length(lp - tip) - 0.012, 2.0));
      }
    }
  }
  // --- brow over the cluster (leather)
  res = opU(res, vec2(sdRoundBox(p - vec3(0.1, 0.84, -0.12), vec3(1.8, 0.075, 0.13), 0.06), 8.0));
  // --- steering wheel rim + spokes (foreground, out of focus)
  vec3 wp = p - WHEEL_C;
  if (abs(wp.z) < 0.2) {
    res = opU(res, vec2(sdTorus(wp, vec2(1.22, 0.058)), 7.0));
  }
  return res;
}

vec3 calcNormal(vec3 p){
  const vec2 k = vec2(1.0, -1.0); const float e = 0.0006;
  return normalize(k.xyy * map(p + k.xyy * e).x + k.yyx * map(p + k.yyx * e).x + k.yxy * map(p + k.yxy * e).x + k.xxx * map(p + k.xxx * e).x);
}
float calcAO(vec3 p, vec3 n){
  float o = 0.0, s = 1.0;
  for (int i = 1; i <= 4; i++){ float h = 0.012 * float(i); o += (h - map(p + n * h).x) * s; s *= 0.7; }
  return sat(1.0 - 9.0 * o);
}
float softShadow(vec3 ro, vec3 rd){
  float r = 1.0, t = 0.01;
  for (int i = 0; i < 14; i++){ float h = map(ro + rd * t).x; r = min(r, 10.0 * h / t); t += clamp(h, 0.01, 0.12); if (r < 0.02 || t > 1.2) break; }
  return sat(r);
}

// emission + albedo of a gauge face from its texture masks
vec3 faceEmit(sampler2D tex, vec2 q, float R, out float albedo){
  vec2 uv = q / (2.0 * R) + 0.5;
  vec3 m = texture(tex, uv).rgb;
  float r = length(q) / R;
  albedo = 0.012 + 0.35 * m.r + 0.15 * m.b;
  vec3 warm = vec3(1.0, 0.8, 0.58);
  vec3 e = warm * (m.r * 2.4 + m.b * 0.75) + vec3(1.0, 0.07, 0.03) * m.g * (2.2 + 5.0 * uRedline);
  e += warm * 0.012 * smoothstep(1.0, 0.2, r);          // diffused backlight
  return e * uBacklight;
}

void main(){
  vec3 ro, rd; cameraRay(ro, rd);
  // march only through the slab that contains geometry
  float t = rd.z > 0.0 ? max(0.0, (-1.0 - ro.z) / rd.z) : 0.0;
  float tMax = 12.0; vec2 h = vec2(0.0);
  bool hit = false;
  for (int i = 0; i < 140; i++){
    h = map(ro + rd * t);
    if (h.x < 0.00035 * t + 0.00008) { hit = true; break; }
    t += h.x * 0.9;
    if (t > tMax) break;
  }
  vec3 col = vec3(0.0);
  float depth = 60.0;
  if (hit) {
    depth = t;
    vec3 p = ro + rd * t;
    vec3 n = calcNormal(p);
    float mat = h.y;
    vec3 v = -rd;
    float ao = calcAO(p, n);

    vec3 base = vec3(0.03); float rough = 0.4; float metal = 1.0; vec3 emit = vec3(0.0);
    if (mat < 1.5) {                 // brushed anthracite panel
      float streak = vnoise(vec2(p.x * 5.0, p.y * 700.0)) * 0.6 + vnoise(vec2(p.x * 1.3, p.y * 180.0)) * 0.4;
      base = vec3(0.16, 0.155, 0.15) * (0.75 + 0.5 * streak);
      rough = 0.28 + 0.2 * streak;
      if (p.z > 0.02) {              // inside a gauge well: face / walls
        vec2 qT = p.xy - TACH_C, qS = p.xy - SPD_C, qM = p.xy - SML_C, qB = p.xy - BTN_C;
        float al = 0.02; metal = 0.0; rough = 0.55;
        if (length(qT) < TACH_R + 0.001) { if (p.z > TACH_D - 0.002) emit = faceEmit(uTach, qT, TACH_R, al); base = vec3(al); }
        else if (length(qS) < SPD_R + 0.001) { if (p.z > SPD_D - 0.002) emit = faceEmit(uSpeedo, qS, SPD_R, al); base = vec3(al); }
        else if (length(qM) < SML_R + 0.001) { if (p.z > SML_D - 0.002) emit = faceEmit(uSmall, qM, SML_R, al); base = vec3(al); }
        else if (length(qB) < 0.125) { base = vec3(0.02); emit = vec3(1.0, 0.05, 0.02) * uRing * 5.0; }
      }
    } else if (mat < 2.5) {          // polished chrome
      base = vec3(0.92, 0.9, 0.87); rough = 0.07;
    } else if (mat < 4.5) {          // needle: lacquered, self-lit
      base = vec3(0.6, 0.12, 0.04); rough = 0.3; metal = 0.0;
      emit = vec3(1.0, 0.2, 0.05) * (0.25 + 2.3 * uBacklight) * (1.0 + 2.0 * uRedline);
    } else if (mat < 5.5) {          // START cap: black anodised, engraved
      vec2 uv = (p.xy - BTN_C) / 0.2 + 0.5;
      vec3 m = texture(uCap, uv).rgb;
      float top = smoothstep(0.5, 0.9, -n.z);
      base = mix(vec3(0.03), vec3(0.55, 0.53, 0.5), (m.r + m.b * 0.6) * top); rough = 0.32; metal = 0.3;
      emit = vec3(1.0, 0.07, 0.02) * (m.r + 0.5 * m.b) * top * uRing * 3.2;
      emit += vec3(1.0, 0.07, 0.02) * uRing * 0.6 * (1.0 - top);
    } else if (mat < 6.9) {          // lamp glass
      int li = int(floor((mat - 6.0) * 100.0 + 0.5));
      float on = 0.0; vec3 lc = vec3(1.0, 0.4, 0.1);
      for (int i = 0; i < 8; i++) if (i == li) { on = uLamps[i]; lc = lampCol(i); }
      base = lc * 0.05; rough = 0.05; metal = 0.0;
      float center = pow(sat(-n.z), 2.0);
      emit = lc * on * (1.2 + 5.0 * center);
    } else if (mat < 7.9) {          // leather: wheel / brow
      float g = vnoise(p.xy * 160.0);
      base = vec3(0.022, 0.02, 0.019) * (0.8 + 0.4 * g); rough = 0.5 + 0.15 * g; metal = 0.0;
      if (mat > 7.4) { base = vec3(0.05); rough = 0.3; metal = 0.8; }
    } else {                         // brow leather
      float g = vnoise(p.xy * 140.0);
      base = vec3(0.018) * (0.8 + 0.4 * g); rough = 0.55; metal = 0.0;
    }

    // lights
    vec3 L1 = normalize(vec3(-0.35, 0.85, -0.45)); vec3 C1 = vec3(1.0, 0.86, 0.7) * uKey;
    vec3 L2 = normalize(vec3(0.95, 0.1, -0.3));    vec3 C2 = vec3(1.0, 0.08, 0.03) * uRedRim * 1.4;
    float sh = softShadow(p + n * 0.002, L1);
    vec3 f0 = mix(vec3(0.04), base, metal);
    vec3 diffC = base * (1.0 - metal);
    vec3 lit = vec3(0.0);
    for (int k = 0; k < 2; k++) {
      vec3 L = k == 0 ? L1 : L2; vec3 C = k == 0 ? C1 * sh : C2;
      vec3 hv = normalize(L + v);
      float ndl = sat(dot(n, L));
      float spec = ggx(sat(dot(n, hv)), max(rough, 0.05)) * fresnel(sat(dot(hv, v)), 0.0);
      lit += C * ndl * (diffC / PI + f0 * min(spec, 60.0) * 0.25);
    }
    // START ring light and cluster backlight as local lights
    vec3 lb = vec3(BTN_C, -0.01) - p; float db = dot(lb, lb);
    lit += vec3(1.0, 0.07, 0.02) * uRing * 0.012 / (db + 0.004) * (diffC + f0 * 0.5) * sat(dot(n, normalize(lb)) * 0.8 + 0.2);
    vec3 lt = vec3(TACH_C, TACH_D - 0.04) - p; float dt = dot(lt, lt);
    lit += vec3(1.0, 0.72, 0.48) * uBacklight * 0.004 / (dt + 0.01) * (diffC + f0 * 0.4) * sat(dot(n, normalize(lt)));
    // image based reflection of the studio
    vec3 r = reflect(rd, n);
    vec3 env = studioEnv(r, rough, uRedRim) * (0.35 + 0.65 * uKey) * uEnv;
    lit += env * mix(vec3(fresnel(sat(dot(n, v)), 0.04)), f0, metal) * ao;
    col = lit * ao + emit;

    // gauge glass: reflection + slight veil
    float tg = (-0.012 - ro.z) / rd.z;
    if (tg > 0.0 && tg < t) {
      vec3 pg = ro + rd * tg;
      float inG = max(max(step(length(pg.xy - TACH_C), TACH_R + 0.012), step(length(pg.xy - SPD_C), SPD_R + 0.01)), step(length(pg.xy - SML_C), SML_R + 0.01));
      if (inG > 0.5) {
        vec3 gn = normalize(vec3((vnoise(pg.xy * 9.0) - 0.5) * 0.015, (vnoise(pg.xy * 9.0 + 3.0) - 0.5) * 0.015, -1.0));
        float fr = fresnel(sat(dot(-rd, -gn)), 0.04);
        float smudge = fbm(pg.xy * 6.0) * 0.6;
        col = col * (0.92 - 0.05 * smudge) + studioEnv(reflect(rd, gn), 0.03 + smudge * 0.15, uRedRim) * fr * (0.35 + 0.3 * uKey) * uEnv;
      }
    }
  }
  // drifting haze lit by the key and red rim
  if (uHaze > 0.0) {
    float tm = min(depth, 2.5); float acc = 0.0;
    for (int i = 0; i < 6; i++) {
      float s = (float(i) + hash12(gl_FragCoord.xy + float(i))) / 6.0 * tm;
      vec3 q = ro + rd * s;
      acc += fbm3(q * 2.2 + vec3(uTime * 0.05, uTime * 0.03, 0.0)) * (tm / 6.0);
    }
    col += acc * uHaze * (vec3(0.5, 0.05, 0.03) * uRedRim + vec3(0.35, 0.28, 0.22) * uKey + vec3(0.25, 0.18, 0.1) * uBacklight * 0.5) * 0.12;
  }
  fragColor = vec4(col, depth);
}
`;
