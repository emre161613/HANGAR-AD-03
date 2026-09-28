#!/usr/bin/env bash
# Stüdyo kurulumu: HyperFrames (npm) + ffmpeg. Tekrar çalıştırmak güvenlidir.
set -u
cd "$(dirname "$0")/.."

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "[setup] ffmpeg kuruluyor..."
  (apt-get update -qq && apt-get install -y -qq ffmpeg) >/dev/null 2>&1 \
    || echo "[setup] UYARI: ffmpeg kurulamadı (ağ erişimi?)"
fi

if [ ! -d node_modules/hyperframes ]; then
  echo "[setup] HyperFrames kuruluyor..."
  npm install --no-audit --no-fund >/dev/null 2>&1 \
    || echo "[setup] UYARI: HyperFrames kurulamadı (registry.npmjs.org erişimi?)"
fi

command -v ffmpeg >/dev/null 2>&1 && echo "[setup] ffmpeg: OK"
[ -d node_modules/hyperframes ] && echo "[setup] hyperframes: OK"
exit 0
