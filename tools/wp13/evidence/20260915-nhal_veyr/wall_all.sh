#!/usr/bin/env bash
# `tools/wp13/capital_wall.lua` over ALL NINE seeds of the capital anchor
# fixture, pairwise: whether the real ground under the four curtain lines is
# ground the wall's rules were written for, and -- the question the wave-2
# review asked for -- how far the walk steps where an x-run meets a z-run's
# CORNER TURRET.
#
#     wall_all.sh <terrain-out-root> [key]
#
# The predicate takes two worlds at a time, so the nine seeds are walked as
# eight consecutive pairs: every seed is measured, and every pair's corner
# verdict is printed with the seed it belongs to.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
root="${1:?usage: wall_all.sh TERRAIN_OUT_ROOT [key]}"
key="${2:-nhal_veyr}"
seeds=(531802985935182545 8675309 15912857179583385436 0 1 2 42 12345 999999999)
status=0
for index in $(seq 0 $(( ${#seeds[@]} - 2 ))); do
	a="${seeds[$index]}"
	b="${seeds[$(( index + 1 ))]}"
	printf '=== %s: seeds %s (a) and %s (b)\n' "$key" "$a" "$b"
	luajit tools/wp13/capital_wall.lua . "$key" \
		"$root/terrain-$a/$key-wall.tsv" \
		"$root/terrain-$b/$key-wall.tsv" || status=1
done
printf '=== worst corner step over every pair above\n'
exit "$status"
