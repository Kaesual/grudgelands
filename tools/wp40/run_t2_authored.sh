#!/usr/bin/env bash
set -euo pipefail

command -v rg >/dev/null 2>&1 || {
	echo "${BASH_SOURCE[0]##*/}: ripgrep (rg) is required and was not found" >&2
	exit 1
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
scratch="$(mktemp -d -p /tmp grudgelands-wp40-authored.XXXXXXXX)"
cleanup() {
	if [[ "$scratch" == /tmp/grudgelands-wp40-authored.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT HUP INT TERM

lua_bin="${WP40_LUA_BIN:-/usr/bin/luajit}"
"$lua_bin" -e 'assert(type(jit) == "table", "D-1 full run requires LuaJIT")'

owned_lua=(
	"$repo/mods/MAPGEN/grug_mapgen/wp40/geometry/authored.lua"
	"$repo/tools/wp40/t2_authored_test.lua"
)
"$repo/tools/bin/luac51" -p "${owned_lua[@]}"
for file in "${owned_lua[@]}"; do
	if "$repo/tools/bin/luac51" -l -p "$file" | rg -q 'SETGLOBAL'; then
		echo "WP40 T2 authored global write in $file" >&2
		exit 1
	fi
done

/usr/bin/time -f 'D1_LUAJIT_WALL=%e D1_LUAJIT_MAXRSS_KIB=%M' \
	-o "$scratch/luajit.time" \
	"$lua_bin" "$script_dir/t2_authored_test.lua" "$repo" "$scratch" full \
	> "$scratch/luajit.out"
/usr/bin/time -f 'D1_PUC_KAT_WALL=%e D1_PUC_KAT_MAXRSS_KIB=%M' \
	-o "$scratch/puc.time" \
	"$repo/tools/bin/lua51" "$script_dir/t2_authored_test.lua" \
	"$repo" "$scratch" kat > "$scratch/puc.out"

awk -F '\t' '$1 == "canonical" {print}' "$scratch/luajit.out" \
	> "$scratch/luajit.canonical"
awk -F '\t' '$1 == "canonical" {print}' "$scratch/puc.out" \
	> "$scratch/puc.canonical"
[[ "$(wc -l < "$scratch/luajit.canonical")" -eq 1 ]]
[[ "$(wc -l < "$scratch/puc.canonical")" -eq 1 ]]
cmp "$scratch/luajit.canonical" "$scratch/puc.canonical"

cat "$scratch/luajit.out"
cat "$scratch/puc.out"
cat "$scratch/luajit.time"
cat "$scratch/puc.time"
bash -n "$script_dir/run_t2_authored.sh"

echo "WP40 T2 authored runner passed; LuaJIT/PUC canonical digests byte-identical"
