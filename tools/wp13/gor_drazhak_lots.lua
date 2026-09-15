-- Where Gor Drazhak's district lots and fill lots may stand.
--
--     luajit tools/wp13/gor_drazhak_lots.lua <repo> <grid-a.tsv> <grid-b.tsv> [grid-c.tsv ...]
--
-- WHY THIS TOOL EXISTS BESIDE `capital_plots.lua` AND `highcourt_plots.lua`.
-- Lane D's `capital_plots.lua` is the general predicate for a capital whose
-- plots are ONE district: it reads `capital.district.plots`, and it reads the
-- ground out of `run_capital.sh <out> <key> scan`, whose sweep covers one
-- quadrant band (x 52..204, z -96..96). Gor Drazhak has FOUR districts in four
-- quadrants and sixteen fill lots, so neither the list nor the band fits it.
-- `highcourt_plots.lua` is the four-district predicate, and it is the pilot
-- capital's own committed gate, hard-wired to Highcourt's quadrant module and
-- to its `field` probe mode. The GAP -- a four-district predicate keyed by
-- settlement, and a whole-envelope field dump in the generic probe -- is
-- reported to the coordinator; this file is the smallest thing that does not
-- widen another lane's files while the gap stands.
--
-- WHAT IT READS. `run_capital.sh <out> gor_drazhak terrain <seed>` writes
-- `gor_drazhak-grid.tsv`: the pure final terrain height and the water class of
-- every fourth column of the whole 576-node envelope plus its collar. That is
-- the same authority `r7_settlement.audit_terrain` uses at load
-- (`grug_zones.terrain_height_at`), at a quarter of its resolution. It is
-- therefore a DERIVATION instrument and not the gate: the gate is the engine's
-- own load-time audit and `run_capital.sh <out> gor_drazhak surface <seed>`,
-- which samples every plot column by column at its real position. This tool
-- says where to put a lot; those two say whether the plot on it stands.
--
-- THE RULES, in the order they refuse (they are `highcourt_plots.lua`'s, and
-- each one is the same failure it is there):
--
--   1. DRY. Neither the lot's own +-13 footprint nor its two-node margin may
--      be water. Gor Drazhak's envelope has no water in it on any seed
--      measured, which is the one thing that differs most from the pilot
--      capital -- see the research note -- but the rule is asked rather than
--      assumed.
--   2. STANDS ON ITS OWN GROUND. The fall under the footprint's perimeter,
--      measured from the lot's own reference column, may not exceed the
--      foundation skirt (6), on EVERY seed.
--   3. FITS UNDER ITS OWN ROOF. The rise anywhere under the footprint may not
--      exceed 6, against an airspace clear of at least 8.
--   4. INSIDE THE ENVELOPE, one node clear of the gate stations at +-256.
--   5. OFF THE CORE, off all four 32-node gate corridors, off every street run
--      the overlay writes -- the four avenues, the ring street, the district
--      lanes AND the rampart -- inside its own quarter, and a lane's width
--      clear of every other lot of that quarter.
--
-- Plain Lua 5.1.

local repo = assert(arg[1], "repository root required")
local grids = {}
for index = 2, #arg do
	if arg[index] ~= "--repair" then grids[#grids + 1] = arg[index] end
end
assert(#grids >= 2, "at least two grid TSVs (two different seeds) required")

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
local palisade = dofile(wp13 .. "/orc_palisade.lua")(wp13)
local quadrants = dofile(wp13 .. "/gor_drazhak_quadrants.lua")()

local STEP = 4                -- the grid dump's own resolution
local SKIRT = 6
local RISE = 6
local CLEAR = 8
local GATE_CORRIDOR = 16      -- half of WP40's 32-node gate corridor
local ENVELOPE = 250
local CORE = 48

local function read(path)
	local height, water, count = {}, {}, 0
	local file = assert(io.open(path, "r"), "cannot read " .. path)
	local header = file:read("*l")
	assert(header and header:find("terrain_y", 1, true),
		path .. " is not a terrain grid dump")
	for line in file:lines() do
		local x, z, y, wet = line:match(
			"^(%-?%d+)\t(%-?%d+)\t(%-?%d+)\t(%a+)")
		assert(x, "unreadable grid row: " .. line)
		height[x .. ":" .. z] = tonumber(y)
		water[x .. ":" .. z] = (wet == "true")
		count = count + 1
	end
	file:close()
	assert(count > 0, path .. " is empty")
	return {height = height, water = water, path = path}
end

local worlds = {}
for index = 1, #grids do worlds[index] = read(grids[index]) end
do
	local differs = false
	for key, y in pairs(worlds[1].height) do
		if worlds[2].height[key] ~= y then differs = true end
	end
	assert(differs, "the first two grids are the same world; use two seeds")
end

-- The lot's own sample ring at the grid's resolution: the perimeter at +-12
-- (the largest multiple of the grid step inside the +-13 reach) and the margin
-- ring at +-16 (the smallest outside the +-15 the skirt's margin needs), which
-- makes both samples conservative in the direction that refuses rather than
-- accepts.
local REACH = 12
local MARGIN = 16

-- The grid samples every fourth column, so a lot centre that is not a multiple
-- of four -- the one fill slot that stands in the gap between two columns of
-- the lot grid is at 94 -- has no row of its own. The sample is SNAPPED to the
-- nearest column of the dump, which is what reading a 4-node sampling of a
-- continuous height field means; the per-column authority is the engine's own
-- surface pass and its load-time audit, which this tool exists to keep a
-- composition from reaching.
local function snap(value)
	return math.floor((value + STEP / 2) / STEP) * STEP
end

local function sample(world, x, z)
	local key = snap(x) .. ":" .. snap(z)
	return world.height[key], world.water[key]
end

-- Relief of one lot on one world: the fall under its perimeter and the rise
-- anywhere under its footprint, both from the lot's own reference column, plus
-- the submerged counts.
local function relief(world, x, z)
	local reference, reference_wet = sample(world, x, z)
	if reference == nil then return nil, "unscanned" end
	local fall, rise, wet_footprint, wet_margin = 0, 0, 0, 0
	if reference_wet then wet_footprint = wet_footprint + 1 end
	for dz = -REACH, REACH, STEP do
		for dx = -REACH, REACH, STEP do
			local y, wet = sample(world, x + dx, z + dz)
			if y == nil then return nil, "unscanned" end
			if wet then wet_footprint = wet_footprint + 1 end
			if y > reference + rise then rise = y - reference end
			local perimeter = (dx == -REACH or dx == REACH or
				dz == -REACH or dz == REACH)
			if perimeter and reference - y > fall then fall = reference - y end
		end
	end
	for dz = -MARGIN, MARGIN, STEP do
		for dx = -MARGIN, MARGIN, STEP do
			if dx == -MARGIN or dx == MARGIN or dz == -MARGIN or
					dz == MARGIN then
				local _, wet = sample(world, x + dx, z + dz)
				if wet then wet_margin = wet_margin + 1 end
			end
		end
	end
	return {fall = fall, rise = rise, wet = wet_footprint,
		wet_margin = wet_margin}
end

local function terrain(x, z)
	local worst_fall, worst_rise = 0, 0
	for index = 1, #worlds do
		local measured, why = relief(worlds[index], x, z)
		if measured == nil then return false, why end
		if measured.wet > 0 then return false, "submerged:" .. measured.wet end
		if measured.wet_margin > 0 then
			return false, "margin_in_water:" .. measured.wet_margin
		end
		if measured.fall > SKIRT then return false, "fall:" .. measured.fall end
		if measured.rise > RISE then return false, "rise:" .. measured.rise end
		if measured.fall > worst_fall then worst_fall = measured.fall end
		if measured.rise > worst_rise then worst_rise = measured.rise end
	end
	return true, nil, worst_fall, worst_rise
end

-- Every run the overlay writes, as a rectangle a lot may not touch.
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
local VERGE = (avenue.WIDTH - 1) / 2 + 1
for _, list in ipairs({quadrants.AVENUES, quadrants.RING,
		quadrants.lane_runs()}) do
	for index = 1, #list do add_run(list[index], VERGE) end
end
for index = 1, #quadrants.WALL do
	add_run(quadrants.WALL[index], palisade.HALF)
end

local function overlaps(a1, a2, b1, b2) return a1 <= b2 and b1 <= a2 end

local function geometry(x, z, reach, lane, others, self_index, extra_block)
	local min_x, max_x = x - reach - 2, x + reach + 2
	local min_z, max_z = z - reach - 2, z + reach + 2
	if min_x < -ENVELOPE or max_x > ENVELOPE or min_z < -ENVELOPE or
			max_z > ENVELOPE then
		return false, "envelope"
	end
	if overlaps(min_x, max_x, -CORE, CORE) and
			overlaps(min_z, max_z, -CORE, CORE) then
		return false, "core"
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
	-- A lane's width clear of every other lot of this quarter, measured
	-- between the two reaches and not between the two margins: the margin is
	-- the lot's own dry ground and two neighbours may share theirs, which is
	-- what "four nodes of grass between two houses" means. The lane between
	-- two lots is the SMALLER of the two rules -- a garden beside a building
	-- lot is a garden, not a street -- which is the fill lot's whole point.
	for index = 1, #others do
		local other = others[index]
		if index ~= self_index then
			local gap = reach + other.reach + math.min(lane, other.lane)
			if math.abs(x - other.x) < gap and math.abs(z - other.z) < gap then
				return false, "lot:" .. other.label
			end
		end
	end
	if extra_block then
		local why = extra_block(x, z, reach)
		if why then return false, why end
	end
	return true
end

-- Every lot of every quadrant, in one list per quadrant so the lot-to-lot rule
-- can be asked of the quarter as a whole.
local function quarter(name)
	local boxes = {}
	local district = quadrants.LOTS[name]
	local fill = quadrants.FILL_LOTS[name]
	for index = 1, #district do
		boxes[#boxes + 1] = {kind = "lot", index = index,
			x = district[index].x, z = district[index].z,
			reach = quadrants.LOT.reach, lane = quadrants.LOT.lane,
			label = name .. "/" .. index}
	end
	for index = 1, #fill do
		boxes[#boxes + 1] = {kind = "fill", index = index,
			x = fill[index].x, z = fill[index].z, reach = fill[index].reach,
			lane = quadrants.FILL.lane, label = name .. "/fill" .. index}
	end
	return boxes
end

-- The quarter a position belongs to, so a lot cannot wander into the
-- neighbouring district's ground while it is being repaired.
local SIGN = {southeast = {1, -1}, northeast = {1, 1},
	northwest = {-1, 1}, southwest = {-1, -1}}
local function in_quarter(name, x, z, reach)
	local sign = SIGN[name]
	local margin = quadrants.LOT.quarter
	if sign[1] * (x - sign[1] * (reach + margin)) < 0 then return false end
	if sign[2] * (z - sign[2] * (reach + margin)) < 0 then return false end
	return true
end

local repair = (arg[#arg] == "--repair")
local failures = 0
io.write("kind\tquadrant\tlot\tx\tz\tverdict\tworst_fall\tworst_rise\n")
local proposals = {}
for q = 1, #quadrants.QUADRANTS do
	local name = quadrants.QUADRANTS[q]
	local boxes = quarter(name)
	local function block(x, z, reach)
		if not in_quarter(name, x, z, reach) then return "quarter" end
		return nil
	end
	for index = 1, #boxes do
		local box = boxes[index]
		local ok, why = geometry(box.x, box.z, box.reach, box.lane, boxes,
			index, block)
		local fall, rise = "-", "-"
		if ok then
			local measured_fall, measured_rise
			ok, why, measured_fall, measured_rise = terrain(box.x, box.z)
			fall, rise = measured_fall or "-", measured_rise or "-"
		end
		if not ok then
			failures = failures + 1
			if repair then
				-- The NEAREST legal position, not the flattest: the authored
				-- layout is a design, and sorting on flatness alone is what put
				-- two Highcourt plots in a river.
				local best
				for dz = -40, 40, STEP do
					for dx = -40, 40, STEP do
						local x, z = box.x + dx, box.z + dz
						if geometry(x, z, box.reach, box.lane, boxes, index,
								block) and terrain(x, z) then
							local distance = math.abs(dx) + math.abs(dz)
							if not best or distance < best.distance then
								local _, _, f, r = terrain(x, z)
								best = {x = x, z = z, distance = distance,
									fall = f, rise = r}
							end
						end
					end
				end
				if best then
					proposals[#proposals + 1] = string.format(
						"%-22s %s %d  %5d,%5d -> %5d,%5d  (move %d, fall %d, rise %d)",
						name, box.kind, box.index, box.x, box.z, best.x, best.z,
						best.distance, best.fall, best.rise)
					box.x, box.z = best.x, best.z
				else
					proposals[#proposals + 1] = string.format(
						"%-22s %s %d  %5d,%5d -> NO LEGAL POSITION WITHIN 40",
						name, box.kind, box.index, box.x, box.z)
				end
			end
		end
		io.write(table.concat({box.kind, name, box.index, box.x, box.z,
			ok and "legal" or ("ILLEGAL " .. tostring(why)),
			fall, rise}, "\t"), "\n")
	end
end

if repair and #proposals > 0 then
	io.write("\n== proposed repairs\n")
	for index = 1, #proposals do io.write(proposals[index], "\n") end
end

io.write("\nseeds\t", #worlds, "\tclear\t", CLEAR, "\n")
if failures > 0 then
	io.write(failures, " lot finding(s) on gor_drazhak\n")
	os.exit(1)
end
io.write("every gor_drazhak lot is dry, stands inside its skirt and fits ",
	"under its own roof, on ", #worlds, " worlds\n")
