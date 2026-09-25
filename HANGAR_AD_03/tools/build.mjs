#!/usr/bin/env node
// HANGAR_AD_03 build tool — builds the whole film as one ffmpeg filtergraph
// from config/timeline.json + config/assets.json. No npm dependencies.
//
//   node tools/build.mjs check            environment + asset report
//   node tools/build.mjs plan             write output/build/ (filtergraph + command), no render
//   node tools/build.mjs render           final render -> output/HANGAR_AD_03_v01.mp4
//   node tools/build.mjs render --preview allow missing assets (slate frames), writes *_PREVIEW.mp4
//
// The code here only cuts, crops, grades, adds film texture, mixes sound and
// draws the end card. It never generates replacement car imagery: a missing
// clip becomes a labelled slate in --preview and blocks the final render.

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const rel = (p) => path.resolve(ROOT, p);
const T = JSON.parse(fs.readFileSync(rel('config/timeline.json'), 'utf8'));
const A = JSON.parse(fs.readFileSync(rel('config/assets.json'), 'utf8'));
const { width: W, height: H, fps: FPS, sampleRate: SR } = T.format;
const f3 = (n) => Number(n).toFixed(3);

const [cmd = 'check', ...flags] = process.argv.slice(2);
const PREVIEW = flags.includes('--preview');

// ---------------------------------------------------------------- environment
function findFfmpeg() {
  const cands = [process.env.FFMPEG, 'ffmpeg'].filter(Boolean);
  for (const c of cands) {
    const r = spawnSync(c, ['-hide_banner', '-encoders'], { encoding: 'utf8' });
    if (r.status === 0) {
      const f = spawnSync(c, ['-hide_banner', '-filters'], { encoding: 'utf8' }).stdout || '';
      return {
        bin: c,
        x264: /libx264/.test(r.stdout),
        aac: /\baac\b/.test(r.stdout),
        filters: ['drawtext', 'zoompan', 'sidechaincompress', 'loudnorm', 'gblur', 'colorbalance']
          .filter((n) => !new RegExp(`\\s${n}\\s`).test(f)),
      };
    }
  }
  return null;
}

function assetPath(id) {
  const e = A.video[id] || A.audio[id] || A.brand[id];
  return e ? rel(e.file) : null;
}
const exists = (p) => p && fs.existsSync(p);

function check() {
  const ff = findFfmpeg();
  const out = [];
  out.push('== Ortam');
  if (!ff) out.push('  ✗ ffmpeg bulunamadı (FFMPEG env veya PATH). Render mümkün değil.');
  else {
    out.push(`  ✓ ffmpeg: ${ff.bin}`);
    out.push(`  ${ff.x264 ? '✓' : '✗'} libx264 (H.264)   ${ff.aac ? '✓' : '✗'} aac`);
    if (ff.filters.length) out.push(`  ✗ eksik filtreler: ${ff.filters.join(', ')}`);
  }
  let blocking = 0;
  for (const [group, entries] of Object.entries({ video: A.video, audio: A.audio, brand: A.brand })) {
    out.push(`== ${group}`);
    for (const [id, e] of Object.entries(entries)) {
      const have = exists(rel(e.file));
      const miss = !have && e.required && e.status !== 'code' && e.status !== 'placeholder';
      if (miss) blocking++;
      out.push(`  ${have ? '✓' : miss ? '✗' : '·'} ${id.padEnd(14)} ${e.status.padEnd(11)} ${e.file}`);
    }
  }
  out.push(`== Final render'ı engelleyen eksik asset: ${blocking}`);
  console.log(out.join('\n'));
  return { ff, blocking };
}

// ---------------------------------------------------------------- graph
function tracked(text, tracking = 0) {
  const n = Math.round(tracking / 0.1); // ~0.1em per hair space
  return n ? [...text].join('\u200A'.repeat(n)) : text;
}

function buildGraph() {
  const inputs = [];      // ffmpeg input args
  const chains = [];      // filtergraph chains
  const addInput = (args) => { inputs.push(...args); return inputs.filter((a) => a === '-i').length - 1; };
  const buildDir = rel('output/build');
  fs.mkdirSync(buildDir, { recursive: true });
  const fontMain = exists(rel(T.endcard.font)) ? rel(T.endcard.font) : T.endcard.fontFallback;
  const fontSec = exists(rel(T.endcard.fontSecondary)) ? rel(T.endcard.fontSecondary) : T.endcard.fontSecondaryFallback;
  const esc = (p) => p.replace(/\\/g, '/').replace(/:/g, '\\:').replace(/'/g, "\\'");

  // --- picture: shots
  const segs = [];
  T.shots.forEach((s, i) => {
    const d = s.end - s.start;
    const out = `v${i}`;
    const file = s.type === 'clip' ? assetPath(s.asset) : null;
    if (s.type === 'black') {
      chains.push(`color=c=black:s=${W}x${H}:r=${FPS}:d=${f3(d)},format=yuv444p[${out}]`);
    } else if (!exists(file)) {
      if (!PREVIEW) throw new Error(`Eksik klip: ${s.asset} (${s.id}) — final render yapılamaz.`);
      const tf = path.join(buildDir, `slate_${s.id}.txt`);
      fs.writeFileSync(tf, `${s.id} · ${s.asset}\nEKSİK KLİP`);
      chains.push(`color=c=0x111111:s=${W}x${H}:r=${FPS}:d=${f3(d)},` +
        `drawtext=fontfile='${esc(fontSec)}':textfile='${esc(tf)}':fontcolor=0x777777:fontsize=42:x=(w-tw)/2:y=(h-th)/2,format=yuv444p[${out}]`);
    } else {
      const k = addInput(['-i', file]);
      const sp = s.speed || 1;
      const N = Math.round(d * FPS);
      const { cx = 0.5, cy = 0.5 } = s.crop || {};
      let c = `[${k}:v]trim=start=${f3(s.in)}:duration=${f3(d * sp)},setpts=(PTS-STARTPTS)/${sp},fps=${FPS},` +
        `scale=${W}:${H}:force_original_aspect_ratio=increase:flags=lanczos,` +
        `crop=${W}:${H}:(iw-${W})*${cx}:(ih-${H})*${cy},setsar=1`;
      if (s.push) {
        // slow optical push-in; supersample first so zoompan doesn't step
        c += `,scale=${W * 2}:${H * 2}:flags=lanczos,zoompan=z='1+${s.push}*on/${N}':` +
          `x='iw/2-iw/zoom/2':y='ih/2-ih/zoom/2':d=1:s=${W}x${H}:fps=${FPS}`;
      }
      chains.push(`${c},format=yuv444p[${out}]`);
    }
    segs.push(`[${out}]`);
  });
  chains.push(`${segs.join('')}concat=n=${segs.length}:v=1:a=0[base]`);

  // --- global grade (footage only; end card is kept neutral)
  const g = T.grade;
  const [sr, sg, sb] = g.shadowTint, [hr, hg, hb] = g.highlightTint;
  chains.push(
    `[base]eq=contrast=${g.contrast}:saturation=${g.saturation},` +
    `curves=all='0/0 ${g.blackCrush}/0 0.5/0.47 1/0.97',` +
    `colorbalance=rs=${sr}:gs=${sg}:bs=${sb}:rh=${hr}:gh=${hg}:bh=${hb},split[gA][gB]`,
    `[gB]curves=all='0/0 ${g.halation.threshold}/0 1/1',colorchannelmixer=rr=1:gg=0.22:bb=0.12,` +
    `gblur=sigma=${g.halation.sigma}[hal]`,
    `[gA][hal]blend=all_mode=screen:all_opacity=${g.halation.opacity},vignette=angle=${g.vignette}[graded]`,
  );

  // --- end card
  const ec = T.endcard;
  const ecStart = ec.items[0].start;
  const ecDur = T.duration - ecStart;
  let card = `color=c=black:s=${W}x${H}:r=${FPS}:d=${f3(ecDur)},format=yuv444p`;
  let cardLabel = 'card0';
  chains.push(`${card}[${cardLabel}]`);
  const logoFile = rel(ec.logo);
  for (const it of ec.items) {
    const a = it.start - ecStart, b = it.end - ecStart;
    const fi = it.fadeIn || 0, op = it.opacity ?? 1;
    const alpha = fi ? `if(lt(t,${f3(a)}),0,min(1,(t-${f3(a)})/${f3(fi)}))*${op}` : `${op}`;
    const next = `card${it.id}`;
    if (it.kind === 'text') {
      const tf = path.join(buildDir, `text_${it.id}.txt`);
      fs.writeFileSync(tf, tracked(it.text, it.tracking));
      const font = it.size >= 80 ? fontMain : fontSec;
      chains.push(`[${cardLabel}]drawtext=fontfile='${esc(font)}':textfile='${esc(tf)}':fontsize=${it.size}:` +
        `fontcolor=${ec.color}:x=(w-tw)/2:y=h*${it.y}-th/2:alpha='${alpha}':enable='between(t,${f3(a)},${f3(b)})'[${next}]`);
      cardLabel = next;
    } else if (it.kind === 'logo') {
      const lw = Math.round(W * it.width);
      if (exists(logoFile)) {
        const k = addInput(['-loop', '1', '-t', f3(ecDur), '-i', logoFile]);
        chains.push(`[${k}:v]format=rgba,scale=${lw}:-1:flags=lanczos,` +
          `fade=t=in:st=${f3(a)}:d=${f3(fi)}:alpha=1[logo]`,
          `[${cardLabel}][logo]overlay=x=(W-w)/2:y=H*${it.y}-h/2:enable='between(t,${f3(a)},${f3(b)})'[${next}]`);
      } else {
        // Placeholder only: neutral outline + label. Not a logo design.
        const lh = Math.round(lw * 0.28);
        const tf = path.join(buildDir, 'logo_placeholder.txt');
        fs.writeFileSync(tf, 'LOGO PLACEHOLDER');
        chains.push(`[${cardLabel}]drawbox=x=(iw-${lw})/2:y=ih*${it.y}-${lh / 2}:w=${lw}:h=${lh}:` +
          `color=0x555555@0.9:t=2:enable='between(t,${f3(a)},${f3(b)})',` +
          `drawtext=fontfile='${esc(fontSec)}':textfile='${esc(tf)}':fontsize=28:fontcolor=0x555555:` +
          `x=(w-tw)/2:y=h*${it.y}-th/2:enable='between(t,${f3(a)},${f3(b)})'[${next}]`);
      }
      cardLabel = next;
    }
  }

  // --- join, film texture, final fade
  chains.push(`[graded][${cardLabel}]concat=n=2:v=1:a=0,noise=alls=${g.grain.strength}:allf=t,` +
    `fade=t=out:st=${f3(ec.fadeOutAt)}:d=${f3(T.duration - ec.fadeOutAt)},format=yuv420p[vout]`);

  // --- sound
  const au = T.audio;
  const pre = [], post = [];
  const addEvent = (id, e, bucket, label) => {
    const file = assetPath(e.asset);
    if (!exists(file)) {
      const req = (A.audio[e.asset] || {}).required;
      if (req && !PREVIEW) throw new Error(`Eksik ses: ${e.asset} (${id}) — final render yapılamaz.`);
      return;
    }
    const k = addInput(['-i', file]);
    const ms = Math.round(e.at * 1000);
    let c = `[${k}:a]atrim=start=${f3(e.in)}:duration=${f3(e.dur)},asetpts=PTS-STARTPTS,` +
      `aformat=sample_rates=${SR}:channel_layouts=stereo,volume=${e.gainDb}dB`;
    if (e.fadeIn) c += `,afade=t=in:d=${f3(e.fadeIn)}`;
    c += `,afade=t=out:st=${f3(Math.max(0, e.dur - (e.fadeOut || 0.01)))}:d=${f3(e.fadeOut || 0.01)}`;
    chains.push(`${c},adelay=${ms}|${ms}[${label}]`);
    bucket.push(`[${label}]`);
  };
  au.events.forEach((e) => addEvent(e.id, e, e.at < au.cutAt ? pre : post, `a${e.id}`));

  const mix = (labels, out) => chains.push(labels.length
    ? `${labels.join('')}amix=inputs=${labels.length}:normalize=0:dropout_transition=0[${out}]`
    : `anullsrc=r=${SR}:cl=stereo,atrim=duration=${f3(T.duration)}[${out}]`);

  mix(pre, 'sfxPre');
  const m = au.music;
  const musicFile = assetPath(m.asset);
  let preBus = 'sfxPre';
  if (exists(musicFile)) {
    const k = addInput(['-i', musicFile]);
    chains.push(`[sfxPre]asplit[sfxDry][sfxKey]`,
      `[${k}:a]atrim=start=${f3(m.in)}:duration=${f3(m.dur)},asetpts=PTS-STARTPTS,` +
      `aformat=sample_rates=${SR}:channel_layouts=stereo,volume=${m.gainDb}dB,afade=t=in:d=${f3(m.fadeIn)},` +
      `adelay=${Math.round(m.at * 1000)}|${Math.round(m.at * 1000)}[mus]`,
      `[mus][sfxKey]sidechaincompress=threshold=0.04:ratio=6:attack=5:release=260:makeup=1[musD]`,
      `[sfxDry][musD]amix=inputs=2:normalize=0[preMix]`);
    preBus = 'preMix';
    if (m.tail) {
      const k2 = addInput(['-i', musicFile]);
      const ms = Math.round(m.tail.at * 1000);
      chains.push(`[${k2}:a]atrim=start=${f3(m.in + m.dur)}:duration=${f3(m.tail.dur)},asetpts=PTS-STARTPTS,` +
        `aformat=sample_rates=${SR}:channel_layouts=stereo,volume=${m.tail.gainDb}dB,afade=t=in:d=0.4,` +
        `afade=t=out:st=${f3(m.tail.dur - m.tail.fadeOut)}:d=${f3(m.tail.fadeOut)},adelay=${ms}|${ms}[musTail]`);
      post.push('[musTail]');
    }
  } else if (!PREVIEW && (A.audio[m.asset] || {}).required) {
    throw new Error('Eksik müzik: MUSIC — final render yapılamaz.');
  }

  // hard cut at cutAt, keeping only a short reverb tail of the last moment
  const cut = au.cutAt, tail = au.cutReverbTail, ms = Math.round(cut * 1000);
  chains.push(`[${preBus}]asplit[pDry][pWet]`,
    `[pDry]atrim=end=${f3(cut)},afade=t=out:st=${f3(cut - 0.012)}:d=0.012,apad=whole_dur=${f3(T.duration)}[cutDry]`,
    `[pWet]atrim=start=${f3(cut - 0.2)}:end=${f3(cut)},asetpts=PTS-STARTPTS,apad=pad_dur=${f3(tail + 0.2)},` +
    `aecho=0.7:0.6:90|170|260|380:0.45|0.32|0.22|0.14,highpass=f=180,atrim=start=0.2,asetpts=PTS-STARTPTS,` +
    `afade=t=out:st=0:d=${f3(tail)},volume=-6dB,adelay=${ms}|${ms}[cutTail]`);
  post.push('[cutDry]', '[cutTail]');
  chains.push(`${post.join('')}amix=inputs=${post.length}:normalize=0:duration=first,` +
    `atrim=duration=${f3(T.duration)},loudnorm=I=${au.targetLUFS}:TP=${au.truePeak}:LRA=11,` +
    `aresample=${SR}[aout]`);

  return { inputs, graph: chains.join(';\n') };
}

// ---------------------------------------------------------------- commands
if (cmd === 'check') {
  check();
} else if (cmd === 'plan' || cmd === 'render') {
  let built;
  try { built = buildGraph(); } catch (e) { console.error(`✗ ${e.message}\n  Taslak için: node tools/build.mjs ${cmd} --preview`); process.exit(3); }
  const { graph, inputs } = built;
  const buildDir = rel('output/build');
  fs.writeFileSync(path.join(buildDir, 'filtergraph.txt'), graph);
  const outFile = rel(PREVIEW ? T.output.replace(/\.mp4$/, '_PREVIEW.mp4') : T.output);
  const args = ['-y', '-hide_banner', ...inputs, '-filter_complex_script', path.join(buildDir, 'filtergraph.txt'),
    '-map', '[vout]', '-map', '[aout]', '-t', f3(T.duration),
    '-c:v', 'libx264', '-profile:v', 'high', '-pix_fmt', 'yuv420p', '-preset', 'slow', '-crf', '16',
    '-r', String(FPS), '-c:a', 'aac', '-b:a', '256k', '-ar', String(SR), '-movflags', '+faststart', outFile];
  fs.writeFileSync(path.join(buildDir, 'command.txt'), ['ffmpeg', ...args].map((a) => JSON.stringify(a)).join(' ') + '\n');
  console.log(`filtergraph → output/build/filtergraph.txt\ncommand     → output/build/command.txt`);
  if (cmd === 'render') {
    const ff = findFfmpeg();
    if (!ff || !ff.x264 || !ff.aac) {
      console.error('✗ Render durduruldu: libx264 + aac içeren ffmpeg gerekli. `node tools/build.mjs check` çalıştırın.');
      process.exit(2);
    }
    const r = spawnSync(ff.bin, args, { stdio: 'inherit' });
    process.exit(r.status ?? 1);
  }
} else {
  console.error('Kullanım: node tools/build.mjs [check|plan|render] [--preview]');
  process.exit(1);
}
