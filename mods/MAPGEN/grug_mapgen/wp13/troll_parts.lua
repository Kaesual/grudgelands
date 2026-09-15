-- The troll capital's own parts: what Kezamba has that no other capital does.
--
-- Same contract as `capitals.lua` and `buildings.lua`: a generator takes a
-- palette handle and a spec and returns a PART -- `{buffer, w, d, peak,
-- points}` in its own local frame, x running 0..w-1, z running 0..d-1, y = 0
-- the ground node and y = 1 the first walkable course -- which `parts.stamp`
-- places at any of the four rotations.
--
-- WHY THESE ARE HERE AND NOT IN `capitals.lua`. The shared library is not this
-- lane's to edit (the wave-2 lane rules), and none of these five is a shape a
-- second capital would want: a stilt hall is a building whose ground floor is
-- open water, a cauldron court is the troll answer to a market cross, a totem
-- gate is what an OPEN capital puts where a walled one puts a gatehouse, a
-- carver's yard is a workshop with its product standing in front of it, and a
-- fish landing is a quay. `wp13/troll_palette.lua` carries the role bindings
-- they read that the shared troll palette does not have.
--
-- Contract (docs/research/wp13-capitals-pois-contract.md section 2.4, the troll
-- row, quoted): "stilted cenote terrace, step 3 | stilt halls on basalt
-- platforms, junglewood walkways, totem posts, cauldron courts, emergent trees
-- kept". Section 4's wall ruling: Kezamba is one of the two OPEN capitals, so
-- there is no curtain and the four gate points carry a threshold instead.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local interiors = dofile(directory .. "/interiors.lua")
	local roofs = dofile(directory .. "/roofs.lua")

	local M = {}

	-- ------------------------------------------------------------------
	-- the vocabulary, each role with its fallback into the start palette
	-- ------------------------------------------------------------------

	local function signature(palette)
		return palette.maybe("signature") or palette.node("foundation")
	end
	local function signature_slab(palette)
		return palette.maybe("signature_slab") or palette.node("roof_slab")
	end
	local function signature_stair(palette)
		return palette.maybe("signature_stair") or palette.node("roof_stair")
	end
	local function paving(palette)
		return palette.maybe("castle_paving") or palette.node("plaza")
	end
	local function spoil(palette)
		return palette.maybe("castle_rubble") or palette.node("rubble")
	end

	-- ------------------------------------------------------------------
	-- sockets, the same shape `capitals.lua` publishes
	-- ------------------------------------------------------------------

	-- `work` is in this list and not in `capitals.lua`'s, and that is the one
	-- deliberate difference: the sockets contract's section 8.1 role landed
	-- after the shared library froze, and a troll part whose whole point is
	-- somebody stirring a cauldron has to be able to say so.
	local SOCKET_ROLES = {guard_post = true, guard_patrol = true,
		vendor = true, idle = true, quest = true, king = true,
		waypoint = true, work = true}

	local function socket(list, id, role, x, y, z, face, extra)
		local entry = {id = id, role = role, x = x, y = y, z = z,
			face = face % 4}
		for key, value in pairs(extra or {}) do entry[key] = value end
		list[#list + 1] = entry
		return entry
	end

	local function top_of(buf)
		local order, count = buf:cells()
		local peak = 0
		for index = 1, count do
			local cell = order[index]
			if cell.name ~= parts.AIR and cell.y > peak then peak = cell.y end
		end
		return peak
	end

	-- Close a part: every socket's feet and head cell free and its floor not
	-- air, exactly as `capitals.finish` does it, because a socket that cannot
	-- be stood in is cheapest to refuse while the cells are still in hand.
	local function finish(buf, w, d, peak, points, extra)
		local seen = {}
		for _, entry in ipairs(points.sockets or {}) do
			if not SOCKET_ROLES[entry.role] then
				error("wp13 troll parts: socket " .. tostring(entry.id) ..
					" has the unknown role " .. tostring(entry.role), 0)
			end
			if entry.role == "work" and type(entry.activity) ~= "string" then
				error("wp13 troll parts: the work socket " ..
					tostring(entry.id) .. " names no activity", 0)
			end
			if seen[entry.id] then
				error("wp13 troll parts: duplicate socket id " ..
					tostring(entry.id), 0)
			end
			seen[entry.id] = true
			for _, level in ipairs({entry.y, entry.y + 1}) do
				local cell = buf:at(entry.x, level, entry.z)
				if cell ~= nil and cell.name ~= parts.AIR then
					error("wp13 troll parts: socket " .. entry.id .. " at " ..
						entry.x .. "," .. entry.y .. "," .. entry.z ..
						" is blocked by " .. cell.name .. " at y " .. level, 0)
				end
			end
			local below = buf:at(entry.x, entry.y - 1, entry.z)
			if below == nil or below.name == parts.AIR then
				error("wp13 troll parts: socket " .. entry.id .. " at " ..
					entry.x .. "," .. entry.y .. "," .. entry.z ..
					" stands on air", 0)
			end
		end
		local part = {buffer = buf, w = w, d = d, peak = peak, points = points}
		for key, value in pairs(extra or {}) do
			if part[key] ~= nil then
				error("wp13 troll parts: the population " .. tostring(key) ..
					" collides with a part field", 0)
			end
			part[key] = value
		end
		return part
	end

	local function patrol(list, id, group, order, x, y, z, face)
		return socket(list, id, "guard_patrol", x, y, z, face,
			{group = group, order = order})
	end

	-- Every node name any generator in this file may emit, byte-sorted. The
	-- overlay's specification identity and the settlement's content channel are
	-- both closed over it, so a name that can be written and is not listed only
	-- fails on the mapchunk that finally needs it.
	function M.palette_names(palette)
		local names = {parts.AIR, signature(palette), signature_slab(palette),
			signature_stair(palette), paving(palette), spoil(palette),
			palette.node("path"), palette.node("post"), palette.node("beam"),
			palette.node("plaza_edge"), palette.node("railing"),
			palette.node("roof_slab"), palette.node("light_post"),
			palette.node("foundation"), palette.node("wall_accent")}
		local seen, list = {}, {}
		for index = 1, #names do
			local name = names[index]
			if type(name) ~= "string" or name == "" then
				error("wp13 troll parts: the palette has no name for a role", 0)
			end
			if not seen[name] then
				seen[name] = true
				list[#list + 1] = name
			end
		end
		table.sort(list, parts.less_bytes)
		return list
	end

	-- ------------------------------------------------------------------
	-- 1. the stilt hall
	-- ------------------------------------------------------------------

	-- A junglewood hall on a basalt-pier platform standing over the water, with
	-- a flight up to it from the bank on its z- side and a walkway running on
	-- off its z+ side.
	--
	-- The platform is the part's OWN ground: `deck` courses of open air under a
	-- plank floor carried on piers, so the whole building stands clear of
	-- whatever is beneath it -- which at Kezamba is the cenote. The hall above
	-- it is a gabled shell with an open verandah all round, and the verandah is
	-- what makes the silhouette read as stilts rather than as a box on a
	-- plinth: the eye sees floor, air, water.
	--
	-- THE PLAN IS THREE BANDS IN z, AND THE ORDER IS THE POINT.
	--
	--     z 0 .. deck-1              the FLIGHT, which stands on the bank
	--     z deck .. deck+d-1         the PLATFORM, which stands in the water
	--     z deck+d .. deck+d+spur-1  the WALKWAY spur, over the water
	--
	-- A stilt hall is only a stilt hall if its deck is four courses over what
	-- is under it, and a deck four courses up is only a building if something
	-- climbs to it. The first version of this generator had the platform and
	-- the spur and no flight at all: the hall was reachable only by the
	-- six-node walkway that ends in open water. The flight is therefore part of
	-- the PART and not of the composition, and the composition's job is only to
	-- put the first `deck` rows on dry ground -- which is a claim it checks
	-- against the committed lake mask before it stamps anything.
	--
	-- Extent: w x (deck + d + spur), y -2 .. (deck + wall_h + roof).
	function M.stilt_hall(palette, spec)
		local w = spec.w or 15
		local d = spec.d or 15
		local deck = spec.deck or 4
		local wall_h = spec.wall_h or 5
		local spur = spec.spur or 6
		if w < 9 or d < 9 then
			error("wp13 troll parts: the stilt hall is too small", 0)
		end
		if w % 2 == 0 or d % 2 == 0 then
			error("wp13 troll parts: the stilt hall needs an odd plan", 0)
		end
		local buf = parts.buffer()
		local lights, sockets, doors, inside, room = {}, {}, {}, {}, {}
		local last_x = w - 1
		local mid_x = math.floor(last_x / 2)
		local base = deck                     -- the platform's own z origin
		local last_z = base + d - 1
		local depth = deck + d + spur
		local PIER = signature(palette)
		local POST = palette.node("post")
		local DECK = palette.node("path")
		local RAIL = palette.node("railing")
		local WALL = palette.node("wall")

		-- The whole footprint is cleared to the ridge: this part stands over
		-- water and nothing of the world may be left inside it.
		buf:clear(0, 1, 0, last_x, deck + wall_h + 6, depth - 1)

		-- 1. THE FLIGHT, on the bank. `deck` treads three wide climbing from the
		-- ground course to the platform, each carried on its own timber.
		local face = parts.step_facedir(0, 1)
		for step = 0, deck - 1 do
			for x = mid_x - 1, mid_x + 1 do
				parts.stair(buf, x, step + 1, step, palette.node("roof_stair"),
					face)
				for y = 1, step do buf:put(x, y, step, POST) end
			end
			buf:clear(mid_x - 1, step + 2, step, mid_x + 1, step + 4, step)
		end

		-- 2. The piers, on a four-node grid and at every corner, each a basalt
		-- footing under a timber leg. Piers reach DOWN to y = -2, which is the
		-- contract's floor for a capital core, and no further: the cenote's bed
		-- lies ten or more nodes below its surface and a leg that tried to
		-- reach it would leave the authorized volume. What the player sees is a
		-- leg going into the water, which is what a stilt is.
		local piers = 0
		local function pier(x, z)
			for y = -2, 0 do buf:put(x, y, z, PIER) end
			for y = 1, deck - 1 do buf:put(x, y, z, POST) end
			piers = piers + 1
		end
		for z = base, last_z, 4 do
			for x = 0, last_x, 4 do pier(x, z) end
		end
		for _, corner in ipairs({{last_x, base}, {0, last_z},
				{last_x, last_z}}) do
			if buf:at(corner[1], 0, corner[2]) == nil then
				pier(corner[1], corner[2])
			end
		end

		-- 3. The deck.
		buf:fill(0, deck, base, last_x, deck, last_z, DECK)

		-- 4. The hall itself, inset two nodes all round, so the deck is a
		-- verandah the whole way round the building.
		local hx0, hz0, hx1, hz1 = 2, base + 2, last_x - 2, last_z - 2
		local floor_y = deck
		local wall_top = floor_y + wall_h
		buf:ring(hx0, hz0, hx1, hz1, floor_y + 1, wall_top, WALL)
		for _, corner in ipairs({{hx0, hz0}, {hx1, hz0}, {hx0, hz1},
				{hx1, hz1}}) do
			for y = floor_y + 1, wall_top do
				buf:put(corner[1], y, corner[2], POST)
			end
		end
		-- The roof: a gable over the hall's own plan and one node of eave,
		-- rastered exactly as `buildings.build` does it.
		roofs.raster(buf, palette, roofs.field("gable", {x0 = hx0 - 1,
			x1 = hx1 + 1, z0 = hz0 - 1, z1 = hz1 + 1, base = wall_top + 1,
			axis = "x", rise = 4}))

		-- 5. The great door in the z- gable, facing the flight, and the window
		-- bars round the rest of the shell.
		parts.double_door(buf, palette, mid_x, floor_y + 1, hz0, 2)
		doors[#doors + 1] = {x = mid_x, y = floor_y + 1, z = hz0, face = 2}
		for _, x in ipairs({hx0 + 2, hx1 - 2}) do
			for _, z in ipairs({hz0, hz1}) do
				parts.pane(buf, palette, x, floor_y + 2, z, "x")
			end
		end
		for _, z in ipairs({hz0 + 2, hz1 - 2}) do
			for _, x in ipairs({hx0, hx1}) do
				parts.pane(buf, palette, x, floor_y + 2, z, "z")
			end
		end

		-- 6. The interior: the hall kit. The room rectangle is the one
		-- `buildings.build` hands a kit -- one node inside the wall ring, `y`
		-- the floor and `h` the wall head.
		local room_box = {x1 = hx0 + 1, z1 = hz0 + 1, x2 = hx1 - 1,
			z2 = hz1 - 1, y = floor_y, h = wall_top}
		for _, light in ipairs(interiors.furnish("hall", buf, parts, palette,
				room_box, {}) or {}) do
			lights[#lights + 1] = light
		end
		room[#room + 1] = {x = hx0 + 1, y = floor_y, z = hz0 + 1,
			top = wall_top, closed = true}
		room[#room + 1] = {x = hx1 - 1, y = floor_y, z = hz1 - 1,
			top = wall_top, closed = true}
		inside[#inside + 1] = {x = mid_x, y = floor_y + 1, z = hz0 + 2}

		-- 7. The verandah rail, opened where the flight lands and where the
		-- walkway leaves.
		local mouth = {}
		for offset = -1, 1 do
			mouth[(mid_x + offset) .. ":" .. last_z] = true
			mouth[(mid_x + offset) .. ":" .. base] = true
		end
		for z = base, last_z do
			for x = 0, last_x do
				if (x == 0 or x == last_x or z == base or z == last_z) and
						not mouth[x .. ":" .. z] then
					buf:put(x, deck + 1, z, RAIL)
				end
			end
		end

		-- 8. The walkway off the z+ face, and the ropes and lanterns under the
		-- deck that are the whole reason the troll palette binds them.
		dressing.walkway(buf, palette, mid_x, last_z + 1, spur, "z", deck)
		local lanterns = 0
		for _, spot in ipairs({{3, base + 3}, {last_x - 3, last_z - 3},
				{3, last_z - 3}, {last_x - 3, base + 3}}) do
			if dressing.lantern(buf, palette, spot[1], deck - 1, spot[2]) then
				lanterns = lanterns + 1
				lights[#lights + 1] = {x = spot[1], y = deck - 1, z = spot[2]}
			end
		end
		local ropes = 0
		for _, spot in ipairs({{1, base + 1}, {last_x - 1, base + 1},
				{1, last_z - 1}, {last_x - 1, last_z - 1}}) do
			ropes = ropes + dressing.rope_fall(buf, palette, spot[1],
				deck - 1, spot[2], 3)
		end
		parts.floor_torch(buf, palette, 1, deck + 1, base + mid_x)
		lights[#lights + 1] = {x = 1, y = deck + 1, z = base + mid_x}

		local id = spec.id or "stilt_hall"
		if spec.patrol_group then
			patrol(sockets, id .. "_deck_a", spec.patrol_group,
				spec.order or 1, 1, deck + 1, base + 1, 1)
			patrol(sockets, id .. "_deck_b", spec.patrol_group,
				(spec.order or 1) + 1, last_x - 1, deck + 1, last_z - 1, 3)
		end
		socket(sockets, id .. "_porch", "idle", mid_x, deck + 1, hz0 - 1, 2,
			{tags = {"door"}})
		-- The verandah spot, on the deck's own z- corner. It is NOT at the foot
		-- of the flight: the flight's lowest tread stands on the WORLD's ground
		-- and this part writes no ground course there, so a socket at the
		-- landing would be one `finish` cannot prove anybody can stand on.
		socket(sockets, id .. "_verandah", "idle", 1, deck + 1, base + 2, 1,
			{tags = {"work"}})

		return finish(buf, w, depth, top_of(buf), {
			doors = doors,
			lights = lights,
			sockets = sockets,
			inside = inside,
			room_corner = room,
		}, {piers = piers, lanterns = lanterns, ropes = ropes,
			land_rows = deck})
	end

	-- ------------------------------------------------------------------
	-- 2. the cauldron court
	-- ------------------------------------------------------------------

	-- The troll answer to a market cross: a paved square with a raised basalt
	-- hearth ring in the middle, four cauldrons standing on it over their own
	-- fire, drying racks on two sides and benches on the others.
	--
	-- Every cauldron is a `brew` workplace and the socket stands on the paving
	-- LOOKING AT IT, which is the feature rule of sockets contract section 8.2's
	-- wave-2 table ("a cauldron, barrel or a cooking pot node").
	--
	-- Extent: size x size, y 0..4.
	function M.cauldron_court(palette, spec)
		local size = spec.size or 15
		if size < 11 or size % 2 == 0 then
			error("wp13 troll parts: the cauldron court needs an odd plan " ..
				"of eleven or more", 0)
		end
		local buf = parts.buffer()
		local lights, sockets = {}, {}
		local last = size - 1
		local mid = math.floor(last / 2)
		local PAVE = paving(palette)
		local MARK = signature(palette)

		buf:clear(0, 1, 0, last, 6, last)
		buf:fill(0, 0, 0, last, 0, last, PAVE)
		-- The kerb, and a signature band one node in from it.
		for z = 0, last do
			for x = 0, last do
				if x == 0 or x == last or z == 0 or z == last then
					buf:put(x, 0, z, palette.node("plaza_edge"))
				elseif x == 2 or x == last - 2 or z == 2 or z == last - 2 then
					buf:put(x, 0, z, MARK)
				end
			end
		end

		-- The hearth ring: a five-by-five basalt platform one course up, with
		-- the four cauldrons on its corners and a fire in the middle.
		local ring = 2
		for z = mid - ring, mid + ring do
			for x = mid - ring, mid + ring do
				buf:put(x, 1, z, MARK)
			end
		end
		-- THE CAULDRONS STAND ON THE PLATFORM'S CORNERS, not beside its fire,
		-- and the reason is the sockets contract's own search rule. Section 8.1
		-- stops the feature search at the first solid node on the socket's own
		-- course, so a pot in the middle of a five-wide masonry platform is a
		-- pot behind a wall: the platform's own edge blocks the look. On the
		-- corners each pot is the first thing its own worker sees.
		local cauldrons = 0
		local CAULDRON = palette.node("hearth")
		local spots = {{mid - ring, mid - ring}, {mid + ring, mid - ring},
			{mid - ring, mid + ring}, {mid + ring, mid + ring}}
		for _, spot in ipairs(spots) do
			buf:put(spot[1], 2, spot[2], CAULDRON)
			cauldrons = cauldrons + 1
		end
		parts.floor_torch(buf, palette, mid, 2, mid)
		lights[#lights + 1] = {x = mid, y = 2, z = mid}

		-- Racks on the x- and x+ edges, benches on the z edges.
		dressing.drying_rack(buf, palette, 2, 3, size - 6, "z")
		dressing.drying_rack(buf, palette, last - 2, 3, size - 6, "z")
		dressing.bench(buf, palette, mid - 1, 2, 0, 3, "x")
		dressing.bench(buf, palette, mid - 1, last - 2, 2, 3, "x")
		for _, lamp in ipairs({{1, 1}, {last - 1, 1}, {1, last - 1},
				{last - 1, last - 1}}) do
			dressing.path_light(buf, palette, lamp[1], lamp[2], lights)
		end

		-- Four `brew` workplaces, one per cauldron, each standing on the paving
		-- OUTSIDE the hearth ring and facing its own pot within three nodes.
		local id = spec.id or "cauldron"
		local stands = {
			{x = mid - ring - 2, z = mid - ring, face = 1},
			{x = mid + ring + 2, z = mid - ring, face = 3},
			{x = mid - ring - 2, z = mid + ring, face = 1},
			{x = mid + ring + 2, z = mid + ring, face = 3},
		}
		for index = 1, #stands do
			local stand = stands[index]
			socket(sockets, id .. "_brew_" .. index, "work", stand.x, 1,
				stand.z, stand.face, {activity = "brew", tags = {"fire"}})
		end
		-- Two `sit` spots on the benches -- a seat is a walkable node and the
		-- resident sits ON it, which is why `y` is 2 and not 1.
		socket(sockets, id .. "_sit_south", "work", mid, 2, 2, 0,
			{activity = "sit", tags = {"bench"}})
		socket(sockets, id .. "_sit_north", "work", mid, 2, last - 2, 2,
			{activity = "sit", tags = {"bench"}})
		if spec.patrol_group then
			patrol(sockets, id .. "_watch_a", spec.patrol_group,
				spec.order or 1, 1, 1, mid, 3)
			patrol(sockets, id .. "_watch_b", spec.patrol_group,
				(spec.order or 1) + 1, last - 1, 1, mid, 1)
		end

		return finish(buf, size, size, top_of(buf), {
			doors = {},
			lights = lights,
			sockets = sockets,
			inside = {{x = mid, y = 1, z = 1}},
			room_corner = {},
		}, {cauldrons = cauldrons})
	end

	-- ------------------------------------------------------------------
	-- 3. the fish landing
	-- ------------------------------------------------------------------

	-- The quay at the cenote's edge: a basalt apron, a plank jetty running out
	-- over the water, drying racks and a fishmonger's counter.
	--
	-- THE JETTY IS WHAT THE `fish` SOCKETS STAND ON. The sockets contract's
	-- section 8.1 wants "a water node" under `dir` within three nodes of a
	-- `fish` socket and reads BLUEPRINT cells for it, which at Kezamba would be
	-- the wrong question: the water is WP40's cenote and not this composition's.
	-- `tools/wp13/kezamba_kat.lua` therefore answers it against the committed
	-- lagoon mask of `wp13/kezamba_lagoon.lua` instead, which is the same claim
	-- about the same columns and is measured on nine seeds. The part's job is
	-- to put the anglers on the jetty's flanks looking outward, and the
	-- composition's is to stand the jetty over water.
	--
	-- Extent: w x (d + reach), y 0..5. `reach` is how far the jetty runs out.
	function M.fish_landing(palette, spec)
		local w = spec.w or 13
		local d = spec.d or 7
		local reach = spec.reach or 8
		if w < 9 or w % 2 == 0 then
			error("wp13 troll parts: the fish landing needs an odd apron", 0)
		end
		local buf = parts.buffer()
		local lights, sockets = {}, {}
		local last_x = w - 1
		local mid = math.floor(last_x / 2)
		local APRON = signature(palette)
		local DECK = palette.node("path")
		local POST = palette.node("post")

		buf:clear(0, 1, 0, last_x, 6, d - 1 + reach)
		buf:fill(0, 0, 0, last_x, 0, d - 1, APRON)
		for x = 0, last_x do buf:put(x, 0, 0, palette.node("plaza_edge")) end

		-- The jetty: three wide, running out from the middle of the apron, on
		-- log piers every third cell. Its deck is the apron's own course, so a
		-- walker steps straight off the quay onto it.
		local jetty_from = d
		for step = 0, reach - 1 do
			local z = jetty_from + step
			for side = -1, 1 do
				buf:put(mid + side, 0, z, DECK)
			end
			if step % 3 == 0 then
				for y = -2, -1 do
					buf:put(mid, y, z, POST)
					buf:put(mid - 1, y, z, POST)
					buf:put(mid + 1, y, z, POST)
				end
			end
		end
		-- A rail on the last three cells only, so the flanks stay open for the
		-- rods.
		for step = reach - 3, reach - 1 do
			local z = jetty_from + step
			buf:put(mid - 1, 1, z, palette.node("railing"))
			buf:put(mid + 1, 1, z, palette.node("railing"))
		end
		buf:put(mid, 1, jetty_from + reach - 1, palette.node("railing"))

		-- The counter on the apron, the racks either side of it, a crate stack
		-- and two lamps.
		dressing.counter(buf, palette, 2, 2, w - 4, "x")
		-- The racks stand on the apron's own flanks and stop one node short of
		-- its far edge: a rack that overran it would hang its rope over the
		-- jetty mouth, which is where the walk to the anglers goes.
		dressing.drying_rack(buf, palette, 1, 3, 3, "z")
		dressing.drying_rack(buf, palette, last_x - 1, 3, 3, "z")
		dressing.crates(buf, palette, 4, d - 2, 0)
		dressing.path_light(buf, palette, 2, 1, lights)
		dressing.path_light(buf, palette, last_x - 2, 1, lights)

		local id = spec.id or "landing"
		-- The fishmonger behind his counter, and his stall work spot beside
		-- him: `stall` is "a counter (any solid node at waist height)" and the
		-- counter is exactly that.
		socket(sockets, id .. "_vendor_fishmonger", "vendor", mid, 1, 1, 0,
			{kind = "fishmonger"})
		socket(sockets, id .. "_stall", "work", mid + 2, 1, 1, 0,
			{activity = "stall"})
		-- Three anglers on the jetty: two on the flanks looking over the side
		-- and one at the head looking out.
		local anglers = {
			{x = mid, z = jetty_from + 1, face = 3},
			{x = mid, z = jetty_from + 3, face = 1},
			{x = mid, z = jetty_from + reach - 2, face = 0},
		}
		for index = 1, #anglers do
			local angler = anglers[index]
			socket(sockets, id .. "_fish_" .. index, "work", angler.x, 1,
				angler.z, angler.face, {activity = "fish"})
		end
		socket(sockets, id .. "_idle_quay", "idle", 2, 1, d - 2, 0,
			{tags = {"work"}})
		if spec.patrol_group then
			patrol(sockets, id .. "_watch_a", spec.patrol_group,
				spec.order or 1, 3, 1, d - 1, 0)
			patrol(sockets, id .. "_watch_b", spec.patrol_group,
				(spec.order or 1) + 1, last_x - 3, 1, d - 1, 2)
		end

		return finish(buf, w, d + reach, top_of(buf), {
			doors = {},
			lights = lights,
			sockets = sockets,
			inside = {{x = 2, y = 1, z = d - 2}},
			room_corner = {},
		}, {jetty = reach})
	end

	-- ------------------------------------------------------------------
	-- 4. the carver's yard
	-- ------------------------------------------------------------------

	-- A totem carver's open yard: a litter floor with a log pile, three posts
	-- in three stages of carving standing in a row, and the carver's block.
	-- The finished post is a `dressing.totem`; the two unfinished ones are bare
	-- logs, which is what a yard with work in it looks like.
	--
	-- `carve`'s feature rule (section 8.2 wave-2) is "a log, a totem/statue
	-- part or a stone block", and every one of the three sockets faces a log
	-- one node away.
	--
	-- Extent: size x size, y 0..8.
	function M.carver_yard(palette, spec)
		local size = spec.size or 15
		if size < 11 then
			error("wp13 troll parts: the carver's yard is too small", 0)
		end
		local buf = parts.buffer()
		local lights, sockets = {}, {}
		local last = size - 1
		local mid = math.floor(last / 2)

		buf:clear(0, 1, 0, last, 10, last)
		buf:fill(0, 0, 0, last, 0, last, palette.node("ground"))
		for z = 0, last do
			for x = 0, last do
				if x == 0 or x == last or z == 0 or z == last then
					buf:put(x, 0, z, palette.node("stepping") or
						palette.node("plaza_edge"))
				end
			end
		end
		-- The working strip: paving down the middle so the posts stand on
		-- something and the carvers do not work in the mud.
		for z = mid - 1, mid + 1 do
			for x = 2, last - 2 do
				buf:put(x, 0, z, paving(palette))
			end
		end

		-- Three posts in a row: finished, half done, a bare log.
		local posts = {}
		local heights = {6, 4, 3}
		for index = 1, 3 do
			local x = 3 + (index - 1) * math.floor((size - 7) / 2)
			posts[index] = x
			if index == 1 then
				dressing.totem(buf, palette, x, mid, heights[index])
			else
				for y = 1, heights[index] do
					buf:put(x, y, mid, palette.node("tree_log"))
				end
			end
		end
		dressing.wood_pile(buf, palette, 2, last - 3, 4, "x")
		dressing.wood_pile(buf, palette, last - 5, 2, 4, "x")
		dressing.path_light(buf, palette, 1, 1, lights)
		dressing.path_light(buf, palette, last - 1, 1, lights)

		local id = spec.id or "carver"
		for index = 1, 3 do
			socket(sockets, id .. "_carve_" .. index, "work", posts[index], 1,
				mid - 1, 0, {activity = "carve"})
		end
		socket(sockets, id .. "_chop", "work", 2, 1, last - 4, 0,
			{activity = "chop"})
		socket(sockets, id .. "_idle", "idle", mid, 1, 2, 2, {tags = {"work"}})
		if spec.patrol_group then
			patrol(sockets, id .. "_watch", spec.patrol_group, spec.order or 1,
				1, 1, mid, 3)
		end

		return finish(buf, size, size, top_of(buf), {
			doors = {},
			lights = lights,
			sockets = sockets,
			inside = {{x = mid, y = 1, z = 2}},
			room_corner = {},
		}, {posts = 3})
	end

	-- ------------------------------------------------------------------
	-- 5. the shaman's shrine
	-- ------------------------------------------------------------------

	-- A basalt platform three courses up with a fire bowl on it, four totem
	-- posts at its corners and a flight up its z- face. The `pray` socket
	-- stands OUTSIDE at the foot of the flight looking at the fire, which is
	-- the sockets contract's rule that every socket is outside a room and
	-- section 8.1's `pray` feature ("an altar, a candle").
	--
	-- Extent: size x size, y 0..(3 + post height + 1).
	function M.shaman_shrine(palette, spec)
		local size = spec.size or 13
		if size < 9 or size % 2 == 0 then
			error("wp13 troll parts: the shrine needs an odd plan of nine " ..
				"or more", 0)
		end
		local buf = parts.buffer()
		local lights, sockets = {}, {}
		local last = size - 1
		local mid = math.floor(last / 2)
		local MARK = signature(palette)
		local platform = 3

		buf:clear(0, 1, 0, last, 12, last)
		buf:fill(0, 0, 0, last, 0, last, palette.node("ground"))
		for z = 1, last - 1 do
			for x = 1, last - 1 do
				buf:put(x, 0, z, paving(palette))
			end
		end
		-- The platform, inset three all round, with a rubble core face.
		local px0, pz0, px1, pz1 = 3, 3, last - 3, last - 3
		buf:fill(px0, 1, pz0, px1, platform, pz1, MARK)
		for y = 1, platform - 1 do
			for z = pz0 + 1, pz1 - 1 do
				for x = px0 + 1, px1 - 1 do
					buf:put(x, y, z, spoil(palette))
				end
			end
		end
		-- The fire bowl on it, and four totem posts at its corners.
		buf:put(mid, platform + 1, mid, palette.node("hearth"))
		parts.floor_torch(buf, palette, mid, platform + 2, mid)
		lights[#lights + 1] = {x = mid, y = platform + 2, z = mid}
		local posts = 0
		for _, corner in ipairs({{px0, pz0}, {px1, pz0}, {px0, pz1},
				{px1, pz1}}) do
			for y = platform + 1, platform + 5 do
				buf:put(corner[1], y, corner[2],
					(y % 3 == 0) and palette.node("plaza_edge")
						or palette.node("post"))
			end
			buf:put(corner[1], platform + 6, corner[2],
				signature_slab(palette))
			posts = posts + 1
		end
		-- The flight up the z- face.
		dressing.outer_stair(buf, palette, mid, pz0, platform, "z", 2)
		dressing.path_light(buf, palette, 1, 1, lights)
		dressing.path_light(buf, palette, last - 1, 1, lights)

		local id = spec.id or "shrine"
		socket(sockets, id .. "_pray", "work", mid, 1, pz0 - 2, 0,
			{activity = "pray"})
		socket(sockets, id .. "_quest", "quest", mid + 2, 1, pz0 - 2, 0,
			{tags = {"door"}})
		socket(sockets, id .. "_idle", "idle", 2, 1, mid, 1, {tags = {"fire"}})
		if spec.patrol_group then
			patrol(sockets, id .. "_watch", spec.patrol_group, spec.order or 1,
				last - 1, 1, mid, 3)
		end

		return finish(buf, size, size, top_of(buf), {
			doors = {},
			lights = lights,
			sockets = sockets,
			inside = {{x = 2, y = 1, z = mid}},
			room_corner = {},
		}, {totem_posts = posts})
	end

	return M
end

return loader
