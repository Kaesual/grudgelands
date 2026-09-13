#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
game_dir="${1:-}"
[[ "$#" -eq 1 && -d "$game_dir/mods/MAPGEN/grug_mapgen/wp40" ]] || {
	echo "usage: patch_snapshot.sh DISPOSABLE_GAME_DIR" >&2
	exit 2
}
target="$game_dir/mods/MAPGEN/grug_mapgen/wp40/r7_mapgen.lua"
patch_file="$script_dir/instrument-mapgen.patch"
[[ -f "$target" && -f "$patch_file" ]] || {
	echo "WP40 profile: mapgen target or instrumentation patch is absent" >&2
	exit 2
}
if rg -q 'GRUG_WP40_PROFILE_CALLBACK' "$target"; then
	echo "WP40 profile: snapshot is already instrumented" >&2
	exit 2
fi
patch --batch --forward --directory="$game_dir" --strip=1 <"$patch_file"
rg -q 'GRUG_WP40_PROFILE_CALLBACK' "$target" || {
	echo "WP40 profile: instrumentation marker was not installed" >&2
	exit 1
}
