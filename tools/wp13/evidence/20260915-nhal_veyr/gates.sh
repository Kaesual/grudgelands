#!/usr/bin/env bash
# Lane R's own gate acceptance over ALL NINE fixture seeds.
#
#     gates.sh <out-dir>
#
# `tools/wp13/route_gates.lua --strict` is the coordinator's acceptance for a
# capital's gates (2026-09-16): it builds each capital's four avenues out of the
# real WP40 height session and through THAT CAPITAL'S OWN overlay dispatch, then
# asks whether the route's graded surface and the built road meet within a node
# at the gate point, whether the walk in from 64 nodes outside the envelope ever
# breaks, and whether the ground just inside the gate is still ground.
#
# Target: `route_faults=0 city_faults=0` on every seed. Anything else is a
# capital's own defect and this is where it shows.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
out="${1:?usage: gates.sh OUT_DIR}"
mkdir -p "$out"
status=0
for seed in 531802985935182545 8675309 15912857179583385436 0 1 2 42 12345 \
		999999999; do
	printf '=== seed %s\n' "$seed"
	nice -n 19 luajit tools/wp13/route_gates.lua . "$seed" \
		"$out/gates-$seed.tsv" --strict >"$out/gates-$seed.txt" 2>&1 || status=1
	tail -1 "$out/gates-$seed.txt"
	grep '^FAULT' "$out/gates-$seed.txt" || true
done
printf '=== every gate row of every capital, nine seeds\n'
grep -h '^gate\|^entry\|^inside\|^overlay' "$out"/gates-*.txt >"$out/gate-rows.tsv"
wc -l <"$out/gate-rows.tsv"
exit "$status"
