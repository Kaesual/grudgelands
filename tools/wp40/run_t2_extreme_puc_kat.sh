#!/usr/bin/env bash
set -euo pipefail

if (( $# != 0 )); then
	echo "usage: tools/wp40/run_t2_extreme_puc_kat.sh" >&2
	exit 2
fi
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
export WP40_NO_CACHE=1
lua_bin="$repo/tools/bin/lua51"
if [[ ! -x "$lua_bin" ]]; then
	echo "WP40 T2 targeted PUC interpreter is not executable: $lua_bin" >&2
	exit 2
fi
scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2-extreme-puc.XXXXXXXX)"
cleanup() {
	if [[ "$scratch" == /tmp/grudgelands-wp40-t2-extreme-puc.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT

"$repo/tools/bin/luac51" -p \
	"$script_dir/t2_extreme_puc_kat.lua" \
	"$script_dir/t2_extreme_authority.lua" \
	"$script_dir/t2_extreme_gate_check.lua" \
	"$script_dir/fixtures/t2_extreme_e0/full_scan_gate.lua" \
	"$script_dir/fixtures/t2_extreme_e0/vocabulary.lua" \
	"$repo/mods/MAPGEN/grug_mapgen/wp40/geometry/extreme.lua"
echo "WP40 T2 targeted PUC interpreter: $lua_bin"
"$lua_bin" "$script_dir/t2_extreme_puc_kat.lua" "$repo" "$scratch"
bash -n "$script_dir/run_t2_extreme_puc_kat.sh"
