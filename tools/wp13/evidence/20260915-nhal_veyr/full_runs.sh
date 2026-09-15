#!/usr/bin/env bash
# The full engine pass of Nhal Veyr: one cold world per seed, the capital's own
# mapchunks emerged one at a time and timed, the NPC roster placed and
# inventoried, and the built core, a plot, an avenue, a stretch of curtain and
# a gatehouse dumped back out of the finished map for the renderer.
set -uo pipefail
export LC_ALL=C
repo="${1:?usage: full_runs.sh REPO OUTROOT SEED...}"
out="${2:?usage: full_runs.sh REPO OUTROOT SEED...}"
shift 2
mkdir -p "$out"
port=31330
for seed in "$@"; do
	dir="$out/full-$seed"
	rm -rf "$dir"
	printf '=== seed %s (port %s) started %s\n' "$seed" "$port" "$(date +%T)"
	WP13_CAPITAL_PORT="$port" WP13_CAPITAL_TIMEOUT=1700 \
		nice -n 19 "$repo/tools/wp13/run_capital.sh" "$dir" nhal_veyr full \
		"$seed" 2>&1 | tail -6
	printf '=== seed %s finished %s\n' "$seed" "$(date +%T)"
	port=$((port + 1))
done
printf '=== done\n'
