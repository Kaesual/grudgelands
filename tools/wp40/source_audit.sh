#!/usr/bin/env bash
set -euo pipefail

repo="${1:?repository root is required}"
handoff="$repo/mods/MAPGEN/grug_mapgen/wp43_handoff.lua"
probe="$repo/tools/wp40/runtime_probe/init.lua"

if rg -n 'function[[:space:]]+handoff\.(encode|checksum)' "$handoff"; then
	echo "WP40 T0 source audit: a second canonical encoder/checksum seam exists" >&2
	exit 1
fi

if rg -n -- '(-100|-300|-500|-700|-1000|-31000)' "$handoff"; then
	echo "WP40 T0 source audit: copied WP43 depth boundary in handoff adapter" >&2
	exit 1
fi

if rg -n -i '(emberstone|grudgesteel|default:stone_with_mese)' \
		"$handoff" "$probe"; then
	echo "WP40 T0 source audit: forbidden runtime identity in target/probe source" >&2
	exit 1
fi

if rg -n 'tonumber[[:space:]]*\([^)]*(seed|Seed)|tonumber[[:space:]]*\([^)]*decimal' \
		"$repo/tools/wp40" "$handoff" --glob '*.lua'; then
	echo "WP40 T0 source audit: full decimal seed converted through a Lua number" >&2
	exit 1
fi

if rg -n '\bminetest\.' "$handoff" "$probe"; then
	echo "WP40 T0 source audit: deprecated namespace in new Lua source" >&2
	exit 1
fi

echo "WP40 T0 source audit passed"

