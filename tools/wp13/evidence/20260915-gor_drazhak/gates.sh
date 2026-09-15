#!/usr/bin/env bash
# LANE R'S ROUTE-GATE ACCEPTANCE, --strict, on the nine fixture seeds.
#
# `tools/wp13/route_gates.lua`'s questions 1-3 are the route graph's and its
# questions 4-7 are a CAPITAL's terrain and blueprint; `--strict` puts the
# second group into the exit status, and a capital lane runs it as its own
# acceptance check (that lane's note, "EXIT STATUS").
#
# THE EXIT STATUS IS THE WHOLE WORLD'S, not one capital's, so this script
# reports the per-seed totals AND the count that belongs to Gor Drazhak, and it
# is the second number this script's own exit status follows. Target for this
# lane: zero Gor Drazhak faults on all nine. Every fault the sweep reports today
# is Nhal Veyr's north gate, which Lane R's own note names as the
# capital-fitting case; `gates/gates-<seed>.txt` holds each full report, rows
# and all.
#
# Each seed is one eight-second WP40 construction; no engine, no world.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260915-gor_drazhak"
out="${1:-$here/gates}"
mkdir -p "$out"

seeds=(531802985935182545 8675309 15912857179583385436 0 1 2 42 12345 999999999)
mine=0
for seed in "${seeds[@]}"; do
	nice -n 19 luajit tools/wp13/route_gates.lua "$repo" "$seed" --strict \
		>"$out/gates-$seed.txt" 2>&1 || true
	world="$(grep -o 'route_faults=[0-9]* city_faults=[0-9]*' \
		"$out/gates-$seed.txt" | tail -1)"
	ours="$(grep -c '^FAULT.*gor_drazhak' "$out/gates-$seed.txt" || true)"
	mine=$((mine + ours))
	printf '%-22s %s  gor_drazhak_faults=%s\n' "$seed" "$world" "$ours"
done

echo
echo "== the raw ground step inside Gor Drazhak's own gates, nine seeds =="
echo "   (Lane R note section 3.1 hands the first ten columns to the capital)"
grep -h '^inside' "$out"/gates-*.txt | grep gor_drazhak |
	awk '{ if ($6 + 0 > worst[$4]) worst[$4] = $6 + 0 }
	     END { for (side in worst) printf "   %-6s worst step %d\n", side,
	           worst[side] }' | sort

echo
printf 'gor_drazhak route-gate faults over nine seeds: %s\n' "$mine"
[[ "$mine" -eq 0 ]]
