#!/usr/bin/env bash
# Static gates for the WP13 wave-2 NPC vocabulary lane, the same set every WP13
# increment runs: parser and SETGLOBAL per changed file and tree-wide, the five
# plain-5.1 sweeps scoped to the changed Lua and then tree-wide over
# mods/*/grug_* and tools, and the fresh-server audit.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
LUAC="$repo/tools/bin/luac51"

CHANGED=(
	mods/ENTITIES/grug_mobs/start_villagers.lua
	mods/ENTITIES/grug_mobs/start_npcs.lua
	mods/ENTITIES/grug_traders/vendors.lua
	mods/ENTITIES/grug_traders/stock.lua
	mods/ENTITIES/grug_traders/init.lua
	tools/wp13/start_npcs_kat.lua
	tools/wp13/npc_probe/init.lua
	tools/wp40/quality/vendor_fixture.lua
	tools/wp40/r7/micro_kat_fixture.lua
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

echo "== the shell harness parses =="
bash -n tools/wp13/run_npc_probe.sh && echo "run_npc_probe.sh syntax PASS"
bash -n tools/wp13/run_npc_load.sh && echo "run_npc_load.sh syntax PASS"

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

echo "== every profession shelf item is a name the engine really registers =="
# The list the engine boot of this lane dumped (items.txt in this directory) is
# the authority; this re-checks the shelves against it without a second boot.
python3 - <<'PYTHON'
import re, sys, os
here = os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else "."
dump = os.path.join("tools/wp13/evidence/20260915-npc-vocabulary", "items.txt")
known = set()
with open(dump) as handle:
    for line in handle:
        m = re.match(r"item=(\S+) sell=(\S+)", line)
        if m:
            known.add(m.group(1))
shelf = re.compile(r'^\t\{"([^"]+)", (\d+)')
missing = []
seen = 0
with open("mods/ENTITIES/grug_traders/stock.lua") as handle:
    for line in handle:
        m = shelf.match(line)
        if m:
            seen += 1
            if m.group(1) not in known:
                missing.append(m.group(1))
print("profession shelf entries checked:", seen)
print("names the engine does not register:", missing or "none")
sys.exit(1 if missing else 0)
PYTHON
echo "shelf item check exit: $?"
