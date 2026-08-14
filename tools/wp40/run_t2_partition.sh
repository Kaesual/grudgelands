#!/usr/bin/env bash
set -euo pipefail

if (( $# != 0 )); then
	echo "usage: tools/wp40/run_t2_partition.sh" >&2
	exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-partition.XXXXXXXX)"
cleanup() {
	if [[ "$scratch" == /tmp/grudgelands-wp40-t2-partition.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT

owned_lua=(
	"$repo/mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua"
	"$repo/tools/wp40/t2_partition_test.lua"
	"$repo/tools/wp40/t2_partition_oracle.lua"
	"$repo/tools/wp40/fixtures/t2_extreme_e0/selected_stage2_blocked.lua"
)

"$repo/tools/bin/luac51" -p "${owned_lua[@]}"
for file in "${owned_lua[@]:0:3}"; do
	if "$repo/tools/bin/luac51" -l -p "$file" | rg -q 'SETGLOBAL'; then
		echo "WP40 T2 partition global write in $file" >&2
		exit 1
	fi
done
test_bytecode="$("$repo/tools/bin/luac51" -l -p \
	"$repo/tools/wp40/t2_partition_test.lua")"
for forbidden in extract_final_edge_points count_bank_envelopes \
		compiled_wing_authority trace_independent_banks \
		independent_transition_expectations assert_transition_payload; do
	if rg -q "GETGLOBAL.*; $forbidden$" <<<"$test_bytecode"; then
		echo "WP40 T2 selected oracle escaped lexical scope: $forbidden" >&2
		exit 1
	fi
done

lua_bin="${WP40_LUA_BIN:-$repo/tools/bin/lua51}"
lua_path="$(command -v "$lua_bin" 2>/dev/null || true)"
if [[ -z "$lua_path" || ! -x "$lua_path" ]]; then
	echo "WP40 T2 partition interpreter is not executable: $lua_bin" >&2
	exit 2
fi
echo "WP40 T2 partition interpreter: $lua_path"
"$lua_path" "$script_dir/t2_partition_test.lua" "$repo" "$scratch" \
	selected_stage2_blocked
"$lua_path" "$script_dir/t2_partition_test.lua" "$repo" "$scratch"
bash -n "$script_dir/run_t2_partition.sh"
