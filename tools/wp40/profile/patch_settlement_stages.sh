#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
game_dir="${1:-}"
[[ "$#" -eq 1 && -d "$game_dir/mods/MAPGEN/grug_mapgen/wp40" ]] || {
	echo "usage: patch_settlement_stages.sh DISPOSABLE_GAME_DIR" >&2
	exit 2
}
target="$game_dir/mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua"
patch_file="$script_dir/instrument-settlement-stages.patch"
[[ -f "$target" && -f "$patch_file" ]] || {
	echo "WP40 profile stages: settlement target or patch is absent" >&2
	exit 2
}
if rg -q 'GRUG_WP40_PROFILE_STAGE' "$target"; then
	echo "WP40 profile stages: snapshot is already instrumented" >&2
	exit 2
fi
patch --batch --forward --fuzz=0 --directory="$game_dir" --strip=1 <"$patch_file"
rg -q 'GRUG_WP40_PROFILE_STAGE' "$target" || {
	echo "WP40 profile stages: instrumentation marker was not installed" >&2
	exit 1
}
