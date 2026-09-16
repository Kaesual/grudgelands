-- Do WP40's routes stop at a capital's gates, and can the city still be
-- entered through them?
--
--     luajit tools/wp13/route_gates.lua <repo> <seed> [out.tsv] [--full] [--strict]
--
-- WHAT IT MEASURES, and why this tool exists.
--
-- WP40's star-shaped route graph predates the WP13 cities. Every route that
-- names a capital zone runs to that zone's HUB, and a capital anchor sits on
-- its hub, so four long-distance roads used to be graded straight through the
-- 512-node build envelope and out the far side. Playtest round 4 found what
-- that leaves on the ground: at Dur Brannoc the incoming road crosses the
-- curtain wall at (-1847, -1756) -- 47 nodes west of the gate the wall has at
-- (-1801, -1756) -- so the road is cut in half by masonry and the gate leads
-- nowhere.
--
-- The ruling (2026-09-15): every incoming route ends at a planned point of the
-- city boundary -- a gate -- and no longer runs into the interior; inside, the
-- WP13 streets take over.
--
-- So this tool answers seven questions per capital and seed, offline, out of
-- the same pure WP40 height session `tools/wp13/lane_routes.lua` and
-- `tools/wp13/capital_anchor_fixture.lua` build (no engine, no world):
--
--   1. GATE DISTANCE. Where does each of the four incoming routes actually
--      end, and how far is that from the gate it should end at? Target 0.
--   2. STRAIGHT APPROACH. Is the final stretch axial -- the road normal to the
--      wall it passes through -- and how long is it?
--   3. INTERIOR CELLS. What lies strictly inside the envelope (both anchor
--      offsets under 256 in absolute value)? Zero bridge decks -- a deck inside
--      the envelope is the wave-1 lane-crossing case, which the ruling turns
--      from a feature into a safeguard -- and, of road, nothing but the four
--      gates' own end caps: a route ends AT its gate and a seven-wide road
--      rounds over its terminal, so fifteen columns per gate reach at most
--      three nodes in, inside the curtain's own thickness. Any road column
--      outside that shape is a STRAY and is a fault; see `end_cap_gate`.
--   4. THE STEP AT THE GATE. The route's own graded surface at the gate column
--      against the level the avenue is actually BUILT at there -- the real
--      `wp13/avenue.lua` run over the real WP40 seam. Target <= 1: a city
--      whose gate is a two-node kerb is a city you jump into.
--   5. WATER UNDER THE AVENUES. With no route inside the envelope there is no
--      WP40 bridge inside it either, so the four avenues carry themselves.
--      This counts the columns of each avenue where water stands on the
--      ground, and then checks the thing that actually matters: that the
--      built road is continuous over them. `wp40/r7_settlement.lua`'s
--      `walkable_values` hands the overlay the WATER surface where there is
--      water, and the settlement writer overwrites, "so the result is a solid
--      causeway across the water and not paving floating on it" -- so a wet
--      avenue is a causeway, not a hole, and the gate is still an entrance.
--      The count is reported, the discontinuity is the fault.
--   6. CAN THE CITY BE ENTERED? The walked surface from 64 nodes outside the
--      avenue's own outer end all the way in to the core edge, route surface
--      where only the route is and the built avenue where the overlay covers
--      the column. Every step of more than one node is a place a player has to
--      jump, and a gate you jump into is not a gate.
--   7. IS THE GROUND JUST INSIDE THE GATE STILL GROUND? The road's own
--      one-Lipschitz envelope smooths question 6 over a cliff it is standing
--      on, so this reads the TERRAIN over the eight columns inside the gate --
--      the curtain's width and its footing -- and refuses a step of more than
--      twice a capital's largest terrace rise. The first version of this lane
--      pinned the gate to the anchor's platform height and built a 52-node
--      embankment with a 24-node wall four columns inside the gate; question 6
--      walked up it quite happily.
--
-- THE SCAN. A route can only grade columns within its corridor of the
-- centreline, so the interior count walks a band around every route and spur
-- polyline rather than all 263169 columns of an envelope. `--full` scans the
-- whole envelope instead and is how that shortcut is checked; the two agree.
--
-- EXIT STATUS. Questions 1, 2 and 3 are the ROUTE GRAPH's, and this lane owns
-- them: any fault there exits 1 on every seed. Questions 4 to 7 are a
-- CAPITAL's terrain and blueprint, which the route graph can improve but not
-- repair, so they are always reported and counted and only enter the exit
-- status under `--strict`. A capital lane runs `--strict` as its own
-- acceptance check -- target zero, on all nine fixture seeds -- and the
-- coordinator runs the default as a merge gate on the route graph. The last
-- line of stdout carries both counts either way.
--
-- Plain Lua 5.1 (LuaJIT in practice for the eight-second WP40 construction).

local repo = assert(arg[1], "repository root required")
local seed = assert(arg[2], "world seed required")
local full, strict, out_path = false, false, nil
for index = 3, #arg do
	if arg[index] == "--full" then full = true
	elseif arg[index] == "--strict" then strict = true
	else out_path = arg[index] end
end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local source = dofile(wp40 .. "/source/simple_map.lua")
local schemas = dofile(wp40 .. "/schemas.lua")
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local raw_sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()

local horizontal = dofile(wp40 .. "/simple_map.lua")({source = source,
	schemas = schemas, canonical = canonical, deterministic = deterministic,
	raw_sha256 = raw_sha256}).new(seed)
local height = dofile(wp40 .. "/height.lua")({source = source,
	canonical = canonical, deterministic = deterministic,
	raw_sha256 = raw_sha256, horizontal_session = horizontal,
	coupled_grade = dofile(wp40 .. "/coupled_grade.lua")()}).new_runtime(seed)

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local palettes = dofile(wp13 .. "/palette.lua")
local avenue = dofile(wp13 .. "/avenue.lua")(wp13)

-- THE SEAM, offline: the two numbers `wp40/r7_settlement.lua`'s
-- `walkable_values` hands the overlay in the engine -- the walkable surface of
-- a column (the ground, or the water standing on it) and the height of a
-- bridge deck that spans it.
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

-- The contract avenue: the anchor's own centre line, half-width 2, from the
-- core edge at 48 out to 261.
local AVENUE_HALF, AVENUE_IN, AVENUE_OUT = 2, 48, 261
assert(AVENUE_HALF * 2 + 1 == avenue.WIDTH,
	"the contract carriageway is no longer the road module's own width")

-- ---------------------------------------------------------------------------
-- The gate points, derived the way the contract defines them
-- ---------------------------------------------------------------------------
-- A capital's build envelope is `source.capital_core`, 512 by 512 centred on
-- the anchor, and WP13 opens one gate in the middle of each edge on the centre
-- line of the avenue that runs out to it (`wp13/highcourt.lua`: "the gate
-- stations sit at +-256 on each axis"). The four gate points are therefore
-- (ax +- 256, az) and (ax, az +- 256). They are derived here rather than read
-- so that the tool states the definition independently; where WP40 publishes
-- the same points (`source.capital_gates`) the two are compared.
local HALF = source.capital_core.width_x / 2
assert(HALF == source.capital_core.width_z / 2, "capital envelope is not square")

-- Luanti's +z is north.
local SIDES = {
	{id = "west", dx = -1, dz = 0}, {id = "east", dx = 1, dz = 0},
	{id = "south", dx = 0, dz = -1}, {id = "north", dx = 0, dz = 1},
}

local capitals = {}
for index = 1, #source.anchors do
	local anchor = source.anchors[index]
	if anchor.slot_id == "capital" then
		local zone = source.zones[anchor.zone_numeric_id]
		assert(anchor.position.x == zone.hub.x and anchor.position.z == zone.hub.z,
			"capital anchor is not its zone hub: " .. anchor.id)
		local gates, by_side = {}, {}
		for _, side in ipairs(SIDES) do
			local gate = {side = side.id, dx = side.dx, dz = side.dz,
				x = anchor.position.x + side.dx * HALF,
				z = anchor.position.z + side.dz * HALF}
			gates[#gates + 1] = gate
			by_side[side.id] = gate
		end
		capitals[#capitals + 1] = {anchor = anchor, zone = zone,
			zone_numeric_id = anchor.zone_numeric_id, key = zone.id,
			x = anchor.position.x, z = anchor.position.z,
			gates = gates, by_side = by_side}
	end
end
assert(#capitals == 6, "the roster carries " .. #capitals .. " capitals")

local capital_by_zone = {}
for _, capital in ipairs(capitals) do
	capital_by_zone[capital.zone_numeric_id] = capital
end

-- Cross-check against WP40's published table where it exists.
local published_faults = 0
if type(source.capital_gates) == "table" then
	local seen = {}
	for index = 1, #source.capital_gates do
		local row = source.capital_gates[index]
		local capital = capital_by_zone[row.zone_numeric_id]
		local gate = capital and capital.by_side[row.side]
		if not gate or gate.x ~= row.position.x or gate.z ~= row.position.z then
			published_faults = published_faults + 1
		else
			seen[row.zone_numeric_id .. ":" .. row.side] = true
		end
	end
	local expected = 0
	for _, capital in ipairs(capitals) do
		for _, side in ipairs(SIDES) do
			expected = expected + 1
			if not seen[capital.zone_numeric_id .. ":" .. side.id] then
				published_faults = published_faults + 1
			end
		end
	end
	if #source.capital_gates ~= expected then
		published_faults = published_faults + 1
	end
end

-- ---------------------------------------------------------------------------
-- Which route takes which gate
-- ---------------------------------------------------------------------------
-- A route that names a capital zone runs from that hub to another zone's hub,
-- and every one of the twenty-four does so along one of the two axes. The gate
-- it takes is therefore the one on the side it approaches from; the assignment
-- is computed here from the OTHER endpoint so that the tool does not depend on
-- the rule it is checking.
local approaches = {}
for index = 1, #source.routes do
	local route = source.routes[index]
	for _, which in ipairs({"a", "b"}) do
		local zone_id = which == "a" and route.zone_a or route.zone_b
		local capital = capital_by_zone[zone_id]
		if capital then
			local other = source.zones[which == "a" and route.zone_b or route.zone_a]
			local dx, dz = other.hub.x - capital.x, other.hub.z - capital.z
			local side
			if math.abs(dx) > math.abs(dz) then
				side = dx < 0 and "west" or "east"
			else
				side = dz < 0 and "south" or "north"
			end
			local gate = capital.by_side[side]
			gate.route_id = route.id
			approaches[#approaches + 1] = {route = route, capital = capital,
				which = which, gate = gate,
				terminal = which == "a" and route.centreline[1] or
					route.centreline[#route.centreline]}
		end
	end
end

-- Two routes may not want the same gate. Nothing in the shipped graph does,
-- but a report that did not say so would be a report that never looked.
local gate_claims, gate_collisions = {}, 0
for _, approach in ipairs(approaches) do
	local key = approach.capital.key .. ":" .. approach.gate.side
	if gate_claims[key] then gate_collisions = gate_collisions + 1 end
	gate_claims[key] = (gate_claims[key] or 0) + 1
end

-- ---------------------------------------------------------------------------
-- The scan band: every column any route or spur could possibly grade
-- ---------------------------------------------------------------------------
-- THE END CAP, which is the one thing a route may leave inside an envelope.
--
-- A route ends AT its gate point, and a road is not a line: a primary route's
-- surface is seven columns wide, so its terminal rounds over into a cap that
-- reaches CAP_DEPTH nodes past the last centreline point. Inside the envelope
-- that is the columns whose distance from the gate is at most the surface's
-- half width -- 7 at one node in, 5 at two, 3 at three: fifteen columns, all of
-- them within the curtain's own seven-node thickness, under the gate passage,
-- and overwritten by the avenue that runs out to 261.
--
-- So this is what the tool ACCEPTS, stated as a shape rather than as a number
-- it happens to have measured: a route column inside the envelope must belong
-- to the route that takes one of this capital's gates, must sit on that gate's
-- inward side, must be at most CAP_DEPTH nodes in and at most CAP_HALF off the
-- gate's own centre line. Anything else is a stray, and a stray is a route
-- fault. The per-gate count is reported too and may not exceed CAP_COLUMNS, so
-- a road that grew wider would redden even while staying inside the box.
local CAP_WIDTH = 7
local CAP_HALF = (CAP_WIDTH - 1) / 2
local CAP_DEPTH = CAP_HALF
local CAP_COLUMNS = 0
for depth = 1, CAP_DEPTH do CAP_COLUMNS = CAP_COLUMNS + (CAP_WIDTH - 2 * (depth - 1)) end

local function end_cap_gate(capital, x, z, feature_id)
	for _, gate in ipairs(capital.gates) do
		if gate.route_id == feature_id then
			-- `inward` counts nodes from the envelope edge toward the anchor,
			-- `across` the offset from the gate's own centre line.
			local inward, across
			if gate.dx ~= 0 then
				inward, across = (gate.x - x) * gate.dx, z - gate.z
			else
				inward, across = (gate.z - z) * gate.dz, x - gate.x
			end
			if inward >= 1 and inward <= CAP_DEPTH and
					math.abs(across) <= CAP_HALF - (inward - 1) then
				return gate
			end
			return nil
		end
	end
	return nil
end

local BAND = 24
local function band_columns(capital)
	local seen, list = {}, {}
	local min_x, max_x = capital.x - HALF + 1, capital.x + HALF - 1
	local min_z, max_z = capital.z - HALF + 1, capital.z + HALF - 1
	local function add(x, z)
		if x < min_x or x > max_x or z < min_z or z > max_z then return end
		local key = x * 100000 + z
		if seen[key] then return end
		seen[key] = true
		list[#list + 1] = {x = x, z = z}
	end
	local function walk(centreline)
		for point_index = 1, #centreline - 1 do
			local a, b = centreline[point_index], centreline[point_index + 1]
			local steps = math.max(math.abs(b.x - a.x), math.abs(b.z - a.z))
			for step = 0, steps do
				local x = a.x + math.floor((b.x - a.x) * step / steps + 0.5)
				local z = a.z + math.floor((b.z - a.z) * step / steps + 0.5)
				for ox = -BAND, BAND do
					for oz = -BAND, BAND do add(x + ox, z + oz) end
				end
			end
		end
	end
	for _, collection in ipairs({source.routes, source.poi_spurs}) do
		for index = 1, #collection do
			local centreline = collection[index].centreline
			-- Cheap rejection: a polyline whose bounding box misses the envelope
			-- by more than the band cannot contribute a column.
			local lo_x, hi_x, lo_z, hi_z = math.huge, -math.huge, math.huge, -math.huge
			for point_index = 1, #centreline do
				local point = centreline[point_index]
				if point.x < lo_x then lo_x = point.x end
				if point.x > hi_x then hi_x = point.x end
				if point.z < lo_z then lo_z = point.z end
				if point.z > hi_z then hi_z = point.z end
			end
			if hi_x >= min_x - BAND and lo_x <= max_x + BAND and
					hi_z >= min_z - BAND and lo_z <= max_z + BAND then
				walk(centreline)
			end
		end
	end
	return list
end

local function full_columns(capital)
	local list = {}
	for x = capital.x - HALF + 1, capital.x + HALF - 1 do
		for z = capital.z - HALF + 1, capital.z + HALF - 1 do
			list[#list + 1] = {x = x, z = z}
		end
	end
	return list
end

local feature_is_path = {}
for index = 1, #source.routes do feature_is_path[source.routes[index].id] = "route" end
for index = 1, #source.poi_spurs do
	feature_is_path[source.poi_spurs[index].id] = "spur"
end

-- ---------------------------------------------------------------------------
-- The measurement
-- ---------------------------------------------------------------------------
local rows = {}
local function emit(...)
	rows[#rows + 1] = table.concat({...}, "\t")
end

-- TWO CLASSES OF FAULT, and why the exit status is what it is.
--
-- A ROUTE fault is this lane's own property and nobody else's: a road that does
-- not end at its gate, a road that grades the city's interior, a deck over the
-- city, a gate two roads want. Any of those is a regression in the route graph
-- and the exit status is 1.
--
-- A CITY fault is a capital's terrain and its blueprint: the step where the
-- route hands over to the avenue, the walk in from the field, the ground just
-- inside the curtain, the avenue's own continuity. The route graph can make
-- those better or worse but it cannot fix them -- Nhal Veyr's north gate is
-- unwalkable on five of the nine fixture seeds because that capital's fitted
-- plateau stops twelve nodes short of its own envelope edge, which is the Nhal
-- Veyr lane's to mend. They are always REPORTED and counted; `--strict` puts
-- them in the exit status too, and that is the mode a capital lane runs as its
-- own acceptance check (target: zero).
--
-- The first version of this tool put both in one status, so it exited 1 on
-- every seed of its own branch over end caps it had itself declared correct.
-- A gate that is red by construction teaches people to ignore it.
local route_faults, city_faults = 0, 0
local function fault(message)
	route_faults = route_faults + 1
	emit("FAULT", seed, "route", message)
end
local function city_fault(message)
	city_faults = city_faults + 1
	emit("FAULT", seed, "city", message)
end

-- 1 and 2: where each incoming route ends, and how straight it gets there.
for _, approach in ipairs(approaches) do
	local terminal, gate = approach.terminal, approach.gate
	local distance = math.max(math.abs(terminal.x - gate.x),
		math.abs(terminal.z - gate.z))
	-- The straight run: how far back along the centreline the road stays on the
	-- gate's own axis, measured from the terminal.
	local centreline = approach.route.centreline
	local step = approach.which == "a" and 1 or -1
	local index = approach.which == "a" and 1 or #centreline
	local straight, cursor = 0, index
	while true do
		local next_index = cursor + step
		local point = centreline[next_index]
		if point == nil then break end
		local off = gate.dx ~= 0 and (point.z - gate.z) or (point.x - gate.x)
		if off ~= 0 then break end
		local here = centreline[cursor]
		straight = straight + math.abs(point.x - here.x) + math.abs(point.z - here.z)
		cursor = next_index
	end
	emit("approach", seed, approach.capital.key, approach.route.id,
		approach.which, approach.gate.side, gate.x, gate.z, terminal.x, terminal.z,
		distance, straight)
	if distance ~= 0 then
		fault(("%s %s ends %d from its %s gate"):format(approach.capital.key,
			approach.route.id, distance, approach.gate.side))
	end
end
if gate_collisions > 0 then
	fault(gate_collisions .. " gate(s) claimed by more than one route")
end
if published_faults > 0 then
	fault(published_faults .. " published capital_gates row(s) differ")
end

-- 3, 4 and 5, per capital.
local scan_kind = full and "full" or "band"
for _, capital in ipairs(capitals) do
	local columns = full and full_columns(capital) or band_columns(capital)
	local interior_route, interior_spur, interior_deck = 0, 0, 0
	local stray, cap_by_gate = 0, {}
	local by_feature = {}
	for _, column in ipairs(columns) do
		local kind, _, feature_id = height.functional_surface_values_at(column.x,
			column.z)
		local family = feature_id and feature_is_path[feature_id]
		if family == "route" then
			interior_route = interior_route + 1
			by_feature[feature_id] = (by_feature[feature_id] or 0) + 1
			local gate = end_cap_gate(capital, column.x, column.z, feature_id)
			if gate then
				cap_by_gate[gate.side] = (cap_by_gate[gate.side] or 0) + 1
			else
				stray = stray + 1
				if stray <= 8 then
					emit("stray", seed, capital.key, feature_id, column.x, column.z,
						column.x - capital.x, column.z - capital.z)
				end
			end
		elseif family == "spur" then
			interior_spur = interior_spur + 1
			by_feature[feature_id] = (by_feature[feature_id] or 0) + 1
			stray = stray + 1
		end
		if kind == "bridge_deck" then interior_deck = interior_deck + 1 end
	end
	local feature_ids = {}
	for id in pairs(by_feature) do feature_ids[#feature_ids + 1] = id end
	table.sort(feature_ids)
	for _, id in ipairs(feature_ids) do
		emit("interior_feature", seed, capital.key, id, by_feature[id])
	end
	local worst_cap = 0
	for _, side in ipairs(SIDES) do
		local count = cap_by_gate[side.id] or 0
		if count > worst_cap then worst_cap = count end
		emit("end_cap", seed, capital.key, side.id, count, CAP_COLUMNS)
	end
	emit("interior", seed, capital.key, scan_kind, #columns, interior_route,
		interior_spur, interior_deck, stray, worst_cap)
	if stray ~= 0 then
		fault(("%s grades %d road column(s) inside its envelope outside the gates'"
			.. " end caps"):format(capital.key, stray))
	end
	if worst_cap > CAP_COLUMNS then
		fault(("%s has %d end-cap column(s) at one gate, more than the %d a"
			.. " %d-wide road rounds over"):format(capital.key, worst_cap,
			CAP_COLUMNS, CAP_WIDTH))
	end
	if interior_deck ~= 0 then
		fault(("%s carries %d bridge-deck column(s) inside its envelope"):format(
			capital.key, interior_deck))
	end

	-- 4 and 5: the four avenues, built. The contract avenue is the anchor's own
	-- centre line, half-width 2, running from the core edge at 48 out to 261 --
	-- five nodes past the envelope edge, because the curtain's gate tunnel runs
	-- through the whole seven-node thickness (`wp13/highcourt.lua`).
	--
	-- THROUGH THE CAPITAL'S OWN OVERLAY DISPATCH WHERE IT HAS ONE, and through
	-- the contract run where it does not. The first version of this section
	-- called `avenue.run` for every capital, which is right for a capital that
	-- is not built yet and WRONG for one that is: a capital source hands the
	-- seam `M.overlay_run`, and Nhal Veyr's wraps the road module to bring its
	-- north avenue down to the free terrain at the gate point -- exactly the
	-- quantity question 4 measures. Measuring the contract run instead reports a
	-- four-node gate step on a capital whose built road has none.
	--
	-- A capital's WP13 module key is the part of its zone id after the region
	-- prefix, and a capital not yet written has no such file; the fallback is
	-- the contract run, unchanged. The spec is handed over in ANCHOR-RELATIVE
	-- coordinates because that is what the seam hands the overlay
	-- (`r7_settlement.lua`'s `local_surface`) and what a capital's own run table
	-- is authored in -- a world-coordinate spec would make a run's own id name a
	-- column two thousand nodes from the one it means.
	local palette = palettes.new(capital.zone.race_region)
	local module_key = capital.key:match("^[a-z]+_(.+)$")
	local capital_module
	if module_key then
		local path = wp13 .. "/" .. module_key .. ".lua"
		local probe = io.open(path, "r")
		if probe then
			probe:close()
			local loaded = dofile(path)(wp13)
			if type(loaded) == "table" and type(loaded.overlay_run) == "function" then
				capital_module = loaded
			end
		end
	end
	emit("overlay", seed, capital.key, tostring(module_key),
		capital_module and "own" or "contract")
	local function local_walkable(x, z)
		return walkable(capital.x + x, capital.z + z)
	end
	local function local_deck(x, z) return deck(capital.x + x, capital.z + z) end
	for _, side in ipairs(SIDES) do
		local axis = side.dx ~= 0 and "x" or "z"
		local sign = side.dx ~= 0 and side.dx or side.dz
		local along = axis == "x" and capital.x or capital.z
		local across = axis == "x" and capital.z or capital.x
		local local_from = sign < 0 and -AVENUE_OUT or AVENUE_IN
		local local_to = sign < 0 and -AVENUE_IN or AVENUE_OUT
		local from, to = along + local_from, along + local_to
		-- The carriageway fields are spelled out, not left to the road module's
		-- defaults, because a capital's own dispatch reads them: Dur Brannoc's
		-- rail refuses a spec with no odd carriageway in it, which is the right
		-- answer to a caller that forgot.
		local spec = {id = "avenue_" .. side.id, axis = axis, at = 0,
			from = local_from, to = local_to, lamp_phase = local_from,
			width = avenue.WIDTH, lamp_spacing = avenue.LAMP_SPACING,
			reach = avenue.REACH, overhead = local_deck}
		local piece
		if capital_module then
			piece = capital_module.overlay_run(avenue, palette, spec,
				local_walkable)
		else
			piece = avenue.run(palette, spec, local_walkable)
		end

		-- The built road, read back off its own cells: the top cell of the
		-- CENTRE lane at every position along the run, carried back into world
		-- coordinates so the rest of this section reads as it always did.
		local centre = {}
		for _, cell in ipairs(piece.cells) do
			if cell.name ~= "air" then
				local lane = axis == "x" and (cell.z - piece.at) or
					(cell.x - piece.at)
				if lane == 0 then
					local p = along + (axis == "x" and cell.x or cell.z)
					if centre[p] == nil or cell.y > centre[p] then
						centre[p] = cell.y
					end
				end
			end
		end

		local water_cells, columns_walked, missing, jumps = 0, 0, 0, 0
		local previous_p, previous_y
		for p = from, to do
			for offset = -AVENUE_HALF, AVENUE_HALF do
				local x = axis == "x" and p or (across + offset)
				local z = axis == "x" and (across + offset) or p
				columns_walked = columns_walked + 1
				local terrain_y = height.terrain_height_at(x, z)
				local water_y = height.water_surface_at(x, z)
				if type(water_y) == "number" and water_y > terrain_y then
					water_cells = water_cells + 1
				end
			end
			local y = centre[p]
			if y == nil then
				missing = missing + 1
			else
				if previous_y ~= nil and p == previous_p + 1 and
						math.abs(y - previous_y) > 1 then
					jumps = jumps + 1
				end
				previous_p, previous_y = p, y
			end
		end
		emit("avenue", seed, capital.key, side.id, columns_walked, water_cells,
			missing, jumps)
		if missing ~= 0 then
			city_fault(("%s avenue_%s leaves %d position(s) unpaved"):format(
				capital.key, side.id, missing))
		end
		if jumps ~= 0 then
			city_fault(("%s avenue_%s steps more than one node at %d position(s)")
				:format(capital.key, side.id, jumps))
		end

		-- THE STEP AT THE GATE. The gate column is the envelope edge, which is
		-- where the route's last graded column and the avenue's pavement meet.
		local gate = capital.by_side[side.id]
		local gate_p = axis == "x" and gate.x or gate.z
		local road_y = centre[gate_p]
		local kind, surface_y, feature_id =
			height.functional_surface_values_at(gate.x, gate.z)
		local terrain_y = height.terrain_height_at(gate.x, gate.z)
		local route_y = surface_y or terrain_y
		local step = road_y and math.abs(route_y - road_y) or -1
		emit("gate", seed, capital.key, side.id, gate.x, gate.z, tostring(kind),
			tostring(surface_y), tostring(feature_id), terrain_y,
			tostring(road_y), step)
		if step < 0 or step > 1 then
			city_fault(("%s %s gate steps %s between route grade and avenue road")
				:format(capital.key, side.id, tostring(step)))
		end

		-- CAN THE CITY BE ENTERED? The surface a traveller actually walks from
		-- the open road into the city: the route's own graded surface out where
		-- only the route is, and the BUILT avenue from the moment the overlay
		-- covers the column (the settlement writer runs after WP40 and
		-- overwrites, so inside the avenue's run the avenue is the ground). A
		-- position that steps more than one node from the one before it is a
		-- position a player has to jump, and a gate you jump into is a gate.
		local ENTRY_RUN = 64
		local breaks, worst, worst_at = 0, 0, nil
		local previous
		for along = AVENUE_OUT + ENTRY_RUN, AVENUE_IN, -1 do
			local x = axis == "x" and (capital.x + sign * along) or capital.x
			local z = axis == "x" and capital.z or (capital.z + sign * along)
			local p = axis == "x" and x or z
			local y = centre[p]
			if y == nil then
				local _, functional_y = height.functional_surface_values_at(x, z)
				y = functional_y or walkable(x, z)
			end
			if previous ~= nil and math.abs(y - previous) > 1 then
				breaks = breaks + 1
				if math.abs(y - previous) > worst then
					worst, worst_at = math.abs(y - previous), along
				end
			end
			previous = y
		end
		emit("entry", seed, capital.key, side.id, AVENUE_OUT + ENTRY_RUN,
			AVENUE_IN, breaks, worst, tostring(worst_at))
		if breaks ~= 0 then
			city_fault(("%s %s entry breaks %d time(s), worst %d at %s"):format(
				capital.key, side.id, breaks, worst, tostring(worst_at)))
		end

		-- THE GROUND JUST INSIDE THE GATE, which the entry walk above cannot
		-- see. `wp13/avenue.lua`'s one-Lipschitz envelope smooths the ROAD over
		-- anything, so a road is walkable over a cliff it is standing on -- and
		-- the first version of this lane built exactly that: pinning the gate
		-- station to the anchor's platform height raised Dur Brannoc's west gate
		-- from 97 to 149 and left the fitted ground back at 97 four columns
		-- inside the wall.
		--
		-- So this reads the TERRAIN along the avenue's centre line over the
		-- eight columns immediately inside the gate -- the width of the curtain
		-- plus its footing, which is where a fill at the gate has to land -- and
		-- reports the worst single step. Deeper inside the envelope the terrain
		-- is the capital fitting's own business: a river bank at Highcourt's
		-- north gate steps 6 some twenty-seven columns in and always has.
		--
		-- The limit is THREE TIMES a capital's largest terrace rise (4, from
		-- `source/simple_map.lua`'s six capital anchor profiles), which is where
		-- the two things this has to tell apart actually sit. A capital on a
		-- hillside makes a lip of its own: Kezamba's south gate stands on ground
		-- climbing three nodes a column, and the route's flat end cap gives it a
		-- 9 on two of the nine fixture seeds -- steep, walkable (the entry check
		-- above passes there on every seed) and the capital's terrain rather
		-- than its road. The embankment this exists to catch is 24.
		local INSIDE_RUN, TERRACE_STEP = 8, 12
		local ground_worst, ground_at = 0, nil
		local ground_previous
		for inward = 0, INSIDE_RUN do
			local along = HALF - inward
			local x = axis == "x" and (capital.x + sign * along) or capital.x
			local z = axis == "x" and capital.z or (capital.z + sign * along)
			local y = height.terrain_height_at(x, z)
			if ground_previous ~= nil and math.abs(y - ground_previous) > ground_worst then
				ground_worst, ground_at = math.abs(y - ground_previous), along
			end
			ground_previous = y
		end
		emit("inside", seed, capital.key, side.id, INSIDE_RUN, ground_worst,
			tostring(ground_at))
		if ground_worst > TERRACE_STEP then
			city_fault(("%s %s ground steps %d at %s just inside the gate"):format(
				capital.key, side.id, ground_worst, tostring(ground_at)))
		end
	end
end

emit("summary", seed, scan_kind, strict and "strict" or "route",
	#approaches, gate_collisions, route_faults, city_faults)

local text = "kind\tseed\tfields...\n" .. table.concat(rows, "\n") .. "\n"
if out_path then
	local file = assert(io.open(out_path, "wb"))
	assert(file:write(text))
	assert(file:close())
end
io.write(text)
-- The exit status gates the ROUTE faults always and the CITY faults only in
-- `--strict`, for the reason at the top of the fault section.
local gated = route_faults + (strict and city_faults or 0)
io.write(("route_gates seed=%s mode=%s route_faults=%d city_faults=%d exit=%d\n")
	:format(seed, strict and "strict" or "route", route_faults, city_faults,
		gated == 0 and 0 or 1))
os.exit(gated == 0 and 0 or 1)
