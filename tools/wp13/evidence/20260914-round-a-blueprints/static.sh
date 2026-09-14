#!/usr/bin/env bash
# Static gates for the WP13 round-A playtest fix round: parser and SETGLOBAL
# per file this round touched and tree-wide, the five plain-5.1 sweeps scoped
# to those files and then to wp13/, the changed wp40 files and tools/wp13, and
# the fresh-server audit.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
LUAC="$repo/tools/bin/luac51"

CHANGED=(
	mods/ITEMS/grug_nodes/init.lua
	mods/MAPGEN/grug_mapgen/wp13/buildings.lua
	mods/MAPGEN/grug_mapgen/wp13/dressing.lua
	mods/MAPGEN/grug_mapgen/wp13/layout.lua
	mods/MAPGEN/grug_mapgen/wp13/palette.lua
	mods/MAPGEN/grug_mapgen/wp13/parts.lua
	mods/MAPGEN/grug_mapgen/wp13/roofs.lua
	mods/MAPGEN/grug_mapgen/wp13/sunscar.lua
	tools/wp13/blueprint_kat.lua
	tools/wp13/library_kat.lua
)

echo "== parser and SETGLOBAL on every Lua file this round touched =="
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

echo "== five plain-5.1 sweeps, scoped to the Lua this round touched =="
sweeps "${CHANGED[@]}"

echo "== the same five sweeps over wp13/, the changed wp40 files and tools/wp13 =="
sweeps mods/MAPGEN/grug_mapgen/wp13 tools/wp13 \
	mods/ITEMS/grug_nodes/init.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_manifest.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_dawnmere_blueprint.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_hearthpine_blueprint.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_kapok_blueprint.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_silverleaf_blueprint.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_stillgrave_blueprint.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_sunscar_blueprint.lua \
	mods/MAPGEN/grug_mapgen/wp40/r7_wp13_library.lua

echo "== the changed Python file compiles =="
python3 -m py_compile tools/wp13/extract_tiles.py &&
	echo "tools/wp13/extract_tiles.py py_compile PASS"

echo "== node_tiles.json parses =="
python3 -c "import json; d = json.load(open('tools/wp13/node_tiles.json')); print('node_tiles.json nodes', len(d['nodes']))"

# The WP40 R7 source audit's changed-production roster, derived exactly the
# way `tools/wp40/r7/source_audit.sh` derives it. The whole audit still cannot
# pass, for two frozen expectations that belong to the WP40 lane and not to
# this one (the deleted-legacy-Lua population, and the durable micro-KAT
# binding that pins the old roster's SHA-256) -- see
# docs/research/wp13-dawnmere-fields.md. What the WP13 review asked for is
# this step, and this step is checked here.
echo "== WP40 R7 changed-production roster =="
derived="$(mktemp)"
{
	git -C "$repo" diff --name-only --diff-filter=AM d6002a2 -- mods
	git -C "$repo" ls-files --others --exclude-standard -- mods
} | sort -u | rg '[.]lua$' >"$derived"
derived_count="$(awk 'END {print NR + 0}' "$derived")"
expected_count="$(rg -o '\-eq ([0-9]+) \]\] \|\| \{' -r '$1' \
	tools/wp40/r7/source_audit.sh | head -n 1)"
if [[ "$derived_count" == "$expected_count" ]] &&
		cmp -s tools/wp40/r7/changed_production_lua.txt "$derived"; then
	echo "changed_production_lua roster PASS ($derived_count files, script expects $expected_count)"
else
	echo "changed_production_lua roster FAIL: derived $derived_count, script expects $expected_count"
	diff tools/wp40/r7/changed_production_lua.txt "$derived" | head -20
fi
rm -f -- "$derived"

echo "== fresh server check =="
python3 tools/check_fresh_server.py
