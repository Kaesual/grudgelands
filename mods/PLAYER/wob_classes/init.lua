wob_classes = {}

local META_CLASS = "wob_classes:class"
local META_RACE = "wob_classes:race"

--
-- Class registry (docs/design/combat_stats.md §1). Room for abilities (WP4)
-- and skill trees (WP11): later fields simply extend the class def.
--

wob_classes.registered_classes = {}
wob_classes.class_ids = {} -- registration order, used by the selection UI

function wob_classes.register_class(def)
	assert(def.id and def.name and def.growth, "incomplete class definition")
	wob_classes.registered_classes[def.id] = def
	table.insert(wob_classes.class_ids, def.id)
end

--
-- Race registry (docs/design/world.md §7). Light-weight layer: region
-- flavor + future vendor/profession perks hang off the race id.
--

wob_classes.registered_races = {}
wob_classes.race_ids = {} -- per faction, registration order

function wob_classes.register_race(def)
	assert(def.id and def.name and def.faction, "incomplete race definition")
	wob_classes.registered_races[def.id] = def
	wob_classes.race_ids[def.faction] = wob_classes.race_ids[def.faction] or {}
	table.insert(wob_classes.race_ids[def.faction], def.id)
end

--
-- Player accessors. Race and class live in player meta; a race that does
-- not match the player's current faction counts as unset (self-heals after
-- admin faction changes).
--

function wob_classes.get_class(player)
	local id = player:get_meta():get_string(META_CLASS)
	return wob_classes.registered_classes[id] and id or nil
end

function wob_classes.get_class_def(player)
	local id = wob_classes.get_class(player)
	return id and wob_classes.registered_classes[id] or nil
end

function wob_classes.set_class(player, id)
	if not wob_classes.registered_classes[id] then
		return false
	end
	player:get_meta():set_string(META_CLASS, id)
	-- heal_gain: a fresh character starts at full HP; admin switches are rare
	wob_classes.apply_stats(player, true)
	return true
end

function wob_classes.get_race(player)
	local id = player:get_meta():get_string(META_RACE)
	local def = wob_classes.registered_races[id]
	if def and def.faction == wob_factions.get_faction(player) then
		return id
	end
	return nil
end

function wob_classes.get_race_def(player)
	local id = wob_classes.get_race(player)
	return id and wob_classes.registered_races[id] or nil
end

function wob_classes.set_race(player, id)
	local def = wob_classes.registered_races[id]
	if not def or def.faction ~= wob_factions.get_faction(player) then
		return false
	end
	player:get_meta():set_string(META_RACE, id)
	return true
end

--
-- MVP classes (combat_stats.md §1): base 10/10/10, 4 growth points per
-- level. resource = "mana" | "rage" (HUD/regen lands with WP4).
--

wob_classes.register_class({
	id = "warrior",
	name = "Warrior",
	description = "Melee fighter and tank. Builds rage by dealing and\n" ..
		"taking blows; holds the enemy's attention.",
	growth = {str = 3, int = 0, dex = 1},
	resource = "rage",
})

wob_classes.register_class({
	id = "mage",
	name = "Mage",
	description = "Ranged spell damage. Fragile but deadly;\n" ..
		"fueled by a deep mana pool.",
	growth = {str = 0, int = 3, dex = 1},
	resource = "mana",
})

wob_classes.register_class({
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

wob_classes.register_race({
	id = "human", name = "Human", faction = "alliance",
	description = "At home on the central plains around the capital.",
})
wob_classes.register_race({
	id = "dwarf", name = "Dwarf", faction = "alliance",
	description = "Hardy folk from the pine hills of the west.",
})
wob_classes.register_race({
	id = "elf", name = "Elf", faction = "alliance",
	description = "Keepers of the deep forests in the east.",
})
wob_classes.register_race({
	id = "orc", name = "Orc", faction = "horde",
	description = "Raised in the central savanna around the capital.",
})
wob_classes.register_race({
	id = "troll", name = "Troll", faction = "horde",
	description = "Jungle hunters from the eastern wilds.",
})
wob_classes.register_race({
	id = "undead", name = "Undead", faction = "horde",
	description = "Risen from the blighted lands of the west.",
})

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/stats.lua")
dofile(modpath .. "/selection.lua")
