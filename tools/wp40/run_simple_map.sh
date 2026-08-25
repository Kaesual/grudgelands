#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
lua_requested="${WP40_LUA_BIN:-/usr/bin/luajit}"
lua_bin="$(command -v "$lua_requested" 2>/dev/null || true)"
puc_bin="$repo/tools/bin/lua51"
luac_bin="$repo/tools/bin/luac51"
output="${1:-$repo/docs/research/wp40-simple-map-preview.svg}"

command -v rg >/dev/null 2>&1 || {
	echo "run_simple_map.sh: ripgrep (rg) is required" >&2
	exit 1
}
command -v xmllint >/dev/null 2>&1 || {
	echo "run_simple_map.sh: xmllint is required" >&2
	exit 1
}
[[ -n "$lua_bin" && -x "$lua_bin" && -x "$puc_bin" && -x "$luac_bin" ]] || {
	echo "run_simple_map.sh: LuaJIT and vendored PUC tools must be executable" >&2
	exit 1
}
[[ "$(readlink -f -- "$lua_bin")" != "$(readlink -f -- "$puc_bin")" ]] || {
	echo "run_simple_map.sh: development and PUC interpreters must differ" >&2
	exit 1
}
"$lua_bin" -e 'assert(type(rawget(_G,"jit"))=="table")'

canonical_output="$repo/docs/research/wp40-simple-map-preview.svg"
[[ "$output" == "$canonical_output" ]] || {
	echo "run_simple_map.sh: output must be $canonical_output" >&2
	exit 1
}

scratch="$(mktemp -d /tmp/grudgelands-wp40-simple-map.XXXXXXXX)"
cleanup() {
	if [[ "$scratch" == /tmp/grudgelands-wp40-simple-map.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT INT TERM

lua_files=(
	"$repo/mods/MAPGEN/grug_mapgen/wp40/schemas.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua"
	"$repo/mods/MAPGEN/grug_mapgen/wp40/simple_map.lua"
	"$repo/tools/wp40/simple_map_offline.lua"
	"$repo/tools/wp40/simple_map_test.lua"
	"$repo/tools/wp40/render_simple_map_svg.lua"
)
"$luac_bin" -p "${lua_files[@]}"
for file in "${lua_files[@]}"; do
	if "$luac_bin" -l -p "$file" | rg -n 'SETGLOBAL'; then
		echo "run_simple_map.sh: unexpected global write in $file" >&2
		exit 1
	fi
done

if rg -n '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' "${lua_files[@]}" ||
	rg -n '\\u\{|\\x[0-9A-Fa-f]|\\z' "${lua_files[@]}" ||
	rg -n 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' "${lua_files[@]}" ||
	rg -n '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' "${lua_files[@]}" ||
	rg -n '\brequire[[:space:]]*\(|io\.popen|os\.exit|\bminetest\.' "${lua_files[@]}"; then
	echo "run_simple_map.sh: Lua 5.1 do-not-write sweep failed" >&2
	exit 1
fi
[[ "$(rg -c 'os\.execute' "$repo/tools/wp40/simple_map_offline.lua")" -eq 1 ]] || {
	echo "run_simple_map.sh: offline SHA seam changed" >&2
	exit 1
}
if rg -n 'os\.execute' "$repo/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua" \
		"$repo/mods/MAPGEN/grug_mapgen/wp40/simple_map.lua"; then
	echo "run_simple_map.sh: production simple map invokes os.execute" >&2
	exit 1
fi

"$lua_bin" "$repo/tools/wp40/simple_map_test.lua" "$repo" "$scratch" --full \
	> "$scratch/full.txt"
kat_seeds=(0 1 9223372036854775808 18446744073709551615)
for seed in "${kat_seeds[@]}"; do
	"$lua_bin" "$repo/tools/wp40/simple_map_test.lua" "$repo" "$scratch" \
		--kat "$seed" > "$scratch/kat-luajit-$seed.txt"
	"$puc_bin" "$repo/tools/wp40/simple_map_test.lua" "$repo" "$scratch" \
		--kat "$seed" > "$scratch/kat-puc51-$seed.txt"
	cmp "$scratch/kat-luajit-$seed.txt" "$scratch/kat-puc51-$seed.txt"
done

"$lua_bin" "$repo/tools/wp40/render_simple_map_svg.lua" "$repo" "$scratch" \
	"$scratch/preview-a.svg" 0 > "$scratch/render-a.txt"
"$lua_bin" "$repo/tools/wp40/render_simple_map_svg.lua" "$repo" "$scratch" \
	"$scratch/preview-b.svg" 0 > "$scratch/render-b.txt"
cmp "$scratch/preview-a.svg" "$scratch/preview-b.svg"
xmllint --noout "$scratch/preview-a.svg"
cp "$scratch/preview-a.svg" "$output"
xmllint --noout "$output"

cat "$scratch/full.txt"
for seed in "${kat_seeds[@]}"; do
	printf 'seed\t%s\t' "$seed"
	cat "$scratch/kat-luajit-$seed.txt"
done
sha256sum "$output"
echo "svg\t$output"
