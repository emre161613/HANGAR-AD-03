// usage: node render.js preview t1 t2 ...   -> prev_<t>.png
//        node render.js full out.h264 out.idx [car.jpg]
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const fs = require('fs'), http = require('http'), path = require('path'), { spawn } = require('child_process');
const W = 1080, H = 1920, FPS = 30, NFRAMES = 1120;
const mode = process.argv[2];
const CAR = process.env.CAR || null;

const html = `<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:#000}</style></head>
<body><canvas id="c" width="${W}" height="${H}"></canvas>
<script src="/scene.js"></script>
<script>
async function loadImg(src){ const i=new Image(); i.src=src; await i.decode(); return i; }
window.ready=(async()=>{
  window.ENV = await (await fetch('/env.json')).json();
  const raw = await loadImg('/logo.jpg');
  // key the logo off its black background into an RGBA image (alpha from luminance)
  const c=document.createElement('canvas'); c.width=raw.naturalWidth; c.height=raw.naturalHeight;
  const x=c.getContext('2d'); x.drawImage(raw,0,0); const d=x.getImageData(0,0,c.width,c.height); const p=d.data;
  let bg=0; for(let i=0;i<40;i++){ bg+=p[i*4]; } bg/=40;
  const m=document.createElement('canvas'); m.width=c.width; m.height=c.height; const mx=m.getContext('2d'); const md=mx.createImageData(c.width,c.height);
  for(let i=0;i<p.length;i+=4){ const l=Math.max(p[i],p[i+1],p[i+2]); const a=Math.min(1,Math.max(0,(l-bg-8)/70));
    md.data[i]=p[i]; md.data[i+1]=p[i+1]; md.data[i+2]=p[i+2]; md.data[i+3]=Math.round(a*255); }
  mx.putImageData(md,0,0);
  window.LOGO = await loadImg(m.toDataURL('image/png')); window.LOGO_MASK = window.LOGO;
  window.CAR = ${CAR ? "await loadImg('/car')" : "Object.assign(makeCarPlaceholder(), {isPlaceholder: true})"};
  await document.fonts.load('700 100px "Liberation Sans"'); await document.fonts.load('400 40px "Liberation Sans"'); await document.fonts.load('400 26px "Liberation Mono"');
  return true;
})();
async function sendFrame(t){ drawFrame(t); const d=document.getElementById('c').getContext('2d').getImageData(0,0,${W},${H}).data;
  const r=await fetch('/frame',{method:'POST',body:d}); if(!r.ok) throw new Error('post failed'); }
async function renderAll(n){ for(let f=0;f<n;f++){ await sendFrame(f/${FPS}); } return n; }
</script></body></html>`;

let enc = null, framesIn = 0;
const srv = http.createServer((q, s) => {
  if (q.url === '/') { s.setHeader('Content-Type', 'text/html'); return s.end(html); }
  if (q.url === '/scene.js') { s.setHeader('Content-Type', 'text/javascript'); return s.end(fs.readFileSync('scene.js')); }
  if (q.url === '/env.json') return s.end(fs.readFileSync('env.json'));
  if (q.url === '/logo.jpg') { s.setHeader('Content-Type', 'image/jpeg'); return s.end(fs.readFileSync('logo.jpg')); }
  if (q.url === '/car' && CAR) { return s.end(fs.readFileSync(CAR)); }
  if (q.url === '/frame' && q.method === 'POST') {
    const bufs = []; q.on('data', b => bufs.push(b)); q.on('end', () => {
      const b = Buffer.concat(bufs); if (b.length !== W * H * 4) { s.statusCode = 500; return s.end('bad size'); }
      framesIn++; if (framesIn % 60 === 0) process.stderr.write(`\rrendered ${framesIn}/${NFRAMES}`);
      if (enc.stdin.write(b)) s.end('ok'); else enc.stdin.once('drain', () => s.end('ok'));
    }); return;
  }
  s.statusCode = 404; s.end();
}).listen(0);

(async () => {
  const port = srv.address().port;
  const browser = await chromium.launch({ args: ['--font-render-hinting=none', '--disable-lcd-text'] });
  const page = await browser.newPage({ viewport: { width: 400, height: 400 } });
  page.on('console', m => console.log('page:', m.text()));
  page.on('pageerror', e => { console.error('PAGE ERROR', e); process.exit(1); });
  await page.goto(`http://localhost:${port}/`);
  await page.evaluate(() => window.ready);
  if (mode === 'sheet') {
    const [name, cols, ...ts] = process.argv.slice(3);
    const url = await page.evaluate(({ts, cols}) => {
      const tw=270, th=480, rows=Math.ceil(ts.length/cols); const sh=document.createElement('canvas'); sh.width=tw*cols; sh.height=(th+30)*rows;
      const sx=sh.getContext('2d'); sx.fillStyle='#444'; sx.fillRect(0,0,sh.width,sh.height);
      ts.forEach((t,i)=>{ drawFrame(parseFloat(t)); const x=(i%cols)*tw, y=Math.floor(i/cols)*(th+30);
        sx.drawImage(document.getElementById('c'),x,y,tw-2,th); sx.fillStyle='#ff0'; sx.font='20px monospace'; sx.fillText('t='+t,x+6,y+th+22); });
      return sh.toDataURL('image/png'); }, {ts, cols: parseInt(cols)});
    fs.writeFileSync(`prev/${name}.png`, Buffer.from(url.split(',')[1], 'base64'));
  } else if (mode === 'preview') {
    for (const ts of process.argv.slice(3)) {
      const t = parseFloat(ts);
      const url = await page.evaluate(t => { drawFrame(t); return document.getElementById('c').toDataURL('image/png'); }, t);
      fs.writeFileSync(`prev/prev_${ts}.png`, Buffer.from(url.split(',')[1], 'base64'));
    }
  } else {
    const [out, idx] = process.argv.slice(3);
    enc = spawn('./h264enc', [String(W), String(H), out, idx, '-q', process.env.QPI || '19', process.env.QPP || '21', '-g', '60'], { stdio: ['pipe', 'inherit', 'inherit'] });
    const done = new Promise(r => enc.on('exit', r));
    const n = parseInt(process.env.NFRAMES || NFRAMES);
    await page.evaluate(n => renderAll(n), n);
    enc.stdin.end(); const code = await done; console.log('\nencoder exit', code);
  }
  await browser.close(); srv.close();
})();
