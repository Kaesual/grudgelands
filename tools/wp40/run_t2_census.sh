#!/usr/bin/env bash
set -euo pipefail

# WP40 T2 census runner — M1 scope: the Scan-1 KAT and small explicit seed
# lists only.  The full-W eight-shard launcher with GO gate, resume,
# first-record validation and cost gate is milestone M2 (plan section 6.6);
# until it lands, this runner cannot start a full-W run at all — the worker
# caps explicit seed lists at 64 seeds.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"

# A missing rg would make the SETGLOBAL gate below pass vacuously: exit
# status 127 in an `if` condition reads exactly like "no match found".
command -v rg >/dev/null 2>&1 || {
	echo "${BASH_SOURCE[0]##*/}: ripgrep (rg) is required and was not found" >&2
	exit 1
}

owned_lua=(
	"$repo/tools/wp40/t2_census_worker.lua"
	"$repo/tools/wp40/fixtures/t2_census/scan1_kat_v1.lua"
)
"$repo/tools/bin/luac51" -p "${owned_lua[@]}"
for file in "${owned_lua[@]}"; do
	if "$repo/tools/bin/luac51" -l -p "$file" | rg -q 'SETGLOBAL'; then
		echo "WP40 T2 census global write in $file" >&2
		exit 1
	fi
done

lua_bin="${WP40_LUA_BIN:-/usr/bin/luajit}"
lua_path="$(command -v "$lua_bin" 2>/dev/null || true)"
if [[ -z "$lua_path" || ! -x "$lua_path" ]]; then
	echo "WP40 T2 census interpreter is not executable: $lua_bin" >&2
	exit 2
fi
echo "WP40 T2 census interpreter: $lua_path"

scratch="$(mktemp -d /tmp/grudgelands-wp40-t2-census.XXXXXXXX)"
cleanup() {
	if [[ "$scratch" == /tmp/grudgelands-wp40-t2-census.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT

case "${1:-}" in
	--kat)
		shift
		if [[ $# -ne 0 ]]; then
			echo "--kat accepts no further arguments" >&2
			exit 2
		fi
		"$lua_path" "$script_dir/t2_census_worker.lua" "$repo" "$scratch" \
			"$scratch/census-kat.tsv" --kat
		;;
	--seeds)
		shift
		if [[ $# -lt 1 ]]; then
			echo "--seeds requires at least one decimal seed" >&2
			exit 2
		fi
		output="${WP40_CENSUS_OUTPUT:?set WP40_CENSUS_OUTPUT to the output TSV path}"
		"$lua_path" "$script_dir/t2_census_worker.lua" "$repo" "$scratch" \
			"$output" "$@"
		;;
	*)
		echo "usage: tools/wp40/run_t2_census.sh --kat" >&2
		echo "       WP40_CENSUS_OUTPUT=path tools/wp40/run_t2_census.sh --seeds SEED..." >&2
		exit 2
		;;
esac
bash -n "$script_dir/run_t2_census.sh"
