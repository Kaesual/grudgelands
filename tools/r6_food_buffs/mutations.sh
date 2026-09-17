#!/usr/bin/env bash
# Reproducible FU6 mutation checks. Each mutation is applied only to a private
# temporary copy of the final production bytes; the worktree is never edited.
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$repo"

lua_bin="${MUTATION_LUA_BIN:-/usr/bin/luajit}"
scratch="$(mktemp -d /tmp/grug-r6-food-mutations.XXXXXX)"
cleanup() {
	rm -rf -- "$scratch"
}
trap cleanup EXIT

copy_case() {
	local name="$1"
	local root="$scratch/$name"
	local file
	for file in \
		mods/CORE/grug_core/hud_layout.lua \
		mods/CORE/grug_core/status.lua \
		mods/CORE/grug_core/combat.lua \
		mods/ITEMS/grug_food/init.lua \
		mods/PLAYER/grug_abilities/init.lua \
		mods/PLAYER/grug_abilities/kits.lua
	do
		mkdir -p -- "$root/$(dirname "$file")"
		cp -- "$file" "$root/$file"
	done
	printf '%s\n' "$root"
}

replace_once() {
	python3 - "$1" "$2" "$3" <<'PYTHON'
import sys

path, old, new = sys.argv[1:]
with open(path) as source:
    text = source.read()
assert text.count(old) == 1, "mutation anchor hit %d times" % text.count(old)
with open(path, "w") as target:
    target.write(text.replace(old, new))
PYTHON
}

run_kat() {
	GRUG_R6_MUTATION_ROOT="$1" "$lua_bin" -e \
		'io.write(dofile("tools/r6_food_buffs/kat.lua")(os.getenv("GRUG_R6_MUTATION_ROOT")))'
}

run_mutation() {
	local name="$1"
	local root
	local expected
	root="$(copy_case "$name")"
	case "$name" in
		mana)
			replace_once "$root/mods/PLAYER/grug_abilities/init.lua" \
				$'\tlocal after = math.min(maximum,\n\t\tbefore + math.max(0, tonumber(amount) or 0))' \
				$'\tlocal after = before -- mutation: restoration is disabled'
			expected="restore_mana returns actual amounts, clamps and updates the HUD"
			;;
		food_math)
			replace_once "$root/mods/ITEMS/grug_food/init.lua" \
				'math.floor(maximum * percent / 100)' \
				'math.ceil(maximum * percent / 100)'
			expected="tick math 325 x 2%"
			;;
		status_order)
			replace_once "$root/mods/CORE/grug_core/status.lua" \
				'return a.kind == "buff"' 'return a.kind == "debuff"'
			expected="buffs sort before debuffs"
			;;
		status_cap)
			replace_once "$root/mods/CORE/grug_core/status.lua" \
				'local STATUS_HUD_LIMIT = 8' 'local STATUS_HUD_LIMIT = 9'
			expected="HUD list capped at eight lines"
			;;
		hud_write)
			replace_once "$root/mods/CORE/grug_core/status.lua" \
				'if text ~= hud.text then' 'if true then'
			expected="HUD text writes only when changed"
			;;
		*)
			echo "unknown mutation: $name" >&2
			return 2
			;;
	esac

	echo "== MUTATION: $name =="
	local output
	output="$(run_kat "$root")"
	printf '%s\n' "$output"
	if [[ "$output" != *"$expected"* || "$output" != *"FAIL "* ]]; then
		echo "expected failure was not observed: $expected" >&2
		return 1
	fi
}

selection="${1:-all}"
echo "== BASELINE =="
baseline="$(run_kat "$repo")"
printf '%s\n' "$baseline"
if [[ "$baseline" != *$'\nPASS'* ]]; then
	echo "baseline KAT failed" >&2
	exit 1
fi
echo

if [[ "$selection" == "all" ]]; then
	for mutation in mana food_math status_order status_cap hud_write; do
		run_mutation "$mutation"
		echo
	done
else
	run_mutation "$selection"
fi
