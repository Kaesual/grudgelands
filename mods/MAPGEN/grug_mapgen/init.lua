-- WP40 R7 production cutover. Legacy biome/ore/decoration/ocean/structure
-- loaders are deliberately absent: r7_loader owns the one reviewed native
-- allowlist, mapgen script, generated callback and VM transaction.

grug_mapgen = {}

local modpath = core.get_modpath(core.get_current_modname())
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
