-- Where a Nhal Veyr district lot may stand, and where it may not.
--
--     luajit tools/wp13/nhal_veyr_plots.lua <repo> <grid.tsv>...
--     luajit tools/wp13/nhal_veyr_plots.lua <repo> <grid.tsv>... --repair
--
-- The default run VERIFIES the 36 lots `wp13/nhal_veyr_quadrants.lua` carries,
-- the 16 FILL LOTS it carries beside them, and the 52 plots the four districts
-- build, against every rule below, on EVERY WORLD it is given at once.
-- `--repair` moves only the lots that no longer stand, so the committed tables
-- are re-derivable rather than remembered.
--
-- ALL NINE SEEDS AND NOT TWO. The wave-2 coordinator's review of the first two
-- capitals found twenty-one illegal lots on seeds a lane had not looked at: a
-- grid derived against two worlds is a grid nobody has asked a third about, and
-- the seeds of `tools/wp13/capital_anchor_fixture.lua` are the nine the rest of
-- this package is measured on. Any number of grids is accepted; they must not
-- all be the same world.
--
-- It is `tools/wp13/highcourt_plots.lua`'s predicate for this capital. That
-- file is the pilot's own committed gate and stays exactly as it is; this one
-- is the same questions asked of Nhal Veyr's grids, and it reads a COARSER
-- input, which is the one thing worth knowing before trusting it.
--
-- THE INPUT IS THE 4-NODE GRID, AND THE ENGINE IS THE AUTHORITY.
-- `tools/wp13/run_capital.sh <out> nhal_veyr terrain <seed>` dumps the pure
-- final height and the land/water class of every fourth column of the 512
-- envelope and its collar (`capital_probe`'s `grid_report`), which is what a
-- capital that is not yet on the roster can be measured with -- Highcourt's
-- own `field` dump is that capital's probe's and is not offered for any other.
-- Sampling every fourth column UNDERSTATES a relief, and by how much is
-- measured and not guessed: against the 1-node wall lines of the same dumps,
-- over the same 31-column window at 464 window positions per seed, a FALL by
-- at most one node and a RISE by at most two (`terrain/calibration.txt` of the
-- evidence directory). So this tool holds a district lot to a fall of 5 and a
-- rise of 6 where the real limits are 6 and the plot's own airspace clear of at
-- least 8, and a fill lot to a rise of 5 because a yard plot clears the
-- builder's floor of 8 and nothing more. Every margin is the measured error or
-- better.
--
-- What decides in the end is the ENGINE: `run_capital.sh <out> nhal_veyr
-- surface <seed>` measures every plot's perimeter, footprint and margin column
-- by column on the real world and the seam's own load-time `audit_terrain`
-- runs beside it, on all nine seeds of `capital_anchor_fixture.lua`. This tool
-- is the pre-flight that keeps a composition from reaching one.
--
-- THE RULES, in the order they refuse:
--
--   1. DRY. Not one column of the lot's own footprint may be water, and
--      neither may its two-node margin. A plot is not a pier. (No column of
--      this capital's envelope is water on any of the nine seeds, which is
--      what makes this rule cheap here and not pointless: the day WP40's
--      terrain changes, it is what says so.)
--   2. STANDS ON ITS OWN GROUND. The fall under the footprint, measured from
--      the lot's own reference column, may not exceed the foundation skirt.
--   3. FITS UNDER ITS OWN ROOF. The rise may not exceed the airspace a plot
--      clears.
--   4. INSIDE THE ENVELOPE, and inside its own QUARTER: taken back to the
--      south-east frame a lot stays in the quarter its grid belongs to, or the
--      permutation would move a district into a neighbour's ground.
--   5. OFF THE CORE, off all four 32-node gate corridors, off every street run
--      the capital's overlay writes -- the four avenues, the ring street, the
--      eight district lanes AND the curtain -- and a lane clear of every other
--      lot of every other quadrant (8 between district lots, 4 for a fill lot,
--      which is what "loose, with fields and gardens" is as arithmetic).
--
-- The grid TSVs must not all be the same seed, which this tool checks by
-- refusing a set whose heights are identical everywhere.
--
-- Plain Lua 5.1.

local repo = assert(arg[1], "repository root required")
local paths, mode = {}, nil
for index = 2, #arg do
	if arg[index]:sub(1, 2) == "--" then
		mode = arg[index]
	else
		paths[#paths + 1] = arg[index]
	end
end
assert(#paths >= 2, "at least two terrain grid TSVs are required")

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
local wall = dofile(wp13 .. "/wall.lua")(wp13)
local capital = dofile(wp13 .. "/nhal_veyr.lua")(wp13)
local quadrants = dofile(wp13 .. "/nhal_veyr_quadrants.lua")()
local districts = dofile(wp13 .. "/nhal_veyr_districts.lua")(wp13)

local LOT = quadrants.LOT
local FILL = quadrants.FILL
local CORE = 48                       -- the core's own +-47 plus a node
local GATE_CORRIDOR = 16              -- half of WP40's 32-node gate corridor
local ENVELOPE = 250                  -- one node clear of the gate stations
-- The sampling step of the grid dump, and the margin the tool keeps for the
-- node it can miss between two samples (see the header).
local STEP = 4
local MAX_FALL = LOT.fall - 1
local MAX_RISE = LOT.rise
local MAX_FILL_RISE = LOT.rise - 1

local function read_grid(path)
	local rows, count = {}, 0
	local file = assert(io.open(path, "r"), "cannot read " .. path)
	local header = file:read("*l")
	assert(header and header:find("terrain_y", 1, true),
		path .. " is not a capital terrain grid dump")
	for line in file:lines() do
		local x, z, y, water = line:match("^(%-?%d+)\t(%-?%d+)\t(%-?%d+)\t(%a+)")
		assert(x, "unreadable grid row: " .. line)
		rows[x .. ":" .. z] = {y = tonumber(y), wet = water == "true"}
		count = count + 1
	end
	file:close()
	assert(count > 0, path .. " is empty")
	return rows, count
end

local worlds = {}
local columns
for index = 1, #paths do
	local grid, count = read_grid(paths[index])
	columns = columns or count
	assert(count == columns, paths[index] ..
		" does not cover the same columns as the first grid")
	worlds[#worlds + 1] = grid
end
do
	local differs = false
	for key, row in pairs(worlds[1]) do
		for index = 2, #worlds do
			local other = assert(worlds[index][key],
				"the grids do not cover the same columns")
			if other.y ~= row.y then differs = true end
		end
	end
	assert(differs, "every grid is the same world; use different seeds")
end

local function snap(value)
	return math.floor(value / STEP + 0.5) * STEP
end

-- The relief a lot of this reach would see: the fall and the rise from its own
-- reference column over the footprint AND its margin, on one world.
local function relief(grid, cx, cz, reach)
	local span = reach + LOT.margin
	local reference = grid[snap(cx) .. ":" .. snap(cz)]
	if not reference then return nil end
	if reference.wet then return nil, "reference_in_water" end
	local low, high = reference.y, reference.y
	for dz = -span, span, STEP do
		for dx = -span, span, STEP do
			local cell = grid[snap(cx + dx) .. ":" .. snap(cz + dz)]
			if not cell then return nil, "unscanned" end
			if cell.wet then return nil, "submerged" end
			if cell.y < low then low = cell.y end
			if cell.y > high then high = cell.y end
		end
	end
	return reference.y - low, high - reference.y
end

-- The WORST a lot sees over every world it was given. One world's verdict is
-- not a verdict: a position legal on eight seeds and submerged on the ninth is
-- a position this table may not carry.
local function terrain(cx, cz, reach, max_rise)
	local fall, rise = 0, 0
	for index = 1, #worlds do
		local world_fall, world_rise = relief(worlds[index], cx, cz, reach)
		if world_fall == nil then
			return nil, nil, world_rise or "unscanned"
		end
		if world_fall > fall then fall = world_fall end
		if world_rise > rise then rise = world_rise end
	end
	if fall > MAX_FALL then return fall, rise, "fall:" .. fall end
	if rise > max_rise then return fall, rise, "rise:" .. rise end
	return fall, rise
end

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
for index = 1, #capital.wall do
	add_run(capital.wall[index], wall.HALF)
end

local function overlaps(a1, a2, b1, b2) return a1 <= b2 and b1 <= a2 end

local function unrotate(x, z, turns)
	for _ = 1, (turns % 4) do x, z = z, -x end
	return x, z
end

-- Geometry only: everything that can be decided without terrain. `placed` is
-- the list of lots already accepted, each with its own lane.
local function geometry(x, z, reach, lane, turns, placed, skip)
	local span = reach + LOT.margin
	local min_x, max_x, min_z, max_z = x - span, x + span, z - span, z + span
	if min_x < -ENVELOPE or max_x > ENVELOPE or min_z < -ENVELOPE or
			max_z > ENVELOPE then
		return "envelope"
	end
	-- IN ITS OWN QUARTER, and by the KAT's own arithmetic rather than a looser
	-- one of this tool's: rotated back into the authored south-east frame the
	-- lot's whole FOOTPRINT has to clear both avenues by the quarter's margin,
	-- so it is `quarter + reach` and not `quarter + a number`. The two used to
	-- differ by five nodes and the KAT was the one that said so.
	local qx, qz = unrotate(x, z, turns)
	if qx - reach < LOT.quarter or qz + reach > -LOT.quarter then
		return "quarter"
	end
	if overlaps(min_x, max_x, -CORE, CORE) and
			overlaps(min_z, max_z, -CORE, CORE) then
		return "core"
	end
	if overlaps(min_z, max_z, -GATE_CORRIDOR, GATE_CORRIDOR) then
		return "gate_corridor_x"
	end
	if overlaps(min_x, max_x, -GATE_CORRIDOR, GATE_CORRIDOR) then
		return "gate_corridor_z"
	end
	for _, run in ipairs(runs) do
		if overlaps(min_x, max_x, run.min_x, run.max_x) and
				overlaps(min_z, max_z, run.min_z, run.max_z) then
			return "street:" .. run.id
		end
	end
	for _, other in ipairs(placed) do
		if other.id ~= skip then
			local other_span = other.reach + LOT.margin + lane
			if overlaps(min_x, max_x, other.x - other_span,
					other.x + other_span) and
					overlaps(min_z, max_z, other.z - other_span,
						other.z + other_span) then
				return "lot:" .. other.id
			end
		end
	end
	return nil
end

-- The lots, in the order a district's plots take them, with the quadrant they
-- belong to and the turn that takes them back to the south-east frame.
local schedule = {}
for index = 1, #quadrants.QUADRANTS do
	local quadrant = quadrants.QUADRANTS[index]
	local turns = index - 1
	for lot = 1, #quadrants.LOTS[quadrant] do
		local entry = quadrants.LOTS[quadrant][lot]
		schedule[#schedule + 1] = {id = quadrant .. "/lot" .. lot,
			kind = "lot", quadrant = quadrant, turns = turns, slot = lot,
			x = entry.x, z = entry.z, reach = LOT.reach, lane = LOT.lane,
			max_rise = MAX_RISE}
	end
end
for index = 1, #quadrants.QUADRANTS do
	local quadrant = quadrants.QUADRANTS[index]
	local turns = index - 1
	for lot = 1, #quadrants.FILL_LOTS[quadrant] do
		local entry = quadrants.FILL_LOTS[quadrant][lot]
		schedule[#schedule + 1] = {id = quadrant .. "/fill" .. lot,
			kind = "fill", quadrant = quadrant, turns = turns, slot = lot,
			x = entry.x, z = entry.z,
			reach = quadrants.FILL_AUTHORED[lot].reach, lane = FILL.lane,
			max_rise = MAX_FILL_RISE}
	end
end

local failures = 0
local placed = {}
io.write("lot\tkind\tx\tz\treach\tverdict\tfall\trise\n")
for _, entry in ipairs(schedule) do
	local why = geometry(entry.x, entry.z, entry.reach, entry.lane,
		entry.turns, placed, entry.id)
	local fall, rise = "-", "-"
	if why == nil then
		local measured_fall, measured_rise
		measured_fall, measured_rise, why =
			terrain(entry.x, entry.z, entry.reach, entry.max_rise)
		fall = measured_fall or "-"
		rise = measured_rise or "-"
	end
	if why ~= nil then failures = failures + 1 end
	placed[#placed + 1] = {id = entry.id, x = entry.x, z = entry.z,
		reach = entry.reach}
	io.write(table.concat({entry.id, entry.kind, entry.x, entry.z, entry.reach,
		why and ("ILLEGAL " .. why) or "legal", fall, rise}, "\t"), "\n")
end

-- THE PLOT SIDE of the same rule: every plot of every district fits inside the
-- lot envelope its grid was chosen for, and clears at least the airspace the
-- lots were chosen against. A lot may carry ANY district's plot, so this is
-- asked of all 52 at once and not per quadrant.
local plot_failures = 0
io.write("\nplot\tkind\tbounds_x\tbounds_z\tclear_to\tverdict\n")
for _, plot in ipairs(districts.resolve()) do
	local composition = plot.build()
	local bounds = composition.bounds
	local reach = (plot.kind == "fill") and
		quadrants.FILL_AUTHORED[plot.lot].reach or LOT.reach
	local widest = math.max(math.abs(bounds.min.x), math.abs(bounds.max.x))
	local deepest = math.max(math.abs(bounds.min.z), math.abs(bounds.max.z))
	local clear = composition.clear_to or bounds.max.y
	local why
	if widest > reach or deepest > reach then
		why = "wider than its lot: " .. widest .. "x" .. deepest ..
			" against " .. reach
	elseif clear < LOT.clear then
		why = "clears " .. clear .. ", not " .. LOT.clear
	elseif bounds.min.y < -LOT.fall then
		why = "reaches y " .. bounds.min.y .. " below the skirt"
	end
	if why then plot_failures = plot_failures + 1 end
	io.write(table.concat({plot.id, plot.kind, widest, deepest, clear,
		why and ("ILLEGAL " .. why) or "legal"}, "\t"), "\n")
end

-- `--repair` is the mode a TERRAIN change needs: every lot that still stands
-- keeps its authored position and only the ones that no longer do take the
-- nearest position that does, with the lots already placed blocking the ground
-- they stand on. Nearest, not flattest: the authored layout is a design, and
-- sorting on flatness alone inside a terraced envelope finds the bottom of the
-- deepest cut.
if mode == "--repair" or mode == "--derive" then
	io.write("\n== proposed grids\n")
	local kept = {}
	for _, entry in ipairs(schedule) do
		local ok = geometry(entry.x, entry.z, entry.reach, entry.lane,
			entry.turns, kept) == nil
		local fall, rise
		if ok then
			local why
			fall, rise, why = terrain(entry.x, entry.z, entry.reach,
				entry.max_rise)
			ok = why == nil
		end
		if ok and mode == "--repair" then
			kept[#kept + 1] = {id = entry.id, x = entry.x, z = entry.z,
				reach = entry.reach}
			io.write(string.format("%-22s keep  x=%5d z=%5d fall=%d rise=%d\n",
				entry.id, entry.x, entry.z, fall, rise))
		else
			local best
			for dz = -60, 60, 2 do
				for dx = -60, 60, 2 do
					local nx, nz = entry.x + dx, entry.z + dz
					if geometry(nx, nz, entry.reach, entry.lane, entry.turns,
							kept) == nil then
						local candidate_fall, candidate_rise, why =
							terrain(nx, nz, entry.reach, entry.max_rise)
						if why == nil then
							local distance = math.abs(dx) + math.abs(dz)
							if not best or distance < best.distance then
								best = {x = nx, z = nz, fall = candidate_fall,
									rise = candidate_rise, distance = distance}
							end
						end
					end
				end
			end
			assert(best, "no legal home for " .. entry.id)
			kept[#kept + 1] = {id = entry.id, x = best.x, z = best.z,
				reach = entry.reach}
			io.write(string.format(
				"%-22s MOVE  x=%5d z=%5d fall=%d rise=%d (was %d,%d, move %d)\n",
				entry.id, best.x, best.z, best.fall, best.rise, entry.x,
				entry.z, best.distance))
		end
	end
end

if failures > 0 or plot_failures > 0 then
	io.write("\n", failures, " lot(s) and ", plot_failures,
		" plot(s) of nhal_veyr are somewhere they may not be\n")
	os.exit(1)
end
io.write("\nevery nhal_veyr lot is dry, inside the skirt and under its own ",
	"roof on every world, and every plot fits the lot it stands on\n")
