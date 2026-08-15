#!/usr/bin/env bash
set -euo pipefail

if (( $# != 0 )); then
	echo "usage: tools/wp40/run_t2_extreme.sh" >&2
	exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
export WP40_NO_CACHE=1
for runner in "$script_dir/run_t2_extreme.sh" \
	"$script_dir/run_t2_extreme_puc_kat.sh" \
	"$script_dir/run_t2_extreme_shard.sh" \
	"$script_dir/run_t2_extreme_shards.sh"; do
	if [[ ! -x "$runner" ]]; then
		echo "WP40 T2 extreme runner is not executable: $runner" >&2
		exit 1
	fi
done
scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-extreme.XXXXXXXX)"
cleanup() {
	if [[ "$scratch" == /tmp/grudgelands-wp40-t2-extreme.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT

owned_lua=(
	"$repo/mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/geometry/extreme.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua"
	"$repo/tools/wp40/t2_extreme_test.lua"
	"$repo/tools/wp40/t2_payload_cache.lua"
	"$repo/tools/wp40/t2_extreme_puc_kat.lua"
	"$repo/tools/wp40/t2_extreme_authority.lua"
	"$repo/tools/wp40/t2_extreme_gate_check.lua"
	"$repo/tools/wp40/t2_extreme_merge.lua"
	"$repo/tools/wp40/t2_extreme_shard_worker.lua"
	"$repo/tools/wp40/t2_extreme_verify_shard.lua"
	"$repo/tools/wp40/fixtures/t2_extreme_e0/full_scan_gate.lua"
	"$repo/tools/wp40/fixtures/t2_extreme_e0/max_u64_r16_r17.lua"
	"$repo/tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua"
)

"$repo/tools/bin/luac51" -p "${owned_lua[@]}"
for file in "${owned_lua[@]:0:3}"; do
	if "$repo/tools/bin/luac51" -l -p "$file" | rg -q 'SETGLOBAL'; then
		echo "WP40 T2 extreme global write in $file" >&2
		exit 1
	fi
done

merge_mode="${WP40_EXTREME_MERGE:-0}"
if [[ "$merge_mode" != 0 && "$merge_mode" != 1 ]]; then
	echo "WP40_EXTREME_MERGE must be 0 or 1" >&2
	exit 2
fi
if [[ "$merge_mode" == 1 ]]; then
	lua_bin="$repo/tools/bin/lua51"
else
	lua_bin="${WP40_LUA_BIN:-$repo/tools/bin/lua51}"
fi
lua_path="$(command -v "$lua_bin" 2>/dev/null || true)"
if [[ -z "$lua_path" || ! -x "$lua_path" ]]; then
	echo "WP40 T2 extreme interpreter is not executable: $lua_bin" >&2
	exit 2
fi
echo "WP40 T2 extreme interpreter: $lua_path"
if [[ "$merge_mode" == 1 ]]; then
	"$lua_path" "$script_dir/t2_extreme_merge.lua" "$repo" "$scratch"
else
	if env -u WP40_EXTREME_RANGE_FIRST -u WP40_EXTREME_RANGE_LAST \
		WP40_EXTREME_BENCHMARK_COUNT=4096 "$lua_path" \
		"$script_dir/t2_extreme_test.lua" "$repo" "$scratch" >/dev/null 2>&1; then
		echo "WP40 T2 extreme Foundation accepted a 4096-candidate benchmark" >&2
		exit 1
	fi
	if env -u WP40_EXTREME_BENCHMARK_COUNT WP40_EXTREME_RANGE_FIRST=0 \
		WP40_EXTREME_RANGE_LAST=64 "$lua_path" \
		"$script_dir/t2_extreme_test.lua" "$repo" "$scratch" >/dev/null 2>&1; then
		echo "WP40 T2 extreme Foundation accepted a range wider than 64" >&2
		exit 1
	fi
	"$lua_path" "$script_dir/t2_extreme_test.lua" "$repo" "$scratch"
fi
bash -n "$script_dir/run_t2_extreme.sh" \
	"$script_dir/run_t2_extreme_puc_kat.sh" \
	"$script_dir/run_t2_extreme_shard.sh" \
	"$script_dir/run_t2_extreme_shards.sh"
