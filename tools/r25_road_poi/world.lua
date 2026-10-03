-- Round 25 Lane E: the portable world of one seed with roads (LuaJIT).
--
--   local W = dofile(repo .. "/tools/r25_road_poi/world.lua")(repo, seed)
--
-- Builds the real zones.lua / simple_map.lua / height.lua session with the
-- water and ROAD layouts (the network roads and trails; the capital streets
-- are not planned here, and the capitals' protected cities are stood in by a
-- 241-node square round each capital anchor), the R7 anchor roster and
-- functional-anchor overlay, main's preparation of every POI, village and
-- camp blueprint (`r7_settlement.prepare`, as `r7_runtime.lua` does), and
-- the world protection exactly as `r7_loader.lua` builds it. Returns
--   session (the overlay-wrapped zones session), height (the height session:
--   natural_height_at), planner_source, source,
--   roads (the road module), road_text, layout (deserialized), built (the
--   layout as routed, with its stats and road ends), sampler
--   (the road sampler on that text), rows (settlement rows for the boxes),
--   protection (world_protection.new result), wp (the module), index128,
--   sha (raw SHA-256), seconds = {world, blueprints, protection}.
return function(repo, seed)
	local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local sha = common.new_sha256()
	local tdata = dofile(dir .. "/terrain_data.lua")
	local source = dofile(dir .. "/source/simple_map.lua")
	local simple_map_factory = dofile(dir .. "/simple_map.lua")(dofile(dir .. "/zone_field.lua"))
	local CITY_HALF = 120
	local shapes = {}
	for index = 1, #source.anchors do
		local anchor = source.anchors[index]
		if anchor.slot_id == "capital" then
			local ax, az = anchor.position.x, anchor.position.z
			shapes[anchor.id] = {member = function(x, z)
				return math.abs(x - ax) <= CITY_HALF and math.abs(z - az) <= CITY_HALF
			end}
		end
	end
	local protection_holder = {shapes = shapes}
	local function horizontal_factory(deps)
		local bound = {}
		for k, v in pairs(deps) do bound[k] = v end
		bound.capital_protection = protection_holder
		return simple_map_factory(bound)
	end
	local water = {module = dofile(dir .. "/water_layout.lua")(tdata.water),
		authored = dofile(dir .. "/water_authored.lua")(tdata.water), plot_rects = {}}
	local roads = {module = dofile(dir .. "/road_layout.lua")}
	local hf = dofile(dir .. "/height.lua")
	_G.core = _G.core or {}
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
	-- the height session itself is kept for the tools that ask the natural
	-- (pre-fitting) ground (`natural_height_at`)
	local held = {}
	local function height_factory(deps)
		local bound = {}
		for k, v in pairs(deps) do bound[k] = v end
		bound.water = water
		bound.roads = roads
		bound.start_grounds = start_grounds
		local module = hf(bound)
		local new_runtime = module.new_runtime
		if type(new_runtime) == "function" then
			module.new_runtime = function(...)
				local session = new_runtime(...)
				held.height = session
				return session
			end
			module.new = module.new_runtime
		end
		return module
	end
	local index128 = dofile(dir .. "/index128.lua")
	local t0 = os.clock()
	local zones = dofile(dir .. "/zones.lua")({source = source,
		schemas = dofile(dir .. "/schemas.lua"), canonical = dofile(dir .. "/canonical.lua"),
		deterministic = dofile(dir .. "/deterministic.lua"),
		index128 = index128, horizontal_factory = horizontal_factory,
		height_factory = height_factory,
		terrain_field = dofile(dir .. "/terrain_field.lua")(tdata), raw_sha256 = sha})
	local raw_session, planner_source = zones.new_with_planner_source_runtime(seed, 1)
	local roster = dofile(dir .. "/r7_anchor_roster.lua")(source, raw_session,
		planner_source, sha)
	local session = dofile(dir .. "/r7_zone_overlay.lua")(raw_session, roster)
	local t1 = os.clock()

	-- Main's preparation of every non-start, non-capital blueprint.
	local rows = {}
	local options = {full_seed = seed, raw_sha256 = sha}
	for _, profile in ipairs(settlement.roster) do
		if profile.slot ~= "start" and profile.slot ~= "capital" then
			local src = dofile(dir .. "/" .. profile.blueprint_file)(options, profile)
			if type(src) == "function" then src = src(options) end
			local prepared = settlement.prepare(profile, src, sha, nil)
			local anchor = session.anchor(profile.zone_id, profile.slot)
			assert(anchor and anchor.id == profile.anchor_id, "anchor " .. profile.key)
			-- the one blueprint's prefix is the settlement key (r7_settlement
			-- descriptors), the key of main's handover
			assert(prepared.blueprints[1].descriptor.prefix == profile.key)
			rows[#rows + 1] = {key = profile.key, slot = profile.slot, anchor = anchor,
				bounds = prepared.blueprints[1].bounds,
				template_id = source.anchors[profile.numeric_id].template_id}
		end
	end
	local t2 = os.clock()

	local wp = dofile(dir .. "/world_protection.lua")
	local road_text = roads.cache.text
	collectgarbage() collectgarbage()
	local memory_before = collectgarbage("count")
	local tp = os.clock()
	local protection = wp.new(index128, {
		corridors = wp.road_corridors(roads.module, road_text),
		boxes = wp.settlement_boxes(rows)})
	local t3 = os.clock()
	collectgarbage() collectgarbage()
	local memory_after = collectgarbage("count")
	local layout = roads.module.deserialize(road_text)
	return {session = session, raw_session = raw_session, height = held.height,
		planner_source = planner_source, source = source, roster = roster,
		roads = roads.module, road_text = road_text, layout = layout,
		built = roads.cache.layout,
		sampler = roads.module.sampler(layout), rows = rows,
		protection = protection, wp = wp, index128 = index128, sha = sha,
		common = common, settlement = settlement,
		memory_kib = memory_after - memory_before,
		seconds = {world = t1 - t0, blueprints = t2 - t1, protection = t3 - tp}}
end
