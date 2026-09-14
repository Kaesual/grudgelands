-- Kapok Cradle: the troll start settlement, composed from the WP13 building
-- library.
--
-- Hearthpine is a craft settlement in a pine clearing and Dawnmere a farming
-- hamlet on open meadow. Kapok is neither: it is a stilt village on the floor
-- of a flooding jungle basin, and the difference is meant to be legible from
-- the gate. Four dwellings stand three courses up on jungletree posts and are
-- joined to each other by railed plank bridges that fly over the road; the
-- ground below them is rainforest litter blotched with swamp mud, walked on a
-- boardwalk instead of a paved lane; the spirit lodge sits alone on a basalt
-- platform between four totem posts; and two emergent kapoks stand clear of
-- the canopy over the whole thing.
--
-- The road runs to -z. Kapok Cradle's start gate is
-- `station:kragmar_kapok_cradle:start_south` at (1800, 2486), which is 64
-- nodes SOUTH of the anchor at (1800, 2550): every Kragmar start exits south,
-- as every Elandor start exits north. The blueprint therefore carries its
-- five-wide route, its gate and its watchpost on negative z, and publishes
-- that in the `main_street` landmark rather than leaving it to be assumed.
--
-- Authored in local coordinates around the troll spawn; the caller fits
-- y = 0 to the fitted start terrain before projecting the cells. The result
-- is the `grug_wp13_kapok_blueprint_v1` payload that
-- `wp40/r7_kapok_blueprint.lua` returns unchanged.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local palettes = dofile(directory .. "/palette.lua")
	local buildings = dofile(directory .. "/buildings.lua")(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local layout = dofile(directory .. "/layout.lua")(directory)

	local RADIUS = 63
	local SCHEMA = "grug_wp13_kapok_blueprint_v1"

	-- The deck height every dwelling and every bridge shares. One height for
	-- the whole village is what lets a bridge leave one veranda and arrive at
	-- another without a step.
	local DECK = 3

	-- The lodge platform: a raised basalt terrace, the only masonry in the
	-- village and the only building standing on the ground.
	local PLATFORM = {x1 = -14, z1 = 16, x2 = 14, z2 = 38}

	-- Boardwalk. Every lane is plank over mud; there is no paved street.
	local LANES = {
		{-2, -RADIUS, 2, 0},         -- the road, village to the south gate
		{-2, 0, 2, 19},              -- the spine, spawn to the lodge door
		{-34, -9, 34, -7},           -- south cross lane, two doorsteps on it
		{-34, 7, 34, 9},             -- north cross lane, two doorsteps on it
		{-28, 16, 21, 18},           -- north lane: drying shed and smoker
		{2, -49, 4, -47},            -- watchpost doorstep
	}

	-- Plot roster. Each row is one placed building: landmark id, generator,
	-- its parameters, the pad anchor of the footprint and the rotation.
	-- `stilt` raises the floor onto posts and `stairs` gives it the flight
	-- that reaches the deck; both are library parameters, not troll-only code.
	local PLOTS = {
		{id = "spirit_lodge", make = "hall", x = -6, z = 20, turns = 0,
			platform = true,
			spec = {w = 13, d = 15, wall_h = 6, overhang = 2, kit = "lodge",
				chimneys = {{x = 6, z = 7}}}},
		{id = "fish_smoker", make = "workshop", x = 14, z = 20, turns = 0,
			-- Door index 3, not the middle: `workshop` stands its first flue
			-- on the middle cell of that wall, and a chimney through a
			-- doorway is a doorway no longer.
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, stilt = 2,
				door_side = "z-", door_index = 3,
				stairs = {{side = "z-", index = 3, width = 3}},
				chimneys = {{x = 5, z = 12}, {x = 15, z = 4}},
				kit = "smoker"}},
		{id = "drying_shed", make = "shed", x = -32, z = 20, turns = 0,
			spec = {w = 13, d = 9, wall_h = 4, open_sides = {"z-", "x+"}}},
		{id = "elder_stilt", make = "cottage", x = -30, z = -22, turns = 0,
			spec = {w = 9, d = 9, wall_h = 4, overhang = 2, stilt = DECK,
				roof = "gable", ridge_axis = "x", door_side = "z+",
				door_index = 4, fancy_bed = true,
				stairs = {{side = "z+", index = 4, width = 3}}}},
		{id = "river_stilt", make = "cottage", x = 22, z = -22, turns = 0,
			spec = {w = 9, d = 9, wall_h = 4, overhang = 2, stilt = DECK,
				roof = "hip", door_side = "z+", door_index = 4,
				stairs = {{side = "z+", index = 4, width = 3}}}},
		{id = "weaver_stilt", make = "cottage", x = -30, z = 14, turns = 0,
			spec = {w = 9, d = 9, wall_h = 4, overhang = 2, stilt = DECK,
				roof = "hip", door_side = "z-", door_index = 4,
				stairs = {{side = "z-", index = 4, width = 3}}}},
		{id = "reed_stilt", make = "cottage", x = 22, z = 14, turns = 0,
			spec = {w = 9, d = 9, wall_h = 4, overhang = 2, stilt = DECK,
				roof = "gable", ridge_axis = "z", door_side = "z-",
				door_index = 4,
				stairs = {{side = "z-", index = 4, width = 3}}}},
		{id = "watchpost", make = "watchpost", x = 5, z = -52, turns = 0,
			spec = {door_side = "x-"}},
	}

	-- Destination order is part of the consumer contract and never changes.
	local DESTINATION_ORDER = {"spirit_lodge", "fish_smoker", "drying_shed",
		"elder_stilt", "river_stilt", "weaver_stilt", "reed_stilt",
		"watchpost_deck"}

	local DESTINATION_ID = {watchpost = "watchpost_deck"}

	-- The lodge alone stands on stone: its apron is the platform it sits on,
	-- not the plank apron every other plot carries.
	local PLATFORM_APRON = {path = "grug_decor:darkage_basalt_brick"}

	-- The two flying bridges: deck to deck across the road, one south of the
	-- village and one north of it. The pier rule keeps the five-wide route
	-- clear underneath, which is the whole point of building them high.
	local BRIDGES = {
		{x = -20, z = -18, len = 41},
		{x = -20, z = 13, len = 41},
	}

	-- Totem posts: four round the lodge platform and two at the gate.
	local TOTEMS = {
		{-13, 17, 7}, {13, 17, 7}, {-13, 37, 7}, {13, 37, 7},
	}

	return function()
		local palette = palettes.new("troll")
		local platform = palettes.new("troll", PLATFORM_APRON)
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

		-- 1. Basin floor: rainforest litter blotched with swamp mud.
		layout.basin(buf, palette, RADIUS)

		-- 2. The lodge platform and the boardwalk.
		layout.pave(buf, palette, PLATFORM.x1, PLATFORM.z1, PLATFORM.x2,
			PLATFORM.z2, "plaza", 4)
		dressing.inlay(buf, palette, PLATFORM.x1, PLATFORM.z1, PLATFORM.x2,
			PLATFORM.z2)
		for _, lane in ipairs(LANES) do
			layout.pave(buf, palette, lane[1], lane[2], lane[3], lane[4],
				"path", 4)
		end

		-- 3. Buildings.
		for _, plot in ipairs(PLOTS) do
			local spec = {}
			for key, value in pairs(plot.spec) do spec[key] = value end
			spec.id = plot.id
			local part = buildings[plot.make](
				plot.platform and platform or palette, spec)
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

		-- 4. The flying bridges, deck to deck over the road.
		local function pier_clear(px)
			return math.abs(px) > 3
		end
		for _, bridge in ipairs(BRIDGES) do
			dressing.walkway(buf, palette, bridge.x, bridge.z, bridge.len,
				"x", DECK, pier_clear)
		end

		-- 5. The gate: two totem posts either side of the road under a
		-- reinforced lintel, with a torch on each post.
		for _, x in ipairs({-3, 3}) do
			dressing.totem(buf, palette, x, -56, 6)
		end
		for x = -2, 2 do buf:put(x, 7, -56, palette.node("beam")) end
		for _, side in ipairs({{-2, -1}, {2, 1}}) do
			parts.wall_torch(buf, palette, side[1], 6, -56, side[2], 0, 0)
		end

		-- 6. The totems round the lodge platform.
		for _, totem in ipairs(TOTEMS) do
			paved_prop(totem[1], totem[2], totem[1], totem[2], function()
				dressing.totem(buf, palette, totem[1], totem[2], totem[3])
			end)
		end

		-- 7. The platform itself: a notice post, a fish stall, low walls down
		-- the approach and mats of straw where the throng sits.
		dressing.signpost(buf, palette, -4, 14)
		paved_prop(5, 12, 9, 16, function()
			dressing.stall(buf, palette, 6, 13, 2)
		end)
		dressing.low_wall_line(buf, palette, -9, 18, -4, 18)
		dressing.low_wall_line(buf, palette, 4, 18, 9, 18)
		for _, seat in ipairs({{-12, 22, 2, "z"}, {-12, 30, 2, "z"},
				{11, 22, 0, "z"}, {11, 30, 0, "z"}}) do
			paved_prop(seat[1], seat[2], seat[1], seat[2] + 2, function()
				dressing.bench(buf, palette, seat[1], seat[2], seat[3], 3, "z")
			end)
		end

		-- 8. The working ground round the drying shed: straw floor, racks of
		-- split fish, stacked timber and crates.
		if palette.maybe("ground_straw") then
			for z = 19, 29 do
				for x = -33, -19 do
					if layout.natural(buf, x, z) and layout.free(buf, x, z, 3) then
						buf:put(x, 0, z, palette.node("ground_straw"))
					end
				end
			end
		end
		local rack_lines = 0
		for _, rack in ipairs({{-36, 20, 7, "z"}, {-36, 30, 6, "z"},
				{-16, 20, 7, "z"}, {-16, 30, 6, "z"}}) do
			prop(rack[1], rack[2], rack[1], rack[2] + rack[3] - 1, function()
				rack_lines = rack_lines +
					dressing.drying_rack(buf, palette, rack[1], rack[2],
						rack[3], rack[4])
			end)
		end
		for _, pile in ipairs({{-40, 12, 4, "z"}, {36, 12, 4, "z"},
				{-40, -14, 3, "z"}, {36, -14, 3, "z"}}) do
			local x2 = pile[4] == "x" and pile[1] + pile[3] - 1 or pile[1]
			local z2 = pile[4] == "z" and pile[2] + pile[3] - 1 or pile[2]
			prop(pile[1], pile[2], x2, z2, function()
				dressing.wood_pile(buf, palette, pile[1], pile[2], pile[3],
					pile[4])
			end)
		end
		for _, crate in ipairs({{-18, 14, 0}, {-18, 15, 0}, {18, 14, 2},
				{18, -12, 2}, {-18, -12, 0}}) do
			prop(crate[1], crate[2], crate[1], crate[2], function()
				dressing.crates(buf, palette, crate[1], crate[2], crate[3])
			end)
		end

		-- 9. Rope falling from the underside of every deck, and lanterns hung
		-- under the bridges and the lodge eaves.
		local rope_cells = 0
		local ROPES = {{-31, -13}, {-21, -13}, {-31, -23}, {21, -13},
			{31, -13}, {21, -23}, {-31, 13}, {-21, 23}, {21, 13}, {31, 23},
			{-19, -19}, {19, -19}, {-19, 12}, {19, 14}}
		for _, spot in ipairs(ROPES) do
			rope_cells = rope_cells +
				dressing.rope_fall(buf, palette, spot[1], DECK - 1, spot[2], 2)
		end
		local lanterns = 0
		local LANTERNS = {{-14, -18}, {14, -18}, {-14, 13}, {14, 13},
			{-8, -18}, {8, -18}, {-8, 13}, {8, 13},
			{-27, -13}, {27, -13}, {-27, 13}, {27, 13}}
		for _, spot in ipairs(LANTERNS) do
			if dressing.lantern(buf, palette, spot[1], DECK - 1, spot[2]) then
				lanterns = lanterns + 1
			end
		end

		-- 10. Stepping stones where the boardwalk stops and the mud starts.
		for _, line in ipairs({{-6, 10, -6, 12}, {6, 10, 6, 12},
				{-6, -12, -6, -10}, {6, -12, 6, -10},
				{-12, 8, -8, 8}, {8, 8, 12, 8},
				{-12, -8, -8, -8}, {8, -8, 12, -8}}) do
			dressing.stepping_line(buf, palette, line[1], line[2], line[3],
				line[4])
		end

		-- 11. Route lighting: the road, the cross lanes and the platform.
		layout.street_lamps(buf, palette, 0, -58, -2, 7, outdoors)
		for _, spot in ipairs({{-6, 6}, {6, 6}, {-6, -6}, {6, -6},
				{-16, 8}, {16, 8}, {-16, -8}, {16, -8},
				{-36, 8}, {36, 8}, {-36, -8}, {36, -8},
				{-15, 16}, {15, 16}, {-15, 38}, {15, 38},
				{-6, 18}, {6, 18}, {-26, 17}, {-6, 40}, {6, 40}}) do
			if outdoors(spot[1], spot[2]) and
					layout.free(buf, spot[1], spot[2], 3) then
				dressing.path_light(buf, palette, spot[1], spot[2])
			end
		end

		-- 12. The jungle: the two emergent giants first, so the scatter has
		-- to make room for them and not the other way round.
		local giants = layout.plant_giants(buf, palette,
			{{-44, 30, 18}, {40, -34, 17}, {-46, -44, 17}})
		local jungle = layout.plant_jungle(buf, palette, RADIUS, 9)

		-- 13. Basin flora on whatever open litter is left.
		dressing.undergrowth(buf, palette, -RADIUS, -RADIUS, RADIUS, RADIUS, 3)

		-- 14. Pane shapes, settled once over the finished pad. The troll
		-- palette carries no `xpanes` node at all, so this settles nothing
		-- and is here because leaving it out would be a silent dependency on
		-- that fact.
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
				error("wp13 kapok: destination " .. id .. " is missing", 0)
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
			error("wp13 kapok: no door for " .. id, 0)
		end

		return {
			schema = SCHEMA,
			cells = cells,
			bounds = {min = minp, max = maxp},
			palette = palette_list,
			landmarks = {
				spawn = {x = 0, y = 1, z = 0},
				arrival = {x = 0, y = 1, z = 0},
				gate = {x = 0, y = 1, z = -RADIUS},
				lodge_platform = {min = {x = PLATFORM.x1, y = 0, z = PLATFORM.z1},
					max = {x = PLATFORM.x2, y = 4, z = PLATFORM.z2}},
				main_street = {min = {x = -2, y = 0, z = -RADIUS},
					max = {x = 2, y = 3, z = 0}},
				spirit_lodge = box("spirit_lodge", 2, 9),
				spirit_lodge_door = door_of("spirit_lodge"),
				fish_smoker = box("fish_smoker", 2, 3),
				fish_smoker_door = door_of("fish_smoker"),
				drying_shed = box("drying_shed", 2, 3),
				elder_stilt = box("elder_stilt", 2, 3),
				elder_stilt_door = door_of("elder_stilt"),
				river_stilt = box("river_stilt", 2, 3),
				weaver_stilt = box("weaver_stilt", 2, 3),
				reed_stilt = box("reed_stilt", 2, 3),
				watchpost = box("watchpost", 2, 3),
				gate_passage = {min = {x = -2, y = 1, z = -RADIUS},
					max = {x = 2, y = 5, z = -50}},
				destinations = destinations,
				doors = doorways,
				rooms = rooms,
				lights = lights,
				deck_height = DECK,
				rope_cells = rope_cells,
				lanterns = lanterns,
				rack_lines = rack_lines,
				jungle_trees = jungle,
				emergent_trees = giants,
			},
		}
	end
end

return loader
