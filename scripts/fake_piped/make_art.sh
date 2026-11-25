#!/usr/bin/env bash
# Artwork for the demo catalogue: 12 thumbnails (16:9), 8 channel avatars and a
# banner — soft two-tone gradients with a blurred highlight, no text, no logos.
# Requires ImageMagick (`magick`). Output is committed; rerun only to restyle.
set -euo pipefail
cd "$(dirname "$0")/media"
rm -rf art && mkdir art
# Warm/cool pairs that sit well next to the app's coral icon.
PAIRS=(
  "#F97362 #FBD38D" "#2F3E46 #84A98C" "#1D3557 #A8DADC" "#6D597A #E56B6F"
  "#355070 #EAAC8B" "#3A5A40 #DAD7CD" "#8E9AAF #FEEAFA" "#B56576 #F2CC8F"
  "#22333B #C6AC8F" "#0B3954 #BFD7EA" "#5F0F40 #FB8B24" "#386641 #F2E8CF"
)
art() {  # out w h "c1 c2" angle
  local out=$1 w=$2 h=$3 c1 c2; read -r c1 c2 <<<"$4"
  magick -size "${w}x${h}" "gradient:${c1}-${c2}" -rotate "$5" -gravity center -extent "${w}x${h}" \
    \( -size "${w}x${h}" xc:none -fill "rgba(255,255,255,0.35)" -draw "circle $((w*7/10)),$((h*3/10)) $((w*7/10)),$((h*3/10+h*45/100))" -blur 0x"$((h/9))" \) -composite \
    \( -size "${w}x${h}" xc:none -fill "rgba(0,0,0,0.18)" -draw "circle $((w*2/10)),$((h*8/10)) $((w*2/10)),$((h*8/10+h*40/100))" -blur 0x"$((h/8))" \) -composite \
    -attenuate 0.15 +noise Gaussian -quality 82 "$out"
}
for i in $(seq 0 11); do art "art/thumb-$(printf %02d "$i").jpg" 640 360 "${PAIRS[$i]}" $(( (i*37) % 180 - 90 )); done
for i in $(seq 0 7);  do art "art/avatar-$(printf %02d "$i").jpg" 240 240 "${PAIRS[$(( (i*5+3) % 12 ))]}" $(( (i*53) % 180 - 90 )); done
art art/banner.jpg 1280 360 "${PAIRS[4]}" -8
du -sh art
