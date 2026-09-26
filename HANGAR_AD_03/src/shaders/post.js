// Post chain: motion-blur accumulation, depth of field, bloom, filmic grade, grain.
const HEAD = `#version 300 es
precision highp float;
out vec4 fragColor;
uniform vec2 uRes;
`;

export const ACCUM = HEAD + `
uniform sampler2D uSrc; uniform float uWeight;
void main(){
  vec4 c = texture(uSrc, gl_FragCoord.xy / uRes);
  // sanitize: a single NaN/inf sample would otherwise bloom into a black block
  if (any(isnan(c)) || any(isinf(c))) c = vec4(0.0, 0.0, 0.0, 60.0);
  c.rgb = clamp(c.rgb, 0.0, 200.0);
  fragColor = c * uWeight;
}`;

// gather DOF — circle of confusion from linear depth stored in alpha
export const DOF = HEAD + `
uniform sampler2D uSrc; uniform float uFocus, uAperture, uMaxCoc;
float coc(float d){ return clamp(abs(d - uFocus) / max(d, 0.05) * uAperture, 0.0, uMaxCoc); }
void main(){
  vec2 uv = gl_FragCoord.xy / uRes;
  vec4 c0 = texture(uSrc, uv);
  float r0 = coc(c0.a);
  if (uAperture <= 0.0) { fragColor = c0; return; }
  vec3 acc = c0.rgb; float wsum = 1.0;
  const int N = 36;
  float rMax = max(r0, uMaxCoc * 0.5);
  for (int i = 1; i < N; i++){
    float a = float(i) * 2.39996;
    float r = sqrt(float(i) / float(N)) * rMax;
    vec2 o = vec2(cos(a), sin(a)) * r / uRes;
    vec4 s = texture(uSrc, uv + o);
    float rs = coc(s.a);
    // a sample contributes if its own blur reaches us; background can't bleed over sharp foreground
    float w = smoothstep(r - 1.0, r + 1.0, rs) * (s.a < c0.a + 0.02 ? 1.0 : smoothstep(r - 1.0, r + 1.0, r0));
    // brighter highlights -> slightly weighted (bokeh)
    w *= 1.0 + 0.6 * smoothstep(1.0, 4.0, dot(s.rgb, vec3(0.33)));
    acc += s.rgb * w; wsum += w;
  }
  fragColor = vec4(acc / wsum, c0.a);
}`;

export const BRIGHT = HEAD + `
uniform sampler2D uSrc; uniform float uThreshold;
void main(){
  vec2 uv = gl_FragCoord.xy / uRes; vec2 px = 1.0 / uRes;
  vec3 c = texture(uSrc, uv + px * vec2(-0.25, -0.25)).rgb + texture(uSrc, uv + px * vec2(0.25, -0.25)).rgb
         + texture(uSrc, uv + px * vec2(-0.25, 0.25)).rgb + texture(uSrc, uv + px * vec2(0.25, 0.25)).rgb;
  c *= 0.25;
  float l = max(c.r, max(c.g, c.b));
  fragColor = vec4(c * smoothstep(uThreshold, uThreshold * 2.0 + 0.2, l), 1.0);
}`;

export const BLUR = HEAD + `
uniform sampler2D uSrc; uniform vec2 uDir;
void main(){
  vec2 uv = gl_FragCoord.xy / uRes;
  vec3 c = texture(uSrc, uv).rgb * 0.227027;
  vec2 o1 = uDir * 1.3846153 / uRes, o2 = uDir * 3.2307692 / uRes;
  c += (texture(uSrc, uv + o1).rgb + texture(uSrc, uv - o1).rgb) * 0.3162162;
  c += (texture(uSrc, uv + o2).rgb + texture(uSrc, uv - o2).rgb) * 0.0702703;
  fragColor = vec4(c, 1.0);
}`;

export const FINAL = HEAD + `
uniform sampler2D uSrc, uB1, uB2, uB3, uB4;
uniform float uTime, uExposure, uBloom, uFlash, uGrain, uVignette, uCA, uFade, uSeed, uStreak;
float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
vec3 aces(vec3 x){ return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0); }
void main(){
  vec2 uv = gl_FragCoord.xy / uRes;
  vec2 cc = uv - 0.5;
  // subtle lateral chromatic aberration toward the edges
  vec2 ca = cc * uCA * dot(cc, cc);
  vec3 col = vec3(texture(uSrc, uv - ca).r, texture(uSrc, uv).g, texture(uSrc, uv + ca).b);
  vec3 bl = texture(uB1, uv).rgb * 0.5 + texture(uB2, uv).rgb * 0.7 + texture(uB3, uv).rgb * 0.9 + texture(uB4, uv).rgb * 1.1;
  // anamorphic-ish horizontal streak from the widest bloom level
  bl += texture(uB4, vec2(uv.x * 0.7 + 0.15, uv.y)).rgb * uStreak;
  col += bl * uBloom;
  col *= uExposure * (1.0 + uFlash * 2.2);
  col += vec3(1.0, 0.55, 0.35) * uFlash * 0.12;
  // filmic tone map
  col = aces(col);
  // grade: crushed blacks, bordeaux shadows, warm-neutral highlights, restrained saturation
  float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
  col = mix(vec3(l), col, 0.86);
  col += vec3(0.022, -0.004, 0.002) * (1.0 - smoothstep(0.0, 0.35, l)) * smoothstep(0.0, 0.08, l);
  col = max(col - 0.006, 0.0) * 1.01;
  // vignette
  float vg = 1.0 - uVignette * smoothstep(0.25, 0.95, length(cc * vec2(1.0, 0.72)) * 1.35);
  col *= vg;
  col *= uFade;
  // gamma
  col = pow(col, vec3(1.0 / 2.2));
  // film grain (luma-weighted, animated per frame) + dither
  float g = hash12(gl_FragCoord.xy + uSeed * 91.7) + hash12(gl_FragCoord.xy * 1.37 + uSeed * 13.1) - 1.0;
  col += g * uGrain * (0.35 + 0.65 * (1.0 - abs(l * 2.0 - 1.0)));
  col += (hash12(gl_FragCoord.xy + 7.7 + uSeed) - 0.5) / 255.0;
  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}`;
