#!/usr/bin/env bash
# The surface pass of Nhal Veyr on all nine seeds of the capital anchor
# fixture, one headless server at a time, each under nice -n 19.
#
# `surface` mode builds every blueprint of the capital in the engine's own
# LuaJIT, runs the seam's load-time `audit_terrain` over all 52 plots, and
# samples the real final height under each plot's footprint, perimeter and
# two-node margin -- which is the per-plot half of the lot-legality rule and
# the only place it is measured against the world rather than against a grid.
set -uo pipefail
export LC_ALL=C
repo="${1:?usage: surface_all.sh REPO OUTROOT}"
out="${2:?usage: surface_all.sh REPO OUTROOT}"
mkdir -p "$out"
seeds="531802985935182545 8675309 15912857179583385436 0 1 2 42 12345 999999999"
port=31310
for seed in $seeds; do
	dir="$out/surface-$seed"
	rm -rf "$dir"
	printf '=== seed %s (port %s)\n' "$seed" "$port"
	WP13_CAPITAL_PORT="$port" WP13_CAPITAL_TIMEOUT=1500 \
		nice -n 19 "$repo/tools/wp13/run_capital.sh" "$dir" nhal_veyr surface \
		"$seed" 2>&1 | tail -2
	port=$((port + 1))
done
printf '=== done\n'
