-- Hearthpine Vale: the dwarf start settlement, composed from the WP13
-- building library.
--
-- Authored in local coordinates around the dwarf spawn; the caller fits
-- y = 0 to the fitted start terrain before projecting the cells. The result
-- is the `grug_wp13_hearthpine_blueprint_v1` payload that
-- `wp40/r7_hearthpine_blueprint.lua` returns unchanged.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local palettes = dofile(directory .. "/palette.lua")
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local decor = dofile(directory .. "/decor_kit.lua")(directory)
	local layout = dofile(directory .. "/layout.lua")(directory)

	local RADIUS = 63
	local SCHEMA = "grug_wp13_hearthpine_blueprint_v1"

	-- The buildings are building templates (Round 56): the layout
	-- `building_templates/layouts/hearthpine.layout` places them in stamp
	-- order, with the slate roof palette of the forge hall and the community
	-- hall.
	local templates = dofile(directory .. "/templates.lua")(directory)
	local TOWN = templates.town("hearthpine")

	-- Paved approaches. The first row is the cross street that serves the
	-- forge, the south-west home and the east gable home; the rest are short
	-- branches from one doorstep to the street or the plaza. Every rectangle
	-- stops one node short of the nearest wall course.
	local PATHS = {
		{-36, -11, 37, -9},
		{-17, 5, -10, 7},
		{10, 0, 15, 2},
		{2, 19, 18, 21},
		{-29, 25, -2, 27},
		{-19, 17, -2, 19},
		{-3, 53, -2, 55},
	}

	-- Destination order is part of the consumer contract and never changes.
	local DESTINATION_ORDER = {"forge_hall", "west_home", "east_home",
		"workyard", "gatewatch_roof", "southwest_home", "east_gable_home",
		"lagerhouse", "community_hall"}

	-- The watchpost lookout keeps its historical destination id.
	local DESTINATION_ID = {gatewatch = "gatewatch_roof"}

	-- The waypoint pad (Round 29, WP17) and its mailbox, at the town's centre
	-- next to the Quartermaster (Round 58, the user's ruling of 2026-10-22):
	-- on the arrival plaza beside the spawn, west of the market stall and the
	-- Quartermaster at its end.
	local WAYPOINT = {x = 2, z = -2}

	-- NPC sockets: the named standing positions this settlement exports for
	-- the runtime mods (docs/research/wp13-npc-sockets-contract.md section 2).
	-- Anchor-relative like every other landmark, in a fixed authored order;
	-- `y` is the node the entity stands IN, so that cell and the one above it
	-- are air and the node under it is walkable. `dir` is the facing as one
	-- of the four axis vectors. Sockets are not identity bytes -- the
	-- settlement identity SHA covers schema, bounds, palette and cells only --
	-- but the WP13 blueprint KAT (retired in Round 22) checked every one of
	-- them against the finished pad.
	local SOCKETS = {
		-- The gate watch: one post either side of the road, inside the gate
		-- line at z = 60, both facing the road out of the vale.
		{id = "gate_west", role = "guard_post", x = -4, y = 1, z = 59,
			dir = {x = 0, z = 1}},
		{id = "gate_east", role = "guard_post", x = 4, y = 1, z = 59,
			dir = {x = 0, z = 1}},
		-- One loop: gate, main street, the plaza's two flanks and the forge
		-- front. Consumers walk it in `order` and wrap around.
		{id = "watch_gate", role = "guard_patrol", group = "vale", order = 1,
			x = 0, y = 1, z = 52, dir = {x = 0, z = 1}},
		{id = "watch_street", role = "guard_patrol", group = "vale", order = 2,
			x = 0, y = 1, z = 24, dir = {x = 0, z = -1}},
		{id = "watch_plaza_west", role = "guard_patrol", group = "vale",
			order = 3, x = -9, y = 1, z = 2, dir = {x = -1, z = 0}},
		{id = "watch_forge", role = "guard_patrol", group = "vale", order = 4,
			x = 0, y = 1, z = -6, dir = {x = 0, z = -1}},
		{id = "watch_plaza_east", role = "guard_patrol", group = "vale",
			order = 5, x = 9, y = 1, z = 2, dir = {x = 1, z = 0}},
		-- The race vendor stands beside the market stall on the arrival
		-- plaza, facing across it.
		{id = "plaza_vendor", role = "vendor", kind = "race", x = 7, y = 1,
			z = -5, dir = {x = -1, z = 0}},
		-- `building`: the point stands at that building's door and is a point
		-- of its template (Round 56); the position comes from the stamp.
		{id = "idle_west_door", role = "idle", tags = {"door"},
			building = "west_home"},
		{id = "idle_plaza_bench", role = "idle", tags = {"bench"}, x = 7, y = 1,
			z = 1, dir = {x = 1, z = 0}},
		{id = "idle_workyard", role = "idle", tags = {"work"}, x = -19, y = 1,
			z = 17, dir = {x = -1, z = 0}},
		-- Round 47: turned round to the plaza; it faced the forge's door post.
		{id = "idle_forge_door", role = "idle", tags = {"fire"}, x = 2, y = 1,
			z = -10, dir = {x = 0, z = 1}},
		--
		-- WORKPLACES (playtest round 3, contract section 8.1). A `work` socket
		-- is a spawn socket like an `idle` one and its resident never leaves
		-- it: it stands there, faces the feature its `dir` names and plays the
		-- animation its `activity` names. Both of these are at features the
		-- vale ALREADY has -- there is no new cell, so the settlement identity
		-- is untouched -- and the WP13 blueprint KAT (retired in Round 22)
		-- measured the feature under the facing as well as every standing rule.
		--
		-- A woodcutter at the pines above the lane, and a gardener at the tufts
		-- beside the workyard.
		{id = "work_woodpile", role = "work", activity = "chop",
			tags = {"work"}, x = -12, y = 1, z = -13, dir = {x = 0, z = -1}},
		-- The tuft is the node in FRONT of the socket, not two nodes behind a
		-- pine trunk: the first version of this socket stood at (-19, 14)
		-- looking east at a trunk with grass behind it, which passed the
		-- feature test until that test learned to stop at an obstruction, and
		-- in the engine was a gardener who could not walk back to its own spot.
		{id = "work_garden", role = "work", activity = "tend", tags = {"work"},
			x = -19, y = 1, z = 21, dir = {x = 1, z = 0}},
		-- `door`: the elder faces the hall door it stands at, and the consumer
		-- turns it round to the street (start_npcs.lua `socket_face_yaw`).
		{id = "hall_quest", role = "quest", tags = {"door"},
			building = "community_hall"},
		-- The travel waystone at the centre of the waypoint pad (WP17); nobody
		-- stands here, grug_home reads it.
		{id = "travel_waypoint", role = "waypoint", x = WAYPOINT.x, y = 1,
			z = WAYPOINT.z, dir = {x = 0, z = 1}},
		--
		-- SPARE IDLE SPOTS (playtest round 2, 2026-09-15). `spawn = false` is
		-- what makes them wander TARGETS and never homes: the roster places one
		-- villager per SPAWN socket, and `next_spot` walks every idle socket. With
		-- exactly as many spots as villagers every spot is always occupied and the
		-- amble is four people swapping four chairs, which is what the playtest
		-- saw. Each one is a legal standing position on the finished pad -- feet
		-- and head air, walkable settlement ground under it, outdoors, reachable
		-- on foot -- measured by the retired WP13 blueprint KAT's socket test,
		-- and no tag, because a spare is a place to stand rather than a feature to
		-- talk about.
		-- the litter east of the street
		{id = "idle_spare_1", role = "idle", spawn = false, x = 7,
			y = 1, z = 9, dir = {x = 0, z = -1}},
		-- the litter west of the street
		{id = "idle_spare_2", role = "idle", spawn = false, x = -8,
			y = 1, z = 9, dir = {x = 0, z = -1}},
		-- the cobble south of the forge
		{id = "idle_spare_3", role = "idle", spawn = false, x = -6,
			y = 1, z = -13, dir = {x = 0, z = 1}},
	}

	return function()
		local palette = palettes.new("dwarf")
		local buf = parts.buffer()
		-- Round 51 follow-up FT: half the start's trees (`dressing.grown`).
		buf.tree_share = 2
		local lights, doorways, rooms = {}, {}, {}
		local placed, inside_by_id = {}, {}
		-- The same plots in roster order. `placed` is keyed by landmark id and
		-- can only be walked with `pairs`; the ordered copy lets the footprint
		-- test below run over an array with `ipairs` instead.
		local plot_order = {}

		-- Outside every building footprint: an empty room has free ground and
		-- headroom, but no street lamp belongs in it.
		local function outdoors(x, z)
			for _, plot in ipairs(plot_order) do
				if x >= plot.x and x <= plot.x + plot.w - 1 and
						z >= plot.z and z <= plot.z + plot.d - 1 then
					return false
				end
			end
			return true
		end

		-- Plaza furniture only needs clear space; it stands on paving.
		local function paved_prop(x1, z1, x2, z2, build)
			if not layout.free_area(buf, x1, z1, x2, z2, 4) then return false end
			build()
			return true
		end

		-- A prop is only built where nothing else stands on natural ground.
		local function prop(x1, z1, x2, z2, build)
			if not layout.free_area(buf, x1, z1, x2, z2, 4) then return false end
			for z = z1, z2 do
				for x = x1, x2 do
					if not layout.natural(buf, x, z) then return false end
				end
			end
			build()
			return true
		end

		-- 1. Pad ground.
		layout.ground(buf, palette, RADIUS)

		-- 2. Arrival road, plaza and its masonry band.
		layout.pave(buf, palette, -11, -10, 11, 7, "plaza_edge", 4)
		layout.pave(buf, palette, -10, -9, 10, 6, "plaza", 4)
		layout.pave(buf, palette, -2, -9, 2, RADIUS, "path", 3)

		-- 3. Buildings, the layout's placements in stamp order.
		local stamped_sockets = {}
		for _, place in ipairs(TOWN.places) do
			local part = TOWN.part(place)
			local points = parts.stamp(buf, part, place.x, place.y, place.z,
				place.turns)
			local footprint = points.footprint[1]
			placed[place.id] = {x = place.x, z = place.z,
				w = footprint.w, d = footprint.d, peak = part.peak}
			plot_order[#plot_order + 1] = placed[place.id]
			for _, door in ipairs(points.doors) do
				doorways[#doorways + 1] = {x = door.x, y = door.y, z = door.z,
					face = door.face, id = place.id}
			end
			local spot = points.inside[1]
			inside_by_id[DESTINATION_ID[place.id] or place.id] =
				{x = spot.x, y = spot.y, z = spot.z}
			for index = 1, #points.room_corner, 2 do
				local a, b = points.room_corner[index], points.room_corner[index + 1]
				rooms[#rooms + 1] = {
					min = {x = math.min(a.x, b.x), y = a.y, z = math.min(a.z, b.z)},
					max = {x = math.max(a.x, b.x), y = a.y, z = math.max(a.z, b.z)},
					top = a.top, closed = a.closed, id = place.id,
				}
			end
			templates.collect_sockets(stamped_sockets, points, place.id)
		end
		local sockets = templates.sockets(SOCKETS, stamped_sockets, "hearthpine")

		-- 4. Paved approaches from every doorstep to the street or the plaza.
		for _, rect in ipairs(PATHS) do
			layout.pave(buf, palette, rect[1], rect[2], rect[3], rect[4], "path", 3)
		end

		-- 5. The gate: two log standards, a lintel beam, flanking low walls
		-- and two torches over the road.
		for _, x in ipairs({-3, 3}) do
			for y = 1, 5 do buf:put(x, y, 60, palette.node("post")) end
		end
		for x = -2, 2 do buf:put(x, 5, 60, palette.node("beam")) end
		for _, side in ipairs({{-2, -1}, {2, 1}}) do
			parts.wall_torch(buf, palette, side[1], 4, 60, side[2], 0, 0)
		end
		dressing.low_wall_line(buf, palette, -9, 60, -4, 60)
		dressing.low_wall_line(buf, palette, 4, 60, 9, 60)

		-- 6. Exterior dressing between the plots. The arrival plaza first:
		-- an inlaid band, the draw well, a market stall and seating.
		dressing.inlay(buf, palette, -7, -6, 7, 3)
		dressing.well(buf, palette, -6, -4)
		dressing.signpost(buf, palette, 8, -4)
		paved_prop(3, -7, 7, -3, function()
			dressing.stall(buf, palette, 4, -6, 2)
		end)
		paved_prop(-8, -8, -8, -6, function()
			dressing.bench(buf, palette, -8, -8, 1, 3, "z")
		end)
		paved_prop(8, 0, 8, 2, function()
			dressing.bench(buf, palette, 8, 0, 3, 3, "z")
		end)
		paved_prop(-8, 0, -8, 2, function()
			dressing.bench(buf, palette, -8, 0, 1, 3, "z")
		end)
		paved_prop(8, -7, 8, -6, function()
			dressing.crates(buf, palette, 8, -7, 3)
			dressing.crates(buf, palette, 8, -6, 3)
		end)
		paved_prop(5, 2, 9, 5, function()
			dressing.planter(buf, palette, 5, 2, 9, 5)
		end)
		paved_prop(-9, 2, -5, 5, function()
			dressing.planter(buf, palette, -9, 2, -5, 5)
		end)

		-- Gardens, kerbs and yard goods around the plots.
		local FENCES = {
			{-28, 0, -18, 0}, {-28, 0, -28, 12}, {-28, 12, -18, 12},
			{26, -6, 26, 8}, {16, 8, 26, 8},
			{29, 2, 41, 2}, {42, -8, 42, 2},
			{13, 36, 23, 36},
		}
		for _, line in ipairs(FENCES) do
			prop(line[1], line[2], line[3], line[4], function()
				dressing.fence_line(buf, palette, line[1], line[2], line[3], line[4])
			end)
		end
		local KERBS = {
			{-40, -21, -40, -11}, {-36, 27, -36, 43}, {-20, 44, -6, 44},
			{12, 8, 12, 18},
		}
		for _, line in ipairs(KERBS) do
			prop(line[1], line[2], line[3], line[4], function()
				dressing.low_wall_line(buf, palette, line[1], line[2],
					line[3], line[4])
			end)
		end
		local PILES = {
			{-35, 16, 4, "z"}, {-35, 22, 3, "x"}, {-18, 14, 3, "z"},
			{-6, -29, 4, "x"}, {24, 20, 3, "x"}, {8, 24, 3, "z"},
		}
		for _, pile in ipairs(PILES) do
			local axis = pile[4]
			local x2 = axis == "x" and pile[1] + pile[3] - 1 or pile[1]
			local z2 = axis == "z" and pile[2] + pile[3] - 1 or pile[2]
			prop(pile[1], pile[2], x2, z2, function()
				dressing.wood_pile(buf, palette, pile[1], pile[2], pile[3], axis)
			end)
		end
		for _, crate in ipairs({{-18, 18, 1}, {-18, 19, 1}, {24, 18, 0},
				{-20, -29, 2}}) do
			prop(crate[1], crate[2], crate[1], crate[2], function()
				dressing.crates(buf, palette, crate[1], crate[2], crate[3])
			end)
		end
		for _, bed in ipairs({{-16, 0, -13, 3}, {26, -5, 28, -2},
				{-33, 44, -30, 47}, {12, 12, 15, 15}, {-45, -14, -42, -11}}) do
			prop(bed[1], bed[2], bed[3], bed[4], function()
				dressing.planter(buf, palette, bed[1], bed[2], bed[3], bed[4])
			end)
		end
		for _, seat in ipairs({{-33, 25, 2, "x"}, {12, 16, 2, "x"},
				{-16, 12, 2, "x"}, {26, 10, 0, "x"}}) do
			prop(seat[1], seat[2], seat[1] + 2, seat[2], function()
				dressing.bench(buf, palette, seat[1], seat[2], seat[3], 3, "x")
			end)
		end

		-- 7. Warm route lighting.
		layout.street_lamps(buf, palette, 0, 2, 62, 7, outdoors)
		for _, spot in ipairs({{-9, -8}, {9, -8},
				{-30, -10}, {30, -10},
				{-17, 8}, {13, 1}, {-18, 16}, {12, 21},
				{-30, 26}, {-6, 44}, {28, 1}, {-41, -11}}) do
			if outdoors(spot[1], spot[2]) and
					layout.free(buf, spot[1], spot[2], 3) then
				dressing.path_light(buf, palette, spot[1], spot[2])
			end
		end

		-- 8b. The waypoint pad, before the planting so nothing grows on it.
		dressing.waypoint_pad(buf, palette, WAYPOINT.x, WAYPOINT.z, "hearthpine")

		-- 8. Planting: the pine wood the clearing was cut from, then
		-- scattered undergrowth on whatever soil is still open.
		layout.plant_wood(buf, palette, RADIUS, 5)

		-- 8c. Every house's small touches (Round 36 decor kit): a barrel or a
		-- pot by the door, flowers under the windows, a wood pile or a barrel
		-- against a side wall; never on a socket or the cell before it. They
		-- stay town work, not template content (Round 56): the paved
		-- approaches of step 4 clear the headroom of touches the kit stands on
		-- them, so written at the stamp, nine of them would be lost.
		decor.dress_rooms(buf, palette, rooms, doorways, sockets,
			{palette.node("foundation"), palette.node("path"), palette.maybe("ground_straw")})

		dressing.vale_undergrowth(buf, palette, -RADIUS, -RADIUS, RADIUS, RADIUS, 5)

		-- 9. Pane shapes. `xpanes` settles a pane's node and param2 from its
		-- horizontal neighbours in `update_pane`, which the engine runs from
		-- `register_on_placenode` and therefore never for a VoxelManip write.
		-- Every neighbour is now in the buffer, so the decision can be made
		-- exactly, once, over the finished pad.
		parts.resolve_panes(buf)

		-- 10. Canonical cell list, bounds and palette.
		-- Round 47 town greening: the race's trees on the open wild ground.
		layout.green(buf, palette, RADIUS, sockets, doorways)
		local source, count = buf:cells()
		local cells = {}
		for index = 1, count do cells[index] = source[index] end
		parts.sort_cells_zyx(cells)
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
				error("wp13 hearthpine: destination " .. id .. " is missing", 0)
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
			error("wp13 hearthpine: no door for " .. id, 0)
		end

		return {
			schema = SCHEMA,
			cells = cells,
			bounds = {min = minp, max = maxp},
			palette = palette_list,
			landmarks = {
				spawn = {x = 0, y = 1, z = 0},
				arrival = {x = 0, y = 1, z = 0},
				gate = {x = 0, y = 1, z = RADIUS},
				arrival_plaza = {min = {x = -10, y = 0, z = -9},
					max = {x = 10, y = 4, z = 6}},
				main_street = {min = {x = -2, y = 0, z = 0},
					max = {x = 2, y = 3, z = RADIUS}},
				forge_hall = box("forge_hall", 2, 3),
				forge_hall_door = door_of("forge_hall"),
				west_home = box("west_home", 2, 3),
				west_home_door = door_of("west_home"),
				east_home = box("east_home", 2, 3),
				east_home_door = door_of("east_home"),
				workyard = box("workyard", 2, 3),
				gatewatch = box("gatewatch", 2, 3),
				gate_passage = {min = {x = -2, y = 1, z = 50},
					max = {x = 2, y = 5, z = RADIUS}},
				southwest_home = box("southwest_home", 2, 3),
				east_gable_home = box("east_gable_home", 2, 3),
				lagerhouse = box("lagerhouse", 2, 3),
				community_hall = box("community_hall", 2, 3),
				destinations = destinations,
				doors = doorways,
				rooms = rooms,
				lights = lights,
				sockets = sockets,
			},
		}
	end
end

return loader
