#!/usr/bin/env bash
set -euo pipefail

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

echo "WP43 material source audit passed"
