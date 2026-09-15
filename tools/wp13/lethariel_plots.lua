-- Where a Lethariel district plot may stand, where the mere is, and where the
-- grove edge stops.
--
--     luajit tools/wp13/lethariel_plots.lua <repo>
--     luajit tools/wp13/lethariel_plots.lua <repo> --derive
--     luajit tools/wp13/lethariel_plots.lua <repo> --derive-fill
--     luajit tools/wp13/lethariel_plots.lua <repo> --shore
--     luajit tools/wp13/lethariel_plots.lua <repo> --edge
--     luajit tools/wp13/lethariel_plots.lua <repo> --gates
--     luajit tools/wp13/lethariel_plots.lua <repo> --census
--     luajit tools/wp13/lethariel_plots.lua <repo> --water
--     luajit tools/wp13/lethariel_plots.lua <repo> --bodies
--     luajit tools/wp13/lethariel_plots.lua <repo> --routes
--     luajit tools/wp13/lethariel_plots.lua <repo> --seeds
--
-- WHY THIS TOOL READS NO ENGINE DUMP, unlike `highcourt_plots.lua` and
-- `capital_plots.lua`, both of which take TSVs a headless boot wrote.
--
-- Those two exist because the first version of the seam package moved two
-- Highcourt plots with an ad-hoc sweep that asked "where is the ground
-- flattest?" -- and inside a terraced capital envelope the answer is the river
-- bed. The predicate had to be committed and re-runnable, and at the time the
-- only thing that could answer "how high is this column, and is it water?" was
-- a running server.
--
-- It is not. `wp40/height.lua` and `wp40/simple_map.lua` are pure modules and
-- `tools/wp13/capital_terrain_fixture.lua` already drives them offline for the
-- walkability gate: `height.terrain_height_at(x, z)` is the same pure final
-- height the writer projects a plot from, and
-- `horizontal.water_class_at(x, z)` is the same class the probe reads through
-- `grug_zones`. Reading them here directly buys three things the engine route
-- cannot:
--
--   * ALL NINE SEEDS instead of two. A capital's lots are legal on nine worlds
--     or they are not legal;
--   * every column at one-node resolution over the whole 533-node envelope,
--     where the shared probe's `scan` mode sweeps one quadrant on a four-node
--     grid;
--   * seconds instead of a boot per seed.
--
-- The engine-side audit (`r7_settlement.audit_terrain`, which runs on every
-- boot) stays the authority; this is the pre-flight that keeps a composition
-- from reaching one, and it earns that by asking the same question.
--
-- THE GENERIC GAP THIS LANE FOUND AND DID NOT CLOSE: `capital_plots.lua`
-- reads `capital.district.plots` -- ONE district -- and `capital_probe`'s
-- `scan` mode sweeps `x 52..204, z -96..96`, which is the quadrant Dur
-- Brannoc's single district stands in. Neither can express a four-district
-- capital, which is why Highcourt has a tool of its own and why this file
-- exists beside it. Generalising them is Lane D's, and the shape this file
-- uses -- read the height session directly, take every seed -- is the
-- suggestion.
--
-- THE RULES, in the order they refuse:
--
--   1. DRY. Not one column of the lot's footprint may be water, and neither
--      may its two-node margin, and neither may its reference column.
--   2. STANDS ON ITS OWN GROUND. The fall under the footprint's PERIMETER,
--      measured from the lot's own reference column, may not exceed the
--      foundation skirt (6), on every seed.
--   3. FITS UNDER ITS OWN ROOF. The rise under the footprint and its margin
--      may not exceed 6, against an airspace clear of at least 8.
--   4. INSIDE THE ENVELOPE, one node clear of the gate stations at +-256.
--   5. OFF THE CORE, off all four 32-node gate corridors, off every street run
--      the overlay writes -- avenues, ring street, district lanes AND the
--      grove edge -- inside its OWN quarter, and a lane clear of every other
--      lot.
--
-- Plain Lua 5.1, LuaJIT in practice; no engine, no globals.

local repo = assert(arg[1], "repository root required")
local mode = arg[2]

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
local grove = dofile(wp13 .. "/elf_grove.lua")(wp13)
local capital = dofile(wp13 .. "/lethariel.lua")(wp13)
local quadrants = dofile(wp13 .. "/lethariel_quadrants.lua")()
local elf_parts = dofile(wp13 .. "/elf_parts.lua")(wp13)
-- The same handle `r7_lethariel_blueprint.lua` gives the overlay.
local road_palette = elf_parts.handles().elf

local source = dofile(wp40 .. "/source/simple_map.lua")
local schemas = dofile(wp40 .. "/schemas.lua")
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local raw_sha256 = common.new_sha256()

-- The nine seeds of `tools/wp13/capital_anchor_fixture.lua`: the two gate
-- seeds, the seed the user's world crashed on, and six more.
local SEEDS = {"531802985935182545", "8675309", "15912857179583385436",
	"0", "1", "2", "42", "12345", "999999999"}
local GATE_SEEDS = {SEEDS[1], SEEDS[2]}
local ANCHOR = "anchor_009"
local SPAN = 266
local ENVELOPE = 250
local CORE = 48
local GATE_CORRIDOR = 16
local SKIRT = 6
local RISE = 6

local function session(seed)
	local horizontal = dofile(wp40 .. "/simple_map.lua")({source = source,
		schemas = schemas, canonical = canonical,
		deterministic = deterministic, raw_sha256 = raw_sha256}).new(seed)
	local coupled_grade = dofile(wp40 .. "/coupled_grade.lua")()
	local height = dofile(wp40 .. "/height.lua")({source = source,
		canonical = canonical, deterministic = deterministic,
		raw_sha256 = raw_sha256, horizontal_session = horizontal,
		coupled_grade = coupled_grade}).new_runtime(seed)
	local anchor = assert(height.selected_anchor_3d_by_id(ANCHOR),
		"the roster carries no " .. ANCHOR)
	return horizontal, height, anchor
end

-- The whole envelope, once per seed: the pure final height and the land class
-- of every column.
local function field(seed)
	local horizontal, height, anchor = session(seed)
	local y, land = {}, {}
	for z = -SPAN, SPAN do
		local row_y, row_land = {}, {}
		for x = -SPAN, SPAN do
			row_y[x] = height.terrain_height_at(anchor.x + x, anchor.z + z)
			row_land[x] =
				horizontal.water_class_at(anchor.x + x, anchor.z + z) == "land"
		end
		y[z], land[z] = row_y, row_land
	end
	return {seed = seed, y = y, land = land, anchor = anchor}
end

local function fields(list)
	local out = {}
	for index = 1, #list do out[index] = field(list[index]) end
	return out
end

local function overlaps(a1, a2, b1, b2) return a1 <= b2 and b1 <= a2 end

-- Every run the capital's overlay writes, as a rectangle a lot may not touch.
local runs = {}
local function add_run(run, half)
	if run.axis == "x" then
		runs[#runs + 1] = {id = run.id, min_x = run.from, max_x = run.to,
			min_z = run.at - half, max_z = run.at + half}
	else
		runs[#runs + 1] = {id = run.id, min_z = run.from, max_z = run.to,
			min_x = run.at - half, max_x = run.at + half}
	end
end
for _, list in ipairs({capital.avenues, capital.ring,
		quadrants.lane_runs()}) do
	for index = 1, #list do
		add_run(list[index], (avenue.WIDTH - 1) / 2 + 1)
	end
end
for index = 1, #capital.edge do add_run(capital.edge[index], grove.HALF) end

local LOT = quadrants.LOT

local function geometry(x, z, turns, reach, lane, placed)
	local min_x, max_x, min_z, max_z = x - reach, x + reach, z - reach,
		z + reach
	if min_x < -ENVELOPE or max_x > ENVELOPE or min_z < -ENVELOPE or
			max_z > ENVELOPE then
		return false, "envelope"
	end
	if overlaps(min_x, max_x, -CORE, CORE) and
			overlaps(min_z, max_z, -CORE, CORE) then
		return false, "core"
	end
	local qx, qz = quadrants.rotate(x, z, (4 - turns) % 4)
	if qx - reach < LOT.quarter or qz + reach > -LOT.quarter then
		return false, "quarter"
	end
	if overlaps(min_z, max_z, -GATE_CORRIDOR, GATE_CORRIDOR) then
		return false, "gate_corridor_x"
	end
	if overlaps(min_x, max_x, -GATE_CORRIDOR, GATE_CORRIDOR) then
		return false, "gate_corridor_z"
	end
	for _, run in ipairs(runs) do
		if overlaps(min_x, max_x, run.min_x, run.max_x) and
				overlaps(min_z, max_z, run.min_z, run.max_z) then
			return false, "street:" .. run.id
		end
	end
	for _, other in ipairs(placed or {}) do
		local gap = math.max(lane, other.lane)
		if overlaps(min_x - gap, max_x + gap, other.x - other.reach,
				other.x + other.reach) and
				overlaps(min_z - gap, max_z + gap, other.z - other.reach,
					other.z + other.reach) then
			return false, "lot:" .. other.tag
		end
	end
	return true
end

local function terrain(worlds, x, z, reach, margin)
	local worst_fall, worst_rise = 0, 0
	for _, world in ipairs(worlds) do
		if not world.land[z][x] then return false, "reference_in_water" end
		local base = world.y[z][x]
		local low, high = base, base
		for oz = z - reach - margin, z + reach + margin do
			local row_y, row_land = world.y[oz], world.land[oz]
			for ox = x - reach - margin, x + reach + margin do
				if not row_land[ox] then return false, "submerged" end
				local value = row_y[ox]
				if value > high then high = value end
				local inside = ox >= x - reach and ox <= x + reach and
					oz >= z - reach and oz <= z + reach
				local edge = inside and (ox == x - reach or ox == x + reach or
					oz == z - reach or oz == z + reach)
				if edge and value < low then low = value end
			end
		end
		if base - low > worst_fall then worst_fall = base - low end
		if high - base > worst_rise then worst_rise = high - base end
	end
	if worst_fall > SKIRT then return false, "fall:" .. worst_fall end
	if worst_rise > RISE then return false, "rise:" .. worst_rise end
	return true, nil, worst_fall, worst_rise
end

-- ------------------------------------------------------------------
-- --shore: the mere, and the composition's own silence over it
-- ------------------------------------------------------------------
if mode == "--shore" then
	local core = capital.core()
	local wrote = {}
	for _, cell in ipairs(core.cells) do
		wrote[cell.x .. ":" .. cell.z] = true
	end
	io.write("seed\twet_in_core\tcovered\tsilent_dry\n")
	local failures = 0
	for _, seed in ipairs(SEEDS) do
		local horizontal, _, anchor = session(seed)
		local wet, covered, silent_dry = 0, 0, 0
		for z = -47, 47 do
			for x = -47, 47 do
				local is_wet = horizontal.water_class_at(anchor.x + x,
					anchor.z + z) ~= "land"
				if is_wet then
					wet = wet + 1
					if wrote[x .. ":" .. z] then covered = covered + 1 end
				elseif not wrote[x .. ":" .. z] then
					silent_dry = silent_dry + 1
				end
			end
		end
		io.write(seed, "\t", wet, "\t", covered, "\t", silent_dry, "\n")
		if covered > 0 then failures = failures + 1 end
	end
	if failures > 0 then
		io.write("\nthe core writes over the mere on ", failures, " seed(s)\n")
		os.exit(1)
	end
	io.write("\nthe core writes on no water column of any of the nine seeds\n")
	os.exit(0)
end

-- ------------------------------------------------------------------
-- --edge: the wet spans of the four envelope lines
-- ------------------------------------------------------------------
if mode == "--edge" then
	io.write("seed\trun\tspans\n")
	local first
	local failures = 0
	for _, seed in ipairs(SEEDS) do
		local horizontal, _, anchor = session(seed)
		local rows = {}
		for index = 1, #capital.edge do
			local run = capital.edge[index]
			local spans, open = {}, nil
			for p = run.from, run.to do
				local wet = false
				for lane = -grove.HALF, grove.HALF do
					local x, z
					if run.axis == "z" then x, z = run.at + lane, p
					else x, z = p, run.at + lane end
					if horizontal.water_class_at(anchor.x + x, anchor.z + z)
							~= "land" then
						wet = true
					end
				end
				if wet and open == nil then open = p end
				if not wet and open ~= nil then
					spans[#spans + 1] = open .. ".." .. (p - 1)
					open = nil
				end
			end
			if open ~= nil then spans[#spans + 1] = open .. ".." .. run.to end
			rows[#rows + 1] = run.id .. "=" .. table.concat(spans, ",")
			io.write(seed, "\t", run.id, "\t",
				table.concat(spans, ",") == "" and "-" or
					table.concat(spans, ","), "\n")
			-- What the composition committed for this run.
			local plan = capital.edge_plan[run.id]
			local committed = {}
			for span_index = 1, #(plan.water or {}) do
				committed[#committed + 1] = plan.water[span_index][1] .. ".." ..
					plan.water[span_index][2]
			end
			if table.concat(committed, ",") ~= table.concat(spans, ",") then
				io.write("FAIL\t", run.id, "\tcommitted ",
					table.concat(committed, ","), "\n")
				failures = failures + 1
			end
		end
		local text = table.concat(rows, "|")
		if first == nil then
			first = text
		elseif first ~= text then
			io.write("FAIL\tthe water plan differs on seed ", seed, "\n")
			failures = failures + 1
		end
	end
	if failures > 0 then os.exit(1) end
	io.write("\nevery edge run's water spans are the committed ones, and the ",
		"same on all nine seeds\n")
	os.exit(0)
end

-- ------------------------------------------------------------------
-- --routes: does THIS capital's road meet Lane R's route ends?
-- ------------------------------------------------------------------
--
-- `tools/wp13/route_gates.lua` asks the same question for all six capitals and
-- answers it from the CONTRACT's generic avenue -- `avenue.run` over a run from
-- the core edge at 48 out to 261, in the race's plain palette -- because it was
-- written while four of the six blueprints did not exist. That is the right
-- shape for a route-graph gate and the wrong one for this capital, which
-- differs from the generic run in two ways that matter at exactly this seam:
--
--   * its NORTH avenue starts at z = 22, not 48, because the civic pad ends at
--     the mere;
--   * its north and east avenues carry a BRIDGE over the mere, whose deck
--     stands one node above the water the generic run paves at.
--
-- So this mode asks the question again of the SHIPPED composition: for each of
-- the four gate points of `source.capital_gates`, the route's own graded
-- surface there against the level `capital.overlay_run` actually builds the
-- centre lane at, and then the walk from sixty-four nodes outside the gate in
-- to the core edge, one column at a time. Target: step <= 1 at the gate, and no
-- position on the walk climbing more than a node.
if mode == "--routes" then
	local ROUTE_IN, ENTRY_RUN = 48, 64
	io.write("seed\tside\tgate_x\tgate_z\troute_y\troad_y\tstep\t",
		"walk_breaks\tworst\n")
	local failures, steps = 0, {}
	for _, seed in ipairs(SEEDS) do
		local horizontal, height, anchor = session(seed)
		local function walkable(x, z)
			local terrain_y = height.terrain_height_at(x, z)
			local water_y = height.water_surface_at(x, z)
			if type(water_y) == "number" and water_y > terrain_y then
				return water_y
			end
			return terrain_y
		end
		local function at(x, z)
			return walkable(anchor.x + x, anchor.z + z)
		end
		-- This capital's own four gates, out of WP40's published table.
		local gates = {}
		for index = 1, #source.capital_gates do
			local row = source.capital_gates[index]
			if row.position.x == anchor.x + row.outward_x * 256 and
					row.position.z == anchor.z + row.outward_z * 256 then
				gates[row.side] = row
			end
		end
		for _, run in ipairs(capital.avenues) do
			local side = run.id:gsub("^avenue_", "")
			local gate = gates[side]
			assert(gate, "no published gate for " .. run.id)
			local piece = capital.overlay_run(avenue, road_palette, {
				id = run.id, axis = run.axis, at = run.at, from = run.from,
				to = run.to, width = avenue.WIDTH,
				lamp_spacing = avenue.LAMP_SPACING, lamp_phase = run.from,
				reach = avenue.REACH}, at)
			-- The BUILT road, read off its own cells: the top of the centre
			-- lane at every position along the run, in world coordinates.
			local centre = {}
			for index = 1, #piece.cells do
				local cell = piece.cells[index]
				local lane = (run.axis == "x") and (cell.z - run.at) or
					(cell.x - run.at)
				if lane == 0 and cell.name ~= "air" then
					local p = (run.axis == "x") and cell.x or cell.z
					if centre[p] == nil or cell.y > centre[p] then
						centre[p] = cell.y
					end
				end
			end
			local gate_p = (run.axis == "x") and (gate.position.x - anchor.x) or
				(gate.position.z - anchor.z)
			local road_y = centre[gate_p]
			local kind, surface_y = height.functional_surface_values_at(
				gate.position.x, gate.position.z)
			local route_y = surface_y or
				height.terrain_height_at(gate.position.x, gate.position.z)
			local step = road_y and math.abs(route_y - road_y) or -1
			steps[#steps + 1] = step
			-- THE WALK IN: the route's own surface out where only the route is,
			-- and the built avenue from the moment this run covers the column.
			local sign = (gate_p < 0) and -1 or 1
			local outer = gate_p + sign * ENTRY_RUN
			local breaks, worst = 0, 0
			local previous
			local first, last = outer, sign * ROUTE_IN
            if sign < 0 then first, last = last, outer end
			for offset = math.min(first, last), math.max(first, last) do
				local p = offset
				local y = centre[p]
				if y == nil then
					local x, z
					if run.axis == "x" then x, z = p, run.at
					else x, z = run.at, p end
					y = walkable(anchor.x + x, anchor.z + z)
				end
				if previous ~= nil then
					local climb = math.abs(y - previous)
					if climb > 1 then
						breaks = breaks + 1
						if climb > worst then worst = climb end
					end
				end
				previous = y
			end
			local ok = step >= 0 and step <= 1 and breaks == 0
			if not ok then failures = failures + 1 end
			io.write(seed, "\t", side, "\t", gate.position.x, "\t",
				gate.position.z, "\t", route_y, "\t", tostring(road_y),
				"\t", step, "\t", breaks, "\t", worst,
				ok and "" or "\tFAULT", "\n")
		end
	end
	local worst_step = steps[1]
	for index = 2, #steps do
		if steps[index] > worst_step then worst_step = steps[index] end
	end
	io.write("\n", #steps, " gate/seed pairs, worst step ", worst_step,
		" against a limit of 1\n")
	if failures > 0 then
		io.write(failures, " gate(s) do not meet the route end\n")
		os.exit(1)
	end
	io.write("every avenue meets its route end, and the walk in never climbs ",
		"more than a node\n")
	os.exit(0)
end

-- ------------------------------------------------------------------
-- --water: the wet span of every overlay run, and --bodies: what the
-- crossings do to the lake
-- ------------------------------------------------------------------
--
-- A WATER BODY STAYS ONE BODY (the coordinator's ruling of 2026-09-16, after
-- the independent review measured that six road runs paving 3 336 of the mere's
-- columns cut it into six lakes). `--water` emits the spans every run crosses,
-- which is the table `wp13/lethariel.lua` commits and `wp13/elf_bridge.lua`
-- reads; `--bodies` is the property itself, counted by flood fill over the
-- planner's own water class with the runs' paved columns knocked out.
--
-- Both are seed-independent by construction and checked to be: a planned water
-- body is a property of the static world plan.

local GROVE_HALF = grove.HALF
local ROAD_HALF = (avenue.WIDTH - 1) / 2 + 1

-- Every run of the overlay, with the half-width of the band it may write in.
local function overlay_runs()
	local list = {}
	for _, group in ipairs({capital.avenues, capital.ring,
			quadrants.lane_runs()}) do
		for index = 1, #group do
			list[#list + 1] = {run = group[index], half = ROAD_HALF,
				kind = "road"}
		end
	end
	for index = 1, #capital.edge do
		list[#list + 1] = {run = capital.edge[index], half = GROVE_HALF,
			kind = "edge"}
	end
	return list
end

-- The columns a run's band covers, as (x, z) pairs.
local function run_columns(entry, visit)
	local run, half = entry.run, entry.half
	for p = run.from, run.to do
		for lane = -half, half do
			if run.axis == "x" then visit(p, run.at + lane)
			else visit(run.at + lane, p) end
		end
	end
end

if mode == "--water" then
	io.write("seed\trun\tkind\tspans\n")
	local first, failures = nil, 0
	for _, seed in ipairs(SEEDS) do
		local horizontal, _, anchor = session(seed)
		local rows = {}
		for _, entry in ipairs(overlay_runs()) do
			local run, half = entry.run, entry.half
			local spans, open = {}, nil
			for p = run.from, run.to do
				local wet = false
				for lane = -half, half do
					local x, z
					if run.axis == "x" then x, z = p, run.at + lane
					else x, z = run.at + lane, p end
					if horizontal.water_class_at(anchor.x + x, anchor.z + z)
							~= "land" then
						wet = true
					end
				end
				if wet and open == nil then open = p end
				if not wet and open ~= nil then
					spans[#spans + 1] = "{" .. open .. ", " .. (p - 1) .. "}"
					open = nil
				end
			end
			if open ~= nil then
				spans[#spans + 1] = "{" .. open .. ", " .. run.to .. "}"
			end
			local text = table.concat(spans, ", ")
			rows[#rows + 1] = run.id .. "=" .. text
			io.write(seed, "\t", run.id, "\t", entry.kind, "\t",
				(text == "") and "-" or text, "\n")
		end
		local joined = table.concat(rows, "|")
		if first == nil then first = joined
		elseif first ~= joined then
			io.write("FAIL\tthe water plan differs on seed ", seed, "\n")
			failures = failures + 1
		end
	end
	if failures > 0 then os.exit(1) end
	io.write("\nevery run's wet spans are the same on all ", #SEEDS,
		" seeds\n")
	os.exit(0)
end

if mode == "--bodies" then
	local seed = arg[3] or SEEDS[1]
	local horizontal, height, anchor = session(seed)
	local WINDOW = SPAN
	local wet = {}
	local total = 0
	for z = -WINDOW, WINDOW do
		local row = {}
		for x = -WINDOW, WINDOW do
			if horizontal.water_class_at(anchor.x + x, anchor.z + z)
					~= "land" then
				row[x] = true
				total = total + 1
			end
		end
		wet[z] = row
	end

	-- WHICH OF THOSE COLUMNS THE OVERLAY ACTUALLY BLOCKS, asked of the
	-- SHIPPED composition and not of a model of it: every run is built over
	-- this world's real surface and a column counts as blocked when the
	-- overlay writes a solid cell at or below that column's own water surface.
	-- A bridge deck one node over the water blocks nothing; a pier does, and a
	-- causeway blocks every column it covers.
	local function walkable_surface(x, z)
		local y = height.terrain_height_at(x, z)
		if horizontal.water_class_at(x, z) ~= "land" then
			local water = height.water_surface_at(x, z)
			if type(water) == "number" and water > y then return water, water end
			return y, y
		end
		return y, nil
	end
	local function at(x, z)
		local y = walkable_surface(anchor.x + x, anchor.z + z)
		return y
	end
	local water_y = {}
	for z = -WINDOW, WINDOW do
		local row = {}
		for x = -WINDOW, WINDOW do
			if wet[z] and wet[z][x] then
				local _, w = walkable_surface(anchor.x + x, anchor.z + z)
				row[x] = w
			end
		end
		water_y[z] = row
	end

	-- TWO WAYS TO LOSE A WATER COLUMN, and the mode counts both.
	--
	--   * PAVED: the overlay writes a solid node at or under the water surface.
	--     That is the causeway, and it is what the ruling of 2026-09-16 was
	--     about.
	--   * EMPTIED: the overlay writes AIR there. The engine's writer takes the
	--     water out just as willingly as it fills it in, so an air cell at the
	--     surface is a hole in the lake -- and a five-wide row of them down the
	--     middle of a crossing separates the water to its left from the water
	--     to its right exactly as a causeway would. The first bridge cleared
	--     `deck - 1` unconditionally and did this; the built map on seed
	--     531802985935182545 carried 2172 such cells and its avenue corridor's
	--     surface came apart into two sheets. A model that only counts solids
	--     cannot see that, so this one counts air too and the body count below
	--     is taken over the union.
	local blocked, blocked_count = {}, 0
	local emptied, emptied_count = {}, 0
	local per_run = {}
	for _, entry in ipairs(overlay_runs()) do
		local run = entry.run
		local piece = capital.overlay_run(avenue, road_palette, {
			id = run.id, axis = run.axis, at = run.at, from = run.from,
			to = run.to, width = avenue.WIDTH,
			lamp_spacing = avenue.LAMP_SPACING, lamp_phase = run.from,
			reach = avenue.REACH}, at)
		local own = 0
		for index = 1, #piece.cells do
			local cell = piece.cells[index]
			if cell.z >= -WINDOW and cell.z <= WINDOW and
					cell.x >= -WINDOW and cell.x <= WINDOW and
					wet[cell.z] and wet[cell.z][cell.x] then
				local level = water_y[cell.z][cell.x]
				if level ~= nil and cell.y <= level then
					local into = (cell.name == "air") and emptied or blocked
					if not (into[cell.z] and into[cell.z][cell.x]) then
						into[cell.z] = into[cell.z] or {}
						into[cell.z][cell.x] = true
						if cell.name == "air" then
							emptied_count = emptied_count + 1
						else
							blocked_count = blocked_count + 1
						end
						own = own + 1
					end
				end
			end
		end
		if own > 0 then per_run[#per_run + 1] = run.id .. "=" .. own end
	end
	local paved, paved_count = {}, 0
	for z = -WINDOW, WINDOW do
		for x = -WINDOW, WINDOW do
			if (blocked[z] and blocked[z][x]) or
					(emptied[z] and emptied[z][x]) then
				paved[z] = paved[z] or {}
				paved[z][x] = true
				paved_count = paved_count + 1
			end
		end
	end

	local function count_bodies(blocked)
		local seen, sizes = {}, {}
		for z = -WINDOW, WINDOW do
			for x = -WINDOW, WINDOW do
				local open = wet[z] and wet[z][x] and
					not (blocked and blocked[z] and blocked[z][x])
				if open and not (seen[z] and seen[z][x]) then
					local size, stack = 0, {{x, z}}
					seen[z] = seen[z] or {}
					seen[z][x] = true
					while #stack > 0 do
						local cell = table.remove(stack)
						size = size + 1
						local cx, cz = cell[1], cell[2]
						for _, step in ipairs({{1, 0}, {-1, 0}, {0, 1},
								{0, -1}}) do
							local nx, nz = cx + step[1], cz + step[2]
							if nz >= -WINDOW and nz <= WINDOW and
									nx >= -WINDOW and nx <= WINDOW and
									wet[nz] and wet[nz][nx] and
									not (blocked and blocked[nz] and
										blocked[nz][nx]) and
									not (seen[nz] and seen[nz][nx]) then
								seen[nz] = seen[nz] or {}
								seen[nz][nx] = true
								stack[#stack + 1] = {nx, nz}
							end
						end
					end
					sizes[#sizes + 1] = size
				end
			end
		end
		table.sort(sizes, function(a, b) return a > b end)
		return sizes
	end

	local before = count_bodies(nil)
	local after = count_bodies(paved)
	io.write("seed ", seed, ", window +-", WINDOW, "\n")
	io.write("planned-water columns: ", total, "\n")
	io.write("columns the overlay takes out of the water surface: ",
		paved_count, " (", blocked_count, " paved solid, ", emptied_count,
		" cleared to air)\n")
	io.write("per run: ", table.concat(per_run, " "), "\n")
	local function sizes(list)
		local text = {}
		for index = 1, math.min(#list, 10) do text[index] = list[index] end
		return table.concat(text, " ")
	end
	io.write("bodies BEFORE: ", #before, "  sizes ", sizes(before), "\n")
	io.write("bodies AFTER:  ", #after, "  sizes ", sizes(after), "\n")
	if #after ~= #before then
		io.write("\nthe crossings split the water: ", #before, " -> ", #after,
			"\n")
		os.exit(1)
	end
	io.write("\nevery water body is still one body after the crossings\n")
	os.exit(0)
end

-- ------------------------------------------------------------------
-- --gates: the air a threshold leaves over the road it spans
-- ------------------------------------------------------------------
--
-- THE ONE PLACE LANE E AND LANE R MEET. Lane R ends each of its four routes at
-- a gate point, and the grove edge stands a marble arch over exactly that
-- column. `avenue.lua` walks its deck on a one-Lipschitz envelope over forty
-- columns, so on climbing ground the road stands above the ground beside it and
-- an arch set from the ground lands on the carriageway. The independent review
-- of 2026-09-16 measured five of these thirty-six pairs under the road's own
-- `MIN_CLEAR` and one of them -- fixture seed 42, north gate -- sealed shut.
--
-- This mode is what keeps that fixed: it drives the SHIPPED `avenue.run` and
-- the SHIPPED `elf_grove.run` over the real height session of every fixture
-- seed and reports, for each of the four gates, the road's top cell, the
-- lintel, and the air between them.
if mode == "--gates" then
	local avenue_module = avenue
	io.write("seed\trun\tdeck_top\tlintel\tair\tverdict\n")
	local failures, values = 0, {}
	for _, seed in ipairs(SEEDS) do
		local horizontal, height, anchor = session(seed)
		local function surface(x, z)
			local y = height.terrain_height_at(x, z)
			local class = horizontal.water_class_at(x, z)
			if class ~= "land" then
				-- The seam hands a road the WATER surface where water stands,
				-- not the bed under it (`r7_settlement.lua`,
				-- `walkable_values`), and the grove has to be told the same
				-- story or the two measure different worlds.
				local water = height.water_surface_at and
					height.water_surface_at(x, z)
				if type(water) == "number" and water > y then y = water end
			end
			return y
		end
		local function at(x, z) return surface(anchor.x + x, anchor.z + z) end
		for index = 1, #capital.edge do
			local run = capital.edge[index]
			local plan = capital.edge_plan[run.id]
			local crossing
			for other = 1, #capital.avenues do
				local avenue_run = capital.avenues[other]
				if avenue_run.axis ~= run.axis then
					local column = run.at
					if column >= avenue_run.from and column <= avenue_run.to then
						crossing = avenue_run
					end
				end
			end
			assert(crossing, run.id .. " crosses no avenue")
			-- The ROAD, as `avenue.lua` builds it, one column wide at the gate.
			local road = avenue_module.run(road_palette, {
				id = crossing.id, axis = crossing.axis, at = crossing.at,
				from = run.at, to = run.at, width = avenue_module.WIDTH,
				lamp_spacing = avenue_module.LAMP_SPACING,
				lamp_phase = crossing.from, reach = avenue_module.REACH}, at)
			local deck_top
			for cell = 1, #road.cells do
				local one = road.cells[cell]
				local across = (crossing.axis == "x") and
					(one.z - crossing.at) or (one.x - crossing.at)
				if math.abs(across) <= (avenue_module.WIDTH - 1) / 2 and
						one.name ~= "air" and
						(deck_top == nil or one.y > deck_top) then
					deck_top = one.y
				end
			end
			-- The THRESHOLD, as `elf_grove.lua` builds it, over the gate zone.
			local piece = grove.run(road_palette, {
				id = run.id, axis = run.axis, at = run.at,
				from = -grove.GATE_HALF, to = grove.GATE_HALF,
				width = avenue_module.WIDTH,
				lamp_spacing = avenue_module.LAMP_SPACING,
				lamp_phase = run.from, reach = avenue_module.REACH},
				at, plan)
			local gate = piece.gates[1]
			assert(gate, run.id .. " built no threshold")
			local air = gate.lintel - deck_top - 1
			local ok = air >= grove.CLEAR
			if not ok then failures = failures + 1 end
			values[#values + 1] = air
			io.write(seed, "\t", run.id, "\t", deck_top, "\t", gate.lintel,
				"\t", air, "\t", ok and "ok" or "TOO LOW", "\n")
		end
	end
	local worst = values[1]
	for index = 2, #values do
		if values[index] < worst then worst = values[index] end
	end
	io.write("\n", #values, " gate/seed pairs, worst air ", worst,
		" against MIN_CLEAR ", grove.CLEAR, "\n")
	if failures > 0 then
		io.write(failures, " threshold(s) leave less air than the road's own ",
			"rule asks for\n")
		os.exit(1)
	end
	io.write("every threshold clears the road it spans on every seed\n")
	os.exit(0)
end

-- ------------------------------------------------------------------
-- --census: how many positions each quarter offers at all
-- ------------------------------------------------------------------
--
-- `--derive` is a nudge search and says nothing about how much room a quarter
-- has. This counts it: every position on a four-node grid that passes the whole
-- predicate, per quarter, at a given reach. It is what section 3.1 of the
-- research note quotes, and it exists because the first version of that table
-- came from a throwaway script nobody could re-run.
if mode == "--census" then
	local reach = tonumber(arg[3] or "11")
	local worlds = fields(SEEDS)
	io.write("# reach ", reach, ", ", #SEEDS, " seeds, 4-node grid\n")
	io.write("quadrant\tlegal_positions\n")
	for index = 1, #quadrants.QUADRANTS do
		local name = quadrants.QUADRANTS[index]
		local turns = index - 1
		local legal = 0
		for z = -240, 240, 4 do
			for x = -240, 240, 4 do
				if geometry(x, z, turns, reach, LOT.lane, nil) and
						terrain(worlds, x, z, reach, LOT.margin) then
					legal = legal + 1
				end
			end
		end
		io.write(name, "\t", legal, "\n")
	end
	os.exit(0)
end

-- ------------------------------------------------------------------
-- --derive / --derive-fill: re-run the searches
-- ------------------------------------------------------------------
if mode == "--derive" or mode == "--derive-fill" then
	-- ALL NINE SEEDS, not the two gate seeds. The first version of this
	-- capital derived its lots on two worlds and the nine-seed verification
	-- then refused seventeen of the forty-four: a lot that is flat on two
	-- worlds is not a lot that is flat, and the terrace the fitting lays over
	-- the relief moves with the seed.
	local worlds = fields(SEEDS)
	local fill = mode == "--derive-fill"
	for index = 1, #quadrants.QUADRANTS do
		local name = quadrants.QUADRANTS[index]
		local turns = index - 1
		local mere = name == quadrants.FIXED_QUADRANT
		local authored
		if fill then
			authored = mere and quadrants.MERE_FILL_AUTHORED or
				quadrants.FILL_AUTHORED
		else
			authored = mere and quadrants.MERE_AUTHORED or quadrants.AUTHORED
		end
		local placed = {}
		if fill then
			local lots = quadrants.LOTS[name]
			for lot = 1, #lots do
				placed[#placed + 1] = {x = lots[lot].x, z = lots[lot].z,
					reach = LOT.reach, lane = LOT.lane,
					tag = "lot" .. lot}
			end
		end
		io.write("\t\t", name, " = {\n")
		for slot = 1, #authored do
			local row = authored[slot]
			local reach = row.reach or LOT.reach
			local lane = fill and quadrants.FILL.lane or LOT.lane
			local margin = fill and quadrants.FILL.margin or LOT.margin
			local ax, az = quadrants.rotate(row.x, row.z, turns)
			local best
			local ok = geometry(ax, az, turns, reach, lane, placed)
			local fall, rise, why
			if ok then
				ok, why, fall, rise = terrain(worlds, ax, az, reach, margin)
			end
			local _ = why
			if ok then
				best = {x = ax, z = az, fall = fall, rise = rise, move = 0}
			else
				for radius = 2, 240, 2 do
					for dz = -radius, radius, 2 do
						for dx = -radius, radius, 2 do
							if math.abs(dx) == radius or
									math.abs(dz) == radius then
								local x, z = ax + dx, az + dz
								if geometry(x, z, turns, reach, lane, placed) then
									local good, _, f, r =
										terrain(worlds, x, z, reach, margin)
									if good then
										local move = math.abs(dx) +
											math.abs(dz)
										if not best or move < best.move then
											best = {x = x, z = z, fall = f,
												rise = r, move = move}
										end
									end
								end
							end
						end
					end
					if best then break end
				end
			end
			assert(best, "no legal home for " .. name .. " slot " .. slot)
			placed[#placed + 1] = {x = best.x, z = best.z, reach = reach,
				lane = lane, tag = "slot" .. slot}
			io.write("\t\t\t{x = ", best.x, ", z = ", best.z, "},  -- fall ",
				best.fall, " rise ", best.rise, " move ", best.move, "\n")
		end
		io.write("\t\t},\n")
	end
	os.exit(0)
end

-- ------------------------------------------------------------------
-- --seeds: the anchor and the terrace of every seed
-- ------------------------------------------------------------------
-- SEEDS OUTSIDE THE FIXTURE SET that put this capital's anchor root on a
-- mapchunk edge. A root lands on a chunk's lowest layer exactly when
-- `anchor_y = 47 (mod 80)`, and no seed of `capital_anchor_fixture.lua` does
-- that for anchor_009 -- the independent review of 2026-09-16 went looking and
-- found seed 7. It is not added to the fixture (that roster is Lane R's); it is
-- named here, and this capital's engine evidence carries a full pass on it.
local EDGE_SEEDS = {"7"}

if mode == "--seeds" then
	io.write("seed\tanchor_y\troot_y\troot_on_chunk_edge\tset\n")
	local list = {}
	for index = 1, #SEEDS do list[index] = SEEDS[index] end
	for index = 1, #EDGE_SEEDS do list[#list + 1] = EDGE_SEEDS[index] end
	for _, seed in ipairs(list) do
		local _, _, anchor = session(seed)
		local root = anchor.y + 1
		local origin = math.floor((root + 32) / 80) * 80 - 32
		local fixture = false
		for index = 1, #SEEDS do
			if SEEDS[index] == seed then fixture = true end
		end
		io.write(seed, "\t", anchor.y, "\t", root, "\t",
			tostring(root == origin), "\t",
			fixture and "fixture" or "edge-coverage", "\n")
	end
	os.exit(0)
end

-- ------------------------------------------------------------------
-- The default run: verify every committed lot on every seed
-- ------------------------------------------------------------------
local worlds = fields(SEEDS)
io.write("quadrant\tkind\tslot\tx\tz\tverdict\tworst_fall\tworst_rise\n")
local failures = 0
for index = 1, #quadrants.QUADRANTS do
	local name = quadrants.QUADRANTS[index]
	local turns = index - 1
	local mere = name == quadrants.FIXED_QUADRANT
	local placed = {}
	local function check(kind, slot, lot, reach, lane, margin)
		local ok, why = geometry(lot.x, lot.z, turns, reach, lane, placed)
		local fall, rise = "-", "-"
		if ok then
			local measured_fall, measured_rise
			ok, why, measured_fall, measured_rise =
				terrain(worlds, lot.x, lot.z, reach, margin)
			fall, rise = measured_fall or "-", measured_rise or "-"
		end
		placed[#placed + 1] = {x = lot.x, z = lot.z, reach = reach,
			lane = lane, tag = kind .. slot}
		if not ok then failures = failures + 1 end
		io.write(name, "\t", kind, "\t", slot, "\t", lot.x, "\t", lot.z, "\t",
			ok and "legal" or ("ILLEGAL " .. tostring(why)), "\t", fall, "\t",
			rise, "\n")
	end
	local lots = quadrants.LOTS[name]
	for slot = 1, #lots do
		check("plot", slot, lots[slot], LOT.reach, LOT.lane, LOT.margin)
	end
	local fills = quadrants.FILL_LOTS[name]
	local reaches = mere and quadrants.MERE_FILL_REACHES or
		quadrants.FILL_REACHES
	for slot = 1, #fills do
		check("fill", slot, fills[slot], reaches[slot], quadrants.FILL.lane,
			quadrants.FILL.margin)
	end
end
if failures > 0 then
	io.write("\n", failures, " lot(s) of Lethariel stand somewhere they may ",
		"not\n")
	os.exit(1)
end
io.write("\nevery Lethariel lot is dry, inside the skirt and under its own ",
	"roof on all ", #SEEDS, " seeds\n")
