-- Round 28 Lane C0 (zone facts atlas): the portable world of one seed
-- (LuaJIT, no engine), also tools/r27_minimap/world.lua. It hands out the
-- height session (coast material), the full road layout, the parsed capital
-- layouts and their protection shapes.
--
--   local W = dofile(repo .. "/tools/r28_zone_atlas/world.lua")(repo, seed)
--
-- Built as the runtime builds it (the shared `wp40/world_assembly.lua`):
-- inland water, the road network, main's capital planning (streets, canals,
-- squares and the protected cities), then the zones session (`zones.lua`,
-- the height session reused from the capital planning) wrapped in the R7
-- functional-anchor overlay, which is what `grug_zones` publishes. Returns
--   zones     the public query surface base.lua reads (get, id_at,
--             water_class_at, terrain_height_at),
--   wp40      the fields base.lua reads from grug_mapgen.wp40
--             (road_polylines, river_polylines, water_layout_text),
--   planner_source  the planner column source (column_values_at), as
--             grug_mapgen.wp40.planner_source,
--   session, seconds = {capitals, world}.
return function(repo, seed)
	seed = tostring(seed)
	local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	_G.core = _G.core or {}
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local sha = common.new_sha256()
	local A = dofile(dir .. "/world_assembly.lua")(dir, sha)

	-- The capital layouts, planned as main plans them.
	local t0 = os.clock()
	local W = A.world(seed)
	W.capitals()
	local t1 = os.clock()

	-- The world session, overlaid as grug_zones publishes it.
	local raw_session, planner_source = W.zones().new_with_planner_source_runtime(seed, 1)
	local roster = dofile(dir .. "/r7_anchor_roster.lua")(A.source, raw_session,
		planner_source, sha)
	local session = dofile(dir .. "/r7_zone_overlay.lua")(raw_session, roster)
	local t2 = os.clock()

	local zones = {}
	for _, name in ipairs({"get", "id_at", "water_class_at", "terrain_height_at"}) do
		zones[name] = function(...) return session[name](...) end
	end
	local water, roads = W.water, W.roads
	local wp40 = {
		water_layout_text = water.cache.text,
		river_polylines = water.cache.sampler.polylines(),
		road_polylines = roads.module.polylines(roads.module.deserialize(roads.cache.text)),
	}
	return {zones = zones, wp40 = wp40, session = session, source = A.source,
		planner_source = planner_source,
		height = W.planning_session, road_module = roads.module,
		road_layout = roads.module.deserialize(roads.cache.text),
		layouts = W.capital_layouts, capital_shapes = W.protection_holder.shapes,
		authored_water = water.authored, roster = roster, sha = sha,
		seconds = {capitals = t1 - t0, world = t2 - t1}}
end
