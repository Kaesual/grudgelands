#!/usr/bin/env bash
# Grudgelands crest: cut the Z-Image render out of its black background and
# export padded square icons. Usage: [MASK=hand_edited_mask.png] make_icons.sh <source.png> <outdir>
# Needs ImageMagick 7 and python3 with numpy + Pillow (hullmask.py next to this script).
# Reference run: MASK=mask_hand.png, derived 2026-09-16 from the GIMP edit of the cutout (cut_hand.png).
# Without MASK the automatic two-tolerance mask is rebuilt; it differs from the reference by a few hundred pixels.
set -euo pipefail
S="$1"; O="$2"; mkdir -p "$O"; here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BG=$(magick "$S" -format '%[pixel:p{2,2}]' info:)
flood() { # fuzz -> binary mask: background flood, close the crack channel, keep the shield component
  magick "$S" -alpha set -bordercolor "$BG" -border 1 -fuzz "$1%" -fill none -draw 'color 0,0 floodfill' -shave 1x1 \
    -alpha extract -threshold 50% -morphology Close Disk:9 \
    -define connected-components:area-threshold=30000 -define connected-components:mean-color=true -connected-components 8 -threshold 50% "$2"
}
gate() { # erode away smoke tendrils, keep the largest body, dilate back, AND with the input
  magick "$1" -morphology Erode Disk:20 \
    -define connected-components:area-threshold=100000 -define connected-components:mean-color=true -connected-components 8 -threshold 50% \
    -morphology Dilate Disk:24 "$O/_gate.png"
  magick "$1" "$O/_gate.png" -compose Darken -composite "$2"
}
if [ -n "${MASK:-}" ]; then cp "$MASK" "$O/mask.png"; else
  # loose tolerance keeps the dark rust at the rim but attaches the smoke; the clean one drops the smoke
  # but notches the rim. Below the widest point the outline is convex, so hullmask.py takes
  # loose AND convexhull(clean) there and clean above it.
  flood 3 "$O/_loose.png"
  flood 7 "$O/_clean_raw.png"; gate "$O/_clean_raw.png" "$O/_clean.png"
  python3 "$here/hullmask.py" "$O/_clean.png" "$O/_loose.png" "$O/_final.png" 300
  magick "$O/_final.png" -morphology Erode Disk:1.5 -blur 0x0.8 "$O/mask.png"
fi
magick "$S" "$O/mask.png" -alpha off -compose CopyOpacity -composite -trim +repage "$O/cut.png"
for s in 512 256 128 96 64 48 32 24; do
  magick "$O/cut.png" -filter Lanczos -resize $((s*90/100))x$((s*90/100)) -background none -gravity center -extent ${s}x${s} "$O/plain_$s.png"
done
for s in 96 64 48 32 24; do
  magick "$O/cut.png" -modulate 100,118,100 -sigmoidal-contrast 3x50% -filter Lanczos -resize $((s*90/100))x$((s*90/100)) -unsharp 0x0.8+0.8+0.02 \
    -background none -gravity center -extent ${s}x${s} "$O/punch_$s.png"
done
rm -f "$O"/_*.png
