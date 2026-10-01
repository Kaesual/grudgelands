#!/usr/bin/env bash
# Round 28 Lane C0: rebuild the zone facts atlas (docs/planning/round28/zones).
#
#   tools/r28_zone_atlas/run.sh [OUT_DIR]
#
# 1. sample.lua (LuaJIT, no engine): the analytic world of the seed on a
#    4-node grid, in 4 parallel bands (each builds the world once, ~17 s CPU).
# 2. probe.sh (one headless engine boot, no world emerged): sockets, quest
#    givers, quests, mob casts and spawn levels, camps, rares, settlement boxes.
# 3. build_atlas.py (numpy + Pillow): index.md, <zone>.md/.json, maps/*.png.
# SEED (default 42, the project's evidence seed) and WORK (scratch directory
# for the grid and the probe output, default a fresh mktemp dir) are optional.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
seed="${SEED:-42}"
out="${1:-$repo/docs/planning/round28/zones}"
work="${WORK:-$(mktemp -d /tmp/r28_zone_atlas.XXXXXX)}"
mkdir -p "$work/grid" "$out"
idle=()
command -v chrt >/dev/null && idle=(chrt --idle 0)
pids=()
for band in 0 1 2 3; do
	"${idle[@]}" luajit "$here/sample.lua" "$repo" "$seed" "$work/grid" 4 "$band" 4 &
	pids+=($!)
done
for pid in "${pids[@]}"; do wait "$pid"; done
SEED="$seed" "$here/probe.sh" "$work/probe"
python3 "$here/build_atlas.py" --grid "$work/grid" --probe "$work/probe/probe.json" --out "$out"
echo "atlas written to $out (work files in $work)"
