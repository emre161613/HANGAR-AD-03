// Frame renderer: window.renderFrame(i) draws frame i into the canvas.
import { createGL, program, target, canvasTexture, updateCanvasTexture, pass } from './gl.js';
import { FPS, W, H, FRAMES, CUE } from './timeline.js';
import { direct } from './director.js';
import { makeTextures, drawEndcard } from './textures.js';
import { DASH } from './shaders/dash.js';
import { END } from './shaders/end.js';
import { ACCUM, DOF, BRIGHT, BLUR, FINAL } from './shaders/post.js';

const params = new URLSearchParams(location.search);
const SCALE = Number(params.get('scale') || 1);          // internal render scale
const SUB = params.get('sub');                           // override motion-blur subframes
const RW = Math.round(W * SCALE), RH = Math.round(H * SCALE);

async function init() {
  await document.fonts.load('700 40px HangarSans');
  await document.fonts.load('400 40px HangarSans');
  const canvas = document.getElementById('c');
  const gl = createGL(canvas);
  const tx = makeTextures();
  const tex = Object.fromEntries(Object.entries(tx).map(([k, c]) => [k, canvasTexture(gl, c)]));
  const textCanvas = document.createElement('canvas'); textCanvas.width = RW; textCanvas.height = RH;
  const textCtx = textCanvas.getContext('2d');
  textCtx.scale(SCALE, SCALE);
  const textTex = canvasTexture(gl, textCanvas, { mip: false });

  const scenes = { dash: program(gl, DASH, 'dash'), end: program(gl, END, 'end') };
  for (const [id, mod] of [['mech', './shaders/mech.js'], ['road', './shaders/road.js']]) {
    try { const m = await import(mod); scenes[id] = program(gl, m[id.toUpperCase()], id); } catch (e) { if (!/Failed to fetch|Cannot find|404|error loading/i.test(String(e))) throw e; }
  }
  const P = { accum: program(gl, ACCUM, 'accum'), dof: program(gl, DOF, 'dof'), bright: program(gl, BRIGHT, 'bright'), blur: program(gl, BLUR, 'blur'), final: program(gl, FINAL, 'final') };

  const T = {
    scene: target(gl, RW, RH), accum: target(gl, RW, RH), dof: target(gl, RW, RH),
    b: [2, 4, 8, 16].map((d) => [target(gl, Math.round(RW / d), Math.round(RH / d)), target(gl, Math.round(RW / d), Math.round(RH / d))]),
  };

  function renderFrame(i) {
    const t = i / FPS;
    const d0 = direct(t);
    const n = SUB ? Number(SUB) : d0.subframes;
    const shutter = 0.5 / FPS; // 180° shutter
    // --- motion blur: accumulate sub-frames
    gl.bindFramebuffer(gl.FRAMEBUFFER, T.accum.fb);
    gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT);
    for (let s = 0; s < n; s++) {
      const ts = n > 1 ? t + (s / (n - 1) - 0.5) * shutter : t;
      const d = direct(ts);
      const prog = scenes[d.scene] || scenes.end;
      if (d.scene === 'end') {
        drawEndcard(textCtx, ts, CUE, W, H);
        updateCanvasTexture(gl, textTex, textCanvas);
      }
      pass(gl, prog, T.scene, {
        uRes: [RW, RH], uTime: ts, uCamPos: d.cam.pos, uCamTarget: d.cam.target, uFov: d.cam.fov, uRoll: d.cam.roll || 0,
        uTach: { tex: tex.tach }, uSpeedo: { tex: tex.speedo }, uSmall: { tex: tex.small }, uCap: { tex: tex.cap }, uText: { tex: textTex },
        ...d.u,
      });
      gl.enable(gl.BLEND); gl.blendFunc(gl.ONE, gl.ONE);
      pass(gl, P.accum, T.accum, { uRes: [RW, RH], uSrc: { tex: T.scene.tex }, uWeight: 1 / n });
      gl.disable(gl.BLEND);
    }
    const po = d0.post;
    pass(gl, P.dof, T.dof, { uRes: [RW, RH], uSrc: { tex: T.accum.tex }, uFocus: po.focus, uAperture: po.aperture * SCALE, uMaxCoc: po.maxCoc * SCALE });
    // --- bloom pyramid
    let src = T.dof;
    T.b.forEach(([a, b], k) => {
      pass(gl, P.bright, a, { uRes: [a.w, a.h], uSrc: { tex: src.tex }, uThreshold: k === 0 ? po.threshold : 0.0 });
      pass(gl, P.blur, b, { uRes: [b.w, b.h], uSrc: { tex: a.tex }, uDir: [1, 0] });
      pass(gl, P.blur, a, { uRes: [a.w, a.h], uSrc: { tex: b.tex }, uDir: [0, 1] });
      src = a;
    });
    pass(gl, P.final, null, {
      uRes: [W, H], uSrc: { tex: T.dof.tex }, uB1: { tex: T.b[0][0].tex }, uB2: { tex: T.b[1][0].tex }, uB3: { tex: T.b[2][0].tex }, uB4: { tex: T.b[3][0].tex },
      uTime: t, uExposure: po.exposure, uBloom: po.bloom, uFlash: po.flash || 0, uGrain: 0.045, uVignette: 0.55, uCA: 0.012,
      uFade: d0.fade, uSeed: i % 97, uStreak: po.streak || 0,
    });
    gl.finish();
    return { t, scene: d0.scene };
  }
  window.renderFrame = renderFrame;
  window.__dbg = { gl, T };
  window.FRAMES = FRAMES;
}
window.ready = init().then(() => 'ok', (e) => { console.error(e); return 'ERR ' + (e && e.message); });
