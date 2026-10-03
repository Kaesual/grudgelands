-- WP40 R7 production cutover. Legacy biome/ore/decoration/ocean/structure
-- loaders are deliberately absent: r7_loader owns the one reviewed native
-- allowlist, mapgen script, generated callback and VM transaction.

grug_mapgen = {}

local modpath = core.get_modpath(core.get_current_modname())
-- LuaJIT side-exit tuning before the construction below (jit_tuning.lua).
dofile(modpath .. "/jit_tuning.lua")()
dofile(modpath .. "/world_nodes.lua")(core, modpath, grug_nodes, grug_gathering)
dofile(modpath .. "/poi_displays.lua")(core)
grug_mapgen.wp40 = dofile(modpath .. "/wp40/r7_loader.lua")(
	core, modpath, grug_materials, grug_gathering, grug_core)

-- Planned water flow for grug_core's water guard (world_zones.md §7.4): at a
-- step between two planned inland surfaces, river or canal, the higher water
-- flows over the lower one. That flow is generated world, also inside
-- protected territory: a position above a wet planned column and no higher
-- than the highest planned surface among its four neighbours.
do
	local column_values_at = grug_mapgen.wp40.planner_source.column_values_at
	local function planned_surface(x, z)
		local _, _, _, _, _, terrain_y, water_y, water_id = column_values_at(x, z)
		if water_id ~= nil and water_y ~= nil and water_y > terrain_y then
			return water_y
		end
		return nil
	end
	local NEIGHBOUR_X, NEIGHBOUR_Z = {1, -1, 0, 0}, {0, 0, 1, -1}
	grug_core.register_planned_water_flow(function(pos)
		local x, y, z = pos.x, pos.y, pos.z
		local own = planned_surface(x, z)
		if own == nil or y <= own then return false end
		for direction = 1, 4 do
			local surface = planned_surface(x + NEIGHBOUR_X[direction],
				z + NEIGHBOUR_Z[direction])
			if surface ~= nil and y <= surface then return true end
		end
		return false
	end)
end

-- Boot memory (Round 30 P3): the construction above leaves several hundred
-- MiB of garbage; collecting it here, before the other mods load and the
-- region maps and the map base are made, lowers the server's peak memory
-- (VmHWM, measured 2.12 -> 1.76 GB on a first start, 1.84 -> 1.71 GB on a
-- later one). The heap after a full collection at the first server step is
-- logged as a regression guard.
do
	local loaded, started = collectgarbage("count"), core.get_us_time()
	collectgarbage("collect")
	core.log("action", ("[grug_mapgen] Lua heap after loading %.0f MiB, %.0f MiB after a " ..
		"full collection (%.0f ms)"):format(loaded / 1024, collectgarbage("count") / 1024,
		(core.get_us_time() - started) / 1000))
	core.after(0, function()
		-- A first start's whole-world sweeps (the world layouts, the map base,
		-- the region maps, the zone grid) leave the bounded query caches full;
		-- a later start reads those from the world folder and never fills
		-- them. Emptied here, the session starts with the same heap either
		-- way (Round 31 C); queries at runtime refill what they use.
		grug_mapgen.wp40.planner_source.drop_caches()
		collectgarbage("collect")
		core.log("action", ("[grug_mapgen] Lua heap at the first server step after a full " ..
			"collection: %.0f MiB"):format(collectgarbage("count") / 1024))
	end)
end
