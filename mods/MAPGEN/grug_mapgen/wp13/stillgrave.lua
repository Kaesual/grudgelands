-- Stillgrave Hollow: the undead start settlement, composed from the WP13
-- building library.
--
-- Hearthpine is a craft settlement in a pine clearing and Dawnmere a farming
-- hamlet on open meadow. The Hollow is neither: it is a half-ruined hamlet in
-- a blight basin, where the living dead keep house among what is left. The
-- difference is meant to be legible from the gate -- dead earth and bone
-- litter instead of turf, a paved gravecourt instead of a village green,
-- gravewood boards on black dungeon-stone footings under obsidian-brick
-- roofs, iron bars instead of glass, burial grounds inside the wall, and two
-- of the four homes on the lane standing open to the sky.
--
-- ROAD DIRECTION. Every Elandor start leaves its pad toward +z; the Kragmar
-- starts do not. `kragmar_stillgrave_hollow` carries the `start:south` gate
-- (`wp40/source/catalog.lua`: `station:kragmar_stillgrave_hollow:start_south`
-- at x = -1800, z = 2486, which is the anchor's z minus 64), so this pad's
-- five-wide route, its gate and its watchtower all lie toward -z. Nothing
-- else about the bounds, landmark or destination contract changes; the
-- `main_street` landmark carries the direction, and the acceptance fixtures
-- read the route out of it instead of assuming +z.
--
-- Authored in local coordinates around the undead spawn; the caller fits
-- y = 0 to the fitted start terrain before projecting the cells. The result
-- is the `grug_wp13_stillgrave_blueprint_v1` payload that
-- `wp40/r7_stillgrave_blueprint.lua` returns unchanged.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local palettes = dofile(directory .. "/palette.lua")
	local buildings = dofile(directory .. "/buildings.lua")(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local layout = dofile(directory .. "/layout.lua")(directory)

	local RADIUS = 63
	local SCHEMA = "grug_wp13_stillgrave_blueprint_v1"
	-- The sign of the road: the pad's gate lies at ROAD * RADIUS.
	local ROAD = -1

	-- The gravecourt is the one paved place in the Hollow. The crypt-chapel
	-- closes its far side, the road leaves its near side toward the gate, and
	-- a lane runs off each flank to the works, the burial grounds and the
	-- home lane behind the chapel.
	local COURT = {x1 = -11, z1 = -7, x2 = 11, z2 = 11}
	local LANES = {
		{-2, ROAD * RADIUS, 2, -6},      -- the road, court to gate
		{-36, 30, 32, 32},               -- the home lane
		{-20, -22, -18, 32},             -- west lane
		{18, -22, 20, 32},               -- east lane
		{-18, 0, -11, 2},                -- court to west lane
		{11, 0, 18, 2},                  -- court to east lane
		{21, -2, 22, 0},                 -- bone works doorstep
		{3, -50, 3, -48},                -- watchtower link off the road
		{-26, -16, -21, -14},            -- old burial ground gate
		{21, 16, 25, 18},                -- new burial ground gate
	}

	-- Plot roster. Each row is one placed building: landmark id, generator,
	-- its parameters and the pad anchor of the footprint. Every door in the
	-- Hollow faces the lane in front of it, so no plot needs a rotation.
	local PLOTS = {
		{id = "crypt_chapel", make = "chapel", x = -5, z = 12,
			spec = {w = 11, d = 15, wall_h = 6, rise = 3, door_side = "z-"}},
		{id = "bone_works", make = "workshop", x = 24, z = -6,
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-",
				kit = "carver", wing_kit = "carver_wing"}},
		{id = "keepers_house", make = "cottage", x = -34, z = 34,
			spec = {w = 9, d = 9, wall_h = 5, roof = "gable", ridge_axis = "x",
				door_side = "z-", door_index = 4}},
		{id = "warden_house", make = "cottage", x = -18, z = 34,
			spec = {w = 11, d = 9, wall_h = 5, roof = "hip",
				door_side = "z-", door_index = 5}},
		{id = "hollow_ruin", make = "ruin", x = 2, z = 34,
			spec = {w = 9, d = 9, wall_h = 6, phase = 0}},
		{id = "sunken_ruin", make = "ruin", x = 18, z = 34,
			spec = {w = 11, d = 9, wall_h = 6, phase = 3}},
		{id = "watchtower", make = "watchpost", x = 5, z = -53,
			spec = {door_side = "x-"}},
	}

	-- Destination order is part of the consumer contract and never changes.
	-- The two ruins are absent on purpose: nobody keeps those rooms.
	local DESTINATION_ORDER = {"crypt_chapel", "bone_works", "keepers_house",
		"warden_house", "watchtower_lookout"}

	local DESTINATION_ID = {watchtower = "watchtower_lookout"}

	-- The crypt-chapel is the one building of the Hollow that is not timber:
	-- pale stone-brick walls and a boarded ceiling of the same stone, under
	-- the SAME black obsidian roof the homes carry. The first render tried it
	-- the other way round -- a pale roof over dark walls -- and the roof mass
	-- swallowed the building; a pale wall under the hamlet's own roof reads as
	-- the one thing here that was built to outlast its builders.
	--
	-- The castle kit's own `castle_dungeon_stone` stair family would have been
	-- the obvious roof and is deliberately NOT used anywhere: those are that
	-- mod's registrations, not `stairs:`, and the rasteriser's outer/inner
	-- param2 convention is transcribed from the `stairs` mod. A roof is not
	-- the place to assume two mods agree about facedir.
	local CRYPT_STONE = {
		wall = "default:stonebrick",
		ceiling = "default:stonebrick",
		wall_accent = "default:mossycobble",
	}

	-- Burial grounds: the old one west of the court, the newer one east of
	-- the works. Each sits inside its own low wall with one gate gap.
	local GRAVEYARDS = {
		{-48, -24, -28, -8},
		{28, 10, 48, 26},
	}
	-- Ten runs, two burial grounds: for each, the two long sides, the far
	-- return, and the two stubs of the near one that leave a gate in the
	-- middle. They share their corner cells on purpose.
	local GRAVE_WALLS = {
		{-50, -26, -26, -26}, {-50, -6, -26, -6}, {-50, -26, -50, -6},
		{-26, -26, -26, -18}, {-26, -12, -26, -6},
		{26, 8, 50, 8}, {26, 28, 50, 28}, {50, 8, 50, 28},
		{26, 8, 26, 14}, {26, 22, 26, 28},
	}
	-- The cells those runs write once the four shared corners per ground are
	-- counted once each, and the lamps the two lighting passes stand. Both
	-- are asserted where they are built: an authored population that the
	-- placement rules quietly fail to reach is exactly the defect the review
	-- found here twice.
	local GRAVE_WALL_CELLS = 164
	-- Eighteen from the road pass (nine z stations, both verges) and the
	-- twenty-three court and lane spots authored below. Every one of them
	-- now stands; three did not before the placement was made fatal.
	local ROUTE_LAMPS = 41

	-- The gravewood stand: a broken outer ring, which is what the zone's
	-- `stillgrave_ringbarrows` landmark asks for, plus the two flanking
	-- bands. Every spot is filtered by soil and clearance, so nothing takes
	-- root on paving or within three nodes of a wall.
	local GROVES = {
		{-60, -60, 60, -34, 7},
		{-60, -30, -26, 28, 7},
		{26, -30, 60, 6, 7},
		{-60, 36, 60, 60, 7},
		{-60, 46, -40, 60, 6},
		{40, 46, 60, 60, 6},
	}

	-- NPC sockets: the named standing positions this settlement exports for
	-- the runtime mods (docs/research/wp13-npc-sockets-contract.md section 2).
	-- Anchor-relative like every other landmark, in a fixed authored order;
	-- `y` is the node the entity stands IN, so that cell and the one above it
	-- are air and the node under it is walkable. `dir` is the facing as one
	-- of the four axis vectors. Sockets are not identity bytes -- the
	-- settlement identity SHA covers schema, bounds, palette and cells only --
	-- but `tools/wp13/blueprint_kat.lua` checks every one of them against the
	-- finished pad.
	local SOCKETS = {
		-- The gate watch: one post either side of the road, two nodes inside
		-- the gate line at z = -58, both facing the way out of the hollow.
		{id = "gate_west", role = "guard_post", x = -4, y = 1, z = -56,
			dir = {x = 0, z = -1}},
		{id = "gate_east", role = "guard_post", x = 4, y = 1, z = -56,
			dir = {x = 0, z = -1}},
		{id = "watch_gate", role = "guard_patrol", group = "hollow", order = 1,
			x = 0, y = 1, z = -52, dir = {x = 0, z = -1}},
		{id = "watch_road", role = "guard_patrol", group = "hollow", order = 2,
			x = 0, y = 1, z = -24, dir = {x = 0, z = 1}},
		{id = "watch_court_west", role = "guard_patrol", group = "hollow",
			order = 3, x = -9, y = 1, z = 0, dir = {x = -1, z = 0}},
		{id = "watch_chapel", role = "guard_patrol", group = "hollow",
			order = 4, x = 0, y = 1, z = 6, dir = {x = 0, z = 1}},
		{id = "watch_court_east", role = "guard_patrol", group = "hollow",
			order = 5, x = 9, y = 1, z = 0, dir = {x = 1, z = 0}},
		{id = "court_vendor", role = "vendor", kind = "race", x = 7, y = 1,
			z = -5, dir = {x = -1, z = 0}},
		{id = "idle_warden_door", role = "idle", tags = {"door"}, x = -13,
			y = 1, z = 32, dir = {x = 0, z = 1}},
		{id = "idle_court_settle", role = "idle", tags = {"bench"}, x = -10,
			y = 1, z = 4, dir = {x = 0, z = -1}},
		{id = "idle_bone_works", role = "idle", tags = {"work"}, x = 22, y = 1,
			z = -1, dir = {x = 1, z = 0}},
		-- The gate braziers at (-4, -58) and (4, -58) are the only fire an
		-- arrival sees; this spot stands at the western one.
		{id = "idle_gate_brazier", role = "idle", tags = {"fire"}, x = -5,
			y = 1, z = -57, dir = {x = 0, z = -1}},
		-- `door`: the elder faces the hall door it stands at, and the consumer
		-- turns it round to the street (start_npcs.lua `socket_face_yaw`).
		{id = "hall_quest", role = "quest", tags = {"door"}, x = 2, y = 1,
			z = 10, dir = {x = 0, z = 1}},
		--
		-- SPARE IDLE SPOTS (playtest round 2, 2026-09-15). `spawn = false` is
		-- what makes them wander TARGETS and never homes: the roster places one
		-- villager per SPAWN socket, and `next_spot` walks every idle socket. With
		-- exactly as many spots as villagers every spot is always occupied and the
		-- amble is four people swapping four chairs, which is what the playtest
		-- saw. Each one is a legal standing position on the finished pad -- feet
		-- and head air, walkable settlement ground under it, outdoors, reachable
		-- on foot -- measured by `tools/wp13/blueprint_kat.lua`'s own socket test,
		-- and no tag, because a spare is a place to stand rather than a feature to
		-- talk about.
		-- the obsidian brick west of the lane
		{id = "idle_spare_1", role = "idle", spawn = false, x = -7,
			y = 1, z = -7, dir = {x = 1, z = 0}},
		-- the blighted ground to the south
		{id = "idle_spare_2", role = "idle", spawn = false, x = 7,
			y = 1, z = -12, dir = {x = 0, z = 1}},
		-- the gravel north-east of the lane
		{id = "idle_spare_3", role = "idle", spawn = false, x = 8,
			y = 1, z = 14, dir = {x = 0, z = -1}},
	}

	return function()
		local palette = palettes.new("undead")
		local crypt = palettes.new("undead", CRYPT_STONE)
		local buf = parts.buffer()
		local lights, doorways, rooms = {}, {}, {}
		local placed, inside_by_id = {}, {}
		local ruin_ivy, ruin_cobwebs = 0, 0

		local function outdoors(x, z)
			for _, plot in pairs(placed) do
				if x >= plot.x and x <= plot.x + plot.w - 1 and
						z >= plot.z and z <= plot.z + plot.d - 1 then
					return false
				end
			end
			return true
		end

		-- Ground this composition laid itself and has built nothing on: the
		-- blight, its bone-litter drifts and its gravel scars. `layout.natural`
		-- is stricter -- bare soil only -- and stays the rule for the gravewood
		-- stand and the pad flora; a cairn, a crate or a settle is allowed to
		-- stand on a litter drift, and must not be lost to one.
		local GROUND = {}
		for _, role in ipairs({"ground", "ground_patch", "ground_bare"}) do
			local name = palette.maybe(role)
			if name ~= nil then GROUND[name] = true end
		end

		-- Every prop the composition asks for MUST land. A prop that is
		-- quietly skipped is a hole in the authored scene that no fixture can
		-- see (the previous increment lost three hand carts that way), so
		-- each helper names the prop and its position and raises instead of
		-- returning false -- as does a `build` that reports a partial result
		-- of its own by returning false.
		local function refuse(name, x, z, reason)
			error("wp13 stillgrave: prop " .. name .. " at " .. x .. "," .. z ..
				" was not placed: " .. reason, 0)
		end

		local function place(name, x1, z1, build)
			if build() == false then
				refuse(name, x1, z1, "the prop could not be completed")
			end
		end

		-- A prop on open ground: clear space, and nothing built underneath.
		local function prop(name, x1, z1, x2, z2, build)
			if not layout.free_area(buf, x1, z1, x2, z2, 4) then
				refuse(name, x1, z1, "the space is taken")
			end
			for z = z1, z2 do
				for x = x1, x2 do
					local below = buf:at(x, 0, z)
					if below == nil or not GROUND[below.name] then
						refuse(name, x1, z1, "the ground at " .. x .. "," .. z ..
							" is " .. (below and below.name or "air"))
					end
				end
			end
			place(name, x1, z1, build)
		end

		-- A run of stepping stones is a prop too, and `stepping_line` reports
		-- how many it laid rather than raising, so the count is checked here:
		-- a stone that finds its cell taken is one the composition asked for
		-- and did not get.
		local stepping_stones = 0
		local function stepping(x1, z1, x2, z2)
			local want = (math.abs(x2 - x1) + 1) * (math.abs(z2 - z1) + 1)
			local laid = dressing.stepping_line(buf, palette, x1, z1, x2, z2)
			if laid ~= want then
				refuse("stepping stones", x1, z1, "only " .. laid .. " of " ..
					want .. " stones found a free cell")
			end
			stepping_stones = stepping_stones + laid
		end

		-- Furniture that belongs on the paving it stands on, so only the space
		-- is tested.
		local function paved_prop(name, x1, z1, x2, z2, build)
			if not layout.free_area(buf, x1, z1, x2, z2, 4) then
				refuse(name, x1, z1, "the space is taken")
			end
			place(name, x1, z1, build)
		end

		-- 1. Blight ground over the whole basin.
		layout.blight(buf, palette, RADIUS)

		-- 2. The gravecourt, its obsidian kerb and the lanes off it.
		layout.pave(buf, palette, COURT.x1, COURT.z1, COURT.x2, COURT.z2,
			"plaza", 4)
		dressing.inlay(buf, palette, COURT.x1, COURT.z1, COURT.x2, COURT.z2)
		for _, lane in ipairs(LANES) do
			layout.pave(buf, palette, lane[1], lane[2], lane[3], lane[4],
				"path", 4)
		end

		-- 3. Buildings.
		for _, plot in ipairs(PLOTS) do
			local spec = {}
			for key, value in pairs(plot.spec) do spec[key] = value end
			spec.id = plot.id
			local walls = palette
			if plot.id == "crypt_chapel" then
				-- The chapel is built from the stone palette; only its roof
				-- comes from the hamlet's, which is the plain one.
				walls = crypt
				spec.roof_palette = palette
				spec.kit = "crypt"
			end
			local part = buildings[plot.make](walls, spec)
			if plot.make == "ruin" then
				if part.ivy < 1 or part.cobwebs < 1 then
					error("wp13 stillgrave: the ruin " .. plot.id ..
						" grew no ivy and no cobweb", 0)
				end
				ruin_ivy = ruin_ivy + part.ivy
				ruin_cobwebs = ruin_cobwebs + part.cobwebs
			end
			local points = parts.stamp(buf, part, plot.x, 0, plot.z, 0)
			local footprint = points.footprint[1]
			placed[plot.id] = {x = plot.x, z = plot.z,
				w = footprint.w, d = footprint.d, peak = part.peak}
			for _, door in ipairs(points.doors) do
				doorways[#doorways + 1] = {x = door.x, y = door.y, z = door.z,
					face = door.face, id = plot.id}
			end
			local spot = points.inside[1]
			if spot then
				inside_by_id[DESTINATION_ID[plot.id] or plot.id] =
					{x = spot.x, y = spot.y, z = spot.z}
			end
			for index = 1, #points.room_corner, 2 do
				local a, b = points.room_corner[index], points.room_corner[index + 1]
				rooms[#rooms + 1] = {
					min = {x = math.min(a.x, b.x), y = a.y, z = math.min(a.z, b.z)},
					max = {x = math.max(a.x, b.x), y = a.y, z = math.max(a.z, b.z)},
					top = a.top, closed = a.closed,
					ruin = a.ruin and true or false, id = plot.id,
				}
			end
		end

		-- 4. The gate: two dressed obsidian pillars on the verge under a
		-- gravewood lintel, a brazier at each foot, and low walls running out
		-- to either side. It is the only fire an arrival sees.
		local gate_z = ROAD * 58
		for _, x in ipairs({-3, 3}) do
			buf:put(x, 1, gate_z, palette.variant("pillar", "_bottom"))
			for y = 2, 4 do
				buf:put(x, y, gate_z, palette.variant("pillar", "_middle"))
			end
			buf:put(x, 5, gate_z, palette.variant("pillar", "_top"))
		end
		for x = -2, 2 do buf:put(x, 5, gate_z, palette.node("beam")) end
		dressing.low_wall_line(buf, palette, -10, gate_z, -4, gate_z)
		dressing.low_wall_line(buf, palette, 4, gate_z, 10, gate_z)
		for _, x in ipairs({-4, 4}) do
			buf:put(x, 1, gate_z, palette.node("foundation"))
			parts.floor_torch(buf, palette, x, 2, gate_z)
		end

		-- 5. The gravecourt: the dry well, the offering stall, the notice
		-- post, bone cairns, stone settles and the stones worn across it.
		dressing.well(buf, palette, -7, 3)
		dressing.signpost(buf, palette, -4, -5)
		-- Two nodes east of where it first stood. (4, -2) is the east lamp of
		-- the pair that flanks the court mouth, and the stall's roof slab
		-- oversails its posts by one node on every side, so the awning was
		-- standing over the lamp. The lamp is the route's; the stall moved.
		paved_prop("offering stall", 5, -5, 9, -1, function()
			dressing.stall(buf, palette, 6, -4, 2)
		end)
		-- The cairn: a stepped black plinth carrying one dressed pillar, the
		-- marker the Hollow gathers round. It stands off the road's sight
		-- line, so the chapel door is what an arrival sees down the axis.
		paved_prop("the cairn", 5, 4, 9, 8, function()
			for z = 5, 7 do
				for x = 6, 8 do buf:put(x, 1, z, palette.node("plaza_edge")) end
			end
			buf:put(7, 2, 6, palette.variant("pillar", "_bottom"))
			buf:put(7, 3, 6, palette.variant("pillar", "_middle"))
			buf:put(7, 4, 6, palette.variant("pillar", "_top"))
			for _, corner in ipairs({{6, 5}, {8, 5}, {6, 7}, {8, 7}}) do
				buf:put(corner[1], 2, corner[2], palette.node("low_wall"))
			end
		end)
		-- Six older plots kept inside the paving itself, kerbed in obsidian.
		for _, plot in ipairs({{-10, -3}, {-10, -1}, {-10, 1},
				{10, 3}, {10, 5}, {10, 7}}) do
			paved_prop("court plot", plot[1], plot[2], plot[1], plot[2],
				function()
					buf:put(plot[1], 0, plot[2], palette.node("plaza_edge"))
					buf:put(plot[1], 1, plot[2], palette.node("low_wall"))
				end)
		end
		for _, cairn in ipairs({{-10, -5, 2}, {-9, -5, 1}, {-9, 9, 2},
				{9, 9, 1}, {10, -4, 1}}) do
			paved_prop("bone cairn", cairn[1], cairn[2], cairn[1], cairn[2],
				function()
					dressing.rubble_heap(buf, palette, cairn[1], cairn[2],
						cairn[3])
				end)
		end
		for _, seat in ipairs({{-5, 10, 2, "x"}, {-6, -6, 0, "x"},
				{4, -6, 0, "x"}, {-10, 3, 1, "z"}, {9, 1, 3, "z"}}) do
			paved_prop("stone settle", seat[1], seat[2], seat[1] + 1, seat[2],
				function()
					dressing.bench(buf, palette, seat[1], seat[2], seat[3], 2,
						"x")
				end)
		end
		stepping(-6, 5, -6, 8)
		stepping(-5, 8, -3, 8)
		stepping(3, 8, 5, 8)
		stepping(-8, 0, -5, 0)
		stepping(5, 0, 8, 0)

		-- 6. The burial grounds and their low walls.
		--
		-- The ten runs MEET: each burial ground is a long side, a second long
		-- side and a return, and the returns start on the cells the sides
		-- already wrote. Testing a run with `free_area` over its whole extent
		-- therefore refused it the moment an earlier run had claimed the
		-- shared corner -- silently, because the test only guarded an `if`.
		-- Six of the ten runs were being dropped that way and the burial
		-- grounds stood open on three sides.
		--
		-- A run now tests only the cells it writes, accepts a cell that
		-- already carries this palette's own low wall (that is its corner,
		-- not an obstruction), and is FATAL on anything else, like every
		-- other prop in this composition. All ten are then placed, and the
		-- count is published so `tools/wp13/blueprint_kat.lua` can hold the
		-- population exactly.
		local low_wall = palette.node("low_wall")
		local wall_cells = 0
		for _, line in ipairs(GRAVE_WALLS) do
			local name = "grave wall " .. line[1] .. "," .. line[2]
			for z = math.min(line[2], line[4]), math.max(line[2], line[4]) do
				for x = math.min(line[1], line[3]), math.max(line[1], line[3]) do
					local here = buf:at(x, 1, z)
					local taken = here ~= nil and here.name ~= "air"
					if taken and here.name ~= low_wall then
						refuse(name, x, z, "the cell holds " .. here.name)
					end
					if not taken and not layout.free(buf, x, z, 3) then
						refuse(name, x, z, "the space is taken")
					end
					local below = buf:at(x, 0, z)
					if below == nil or not GROUND[below.name] then
						refuse(name, x, z, "the ground is " ..
							(below and below.name or "air"))
					end
					if not taken then wall_cells = wall_cells + 1 end
				end
			end
			dressing.low_wall_line(buf, palette, line[1], line[2],
				line[3], line[4])
		end
		assert(wall_cells == GRAVE_WALL_CELLS, "wp13 stillgrave: the burial " ..
			"walls wrote " .. wall_cells .. " cells, not " .. GRAVE_WALL_CELLS)
		local graves = 0
		for _, yard in ipairs(GRAVEYARDS) do
			graves = graves + dressing.graveyard(buf, palette, yard[1], yard[2],
				yard[3], yard[4])
		end

		-- 7. The works yard and what the hamlet leaves lying about.
		for _, pile in ipairs({{-22, 6, 4, "z"}, {22, 8, 3, "z"},
				{-38, 24, 3, "x"}, {26, -18, 3, "x"}}) do
			local axis = pile[4]
			local x2 = axis == "x" and pile[1] + pile[3] - 1 or pile[1]
			local z2 = axis == "z" and pile[2] + pile[3] - 1 or pile[2]
			prop("gravewood stack", pile[1], pile[2], x2, z2, function()
				dressing.wood_pile(buf, palette, pile[1], pile[2], pile[3], axis)
			end)
		end
		-- (-22, 2) is a route lamp; the crate that used to stand there stands
		-- one node west of it now.
		for _, crate in ipairs({{22, -6, 3}, {22, -5, 3}, {-23, 2, 1},
				{16, -20, 2}, {-14, 26, 0}}) do
			prop("crate stack", crate[1], crate[2], crate[1], crate[2],
				function()
					dressing.crates(buf, palette, crate[1], crate[2], crate[3])
				end)
		end
		for _, heap in ipairs({{14, 27, 2}, {15, 27, 1}, {-24, 27, 2},
				{31, 34, 1}, {-38, 32, 2}, {0, 28, 1}, {12, 12, 2},
				{-14, 8, 1}}) do
			prop("rubble heap", heap[1], heap[2], heap[1], heap[2], function()
				dressing.rubble_heap(buf, palette, heap[1], heap[2], heap[3])
			end)
		end

		-- 8. The gravewood stand.
		local grove = 0
		for _, block in ipairs(GROVES) do
			grove = grove + layout.plant_gravewood(buf, palette, block[1],
				block[2], block[3], block[4], block[5])
		end

		-- 9. Route lighting: the road, the lanes and the court.
		--
		-- A lamp that cannot be placed is a dark stretch of route, which is
		-- the one thing section 5's lit-route invariant forbids, so both
		-- passes are fatal and the total is asserted. They were not: the
		-- road pass threw its return away and the court pass hid its
		-- failures in an `if`, which is how the crate stack at (-22, 2) came
		-- to stand where a lamp was authored and three lamps went missing
		-- with nothing said. The crate moved; the checks stayed.
		local lamps = layout.street_lamps(buf, palette, 0, ROAD * 56, -4, 6,
			outdoors)
		-- The Hollow burns few open flames: the road lamps, the gate braziers
		-- and the candles on the buildings. These are the road's own.
		for _, spot in ipairs({{-4, -2}, {4, -2},
				{-12, 3}, {12, 3}, {-12, -6}, {12, -6},
				{-19, -18}, {19, -18}, {-19, 10}, {19, 10},
				{-19, 26}, {19, 26}, {-12, 30}, {12, 30},
				{-30, 30}, {30, 30}, {-22, 2}, {-9, -6}, {9, -6},
				-- (17, 34), not (19, 34): the sunken ruin's footprint starts
				-- at x = 18, and a lamp authored inside a plot is a lamp that
				-- never stood. Its mirror (-19, 34) sits west of the warden
				-- house the same way.
				{-6, 10}, {6, 10}, {-19, 34}, {17, 34}}) do
			if not outdoors(spot[1], spot[2]) then
				refuse("path lamp", spot[1], spot[2], "the spot is indoors")
			end
			-- `paved_prop`, not `prop`: a route lamp stands where the route
			-- runs, and half of these stand on the court's paving. What it
			-- needs is a floor and four clear courses, which is exactly what
			-- `layout.free_area` demands.
			paved_prop("path lamp", spot[1], spot[2], spot[1], spot[2],
				function()
					dressing.path_light(buf, palette, spot[1], spot[2])
				end)
			lamps = lamps + 1
		end
		assert(lamps == ROUTE_LAMPS, "wp13 stillgrave: " .. lamps ..
			" route lamps stand, not " .. ROUTE_LAMPS)

		-- 10. Bone piles and dead shrubs on whatever open blight is left:
		-- thin over the basin, thicker where the ground is already turned.
		local bones, shrubs = dressing.blight_flora(buf, palette, -RADIUS,
			-RADIUS, RADIUS, RADIUS, 97, 2, 4)
		for _, yard in ipairs(GRAVEYARDS) do
			local b, s = dressing.blight_flora(buf, palette, yard[1] - 2,
				yard[2] - 2, yard[3] + 2, yard[4] + 2, 17, 2, 2)
			bones, shrubs = bones + b, shrubs + s
		end

		-- 11. Bar shapes, settled once over the finished pad for the reason
		-- written in `parts.resolve_panes`.
		parts.resolve_panes(buf)

		-- 12. Canonical cell list, bounds and palette.
		local source, count = buf:cells()
		local cells = {}
		for index = 1, count do cells[index] = source[index] end
		table.sort(cells, function(a, b)
			if a.z ~= b.z then return a.z < b.z end
			if a.y ~= b.y then return a.y < b.y end
			return a.x < b.x
		end)
		local light_names = {[palette.node("light_post")] = true,
			[palette.node("light_wall")] = true,
			[palette.node("light_indoor")] = true}
		for index = 1, #cells do
			local cell = cells[index]
			if light_names[cell.name] then
				lights[#lights + 1] = {x = cell.x, y = cell.y, z = cell.z}
			end
		end
		local names, palette_list = {}, {}
		local minp = {x = cells[1].x, y = cells[1].y, z = cells[1].z}
		local maxp = {x = cells[1].x, y = cells[1].y, z = cells[1].z}
		for index = 1, #cells do
			local cell = cells[index]
			if not names[cell.name] then
				names[cell.name] = true
				palette_list[#palette_list + 1] = cell.name
			end
			if cell.x < minp.x then minp.x = cell.x end
			if cell.y < minp.y then minp.y = cell.y end
			if cell.z < minp.z then minp.z = cell.z end
			if cell.x > maxp.x then maxp.x = cell.x end
			if cell.y > maxp.y then maxp.y = cell.y end
			if cell.z > maxp.z then maxp.z = cell.z end
		end
		-- ASCII byte order, not Lua's `<`, which is `strcoll` and so
		-- locale-dependent; see `parts.less_bytes`.
		table.sort(palette_list, parts.less_bytes)

		local destinations = {}
		for _, id in ipairs(DESTINATION_ORDER) do
			local spot = inside_by_id[id]
			if not spot then
				error("wp13 stillgrave: destination " .. id .. " is missing", 0)
			end
			destinations[#destinations + 1] =
				{id = id, x = spot.x, y = spot.y, z = spot.z}
		end

		local function box(id, margin, lift)
			local plot = placed[id]
			return {
				min = {x = plot.x - margin, y = -1, z = plot.z - margin},
				max = {x = plot.x + plot.w - 1 + margin, y = plot.peak + lift,
					z = plot.z + plot.d - 1 + margin},
			}
		end
		local function door_of(id)
			for _, door in ipairs(doorways) do
				if door.id == id then
					return {x = door.x, y = door.y, z = door.z}
				end
			end
			error("wp13 stillgrave: no door for " .. id, 0)
		end

		return {
			schema = SCHEMA,
			cells = cells,
			bounds = {min = minp, max = maxp},
			palette = palette_list,
			landmarks = {
				spawn = {x = 0, y = 1, z = 0},
				arrival = {x = 0, y = 1, z = 0},
				gate = {x = 0, y = 1, z = ROAD * RADIUS},
				gravecourt = {min = {x = COURT.x1, y = 0, z = COURT.z1},
					max = {x = COURT.x2, y = 4, z = COURT.z2}},
				-- The five-wide route, gate end first. Its z span carries the
				-- road direction for every consumer.
				main_street = {min = {x = -2, y = 0, z = ROAD * RADIUS},
					max = {x = 2, y = 3, z = 0}},
				crypt_chapel = box("crypt_chapel", 2, 3),
				crypt_chapel_door = door_of("crypt_chapel"),
				bone_works = box("bone_works", 2, 3),
				bone_works_door = door_of("bone_works"),
				keepers_house = box("keepers_house", 2, 3),
				keepers_house_door = door_of("keepers_house"),
				warden_house = box("warden_house", 2, 3),
				warden_house_door = door_of("warden_house"),
				hollow_ruin = box("hollow_ruin", 2, 3),
				sunken_ruin = box("sunken_ruin", 2, 3),
				watchtower = box("watchtower", 2, 3),
				gate_passage = {min = {x = -2, y = 1, z = ROAD * RADIUS},
					max = {x = 2, y = 5, z = ROAD * 50}},
				destinations = destinations,
				doors = doorways,
				rooms = rooms,
				lights = lights,
				sockets = SOCKETS,
				graves = graves,
				gravewood_trees = grove,
				bone_piles = bones,
				dead_shrubs = shrubs,
				stepping_stones = stepping_stones,
				ruin_ivy = ruin_ivy,
				ruin_cobwebs = ruin_cobwebs,
			},
		}
	end
end

return loader
