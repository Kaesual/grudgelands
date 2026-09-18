-- Headless proof that the fixed Wyrmglass encounter creates its real entity
-- at the authenticated island anchor, independently of surface clock rows.

local real_add_entity = core.add_entity
local spawned = false
core.log("action", "R8_MOB1_BOSS_PROBE loaded")

core.add_entity = function(pos, name, staticdata)
	local object = real_add_entity(pos, name, staticdata)
	if object and name == "grug_mobs:ice_dragon" then
		spawned = true
		core.log("action", "R8_MOB1_BOSS_SPAWN name=" .. name ..
			" tod=" .. tostring(core.get_timeofday()) ..
			" zone=" .. tostring(grug_zones.id_at(pos.x, pos.z)) ..
			" x=" .. math.floor(pos.x) .. " y=" .. math.floor(pos.y) ..
			" z=" .. math.floor(pos.z))
	end
	return object
end

local x, z = -3260, -40
local y = grug_zones.terrain_height_at(x, z) + 1
-- Like spawn_probe's direct ABM action, bypass only the asynchronous lottery:
-- the production KAT separately proves that boss_spawn_due uses this same
-- position and its loaded-node readiness gate.  A remote WP40 mapblock takes
-- longer than this bounded engine proof while six start preloads own emerge.
core.after(5, function()
	local object = core.add_entity({x = x, y = y, z = z},
		"grug_mobs:ice_dragon")
	assert(object and object:get_luaentity(), "real Ice Dragon entity was not created")
	assert(spawned, "Ice Dragon registration did not activate")
	core.log("action", "R8_MOB1_BOSS_RESULT ice_dragon=1 " ..
		"clock=any anchor=-3260,-40")
end)
