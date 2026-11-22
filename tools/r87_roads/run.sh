#!/usr/bin/env bash
# Round 87 ROADS: the two-candidate routing study over a few seeds
# (tools/r87_roads/run.lua, LuaJIT; with R87_FULL=1, the default, about
# 3 GB a seed while both worlds are held). Run it through the shared Lua queue
# with JOBS slots.
#   tools/r87_roads/run.sh OUT BEFORE [SEED ...]
#     OUT     directory; gets <seed>/ (run.lua study's files, run.txt)
#     BEFORE  an older checkout (a directory: run.lua before builds its map
#             of each seed into <seed>/before-reference.txt first), or one file for its matching
#             seed (an occupied claim snapshot or a historical road reference)
#     SEED    default: the production seed and the usual test seed 12345
#   JOBS=<n> parallel seeds (default 1); R87_WEIGHTS, R87_FEE and R87_FULL
#   pass through to run.lua.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
out="${1:?usage: run.sh OUT BEFORE [SEED ...]}"
before="${2:?usage: run.sh OUT BEFORE [SEED ...]}"
shift 2
seeds=("$@")
[[ ${#seeds[@]} -gt 0 ]] || seeds=(3684797457838814663 12345)
mkdir -p "$out"
export repo out before
one() {
	local seed="$1" dir="$out/$1" ref="$before" mode=study
	mkdir -p "$dir"
	if [[ -d "$before" ]]; then
		ref="$dir/before-reference.txt"
		luajit "$repo/tools/r87_roads/run.lua" before "$repo" "$before" "$seed" "$ref" >"$dir/before.txt" 2>&1 ||
			{ echo "FAIL $seed (before)"; return 1; }
	fi
	if [[ $(head -n 1 "$ref") == grug_claim_chunks_v1 ]]; then mode=claims; fi
	luajit "$repo/tools/r87_roads/run.lua" "$mode" "$repo" "$seed" "$ref" "$dir" >"$dir/run.txt" 2>&1 ||
		{ echo "FAIL $seed"; return 1; }
}
export -f one
started=$SECONDS
printf '%s\n' "${seeds[@]}" | xargs -P "${JOBS:-1}" -I{} bash -c 'one "$1"' _ {}
echo "r87 roads: ${#seeds[@]} seeds in $(( (SECONDS - started) / 60 )) min $(( (SECONDS - started) % 60 )) s"
