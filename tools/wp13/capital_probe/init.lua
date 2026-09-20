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
local probe_storage = core.get_mod_storage()
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

local source, plots, overlay, core_composition
if not ground_only then
	source = timed("module_load", function()
		local loaded = dofile(wp40 .. "/" .. profile.blueprint_file)
		return loaded({full_seed = world_seed(), raw_sha256 = raw_sha256})
	end)
	-- Built and dropped: what is measured is the build, which is exactly the
	-- work the emerge thread does on the first mapchunk that touches the
	-- envelope.
	core_composition = timed("core", source.core.build)
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
-- overlay runs whose ids begin `wall_`; the probe adds THREE dump regions when
-- it does -- a stretch of curtain, the east gate and the four corners -- and
-- none when it does not. Gor Drazhak's rampart is a stake palisade rather than
-- masonry and it publishes the same four run ids, so it gets all three too.
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
	-- AN ORDINARY REFERENCE CAPITAL. Lethariel now carries the same eight service
	-- plots as every capital, so it is not a "no WP13 blueprints" isolation
	-- control. It remains a useful same-class timing reference beside the subject;
	-- the report labels it `control_capital` and makes no package-only cost claim.
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

-- A dump region is a LIST OF BOXES, not one box. Every region but one is a
-- single box and is normalised into a one-element list at queue time; the
-- corner region is four boxes, because the four places two wall runs meet are
-- the four corners of a 512 envelope and one box around all of them is the
-- envelope. The rows and the digest run over the boxes in order, so a multi-box
-- region is one file and one expectation.
--
-- EACH BOX IS EMERGED, HELD, READ AND RELEASED ON ITS OWN, and that is the
-- whole reason this is five functions and not one. The header of the dump queue
-- below says the first half of it: the server unloads mapblocks when no player
-- is near, so a box emerged three boxes ago is not still in memory. The first
-- version of the corner region emerged all four and then read all four, and
-- read 56 125 `ignore` nodes against 39 529 real ones -- the three earlier
-- corners had gone. The second half is round 4's (see THE MAPBLOCKS OF A BOX
-- below): emerging a box does not keep it, so a box is force-held while it is
-- read and a box that still comes back with anything ignored is read again.
-- So `open` writes the header, `scan_box` reads one held box into a buffer,
-- `commit_box` puts a clean buffer into the file and the digest, and `close`
-- digests what was written.
local function dump_open(name, header)
	local file = assert(io.open(worldpath .. "/" .. name, "wb"))
	file:write("# ", header, "\n")
	file:write("# anchor ", anchor_x, ",", anchor_y, ",", anchor_z, "\n")
	return {file = file, written = 0, ignored = 0, road = 0, rows = {},
		retries = 0, trouble = 0, held = 0, unheld = 0}
end

-- ONE BOX, READ INTO A BUFFER AND NOT STRAIGHT INTO THE FILE.
--
-- A box that comes back with `ignore` nodes in it is re-emerged and read
-- again (see `dump_attempt`), and a half-read box must never reach the file or
-- the digest. So a read produces a buffer and `dump_commit_box` is what puts
-- it into either. The largest region any capital publishes is Highcourt's
-- district region at ~195 000 written cells, which is a table this process can
-- hold for the length of one read.
local function dump_scan_box(box)
	local out = {written = 0, ignored = 0, road = 0, lines = {}, rows = {}}
	for z = box.min_z, box.max_z do
		for y = box.min_y, box.max_y do
			for x = box.min_x, box.max_x do
				local node = core.get_node({x = x, y = y, z = z})
				if node.name == "ignore" then
					out.ignored = out.ignored + 1
				elseif node.name ~= "air" then
					out.lines[#out.lines + 1] = table.concat(
						{x - anchor_x, y - anchor_y, z - anchor_z, node.name,
							node.param2 or 0}, "\t")
					out.written = out.written + 1
					if road_names[node.name] then
						out.road = out.road + 1
						out.rows[#out.rows + 1] = table.concat(
							{x - anchor_x, y - anchor_y, z - anchor_z,
								node.name, node.param2 or 0}, ":")
					end
				end
			end
		end
	end
	return out
end

local function dump_commit_box(state, out)
	if #out.lines > 0 then
		state.file:write(table.concat(out.lines, "\n"), "\n")
	end
	state.written = state.written + out.written
	state.ignored = state.ignored + out.ignored
	state.road = state.road + out.road
	for index = 1, #out.rows do
		state.rows[#state.rows + 1] = out.rows[index]
	end
end

local function dump_close(state)
	assert(state.file:close())
	return state.written, state.ignored, state.road,
		core.sha256(table.concat(state.rows, "\n"), false)
end

-- THE MAPBLOCKS OF A BOX, HELD IN MEMORY WHILE IT IS READ (round 4,
-- 2026-09-16).
--
-- `core.get_node` does not load anything: it answers `ignore` for a block that
-- is not resident, and emerging a box is not the same as keeping it. Highcourt
-- publishes the largest region of any capital (49 572 cells over four corner
-- boxes) and on two passes of four it came back with 12 000 and 14 125 `ignore`
-- nodes in it on an idle machine -- so `run_capital.sh` grew a guard that
-- refuses to compare such a digest, and the guard has been firing on a read
-- that was nobody's bug but this probe's.
--
-- WHAT IS MEASURED TO WORK IS THE RE-READ, and that sentence is this way round
-- because the independent review of 2026-09-16 measured it: in its own
-- Highcourt pass the corner box came back with `corner_held = 126` AND
-- `ignored = 12000` on attempt 1, and the SECOND attempt is what read it whole.
-- Over 171 region reads of this lane's campaign plus three passes of the
-- review's, no measurement anywhere shows the hold preventing an `ignore`.
-- So: a box that comes back with anything ignored is re-emerged and read again,
-- and that is the fix.
--
-- THE HOLD IS INSURANCE AND IS UNPROVEN. A transient forceload is the engine's
-- own "keep this block in memory" -- released explicitly, never written to the
-- world -- but `core.forceload_block` loads asynchronously and cannot make a
-- block resident inside the same server step, and a block cannot be unloaded
-- mid-step either, so on the one path this code takes it may be doing nothing
-- at all. It is kept because it costs a table of block positions and because it
-- is the only thing that would help if the read ever grew a step boundary
-- inside it; it is not what the passes credit.
--
-- The block span of a box is small (a corner box is 25 x ~20 x 25, at most
-- 3 x 3 x 3 mapblocks) but the engine's default budget is 16 blocks, so
-- `tools/wp13/run_capital.sh` -- the ONLY runner that stages this probe --
-- raises `max_forceloaded_blocks` for its own disposable world.
-- `tools/wp13/run_highcourt.sh` stages a different probe
-- (`tools/wp13/highcourt_probe`), which still carries the pre-round-4
-- emerge-then-read-a-step-later loop with no outcome check and no re-read. That
-- is recorded as open in `docs/research/wp13-streets-round4.md` section 8 and
-- is not fixed here.
--
-- The emerge OUTCOME is checked as well, rather than assumed; the log publishes
-- `_held`, `_unheld`, `_emerge_trouble` and `_retries` per region, so a pass
-- says which of the three did the work instead of leaving it to be guessed at.
local BLOCK = 16
local function block_span(box)
	return math.floor(box.min_x / BLOCK), math.floor(box.max_x / BLOCK),
		math.floor(box.min_y / BLOCK), math.floor(box.max_y / BLOCK),
		math.floor(box.min_z / BLOCK), math.floor(box.max_z / BLOCK)
end

local function hold_box(state, box)
	local held = {}
	local x0, x1, y0, y1, z0, z1 = block_span(box)
	for bx = x0, x1 do
		for by = y0, y1 do
			for bz = z0, z1 do
				local pos = {x = bx * BLOCK, y = by * BLOCK, z = bz * BLOCK}
				if core.forceload_block(pos, true) then
					held[#held + 1] = pos
					state.held = state.held + 1
				else
					state.unheld = state.unheld + 1
				end
			end
		end
	end
	return held
end

local function release_box(held)
	for index = 1, #held do
		core.forceload_free_block(held[index], true)
	end
end

--
-- 6. THE TREE CENSUS (wave 3, 2026-09-16; the open item wave 2 left).
--
-- The question: after generation, how many TREES stand inside what the
-- composition built -- a district plot's footprint, or the carriageway of an
-- avenue, a ring street or a district lane? A trunk in a market square is a
-- decoration the mapgen placed on top of a finished city, and nobody had
-- counted them.
--
-- WHERE THE NODES ARE READ. Not from an extra emerge: the timing phase already
-- walks every mapchunk the capital touches, one at a time, and a mapchunk is in
-- memory exactly when its emerge callback fires. So the census rides along on
-- that walk -- each capital mapchunk is intersected with the census regions and
-- read while it is there. That is why it costs nothing and why it is complete:
-- the corpus is built from the same plot and run boxes the census uses.
--
-- The window a mapchunk contributes is therefore at most the mapchunk itself
-- (80 cubed), so every `find_nodes_in_area` call below is bounded by
-- construction rather than by an engine constant.
--
-- WHAT COUNTS, AND THE TRAP THE FIRST VERSION WALKED INTO. `group:tree` is the
-- trunk, and a raw count of it is USELESS: the settlement's own posts, beams,
-- jetty piles and lamp standards are `default:tree` and `default:jungletree`
-- too, so the first run of this census reported 4388 "trees" inside Gor
-- Drazhak's 52 plots -- which is the orc capital's own timber, counted as
-- decoration. A census that cannot tell a post from a pine says nothing.
--
-- So each region kind is counted the way that kind can be told apart:
--
--   * A PLOT knows exactly what it wrote. `plot.composition` is the built
--     blueprint and this probe holds it, so every trunk in the plot's box is
--     checked against the cell the blueprint authored at that very column and
--     course. Authored -> the settlement's own timber. NOT authored -> WILD,
--     and that is the number: a tree the mapgen put inside a finished plot.
--   * A STREET has no cells to compare against -- an overlay's cells do not
--     exist until a surface is handed to it -- so the discriminator is the
--     CANOPY: a trunk with a `group:leaves` node in its own column within
--     three courses above it. A lamp standard carries a torch, a jetty pile
--     carries a deck, a post carries a beam; none of them carries leaves. It
--     is a heuristic and is reported as one, next to the raw trunk count. It
--     reads three nodes up with `get_node_or_nil`, so a trunk in the top three
--     courses of a mapchunk whose neighbour above is not loaded reads as
--     uncanopied: the street number is a FLOOR, and a small one -- a street's
--     band is the surface plus 24, which almost never ends on a chunk edge.
--
-- `group:leaves` is counted raw beside both and is NOT added to either: a
-- canopy legitimately overhangs a lane from a grove beside it, which is what
-- the elf capital is made of.
--
-- FIXING WHAT THIS FINDS IS NOT THIS LANE'S WORK. The probe reports; the
-- decision about decoration suppression inside a capital envelope belongs to
-- whoever owns that seam.
local TREE_NAMES = {"group:tree"}
local LEAF_NAMES = {"group:leaves"}
-- How far above a trunk a canopy still belongs to it.
local CANOPY_REACH = 3
-- How far above a street's own surface a trunk still counts as standing IN the
-- street. A plot carries its own y bounds; a street has none, so the band is
-- the sampled surface of the run plus a tree's height.
local STREET_BAND_UP = 24
local STREET_BAND_DOWN = 4

local census_regions = nil
local census_rows, census_order = {}, {}
local census_seen = {}

local function census_add(kind, id, min_x, max_x, min_y, max_y, min_z, max_z,
		authored)
	census_regions[#census_regions + 1] = {kind = kind, id = id,
		min_x = min_x, max_x = max_x, min_y = min_y, max_y = max_y,
		min_z = min_z, max_z = max_z, authored = authored}
	if census_rows[kind] == nil then
		census_rows[kind] = {trunks = 0, leaves = 0, wild = 0, canopy = 0,
			regions = 0, worst = 0, worst_id = "-"}
		census_order[#census_order + 1] = kind
	end
	census_rows[kind].regions = census_rows[kind].regions + 1
end

-- Built once, the first time a capital mapchunk arrives, because it needs the
-- fitted anchor and the built compositions and both exist by then.
local function census_plan()
	if census_regions then return end
	census_regions = {}
	if plots == nil or overlay == nil then return end
	for index = 1, #plots do
		local plot = plots[index]
		local bounds = plot.composition.bounds
		local base = grug_zones.terrain_height_at(
			anchor_x + plot.x + plot.composition.reference.x,
			anchor_z + plot.z + plot.composition.reference.z)
		-- EVERY CELL THIS PLOT AUTHORED, in world space and by key. A plot is
		-- projected from `base` -- the pure final height at its own reference
		-- column -- which is the same projection `corpus()` uses for the plot's
		-- box and the same one the writer uses, so a blueprint cell and the
		-- node the map holds are at the same coordinate.
		local authored = {}
		local cells = plot.composition.cells
		for step = 1, #cells do
			local cell = cells[step]
			authored[(anchor_x + plot.x + cell.x) .. ":" ..
				(base + cell.y) .. ":" ..
				(anchor_z + plot.z + cell.z)] = true
		end
		census_add("plot", plot.id,
			anchor_x + plot.x + bounds.min.x, anchor_x + plot.x + bounds.max.x,
			base + bounds.min.y, base + bounds.max.y,
			anchor_z + plot.z + bounds.min.z, anchor_z + plot.z + bounds.max.z,
			authored)
	end
	-- The CARRIAGEWAY and not the run's whole box: `overlay.width` is the paved
	-- width and the run's own half is what a walker walks on.
	--
	-- TWO KINDS OF RUN ARE NOT STREETS and are skipped. A `wall_` run is a
	-- curtain. An `edge_` run is an OPEN capital's boundary -- Lethariel's grove
	-- edge (`wp13/elf_grove.lua`), a planted belt of silverwood -- and counting
	-- the trees in it is counting the thing it is made of: the first run of
	-- this census reported 4269 canopied trunks along Lethariel's four edge
	-- runs, every one of them the composition's own grove. Kezamba's `gate_`
	-- thresholds are two posts and a lintel and are a street's own furniture,
	-- so they stay in.
	local half = math.floor((overlay.width - 1) / 2)
	for index = 1, #overlay.runs do
		local run = overlay.runs[index]
		if run.id:sub(1, 5) ~= "wall_" and run.id:sub(1, 5) ~= "edge_" then
			local min_x, max_x, min_z, max_z
			if run.axis == "x" then
				min_x, max_x = run.from, run.to
				min_z, max_z = run.at - half, run.at + half
			else
				min_z, max_z = run.from, run.to
				min_x, max_x = run.at - half, run.at + half
			end
			local low, high = anchor_y, anchor_y
			for step = 0, 16 do
				local along = min_x + math.floor((max_x - min_x) * step / 16)
				local across = min_z + math.floor((max_z - min_z) * step / 16)
				local y = grug_zones.terrain_height_at(anchor_x + along,
					anchor_z + across)
				if y < low then low = y end
				if y > high then high = y end
			end
			-- `avenue_north` and the like become "avenue"; `ring_east`, "ring";
			-- `lane_*`, "lane". One bucket per street family, which is the level
			-- the answer is wanted at.
			local kind = run.id:match("^([a-z]+)") or "street"
			census_add(kind, run.id, anchor_x + min_x, anchor_x + max_x,
				low - STREET_BAND_DOWN, high + STREET_BAND_UP,
				anchor_z + min_z, anchor_z + max_z)
		end
	end
end

-- One mapchunk's contribution. `origin` is the chunk's minimum corner; a
-- mapchunk is 80 nodes on a side.
local function census_mapchunk(origin)
	census_plan()
	local max_x, max_y, max_z = origin.x + 79, origin.y + 79, origin.z + 79
	for index = 1, #census_regions do
		local region = census_regions[index]
		local x0 = math.max(region.min_x, origin.x)
		local x1 = math.min(region.max_x, max_x)
		local y0 = math.max(region.min_y, origin.y)
		local y1 = math.min(region.max_y, max_y)
		local z0 = math.max(region.min_z, origin.z)
		local z1 = math.min(region.max_z, max_z)
		if x0 <= x1 and y0 <= y1 and z0 <= z1 then
			local row = census_rows[region.kind]
			local minp = {x = x0, y = y0, z = z0}
			local maxp = {x = x1, y = y1, z = z1}
			local here = 0
			local trunks = core.find_nodes_in_area(minp, maxp, TREE_NAMES)
			for step = 1, #trunks do
				local pos = trunks[step]
				local id = pos.x .. ":" .. pos.y .. ":" .. pos.z
				-- A lane's band and a plot's box can overlap by a node or two,
				-- and one trunk is one trunk: the first region to claim it
				-- keeps it, and plots are planned first.
				if not census_seen[id] then
					census_seen[id] = true
					row.trunks = row.trunks + 1
					if region.authored then
						-- A PLOT: the blueprint is the discriminator.
						if not region.authored[id] then
							row.wild = row.wild + 1
							here = here + 1
						end
					else
						-- A STREET: the canopy is.
						local wooded = false
						for lift = 1, CANOPY_REACH do
							local above = core.get_node_or_nil(
								{x = pos.x, y = pos.y + lift, z = pos.z})
							if above and
									core.get_item_group(above.name, "leaves") > 0 then
								wooded = true
							end
						end
						if wooded then
							row.canopy = row.canopy + 1
							here = here + 1
						end
					end
				end
			end
			local leaves = core.find_nodes_in_area(minp, maxp, LEAF_NAMES)
			row.leaves = row.leaves + #leaves
			region.found = (region.found or 0) + here
			if region.found > row.worst then
				row.worst = region.found
				row.worst_id = region.id
			end
		end
	end
end

local function census_report()
	local parts = {}
	if census_regions == nil then return parts end
	table.sort(census_order)
	local total = 0
	for index = 1, #census_order do
		local kind = census_order[index]
		local row = census_rows[kind]
		-- The FINDING of each kind: a plot's is the wild trunks (the blueprint
		-- says which are its own), a street's is the canopied ones.
		local found = row.wild + row.canopy
		total = total + found
		parts[#parts + 1] = "trees_" .. kind .. "_regions=" .. row.regions
		parts[#parts + 1] = "trees_" .. kind .. "_trunks=" .. row.trunks
		parts[#parts + 1] = "trees_" .. kind .. "_wild=" .. row.wild
		parts[#parts + 1] = "trees_" .. kind .. "_canopy=" .. row.canopy
		parts[#parts + 1] = "trees_" .. kind .. "_leaves=" .. row.leaves
		parts[#parts + 1] = "trees_" .. kind .. "_worst=" .. row.worst
		parts[#parts + 1] = "trees_" .. kind .. "_worst_id=" .. row.worst_id
	end
	parts[#parts + 1] = "trees_found_total=" .. total
	return parts
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
	-- THE TREE CENSUS RIDES ALONG, and AFTER the timing is taken so it cannot
	-- be charged to the mapchunk it reads. Only the capital's own mapchunks:
	-- the warm-up, the control capital and the three open-land controls are
	-- there to be compared against, not to be censused.
	if state.case.kind == "capital" and not ground_only then
		census_mapchunk(state.case)
	end
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
	local state = spec.state
	local written, ignored, road, digest = dump_close(state)
	spec.state = nil
	dump_results[#dump_results + 1] = {label = spec.label, written = written,
		ignored = ignored, road = road,
		-- What it took to read the region whole: the mapblocks held in memory
		-- while it was read, the ones the engine's forceload budget refused,
		-- the emerge callbacks that came back errored or cancelled, and the
		-- boxes that had to be taken again. A pass with `held` > 0 and
		-- everything else 0 is the read working as designed.
		held = state.held, unheld = state.unheld,
		trouble = state.trouble, retries = state.retries,
		-- Every dump publishes the digest of the OVERLAY cells it read back out
		-- of the finished map, not only the road's. Dur Brannoc's overlay
		-- carries the curtain wall as well, and nothing else in the tree hashes
		-- what the wall actually built: an overlay's manifest identity is its
		-- SPECIFICATION, so a change to `wall.run` could move every node of
		-- every capital rampart in silence.
		digest = digest}
	log({"event=dump", "file=" .. spec.name, "cells=" .. written,
		"ignored=" .. ignored, "road_cells=" .. road,
		"held=" .. dump_results[#dump_results].held,
		"unheld=" .. dump_results[#dump_results].unheld,
		"emerge_trouble=" .. dump_results[#dump_results].trouble,
		"retries=" .. dump_results[#dump_results].retries,
		"road_digest=" .. digest})
	core.after(0, run_dumps)
end

local function alchemy_report()
	local trainer, station
	local sockets = grug_core.settlement_sockets_at(KEY)
	for index = 1, #sockets do
		local socket = sockets[index]
		if socket.role == "trainer" and socket.profession == "alchemist" then
			trainer = socket
		elseif socket.role == "public_station" and socket.tags and
				socket.tags[1] == "brewing_stand" then
			station = socket
		end
	end
	if not trainer then fail("Alchemist trainer socket is absent") end
	if not station then fail("public brewing-stand socket is absent") end
	local stand_pos = station.pos
	local stand_node = core.get_node(stand_pos)
	if stand_node.name ~= grug_brewing.NODE and
			stand_node.name ~= grug_brewing.NODE_ACTIVE then
		fail("brewing stand is absent beside Alchemist trainer: " .. stand_node.name)
	end
	local dx, dy, dz = trainer.pos.x - stand_pos.x, trainer.pos.y - stand_pos.y,
		trainer.pos.z - stand_pos.z
	if trainer.id:match("^(.-)_alchemist$") ~=
			station.id:match("^(.-)_station$") or dx * dx + dy * dy + dz * dz > 25 then
		fail("public brewing stand is outside its Alchemist service room/range")
	end

	-- A disposable PlayerMeta-compatible store drives the real trainer field
	-- callback, profession state, station take gate and book query. No player is
	-- connected during this headless capital probe, so this is the smallest
	-- end-to-end exercise of those server-only paths.
	local meta = probe_storage
	for slot = 1, 2 do meta:set_string("grug_jobs:primary:" .. slot, "") end
	meta:set_int("grug_jobs:level:alchemist", 0)
	meta:set_int("grug_jobs:crafts:alchemist", 0)
	meta:set_int("grug_xp:xp", 10000) -- character level 11 / tier 2
	local player = {
		is_player = function() return true end,
		get_player_name = function() return "r8_alch_capital_probe" end,
		get_meta = function() return meta end,
		get_pos = function() return trainer.pos end,
	}
	if not grug_jobs.open_trainer(player, "alchemist", trainer.pos) then
		fail("Alchemist trainer did not open")
	end
	local received = false
	for index = 1, #(core.registered_on_player_receive_fields or {}) do
		if core.registered_on_player_receive_fields[index](player,
				"grug_jobs:trainer", {grug_jobs_learn = true}) then
			received = true
		end
	end
	if not received or not grug_jobs.has(player, "alchemist") then
		fail("Alchemist trainer learn flow failed")
	end

	local node_def = core.registered_nodes[stand_node.name]
	-- VoxelManip blueprint writes bypass on_construct. A real player initializes
	-- the inventory through the stand's right-click path before inserting; this
	-- direct headless inventory writer must cross the same seam explicitly.
	grug_brewing.ensure_inventory(stand_pos)
	local inv = core.get_meta(stand_pos):get_inventory()
	inv:set_stack("reagent", 1, "grug_gathering:gravemoss 10")
	inv:set_stack("reagent", 2, "grug_gathering:sunleaf 10")
	inv:set_stack("vial", 1, "vessels:glass_bottle 10")
	inv:set_stack("fuel", 1, "default:coal_lump 2")
	inv:set_stack("output", 1, "")
	inv:set_stack("output", 2, "")
	local matched = grug_brewing.match("grug_gathering:gravemoss",
		"grug_gathering:sunleaf", "vessels:glass_bottle")
	grug_brewing.timer(stand_pos, 100)
	stand_node = core.get_node(stand_pos)
	node_def = core.registered_nodes[stand_node.name]
	-- The inactive/active node swap preserves metadata, but an InventoryRef
	-- acquired before the swap is not a stable observation handle.
	inv = core.get_meta(stand_pos):get_inventory()
	local brewed = inv:get_stack("output", 1)
	if brewed:get_name() ~= "grug_alchemy:potion_healing" or
			brewed:get_count() ~= 10 then
		fail("T1 potion brew differs: output=" .. brewed:to_string() ..
			" matched=" .. tostring(matched and matched.output_name) ..
			" sizes=" .. inv:get_size("reagent") .. "/" ..
			inv:get_size("vial") .. "/" .. inv:get_size("fuel") .. "/" ..
			inv:get_size("output") .. " inputs=" ..
			inv:get_stack("reagent", 1):to_string() .. "," ..
			inv:get_stack("reagent", 2):to_string() .. " vial=" ..
			inv:get_stack("vial", 1):to_string() .. " fuel=" ..
			inv:get_stack("fuel", 1):to_string() .. " times=" ..
			core.get_meta(stand_pos):get_float("fuel_total") .. "/" ..
			core.get_meta(stand_pos):get_float("brew_time"))
	end
	if node_def.allow_metadata_inventory_take(stand_pos, "output", 1,
			brewed, player) ~= 10 then
		fail("learned Alchemist could not take brewed output")
	end
	inv:set_stack("output", 1, "")
	node_def.on_metadata_inventory_take(stand_pos, "output", 1, brewed, player)
	if grug_jobs.profession_level(player, "alchemist") ~= 2 then
		fail("ten T1 brews did not advance Alchemy to T2")
	end
	local records = grug_jobs.book_records(player, "alchemist", "brewing_stand")
	local tiers = {}
	for index = 1, #records do tiers[records[index].tier] = true end
	local tier_text = {}
	for tier = 1, 6 do
		if not tiers[tier] then fail("Alchemy book is missing tier " .. tier) end
		tier_text[#tier_text + 1] = tier
	end
	log({"event=alchemy", "capital=" .. KEY,
		"trainer=" .. trainer.pos.x .. "," .. trainer.pos.y .. "," .. trainer.pos.z,
		"stand=" .. stand_pos.x .. "," .. stand_pos.y .. "," .. stand_pos.z,
		"learned=true", "brewed=10", "output=grug_alchemy:potion_healing",
		"book_tiers=" .. table.concat(tier_text, ","), "profession_level=2"})
end

local function finalize_report()
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
		parts[#parts + 1] = row.label .. "_held=" .. row.held
		parts[#parts + 1] = row.label .. "_unheld=" .. row.unheld
		parts[#parts + 1] = row.label .. "_emerge_trouble=" .. row.trouble
		parts[#parts + 1] = row.label .. "_retries=" .. row.retries
		parts[#parts + 1] = row.label .. "_road_cells=" .. row.road
		if row.digest then
			parts[#parts + 1] = row.label .. "_road_digest=" .. row.digest
		end
	end
	-- THE SURFACE AND SOCKET REPORTS NEED A COMPOSITION, and the ground-only
	-- modes have none: `edge` walks mapchunks before a capital is in the roster
	-- at all. Its completion is the timing summary and nothing else.
	if plots ~= nil then
		alchemy_report()
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
		local trees = census_report()
		for index = 1, #trees do parts[#parts + 1] = trees[index] end
	end
	log(parts)
	core.request_shutdown("WP13 capital probe complete", false, 0.2)
end

local service_started = false
local function report_complete()
	if mode ~= "full" or plots == nil then return finalize_report() end
	if service_started then fail("service witness started twice") end
	service_started = true
	local anchor = {x = anchor_x, y = anchor_y, z = anchor_z}
	local core_box = {min_x = anchor_x - 49, max_x = anchor_x + 49,
		min_y = anchor_y, max_y = anchor_y + 4,
		min_z = anchor_z - 49, max_z = anchor_z + 49}
	local trouble = 0
	core.emerge_area({x = core_box.min_x, y = core_box.min_y, z = core_box.min_z},
		{x = core_box.max_x, y = core_box.max_y, z = core_box.max_z},
		function(_, action, calls_remaining)
			if action == core.EMERGE_ERRORED or action == core.EMERGE_CANCELLED then
				trouble = trouble + 1
			end
			if calls_remaining ~= 0 then return end
			core.after(0, function()
				if trouble ~= 0 then fail("precinct emerge failed: " .. trouble) end
				local hold_state = {held = 0, unheld = 0}
				local anchor_hold = hold_box(hold_state, core_box)
				if hold_state.unheld ~= 0 then
					release_box(anchor_hold); fail("precinct forceload refused")
				end
				assert(loadfile(core.get_modpath("grug_wp13_capital_probe") ..
					"/precinct_witness.lua"))()({key = KEY, anchor = anchor,
					composition = core_composition, worldpath = worldpath,
					fail = fail, log = log})
				local run_services = assert(loadfile(core.get_modpath(
					"grug_wp13_capital_probe") .. "/service_witness.lua"))()({
					key = KEY, race = profile.race, plots = plots, anchor = anchor,
					worldpath = worldpath, wp13 = wp40:gsub("/wp40$", "/wp13"),
					fail = fail, log = log})
				run_services(function()
					release_box(anchor_hold)
					finalize_report()
				end)
			end)
		end)
end

-- Each BOX of a region is emerged, held, read and released in turn, and the
-- region is closed once they all are. A region's boxes are emerged one after
-- another rather than together because `core.emerge_area` takes one rectangle,
-- and because the four corner boxes of a capital are 500 nodes apart: one
-- rectangle round them is the whole envelope and this probe would emerge it to
-- read four turrets.
--
-- A BOX IS READ UNTIL IT COMES BACK WHOLE, at most `DUMP_ATTEMPTS` times. The
-- emerge outcome is CHECKED and not assumed -- an errored or cancelled block
-- still decrements the callback's own counter, so the first version of this
-- loop could not tell a finished box from a half-finished one -- and a read
-- that still finds anything ignored is thrown away and taken again. That is
-- why `dump_scan_box` buffers: a half-read box may not reach the file or the
-- digest.
local DUMP_ATTEMPTS = 4
local dump_box = 0
local dump_attempt

dump_attempt = function(spec, box, last, attempt)
	local trouble = 0
	core.emerge_area({x = box.min_x, y = box.min_y, z = box.min_z},
		{x = box.max_x, y = box.max_y, z = box.max_z},
		function(_, action, calls_remaining)
			if action == core.EMERGE_ERRORED or
					action == core.EMERGE_CANCELLED then
				trouble = trouble + 1
			end
			if calls_remaining == 0 then
				core.after(0, function()
					local state = spec.state
					state.trouble = state.trouble + trouble
					-- HELD, READ, RELEASED -- in that order and in one step, so
					-- nothing between the hold and the read can unload a block.
					local held = hold_box(state, box)
					local out = dump_scan_box(box)
					release_box(held)
					if (out.ignored > 0 or trouble > 0) and
							attempt < DUMP_ATTEMPTS then
						state.retries = state.retries + 1
						log({"event=dump_retry", "file=" .. spec.name,
							"box=" .. dump_box, "attempt=" .. attempt,
							"ignored=" .. out.ignored,
							"emerge_trouble=" .. trouble})
						return dump_attempt(spec, box, last, attempt + 1)
					end
					dump_commit_box(state, out)
					if last then return dump_done() end
					return run_dumps()
				end)
			end
		end)
end

run_dumps = function()
	local spec = dump_queue[dump_index]
	if spec == nil or dump_box >= #spec.boxes then
		dump_index = dump_index + 1
		spec = dump_queue[dump_index]
		if not spec then return report_complete() end
		dump_box = 0
		spec.state = dump_open(spec.name, spec.header)
	end
	dump_box = dump_box + 1
	local last = (dump_box >= #spec.boxes)
	dump_attempt(spec, spec.boxes[dump_box], last, 1)
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
	-- THE STEEPEST GATE APPROACH, whichever of the four axes it is.
	--
	-- The dump above reads the EAST avenue and only the east avenue, which for
	-- Dur Brannoc and Highcourt is the interesting one and for Nhal Veyr is the
	-- flat one: the wave-2 review of that capital found its NORTH road standing
	-- four to seven courses above its ground at the gate point while the east
	-- road sat on its own ground the whole way, and no north/south/west
	-- carriageway had ever been read back out of a finished map. So the probe
	-- picks the axis whose FREE TERRAIN falls furthest over the last thirty
	-- columns before the gate point and dumps that one too, out to 261 and not
	-- to 260, because the gate approach is exactly the band the other dump's
	-- range excludes. On a capital whose four axes are equally calm this is one
	-- of them chosen arbitrarily and costs a region; on a capital with a steep
	-- flank it is the region somebody needs.
	local APPROACH_FROM, APPROACH_TO = 200, 261
	local axes = {
		{id = "north", dx = 0, dz = 1}, {id = "south", dx = 0, dz = -1},
		{id = "east", dx = 1, dz = 0}, {id = "west", dx = -1, dz = 0}}
	local steepest, steepest_fall
	for _, axis in ipairs(axes) do
		local high, low
		for p = 230, 261 do
			local y = grug_zones.terrain_height_at(anchor_x + axis.dx * p,
				anchor_z + axis.dz * p)
			if high == nil or y > high then high = y end
			if low == nil or y < low then low = y end
		end
		local fall = high - low
		if steepest_fall == nil or fall > steepest_fall then
			steepest, steepest_fall = axis, fall
		end
	end
	local app_low, app_high = anchor_y, anchor_y
	for p = APPROACH_FROM, APPROACH_TO do
		local y = grug_zones.terrain_height_at(anchor_x + steepest.dx * p,
			anchor_z + steepest.dz * p)
		if y < app_low then app_low = y end
		if y > app_high then app_high = y end
	end
	local function approach_span(component)
		local a = steepest[component] * APPROACH_FROM
		local b = steepest[component] * APPROACH_TO
		if a > b then a, b = b, a end
		if a == 0 and b == 0 then return -12, 12 end
		return a, b
	end
	local app_min_x, app_max_x = approach_span("dx")
	local app_min_z, app_max_z = approach_span("dz")
	dump_queue[#dump_queue + 1] = {name = (KEY .. "-approach.tsv"),
		label = "approach",
		header = profile.label .. " " .. steepest.id .. " gate approach as " ..
			"built (the steepest of the four axes, free terrain falling " ..
			steepest_fall .. " nodes over 230..261), anchor-relative",
		min_x = anchor_x + app_min_x, max_x = anchor_x + app_max_x,
		min_y = app_low - 8, max_y = app_high + 8,
		min_z = anchor_z + app_min_z, max_z = anchor_z + app_max_z}
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
	-- THE FOUR CORNERS OF THE CURTAIN, which is where two wall runs meet and
	-- until the review of 2026-09-16 nothing in the tree could look.
	--
	-- `wall.lua` section 1b reconciles the two decks at a shared corner, and
	-- every artefact that could have gated it is blind: the rampart region is
	-- the east curtain either side of the anchor (z -80..80), the gate region is
	-- the gate (z -20..20), and a corner is at +-256. So a regression in the seam
	-- -- `plan.corners` dropped from a capital, say -- would leave every
	-- committed digest and every KAT green. This region is the gate that closes
	-- that: four boxes, one per corner, in one file with one digest.
	--
	-- +-12 of each corner column covers, on every one of the four: the z-run's
	-- corner TURRET (centred on +-256, eleven columns along and seven across),
	-- the x-run's last columns up to its own end at +-252 with its own seven
	-- lanes, and a margin either side. It does not reach the nearest ordinary
	-- turret at +-192, so what is in it is corner and nothing else.
	if wall_lines then
		local CORNER, CORNER_PAD = WALL_AT, 12
		local corner_boxes = {}
		for _, sx in ipairs({-1, 1}) do
			for _, sz in ipairs({-1, 1}) do
				local cx, cz = sx * CORNER, sz * CORNER
				local low, high = anchor_y, anchor_y
				for x = cx - CORNER_PAD, cx + CORNER_PAD, 2 do
					for z = cz - CORNER_PAD, cz + CORNER_PAD, 2 do
						local y = grug_zones.terrain_height_at(anchor_x + x,
							anchor_z + z)
						if y < low then low = y end
						if y > high then high = y end
					end
				end
				corner_boxes[#corner_boxes + 1] = {
					min_x = anchor_x + cx - CORNER_PAD,
					max_x = anchor_x + cx + CORNER_PAD,
					min_y = low - 6, max_y = high + 24,
					min_z = anchor_z + cz - CORNER_PAD,
					max_z = anchor_z + cz + CORNER_PAD}
			end
		end
		dump_queue[#dump_queue + 1] = {name = (KEY .. "-corner.tsv"),
			label = "corner",
			header = profile.label .. " curtain corners as built -- all four, " ..
				"+-" .. CORNER_PAD .. " of each corner column, anchor-relative",
			boxes = corner_boxes}
	end
	-- Every region above names ONE box in the fields it always named; the corner
	-- region names four. Normalising here keeps every author of a region free to
	-- write the simple form.
	for index = 1, #dump_queue do
		local spec = dump_queue[index]
		if spec.boxes == nil then
			spec.boxes = {{min_x = spec.min_x, max_x = spec.max_x,
				min_y = spec.min_y, max_y = spec.max_y,
				min_z = spec.min_z, max_z = spec.max_z}}
		end
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
