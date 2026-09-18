#!/usr/bin/env bash
set -euo pipefail

ROOT=${1:?absolute repository root required}
case "$ROOT" in /*) ;; *) echo "absolute repository root required" >&2; exit 2;; esac

run_mutation() {
	local mutation=$1 kat=$2
	if R8_ALCH_MUTATION=$mutation "$ROOT/tools/bin/lua51" -e \
		"io.write(dofile('$ROOT/tools/r8_alch/$kat.lua')('$ROOT'))" >/dev/null 2>&1; then
		echo "mutation unexpectedly survived: $mutation" >&2
		exit 1
	fi
	echo "mutation killed: $mutation"
}

for mutation in recipe_tier cooking_items mana_tier shared_cooldown greater_cooldown antivenom_callback swiftness_callback cave_callback deepwater_callback food_stack elixir_clock elixir_exclusive apothecary_cap item_level vendor_bottle authorizer authorizer_allow cave_cap; do
	run_mutation "$mutation" alchemy_kat
done
for mutation in geometry activation root_alternative take_veto take_allow_side_effect; do
	run_mutation "$mutation" stand_kat
done
run_mutation poison_clear poison_kat
run_mutation capital capital_kat
