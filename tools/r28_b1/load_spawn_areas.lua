-- Round 28 Lane B1 (Lane S1: spawn_regions.lua): load the real grug_mobs
-- per-zone spawn data (palettes, recipes) into the CURRENT global stubs of a
-- portable fixture, before that fixture loads spawn_policy.lua, which reads
-- its palettes from it.
--
--   dofile(repo .. "/tools/r28_b1/load_spawn_areas.lua")(repo)
--
-- Only what spawn_regions.lua touches at load is supplied, for the duration
-- of the load, and restored afterwards: the data directory listing, a JSON
-- decoder, the two registration hooks, settings, the level overlay seam and
-- grug_zones.get with the 38 zone records of the mapgen's own source. Whatever stubs the fixture
-- already has stay untouched otherwise.
return function(repo)
	local json = dofile(repo .. "/tools/r28_b1/json.lua")
	local mobs_dir = repo .. "/mods/ENTITIES/grug_mobs"
	local data_dir = mobs_dir .. "/data/zones"
	local source = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")
	-- The gameplay bands, as grug_zones serves them (zone_bands.lua).
	local zone_bands = dofile(repo .. "/mods/CORE/grug_core/zone_bands.lua")
	local records, files = {}, {}
	for _, zone in ipairs(source.zones) do
		records[zone.id] = zone_bands.apply({macro_region = zone.macro_region, hub = zone.hub,
			level_min = zone.level_min, level_max = zone.level_max}, zone.id)
		local f = io.open(data_dir .. "/" .. zone.id .. ".spawns.json")
		if f then
			f:close()
			files[#files + 1] = zone.id .. ".spawns.json"
		end
	end
	local function noop() end
	local core_fields = {
		get_modpath = function() return mobs_dir end,
		get_current_modname = function() return "grug_mobs" end,
		get_dir_list = function() return files end,
		parse_json = json.parse,
		register_globalstep = noop,
		register_on_mods_loaded = noop,
		settings = {get = function() return nil end, get_bool = function() return nil end},
	}
	local saved_core = {}
	for key, value in pairs(core_fields) do
		saved_core[key] = rawget(core, key)
		rawset(core, key, value)
	end
	local saved_get = rawget(grug_zones, "get")
	rawset(grug_zones, "get", function(zone_id) return records[zone_id] end)
	local saved_overlay = rawget(grug_core, "register_level_overlay")
	rawset(grug_core, "register_level_overlay", function() end)
	local ok, err = pcall(dofile, mobs_dir .. "/spawn_regions.lua")
	for key in pairs(core_fields) do
		rawset(core, key, saved_core[key])
	end
	rawset(grug_zones, "get", saved_get)
	rawset(grug_core, "register_level_overlay", saved_overlay)
	if not ok then error(err, 0) end
	return grug_mobs.spawn_regions
end
