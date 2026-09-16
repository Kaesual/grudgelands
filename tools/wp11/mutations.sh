#!/usr/bin/env bash
# Mutation proofs for tools/wp11/talent_tree_kat.lua (skill_trees.md §3.7's
# "mutation proof the review should demand"). Each mutation breaks ONE rule on
# purpose, runs the KAT, prints the failures it produced and restores the file
# from git, so the tree is clean again afterwards.
#
# Usage (from the repository root):  bash tools/wp11/mutations.sh
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$repo"

KAT='io.write(dofile("tools/wp11/talent_tree_kat.lua")("."))'

run_kat() {
	luajit -e "$KAT" 2>&1 | grep -E 'wp11_talents_(result|failure)'
}

# Restore from a byte copy taken here, NOT from version control: an
# uncommitted change in the file being mutated would otherwise be silently
# thrown away, which is exactly what happened the first time this script ran
# against a dirty tree.
mutate() {
	local label="$1" file="$2" from="$3" to="$4"
	echo "== MUTATION: $label =="
	local backup
	backup="$(mktemp /tmp/grug-wp11-mutation.XXXXXX)"
	cp -- "$file" "$backup"
	python3 - "$file" "$from" "$to" <<'PYTHON'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
assert text.count(old) == 1, "mutation anchor hit %d times" % text.count(old)
open(path, "w").write(text.replace(old, new))
PYTHON
	run_kat
	cp -- "$backup" "$file"
	rm -f -- "$backup"
	echo
}

echo "== BASELINE (clean tree) =="
run_kat
echo

mutate "a tier gate that lets a point through early (tier 3: 12 -> 9)" \
	mods/PLAYER/grug_classes/talents.lua \
	'grug_classes.TALENT_TIER_GATES = {0, 5, 12, 20}' \
	'grug_classes.TALENT_TIER_GATES = {0, 5, 9, 20}'

mutate "the hard chain stops being checked on a spend" \
	mods/PLAYER/grug_classes/talents.lua \
	'	local above = talent_above(def)
	if above and grug_classes.talent_rank(player, above.id) < above.ranks then' \
	'	local above = talent_above(def)
	if false and above and grug_classes.talent_rank(player, above.id) < above.ranks then'

mutate "the persistence read accepts an unknown talent id" \
	mods/PLAYER/grug_classes/talents.lua \
	'		local def = grug_classes.registered_talents[id]
		if def and talent_of_class(def, class_id) then
			local rank = math.floor(tonumber(value) or 0)
			if rank > def.ranks then
				rank = def.ranks
			end
			if rank > 0 then
				ranks[id] = rank
			end
		end' \
	'		local def = grug_classes.registered_talents[id]
			or grug_classes.registered_talents["ironbound"]
		if def and talent_of_class(def, class_id) then
			local rank = math.floor(tonumber(value) or 0)
			if rank > def.ranks then
				rank = def.ranks
			end
			if rank > 0 then
				ranks[def.id] = rank
			end
		end'

mutate "one add_rage site left on the retired 12" \
	mods/PLAYER/grug_abilities/init.lua \
	'		grug_abilities.add_rage(player, swing_rage(player) * (fraction or 1))' \
	'		grug_abilities.add_rage(player, 12 * (fraction or 1))'

mutate "the arm_cooldown talent read defaults to 1 instead of 0" \
	mods/PLAYER/grug_abilities/init.lua \
	'	local cooldown = def.cooldown or 0
	if def.cooldown_talent then' \
	'	local cooldown = (def.cooldown or 0) - 1
	if def.cooldown_talent then'

mutate "a tier-1 talent gets a sixth rank" \
	mods/PLAYER/grug_classes/talents.lua \
	'	effects = {armor_percent_add = {1, 2, 3, 4, 5}},' \
	'	effects = {armor_percent_add = {1, 2, 3, 4, 5, 6}},'

mutate "a window key leaks past its expiry" \
	mods/PLAYER/grug_classes/talents.lua \
	'	if core.get_us_time() > expiry then
		per_player[talent_id] = nil
		return false
	end
	return true' \
	'	return true'

mutate "a consumer stops reading its effect key" \
	mods/PLAYER/grug_classes/stats.lua \
	'		+ 0.01 * grug_classes.get_talent_bonus(player, "crit_chance_add"))' \
	'		)'

# The two the independent review of 2026-09-16 asked for by name: the seam
# that re-applies derived stats after a talent change (its absence was the
# review's one required fix), and ruling 20's free reset on a level drop.
mutate "a talent change no longer re-applies derived stats" \
	mods/PLAYER/grug_classes/talents.lua \
	'grug_classes.register_on_talents_changed(function(player)
	grug_classes.apply_stats(player)
end)' \
	'-- consumer removed on purpose'

mutate "an admin level drop stops returning the points" \
	mods/PLAYER/grug_classes/talents.lua \
	'		if spent > 0 then
			grug_classes.respec(player)' \
	'		if false and spent > 0 then
			grug_classes.respec(player)'

echo "== every mutated file is back to the bytes this script found =="
sha256sum mods/PLAYER/grug_classes/talents.lua \
	mods/PLAYER/grug_classes/stats.lua \
	mods/PLAYER/grug_abilities/init.lua
