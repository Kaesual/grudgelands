#!/usr/bin/env bash
# Static gates for the mob-pressure lane (round 4, 2026-09-16): parser and
# SETGLOBAL per changed file and tree-wide, the five plain-5.1 sweeps scoped
# to the changed Lua and then tree-wide, the fresh-server audit, the WP40 R7
# unit suite, and the measurements the lane's note quotes.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
LUAC="$repo/tools/bin/luac51"

CHANGED=(
	mods/CORE/grug_core/movement.lua
	mods/CORE/grug_core/init.lua
	mods/ENTITIES/mobs/api.lua
	mods/ENTITIES/grug_mobs/verbs.lua
	mods/ENTITIES/grug_mobs/bandit.lua
	mods/ENTITIES/grug_mobs/bandit_archer.lua
	mods/ENTITIES/grug_mobs/camps.lua
	mods/ENTITIES/grug_mobs/golem.lua
	mods/ENTITIES/grug_mobs/init.lua
	mods/ENTITIES/grug_mobs/skeleton_archer.lua
	mods/ENTITIES/grug_mobs/skeleton_raider.lua
	mods/PLAYER/grug_abilities/kits.lua
	mods/PLAYER/grug_classes/selection.lua
	tools/wp11/move_aggregator_kat.lua
	tools/wp11/mob_cadence_kat.lua
	tools/wp11/cadence_probe/init.lua
	tools/wp11/ranged_probe/init.lua
	tools/wp45/character_creation_test.lua
)

echo "== parser and SETGLOBAL on every Lua file this lane changed =="
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
"$LUAC" -p mods/ENTITIES/mobs/api.lua && echo "vendored api.lua parser PASS"
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

echo "== five plain-5.1 sweeps, scoped to the Lua this lane changed =="
sweeps "${CHANGED[@]}"

echo "== the same five sweeps over all of mods/*/grug_* and tools =="
sweeps mods/*/grug_* tools

echo "== fresh server check =="
python3 tools/check_fresh_server.py

echo "== WP40 R7 unit suite =="
bash tools/wp40/r7/run.sh unit

echo "== physics_override has exactly one call site =="
grep -rn "set_physics_override" mods/ | grep -v '^[^:]*:[0-9]*:--' |
	grep -v '^[^:]*:[0-9]*:\s*--'

echo "== attack_type census =="
printf 'dogshoot sites: '; grep -rn 'attack_type *= *"dogshoot"' mods/ | wc -l
printf 'dogfight sites: '; grep -rn 'attack_type *= *"dogfight"' mods/ | wc -l
printf 'shoot sites:    '; grep -rn 'attack_type *= *"shoot"' mods/ | wc -l
printf 'register_mob:   '
grep -rn 'grug_mobs.register_mob("' mods/ENTITIES/grug_mobs/*.lua | wc -l

echo "== run_velocity table =="
# Both spellings: a def-table field and a variant file's `archer.run_velocity`.
grep -rhnE "^[[:space:]]*([A-Za-z_]+\.)?run_velocity = [0-9]" \
	mods/ENTITIES/grug_mobs/*.lua |
	sed 's/.*run_velocity = //' | sed 's/,.*//' | sort -n | uniq -c

echo "== view_range table =="
grep -rn "view_range = [0-9]" mods/ENTITIES/grug_mobs/*.lua

echo "== GRUG PATCH markers in the vendored api.lua =="
grep -c "GRUG PATCH" mods/ENTITIES/mobs/api.lua
