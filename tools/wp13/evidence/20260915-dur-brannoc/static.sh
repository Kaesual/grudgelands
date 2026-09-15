#!/usr/bin/env bash
# Static gates for the WP13 Dur Brannoc package: the plain-5.1 parser, the
# SETGLOBAL count per touched file and tree-wide, and the five grep sweeps of
# docs/research/luanti-lua.md -- scoped first to the files this package touched
# and then to the whole WP13 surface.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
luac=tools/bin/luac51

touched=(
	mods/MAPGEN/grug_mapgen/wp13/wall.lua
	mods/MAPGEN/grug_mapgen/wp13/dur_brannoc.lua
	mods/MAPGEN/grug_mapgen/wp13/dur_brannoc_district.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_dur_brannoc_blueprint.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua
	tools/wp13/dur_brannoc_kat.lua
	tools/wp13/capital_plots.lua
	tools/wp13/capital_wall.lua
	tools/wp13/capital_timing.lua
	tools/wp13/capital_probe/init.lua
	tools/wp13/seam_kat.lua
	tools/wp13/highcourt_timing.lua
	tools/wp13/final_micro.lua
	tools/wp13/evidence/20260914-capital-parts/start_identity.lua
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
if [[ -x tools/check_fresh_server.py ]]; then
	python3 tools/check_fresh_server.py
elif [[ -f tools/check_fresh_server.py ]]; then
	python3 tools/check_fresh_server.py
else
	echo "no fresh-server audit in this tree"
fi
