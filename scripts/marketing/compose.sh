#!/usr/bin/env bash
# Compose an App Store marketing image: headline + subhead on a soft gradient,
# with the raw screenshot in a rounded, shadowed frame bleeding off the bottom.
#
#   compose.sh <screenshot.png> <out.png> "<headline>" "<subhead>" [gradient "#c1 #c2"]
#
# Output keeps the screenshot's pixel size (1320x2868 iPhone 6.9", 2064x2752
# iPad 13"), which is what App Store Connect expects. Requires ImageMagick 7.
set -euo pipefail
IN=$1 OUT=$2 HEAD=$3 SUB=$4 GRAD=${5:-"#FFF4EC #F6B99F"}
W=$(magick identify -format "%w" "$IN"); H=$(magick identify -format "%h" "$IN")
FONT_BOLD="/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_REG="/System/Library/Fonts/Supplemental/Arial.ttf"
[ -f "/System/Library/Fonts/Avenir Next.ttc" ] && FONT_BOLD="/System/Library/Fonts/Avenir Next.ttc"  # the TTC resolves to the bold face
read -r C1 C2 <<<"$GRAD"
# Scale type and geometry off the width so iPhone and iPad share one look.
HEADPT=$(( W * 7 / 100 ))      # ~92px on 1320, ~144px on 2064
SUBPT=$(( W * 32 / 1000 ))     # ~42px / ~66px
TOPPAD=$(( H * 7 / 100 ))
SHOTW=$(( W * 84 / 100 ))
RADIUS=$(( W * 7 / 100 ))
SHOTY=$(( H * 25 / 100 ))     # frame top; the bottom runs off the canvas
TMP=$(mktemp -d)
# Rounded, shadowed screenshot.
magick "$IN" -resize "${SHOTW}x" \
  \( +clone -alpha extract -draw "fill black polygon 0,0 0,$RADIUS $RADIUS,0 fill white circle $RADIUS,$RADIUS $RADIUS,0" \
     \( +clone -flip \) -compose Multiply -composite \( +clone -flop \) -compose Multiply -composite \) \
  -alpha off -compose CopyOpacity -composite "$TMP/shot.png"
magick "$TMP/shot.png" \( +clone -background black -shadow "55x${RADIUS}+0+$(( RADIUS / 3 ))" \) +swap -background none -layers merge +repage "$TMP/shadow.png"
# Background + text.
magick -size "${W}x${H}" "gradient:${C1}-${C2}" -rotate 180 \
  \( -size "${W}x${H}" xc:none -fill "rgba(255,255,255,0.30)" -draw "circle $(( W * 85 / 100 )),$(( H * 12 / 100 )) $(( W * 85 / 100 )),$(( H * 12 / 100 + W * 55 / 100 ))" -blur 0x$(( W / 8 )) \) -composite \
  -gravity north -font "$FONT_BOLD" -pointsize "$HEADPT" -fill "#1B1B1F" -interline-spacing $(( -HEADPT / 9 )) \
    -annotate +0+"$TOPPAD" "$HEAD" \
  -font "$FONT_REG" -pointsize "$SUBPT" -fill "#4A4A52" -annotate +0+"$(( TOPPAD + HEADPT * 25 / 10 ))" "$SUB" \
  "$TMP/bg.png"
magick "$TMP/bg.png" "$TMP/shadow.png" -gravity north -geometry +0+"$SHOTY" -composite -crop "${W}x${H}+0+0" +repage "$OUT"
rm -rf "$TMP"
echo "$OUT ($(magick identify -format '%wx%h' "$OUT"))"
