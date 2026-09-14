-- Silverleaf Glade: the elf start settlement, composed from the WP13
-- building library.
--
-- Hearthpine is a craft settlement in a pine clearing and Dawnmere a farming
-- hamlet on open meadow. Silverleaf is neither: it is a glade cut into the
-- silverwood, and the difference is meant to be legible from the gate. The
-- ground is the elf forest's own silver litter, the paving is marble, the
-- houses are narrow and steep instead of broad and low, two of them stand on
-- marble terraces with railed fronts, the light is candle and hanging
-- lantern instead of pitch torch, and the whole place is roofed in pale
-- silver sandstone under columnar silverwood standards that overtop it.
--
-- Authored in local coordinates around the elf spawn; the caller fits y = 0
-- to the fitted start terrain before projecting the cells. The result is the
-- `grug_wp13_silverleaf_blueprint_v1` payload that
-- `wp40/r7_silverleaf_blueprint.lua` returns unchanged.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local palettes = dofile(directory .. "/palette.lua")
	local buildings = dofile(directory .. "/buildings.lua")(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local layout = dofile(directory .. "/layout.lua")(directory)

	local RADIUS = 63
	local SCHEMA = "grug_wp13_silverleaf_blueprint_v1"

	-- The moon court is the settlement's floor: one marble square around the
	-- spawn, with the crescent inlaid in pale block. Everything else hangs
	-- off two avenues that leave it east and west, and off the five-wide
	-- north road the contract reserves, which carries no plot.
	local COURT = {x1 = -13, z1 = -10, x2 = 13, z2 = 7}
	local CRESCENT = {x = 0, z = -4, outer = 20, inner = 13, offset = 3}

	local LANES = {
		{-2, 0, 2, RADIUS},        -- the road, court to gate
		{-2, -22, 2, -10},         -- the road's southern continuation
		{-24, 8, -3, 10},          -- west avenue
		{3, 8, 24, 10},            -- east avenue
		{-23, 11, -19, 17},        -- shrine approach
		{19, 11, 23, 15},          -- lore hall doorstep
		{-26, -22, -24, 10},       -- west lane
		{24, -22, 26, 10},         -- east lane
		{-40, -24, 40, -22},       -- south lane
		{-31, -2, -14, 0},         -- market spur
		{14, -2, 29, 0},           -- bowyer spur
		{3, 51, 4, 53},            -- lookout doorstep
	}

	-- Plot roster. Each row is one placed building: landmark id, generator,
	-- its parameters, the pad anchor of the footprint, the rotation that
	-- turns its door toward its lane and, for the two terrace houses, the
	-- height of the podium the whole building is lifted onto.
	local PLOTS = {
		{id = "moon_shrine", make = "chapel", x = -26, z = 18, turns = 0,
			roof_material = "pale",
			spec = {w = 11, d = 15, wall_h = 7, door_index = 5}},
		{id = "lore_hall", make = "hall", x = 14, z = 16, turns = 0,
			roof_material = "pale",
			spec = {w = 13, d = 15, wall_h = 6}},
		{id = "bowyer_workshop", make = "workshop", x = 30, z = -6, turns = 0,
			spec = {w = 11, d = 13, wing = 7, wall_h = 6, door_side = "x-"}},
		{id = "terrace_house_west", make = "cottage", x = -22, z = -18,
			turns = 0, lift = 3,
			spec = {w = 7, d = 11, wall_h = 6, roof = "gable",
				ridge_axis = "z", door_side = "z-", door_index = 3,
				fancy_bed = true}},
		{id = "terrace_house_east", make = "cottage", x = 16, z = -18,
			turns = 0, lift = 3,
			spec = {w = 7, d = 11, wall_h = 6, roof = "gable",
				ridge_axis = "z", door_side = "z-", door_index = 3}},
		{id = "glade_house_west", make = "cottage", x = -38, z = -21,
			turns = 0,
			spec = {w = 7, d = 11, wall_h = 6, roof = "gable",
				ridge_axis = "z", door_side = "z-", door_index = 3}},
		{id = "glade_house_east", make = "cottage", x = 32, z = -21,
			turns = 0,
			spec = {w = 7, d = 11, wall_h = 6, roof = "hip",
				door_side = "z-", door_index = 3}},
		{id = "covered_market", make = "shed", x = -44, z = -4, turns = 0,
			spec = {w = 13, d = 9, wall_h = 5, open_sides = {"x+", "z-"}}},
		{id = "gate_lookout", make = "watchpost", x = 5, z = 48, turns = 0,
			roof_material = "pale", spec = {door_side = "x-"}},
	}

	-- Destination order is part of the consumer contract and never changes.
	local DESTINATION_ORDER = {"moon_shrine", "lore_hall", "bowyer_workshop",
		"terrace_house_west", "terrace_house_east", "glade_house_west",
		"glade_house_east", "covered_market", "lookout_deck"}

	local DESTINATION_ID = {gate_lookout = "lookout_deck"}

	-- The three public buildings carry the brick cut of the same silver
	-- sandstone instead of the plain one, in the same rasterised stair
	-- family, so the shrine, the lore hall and the gate read as the parts of
	-- the glade that were dressed rather than sawn.
	local PALE_ROOF = {
		roof_stair = "stairs:stair_silver_sandstone_brick",
		roof_stair_outer = "stairs:stair_outer_silver_sandstone_brick",
		roof_stair_inner = "stairs:stair_inner_silver_sandstone_brick",
		roof_slab = "stairs:slab_silver_sandstone_brick",
		roof_ridge = "default:silver_sandstone_brick",
	}

	-- The processional colonnade on the shrine approach: paired silverwood
	-- posts carrying a beam architrave, with a lantern hung under every bay.
	local COLONNADE = {x1 = -23, x2 = -19, z = {12, 14, 16}, height = 5}

	-- The silverwood standards the glade was cut out of: a handful of named
	-- specimens close in, then a deterministic scatter over everything the
	-- settlement did not take.
	local SPECIMENS = {
		{-8, 12, 13}, {8, 12, 12}, {-10, -16, 12}, {10, -16, 13},
		{-30, 4, 13}, {30, 12, 12}, {-16, 30, 13}, {16, 32, 12},
		{-6, 30, 11}, {6, 34, 13}, {-34, -8, 12}, {34, -14, 11},
	}

	return function()
		local palette = palettes.new("elf")
		local pale = palettes.new("elf", PALE_ROOF)
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

		-- 1. Glade ground.
		layout.glade(buf, palette, RADIUS, 34)

		-- 2. The moon court, its kerb and the crescent inlay, then the road
		-- and the avenues over it.
		for z = COURT.z1, COURT.z2 do
			for x = COURT.x1, COURT.x2 do
				buf:put(x, 0, z, palette.node("plaza"))
			end
		end
		dressing.inlay(buf, palette, COURT.x1, COURT.z1, COURT.x2, COURT.z2)
		for _, lane in ipairs(LANES) do
			layout.pave(buf, palette, lane[1], lane[2], lane[3], lane[4],
				"path", 5)
		end
		-- The crescent: a pale disc with a second disc cut out of it, laid
		-- last so the paving does not break its edge.
		for dz = -5, 5 do
			for dx = -5, 5 do
				local outer = dx * dx + dz * dz
				local cut = (dx + CRESCENT.offset) * (dx + CRESCENT.offset) +
					dz * dz
				if outer <= CRESCENT.outer and cut > CRESCENT.inner then
					buf:put(CRESCENT.x + dx, 0, CRESCENT.z + dz,
						palette.node("foundation"))
				end
			end
		end

		-- 3. Terraces, then buildings.
		for _, plot in ipairs(PLOTS) do
			local lift = plot.lift or 0
			if lift > 0 then
				dressing.terrace(buf, palette, plot.x - 1, plot.z - 1,
					plot.x + plot.spec.w, plot.z + plot.spec.d - 1, lift, "z-")
			end
			local spec = {}
			for key, value in pairs(plot.spec) do spec[key] = value end
			spec.id = plot.id
			if plot.roof_material == "pale" then spec.roof_palette = pale end
			local part = buildings[plot.make](palette, spec)
			local points = parts.stamp(buf, part, plot.x, lift, plot.z,
				plot.turns)
			local footprint = points.footprint[1]
			placed[plot.id] = {x = plot.x, z = plot.z, lift = lift,
				w = footprint.w, d = footprint.d, peak = part.peak + lift}
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
					top = a.top + lift, closed = a.closed, id = plot.id,
				}
			end
		end

		-- 4. Terrace railings: the two sides and the back of every podium,
		-- so the front stays open for the steps and the doorway.
		for _, id in ipairs({"terrace_house_west", "terrace_house_east"}) do
			local plot = placed[id]
			local x1, z1 = plot.x - 1, plot.z - 1
			local x2, z2 = plot.x + plot.w, plot.z + plot.d
			for z = z1, z2 do
				buf:put(x1, plot.lift + 1, z, palette.node("railing"))
				buf:put(x2, plot.lift + 1, z, palette.node("railing"))
			end
			for x = x1 + 1, x2 - 1 do
				buf:put(x, plot.lift + 1, z2, palette.node("railing"))
			end
		end

		-- 5. The spire on the shrine's ridge: the one silhouette that marks
		-- the glade's centre from under the canopy.
		do
			local shrine = placed.moon_shrine
			local spire = buildings.belfry(palette,
				{height = 4, roof_palette = pale})
			parts.stamp(buf, spire, shrine.x + 3, shrine.peak, shrine.z + 5, 0)
		end

		-- 6. The gate: two brick piers under a silverwood lintel, candles
		-- over the road and a marble kerb to either side.
		for _, x in ipairs({-3, 3}) do
			for y = 1, 5 do buf:put(x, y, 58, palette.node("wall_accent")) end
		end
		for x = -2, 2 do buf:put(x, 5, 58, palette.node("beam")) end
		parts.beacon(buf, palette, 0, 6, 58)
		for _, side in ipairs({{-2, -1}, {2, 1}}) do
			parts.wall_torch(buf, palette, side[1], 4, 58, side[2], 0, 0)
		end
		dressing.low_wall_line(buf, palette, -12, 58, -4, 58)
		dressing.low_wall_line(buf, palette, 4, 58, 12, 58)

		-- 7. The shrine's colonnade: two rows of posts with a beam
		-- architrave and a lantern hanging in every bay.
		for _, z in ipairs(COLONNADE.z) do
			for _, x in ipairs({COLONNADE.x1, COLONNADE.x2}) do
				for y = 1, COLONNADE.height do
					buf:put(x, y, z, palette.node("post"))
				end
			end
			for x = COLONNADE.x1, COLONNADE.x2 do
				buf:put(x, COLONNADE.height + 1, z, palette.node("beam"))
			end
			parts.hanging_light(buf, palette, COLONNADE.x1 + 2,
				COLONNADE.height, z)
		end

		-- 8. Gable lights: one emberglass lamp set into the ridge gable of
		-- every house, which is what makes the glade readable at night from
		-- the canopy paths.
		for _, id in ipairs({"terrace_house_west", "terrace_house_east",
				"glade_house_west", "glade_house_east"}) do
			local plot = placed[id]
			parts.beacon(buf, palette, plot.x + 3, plot.lift + 8, plot.z)
		end

		-- 9. The court: lantern standards, flower beds on marble kerbs,
		-- benches and a notice post under the crescent.
		for _, spot in ipairs({{-11, -8}, {11, -8}, {-11, 5}, {11, 5},
				{-11, -2}, {11, -2}}) do
			paved_prop(spot[1], spot[2], spot[1] + 1, spot[2], function()
				dressing.lantern_post(buf, palette, spot[1], spot[2])
			end)
		end
		prop(-11, -19, -8, -16, function()
			dressing.flower_bed(buf, palette, -11, -19, -8, -16)
		end)
		prop(8, -19, 11, -16, function()
			dressing.flower_bed(buf, palette, 8, -19, 11, -16)
		end)
		prop(-11, 12, -8, 15, function()
			dressing.flower_bed(buf, palette, -11, 12, -8, 15)
		end)
		prop(8, 12, 11, 15, function()
			dressing.flower_bed(buf, palette, 8, 12, 11, 15)
		end)
		paved_prop(-8, 4, -6, 4, function()
			dressing.bench(buf, palette, -8, 4, 2, 3, "x")
		end)
		paved_prop(6, 4, 8, 4, function()
			dressing.bench(buf, palette, 6, 4, 2, 3, "x")
		end)
		paved_prop(-8, -9, -6, -9, function()
			dressing.bench(buf, palette, -8, -9, 0, 3, "x")
		end)
		paved_prop(6, -9, 8, -9, function()
			dressing.bench(buf, palette, 6, -9, 0, 3, "x")
		end)
		paved_prop(-6, -1, -6, -1, function()
			dressing.signpost(buf, palette, -6, -1)
		end)
		-- The four lantern pillars that mark the corners of the court.
		for _, pillar in ipairs({{-8, 1}, {8, 1}, {-8, -7}, {8, -7}}) do
			paved_prop(pillar[1] - 1, pillar[2] - 1, pillar[1] + 1,
				pillar[2] + 1, function()
					dressing.lantern_pillar(buf, palette, pillar[1], pillar[2])
				end)
		end

		-- 10. Planters and crates along the avenues and outside the market.
		for _, bed in ipairs({{-22, 4, -20, 6}, {20, 4, 22, 6},
				{-22, -8, -20, -6}, {20, -8, 22, -6}}) do
			prop(bed[1], bed[2], bed[3], bed[4], function()
				dressing.planter(buf, palette, bed[1], bed[2], bed[3], bed[4])
			end)
		end
		for _, crate in ipairs({{-30, -4, 3}, {-30, -3, 3}, {28, 2, 1},
				{28, 3, 1}}) do
			prop(crate[1], crate[2], crate[1], crate[2], function()
				dressing.crates(buf, palette, crate[1], crate[2], crate[3])
			end)
		end
		for _, pile in ipairs({{-34, 14, 4, "z"}, {34, 14, 4, "z"},
				{46, -8, 3, "z"}}) do
			local axis = pile[4]
			local x2 = axis == "x" and pile[1] + pile[3] - 1 or pile[1]
			local z2 = axis == "z" and pile[2] + pile[3] - 1 or pile[2]
			prop(pile[1], pile[2], x2, z2, function()
				dressing.wood_pile(buf, palette, pile[1], pile[2], pile[3], axis)
			end)
		end

		-- 11. Low silverwood railings where a lane runs along a drop or a
		-- grove edge, and stepping stones off the paving into the trees.
		for _, line in ipairs({{-40, -26, -28, -26}, {28, -26, 40, -26},
				{-24, 12, -24, 20}, {26, 16, 26, 24}}) do
			prop(math.min(line[1], line[3]), math.min(line[2], line[4]),
				math.max(line[1], line[3]), math.max(line[2], line[4]),
				function()
					dressing.fence_line(buf, palette, line[1], line[2],
						line[3], line[4])
				end)
		end
		dressing.stepping_line(buf, palette, -14, 4, -14, 7)
		dressing.stepping_line(buf, palette, 14, 4, 14, 7)
		dressing.stepping_line(buf, palette, -18, -12, -15, -12)
		dressing.stepping_line(buf, palette, 15, -12, 18, -12)
		dressing.stepping_line(buf, palette, -3, 12, -3, 15)
		dressing.stepping_line(buf, palette, 3, 12, 3, 15)

		-- 12. Route lighting: the road, the avenues and the lanes.
		layout.street_lamps(buf, palette, 0, 2, 56, 7, outdoors)
		for _, spot in ipairs({{-16, 9}, {16, 9}, {-25, 6}, {25, 6},
				{-25, -12}, {25, -12}, {-25, -20}, {25, -20},
				{-14, -21}, {14, -21}, {-30, -21}, {30, -21},
				{-42, -21}, {42, -21}, {-28, 0}, {28, 4},
				{-19, 18}, {19, 16}}) do
			if outdoors(spot[1], spot[2]) and
					layout.free(buf, spot[1], spot[2], 3) then
				dressing.path_light(buf, palette, spot[1], spot[2])
			end
		end

		-- 13. The silverwood: named specimens first, then the scatter.
		local standards = layout.plant_grove(buf, palette, RADIUS, 7, SPECIMENS)

		-- 14. Ferns and pale grass on whatever litter is left.
		dressing.undergrowth(buf, palette, -RADIUS, -RADIUS, RADIUS, RADIUS, 3)

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
		for _, role in ipairs({"light_hanging", "light_beacon"}) do
			local name = palette.maybe(role)
			if name then light_names[name] = true end
		end
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
				error("wp13 silverleaf: destination " .. id .. " is missing", 0)
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
			error("wp13 silverleaf: no door for " .. id, 0)
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
				moon_court = {min = {x = COURT.x1, y = 0, z = COURT.z1},
					max = {x = COURT.x2, y = 4, z = COURT.z2}},
				main_street = {min = {x = -2, y = 0, z = 0},
					max = {x = 2, y = 3, z = RADIUS}},
				moon_shrine = box("moon_shrine", 2, 9),
				moon_shrine_door = door_of("moon_shrine"),
				lore_hall = box("lore_hall", 2, 3),
				lore_hall_door = door_of("lore_hall"),
				bowyer_workshop = box("bowyer_workshop", 2, 3),
				bowyer_workshop_door = door_of("bowyer_workshop"),
				terrace_house_west = box("terrace_house_west", 2, 3),
				terrace_house_east = box("terrace_house_east", 2, 3),
				glade_house_west = box("glade_house_west", 2, 3),
				glade_house_east = box("glade_house_east", 2, 3),
				covered_market = box("covered_market", 2, 3),
				gate_lookout = box("gate_lookout", 2, 3),
				gate_passage = {min = {x = -2, y = 1, z = 50},
					max = {x = 2, y = 5, z = RADIUS}},
				destinations = destinations,
				doors = doorways,
				rooms = rooms,
				lights = lights,
				standards = standards,
			},
		}
	end
end

return loader
