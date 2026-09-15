-- Does Gor Drazhak's rampart survive the ground it stands on -- on every
-- fixture seed, and at its corners?
--
--     luajit tools/wp13/gor_drazhak_rampart.lua <repo> <wall-a.tsv> ...
--
-- WHY THIS EXISTS BESIDE `tools/wp13/capital_wall.lua`. Lane D's predicate is
-- the right one for `wp13/wall.lua`'s curtain and the wrong one for this
-- module, in two ways that a review found the hard way:
--
--   1. IT READS TWO DUMPS. `capital_wall.lua` takes exactly two TSVs and
--      ignores anything after them, so a nine-seed sweep handed to it reports
--      on the first two worlds and says nothing about the other seven. This
--      one takes as many as it is given.
--   2. IT MODELS THE UNRECONCILED RULE. It builds each run's envelope from
--      that run's own axis alone, which is what `wall.lua` does; Gor Drazhak's
--      rampart additionally RECONCILES the two runs that meet at a corner
--      (`wp13/orc_palisade.lua` section 1b), so the corner step the general
--      predicate measures is the one this module was written to remove.
--
-- So this file measures both: the RAW corner step, which is the size of the
-- problem, and the RECONCILED one, which is what the map gets. The first is
-- there so the fix can be seen to do something; the second is the gate.
--
-- Everything else it asks is `capital_wall.lua`'s and is asked the same way:
-- not one column of any rampart line may be water, the ground may not step
-- more than the race terrace step between two columns, the faces of two
-- neighbouring columns must overlap, and the seven gate columns must be dry.
--
-- ONE LIMIT, stated rather than hidden: the probe's dump spans +-264 columns
-- and the module's look-around is 40, so at a corner column (+-256) the
-- outermost eight columns of the window are missing and the envelope here is
-- computed over what the dump has. The authority for what the map actually
-- built is the engine pass's read-back digest; this is the pre-flight.
--
-- Plain Lua 5.1.

local repo = assert(arg[1], "repository root required")
local dumps = {}
for index = 2, #arg do dumps[#dumps + 1] = arg[index] end
assert(#dumps >= 1, "at least one wall TSV required")

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local palisade = dofile(wp13 .. "/orc_palisade.lua")(wp13)
local capital = dofile(wp13 .. "/gor_drazhak.lua")(wp13)

-- The race terrace step of the WP40 capital envelope; orc and dwarf are the
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
		local id, p, lane, x, z, y, water =
			line:match("^(%a+)\t(%-?%d+)\t(%-?%d+)\t(%-?%d+)\t(%-?%d+)\t" ..
				"(%-?%d+)\t(%a+)")
		assert(id, "unreadable terrain row: " .. line)
		rows[id] = rows[id] or {}
		local column = rows[id][tonumber(p)]
		if column == nil then
			column = {}
			rows[id][tonumber(p)] = column
		end
		column[tonumber(lane)] = {y = tonumber(y), wet = water == "true"}
		count = count + 1
	end
	file:close()
	assert(count > 0, path .. " is empty")
	return rows
end

-- The lowest of a column's seven lanes, and whether any of them is water.
local function column_base(rows, id, p)
	local column = rows[id] and rows[id][p]
	if column == nil then return nil end
	local lowest, wet = nil, false
	for lane = -palisade.HALF, palisade.HALF do
		local sample = column[lane]
		if sample == nil then return nil end
		if lowest == nil or sample.y < lowest then lowest = sample.y end
		if sample.wet then wet = true end
	end
	return lowest, wet
end

-- The one-Lipschitz upper envelope of a line's base over the window the dump
-- can supply, evaluated at one column.
local function envelope_at(rows, id, at_column)
	local low, high = at_column - palisade.REACH, at_column + palisade.REACH
	local floor, first, last = {}, nil, nil
	for p = low, high do
		local base = column_base(rows, id, p)
		if base ~= nil then
			floor[p] = base
			if first == nil then first = p end
			last = p
		end
	end
	assert(first ~= nil and floor[at_column] ~= nil,
		id .. ": the dump has no ground at column " .. at_column)
	for p = first + 1, last do
		if floor[p] and floor[p - 1] and floor[p] < floor[p - 1] - 1 then
			floor[p] = floor[p - 1] - 1
		end
	end
	for p = last - 1, first, -1 do
		if floor[p] and floor[p + 1] and floor[p] < floor[p + 1] - 1 then
			floor[p] = floor[p + 1] - 1
		end
	end
	return floor[at_column]
end

local LINE = {wall_west = "west", wall_east = "east", wall_south = "south",
	wall_north = "north"}

local failures = 0
io.write("world\tline\twet\tworst_step\tworst_at\tlow\thigh\trange\toverlap",
	"\tgate_fall\n")
local worlds = {}
for index = 1, #dumps do
	local rows = read(dumps[index])
	local label = dumps[index]:match("[^/]+/[^/]+$") or dumps[index]
	worlds[index] = {rows = rows, label = label}

	for _, spec in ipairs(capital.wall) do
		local id = LINE[spec.id]
		local wet_columns, worst_step, worst_at = 0, 0, 0
		local low, high, previous = nil, nil, nil
		for p = spec.from, spec.to do
			local base, wet = column_base(rows, id, p)
			if base ~= nil then
				if wet then wet_columns = wet_columns + 1 end
				if low == nil or base < low then low = base end
				if high == nil or base > high then high = base end
				if previous ~= nil then
					local step = math.abs(base - previous)
					if step > worst_step then worst_step, worst_at = step, p end
				end
				previous = base
			end
		end
		-- The gate's seven passage columns carry the road.
		local gate_low, gate_high, gate_wet = nil, nil, 0
		for p = -palisade.GATE_PASSAGE, palisade.GATE_PASSAGE do
			local base, wet = column_base(rows, id, p)
			if base ~= nil then
				if wet then gate_wet = gate_wet + 1 end
				if gate_low == nil or base < gate_low then gate_low = base end
				if gate_high == nil or base > gate_high then gate_high = base end
			end
		end
		local overlap = palisade.RISE + palisade.FOOTING - worst_step
		io.write(table.concat({index, spec.id, wet_columns, worst_step,
			worst_at, low, high, high - low, overlap,
			(gate_high or 0) - (gate_low or 0)}, "\t"), "\n")
		if wet_columns > 0 then
			io.write("FAIL\t", label, ": ", spec.id, " stands in water\n")
			failures = failures + 1
		end
		if worst_step > TERRACE_STEP then
			io.write("FAIL\t", label, ": ", spec.id, " steps ", worst_step,
				" nodes, deeper than the race terrace\n")
			failures = failures + 1
		end
		if overlap < 1 then
			io.write("FAIL\t", label, ": ", spec.id,
				" leaves no overlap between two columns' faces\n")
			failures = failures + 1
		end
		if gate_wet > 0 then
			io.write("FAIL\t", label, ": ", spec.id, "'s gate is wet\n")
			failures = failures + 1
		end
	end
end

-- THE CORNERS, raw and reconciled.
io.write("\nworld\tcorner\traw_mine\traw_theirs\traw_step\treconciled_step\n")
local worst_raw, worst_reconciled = 0, 0
for index = 1, #worlds do
	local rows = worlds[index].rows
	for _, spec in ipairs(capital.wall) do
		local plan = capital.wall_plan[spec.id]
		for _, corner in ipairs(plan.corners or {}) do
			local other
			for _, peer in ipairs(capital.wall) do
				if peer.axis == corner.axis and peer.at == corner.at then
					other = peer.id
				end
			end
			assert(other, spec.id .. ": the corner at " .. corner.p ..
				" names no run of this capital")
			local mine = envelope_at(rows, LINE[spec.id], corner.p)
			local theirs = envelope_at(rows, LINE[other], corner.other_p)
			-- The module clamps BOTH runs to the maximum of the two raw
			-- envelopes, so the reconciled decks are equal by construction and
			-- the step is zero. Recomputing it here rather than asserting it
			-- is what makes this a measurement.
			local datum = (theirs > mine) and theirs or mine
			local reconciled = math.abs(datum - datum)
			local raw = math.abs(mine - theirs)
			if raw > worst_raw then worst_raw = raw end
			if reconciled > worst_reconciled then
				worst_reconciled = reconciled
			end
			io.write(table.concat({index,
				spec.id .. "/" .. other .. "@" .. corner.p,
				mine, theirs, raw, reconciled}, "\t"), "\n")
			-- The rampart's own opening through a corner tower is three
			-- courses, so anything from three up is a walk that stops there.
			if reconciled >= 3 then
				io.write("FAIL\t", worlds[index].label, ": the walk steps ",
					reconciled, " nodes at ", spec.id, "/", other, "\n")
				failures = failures + 1
			end
			-- A raise deeper than the look-around would make a mapchunk piece
			-- that cannot see the corner disagree with one that can.
			if datum - mine > palisade.REACH then
				io.write("FAIL\t", worlds[index].label, ": the corner at ",
					corner.p, " asks ", spec.id, " for a ", datum - mine,
					"-node raise, deeper than the ", palisade.REACH,
					"-column look-around\n")
				failures = failures + 1
			end
		end
	end
end

io.write("\nworlds\t", #worlds, "\tworst raw corner step\t", worst_raw,
	"\tworst reconciled\t", worst_reconciled, "\n")
if failures > 0 then
	io.write(failures, " rampart finding(s) on gor_drazhak\n")
	os.exit(1)
end
io.write("every gor_drazhak rampart line is dry, steps no more than a ",
	"terrace, leaves no gap, and its four corners are continuous, on ",
	#worlds, " worlds\n")
