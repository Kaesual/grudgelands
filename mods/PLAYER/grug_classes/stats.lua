-- Attribute and derived-stat formulas (combat_stats.md §1/§2), applied via
-- the grug_xp level pipeline. Ability/mana HUDs and the damage pipeline that
-- consumes melee/spell/crit values arrive with WP4; the accessors below are
-- their single source of truth.

local BASE_ATTR = 10

function grug_classes.get_attributes(player)
	local level = grug_xp.get_level(player)
	local def = grug_classes.get_class_def(player)
	local g = def and def.growth or {}
	return {
		str = BASE_ATTR + (g.str or 0) * (level - 1),
		int = BASE_ATTR + (g.int or 0) * (level - 1),
		dex = BASE_ATTR + (g.dex or 0) * (level - 1),
	}
end

function grug_classes.get_max_hp(player)
	return 20 + 2 * (grug_xp.get_level(player) - 1)
		+ grug_classes.get_attributes(player).str
end

-- 0 for classes that use rage (or no class yet).
function grug_classes.get_max_mana(player)
	local def = grug_classes.get_class_def(player)
	if not def or def.resource ~= "mana" then
		return 0
	end
	return 10 + 2 * grug_classes.get_attributes(player).int
end

-- Flat bonus added to weapon damage.
function grug_classes.get_melee_bonus(player)
	return math.floor(grug_classes.get_attributes(player).str / 10)
end

-- Flat bonus added to ability base values.
function grug_classes.get_spell_power_bonus(player)
	return math.floor(grug_classes.get_attributes(player).int / 10)
end

-- Chances in 0..1; flat caps, no diminishing returns (combat_stats.md §2).
function grug_classes.get_crit_chance(player)
	return math.min(0.30, 0.05 + 0.001 * grug_classes.get_attributes(player).dex)
end

function grug_classes.get_dodge_chance(player)
	return math.min(0.30, 0.001 * grug_classes.get_attributes(player).dex)
end

-- Recomputes hp_max from level + class. heal_gain grants the gained
-- maximum as healing — ONLY for real level-ups/class picks; the join
-- callback must not pass it (properties reset to engine defaults every
-- session, so healing the join delta would make relogging a free heal).
function grug_classes.apply_stats(player, heal_gain)
	local max_hp = grug_classes.get_max_hp(player)
	local old_max = player:get_properties().hp_max
	if old_max == max_hp then
		return
	end
	player:set_properties({hp_max = max_hp})
	local hp = player:get_hp()
	if heal_gain and hp > 0 and max_hp > old_max then
		player:set_hp(hp + max_hp - old_max)
	elseif hp > max_hp then
		player:set_hp(max_hp)
	end
end

-- Wire the real rolls into grug_core's damage pipeline (stub override,
-- same pattern as grug_core.get_player_faction).
grug_core.get_crit_chance = grug_classes.get_crit_chance
grug_core.get_dodge_chance = grug_classes.get_dodge_chance
-- Auto-attack Strength bonus (combat_stats.md §2); read by the weapon-cadence
-- patch in mobs/api.lua on_punch.
grug_core.get_melee_bonus = grug_classes.get_melee_bonus

grug_xp.register_on_level_change(function(player, old_level, new_level)
	grug_classes.apply_stats(player,
		old_level ~= nil and new_level > old_level)
end)
