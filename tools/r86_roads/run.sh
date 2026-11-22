#!/usr/bin/env bash
# Round 86 lane ROADS: the road cut wall census over a seed list
# (tools/r86_roads/census.lua per seed, LuaJIT, about 30 s and 1.5 GB a seed
# for today's rule, about 5 s more per candidate rule).
#   tools/r86_roads/run.sh OUT [SEEDS_FILE]
#     OUT         directory; gets <seed>.txt per seed (census.lua's lines)
#     SEEDS_FILE  one seed per line, # comments (default tools/seed_fleet/seeds.txt)
#   JOBS=<n> parallel seeds (default 6); R86_ROADS_RULES and R86_ROADS_PROFILE
#   pass through to census.lua. Run it through the shared Lua queue with
#   JOBS slots. Then tools/r86_roads/summary.py OUT.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
out="${1:?usage: run.sh OUT [SEEDS_FILE]}"
seeds="${2:-$repo/tools/seed_fleet/seeds.txt}"
mkdir -p "$out"
export repo out
started=$SECONDS
grep -v '^#' "$seeds" | grep . | xargs -P "${JOBS:-6}" -I{} sh -c \
	'luajit "$repo/tools/r86_roads/census.lua" "$repo" "$1" >"$out/$1.txt" 2>&1 || echo "FAIL $1"' _ {}
echo "census: $(ls "$out" | wc -l) seeds in $(( (SECONDS - started) / 60 )) min $(( (SECONDS - started) % 60 )) s"
