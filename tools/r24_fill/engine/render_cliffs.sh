#!/usr/bin/env bash
# Round 24 B2 cliff renders. Usage:
#   render_cliffs.sh BEFORE_RUN AFTER_RUN NATIVE_DIR OUT_DIR
# BEFORE_RUN/AFTER_RUN hold r24_dump_cliff.tsv (engine runs); NATIVE_DIR holds
# before.tsv/after.tsv from tools/r24_fill/native_cliff.lua.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../../.." && pwd -P)"
before="$1"; after="$2"; native="$3"; out="$4"
mkdir -p "$out"
tiles="$out/.node_tiles.json"
python3 "$repo/tools/wp13/extract_tiles.py" --out "$tiles.base" >/dev/null
python3 "$here/add_tiles.py" "$tiles.base" "$tiles"
r() { python3 "$repo/tools/wp13/render_blueprint.py" "$@" --tiles "$tiles" --quiet; }
r "$before/r24_dump_cliff.tsv" -o "$out/b2-fill-cliff-before.png" --view ne --scale 8
r "$after/r24_dump_cliff.tsv" -o "$out/b2-fill-cliff-after.png" --view ne --scale 8
r "$native/before.tsv" -o "$out/b2-native-cliff-before.png" --view ne --scale 8
r "$native/after.tsv" -o "$out/b2-native-cliff-after.png" --view ne --scale 8
rm -f "$tiles" "$tiles.base"
