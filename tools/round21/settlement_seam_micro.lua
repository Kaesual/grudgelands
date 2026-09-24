-- Real prepare/config/writer seam on a tiny composition, no roster builds.
return function(repo)
	local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
	local settlement = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua")
	local palette = dofile(wp13 .. "/palette.lua").new("human")
	local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
	local streets = dofile(wp13 .. "/street_plan.lua")(wp13)
	local function build(plot)
		local cells, names, seen = {}, {}, {}
		local min, max = {x = -2, y = 0, z = -2}, {x = 2, y = 3, z = 2}
		for z = -2, 2 do for y = 0, 3 do for x = -2, 2 do
			local name = y == 0 and "default:dirt_with_grass" or "air"
			cells[#cells + 1] = {x = x, y = y, z = z, name = name, param2 = 0}
			if not seen[name] then seen[name] = true; names[#names + 1] = name end
		end end end
		table.sort(names)
		return {schema = "micro_blueprint_v1", cells = cells, palette = names,
			bounds = {min = min, max = max}, reference = plot and {x = 0, z = 0} or nil,
			landmarks = plot and {plot = {min = min, max = max}, entry = {x = 0, y = 1, z = -1},
				sockets = {{id = "worker", role = "citizen", x = 0, y = 1, z = 0}}} or {}}
	end
	local runs = streets.attach({{id = "street", axis = "x", at = 10, from = -10, to = 10}})
	local source = {schema = "grug_wp13_capital_source_v1",
		core = {schema = "micro_blueprint_v1", build = function() return build(false) end},
		plots = {{id = "test", x = 0, z = 16, schema = "micro_blueprint_v1", build = function() return build(true) end}},
		overlay = {schema = "micro_overlay_v1", runs = runs, width = 5, reach = 40, lamp_spacing = 8,
			names = avenue.palette_names(palette), run = function(spec, surface) return avenue.run(palette, spec, surface) end}}
	local profile = {key = "micro", label = "Micro", race = "human", slot = "capital",
		bounds = "capital_core", plot_bounds = "capital_plot", zone_id = "micro", anchor_id = "anchor_999",
		numeric_id = 999, x = 0, z = 0, blueprint_file = "none.lua", blueprint_schema = "micro_blueprint_v1",
		identity_schema = "micro_blueprint_identity_v1", config_schema = "micro_config_v1",
		ledger_schema = "micro_ledger_v1", metrics_schema = "micro_metrics_v1", delta_schema = "micro_delta_v1",
		reserve_anchor_root = true}
	-- Hash correctness is outside this seam; stable framing is exercised by
	-- production prepare, using a bounded deterministic test digest.
	local function sha(s)
		local n = 0
		for i = 1, #s do n = (n * 31 + s:byte(i)) % 251 end
		return string.rep(string.char(n), 32)
	end
	local prepared = settlement.prepare(profile, source, sha)
	local refs = {}
	for i, name in ipairs(prepared.palette) do refs[name] = i end
	local content = {schema = "grug_wp13_settlement_content_v1", content_names = prepared.palette,
		content_ref = function(name) return refs[name] end, resolve = function(ref, param2) return ref, param2 end}
	local config = settlement.config(prepared, content, sha)
	local plot_level = 8
	local function ground(x, z) return (math.abs(x) <= 2 and z >= 14 and z <= 18) and plot_level or 10 end
	local deps = {zones_session = {anchor = function() return {id = "anchor_999", numeric_id = 999, x = 0, y = 10, z = 0} end},
		planner_source = {column_values_at = function(x, z) return "land", 1, "micro", "biome", "human", ground(x, z) end}}
	local function emit(x0, x1)
		local tail, plan = config.new(deps), {}
		local lo, hi = {x = x0, y = 0, z = -3}, {x = x1, y = 16, z = 27}
		tail:bind_plan(lo, hi, plan, 1)
		local result = {}
		local context = {plan = plan, generation = 1, min_x = lo.x, min_y = lo.y, min_z = lo.z,
			max_x = hi.x, max_y = hi.y, max_z = hi.z}
		function context.inside_owner(x, y, z)
			return x >= lo.x and x <= hi.x and y >= lo.y and y <= hi.y and z >= lo.z and z <= hi.z
		end
		function context.write_hearthpine(x, y, z, cid, param2)
			assert(context.inside_owner(x, y, z))
			result[x .. ":" .. y .. ":" .. z] = prepared.palette[cid] .. ":" .. param2
		end
		local ledger = tail:settle(context)
		if plot_level == 8 then
			assert(#ledger.approach_findings == 0, table.concat(ledger.approach_findings, "; "))
		else assert(#ledger.approach_findings == 1, "impossible approach was hidden") end
		return result
	end
	local whole, left, right = emit(-12, 12), emit(-12, -1), emit(0, 12)
	for k, v in pairs(right) do assert(not left[k]); left[k] = v end
	for k, v in pairs(whole) do assert(left[k] == v, "seam chunk mismatch " .. k) end
	for k, v in pairs(left) do assert(whole[k] == v, "seam excess " .. k) end
	assert(not whole["0:11:0"], "anchor root overwritten")
	for z = 12, 14 do
		local top = 22 - z
		assert(whole["0:" .. top .. ":" .. z] and not whole["0:" .. top .. ":" .. z]:match("^air"), "entry floor missing")
		for y = top + 1, top + 3 do
			local cell = whole["0:" .. y .. ":" .. z]
			assert(cell == nil or cell == "air:0", "entry headroom blocked")
		end
	end
	local sockets = settlement.sockets(prepared, {x = 0, y = 10, z = 0}, ground)
	assert(sockets[1].y == -1, "plot socket projection changed")
	plot_level = 6
	emit(-12, 12)
	return "round21_settlement_seam\tprepare+config=real\tsplit=equal\troot=preserved\tentry=clear\n"
end
