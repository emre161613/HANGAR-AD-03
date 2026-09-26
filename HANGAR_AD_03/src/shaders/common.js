// Shared GLSL: header, camera, noise, SDF primitives, studio environment.
export const COMMON = /* glsl */ `#version 300 es
precision highp float;
precision highp int;
out vec4 fragColor;

uniform vec2 uRes;          // render target size
uniform float uTime;        // seconds (sub-frame accurate)
uniform vec3 uCamPos;
uniform vec3 uCamTarget;
uniform float uFov;         // vertical fov (radians)
uniform float uRoll;

#define PI 3.14159265
#define TAU 6.28318531

float sat(float x){ return clamp(x, 0.0, 1.0); }
mat2 rot(float a){ float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

// camera ray for this pixel
void cameraRay(out vec3 ro, out vec3 rd) {
  vec2 uv = (gl_FragCoord.xy - 0.5 * uRes) / uRes.y;
  vec3 fw = normalize(uCamTarget - uCamPos);
  vec3 rt = normalize(cross(vec3(0.0, 1.0, 0.0), fw));
  vec3 up = cross(fw, rt);
  float c = cos(uRoll), s = sin(uRoll);
  vec3 r2 = rt * c + up * s, u2 = -rt * s + up * c;
  float f = 0.5 / tan(uFov * 0.5);
  ro = uCamPos;
  rd = normalize(fw * f + uv.x * r2 + uv.y * u2);
}

// ---- hashing / noise (deterministic, no textures)
float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float hash13(vec3 p3){ p3 = fract(p3 * 0.1031); p3 += dot(p3, p3.zyx + 31.32); return fract((p3.x + p3.y) * p3.z); }
vec2 hash22(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.xx + p3.yz) * p3.zy); }
float vnoise(vec2 p){
  vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash12(i), hash12(i + vec2(1, 0)), u.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), u.x), u.y);
}
float vnoise3(vec3 p){
  vec3 i = floor(p), f = fract(p); vec3 u = f * f * (3.0 - 2.0 * f);
  float a = mix(mix(hash13(i), hash13(i + vec3(1,0,0)), u.x), mix(hash13(i + vec3(0,1,0)), hash13(i + vec3(1,1,0)), u.x), u.y);
  float b = mix(mix(hash13(i + vec3(0,0,1)), hash13(i + vec3(1,0,1)), u.x), mix(hash13(i + vec3(0,1,1)), hash13(i + vec3(1,1,1)), u.x), u.y);
  return mix(a, b, u.z);
}
float fbm(vec2 p){ float s = 0.0, a = 0.5; for (int i = 0; i < 5; i++){ s += a * vnoise(p); p = p * 2.03 + 17.1; a *= 0.5; } return s; }
float fbm3(vec3 p){ float s = 0.0, a = 0.5; for (int i = 0; i < 4; i++){ s += a * vnoise3(p); p = p * 2.07 + 11.3; a *= 0.5; } return s; }

// ---- SDF primitives
float sdBox(vec3 p, vec3 b){ vec3 q = abs(p) - b; return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0); }
float sdRoundBox(vec3 p, vec3 b, float r){ return sdBox(p, b - r) - r; }
float sdTorus(vec3 p, vec2 t){ vec2 q = vec2(length(p.xy) - t.x, p.z); return length(q) - t.y; }   // ring in XY plane
float sdCapsule(vec3 p, vec3 a, vec3 b, float r){ vec3 pa = p - a, ba = b - a; float h = sat(dot(pa, ba) / dot(ba, ba)); return length(pa - ba * h) - r; }
float sdCylZ(vec3 p, float r, float h){ vec2 d = abs(vec2(length(p.xy), p.z)) - vec2(r, h); return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)); }
float smin(float a, float b, float k){ float h = sat(0.5 + 0.5 * (b - a) / k); return mix(b, a, h) - k * h * (1.0 - h); }

// ---- lighting helpers
float fresnel(float cosT, float f0){ return f0 + (1.0 - f0) * pow(1.0 - sat(cosT), 5.0); }
float ggx(float NdH, float rough){ float a = rough * rough; float a2 = a * a; float d = NdH * NdH * (a2 - 1.0) + 1.0; return a2 / (PI * d * d); }

// Dark automotive studio: black cyclorama, one long warm softbox overhead,
// a narrow controlled-red strip on the right, faint amber floor bounce.
// 'rough' widens the highlights (brushed/satin surfaces).
vec3 studioEnv(vec3 d, float rough, float redAmt){
  float w = mix(0.04, 0.45, rough);
  vec3 c = vec3(0.004, 0.0035, 0.003);
  float top = smoothstep(0.55 - w, 0.75 + w * 0.5, d.y) * smoothstep(0.34 + w, 0.18 - w * 0.5, abs(d.x + 0.15));
  c += vec3(1.0, 0.86, 0.72) * top * mix(2.2, 0.55, rough);
  float strip = smoothstep(0.12 + w, 0.0, abs(d.y - 0.12)) * smoothstep(0.55 - w, 0.95, d.x);
  c += vec3(1.0, 0.07, 0.03) * strip * 2.6 * redAmt * mix(1.0, 0.45, rough);
  float fill = smoothstep(0.2 + w, 0.0, abs(d.y + 0.05)) * smoothstep(0.6, 0.95, -d.x);
  c += vec3(0.9, 0.72, 0.55) * fill * 0.18;
  c += vec3(0.28, 0.12, 0.05) * smoothstep(0.0, -0.8, d.y) * 0.05;
  return c;
}
`;
