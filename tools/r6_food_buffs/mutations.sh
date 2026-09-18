#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
lua_bin="${MUTATION_LUA_BIN:-luajit}"
scratch="$(mktemp -d /tmp/grug-r6-status-mutations.XXXXXX)"
cleanup() {
	rm -rf -- "$scratch"
}
trap cleanup EXIT

copy_case() {
	local name="$1"
	local target="$scratch/$name"
	local file
	for file in \
		mods/CORE/grug_core/hud_layout.lua \
		mods/CORE/grug_core/status.lua \
		mods/CORE/grug_core/combat.lua \
		mods/PLAYER/grug_abilities/init.lua \
		mods/PLAYER/grug_abilities/kits.lua
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
	R6_ROOT="$1" R6_KAT="$root/tools/r6_food_buffs/kat.lua" "$lua_bin" -e \
		'io.write(dofile(os.getenv("R6_KAT"))(os.getenv("R6_ROOT")))'
}

mutate() {
	local name="$1"
	local target expected output
	target="$(copy_case "$name")"
	case "$name" in
		mana)
		replace_once "$target/mods/PLAYER/grug_abilities/init.lua" \
			$'\tlocal after = math.min(maximum,\n\t\tbefore + math.max(0, tonumber(amount) or 0))' \
			$'\tlocal after = before -- mutation: restoration disabled'
		expected="restore_mana returns actual amounts, clamps and updates the HUD"
		;;
		status_order)
		replace_once "$target/mods/CORE/grug_core/status.lua" \
			'return a.kind == "buff"' 'return a.kind == "debuff"'
		expected="buffs sort before debuffs"
		;;
		status_cap)
		replace_once "$target/mods/CORE/grug_core/status.lua" \
			'local STATUS_HUD_LIMIT = 8' 'local STATUS_HUD_LIMIT = 9'
		expected="HUD list capped at eight lines"
		;;
		hud_write)
		replace_once "$target/mods/CORE/grug_core/status.lua" \
			'if text ~= hud.text then' 'if true then'
		expected="HUD text writes only when changed"
		;;
		potion_mirror)
		replace_once "$target/mods/CORE/grug_core/status.lua" \
			'if left > 0 then' 'if false then'
		expected="persistent potion cooldown mirrored"
		;;
		renew_cleanup)
		replace_once "$target/mods/PLAYER/grug_abilities/kits.lua" \
			$'core.register_on_dieplayer(function(player)\n\trenews[player:get_player_name()] = nil\nend)' \
			$'core.register_on_dieplayer(function(player)\n\t-- mutation: private Renew record retained\nend)'
		expected="death clears Renew status and private record"
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
	for name in mana status_order status_cap hud_write potion_mirror renew_cleanup; do
		mutate "$name"
	done
else
	mutate "$selection"
fi
