grug_classes = {}

local META_CLASS = "grug_classes:class"
local META_RACE = "grug_classes:race"

--
-- Class registry (docs/design/combat_stats.md §1). Room for abilities (WP4)
-- and skill trees (WP11): later fields simply extend the class def.
--

grug_classes.registered_classes = {}
grug_classes.class_ids = {} -- registration order, used by the selection UI

function grug_classes.register_class(def)
	assert(def.id and def.name and def.growth, "incomplete class definition")
	grug_classes.registered_classes[def.id] = def
	table.insert(grug_classes.class_ids, def.id)
end

--
-- Race registry (docs/design/world.md §7). Light-weight layer: region
-- flavor + future vendor/profession perks hang off the race id.
--

grug_classes.registered_races = {}
grug_classes.race_ids = {} -- per faction, registration order

function grug_classes.register_race(def)
	assert(def.id and def.name and def.faction, "incomplete race definition")
	grug_classes.registered_races[def.id] = def
	grug_classes.race_ids[def.faction] = grug_classes.race_ids[def.faction] or {}
	table.insert(grug_classes.race_ids[def.faction], def.id)
end

--
-- Player accessors. Race and class live in player meta; a race that does
-- not match the player's current faction counts as unset (self-heals after
-- admin faction changes).
--

function grug_classes.get_class(player)
	local id = player:get_meta():get_string(META_CLASS)
	return grug_classes.registered_classes[id] and id or nil
end

function grug_classes.get_class_def(player)
	local id = grug_classes.get_class(player)
	return id and grug_classes.registered_classes[id] or nil
end

local class_chosen_callbacks = {}

-- func(player, class_id) — called after a class was set (selection dialog
-- AND admin /class switches). grug_abilities grants the kit here.
function grug_classes.register_on_class_chosen(func)
	table.insert(class_chosen_callbacks, func)
end

function grug_classes.set_class(player, id)
	if not grug_classes.registered_classes[id] then
		return false
	end
	player:get_meta():set_string(META_CLASS, id)
	-- heal_gain: a fresh character starts at full HP; admin switches are rare
	grug_classes.apply_stats(player, true)
	for _, func in ipairs(class_chosen_callbacks) do
		func(player, id)
	end
	return true
end

function grug_classes.get_race(player)
	local id = player:get_meta():get_string(META_RACE)
	local def = grug_classes.registered_races[id]
	if def and def.faction == grug_factions.get_faction(player) then
		return id
	end
	return nil
end

function grug_classes.get_race_def(player)
	local id = grug_classes.get_race(player)
	return id and grug_classes.registered_races[id] or nil
end

function grug_classes.set_race(player, id)
	local def = grug_classes.registered_races[id]
	if not def or def.faction ~= grug_factions.get_faction(player) then
		return false
	end
	player:get_meta():set_string(META_RACE, id)
	return true
end

--
-- MVP classes (combat_stats.md §1): base 10/10/10, 4 growth points per
-- level. resource = "mana" | "rage" (HUD/regen lands with WP4).
--

grug_classes.register_class({
	id = "warrior",
	name = "Warrior",
	description = "Melee fighter and tank. Builds rage by dealing and\n" ..
		"taking blows; holds the enemy's attention.",
	growth = {str = 3, int = 0, dex = 1},
	resource = "rage",
})

grug_classes.register_class({
	id = "mage",
	name = "Mage",
	description = "Ranged spell damage. Fragile but deadly;\n" ..
		"fueled by a deep mana pool.",
	growth = {str = 0, int = 3, dex = 1},
	resource = "mana",
})

grug_classes.register_class({
	id = "priest",
	name = "Priest",
	description = "Healer and support. Keeps the group alive —\n" ..
		"and pulls aggro if the tank sleeps.",
	growth = {str = 1, int = 2, dex = 1},
	resource = "mana",
})

--
-- MVP races (world.md §7); own flavor names come later (no 1:1 copies).
--

-- Each race has ONE visible passive (world.md §7); the perk keys are
-- documented and consumed via perks.lua.

grug_classes.register_race({
	id = "human", name = "Human", faction = "accord",
	description = "At home on the central plains around the capital.\n" ..
		"Passive: +10% quest XP.",
	perks = {quest_xp_mult = 1.1},
})
grug_classes.register_race({
	id = "dwarf", name = "Dwarf", faction = "accord",
	description = "Hardy folk from the pine hills of the west.\n" ..
		"Passive: -20% fall damage.",
	perks = {fall_damage_mult = 0.8},
})
grug_classes.register_race({
	id = "elf", name = "Elf", faction = "accord",
	description = "Keepers of the deep forests in the east.\n" ..
		"Passive: +5 m ability range.",
	perks = {ability_range_bonus = 5},
})
grug_classes.register_race({
	id = "orc", name = "Orc", faction = "throng",
	description = "Raised in the central savanna around the capital.\n" ..
		"Passive: +1 rage per hit taken.",
	perks = {rage_per_hit_taken_bonus = 1},
})
grug_classes.register_race({
	id = "troll", name = "Troll", faction = "throng",
	description = "Jungle hunters from the eastern wilds.\n" ..
		"Passive: +50% regeneration out of combat.",
	perks = {ooc_regen_mult = 1.5},
})
grug_classes.register_race({
	id = "undead", name = "Undead", faction = "throng",
	description = "Risen from the blighted lands of the west.\n" ..
		"Passive: zombies ignore you at night (unless attacked).",
	perks = {zombie_night_truce = true},
})

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/stats.lua")
dofile(modpath .. "/perks.lua")
dofile(modpath .. "/selection.lua")
