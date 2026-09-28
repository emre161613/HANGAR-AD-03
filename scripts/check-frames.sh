#!/usr/bin/env bash
# Kullanım: bash scripts/check-frames.sh renders/<ad>.mp4
# Videodan eşit aralıklı 12 kare çıkarır (kare 01 = t=0).
set -euo pipefail
video="${1:?Kullanım: $0 <video.mp4>}"
n=12
out="${video%.mp4}_frames"
rm -rf "$out" && mkdir -p "$out"

dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$video")
for i in $(seq 0 $((n - 1))); do
  # Son kare videonun bitişinden az önce alınır
  t=$(python3 -c "print(round(($dur - 0.05) * $i / ($n - 1), 3))")
  ffmpeg -v error -y -ss "$t" -i "$video" -frames:v 1 \
    "$out/frame_$(printf %02d $((i + 1)))_t${t}s.png"
done

echo "$n kare -> $out/"
ls -1 "$out"
