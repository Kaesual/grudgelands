-- Where a capital's streets meet WP40's long-distance routes, and whether a
-- player can walk the meeting.
--
--     luajit tools/wp13/lane_routes.lua <repo> <seed> [--legacy] [out.tsv]
--
-- WHAT IT MEASURES. A WP13 capital road (`wp13/avenue.lua`) is a surface
-- overlay: it paves whatever column surface the seam hands it. WP40's routes
-- are built by a different authority and cross the same rivers, and where a
-- route crosses on a BRIDGE its deck passes over the city in the air. Round 3
-- of the playtest found what that leaves: a district lane with one block of
-- air over it, which is a lane nobody can walk and therefore a lane that dead
-- ends at the route.
--
-- This tool builds WP40's height session OFFLINE -- the same construction
-- `tools/wp13/terrain_fixture.lua` uses, no engine and no world -- runs every
-- avenue, ring-street side and district lane of both capitals through the
-- real `avenue.run`, and reports every column a deck spans with the air over
-- the built road: `clear` is `deck_y - road_y - 2`, the blocks of air between
-- the road's walking surface and the deck's underside (a deck is written as a
-- surface course with a support course under it, so its underside is
-- `deck_y - 1`).
--
-- THE RULING it checks (playtest round 3): at least three blocks of air and
-- the street passes under unchanged; fewer and the street climbs onto the
-- route and crosses at grade. So a column is legal when `clear >= 3` or the
-- road is AT OR ABOVE the deck, and illegal at `clear` of 2, 1, 0 or below --
-- the last of which is a street paved inside a bridge.
--
-- `--legacy` runs the same roads with no route geometry at all, which is the
-- road this tree built before the rule: the before half of the measurement.
--
-- Exit status is 1 if any column is illegal, so this is also a gate.
--
-- Plain Lua 5.1 (LuaJIT for the seven-second WP40 construction).

local repo = assert(arg[1], "repository root required")
local seed = assert(arg[2], "world seed required")
local legacy, out_path = false, nil
for index = 3, #arg do
	if arg[index] == "--legacy" then legacy = true else out_path = arg[index] end
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
local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
local highcourt = dofile(wp13 .. "/highcourt.lua")(wp13)
local quadrants = dofile(wp13 .. "/highcourt_quadrants.lua")()
local dur_brannoc = dofile(wp13 .. "/dur_brannoc.lua")(wp13)

-- The two capitals, at the anchor positions `wp40/r7_settlement.lua`'s roster
-- pins them to, with the runs their own blueprint hands the overlay. Dur
-- Brannoc's curtain wall is not a street and is not walked here.
local function concat_lists(...)
	local runs = {}
	for _, list in ipairs({...}) do
		for index = 1, #list do runs[#runs + 1] = list[index] end
	end
	return runs
end

local CAPITALS = {
	{key = "highcourt", race = "human", x = 0, z = -1500,
		runs = concat_lists(highcourt.avenues, highcourt.ring,
			quadrants.lane_runs())},
	{key = "dur_brannoc", race = "dwarf", x = -1800, z = -1500,
		runs = concat_lists(dur_brannoc.avenues, dur_brannoc.ring)},
}

-- THE SEAM, offline. These are the two queries `wp40/r7_settlement.lua` hands
-- the overlay in the engine, answered from the same pure height session:
-- the walkable surface of a column (the ground, or the water standing on it)
-- and the height of a bridge deck that spans it.
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

-- The verdict is read off the BUILT ROAD and not off the rule that built it:
-- the walking surface of a carriageway column is the topmost cell the run
-- wrote there, whichever mode produced it, so the legacy road and the road
-- with the rule are measured by exactly the same sentence.
local HALF = (avenue.WIDTH - 1) / 2
local rows, illegal, spanned = {}, 0, 0
local by_run = {}
for _, capital in ipairs(CAPITALS) do
	local palette = palettes.new(capital.race)
	for _, run in ipairs(capital.runs) do
		local along = (run.axis == "x") and capital.x or capital.z
		local across = (run.axis == "x") and capital.z or capital.x
		local piece = avenue.run(palette, {id = run.id, axis = run.axis,
			at = across + run.at, from = along + run.from, to = along + run.to,
			lamp_phase = along + run.from,
			overhead = (not legacy) and deck or nil}, walkable)
		local top, order = {}, {}
		for _, cell in ipairs(piece.cells) do
			local lane = (run.axis == "x") and (cell.z - piece.at) or
				(cell.x - piece.at)
			if lane >= -HALF and lane <= HALF then
				local key = cell.x .. ":" .. cell.z
				if top[key] == nil then
					order[#order + 1] = {key = key, x = cell.x, z = cell.z, lane = lane}
					top[key] = cell.y
				elseif cell.y > top[key] then
					top[key] = cell.y
				end
			end
		end
		for _, column in ipairs(order) do
			local deck_y = deck(column.x, column.z)
			if deck_y ~= nil then
				spanned = spanned + 1
				local road_y = top[column.key]
				local clear = deck_y - road_y - 2
				local verdict
				if road_y >= deck_y then verdict = "at_grade"
				elseif clear >= avenue.MIN_CLEAR then verdict = "under_clear"
				else verdict = "ILLEGAL" illegal = illegal + 1 end
				rows[#rows + 1] = table.concat({capital.key, run.id, column.lane,
					column.x, road_y, column.z, walkable(column.x, column.z),
					deck_y, clear, verdict}, "\t")
				local key = capital.key .. "\t" .. run.id .. "\t" .. verdict
				by_run[key] = (by_run[key] or 0) + 1
			end
		end
	end
end

-- THE ROAD IS STILL A ROAD, and it is still a per-mapchunk function.
--
--   * every lane climbs by at most one node per column, end to end, so the
--     ruling's "one-block ground steps" is a property of the built road and
--     not of the rule that built it;
--   * the carriageway is FLAT ACROSS at every column a deck spans, so a
--     crossing is a crossing and not a ledge;
--   * and a run CUT at a crossing is, piece for piece, the run built whole.
--     The crossing rule raises columns, a raised column lifts its neighbours,
--     and a piece that did not see the deck would climb differently -- which
--     would be a wall at a mapchunk border exactly where the playtest found
--     the last one.
local function run_spec(capital, run, cut_from, cut_to)
	local along = (run.axis == "x") and capital.x or capital.z
	local across = (run.axis == "x") and capital.z or capital.x
	return {id = run.id, axis = run.axis, at = across + run.at,
		from = cut_from or (along + run.from), to = cut_to or (along + run.to),
		lamp_phase = along + run.from,
		overhead = (not legacy) and deck or nil}
end

local walk_faults, cross_faults, cut_faults, cuts = 0, 0, 0, 0
local lamp_faults = 0
for _, capital in ipairs(CAPITALS) do
	local palette = palettes.new(capital.race)
	for _, run in ipairs(capital.runs) do
		local whole = avenue.run(palette, run_spec(capital, run), walkable)
		local along = (run.axis == "x") and capital.x or capital.z
		local top, low, stack, order = {}, {}, {}, {}
		for _, cell in ipairs(whole.cells) do
			local p = (run.axis == "x") and cell.x or cell.z
			local lane = (run.axis == "x") and (cell.z - whole.at) or
				(cell.x - whole.at)
			if lane >= -HALF and lane <= HALF then
				local key = p .. ":" .. lane
				if top[key] == nil then
					top[key], low[key], stack[key] = cell.y, cell.y, {}
					order[#order + 1] = {key = key, x = cell.x, z = cell.z}
				end
				if cell.y > top[key] then top[key] = cell.y end
				if cell.y < low[key] then low[key] = cell.y end
				stack[key][cell.y] = true
			end
		end
		-- NOTHING THE ROAD WRITES HANGS IN THE AIR. Every carriageway column
		-- is one unbroken stack, and it starts on the ground it was read from
		-- or on the deck that carries it -- which is the abutment question a
		-- bridge narrower than the carriageway asks.
		for _, column in ipairs(order) do
			local key = column.key
			for y = low[key], top[key] do
				if not stack[key][y] then
					walk_faults = walk_faults + 1
					io.stderr:write("gap in the column " .. column.x .. "," ..
						column.z .. " of " .. run.id .. " at y " .. y .. "\n")
				end
			end
			local ground_y = walkable(column.x, column.z)
			local deck_y = deck(column.x, column.z)
			if low[key] ~= ground_y and low[key] ~= deck_y then
				walk_faults = walk_faults + 1
				io.stderr:write("the column " .. column.x .. "," .. column.z ..
					" of " .. run.id .. " starts at " .. low[key] ..
					", neither its ground " .. ground_y .. " nor a deck " ..
					tostring(deck_y) .. "\n")
			end
		end
		for lane = -HALF, HALF do
			for p = whole.from, whole.to - 1 do
				local here, next_one = top[p .. ":" .. lane], top[(p + 1) .. ":" .. lane]
				if here and next_one and math.abs(next_one - here) > 1 then
					walk_faults = walk_faults + 1
					io.stderr:write("step of " .. (next_one - here) .. " in " ..
						run.id .. " lane " .. lane .. " at " .. p .. "\n")
				end
			end
		end
		-- NO STANDARD IS BURIED BY THE CROSSING IT LIGHTS. A lamp's light sits
		-- three courses over its footing, and at a crossing the carriageway
		-- beside it can be six nodes up, so a verge that did not come with the
		-- road leaves the whole standard under the surface -- in the water,
		-- against the abutment. Checked only where a deck is within the
		-- carriageway's reach of the lamp, because a standard beside an
		-- ordinary terrace climb legitimately stands on its own lower ground.
		for _, lamp in ipairs(whole.lamps) do
			local p = (run.axis == "x") and lamp.x or lamp.z
			local near = false
			for step = -8, 8 do
				for lane = -HALF, HALF do
					local x, z
					if run.axis == "x" then x, z = p + step, whole.at + lane
					else x, z = whole.at + lane, p + step end
					if deck(x, z) ~= nil then near = true break end
				end
				if near then break end
			end
			if near then
				local road = nil
				for lane = -HALF, HALF do
					local value = top[p .. ":" .. lane]
					if value ~= nil and (road == nil or value > road) then
						road = value
					end
				end
				if road ~= nil and lamp.y < road then
					lamp_faults = lamp_faults + 1
					io.stderr:write("the standard at " .. lamp.x .. "," .. lamp.z ..
						" lights from " .. lamp.y .. ", under the road at " ..
						road .. " (" .. run.id .. ")\n")
				end
			end
		end
		local cut_at = {}
		for _, crossing in ipairs(whole.crossings) do
			local p = (run.axis == "x") and crossing.x or crossing.z
			local low, high = top[p .. ":" .. -HALF], top[p .. ":" .. -HALF]
			for lane = -HALF, HALF do
				local value = top[p .. ":" .. lane]
				if value < low then low = value end
				if value > high then high = value end
			end
			if high ~= low then
				cross_faults = cross_faults + 1
				io.stderr:write("cross fall of " .. (high - low) .. " across " ..
					run.id .. " at " .. p .. "\n")
			end
			if p > whole.from and p < whole.to then cut_at[p] = true end
			if p - 4 > whole.from then cut_at[p - 4] = true end
			if p + 4 < whole.to then cut_at[p + 4] = true end
		end
		local ordered = {}
		for p in pairs(cut_at) do ordered[#ordered + 1] = p end
		table.sort(ordered)
		for _, p in ipairs(ordered) do
			cuts = cuts + 1
			local union = {}
			for _, side in ipairs({
					{along + run.from, p}, {p + 1, along + run.to}}) do
				local piece = avenue.run(palette,
					run_spec(capital, run, side[1], side[2]), walkable)
				for _, cell in ipairs(piece.cells) do
					union[cell.x .. ":" .. cell.y .. ":" .. cell.z] =
						cell.name .. ":" .. cell.param2
				end
			end
			local missing, extra = 0, 0
			for _, cell in ipairs(whole.cells) do
				local key = cell.x .. ":" .. cell.y .. ":" .. cell.z
				if union[key] ~= cell.name .. ":" .. cell.param2 then
					missing = missing + 1
				end
				union[key] = nil
			end
			for _ in pairs(union) do extra = extra + 1 end
			if missing > 0 or extra > 0 then
				cut_faults = cut_faults + 1
				io.stderr:write("cut of " .. run.id .. " at " .. p .. " differs: " ..
					missing .. " missing, " .. extra .. " extra\n")
			end
		end
	end
end

local out = {"# grug_wp13_lane_routes_v1 seed=" .. seed .. " mode=" ..
	(legacy and "legacy" or "crossing_rule") .. " min_clear=" ..
	avenue.MIN_CLEAR .. "\n",
	"# spanned_columns=" .. spanned .. " illegal=" .. illegal ..
		" walk_faults=" .. walk_faults .. " cross_faults=" .. cross_faults ..
		" cuts=" .. cuts .. " cut_faults=" .. cut_faults ..
		" lamp_faults=" .. lamp_faults .. "\n",
	"capital\trun\tlane\tx\troad_y\tz\tnatural_y\tdeck_y\tclear\tverdict\n"}
for index = 1, #rows do out[#out + 1] = rows[index] .. "\n" end
local keys = {}
for key in pairs(by_run) do keys[#keys + 1] = key end
table.sort(keys)
for _, key in ipairs(keys) do
	out[#out + 1] = "# " .. key .. "\t" .. by_run[key] .. "\n"
end
local text = table.concat(out)
if out_path then
	local file = assert(io.open(out_path, "wb"))
	file:write(text)
	assert(file:close())
else
	io.write(text)
end
io.stderr:write("lane_routes seed=" .. seed .. " mode=" ..
	(legacy and "legacy" or "crossing_rule") .. " spanned=" .. spanned ..
	" illegal=" .. illegal .. " walk_faults=" .. walk_faults ..
	" cross_faults=" .. cross_faults .. " cuts=" .. cuts ..
	" cut_faults=" .. cut_faults .. " lamp_faults=" .. lamp_faults .. "\n")
if illegal > 0 or walk_faults > 0 or cut_faults > 0 or
		((cross_faults > 0 or lamp_faults > 0) and not legacy) then
	os.exit(1)
end
