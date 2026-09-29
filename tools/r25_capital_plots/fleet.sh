#!/bin/bash
# Round 25 Lane H: run harness.lua over a seed list in N idle-priority LuaJIT
# workers (round-robin split), then merge in seed-list order.
#
#   tools/r25_capital_plots/fleet.sh <repo> <seeds.txt> <out.tsv> [workers=4]
#
# About 14 s CPU and 0.5 GB per seed per worker.
set -eu
repo=$1 seeds=$2 out=$3 workers=${4:-4}
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/r25-capital-plots.XXXXXX")
mapfile -t all < <(grep -v '^\s*$' "$seeds")
for ((w = 0; w < workers; w++)); do
	part=()
	for ((i = w; i < ${#all[@]}; i += workers)); do part+=("${all[i]}"); done
	[ ${#part[@]} -gt 0 ] || continue
	chrt --idle 0 ionice -c3 luajit "$here/harness.lua" "$repo" "$tmp/$w.tsv" "${part[@]}" \
		2> "$tmp/$w.err" &
done
wait
: > "$out"
for s in "${all[@]}"; do
	grep -ah "^$s	" "$tmp"/*.tsv >> "$out" || echo "$s	MISSING" >> "$out"
done
cat "$tmp"/*.err > "${out%.tsv}.err"
rm -rf "$tmp"
