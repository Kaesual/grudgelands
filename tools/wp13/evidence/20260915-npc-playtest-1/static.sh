#!/usr/bin/env bash
# Static gates for WP13 playtest round 1 (settlement NPC behaviour): the
# plain-5.1 parser, the SETGLOBAL count per touched file and tree-wide, the five
# grep sweeps of docs/research/luanti-lua.md -- scoped first to the files this
# round touched and then to the whole WP13 surface -- and the fresh-server audit.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
luac=tools/bin/luac51

touched=(
	mods/ENTITIES/grug_mobs/init.lua
	mods/ENTITIES/grug_mobs/verbs.lua
	mods/ENTITIES/grug_mobs/levels.lua
	mods/ENTITIES/grug_mobs/patrol.lua
	mods/ENTITIES/grug_mobs/guard.lua
	mods/ENTITIES/grug_mobs/start_npcs.lua
	mods/ENTITIES/grug_mobs/start_villagers.lua
	mods/ENTITIES/grug_traders/vendors.lua
	tools/wp13/start_npcs_kat.lua
	tools/wp13/npc_probe/init.lua
)

echo "== luac51 -p and SETGLOBAL, per touched file =="
for file in "${touched[@]}"; do
	"$luac" -p "$file"
	globals="$("$luac" -l -p "$file" | grep -c SETGLOBAL || true)"
	printf '%-58s parse=PASS setglobal=%s\n' "$file" "$globals"
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

sweeps() {
	run_sweep "1 goto/labels" '(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::' "$@"
	run_sweep "2 escapes" '\\u\{|\\x[0-9A-Fa-f]|\\z' "$@"
	run_sweep "3 5.2+ stdlib" 'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.' "$@"
	run_sweep "4 // and bitwise" '[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]' "$@"
	run_sweep "5 sandbox/namespace" '\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.' "$@"
}

echo
echo "== the five plain-5.1 sweeps, the touched mod files =="
sweeps mods/ENTITIES/grug_mobs mods/ENTITIES/grug_traders

echo
echo "== the same five sweeps, mods/*/grug_* (the whole shipped surface) =="
sweeps mods/*/grug_*

echo
echo "== the same five sweeps over tools/wp13 (not covered by the mod scope) =="
sweeps tools/wp13

echo
echo "== fresh-server audit =="
python3 tools/check_fresh_server.py
