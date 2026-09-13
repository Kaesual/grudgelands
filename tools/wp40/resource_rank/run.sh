#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$script_dir/../../.." && pwd -P)"
lua_bin="${WP40_LUA_BIN:-/usr/bin/luajit}"
mode="${1:-}"
[[ -z "$mode" || "$mode" == expanded ]] || {
	echo "usage: bash tools/wp40/resource_rank/run.sh [expanded]" >&2
	exit 2
}
"$repo/tools/bin/luac51" -p "$script_dir/fixture.lua" "$script_dir/run.lua" \
	"$repo/mods/MAPGEN/grug_mapgen/wp40/r6_hash.lua" \
	"$repo/mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua"
"$lua_bin" "$script_dir/run.lua" "$repo" ${mode:+"$mode"}
