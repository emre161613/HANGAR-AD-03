// cloud_deneme parçasını (Layer0 profili) ekstrüde edip karbon elyaf görünümüyle WebGL2'de çizer.
// Tarayıcıda çalışır: window.PARCA = {centerline, thickness}, window.KAMERA = {...}
(function () {
  const { centerline, thickness } = window.PARCA;
  const cam = window.KAMERA;

  // --- Profili normalize et (genişlik = 2 birim) ---
  let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
  for (const [x, y] of centerline) {
    minX = Math.min(minX, x); maxX = Math.max(maxX, x);
    minY = Math.min(minY, y); maxY = Math.max(maxY, y);
  }
  const s = 2 / (maxX - minX);
  const cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
  const P = centerline.map(([x, y]) => [(x - cx) * s, (y - cy) * s]);
  const T = thickness * cam.kalinlikCarpani * s; // görünürlük için kalınlık abartılı
  const D = cam.derinlik;                      // ekstrüzyon boyu

  const sub = (a, b) => [a[0] - b[0], a[1] - b[1]];
  const norm = (a) => { const l = Math.hypot(a[0], a[1]); return [a[0] / l, a[1] / l]; };
  const n = P.length;
  const segT = [], segN = [];
  for (let i = 0; i < n - 1; i++) {
    const t = norm(sub(P[i + 1], P[i]));
    segT.push(t); segN.push([-t[1], t[0]]);
  }
  // Köşelerde miter ofset
  const off = P.map((p, i) => {
    const a = segN[Math.max(0, i - 1)], b = segN[Math.min(n - 2, i)];
    const m = norm([a[0] + b[0], a[1] + b[1]]);
    const k = 1 / Math.max(0.3, m[0] * b[0] + m[1] * b[1]);
    return [m[0] * k, m[1] * k];
  });
  const side = (i, sg) => [P[i][0] + off[i][0] * sg * T / 2, P[i][1] + off[i][1] * sg * T / 2];
  const arc = [0];
  for (let i = 1; i < n; i++) arc.push(arc[i - 1] + Math.hypot(...sub(P[i], P[i - 1])));

  // Yumuşak normaller: yalnızca 25°'den küçük kırılımlarda ortala (radyüs), keskin köşeler keskin kalsın
  const vNormal = (i, seg) => {
    const own = segN[seg];
    const other = seg === i ? segN[i - 1] : segN[i + 1];
    if (!other) return own;
    const c = own[0] * other[0] + own[1] * other[1];
    return c > Math.cos(25 * Math.PI / 180) ? norm([own[0] + other[0], own[1] + other[1]]) : own;
  };

  const data = []; // pos3 nrm3 uv2 tan3 type1
  const push = (p, nr, uv, tg, ty) => data.push(...p, ...nr, ...uv, ...tg, ty);
  const quad = (a, b, c, d) => { for (const v of [a, b, c, a, c, d]) push(...v); };
  const z0 = -D / 2, z1 = D / 2;

  for (let i = 0; i < n - 1; i++) {
    const tg = [segT[i][0], segT[i][1], 0];
    for (const sg of [1, -1]) {
      const pa = side(i, sg), pb = side(i + 1, sg);
      const na = vNormal(i, i), nb = vNormal(i + 1, i);
      const NA = [na[0] * sg, na[1] * sg, 0], NB = [nb[0] * sg, nb[1] * sg, 0];
      quad(
        [[pa[0], pa[1], z0], NA, [arc[i], z0], tg, 0],
        [[pb[0], pb[1], z0], NB, [arc[i + 1], z0], tg, 0],
        [[pb[0], pb[1], z1], NB, [arc[i + 1], z1], tg, 0],
        [[pa[0], pa[1], z1], NA, [arc[i], z1], tg, 0],
      );
    }
    // Ön/arka kesit (laminat kenarı)
    for (const [z, nz] of [[z0, -1], [z1, 1]]) {
      const a = side(i, 1), b = side(i + 1, 1), c = side(i + 1, -1), d = side(i, -1);
      const N = [0, 0, nz];
      quad(
        [[a[0], a[1], z], N, [arc[i], 1], tg, 1],
        [[b[0], b[1], z], N, [arc[i + 1], 1], tg, 1],
        [[c[0], c[1], z], N, [arc[i + 1], 0], tg, 1],
        [[d[0], d[1], z], N, [arc[i], 0], tg, 1],
      );
    }
  }
  // Uç yüzler
  for (const [i, dir] of [[0, -1], [n - 1, 1]]) {
    const t = segT[Math.min(i, n - 2)];
    const N = [t[0] * dir, t[1] * dir, 0];
    const a = side(i, 1), b = side(i, -1);
    quad(
      [[a[0], a[1], z0], N, [1, z0], [0, 0, 1], 1],
      [[b[0], b[1], z0], N, [0, z0], [0, 0, 1], 1],
      [[b[0], b[1], z1], N, [0, z1], [0, 0, 1], 1],
      [[a[0], a[1], z1], N, [1, z1], [0, 0, 1], 1],
    );
  }

  // --- WebGL ---
  const canvas = document.getElementById("parca");
  const gl = canvas.getContext("webgl2", { antialias: true, alpha: true, premultipliedAlpha: true, preserveDrawingBuffer: true });
  const vs = `#version 300 es
  layout(location=0) in vec3 aP; layout(location=1) in vec3 aN; layout(location=2) in vec2 aUv;
  layout(location=3) in vec3 aT; layout(location=4) in float aTy;
  uniform mat4 uM, uVP;
  out vec3 vP, vN, vT; out vec2 vUv; out float vTy;
  void main(){
    vec4 w = uM*vec4(aP,1.); vP = w.xyz;
    vN = mat3(uM)*aN; vT = mat3(uM)*aT; vUv = aUv; vTy = aTy;
    gl_Position = uVP*w;
  }`;
  const fs = `#version 300 es
  precision highp float;
  in vec3 vP, vN, vT; in vec2 vUv; in float vTy;
  uniform vec3 uCam; uniform float uTow;
  out vec4 o;
  float h(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
  void main(){
    vec3 N = normalize(vN), V = normalize(uCam - vP);
    if (dot(N,V) < 0.) N = -N;
    vec3 L1 = normalize(vec3(-0.45, 1.0, 0.55));   // ana ışık
    vec3 L2 = normalize(vec3(0.9, 0.15, -0.5));    // camgöbeği arka kontur
    vec3 col;
    if (vTy < 0.5) {
      // 2x2 twill karbon dokusu
      vec3 Tu = normalize(vT - N*dot(vT,N));
      vec3 Tv = normalize(cross(N, Tu));
      vec2 g = vUv / uTow; vec2 c = floor(g); vec2 f = fract(g);
      bool hz = mod(c.x + c.y, 4.0) < 2.0;
      vec3 Tf = hz ? Tu : Tv;
      float across = hz ? f.y : f.x;
      float bulge = sin(across*3.14159);
      float fib = 0.82 + 0.18*sin(across*3.14159*16. + h(c)*6.28);
      vec3 H = normalize(L1 + V);
      float th = dot(Tf, H);
      float aniso = pow(sqrt(max(0., 1. - th*th)), 70.);
      float diff = max(dot(N,L1), 0.);
      float tv = abs(dot(Tf, V));
      vec3 base = vec3(0.030, 0.034, 0.042);
      col = base*(0.35 + 0.9*diff);
      col += vec3(0.50, 0.56, 0.64)*aniso*bulge*fib*0.85;
      col += vec3(0.05, 0.06, 0.075)*(1. - tv)*bulge*fib;
      col *= 0.45 + 0.55*pow(bulge, 0.5);
    } else {
      // Kesit: laminat katmanları
      float ply = fract(vUv.y*6.);
      float diff = max(dot(N,L1), 0.)*0.6 + 0.4;
      col = mix(vec3(0.05,0.06,0.07), vec3(0.10,0.12,0.14), smoothstep(0.2,0.5,ply)*smoothstep(0.95,0.7,ply))*diff;
      col += vec3(0.22,0.78,0.96)*0.10;
    }
    // Vernik (clear coat) yansıması
    vec3 R = reflect(-V, N);
    float fres = 0.04 + 0.96*pow(1. - max(dot(N,V), 0.), 5.);
    vec3 env = mix(vec3(0.006,0.010,0.016), vec3(0.16,0.26,0.36), smoothstep(-0.2, 0.95, R.y));
    float box = smoothstep(0.45, 0.6, R.y)*smoothstep(0.55, 0.15, abs(R.x + 0.25));
    float spec = pow(max(dot(R, L1), 0.), 180.) + pow(max(dot(R, L1), 0.), 14.)*0.10;
    col += env*fres*0.55 + vec3(0.9,0.95,1.0)*box*(0.015 + fres*0.9) + spec*1.1;
    float rim = pow(1. - max(dot(N,V), 0.), 6.);
    col += vec3(0.22,0.78,0.96)*rim*max(dot(N,L2), 0.)*0.7;
    col = col/(1. + col);
    o = vec4(pow(col, vec3(1./2.2)), 1.);
  }`;
  const sh = (t, src) => { const x = gl.createShader(t); gl.shaderSource(x, src); gl.compileShader(x);
    if (!gl.getShaderParameter(x, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(x)); return x; };
  const prog = gl.createProgram();
  gl.attachShader(prog, sh(gl.VERTEX_SHADER, vs)); gl.attachShader(prog, sh(gl.FRAGMENT_SHADER, fs));
  gl.linkProgram(prog); gl.useProgram(prog);

  const buf = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, buf);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(data), gl.STATIC_DRAW);
  const stride = 12 * 4;
  [[0, 3, 0], [1, 3, 3], [2, 2, 6], [3, 3, 8], [4, 1, 11]].forEach(([loc, sz, ofs]) => {
    gl.enableVertexAttribArray(loc); gl.vertexAttribPointer(loc, sz, gl.FLOAT, false, stride, ofs * 4);
  });

  // --- Matrisler ---
  const persp = (fov, asp, nr, fr) => { const f = 1 / Math.tan(fov / 2), r = 1 / (nr - fr);
    return [f / asp, 0, 0, 0, 0, f, 0, 0, 0, 0, (nr + fr) * r, -1, 0, 0, 2 * nr * fr * r, 0]; };
  const lookAt = (e, t, u) => {
    const z = (() => { const v = [e[0] - t[0], e[1] - t[1], e[2] - t[2]]; const l = Math.hypot(...v); return v.map((q) => q / l); })();
    const cr = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
    let x = cr(u, z); const lx = Math.hypot(...x); x = x.map((q) => q / lx);
    const y = cr(z, x); const d = (a) => a[0] * e[0] + a[1] * e[1] + a[2] * e[2];
    return [x[0], y[0], z[0], 0, x[1], y[1], z[1], 0, x[2], y[2], z[2], 0, -d(x), -d(y), -d(z), 1];
  };
  const mul = (a, b) => { const r = new Array(16).fill(0);
    for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) for (let k = 0; k < 4; k++) r[j * 4 + i] += a[k * 4 + i] * b[j * 4 + k];
    return r; };
  const ry = (a) => [Math.cos(a), 0, -Math.sin(a), 0, 0, 1, 0, 0, Math.sin(a), 0, Math.cos(a), 0, 0, 0, 0, 1];

  const eye = cam.goz, M = ry(cam.donus * Math.PI / 180);
  const VP = mul(persp(cam.fov * Math.PI / 180, canvas.width / canvas.height, 0.1, 50), lookAt(eye, cam.hedef, [0, 1, 0]));
  gl.uniformMatrix4fv(gl.getUniformLocation(prog, "uM"), false, M);
  gl.uniformMatrix4fv(gl.getUniformLocation(prog, "uVP"), false, VP);
  gl.uniform3fv(gl.getUniformLocation(prog, "uCam"), eye);
  gl.uniform1f(gl.getUniformLocation(prog, "uTow"), cam.tow);

  gl.viewport(0, 0, canvas.width, canvas.height);
  gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
  gl.enable(gl.DEPTH_TEST);
  gl.drawArrays(gl.TRIANGLES, 0, data.length / 12);
  window.PARCA_HAZIR = true;
})();
