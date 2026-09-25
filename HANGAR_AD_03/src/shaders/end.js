// End card: typography layer (drawn with Canvas2D) treated as emission.
import { COMMON } from './common.js';
export const END = COMMON + /* glsl */ `
uniform sampler2D uText;
void main(){
  vec2 uv = gl_FragCoord.xy / uRes;
  vec3 c = texture(uText, uv).rgb;
  c = pow(c, vec3(2.2));               // sRGB canvas -> linear light
  fragColor = vec4(c * 1.05, 60.0);
}`;
