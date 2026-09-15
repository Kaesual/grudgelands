#!/usr/bin/env bash
# The terrain pass of Nhal Veyr on all nine seeds of the capital anchor
# fixture, one headless server at a time, each under nice -n 19.
#
# `terrain` mode measures the ground BEFORE a composition is designed against
# it: the four candidate curtain-wall lines column by column across the wall's
# own thickness, and a 4-node grid of the whole 512 envelope and its collar.
# It is the input of `tools/wp13/nhal_veyr_plots.lua` and of
# `tools/wp13/capital_wall.lua`.
#
# NINE seeds and not two, from the wave-2 coordinator's review round: a lot
# grid derived against two worlds is a lot grid nobody has asked a third about.
set -uo pipefail
export LC_ALL=C
repo="${1:?usage: terrain_all.sh REPO OUTROOT}"
out="${2:?usage: terrain_all.sh REPO OUTROOT}"
mkdir -p "$out"
seeds="531802985935182545 8675309 15912857179583385436 0 1 2 42 12345 999999999"
port=31320
for seed in $seeds; do
	dir="$out/terrain-$seed"
	rm -rf "$dir"
	printf '=== seed %s (port %s) %s\n' "$seed" "$port" "$(date +%T)"
	WP13_CAPITAL_PORT="$port" WP13_CAPITAL_RACE=undead WP13_CAPITAL_TIMEOUT=900 \
		nice -n 19 "$repo/tools/wp13/run_capital.sh" "$dir" nhal_veyr terrain \
		"$seed" 2>&1 | tail -2
	port=$((port + 1))
done
printf '=== done\n'
