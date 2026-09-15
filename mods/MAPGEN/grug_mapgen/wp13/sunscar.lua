-- Sunscar Camp: the orc start settlement, composed from the WP13 building
-- library.
--
-- Hearthpine is a craft settlement in a pine clearing and Dawnmere a farming
-- hamlet on open meadow. Sunscar is neither: it is a WAR CAMP that stopped
-- moving, on the ochre flats beside a low red rock outcrop of Sunscar Flats
-- (world_zones.md section 8.2 and section 10). What makes that legible from
-- the gate is the roofline -- every building here is flat topped behind a
-- crenellated breastwork, where the other two starts are all ridges -- and
-- then, in order: adobe over a desert-stone base course instead of timber
-- walls, barred slits instead of glazed windows, a beaten muster yard
-- instead of a plaza or a green, a stake palisade and gate towers across the
-- road face, siege berms round the rest of the perimeter, and flat-crowned
-- acacias instead of conifers or orchard standards.
--
-- The road exits SOUTH. Every Accord start's road runs north to its gate;
-- the three Throng starts are on the other side of the world and their gate
-- stations sit at z = anchor.z - 64 (`start:south` in
-- `wp40/source/catalog.lua`). The corridor, the gate, the towers and the
-- street lighting therefore run toward -z, and the `main_street` landmark
-- says so, which is what the KAT and the engine case read instead of
-- assuming a direction.
--
-- Authored in local coordinates around the orc spawn; the caller fits y = 0
-- to the fitted start terrain before projecting the cells. The result is the
-- `grug_wp13_sunscar_blueprint_v1` payload that
-- `wp40/r7_sunscar_blueprint.lua` returns unchanged.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local palettes = dofile(directory .. "/palette.lua")
	local buildings = dofile(directory .. "/buildings.lua")(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local layout = dofile(directory .. "/layout.lua")(directory)

	local RADIUS = 63
	local SCHEMA = "grug_wp13_sunscar_blueprint_v1"
	-- The road runs toward -z, to the `start:south` gate station.
	local EXIT = -1

	-- The muster yard: beaten sand, the only paved open space in the camp.
	local YARD = {x1 = -13, z1 = -9, x2 = 13, z2 = 11}

	-- Paved runs, in the order they are laid. The five wide road from the
	-- yard to the gate is the contract's route and carries no plot.
	local LANES = {
		{-2, -RADIUS, 2, -9},            -- the road, yard to gate
		{-5, -58, 5, -52},               -- the gate court between the towers
		{-2, 11, 2, 13},                 -- yard to the warlord's hall
		{-41, -1, -13, 1},               -- west lane, to the beast pen
		{13, -3, 21, -1},                -- east lane, to the armoury
		{-33, 13, -9, 15},               -- hall lane, on to the round lodge
		{-35, -24, 19, -22},             -- the lodges' lane
		{-31, -25, -29, -23},            -- spear lodge doorstep
		{-12, -25, -10, -23},            -- tusk lodge doorstep
		{13, -25, 15, -23},              -- bone lodge doorstep
	}

	-- Plot roster. Each row is one placed building: landmark id, generator,
	-- its parameters and the pad anchor of its footprint. Every roof is a
	-- flat deck; the breastwork that turns a deck into a fighting top is
	-- written over the finished pad, because a parapet is a ring of full
	-- nodes and the roof rasteriser writes exactly one cell per column.
	local PLOTS = {
		{id = "warlord_hall", make = "hall", x = -7, z = 14, turns = 0,
			spec = {w = 15, d = 17, wall_h = 7, roof = "flat_deck"}},
		{id = "armoury", make = "workshop", x = 22, z = -7, turns = 0,
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, wing_wall_h = 4,
				roof = "flat_deck", door_side = "x-"}},
		{id = "beast_pen", make = "shed", x = -40, z = -8, turns = 0,
			spec = {w = 13, d = 11, wall_h = 4, roof = "flat_deck",
				open_sides = {"x+", "z+"}}},
		{id = "chief_lodge", make = "round_lodge", x = -36, z = 16, turns = 0,
			spec = {wall_h = 5}},
		{id = "spear_lodge", make = "cottage", x = -34, z = -34, turns = 0,
			spec = {w = 9, d = 9, wall_h = 5, roof = "flat_deck",
				door_side = "z+", door_index = 4, infill = true}},
		{id = "tusk_lodge", make = "cottage", x = -16, z = -34, turns = 0,
			spec = {w = 11, d = 9, wall_h = 5, roof = "flat_deck",
				door_side = "z+", door_index = 5, fancy_bed = true}},
		{id = "bone_lodge", make = "cottage", x = 10, z = -34, turns = 0,
			spec = {w = 9, d = 11, wall_h = 6, roof = "flat_deck",
				door_side = "z+", door_index = 4, infill = true}},
		{id = "west_tower", make = "watchpost", x = -14, z = -60, turns = 0,
			spec = {roof = "flat_deck", door_side = "x+"}},
		{id = "east_tower", make = "watchpost", x = 6, z = -60, turns = 0,
			spec = {roof = "flat_deck", door_side = "x-"}},
	}

	-- Destination order is part of the consumer contract and never changes.
	local DESTINATION_ORDER = {"warlord_hall", "warlord_platform", "armoury",
		"beast_pen", "chief_lodge", "spear_lodge", "tusk_lodge", "bone_lodge",
		"west_tower_lookout", "east_tower_lookout"}

	local DESTINATION_ID = {west_tower = "west_tower_lookout",
		east_tower = "east_tower_lookout"}

	-- The breastwork on each building's deck: the rectangle it rings, the
	-- deck course it stands on and the merlon rhythm. A deck slab sits one
	-- course above the wall head (`roofs.flat_deck`), so the breastwork
	-- stands on the course above that and a warrior walks the deck between
	-- the merlons.
	local BREASTWORKS = {
		{id = "warlord_hall", x1 = -7, z1 = 14, x2 = 7, z2 = 30, y = 9,
			step = 2},
		{id = "armoury", x1 = 22, z1 = -7, x2 = 32, z2 = 5, y = 7, step = 2},
		{id = "armoury_wing", x1 = 31, z1 = -4, x2 = 37, z2 = 2, y = 6,
			step = 2},
		{id = "chief_lodge", x1 = -35, z1 = 17, x2 = -29, z2 = 23, y = 7,
			step = 2},
		{id = "spear_lodge", x1 = -34, z1 = -34, x2 = -26, z2 = -26, y = 7,
			step = 2},
		{id = "tusk_lodge", x1 = -16, z1 = -34, x2 = -6, z2 = -26, y = 7,
			step = 2},
		{id = "bone_lodge", x1 = 10, z1 = -34, x2 = 18, z2 = -24, y = 8,
			step = 2},
		{id = "west_tower", x1 = -14, z1 = -60, x2 = -6, z2 = -52, y = 10,
			step = 2},
		{id = "east_tower", x1 = 6, z1 = -60, x2 = 14, z2 = -52, y = 10,
			step = 2},
	}

	-- The stake line across the road face, left and right of the gate
	-- towers, and the siege berms round the other three sides. A berm row is
	-- {x1, z1, x2, z2, crest}: three rows of crest 1, 2, 1 make a bank with
	-- sides, not a wall.
	local PALISADE = {
		{-62, -56, -15, -56},
		{15, -56, 62, -56},
	}
	-- Each bank is {axis, outer line, from, to}: three rows deep with a
	-- 1-2-1 crest, laid inward from the pad edge. They are SHORT -- a camp
	-- digs where it expects to be hit and leaves the rest to the flats -- so
	-- the perimeter is a broken line of works, not a continuous rampart.
	local BERMS = {
		{"z", 58, -58, -30}, {"z", 58, -16, 16},
		{"x", -62, -44, -22}, {"x", -62, -6, 16}, {"x", -62, 28, 52},
		{"x", 62, -44, -22}, {"x", 62, -6, 16},
	}
	local BERM_CREST = {1, 2, 1}

	-- A low red rock outcrop in the north-east corner: the one piece of
	-- relief on the flats, and all the relief they are allowed.
	--
	-- `docs/design/world_zones.md` section 8.4 gives Sunscar Flats open
	-- golden savanna with SMALL rolling-hill rock masks. The first version
	-- built an eight-course bluff right across the corner and out to the pad
	-- edge -- a mesa, which is the neighbouring Bannerbreak zone's landform,
	-- not this one's, and a wall at the edge where the writer's own apron has
	-- to blend into whatever terrain the seed put there.
	--
	-- Three courses now, none of it closer than four nodes to the pad edge,
	-- in overlapping slabs whose corners are staggered against each other so
	-- the outcrop's foot is a broken line and its top is two or three ledges
	-- rather than a quarter circle of masonry stepped like a ziggurat.
	-- Ascending height, because a later slab overwrites an earlier one.
	local OUTCROP = {
		{38, 34, 59, 59, 1},
		{44, 27, 55, 47, 1},
		{41, 41, 59, 52, 2},
		{48, 32, 57, 44, 2},
		{46, 46, 54, 56, 3},
		{51, 36, 56, 42, 3},
	}

	-- Acacia blocks on the open flats. The crown of `dressing.acacia` reaches
	-- three nodes and the stem is clear, so the same clearance rule the
	-- orchards use fits it unchanged.
	local GROVES = {
		{-58, -46, -40, -26, 7, 6}, {40, -46, 58, -26, 7, 6},
		{-58, -18, -46, 8, 7, 5}, {46, -18, 58, 8, 7, 5},
		{-58, 20, -42, 50, 8, 6}, {42, 20, 58, 50, 8, 6},
		{-34, 36, -12, 52, 8, 5}, {12, 36, 34, 52, 8, 5},
		{-34, -20, -20, -10, 9, 5}, {24, 14, 38, 30, 9, 5},
	}

	-- A round-ish dwelling. `buildings.build` takes rectangles, and the union
	-- of a tall narrow one with a short wide one is an octagon: the four
	-- corner cells of the square are simply never built, and every wall cell
	-- that falls strictly inside the other rectangle is opened, so the two
	-- blocks are one room. That is as round as an axis-aligned voxel house
	-- gets without a curve, and it is what a chief's round lodge looks like
	-- from the yard.
	local function round_lodge(palette, spec)
		local w, d = 9, 9
		local wall_h = spec.wall_h or 5
		return buildings.build(palette, {
			id = spec.id, overhang = 1, infill = true,
			blocks = {
				{x0 = 1, z0 = 0, x1 = w - 2, z1 = d - 1, wall_h = wall_h,
					roof = "flat_deck", kit = "home",
					kit_spec = {hearth_x = w - 3, hearth_z = 1,
						hearth_face = 3}},
				{x0 = 0, z0 = 1, x1 = w - 1, z1 = d - 2, wall_h = wall_h,
					roof = "flat_deck"},
			},
			chimneys = {{x = w - 2, z = 1}},
			doors = {{side = "z-", index = 3}},
			inside = {x = 3, y = 1, z = d - 3},
		})
	end

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
		-- The gate watch: one post either side of the road behind the two
		-- gate towers, both facing the way out of the flats.
		{id = "gate_west", role = "guard_post", x = -4, y = 1, z = -51,
			dir = {x = 0, z = -1}},
		{id = "gate_east", role = "guard_post", x = 4, y = 1, z = -51,
			dir = {x = 0, z = -1}},
		{id = "watch_gate", role = "guard_patrol", group = "camp", order = 1,
			x = 0, y = 1, z = -40, dir = {x = 0, z = -1}},
		{id = "watch_road", role = "guard_patrol", group = "camp", order = 2,
			x = 0, y = 1, z = -22, dir = {x = 0, z = 1}},
		{id = "watch_yard_west", role = "guard_patrol", group = "camp",
			order = 3, x = -11, y = 1, z = 0, dir = {x = -1, z = 0}},
		{id = "watch_hall", role = "guard_patrol", group = "camp", order = 4,
			x = -1, y = 1, z = 7, dir = {x = 0, z = 1}},
		{id = "watch_yard_east", role = "guard_patrol", group = "camp",
			order = 5, x = 11, y = 1, z = 0, dir = {x = 1, z = 0}},
		{id = "yard_vendor", role = "vendor", kind = "race", x = 8, y = 1,
			z = -5, dir = {x = -1, z = 0}},
		{id = "idle_tusk_door", role = "idle", tags = {"door"}, x = -11, y = 1,
			z = -22, dir = {x = 0, z = -1}},
		{id = "idle_council_seat", role = "idle", tags = {"bench"}, x = -3,
			y = 1, z = 8, dir = {x = 1, z = 0}},
		{id = "idle_beast_pen", role = "idle", tags = {"work"}, x = -25, y = 1,
			z = -2, dir = {x = -1, z = 0}},
		{id = "idle_armoury_forge", role = "idle", tags = {"fire"}, x = 20,
			y = 1, z = -2, dir = {x = 1, z = 0}},
		--
		-- WORKPLACES (playtest round 3, contract section 8.1). A `work` socket
		-- is a spawn socket like an `idle` one and its resident never leaves
		-- it. Both stand at features the camp already has, so no cell moves.
		--
		-- A SMITH at the open anvil west of the yard -- the one anvil in the
		-- six starts that stands outdoors, which is what a `work` socket needs
		-- (a socket is never inside a room) -- and a woodcutter at the acacia
		-- on the north lane.
		{id = "work_forge", role = "work", activity = "smith", tags = {"fire"},
			x = -34, y = 1, z = 2, dir = {x = 0, z = -1}},
		{id = "work_acacia", role = "work", activity = "chop", tags = {"work"},
			x = -14, y = 1, z = -1, dir = {x = 0, z = -1}},
		-- `door`: the elder faces the hall door it stands at, and the consumer
		-- turns it round to the street (start_npcs.lua `socket_face_yaw`).
		{id = "hall_quest", role = "quest", tags = {"door"}, x = 3, y = 1,
			z = 12, dir = {x = 0, z = 1}},
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
		-- the sand west of the muster yard
		{id = "idle_spare_1", role = "idle", spawn = false, x = -7,
			y = 1, z = -6, dir = {x = 1, z = 0}},
		-- the sand south of the muster yard
		{id = "idle_spare_2", role = "idle", spawn = false, x = 6,
			y = 1, z = -12, dir = {x = 0, z = 1}},
		-- the desert cobble by the north lane
		{id = "idle_spare_3", role = "idle", spawn = false, x = -8,
			y = 1, z = 14, dir = {x = 0, z = -1}},
	}

	return function()
		local palette = palettes.new("orc")
		local buf = parts.buffer()
		local lights, doorways, rooms = {}, {}, {}
		local placed, inside_by_id = {}, {}
		local make = {}
		for name, generator in pairs(buildings) do make[name] = generator end
		make.round_lodge = round_lodge

		-- The same plots in roster order. `placed` is keyed by landmark id and
		-- can only be walked with `pairs`; the ordered copy keeps the
		-- footprint test free of hash-table iteration.
		local plot_order = {}

		local function outdoors(x, z)
			for _, plot in ipairs(plot_order) do
				if x >= plot.x and x <= plot.x + plot.w - 1 and
						z >= plot.z and z <= plot.z + plot.d - 1 then
					return false
				end
			end
			return true
		end

		-- Ground this composition laid itself and has built nothing on: the
		-- flats' grass, the camp's worn earth and gravel, and the byre's
		-- straw. `layout.natural` is stricter -- bare soil only -- and stays
		-- the rule for the groves and the dry flora; a bale, a barrel or a
		-- wagon is allowed to stand on a worn patch and must not be lost to
		-- one.
		local GROUND = {}
		for _, role in ipairs({"ground", "ground_patch", "ground_bare",
				"ground_straw"}) do
			local name = palette.maybe(role)
			if name ~= nil then GROUND[name] = true end
		end

		-- Every prop the composition asks for MUST land. A prop that is
		-- quietly skipped is a hole in the authored scene that no fixture can
		-- see, so both helpers name the prop and its position and raise
		-- instead of returning false -- as does a `build` that reports a
		-- partial result of its own by returning false.
		local function refuse(name, x, z, reason)
			error("wp13 sunscar: prop " .. name .. " at " .. x .. "," .. z ..
				" was not placed: " .. reason, 0)
		end

		local function place(name, x1, z1, build)
			if build() == false then
				refuse(name, x1, z1, "the prop could not be completed")
			end
		end

		-- The first cell of a rectangle that is not clear standing room, named
		-- with what is in the way: "the space is taken" on its own is a
		-- message that costs an hour to act on.
		local function obstruction(x1, z1, x2, z2)
			for z = z1, z2 do
				for x = x1, x2 do
					if not layout.free(buf, x, z, 4) then
						local blocker
						for y = 1, 4 do
							local cell = buf:at(x, y, z)
							if cell ~= nil and cell.name ~= "air" then
								blocker = cell.name .. " at height " .. y
								break
							end
						end
						return x .. "," .. z .. " holds " ..
							(blocker or "no ground under it")
					end
				end
			end
			return nil
		end

		-- A prop on open ground: clear space, and nothing built underneath.
		local function prop(name, x1, z1, x2, z2, build)
			local taken = obstruction(x1, z1, x2, z2)
			if taken then refuse(name, x1, z1, taken) end
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

		-- Camp gear that belongs on the paving it stands on, so only the
		-- space is tested.
		local function paved_prop(name, x1, z1, x2, z2, build)
			local taken = obstruction(x1, z1, x2, z2)
			if taken then refuse(name, x1, z1, taken) end
			place(name, x1, z1, build)
		end

		-- A wall prop must find its support and a free cell, or the wall it
		-- was authored against has moved.
		local function wall_prop(name, role, x, y, z, dx, dy, dz)
			if not parts.wall_prop(buf, palette, role, x, y, z, dx, dy, dz) then
				refuse(name, x, z, "no support or no room at height " .. y)
			end
		end

		-- 1. The flats: ochre grass with the bare dirt and gravel of a camp
		-- worn only where the camp actually treads.
		layout.meadow(buf, palette, RADIUS, 36)
		-- The camp's own wear. `layout.meadow` scatters a few patches for a
		-- hamlet on turf; a war camp on dry ground is beaten bare wherever it
		-- stands, and without this the whole 127-node pad rendered as a
		-- single unbroken yellow. Two passes: a wide light one over the
		-- ground the camp uses, and a heavy one over the ground it lives on.
		-- Wear needs a hash, not a pattern. Any expression linear in x lays
		-- its hits on an arithmetic progression, and an arithmetic
		-- progression modulo the sieve's period is exactly a stripe: the
		-- first version streaked the pad diagonally, the second banded it.
		-- Two rounds of a plain LCG decorrelate x from z and leave no visible
		-- lattice. `parts.position_hash` is exactly that pair of rounds, and
		-- the ground cover in `dressing.lua` reads the same helper.
		local wear_hash = parts.position_hash
		-- Each hit paints a 2 x 2 blob, not a single cell: single-cell noise
		-- reads as dithering at every camera distance, where a patch two
		-- nodes across reads as ground somebody wore out.
		for _, pass in ipairs({{46, 29, 7}, {26, 17, 5}}) do
			local reach, period, bare = pass[1], pass[2], pass[3]
			for z = -reach, reach do
				for x = -reach, reach do
					local hash = wear_hash(x, z) % period
					local role
					if hash == 0 then role = "ground_patch"
					elseif hash == bare then role = "ground_bare" end
					if role then
						buf:fill(x, 0, z, math.min(x + 1, reach), 0,
							math.min(z + 1, reach), palette.node(role))
					end
				end
			end
		end

		-- 2. The muster yard and the lanes off it.
		layout.pave(buf, palette, YARD.x1, YARD.z1, YARD.x2, YARD.z2,
			"plaza", 4)
		dressing.inlay(buf, palette, YARD.x1, YARD.z1, YARD.x2, YARD.z2)
		for _, lane in ipairs(LANES) do
			layout.pave(buf, palette, lane[1], lane[2], lane[3], lane[4],
				"path", 4)
		end

		-- 3. Buildings.
		for _, plot in ipairs(PLOTS) do
			local spec = {}
			for key, value in pairs(plot.spec) do spec[key] = value end
			spec.id = plot.id
			local part = make[plot.make](palette, spec)
			local points = parts.stamp(buf, part, plot.x, 0, plot.z, plot.turns)
			local footprint = points.footprint[1]
			placed[plot.id] = {x = plot.x, z = plot.z,
				w = footprint.w, d = footprint.d, peak = part.peak}
			plot_order[#plot_order + 1] = placed[plot.id]
			for _, door in ipairs(points.doors) do
				doorways[#doorways + 1] = {x = door.x, y = door.y, z = door.z,
					face = door.face, id = plot.id}
			end
			local spot = points.inside[1]
			inside_by_id[DESTINATION_ID[plot.id] or plot.id] =
				{x = spot.x, y = spot.y, z = spot.z}
			for index = 1, #points.room_corner, 2 do
				local a, b = points.room_corner[index], points.room_corner[index + 1]
				rooms[#rooms + 1] = {
					min = {x = math.min(a.x, b.x), y = a.y, z = math.min(a.z, b.z)},
					max = {x = math.max(a.x, b.x), y = a.y, z = math.max(a.z, b.z)},
					top = a.top, closed = a.closed, id = plot.id,
				}
			end
		end

		-- 3b. Two cressets on the round lodge's outer ring. The octagon is
		-- two overlapping rectangles, so it publishes two rooms, and the home
		-- kit's own torches slide onto the chamfer walls of the inner one:
		-- the outer ring would be a furnished room with no light of its own.
		-- These hang on the wide block's long walls, which are the only two
		-- walls that ring is bounded by.
		for _, cresset in ipairs({{-35, 18, -1}, {-29, 22, 1}}) do
			parts.wall_torch(buf, palette, cresset[1], 3, cresset[2],
				cresset[3], 0, 0)
		end

		-- 4. Breastworks. Every deck gets its crenellated ring; the armoury's
		-- main ring is cut where the forge wing passes under it, so the two
		-- roofs stay one working top and not a walled-off gutter.
		local merlon_caps = {}
		for _, work in ipairs(BREASTWORKS) do
			dressing.parapet(buf, palette, work.x1, work.z1, work.x2, work.z2,
				work.y, work.step, merlon_caps)
		end
		-- Two cuts where the armoury and its forge wing meet. The main ring
		-- is cut where the wing passes under it, so the two roofs are one
		-- working top and not a walled-off gutter -- and the WING's own west
		-- ring stands on the main room's roof deck, where for seven columns
		-- it was the only thing over the room: `walls:desertcobble` is a
		-- connected nodebox, so daylight came straight down into the armoury
		-- between the wall and its neighbours. That ring is cut too and the
		-- deck laid across it.
		buf:clear(32, 7, -4, 32, 8, 2)
		buf:clear(31, 6, -4, 31, 7, 2)
		-- The patch is the same course the rasteriser lays for a deck, so it
		-- is the deck's full cube and not a bottom slab: a slab here would
		-- put back exactly the half node of air the parapet fix removed.
		for z = -4, 2 do
			buf:put(31, 6, z, palette.node("roof_ridge"))
		end

		-- 5. The warlord's fighting top: an external stair off the east
		-- apron, a gap cut in the breastwork where it lands, and a brazier on
		-- each corner of the deck, so the platform is lit and reachable
		-- without a ladder.
		dressing.outer_stair(buf, palette, 8, 16, 8, "z", 0)
		-- The flight climbs under the deck's own eave, so the eave is cut
		-- away over it: without that a warrior halfway up has a slab where
		-- his head is, and the platform is only reachable in theory.
		buf:clear(8, 8, 16, 8, 8, 22)
		buf:clear(7, 9, 22, 7, 10, 23)
		for _, brazier in ipairs({{-5, 18}, {5, 18}, {-5, 26}, {5, 26},
				{0, 25}}) do
			buf:put(brazier[1], 9, brazier[2], palette.node("wall_accent"))
			parts.floor_torch(buf, palette, brazier[1], 10, brazier[2])
		end
		inside_by_id.warlord_platform = {x = 0, y = 9, z = 22}

		-- 6. The gate: two desert-stone piers under an acacia lintel, torches
		-- over the road and the stake line running out to either side.
		-- The arch stands IN the stake line at z = -56, in the gap between the
		-- towers, not between them at z = -58 where the towers themselves
		-- hide it from every approach. A rider passes the arch and the wall
		-- together, with a tower over each shoulder.
		for _, x in ipairs({-4, 4}) do
			for y = 1, 5 do buf:put(x, y, -56, palette.node("wall_accent")) end
		end
		for x = -3, 3 do buf:put(x, 5, -56, palette.node("beam")) end
		for _, side in ipairs({{-3, -1}, {3, 1}}) do
			parts.wall_torch(buf, palette, side[1], 4, -56, side[2], 0, 0)
		end
		local stakes = 0
		for _, line in ipairs(PALISADE) do
			stakes = stakes + dressing.palisade(buf, palette, line[1], line[2],
				line[3], line[4], 4)
		end
		-- Two barred loopholes cut into the stake line beside the gate. A bar
		-- with timber on three sides is the one place in the camp where
		-- `xpanes` settles on its connected shape instead of a flat slit.
		for _, hole in ipairs({{-16, -56}, {16, -56}}) do
			parts.pane(buf, palette, hole[1], 3, hole[2], "x")
			buf:put(hole[1], 3, hole[2] - 1, palette.node("tree_log"))
		end

		-- 7. The rock outcrop, then the siege berms on the sides the palisade
		-- does not cover. The rock goes down first: it is terrain, and the
		-- earthworks are dug against it.
		local outcrop_cells = 0
		for _, slab in ipairs(OUTCROP) do
			outcrop_cells = outcrop_cells + dressing.rock_terrace(buf, palette,
				slab[1], slab[2], slab[3], slab[4], slab[5])
		end
		local berm_cells = 0
		for _, bank in ipairs(BERMS) do
			local axis, outer, from, to = bank[1], bank[2], bank[3], bank[4]
			local inward = (outer > 0) and -1 or 1
			for row = 1, #BERM_CREST do
				local line = outer + inward * (row - 1)
				local x1, z1, x2, z2
				if axis == "z" then
					x1, z1, x2, z2 = from, line, to, line
				else
					x1, z1, x2, z2 = line, from, line, to
				end
				berm_cells = berm_cells + dressing.berm(buf, palette, x1, z1,
					x2, z2, BERM_CREST[row])
			end
		end

		-- 8. The training yard: two ranks of drill posts, weapon racks, bale
		-- targets, the war council's fire ring, two parked wagons and four
		-- standards on the corners of the muster ground.
		for _, post in ipairs({{-11, 3}, {-9, 3}, {-7, 3}, {-5, 3},
				{-11, 6}, {-9, 6}, {-7, 6}, {-5, 6}}) do
			paved_prop("drill_post", post[1], post[2], post[1], post[2],
				function()
					return dressing.drill_post(buf, palette, post[1], post[2], 3)
				end)
		end
		for _, rack in ipairs({{4, 3, 8, 3}, {4, 6, 8, 6}}) do
			paved_prop("weapon_rack", rack[1], rack[2], rack[3], rack[4],
				function()
					dressing.fence_line(buf, palette, rack[1], rack[2],
						rack[3], rack[4])
				end)
		end
		for _, target in ipairs({{11, 2, 2}, {11, 5, 3}, {11, 8, 2}}) do
			paved_prop("bale_target", target[1], target[2], target[1],
				target[2], function()
					return dressing.bale_stack(buf, palette, target[1],
						target[2], target[3])
				end)
		end
		-- The council fire: a stone ring, the camp pot and its light. It sits
		-- BEYOND the spawn end of the road, so the five-wide route from the
		-- gate stays clear the whole way in.
		dressing.inlay(buf, palette, -2, 6, 2, 10, "plaza_edge")
		buf:put(0, 1, 8, palette.node("hearth"), 0)
		parts.floor_torch(buf, palette, 0, 2, 8)
		for _, seat in ipairs({{-2, 7, 1}, {2, 7, 3}, {-2, 9, 1}, {2, 9, 3}}) do
			paved_prop("council_seat", seat[1], seat[2], seat[1], seat[2],
				function()
					parts.seat(buf, palette, seat[1], 1, seat[2], seat[3])
				end)
		end
		for _, wain in ipairs({{-12, -6}, {10, -6}}) do
			paved_prop("yard_wagon", wain[1], wain[2] - 1, wain[1] + 2, wain[2],
				function()
					return dressing.wagon(buf, palette, wain[1], wain[2], "x")
				end)
		end
		for _, mast in ipairs({{-12, -8}, {12, -8}, {-12, 10}, {12, 10}}) do
			paved_prop("yard_standard", mast[1], mast[2], mast[1], mast[2],
				function()
					dressing.standard(buf, palette, mast[1], mast[2], 4)
				end)
		end

		-- 9. The beast pen: straw ground under the byre, paddock rails and a
		-- gate, feed bales and a loaded wagon.
		if palette.maybe("ground_straw") then
			for z = -7, 1 do
				for x = -39, -29 do
					if layout.free(buf, x, z, 3) then
						buf:put(x, 0, z, palette.node("ground_straw"))
					end
				end
			end
		end
		-- The four rails share no cell: a run that starts where the last one
		-- ended is a prop refused for standing on itself.
		for _, rail in ipairs({{-40, -20, -22, -20}, {-40, -19, -40, -10},
				{-22, -19, -22, -10}, {-26, -10, -23, -10}}) do
			prop("paddock_rail", math.min(rail[1], rail[3]),
				math.min(rail[2], rail[4]), math.max(rail[1], rail[3]),
				math.max(rail[2], rail[4]), function()
					dressing.fence_line(buf, palette, rail[1], rail[2],
						rail[3], rail[4])
				end)
		end
		local gate = palette.maybe("fence_gate")
		if gate then
			buf:put(-31, 1, -20, gate, 0)
			buf:put(-32, 1, -20, gate, 0)
		end
		for _, stack in ipairs({{-27, -18, 2}, {-26, -18, 3}, {-27, -14, 2},
				{-38, -12, 2}, {-37, -12, 3}}) do
			prop("feed_bale", stack[1], stack[2], stack[1], stack[2], function()
				return dressing.bale_stack(buf, palette, stack[1], stack[2],
					stack[3])
			end)
		end
		for _, wain in ipairs({{-35, -17}, {-31, -13}}) do
			prop("pen_wagon", wain[1], wain[2] - 1, wain[1] + 2, wain[2],
				function()
					return dressing.wagon(buf, palette, wain[1], wain[2], "x")
				end)
		end

		-- 10. Camp gear between the plots: timber, barrels, more wagons, and
		-- the wheels left leaning where the carters left them.
		for _, pile in ipairs({{-22, 6, 4, "z"}, {20, 8, 3, "z"},
				{-24, -30, 3, "x"}, {24, -30, 3, "x"}, {-12, 24, 3, "z"}}) do
			local axis = pile[4]
			local x2 = axis == "x" and pile[1] + pile[3] - 1 or pile[1]
			local z2 = axis == "z" and pile[2] + pile[3] - 1 or pile[2]
			prop("wood_pile", pile[1], pile[2], x2, z2, function()
				dressing.wood_pile(buf, palette, pile[1], pile[2], pile[3],
					axis)
			end)
		end
		for _, crate in ipairs({{20, 3, 3}, {20, 4, 3}, {-22, 2, 1},
				{18, -20, 0}, {-20, -30, 0}, {-16, 12, 2}, {16, 16, 0}}) do
			prop("crates", crate[1], crate[2], crate[1], crate[2], function()
				dressing.crates(buf, palette, crate[1], crate[2], crate[3])
			end)
		end
		prop("hall_wagon", 26, 7, 28, 8, function()
			return dressing.wagon(buf, palette, 26, 8, "x")
		end)
		wall_prop("hall_wheel_west", "wheel", -8, 2, 18, 1, 0, 0)
		-- Both wheels hang on the hall's timber window frames; the adobe
		-- between them carries a slit, and a wheel on a barred slit hangs in
		-- the window.
		wall_prop("hall_wheel_north", "wheel", -8, 2, 22, 1, 0, 0)
		wall_prop("armoury_wheel", "wheel", 21, 2, 0, 1, 0, 0)
		wall_prop("bone_lodge_wheel", "wheel", 9, 2, -30, 1, 0, 0)

		-- 11. Standards down the road, where a war band would plant them.
		for _, mast in ipairs({{-6, -20}, {6, -20}, {-6, -40}, {6, -40},
				{-8, -50}, {8, -50}}) do
			prop("road_standard", mast[1], mast[2], mast[1], mast[2], function()
				dressing.standard(buf, palette, mast[1], mast[2], 4)
			end)
		end

		-- 12. Acacias on the flats.
		local trees = 0
		for _, block in ipairs(GROVES) do
			trees = trees + layout.plant_orchard(buf, palette, block[1],
				block[2], block[3], block[4], block[5], block[6], "acacia")
		end

		-- 13. Route lighting: the road out to the gate, then the lanes and
		-- the yard.
		layout.street_lamps(buf, palette, 0, -60, -4, 7, outdoors)
		for _, spot in ipairs({{-14, -2}, {14, -2}, {-14, 12}, {14, 12},
				{-20, -2}, {20, -4}, {-30, -2}, {-34, 14}, {-24, 14},
				{-12, 14}, {4, 12}, {-4, 12}, {-12, -21}, {12, -21},
				{-24, -21}, {20, -21}, {-6, -25}, {6, -25},
				{-12, -8}, {12, -8}, {-12, 10}, {12, 10}}) do
			if outdoors(spot[1], spot[2]) and
					layout.free(buf, spot[1], spot[2], 3) then
				dressing.path_light(buf, palette, spot[1], spot[2])
			end
		end

		-- 14. Dry flora on whatever open ground is left.
		-- Density 6, not the 4 the wooded starts use: at 4 the sieve
		-- `(7x + 11z) % d` collapses onto `(x + z) % 4`, which is exactly the
		-- test that chooses between shrub and tuft, so every planted cell
		-- came out a dead shrub and the flats read as a bush field. At 6 the
		-- two tests are independent again and the ground is mostly ochre
		-- tufts with shrubs scattered through them.
		dressing.undergrowth(buf, palette, -RADIUS, -RADIUS, RADIUS, RADIUS, 6)

		-- 15. Pane shapes, settled once over the finished pad for the reason
		-- written in `parts.resolve_panes`.
		parts.resolve_panes(buf)

		-- 16. Canonical cell list, bounds and palette.
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
				error("wp13 sunscar: destination " .. id .. " is missing", 0)
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
			error("wp13 sunscar: no door for " .. id, 0)
		end

		-- The merlon population, counted AFTER the two cuts above: the
		-- landmark is what stands, not what was raised. The first version
		-- published `dressing.parapet`'s return, which is the ring's cell
		-- count and includes every plain wall cell between the merlons.
		local merlon_node = palette.node("wall_accent")
		local merlons = 0
		for _, cap in ipairs(merlon_caps) do
			local cell = buf:at(cap.x, cap.y, cap.z)
			if cell ~= nil and cell.name == merlon_node then
				merlons = merlons + 1
			end
		end

		return {
			schema = SCHEMA,
			cells = cells,
			bounds = {min = minp, max = maxp},
			palette = palette_list,
			landmarks = {
				spawn = {x = 0, y = 1, z = 0},
				arrival = {x = 0, y = 1, z = 0},
				gate = {x = 0, y = 1, z = EXIT * RADIUS},
				muster_yard = {min = {x = YARD.x1, y = 0, z = YARD.z1},
					max = {x = YARD.x2, y = 4, z = YARD.z2}},
				main_street = {min = {x = -2, y = 0, z = -RADIUS},
					max = {x = 2, y = 3, z = 0}},
				warlord_hall = box("warlord_hall", 2, 3),
				warlord_hall_door = door_of("warlord_hall"),
				armoury = box("armoury", 2, 3),
				armoury_door = door_of("armoury"),
				beast_pen = box("beast_pen", 2, 3),
				chief_lodge = box("chief_lodge", 2, 3),
				chief_lodge_door = door_of("chief_lodge"),
				spear_lodge = box("spear_lodge", 2, 3),
				tusk_lodge = box("tusk_lodge", 2, 3),
				bone_lodge = box("bone_lodge", 2, 3),
				west_tower = box("west_tower", 2, 3),
				east_tower = box("east_tower", 2, 3),
				gate_passage = {min = {x = -2, y = 1, z = -RADIUS},
					max = {x = 2, y = 5, z = -50}},
				destinations = destinations,
				doors = doorways,
				rooms = rooms,
				lights = lights,
				sockets = SOCKETS,
				merlon_cells = merlons,
				palisade_stakes = stakes,
				berm_cells = berm_cells,
				outcrop_cells = outcrop_cells,
				acacia_trees = trees,
			},
		}
	end
end

return loader
