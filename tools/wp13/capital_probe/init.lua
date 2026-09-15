-- Disposable headless probe for ONE capital of the WP13 roster, named by the
-- `grug_wp13_probe_key` setting. Staged into a scratch game copy by
-- `tools/wp13/run_capital.sh`; never shipped with the game, never loaded by a
-- normal server.
--
-- It is the Highcourt probe of the seam-generalisation package
-- (`tools/wp13/highcourt_probe/`) with the capital key lifted out of it and one
-- mode added, because the second capital needs the same five answers and one
-- the first did not: what the ground under the CURTAIN WALL does. That mode
-- runs before the composition exists, which is why this probe does not load a
-- capital source unless the mode it was given needs one.
--
-- It answers, in one boot, the engine questions a capital package owes:
--
--   0. THE GROUND ALONG THE WALL LINES (`terrain` mode, and the only mode that
--      works before the settlement is in the roster). Every column of the four
--      candidate curtain-wall lines at +-256, lane by lane across the wall's
--      own thickness, plus a coarse grid over the whole 512 envelope: the
--      terrace steps a wall has to survive, and the water it must not stand in.
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

grug_wp13_capital_probe = {}

local KEY = core.settings:get("grug_wp13_probe_key") or ""
local worldpath = core.get_worldpath()
-- The fitted capital anchor, filled in once the world authority is installed.
local anchor_x, anchor_y, anchor_z
local mode = core.settings:get("grug_wp13_probe_mode") or "full"
local timeout_seconds =
	tonumber(core.settings:get("grug_wp13_probe_timeout")) or 900

local function fail(message)
	error("grug_wp13_capital_probe: " .. message, 0)
end
if not KEY:match("^[a-z][a-z0-9_]*$") then
	fail("grug_wp13_probe_key must be a roster key")
end
if mode ~= "terrain" and mode ~= "surface" and mode ~= "full" and
		mode ~= "scan" and mode ~= "field" and mode ~= "edge" then
	fail("mode must be terrain, field, surface, scan, edge or full")
end
-- The two modes that need no composition at all: they measure the GROUND and
-- the emerge order, both of which exist before a capital is designed. They are
-- grouped once here so the three places that ask "is there a settlement yet"
-- cannot drift apart.
local ground_only = (mode == "terrain" or mode == "field" or mode == "edge")

local function log(fields)
	local parts = {"GRUG_WP13_CAPITAL"}
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
-- `terrain` mode exists to be run BEFORE the capital is in the roster: it
-- measures the ground a composition has not been designed against yet. It
-- therefore takes the faction and the race from settings instead, and it is the
-- only mode that may run without a roster row.
if not profile then
	if not ground_only then fail("the roster has no " .. KEY) end
	profile = {key = KEY, label = KEY,
		faction = core.settings:get("grug_wp13_probe_faction") or "",
		race = core.settings:get("grug_wp13_probe_race") or ""}
end
local plot_bounds = profile.plot_bounds and settlement.BOUNDS[profile.plot_bounds]
local core_bounds = profile.bounds and settlement.BOUNDS[profile.bounds]

local build_us = {}
local function timed(label, body)
	local started = core.get_us_time()
	local result = body()
	build_us[#build_us + 1] = label .. "=" .. (core.get_us_time() - started)
	return result
end

-- THE WORLD'S OWN QUADRANT SEAM, and not the canonical one.
--
-- A capital's blueprint source takes `full_seed` and `raw_sha256` and decides
-- which district stands in which quadrant from them; a caller that passes
-- neither is engine-free and gets the CANONICAL assignment, the roles in
-- authored order. This probe has an engine, so passing neither is a defect and
-- a quiet one: every plot dump and every surface row would be labelled with the
-- district the canonical assignment puts there while the map underneath holds
-- the district the SEED put there. The terrain numbers stay right -- a lot is a
-- lot whichever district takes it, and the SET of lot positions does not depend
-- on the permutation -- but "fill forge_ore_court" would name a region where
-- another quarter's mushroom garden actually stands, which is exactly what the
-- first render of this package showed.
--
-- The seam is spelled the way `r7_runtime.lua` spells it, from the same two
-- engine calls, so probe and world agree about the permutation by construction.
-- A single-district capital passes the same two fields and ignores them.
local function world_seed()
	local seed = core.get_mapgen_setting("seed")
	if type(seed) ~= "string" or seed == "" or not seed:match("^%-?%d+$") then
		fail("full world seed differs")
	end
	return seed
end
local function raw_sha256(bytes)
	local digest = core.sha256(bytes, true)
	if type(digest) ~= "string" or #digest ~= 32 then
		fail("core.sha256 raw result differs")
	end
	return digest
end

local source, plots, overlay
if not ground_only then
	source = timed("module_load", function()
		local loaded = dofile(wp40 .. "/" .. profile.blueprint_file)
		return loaded({full_seed = world_seed(), raw_sha256 = raw_sha256})
	end)
	-- Built and dropped: what is measured is the build, which is exactly the
	-- work the emerge thread does on the first mapchunk that touches the
	-- envelope.
	timed("core", source.core.build)
	plots = {}
	for index = 1, #source.plots do
		local plot = source.plots[index]
		-- `district`, `kind` and `lot` are present only for a capital whose
		-- source resolves several districts (Highcourt, Dur Brannoc since wave
		-- 2); a single-district capital carries none of them and every report
		-- below reads them as nil.
		plots[index] = {id = plot.id, x = plot.x, z = plot.z,
			district = plot.district, role = plot.role, kind = plot.kind,
			lot = plot.lot,
			composition = timed("plot_" .. plot.id, plot.build)}
	end
	overlay = source.overlay
end

-- Does this capital have a curtain wall? The composition says so by publishing
-- overlay runs whose ids begin `wall_`; the probe adds two dump regions when it
-- does, and none when it does not.
local wall_lines = nil
if overlay then
	for index = 1, #overlay.runs do
		if overlay.runs[index].id:sub(1, 5) == "wall_" then
			wall_lines = (wall_lines or 0) + 1
		end
	end
end

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
-- A column is WET unless the map calls it land. A plot standing on wet columns
-- is a plot in the water, and the first version of this package put two of them
-- there: a sweep that looked only for FLAT ground found the river bed, which is
-- the flattest ground inside a terraced capital envelope. So every plot report
-- carries the submerged count beside the fall, and a plot whose footprint has
-- one wet column is not a legal position however flat it is.
--
-- The MARGIN is sampled too, because a plot whose skirt ends one node from the
-- water is a building with a moat.
local PLOT_MARGIN = 2
local function wet(x, z)
	return grug_zones.water_class_at(x, z) ~= "land"
end

-- THE SAME SAMPLE `r7_settlement.audit_terrain` TAKES, and not a cheaper one.
--
-- The fall is read off the PERIMETER, because the perimeter is what the
-- foundation skirt carries down. The RISE is read off the perimeter, the
-- outside margin ring AND every other interior column, because a shoulder of
-- terrace standing anywhere under the plot is terrain left inside the building
-- -- and the first version of this probe read the rise off the perimeter alone.
-- The seam's load-time audit then disagreed with the offline predicate about
-- `forge_copse` by four nodes, which is what a cheaper sample buys.
local function plot_relief(origin_x, origin_z, bounds, margin, base)
	local edge_low, high = base, base
	local function sample(x, z, edge)
		local y = grug_zones.terrain_height_at(x, z)
		if y > high then high = y end
		if edge and y < edge_low then edge_low = y end
	end
	for z = bounds.min.z - margin, bounds.max.z + margin do
		for x = bounds.min.x - margin, bounds.max.x + margin do
			local outside = x < bounds.min.x or x > bounds.max.x or
				z < bounds.min.z or z > bounds.max.z
			local edge = (not outside) and
				(x == bounds.min.x or x == bounds.max.x or
					z == bounds.min.z or z == bounds.max.z)
			if outside or edge then
				sample(origin_x + x, origin_z + z, edge)
			elseif x % 2 == 0 and z % 2 == 0 then
				sample(origin_x + x, origin_z + z, false)
			end
		end
	end
	return base - edge_low, high - base
end

local function submerged_count(origin_x, origin_z, bounds, margin)
	local count = 0
	for z = bounds.min.z - margin, bounds.max.z + margin do
		for x = bounds.min.x - margin, bounds.max.x + margin do
			if wet(origin_x + x, origin_z + z) then count = count + 1 end
		end
	end
	return count
end

--
-- 0. THE GROUND THE CURTAIN WALL WOULD STAND ON.
--
-- The wall of a walled capital follows the 512 envelope's four edges at +-256,
-- and WP40 terraces that envelope: the ground under one line rises and falls in
-- race terrace steps (4 for the dwarf) with a 32-node blend band inside it and
-- a 96-node collar outside. Whether a wall survives that is not a design
-- opinion, it is a measurement, and this is where it is taken: every column of
-- each candidate line, lane by lane across the wall's own thickness, plus the
-- coarse grid of the whole envelope so the terraces can be looked at as a
-- picture.
--
-- `WALL_LINES` are candidates, not a decision. The composition picks its line
-- from what this prints.
local WALL_AT = 256
local WALL_LANES = 3           -- the seam offers an overlay run +-(half+1) = 3
local WALL_SPAN = 264

local function terrain_report()
	local rows = {"line\tp\tlane\tx\tz\tterrain_y\twater\n"}
	local lines = {
		{id = "west", axis = "z", at = -WALL_AT},
		{id = "east", axis = "z", at = WALL_AT},
		{id = "south", axis = "x", at = -WALL_AT},
		{id = "north", axis = "x", at = WALL_AT},
	}
	local summary = {}
	for index = 1, #lines do
		local line = lines[index]
		local worst_step, worst_at, wet_columns = 0, 0, 0
		local low, high
		local previous
		for p = -WALL_SPAN, WALL_SPAN do
			local column_low, column_high
			for lane = -WALL_LANES, WALL_LANES do
				local x, z
				if line.axis == "z" then x, z = line.at + lane, p
				else x, z = p, line.at + lane end
				-- The file is ANCHOR-RELATIVE, like every other dump here; the
				-- queries are in world coordinates.
				local y = grug_zones.terrain_height_at(anchor_x + x, anchor_z + z)
				local is_wet = wet(anchor_x + x, anchor_z + z)
				if is_wet then wet_columns = wet_columns + 1 end
				if column_low == nil or y < column_low then column_low = y end
				if column_high == nil or y > column_high then column_high = y end
				rows[#rows + 1] = table.concat({line.id, p, lane, x, z, y,
					tostring(is_wet)}, "\t") .. "\n"
			end
			if low == nil or column_low < low then low = column_low end
			if high == nil or column_high > high then high = column_high end
			-- The step ALONG the line is what a wall walk has to come down; the
			-- centre lane is the one the walk stands over.
			local centre
			if line.axis == "z" then
				centre = grug_zones.terrain_height_at(anchor_x + line.at, anchor_z + p)
			else
				centre = grug_zones.terrain_height_at(anchor_x + p, anchor_z + line.at)
			end
			if previous ~= nil then
				local step = math.abs(centre - previous)
				if step > worst_step then worst_step, worst_at = step, p end
			end
			previous = centre
		end
		summary[#summary + 1] = "line_" .. line.id .. "=" ..
			table.concat({low, high, high - low, worst_step, worst_at,
				wet_columns}, ":")
	end
	return table.concat(rows), summary
end

-- THE WHOLE FIELD, once (added 2026-09-15 by the Dur Brannoc upgrade lane;
-- `tools/wp13/highcourt_probe/` has carried it since the districts increment
-- and every capital lane needs it).
--
-- `scan_report` below answers "where may THIS plot stand" by re-reading the
-- same terrain column once per candidate position per plot: one quadrant's
-- 39 x 49 grid costs a plot two million queries, and a capital with four
-- districts has four quadrants and 52 compositions to place. The field is the
-- same two numbers per column whoever asks, so this reads it ONCE -- the pure
-- final height and whether the map calls the column land -- over the whole
-- capital envelope, and every lot question becomes arithmetic on an array
-- outside the engine (`tools/wp13/capital_lots.lua`).
--
-- One line per z row: the row's z, then the heights for x = -reach..reach
-- separated by spaces, then the same number of `0`/`1` land flags as one
-- string. About a megabyte per seed, re-derivable by a reviewer in one boot.
--
-- THE REACH IS +-250 AND NOT +-256: the field covers the 512 envelope less its
-- three outermost columns on each side, which is where the curtain wall stands
-- and where no lot may be in any case (`capital_lots.lua` refuses one past 236).
-- A lot placed beyond 250 would silently have no field under it, so the number
-- is stated here rather than described as "the whole envelope", which is what
-- the first version of this comment and of `run_capital.sh`'s header said.
local FIELD_REACH = 250
local function field_report()
	local rows = {"# grug_wp13_capital_field_v1 key=" .. KEY .. " reach=" ..
		FIELD_REACH .. " anchor=" .. anchor_x .. "," .. anchor_y .. "," ..
		anchor_z .. "\n",
		"# z\theights(x=-reach..reach)\tland(1=land)\n"}
	local heights, land = {}, {}
	for z = -FIELD_REACH, FIELD_REACH do
		local count = 0
		for x = -FIELD_REACH, FIELD_REACH do
			count = count + 1
			heights[count] = grug_zones.terrain_height_at(anchor_x + x,
				anchor_z + z)
			land[count] = (grug_zones.water_class_at(anchor_x + x,
				anchor_z + z) == "land") and "1" or "0"
		end
		rows[#rows + 1] = z .. "\t" .. table.concat(heights, " ", 1, count) ..
			"\t" .. table.concat(land, "", 1, count) .. "\n"
	end
	return table.concat(rows)
end

-- The coarse grid of the whole envelope plus its collar, which is what the
-- renderer draws as a height map.
local function grid_report()
	local rows = {"x\tz\tterrain_y\twater\n"}
	for z = -288, 288, 4 do
		for x = -288, 288, 4 do
			local wx, wz = anchor_x + x, anchor_z + z
			rows[#rows + 1] = table.concat({x, z,
				grug_zones.terrain_height_at(wx, wz), tostring(wet(wx, wz))},
				"\t") .. "\n"
		end
	end
	return table.concat(rows)
end

local function surface_report()
	local rows = {"plot\treference_x\treference_z\treference_y" ..
		"\tperimeter_min\tperimeter_max\tperimeter_fall\tperimeter_rise" ..
		"\tfootprint_min\tfootprint_max\tfootprint_fall\tfootprint_rise" ..
		"\tsubmerged\tsubmerged_margin\treference_wet\tclear_to\tcolumns\n"}
	local worst_fall, worst_plot = 0, "-"
	local worst_wet, worst_wet_plot = 0, "-"
	for index = 1, #plots do
		local plot = plots[index]
		local bounds = plot.composition.bounds
		local reference = plot.composition.reference
		local origin_x, origin_z = anchor_x + plot.x, anchor_z + plot.z
		local reference_y = grug_zones.terrain_height_at(origin_x + reference.x,
			origin_z + reference.z)
		local min_y, max_y = reference_y, reference_y
		local columns = 0
		local submerged = 0
		for z = bounds.min.z, bounds.max.z do
			for x = bounds.min.x, bounds.max.x do
				local y = grug_zones.terrain_height_at(origin_x + x, origin_z + z)
				if y < min_y then min_y = y end
				if y > max_y then max_y = y end
				if wet(origin_x + x, origin_z + z) then submerged = submerged + 1 end
				columns = columns + 1
			end
		end
		local relief_fall, relief_rise = plot_relief(origin_x, origin_z, bounds,
			PLOT_MARGIN, reference_y)
		local edge_min = reference_y - relief_fall
		local edge_max = reference_y + relief_rise
		local fall = relief_fall
		if fall > worst_fall then worst_fall, worst_plot = fall, plot.id end
		if submerged > worst_wet then worst_wet, worst_wet_plot = submerged, plot.id end
		rows[#rows + 1] = table.concat({plot.id, origin_x + reference.x,
			origin_z + reference.z, reference_y,
			edge_min, edge_max, fall, edge_max - reference_y,
			min_y, max_y, reference_y - min_y, max_y - reference_y,
			submerged,
			submerged_count(origin_x, origin_z, bounds, PLOT_MARGIN),
			tostring(wet(origin_x + reference.x, origin_z + reference.z)),
			plot.composition.clear_to or bounds.max.y, columns}, "\t") .. "\n"
	end
	return table.concat(rows), worst_fall, worst_plot, worst_wet, worst_wet_plot
end

-- A candidate sweep for a plot that has to be MOVED: the perimeter fall and
-- rise its footprint would see at every position on a coarse grid of the
-- capital's own quadrant. Two seeds' sweeps intersected is what decides a new
-- position, because a plot that only stands on one world's terrain has not been
-- fixed. The geometric constraints (envelope, gate corridors, street runs, the
-- other plots) are applied afterwards, outside the engine, where the whole
-- composition is in one place.
local function scan_report()
	local rows = {"plot\tx\tz\tperimeter_fall\tperimeter_rise" ..
		"\tsubmerged\tsubmerged_margin\treference_wet\tclear_to\n"}
	for index = 1, #plots do
		local plot = plots[index]
		local bounds = plot.composition.bounds
		local reference = plot.composition.reference
		for z = -96, 96, 4 do
			for x = 52, 204, 4 do
				local origin_x, origin_z = anchor_x + x, anchor_z + z
				local reference_y = grug_zones.terrain_height_at(
					origin_x + reference.x, origin_z + reference.z)
				local submerged = 0
				for ez = bounds.min.z, bounds.max.z do
					for ex = bounds.min.x, bounds.max.x do
						if wet(origin_x + ex, origin_z + ez) then
							submerged = submerged + 1
						end
					end
				end
				local relief_fall, relief_rise = plot_relief(origin_x, origin_z,
					bounds, PLOT_MARGIN, reference_y)
				local edge_min = reference_y - relief_fall
				local edge_max = reference_y + relief_rise
				-- The margin ring is only counted when the footprint itself is dry,
				-- because a wet footprint is already refused and the ring costs
				-- another 200 queries per candidate.
				local margin = -1
				if submerged == 0 then
					margin = submerged_count(origin_x, origin_z, bounds, PLOT_MARGIN)
				end
				rows[#rows + 1] = table.concat({plot.id, x, z,
					reference_y - edge_min, edge_max - reference_y,
					submerged, margin,
					tostring(wet(origin_x + reference.x, origin_z + reference.z)),
					plot.composition.clear_to or bounds.max.y}, "\t") .. "\n"
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
	-- so WP40 fits, flattens, terraces and protects it exactly like the subject --
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
	if #ordered > 160 then fail("the capital corpus is unbounded: " .. #ordered) end
	return ordered
end

--
-- 5. The dumps, read back from the finished map in ANCHOR-RELATIVE coordinates
-- so `tools/wp13/render_blueprint.py` draws them the way it draws a
-- composition dump.
--
-- The dump also DIGESTS what it wrote, over the road's own node names only.
-- Nothing else hashes the avenue's built geometry: the overlay's manifest
-- identity is its specification and not its cells, and the six-start engine gate
-- excludes capitals by construction. Without this, a change to `avenue.run`
-- would move every node of every capital road and no gate would notice.
--
-- The digest is taken over the ROAD cells alone -- the overlay's own palette --
-- so the surrounding terrain, which is WP40's and moves for WP40's reasons,
-- does not make the value churn.
local road_names = {}
if overlay then
	for index = 1, #overlay.names do road_names[overlay.names[index]] = true end
end

local function dump(name, min_x, max_x, min_y, max_y, min_z, max_z, header)
	local file = assert(io.open(worldpath .. "/" .. name, "wb"))
	file:write("# ", header, "\n")
	file:write("# anchor ", anchor_x, ",", anchor_y, ",", anchor_z, "\n")
	local written, ignored = 0, 0
	local road, road_rows = 0, {}
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
					if road_names[node.name] then
						road = road + 1
						road_rows[#road_rows + 1] = table.concat({x - anchor_x,
							y - anchor_y, z - anchor_z, node.name,
							node.param2 or 0}, ":")
					end
				end
			end
		end
	end
	assert(file:close())
	local digest = core.sha256(table.concat(road_rows, "\n"), false)
	return written, ignored, road, digest
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
	local written, ignored, road, digest = dump(spec.name, spec.min_x, spec.max_x,
		spec.min_y, spec.max_y, spec.min_z, spec.max_z, spec.header)
	dump_results[#dump_results + 1] = {label = spec.label, written = written,
		ignored = ignored, road = road,
		-- Every dump publishes the digest of the OVERLAY cells it read back out
		-- of the finished map, not only the road's. Dur Brannoc's overlay
		-- carries the curtain wall as well, and nothing else in the tree hashes
		-- what the wall actually built: an overlay's manifest identity is its
		-- SPECIFICATION, so a change to `wall.run` could move every node of
		-- every capital rampart in silence.
		digest = digest}
	log({"event=dump", "file=" .. spec.name, "cells=" .. written,
		"ignored=" .. ignored, "road_cells=" .. road, "road_digest=" .. digest})
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
		parts[#parts + 1] = row.label .. "_road_cells=" .. row.road
		if row.digest then
			parts[#parts + 1] = row.label .. "_road_digest=" .. row.digest
		end
	end
	-- THE SURFACE AND SOCKET REPORTS NEED A COMPOSITION, and the ground-only
	-- modes have none: `edge` walks mapchunks before a capital is in the roster
	-- at all. Its completion is the timing summary and nothing else.
	if plots ~= nil then
		local surface_text, worst_fall, worst_plot, worst_wet, worst_wet_plot =
			surface_report()
		local surface_file = assert(io.open(worldpath .. "/" .. KEY ..
			"-surface.tsv", "wb"))
		surface_file:write(surface_text)
		assert(surface_file:close())
		parts[#parts + 1] = "worst_plot_fall=" .. worst_fall
		parts[#parts + 1] = "worst_plot=" .. worst_plot
		parts[#parts + 1] = "worst_plot_submerged=" .. worst_wet
		parts[#parts + 1] = "worst_submerged_plot=" .. worst_wet_plot
		local sockets = select(1, socket_report())
		for index = 1, #sockets do parts[#parts + 1] = sockets[index] end
	end
	log(parts)
	core.request_shutdown("WP13 capital probe complete", false, 0.2)
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
	-- THE GROUND-ONLY MODES HAVE NOTHING TO DUMP. `edge` emerges mapchunks and
	-- loads no capital source at all (it runs before a capital is in the
	-- roster), so there are no plots to read a dump region off and the run ends
	-- on the corpus it just walked. The first version of that mode fell through
	-- to the dump queue and indexed a nil `plots`, which is the one defect this
	-- probe's own engine pass caught rather than a reader.
	if plots == nil then return report_complete() end
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
		{name = (KEY .. "-core.tsv"), label = "core",
			header = profile.label .. " core region as built, anchor-relative",
			min_x = anchor_x + core_bounds.min.x,
			max_x = anchor_x + core_bounds.max.x,
			min_y = anchor_y + core_bounds.min.y,
			max_y = anchor_y + core_bounds.max.y,
			min_z = anchor_z + core_bounds.min.z,
			max_z = anchor_z + core_bounds.max.z},
		{name = (KEY .. "-plot.tsv"), label = "plot",
			header = profile.label .. " district plot " .. plot.id ..
				" as built, anchor-relative",
			min_x = anchor_x + plot.x + plot_bounds.min.x,
			max_x = anchor_x + plot.x + plot_bounds.max.x,
			min_y = plot_base + plot_bounds.min.y,
			max_y = plot_base + plot_bounds.max.y,
			min_z = anchor_z + plot.z + plot_bounds.min.z,
			max_z = anchor_z + plot.z + plot_bounds.max.z},
		{name = (KEY .. "-avenue.tsv"), label = "avenue",
			header = profile.label .. " east avenue as built over the terraces, " ..
				"anchor-relative",
			min_x = anchor_x + 40, max_x = anchor_x + 260,
			min_y = avenue_low - 6, max_y = avenue_high + 6,
			min_z = anchor_z - 12, max_z = anchor_z + 12},
	}
	-- A capital with DISTRICTS publishes two more regions, because one plot on
	-- its own says nothing about whether a quarter reads as a quarter: a band
	-- over the near half of the first district's lot grid, and the first FILL
	-- dressing of that district. Both are added only when the source resolved
	-- districts, so a single-district capital's dump set is unchanged.
	do
		local first_fill, district_key
		local min_x, max_x, min_z, max_z
		for index = 1, #plots do
			local entry = plots[index]
			if entry.district and district_key == nil then
				district_key = entry.district
			end
			if entry.district == district_key then
				if entry.kind == "fill" then
					first_fill = first_fill or entry
				else
					local bounds = entry.composition.bounds
					local lo_x = entry.x + bounds.min.x
					local hi_x = entry.x + bounds.max.x
					local lo_z = entry.z + bounds.min.z
					local hi_z = entry.z + bounds.max.z
					if min_x == nil or lo_x < min_x then min_x = lo_x end
					if max_x == nil or hi_x > max_x then max_x = hi_x end
					if min_z == nil or lo_z < min_z then min_z = lo_z end
					if max_z == nil or hi_z > max_z then max_z = hi_z end
				end
			end
		end
		if district_key and min_x then
			-- The whole grid is some 130 nodes across and a dump of that with
			-- its headroom is a few million cells, so the band is CLIPPED to
			-- 112 on each axis from the corner nearest the core: what the
			-- picture has to show is lanes with buildings either side, and four
			-- lots do that as well as nine.
			local CLIP = 112
			if min_x < 0 then
				if min_x < max_x - CLIP then min_x = max_x - CLIP end
			elseif max_x > min_x + CLIP then
				max_x = min_x + CLIP
			end
			if min_z < 0 then
				if min_z < max_z - CLIP then min_z = max_z - CLIP end
			elseif max_z > min_z + CLIP then
				max_z = min_z + CLIP
			end
			local low, high = anchor_y, anchor_y
			for z = min_z, max_z, 4 do
				for x = min_x, max_x, 4 do
					local y = grug_zones.terrain_height_at(anchor_x + x,
						anchor_z + z)
					if y < low then low = y end
					if y > high then high = y end
				end
			end
			dump_queue[#dump_queue + 1] = {name = (KEY .. "-district.tsv"),
				label = "district",
				header = profile.label .. " district " .. district_key ..
					" as built, anchor-relative",
				min_x = anchor_x + min_x, max_x = anchor_x + max_x,
				min_y = low - 8, max_y = high + 24,
				min_z = anchor_z + min_z, max_z = anchor_z + max_z}
		end
		if first_fill then
			local bounds = first_fill.composition.bounds
			local base = grug_zones.terrain_height_at(
				anchor_x + first_fill.x + first_fill.composition.reference.x,
				anchor_z + first_fill.z + first_fill.composition.reference.z)
			dump_queue[#dump_queue + 1] = {name = (KEY .. "-fill.tsv"),
				label = "fill",
				header = profile.label .. " fill dressing " .. first_fill.id ..
					" as built, anchor-relative",
				min_x = anchor_x + first_fill.x + bounds.min.x - 2,
				max_x = anchor_x + first_fill.x + bounds.max.x + 2,
				min_y = base + bounds.min.y,
				max_y = base + bounds.max.y + 4,
				min_z = anchor_z + first_fill.z + bounds.min.z - 2,
				max_z = anchor_z + first_fill.z + bounds.max.z + 2}
		end
	end
	-- A WALLED capital publishes two more regions: a stretch of curtain that
	-- crosses a terrace step with a turret on it, and its east gate. Neither
	-- exists for an open capital, so both are added only when the composition
	-- authors a wall.
	if wall_lines then
		local wall_low, wall_high = anchor_y, anchor_y
		for z = -80, 80, 2 do
			local y = grug_zones.terrain_height_at(anchor_x + WALL_AT, anchor_z + z)
			if y < wall_low then wall_low = y end
			if y > wall_high then wall_high = y end
		end
		dump_queue[#dump_queue + 1] = {name = (KEY .. "-rampart.tsv"),
			label = "rampart",
			header = profile.label .. " east curtain over its terrace steps, " ..
				"anchor-relative",
			min_x = anchor_x + WALL_AT - 6, max_x = anchor_x + WALL_AT + 6,
			min_y = wall_low - 6, max_y = wall_high + 24,
			min_z = anchor_z - 80, max_z = anchor_z + 80}
		local gate_low, gate_high = anchor_y, anchor_y
		for x = WALL_AT - 20, WALL_AT + 10, 2 do
			local y = grug_zones.terrain_height_at(anchor_x + x, anchor_z)
			if y < gate_low then gate_low = y end
			if y > gate_high then gate_high = y end
		end
		dump_queue[#dump_queue + 1] = {name = (KEY .. "-gate.tsv"),
			label = "gate",
			header = profile.label .. " east gatehouse as built, anchor-relative",
			min_x = anchor_x + WALL_AT - 24, max_x = anchor_x + WALL_AT + 10,
			min_y = gate_low - 6, max_y = gate_high + 26,
			min_z = anchor_z - 20, max_z = anchor_z + 20}
	end
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
	-- The capital anchor of this profile's race. The faction is not in the
	-- roster row (a settlement carries a race, and `zone_authority.lua` owns
	-- which faction a race belongs to), so both are asked and the one that
	-- answers is the one that owns the race.
	local capital
	for _, faction in ipairs({"accord", "throng"}) do
		local candidate = grug_core.capital_anchor(faction, profile.race)
		if type(candidate) == "table" then capital = candidate end
	end
	if type(capital) ~= "table" then fail("capital authority differs") end
	if profile.x ~= nil and (capital.x ~= profile.x or capital.z ~= profile.z) then
		fail("the capital anchor of " .. KEY .. " is not the roster's position")
	end
	anchor_x, anchor_y, anchor_z = capital.x, capital.y, capital.z
	if mode == "terrain" then
		-- No settlement, no sockets, no corpus: the ground, before anything is
		-- designed against it.
		local wall_text, summary = terrain_report()
		local wall_file = assert(io.open(worldpath .. "/" .. KEY .. "-wall.tsv",
			"wb"))
		wall_file:write(wall_text)
		assert(wall_file:close())
		local grid_file = assert(io.open(worldpath .. "/" .. KEY .. "-grid.tsv",
			"wb"))
		grid_file:write(grid_report())
		assert(grid_file:close())
		local parts = {"event=complete", "mode=terrain",
			"engine=" .. core.get_version().string,
			"seed=" .. core.get_mapgen_setting("seed"),
			"anchor=" .. anchor_x .. "," .. anchor_y .. "," .. anchor_z,
			"legend=low:high:range:worst_step:worst_step_at:wet_columns"}
		for index = 1, #summary do parts[#parts + 1] = summary[index] end
		log(parts)
		finished = true
		core.request_shutdown("WP13 capital terrain probe complete", false, 0.2)
		return
	end
	if mode == "field" then
		-- The height and land field of the whole envelope, once, for the
		-- offline lot predicate. No settlement is needed and none is loaded.
		local file = assert(io.open(worldpath .. "/" .. KEY .. "-field.tsv",
			"wb"))
		file:write(field_report())
		assert(file:close())
		log({"event=complete", "mode=field",
			"engine=" .. core.get_version().string,
			"seed=" .. core.get_mapgen_setting("seed"),
			"anchor=" .. anchor_x .. "," .. anchor_y .. "," .. anchor_z,
			"reach=250"})
		finished = true
		core.request_shutdown("WP13 capital field probe complete", false, 0.2)
		return
	end
	-- THE EMERGE ORDER GATE (`tools/wp13/run_highcourt.sh edge`, generalised
	-- so every capital lane can run it without the pilot capital's runner).
	--
	-- An anchor writes its content at anchor.y + 1 and needs solid ground at
	-- anchor.y. A mapchunk is 80 nodes tall and offset by -32, so a root can
	-- land on a chunk's LOWEST layer and the support is then one node down in
	-- the chunk below. Which of the two the engine generates first is the
	-- emerge order, and a player teleporting in from above gets the upper one
	-- first. The ordinary corpus walks y upward and can therefore never see
	-- it; this mode emerges, for every one of the six capitals, the ROOT's
	-- chunk first and the SUPPORT's chunk second.
	if mode == "edge" then
		resolved = {}
		local seen = {}
		local races = {"human", "dwarf", "elf", "undead", "orc", "troll"}
		local factions = {human = "accord", dwarf = "accord", elf = "accord",
			undead = "throng", orc = "throng", troll = "throng"}
		for index = 1, #races do
			local race = races[index]
			local seat = grug_core.capital_anchor(factions[race], race)
			if type(seat) ~= "table" then
				fail("capital anchor differs for " .. race)
			end
			local root_chunk = chunk_origin(seat.y + 1)
			local support_chunk = chunk_origin(seat.y)
			for _, y in ipairs({root_chunk, support_chunk}) do
				local chunk_key = chunk_origin(seat.x) .. ":" .. y .. ":" ..
					chunk_origin(seat.z)
				if not seen[chunk_key] then
					seen[chunk_key] = true
					resolved[#resolved + 1] = {id = "anchor_" .. race,
						kind = "anchor_order", key = chunk_key,
						x = chunk_origin(seat.x), y = y,
						z = chunk_origin(seat.z)}
				end
			end
			log({"event=anchor_order", "race=" .. race,
				"anchor=" .. seat.x .. "," .. seat.y .. "," .. seat.z,
				"root_chunk_y=" .. root_chunk,
				"support_chunk_y=" .. support_chunk,
				"root_on_chunk_edge=" .. tostring(root_chunk ~= support_chunk)})
		end
		log({"event=corpus", "mapchunks=" .. #resolved, "mode=edge"})
		core.after(1, run_next)
		core.after(timeout_seconds, function()
			if not finished then
				log({"event=timeout", "current=" .. current,
					"completed=" .. completed})
				core.request_shutdown("WP13 capital probe timeout", false, 0)
			end
		end)
		return
	end
	local registered = grug_core.settlement_socket_anchor(KEY)
	if type(registered) ~= "table" or registered.x ~= anchor_x or
			registered.y ~= anchor_y or registered.z ~= anchor_z then
		fail("the registered " .. KEY .. " anchor is not the published capital anchor")
	end
	local sockets = select(1, socket_report())
	-- WHICH DISTRICT THIS WORLD PUT IN WHICH QUARTER. The source publishes what
	-- it decided; a capital with one district publishes nothing and this logs
	-- nothing. It is the one thing about a capital that a reader cannot work
	-- out from the dumps, and the renders are labelled by it.
	if type(source.districts) == "table" and
			type(source.districts.assignment) == "table" then
		local rows = {"event=districts"}
		local roles = {}
		for role in pairs(source.districts.assignment) do
			roles[#roles + 1] = role
		end
		table.sort(roles)
		for index = 1, #roles do
			rows[#rows + 1] = roles[index] .. "=" ..
				tostring(source.districts.assignment[roles[index]].quadrant)
		end
		if type(source.districts.permutation) == "table" then
			rows[#rows + 1] = "permutation=" ..
				table.concat(source.districts.permutation, ",")
		end
		log(rows)
	end
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
		local file = assert(io.open(worldpath .. "/" .. KEY .. "-scan.tsv", "wb"))
		file:write(scan_report())
		assert(file:close())
		local surface_text = surface_report()
		local surface_file = assert(io.open(worldpath .. "/" .. KEY .. "-surface.tsv",
			"wb"))
		surface_file:write(surface_text)
		assert(surface_file:close())
		log({"event=complete", "mode=scan"})
		finished = true
		core.request_shutdown("WP13 capital scan complete", false, 0.2)
		return
	end
	if mode == "surface" then
		local surface_text, worst_fall, worst_plot, worst_wet, worst_wet_plot =
			surface_report()
		local file = assert(io.open(worldpath .. "/" .. KEY .. "-surface.tsv", "wb"))
		file:write(surface_text)
		assert(file:close())
		log({"event=complete", "mode=surface", "worst_plot_fall=" .. worst_fall,
			"worst_plot=" .. worst_plot,
			"worst_plot_submerged=" .. worst_wet,
			"worst_submerged_plot=" .. worst_wet_plot})
		finished = true
		core.request_shutdown("WP13 capital surface probe complete", false, 0.2)
		return
	end
	resolved = corpus()
	log({"event=corpus", "mapchunks=" .. #resolved})
	core.after(1, run_next)
	core.after(timeout_seconds, function()
		if not finished then
			log({"event=timeout", "current=" .. current, "completed=" .. completed})
			core.request_shutdown("WP13 capital probe timeout", false, 0)
		end
	end)
end)
