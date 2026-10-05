-- Round 27 Lane M: the portable world of one seed for the world map base
-- (LuaJIT, no engine).
--
--   local W = dofile(repo .. "/tools/r27_minimap/world.lua")(repo, seed)
--
-- The world of tools/r28_zone_atlas/world.lua (built as the runtime builds
-- it, through the shared `wp40/world_assembly.lua`): inland water, the road
-- network, main's capital planning, then the zones session wrapped in the R7
-- functional-anchor overlay, which is what `grug_zones` publishes. Returns
-- (among the atlas fields)
--   zones     the public query surface base.lua reads (get, id_at,
--             water_class_at, terrain_height_at),
--   wp40      the fields base.lua reads from grug_mapgen.wp40
--             (road_polylines, river_polylines, water_layout_text),
--   session, seconds = {capitals, world}.
return function(repo, seed)
	return dofile(repo .. "/tools/r28_zone_atlas/world.lua")(repo, seed)
end
