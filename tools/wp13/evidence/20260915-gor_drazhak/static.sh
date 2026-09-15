#!/usr/bin/env bash
# Static gates for the WP13 Gor Drazhak package: the plain-5.1 parser, the
# SETGLOBAL count per touched file and tree-wide, the five grep sweeps of
# docs/research/luanti-lua.md, and the fresh-server audit.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
luac=tools/bin/luac51

touched=(
	mods/MAPGEN/grug_mapgen/wp13/orc_palisade.lua
	mods/MAPGEN/grug_mapgen/wp13/gor_drazhak.lua
	mods/MAPGEN/grug_mapgen/wp13/gor_drazhak_quadrants.lua
	mods/MAPGEN/grug_mapgen/wp13/gor_drazhak_plot.lua
	mods/MAPGEN/grug_mapgen/wp13/gor_drazhak_districts.lua
	mods/MAPGEN/grug_mapgen/wp13/gor_drazhak_district_market.lua
	mods/MAPGEN/grug_mapgen/wp13/gor_drazhak_district_martial.lua
	mods/MAPGEN/grug_mapgen/wp13/gor_drazhak_district_lore.lua
	mods/MAPGEN/grug_mapgen/wp13/gor_drazhak_district_homes.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_gor_drazhak_blueprint.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua
	tools/wp13/gor_drazhak_kat.lua
	tools/wp13/gor_drazhak_lots.lua
	tools/wp13/final_micro.lua
)

echo "== luac51 -p and SETGLOBAL, per touched file =="
for file in "${touched[@]}"; do
	"$luac" -p "$file"
	globals="$("$luac" -l -p "$file" | grep -c SETGLOBAL || true)"
	printf '%-62s parse=PASS setglobal=%s\n' "$file" "$globals"
done

echo
echo "== luac51 -p, whole mods and tools trees =="
find mods tools -name '*.lua' -print0 | xargs -0 -n 40 "$luac" -p
echo "all Lua parses under plain 5.1"

echo
echo "== SETGLOBAL, every grug mod file =="
total=0
while IFS= read -r file; do
	count="$("$luac" -l -p "$file" | grep -c SETGLOBAL || true)"
	total=$((total + count))
	[[ "$count" -eq 0 ]] || printf '%s: %s\n' "$file" "$count"
done < <(find mods/*/grug_* -name '*.lua')
printf 'grug mod SETGLOBAL writes: %s (the one global table per mod)\n' "$total"

echo
echo "== the five plain-5.1 sweeps, mods/*/grug_* =="
run_sweep() {
	local label="$1" pattern="$2"
	shift 2
	local hits
	hits="$(grep -rnE "$pattern" "$@" --include=*.lua || true)"
	if [[ -z "$hits" ]]; then
		printf '%s: clean\n' "$label"
	else
		printf '%s: READ THESE\n%s\n' "$label" "$hits"
	fi
}
run_sweep "1 goto/labels" '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' mods/*/grug_*
run_sweep "2 escapes" '\\u\{|\\x[0-9A-Fa-f]|\\z' mods/*/grug_*
run_sweep "3 5.2+ stdlib" 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' mods/*/grug_*
run_sweep "4 // and bitwise" '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' mods/*/grug_*
run_sweep "5 sandbox/namespace" '\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.' mods/*/grug_*

echo
echo "== the same five sweeps over tools/wp13 (not covered by the mod scope) =="
run_sweep "1 goto/labels" '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' tools/wp13
run_sweep "2 escapes" '\\u\{|\\x[0-9A-Fa-f]|\\z' tools/wp13
run_sweep "3 5.2+ stdlib" 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' tools/wp13
run_sweep "4 // and bitwise" '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' tools/wp13
run_sweep "5 sandbox/namespace" '\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.' tools/wp13

echo
echo "== fresh-server audit =="
python3 tools/check_fresh_server.py
