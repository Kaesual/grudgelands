#!/usr/bin/env bash
# The measurement: every place a capital street meets a WP40 route on the two
# gate seeds, before this lane and after it, plus the parity check that says
# what did NOT move.
#
# Usage: measure.sh [<a checkout of the base commit>]
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
here="$repo/tools/wp13/evidence/20260915-lane-routes"
base="${1:-}"
cd "$repo"
out="$here/crossings"
rm -rf "$out"
mkdir -p "$out"

for seed in 531802985935182545 8675309; do
	echo "== seed $seed, the road before this lane =="
	luajit tools/wp13/lane_routes.lua "$repo" "$seed" --legacy \
		"$out/before-$seed.tsv" || echo "  (exit non-zero: illegal columns, which" \
		"is the defect this lane fixes)"
	echo "== seed $seed, the road with the crossing rule =="
	luajit tools/wp13/lane_routes.lua "$repo" "$seed" "$out/after-$seed.tsv"
done

if [[ -n "$base" && -d "$base" ]]; then
	echo
	for seed in 531802985935182545 8675309; do
		echo "== seed $seed, against the base commit's road =="
		luajit "$here/parity.lua" "$repo" "$base" "$seed"
	done
fi
