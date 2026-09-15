#!/usr/bin/env bash
# Static gates for the Dur Brannoc upgrade (WP13 wave 2, lane D): parser and
# SETGLOBAL per changed file and tree-wide, the five plain-5.1 sweeps scoped to
# the changed Lua and then tree-wide over mods/*/grug_* and tools, and the
# fresh-server audit. Same set every WP13 increment runs.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
LUAC="$repo/tools/bin/luac51"

CHANGED=(
	mods/MAPGEN/grug_mapgen/wp13/dur_brannoc.lua
	mods/MAPGEN/grug_mapgen/wp13/dur_brannoc_plot.lua
	mods/MAPGEN/grug_mapgen/wp13/dur_brannoc_quadrants.lua
	mods/MAPGEN/grug_mapgen/wp13/dur_brannoc_districts.lua
	mods/MAPGEN/grug_mapgen/wp13/dur_brannoc_district.lua
	mods/MAPGEN/grug_mapgen/wp13/dur_brannoc_district_martial.lua
	mods/MAPGEN/grug_mapgen/wp13/dur_brannoc_district_lore.lua
	mods/MAPGEN/grug_mapgen/wp13/dur_brannoc_district_homes.lua
	mods/MAPGEN/grug_mapgen/wp13/dwarf_dressing.lua
	mods/MAPGEN/grug_mapgen/wp40/r7_dur_brannoc_blueprint.lua
	tools/wp13/dur_brannoc_kat.lua
	tools/wp13/capital_lots.lua
	tools/wp13/capital_plots.lua
	tools/wp13/capital_timing.lua
	tools/wp13/capital_probe/init.lua
	tools/wp13/dump_capital_plan.lua
)

echo "== parser and SETGLOBAL on every Lua file this increment changed =="
for file in "${CHANGED[@]}"; do
	if "$LUAC" -p "$file" >/dev/null 2>&1; then
		globals="$("$LUAC" -p -l "$file" | grep -c SETGLOBAL)"
		echo "$file parser PASS; SETGLOBAL [$globals]"
	else
		echo "$file parser FAIL"
	fi
done

echo "== whole tree parses =="
find mods -name '*.lua' -path 'mods/*/grug_*' -print0 |
	xargs -0 "$LUAC" -p && echo "mods/*/grug_* parser PASS"
find tools -name '*.lua' -print0 | xargs -0 "$LUAC" -p &&
	echo "tools parser PASS"

echo "== every shell script this increment changed or added parses =="
for script in tools/wp13/run_capital.sh \
		tools/wp13/evidence/20260915-dur-brannoc-upgrade/static.sh \
		tools/wp13/evidence/20260915-dur-brannoc-upgrade/identity.sh \
		tools/wp13/evidence/20260915-dur-brannoc-upgrade/timing.sh \
		tools/wp13/evidence/20260915-dur-brannoc-upgrade/lots.sh \
		tools/wp13/evidence/20260915-dur-brannoc-upgrade/renders.sh \
		tools/wp13/evidence/20260915-dur-brannoc-upgrade/mutation.sh \
		tools/wp13/evidence/20260915-dur-brannoc-upgrade/open-capital-digest.sh \
		tools/wp13/evidence/20260915-dur-brannoc-upgrade/final-micro.sh \
		tools/wp13/evidence/20260915-dur-brannoc-upgrade/files.sha256.sh; do
	bash -n "$script" && echo "$script bash -n PASS"
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
	echo "SWEEPS DONE (no output above a SWEEP line means zero hits)"
}

echo "== five plain-5.1 sweeps, scoped to the Lua this increment changed =="
sweeps "${CHANGED[@]}"

echo "== the same five sweeps over all of mods/*/grug_* and tools =="
sweeps mods/*/grug_* tools

echo "== fresh server check =="
python3 tools/check_fresh_server.py
