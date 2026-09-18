-- Dur Brannoc: the dwarf capital, and the first WALLED capital of the game.
--
-- This file is the CORE composition of docs/research/wp13-capitals-pois-
-- contract.md section 2.1 -- the 96 x 96 civic core, anchor-relative exactly
-- like a start, flat at y = 0 by construction, inside the contract's bounds of
-- x/z [-47, 47] and y [-2, 40] -- plus the run specifications the two OVERLAY
-- modules turn into the avenues and the curtain wall.
--
-- Dur Brannoc is the dwarf capital of the contract's section 2.4 table: a
-- stone-block citadel on the WP40 granite terrace, with pillars and arrowslits,
-- pine-and-slate halls, a forge court, and -- by the user's ruling of
-- 2026-09-14 -- a curtain wall. The Hearthpine palette is the city, the castle
-- kit is the citadel, and `default:stone_block` is the signature material every
-- capital part dresses itself in.
--
--   * `M.core()` returns the core composition in the exact shape of a start
--     composition (schema, canonical cells, bounds, sorted palette, landmarks)
--     plus `landmarks.sockets`, the NPC seam of
--     docs/research/wp13-npc-sockets-contract.md.
--   * `M.districts` is the four districts of the contract's section 2.1 --
--     market and professions, martial and garrison, lore and spiritual,
--     residential and cultural -- each a list of nine PLOT compositions and
--     four FILL compositions, every one of them with its own reference column,
--     because a plot outside the core stands on terraced ground. The rosters
--     are `dur_brannoc_district*.lua`, the builder is `dur_brannoc_plot.lua`
--     and which district stands in which quarter is the world seed's
--     (`dur_brannoc_quadrants.lua`).
--   * `M.quadrants` is that quadrant module, published so the blueprint source
--     and the offline lot predicate read the same geometry.
--   * `M.avenues` and `M.ring` are the runs `avenue.lua` turns into pavement.
--   * `M.wall` is the four runs `wall.lua` turns into curtain, turrets and
--     gatehouses at the 512 envelope edge, and `M.wall_plan` is the authored
--     geometry each of those runs carries (which side is the field, where the
--     turrets and the gate stand). The wall is an overlay and not a blueprint
--     for the reasons written at the top of `wall.lua`.
--
-- WHERE THE CORE DIFFERS FROM HIGHCOURT, and why
-- ----------------------------------------------
--   * Highcourt's open edge is a hedge; Dur Brannoc's is a CITADEL PARAPET --
--     two courses of castle masonry with merlons on a four-node rhythm and a
--     drum at each corner of the pad. A walled city's civic core is a precinct
--     inside the walls, not a field with four gate towers in it.
--   * The east quarter is the FORGE COURT instead of a service court: the two
--     royal booths stand in it, but so do the great forge, the smelting yard,
--     the charcoal stacks and the ore crates. It is the one quarter of this
--     capital that says dwarf from the crossing.
--   * Two palette handles, not three. Highcourt's crown is white marble over
--     brick, which needs a second handle; the dwarf signature IS
--     `default:stone_block` and is bound in the Hearthpine palette already, so
--     the only second handle is the slate roof of the civic buildings.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local palettes = dofile(directory .. "/palette.lua")
	local buildings = dofile(directory .. "/buildings.lua")(directory)
	local capitals = dofile(directory .. "/capitals.lua")(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local layout = dofile(directory .. "/layout.lua")(directory)
	local precinct_ring = dofile(directory .. "/precinct_ring.lua")
	local wall = dofile(directory .. "/wall.lua")(directory)
	local districts = dofile(directory .. "/dur_brannoc_districts.lua")(directory)
	local street_plan = dofile(directory .. "/street_plan.lua")(directory)

	local M = {}

	-- The four quadrants' lot grids and the seeded permutation that hands one
	-- grid to one district (`dur_brannoc_quadrants.lua`). Published here
	-- because that is where every consumer looks for a capital's geometry: the
	-- blueprint source asks it for the plot offsets, and
	-- `tools/wp13/capital_lots.lua` asks it for the lots themselves.
	M.quadrants = districts.quadrants

	local RADIUS = 47
	local SCHEMA = "grug_wp13_dur_brannoc_core_v1"

	-- The city's own patrol loop. The four gatehouses keep a two-waypoint
	-- watch each, for the reason Highcourt records: a gate tower's waypoints
	-- are on the wall walk and on the fighting deck five courses above it, and
	-- a ground loop that took either in would ask an NPC to step from the
	-- street to a rampart through a wall.
	local WATCH = "dur_brannoc_watch"

	-- The civic roof: slate, not plank. The contract's "pine-and-slate halls"
	-- is exactly this -- the Hearthpine palette's pine walls under the darkage
	-- slate family, which has the corner shapes the roof rasteriser needs.
	local SLATE = {
		roof_stair = "grug_decor:darkage_slate_tile_stair",
		roof_stair_outer = "grug_decor:darkage_slate_tile_stair_outer",
		roof_stair_inner = "grug_decor:darkage_slate_tile_stair_inner",
		roof_slab = "grug_decor:darkage_slate_tile_slab",
		roof_ridge = "grug_decor:darkage_slate_tile",
	}

	-- The king's hall's own dimensions, in one place, so the floor this
	-- composition lays inside it cannot be left behind by a hall of another
	-- size. `base`, `arcade` and `dais` are `capitals.king_hall`'s own.
	local HALL = {w = 31, d = 27, rise = 7, base = 2, arcade = 5, dais = 9}

	-- The travel plaza reserved for WP17: kerbed, lit from its own kerb and
	-- empty of everything above its paving.
	-- x1 is 11 and not 8: the east colonnade's eaves oversail its own footprint
	-- to x = 9, and a plaza that starts there has ten slabs hanging over the
	-- square WP17's pad is being kept clear for.
	local PLAZA = {x1 = 11, z1 = -32, x2 = 27, z2 = -12}

	-- The forge court: the whole north-east quarter, paved in one piece with
	-- the streets so a building stamped into it keeps its own apron.
	local COURT = {x1 = 22, z1 = 5, x2 = 45, z2 = 43}

	local STREETS = {
		-- The throne approach, from the south gate through the crossing to the
		-- hall's forecourt.
		{-2, -RADIUS, 2, 5, "avenue"},
		-- The service avenue behind the hall, out to the north gate.
		{-2, 38, 2, RADIUS, "avenue"},
		-- The east-west avenue, gate to gate through the same crossing.
		{-RADIUS, -2, RADIUS, 2, "avenue"},
		-- The two flank lanes past the hall and the back lane joining them.
		{-24, 0, -22, 42, "lane"},
		{19, 0, 21, 42, "lane"},
		{-24, 38, 21, 40, "lane"},
		-- The hall's forecourt.
		{-10, 3, 10, 5, "lane"},
		-- The gate forecourts: a gate chamber's door is in its city face and
		-- its doorstep is one node beyond the part's own footprint. The north
		-- gate's forecourt is the back lane, which already reaches it.
		{-8, -40, 8, -38, "lane"},
		{38, -8, 40, 8, "lane"},
		{-40, -8, -38, 8, "lane"},
		-- The travel plaza's approach off the east avenue.
		{4, -13, 11, -11, "lane"},
		-- The west quarter: the cistern court's walk and the temple's.
		{-34, 14, -25, 16, "lane"},
		{-38, 17, -36, 23, "lane"},
		-- The doorsteps of the outer houses and the guild.
		{-36, -17, -34, -15, "lane"},
		{-31, -38, -29, -36, "lane"},
		{34, -14, 36, -12, "lane"},
		{26, -40, 28, -38, "lane"},
		{17, -40, 19, -38, "lane"},
	}

	-- The plot roster. `make` is the generator, `module` the library it comes
	-- from, `x`/`z` the pad anchor of the rotated footprint, `turns` the
	-- rotation, `palette` and `roof` which handle it is built and roofed with.
	--
	-- `drop` and `recast` are the socket policy of the sockets contract, and
	-- they exist because a part cannot know how many of a thing a CAPITAL may
	-- have: one throne, one travel pad for WP17 and exactly two vendor families
	-- in `grug_traders`. The KAT asserts the resulting multiset.
	local PLOTS = {
		-- 1. The king's hall, on the axis, its great door looking down the
		-- approach to the south gate. Built with the slate handle as well as
		-- roofed with it: a lucarne takes its hood from the palette's own
		-- `roof_slab`, so a hall built with the plain handle would wear plank
		-- hoods on a slate roof.
		{id = "kings_hall", module = "capitals", make = "king_hall",
			x = -15, z = 9, turns = 0, palette = "slate", roof = "slate",
			spec = {w = HALL.w, d = HALL.d, rise = HALL.rise},
			drop = {waypoint = true}},

		-- 2. The four inner gatehouses, where the avenues leave the citadel
		-- precinct. Dur Brannoc's curtain wall is 209 nodes further out, so
		-- these are the citadel's own gates and not the city's.
		{id = "gate_south", module = "capitals", make = "gatehouse",
			x = -6, z = -RADIUS, turns = 0, palette = "dwarf", roof = "slate",
			spec = {patrol_group = "dur_brannoc_gate_south_tower",
				deck_group = "dur_brannoc_gate_south_tower", order = 2}},
		{id = "gate_west", module = "capitals", make = "gatehouse",
			x = -RADIUS, z = -6, turns = 1, palette = "dwarf", roof = "slate",
			spec = {patrol_group = "dur_brannoc_gate_west_tower",
				deck_group = "dur_brannoc_gate_west_tower", order = 2}},
		{id = "gate_north", module = "capitals", make = "gatehouse",
			x = -6, z = 41, turns = 2, palette = "dwarf", roof = "slate",
			spec = {patrol_group = "dur_brannoc_gate_north_tower",
				deck_group = "dur_brannoc_gate_north_tower", order = 2}},
		{id = "gate_east", module = "capitals", make = "gatehouse",
			x = 41, z = -6, turns = 3, palette = "dwarf", roof = "slate",
			spec = {patrol_group = "dur_brannoc_gate_east_tower",
				deck_group = "dur_brannoc_gate_east_tower", order = 2}},

		-- 3. The market square, west of the approach, its north apron on the
		-- great avenue's own kerb.
		{id = "market", module = "capitals", make = "market_square",
			x = -35, z = -28, turns = 0, palette = "dwarf",
			spec = {size = 25},
			drop = {waypoint = true},
			-- A booth without a trader is a flair NPC's work spot, and its id
			-- has to say booth: `market_vendor_1` with the role `idle` is a
			-- socket that argues with itself.
			recast = {vendor = {role = "idle", tags = {"work"},
				from = "_vendor_", to = "_booth_"}}},

		-- 4. The two colonnades flanking the approach.
		{id = "colonnade_west", module = "capitals", make = "colonnade",
			x = -9, z = -21, turns = 1, palette = "dwarf",
			spec = {len = 15, patrol_group = WATCH, order = 1}},
		{id = "colonnade_east", module = "capitals", make = "colonnade",
			x = 4, z = -21, turns = 3, palette = "dwarf",
			spec = {len = 15, patrol_group = WATCH, order = 6}},

		-- 5. The civic furniture: the king's statue east of the crossing and
		-- the cistern court in the west quarter.
		{id = "statue", module = "capitals", make = "statue_plinth",
			x = 12, z = -11, turns = 0, palette = "dwarf", spec = {}},
		{id = "cistern_court", module = "capitals", make = "well_court",
			x = -45, z = 9, turns = 0, palette = "dwarf", spec = {size = 11}},

		-- 6. The hall of the ancestors: the capital library's temple, in the
		-- west quarter, and where this capital's quest shell stands.
		{id = "ancestor_hall", module = "capitals", make = "temple",
			x = -44, z = 22, turns = 0, palette = "dwarf", roof = "slate",
			spec = {w = 13, d = 19, wall_h = 7, rise = 5},
			-- The temple publishes its own quest shell, and a capital has
			-- exactly one: the composition adds none of its own.
			--
			-- It does MOVE AND RETAG the shell. `capitals.temple` stands it
			-- three nodes inside its own door, in the nave -- where a shrine's
			-- own keeper belongs and a quest-giver does not. The user's
			-- playtest-round-2 ruling is that the elder stands on the doorstep
			-- and shows the street his face, so this plot puts him one node
			-- outside the door on the temple walk and tags him `door`, which is
			-- what turns an NPC round (`grug_mobs/start_npcs.lua`,
			-- `socket_face_yaw`).
			--
			-- Both halves are here and not in `capitals.lua` for the reason
			-- `highcourt_district_lore.lua` gives at the same socket: the
			-- generator cannot know which of its walls this composition puts to
			-- a lane, nor where this plot's path runs. `socket_overrides` is
			-- lane 3's hook, in the core's own frame -- the pad coordinates
			-- `parts.stamp` has already resolved.
			socket_overrides = function(placed)
				return {ancestor_hall_quest = {x = placed.x + 6,
					z = placed.z - 1, face = 0, tags = {"door"}}}
			end},

		-- 7. The forge court, the north-east quarter and this capital's
		-- signature. The great forge opens in its x- wall, like Dawnmere's
		-- smithy: the `workshop` interior kit stands the forge's cauldrons on
		-- the odd cells of the z- gable's inner run, and the generator's own
		-- chimney stack stands on the middle cell of that same wall and is
		-- written after the door.
		{id = "great_forge", module = "buildings", make = "workshop",
			x = 24, z = 8, turns = 0, palette = "dwarf",
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true}},
		{id = "smelting_yard", module = "buildings", make = "shed",
			x = 24, z = 27, turns = 0, palette = "dwarf",
			spec = {w = 13, d = 9, wall_h = 4, open_sides = {"z-", "x+"}}},

		-- 8. The masons' guild, in the south-east corner.
		{id = "masons_guild", module = "capitals", make = "scriptorium",
			x = 29, z = -46, turns = 2, palette = "dwarf", roof = "slate",
			spec = {w = 13, d = 17, wall_h = 6}},

		-- 9. The citizens' quarter: four houses on the outer ground. The
		-- cottages keep the generator's own door side (`z-`) and are TURNED to
		-- face their ground instead: the `home` kit furnishes the cell behind
		-- every other wall and only the z- doorway is authored clear of it.
		{id = "market_house", module = "buildings", make = "cottage",
			x = -45, z = -20, turns = 3, palette = "dwarf",
			spec = {w = 9, d = 9, wall_h = 5, roof = "gable",
				ridge_axis = "z", infill = true, shutters = true}},
		{id = "south_house", module = "buildings", make = "cottage",
			x = -41, z = -41, turns = 1, palette = "dwarf",
			spec = {w = 9, d = 9, wall_h = 5, roof = "hip",
				infill = true, shutters = true}},
		{id = "lane_house", module = "buildings", make = "cottage",
			x = 37, z = -17, turns = 1, palette = "dwarf",
			spec = {w = 9, d = 9, wall_h = 5, roof = "saltbox",
				ridge_axis = "x", infill = true, fancy_bed = true}},
		{id = "plaza_house", module = "buildings", make = "cottage",
			x = 9, z = -46, turns = 1, palette = "dwarf",
			spec = {w = 9, d = 9, wall_h = 5, roof = "gable",
				ridge_axis = "x", infill = true, shutters = true}},
	}

	-- Destination order is part of the consumer contract and never changes.
	local DESTINATION_ORDER = {"kings_hall", "gate_south", "gate_west",
		"gate_north", "gate_east", "ancestor_hall", "great_forge",
		"smelting_yard", "masons_guild", "market_house", "south_house",
		"lane_house", "plaza_house"}

	-- The corner waypoints of the city loop, in the open ground between the
	-- outer plots, so the walk along the precinct wall has something to follow
	-- between one quarter and the next.
	local CORNERS = {
		{id = "watch_south_west", x = -30, z = -35, face = 0, order = 2},
		{id = "watch_north_west", x = -28, z = 44, face = 2, order = 3},
		{id = "watch_north_east", x = 43, z = 33, face = 2, order = 4},
		{id = "watch_south_east", x = 22, z = -40, face = 0, order = 5},
	}

	-- Where the four avenues and the ring street run in the 512 envelope.
	-- These are not cells: they are the runs `avenue.lua` projects onto
	-- whatever surface the terrain has when a chunk is emerged.
	--
	-- THEY REACH 261, not the gate station at 256, because Dur Brannoc has a
	-- wall: the curtain's centre line is at +-256 and its gate tunnel runs
	-- through the whole seven-node thickness, so a road that stopped at the
	-- centre line would stop inside the gate.
	local GATE_OUT = 261
	M.avenues = {
		{id = "avenue_south", axis = "z", at = 0, from = -GATE_OUT, to = -48,
			gate = "gate_south"},
		{id = "avenue_north", axis = "z", at = 0, from = 48, to = GATE_OUT,
			gate = "gate_north"},
		{id = "avenue_west", axis = "x", at = 0, from = -GATE_OUT, to = -48,
			gate = "gate_west"},
		{id = "avenue_east", axis = "x", at = 0, from = 48, to = GATE_OUT,
			gate = "gate_east"},
	}

	-- The ring street at 96, which the district plots stand along. Every run
	-- spans the full -96..96 so the circuit closes at all four corners.
	M.ring = {
		{id = "ring_west", axis = "z", at = -96, from = -96, to = 96},
		{id = "ring_east", axis = "z", at = 96, from = -96, to = 96},
		{id = "ring_south", axis = "x", at = -96, from = -96, to = 96},
		{id = "ring_north", axis = "x", at = 96, from = -96, to = 96},
	}

	-- THE CURTAIN WALL, on the four edges of the 512 envelope.
	--
	-- The two axes are authored differently on purpose. The z-runs (west and
	-- east) carry the four CORNER TURRETS and therefore reach 261, five nodes
	-- past the envelope edge, so a turret centred on the corner is whole. The
	-- x-runs (south and north) stop at 252, one node short of the corner
	-- turret's own face, so the two never write into each other: the
	-- successor's first-run-wins arbitration would otherwise decide which
	-- half of a corner survives, and half a turret is not a corner.
	--
	-- `outside` says which lane sign faces the field, which is what turns the
	-- crenellated parapet, the loopholes and the merlon caps outward.
	local WALL_AT = 256
	local WALL_END = 261
	local WALL_SIDE = 252
	local TURRETS = {-192, -128, -64, 64, 128, 192}
	local function turret_list(extra)
		local list = {}
		for index = 1, #TURRETS do list[index] = TURRETS[index] end
		for index = 1, #(extra or {}) do list[#list + 1] = extra[index] end
		table.sort(list)
		return list
	end
	M.wall = {
		{id = "wall_west", axis = "z", at = -WALL_AT,
			from = -WALL_END, to = WALL_END},
		{id = "wall_east", axis = "z", at = WALL_AT,
			from = -WALL_END, to = WALL_END},
		{id = "wall_south", axis = "x", at = -WALL_AT,
			from = -WALL_SIDE, to = WALL_SIDE},
		{id = "wall_north", axis = "x", at = WALL_AT,
			from = -WALL_SIDE, to = WALL_SIDE},
	}
	-- `corners` is the pair of places each run's walk MEETS another run's, and
	-- it is what `wall.lua` section 1b reconciles. A z-run meets an x-run at its
	-- own corner turret's centre column (+-256); the x-run meets it four columns
	-- earlier, at its own end (+-252), which is where its walk stops and the
	-- turret's city-face opening begins. Each entry names MY column and the
	-- other run's line and column, and both runs of a pair name the same two
	-- places -- which is what lets them agree on a datum without either knowing
	-- the other exists.
	local function corner(p, axis, at, other_p)
		return {p = p, axis = axis, at = at, other_p = other_p}
	end
	M.wall_plan = {
		wall_west = {outside = -1, gates = {0},
			towers = turret_list({-WALL_AT, WALL_AT}),
			cross_towers = {-WALL_AT, WALL_AT},
			corners = {corner(-WALL_AT, "x", -WALL_AT, -WALL_SIDE),
				corner(WALL_AT, "x", WALL_AT, -WALL_SIDE)}},
		wall_east = {outside = 1, gates = {0},
			towers = turret_list({-WALL_AT, WALL_AT}),
			cross_towers = {-WALL_AT, WALL_AT},
			corners = {corner(-WALL_AT, "x", -WALL_AT, WALL_SIDE),
				corner(WALL_AT, "x", WALL_AT, WALL_SIDE)}},
		wall_south = {outside = -1, gates = {0}, towers = turret_list(),
			cross_towers = {},
			corners = {corner(-WALL_SIDE, "z", -WALL_AT, -WALL_AT),
				corner(WALL_SIDE, "z", WALL_AT, -WALL_AT)}},
		wall_north = {outside = 1, gates = {0}, towers = turret_list(),
			cross_towers = {},
			corners = {corner(-WALL_SIDE, "z", -WALL_AT, WALL_AT),
				corner(WALL_SIDE, "z", WALL_AT, WALL_AT)}},
	}

	-- The four districts and their 36 + 16 plots, resolved against this
	-- world's quadrant permutation (`dur_brannoc_districts.lua`). Wave 1 had
	-- ONE district here and published it as `M.district`; the four of wave 2
	-- are a roster the source resolves, so the field is gone and the note
	-- records it.
	M.districts = districts

	function M.core()
		local dwarf = palettes.new("dwarf")
		local slate = palettes.new("dwarf", SLATE)
		local handles = {dwarf = dwarf, slate = slate}
		local buf = parts.buffer()
		local doorways, rooms, sockets = {}, {}, {}
		local placed, inside_by_id, plot_order = {}, {}, {}
		local claimed = {}

		-- The citadel paving of the avenues and the cobble of the lanes, each
		-- resolved the way `capitals.lua` resolves it: the capital vocabulary
		-- is optional and falls back into the start vocabulary.
		local AVENUE = dwarf.maybe("castle_paving") or dwarf.node("plaza")
		local LANE = dwarf.node("path")
		local KERB = dwarf.node("plaza_edge")
		local STONE = dwarf.maybe("castle_wall") or dwarf.node("wall_accent")
		local CAP = dwarf.maybe("signature_slab") or dwarf.node("roof_slab")

		local function outdoors(x, z)
			for _, plot in ipairs(plot_order) do
				if x >= plot.x and x <= plot.x + plot.w - 1 and
						z >= plot.z and z <= plot.z + plot.d - 1 then
					return false
				end
			end
			return true
		end

		-- Ground this composition laid itself and has built nothing on.
		local GROUND = {}
		for _, role in ipairs({"ground", "ground_patch", "ground_bare"}) do
			GROUND[dwarf.node(role)] = true
		end

		-- Every prop the composition asks for MUST land; a prop quietly
		-- skipped is a hole in the authored scene no fixture can see (the
		-- Dawnmere lesson, wp13-hearthpine-library.md round A).
		local function refuse(name, x, z, reason)
			error("wp13 dur brannoc: prop " .. name .. " at " .. x .. "," ..
				z .. " was not placed: " .. reason, 0)
		end
		local function place(name, x1, z1, build)
			if build() == false then
				refuse(name, x1, z1, "the prop could not be completed")
			end
		end
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
		local function paved_prop(name, x1, z1, x2, z2, build)
			if not layout.free_area(buf, x1, z1, x2, z2, 4) then
				refuse(name, x1, z1, "the space is taken")
			end
			place(name, x1, z1, build)
		end

		local function pave(name, x1, z1, x2, z2, height)
			for z = z1, z2 do
				for x = x1, x2 do
					buf:put(x, 0, z, name)
				end
			end
			buf:clear(x1, 1, z1, x2, height or 4, z2)
		end

		-- 1. The terrace: coniferous litter over dirt, worn where the city
		-- walks.
		layout.meadow(buf, dwarf, RADIUS, 40)

		-- 2. The streets, the forge court and the kerbs of the great avenues.
		for _, street in ipairs(STREETS) do
			local name = (street[5] == "avenue") and AVENUE or LANE
			pave(name, street[1], street[2], street[3], street[4], 5)
		end
		pave(AVENUE, COURT.x1, COURT.z1, COURT.x2, COURT.z2, 5)
		dressing.inlay(buf, dwarf, COURT.x1, COURT.z1, COURT.x2, COURT.z2)
		for _, kerb in ipairs({{-3, -RADIUS, -3, 7}, {3, -RADIUS, 3, 7},
				{-3, 40, -3, RADIUS}, {3, 40, 3, RADIUS},
				{-RADIUS, -3, RADIUS, -3}, {-RADIUS, 3, RADIUS, 3}}) do
			for z = kerb[2], kerb[4] do
				for x = kerb[1], kerb[3] do
					buf:put(x, 0, z, KERB)
				end
			end
		end

		-- 3. The travel plaza: paving, two kerb rings and nothing inside it.
		-- The pad WP17 will put here needs room and sky, so the whole of its
		-- decoration is drawn INTO the ground course.
		pave(AVENUE, PLAZA.x1, PLAZA.z1, PLAZA.x2, PLAZA.z2, 6)
		dressing.inlay(buf, dwarf, PLAZA.x1, PLAZA.z1, PLAZA.x2, PLAZA.z2)
		dressing.inlay(buf, dwarf, PLAZA.x1 + 4, PLAZA.z1 + 4,
			PLAZA.x2 - 4, PLAZA.z2 - 4)
		local pad_x = math.floor((PLAZA.x1 + PLAZA.x2) / 2)
		local pad_z = math.floor((PLAZA.z1 + PLAZA.z2) / 2)
		local SIGNATURE = dwarf.maybe("signature") or KERB
		for step = -6, 6 do
			buf:put(pad_x + step, 0, pad_z, SIGNATURE)
			buf:put(pad_x, 0, pad_z + step, SIGNATURE)
		end
		for step = 0, 6 do
			for _, corner in ipairs({{step, 6 - step}, {-step, 6 - step},
					{step, step - 6}, {-step, step - 6}}) do
				buf:put(pad_x + corner[1], 0, pad_z + corner[2], SIGNATURE)
			end
		end

		-- 4. The plots.
		for _, plot in ipairs(PLOTS) do
			local spec = {}
			for key, value in pairs(plot.spec) do spec[key] = value end
			spec.id = plot.id
			if plot.roof then spec.roof_palette = handles[plot.roof] end
			local module = (plot.module == "capitals") and capitals or buildings
			local generator = module[plot.make]
			if type(generator) ~= "function" then
				error("wp13 dur brannoc: no generator " .. plot.make, 0)
			end
			local part = generator(handles[plot.palette], spec)
			-- Two plots may not share a cell. `parts.stamp` writes; it does not
			-- ask, so a plot laid over another cuts a silent hole in the first
			-- and the pad still builds -- the shape of defect that cost
			-- Dawnmere twenty-two props. Overwriting the STREETS and the ground
			-- under a plot is intended; overwriting another plot never is.
			local source, count = part.buffer:cells()
			for index = 1, count do
				local cell = source[index]
				local rx, rz = parts.rotate_footprint(cell.x, cell.z,
					part.w, part.d, plot.turns)
				local key = (plot.x + rx) .. ":" .. cell.y ..
					":" .. (plot.z + rz)
				local owner = claimed[key]
				if owner ~= nil then
					error("wp13 dur brannoc: the plot " .. plot.id ..
						" writes " .. cell.name .. " into " .. owner ..
						" at " .. key, 0)
				end
				claimed[key] = plot.id
			end
			local points = parts.stamp(buf, part, plot.x, 0, plot.z, plot.turns)
			local footprint = points.footprint[1]
			placed[plot.id] = {x = plot.x, z = plot.z, w = footprint.w,
				d = footprint.d, peak = part.peak}
			plot_order[#plot_order + 1] = placed[plot.id]
			for _, door in ipairs(points.doors or {}) do
				doorways[#doorways + 1] = {x = door.x, y = door.y, z = door.z,
					face = door.face, id = plot.id}
			end
			local spot = (points.inside or {})[1]
			if spot then
				inside_by_id[plot.id] = {x = spot.x, y = spot.y, z = spot.z}
			end
			for index = 1, #(points.room_corner or {}), 2 do
				local a = points.room_corner[index]
				local b = points.room_corner[index + 1]
				rooms[#rooms + 1] = {
					min = {x = math.min(a.x, b.x), y = a.y,
						z = math.min(a.z, b.z)},
					max = {x = math.max(a.x, b.x), y = a.y,
						z = math.max(a.z, b.z)},
					top = a.top, closed = a.closed, id = plot.id,
				}
			end
			-- What this plot changes about the sockets its PART published. A
			-- generator in `capitals.lua` knows its own building and nothing
			-- about the composition it is built into, so the roster says so
			-- instead of the library being edited per composition. Keyed by
			-- socket id and a function of where the plot was actually placed,
			-- because that is where the answers are; the same hook
			-- `highcourt_plot.lua` gives a district plot.
			local overrides = {}
			if type(plot.socket_overrides) == "function" then
				overrides = plot.socket_overrides(placed[plot.id])
			end
			for _, entry in ipairs(points.sockets or {}) do
				local drop = plot.drop and plot.drop[entry.role]
				if not drop then
					local recast = plot.recast and plot.recast[entry.role]
					local override = overrides[entry.id] or {}
					local out = {id = entry.id, role = entry.role,
						x = override.x or entry.x, y = override.y or entry.y,
						z = override.z or entry.z,
						face = override.face or entry.face,
						group = entry.group,
						order = entry.order, kind = entry.kind,
						-- `spawn` travels with the socket: a generator that
						-- publishes a spare must not lose it here.
						spawn = entry.spawn,
						tags = override.tags or entry.tags}
					if recast then
						out.role = recast.role
						out.tags = recast.tags
						out.kind, out.group, out.order = nil, nil, nil
						if recast.from then
							out.id = out.id:gsub(recast.from, recast.to, 1)
						end
					end
					sockets[#sockets + 1] = out
				end
			end
		end

		-- 5. The hall's floor: a stone-block edging either side of the carpet
		-- and a band across the nave at every arcade bay, with braziers
		-- between the bays. The generator owns the architecture; what a
		-- twenty-five-node nave of one paving material needs is a floor
		-- somebody drew.
		local nave = {}
		do
			local hall = placed.kings_hall
			local floor_y = HALL.base
			local west = hall.x + HALL.arcade + 1
			local east = hall.x + HALL.w - 2 - HALL.arcade
			local carpet_from = hall.z + 1
			local carpet_to = hall.z + HALL.d - HALL.dais - 1
			local centre = hall.x + math.floor((HALL.w - 1) / 2)
			local paving_name = slate.maybe("castle_paving") or
				slate.node("plaza")
			local function inlay_floor(x, z)
				local cell = buf:at(x, floor_y, z)
				if cell == nil or cell.name ~= paving_name then
					error("wp13 dur brannoc: the hall's floor at " .. x .. "," ..
						z .. " is " .. (cell and cell.name or "air") ..
						", not the paving this band is laid into", 0)
				end
				buf:put(x, floor_y, z, SIGNATURE)
				nave[#nave + 1] = {x = x, z = z}
			end
			for z = carpet_from, carpet_to do
				inlay_floor(centre - 2, z)
				inlay_floor(centre + 2, z)
			end
			for z = carpet_from + 3, carpet_to, 4 do
				for x = west, east do
					if x < centre - 2 or x > centre + 2 then
						inlay_floor(x, z)
					end
				end
			end
			for _, z in ipairs({carpet_from + 5, carpet_to - 4}) do
				for _, x in ipairs({centre - 4, centre + 4}) do
					for level = floor_y + 1, floor_y + 2 do
						local cell = buf:at(x, level, z)
						if cell ~= nil and cell.name ~= parts.AIR then
							error("wp13 dur brannoc: the brazier at " .. x ..
								"," .. z .. " stands in " .. cell.name, 0)
						end
					end
					parts.floor_torch(buf, dwarf, x, floor_y + 1, z)
				end
			end
		end

		-- 6. The forge court: the two royal booths of the contract's `vendor`
		-- pair, the charcoal stacks, the ore crates, the quenching cauldrons
		-- and the court's own lamps. This is where the two fixed vendor
		-- offsets of `grug_traders/vendors.lua` come to rest.
		local VENDORS = {
			{id = "vendor_race", kind = "race", x = 42, z = 10},
			{id = "vendor_general", kind = "general", x = 42, z = 17},
		}
		for _, booth in ipairs(VENDORS) do
			paved_prop("booth", booth.x - 1, booth.z - 1, booth.x + 3,
				booth.z + 3, function()
					dressing.stall(buf, dwarf, booth.x, booth.z, 0)
				end)
		end
		for _, pile in ipairs({{23, 38, 4, "z"}, {26, 38, 4, "z"},
				{42, 24, 4, "z"}, {30, 38, 4, "z"}, {34, 38, 4, "z"},
				{22, 12, 4, "z"}}) do
			local x2 = (pile[4] == "x") and pile[1] + pile[3] - 1 or pile[1]
			local z2 = (pile[4] == "z") and pile[2] + pile[3] - 1 or pile[2]
			paved_prop("charcoal_stack", pile[1], pile[2], x2, z2, function()
				dressing.wood_pile(buf, dwarf, pile[1], pile[2], pile[3],
					pile[4])
			end)
		end
		for _, stack in ipairs({{23, 23}, {24, 23}, {42, 30}, {42, 31},
				{42, 33}, {38, 41}, {39, 41}, {41, 41}, {44, 26}, {44, 27},
				{44, 34}, {22, 20}}) do
			paved_prop("ore_crates", stack[1], stack[2], stack[1], stack[2],
				function()
					dressing.crates(buf, dwarf, stack[1], stack[2], 2)
				end)
		end
		-- The quenching cauldrons and the anvil line: the palette's own hearth
		-- and workbench roles, stood in the open between the forge and the
		-- smelting yard, which is what the working half of a forge court is.
		-- (`workbench` is an iron block in this palette and an anvil in two
		-- others; either reads as the same thing on a paved court.)
		for _, spot in ipairs({{30, 23}, {32, 23}, {34, 23}}) do
			paved_prop("cauldron", spot[1], spot[2], spot[1], spot[2],
				function()
					buf:put(spot[1], 1, spot[2], dwarf.node("hearth"))
				end)
		end
		for _, spot in ipairs({{26, 23}, {28, 23}, {36, 23}, {38, 23}}) do
			paved_prop("anvil", spot[1], spot[2], spot[1], spot[2],
				function()
					buf:put(spot[1], 1, spot[2], dwarf.node("workbench"))
				end)
		end
		for _, seat in ipairs({{44, 36, 0, "z"}, {22, 28, 1, "z"}}) do
			local x2 = (seat[4] == "x") and seat[1] + 2 or seat[1]
			local z2 = (seat[4] == "z") and seat[2] + 2 or seat[2]
			paved_prop("court_bench", seat[1], seat[2], x2, z2, function()
				dressing.bench(buf, dwarf, seat[1], seat[2], seat[3], 3,
					seat[4])
			end)
		end
		for _, lamp in ipairs({{22, 7}, {38, 6}, {22, 42}, {45, 42},
				{42, 22}, {22, 24}}) do
			paved_prop("court_lamp", lamp[1], lamp[2], lamp[1], lamp[2],
				function()
					dressing.path_light(buf, dwarf, lamp[1], lamp[2])
				end)
		end

		-- 7. The plaza's kerb lamps and the street lighting. The great
		-- avenue's lamp line stops one node short of the crossing: a standard
		-- on the kerb at x = +-3 is on the verge of one avenue and in the
		-- CARRIAGEWAY of the other.
		for _, lamp in ipairs({{PLAZA.x1, PLAZA.z1}, {PLAZA.x2, PLAZA.z1},
				{PLAZA.x1, PLAZA.z2}, {PLAZA.x2, PLAZA.z2}}) do
			paved_prop("plaza_lamp", lamp[1], lamp[2], lamp[1], lamp[2],
				function()
					dressing.path_light(buf, dwarf, lamp[1], lamp[2])
				end)
		end
		layout.street_lamps(buf, dwarf, 0, -44, -6, 8, outdoors)
		layout.street_lamps(buf, dwarf, 0, 42, RADIUS - 2, 8, outdoors)
		for _, spot in ipairs({{-6, -6}, {6, -6}, {-6, 6}, {6, 6},
				{-25, -6}, {-25, 6}, {25, -6}, {25, 6},
				{-40, -6}, {-40, 6}, {40, -6}, {40, 6},
				{-25, 18}, {-25, 30}, {28, -16}, {-16, -6}, {16, -6},
				{-34, -8}, {34, 4}}) do
			if outdoors(spot[1], spot[2]) and
					layout.free(buf, spot[1], spot[2], 4) then
				paved_prop("street_lamp", spot[1], spot[2], spot[1], spot[2],
					function()
						dressing.path_light(buf, dwarf, spot[1], spot[2])
					end)
			end
		end

		-- 8. Benches at the crossing and on the hall's forecourt.
		for _, seat in ipairs({{-6, -4, 0, "x"}, {4, -4, 0, "x"},
				{-6, 4, 2, "x"}, {4, 4, 2, "x"}}) do
			paved_prop("bench", seat[1], seat[2], seat[1] + 2, seat[2],
				function()
					dressing.bench(buf, dwarf, seat[1], seat[2], seat[3], 3,
						"x")
				end)
		end
		for _, bed in ipairs({{-12, 3, -10, 5}, {9, 3, 11, 5}}) do
			paved_prop("planter", bed[1], bed[2], bed[3], bed[4], function()
				dressing.planter(buf, dwarf, bed[1], bed[2], bed[3], bed[4])
			end)
		end

		-- 9. Pine stands on the turf the quarters leave, which is what the
		-- Hearthpine terrace looks like where the city has not paved it.
		-- THREE NODES CLEAR OF THE PRECINCT RING, every one of them. A pine
		-- crown reaches two nodes from its stem, the parapet is written after
		-- the trees and only asks whether the four courses above the ground are
		-- free -- so a stem at the ring's own column lets the wall be built
		-- under it and hangs needles on the merlon cap. The KAT's shape rule
		-- (a bottom slab carries nothing) is what found that.
		local pines = layout.plant_pines(buf, dwarf, {
			{-28, -42, 9}, {-20, -38, 10}, {-14, -42, 9}, {-26, -34, 9},
			{22, -42, 9}, {22, -36, 8}, {5, -38, 10}, {5, -26, 9},
			{5, -18, 8}, {31, -20, 9}, {31, -12, 8}, {-16, 42, 9},
			{12, 42, 10}, {-30, 6, 8}, {-34, 4, 9}, {-8, -34, 9},
			{-32, -20, 8}, {16, -38, 9}, {-20, -28, 9}, {26, -34, 8},
		})
		if pines < 12 then
			error("wp13 dur brannoc: only " .. pines ..
				" pine stands found open ground", 0)
		end

		-- 10. THE CITADEL PARAPET, and the four drums at the corners of the
		-- pad: Dur Brannoc's core edge in place of Highcourt's hedge.
		--
		-- The DRUMS FIRST. The protected parapet explicitly skips the five square
		-- boundary columns at each corner; each closed drum perimeter owns that
		-- detour and the first parapet column beyond the skip joins straight into
		-- it. This is an authored corner substitution, not an occupied-cell stop.
		local drums = 0
		for _, corner in ipairs({{-45, -45}, {45, -45}, {-45, 45}, {45, 45}}) do
			local cx, cz = corner[1], corner[2]
			if layout.free_area(buf, cx - 2, cz - 2, cx + 2, cz + 2, 8) then
				buf:ring(cx - 2, cz - 2, cx + 2, cz + 2, 1, 7, STONE)
				buf:fill(cx - 1, 1, cz - 1, cx + 1, 1, cz + 1, AVENUE)
				for z = cz - 2, cz + 2 do
					for x = cx - 2, cx + 2 do
						if (x == cx - 2 or x == cx + 2 or z == cz - 2 or
								z == cz + 2) and (x + z) % 2 == 0 then
							buf:put(x, 8, z, STONE)
							buf:put(x, 9, z, CAP)
						end
					end
				end
				drums = drums + 1
			end
		end
		if drums ~= 4 then
			error("wp13 dur brannoc: " .. drums ..
				" of the four corner drums found room", 0)
		end
		-- The protected parapet is walked round the whole pad after the content.
		-- It wins every ordinary column; the shared mask omits the four authored
		-- gatehouse bands and the callback preserves the four corner drums.
		local parapet = 0
		precinct_ring.walk(function(x, z)
			precinct_ring.clear_wallmounted(buf, parts, x, z, 4)
			buf:put(x, 1, z, STONE)
			buf:put(x, 2, z, STONE)
			if (x + z) % 4 == 0 then
				buf:put(x, 3, z, STONE)
				local above = buf:at(x, 5, z)
				if not above or above.name == "air" then
					buf:put(x, 4, z, CAP)
				end
			end
			parapet = parapet + 1
		end, {skip = precinct_ring.is_corner})

		-- 11. Undergrowth on the turf between the quarters.
		dressing.undergrowth(buf, dwarf, -RADIUS, -RADIUS, RADIUS, RADIUS, 5)

		-- 12. The sockets the composition owns.
		local function socket(id, role, x, y, z, face, extra)
			local entry = {id = id, role = role, x = x, y = y, z = z,
				face = face % 4}
			for key, value in pairs(extra or {}) do entry[key] = value end
			sockets[#sockets + 1] = entry
		end
		for _, booth in ipairs(VENDORS) do
			socket(booth.id, "vendor", booth.x + 1, 1, booth.z - 1, 0,
				{kind = booth.kind})
		end
		socket("travel_waypoint", "waypoint", pad_x, 1, pad_z, 0)
		for _, corner in ipairs(CORNERS) do
			socket(corner.id, "guard_patrol", corner.x, 1, corner.z,
				corner.face, {group = WATCH, order = corner.order})
		end
		socket("court_idle_forge", "idle", 41, 1, 23, 3, {tags = {"work"}})
		socket("court_idle_yard", "idle", 28, 1, 24, 0, {tags = {"work"}})
		socket("court_idle_fire", "idle", 35, 1, 39, 0, {tags = {"fire"}})
		socket("forecourt_idle_west", "idle", -6, 1, 3, 1, {tags = {"bench"}})
		socket("forecourt_idle_east", "idle", 7, 1, 3, 3, {tags = {"bench"}})
		-- Two SPARE spots. `spawn = false` is the sockets contract's own word
		-- for them (playtest round 2, 2026-09-15): a real authored standing
		-- position that reaches every consumer and that NOBODY IS PLACED ON, so
		-- a villager's amble has somewhere to go that is not another villager's
		-- doorstep. Without them a settlement has exactly as many idle spots as
		-- idle villagers, every spot is permanently occupied, and the amble is
		-- four people swapping four chairs.
		--
		-- The first version of this composition wrote them as ordinary idle
		-- spots with a `walk` tag, which is a description and not a contract:
		-- the engine placed a villager on each of them and the two ends of the
		-- line were back. `grug_core/settlement_sockets.lua` normalises the
		-- field, `grug_mobs/start_npcs.lua` counts them out of the roster and
		-- keeps them as wander targets, and the KAT asserts both.
		-- No tag. A tag is what the spoken line and the facing rule read
		-- (`_grug_idle_tag`, `FACE_AWAY_TAGS`), and a spare has neither a line
		-- nor a door: `spawn = false` is the whole of what it is, which is the
		-- shape lane 3's spares settled on.
		socket("citadel_walk_west", "idle", -23, 1, 20, 0, {spawn = false})
		socket("citadel_walk_north", "idle", 20, 1, 30, 2, {spawn = false})

		-- 13. Pane shapes, settled once over the finished pad.
		parts.resolve_panes(buf)

		-- 14. Canonical cell list, bounds and palette.
		local source, count = buf:cells()
		local cells = {}
		for index = 1, count do cells[index] = source[index] end
		table.sort(cells, function(a, b)
			if a.z ~= b.z then return a.z < b.z end
			if a.y ~= b.y then return a.y < b.y end
			return a.x < b.x
		end)
		local light_names = {[dwarf.node("light_post")] = true,
			[dwarf.node("light_wall")] = true,
			[dwarf.node("light_indoor")] = true}
		local lights = {}
		local names, palette_list = {}, {}
		local minp = {x = cells[1].x, y = cells[1].y, z = cells[1].z}
		local maxp = {x = cells[1].x, y = cells[1].y, z = cells[1].z}
		for index = 1, #cells do
			local cell = cells[index]
			if light_names[cell.name] then
				lights[#lights + 1] = {x = cell.x, y = cell.y, z = cell.z}
			end
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
		table.sort(palette_list, parts.less_bytes)

		-- The sockets contract carries `dir` as a unit vector; the parts carry
		-- `face` as a facedir, because a facedir is what rotates with a
		-- stamped part. This is the settlement boundary, so it is converted
		-- here, with the library's own table rather than with an engine call.
		for _, entry in ipairs(sockets) do
			local dx, dz = parts.facedir_step(entry.face)
			entry.dir = {x = dx, z = dz}
		end

		local destinations = {}
		for _, id in ipairs(DESTINATION_ORDER) do
			local spot = inside_by_id[id]
			if not spot then
				error("wp13 dur brannoc: destination " .. id .. " is missing", 0)
			end
			destinations[#destinations + 1] =
				{id = id, x = spot.x, y = spot.y, z = spot.z}
		end

		local function box(id, margin, lift)
			local plot = placed[id]
			return {
				min = {x = plot.x - margin, y = -1, z = plot.z - margin},
				max = {x = plot.x + plot.w - 1 + margin,
					y = plot.peak + lift, z = plot.z + plot.d - 1 + margin},
			}
		end
		local function door_of(id)
			for _, door in ipairs(doorways) do
				if door.id == id then
					return {x = door.x, y = door.y, z = door.z}
				end
			end
			error("wp13 dur brannoc: no door for " .. id, 0)
		end

		return {
			schema = SCHEMA,
			cells = cells,
			bounds = {min = minp, max = maxp},
			palette = palette_list,
			landmarks = {
				-- A capital core has no player spawn; `arrival` is the
				-- spawn-equivalent landmark, the crossing of the two great
				-- avenues, and every route starts there.
				arrival = {x = 0, y = 1, z = 0},
				gate_south = {x = 0, y = 1, z = -RADIUS},
				gate_north = {x = 0, y = 1, z = RADIUS},
				gate_east = {x = RADIUS, y = 1, z = 0},
				gate_west = {x = -RADIUS, y = 1, z = 0},
				main_street = {min = {x = -2, y = 0, z = -RADIUS},
					max = {x = 2, y = 5, z = 5}},
				avenue_south = {min = {x = -2, y = 0, z = -RADIUS},
					max = {x = 2, y = 5, z = 5}},
				avenue_north = {min = {x = -2, y = 0, z = 38},
					max = {x = 2, y = 5, z = RADIUS}},
				avenue_west = {min = {x = -RADIUS, y = 0, z = -2},
					max = {x = -3, y = 5, z = 2}},
				avenue_east = {min = {x = 3, y = 0, z = -2},
					max = {x = RADIUS, y = 5, z = 2}},
				throne_approach = {min = {x = -2, y = 2, z = 9},
					max = {x = 2, y = 8, z = 33}},
				-- The reserved square is the plaza INSIDE its kerb: the four
				-- lamp standards stand on the kerb ring itself.
				waypoint_plaza = {min = {x = PLAZA.x1 + 1, y = 0,
						z = PLAZA.z1 + 1},
					max = {x = PLAZA.x2 - 1, y = 4, z = PLAZA.z2 - 1}},
				forge_court = {min = {x = COURT.x1, y = 0, z = COURT.z1},
					max = {x = COURT.x2, y = 8, z = COURT.z2}},
				kings_hall = box("kings_hall", 2, 2),
				kings_hall_door = door_of("kings_hall"),
				market = box("market", 1, 1),
				ancestor_hall = box("ancestor_hall", 2, 4),
				ancestor_hall_door = door_of("ancestor_hall"),
				destinations = destinations,
				doors = doorways,
				rooms = rooms,
				lights = lights,
				sockets = sockets,
				parapet_columns = parapet,
				corner_drums = drums,
				pines = pines,
				nave_floor = #nave,
			},
		}
	end

	-- The overlay seam, in one place: the run list in authored order (avenues
	-- first, then the ring street, then the wall) and the one function that
	-- turns a run into cells. The successor's first-run-wins arbitration reads
	-- this order, so the avenue runs through the gate and the wall yields the
	-- cells of the road it lets past.
	-- `lanes` is the district lane list of `dur_brannoc_quadrants.lua`, handed
	-- in by the blueprint source. The lanes come AFTER the avenues and the ring
	-- and BEFORE the wall: a lane yields the cells of the great road it meets,
	-- and the wall yields the cells of every road it lets through its gate.
	function M.overlay_runs(lanes)
		-- THE JUNCTION PLATEAUS are attached here, and here is the only
		-- place they can be. A plateau is a property of TWO street runs, and
		-- only the composition knows which of its overlay runs ARE streets:
		-- the curtain wall is an overlay run too, and a road passing through
		-- its gate is not a crossroads. `wp13/street_plan.lua` turns the
		-- street rectangles -- which are static, and are what the overlay's
		-- identity is already hashed from -- into the squares they share, and
		-- `wp13/avenue.lua` gives each square its height from the two runs'
		-- own ground. The runs that are not streets are appended afterwards
		-- and carry no junctions at all.
		local streets = {}
		for _, list in ipairs({M.avenues, M.ring, lanes or {}}) do
			for index = 1, #list do streets[#streets + 1] = list[index] end
		end
		-- AND THE GATE PASSAGES, for the same reason and out of the same
		-- rectangles: a street runs THROUGH the structure that is not a street,
		-- and inside that passage the structure owns the lanes either side of
		-- the carriageway. `wp13/avenue.lua` writes no plank walk, no rail and
		-- no pillar there, which is the sentence the per-capital kerb parapets
		-- this rule replaced each carried in their own words.
		local runs = street_plan.attach(streets, nil,
			{{runs = M.wall, half = wall.HALF}})
		for index = 1, #M.wall do runs[#runs + 1] = M.wall[index] end
		return runs
	end

	-- Every node name either overlay may write, byte-sorted and without
	-- duplicates: the union of the road's vocabulary and the wall's, which is
	-- what the settlement's shared content channel is closed over and what the
	-- overlay's specification identity is written from.
	function M.overlay_names(avenue, palette)
		local seen, list = {}, {}
		for _, source in ipairs({avenue.palette_names(palette),
				wall.palette_names(palette)}) do
			for index = 1, #source do
				local name = source[index]
				if not seen[name] then
					seen[name] = true
					list[#list + 1] = name
				end
			end
		end
		table.sort(list, parts.less_bytes)
		return list
	end

	-- THE CAUSEWAY PARAPET IS THE ROAD MODULE'S NOW.
	--
	-- This composition used to add one course of masonry on a kerb column the
	-- road had had to FILL by three or more courses: an embankment out of the
	-- blend band is a fine thing to look at and a bad thing to walk beside, and
	-- `wp13/avenue.lua` was the shared road of capitals whose built roads were
	-- frozen against it, so the parapet went here.
	--
	-- Playtest 5 (2026-09-16) settled that the other way round. A street raised
	-- three or more nodes above its own ground is no longer FILLED at all -- it
	-- is a viaduct on pillars with air under it, and it carries a plank walk and
	-- a rail on the two VERGE lanes, outside the carriageway rather than on its
	-- outermost lane. Every capital gets it, in its own palette, from one rule.
	-- A kerb column of a raised span now has a single cell in it, so the test
	-- this routine ran could never fire again; it is gone rather than left to
	-- read as a parapet that is not there.

	-- One run, dispatched by its own id. A wall run carries authored geometry
	-- the seam's overlay spec has no field for -- which side is the field,
	-- where the turrets and the gate stand -- so it is looked up here, from the
	-- same table for every piece, which is what keeps a piece of a run exactly
	-- that stretch of the whole run.
	function M.overlay_run(avenue, palette, spec, surface)
		local plan = M.wall_plan[spec.id]
		if plan then return wall.run(palette, spec, surface, plan) end
		return avenue.run(palette, spec, surface)
	end

	return M
end

return loader
