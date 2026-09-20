#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$repo"
LUAC="${GRUG_LUAC51:-$repo/tools/bin/luac51}"
CHANGED=(
	mods/ENTITIES/grug_traders/stock.lua
	mods/ENTITIES/grug_traders/trade.lua
	mods/ENTITIES/grug_traders/vendors.lua
	tools/r11_scout_traders/stock_kat.lua
)

for file in "${CHANGED[@]}"; do
	"$LUAC" -p "$file" || exit 1
	printf '%s parser PASS; SETGLOBAL [%s]\n' "$file" \
		"$("$LUAC" -l -p "$file" | grep -c SETGLOBAL)"
done

sweeps() {
	local index=1
	for pattern in \
		'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' \
		'\\u\{|\\x[0-9A-Fa-f]|\\z' \
		'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' \
		'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' \
		'\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'; do
		echo "SWEEP $index"
		grep -rnE "$pattern" "$@" --include=*.lua
		index=$((index + 1))
	done
}

echo "== changed-file sweeps =="
sweeps "${CHANGED[@]}"
echo "== shipped-mod sweeps =="
sweeps mods/*/grug_*
