#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-schema.XXXXXXXX)"
cleanup() {
	if [[ "$scratch" == /tmp/grudgelands-wp40-t2-schema.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT

owned_lua=(
	"$repo/mods/MAPGEN/grug_mapgen/wp40/compiled_schema.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/compiler.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/schemas.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/init.lua"
	"$repo/tools/wp40/t2_schema_core_test.lua"
)

"$repo/tools/bin/luac51" -p "${owned_lua[@]}"
for file in "${owned_lua[@]}"; do
	if "$repo/tools/bin/luac51" -l -p "$file" | rg -q 'SETGLOBAL'; then
		echo "WP40 T2 schema/core global write in $file" >&2
		exit 1
	fi
done

"$repo/tools/bin/lua51" "$script_dir/t2_schema_core_test.lua" "$repo" "$scratch"
bash -n "$script_dir/run_t2_schema_core.sh"

"$script_dir/t2_source_audit.sh" "$repo"
"$script_dir/run_t1.sh"
"$script_dir/run_t0.sh"
"$repo/tools/wp43/source_audit.sh" "$repo"

echo "WP40 T2 schema/core gates passed"
