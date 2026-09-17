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
		+ grug_classes.get_talent_bonus(player, "max_hp_add")
end

-- 0 for classes that use rage (or no class yet).
function grug_classes.get_max_mana(player)
	local def = grug_classes.get_class_def(player)
	if not def or def.resource ~= "mana" then
		return 0
	end
	local base = 10 + 2 * grug_classes.get_attributes(player).int
	-- Deep Well / Deep Reserve are PERCENT of the untalented pool, so the
	-- two Priest/Mage keys add rather than compound (skill_trees.md §2.3/§2.5).
	return math.floor(base * (1 + 0.01
		* grug_classes.get_talent_bonus(player, "max_mana_percent_add")))
end

-- Flat bonus added to weapon damage.
function grug_classes.get_melee_bonus(player)
	return math.floor(grug_classes.get_attributes(player).str / 10)
end

-- Flat bonus added to ability base values.
function grug_classes.get_spell_power_bonus(player)
	return math.floor(grug_classes.get_attributes(player).int / 10)
end

-- Raw chances are presentation accessors: the Talents page must show points
-- above the ordinary cap rather than making them look lost. Combat continues
-- to consume the capped accessors below. Lane X3 owns the time-limited cap
-- overrides and will make those consumers use their raised caps.
function grug_classes.get_crit_chance_raw(player)
	return 0.05 + 0.001 * grug_classes.get_attributes(player).dex
		+ 0.01 * (grug_classes.get_talent_bonus(player, "crit_chance_add")
			+ grug_classes.get_talent_bonus(player, "crit_chance_add_window"))
end

function grug_classes.get_dodge_chance_raw(player)
	return 0.001 * grug_classes.get_attributes(player).dex
		+ 0.01 * (grug_classes.get_talent_bonus(player, "dodge_chance_add")
			+ grug_classes.get_talent_bonus(player, "dodge_chance_window"))
end

-- Chances in 0..1; flat caps, no diminishing returns (combat_stats.md §2).
function grug_classes.get_crit_chance(player)
	return math.min(0.30, grug_classes.get_crit_chance_raw(player))
end

function grug_classes.get_dodge_chance(player)
	return math.min(0.30, grug_classes.get_dodge_chance_raw(player))
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
-- Native proportional melee Strength bonus (combat_stats.md §2); read by the
-- player-melee patch in mobs/api.lua and the hostile-PvP handler.
grug_core.get_melee_bonus = grug_classes.get_melee_bonus

-- FIRST equipment-change consumer. grug_classes is a dependency of both
-- grug_inventory and grug_abilities, so registering here is earlier by the mod
-- graph, not by incidental sibling-mod/alphabetical order. Stats are therefore
-- current before the Character-page and skin consumers run.
--
-- Keep the wrapper: registering apply_stats directly would pass `listname` as
-- its `heal_gain` argument and turn an equipment drag into unintended healing.
grug_core.register_on_equipment_change(function(player, listname)
	grug_classes.apply_stats(player)
end)

grug_xp.register_on_level_change(function(player, old_level, new_level)
	grug_classes.apply_stats(player,
		old_level ~= nil and new_level > old_level)
	-- Talent points (skill_trees.md §3.6): the point line on the way up, and
	-- ruling 20's free full reset when an admin /xp lowers a level. It lives
	-- in talents.lua, called from here so its order against apply_stats is
	-- fixed rather than incidental, and it carries the `old_level ~= nil`
	-- guard join needs.
	grug_classes.on_level_change_talents(player, old_level, new_level)
end)
