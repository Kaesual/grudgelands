#!/usr/bin/env bash
# Lane H (round 4) -- the HUD-bar KAT has to go RED when the rule is broken.
#
# Three mutations, one per way the user's ruling of 2026-09-16 can be lost:
# the half-heart statbar comes back, a mod guesses its own pixel offset
# again, and the fill is allowed to run past the end of the bar. Each is
# applied to the real source, the KAT is run, and the source is restored from
# a byte copy taken first (no git, so this is safe inside any worktree).
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo" || exit 1

KAT='io.write(dofile("tools/ui/hud_bars_kat.lua")("."))'
work="$(mktemp -d /tmp/grug-w4-H-mutation.XXXXXX)"
trap 'rm -rf "$work"' EXIT

run_kat() {
	luajit -e "$KAT" | grep -E 'hud_bars_result|hud_bars_failure' | head -4
}

mutate() {
	local label="$1" file="$2" script="$3"
	cp "$file" "$work/backup"
	python3 - "$file" "$script" <<'PYTHON'
import io, sys
path, script = sys.argv[1], sys.argv[2]
body = io.open(path, encoding="utf-8").read()
old, new = script.split("|||")
assert body.count(old) == 1, "mutation anchor is not unique in " + path
io.open(path, "w", encoding="utf-8").write(body.replace(old, new))
PYTHON
	echo "== MUTATION: $label ($file)"
	run_kat
	cp "$work/backup" "$file"
	echo "-- restored"
}

echo "== BASELINE (unmutated tree)"
run_kat

# 1. The rejected element type comes back.
mutate "a bar is drawn as a statbar again" \
	mods/CORE/grug_core/hud_layout.lua \
	'		type = "image",
		position = {x = layout.POSITION.x, y = layout.POSITION.y},|||		type = "statbar",
		position = {x = layout.POSITION.x, y = layout.POSITION.y},'

# 2. A consumer mod guesses its own offset again.
mutate "grug_xp writes its own pixel offset again" \
	mods/PLAYER/grug_xp/init.lua \
	'	hud_ids[player:get_player_name()] = player:hud_add(
		grug_core.hud_layout.text_element("xp", {
			number = 0xffd100,
			text = hud_text(player),
		}))|||	hud_ids[player:get_player_name()] = player:hud_add({
		type = "text",
		position = {x = 0.5, y = 1},
		offset = {x = 0, y = -110},
		alignment = {x = 0, y = 0},
		number = 0xffd100,
		text = hud_text(player),
	})'

# 3. The fill runs past the end of the bar (a scale over the full width).
#    Note that adding 1 to the ROUNDED value is not this mutation: the upper
#    guard absorbs it, which is the guard doing its job.
mutate "a full bar draws wider than the bar" \
	mods/CORE/grug_core/hud_layout.lua \
	'	if value >= maximum then
		return width
	end|||	if value >= maximum then
		return width + 1
	end'

# 4. The guard that keeps the last point visible is removed -- the exact
#    failure mode the user rejected, one step finer than half hearts. At 180
#    px the rounding alone still leaves 1 px for 1 of 325 hit points, so what
#    this actually catches is the DEEPEST pool in the game: the level-60
#    Mage's 384 mana (combat_stats.md section 2). That is the honest label.
mutate "one point of a 384-mana pool reads as an empty bar" \
	mods/CORE/grug_core/hud_layout.lua \
	'	if px < layout.MIN_FILL then
		px = layout.MIN_FILL
	elseif|||	if false then
		px = layout.MIN_FILL
	elseif'

echo "== FINAL (tree restored)"
run_kat
