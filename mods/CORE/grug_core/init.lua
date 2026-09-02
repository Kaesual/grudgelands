grug_core = {}

-- Player-facing faction identity remains core-owned. World coordinates,
-- ownership, levels and anchors are installed later by the validated WP40
-- session; this module deliberately contains no fallback world geometry.
grug_core.factions = {
	accord = {
		id = "accord",
		name = "Accord",
		color = "#3f6fce",
		seat_race = "human",
	},
	throng = {
		id = "throng",
		name = "Throng",
		color = "#c41e3a",
		seat_race = "orc",
	},
}

grug_core.faction_ids = {"accord", "throng"}

function grug_core.opposing_faction(faction_id)
	return faction_id == "accord" and "throng" or "accord"
end

-- Resolved by grug_factions. Keeping the stub here preserves the acyclic
-- dependency: grug_core never depends on a player mod.
function grug_core.get_player_faction(name)
	return nil
end

-- Resolved by grug_classes through the same stub-override pattern.
function grug_core.get_player_race(name)
	return nil
end

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/zone_authority.lua")
dofile(modpath .. "/protection.lua")
dofile(modpath .. "/combat_debug.lua")
dofile(modpath .. "/combat_ray.lua")
dofile(modpath .. "/combat.lua")
