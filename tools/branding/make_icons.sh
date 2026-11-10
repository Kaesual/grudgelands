#!/usr/bin/env bash
# Export the approved transparent master; no generation or background removal.
# Usage: make_icons.sh <source.png> <outdir>
# Requires ImageMagick 7.
set -euo pipefail
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <source.png> <outdir>" >&2
  exit 2
fi
source_image="$1"
output_dir="$2"
command -v magick >/dev/null || { echo "ImageMagick 7 is required" >&2; exit 2; }
[[ "$(magick "$source_image" -format '%[opaque]' info:)" == "False" ]] || {
  echo "The master must have a transparent background" >&2
  exit 2
}
mkdir -p "$output_dir"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
magick "$source_image" -trim +repage "$scratch/cut.png"
for size in 16 32 48 64 96 128 256 512 1024; do
  extent=$((size * 90 / 100))
  magick "$scratch/cut.png" -filter Lanczos -resize "${extent}x${extent}" \
    -background none -gravity center -extent "${size}x${size}" \
    -strip -define png:color-type=6 -define png:exclude-chunks=date,time \
    "$output_dir/plain_${size}.png"
done
# 75% height leaves room for circular profile-picture crops.
for size in 512 1024; do
  extent=$((size * 75 / 100))
  magick "$scratch/cut.png" -filter Lanczos -resize "${extent}x${extent}" \
    -background '#181b20' -gravity center -extent "${size}x${size}" \
    -alpha remove -alpha off -strip -define png:exclude-chunks=date,time \
    "$output_dir/avatar_${size}.png"
done
magick "$output_dir/plain_16.png" "$output_dir/plain_32.png" \
  "$output_dir/plain_48.png" "$output_dir/favicon.ico"
