-- Where Kezamba's district and fill lots may stand, on all NINE seeds.
--
--     luajit tools/wp13/kezamba_lots.lua <repo> check
--     luajit tools/wp13/kezamba_lots.lua <repo> walk
--     luajit tools/wp13/kezamba_lots.lua <repo> repair
--     luajit tools/wp13/kezamba_lots.lua <repo> gates
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

-- `repair`: THE GROUND UNDER A FINISHED CITY HAS MOVED.
--
--     luajit tools/wp13/kezamba_lots.lua <repo> repair
--
-- `pack` invents a layout and is the right tool exactly once. When a WP40
-- terrain package moves the ground under a city that already stands -- which
-- the `cenote_terrace` apron of 2026-09-16 did -- re-running `pack` would slide
-- districts that are perfectly legal and rearrange a composition for nothing.
-- This is `tools/wp13/highcourt_plots.lua --repair`'s rule applied here: KEEP
-- EVERY LEGAL LOT, and move only an illegal one, to the NEAREST legal centre
-- that clashes with none of the other fifty-one.
--
-- The search is deterministic and lattice-aligned: candidates on the packer's
-- own even lattice, ranked by (Manhattan distance from the authored centre, x,
-- z), first hit wins. It prints the replacement row for `wp13/kezamba_lots.lua`
-- and nothing else has to be decided by hand.
--
-- AND IF NOTHING FITS AT THE LOT'S OWN REACH, IT TRIES A SMALLER FILL SIZE
-- BEFORE IT GIVES UP -- which the apron of 2026-09-16 made necessary and is a
-- measurement, not a convenience. `totem_f2` stood at (66, 154) with a reach of
-- 11 on the lake's north bank; the apron steps the ground up from the shore at
-- the terrace step, so that lot now looks up a 33-node slope inside its own
-- clear. There is no other reach-11 centre for it: over the whole totem band on
-- the packer's lattice exactly TWELVE are legal, all of them in the far
-- north-east corner 150 nodes from the district's spine -- and the same twelve,
-- in the same corner, on the tree WITHOUT the apron. The shortage is the lake's
-- and not this change's. A reach of 8 has 39, several of them ten nodes from
-- where the lot already stood, so the ladder below prefers a SMALLER lot in its
-- own quarter over a full-sized one in someone else's.
if mode == "repair" then
	-- The fill reaches `pack` uses, largest first: a repair may drop to a
	-- smaller one and never grows a lot.
	--
	-- A BUILDING PLOT NEVER SHRINKS. Its yard is not empty -- a building is
	-- projected into it and `kezamba_plot.build` measures the part against the
	-- reach -- so a smaller reach would either refuse at construction or leave
	-- the composition wider than the lot the predicate measured, which is the
	-- rule `kezamba_kat.lua` asserts ("is wider than the lot it was measured
	-- on"). Only a `fill` lot, whose yard IS its reach, may take a smaller size;
	-- a building plot moves or the repair says it could not.
	local REACH_LADDER = {13, 11, 8, 5}
	local all = lots.all()
	local function clashes_with_others(id, x, z, reach)
		for index = 1, #all do
			local other = all[index]
			if other.id ~= id then
				local gap_x = math.abs(x - other.x) -
					(reach + other.reach + 2 * MARGIN)
				local gap_z = math.abs(z - other.z) -
					(reach + other.reach + 2 * MARGIN)
				if gap_x <= 0 and gap_z <= 0 then return true end
			end
		end
		return false
	end
	io.write("kind\tid\tfrom_x\tfrom_z\tto_x\tto_z\tmoved\trefusal\n")
	local moved, unrepairable = 0, 0
	for index = 1, #all do
		local lot = all[index]
		local refusal = legal(lot.x, lot.z, lot.reach, MIN_CLEAR)
		if refusal == nil and not clashes_with_others(lot.id, lot.x, lot.z,
				lot.reach) then
			io.write("kezamba_repair_keep\t", lot.id, "\t", lot.x, "\t", lot.z,
				"\t", lot.x, "\t", lot.z, "\t0\t-\n")
		else
			local best
			for ladder = 1, #REACH_LADDER do
				local reach = REACH_LADDER[ladder]
				if reach == lot.reach or
						(reach < lot.reach and lot.kind == "fill") then
					for radius = 0, 64, 2 do
						for dz = -radius, radius, 2 do
							local dx_span = radius - math.abs(dz)
							for _, dx in ipairs(dx_span == 0 and {0} or
									{-dx_span, dx_span}) do
								local x, z = lot.x + dx, lot.z + dz
								if best == nil and
										legal(x, z, reach, MIN_CLEAR) == nil and
										not clashes_with_others(lot.id, x, z, reach) then
									best = {x = x, z = z, cost = radius,
										reach = reach}
								end
							end
						end
						if best then break end
					end
				end
				if best then break end
			end
			if best then
				moved = moved + 1
				io.write("kezamba_repair_move\t", lot.id, "\t", lot.x, "\t",
					lot.z, "\t", best.x, "\t", best.z, "\t", best.cost,
					"\treach ", lot.reach, "->", best.reach, " ",
					tostring(refusal or "clash"), "\n")
				io.write(string.format(
					"\t\t{id = \"%s\", kind = \"%s\", x = %d, z = %d, reach = %d},\n",
					lot.id, lot.kind, best.x, best.z, best.reach))
			else
				unrepairable = unrepairable + 1
				io.write("kezamba_repair_FAIL\t", lot.id, "\t", lot.x, "\t",
					lot.z, "\t-\t-\t-\t", tostring(refusal or "clash"), "\n")
			end
		end
	end
	io.write("kezamba_repair\t", #all, "\tmoved\t", moved, "\tunrepairable\t",
		unrepairable, "\n")
	os.exit(unrepairable == 0 and 0 or 1)
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
-- (3) Its third version took the best APPROACH of the four sides but the worst
-- KERB FACE, and failed three lot-seed pairs by one node on a face a walker
-- would never use. Both halves belong to the same side.
--
-- So: for each side, walk sixteen columns straight out from the first column
-- beyond the plot's own ground, recording the step off the kerb and the worst
-- step between neighbours, with a water column ending that direction (you
-- cannot walk into the cenote). The verdict is the side a walker would pick --
-- the lowest kerb face, then the gentlest approach -- held to one terrace step
-- on the walk and to the contract's foundation skirt of six on the face.
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
			local best, best_side, best_face, walkable = nil, "-", 99, 0
			for _, side in ipairs(SIDES) do
				local step, reached, face = 0, 0, 0
				for out = out0, out0 + APPROACH do
					local x = entry.x + side[1] * out
					local z = entry.z + side[2] * out
					local cell = column(session, x, z)
					if cell.wet then break end
					local previous = column(session,
						entry.x + side[1] * (out - 1),
						entry.z + side[2] * (out - 1))
					if out == out0 then
						face = math.abs(cell.y - base)
					elseif not previous.wet then
						local gap = math.abs(cell.y - previous.y)
						if gap > step then step = gap end
					end
					reached = out - out0 + 1
				end
				-- A side that walks into the water before it has left the plot
				-- is no approach at all.
				if reached >= 4 then
					if step <= TERRACE and face <= SKIRT_FACE then
						walkable = walkable + 1
					end
					-- THE BEST SIDE IS THE ONE A WALKER WOULD USE, so it is
					-- chosen on the face FIRST and the approach second: a plot
					-- with a seven-node kerb on one side and a level one on
					-- another is entered from the level one. Taking the worst
					-- of the four sides was this mode's third wrong question.
					if best == nil or face < best_face or
							(face == best_face and step < best) then
						best, best_face = step, face
						best_side = side[1] .. "," .. side[2]
					end
				end
			end
			best = best or 99
			io.write(table.concat({"kezamba_walk", session.seed, entry.id,
				base, best_face, best_side, best, walkable}, "\t"), "\n")
			if best > worst_walk then
				worst_walk, worst_lot, worst_seed = best, entry.id,
					session.seed
			end
			if best_face > worst_face then
				worst_face, worst_face_lot = best_face, entry.id
			end
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
	io.write("kezamba_walk PASS: every lot has a side whose kerb is inside the ",
		"skirt and whose approach steps at most ", TERRACE,
		" nodes a column, on all ", #SEEDS, " seeds\n")
	os.exit(0)
end

-- `gates`: WHERE EACH AVENUE ARRIVES AT ITS GATE POINT, ON ALL NINE SEEDS.
--
-- The independent review of 2026-09-16 measured the road arriving up to 26 nodes
-- above the terrain Lane R hands it, on a sheer face, with the threshold's posts
-- floating on top (blocker B2). The coordinator's ruling is that the avenue
-- arrives at the terrain height there, descending inside the envelope at most a
-- node a column, with nothing floating. `wp13/kezamba_ramp.lua` is the rule;
-- this is the measurement, and it is a gate rather than a note because the
-- terrain outside the envelope is WP40's and moves for WP40's reasons.
--
-- It runs the real modules -- `wp13/avenue.lua`'s own `M.run` and the ramp on
-- top of it -- against the seam's own surface rule, which is why it can be
-- trusted to agree with the built map: `r7_settlement.lua` hands an overlay the
-- WALKABLE surface of a column, "the ground, or the water standing on it where
-- there is any", and that is exactly what `walkable` below returns.
--
-- Per gate and seed it reports:
--   step        the road's level at the gate point minus the terrain there.
--               The ruling's target is 0, and anything over 1 is a face.
--   ramp        how many columns the descent took.
--   drop        how far it came down over them.
--   floating    cells of the piece with nothing under them and no reason to
--               have none. Target 0.
--   on_water/on_deck/on_pillars
--               the three exempt kinds: a boardwalk over the cenote, a column
--               standing on a WP40 route's deck, and a VIADUCT column the road
--               raised MIN_CLEAR or more, whose open air is playtest 5's
--               ruling 4 and not a defect.
if mode == "gates" then
	local wp13dir = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
	local avenue = dofile(wp13dir .. "/avenue.lua")(wp13dir)
	local palettes = dofile(wp13dir .. "/palette.lua")
	local kezamba = dofile(wp13dir .. "/kezamba.lua")(wp13dir)
	local road = palettes.new("troll")
	local STEP_CEILING = 1

	io.write("kind\tseed\trun\tgate\tterrain\troad\tstep\tramp",
		"\tdrop\tfloating\ton_water/on_deck/on_pillars\tcells\n")
	local worst_step, worst_run, worst_seed = 0, "-", "-"
	local worst_float, float_run = 0, "-"
	for index = 1, #sessions do
		local session = sessions[index]
		-- THE SEAM'S OWN SURFACE RULE, mirrored: the ground, or the water
		-- standing on it. `r7_settlement.lua` builds an overlay's surface this
		-- way and `wp13/avenue.lua` is written against it.
		local cache = {}
		local function walkable(x, z)
			local key = x * 8192 + z
			local hit = cache[key]
			if hit == nil then
				local wx, wz = session.anchor.x + x, session.anchor.z + z
				local terrain = session.height.terrain_height_at(wx, wz)
				local wet = session.horizontal.water_class_at(wx, wz) ~= "land"
				local water = wet and session.height.water_surface_at(wx, wz)
					or nil
				if type(water) == "number" and water > terrain then
					hit = {surface = water, terrain = terrain}
				else
					hit = {surface = terrain, terrain = terrain}
				end
				cache[key] = hit
			end
			return hit
		end
		local function surface(x, z) return walkable(x, z).surface end
		-- AND THE SEAM'S OWN WATER QUERY beside it. Since 2026-09-16 the seam
		-- publishes whether a column is water as a third value of
		-- `walkable_values`, and `wp13/avenue.lua` bridges a wet column instead
		-- of paving a causeway across it. A tool that handed the road only the
		-- surface would be measuring a road nobody builds -- over Kezamba's own
		-- cenote, the one this gate is about.
		local function wet_at(x, z)
			local here = walkable(x, z)
			return here.surface > here.terrain
		end

		-- THE RUNS AS THE SEAM HANDS THEM OVER, which since 2026-09-16 means
		-- carrying the JUNCTION SQUARES the composition attached in
		-- `overlay_runs`: a plateau where two streets cross is part of the
		-- road's own geometry, and an avenue built without them is not the
		-- avenue that arrives at the gate.
		local attached = {}
		for _, entry in ipairs(kezamba.overlay_runs()) do
			attached[entry.id] = entry
		end
		for _, authored in ipairs(kezamba.avenues) do
			local run = attached[authored.id] or authored
			local plan = kezamba.avenue_plan[run.id]
			local spec = {id = run.id, axis = run.axis, at = run.at,
				from = run.from, to = run.to, width = avenue.WIDTH,
				lamp_spacing = avenue.LAMP_SPACING, lamp_phase = run.lamp_phase or run.from,
				reach = avenue.REACH, wet = wet_at,
				junctions = run.junctions, plain_verge = run.plain_verge,
				clear_verge = run.clear_verge}
			local ok, piece = pcall(kezamba.overlay_run, avenue, road, spec,
				surface)
			if not ok then
				io.write(table.concat({"kezamba_gate", session.seed, run.id,
					plan.gate, "-", "-", "REFUSED", "-", "-", "-",
					tostring(piece)}, "\t"), "\n")
				worst_step = 99
			else
				local dx = (run.axis == "x") and 1 or 0
				local function column(q, lane)
					if dx == 1 then return q, run.at + lane end
					return run.at + lane, q
				end
				-- The road's level at the gate point: the topmost cell of the
				-- carriageway there.
				local gx, gz = column(plan.gate, 0)
				local level
				local occupied = {}
				for cell_index = 1, #piece.cells do
					local cell = piece.cells[cell_index]
					if cell.name ~= "air" then
						occupied[cell.x .. ":" .. cell.y .. ":" .. cell.z] = true
						if cell.x == gx and cell.z == gz and
								(level == nil or cell.y > level) then
							level = cell.y
						end
					end
				end
				local ground = walkable(gx, gz).terrain
				local step = level and math.abs(level - ground) or 99
				-- FLOATING CELLS: a cell of the piece whose own column has
				-- nothing under it -- neither the ground nor another cell of
				-- the piece. This is the half of the ruling that says the ramp
				-- may not be a shelf.
				--
				-- TWO COLUMNS ARE EXEMPT, and both are the seam's own design
				-- rather than this lane's:
				--
				--   * a column of the CENOTE. `r7_settlement.lua` hands an
				--     overlay the water's surface where there is water, on
				--     purpose -- "the result is a solid causeway across the
				--     water and not paving floating on it" -- and the lake
				--     itself is what the deck rests on. Counting those would
				--     call every boardwalk column a defect.
				--   * a column a WP40 ROUTE BRIDGE spans. `avenue.lua`'s
				--     crossing rule stands the road on the route's own deck and
				--     deliberately does not fill up to it ("the bridge carries
				--     the road, so the road does not fill the river up to it,
				--     which would be a dam with a street on top"). The deck is
				--     WP40's and is not in this piece.
				--   * a column of a VIADUCT, and this one is the user's ruling
				--     of 2026-09-16 rather than the seam's design: "streets
				--     raised artificially must stand on SUPPORT PILLARS with
				--     open air beneath, so the street is not a wall and a player
				--     can walk under it". A column the road walks `MIN_CLEAR` or
				--     more above its own ground carries the deck course, the
				--     plank verge, its rail and a pillar every `avenue.PIER`
				--     columns, and NOTHING else -- the air under it is the whole
				--     point. The exemption is bounded by exactly that test, so a
				--     cell hanging over ground the road did NOT raise is still a
				--     defect: measured on seed 8675309 before the exemption,
				--     100 % of the 509 cells this gate flagged stood on a column
				--     raised at least MIN_CLEAR (the independent review of
				--     2026-09-16, `kzfloat.lua`).
				local spanned = {}
				for cross = 1, #(piece.crossings or {}) do
					local row = piece.crossings[cross]
					spanned[row.x .. ":" .. row.z] = true
				end
				-- The road's own walking level per column, which is what the
				-- viaduct test is taken against: the topmost cell of the piece
				-- in that column.
				local column_top = {}
				for cell_index = 1, #piece.cells do
					local cell = piece.cells[cell_index]
					if cell.name ~= "air" then
						local key = cell.x .. ":" .. cell.z
						if column_top[key] == nil or cell.y > column_top[key] then
							column_top[key] = cell.y
						end
					end
				end
				local floating, on_water, on_deck, on_pillars = 0, 0, 0, 0
				for cell_index = 1, #piece.cells do
					local cell = piece.cells[cell_index]
					if cell.name ~= "air" then
						local key = cell.x .. ":" .. cell.z
						local here = walkable(cell.x, cell.z)
						local unsupported = cell.y - 1 > here.terrain and
							not occupied[cell.x .. ":" .. (cell.y - 1) ..
								":" .. cell.z]
						if unsupported then
							if here.surface > here.terrain then
								on_water = on_water + 1
							elseif spanned[key] then
								on_deck = on_deck + 1
							elseif column_top[key] ~= nil and
									column_top[key] - here.terrain >=
										avenue.MIN_CLEAR then
								on_pillars = on_pillars + 1
							else
								floating = floating + 1
							end
						end
					end
				end
				io.write(table.concat({"kezamba_gate", session.seed, run.id,
					plan.gate, ground, level or "-", step,
					piece.ramp_columns or 0, piece.ramp_drop or 0, floating,
					on_water .. "/" .. on_deck .. "/" .. on_pillars,
					#piece.cells}, "\t"), "\n")
				if step > worst_step then
					worst_step, worst_run, worst_seed = step, run.id,
						session.seed
				end
				if floating > worst_float then
					worst_float, float_run = floating, run.id .. "@" ..
						session.seed
				end
			end
		end
	end
	io.write("kezamba_gates_worst\tstep\t", worst_step, "\t", worst_run,
		"\t", worst_seed, "\tfloating\t", worst_float, "\t", float_run,
		"\tceiling\t", STEP_CEILING, "\n")
	if worst_step > STEP_CEILING or worst_float > 0 then
		io.write("kezamba_gates FAIL: an avenue does not reach its gate\n")
		os.exit(1)
	end
	io.write("kezamba_gates PASS: every avenue arrives at its gate point ",
		"within ", STEP_CEILING, " node of the terrain with nothing floating, ",
		"on all ", #SEEDS, " seeds\n")
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

-- `check`: the authored lots of `wp13/kezamba_lots.lua` -- AND THE COMMITTED
-- MASK ITSELF.
--
-- The mask is verified here and not only by `kezamba_water.lua --verify`
-- because of what the independent review of 2026-09-16 found: the KAT asserts
-- the mask's published counts, its disjointness and its one-node relation to the
-- reference, all of which are the module against itself, and nothing that RUNS
-- ever asked the planner whether the lake is still where the module says. A WP40
-- change that moved the cenote would therefore leave every gate green while the
-- composition wrote ground into water and air over it -- the one failure this
-- whole package exists to avoid.
--
-- `check` already builds the nine planner sessions this needs, so the
-- verification is free here and nowhere else. It is the gate; the note and the
-- tool headers say so.
--
-- BOTH HALVES OF THE MASK ARE CHECKED HERE, and the second half is the reason
-- this paragraph was written twice. The lagoon half was added after the review
-- of 2026-09-16. The RAVINE half was added a day later, after the rebase onto
-- main `f5583e13`: WP40's routes had stopped grading through the capital
-- envelope, the graded corridor that cut the pad was gone, and the only thing
-- in the tree that noticed was `kezamba_water.lua --verify`, which nothing runs
-- on every change. A dry column standing below the fitted reference must be a
-- ravine column of the committed mask, and a ravine column must stand below it:
-- anything else and the composition is building around a gorge that is not
-- there, or laying ground over one that is.
do
	local committed = dofile(wp13 .. "/kezamba_lagoon.lua")()
	local bad, wet_core, low_core = 0, 0, 0
	for index = 1, #sessions do
		local session = sessions[index]
		for z = -committed.REACH, committed.REACH do
			for x = -committed.REACH, committed.REACH do
				local cell = column(session, x, z)
				if cell.wet then
					if index == 1 then wet_core = wet_core + 1 end
					if not committed.lagoon(x, z) then bad = bad + 1 end
				else
					if committed.lagoon(x, z) then bad = bad + 1 end
					-- The ravine half. The committed mask is the UNION over the
					-- nine seeds grown by one node, so a mask column may stand
					-- at the reference on any single seed; a column BELOW the
					-- reference may never be outside it.
					if cell.y < committed.REFERENCE_Y then
						low_core = low_core + 1
						if not committed.ravine(x, z) then bad = bad + 1 end
					end
				end
			end
		end
		if session.anchor.y ~= committed.REFERENCE_Y then bad = bad + 1 end
	end
	-- And the other direction, which a union cannot state per seed: a mask that
	-- claims a gorge no seed has is a composition built around nothing.
	if committed.RAVINE_COLUMNS > 0 and low_core == 0 then bad = bad + 1 end
	io.write("kezamba_mask\tcore_wet\t", wet_core, "\tcore_below_reference\t",
		low_core, "\travine_columns\t", committed.RAVINE_COLUMNS,
		"\tdisagreements\t", bad, "\tseeds\t", #sessions, "\n")
	if bad ~= 0 then
		io.write("kezamba_lots FAIL: the committed mask is not the map\n")
		os.exit(1)
	end
end

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
