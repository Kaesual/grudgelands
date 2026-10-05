-- Round 26 Lane W: the capital planning phase of a world's first boot, per
-- seed, without the engine (LuaJIT), built as the runtime builds it (the
-- shared `wp40/world_assembly.lua`, like tools/r25_capital_plots/harness.lua):
-- the horizontal + height session, inland water, road layout, main's plot
-- preparations, `r7_capitals.plan_all` -- against the repo tree given as
-- <repo>, so the same file runs main and a branch.
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
	local A = dofile(dir .. "/world_assembly.lua")(dir, raw_sha256)
	local capitals = A.capitals
	local planner = capitals.planner
	local key_of = {}
	for _, profile in ipairs(A.capital_profiles) do key_of[profile.anchor_id] = profile.key end
	-- plot preparations are seed-independent: once per process
	A.capital_plots()

	local W = {planner = planner, capitals = capitals, profiles = A.capital_profiles,
		kits = A.capital_kits, key_of = key_of, source = A.source, sha256 = raw_sha256}

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
		local world = A.world(seed)
		local ok, err = pcall(world.plan_capitals)
		planner.plan = original_plan
		if not ok then error(err, 0) end
		return {session = world.planning_session, horizontal = world.planning_horizontal,
			plans = plans, inputs = inputs, order = order, text = world.capital_layout_text,
			rows = world.capital_rows, stats = world.capital_stats, water = world.water,
			seconds = {total = os.clock() - t0}}
	end

	return W
end
