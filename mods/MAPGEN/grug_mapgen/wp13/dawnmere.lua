-- Dawnmere Fields: the human start settlement, composed from the WP13
-- building library.
--
-- Hearthpine is a craft settlement in a pine clearing; Dawnmere is a farming
-- hamlet on open meadow, and the difference is meant to be legible from the
-- gate: turf instead of needle litter, a village green instead of a paved
-- plaza, half-timbered loam walls under plank roofs instead of pine boards
-- under pine shingles, and fenced crop fields, hedgerows and an orchard
-- instead of a wood.
--
-- Authored in local coordinates around the human spawn; the caller fits
-- y = 0 to the fitted start terrain before projecting the cells. The result
-- is the `grug_wp13_dawnmere_blueprint_v1` payload that
-- `wp40/r7_dawnmere_blueprint.lua` returns unchanged.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local palettes = dofile(directory .. "/palette.lua")
	local buildings = dofile(directory .. "/buildings.lua")(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local layout = dofile(directory .. "/layout.lua")(directory)

	local RADIUS = 63
	local SCHEMA = "grug_wp13_dawnmere_blueprint_v1"

	-- The hamlet is organised on three lanes off the village green: the south
	-- lane in front of the cottages, and a west and an east lane out to the
	-- farmyard and the smithy. The north road to the gate is the contract's
	-- five wide route and carries no plot.
	local GREEN = {x1 = -11, z1 = -9, x2 = 11, z2 = 7}
	local LANES = {
		{-2, -18, 2, RADIUS},            -- the road, green to gate
		{-36, -17, 36, -15},             -- south lane
		{-20, -17, -18, 34},             -- west lane
		{18, -17, 20, 34},               -- east lane
		{-18, -2, -11, 0},               -- green to west lane
		{11, -2, 18, 0},                 -- green to east lane
		{-13, 8, -9, 9},                 -- meeting hall doorstep
		{9, 8, 13, 9},                   -- inn doorstep
		{21, -1, 23, 1},                 -- smithy doorstep
		{3, 51, 4, 53},                  -- tollhouse doorstep
	}

	-- Plot roster. Each row is one placed building: landmark id, generator,
	-- its parameters, the pad anchor of the rotated footprint and the
	-- rotation that turns its door toward the lane.
	local PLOTS = {
		{id = "meeting_hall", make = "chapel", x = -16, z = 10, turns = 0,
			roof_material = "tile",
			spec = {w = 11, d = 15, wall_h = 6, shutters = true}},
		{id = "harvest_inn", make = "longhouse", x = 6, z = 10, turns = 0,
			spec = {w = 11, d = 15, wall_h = 5, kit = "inn", infill = true,
				shutters = true}},
		{id = "great_barn", make = "barn", x = -33, z = -6, turns = 0,
			spec = {w = 13, d = 11, wall_h = 6, door_side = "x+",
				door_index = 6, infill = true}},
		{id = "smithy", make = "workshop", x = 24, z = -6, turns = 0,
			roof_material = "tile",
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-"}},
		{id = "orchard_cottage", make = "cottage", x = -30, z = -26, turns = 0,
			spec = {w = 9, d = 9, wall_h = 5, roof = "gable", ridge_axis = "x",
				door_side = "z+", door_index = 3, infill = true,
				shutters = true}},
		{id = "lane_cottage", make = "cottage", x = -14, z = -26, turns = 0,
			spec = {w = 9, d = 9, wall_h = 5, roof = "hip", door_side = "z+",
				door_index = 4, shutters = true, fancy_bed = true}},
		{id = "green_cottage", make = "cottage", x = 6, z = -26, turns = 0,
			spec = {w = 9, d = 9, wall_h = 5, roof = "saltbox", ridge_axis = "x", lift = 2,
				door_side = "z+", door_index = 4, infill = true,
				shutters = true}},
		{id = "field_cottage", make = "cottage", x = 22, z = -26, turns = 0,
			spec = {w = 11, d = 9, wall_h = 5, roof = "gable", ridge_axis = "z",
				door_side = "z+", door_index = 5, shutters = true}},
		{id = "tollhouse", make = "watchpost", x = 5, z = 48, turns = 0,
			roof_material = "tile", spec = {door_side = "x-"}},
	}

	-- Destination order is part of the consumer contract and never changes.
	local DESTINATION_ORDER = {"meeting_hall", "harvest_inn", "great_barn",
		"smithy", "orchard_cottage", "lane_cottage", "green_cottage",
		"field_cottage", "tollhouse_roof"}

	local DESTINATION_ID = {tollhouse = "tollhouse_roof"}

	-- The two public buildings carry a brick roof instead of a plank one, in
	-- the same rasterised stair family, so the civic core reads as the part of
	-- the hamlet that was built to last.
	local TILE_ROOF = {
		roof_stair = "stairs:stair_brick",
		roof_stair_outer = "stairs:stair_outer_brick",
		roof_stair_inner = "stairs:stair_inner_brick",
		roof_slab = "stairs:slab_brick",
		roof_ridge = "default:brick",
	}

	-- Fenced fields, each a rectangle of furrows with a headland inside its
	-- fence. `axis` names the direction the rows run.
	local FIELDS = {
		{-60, -13, -38, 11, "z"},
		{-60, -42, -40, -21, "x"},
		{42, -12, 60, 12, "z"},
		{38, -42, 60, -22, "x"},
		{-42, 30, -16, 52, "x"},
		{16, 30, 36, 52, "x"},
		{-34, -60, -10, -44, "x"},
		{10, -60, 34, -44, "x"},
	}

	-- Hedgerows on the outer boundaries of the fields.
	local HEDGES = {
		{-62, 13, -36, 13}, {-62, -15, -62, 13},
		{-62, -44, -38, -44}, {-38, -44, -38, -19},
		{40, 14, 62, 14}, {62, -14, 62, 14},
		{36, -44, 62, -44}, {36, -44, 36, -20},
		{-44, 28, -14, 28}, {-44, 28, -44, 54},
		{14, 28, 38, 28}, {38, 28, 38, 54},
		{-36, -62, -8, -62}, {-36, -62, -36, -46},
		{8, -62, 36, -62}, {36, -62, 36, -46},
	}

	return function()
		local palette = palettes.new("human")
		local tile = palettes.new("human", TILE_ROOF)
		local buf = parts.buffer()
		local lights, doorways, rooms = {}, {}, {}
		local placed, inside_by_id = {}, {}

		local function outdoors(x, z)
			for _, plot in pairs(placed) do
				if x >= plot.x and x <= plot.x + plot.w - 1 and
						z >= plot.z and z <= plot.z + plot.d - 1 then
					return false
				end
			end
			return true
		end

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

		local function paved_prop(x1, z1, x2, z2, build)
			if not layout.free_area(buf, x1, z1, x2, z2, 4) then return false end
			build()
			return true
		end

		-- 1. Meadow ground.
		layout.meadow(buf, palette, RADIUS, 32)

		-- 2. The village green, its brick kerb, and the lanes off it. The
		-- green itself stays turf: this hamlet has no paved plaza.
		dressing.inlay(buf, palette, GREEN.x1, GREEN.z1, GREEN.x2, GREEN.z2)
		for _, lane in ipairs(LANES) do
			layout.pave(buf, palette, lane[1], lane[2], lane[3], lane[4],
				"path", 4)
		end

		-- 3. Buildings.
		for _, plot in ipairs(PLOTS) do
			local spec = {}
			for key, value in pairs(plot.spec) do spec[key] = value end
			spec.id = plot.id
			if plot.roof_material == "tile" then spec.roof_palette = tile end
			local part = buildings[plot.make](palette, spec)
			local points = parts.stamp(buf, part, plot.x, 0, plot.z, plot.turns)
			local footprint = points.footprint[1]
			placed[plot.id] = {x = plot.x, z = plot.z,
				w = footprint.w, d = footprint.d, peak = part.peak}
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

		-- 4. The belfry on the meeting hall's ridge: the one silhouette that
		-- marks the hamlet's centre from the fields.
		do
			local hall = placed.meeting_hall
			local belfry = buildings.belfry(palette,
				{height = 3, roof_palette = tile})
			parts.stamp(buf, belfry, hall.x + 3, hall.peak, hall.z + 5, 0)
		end

		-- 5. The gate: two brick piers on cobble footings under a timber
		-- lintel, torches over the road and low walls to either side.
		for _, x in ipairs({-3, 3}) do
			for y = 1, 5 do buf:put(x, y, 58, palette.node("wall_accent")) end
		end
		for x = -2, 2 do buf:put(x, 5, 58, palette.node("beam")) end
		for _, side in ipairs({{-2, -1}, {2, 1}}) do
			parts.wall_torch(buf, palette, side[1], 4, 58, side[2], 0, 0)
		end
		dressing.low_wall_line(buf, palette, -10, 58, -4, 58)
		dressing.low_wall_line(buf, palette, 4, 58, 10, 58)

		-- 6. The green: the draw well, the market stall the carrier's wagon
		-- pulls up to, the notice post, flower beds, settles and a hand cart
		-- left where the carter left it.
		dressing.well(buf, palette, -6, -3)
		dressing.signpost(buf, palette, 7, -4)
		paved_prop(3, 2, 7, 6, function()
			dressing.stall(buf, palette, 4, 3, 2)
		end)
		prop(-10, 2, -6, 5, function()
			dressing.flower_bed(buf, palette, -10, 2, -6, 5)
		end)
		prop(-10, -8, -8, -6, function()
			dressing.flower_bed(buf, palette, -10, -8, -8, -6)
		end)
		prop(8, -8, 10, -6, function()
			dressing.flower_bed(buf, palette, 8, -8, 10, -6)
		end)
		for _, seat in ipairs({{-4, 6, 2, "x"}, {-4, -8, 0, "x"},
				{4, -8, 0, "x"}, {-10, -1, 1, "z"}, {9, -1, 3, "z"}}) do
			prop(seat[1], seat[2], seat[1] + 2, seat[2], function()
				dressing.bench(buf, palette, seat[1], seat[2], seat[3], 3, "x")
			end)
		end
		prop(7, -7, 8, -7, function()
			dressing.handcart(buf, palette, 7, -7, "x")
		end)
		prop(-9, 6, -8, 6, function()
			dressing.handcart(buf, palette, -9, 6, "x")
		end)
		-- Stepping stones across the turf, from the green's kerb to the well
		-- and on to the lanes, so the green reads as walked on.
		dressing.stepping_line(buf, palette, -6, -1, -6, 1)
		dressing.stepping_line(buf, palette, -5, 1, -3, 1)
		dressing.stepping_line(buf, palette, 3, 1, 8, 1)
		dressing.stepping_line(buf, palette, -6, -6, -6, -5)
		dressing.stepping_line(buf, palette, -5, -6, -3, -6)
		dressing.stepping_line(buf, palette, -11, 6, -8, 6)
		dressing.stepping_line(buf, palette, 8, 6, 11, 6)

		-- 7. The farmyard around the barn: straw ground, bale stacks, barrels
		-- and a paddock fence.
		if palette.maybe("ground_straw") then
			for z = -10, -8 do
				for x = -32, -22 do
					if layout.natural(buf, x, z) and layout.free(buf, x, z, 3) then
						buf:put(x, 0, z, palette.node("ground_straw"))
					end
				end
			end
		end
		for _, stack in ipairs({{-32, -10, 2}, {-31, -10, 3}, {-24, -10, 2},
				{-23, -10, 2}}) do
			prop(stack[1], stack[2], stack[1], stack[2], function()
				dressing.bale_stack(buf, palette, stack[1], stack[2], stack[3])
			end)
		end
		prop(-27, -10, -26, -10, function()
			dressing.handcart(buf, palette, -27, -10, "x")
		end)
		-- Cart wheels left leaning on the barn and the inn gable.
		parts.wall_prop(buf, palette, "wheel", -34, 2, -2, 1, 0, 0)
		parts.wall_prop(buf, palette, "wheel", -34, 2, 0, 1, 0, 0)
		parts.wall_prop(buf, palette, "wheel", 17, 2, 14, -1, 0, 0)
		parts.wall_prop(buf, palette, "wheel", 17, 2, 16, -1, 0, 0)

		-- 8. Fields, their fences and their gates.
		local crop_cells = 0
		for _, field in ipairs(FIELDS) do
			local x1, z1, x2, z2, axis = field[1], field[2], field[3], field[4],
				field[5]
			if layout.free_area(buf, x1, z1, x2, z2, 3) then
				crop_cells = crop_cells +
					dressing.crop_rows(buf, palette, x1 + 1, z1 + 1, x2 - 1,
						z2 - 1, axis)
				dressing.fence_line(buf, palette, x1, z1, x2, z1)
				dressing.fence_line(buf, palette, x1, z2, x2, z2)
				dressing.fence_line(buf, palette, x1, z1, x1, z2)
				dressing.fence_line(buf, palette, x2, z1, x2, z2)
				local gate = palette.maybe("fence_gate")
				local mid = math.floor((x1 + x2) / 2)
				if gate then
					buf:put(mid, 1, z1, gate, 0)
					buf:put(mid, 1, z2, gate, 0)
				end
			end
		end

		-- 9. Hedgerows on the field boundaries.
		local hedge_cells = 0
		for _, line in ipairs(HEDGES) do
			if layout.free_area(buf, math.min(line[1], line[3]),
					math.min(line[2], line[4]), math.max(line[1], line[3]),
					math.max(line[2], line[4]), 3) then
				hedge_cells = hedge_cells +
					dressing.hedge_line(buf, palette, line[1], line[2],
						line[3], line[4], 2)
			end
		end

		-- 10. Kerbs, timber and props between the plots.
		local KERBS = {
			{-20, 36, -12, 36}, {12, 36, 20, 36},
			{-17, -20, -9, -20}, {7, -20, 15, -20},
		}
		for _, line in ipairs(KERBS) do
			prop(line[1], line[2], line[3], line[4], function()
				dressing.low_wall_line(buf, palette, line[1], line[2],
					line[3], line[4])
			end)
		end
		for _, pile in ipairs({{-22, 6, 4, "z"}, {22, 8, 3, "z"},
				{-36, -12, 3, "x"}, {26, 28, 3, "x"}}) do
			local axis = pile[4]
			local x2 = axis == "x" and pile[1] + pile[3] - 1 or pile[1]
			local z2 = axis == "z" and pile[2] + pile[3] - 1 or pile[2]
			prop(pile[1], pile[2], x2, z2, function()
				dressing.wood_pile(buf, palette, pile[1], pile[2], pile[3], axis)
			end)
		end
		for _, crate in ipairs({{22, 2, 3}, {22, 3, 3}, {-22, 2, 1},
				{-14, 12, 0}}) do
			prop(crate[1], crate[2], crate[1], crate[2], function()
				dressing.crates(buf, palette, crate[1], crate[2], crate[3])
			end)
		end

		-- 11. Orchards: apple standards on the proportions of the vendored
		-- apple tree, in two blocks either side of the civic core.
		local ORCHARDS = {
			{-44, 12, -24, 26, 4, 5}, {24, 12, 44, 26, 4, 5},
			{-58, -38, -44, -20, 6, 6}, {44, -38, 58, -20, 6, 6},
			{-10, 34, 8, 54, 6, 6}, {-34, -58, 34, -48, 7, 6},
			{-58, 34, -50, 54, 7, 6}, {50, 34, 58, 54, 7, 6},
		}
		local orchard = 0
		for _, block in ipairs(ORCHARDS) do
			orchard = orchard + layout.plant_orchard(buf, palette, block[1],
				block[2], block[3], block[4], block[5], block[6])
		end

		-- 12. Route lighting: the road, the three lanes and the green.
		layout.street_lamps(buf, palette, 0, 2, 56, 7, outdoors)
		for _, spot in ipairs({{-12, -3}, {12, -3}, {-12, 8}, {12, 8},
				{-19, -13}, {19, -13}, {-19, 12}, {19, 12},
				{-19, 28}, {19, 28}, {-12, -16}, {12, -16},
				{-30, -16}, {30, -16}, {-22, -2}, {-9, 8}, {9, 8},
				{-6, -8}, {6, -8}}) do
			if outdoors(spot[1], spot[2]) and
					layout.free(buf, spot[1], spot[2], 3) then
				dressing.path_light(buf, palette, spot[1], spot[2])
			end
		end

		-- 13. Meadow flora on whatever open turf is left.
		dressing.undergrowth(buf, palette, -RADIUS, -RADIUS, RADIUS, RADIUS, 4)

		-- 14. Pane shapes, settled once over the finished pad for the reason
		-- written in `parts.resolve_panes`.
		parts.resolve_panes(buf)

		-- 15. Canonical cell list, bounds and palette.
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
		table.sort(palette_list)

		local destinations = {}
		for _, id in ipairs(DESTINATION_ORDER) do
			local spot = inside_by_id[id]
			if not spot then
				error("wp13 dawnmere: destination " .. id .. " is missing", 0)
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
			error("wp13 dawnmere: no door for " .. id, 0)
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
				village_green = {min = {x = GREEN.x1, y = 0, z = GREEN.z1},
					max = {x = GREEN.x2, y = 4, z = GREEN.z2}},
				main_street = {min = {x = -2, y = 0, z = 0},
					max = {x = 2, y = 3, z = RADIUS}},
				meeting_hall = box("meeting_hall", 2, 9),
				meeting_hall_door = door_of("meeting_hall"),
				harvest_inn = box("harvest_inn", 2, 3),
				harvest_inn_door = door_of("harvest_inn"),
				great_barn = box("great_barn", 2, 3),
				great_barn_door = door_of("great_barn"),
				smithy = box("smithy", 2, 3),
				smithy_door = door_of("smithy"),
				orchard_cottage = box("orchard_cottage", 2, 3),
				lane_cottage = box("lane_cottage", 2, 3),
				green_cottage = box("green_cottage", 2, 3),
				field_cottage = box("field_cottage", 2, 3),
				tollhouse = box("tollhouse", 2, 3),
				gate_passage = {min = {x = -2, y = 1, z = 50},
					max = {x = 2, y = 5, z = RADIUS}},
				destinations = destinations,
				doors = doorways,
				rooms = rooms,
				lights = lights,
				crop_cells = crop_cells,
				hedge_cells = hedge_cells,
				orchard_trees = orchard,
			},
		}
	end
end

return loader
