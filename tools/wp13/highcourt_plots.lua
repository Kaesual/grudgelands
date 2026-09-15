-- Where a Highcourt district plot may stand, and where it may not.
--
--     luajit tools/wp13/highcourt_plots.lua <repo> <field-a.tsv> <field-b.tsv>
--     luajit tools/wp13/highcourt_plots.lua <repo> <field-a.tsv> <field-b.tsv> --derive
--     luajit tools/wp13/highcourt_plots.lua <repo> <field-a.tsv> <field-b.tsv> --repair
--     luajit tools/wp13/highcourt_plots.lua <repo> <field-a.tsv> <field-b.tsv> --derive-fill
--
-- The default run VERIFIES the 36 lots `wp13/highcourt_quadrants.lua` carries,
-- the 16 FILL LOTS it carries beside them, and the 52 plots the four districts
-- build, against every rule below, on two worlds at once. `--derive` re-runs
-- the search that produced the lot grids and `--derive-fill` the one that
-- produced the fill grids, so both committed tables are re-derivable rather
-- than remembered.
--
-- A FILL LOT (playtest round 3) is a district lot with two differences: it
-- carries its own reach, because the four fill slots are four deliberately
-- different sizes, and its lane is 4 rather than 8, because a garden between
-- two cottages is four nodes of grass. Every other rule below is the same one,
-- applied to the same two fields, and a fill lot is additionally held clear of
-- every district lot of its own quadrant.
--
-- `--repair` is the mode a TERRAIN change needs, and it is `capital_plots.lua
-- --assign` for this capital: every lot that still stands keeps its authored
-- position and only the ones that no longer do take the nearest position that
-- does. `--derive` searches the whole-quadrant translation again and will
-- happily slide nine lots forty nodes to save one of them a four-node move,
-- which is the right answer when the grid is being INVENTED and the wrong one
-- when the ground under a finished city has moved by a node: the districts
-- that stand on those lots are authored against them.
--
-- WHY THIS IS A COMMITTED TOOL AND NOT A SCRATCH SCRIPT. The first version of
-- the seam package moved two plots with an ad-hoc sweep that asked one
-- question -- "where is the ground flattest?" -- and the answer inside a
-- terraced capital envelope is THE RIVER BED. Both plots landed in the water,
-- on both gate seeds, and nothing in the tree could say so: the surface probe
-- measured terrain height only, the composition KAT has no terrain at all,
-- and the settlement seam is deliberately water-agnostic. The predicate
-- belongs in one place that can be re-run and read, and this is it.
--
-- WHAT CHANGED WITH THE FOUR DISTRICTS. The question is no longer "where may
-- THIS plot stand". Four districts stand in four quadrants and the world seed
-- decides which in which, so the thing that has to be legal is a LOT -- a
-- position that carries ANY district's plot -- and legality is therefore
-- asked once, against one envelope, for all 36 of them. The plot side of the
-- same rule is checked here too and in `highcourt_kat.lua`: every plot fits
-- inside +-13 of its lot origin and clears at least 8 nodes of airspace.
--
-- THE RULES, in the order they refuse:
--
--   1. DRY. Not one column of the lot's +-13 footprint may be water, and
--      neither may its two-node margin. A plot is not a pier.
--   2. STANDS ON ITS OWN GROUND. The fall under the footprint's PERIMETER,
--      measured from the lot's own reference column, may not exceed the
--      foundation skirt (6), on either seed; the perimeter is what the skirt
--      carries down.
--   3. FITS UNDER ITS OWN ROOF. The rise under the footprint may not exceed
--      6, on either seed, against an airspace clear of at least 8.
--   4. INSIDE THE ENVELOPE, one node clear of the gate stations at +-256.
--   5. OFF THE CORE, off all four 32-node gate corridors, off all eight
--      street runs (carriageway plus verge), inside its OWN quarter, and a
--      lane of 8 clear of every other lot of every other quadrant.
--
-- The field TSVs come from `tools/wp13/run_highcourt.sh <out> field <seed>`:
-- the pure final height and the land/water class of every column of the
-- capital's envelope, read once. The two must be different seeds, which this
-- tool checks by refusing two files whose heights are identical everywhere.
--
-- Plain Lua 5.1.

local repo = assert(arg[1], "repository root required")
local field_a = assert(arg[2], "first field TSV required")
local field_b = assert(arg[3], "second field TSV required")
local derive = arg[4] == "--derive"
local repair = arg[4] == "--repair"
local derive_fill = arg[4] == "--derive-fill"

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
local highcourt = dofile(wp13 .. "/highcourt.lua")(wp13)
local quadrants = dofile(wp13 .. "/highcourt_quadrants.lua")()
local districts = dofile(wp13 .. "/highcourt_districts.lua")(wp13)

local wall = dofile(wp13 .. "/wall.lua")(wp13)

local LOT = quadrants.LOT
local FILL = quadrants.FILL
local ENVELOPE = 250 - LOT.reach - LOT.margin   -- one node clear of the gates
local CORE = 48                                 -- the core's own +-47 plus a node

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
	return {reach = reach, heights = heights, land = land}
end

local a = read_field(field_a)
local b = read_field(field_b)
assert(a.reach == b.reach, "the two fields do not cover the same envelope")
do
	local differs = false
	for z = -a.reach, a.reach do
		if not differs then
			for x = 1, 2 * a.reach + 1 do
				if a.heights[z][x] ~= b.heights[z][x] then differs = true end
			end
		end
	end
	assert(differs, "the two fields are the same world; use two different seeds")
end

local function height_at(field, x, z)
	return field.heights[z][x + field.reach + 1]
end
local function is_land(field, x, z)
	return field.land[z]:byte(x + field.reach + 1) == 49   -- "1"
end

-- The terrain half of the predicate, on ONE world: nil when the position is
-- refused, otherwise the perimeter fall and the footprint rise. `reach` is the
-- lot's own half-width, which a district lot and a fill lot answer differently.
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
		for column = x - reach, x + reach do
			local y = height_at(field, column, row)
			if y > highest then highest = y end
			if (row == z - reach or row == z + reach or
					column == x - reach or column == x + reach) and
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

local function both(x, z, reach)
	local fall_a, rise_a = terrain(a, x, z, reach)
	if not fall_a then return nil, "a:" .. tostring(rise_a) end
	local fall_b, rise_b = terrain(b, x, z, reach)
	if not fall_b then return nil, "b:" .. tostring(rise_b) end
	return math.max(fall_a, fall_b), math.max(rise_a, rise_b)
end

-- The fifteen street runs -- four avenues, four ring sides and seven district
-- lanes -- carriageway plus a verge column either side: that is
-- the width the overlay actually writes.
local runs = {}
for _, list in ipairs({highcourt.avenues, highcourt.ring,
		quadrants.lane_runs()}) do
	for index = 1, #list do
		local run = list[index]
		local half = (avenue.WIDTH - 1) / 2 + 1
		if run.axis == "x" then
			runs[#runs + 1] = {id = run.id, min_x = run.from, max_x = run.to,
				min_z = run.at - half, max_z = run.at + half}
		else
			runs[#runs + 1] = {id = run.id, min_z = run.from, max_z = run.to,
				min_x = run.at - half, max_x = run.at + half}
		end
	end
end

-- The curtain wall, which is a run of the same overlay and is therefore a
-- place no lot may stand either. It is `wall.HALF` either side of its centre
-- line rather than the road's verge (playtest round 3).
for _, run in ipairs(highcourt.wall) do
	if run.axis == "x" then
		runs[#runs + 1] = {id = run.id, min_x = run.from, max_x = run.to,
			min_z = run.at - wall.HALF, max_z = run.at + wall.HALF}
	else
		runs[#runs + 1] = {id = run.id, min_z = run.from, max_z = run.to,
			min_x = run.at - wall.HALF, max_x = run.at + wall.HALF}
	end
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
	-- lot is measured against the district lot's 13 and not against its own.
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
io.write("== the 36 lots\n")
io.write("quadrant\tlot\tx\tz\tverdict\tworst_fall\tworst_rise\n")
local placed = {}
local by_quadrant = {}
for _, name in ipairs(quadrants.QUADRANTS) do by_quadrant[name] = {} end
for turns = 0, 3 do
	local name = quadrants.QUADRANTS[turns + 1]
	for index, lot in ipairs(quadrants.LOTS[name]) do
		local id = name .. "/" .. index
		local ok, why = geometry(lot.x, lot.z, turns, placed)
		local fall, rise = "-", "-"
		if ok then
			local measured_fall, measured_rise = both(lot.x, lot.z)
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
		placed[#placed + 1] = {id = id, x = lot.x, z = lot.z}
		by_quadrant[name][#by_quadrant[name] + 1] =
			{id = id, x = lot.x, z = lot.z, reach = LOT.reach, lane = FILL.lane}
	end
end

io.write("\n== the 16 fill lots\n")
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
			local measured_fall, measured_rise = both(lot.x, lot.z, reach)
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

io.write("\n== every plot against the envelope of the lot it stands on\n")
io.write("plot\tdistrict\tquadrant\tkind\tlot\tverdict\tx_reach\tz_reach\tclear\n")
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

----------------------------------------------------------------------
-- Repair
----------------------------------------------------------------------
--
-- What a terrain change needs: the smallest edit to `M.LOTS` that makes every
-- lot legal again. Each quadrant is walked in its committed order, a lot that
-- is still legal is kept exactly where it is and blocks its lane around
-- itself, and a lot that is not takes the nearest legal position on the same
-- four-node grid the derivation used. The output is the table to paste.
if repair then
	io.write("\n== repaired grids\n")
	local STEP = 4
	local moved = 0
	for turns = 0, 3 do
		local name = quadrants.QUADRANTS[turns + 1]
		local here = {}
		local rows = {}
		for index, lot in ipairs(quadrants.LOTS[name]) do
			local x, z, move = lot.x, lot.z, 0
			if not (geometry(x, z, turns, here) and both(x, z)) then
				local nearest
				for cz = -232, 232, STEP do
					for cx = -232, 232, STEP do
						if geometry(cx, cz, turns, here) and both(cx, cz) then
							local distance = math.abs(cx - lot.x) + math.abs(cz - lot.z)
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
			local fall, rise = both(x, z)
			rows[index] = string.format(
				"  {x = %d, z = %d},  -- lot %d fall=%d rise=%d move=%d",
				x, z, index, fall, rise, move)
		end
		io.write(name, ":\n")
		for index = 1, #rows do io.write(rows[index], "\n") end
	end
	io.write(moved, " lot(s) moved\n")
	os.exit(0)
end

----------------------------------------------------------------------
-- Derive
----------------------------------------------------------------------
--
-- How the committed grids were found, kept so they are re-derivable. The
-- authored layout is rotated into the quadrant, slid as a whole to the
-- translation that needs the least correction, and every lot that still does
-- not stand takes the NEAREST position that does, with the lots already
-- placed blocking a lane around themselves. The objective is the WORST move,
-- not the total: a layout where one lot walks eighty nodes and the rest stay
-- put is not the same design any more, and minimising the sum is what chooses
-- it.
if derive then
	io.write("\n== derived grids\n")
	local STEP = 4
	for turns = 0, 3 do
		local name = quadrants.QUADRANTS[turns + 1]
		local candidates = {}
		for z = -232, 232, STEP do
			for x = -232, 232, STEP do
				if geometry(x, z, turns) and both(x, z) then
					candidates[#candidates + 1] = {x = x, z = z}
				end
			end
		end
		local best
		for dz = -64, 64, STEP do
			for dx = -64, 64, STEP do
				local here, worst, total = {}, 0, 0
				local ok = true
				for index, authored in ipairs(quadrants.AUTHORED) do
					local x, z = quadrants.rotate(authored.x + dx,
						authored.z + dz, turns)
					local move
					if geometry(x, z, turns, here) and both(x, z) then
						move = 0
					else
						local nearest
						for _, candidate in ipairs(candidates) do
							if geometry(candidate.x, candidate.z, turns, here) then
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
				-- Rank: the worst move first, then the sum of the moves, then
				-- the translation itself. The last of the three is what stops
				-- a layout that needs no correction at all from being chosen
				-- at the far edge of the envelope merely because the search
				-- reached it first; ties there are broken towards the
				-- authored position.
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
		io.write(string.format("%s: shift dx=%d dz=%d worst move %d, total %d\n",
			name, best.dx, best.dz, best.worst, best.total))
		for _, lot in ipairs(best.lots) do
			local fall, rise = both(lot.x, lot.z)
			io.write(string.format("  {x = %d, z = %d},  -- lot %d fall=%d rise=%d move=%d\n",
				lot.x, lot.z, lot.id, fall, rise, lot.move))
		end
	end
end

----------------------------------------------------------------------
-- Derive the fill lots
----------------------------------------------------------------------
--
-- The same search as the district grids, with the district lots of the
-- quadrant already standing: the authored fill layout is rotated into the
-- quadrant, slid as a whole to the translation that needs the least
-- correction, and every slot that still does not stand takes the NEAREST
-- position that does. The objective is the worst move, then the total, then
-- the translation, for the reason written above the district derivation.
if derive_fill then
	io.write("\n== derived fill grids\n")
	local STEP = 4
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
				local list = {}
				for z = -236, 236, STEP do
					for x = -236, 236, STEP do
						if geometry(x, z, turns, district_lots, reach,
								FILL.lane) and both(x, z, reach) then
							list[#list + 1] = {x = x, z = z}
						end
					end
				end
				candidates[reach] = list
			end
		end
		local best
		for dz = -64, 64, STEP do
			for dx = -64, 64, STEP do
				local here, worst, total = {}, 0, 0
				local standing = {}
				for index = 1, #district_lots do standing[index] = district_lots[index] end
				local ok = true
				for slot, authored in ipairs(quadrants.FILL_AUTHORED) do
					local reach = authored.reach
					local x, z = quadrants.rotate(authored.x + dx,
						authored.z + dz, turns)
					local move
					if geometry(x, z, turns, standing, reach, FILL.lane) and
							both(x, z, reach) then
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
					standing[#standing + 1] = {id = "fill" .. slot, x = x, z = z,
						reach = reach, lane = FILL.lane}
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
		io.write(string.format("%s: shift dx=%d dz=%d worst move %d, total %d\n",
			name, best.dx, best.dz, best.worst, best.total))
		for _, lot in ipairs(best.lots) do
			local fall, rise = both(lot.x, lot.z, lot.reach)
			io.write(string.format(
				"  {x = %d, z = %d},  -- fill %d reach=%d fall=%d rise=%d move=%d\n",
				lot.x, lot.z, lot.slot, lot.reach, fall, rise, lot.move))
		end
	end
end

if failures > 0 then
	io.write("\n", failures, " lot(s) or plot(s) stand somewhere they may not\n")
	os.exit(1)
end
io.write("\nevery lot and every fill lot is dry, inside the skirt and under",
	" its own roof on both worlds, and every plot fits the lot it stands on\n")
