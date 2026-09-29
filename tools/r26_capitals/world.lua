-- Round 26 Lane W: the capital planning phase of a world's first boot, per
-- seed, without the engine (LuaJIT). Mirrors `r7_runtime.lua` exactly as
-- tools/r25_capital_plots/harness.lua does: the horizontal + height session,
-- inland water, road layout, main's plot preparations, `r7_capitals.plan_all`
-- -- against the repo tree given as <repo>, so the same file runs main and a
-- branch.
--
--   local W = dofile(".../tools/r26_capitals/world.lua")(repo)
--   local run = W.plan(seed)   -- {session, plans = {key -> plan}, inputs,
--                              --  text, stats, seconds}
--
-- `plans[key]` is the planner's own return table (outline, gates, wall,
-- streets, plots, left_out, stats); `inputs[key]` the planner inputs (the
-- plot kit with required flags). After `plan`, the session answers the final
-- ground with the capital streets and canals joined (terrain_height_at,
-- water_surface_at, road_column_at), which is what the renderer rasters.
return function(repo)
	local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	_G.core = _G.core or {}
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local raw_sha256 = common.new_sha256()

	local source = dofile(dir .. "/source/simple_map.lua")
	local schemas = dofile(dir .. "/schemas.lua")
	local canonical = dofile(dir .. "/canonical.lua")
	local deterministic = dofile(dir .. "/deterministic.lua")
	local terrain_data = dofile(dir .. "/terrain_data.lua")
	local terrain_field = dofile(dir .. "/terrain_field.lua")(terrain_data)
	local simple_map_factory = dofile(dir .. "/simple_map.lua")(dofile(dir .. "/zone_field.lua"))
	local height_module_factory = dofile(dir .. "/height.lua")
	local settlement = dofile(dir .. "/r7_settlement.lua")
	local capitals = dofile(dir .. "/r7_capitals.lua")(dir)
	local planner = capitals.planner
	local palette = dofile(dir .. "/../wp13/palette.lua")
	local TWIN = {["default:dirt_with_dry_grass"] = "default:dry_dirt_with_dry_grass"}
	local start_grounds = {}
	for _, profile in ipairs(settlement.roster) do
		if profile.slot == "start" then
			local ground = palette.races[profile.race].ground
			start_grounds[profile.anchor_id] = {ground = TWIN[ground] or ground}
		end
	end

	-- plot preparations are seed-independent: once per process
	local profiles, kits, prepared, key_of = {}, {}, {}, {}
	for _, profile in ipairs(settlement.roster) do
		if profile.slot == "capital" then
			profiles[#profiles + 1] = profile
			key_of[profile.anchor_id] = profile.key
			local kit = capitals.source.kit(profile.key)
			kits[profile.key] = kit
			for _, plot in ipairs(kit.plots) do
				prepared[profile.key .. "_" .. plot.id] = settlement.prepare_plot(profile, plot, raw_sha256)
			end
		end
	end

	local W = {planner = planner, capitals = capitals, profiles = profiles, kits = kits,
		key_of = key_of, source = source, sha256 = raw_sha256}

	function W.plan(seed)
		local plans, inputs, order = {}, {}, {}
		local original_plan = planner.plan
		planner.plan = function(s, I, opt)
			local plan = original_plan(s, I, opt)
			local key = key_of[I.anchor.id] or I.anchor.id
			plans[key], inputs[key] = plan, I
			order[#order + 1] = key
			-- a missing required plot fails the load in plan_all; the images
			-- still want the other capitals, so stand in (as the Lane H harness)
			local have = {}
			for _, p in ipairs(plan.plots) do have[p.id] = true end
			plan.missing_required = {}
			local stand_ins = {}
			for _, p in ipairs(I.plots) do
				if p.required and not have[p.id] then
					plan.missing_required[#plan.missing_required + 1] = p.id
					local copy = {}
					for k, v in pairs(plan.plots[1]) do copy[k] = v end
					copy.id, copy.required, copy.stand_in = p.id, true, true
					stand_ins[#stand_ins + 1] = copy
				end
			end
			for _, c in ipairs(stand_ins) do plan.plots[#plan.plots + 1] = c end
			return plan
		end
		local t0 = os.clock()
		local water = {module = dofile(dir .. "/water_layout.lua")(terrain_data.water),
			authored = dofile(dir .. "/water_authored.lua")(terrain_data.water)}
		local roads = {module = dofile(dir .. "/road_layout.lua")}
		local reuse = {}
		local protection_holder = {}
		local function horizontal_factory(deps)
			local bound = {}
			for k, v in pairs(deps) do bound[k] = v end
			bound.capital_protection = protection_holder
			return simple_map_factory(bound)
		end
		local function height_factory(deps)
			local bound = {}
			for k, v in pairs(deps) do bound[k] = v end
			bound.water, bound.roads, bound.reuse = water, roads, reuse
			bound.start_grounds = start_grounds
			return height_module_factory(bound)
		end
		local horizontal = horizontal_factory({source = source, schemas = schemas,
			canonical = canonical, deterministic = deterministic,
			raw_sha256 = raw_sha256}).new(seed)
		local session = height_factory({source = source, canonical = canonical,
			deterministic = deterministic, raw_sha256 = raw_sha256,
			horizontal_session = horizontal, terrain_field = terrain_field}).new_runtime(seed)
		local t_session = os.clock() - t0
		local ok, text, rows, stats = pcall(capitals.plan_all, {seed = seed, session = session,
			roads = roads.module, anchors = source.anchors, profiles = profiles, kits = kits,
			prepared = prepared, authored = water.authored,
			simplex = terrain_field.simplex, proxy = terrain_data.water.LAKE_PROXY})
		planner.plan = original_plan
		if not ok then error(text, 0) end
		return {session = session, horizontal = horizontal, plans = plans, inputs = inputs,
			order = order, text = text, rows = rows, stats = stats, water = water,
			seconds = {session = t_session, total = os.clock() - t0}}
	end

	return W
end
