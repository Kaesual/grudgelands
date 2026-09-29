-- Round 27 Lane M: the portable world of one seed for the world map base
-- (LuaJIT, no engine).
--
--   local W = dofile(repo .. "/tools/r27_minimap/world.lua")(repo, seed)
--
-- Mirrors `r7_runtime.lua` as far as the map base needs it: inland water,
-- the road network, main's capital planning (streets, canals, squares and the
-- protected cities joined exactly as the runtime joins them), then the zones
-- session (`zones.lua`, the height session reused from the capital planning)
-- wrapped in the R7 functional-anchor overlay, which is what `grug_zones`
-- publishes. Returns
--   zones     the public query surface base.lua reads (get, id_at,
--             water_class_at, terrain_height_at),
--   wp40      the fields base.lua reads from grug_mapgen.wp40
--             (road_polylines, river_polylines, water_layout_text),
--   session, seconds = {capitals, world}.
return function(repo, seed)
	seed = tostring(seed)
	local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	_G.core = _G.core or {}
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local sha = common.new_sha256()
	local tdata = dofile(dir .. "/terrain_data.lua")
	local source = dofile(dir .. "/source/simple_map.lua")
	local schemas = dofile(dir .. "/schemas.lua")
	local canonical = dofile(dir .. "/canonical.lua")
	local deterministic = dofile(dir .. "/deterministic.lua")
	local terrain_field = dofile(dir .. "/terrain_field.lua")(tdata)
	local simple_map_factory = dofile(dir .. "/simple_map.lua")(dofile(dir .. "/zone_field.lua"))
	local capital_protection = dofile(dir .. "/capital_protection.lua")
	local protection_holder = {}
	local function horizontal_factory(deps)
		local bound = {}
		for k, v in pairs(deps) do bound[k] = v end
		bound.capital_protection = protection_holder
		return simple_map_factory(bound)
	end
	local water = {module = dofile(dir .. "/water_layout.lua")(tdata.water),
		authored = dofile(dir .. "/water_authored.lua")(tdata.water)}
	local roads = {module = dofile(dir .. "/road_layout.lua")}
	local reuse = {}
	local settlement = dofile(dir .. "/r7_settlement.lua")
	local palette = dofile(dir .. "/../wp13/palette.lua")
	local TWIN = {["default:dirt_with_dry_grass"] = "default:dry_dirt_with_dry_grass"}
	local start_grounds = {}
	for _, profile in ipairs(settlement.roster) do
		if profile.slot == "start" then
			local ground = palette.races[profile.race].ground
			start_grounds[profile.anchor_id] = {ground = TWIN[ground] or ground}
		end
	end
	local hf = dofile(dir .. "/height.lua")
	local function height_factory(deps)
		local bound = {}
		for k, v in pairs(deps) do bound[k] = v end
		bound.water, bound.roads, bound.reuse = water, roads, reuse
		bound.start_grounds = start_grounds
		return hf(bound)
	end

	-- The capital layouts, planned as main plans them (r7_runtime.lua).
	local t0 = os.clock()
	local capitals = dofile(dir .. "/r7_capitals.lua")(dir)
	local profiles, kits, plots = {}, {}, {}
	for _, profile in ipairs(settlement.roster) do
		if profile.slot == "capital" then
			profiles[#profiles + 1] = profile
			local kit = capitals.source.kit(profile.key)
			kits[profile.key] = kit
			for _, plot in ipairs(kit.plots) do
				plots[profile.key .. "_" .. plot.id] = settlement.prepare_plot(profile, plot, sha)
			end
		end
	end
	local planning_horizontal = horizontal_factory({source = source, schemas = schemas,
		canonical = canonical, deterministic = deterministic, raw_sha256 = sha}).new(seed)
	local planning_session = height_factory({source = source, canonical = canonical,
		deterministic = deterministic, raw_sha256 = sha,
		horizontal_session = planning_horizontal,
		terrain_field = terrain_field}).new_runtime(seed)
	local capital_text = capitals.plan_all({seed = seed, session = planning_session,
		roads = roads.module, anchors = source.anchors, profiles = profiles, kits = kits,
		prepared = plots, authored = water.authored, simplex = terrain_field.simplex,
		proxy = tdata.water.LAKE_PROXY})
	reuse.session, reuse.seed = planning_session, seed
	local layouts = capitals.parse(capital_text)
	local civic_lakes = {}
	for _, profile in ipairs(profiles) do
		local lake_id = kits[profile.key].cfg.lake
		if lake_id then
			for _, row in ipairs(water.authored) do
				if row.id == lake_id then civic_lakes[profile.anchor_id] = row end
			end
		end
	end
	capital_protection.install(protection_holder, layouts, civic_lakes)
	for _, profile in ipairs(profiles) do
		local entry = assert(layouts[profile.anchor_id], "capital layout missing")
		if entry.layout.canal then
			water.authored[#water.authored + 1] = capitals.canal_row(
				"canal_" .. profile.key, entry.layout.anchor, entry.layout.canal,
				tdata.water.LAKE_PROXY)
		end
	end
	local t1 = os.clock()

	-- The world session, overlaid as grug_zones publishes it.
	local zones_module = dofile(dir .. "/zones.lua")({source = source,
		schemas = schemas, canonical = canonical, deterministic = deterministic,
		index128 = dofile(dir .. "/index128.lua"), horizontal_factory = horizontal_factory,
		height_factory = height_factory, terrain_field = terrain_field, raw_sha256 = sha})
	local raw_session, planner_source = zones_module.new_with_planner_source_runtime(seed, 1)
	local roster = dofile(dir .. "/r7_anchor_roster.lua")(source, raw_session,
		planner_source, sha)
	local session = dofile(dir .. "/r7_zone_overlay.lua")(raw_session, roster)
	local t2 = os.clock()

	local zones = {}
	for _, name in ipairs({"get", "id_at", "water_class_at", "terrain_height_at"}) do
		zones[name] = function(...) return session[name](...) end
	end
	local wp40 = {
		water_layout_text = water.cache.text,
		river_polylines = water.cache.sampler.polylines(),
		road_polylines = roads.module.polylines(roads.module.deserialize(roads.cache.text)),
	}
	return {zones = zones, wp40 = wp40, session = session, source = source,
		seconds = {capitals = t1 - t0, world = t2 - t1}}
end
