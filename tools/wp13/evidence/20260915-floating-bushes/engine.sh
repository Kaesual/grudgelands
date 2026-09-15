#!/usr/bin/env bash
# The engine census of WP13 playtest round 3 lane 2: four runs of
# `tools/wp13/run_bush_probe.sh`, radius 190 around all six starts, on both gate
# seeds -- two against a PRISTINE `main` tree (the baseline, expected non-zero)
# and two against this tree (expected zero).
#
# The baseline pair needs a tree with `main`'s own
# `mods/MAPGEN/grug_mapgen/wp40/r6_templates.lua`; this script builds one in the
# output directory from `git show <base>:...`, so the two halves differ in
# exactly that one file and in nothing else, the probe included.
#
# Ports 31130/31140/31150/31160 are this lane's block. All four run in parallel;
# the wall time of the recorded run was about twelve minutes.
#
# Usage: engine.sh OUTPUT_DIR [BASE_COMMIT]
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="${1:?usage: engine.sh OUTPUT_DIR [BASE_COMMIT]}"
base="${2:-19abee02}"
[[ "$out" = /* && ! -e "$out" ]] || {
	echo "engine.sh: OUTPUT_DIR must be an absent absolute path" >&2
	exit 2
}
mkdir -p "$out"

pristine="$out/pristine"
mkdir -p "$pristine"
cp -a "$repo/mods" "$repo/tools" "$repo/game.conf" "$repo/minetest.conf" \
	"$repo/settingtypes.txt" "$pristine/"
git -C "$repo" show \
	"$base:mods/MAPGEN/grug_mapgen/wp40/r6_templates.lua" \
	>"$pristine/mods/MAPGEN/grug_mapgen/wp40/r6_templates.lua"
diff -rq "$repo/tools/wp13/bush_probe" "$pristine/tools/wp13/bush_probe"
echo "pristine tree: only r6_templates.lua differs from this one"
diff -q "$repo/mods/MAPGEN/grug_mapgen/wp40/r6_templates.lua" \
	"$pristine/mods/MAPGEN/grug_mapgen/wp40/r6_templates.lua" && {
	echo "engine.sh: the pristine copy is identical -- wrong base commit?" >&2
	exit 1
}

run() {
	local tree="$1" dir="$2" seed="$3" port="$4" baseline="$5"
	BASELINE="$baseline" PORT="$port" \
		"$tree/tools/wp13/run_bush_probe.sh" "$out/$dir" "$seed" 190 \
		1,2,3,4,5,6 2400 >"$out/$dir.log" 2>&1
}

run "$pristine" base-user 531802985935182545 31130 1 &
pids=$!
run "$pristine" base-boundary 8675309 31140 1 &
pids="$pids $!"
run "$repo" fix-user 531802985935182545 31150 0 &
pids="$pids $!"
run "$repo" fix-boundary 8675309 31160 0 &
pids="$pids $!"
status=0
for pid in $pids; do wait "$pid" || status=1; done

for dir in base-user base-boundary fix-user fix-boundary; do
	printf '== %s\n' "$dir"
	cat "$out/$dir.log"
	grep -h 'event=census' "$out/$dir/probe.txt" |
		sed 's/.*start=/start=/;s/ canopy=[^ ]*//;s/ samples=.*//' \
		>"$out/$dir.tsv"
done
printf 'baseline totals: user %s boundary %s\n' \
	"$(sed -n 's/.*floating_total=\([0-9]*\).*/\1/p' "$out/base-user.log")" \
	"$(sed -n 's/.*floating_total=\([0-9]*\).*/\1/p' "$out/base-boundary.log")"
printf 'this lane:       user %s boundary %s\n' \
	"$(sed -n 's/.*floating_total=\([0-9]*\).*/\1/p' "$out/fix-user.log")" \
	"$(sed -n 's/.*floating_total=\([0-9]*\).*/\1/p' "$out/fix-boundary.log")"
pgrep -af 'luanti.bin --server' | grep -F "$out" && {
	echo "engine.sh: a server of this run is still alive" >&2
	exit 1
}
echo "no server of this run remains"
exit "$status"
