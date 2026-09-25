// ROAD world — abstract but physical night drive: wet asphalt, painted lines,
// guard rail, red delineators, sodium lamps, cars' tail lights, ground mist.
// Analytic ray intersections (cheap enough for heavy motion-blur supersampling).
import { COMMON } from './common.js';

export const ROAD = COMMON + /* glsl */ `
uniform float uDist;        // distance travelled (m)
uniform float uSpeed;       // m/s
uniform float uLead;        // distance to the car ahead (m)
uniform float uPass;        // relative z of the car being overtaken (left lane)
uniform float uHead;        // headlight intensity

const float LAMP_SP = 34.0, LAMP_OFF = 18.0, POST_SP = 12.0;
const vec3 SODIUM = vec3(1.0, 0.5, 0.17);
const vec3 TAIL = vec3(1.0, 0.035, 0.015);

// gentle S-curve: road centre x as function of world Z
float curveX(float Z){ return 5.5 * sin(Z * 0.0065) + 2.0 * sin(Z * 0.017 + 1.3); }
// lateral coordinate relative to the road centre at this depth (camera frame)
float laneX(vec3 p){ float Z = p.z + uDist; return p.x - (curveX(Z) - curveX(uDist)); }
vec3 roadPt(float x, float y, float zRel){ float Z = zRel + uDist; return vec3(x + curveX(Z) - curveX(uDist), y, zRel); }

float ggxSpec(vec3 n, vec3 v, vec3 l, float rough){ vec3 h = normalize(l + v); return ggx(sat(dot(n, h)), rough) * fresnel(sat(dot(h, v)), 0.03); }

// glow of a point emitter seen along a ray: 1/(perp distance^2) falloff with a core
float pointGlow(vec3 ro, vec3 rd, vec3 c, float size, float tMax){
  float tc = dot(c - ro, rd);
  if (tc < 0.0 || tc > tMax + 0.5) return 0.0;
  float d = length(ro + rd * tc - c);
  float ang = d / tc;                       // angular distance
  float s = size / tc;
  float g = s * s / (ang * ang + s * s * 0.25) * 0.25 + exp(-ang / (s * 6.0)) * 0.02 * size * 40.0 / (tc * 0.05 + 1.0);
  return g * exp(-tc * 0.006);
}

void main(){
  vec3 ro, rd; cameraRay(ro, rd);
  vec3 col = vec3(0.0);
  float depth = 400.0;
  float tGround = rd.y < -1e-4 ? -ro.y / rd.y : 1e9;

  // ---- guard rail (right) and median barrier (left): vertical surfaces following the curve.
  // Solve approximately by marching lateral distance (few iterations, surfaces are gentle).
  float tRail = 1e9, tMed = 1e9;
  {
    float tt = 0.0;
    for (int i = 0; i < 24; i++) {
      vec3 p = ro + rd * tt; float lx = laneX(p);
      float d = 2.85 - lx;
      if (abs(d) < 0.01) { if (p.y > 0.44 && p.y < 0.8) tRail = tt; break; }
      float s = rd.x; if (abs(s) < 1e-3) break;
      float step_ = d / s; if (step_ < 0.0) break;
      tt += step_ * 0.9; if (tt > 250.0) break;
    }
    tt = 0.0;
    for (int i = 0; i < 24; i++) {
      vec3 p = ro + rd * tt; float lx = laneX(p);
      float d = lx + 6.0;
      if (abs(d) < 0.01) { if (p.y < 0.85) tMed = tt; break; }
      float s = -rd.x; if (abs(s) < 1e-3) break;
      float step_ = d / s; if (step_ < 0.0) break;
      tt += step_ * 0.9; if (tt > 250.0) break;
    }
  }

  // ---- cars (dark bodies as boxes, only lights & reflections read)
  float tCar = 1e9; vec3 carN = vec3(0.0);
  for (int c = 0; c < 2; c++) {
    vec3 cc = c == 0 ? roadPt(0.0, 0.62, uLead + 2.2) : roadPt(-3.7, 0.62, uPass + 2.2);
    vec3 hb = vec3(0.88, 0.6, 2.2);
    vec3 o = ro - cc; vec3 inv = 1.0 / rd;
    vec3 t0 = (-hb - o) * inv, t1 = (hb - o) * inv;
    vec3 tn = min(t0, t1), tf = max(t0, t1);
    float a = max(max(tn.x, tn.y), tn.z), b = min(min(tf.x, tf.y), tf.z);
    if (a < b && a > 0.0 && a < tCar) { tCar = a; carN = -sign(rd) * step(tn.yzx, tn.xyz) * step(tn.zxy, tn.xyz); }
  }

  float tHit = min(min(tGround, tRail), min(tMed, tCar));
  vec3 v = -rd;

  // lamp positions near a given depth
  #define LAMP(k) roadPt(2.3, 7.4, (floor((uDist - LAMP_OFF) / LAMP_SP) + float(k)) * LAMP_SP + LAMP_OFF - uDist)

  if (tHit < 1e8) {
    depth = tHit;
    vec3 p = ro + rd * tHit;
    vec3 n; vec3 alb; float rough; float wet = 0.0; float paint = 0.0; float metal = 0.0;
    if (tHit == tGround) {
      n = vec3(0.0, 1.0, 0.0);
      float lx = laneX(p); float Z = p.z + uDist;
      vec2 wp = vec2(lx, Z);
      // aggregate asphalt: multi-scale speckle
      float ag = vnoise(wp * 38.0) * 0.45 + vnoise(wp * 140.0) * 0.35 + hash12(floor(wp * 420.0)) * 0.2;
      alb = vec3(0.05, 0.049, 0.048) * (0.5 + 0.9 * ag);
      // wetness puddles + tyre tracks (smoother, wetter)
      float pud = smoothstep(0.42, 0.7, fbm(wp * vec2(0.35, 0.12)));
      float tracks = smoothstep(0.55, 0.0, abs(abs(lx) - 0.8) - 0.25);
      wet = sat(0.45 + 0.55 * max(pud, tracks * 0.8));
      // lines
      float dash = step(fract(Z / 12.0), 4.0 / 12.0);
      float center = smoothstep(0.075, 0.055, abs(lx + 1.85)) * dash;
      float edgeR = smoothstep(0.085, 0.065, abs(lx - 1.8));
      float edgeL = smoothstep(0.085, 0.065, abs(lx + 5.6));
      paint = max(center, max(edgeR, edgeL)) * (0.75 + 0.25 * vnoise(wp * vec2(8.0, 1.0)));
      alb = mix(alb, vec3(0.62, 0.6, 0.55), paint);
      alb *= mix(1.0, 0.55, wet * (1.0 - paint));
      rough = mix(0.55, 0.07, wet * (1.0 - paint * 0.6));
      // micro ripples on the water film
      n = normalize(vec3((vnoise(wp * 22.0 + uTime * 2.0) - 0.5) * 0.04 * wet, 1.0, (vnoise(wp * 19.0 - uTime * 2.3) - 0.5) * 0.04 * wet));
    } else if (tHit == tRail) {
      float Z = p.z + uDist;
      n = normalize(vec3(-1.0, 0.0, 0.0) + vec3(0.0, sin((p.y - 0.44) / 0.36 * TAU * 1.5) * 0.35, 0.0));
      alb = vec3(0.5, 0.5, 0.52); rough = 0.22; metal = 1.0;
      alb *= 0.7 + 0.3 * vnoise(vec2(Z * 0.8, p.y * 20.0));
    } else if (tHit == tMed) {
      n = vec3(1.0, 0.0, 0.0); alb = vec3(0.12, 0.115, 0.11) * (0.7 + 0.3 * vnoise(p.yz * 8.0)); rough = 0.8;
    } else {
      n = carN; alb = vec3(0.01); rough = 0.12; metal = 0.3; // black lacquer
    }

    vec3 lit = vec3(0.0);
    // our headlights: two warm halogen cones pointing down the road
    for (int s = 0; s < 2; s++) {
      vec3 hp = vec3(s == 0 ? -0.7 : 0.7, 0.62, 0.6);
      vec3 l = hp - p; float d2 = dot(l, l); l = normalize(l);
      vec3 axis = normalize(vec3(curveX(uDist + 25.0) - curveX(uDist), -0.045, 25.0));
      float cone = smoothstep(0.93, 0.995, dot(-l, axis)) + 0.35 * smoothstep(0.6, 0.95, dot(-l, axis)) + 0.3 * smoothstep(-0.4, 0.5, dot(-l, axis)) * smoothstep(20.0, 0.3, d2);
      vec3 C = vec3(1.0, 0.88, 0.72) * uHead * 55.0 * cone / (d2 + 1.0);
      lit += C * sat(dot(n, l)) * (alb * (1.0 - metal) / PI + mix(vec3(0.03), alb, metal) * min(ggxSpec(n, v, l, rough), 40.0));
      // retroreflective paint / reflectors bounce headlight straight back
      lit += C * paint * 0.25;
    }
    // sodium lamps (nearest few)
    for (int k = -1; k < 6; k++) {
      vec3 lp = LAMP(k);
      vec3 l = lp - p; float d2 = dot(l, l); l = normalize(l);
      vec3 C = SODIUM * 90.0 / d2 * smoothstep(0.0, 0.35, l.y) * exp(-sqrt(d2) * 0.006);
      lit += C * sat(dot(n, l)) * (alb * (1.0 - metal) / PI + mix(vec3(0.03), alb, metal) * min(ggxSpec(n, v, l, rough), 120.0));
    }
    // tail lights as light sources (their reflections streak on the wet road)
    for (int c = 0; c < 2; c++) {
      for (int s = 0; s < 2; s++) {
        vec3 lp = c == 0 ? roadPt(s == 0 ? -0.66 : 0.66, 0.85, uLead) : roadPt(-3.7 + (s == 0 ? -0.66 : 0.66), 0.85, uPass);
        vec3 l = lp - p; float d2 = dot(l, l); l = normalize(l);
        vec3 C = TAIL * 6.0 / (d2 + 0.2);
        lit += C * sat(dot(n, l)) * (alb * (1.0 - metal) / PI + mix(vec3(0.03), alb, metal) * min(ggxSpec(n, v, l, rough), 400.0));
      }
    }
    // faint warm sky bounce
    lit += alb * vec3(0.012, 0.008, 0.006);
    col = lit;
  }

  // ---- atmosphere: exponential fog, faint warm light-pollution at the horizon
  float tv = min(tHit, 600.0);
  float fog = 1.0 - exp(-tv * 0.006);
  vec3 fogC = vec3(0.006, 0.0045, 0.004) + SODIUM * 0.012 * exp(-abs(rd.y) * 25.0);
  col = mix(col, fogC, fog);
  // ---- emitters seen directly: lamp heads, delineator reflectors, tail lights
  for (int k = 0; k < 14; k++) {
    vec3 lp = LAMP(k);
    col += SODIUM * pointGlow(ro, rd, lp, 0.22, tv) * 3.0;
  }
  for (int k = 0; k < 16; k++) {
    float z = (floor(uDist / POST_SP) + float(k)) * POST_SP - uDist + 4.0;
    vec3 rp = roadPt(2.55, 0.9, z);
    // lit by our headlights -> red retro-reflection, fades with distance
    float lum = uHead * 20.0 / (z * z * 0.02 + 1.0);
    col += TAIL * pointGlow(ro, rd, rp, 0.045, tv) * lum;
  }
  for (int c = 0; c < 2; c++) {
    for (int s = 0; s < 2; s++) {
      vec3 lp = c == 0 ? roadPt(s == 0 ? -0.66 : 0.66, 0.85, uLead) : roadPt(-3.7 + (s == 0 ? -0.66 : 0.66), 0.85, uPass);
      col += TAIL * pointGlow(ro, rd, lp, 0.08, tv + 0.3) * 9.0;
    }
  }

  {
    float acc = 0.0;
    for (int i = 0; i < 6; i++) {
      float s = (float(i) + hash12(gl_FragCoord.xy + float(i))) / 6.0;
      float tt = 1.5 + s * s * 40.0; if (tt > tv) break;
      vec3 q = ro + rd * tt;
      float h = smoothstep(0.9, 0.0, q.y);
      float dens = smoothstep(0.35, 0.8, fbm3(vec3(q.x * 0.6, q.y * 2.0, (q.z + uDist) * 0.25 - uTime * 0.2)));
      float inBeam = smoothstep(4.0, 0.0, abs(q.x)) * smoothstep(40.0, 5.0, tt);
      acc += dens * h * (0.3 + inBeam) * (tt / 40.0 + 0.2);
    }
    col += acc * vec3(0.9, 0.8, 0.68) * uHead * 0.025;
  }
  fragColor = vec4(col, depth);
}
`;
