#!/usr/bin/env bash
# Render the dumps of one run (r24_dump_section.tsv, r24_dump_cliff.tsv) with
# the repository's isometric renderer. Usage: render.sh RUN_DIR NAME OUT_DIR
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../../.." && pwd -P)"
run="$1"; name="$2"; out="$3"
mkdir -p "$out"
tiles="$out/.node_tiles.json"
python3 "$repo/tools/wp13/extract_tiles.py" --out "$tiles.base" >/dev/null
python3 "$here/add_tiles.py" "$tiles.base" "$tiles"
r() { python3 "$repo/tools/wp13/render_blueprint.py" "$@" --tiles "$tiles" --quiet; }
r "$run/r24_dump_section.tsv" -o "$out/mountain-section-$name.png" --view sw --scale 5
r "$run/r24_dump_cliff.tsv" -o "$out/fill-cliff-$name.png" --view ne --scale 8
python3 "$here/tunnel.py" "$run/r24_dump_section.tsv" "$out/.tunnel.tsv"
r "$out/.tunnel.tsv" -o "$out/mountain-tunnel-$name.png" --view sw --scale 12
rm -f "$out/.tunnel.tsv" "$tiles" "$tiles.base"
