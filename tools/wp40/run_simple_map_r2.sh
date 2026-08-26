#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
lua_bin="$(command -v /usr/bin/luajit 2>/dev/null || true)"
luac_bin="$repo/tools/bin/luac51"
output="$repo/docs/research/wp40-simple-map-r2-artifact.tsv"

command -v rg >/dev/null 2>&1 || {
	echo "run_simple_map_r2.sh: ripgrep (rg) is required" >&2
	exit 1
}
[[ -n "$lua_bin" && -x "$lua_bin" && -x "$luac_bin" ]] || {
	echo "run_simple_map_r2.sh: LuaJIT and luac51 must be executable" >&2
	exit 1
}
"$lua_bin" -e 'assert(type(rawget(_G,"jit"))=="table")'

scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
cleanup() {
	if [[ "$scratch" == /tmp/grudgelands-wp40-simple-map.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT INT TERM

lua_files=(
	"$repo/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/simple_map.lua"
	"$repo/tools/wp40/simple_map_offline.lua"
	"$repo/tools/wp40/simple_map_r2_test.lua"
	"$repo/tools/wp40/simple_map_r2_metadata.lua"
	"$repo/tools/wp40/simple_map_r2_cores.lua"
	"$repo/tools/wp40/simple_map_r2_water.lua"
	"$repo/tools/wp40/simple_map_r2_routes.lua"
	"$repo/tools/wp40/simple_map_r2_grid.lua"
	"$repo/tools/wp40/simple_map_r2_housing.lua"
	"$repo/tools/wp40/simple_map_r2_contacts.lua"
)
"$luac_bin" -p "${lua_files[@]}"
for file in "${lua_files[@]}"; do
	if "$luac_bin" -l -p -o /dev/null "$file" | rg -n 'SETGLOBAL'; then
		echo "run_simple_map_r2.sh: unexpected global write in $file" >&2
		exit 1
	fi
done
if rg -n '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' "${lua_files[@]}" ||
	rg -n '\\u\{|\\x[0-9A-Fa-f]|\\z' "${lua_files[@]}" ||
	rg -n 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' "${lua_files[@]}" ||
	rg -n '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' "${lua_files[@]}" ||
	rg -n '\brequire[[:space:]]*\(|io\.popen|os\.exit|\bminetest\.' "${lua_files[@]}"; then
	echo "run_simple_map_r2.sh: Lua 5.1 do-not-write sweep failed" >&2
	exit 1
fi
[[ "$(rg -c 'os\.execute' "$repo/tools/wp40/simple_map_offline.lua")" -eq 1 ]] || {
	echo "run_simple_map_r2.sh: offline SHA seam changed" >&2
	exit 1
}
if rg -n 'os\.execute' "$repo/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua" \
		"$repo/mods/MAPGEN/grug_mapgen/wp40/simple_map.lua"; then
	echo "run_simple_map_r2.sh: production simple map invokes os.execute" >&2
	exit 1
fi

"$lua_bin" -e '_G.wp40_ffi=require("ffi")' \
	"$repo/tools/wp40/simple_map_r2_test.lua" "$repo" "$scratch" "$output"
sha256sum "$output"
