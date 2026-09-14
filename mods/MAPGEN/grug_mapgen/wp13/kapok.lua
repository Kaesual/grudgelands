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
-- terrace between four totem posts; and three emergent kapoks stand clear of
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

	-- The lodge terrace: the only masonry in the village, and the only floor
	-- in it that is neither plank nor mud.
	local PLATFORM = {x1 = -13, z1 = 19, x2 = 13, z2 = 38}

	-- Boardwalk. Every lane is plank over mud; there is no paved street.
	local LANES = {
		{-2, -RADIUS, 2, 0},         -- the road, village to the south gate
		{-2, 0, 2, 19},              -- the spine, spawn to the lodge door
		{-34, -10, 34, -8},          -- south lane: the elder and river stairs
		{-34, -2, 34, 0},            -- mid lane: the weaver and reed stairs
		{-28, 16, 21, 18},           -- north lane: drying shed and smoker
		{2, -49, 4, -47},            -- watchpost doorstep
	}

	-- Plot roster. Each row is one placed building: landmark id, generator,
	-- its parameters, the pad anchor of the footprint and the rotation.
	-- `stilt` raises the floor onto posts and `stairs` gives it the flight
	-- that reaches the deck; both are library parameters, not troll-only code.
	local PLOTS = {
		{id = "spirit_lodge", make = "hall", x = -6, z = 20, turns = 0,
			terrace = true,
			spec = {w = 13, d = 15, wall_h = 7, overhang = 1, apron = 3,
				rise = 3, kit = "lodge", chimneys = {{x = 6, z = 7}}}},
		-- Door index 3, not the middle: `workshop` stands its first flue on
		-- the middle cell of a wall, and a chimney through a doorway is a
		-- doorway no longer. Both flues are moved to the smoking wall.
		{id = "fish_smoker", make = "workshop", x = 16, z = 20, turns = 0,
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, stilt = 2, apron = 2,
				door_side = "z-", door_index = 3,
				stairs = {{side = "z-", index = 3, width = 3}},
				chimneys = {{x = 5, z = 12}, {x = 15, z = 4}},
				kit = "smoker"}},
		{id = "drying_shed", make = "shed", x = -32, z = 20, turns = 0,
			spec = {w = 13, d = 9, wall_h = 4, open_sides = {"z-", "x+"}}},
		{id = "elder_stilt", make = "cottage", x = -30, z = -22, turns = 0,
			spec = {w = 9, d = 9, wall_h = 5, overhang = 1, apron = 2, stilt = DECK,
				roof = "gable", ridge_axis = "x", rise = 3, door_side = "z+",
				door_index = 4, fancy_bed = true,
				stairs = {{side = "z+", index = 4, width = 3}}}},
		{id = "river_stilt", make = "cottage", x = 22, z = -22, turns = 0,
			spec = {w = 9, d = 9, wall_h = 5, overhang = 1, apron = 2, stilt = DECK,
				roof = "hip", rise = 3, door_side = "z+", door_index = 4,
				stairs = {{side = "z+", index = 4, width = 3}}}},
		{id = "weaver_stilt", make = "cottage", x = -30, z = 4, turns = 0,
			spec = {w = 9, d = 9, wall_h = 5, overhang = 1, apron = 2, stilt = DECK,
				roof = "hip", rise = 3, door_side = "z-", door_index = 4,
				stairs = {{side = "z-", index = 4, width = 3}}}},
		{id = "reed_stilt", make = "cottage", x = 22, z = 4, turns = 0,
			spec = {w = 9, d = 9, wall_h = 5, overhang = 1, apron = 2, stilt = DECK,
				roof = "gable", ridge_axis = "z", rise = 3, door_side = "z-",
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

	-- The lodge alone stands on stone: its apron is the terrace it sits on,
	-- not the plank apron every other plot carries.
	local TERRACE_APRON = {path = "grug_decor:darkage_basalt_brick"}

	-- The two flying bridges, deck to deck across the road: one between the
	-- southern pair of dwellings, one between the northern pair. The pier rule
	-- keeps the five-wide route clear underneath, which is the whole point of
	-- building them high.
	local BRIDGES = {
		{x = -20, z = -18, len = 41},
		{x = -20, z = 10, len = 41},
	}

	-- Totem posts round the lodge terrace.
	local TOTEMS = {{-12, 20, 7}, {12, 20, 7}, {-12, 37, 7}, {12, 37, 7}}

	-- Rope falling from the underside of the four verandas.
	local ROPES = {{-31, -13}, {-21, -13}, {-31, -23}, {-21, -23},
		{21, -13}, {31, -13}, {21, -23}, {31, -23},
		{-31, 3}, {-21, 3}, {-31, 13}, {-21, 13},
		{21, 3}, {31, 3}, {21, 13}, {31, 13}}

	-- Lanterns under the bridges and the verandas. The bridge cells avoid the
	-- pier line, which is every third cell from the bridge's own origin.
	local LANTERNS = {{-15, -18}, {-6, -18}, {6, -18}, {15, -18},
		{-15, 10}, {-6, 10}, {6, 10}, {15, 10},
		{-31, -18}, {-21, -18}, {21, -18}, {31, -18},
		{-31, 8}, {-21, 8}, {21, 8}, {31, 8}}

	-- Drying racks of split fish on the shed's working ground.
	local RACKS = {{-37, 20, 7, "z"}, {-37, 30, 6, "z"},
		{-17, 20, 7, "z"}, {-17, 30, 6, "z"}}

	return function()
		local palette = palettes.new("troll")
		local terrace = palettes.new("troll", TERRACE_APRON)
		local buf = parts.buffer()
		local lights, doorways, rooms = {}, {}, {}
		local placed, inside_by_id, plot_order = {}, {}, {}

		local function outdoors(x, z)
			for _, plot in ipairs(plot_order) do
				if x >= plot.x and x <= plot.x + plot.w - 1 and
						z >= plot.z and z <= plot.z + plot.d - 1 then
					return false
				end
			end
			return true
		end

		-- Ground this composition laid itself and has built nothing on. As in
		-- Dawnmere, `layout.natural` is the stricter rule that keeps the
		-- planting on bare soil; a rack, a pile or a crate may also stand on
		-- the mud and in the shed's straw, and must not be lost to one.
		local GROUND = {}
		for _, role in ipairs({"ground", "ground_patch", "ground_bare",
				"ground_straw"}) do
			local name = palette.maybe(role)
			if name ~= nil then GROUND[name] = true end
		end

		-- Every prop the composition asks for MUST land. A prop quietly
		-- skipped is a hole in the authored scene that no fixture can see, so
		-- each helper names the prop and its position and raises instead of
		-- returning false.
		local function refuse(name, x, z, reason)
			error("wp13 kapok: prop " .. name .. " at " .. x .. "," .. z ..
				" was not placed: " .. reason, 0)
		end

		local function place(name, x, z, build)
			if build() == false then
				refuse(name, x, z, "the prop could not be completed")
			end
		end

		-- Space that is genuinely outside: clear of props AND clear of every
		-- plot footprint. A stilt house leaves its own floor cleared at pad
		-- level, and a cleared room passes an emptiness test while being the
		-- last place a notice post belongs.
		local function open_air(name, x1, z1, x2, z2)
			if not layout.free_area(buf, x1, z1, x2, z2, 4) then
				refuse(name, x1, z1, "the space is taken")
			end
			for z = z1, z2 do
				for x = x1, x2 do
					if not outdoors(x, z) then
						refuse(name, x1, z1,
							"the cell at " .. x .. "," .. z .. " is indoors")
					end
				end
			end
		end

		-- A prop on open ground: clear space, and nothing built underneath.
		local function prop(name, x1, z1, x2, z2, build)
			open_air(name, x1, z1, x2, z2)
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

		-- Furniture that belongs on the paving it stands on, so only the space
		-- is tested.
		local function paved_prop(name, x1, z1, x2, z2, build)
			open_air(name, x1, z1, x2, z2)
			place(name, x1, z1, build)
		end

		-- A prop that hangs from a deck rather than standing on the ground.
		local function hung_prop(name, x, y, z, build)
			local placed_cells = build()
			if placed_cells == false or placed_cells == 0 then
				refuse(name, x, z, "no deck above it at height " .. y)
			end
		end

		-- 1. Basin floor: rainforest litter blotched with swamp mud.
		layout.basin(buf, palette, RADIUS)

		-- 2. The lodge terrace and the boardwalk.
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
				plot.terrace and terrace or palette, spec)
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
			prop("gate_totem", x, -56, x, -56, function()
				dressing.totem(buf, palette, x, -56, 6)
			end)
		end
		for x = -2, 2 do buf:put(x, 7, -56, palette.node("beam")) end
		for _, side in ipairs({{-2, -1}, {2, 1}}) do
			parts.wall_torch(buf, palette, side[1], 6, -56, side[2], 0, 0)
		end

		-- 6. The totems round the lodge terrace.
		for _, totem in ipairs(TOTEMS) do
			paved_prop("terrace_totem", totem[1], totem[2], totem[1], totem[2],
				function()
					dressing.totem(buf, palette, totem[1], totem[2], totem[3])
				end)
		end

		-- 7. The terrace itself: a notice post, a fish stall, low walls down
		-- the approach and settles where the throng sits.
		paved_prop("notice_post", 11, 22, 11, 22, function()
			dressing.signpost(buf, palette, 11, 22)
		end)
		paved_prop("fish_stall", -13, 21, -9, 25, function()
			dressing.stall(buf, palette, -12, 22, 1)
		end)
		for _, kerb in ipairs({{-13, 19, -9, 19}, {9, 19, 13, 19}}) do
			paved_prop("terrace_kerb", kerb[1], kerb[2], kerb[3], kerb[4],
				function()
					dressing.low_wall_line(buf, palette, kerb[1], kerb[2],
						kerb[3], kerb[4])
				end)
		end
		for _, seat in ipairs({{-11, 26, 1}, {-11, 32, 1}, {11, 26, 3},
				{11, 32, 3}}) do
			paved_prop("settle", seat[1], seat[2], seat[1], seat[2] + 2,
				function()
					dressing.bench(buf, palette, seat[1], seat[2], seat[3], 3,
						"z")
				end)
		end

		-- 8. The working ground round the drying shed: a straw floor, racks of
		-- split fish, stacked timber and crates.
		local straw = palette.maybe("ground_straw")
		if straw then
			for z = 19, 29 do
				for x = -33, -19 do
					if layout.natural(buf, x, z) and layout.free(buf, x, z, 3) then
						buf:put(x, 0, z, straw)
					end
				end
			end
		end
		local rack_lines = 0
		for _, rack in ipairs(RACKS) do
			prop("drying_rack", rack[1], rack[2], rack[1],
				rack[2] + rack[3] - 1, function()
					rack_lines = rack_lines +
						dressing.drying_rack(buf, palette, rack[1], rack[2],
							rack[3], rack[4])
				end)
		end
		for _, pile in ipairs({{-40, 24, 4, "z"}, {36, 24, 4, "z"},
				{-40, -24, 3, "z"}, {36, -24, 3, "z"}}) do
			local x2 = pile[4] == "x" and pile[1] + pile[3] - 1 or pile[1]
			local z2 = pile[4] == "z" and pile[2] + pile[3] - 1 or pile[2]
			prop("wood_pile", pile[1], pile[2], x2, z2, function()
				dressing.wood_pile(buf, palette, pile[1], pile[2], pile[3],
					pile[4])
			end)
		end
		for _, crate in ipairs({{-18, 22, 0}, {-18, 23, 0}, {-18, 26, 2}}) do
			prop("crates", crate[1], crate[2], crate[1], crate[2], function()
				dressing.crates(buf, palette, crate[1], crate[2], crate[3])
			end)
		end

		-- 9. Rope falling from the underside of every veranda, and lanterns
		-- hung under the bridges and the verandas.
		local rope_cells = 0
		for _, spot in ipairs(ROPES) do
			hung_prop("veranda_rope", spot[1], DECK - 1, spot[2], function()
				local hung = dressing.rope_fall(buf, palette, spot[1],
					DECK - 1, spot[2], 2)
				rope_cells = rope_cells + hung
				return hung
			end)
		end
		for _, spot in ipairs(LANTERNS) do
			hung_prop("lantern", spot[1], DECK - 1, spot[2], function()
				return dressing.lantern(buf, palette, spot[1], DECK - 1,
					spot[2])
			end)
		end

		-- 10. Stepping stones where the boardwalk stops and the mud starts.
		-- Every stone of every line has to land, for the same reason every
		-- other prop does: a line that lays half its stones is a path that
		-- stops in the mud, and nothing downstream would notice.
		local stepping = 0
		for _, line in ipairs({{-6, 1, -6, 3}, {6, 1, 6, 3},
				{-6, -13, -6, -11}, {6, -13, 6, -11},
				{-12, -7, -8, -7}, {8, -7, 12, -7},
				{-12, 1, -8, 1}, {8, 1, 12, 1},
				{-18, 19, -14, 19}, {14, 19, 18, 19}}) do
			local wanted = (math.abs(line[3] - line[1]) + 1) *
				(math.abs(line[4] - line[2]) + 1)
			local laid = dressing.stepping_line(buf, palette, line[1], line[2],
				line[3], line[4])
			if laid ~= wanted then
				refuse("stepping_line", line[1], line[2],
					"only " .. laid .. " of " .. wanted .. " stones landed")
			end
			stepping = stepping + laid
		end

		-- 11. Route lighting: the road, the cross lanes and the terrace.
		local road_lamps = layout.street_lamps(buf, palette, 0, -58, -2, 7,
			outdoors)
		if road_lamps ~= 18 then
			error("wp13 kapok: the road lost a lamp: " .. road_lamps, 0)
		end
		for _, spot in ipairs({{-16, -9}, {16, -9}, {-16, -1}, {16, -1},
				{-36, -9}, {36, -9}, {-36, -1}, {36, -1},
				{-15, 17}, {15, 17}, {-26, 17},
				{-12, 29}, {12, 29}, {-12, 34}, {12, 34},
				{-6, 39}, {6, 39}}) do
			paved_prop("path_light", spot[1], spot[2], spot[1], spot[2],
				function()
					dressing.path_light(buf, palette, spot[1], spot[2])
				end)
		end

		-- 12. The jungle: the emergent giants first, so the scatter has to
		-- make room for them and not the other way round.
		local giants = layout.plant_giants(buf, palette,
			{{-46, 30, 18}, {44, -34, 17}, {-46, -44, 17}})
		if giants ~= 3 then
			error("wp13 kapok: an emergent kapok lost its ground: " .. giants, 0)
		end
		local jungle = layout.plant_jungle(buf, palette, RADIUS, 7)

		-- 13. Basin flora on whatever open litter is left.
		local flora = dressing.basin_flora(buf, palette, -RADIUS, -RADIUS,
			RADIUS, RADIUS)

		-- 14. Pane shapes, settled once over the finished pad. The troll
		-- palette carries no `xpanes` node at all, so this settles nothing and
		-- is here because leaving it out would be a silent dependency on that.
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
				lodge_terrace = {min = {x = PLATFORM.x1, y = 0, z = PLATFORM.z1},
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
				rack_lines = rack_lines,
				stepping_stones = stepping,
				flora_cells = flora,
				jungle_trees = jungle,
				emergent_trees = giants,
			},
		}
	end
end

return loader
