-- Silverleaf Glade: the elf start settlement, composed from the WP13
-- building library.
--
-- Hearthpine is a craft settlement in a pine clearing and Dawnmere a farming
-- hamlet on open meadow. Silverleaf is neither: it is a glade cut into the
-- silverwood, and the difference is meant to be legible from the gate. The
-- ground is the elf forest's own silver litter, the paving is marble, the
-- houses are narrow and steep instead of broad and low, two of them stand on
-- marble terraces with railed fronts, the light is candle and hanging
-- lantern instead of pitch torch, and the place is roofed in darkage slate
-- tile -- pale silver sandstone brick is the CIVIC roof, on the shrine, the
-- lore hall and the gate lookout only -- under columnar silverwood standards
-- that overtop all of it.
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
	local CRESCENT = {x = 0, z = -2, outer = 40, inner = 30, offset = 4,
		reach = 7}

	local LANES = {
		{-2, 0, 2, RADIUS},        -- the road, court to gate
		{-2, -22, 2, -10},         -- the road's southern continuation
		{-24, 8, -3, 10},          -- west avenue
		{3, 8, 24, 10},            -- east avenue
		{-23, 11, -19, 14},        -- shrine approach, between the colonnade
		{-27, 15, -15, 17},        -- shrine forecourt
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
		-- The shrine is the one steep roof in the glade: a narrow nave under a
		-- full-pitch gable whose ridge runs with the approach, so the moon
		-- face at the gable end is what the colonnade walks you toward. A hip
		-- at this width would clip into the broad flat deck the lore hall and
		-- the lookout carry, and a shrine is not a hall.
		{id = "moon_shrine", make = "chapel", x = -25, z = 18, turns = 0,
			roof_material = "pale",
			spec = {w = 9, d = 15, wall_h = 7, door_index = 4,
				roof = "gable", ridge_axis = "z", rise = 5}},
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
		-- The gate watch: one post either side of the avenue, inside the
		-- gate wall at z = 58, both facing the way out of the glade.
		{id = "gate_west", role = "guard_post", x = -4, y = 1, z = 57,
			dir = {x = 0, z = 1}},
		{id = "gate_east", role = "guard_post", x = 4, y = 1, z = 57,
			dir = {x = 0, z = 1}},
		{id = "watch_gate", role = "guard_patrol", group = "glade", order = 1,
			x = 0, y = 1, z = 52, dir = {x = 0, z = 1}},
		{id = "watch_avenue", role = "guard_patrol", group = "glade",
			order = 2, x = 0, y = 1, z = 24, dir = {x = 0, z = -1}},
		{id = "watch_court_west", role = "guard_patrol", group = "glade",
			order = 3, x = -10, y = 1, z = 0, dir = {x = -1, z = 0}},
		{id = "watch_court_south", role = "guard_patrol", group = "glade",
			order = 4, x = 0, y = 1, z = -7, dir = {x = 0, z = -1}},
		{id = "watch_court_east", role = "guard_patrol", group = "glade",
			order = 5, x = 10, y = 1, z = 0, dir = {x = 1, z = 0}},
		{id = "court_vendor", role = "vendor", kind = "race", x = 7, y = 1,
			z = -4, dir = {x = -1, z = 0}},
		{id = "idle_shrine_door", role = "idle", tags = {"door"}, x = -21,
			y = 1, z = 16, dir = {x = 0, z = 1}},
		{id = "idle_court_bench", role = "idle", tags = {"bench"}, x = -7,
			y = 1, z = 5, dir = {x = 0, z = -1}},
		{id = "idle_bowyer", role = "idle", tags = {"work"}, x = 28, y = 1,
			z = -1, dir = {x = 1, z = 0}},
		-- The covered market's hanging lanterns are the only open flame the
		-- glade keeps outdoors; this is its fireside.
		{id = "idle_market", role = "idle", tags = {"fire"}, x = -31, y = 1,
			z = 0, dir = {x = -1, z = 0}},
		--
		-- WORKPLACES (playtest round 3, contract section 8.1). A `work` socket
		-- is a spawn socket like an `idle` one and its resident never leaves
		-- it. Both stand at features the glade already has, so no cell moves.
		--
		-- A gardener at the court's planters, and a stall keeper at the covered
		-- market's own slate counter.
		{id = "work_planters", role = "work", activity = "tend",
			tags = {"work"}, x = 4, y = 1, z = 11, dir = {x = 0, z = 1}},
		{id = "work_market", role = "work", activity = "stall", tags = {"work"},
			x = -33, y = 1, z = 5, dir = {x = 0, z = -1}},
		-- `door`: the elder faces the hall door it stands at, and the consumer
		-- turns it round to the street (start_npcs.lua `socket_face_yaw`).
		{id = "hall_quest", role = "quest", tags = {"door"}, x = 20, y = 1,
			z = 14, dir = {x = 0, z = 1}},
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
		-- the slate brick east of the walk
		{id = "idle_spare_1", role = "idle", spawn = false, x = 7,
			y = 1, z = 7, dir = {x = -1, z = 0}},
		-- the silver litter to the south
		{id = "idle_spare_2", role = "idle", spawn = false, x = -5,
			y = 1, z = -12, dir = {x = 0, z = 1}},
		-- the silver litter to the north
		{id = "idle_spare_3", role = "idle", spawn = false, x = -7,
			y = 1, z = 12, dir = {x = 0, z = -1}},
	}

	return function()
		local palette = palettes.new("elf")
		local pale = palettes.new("elf", PALE_ROOF)
		local buf = parts.buffer()
		local lights, doorways, rooms = {}, {}, {}
		local placed, inside_by_id = {}, {}
		-- The same plots in roster order. `placed` is keyed by landmark id and
		-- can only be walked with `pairs`; the ordered copy lets the footprint
		-- test below run over an array with `ipairs` instead.
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
		-- glade's litter, its lawns and its worn earth. `layout.natural` is
		-- the stricter rule and stays the one the grove plants by.
		local GROUND = {}
		for _, role in ipairs({"ground", "ground_patch", "ground_bare"}) do
			local name = palette.maybe(role)
			if name ~= nil then GROUND[name] = true end
		end

		-- Every prop the composition asks for MUST land. A prop that is
		-- quietly skipped is a hole in the authored scene that no fixture can
		-- see, so both helpers name the prop and its position and raise
		-- instead of returning false -- as does a `build` that reports a
		-- partial result of its own by returning false.
		local function refuse(name, x, z, reason)
			error("wp13 silverleaf: prop " .. name .. " at " .. x .. "," .. z ..
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

		-- Furniture that belongs on the paving it stands on, so only the space
		-- is tested.
		local function paved_prop(name, x1, z1, x2, z2, build)
			if not layout.free_area(buf, x1, z1, x2, z2, 4) then
				refuse(name, x1, z1, "the space is taken")
			end
			place(name, x1, z1, build)
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
		dressing.inlay(buf, palette, COURT.x1, COURT.z1, COURT.x2, COURT.z2,
			"wall_accent")
		for _, lane in ipairs(LANES) do
			layout.pave(buf, palette, lane[1], lane[2], lane[3], lane[4],
				"path", 5)
		end
		-- The crescent: a disc with a second disc cut out of it, in the dark
		-- stone of the kerb on the white marble, laid last so the paving does
		-- not break its edge. Dark on pale rather than pale on pale: the
		-- first review render had this in a stone one step from the court's
		-- own and the moon simply was not there.
		for dz = -CRESCENT.reach, CRESCENT.reach do
			for dx = -CRESCENT.reach, CRESCENT.reach do
				local outer = dx * dx + dz * dz
				local cut = (dx + CRESCENT.offset) * (dx + CRESCENT.offset) +
					dz * dz
				if outer <= CRESCENT.outer and cut > CRESCENT.inner then
					buf:put(CRESCENT.x + dx, 0, CRESCENT.z + dz,
						palette.node("wall_accent"))
				end
			end
		end

		-- 3. Terraces, then buildings.
		for _, plot in ipairs(PLOTS) do
			local lift = plot.lift or 0
			if lift > 0 then
				-- The podium reaches `plot.z + spec.d`, one node PAST the
				-- back wall, because that is where the apron ring and the
				-- railing below stand. It used to stop at `spec.d - 1`, flush
				-- with the wall, and the 33 cells of ring and rail behind the
				-- two terrace houses had nothing under them at all.
				dressing.terrace(buf, palette, plot.x - 1, plot.z - 1,
					plot.x + plot.spec.w, plot.z + plot.spec.d, lift, "z-")
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
			parts.stamp(buf, spire, shrine.x + 2, shrine.peak, shrine.z + 5, 0)
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

		-- 7b. Lanterns under the covered market's open bays. The top plate of
		-- an open side follows the roof, so its height varies along the bay;
		-- the lantern is hung under the first beam found scanning down.
		local function lantern_under(x, z)
			for y = 7, 3, -1 do
				if parts.hanging_light(buf, palette, x, y, z) then return true end
			end
			refuse("market_lantern", x, z, "no beam to hang it under")
		end
		for _, bay in ipairs({{-32, -2}, {-32, 2}, {-42, -4}, {-38, -4}}) do
			lantern_under(bay[1], bay[2])
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
		for _, spot in ipairs({{-11, -8}, {11, -8}, {-11, 5}, {11, 5}}) do
			paved_prop("lantern_post", spot[1], spot[2], spot[1] + 1, spot[2],
				function()
					dressing.lantern_post(buf, palette, spot[1], spot[2])
				end)
		end
		for _, bed in ipairs({{-11, -19, -8, -16}, {8, -19, 11, -16},
				{-11, 12, -8, 15}, {8, 12, 11, 15}}) do
			prop("flower_bed", bed[1], bed[2], bed[3], bed[4], function()
				dressing.flower_bed(buf, palette, bed[1], bed[2], bed[3], bed[4])
			end)
		end
		for _, seat in ipairs({{-8, 4, 2}, {6, 4, 2}, {-8, -9, 0}, {6, -9, 0}}) do
			paved_prop("bench", seat[1], seat[2], seat[1] + 2, seat[2],
				function()
					dressing.bench(buf, palette, seat[1], seat[2], seat[3], 3, "x")
				end)
		end
		paved_prop("signpost", -6, -1, -6, -1, function()
			dressing.signpost(buf, palette, -6, -1)
		end)
		-- The four lantern pillars that mark the corners of the court.
		for _, pillar in ipairs({{-8, 1}, {8, 1}, {-8, -7}, {8, -7}}) do
			paved_prop("lantern_pillar", pillar[1] - 1, pillar[2] - 1,
				pillar[1] + 1, pillar[2] + 1, function()
					dressing.lantern_pillar(buf, palette, pillar[1], pillar[2])
				end)
		end

		-- 10. Planters and crates along the avenues and outside the market.
		for _, bed in ipairs({{-19, 4, -17, 6}, {17, 4, 19, 6},
				{-13, -14, -11, -12}, {11, -14, 13, -12}}) do
			prop("planter", bed[1], bed[2], bed[3], bed[4], function()
				dressing.planter(buf, palette, bed[1], bed[2], bed[3], bed[4])
			end)
		end
		for _, crate in ipairs({{-30, -4, 3}, {-30, -3, 3}, {28, 2, 1},
				{28, 3, 1}}) do
			prop("crates", crate[1], crate[2], crate[1], crate[2], function()
				dressing.crates(buf, palette, crate[1], crate[2], crate[3])
			end)
		end
		for _, pile in ipairs({{-34, 14, 4, "z"}, {34, 14, 4, "z"},
				{46, -8, 3, "z"}}) do
			local axis = pile[4]
			local x2 = axis == "x" and pile[1] + pile[3] - 1 or pile[1]
			local z2 = axis == "z" and pile[2] + pile[3] - 1 or pile[2]
			prop("wood_pile", pile[1], pile[2], x2, z2, function()
				dressing.wood_pile(buf, palette, pile[1], pile[2], pile[3], axis)
			end)
		end

		-- 11. Low silverwood railings where a lane runs along a drop or a
		-- grove edge, and stepping stones off the paving into the trees.
		for _, line in ipairs({{-40, -26, -28, -26}, {28, -26, 40, -26},
				{-28, 12, -28, 20}, {28, 16, 28, 24}}) do
			prop("fence_line", math.min(line[1], line[3]),
				math.min(line[2], line[4]), math.max(line[1], line[3]),
				math.max(line[2], line[4]), function()
					dressing.fence_line(buf, palette, line[1], line[2],
						line[3], line[4])
				end)
		end
		-- Stepping stones off the paving into the litter. Each run is four
		-- cells of open ground, and `blueprint_kat` counts the lot, so a run
		-- that walks under a later prop shows up as a number there.
		local STEPPING = {{-16, 2, -16, 5}, {16, 2, 16, 5},
			{-9, -14, -6, -14}, {6, -14, 9, -14},
			{-16, 12, -13, 12}, {13, 12, 16, 12}}
		local stepping_stones = 0
		for _, run in ipairs(STEPPING) do
			prop("stepping_line", math.min(run[1], run[3]),
				math.min(run[2], run[4]), math.max(run[1], run[3]),
				math.max(run[2], run[4]), function()
					stepping_stones = stepping_stones +
						dressing.stepping_line(buf, palette, run[1], run[2],
							run[3], run[4])
				end)
		end

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
		local standards = layout.plant_grove(buf, palette, RADIUS, 6, SPECIMENS)

		-- 14. Ferns and pale grass on whatever litter is left.
		dressing.undergrowth(buf, palette, -RADIUS, -RADIUS, RADIUS, RADIUS, 5)

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
		-- ASCII byte order, not Lua's `<`, which is `strcoll` and so
		-- locale-dependent; see `parts.less_bytes`.
		table.sort(palette_list, parts.less_bytes)

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
				sockets = SOCKETS,
				standards = standards,
				stepping_stones = stepping_stones,
			},
		}
	end
end

return loader
