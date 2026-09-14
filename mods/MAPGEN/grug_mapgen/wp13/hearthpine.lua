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
	local buildings = dofile(directory .. "/buildings.lua")(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local layout = dofile(directory .. "/layout.lua")(directory)

	local RADIUS = 63
	local SCHEMA = "grug_wp13_hearthpine_blueprint_v1"

	-- Plot roster. Each row is one placed building: landmark id, generator,
	-- its parameters, the pad anchor of the rotated footprint and the
	-- rotation that turns its door toward the path.
	local PLOTS = {
		{id = "forge_hall", make = "workshop", x = -5, z = -26, turns = 0,
			roof_material = "slate",
			spec = {w = 11, d = 15, wing = 7, wall_h = 5}},
		{id = "west_home", make = "cottage", x = -26, z = 2, turns = 3,
			spec = {w = 9, d = 9, roof = "gable", ridge_axis = "x"}},
		{id = "east_home", make = "cottage", x = 16, z = -4, turns = 1,
			spec = {w = 11, d = 9, roof = "hip", fancy_bed = true}},
		{id = "southwest_home", make = "cottage", x = -38, z = -20, turns = 2,
			spec = {w = 9, d = 9, roof = "saltbox", ridge_axis = "x", lift = 2}},
		{id = "east_gable_home", make = "cottage", x = 30, z = -8, turns = 0,
			spec = {w = 11, d = 9, roof = "gable", ridge_axis = "x"}},
		{id = "lagerhouse", make = "longhouse", x = 14, z = 22, turns = 0,
			spec = {w = 9, d = 13}},
		{id = "community_hall", make = "hall", x = -34, z = 28, turns = 0,
			roof_material = "slate",
			spec = {w = 13, d = 15, wall_h = 5}},
		{id = "workyard", make = "shed", x = -32, z = 14, turns = 0,
			spec = {w = 13, d = 9, open_sides = {"z-", "x+"}}},
		{id = "gatewatch", make = "watchpost", x = -12, z = 50, turns = 2,
			spec = {door_side = "x-"}},
	}

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

	-- Not every roof is pine. The two civic buildings -- the forge hall and
	-- the community hall -- carry a stone-brick roof, which is the same
	-- rasterised stair family in a different material, so the roof generator
	-- needs no change and the village reads as more than one trade.
	local SLATE_ROOF = {
		roof_stair = "stairs:stair_stonebrick",
		roof_stair_outer = "stairs:stair_outer_stonebrick",
		roof_stair_inner = "stairs:stair_inner_stonebrick",
		roof_slab = "stairs:slab_stonebrick",
		roof_ridge = "default:stonebrick",
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
		{id = "idle_west_door", role = "idle", tags = {"door"}, x = -16, y = 1,
			z = 4, dir = {x = -1, z = 0}},
		{id = "idle_plaza_bench", role = "idle", tags = {"bench"}, x = 7, y = 1,
			z = 1, dir = {x = 1, z = 0}},
		{id = "idle_workyard", role = "idle", tags = {"work"}, x = -19, y = 1,
			z = 17, dir = {x = -1, z = 0}},
		{id = "idle_forge_door", role = "idle", tags = {"fire"}, x = 2, y = 1,
			z = -10, dir = {x = 0, z = -1}},
		{id = "hall_quest", role = "quest", x = -28, y = 1, z = 26,
			dir = {x = 0, z = 1}},
	}

	return function()
		local palette = palettes.new("dwarf")
		local slate = palettes.new("dwarf", SLATE_ROOF)
		local buf = parts.buffer()
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

		-- 3. Buildings.
		for _, plot in ipairs(PLOTS) do
			local spec = {}
			for key, value in pairs(plot.spec) do spec[key] = value end
			spec.id = plot.id
			if plot.roof_material == "slate" then spec.roof_palette = slate end
			local part = buildings[plot.make](palette, spec)
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
		for _, seat in ipairs({{-33, 25, 0, "x"}, {12, 16, 2, "x"},
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

		-- 8. Planting: the pine wood the clearing was cut from, then
		-- scattered undergrowth on whatever soil is still open.
		layout.plant_wood(buf, palette, RADIUS, 5)
		dressing.vale_undergrowth(buf, palette, -RADIUS, -RADIUS, RADIUS, RADIUS, 5)

		-- 9. Pane shapes. `xpanes` settles a pane's node and param2 from its
		-- horizontal neighbours in `update_pane`, which the engine runs from
		-- `register_on_placenode` and therefore never for a VoxelManip write.
		-- Every neighbour is now in the buffer, so the decision can be made
		-- exactly, once, over the finished pad.
		parts.resolve_panes(buf)

		-- 10. Canonical cell list, bounds and palette.
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
				sockets = SOCKETS,
			},
		}
	end
end

return loader
