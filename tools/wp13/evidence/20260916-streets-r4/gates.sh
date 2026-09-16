#!/usr/bin/env bash
# The road gates of tools/wp13, run as gates.
#
#   gates.sh <repo>
#
# THREE OF THEM HAD TO LEARN THE VIADUCT RULE, because a column with open air
# under it is playtest 5's ruling 4 and not a defect: `lane_crossing_kat.lua`,
# `lane_routes.lua` and `kezamba_lots.lua gates`. Each allows the third case
# only where `top - ground >= MIN_CLEAR`, so a cell hanging over ground the road
# did NOT raise is still a defect. TWO of them had to be handed the seam's own
# `wet(x, z)` as well -- `kezamba_lots.lua gates` and
# `lethariel_plots.lua --bodies` -- or they build the pre-2026-09-16 causeway
# and measure a road nobody builds.
set -uo pipefail
export LC_ALL=C
repo="${1:?usage: gates.sh REPO}"
cd "$repo"
status=0

gate() {
	local label="$1"; shift
	printf '%-34s ' "$label"
	if nice -n 19 luajit "$@" >/tmp/gate.$$.out 2>/tmp/gate.$$.err; then
		printf 'exit 0  %s\n' "$(tail -1 /tmp/gate.$$.out)"
	else
		printf 'EXIT %s  %s\n' "$?" "$(tail -1 /tmp/gate.$$.out)"
		status=1
	fi
	rm -f /tmp/gate.$$.out /tmp/gate.$$.err
}

gate "kezamba_lots gates" tools/wp13/kezamba_lots.lua . gates
gate "kezamba_lots walk" tools/wp13/kezamba_lots.lua . walk
gate "kezamba_lots lots" tools/wp13/kezamba_lots.lua .
gate "lethariel_plots bodies" tools/wp13/lethariel_plots.lua . --bodies
gate "lethariel_plots lots" tools/wp13/lethariel_plots.lua .
gate "lethariel_plots gates" tools/wp13/lethariel_plots.lua . --gates

echo
echo "== lane_routes, nine seeds (illegal / walk / cross / lamp faults all 0) =="
for seed in 531802985935182545 8675309 15912857179583385436 0 1 2 42 12345 \
		999999999; do
	line="$(nice -n 19 luajit tools/wp13/lane_routes.lua . "$seed" /dev/null \
		2>&1 >/dev/null | tail -1)"
	echo "$line"
	case "$line" in
		*"illegal=0 walk_faults=0 cross_faults=0"*) ;;
		*) status=1 ;;
	esac
done

echo
echo "== route_gates --strict, nine seeds =="
for seed in 531802985935182545 8675309 15912857179583385436 0 1 2 42 12345 \
		999999999; do
	printf 'seed %-22s ' "$seed"
	if nice -n 19 luajit tools/wp13/route_gates.lua . "$seed" --strict \
			>/tmp/rg.$$.out 2>&1; then
		echo "exit 0  $(tail -1 /tmp/rg.$$.out)"
	else
		echo "EXIT 1  $(tail -1 /tmp/rg.$$.out)"
		status=1
	fi
	rm -f /tmp/rg.$$.out
done

echo
[[ "$status" -eq 0 ]] && echo "ALL ROAD GATES GREEN" || echo "A ROAD GATE IS RED"
exit "$status"
