-- Does the curtain wall survive the ground it is built on?
--
--     luajit tools/wp13/capital_wall.lua <repo> <key> <wall-a.tsv> <wall-b.tsv>
--
-- The KAT proves the wall module's rules on a synthetic profile. This asks the
-- other half of the question -- whether the REAL terrain under the four wall
-- lines is the kind of ground those rules were written for -- and it asks it on
-- both gate seeds at once, because a wall that stands on one world's terrain
-- has not been checked.
--
-- The TSVs come from `tools/wp13/run_capital.sh <out> <key> terrain <seed>`:
-- one row per column of each candidate wall line, lane by lane across the
-- wall's own thickness, carrying the final terrain height and whether the map
-- calls that column water.
--
-- WHAT IT CHECKS, and why each one is a way a wall fails:
--
--   1. DRY. Not one column of any wall line may be water. A curtain wall is not
--      a bridge, and the settlement writer is water-agnostic: it would build a
--      rampart across a river bed with the water standing in the rubble.
--   2. THE STEP IS A TERRACE STEP. The ground along a line may not change by
--      more than the race's own terrace step between two columns. The walk is
--      the one-Lipschitz envelope of that ground plus the rise, so a cliff
--      under the line is a wall that leaves the ground -- which is legal, and
--      buildable, and ugly, and worth knowing about before it is built.
--   3. NO GAP IS POSSIBLE. This is the property the whole design turns on, and
--      it is checked here against the real ground rather than assumed: every
--      column's masonry starts at its own lowest ground minus the footing, and
--      the envelope is everywhere at or above that, so the fill is a closed
--      interval per column and the faces of two neighbouring columns overlap by
--      at least (rise + footing - step) courses. That number is printed.
--   4. THE GATE IS DRY AND FLAT. The seven passage columns of each gate carry
--      the road, so they are checked for water and for their own fall.
--   5. THE CORNER STEP. The two runs that meet at a corner compute their decks
--      from different neighbourhoods, so the walk can have a step where they
--      meet. It is measured -- here, on the real ground, on both seeds -- and
--      reported, because nothing in the composition can see it.
--
-- Plain Lua 5.1.

local repo = assert(arg[1], "repository root required")
local key = assert(arg[2], "settlement key required")
local scan_a = assert(arg[3], "first terrain TSV required")
local scan_b = assert(arg[4], "second terrain TSV required")

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local wall = dofile(wp13 .. "/wall.lua")(wp13)
local capital = dofile(wp13 .. "/" .. key .. ".lua")(wp13)

-- The race terrace step of the WP40 capital envelope, dwarf and orc being the
-- deepest at four (`wp13-capitals-pois-contract.md` section 1).
local TERRACE_STEP = 4

local function read(path)
	local rows = {}
	local file = assert(io.open(path, "r"), "cannot read " .. path)
	local header = file:read("*l")
	assert(header and header:find("terrain_y", 1, true),
		path .. " is not a terrain dump")
	local count = 0
	for line in file:lines() do
		local line_id, p, lane, x, z, y, water =
			line:match("^(%a+)\t(%-?%d+)\t(%-?%d+)\t(%-?%d+)\t(%-?%d+)\t" ..
				"(%-?%d+)\t(%a+)")
		assert(line_id, "unreadable terrain row: " .. line)
		rows[line_id] = rows[line_id] or {}
		local column = rows[line_id][tonumber(p)]
		if column == nil then
			column = {}
			rows[line_id][tonumber(p)] = column
		end
		column[tonumber(lane)] = {y = tonumber(y), wet = water == "true",
			x = tonumber(x), z = tonumber(z)}
		count = count + 1
	end
	file:close()
	assert(count > 0, path .. " is empty")
	return rows
end

local worlds = {{name = "a", rows = read(scan_a)},
	{name = "b", rows = read(scan_b)}}

-- The composition's own four runs, mapped onto the terrain dump's line names.
-- The dump names the four candidate lines by compass; the composition names
-- them by run id, and the two have to be the same lines or this tool is
-- measuring somewhere else.
local LINE_OF = {wall_west = "west", wall_east = "east",
	wall_south = "south", wall_north = "north"}

local failures = 0
local function fail(message)
	failures = failures + 1
	io.write("FAIL\t", message, "\n")
end

io.write("world\tline\twet\tworst_step\tworst_step_at\tlow\thigh\trange" ..
	"\toverlap\tgate_fall\n")
local decks = {}
for _, world in ipairs(worlds) do
	decks[world.name] = {}
	for _, spec in ipairs(capital.wall) do
		local line = assert(LINE_OF[spec.id], "no terrain line for " .. spec.id)
		local columns = assert(world.rows[line],
			"the terrain dump has no line " .. line)
		local wet, worst_step, worst_at = 0, 0, 0
		local low, high, previous
		local base = {}
		-- THE SAME WINDOW THE MODULE USES, which is the run's own span plus the
		-- look-around either side (`wall.lua`, section 1: `low_end, high_end =
		-- from - reach, to + reach`). The first version of this tool built the
		-- envelope over [from, to] alone and therefore did not compute the deck
		-- the map actually has: on the user seed that moved three columns of
		-- `wall_west` and one of `wall_north`, and with them the corner step it
		-- reports. A tool that models the module has to model all of it.
		--
		-- The dump is sampled over a fixed span, so the window is clipped to
		-- what was measured; the summary columns below still describe the RUN.
		local window_from = spec.from - wall.REACH
		local window_to = spec.to + wall.REACH
		local measured_from, measured_to
		for p in pairs(columns) do
			if measured_from == nil or p < measured_from then measured_from = p end
			if measured_to == nil or p > measured_to then measured_to = p end
		end
		if window_from < measured_from then window_from = measured_from end
		if window_to > measured_to then window_to = measured_to end
		for p = window_from, window_to do
			local lanes = columns[p]
			assert(lanes, "the terrain dump has no column " .. p ..
				" of line " .. line)
			local lowest
			for lane = -wall.HALF, wall.HALF do
				local sample = assert(lanes[lane],
					"the terrain dump has no lane " .. lane .. " at " .. p)
				if sample.wet and p >= spec.from and p <= spec.to then
					wet = wet + 1
				end
				if lowest == nil or sample.y < lowest then lowest = sample.y end
			end
			base[p] = lowest
			if p >= spec.from and p <= spec.to then
				if low == nil or lowest < low then low = lowest end
				if high == nil or lowest > high then high = lowest end
				if previous ~= nil then
					local step = math.abs(lowest - previous)
					if step > worst_step then worst_step, worst_at = step, p end
				end
				previous = lowest
			end
		end

		-- 3. The overlap of two neighbouring columns' masonry: the lower column
		-- is filled from its own ground minus the footing up to its own deck,
		-- and its neighbour's fill starts at most `worst_step` higher, so the
		-- two faces share at least this many courses. A number of one or more
		-- is what "no gap" means as arithmetic.
		local overlap = wall.RISE + wall.FOOTING - worst_step

		-- 1-Lipschitz envelope of the base over the whole window, which is what
		-- the module builds.
		local level = {}
		for p = window_from, window_to do level[p] = base[p] end
		for p = window_from + 1, window_to do
			if level[p] < level[p - 1] - 1 then level[p] = level[p - 1] - 1 end
		end
		for p = window_to - 1, window_from, -1 do
			if level[p] < level[p + 1] - 1 then level[p] = level[p + 1] - 1 end
		end
		decks[world.name][spec.id] = {}
		for p = spec.from, spec.to do
			decks[world.name][spec.id][p] = level[p] + wall.RISE
		end

		-- 4. The gate, which is also the road.
		local gate_low, gate_high
		for p = -wall.GATE_PASSAGE, wall.GATE_PASSAGE do
			local lanes = columns[p]
			for lane = -wall.HALF, wall.HALF do
				local sample = lanes[lane]
				if sample.wet then
					fail(world.name .. "/" .. spec.id ..
						": the gate passage is water at " .. p .. "," .. lane)
				end
				if gate_low == nil or sample.y < gate_low then gate_low = sample.y end
				if gate_high == nil or sample.y > gate_high then
					gate_high = sample.y
				end
			end
		end

		if wet > 0 then
			fail(world.name .. "/" .. spec.id .. ": " .. wet ..
				" columns of this wall line are water")
		end
		if worst_step > TERRACE_STEP then
			fail(world.name .. "/" .. spec.id .. ": the ground steps " ..
				worst_step .. " nodes at column " .. worst_at ..
				", more than the race terrace step of " .. TERRACE_STEP)
		end
		if overlap < 1 then
			fail(world.name .. "/" .. spec.id ..
				": two neighbouring columns of masonry share " .. overlap ..
				" courses, so the curtain can show a gap")
		end
		io.write(table.concat({world.name, spec.id, wet, worst_step, worst_at,
			low, high, high - low, overlap, gate_high - gate_low}, "\t"), "\n")
	end
end

-- 5. The corner step: where an x-run's walk arrives at the z-run's corner
-- turret, the two decks are computed from different neighbourhoods and can
-- disagree. The turret's own rampart opening is three courses high, so a step
-- of one or two is walked through it; more is a step a patrol cannot take.
--
-- It is not always zero. With the look-around window the module really uses,
-- the user seed shows a one-node step where `wall_north` meets `wall_west`'s
-- corner turret (built decks 104 and 103), which the opening walks. The first
-- version of this tool reported zero everywhere because it left the window out.
io.write("\nworld\tcorner\tz_run_deck\tx_run_deck\tstep\n")
local CORNER_OPENING = 3
for _, world in ipairs(worlds) do
	for _, along in ipairs({{"wall_west", -256}, {"wall_east", 256}}) do
		for _, across in ipairs({{"wall_south", -256}, {"wall_north", 256}}) do
			local turret = decks[world.name][along[1]][across[2]]
			local arriving = decks[world.name][across[1]][along[2] -
				(along[2] > 0 and wall.HALF + 1 or -(wall.HALF + 1))]
			if turret and arriving then
				local step = math.abs(turret - arriving)
				io.write(table.concat({world.name,
					along[1] .. "/" .. across[1], turret, arriving, step},
					"\t"), "\n")
				if step >= CORNER_OPENING then
					fail(world.name .. ": the walk steps " .. step ..
						" nodes where " .. across[1] .. " meets the corner " ..
						"turret of " .. along[1] .. ", and the turret's own " ..
						"opening is only " .. CORNER_OPENING .. " courses high")
				end
			end
		end
	end
end

if failures > 0 then
	io.write("\n", failures, " wall finding(s) on ", key, "\n")
	os.exit(1)
end
io.write("\nevery ", key, " wall line is dry, steps no more than a terrace, ",
	"and leaves no gap on either world\n")
