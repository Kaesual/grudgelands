-- Where a CAPITAL's district lots may stand, and where they may not.
--
--     luajit tools/wp13/capital_lots.lua <repo> <key> <field.tsv>...
--     luajit tools/wp13/capital_lots.lua <repo> <key> <field.tsv>... --derive
--     luajit tools/wp13/capital_lots.lua <repo> <key> <field.tsv>... --derive-fill
--     luajit tools/wp13/capital_lots.lua <repo> <key> <field.tsv>... --repair
--
-- This is `tools/wp13/highcourt_plots.lua` with two things lifted out of it:
-- the CAPITAL (it takes a roster key and reads the quadrants and the district
-- rosters off the composition, so any capital that publishes them can use it)
-- and the NUMBER OF WORLDS (it takes as many field dumps as it is given, and a
-- lot is legal only where it is legal on every one of them). That file is the
-- pilot capital's own committed predicate and stays exactly as it is.
--
-- TWO WORLDS WERE NOT ENOUGH, which is the reason this file exists rather than
-- a second argument to that one. Wave 1 measured Highcourt's 36 lots on the two
-- gate seeds; the round-1 playtest then produced an `audit_terrain` warning
-- ("martial_wood_yard rise 10 against clear 8") on the user's own seed, which
-- is to say a plot that is legal on two worlds can be illegal on a third. The
-- seed set of `tools/wp13/capital_anchor_fixture.lua` is nine worlds and this
-- tool takes all nine.
--
-- WHAT A CAPITAL HAS TO PUBLISH for this tool to work on it: its composition
-- (`wp13/<key>.lua`) carries `avenues`, `ring`, optionally `wall`, and
-- `quadrants` (the module of `wp13/<key>_quadrants.lua`); the district roster
-- (`districts`, with `resolve()`) is optional and is what turns on the third
-- section, "every plot against the envelope of the lot it stands on". A capital
-- that publishes no quadrants module is refused here and keeps using
-- `tools/wp13/capital_plots.lua`, which asks the same questions of a
-- single-district capital.
--
-- A FILL LOT is a district lot with two differences: it carries its own reach,
-- because the four fill slots are four deliberately different sizes, and its
-- lane is the fill lane rather than the district lane. Every other rule below
-- is the same one, applied to the same fields, and a fill lot is additionally
-- held clear of every district lot of its own quadrant.
--
-- `--repair` is the mode a TERRAIN change needs: every lot that still stands
-- keeps its authored position and only the ones that no longer do take the
-- nearest position that does. `--derive` searches the whole-quadrant
-- translation again and will happily slide nine lots forty nodes to save one of
-- them a four-node move, which is the right answer when the grid is being
-- INVENTED and the wrong one when the ground under a finished city has moved by
-- a node.
--
-- THE RULES, in the order they refuse:
--
--   1. DRY. Not one column of the lot's footprint may be water, and neither may
--      its margin ring. A plot is not a pier.
--   2. STANDS ON ITS OWN GROUND. The fall under the footprint's PERIMETER,
--      measured from the lot's own reference column, may not exceed the
--      foundation skirt, on EVERY world; the perimeter is what the skirt
--      carries down.
--   3. FITS UNDER ITS OWN ROOF. The rise under the footprint may not exceed the
--      lot's rise, on every world, against an airspace clear of at least the
--      lot's clear.
--   4. INSIDE THE ENVELOPE, one node clear of the gate stations at +-256.
--   5. OFF THE CORE, off all four 32-node gate corridors, off every street run
--      the capital's overlay writes -- avenues, ring, district lanes AND, for a
--      walled capital, the curtain -- inside its OWN quarter, and a lane clear
--      of every other lot of the same quadrant.
--
-- The field TSVs come from `tools/wp13/run_capital.sh <out> <key> field <seed>`:
-- the pure final height and the land/water class of every column of the
-- capital's envelope, read once. They must be different worlds, which this tool
-- checks by refusing a set whose heights are identical everywhere.
--
-- Plain Lua 5.1.

local repo = assert(arg[1], "repository root required")
local key = assert(arg[2], "settlement key required")
local paths, mode = {}, nil
for index = 3, #arg do
	local value = arg[index]
	if value:sub(1, 2) == "--" then mode = value else paths[#paths + 1] = value end
end
assert(#paths >= 2, "at least two field TSVs required")
local derive = mode == "--derive"
local repair = mode == "--repair"
local derive_fill = mode == "--derive-fill"

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
local wall = dofile(wp13 .. "/wall.lua")(wp13)
local capital = dofile(wp13 .. "/" .. key .. ".lua")(wp13)
assert(type(capital.quadrants) == "table" and
	type(capital.quadrants.LOTS) == "table",
	"the composition of " .. key .. " publishes no quadrants module")
local quadrants = capital.quadrants
local districts = capital.districts

local LOT = quadrants.LOT
local FILL = quadrants.FILL
local ENVELOPE = 250 - LOT.reach - LOT.margin    -- one node clear of the gates
local CORE = 48                                  -- the core's +-47 plus a node

----------------------------------------------------------------------
-- The fields
----------------------------------------------------------------------

local function read_field(path)
	local file = assert(io.open(path, "r"), "cannot read " .. path)
	local reach
	local heights, land = {}, {}
	local rows = 0
	for line in file:lines() do
		if line:sub(1, 1) == "#" then
			local value = line:match("reach=(%d+)")
			if value then reach = tonumber(value) end
		elseif line ~= "" then
			local z, numbers, flags = line:match("^(%-?%d+)\t(.-)\t([01]+)$")
			assert(z, "unreadable field row: " .. line:sub(1, 40))
			z = tonumber(z)
			local row, count = {}, 0
			for number in numbers:gmatch("%-?%d+") do
				count = count + 1
				row[count] = tonumber(number)
			end
			assert(count == #flags, "field row " .. z .. " is ragged")
			heights[z], land[z] = row, flags
			rows = rows + 1
		end
	end
	file:close()
	assert(reach, path .. " has no reach header; re-run the field dump")
	assert(rows == 2 * reach + 1, path .. " is not a whole field")
	return {reach = reach, heights = heights, land = land, path = path}
end

local fields = {}
for index = 1, #paths do fields[index] = read_field(paths[index]) end
for index = 2, #fields do
	assert(fields[index].reach == fields[1].reach,
		"the fields do not cover the same envelope")
end
do
	-- Every field must differ from the FIRST one somewhere: a set that
	-- contains the same world twice is a set that measured one world.
	for index = 2, #fields do
		local differs = false
		for z = -fields[1].reach, fields[1].reach do
			if differs then break end
			local a, b = fields[1].heights[z], fields[index].heights[z]
			for column = 1, #a do
				if a[column] ~= b[column] then differs = true break end
			end
		end
		assert(differs, fields[index].path .. " is the same world as " ..
			fields[1].path .. "; use different seeds")
	end
end

local function height_at(field, x, z)
	return field.heights[z][x + field.reach + 1]
end
local function is_land(field, x, z)
	return field.land[z]:byte(x + field.reach + 1) == 49   -- "1"
end

-- The terrain half of the predicate, on ONE world: nil when the position is
-- refused, otherwise the perimeter fall and the footprint rise.
local function terrain(field, x, z, reach)
	local margin = LOT.margin
	reach = reach or LOT.reach
	if math.abs(x) + reach + margin > field.reach or
			math.abs(z) + reach + margin > field.reach then
		return nil, "envelope"
	end
	for row = z - reach - margin, z + reach + margin do
		for column = x - reach - margin, x + reach + margin do
			if not is_land(field, column, row) then return nil, "water" end
		end
	end
	local reference = height_at(field, x, z)
	local lowest, highest = reference, reference
	for row = z - reach, z + reach do
		local edge_row = (row == z - reach or row == z + reach)
		for column = x - reach, x + reach do
			local y = height_at(field, column, row)
			if y > highest then highest = y end
			if (edge_row or column == x - reach or column == x + reach) and
					y < lowest then
				lowest = y
			end
		end
	end
	local fall, rise = reference - lowest, highest - reference
	if fall > LOT.fall then return nil, "fall:" .. fall end
	if rise > LOT.rise then return nil, "rise:" .. rise end
	return fall, rise
end

-- Every world at once: the worst fall and the worst rise over the whole set, or
-- nil and the first world that refused.
local function every(x, z, reach)
	local worst_fall, worst_rise = 0, 0
	for index = 1, #fields do
		local fall, rise = terrain(fields[index], x, z, reach)
		if not fall then return nil, index .. ":" .. tostring(rise) end
		if fall > worst_fall then worst_fall = fall end
		if rise > worst_rise then worst_rise = rise end
	end
	return worst_fall, worst_rise
end

----------------------------------------------------------------------
-- The streets
----------------------------------------------------------------------

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
-- The carriageway plus a verge column either side: that is the width the road
-- overlay actually writes.
local ROAD_HALF = (avenue.WIDTH - 1) / 2 + 1
for _, list in ipairs({capital.avenues, capital.ring,
		quadrants.lane_runs()}) do
	for index = 1, #list do add_run(list[index], ROAD_HALF) end
end
-- The curtain wall is a run of the same overlay and is therefore a place no lot
-- may stand either. It is `wall.HALF` either side of its centre line rather
-- than the road's verge.
for index = 1, #(capital.wall or {}) do
	add_run(capital.wall[index], wall.HALF)
end

local function overlaps(a1, a2, b1, b2) return a1 <= b2 and b1 <= a2 end

-- Geometry only: everything that can be decided without terrain. `turns` says
-- which quadrant the lot belongs to, because "inside its own quarter" is the
-- one rule that is not symmetric in the lot alone.
local function geometry(x, z, turns, placed, reach, lane)
	reach = reach or LOT.reach
	lane = lane or LOT.lane
	local min_x, max_x, min_z, max_z = x - reach, x + reach, z - reach, z + reach
	if min_x < -ENVELOPE - reach or max_x > ENVELOPE + reach or
			min_z < -ENVELOPE - reach or max_z > ENVELOPE + reach then
		return false, "envelope"
	end
	if overlaps(min_x, max_x, -CORE, CORE) and
			overlaps(min_z, max_z, -CORE, CORE) then
		return false, "core"
	end
	local qx, qz = quadrants.rotate(x, z, 4 - turns)
	if qx - reach < LOT.quarter or qz + reach > -LOT.quarter then
		return false, "quarter"
	end
	if overlaps(min_z, max_z, -16, 16) then return false, "gate_corridor_x" end
	if overlaps(min_x, max_x, -16, 16) then return false, "gate_corridor_z" end
	for _, run in ipairs(runs) do
		if overlaps(min_x, max_x, run.min_x, run.max_x) and
				overlaps(min_z, max_z, run.min_z, run.max_z) then
			return false, "street:" .. run.id
		end
	end
	-- A lane between this lot and every one already placed. `other.reach` is
	-- the other lot's own half-width, so a fill lot measured against a district
	-- lot is measured against the district lot's reach and not against its own.
	for _, other in ipairs(placed or {}) do
		local gap = math.max(lane, other.lane or lane)
		local other_reach = other.reach or LOT.reach
		if overlaps(min_x, max_x, other.x - other_reach - gap,
				other.x + other_reach + gap) and
				overlaps(min_z, max_z, other.z - other_reach - gap,
					other.z + other_reach + gap) then
			return false, "lot:" .. other.id
		end
	end
	return true
end

----------------------------------------------------------------------
-- Verify
----------------------------------------------------------------------

local failures = 0
io.write("== the ", 9 * 4, " lots of ", key, ", on ", #fields, " worlds\n")
io.write("quadrant\tlot\tx\tz\tverdict\tworst_fall\tworst_rise\n")
local by_quadrant = {}
for _, name in ipairs(quadrants.QUADRANTS) do by_quadrant[name] = {} end
for turns = 0, 3 do
	local name = quadrants.QUADRANTS[turns + 1]
	local here = by_quadrant[name]
	for index, lot in ipairs(quadrants.LOTS[name]) do
		local id = name .. "/" .. index
		local ok, why = geometry(lot.x, lot.z, turns, here)
		local fall, rise = "-", "-"
		if ok then
			local measured_fall, measured_rise = every(lot.x, lot.z)
			if measured_fall then
				fall, rise = measured_fall, measured_rise
			else
				ok, why = false, measured_rise
			end
		end
		if not ok then failures = failures + 1 end
		io.write(table.concat({name, index, lot.x, lot.z,
			ok and "legal" or ("ILLEGAL " .. tostring(why)), fall, rise},
			"\t"), "\n")
		here[#here + 1] = {id = id, x = lot.x, z = lot.z, reach = LOT.reach,
			lane = FILL.lane}
	end
end

io.write("\n== the ", 4 * 4, " fill lots\n")
io.write("quadrant\tslot\tx\tz\treach\tverdict\tworst_fall\tworst_rise\n")
for turns = 0, 3 do
	local name = quadrants.QUADRANTS[turns + 1]
	local grid = quadrants.FILL_LOTS[name] or {}
	if #grid ~= #quadrants.FILL_AUTHORED then
		io.write(name, "\tALL\t-\t-\t-\tWRONG COUNT ", #grid, "\t-\t-\n")
		failures = failures + 1
	end
	local here = {}
	for index = 1, #by_quadrant[name] do here[index] = by_quadrant[name][index] end
	for index, lot in ipairs(grid) do
		local reach = quadrants.FILL_AUTHORED[index].reach
		local id = name .. "/fill" .. index
		local ok, why = geometry(lot.x, lot.z, turns, here, reach, FILL.lane)
		local fall, rise = "-", "-"
		if ok then
			local measured_fall, measured_rise = every(lot.x, lot.z, reach)
			if measured_fall then
				fall, rise = measured_fall, measured_rise
			else
				ok, why = false, measured_rise
			end
		end
		if not ok then failures = failures + 1 end
		io.write(table.concat({name, index, lot.x, lot.z, reach,
			ok and "legal" or ("ILLEGAL " .. tostring(why)), fall, rise},
			"\t"), "\n")
		here[#here + 1] = {id = id, x = lot.x, z = lot.z, reach = reach,
			lane = FILL.lane}
	end
end

if type(districts) == "table" and type(districts.resolve) == "function" then
	io.write("\n== every plot against the envelope of the lot it stands on\n")
	io.write("plot\tdistrict\tquadrant\tkind\tlot\tverdict\tx_reach",
		"\tz_reach\tclear\n")
	for _, entry in ipairs(districts.resolve()) do
		local composition = entry.build()
		local bounds = composition.bounds
		local x_reach = math.max(math.abs(bounds.min.x), math.abs(bounds.max.x))
		local z_reach = math.max(math.abs(bounds.min.z), math.abs(bounds.max.z))
		local clear = composition.clear_to
		local reach = LOT.reach
		local floor = LOT.clear
		if entry.kind == "fill" then
			reach = quadrants.FILL_AUTHORED[entry.lot].reach
			floor = FILL.clear
		end
		local verdict = "fits"
		if x_reach > reach or z_reach > reach then
			verdict = "WIDER THAN THE LOT"
		elseif clear < floor then
			verdict = "CLEARS TOO LITTLE"
		end
		if verdict ~= "fits" then failures = failures + 1 end
		io.write(table.concat({entry.id, entry.district, entry.quadrant,
			entry.kind or "plot", entry.lot, verdict, x_reach, z_reach, clear},
			"\t"), "\n")
	end
end

----------------------------------------------------------------------
-- Repair
----------------------------------------------------------------------

if repair then
	io.write("\n== repaired grids\n")
	local STEP = 4
	local moved = 0
	-- The repaired district grid per quadrant, kept for the fill pass below:
	-- a fill lot's lane is measured against the district lots as they NOW
	-- stand, not as they were authored.
	local repaired = {}
	for turns = 0, 3 do
		local name = quadrants.QUADRANTS[turns + 1]
		local here, rows = {}, {}
		for index, lot in ipairs(quadrants.LOTS[name]) do
			local x, z, move = lot.x, lot.z, 0
			if not (geometry(x, z, turns, here) and every(x, z)) then
				local nearest
				for cz = -232, 232, STEP do
					for cx = -232, 232, STEP do
						if geometry(cx, cz, turns, here) and every(cx, cz) then
							local distance = math.abs(cx - lot.x) +
								math.abs(cz - lot.z)
							if not nearest or distance < nearest.distance then
								nearest = {x = cx, z = cz, distance = distance}
							end
						end
					end
				end
				assert(nearest, "no legal home for " .. name .. " lot " .. index)
				x, z, move = nearest.x, nearest.z, nearest.distance
				moved = moved + 1
			end
			here[#here + 1] = {id = index, x = x, z = z}
			local fall, rise = every(x, z)
			rows[index] = string.format(
				"  {x = %d, z = %d},  -- lot %d fall=%d rise=%d move=%d",
				x, z, index, fall, rise, move)
		end
		io.write(name, ":\n")
		for index = 1, #rows do io.write(rows[index], "\n") end
		repaired[name] = here
	end
	io.write(moved, " lot(s) moved\n")

	-- AND THE FILL GRID, with the repaired district lots already standing.
	--
	-- `--repair` used to stop at the 36 district lots, and the wave-3 nine-seed
	-- re-measurement is what made that a gap rather than a scope: six of
	-- Highcourt's twelve illegal positions are FILL lots, and `--derive-fill`
	-- is the wrong answer for them for the reason the header gives about
	-- `--derive` -- it slides the whole quadrant's grid to the best
	-- translation, which is right when a grid is being invented and wrong when
	-- the ground under a finished city has moved by a node.
	--
	-- Same rule as above, one difference: a fill lot carries its OWN reach (the
	-- four slots are four deliberately different sizes) and its own lane, and it
	-- is measured against the district lots of its quadrant as they now stand,
	-- not as they were authored. So this runs after the district pass and reads
	-- `repaired`.
	io.write("\n== repaired fill grids\n")
	local fill_moved = 0
	for turns = 0, 3 do
		local name = quadrants.QUADRANTS[turns + 1]
		local here, rows = {}, {}
		for index = 1, #(repaired[name] or {}) do
			local lot = repaired[name][index]
			here[#here + 1] = {id = name .. "/" .. index, x = lot.x, z = lot.z,
				reach = LOT.reach, lane = FILL.lane}
		end
		local grid = quadrants.FILL_LOTS[name] or {}
		for index, lot in ipairs(grid) do
			local reach = quadrants.FILL_AUTHORED[index].reach
			local x, z, move = lot.x, lot.z, 0
			if not (geometry(x, z, turns, here, reach, FILL.lane) and
					every(x, z, reach)) then
				local nearest
				for cz = -236, 236, STEP do
					for cx = -236, 236, STEP do
						if geometry(cx, cz, turns, here, reach, FILL.lane) and
								every(cx, cz, reach) then
							local distance = math.abs(cx - lot.x) +
								math.abs(cz - lot.z)
							if not nearest or distance < nearest.distance then
								nearest = {x = cx, z = cz, distance = distance}
							end
						end
					end
				end
				assert(nearest, "no legal home for " .. name .. " fill " .. index)
				x, z, move = nearest.x, nearest.z, nearest.distance
				fill_moved = fill_moved + 1
			end
			here[#here + 1] = {id = name .. "/fill" .. index, x = x, z = z,
				reach = reach, lane = FILL.lane}
			local fall, rise = every(x, z, reach)
			rows[index] = string.format(
				"  {x = %d, z = %d},  -- fill %d reach=%d fall=%d rise=%d move=%d",
				x, z, index, reach, fall, rise, move)
		end
		io.write(name, ":\n")
		for index = 1, #rows do io.write(rows[index], "\n") end
	end
	io.write(fill_moved, " fill lot(s) moved\n")
	os.exit(0)
end

----------------------------------------------------------------------
-- Derive
----------------------------------------------------------------------
--
-- How the committed grids were found, kept so they are re-derivable. The
-- authored layout is rotated into the quadrant, slid as a whole to the
-- translation that needs the least correction, and every lot that still does
-- not stand takes the NEAREST position that does, with the lots already placed
-- blocking a lane around themselves. The objective is the WORST move, not the
-- total: a layout where one lot walks eighty nodes and the rest stay put is not
-- the same design any more, and minimising the sum is what chooses it.

local STEP = 4

local function candidate_list(turns, placed, reach, lane, span)
	local list = {}
	for z = -span, span, STEP do
		for x = -span, span, STEP do
			if geometry(x, z, turns, placed, reach, lane) and
					every(x, z, reach) then
				list[#list + 1] = {x = x, z = z}
			end
		end
	end
	return list
end

if derive then
	io.write("\n== derived grids\n")
	for turns = 0, 3 do
		local name = quadrants.QUADRANTS[turns + 1]
		local candidates = candidate_list(turns, nil, LOT.reach, LOT.lane, 232)
		local best
		for dz = -64, 64, STEP do
			for dx = -64, 64, STEP do
				local here, worst, total = {}, 0, 0
				local ok = true
				for index, authored in ipairs(quadrants.AUTHORED) do
					local x, z = quadrants.rotate(authored.x + dx,
						authored.z + dz, turns)
					local move
					if geometry(x, z, turns, here) and every(x, z) then
						move = 0
					else
						local nearest
						for _, candidate in ipairs(candidates) do
							if geometry(candidate.x, candidate.z, turns,
									here) then
								local distance = math.abs(candidate.x - x) +
									math.abs(candidate.z - z)
								if not nearest or distance < nearest.distance then
									nearest = {x = candidate.x, z = candidate.z,
										distance = distance}
								end
							end
						end
						if not nearest then ok = false break end
						x, z, move = nearest.x, nearest.z, nearest.distance
					end
					here[#here + 1] = {id = index, x = x, z = z, move = move}
					if move > worst then worst = move end
					total = total + move
				end
				-- Rank: the worst move first, then the sum, then the
				-- translation itself, which is what stops a layout needing no
				-- correction at all from being chosen at the far edge of the
				-- envelope merely because the search reached it first.
				local shift = math.abs(dx) + math.abs(dz)
				if ok and (not best or worst < best.worst or
						(worst == best.worst and (total < best.total or
							(total == best.total and shift < best.shift)))) then
					best = {worst = worst, total = total, shift = shift,
						dx = dx, dz = dz, lots = here}
				end
			end
		end
		assert(best, "no nine-lot grid exists in " .. name)
		io.write(string.format(
			"%s: shift dx=%d dz=%d worst move %d, total %d\n",
			name, best.dx, best.dz, best.worst, best.total))
		for _, lot in ipairs(best.lots) do
			local fall, rise = every(lot.x, lot.z)
			io.write(string.format(
				"  {x = %d, z = %d},  -- lot %d fall=%d rise=%d move=%d\n",
				lot.x, lot.z, lot.id, fall, rise, lot.move))
		end
	end
end

----------------------------------------------------------------------
-- Derive the fill lots
----------------------------------------------------------------------
--
-- The same search with the district lots of the quadrant already standing.

if derive_fill then
	io.write("\n== derived fill grids\n")
	for turns = 0, 3 do
		local name = quadrants.QUADRANTS[turns + 1]
		local district_lots = {}
		for index, lot in ipairs(quadrants.LOTS[name]) do
			district_lots[index] = {id = name .. "/" .. index, x = lot.x,
				z = lot.z, reach = LOT.reach, lane = FILL.lane}
		end
		local candidates = {}
		for slot = 1, #quadrants.FILL_AUTHORED do
			local reach = quadrants.FILL_AUTHORED[slot].reach
			if candidates[reach] == nil then
				candidates[reach] = candidate_list(turns, district_lots, reach,
					FILL.lane, 236)
			end
		end
		local best
		for dz = -64, 64, STEP do
			for dx = -64, 64, STEP do
				local here, worst, total = {}, 0, 0
				local standing = {}
				for index = 1, #district_lots do
					standing[index] = district_lots[index]
				end
				local ok = true
				for slot, authored in ipairs(quadrants.FILL_AUTHORED) do
					local reach = authored.reach
					local x, z = quadrants.rotate(authored.x + dx,
						authored.z + dz, turns)
					local move
					if geometry(x, z, turns, standing, reach, FILL.lane) and
							every(x, z, reach) then
						move = 0
					else
						local nearest
						for _, candidate in ipairs(candidates[reach]) do
							if geometry(candidate.x, candidate.z, turns,
									standing, reach, FILL.lane) then
								local distance = math.abs(candidate.x - x) +
									math.abs(candidate.z - z)
								if not nearest or distance < nearest.distance then
									nearest = {x = candidate.x, z = candidate.z,
										distance = distance}
								end
							end
						end
						if not nearest then ok = false break end
						x, z, move = nearest.x, nearest.z, nearest.distance
					end
					here[#here + 1] = {slot = slot, x = x, z = z, move = move,
						reach = reach}
					standing[#standing + 1] = {id = "fill" .. slot, x = x,
						z = z, reach = reach, lane = FILL.lane}
					if move > worst then worst = move end
					total = total + move
				end
				local shift = math.abs(dx) + math.abs(dz)
				if ok and (not best or worst < best.worst or
						(worst == best.worst and (total < best.total or
							(total == best.total and shift < best.shift)))) then
					best = {worst = worst, total = total, shift = shift,
						dx = dx, dz = dz, lots = here}
				end
			end
		end
		assert(best, "no fill grid exists in " .. name)
		io.write(string.format(
			"%s: shift dx=%d dz=%d worst move %d, total %d\n",
			name, best.dx, best.dz, best.worst, best.total))
		for _, lot in ipairs(best.lots) do
			local fall, rise = every(lot.x, lot.z, lot.reach)
			io.write(string.format(
				"  {x = %d, z = %d},  -- fill %d reach=%d fall=%d rise=%d move=%d\n",
				lot.x, lot.z, lot.slot, lot.reach, fall, rise, lot.move))
		end
	end
end

if failures > 0 then
	io.write("\n", failures, " lot(s) or plot(s) of ", key,
		" stand somewhere they may not\n")
	os.exit(1)
end
io.write("\nevery lot and every fill lot of ", key, " is dry, inside the skirt",
	" and under its own roof on all ", #fields, " worlds\n")
