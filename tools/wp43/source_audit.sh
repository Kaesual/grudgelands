#!/usr/bin/env bash
set -euo pipefail

# A missing rg would make every check below pass vacuously: exit status 127 in
# an `if` condition reads exactly like "no match found". Fail loudly instead.
command -v rg >/dev/null 2>&1 || {
	echo "${BASH_SOURCE[0]##*/}: ripgrep (rg) is required and was not found" >&2
	exit 1
}

repo="${1:?repository root is required}"

own_lua=(
	"$repo/mods"
	--glob '*.lua'
	--glob '!**/BASE/**'
	--glob '!**/ENTITIES/mobs/**'
)

if rg -n -i '(level_for_tier|leveldiff)' "${own_lua[@]}"; then
	echo "WP43 source audit: retired engine-level authority remains" >&2
	exit 1
fi

if rg -n -i '(emberstone|grudgesteel)' "${own_lua[@]}" \
		--glob '!**/ITEMS/grug_materials/registry.lua' \
		--glob '!**/ITEMS/grug_materials/migration.lua'; then
	echo "WP43 source audit: legacy material name escaped migration data" >&2
	exit 1
fi

if rg -n '(default:stone_with_mese|default:mese(_crystal(_fragment)?)?|default:stone_with_diamond|default:diamond(block)?)' \
		"${own_lua[@]}" \
		--glob '!**/ITEMS/grug_materials/registry.lua' \
		--glob '!**/ITEMS/grug_materials/migration.lua'; then
	echo "WP43 source audit: legacy runtime item id escaped migration data" >&2
	exit 1
fi

if rg -n -i 'description[[:space:]]*=[^\n]*(mese|emberstone|grudgesteel)' \
		"${own_lua[@]}"; then
	echo "WP43 source audit: stale player-facing material name remains" >&2
	exit 1
fi

mining="$repo/mods/ITEMS/grug_materials/mining.lua"
migration="$repo/mods/ITEMS/grug_materials/migration.lua"
derivatives="$repo/mods/ITEMS/grug_materials/derivatives.lua"

if rg -n 'is_ground_content[[:space:]]*==[[:space:]]*true' "$mining"; then
	echo "WP43 source audit: unsafe nodedef-default natural classifier remains" >&2
	exit 1
fi

for contract in 'punch_attack_uses' 'emit_mining_failure' \
		'resource_ore_description' 'record_protection_violation'; do
	if ! rg -q "$contract" "$mining"; then
		echo "WP43 source audit: mining contract missing $contract" >&2
		exit 1
	fi
done

if ! rg -q 'clear_craft\(\{output = "default:pick_steel"\}\)' "$migration"; then
	echo "WP43 source audit: Steel verification pick is craftable" >&2
	exit 1
fi

if rg -n 'register_craft' "$derivatives"; then
	echo "WP43 source audit: canonical derivatives pulled WP26 recipes forward" >&2
	exit 1
fi

echo "WP43 material source audit passed"
