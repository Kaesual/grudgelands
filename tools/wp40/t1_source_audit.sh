#!/usr/bin/env bash
set -euo pipefail

# A missing rg would make every check below pass vacuously: exit status 127 in
# an `if` condition reads exactly like "no match found". Fail loudly instead.
command -v rg >/dev/null 2>&1 || {
	echo "${BASH_SOURCE[0]##*/}: ripgrep (rg) is required and was not found" >&2
	exit 1
}

repo="${1:?repository root is required}"
foundation="$repo/mods/MAPGEN/grug_mapgen/wp40"

if [[ "$(rg -n 'function canonical\.encode' "$foundation" --glob '*.lua' | wc -l)" -ne 1 ]] ||
		[[ "$(rg -n 'function canonical\.checksum' "$foundation" --glob '*.lua' | wc -l)" -ne 1 ]] ||
		[[ "$(rg -n 'function deterministic\.new_hash' "$foundation" --glob '*.lua' | wc -l)" -ne 1 ]]; then
	echo "WP40 T1 source audit: canonical/hash seam count mismatch" >&2
	exit 1
fi

ipc_hits="$(rg -l 'ipc_(get|set|poll|cas)' "$foundation" --glob '*.lua' || true)"
if [[ "$ipc_hits" != "$foundation/validation.lua" ]]; then
	echo "WP40 T1 source audit: IPC exists outside the one transport seam" >&2
	exit 1
fi

if rg -n 'math\.(random|randomseed|sqrt)|PseudoRandom|PcgRandom|SecureRandom' \
		"$foundation" --glob '*.lua'; then
	echo "WP40 T1 source audit: ambient PRNG or floating sqrt found" >&2
	exit 1
fi

if rg -n 'register_on_generated|VoxelManip|\bgrug_zones\b' \
		"$foundation" --glob '*.lua'; then
	echo "WP40 T1 source audit: later-WP authority found" >&2
	exit 1
fi

if rg -n 'tonumber[[:space:]]*\([^)]*(seed|Seed)|tonumber[[:space:]]*\([^)]*decimal' \
		"$foundation" "$repo/tools/wp40" --glob '*.lua'; then
	echo "WP40 T1 source audit: full decimal seed converted through Lua number" >&2
	exit 1
fi

echo "WP40 T1 source audit passed"
