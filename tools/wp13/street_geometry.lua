-- What a capital's streets are actually shaped like, measured off the built
-- road and not off the rule that built it.
--
--     luajit tools/wp13/street_geometry.lua <repo> <seed> [--capital <key>]
--                                           [--runs] [out.tsv]
--
-- WHY THIS EXISTS. Playtest 5 (2026-09-16) looked at Dur Brannoc and
-- Lethariel and found five things wrong with the streets at once: they follow
-- the terrain as "a wild mix of stairs and orthogonal one-block jumps"; a
-- junction on a slope has unwalkable height jumps in it; the lamp standards
-- follow the ground instead of the road; a street raised on a slope is a solid
-- wall rather than a viaduct; and only Lethariel has piers and rails where a
-- street crosses water. Each of those is a NUMBER about the built road, so
-- this tool reads the cells the overlay writes and counts them.
--
-- WHAT IT MEASURES, per road run of a capital (`--runs` prints one row per
-- run; the default prints one row per capital):
--
--   columns          positions along the run's axis
--   spread           the worst CROSS-PROFILE spread: over the carriageway's
--                    own lanes at one position, the highest walking cell minus
--                    the lowest. Ruling 1 wants 0 -- one cross-profile per
--                    column of the run.
--   step             the worst change of the walking level between two
--                    neighbouring positions. Ruling 1 wants at most 1.
--   lane_step        the same per LANE, which is what a per-lane envelope can
--                    break while the road-wide one does not.
--   junc_spread      the worst spread of the walking level over a JUNCTION
--                    square -- the footprint two crossing runs share -- taken
--                    over the cells of BOTH runs. Ruling 2 wants 0.
--   junc_step        the worst step of either run arriving at a junction
--                    square. Ruling 2 wants at most 1.
--   raised           columns whose walking level stands above their own
--                    ground, and `raise_max` the worst of those heights;
--                    `walled` those raised by MIN_CLEAR or more, which are the
--                    ones ruling 4 says must stand on pillars with air under
--                    them, and `solid` how many of THOSE are solid fill today.
--   wet              carriageway columns standing over planned water, `piers`
--                    and `rails` what the run built there. Ruling 5 wants
--                    every wet column decked, piered and railed.
--   lamps            lamp standards, and `lamps_off` how many of them have
--                    their footing at a height the road beside them does not
--                    stand at. Ruling 3 wants 0.
--   queries          `surface` calls, which is what the timing gate pays for.
--
-- HOW THE WALKING LEVEL IS READ. The topmost cell of a carriageway column
-- whose name is one of the road's own three surfaces -- paving, kerb, tread --
-- resolved from the same palette the run was built with. A rail, a lamp post
-- and a bridge's plank verge are therefore not mistaken for road, and the
-- before and the after are read by exactly the same sentence.
--
-- THE GROUND is WP40's own height session, built offline the way
-- `tools/wp13/lane_routes.lua` and `tools/wp13/terrain_fixture.lua` build it:
-- no engine, no world, one construction per seed.
--
-- Plain Lua 5.1 (LuaJIT for the WP40 construction).

local repo = assert(arg[1], "repository root required")
local seed = assert(arg[2], "world seed required")
local only, per_run, out_path = nil, false, nil
local show_junctions = false
local index = 3
while index <= #arg do
	local token = arg[index]
	if token == "--capital" then
		index = index + 1
		only = assert(arg[index], "--capital needs a settlement key")
	elseif token == "--runs" then
		per_run = true
	elseif token == "--junctions" then
		show_junctions = true
	else
		out_path = token
	end
	index = index + 1
end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"

local source = dofile(wp40 .. "/source/simple_map.lua")
local schemas = dofile(wp40 .. "/schemas.lua")
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local raw_sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local horizontal_factory = dofile(wp40 .. "/simple_map.lua")
local height_factory = dofile(wp40 .. "/height.lua")
local coupled_grade = dofile(wp40 .. "/coupled_grade.lua")()

local horizontal = horizontal_factory({source = source, schemas = schemas,
	canonical = canonical, deterministic = deterministic,
	raw_sha256 = raw_sha256}).new(seed)
local height = height_factory({source = source, canonical = canonical,
	deterministic = deterministic, raw_sha256 = raw_sha256,
	horizontal_session = horizontal, coupled_grade = coupled_grade})
	.new_runtime(seed)

local palettes = dofile(wp13 .. "/palette.lua")
local elf_parts = dofile(wp13 .. "/elf_parts.lua")(wp13)
local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
local street_plan = dofile(wp13 .. "/street_plan.lua")(wp13)
local settlement = dofile(wp40 .. "/r7_settlement.lua")

-- The six capitals of the roster, each with the palette handle its own
-- blueprint source closes over (`wp40/r7_<key>_blueprint.lua`): the elf capital
-- takes the CAPITAL handle because its bridge and its grove edge need roles a
-- bare start palette does not bind.
local KEYS = {"highcourt", "dur_brannoc", "gor_drazhak", "lethariel",
	"kezamba", "nhal_veyr"}

local function profile_of(key)
	for i = 1, #settlement.roster do
		if settlement.roster[i].key == key then return settlement.roster[i] end
	end
	error("the roster carries no settlement called " .. key, 0)
end

local function palette_of(key, race)
	if key == "lethariel" then return elf_parts.handles().elf end
	return palettes.new(race)
end

-- THE SEAM, offline: the two queries `wp40/r7_settlement.lua` hands an overlay
-- in the engine, answered from the same pure height session -- the walkable
-- surface of a column (the ground, or the water standing on it) and the height
-- of a bridge deck that spans it.
local function walkable(x, z)
	local terrain_y = height.terrain_height_at(x, z)
	local water_y = height.water_surface_at(x, z)
	if type(water_y) == "number" and water_y > terrain_y then return water_y end
	return terrain_y
end
local function deck(x, z)
	local kind, functional_y = height.functional_surface_values_at(x, z)
	if kind ~= "bridge_deck" then return nil end
	return functional_y
end
local function is_wet(x, z)
	local terrain_y = height.terrain_height_at(x, z)
	local water_y = height.water_surface_at(x, z)
	return type(water_y) == "number" and water_y > terrain_y
end

-- A road run is a run of the overlay that is a STREET. The other runs of the
-- same overlay -- the curtain wall, the grove edge, Kezamba's gate cones --
-- are dispatched to their own modules by the composition and are not streets,
-- so they are named by their own id prefixes and skipped.
local function is_road(id)
	return not (id:match("^wall_") or id:match("^edge_") or id:match("^gate_"))
end

local function new_stats()
	return {columns = 0, spread = 0, step = 0, lane_step = 0,
		junc_spread = 0, junc_step = 0, raised = 0, raise_max = 0,
		walled = 0, solid = 0, wet = 0, piers = 0, rails = 0,
		lamps = 0, lamps_off = 0, queries = 0, pillars = 0, junctions = 0,
		overlaps = 0}
end

local function fold(into, from)
	for name, value in pairs(from) do
		if name == "spread" or name == "step" or name == "lane_step" or
				name == "junc_spread" or name == "junc_step" or
				name == "raise_max" then
			if value > into[name] then into[name] = value end
		else
			into[name] = into[name] + value
		end
	end
end

local COLUMNS = {"columns", "spread", "step", "lane_step", "junctions",
	"overlaps",
	"junc_spread", "junc_step", "raised", "raise_max", "walled", "solid",
	"pillars", "wet", "piers", "rails", "lamps", "lamps_off", "queries"}

local rows = {}
local function emit(row)
	local out = {row.capital, row.run}
	for i = 1, #COLUMNS do out[#out + 1] = row[COLUMNS[i]] end
	rows[#rows + 1] = table.concat(out, "\t")
end

local half = (avenue.WIDTH - 1) / 2
local totals = new_stats()

for _, key in ipairs(KEYS) do
	if only == nil or only == key then
		local capital_profile = profile_of(key)
		local composition = dofile(wp13 .. "/" .. key .. ".lua")(wp13)
		local palette = palette_of(key, capital_profile.race)
		local blueprint = dofile(wp40 .. "/r7_" .. key .. "_blueprint.lua")()
		local anchor_x, anchor_z = capital_profile.x, capital_profile.z
		local PAVING = palette.maybe("castle_paving") or palette.node("plaza")
		local KERB = palette.node("plaza_edge")
		local TREAD = palette.maybe("castle_wall_stair") or
			palette.node("roof_stair")
		local ROAD_NAME = {[PAVING] = true, [KERB] = true, [TREAD] = true}
		local PIER = palette.maybe("signature") or palette.node("wall_accent")
		local RAIL = palette.maybe("railing")

		local function local_surface(x, z)
			return walkable(anchor_x + x, anchor_z + z)
		end
		local function local_overhead(x, z)
			return deck(anchor_x + x, anchor_z + z)
		end
		local function local_wet(x, z)
			return is_wet(anchor_x + x, anchor_z + z)
		end

		-- Every road run of the overlay, built exactly as the seam builds a
		-- whole run in one call: the spec's three carriageway fields come from
		-- the overlay's own declaration and the lamp phase is the run's start.
		local pieces, specs = {}, {}
		for _, run in ipairs(blueprint.overlay.runs) do
			if is_road(run.id) then
				local spec = {id = run.id, axis = run.axis, at = run.at,
					from = run.from, to = run.to,
					width = blueprint.overlay.width,
					lamp_spacing = blueprint.overlay.lamp_spacing,
					lamp_phase = run.from, reach = blueprint.overlay.reach,
					overhead = local_overhead, wet = local_wet,
					junctions = run.junctions}
				pieces[run.id] = blueprint.overlay.run(spec, local_surface)
				specs[#specs + 1] = spec
			end
		end

		-- The walking level of every carriageway column of every run, read off
		-- the cells: the topmost of the road's own three surfaces.
		local walk = {}
		for _, spec in ipairs(specs) do
			local dx = (spec.axis == "x") and 1 or 0
			local lanes = {}
			local piece = pieces[spec.id]
			for i = 1, #piece.cells do
				local cell = piece.cells[i]
				if ROAD_NAME[cell.name] then
					local p = (dx == 1) and cell.x or cell.z
					local lane = (dx == 1) and (cell.z - spec.at) or
						(cell.x - spec.at)
					if lane >= -half and lane <= half then
						local column = lanes[p]
						if column == nil then
							column = {}
							lanes[p] = column
						end
						if column[lane] == nil or cell.y > column[lane] then
							column[lane] = cell.y
						end
					end
				end
			end
			walk[spec.id] = lanes
		end

		-- The junctions, from the module the road itself is handed them by, so
		-- the measurement asks about exactly the squares the rule levels. A
		-- PARALLEL overlap is not a junction (see `wp13/street_plan.lua`); it is
		-- counted on its own line.
		local junction_map, overlaps = street_plan.junctions(specs,
			blueprint.overlay.width)
		if show_junctions then
			for _, pair in ipairs(overlaps) do
				io.stderr:write("  parallel " .. key .. " " .. pair.one ..
					" and " .. pair.two .. "\n")
			end
		end
		local spec_by_id = {}
		for _, spec in ipairs(specs) do spec_by_id[spec.id] = spec end
		-- One measured junction per GROUP: the square every member of it stands
		-- in, taken over the merged ranges the plan hands each of them, and the
		-- walking level read off every member's own cells inside it.
		local junctions, seen_group = {}, {}
		for _, spec in ipairs(specs) do
			for _, record in ipairs(junction_map[spec.id] or {}) do
				local names = {spec.id}
				for _, member in ipairs(record.members) do
					names[#names + 1] = member.id
				end
				table.sort(names)
				local signature = table.concat(names, "+")
				if not seen_group[signature] then
					seen_group[signature] = true
					local min_x, max_x, min_z, max_z
					local function stretch(run, low, high)
						local a, b, c, d
						if run.axis == "x" then
							a, b = low, high
							c, d = run.at - half, run.at + half
						else
							c, d = low, high
							a, b = run.at - half, run.at + half
						end
						if min_x == nil or a > min_x then min_x = a end
						if max_x == nil or b < max_x then max_x = b end
						if min_z == nil or c > min_z then min_z = c end
						if max_z == nil or d < max_z then max_z = d end
					end
					stretch(spec, record.low, record.high)
					for _, member in ipairs(record.members) do
						stretch(spec_by_id[member.id], member.low, member.high)
					end
					local members = {spec}
					for _, member in ipairs(record.members) do
						members[#members + 1] = spec_by_id[member.id]
					end
					junctions[#junctions + 1] = {members = members,
						min_x = min_x, max_x = max_x,
						min_z = min_z, max_z = max_z, label = signature}
				end
			end
		end

		local capital_stats = new_stats()
		local junction_stats = {spread = 0, step = 0}
		for _, junction in ipairs(junctions) do
			local low, high
			for _, spec in ipairs(junction.members) do
				local dx = (spec.axis == "x") and 1 or 0
				local lanes = walk[spec.id]
				for x = junction.min_x, junction.max_x do
					for z = junction.min_z, junction.max_z do
						local p = (dx == 1) and x or z
						local lane = (dx == 1) and (z - spec.at) or
							(x - spec.at)
						local column = lanes[p]
						local y = column and column[lane]
						if y then
							if low == nil or y < low then low = y end
							if high == nil or y > high then high = y end
						end
					end
				end
			end
			if low and high - low > junction_stats.spread then
				junction_stats.spread = high - low
			end
			if show_junctions and low then
				io.stderr:write(string.format(
					"  junction %-12s %-48s x %d..%d z %d..%d  " ..
					"y %d..%d spread %d\n", key, junction.label,
					junction.min_x, junction.max_x,
					junction.min_z, junction.max_z, low, high, high - low))
			end
			-- How the two runs ARRIVE: the step between the last column before
			-- the square and the first column inside it, per lane.
			for _, spec in ipairs(junction.members) do
				local dx = (spec.axis == "x") and 1 or 0
				local inside_low = (dx == 1) and junction.min_x or junction.min_z
				local inside_high = (dx == 1) and junction.max_x or junction.max_z
				local lanes = walk[spec.id]
				for _, pair in ipairs({{inside_low - 1, inside_low},
						{inside_high, inside_high + 1}}) do
					local before, after = lanes[pair[1]], lanes[pair[2]]
					if before and after then
						for lane = -half, half do
							if before[lane] and after[lane] then
								local delta = before[lane] - after[lane]
								if delta < 0 then delta = -delta end
								if delta > junction_stats.step then
									junction_stats.step = delta
								end
							end
						end
					end
				end
			end
		end
		capital_stats.junctions = #junctions
		capital_stats.overlaps = #overlaps
		capital_stats.junc_spread = junction_stats.spread
		capital_stats.junc_step = junction_stats.step

		for _, spec in ipairs(specs) do
			local piece = pieces[spec.id]
			local lanes = walk[spec.id]
			local dx = (spec.axis == "x") and 1 or 0
			local stats = new_stats()
			stats.queries = piece.queries or 0
			local cells_by_column = {}
			for i = 1, #piece.cells do
				local cell = piece.cells[i]
				local p = (dx == 1) and cell.x or cell.z
				local lane = (dx == 1) and (cell.z - spec.at) or
					(cell.x - spec.at)
				local key_column = p .. ":" .. lane
				local list = cells_by_column[key_column]
				if list == nil then
					list = {}
					cells_by_column[key_column] = list
				end
				list[#list + 1] = cell
				if cell.name == PIER then stats.piers = stats.piers + 1 end
				if RAIL and cell.name == RAIL then stats.rails = stats.rails + 1 end
				local _ = cell
			end
			for p = spec.from, spec.to do
				stats.columns = stats.columns + 1
				local column = lanes[p]
				if column then
					local low, high
					for lane = -half, half do
						local y = column[lane]
						if y then
							if low == nil or y < low then low = y end
							if high == nil or y > high then high = y end
						end
					end
					if low and high - low > stats.spread then
						stats.spread = high - low
					end
					local next_column = lanes[p + 1]
					if next_column and p < spec.to then
						local next_low, next_high
						for lane = -half, half do
							local y = next_column[lane]
							if y then
								if next_low == nil or y < next_low then next_low = y end
								if next_high == nil or y > next_high then next_high = y end
							end
							if column[lane] and next_column[lane] then
								local delta = column[lane] - next_column[lane]
								if delta < 0 then delta = -delta end
								if delta > stats.lane_step then
									stats.lane_step = delta
								end
							end
						end
						if high and next_high then
							local delta = high - next_high
							if delta < 0 then delta = -delta end
							if delta > stats.step then stats.step = delta end
						end
					end
					-- What the column stands on and how far above it the road
					-- walks. `wet` is the planned water of the world, not a
					-- guess from the surface number.
					for lane = -half, half do
						local y = column[lane]
						if y then
							local x, z
							if dx == 1 then x, z = p, spec.at + lane
							else x, z = spec.at + lane, p end
							local ground = local_surface(x, z)
							local raise = y - ground
							if is_wet(anchor_x + x, anchor_z + z) then
								stats.wet = stats.wet + 1
							end
							if raise > 0 then
								stats.raised = stats.raised + 1
								if raise > stats.raise_max then
									stats.raise_max = raise
								end
								if raise >= avenue.MIN_CLEAR then
									stats.walled = stats.walled + 1
									-- Solid fill: every course between the
									-- ground and the walking cell is written.
									local list = cells_by_column[p .. ":" .. lane]
									local filled = 0
									for i = 1, #list do
										local cell = list[i]
										if cell.y > ground and cell.y < y and
												cell.name ~= "air" then
											filled = filled + 1
										end
									end
									if filled >= raise - 1 then
										stats.solid = stats.solid + 1
									else
										stats.pillars = stats.pillars + 1
									end
								end
							end
						end
					end
				end
			end
			-- The lamps, and how many of them stand at a height the road beside
			-- them does not. A standard is a footing, two posts and a torch, so
			-- its footing is three courses under the published light cell.
			for i = 1, #(piece.lamps or {}) do
				local lamp = piece.lamps[i]
				stats.lamps = stats.lamps + 1
				local p = (dx == 1) and lamp.x or lamp.z
				local column = lanes[p]
				local footing = lamp.y - 3
				local road_y
				if column then
					for lane = -half, half do
						local y = column[lane]
						if y and (road_y == nil or y > road_y) then road_y = y end
					end
				end
				if road_y == nil or road_y ~= footing then
					stats.lamps_off = stats.lamps_off + 1
				end
			end
			if per_run then
				local row = {capital = key, run = spec.id}
				for name, value in pairs(stats) do row[name] = value end
				emit(row)
			end
			fold(capital_stats, stats)
		end
		if not per_run then
			local row = {capital = key, run = "*"}
			for name, value in pairs(capital_stats) do row[name] = value end
			emit(row)
		end
		fold(totals, capital_stats)
		io.stderr:write(string.format(
			"%-12s seed %s  spread %d  step %d  junc %d/%d  walled %d " ..
			"(solid %d)  wet %d  lamps_off %d/%d\n",
			key, seed, capital_stats.spread, capital_stats.step,
			capital_stats.junc_spread, capital_stats.junc_step,
			capital_stats.walled, capital_stats.solid, capital_stats.wet,
			capital_stats.lamps_off, capital_stats.lamps))
	end
end

local header = {"capital", "run"}
for i = 1, #COLUMNS do header[#header + 1] = COLUMNS[i] end
local text = table.concat(header, "\t") .. "\n" .. table.concat(rows, "\n") ..
	"\n"
if out_path then
	local file = assert(io.open(out_path, "wb"))
	file:write(text)
	file:close()
else
	io.write(text)
end
io.stderr:write(string.format(
	"TOTAL seed %s  spread %d  step %d  lane_step %d  junc %d/%d  " ..
	"raised %d (max %d) walled %d solid %d pillars %d  wet %d piers %d " ..
	"rails %d  lamps %d off %d\n",
	seed, totals.spread, totals.step, totals.lane_step, totals.junc_spread,
	totals.junc_step, totals.raised, totals.raise_max, totals.walled,
	totals.solid, totals.pillars, totals.wet, totals.piers, totals.rails,
	totals.lamps, totals.lamps_off))
