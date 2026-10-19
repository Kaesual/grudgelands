#!/usr/bin/env bash
# Round 51 lane NAMES: the water survey (water_survey.lua) for the
# production seed and three fleet seeds, one LuaJIT process per seed (about
# 35 s each). Writes tools/r51_names/survey/seed_<seed>.json; then rerun
# build.py. Start it through the round's Lua queue (4 slots).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
mkdir -p "$here/survey"
pids=()
for seed in 3464175725660475642 42 7 2026; do
	luajit "$here/water_survey.lua" "$repo" "$seed" > "$here/survey/seed_$seed.json" &
	pids+=($!)
done
rc=0
for p in "${pids[@]}"; do wait "$p" || rc=1; done
exit $rc
