// Minimal WebGL2 helpers: programs, float render targets, fullscreen pass.

export const VERT = `#version 300 es
void main(){ vec2 p = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2); gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0); }`;

export function createGL(canvas) {
  const gl = canvas.getContext('webgl2', { antialias: false, preserveDrawingBuffer: true, premultipliedAlpha: false });
  if (!gl) throw new Error('WebGL2 not available');
  if (!gl.getExtension('EXT_color_buffer_float')) throw new Error('EXT_color_buffer_float missing');
  gl.getExtension('OES_texture_float_linear');
  gl.bindVertexArray(gl.createVertexArray());
  return gl;
}

export function program(gl, frag, name) {
  const sh = (type, src) => {
    const s = gl.createShader(type);
    gl.shaderSource(s, src);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
      const log = gl.getShaderInfoLog(s);
      const lines = src.split('\n').map((l, i) => `${String(i + 1).padStart(4)}: ${l}`);
      const m = /ERROR: 0:(\d+)/.exec(log);
      const ctx = m ? lines.slice(Math.max(0, +m[1] - 4), +m[1] + 2).join('\n') : '';
      throw new Error(`[${name}] shader compile failed:\n${log}\n${ctx}`);
    }
    return s;
  };
  const p = gl.createProgram();
  gl.attachShader(p, sh(gl.VERTEX_SHADER, VERT));
  gl.attachShader(p, sh(gl.FRAGMENT_SHADER, frag));
  gl.linkProgram(p);
  if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error(`[${name}] link failed: ${gl.getProgramInfoLog(p)}`);
  const locs = {};
  const n = gl.getProgramParameter(p, gl.ACTIVE_UNIFORMS);
  for (let i = 0; i < n; i++) { const u = gl.getActiveUniform(p, i); locs[u.name.replace(/\[0\]$/, '')] = gl.getUniformLocation(p, u.name); }
  return { p, locs, name };
}

export function target(gl, w, h, { float = true, filter = gl.LINEAR } = {}) {
  const tex = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, tex);
  gl.texImage2D(gl.TEXTURE_2D, 0, float ? gl.RGBA16F : gl.RGBA8, w, h, 0, gl.RGBA, float ? gl.HALF_FLOAT : gl.UNSIGNED_BYTE, null);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  const fb = gl.createFramebuffer();
  gl.bindFramebuffer(gl.FRAMEBUFFER, fb);
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0);
  gl.bindFramebuffer(gl.FRAMEBUFFER, null);
  return { tex, fb, w, h };
}

export function canvasTexture(gl, canvas, { mip = true } = {}) {
  const tex = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, tex);
  gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, canvas);
  gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
  if (mip) gl.generateMipmap(gl.TEXTURE_2D);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, mip ? gl.LINEAR_MIPMAP_LINEAR : gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  return tex;
}

export function updateCanvasTexture(gl, tex, canvas) {
  gl.bindTexture(gl.TEXTURE_2D, tex);
  gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, canvas);
  gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
}

// Draw a fullscreen pass. uniforms: {name: number | [..] | {tex, unit}}
export function pass(gl, prog, dst, uniforms = {}) {
  gl.useProgram(prog.p);
  gl.bindFramebuffer(gl.FRAMEBUFFER, dst ? dst.fb : null);
  gl.viewport(0, 0, dst ? dst.w : gl.drawingBufferWidth, dst ? dst.h : gl.drawingBufferHeight);
  let unit = 0;
  for (const [k, v] of Object.entries(uniforms)) {
    const loc = prog.locs[k];
    if (loc === undefined || loc === null) continue;
    if (v && v.tex !== undefined) {
      gl.activeTexture(gl.TEXTURE0 + unit);
      gl.bindTexture(gl.TEXTURE_2D, v.tex);
      gl.uniform1i(loc, unit++);
    } else if (v && v.fv) gl.uniform1fv(loc, v.fv);
    else if (typeof v === 'number') gl.uniform1f(loc, v);
    else if (v.length === 2) gl.uniform2fv(loc, v);
    else if (v.length === 3) gl.uniform3fv(loc, v);
    else if (v.length === 4) gl.uniform4fv(loc, v);
    else gl.uniform1fv(loc, v);
  }
  gl.drawArrays(gl.TRIANGLES, 0, 3);
}
