#!/usr/bin/env python3
"""Minimal MP4 muxer: H.264 Annex-B (+ per-frame index) and MP3 passthrough -> faststart MP4.
usage: mux.py video.h264 video.idx fps audio.mp3|- out.mp4 [width height]
"""
import struct, sys

def box(t, *payload):
    data = b''.join(payload)
    return struct.pack('>I', 8 + len(data)) + t + data

def fullbox(t, ver, flags, *payload):
    return box(t, struct.pack('>I', (ver << 24) | flags), *payload)

# ---------------- video ----------------
def split_nals(buf):
    out = []; i = 0; n = len(buf); starts = []
    while i + 3 <= n:
        if buf[i] == 0 and buf[i+1] == 0 and buf[i+2] == 1:
            starts.append(i + 3); i += 3
        else:
            i += 1
    for k, s in enumerate(starts):
        e = starts[k+1] - 3 if k + 1 < len(starts) else n
        nal = buf[s:e]
        while nal and nal[-1] == 0:  # strip trailing zero (part of next 4-byte start code)
            nal = nal[:-1]
        out.append(nal)
    return out

def load_video(h264, idx):
    data = open(h264, 'rb').read()
    frames = []; pos = 0; sps = pps = None
    for line in open(idx):
        size, key = line.split(); size = int(size); key = int(key)
        chunk = data[pos:pos+size]; pos += size
        sample = b''
        for nal in split_nals(chunk):
            t = nal[0] & 31
            if t == 7: sps = sps or nal; continue
            if t == 8: pps = pps or nal; continue
            sample += struct.pack('>I', len(nal)) + nal
        frames.append((sample, key))
    assert pos == len(data), (pos, len(data))
    return frames, sps, pps

# ---------------- audio (MP3) ----------------
BR = {1: [0,32,40,48,56,64,80,96,112,128,160,192,224,256,320]}
SR = [44100, 48000, 32000]

def load_mp3(path):
    d = open(path, 'rb').read(); i = 0
    if d[:3] == b'ID3':
        i = 10 + ((d[6] << 21) | (d[7] << 14) | (d[8] << 7) | d[9])
    frames = []; delay = padding = 0; sr = None; ch = None; first = True
    while i + 4 <= len(d):
        h = int.from_bytes(d[i:i+4], 'big')
        if (h >> 21) & 0x7ff != 0x7ff:
            break
        ver = (h >> 19) & 3; layer = (h >> 17) & 3
        assert ver == 3 and layer == 1, 'only MPEG-1 Layer III supported'
        br = BR[1][(h >> 12) & 15]; sr = SR[(h >> 10) & 3]; pad = (h >> 9) & 1
        mode = (h >> 6) & 3; ch = 1 if mode == 3 else 2
        L = 144000 * br // sr + pad
        fr = d[i:i+L]
        if first and (b'Xing' in fr[:64] or b'Info' in fr[:64]):
            k = fr.find(b'LAME')
            if k >= 0:
                x = fr[k+21:k+24]
                delay = (x[0] << 4) | (x[1] >> 4); padding = ((x[1] & 15) << 8) | x[2]
        else:
            frames.append(fr)
        first = False
        i += L
    return frames, sr, ch, delay, padding

def descr(tag, payload):
    assert len(payload) < 128
    return bytes([tag, len(payload)]) + payload

def main():
    h264, idx, fps, mp3, out = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5]
    W = int(sys.argv[6]) if len(sys.argv) > 6 else 1080
    H = int(sys.argv[7]) if len(sys.argv) > 7 else 1920
    vframes, sps, pps = load_video(h264, idx)
    has_audio = mp3 != '-'
    if has_audio:
        aframes, asr, ach, delay, padding = load_mp3(mp3)
        dec_delay = 529
        a_total = len(aframes) * 1152
        a_media_start = delay + dec_delay
        a_valid = a_total - delay - padding
        print(f'audio: {len(aframes)} frames sr={asr} ch={ach} delay={delay} padding={padding} valid={a_valid/asr:.3f}s')

    MT = 1000                      # movie timescale
    VTS = fps * 1000; VDUR = 1000  # video timescale / sample delta
    v_dur_media = len(vframes) * VDUR
    v_dur_movie = v_dur_media * MT // VTS
    if has_audio:
        a_dur_movie = a_valid * MT // asr
    movie_dur = max(v_dur_movie, a_dur_movie if has_audio else 0)

    # interleave into ~0.5 s chunks
    chunks = []  # (track, [samples])
    vi = ai = 0; vchunk = fps // 2; achunk = (asr // 1152) // 2 if has_audio else 0
    while vi < len(vframes) or (has_audio and ai < len(aframes)):
        if vi < len(vframes):
            chunks.append(('v', vframes[vi:vi+vchunk])); vi += vchunk
        if has_audio and ai < len(aframes):
            chunks.append(('a', aframes[ai:ai+achunk])); ai += achunk

    def stsc_for(track):
        entries = []; cidx = 0
        for t, s in chunks:
            if t != track: continue
            cidx += 1
            n = len(s)
            if not entries or entries[-1][1] != n:
                entries.append((cidx, n))
        return fullbox(b'stsc', 0, 0, struct.pack('>I', len(entries)), *[struct.pack('>III', c, n, 1) for c, n in entries])

    def build_moov(offsets):
        mvhd = fullbox(b'mvhd', 0, 0, struct.pack('>IIII', 0, 0, MT, movie_dur), struct.pack('>IH', 0x00010000, 0x0100),
                       b'\0' * 10, struct.pack('>9I', 0x10000, 0, 0, 0, 0x10000, 0, 0, 0, 0x40000000), b'\0' * 24,
                       struct.pack('>I', 3))
        matrix = struct.pack('>9I', 0x10000, 0, 0, 0, 0x10000, 0, 0, 0, 0x40000000)
        # video trak
        vsizes = [len(s) for s, k in vframes]
        vkeys = [i + 1 for i, (s, k) in enumerate(vframes) if k]
        avcC = box(b'avcC', bytes([1, sps[1], sps[2], sps[3], 0xFF, 0xE1]), struct.pack('>H', len(sps)), sps,
                   bytes([1]), struct.pack('>H', len(pps)), pps)
        colr = box(b'colr', b'nclx', struct.pack('>HHHB', 1, 1, 1, 0))
        pasp = box(b'pasp', struct.pack('>II', 1, 1))
        avc1 = box(b'avc1', b'\0' * 6, struct.pack('>H', 1), b'\0' * 16, struct.pack('>HH', W, H),
                   struct.pack('>II', 0x00480000, 0x00480000), b'\0' * 4, struct.pack('>H', 1), b'\0' * 32,
                   struct.pack('>Hh', 0x18, -1), avcC, colr, pasp)
        vstbl = box(b'stbl',
                    fullbox(b'stsd', 0, 0, struct.pack('>I', 1), avc1),
                    fullbox(b'stts', 0, 0, struct.pack('>III', 1, len(vframes), VDUR)),
                    fullbox(b'stss', 0, 0, struct.pack('>I', len(vkeys)), *[struct.pack('>I', k) for k in vkeys]),
                    stsc_for('v'),
                    fullbox(b'stsz', 0, 0, struct.pack('>II', 0, len(vsizes)), *[struct.pack('>I', s) for s in vsizes]),
                    fullbox(b'stco', 0, 0, struct.pack('>I', len(offsets['v'])), *[struct.pack('>I', o) for o in offsets['v']]))
        dinf = box(b'dinf', fullbox(b'dref', 0, 0, struct.pack('>I', 1), fullbox(b'url ', 0, 1)))
        vtrak = box(b'trak',
                    fullbox(b'tkhd', 0, 3, struct.pack('>IIIII', 0, 0, 1, 0, v_dur_movie), b'\0' * 8,
                            struct.pack('>hhhH', 0, 0, 0, 0), matrix, struct.pack('>II', W << 16, H << 16)),
                    box(b'edts', fullbox(b'elst', 0, 0, struct.pack('>IIIhh', 1, v_dur_movie, 0, 1, 0))),
                    box(b'mdia',
                        fullbox(b'mdhd', 0, 0, struct.pack('>IIII', 0, 0, VTS, v_dur_media), struct.pack('>HH', 0x55C4, 0)),
                        fullbox(b'hdlr', 0, 0, struct.pack('>I', 0), b'vide', b'\0' * 12, b'VideoHandler\0'),
                        box(b'minf', fullbox(b'vmhd', 0, 1, b'\0' * 8), dinf, vstbl)))
        traks = [vtrak]
        if has_audio:
            asizes = [len(f) for f in aframes]
            esds = fullbox(b'esds', 0, 0, descr(3, struct.pack('>HB', 2, 0) +
                            descr(4, bytes([0x6B, 0x15]) + (1152 * 4).to_bytes(3, 'big') + struct.pack('>II', 320000, 320000)) +
                            descr(6, b'\x02')))
            mp4a = box(b'mp4a', b'\0' * 6, struct.pack('>H', 1), b'\0' * 8, struct.pack('>HHHH', ach, 16, 0, 0),
                       struct.pack('>I', asr << 16), esds)
            astbl = box(b'stbl',
                        fullbox(b'stsd', 0, 0, struct.pack('>I', 1), mp4a),
                        fullbox(b'stts', 0, 0, struct.pack('>III', 1, len(aframes), 1152)),
                        stsc_for('a'),
                        fullbox(b'stsz', 0, 0, struct.pack('>II', 0, len(asizes)), *[struct.pack('>I', s) for s in asizes]),
                        fullbox(b'stco', 0, 0, struct.pack('>I', len(offsets['a'])), *[struct.pack('>I', o) for o in offsets['a']]))
            atrak = box(b'trak',
                        fullbox(b'tkhd', 0, 3, struct.pack('>IIIII', 0, 0, 2, 0, a_dur_movie), b'\0' * 8,
                                struct.pack('>hhhH', 0, 1, 0x0100, 0), matrix, struct.pack('>II', 0, 0)),
                        box(b'edts', fullbox(b'elst', 0, 0, struct.pack('>IIIhh', 1, a_dur_movie, a_media_start, 1, 0))),
                        box(b'mdia',
                            fullbox(b'mdhd', 0, 0, struct.pack('>IIII', 0, 0, asr, a_total), struct.pack('>HH', 0x55C4, 0)),
                            fullbox(b'hdlr', 0, 0, struct.pack('>I', 0), b'soun', b'\0' * 12, b'SoundHandler\0'),
                            box(b'minf', fullbox(b'smhd', 0, 0, b'\0' * 4), dinf, astbl)))
            traks.append(atrak)
        mvhd = mvhd[:-4] + struct.pack('>I', len(traks) + 1)
        return box(b'moov', mvhd, *traks)

    ftyp = box(b'ftyp', b'isom', struct.pack('>I', 0x200), b'isom', b'iso2', b'avc1', b'mp41')
    # two passes: sizes of moov don't depend on offset values
    dummy = {'v': [0] * sum(1 for t, _ in chunks if t == 'v'), 'a': [0] * sum(1 for t, _ in chunks if t == 'a')}
    moov_len = len(build_moov(dummy))
    mdat_start = len(ftyp) + moov_len + 8
    offsets = {'v': [], 'a': []}; pos = mdat_start; payload = []
    for t, s in chunks:
        offsets[t].append(pos)
        for smp in s:
            b = smp[0] if t == 'v' else smp
            payload.append(b); pos += len(b)
    moov = build_moov(offsets)
    assert len(moov) == moov_len
    mdat_size = pos - mdat_start + 8
    with open(out, 'wb') as f:
        f.write(ftyp); f.write(moov); f.write(struct.pack('>I', mdat_size) + b'mdat')
        for b in payload: f.write(b)
    print(f'wrote {out}: {len(vframes)} video frames ({v_dur_movie/1000:.3f}s), size {pos} bytes')

if __name__ == '__main__':
    main()
