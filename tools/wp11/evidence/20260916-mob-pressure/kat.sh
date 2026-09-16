#!/usr/bin/env bash
# Both KATs of the mob-pressure lane under BOTH interpreters, their mutations,
# and the three suites this lane's changes could have broken.
#
# Usage: kat.sh [OUTPUT_DIR]   (default: the kat/ directory beside this file)
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
out="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/kat}"
mkdir -p "$out"

run() {
	local label="$1" bin="$2" kat="$3"
	"$bin" -e "io.write(dofile(\"$kat\")(\".\"))" >"$out/$label.txt" 2>&1
	echo "$label exit=$?"
}

run aggregator-luajit luajit tools/wp11/move_aggregator_kat.lua
run aggregator-puc51 tools/bin/lua51 tools/wp11/move_aggregator_kat.lua
run cadence-luajit luajit tools/wp11/mob_cadence_kat.lua
run cadence-puc51 tools/bin/lua51 tools/wp11/mob_cadence_kat.lua

echo "== the two interpreters agree, byte for byte =="
cmp "$out/aggregator-luajit.txt" "$out/aggregator-puc51.txt" &&
	echo "aggregator IDENTICAL"
cmp "$out/cadence-luajit.txt" "$out/cadence-puc51.txt" &&
	echo "cadence IDENTICAL"

echo "== mutations: each must FAIL =="
# The aggregator has four (=4 is the root replacement rule the round-4 review
# found); the cadence has three.
: >"$out/mutations.txt"
for m in 1 2 3 4; do
	{
		echo "--- aggregator MUTATION=$m"
		MUTATION=$m luajit -e \
			'io.write(dofile("tools/wp11/move_aggregator_kat.lua")("."))' 2>&1 |
			head -1
	} >>"$out/mutations.txt"
done
for m in 1 2 3; do
	{
		echo "--- cadence MUTATION=$m"
		MUTATION=$m luajit -e \
			'io.write(dofile("tools/wp11/mob_cadence_kat.lua")("."))' 2>&1 |
			head -1
	} >>"$out/mutations.txt"
done
cat "$out/mutations.txt"

echo "== suites this lane's files are loaded by =="
# THREE of these are RED on main ba831caf itself, before this branch is
# involved, and the lane's note records the A/B that shows it:
#   * wp45 character_creation -- Lane W1 removed the `/class` chatcommand
#     (ruling 20) and the test still calls `chatcommands.class.func`;
#   * wp39 combat_integration -- Lane H's HUD reads `grug_core.hud_layout`,
#     which that test's stub does not provide;
#   * wp39 projectile -- Lane W1's rage tuning renamed/removed
#     `RAGE_PER_SWING`, which kits.lua's own description string still reads.
# They are printed, not hidden: swapping this branch's selection.lua,
# kits.lua, grug_core/init.lua and the wp45 test for main's own versions
# reproduces all three failures unchanged.
{
	bash tools/wp45/run.sh
	WP45_LUA_BIN=tools/bin/lua51 bash tools/wp45/run.sh
	luajit tools/wp39/combat_integration_test.lua .
	luajit tools/wp39/projectile_test.lua .
	luajit -e 'io.write(dofile("tools/wp13/start_npcs_kat.lua")("."))' | tail -1
} >"$out/suites.txt" 2>&1
cat "$out/suites.txt"

echo "== the two main-side suites this branch must not break =="
{
	luajit -e 'io.write(dofile("tools/wp11/talent_tree_kat.lua")("."))' | tail -1
	tools/bin/lua51 -e 'io.write(dofile("tools/wp11/talent_tree_kat.lua")("."))' | tail -1
	luajit -e 'io.write(dofile("tools/ui/hud_bars_kat.lua")("."))' | tail -1
	tools/bin/lua51 -e 'io.write(dofile("tools/ui/hud_bars_kat.lua")("."))' | tail -1
} >"$out/neighbour-suites.txt" 2>&1
cat "$out/neighbour-suites.txt"

echo "== final micro pair (this lane touches no mapgen file) =="
# final_micro refuses to overwrite its own output on purpose, so a re-run
# clears the pair first.
rm -f "$out/final-micro-luajit.tsv" "$out/final-micro-puc51.tsv"
luajit tools/wp13/final_micro.lua . "$out/final-micro-luajit.tsv" luajit \
	>"$out/final-micro-luajit.txt" 2>&1
tools/bin/lua51 tools/wp13/final_micro.lua . "$out/final-micro-puc51.tsv" puc51 \
	>"$out/final-micro-puc51.txt" 2>&1
cat "$out/final-micro-luajit.txt" "$out/final-micro-puc51.txt"
sha256sum "$out/final-micro-luajit.tsv" "$out/final-micro-puc51.tsv" \
	>"$out/micro-pair.sha256"
cat "$out/micro-pair.sha256"
