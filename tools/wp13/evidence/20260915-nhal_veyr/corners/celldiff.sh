#!/usr/bin/env bash
# Did `wall.lua` section 1b move anything but a corner?
#
#     celldiff.sh <before-tree> <after-tree> <out-dir> [key...]
#
# `<before-tree>` is an export of the commit the fix landed on top of:
#
#     mkdir -p /tmp/wall-before
#     git archive f5583e13 | tar -x -C /tmp/wall-before
#     cp -a tools/bin /tmp/wall-before/tools/
#
# For each capital and each of the two gate seeds it builds ALL FOUR wall runs
# WHOLE -- not per mapchunk -- out of the real WP40 height session, in both
# trees, and diffs the two cell lists. `classify.py` then says, for every changed
# cell, whether its column lies inside the look-around window of a corner column
# of its own run's axis. The constraint the corner commit was given is that the
# answer is "all of them", and that is what these two scripts check.
#
# `corners.py` reads the corner step itself off the same dumps: the highest solid
# cell of the centre lane with air above it, at the z-run's own corner column and
# at the x-run's end four columns earlier -- the same reading
# `tools/wp13/capital_wall.lua` section 5 and `nhal_veyr_kat.lua` rule (f) take.
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
before="${1:?usage: celldiff.sh BEFORE_TREE AFTER_TREE OUT_DIR [key...]}"
after="${2:?usage: celldiff.sh BEFORE_TREE AFTER_TREE OUT_DIR [key...]}"
out="${3:?usage: celldiff.sh BEFORE_TREE AFTER_TREE OUT_DIR [key...]}"
shift 3
keys=("$@")
[[ ${#keys[@]} -gt 0 ]] || keys=(highcourt dur_brannoc)
mkdir -p "$out"
for key in "${keys[@]}"; do
	for seed in 531802985935182545 8675309; do
		if [[ -f "$before/mods/MAPGEN/grug_mapgen/wp13/$key.lua" ]]; then
			nice -n 19 luajit "$here/wall_cells.lua" "$before" "$seed" "$key" \
				"$out/before-$key-$seed.tsv"
		else
			echo "$key does not exist in the before tree; after only"
		fi
		nice -n 19 luajit "$here/wall_cells.lua" "$after" "$seed" "$key" \
			"$out/after-$key-$seed.tsv"
		a="$out/before-$key-$seed.tsv"
		b="$out/after-$key-$seed.tsv"
		[[ -f "$a" ]] || continue
		n=$(diff <(tail -n +2 "$a") <(tail -n +2 "$b") | grep -c '^[<>]' || true)
		printf '%s %s changed_cell_lines=%s\n' "$key" "$seed" "$n"
		diff "$a" "$b" >"$out/diff-$key-$seed.txt" || true
	done
done
echo "== the classification: every changed cell, by column"
python3 "$here/classify.py" "$out"
echo
echo "== the corner step, read off the same dumps"
python3 "$here/corners.py" "$out" | sort
