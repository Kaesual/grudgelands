-- Disposable headless probe for the Highcourt capital (WP13 seam
-- generalisation). Staged into a scratch game copy by
-- `tools/wp13/run_highcourt.sh`; never shipped with the game, never loaded by
-- a normal server.
--
-- It answers, in one boot, the five engine questions the seam package owes:
--
--   1. THE SURFACE UNDER EVERY DISTRICT PLOT. `grug_zones.terrain_height_at` is
--      the same pure final height the writer projects a plot from, so the
--      footprint of each plot is sampled column by column and the fall from its
--      reference column reported. The plot skirt reaches 6 nodes down, so a
--      plot whose footprint falls further than that stands on air (the M2
--      hand-off of docs/research/wp13-highcourt.md section 7).
--   2. BUILD TIME ON FIRST TOUCH. The capital's cells are built lazily, so the
--      composition is timed here in the main environment under the engine's own
--      LuaJIT, which is the same work the emerge thread does on the first
--      mapchunk that touches the envelope.
--   3. THE PER-MAPCHUNK COST. The mapchunks the capital's blueprints and
--      avenues actually touch are emerged ONE AT A TIME, in a fixed order, and
--      each one is timed; control mapchunks outside the envelope and one over
--      the Dawnmere start give the baseline the contract's "no more than 2x the
--      ~0.5 s Dawnmere chunk" is measured against.
--   4. THE NPC ROSTER. The socket registry is inventoried per role, and the
--      placement engine's own log lines are what the run script counts.
--   5. HIGHCOURT AS BUILT. Three TSV dumps the renderer can draw, read back
--      from the finished map: the core region, one district plot, and a band
--      along an avenue so the road over the terraces can be looked at.
--
-- Plain Lua 5.1.

grug_wp13_highcourt_probe = {}

local KEY = "highcourt"
local worldpath = core.get_worldpath()
-- The fitted capital anchor, filled in once the world authority is installed.
local anchor_x, anchor_y, anchor_z
local mode = core.settings:get("grug_wp13_probe_mode") or "full"
local timeout_seconds =
	tonumber(core.settings:get("grug_wp13_probe_timeout")) or 900

local function fail(message)
	error("grug_wp13_highcourt_probe: " .. message, 0)
end
if mode ~= "surface" and mode ~= "full" and mode ~= "scan" then
	fail("mode must be surface, scan or full")
end

local function log(fields)
	local parts = {"GRUG_WP13_HIGHCOURT"}
	for index = 1, #fields do parts[#parts + 1] = fields[index] end
	core.log("action", table.concat(parts, " "))
end

local function chunk_origin(value)
	local block = math.floor(value / 16)
	return (math.floor((block + 2) / 5) * 5 - 2) * 16
end

--
-- The capital's own geometry, read from the production seam rather than
-- restated: the roster profile, the plot offsets and the avenue runs.
--
local wp40 = core.get_modpath("grug_mapgen") .. "/wp40"
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local profile
for index = 1, #settlement.roster do
	if settlement.roster[index].key == KEY then profile = settlement.roster[index] end
end
if not profile then fail("the roster has no " .. KEY) end
local plot_bounds = settlement.BOUNDS[profile.plot_bounds]
local core_bounds = settlement.BOUNDS[profile.bounds]

local build_us = {}
local function timed(label, body)
	local started = core.get_us_time()
	local result = body()
	build_us[#build_us + 1] = label .. "=" .. (core.get_us_time() - started)
	return result
end

local source = timed("module_load", function()
	local loaded = dofile(wp40 .. "/" .. profile.blueprint_file)
	return loaded()
end)
-- Built and dropped: what is measured is the build, which is exactly the work
-- the emerge thread does on the first mapchunk that touches the envelope.
timed("core", source.core.build)
local plots = {}
for index = 1, #source.plots do
	local plot = source.plots[index]
	plots[index] = {id = plot.id, x = plot.x, z = plot.z,
		composition = timed("plot_" .. plot.id, plot.build)}
end
local overlay = source.overlay

--
-- 1. The surface under every plot footprint.
--
-- The SKIRT is the perimeter only (`wp13/highcourt_district.lua`: "only the
-- perimeter is skirted, because a solid block of both would cost a plot four
-- thousand cells of buried stone"), so the fall that decides whether a plot
-- stands on air is the fall under its PERIMETER. The whole footprint is
-- measured beside it, because an interior column far below the floor is a
-- two-node floor over a void -- not visible, but worth knowing -- and because a
-- RISE anywhere under the plot is what the plot's own airspace clear has to
-- cover.
local function surface_report()
	local rows = {"plot\treference_x\treference_z\treference_y" ..
		"\tperimeter_min\tperimeter_max\tperimeter_fall\tperimeter_rise" ..
		"\tfootprint_min\tfootprint_max\tfootprint_fall\tfootprint_rise" ..
		"\tclear_to\tcolumns\n"}
	local worst_fall, worst_plot = 0, "-"
	for index = 1, #plots do
		local plot = plots[index]
		local bounds = plot.composition.bounds
		local reference = plot.composition.reference
		local origin_x, origin_z = anchor_x + plot.x, anchor_z + plot.z
		local reference_y = grug_zones.terrain_height_at(origin_x + reference.x,
			origin_z + reference.z)
		local min_y, max_y = reference_y, reference_y
		local edge_min, edge_max, columns = reference_y, reference_y, 0
		for z = bounds.min.z, bounds.max.z do
			for x = bounds.min.x, bounds.max.x do
				local y = grug_zones.terrain_height_at(origin_x + x, origin_z + z)
				if y < min_y then min_y = y end
				if y > max_y then max_y = y end
				if x == bounds.min.x or x == bounds.max.x or z == bounds.min.z or
						z == bounds.max.z then
					if y < edge_min then edge_min = y end
					if y > edge_max then edge_max = y end
				end
				columns = columns + 1
			end
		end
		local fall = reference_y - edge_min
		if fall > worst_fall then worst_fall, worst_plot = fall, plot.id end
		rows[#rows + 1] = table.concat({plot.id, origin_x + reference.x,
			origin_z + reference.z, reference_y,
			edge_min, edge_max, fall, edge_max - reference_y,
			min_y, max_y, reference_y - min_y, max_y - reference_y,
			bounds.max.y, columns}, "\t") .. "\n"
	end
	return table.concat(rows), worst_fall, worst_plot
end

-- A candidate sweep for a plot that has to be MOVED: the perimeter fall and
-- rise its footprint would see at every position on a coarse grid of the
-- capital's own quadrant. Two seeds' sweeps intersected is what decides a new
-- position, because a plot that only stands on one world's terrain has not been
-- fixed. The geometric constraints (envelope, gate corridors, street runs, the
-- other plots) are applied afterwards, outside the engine, where the whole
-- composition is in one place.
local function scan_report()
	local rows = {"plot\tx\tz\tperimeter_fall\tperimeter_rise\n"}
	for index = 1, #plots do
		local plot = plots[index]
		local bounds = plot.composition.bounds
		local reference = plot.composition.reference
		for z = -96, 96, 4 do
			for x = 52, 204, 4 do
				local origin_x, origin_z = anchor_x + x, anchor_z + z
				local reference_y = grug_zones.terrain_height_at(
					origin_x + reference.x, origin_z + reference.z)
				local edge_min, edge_max = reference_y, reference_y
				for ez = bounds.min.z, bounds.max.z do
					for ex = bounds.min.x, bounds.max.x do
						if ex == bounds.min.x or ex == bounds.max.x or
								ez == bounds.min.z or ez == bounds.max.z then
							local y = grug_zones.terrain_height_at(origin_x + ex,
								origin_z + ez)
							if y < edge_min then edge_min = y end
							if y > edge_max then edge_max = y end
						end
					end
				end
				rows[#rows + 1] = table.concat({plot.id, x, z,
					reference_y - edge_min, edge_max - reference_y}, "\t") .. "\n"
			end
		end
	end
	return table.concat(rows)
end

--
-- The mapchunk corpus: exactly the mapchunks the capital touches, plus the
-- controls. Derived from the real geometry, deduplicated, in a fixed order.
--
local function corpus()
	local boxes = {}
	local function box(id, min_x, max_x, min_y, max_y, min_z, max_z)
		boxes[#boxes + 1] = {id = id, min_x = min_x, max_x = max_x,
			min_y = min_y, max_y = max_y, min_z = min_z, max_z = max_z}
	end
	box("core", anchor_x + core_bounds.min.x, anchor_x + core_bounds.max.x,
		anchor_y + core_bounds.min.y, anchor_y + core_bounds.max.y,
		anchor_z + core_bounds.min.z, anchor_z + core_bounds.max.z)
	for index = 1, #plots do
		local plot = plots[index]
		local base = grug_zones.terrain_height_at(
			anchor_x + plot.x + plot.composition.reference.x,
			anchor_z + plot.z + plot.composition.reference.z)
		local bounds = plot.composition.bounds
		box("plot_" .. plot.id, anchor_x + plot.x + bounds.min.x,
			anchor_x + plot.x + bounds.max.x, base + bounds.min.y,
			base + bounds.max.y, anchor_z + plot.z + bounds.min.z,
			anchor_z + plot.z + bounds.max.z)
	end
	-- Every avenue and ring run, seven columns wide, over the height band the
	-- terraced envelope can put the road in. The four gate stations sit at the
	-- far end of the four avenues, so the corridors are covered by the runs.
	local half = (overlay.width - 1) / 2 + 1
	for index = 1, #overlay.runs do
		local run = overlay.runs[index]
		local min_x, max_x, min_z, max_z
		if run.axis == "x" then
			min_x, max_x = run.from, run.to
			min_z, max_z = run.at - half, run.at + half
		else
			min_z, max_z = run.from, run.to
			min_x, max_x = run.at - half, run.at + half
		end
		local low, high = anchor_y, anchor_y
		for step = 0, 8 do
			local along = min_x + math.floor((max_x - min_x) * step / 8)
			local across = min_z + math.floor((max_z - min_z) * step / 8)
			local y = grug_zones.terrain_height_at(anchor_x + along, anchor_z + across)
			if y < low then low = y end
			if y > high then high = y end
		end
		box("run_" .. run.id, anchor_x + min_x, anchor_x + max_x, low - 4,
			high + 4, anchor_z + min_z, anchor_z + max_z)
	end
	local ordered, seen = {}, {}
	local function add(id, kind, x, y, z)
		local key = x .. ":" .. y .. ":" .. z
		if seen[key] then return end
		seen[key] = true
		ordered[#ordered + 1] = {id = id, kind = kind, key = key,
			x = x, y = y, z = z}
	end
	local function add_box(id, kind, entry)
		for z = chunk_origin(entry.min_z), chunk_origin(entry.max_z), 80 do
			for y = chunk_origin(entry.min_y), chunk_origin(entry.max_y), 80 do
				for x = chunk_origin(entry.min_x), chunk_origin(entry.max_x), 80 do
					add(id, kind, x, y, z)
				end
			end
		end
	end
	-- WARM-UP FIRST, and not counted. The emerge environment builds the whole R7
	-- assembly on its first mapchunk -- the content channel, the R6 session and
	-- this package's own identity pass over every settlement -- and that is a
	-- once-per-process cost that would otherwise be charged to whichever
	-- mapchunk happened to be first.
	local warm_y = grug_zones.terrain_height_at(1500, 700)
	add("warmup", "warmup", chunk_origin(1500), chunk_origin(warm_y),
		chunk_origin(700))
	-- THE SAME TERRAIN WITHOUT THIS PACKAGE'S CELLS. Lethariel is a capital too,
	-- so WP40 fits, flattens, terraces and protects it exactly like Highcourt --
	-- and it has no WP13 blueprints at all. The difference between the two
	-- capitals' mapchunks is therefore the cost of the capital SETTLEMENT, which
	-- is what this package owns; comparing a capital mapchunk with open land
	-- would charge the terracing to the seam.
	local control_capital = grug_core.capital_anchor("accord", "elf")
	if type(control_capital) ~= "table" then fail("control capital differs") end
	add_box("control_capital_lethariel", "control_capital", {
		min_x = control_capital.x + core_bounds.min.x,
		max_x = control_capital.x + core_bounds.max.x,
		min_y = control_capital.y + core_bounds.min.y,
		max_y = control_capital.y + core_bounds.max.y,
		min_z = control_capital.z + core_bounds.min.z,
		max_z = control_capital.z + core_bounds.max.z})
	for index = 1, #boxes do
		add_box(boxes[index].id, "capital", boxes[index])
	end
	-- Controls: two mapchunks no settlement can reach, and one over the Dawnmere
	-- start, which is the contract's own per-chunk reference.
	local controls = {
		{"control_open_land", 900, 900},
		{"control_open_land_far", 1220, 780},
		{"control_dawnmere_start", 0, -2550},
	}
	for index = 1, #controls do
		local entry = controls[index]
		local y = grug_zones.terrain_height_at(entry[2], entry[3])
		add(entry[1], "control", chunk_origin(entry[2]), chunk_origin(y),
			chunk_origin(entry[3]))
	end
	if #ordered > 160 then fail("the Highcourt corpus is unbounded: " .. #ordered) end
	return ordered
end

--
-- 5. The dumps, read back from the finished map in ANCHOR-RELATIVE coordinates
-- so `tools/wp13/render_blueprint.py` draws them the way it draws a
-- composition dump.
--
local function dump(name, min_x, max_x, min_y, max_y, min_z, max_z, header)
	local file = assert(io.open(worldpath .. "/" .. name, "wb"))
	file:write("# ", header, "\n")
	file:write("# anchor ", anchor_x, ",", anchor_y, ",", anchor_z, "\n")
	local written, ignored = 0, 0
	for z = min_z, max_z do
		for y = min_y, max_y do
			for x = min_x, max_x do
				local node = core.get_node({x = x, y = y, z = z})
				if node.name == "ignore" then
					ignored = ignored + 1
				elseif node.name ~= "air" then
					file:write(x - anchor_x, "\t", y - anchor_y, "\t", z - anchor_z,
						"\t", node.name, "\t", node.param2 or 0, "\n")
					written = written + 1
				end
			end
		end
	end
	assert(file:close())
	return written, ignored
end

--
-- 4. The socket inventory, straight out of the registry.
--
local function socket_report()
	local sockets = grug_core.settlement_sockets_at(KEY)
	local counts, order = {}, {}
	local groups, group_order = {}, {}
	for index = 1, #sockets do
		local socket = sockets[index]
		if counts[socket.role] == nil then
			counts[socket.role] = 0
			order[#order + 1] = socket.role
		end
		counts[socket.role] = counts[socket.role] + 1
		if socket.role == "guard_patrol" then
			if groups[socket.group] == nil then
				groups[socket.group] = 0
				group_order[#group_order + 1] = socket.group
			end
			groups[socket.group] = groups[socket.group] + 1
		end
	end
	table.sort(order)
	table.sort(group_order)
	local parts = {"sockets=" .. #sockets}
	for index = 1, #order do
		parts[#parts + 1] = "role_" .. order[index] .. "=" .. counts[order[index]]
	end
	parts[#parts + 1] = "loops=" .. #group_order
	for index = 1, #group_order do
		parts[#parts + 1] = "loop_" .. group_order[index] .. "=" ..
			groups[group_order[index]]
	end
	return parts, sockets
end

--
-- Driver
--
local resolved
local current, completed, finished = 0, 0, false
local timings = {}
local run_next

local function emerge_done(_, action, calls_remaining, state)
	if action == core.EMERGE_ERRORED then
		fail("emerge errored at " .. state.case.key)
	end
	if calls_remaining ~= 0 then return end
	completed = completed + 1
	local elapsed = core.get_us_time() - state.started_us
	timings[#timings + 1] = {case = state.case, us = elapsed}
	log({"event=mapchunk", "case=" .. state.case.id,
		"mapchunk=" .. state.case.key,
		"kind=" .. state.case.kind,
		"elapsed_us=" .. elapsed})
	core.after(0, run_next)
end

-- The dump regions, each re-emerged immediately before it is read. A mapchunk
-- emerged half a minute ago is NOT still in memory: the server unloads blocks
-- no player is near, and the first version of this probe read 202,592 "ignore"
-- nodes out of the core region because of it.
local dump_queue, dump_index, dump_results = {}, 0, {}
local run_dumps

local function dump_done()
	local spec = dump_queue[dump_index]
	local written, ignored = dump(spec.name, spec.min_x, spec.max_x, spec.min_y,
		spec.max_y, spec.min_z, spec.max_z, spec.header)
	dump_results[#dump_results + 1] = {label = spec.label, written = written,
		ignored = ignored}
	log({"event=dump", "file=" .. spec.name, "cells=" .. written,
		"ignored=" .. ignored})
	core.after(0, run_dumps)
end

local function report_complete()
	finished = true
	local function summarise(kind)
		local count, total, worst, best, first = 0, 0, 0, nil, nil
		for index = 1, #timings do
			local row = timings[index]
			if row.case.kind == kind then
				count = count + 1
				total = total + row.us
				if first == nil then first = row.us end
				if row.us > worst then worst = row.us end
				if best == nil or row.us < best then best = row.us end
			end
		end
		return count, total, worst, best or 0, first or 0
	end
	local parts = {"event=complete", "mode=" .. mode,
		"requested=" .. #resolved, "completed=" .. completed}
	for _, kind in ipairs({"warmup", "capital", "control_capital", "control"}) do
		local count, total, worst, best, first = summarise(kind)
		parts[#parts + 1] = kind .. "_chunks=" .. count
		parts[#parts + 1] = kind .. "_total_us=" .. total
		parts[#parts + 1] = kind .. "_first_us=" .. first
		parts[#parts + 1] = kind .. "_worst_us=" .. worst
		parts[#parts + 1] = kind .. "_best_us=" .. best
		-- The steady state: every mapchunk of this kind except its first, which
		-- carries whatever that kind's own one-time terrain work costs.
		if count > 1 then
			parts[#parts + 1] = kind .. "_steady_mean_us=" ..
				math.floor((total - first) / (count - 1))
		end
	end
	for index = 1, #dump_results do
		local row = dump_results[index]
		parts[#parts + 1] = row.label .. "_cells=" .. row.written
		parts[#parts + 1] = row.label .. "_ignored=" .. row.ignored
	end
	local surface_text, worst_fall, worst_plot = surface_report()
	local surface_file = assert(io.open(worldpath .. "/highcourt-surface.tsv", "wb"))
	surface_file:write(surface_text)
	assert(surface_file:close())
	parts[#parts + 1] = "worst_plot_fall=" .. worst_fall
	parts[#parts + 1] = "worst_plot=" .. worst_plot
	local sockets = select(1, socket_report())
	for index = 1, #sockets do parts[#parts + 1] = sockets[index] end
	log(parts)
	core.request_shutdown("WP13 Highcourt probe complete", false, 0.2)
end

run_dumps = function()
	dump_index = dump_index + 1
	local spec = dump_queue[dump_index]
	if not spec then return report_complete() end
	core.emerge_area({x = spec.min_x, y = spec.min_y, z = spec.min_z},
		{x = spec.max_x, y = spec.max_y, z = spec.max_z},
		function(_, _, calls_remaining)
			if calls_remaining == 0 then core.after(0, dump_done) end
		end)
end

local function finish()
	local plot = plots[1]
	local plot_base = grug_zones.terrain_height_at(
		anchor_x + plot.x + plot.composition.reference.x,
		anchor_z + plot.z + plot.composition.reference.z)
	-- The east avenue over the terraces, plus the ring street crossing it.
	local avenue_low, avenue_high = anchor_y, anchor_y
	for x = 40, 260, 4 do
		local y = grug_zones.terrain_height_at(anchor_x + x, anchor_z)
		if y < avenue_low then avenue_low = y end
		if y > avenue_high then avenue_high = y end
	end
	dump_queue = {
		{name = "highcourt-core.tsv", label = "core",
			header = "Highcourt core region as built, anchor-relative",
			min_x = anchor_x + core_bounds.min.x,
			max_x = anchor_x + core_bounds.max.x,
			min_y = anchor_y + core_bounds.min.y,
			max_y = anchor_y + core_bounds.max.y,
			min_z = anchor_z + core_bounds.min.z,
			max_z = anchor_z + core_bounds.max.z},
		{name = "highcourt-plot.tsv", label = "plot",
			header = "Highcourt district plot " .. plot.id ..
				" as built, anchor-relative",
			min_x = anchor_x + plot.x + plot_bounds.min.x,
			max_x = anchor_x + plot.x + plot_bounds.max.x,
			min_y = plot_base + plot_bounds.min.y,
			max_y = plot_base + plot_bounds.max.y,
			min_z = anchor_z + plot.z + plot_bounds.min.z,
			max_z = anchor_z + plot.z + plot_bounds.max.z},
		{name = "highcourt-avenue.tsv", label = "avenue",
			header = "Highcourt east avenue as built over the terraces, " ..
				"anchor-relative",
			min_x = anchor_x + 40, max_x = anchor_x + 260,
			min_y = avenue_low - 6, max_y = avenue_high + 6,
			min_z = anchor_z - 12, max_z = anchor_z + 12},
	}
	run_dumps()
end

run_next = function()
	current = current + 1
	local case = resolved[current]
	if not case then return finish() end
	local minp = {x = case.x, y = case.y, z = case.z}
	local maxp = {x = case.x + 79, y = case.y + 79, z = case.z + 79}
	local state = {case = case, started_us = core.get_us_time()}
	core.emerge_area(minp, maxp, emerge_done, state)
end

core.register_on_mods_loaded(function()
	local status = type(grug_mapgen) == "table" and grug_mapgen.wp40 or nil
	if type(status) ~= "table" or status.enabled ~= true or
			status.production_enabled ~= true or status.writer_count ~= 1 then
		fail("R7 production authority differs")
	end
	if type(grug_zones) ~= "table" or
			type(grug_zones.terrain_height_at) ~= "function" then
		fail("terrain height authority is unavailable")
	end
	local capital = grug_core.capital_anchor("accord", "human")
	if type(capital) ~= "table" then fail("capital authority differs") end
	anchor_x, anchor_y, anchor_z = capital.x, capital.y, capital.z
	local registered = grug_core.settlement_socket_anchor(KEY)
	if type(registered) ~= "table" or registered.x ~= anchor_x or
			registered.y ~= anchor_y or registered.z ~= anchor_z then
		fail("the registered " .. KEY .. " anchor is not the published capital anchor")
	end
	local sockets = select(1, socket_report())
	log({"event=start", "engine=" .. core.get_version().string,
		"seed=" .. core.get_mapgen_setting("seed"),
		"manifest=" .. status.manifest_sha256,
		"sockets_registered=" .. status.settlement_sockets,
		"anchor=" .. anchor_x .. "," .. anchor_y .. "," .. anchor_z,
		"mode=" .. mode,
		"build_us=" .. table.concat(build_us, ",")})
	log({"event=build"})
	for index = 1, #build_us do
		log({"event=build_time", build_us[index]})
	end
	for index = 1, #sockets do log({"event=socket", sockets[index]}) end
	if mode == "scan" then
		local file = assert(io.open(worldpath .. "/highcourt-scan.tsv", "wb"))
		file:write(scan_report())
		assert(file:close())
		local surface_text = surface_report()
		local surface_file = assert(io.open(worldpath .. "/highcourt-surface.tsv",
			"wb"))
		surface_file:write(surface_text)
		assert(surface_file:close())
		log({"event=complete", "mode=scan"})
		finished = true
		core.request_shutdown("WP13 Highcourt scan complete", false, 0.2)
		return
	end
	if mode == "surface" then
		local surface_text, worst_fall, worst_plot = surface_report()
		local file = assert(io.open(worldpath .. "/highcourt-surface.tsv", "wb"))
		file:write(surface_text)
		assert(file:close())
		log({"event=complete", "mode=surface", "worst_plot_fall=" .. worst_fall,
			"worst_plot=" .. worst_plot})
		finished = true
		core.request_shutdown("WP13 Highcourt surface probe complete", false, 0.2)
		return
	end
	resolved = corpus()
	log({"event=corpus", "mapchunks=" .. #resolved})
	core.after(1, run_next)
	core.after(timeout_seconds, function()
		if not finished then
			log({"event=timeout", "current=" .. current, "completed=" .. completed})
			core.request_shutdown("WP13 Highcourt probe timeout", false, 0)
		end
	end)
end)
