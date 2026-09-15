-- Do WP40's routes stop at a capital's gates, and can the city still be
-- entered through them?
--
--     luajit tools/wp13/route_gates.lua <repo> <seed> [out.tsv] [--full]
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
-- So this tool answers five questions per capital and seed, offline, out of
-- the same pure WP40 height session `tools/wp13/lane_routes.lua` and
-- `tools/wp13/capital_anchor_fixture.lua` build (no engine, no world):
--
--   1. GATE DISTANCE. Where does each of the four incoming routes actually
--      end, and how far is that from the gate it should end at? Target 0.
--   2. STRAIGHT APPROACH. Is the final stretch axial -- the road normal to the
--      wall it passes through -- and how long is it?
--   3. INTERIOR CELLS. How many columns strictly inside the envelope
--      (both anchor offsets under 256 in absolute value) does a route grade,
--      and how many does a bridge deck span? A deck inside the envelope is the
--      wave-1 lane-crossing case, which the ruling turns from a feature into
--      a safeguard.
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
--
-- THE SCAN. A route can only grade columns within its corridor of the
-- centreline, so the interior count walks a band around every route and spur
-- polyline rather than all 263169 columns of an envelope. `--full` scans the
-- whole envelope instead and is how that shortcut is checked; the two agree.
--
-- Exit status is 1 if any target above is missed, so this is a gate and not
-- only a report.
--
-- Plain Lua 5.1 (LuaJIT in practice for the eight-second WP40 construction).

local repo = assert(arg[1], "repository root required")
local seed = assert(arg[2], "world seed required")
local full, out_path = false, nil
for index = 3, #arg do
	if arg[index] == "--full" then full = true else out_path = arg[index] end
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
			approaches[#approaches + 1] = {route = route, capital = capital,
				which = which, gate = capital.by_side[side],
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

local faults = 0
local function fault(message)
	faults = faults + 1
	emit("FAULT", seed, message)
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
	local by_feature = {}
	for _, column in ipairs(columns) do
		local kind, _, feature_id = height.functional_surface_values_at(column.x,
			column.z)
		local family = feature_id and feature_is_path[feature_id]
		if family == "route" then
			interior_route = interior_route + 1
			by_feature[feature_id] = (by_feature[feature_id] or 0) + 1
		elseif family == "spur" then
			interior_spur = interior_spur + 1
			by_feature[feature_id] = (by_feature[feature_id] or 0) + 1
		end
		if kind == "bridge_deck" then interior_deck = interior_deck + 1 end
	end
	local feature_ids = {}
	for id in pairs(by_feature) do feature_ids[#feature_ids + 1] = id end
	table.sort(feature_ids)
	for _, id in ipairs(feature_ids) do
		emit("interior_feature", seed, capital.key, id, by_feature[id])
	end
	emit("interior", seed, capital.key, scan_kind, #columns, interior_route,
		interior_spur, interior_deck)
	if interior_route ~= 0 then
		fault(("%s grades %d route column(s) inside its envelope"):format(
			capital.key, interior_route))
	end
	if interior_deck ~= 0 then
		fault(("%s carries %d bridge-deck column(s) inside its envelope"):format(
			capital.key, interior_deck))
	end

	-- 4 and 5: the four avenues, built. The contract avenue is the anchor's own
	-- centre line, half-width 2, running from the core edge at 48 out to 261 --
	-- five nodes past the envelope edge, because the curtain's gate tunnel runs
	-- through the whole seven-node thickness (`wp13/highcourt.lua`). Highcourt
	-- and Dur Brannoc author exactly that; the four wave-2 capitals are being
	-- built to the same standard, so the run is taken from the contract rather
	-- than from six blueprints, four of which do not exist yet.
	local palette = palettes.new(capital.zone.race_region)
	for _, side in ipairs(SIDES) do
		local axis = side.dx ~= 0 and "x" or "z"
		local sign = side.dx ~= 0 and side.dx or side.dz
		local along = axis == "x" and capital.x or capital.z
		local across = axis == "x" and capital.z or capital.x
		local from = along + (sign < 0 and -AVENUE_OUT or AVENUE_IN)
		local to = along + (sign < 0 and -AVENUE_IN or AVENUE_OUT)
		local piece = avenue.run(palette, {id = "avenue_" .. side.id, axis = axis,
			at = across, from = from, to = to, lamp_phase = from,
			overhead = deck}, walkable)

		-- The built road, read back off its own cells: the top cell of the
		-- CENTRE lane at every position along the run.
		local centre, low = {}, {}
		for _, cell in ipairs(piece.cells) do
			local lane = axis == "x" and (cell.z - piece.at) or (cell.x - piece.at)
			if lane == 0 then
				local p = axis == "x" and cell.x or cell.z
				if centre[p] == nil or cell.y > centre[p] then centre[p] = cell.y end
				if low[p] == nil or cell.y < low[p] then low[p] = cell.y end
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
			fault(("%s avenue_%s leaves %d position(s) unpaved"):format(
				capital.key, side.id, missing))
		end
		if jumps ~= 0 then
			fault(("%s avenue_%s steps more than one node at %d position(s)")
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
			fault(("%s %s gate steps %s between route grade and avenue road")
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
			fault(("%s %s entry breaks %d time(s), worst %d at %s"):format(
				capital.key, side.id, breaks, worst, tostring(worst_at)))
		end
	end
end

emit("summary", seed, scan_kind, #approaches, gate_collisions, faults)

local text = "kind\tseed\tfields...\n" .. table.concat(rows, "\n") .. "\n"
if out_path then
	local file = assert(io.open(out_path, "wb"))
	assert(file:write(text))
	assert(file:close())
end
io.write(text)
os.exit(faults == 0 and 0 or 1)
