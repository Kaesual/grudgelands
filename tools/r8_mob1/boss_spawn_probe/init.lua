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
-- Emerge the production anchor, then enter through the exported production
-- due-spawner.  Its loaded-node readiness check, authenticated anchor lookup,
-- real add_entity call, runtime boss fields and persistent alive gate all run.
core.register_on_mods_loaded(function()
	core.after(0, function()
		core.emerge_area({x = x, y = y, z = z}, {x = x, y = y, z = z},
			function(_, _, remaining)
				if remaining ~= 0 then return end
				assert(grug_mobs.boss_spawn_due("wyrmglass"),
					"production Wyrmglass due-spawner refused the ready anchor")
				assert(spawned, "Ice Dragon registration did not activate")
				core.log("action", "R8_MOB1_BOSS_RESULT ice_dragon=1 " ..
					"clock=any anchor=-3260,-40")
				core.request_shutdown("R8-MOB1 boss spawn probe complete", false, 0)
			end)
	end)
end)
