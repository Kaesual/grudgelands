-- Where Kezamba's district and fill lots may stand, on all NINE seeds.
--
--     luajit tools/wp13/kezamba_lots.lua <repo> check
--     luajit tools/wp13/kezamba_lots.lua <repo> walk
--     luajit tools/wp13/kezamba_lots.lua <repo> sweep <reach> [<count>]
--     luajit tools/wp13/kezamba_lots.lua <repo> map
--
-- WHY THIS EXISTS BESIDE `tools/wp13/capital_plots.lua`.
--
-- `capital_plots.lua` (lane D's, generic) is the committed predicate every
-- capital's plot positions are accepted by, and it reads two ENGINE scan dumps
-- of a capital the roster already carries. Kezamba cannot start there, for two
-- reasons that are properties of this capital and of no other:
--
--   * its 512 envelope carries an AUTHORED LAKE. `wp40/source/simple_map.lua`
--     declares `hydro_kezamba_cenote`, a `deep_cenote` of four basins at fixed
--     world coordinates, and `tools/wp13/kezamba_water.lua` measures that the
--     wet mask of the envelope is BYTE-IDENTICAL on all nine seeds of
--     `capital_anchor_fixture.lua`, with the water surface at y = 65 on every
--     one of them. Water is the first thing a lot predicate refuses, so a
--     two-seed sample is the wrong instrument for a capital whose dominant
--     constraint is the same in every world;
--   * the lake eats one whole quadrant, so Kezamba's lots cannot be a rotated
--     grid the way Highcourt's are, and the positions have to be searched
--     rather than authored and corrected.
--
-- So this tool asks `capital_plots.lua`'s OWN four questions -- dry, inside the
-- skirt, under its own roof, off the core and the streets -- against the
-- planner directly, on nine seeds instead of two, before a composition exists.
-- It is a pre-flight and not a replacement: once Kezamba is in the roster, the
-- engine scan and `capital_plots.lua` are still the authority, and the
-- research note records both answers.
--
-- Plain Lua 5.1, LuaJIT in practice; no engine, no globals.

local repo = assert(arg[1], "repository root required")
local mode = arg[2] or "check"

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local source = dofile(wp40 .. "/source/simple_map.lua")
local schemas = dofile(wp40 .. "/schemas.lua")
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local raw_sha256 = common.new_sha256()
local horizontal_factory = dofile(wp40 .. "/simple_map.lua")
local height_factory = dofile(wp40 .. "/height.lua")
local coupled_grade = dofile(wp40 .. "/coupled_grade.lua")()
local lots = dofile(wp13 .. "/kezamba_lots.lua")()

local SEEDS = {"531802985935182545", "8675309", "15912857179583385436",
	"0", "1", "2", "42", "12345", "999999999"}
local ANCHOR_ID = "anchor_012"

-- `capital_plots.lua`'s own constants.
local SKIRT = 6
local MARGIN = 2
local GATE_CORRIDOR = 16
local ENVELOPE = 250
local CORE = 48
local AVENUE_HALF = 3         -- the five-wide carriageway plus its verge
local RING_AT = 96

-- The airspace a lot is credited with. `wp13/kezamba_plot.lua` clears at least
-- this much over every plot, whatever its own roof needs, and the predicate may
-- not credit a plot with more than its builder cuts.
local MIN_CLEAR = 8

local sessions = {}
for index = 1, #SEEDS do
	local seed = SEEDS[index]
	local horizontal = horizontal_factory({source = source, schemas = schemas,
		canonical = canonical, deterministic = deterministic,
		raw_sha256 = raw_sha256}).new(seed)
	local height = height_factory({source = source, canonical = canonical,
		deterministic = deterministic, raw_sha256 = raw_sha256,
		horizontal_session = horizontal,
		coupled_grade = coupled_grade}).new_runtime(seed)
	local anchor = height.selected_anchor_3d_by_id(ANCHOR_ID)
	if type(anchor) ~= "table" then
		error("kezamba lots: the capital anchor is absent", 0)
	end
	sessions[index] = {seed = seed, horizontal = horizontal, height = height,
		anchor = anchor, cache = {}}
end

-- One column, per seed, cached: the final height and whether it is water.
local function column(session, x, z)
	local key = x * 1024 + z
	local hit = session.cache[key]
	if hit == nil then
		local wx, wz = session.anchor.x + x, session.anchor.z + z
		hit = {y = session.height.terrain_height_at(wx, wz),
			wet = session.horizontal.water_class_at(wx, wz) ~= "land"}
		session.cache[key] = hit
	end
	return hit
end

-- RULE 4 and 5, which are pure geometry and need no terrain at all: inside the
-- envelope, off the core, off the four gate corridors, off the avenues and off
-- the ring street. `clear_to` is the lot's own, so this answers for a lot and
-- not for a composition.
local function geometry_refusal(x, z, reach)
	local half = reach + MARGIN
	if math.abs(x) + half > ENVELOPE or math.abs(z) + half > ENVELOPE then
		return "leaves the envelope"
	end
	if math.abs(x) - half < CORE and math.abs(z) - half < CORE then
		return "overlaps the civic core"
	end
	-- The four 32-node gate corridors: |across| <= 16 on either axis, for the
	-- whole length of that axis outside the core.
	if math.abs(z) - half < GATE_CORRIDOR then return "in the x gate corridor" end
	if math.abs(x) - half < GATE_CORRIDOR then return "in the z gate corridor" end
	-- The ring street at +-96 on both axes, five wide plus a verge.
	for _, at in ipairs({-RING_AT, RING_AT}) do
		if math.abs(x - at) <= half + AVENUE_HALF and math.abs(z) <= RING_AT + half then
			return "on the ring street"
		end
		if math.abs(z - at) <= half + AVENUE_HALF and math.abs(x) <= RING_AT + half then
			return "on the ring street"
		end
	end
	return nil
end

-- RULES 1..3 against the terrain, on every seed.
local function terrain_refusal(x, z, reach, clear_to)
	local worst_fall, worst_rise, wet_columns = 0, 0, 0
	for index = 1, #sessions do
		local session = sessions[index]
		local base = column(session, x, z)
		if base.wet then return "the reference column is water", 0, 0, 1 end
		local fall, rise = 0, 0
		for dz = -reach - MARGIN, reach + MARGIN do
			for dx = -reach - MARGIN, reach + MARGIN do
				local cell = column(session, x + dx, z + dz)
				if cell.wet then wet_columns = wet_columns + 1 end
				local edge = (dx == -reach or dx == reach or
					dz == -reach or dz == reach)
				if cell.y > base.y + rise then rise = cell.y - base.y end
				if edge and base.y - cell.y > fall then fall = base.y - cell.y end
			end
		end
		if fall > worst_fall then worst_fall = fall end
		if rise > worst_rise then worst_rise = rise end
	end
	if wet_columns > 0 then
		return wet_columns .. " submerged columns", worst_fall, worst_rise,
			wet_columns
	end
	if worst_fall > SKIRT then
		return "falls " .. worst_fall .. " past the skirt", worst_fall,
			worst_rise, 0
	end
	if worst_rise > clear_to then
		return "rises " .. worst_rise .. " past the clear", worst_fall,
			worst_rise, 0
	end
	return nil, worst_fall, worst_rise, 0
end

local function legal(x, z, reach, clear_to)
	local refusal = geometry_refusal(x, z, reach)
	if refusal then return refusal end
	return (terrain_refusal(x, z, reach, clear_to or MIN_CLEAR))
end

if mode == "sweep" then
	local reach = tonumber(arg[3] or "13")
	local want = tonumber(arg[4] or "40")
	local found = {}
	for z = -240, 240, 4 do
		for x = -240, 240, 4 do
			if legal(x, z, reach, MIN_CLEAR) == nil then
				found[#found + 1] = {x = x, z = z}
			end
		end
	end
	io.write("kezamba_lot_sweep\treach\t", reach, "\tlegal\t", #found, "\n")
	for index = 1, math.min(#found, want) do
		io.write("  (", found[index].x, ", ", found[index].z, ")\n")
	end
	os.exit(0)
end

-- `pack`: the search that produced the authored table. Four district regions,
-- each given a spine to hug, nine building lots of reach 13 and four fill lots
-- of reaches 11, 11, 8 and 5, greedily packed nearest-the-spine-first with a
-- one-node gap between every pair. Deterministic: the candidate order is the
-- lattice order and the ranking is (distance to the spine, x, z).
if mode == "pack" then
	local REGIONS = {
		{key = "shore", x1 = 40, x2 = 224, z1 = -224, z2 = -32,
			sx = 128, sz = -112, step = 4, plots = 9},
		{key = "vine", x1 = -224, x2 = -40, z1 = -224, z2 = -32,
			sx = -128, sz = -112, step = 4, plots = 9},
		{key = "canopy", x1 = -232, x2 = -40, z1 = 32, z2 = 224,
			sx = -136, sz = 112, step = 4, plots = 11},
		{key = "totem", x1 = -160, x2 = 208, z1 = 128, z2 = 236,
			sx = 32, sz = 184, step = 2, plots = 7},
	}
	local FILL = {11, 11, 8, 5}
	local taken = {}
	local function clashes(x, z, reach)
		for _, other in ipairs(taken) do
			local gap_x = math.abs(x - other.x) -
				(reach + other.reach + 2 * MARGIN)
			local gap_z = math.abs(z - other.z) -
				(reach + other.reach + 2 * MARGIN)
			if gap_x <= 0 and gap_z <= 0 then return true end
		end
		return false
	end
	io.write("-- generated by: luajit tools/wp13/kezamba_lots.lua <repo> pack\n")
	for _, region in ipairs(REGIONS) do
		local reaches = {}
		for slot = 1, region.plots do reaches[slot] = 13 end
		for slot = 1, #FILL do reaches[region.plots + slot] = FILL[slot] end
		local placed = 0
		for slot = 1, #reaches do
			local reach = reaches[slot]
			local best
			for z = region.z1, region.z2, region.step do
				for x = region.x1, region.x2, region.step do
					if not clashes(x, z, reach) and
							legal(x, z, reach, MIN_CLEAR) == nil then
						local cost = math.abs(x - region.sx) +
							math.abs(z - region.sz)
						if best == nil or cost < best.cost or
								(cost == best.cost and (x < best.x or
									(x == best.x and z < best.z))) then
							best = {x = x, z = z, cost = cost, reach = reach}
						end
					end
				end
			end
			if best then
				taken[#taken + 1] = best
				placed = placed + 1
				io.write(string.format(
					"\t\t{id = \"%s_%d\", kind = \"%s\", x = %d, z = %d, reach = %d},\n",
					region.key, slot <= region.plots and slot or slot - region.plots,
					slot <= region.plots and "plot" or "fill",
					best.x, best.z, best.reach))
			else
				io.write("\t\t-- NO LOT FOUND for slot ", slot, " reach ", reach,
					" in ", region.key, "\n")
			end
		end
		io.write("\t\t-- ", region.key, ": ", placed, " of ", #reaches, "\n")
	end
	os.exit(0)
end

-- `walk`: CAN A PLAYER WALK UP TO EVERY PLOT, ON ALL NINE SEEDS.
--
-- The coordinator's wave-2 update of 2026-09-15, after the first two capital
-- reviews found a four-node step on seeds a lane had skipped.
--
-- WHAT THE QUESTION IS, AND THE TWO WAYS THIS MODE FIRST ASKED IT WRONG.
--
-- (1) Its first version took the greatest |reference - surface| over the whole
-- ring one node outside each plot, and 267 of its 468 lot-seed pairs came back
-- over three -- which says nothing, because a capital envelope is TERRACED and a
-- terrace riser IS a three-node difference. WP13 round 3 already turned every
-- riser into a band of one-block ground steps
-- (`tools/wp13/capital_terrain_fixture.lua`), so three nodes spread over three
-- columns is a staircase, not a wall. The property that decides reachability is
-- the step between ADJACENT columns.
--
-- (2) Its second version walked only the plot's own z- doorstep, and failed
-- `totem_f2` by 35 nodes on eight seeds -- correctly measuring the CENOTE'S
-- BANK, which is what lies south of a lot on the lake's north shore. But a plot
-- with a cliff on one side and open ground on the other three is a plot you
-- walk up to from the other three. A lot is reachable if ANY of its four sides
-- is, so the verdict is the BEST of the four and not the doorstep's.
--
-- So: for each side, walk sixteen columns straight out from the first column
-- beyond the plot's own ground and record the worst step between neighbours,
-- with a water column ending that direction (you cannot walk into the cenote);
-- then take the best side. And separately record the step OFF the plot itself,
-- which is the foundation skirt's own face and is bounded by the contract's
-- skirt of six rather than by a walking step.
if mode == "walk" then
	local TERRACE = 3            -- the troll cenote terrace of contract 2.4
	local SKIRT_FACE = 6         -- the contract's foundation skirt
	local APPROACH = 16
	local CORE_EDGE = 48
	local SIDES = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
	io.write("kind\tseed\tlot\treference\tskirt_face\tbest_side",
		"\tbest_step\twalkable_sides\n")
	local worst_walk, worst_lot, worst_seed = 0, "-", "-"
	local worst_face, worst_face_lot = 0, "-"
	for index = 1, #sessions do
		local session = sessions[index]
		for _, entry in ipairs(lots.all()) do
			local base = column(session, entry.x, entry.z).y
			local out0 = entry.reach + 1
			local best, best_side, walkable = nil, "-", 0
			local face = 0
			for _, side in ipairs(SIDES) do
				local step, reached = 0, 0
				for out = out0, out0 + APPROACH do
					local x = entry.x + side[1] * out
					local z = entry.z + side[2] * out
					local cell = column(session, x, z)
					if cell.wet then break end
					local previous = column(session,
						entry.x + side[1] * (out - 1),
						entry.z + side[2] * (out - 1))
					if out == out0 then
						local gap = math.abs(cell.y - base)
						if gap > face then face = gap end
					elseif not previous.wet then
						local gap = math.abs(cell.y - previous.y)
						if gap > step then step = gap end
					end
					reached = out - out0 + 1
				end
				-- A side that walks into the water before it has left the plot
				-- is no approach at all.
				if reached >= 4 then
					if step <= TERRACE then walkable = walkable + 1 end
					if best == nil or step < best then
						best, best_side = step, side[1] .. "," .. side[2]
					end
				end
			end
			best = best or 99
			io.write(table.concat({"kezamba_walk", session.seed, entry.id,
				base, face, best_side, best, walkable}, "\t"), "\n")
			if best > worst_walk then
				worst_walk, worst_lot, worst_seed = best, entry.id,
					session.seed
			end
			if face > worst_face then worst_face, worst_face_lot = face, entry.id end
		end
		for _, spot in ipairs({{CORE_EDGE, 0}, {-CORE_EDGE, 0},
				{0, CORE_EDGE}, {0, -CORE_EDGE}}) do
			local cell = column(session, spot[1], spot[2])
			io.write(table.concat({"kezamba_core_edge", session.seed,
				spot[1] .. "," .. spot[2], session.anchor.y,
				cell.wet and "water" or math.abs(cell.y - session.anchor.y),
				"-", "-", "-"}, "\t"), "\n")
		end
	end
	io.write("kezamba_walk_worst\tbest_side_step\t", worst_walk, "\t",
		worst_lot, "\t", worst_seed, "\tskirt_face\t", worst_face, "\t",
		worst_face_lot, "\tterrace\t", TERRACE, "\tskirt\t", SKIRT_FACE,
		"\n")
	if worst_walk > TERRACE or worst_face > SKIRT_FACE then
		io.write("kezamba_walk FAIL: a plot cannot be walked up to\n")
		os.exit(1)
	end
	io.write("kezamba_walk PASS: every lot has an approach that steps at most ",
		TERRACE, " nodes a column and a face inside the skirt, on all ",
		#SEEDS, " seeds\n")
	os.exit(0)
end

if mode == "probe" then
	local reach = tonumber(arg[5] or "13")
	local x, z = tonumber(arg[3]), tonumber(arg[4])
	local geometry = geometry_refusal(x, z, reach)
	local refusal, fall, rise, wet = terrain_refusal(x, z, reach, MIN_CLEAR)
	io.write("probe (", x, ", ", z, ") reach ", reach, ": ",
		geometry or refusal or "ok", "  fall=", fall or "-", " rise=",
		rise or "-", " wet=", wet or "-", "\n")
	os.exit(0)
end

if mode == "map" then
	local reach = tonumber(arg[3] or "13")
	io.write("-- legal lot centres for reach ", reach,
		", 8-node lattice; # legal, . refused, ~ wet reference\n")
	for z = -248, 248, 8 do
		local row = {}
		for x = -248, 248, 8 do
			local mark = "."
			if column(sessions[1], x, z).wet then mark = "~"
			elseif legal(x, z, reach, MIN_CLEAR) == nil then mark = "#" end
			row[#row + 1] = mark
		end
		io.write(string.format("%5d %s\n", z, table.concat(row)))
	end
	os.exit(0)
end

-- `check`: the authored lots of `wp13/kezamba_lots.lua`.
io.write("kind\tlot\tkind2\tx\tz\treach\tfall\trise\twet\tverdict\n")
local failures = 0
local seen = {}
for _, entry in ipairs(lots.all()) do
	local refusal, fall, rise, wet = terrain_refusal(entry.x, entry.z,
		entry.reach, MIN_CLEAR)
	local geometry = geometry_refusal(entry.x, entry.z, entry.reach)
	local verdict = geometry or refusal or "ok"
	-- One node clear of every other lot.
	for _, other in ipairs(seen) do
		local gap_x = math.abs(entry.x - other.x) -
			(entry.reach + other.reach + 2 * MARGIN)
		local gap_z = math.abs(entry.z - other.z) -
			(entry.reach + other.reach + 2 * MARGIN)
		if gap_x <= 0 and gap_z <= 0 then
			verdict = "overlaps " .. other.id
		end
	end
	seen[#seen + 1] = entry
	if verdict ~= "ok" then failures = failures + 1 end
	io.write(table.concat({"kezamba_lot", entry.id, entry.kind, entry.x,
		entry.z, entry.reach, fall or "-", rise or "-", wet or "-",
		verdict}, "\t"), "\n")
end
io.write("kezamba_lots\t", #lots.all(), "\tfailures\t", failures, "\n")
if failures ~= 0 then
	io.write("kezamba_lots FAIL\n")
	os.exit(1)
end
io.write("kezamba_lots PASS: every authored lot is legal on all ", #SEEDS,
	" seeds\n")
