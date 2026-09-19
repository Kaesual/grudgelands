#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
lua_bin="${MUTATION_LUA_BIN:-luajit}"
scratch="$(mktemp -d /tmp/grug-r7-food-mutations.XXXXXX)"
cleanup() {
	rm -rf -- "$scratch"
}
trap cleanup EXIT

copy_case() {
	local name="$1"
	local target="$scratch/$name"
	local file
	for file in \
		mods/CORE/grug_core/status.lua \
		mods/CORE/grug_core/combat.lua \
		mods/CORE/grug_core/starts_preload.lua \
		mods/ITEMS/grug_food/init.lua \
		mods/PLAYER/grug_classes/stats.lua \
		mods/PLAYER/grug_abilities/init.lua \
		mods/PLAYER/grug_abilities/kits.lua \
		mods/PLAYER/grug_inventory/equipment.lua
	do
		mkdir -p -- "$target/$(dirname "$file")"
		cp -- "$root/$file" "$target/$file"
	done
	printf '%s\n' "$target"
}

replace_once() {
	python3 - "$1" "$2" "$3" <<'PYTHON'
import sys
path, old, new = sys.argv[1:]
with open(path, encoding="utf-8") as source:
    text = source.read()
assert text.count(old) == 1, "mutation anchor hit %d times" % text.count(old)
with open(path, "w", encoding="utf-8") as target:
    target.write(text.replace(old, new))
PYTHON
}

run_kat() {
	local candidate="$1"
	R7_ROOT="$candidate" R7_KAT="$root/tools/r7_food/kat.lua" "$lua_bin" -e \
		'io.write(dofile(os.getenv("R7_KAT"))(os.getenv("R7_ROOT")))'
}

mutate() {
	local name="$1"
	local target expected output
	target="$(copy_case "$name")"
	case "$name" in
		tier)
		replace_once "$target/mods/ITEMS/grug_food/init.lua" \
			'[6] = {instant_hp = 300, min_level = 51' \
			'[6] = {instant_hp = 301, min_level = 51'
		expected="tier table shape T6"
		;;
		raw)
		replace_once "$target/mods/ITEMS/grug_food/init.lua" \
			'return {regen = {[role] = 1}, modifiers = {}}' \
			'return {regen = {[role] = 2}, modifiers = {}}'
		expected="raw rule T1"
		;;
	dish)
		replace_once "$target/mods/ITEMS/grug_food/init.lua" \
			'caster = {regen = {hp = 3.5, mana = 3.5},
			modifiers = {mana_pool_percent = 4}},' \
			'caster = {regen = {hp = 3.5, mana = 3.6},
			modifiers = {mana_pool_percent = 4}},'
		expected="dish table rule"
		;;
		deferral)
		replace_once "$target/mods/ITEMS/grug_food/init.lua" \
			'if grug_core.in_combat(player) then' \
			'if false then'
		expected="combat pauses instant and regeneration"
		;;
		expiry_deferral)
		replace_once "$target/mods/ITEMS/grug_food/init.lua" \
			'if player and player:get_hp() > 0 and not grug_core.in_combat(player) then' \
			'if player and grug_core.get_status(player, "food") and player:get_hp() > 0 and not grug_core.in_combat(player) then'
		expected="expired food pays deferred instant exactly once out of combat"
		;;
		spell_damage)
		replace_once "$target/mods/PLAYER/grug_abilities/kits.lua" \
			'return math.floor(amount * (1 + percent / 100) + 0.5)' \
			'return math.floor(amount + 0.5)'
		expected="spell damage percent raises Fireball only"
		;;
		modifiers)
		replace_once "$target/mods/CORE/grug_core/status.lua" \
			'total = total + (ordered[index].modifiers[key] or 0)' \
			'total = total + 0'
		expected="status modifiers reach stat accessors"
		;;
		level_gate)
		replace_once "$target/mods/CORE/grug_core/combat.lua" \
			'return current >= required, required, current' \
			'return true, required, current'
		expected="consumable level gate refuses without consuming"
		;;
		label)
		replace_once "$target/mods/ITEMS/grug_food/init.lua" \
			'regen[#regen] = regen[#regen] .. "/" .. grug_food.INTERVAL .. "s"' \
			'regen[#regen] = regen[#regen] .. " per " .. grug_food.INTERVAL .. "s"'
		expected="buff labels state effects"
		;;
		tooltip)
		replace_once "$target/mods/ITEMS/grug_food/init.lua" \
			'Instant heal and regeneration wait until you are out of combat; other bonuses stay.' \
			'Instant healing works in combat.'
		expected="food tooltip text"
		;;
		regen)
		replace_once "$target/mods/PLAYER/grug_abilities/init.lua" \
			'local rate = 1 + 0.15 * level' \
			'local rate = 1 + 0.16 * level'
		expected="mana regen curve L1"
		;;
		troll_combat)
		replace_once "$target/mods/PLAYER/grug_abilities/init.lua" \
			'return combat_rate * (1 + 2 * bonus)' \
			'return combat_rate * (grug_classes.get_race_perk(player, "ooc_regen_mult") or 1) * (1 + 2 * bonus)'
		expected="mana regen curve L1"
		;;
		preload)
		replace_once "$target/mods/CORE/grug_core/starts_preload.lua" \
			'storage:set_int(PRELOAD_MARKER, 1)' \
			'-- mutation: marker write removed'
		expected="fresh preload did not persist after six starts"
		;;
		*)
		echo "unknown mutation: $name" >&2
		return 2
		;;
	esac
	output="$(run_kat "$target")"
	printf '== %s ==\n%s\n' "$name" "$output"
	if [[ "$output" != *"FAIL "* || "$output" != *"$expected"* ]]; then
		echo "expected failure not observed: $expected" >&2
		return 1
	fi
}

baseline="$(run_kat "$root")"
printf '== baseline ==\n%s\n' "$baseline"
[[ "$baseline" == *$'\nPASS' ]] || exit 1

selection="${1:-all}"
if [[ "$selection" == "all" ]]; then
	for name in tier raw dish deferral expiry_deferral spell_damage modifiers level_gate label tooltip regen troll_combat preload; do
		mutate "$name"
	done
	MUTATION_LUA_BIN="$lua_bin" bash \
		"$root/tools/r6_food_buffs/mutations.sh" all
else
	mutate "$selection"
fi
