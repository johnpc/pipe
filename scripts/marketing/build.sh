#!/usr/bin/env bash
# Build the App Store screenshot set from raw simulator captures.
#   build.sh <captures-dir> <out-dir>
# <captures-dir>/{iphone,ipad}/NN-name.png (from the screenshot walkthrough)
# → <out-dir>/{iphone,ipad}/NN-name.png composed with a headline per screen.
set -euo pipefail
IN=$1 OUT=$2
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# screen prefix | headline | subhead | gradient
SPEC=$(cat <<'TXT'
02-feed|Your channels,\naudio first|Follow what you love. Listen in the background.|#FFF4EC #F6B99F
03-feed-playing|Live now,\nup next, in one feed|Streams on air, premieres to come, new uploads.|#EEF4F2 #9FC5B8
04-player|A player built\nfor listening|Speed, skip, chapters, queue — without the video.|#F3EEFA #C9B6E4
05-chapters|Jump straight\nto a chapter|Tap a chapter to seek. The current one stays lit.|#FFF1E6 #F3C19A
06-detail|Read along,\nno play required|Description, chapters and comments on their own page.|#EAF2FB #A9C8EA
01-search|Search any\nchannel or video|Then play it, queue it, cast it, or save it offline.|#F1F5EE #B8D3A8
TXT
)
for device in iphone ipad; do
  mkdir -p "$OUT/$device"
  n=1
  while IFS='|' read -r prefix head sub grad; do
    src=$(ls "$IN/$device/$prefix"*.png 2>/dev/null | head -1)
    [ -n "$src" ] || { echo "missing $device/$prefix" >&2; continue; }
    bash "$HERE/compose.sh" "$src" "$OUT/$device/$(printf %02d "$n")-${prefix#*-}.png" "$head" "$sub" "$grad"
    n=$((n+1))
  done <<<"$SPEC"
done
