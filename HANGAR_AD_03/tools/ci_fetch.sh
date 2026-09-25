#!/usr/bin/env bash
# CI only: download Pexels candidates from config/assets.json, probe them and
# build a contact sheet per clip into review/ for visual verification.
set -uo pipefail
cd "$(dirname "$0")/.."
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"
DL=dl; OUT=review; mkdir -p "$DL" "$OUT"
[ -f "$OUT/report.tsv" ] || printf 'id\tslots\tstatus\twidth\theight\tfps\tduration\tcodec\tfile_url\tpage\n' > "$OUT/report.tsv"

# unique candidate pages -> slots
node -e '
const a=require("./config/assets.json"); const m={};
for (const [slot,e] of Object.entries(a.video)) for (const c of e.candidates||[]) { (m[c.url]=m[c.url]||[]).push(slot); }
for (const [u,s] of Object.entries(m)) console.log(u+" "+s.join(","));
' > "$DL/list.txt"

while read -r page slots <&3; do
  id=$(echo "$page" | grep -oE '[0-9]+/?$' | tr -d /)
  [ -f "$OUT/${id}_sheet.jpg" ] && continue
  f="$DL/$id.mp4"; status=ok; furl=""
  html=$(curl -sSL -m 30 -A "$UA" -H 'Accept-Language: en-US,en' "$page" || true)
  # best rendition by pixel count, from links embedded in the page
  furl=$(echo "$html" | grep -oE 'https://videos\.pexels\.com/video-files/[0-9]+/[A-Za-z0-9_.-]+\.mp4' | sort -u | \
    awk -F'[_x]' '{ best=0; for(i=1;i<=NF;i++) if ($i ~ /^[0-9][0-9][0-9][0-9]?$/ && $(i+1) ~ /^[0-9][0-9][0-9][0-9]?$/) { p=$i*$(i+1); if(p>best) best=p } print best, $0 }' | \
    sort -nr | head -1 | cut -d' ' -f2)
  if [ -n "$furl" ]; then curl -sSL -m 180 -A "$UA" -o "$f" "$furl" || status=dl_fail
  else curl -sSL -m 180 -A "$UA" -o "$f" "https://www.pexels.com/download/video/$id/" || status=dl_fail; furl="download/video/$id"; fi
  if ! ffprobe -v error "$f" >/dev/null 2>&1; then
    status="not_video(page_bytes=${#html})"; rm -f "$f"
    printf '%s\t%s\t%s\t\t\t\t\t\t%s\t%s\n' "$id" "$slots" "$status" "$furl" "$page" >> "$OUT/report.tsv"; continue
  fi
  read -r w h fr codec <<<"$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,codec_name -of csv=p=0 "$f" | awk -F, '{print $2,$3,$4,$1}')"
  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
  # 12 evenly spaced frames, 4x3 grid, with timestamps
  n=12; step=$(awk -v d="$dur" -v n=$n 'BEGIN{printf "%.3f", d/n}')
  ffmpeg -nostdin -v error -y -i "$f" -vf "fps=1/$step,scale=480:-2,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='%{pts\:hms}':x=8:y=8:fontsize=20:fontcolor=white:box=1:boxcolor=black@0.6,tile=4x3:padding=4:color=black" -frames:v 1 -q:v 4 "$OUT/${id}_sheet.jpg" || status=sheet_fail
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$slots" "$status" "$w" "$h" "$fr" "$dur" "$codec" "$furl" "$page" >> "$OUT/report.tsv"
done 3< "$DL/list.txt"
cat "$OUT/report.tsv"
