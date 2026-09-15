#!/usr/bin/env bash
# THE NINE-SEED SWEEP of the fix round (2026-09-15).
#
# `common.md` and `city-common.md` ask for lot legality and `audit_terrain` on
# ALL NINE fixture seeds; the first version of this package measured three, and
# the review found a blocker and three should-fixes hiding in the other six.
# This is the sweep that closes them.
#
#   1. `gor_drazhak_rampart.lua` over the nine rampart-line dumps: dry, the step
#      no deeper than the race terrace, the faces overlapping, the gates dry,
#      and -- the blocker -- the four corners continuous. It reports the RAW
#      corner step beside the reconciled one, so the fix can be seen to do
#      something.
#   2. `gor_drazhak_lots.lua` over the nine whole-envelope grids: every district
#      lot and every fill lot dry, inside its skirt and under its own roof.
#   3. the engine's own load-time terrain audit, read out of each boot's log.
#
# The nine dumps come from one `run_capital.sh <out> gor_drazhak terrain <seed>`
# each (31 s apiece). They are 700 kB each and are not committed; this script
# takes their directory prefix as an argument and the `nine/` directory beside
# it carries the output.
#
#     nine.sh /tmp/grug-w2-gor-t9b
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
prefix="${1:-/tmp/grug-w2-gor-t9b}"
here="tools/wp13/evidence/20260915-gor_drazhak"
mkdir -p "$here/nine"

seeds=(531802985935182545 8675309 15912857179583385436 0 1 2 42 12345 999999999)
walls=()
grids=()
for seed in "${seeds[@]}"; do
	walls+=("$prefix-$seed/gor_drazhak-wall.tsv")
	grids+=("$prefix-$seed/gor_drazhak-grid.tsv")
done

echo "== the rampart, nine worlds =="
luajit tools/wp13/gor_drazhak_rampart.lua . "${walls[@]}" \
	| tee "$here/nine/rampart-nine-seeds.txt" | tail -3

echo
echo "== the 36 district lots and the 16 fill lots, nine worlds =="
luajit tools/wp13/gor_drazhak_lots.lua . "${grids[@]}" \
	| tee "$here/nine/lots-nine-seeds.txt" | tail -2

echo
echo "== the engine's own load-time terrain audit, nine worlds =="
: >"$here/nine/audit-nine-seeds.txt"
for seed in "${seeds[@]}"; do
	log="$prefix-$seed/server.log"
	count=0
	[[ -f "$log" ]] && count="$(grep -c 'WP13 gor_drazhak: the plot' "$log" || true)"
	printf '%-22s %s finding(s)\n' "$seed" "$count" \
		>>"$here/nine/audit-nine-seeds.txt"
	[[ "$count" -eq 0 ]] || grep -o 'WP13 gor_drazhak: the plot [^.]*' "$log" \
		>>"$here/nine/audit-nine-seeds.txt"
done
cat "$here/nine/audit-nine-seeds.txt"
total="$(awk '{s += $2} END {print s + 0}' "$here/nine/audit-nine-seeds.txt")"
printf 'total audit findings over nine worlds: %s\n' "$total"
[[ "$total" -eq 0 ]]
