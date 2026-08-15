#!/usr/bin/env bash
set -euo pipefail

# T2-final must use the fallback interpreter, bypass the payload cache, and
# include the retained historical-provenance check:
#   WP40_FINAL=1 tools/wp40/run_t2_partition.sh --no-cache --historical

no_cache="${WP40_NO_CACHE:-0}"
historical=0
for option in "$@"; do
	case "$option" in
		--no-cache) no_cache=1 ;;
		--historical) historical=1 ;;
		*)
			echo "usage: tools/wp40/run_t2_partition.sh [--no-cache] [--historical]" >&2
			exit 2
			;;
	esac
done
if [[ "$no_cache" != 0 && "$no_cache" != 1 ]]; then
	echo "WP40_NO_CACHE must be 0 or 1" >&2
	exit 2
fi
final="${WP40_FINAL:-0}"
if [[ "$final" != 0 && "$final" != 1 ]]; then
	echo "WP40_FINAL must be 0 or 1" >&2
	exit 2
fi
if [[ "$final" == 1 ]]; then
	if [[ -n "${WP40_T2_ONLY:-}" ]]; then
		echo "WP40_FINAL rejects WP40_T2_ONLY; the final gate runs every phase" >&2
		exit 2
	fi
	no_cache=1
	historical=1
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
	"$repo/tools/wp40/t2_partition_c2_selected.lua"
	"$repo/tools/wp40/t2_payload_cache.lua"
	"$repo/tools/wp40/t2_phase_selector.lua"
	"$repo/tools/wp40/fixtures/t2_extreme_e0/selected_stage2_blocked.lua"
)

"$repo/tools/bin/luac51" -p "${owned_lua[@]}"
for file in "${owned_lua[@]:0:3}"; do
	if "$repo/tools/bin/luac51" -l -p "$file" | rg -q 'SETGLOBAL'; then
		echo "WP40 T2 partition global write in $file" >&2
		exit 1
	fi
done
if "$repo/tools/bin/luac51" -l -p \
	"$repo/tools/wp40/t2_partition_c2_selected.lua" | rg -q 'SETGLOBAL'; then
	echo "WP40 T2 partition selected diagnostic wrapper writes a global" >&2
	exit 1
fi
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

if [[ "$final" == 1 ]]; then
	lua_bin="$repo/tools/bin/lua51"
else
	lua_bin="${WP40_LUA_BIN:-/usr/bin/luajit}"
fi
lua_path="$(command -v "$lua_bin" 2>/dev/null || true)"
if [[ -z "$lua_path" || ! -x "$lua_path" ]]; then
	echo "WP40 T2 partition interpreter is not executable: $lua_bin" >&2
	exit 2
fi
echo "WP40 T2 partition interpreter: $lua_path"
cache_dir="$repo/tools/wp40/results/payload-cache"
mkdir -p "$cache_dir"
export WP40_NO_CACHE="$no_cache"
export WP40_PAYLOAD_CACHE_DIR="$cache_dir"
if [[ "$historical" == 1 ]]; then
	"$lua_path" "$script_dir/t2_partition_test.lua" "$repo" "$scratch" \
		selected_stage2_historical
fi
"$lua_path" "$script_dir/t2_partition_test.lua" "$repo" "$scratch"
bash -n "$script_dir/run_t2_partition.sh"
