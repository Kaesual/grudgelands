#!/bin/bash
# Round 26 Lane W (playtest fix): run gate_gaps.lua over a seed list in N
# idle-priority LuaJIT workers (round-robin split), then merge in seed-list
# order. <repo> is the tree planned and written (main or a branch).
#
#   tools/r26_capitals/gate_fleet.sh <repo> <seeds.txt> <out.tsv> [workers=3]
#
# About 40 s (idle priority, six workers) and 0.5 GB per seed per worker.
set -eu
repo=$1 seeds=$2 out=$3 workers=${4:-3}
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/r26-gate-gaps.XXXXXX")
mapfile -t all < <(grep -v '^\s*$' "$seeds")
for ((w = 0; w < workers; w++)); do
	part=()
	for ((i = w; i < ${#all[@]}; i += workers)); do part+=("${all[i]}"); done
	[ ${#part[@]} -gt 0 ] || continue
	LC_ALL=C chrt --idle 0 ionice -c3 luajit "$here/gate_gaps.lua" "$repo" "$tmp/$w.tsv" "${part[@]}" \
		2> "$tmp/$w.err" &
done
wait
: > "$out"
for s in "${all[@]}"; do
	grep -ah "^$s	" "$tmp"/*.tsv >> "$out" || echo "$s	MISSING" >> "$out"
done
rm -rf "$tmp"
