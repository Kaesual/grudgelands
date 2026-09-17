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
-- The bottom-centre HUD column. Pure data plus arithmetic, depends on
-- nothing, and every HUD writer in the game reads it.
dofile(modpath .. "/hud_layout.lua")
dofile(modpath .. "/atmosphere.lua")
-- After atmosphere.lua (it extends that preset table) and before
-- zone_authority.lua, which only installs a seam grug_mapgen fills in later.
dofile(modpath .. "/atmosphere_zones.lua")
dofile(modpath .. "/zone_authority.lua")
-- After zone_authority.lua: it reads grug_core.start_identities(), which that
-- file publishes. The request itself waits for register_on_mods_loaded.
dofile(modpath .. "/starts_preload.lua")
-- The settlement NPC socket registry. After zone_authority.lua only because
-- everything in grug_core is loaded in dependency order; it needs nothing
-- from it, and grug_mapgen fills it once the authority is installed.
dofile(modpath .. "/settlement_sockets.lua")
dofile(modpath .. "/protection.lua")
dofile(modpath .. "/combat_debug.lua")
dofile(modpath .. "/combat_ray.lua")
dofile(modpath .. "/combat.lua")
-- After combat.lua: the aggregator reads grug_core.mono_time() (one clock for
-- every combat timer, see there). It is the ONLY writer of a player's
-- physics_override in the game -- grug_mobs, grug_abilities and grug_classes
-- all go through its named modifiers, root flag and exclusive hold
-- (skill_trees.md §3.9, rulings 11 and 26).
dofile(modpath .. "/movement.lua")

-- Actors collide with terrain but pass through other active objects. Mobs and
-- NPCs receive the matching property in the vendored mobs definition path.
-- This is intentionally a join-time object property, not persisted player
-- data; every player ObjectRef starts each session with the decided rule.
core.register_on_joinplayer(function(player)
	player:set_properties({collide_with_objects = false})
end)
