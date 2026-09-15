-- Highcourt: the human capital, and the first capital of the game.
--
-- This file is the CORE composition of docs/research/wp13-capitals-pois-
-- contract.md section 2.1: the 96 x 96 civic core, anchor-relative exactly
-- like a start, flat at y = 0 by construction, inside the contract's bounds
-- of x/z [-47, 47] and y [-2, 40] (it reaches y 31, the hall's ridge
-- lantern). It is authored out of the capital parts of `capitals.lua` and
-- the start generators of `buildings.lua`, the same way Dawnmere Fields is
-- authored out of the latter alone.
--
-- Highcourt is the human capital of the contract's section 2.4 table: a
-- brick-and-white-stone city on a river plateau, half-timbered lanes, a
-- market square, a chapel with a belfry, and "orchards inside the wall ring".
--
-- THE WALL RING ARRIVED IN PLAYTEST ROUND 3 (user ruling, 2026-09-15). The
-- 2026-09-14 ruling had Highcourt among the three OPEN capitals; round 3
-- reversed it for this one capital, because the contract's own section 2.4
-- line for the human capital names a wall ring and because a capital the
-- player can walk into from any direction reads as a field with houses in it.
-- The wall is `wall.lua`'s overlay, the same mechanism Dur Brannoc landed
-- (wp13-dur-brannoc.md), in Highcourt's own palette: castle stonewall over
-- brick string courses, brick merlon caps, four gatehouses on the avenues.
-- The four gatehouses that stand where the avenues leave the CORE stay where
-- they are -- they are the precinct's gates, the ring's are 209 nodes further
-- out.
-- The white stone is the crown's, not the city's: the king's hall, the
-- chapel, the colonnades, the gatehouses and the civic furniture are dressed
-- in marble over citadel masonry under slate, and everything a citizen built
-- is the human palette's brick, plank and loam.
--
-- What else lives here:
--
--   * `M.core()` returns the core composition in the exact shape of a start
--     composition (schema, canonical cells, bounds, sorted palette,
--     landmarks) plus `landmarks.sockets`, the NPC seam of
--     docs/research/wp13-npc-sockets-contract.md.
--   * `M.district` is the market and professions district: a list of PLOT
--     compositions, each self-contained, each with its own reference column,
--     because a plot outside the core stands on terraced ground and cannot be
--     anchor-relative (`highcourt_district.lua`).
--   * `M.avenues` and `M.ring` are the runs `avenue.lua` turns into pavement
--     at whatever height the terrain has at the moment a chunk is emerged.
--
-- Nothing here is wired into the WP40 seam: the seam generalisation that
-- gives a settlement several blueprints is its own package (contract section
-- 2.2), and this lane deliberately does not touch it.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local palettes = dofile(directory .. "/palette.lua")
	local buildings = dofile(directory .. "/buildings.lua")(directory)
	local capitals = dofile(directory .. "/capitals.lua")(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local layout = dofile(directory .. "/layout.lua")(directory)
	local wall = dofile(directory .. "/wall.lua")(directory)
	local district = dofile(directory .. "/highcourt_district.lua")(directory)

	local M = {}

	local RADIUS = 47
	local SCHEMA = "grug_wp13_highcourt_core_v1"

	-- The city's own patrol loop (the sockets contract's `group`), and every
	-- waypoint in it carries its place in the walk: out along the southern
	-- orchard street, round the four corners of the open edge, back along
	-- the western orchard street and up the great avenue through the two
	-- colonnades. The four gate towers keep their own two-waypoint watches;
	-- see the gatehouse rows below for why they cannot be in this one.
	local WATCH = "highcourt_watch"

	-- The crown's white stone. `signature` is the role every capital part
	-- dresses itself in (podium, string courses, merlon caps, the market
	-- cross, the statue), so rebinding it is what turns one part from a city
	-- building into a royal one without a second generator.
	local WHITE = {
		signature = "grug_decor:darkage_marble",
		signature_stair = "grug_decor:darkage_marble_stair",
		signature_slab = "grug_decor:darkage_marble_slab",
	}

	-- The civic roof: slate, not plank. A hall, a chapel and a gate tower
	-- roofed in the same boards as a cottage read as big cottages, which is
	-- the defect the Dawnmere increment fixed with its brick roof; here the
	-- civic buildings carry the darkage slate family, which has the corner
	-- shapes the rasteriser needs.
	local SLATE = {
		roof_stair = "grug_decor:darkage_slate_tile_stair",
		roof_stair_outer = "grug_decor:darkage_slate_tile_stair_outer",
		roof_stair_inner = "grug_decor:darkage_slate_tile_stair_inner",
		roof_slab = "grug_decor:darkage_slate_tile_slab",
		roof_ridge = "grug_decor:darkage_slate_tile",
	}

	local function merged(...)
		local out = {}
		for _, source in ipairs({...}) do
			for role, name in pairs(source) do out[role] = name end
		end
		return out
	end

	-- The king's hall's own dimensions, in one place: the plot row below is
	-- built from them and so is the floor the composition lays inside it, so
	-- a hall of another size cannot leave its carpet edging behind.
	-- `base`, `arcade` and the dais offset are the generator's own
	-- (`capitals.king_hall`): y = 2 is the hall floor, the arcades stand at
	-- x = arcade and w - 1 - arcade, and the carpet runs from z = 1 to the
	-- foot of the dais at d - 9.
	local HALL = {w = 31, d = 27, rise = 7, base = 2, arcade = 5, dais = 9}

	-- The streets. Every one of them is five or three nodes wide, paved at
	-- y = 0 and cleared to head height; the plots are laid clear of them, so
	-- a plot stamped later never has to fight a street for a cell.
	--
	-- `role` is the surface: "avenue" is the citadel paving of the four
	-- great streets, "lane" the cobble of the inner ones.
	local STREETS = {
		-- The great avenue, from the south gate through the crossing to the
		-- forecourt of the king's hall: the throne approach of the contract,
		-- on the north-south axis.
		{-2, -RADIUS, 2, 5, "avenue"},
		-- The service avenue behind the hall, from the back lane to the
		-- north gate.
		{-2, 38, 2, RADIUS, "avenue"},
		-- The east-west avenue, gate to gate through the same crossing.
		{-RADIUS, -2, RADIUS, 2, "avenue"},
		-- The two side lanes past the hall's flanks, and the back lane that
		-- joins them behind it.
		{-22, -38, -20, 38, "lane"},
		{20, -38, 22, 38, "lane"},
		{-22, 38, 22, 40, "lane"},
		-- The forecourts the four gatehouses open onto: a gate chamber's
		-- door is in its city face and its doorstep is one node beyond the
		-- part's own footprint, so the composition owes each of them paving.
		{-8, -40, 8, -38, "lane"},
		{-8, 38, 8, 40, "lane"},
		{38, -8, 40, 8, "lane"},
		{-40, -8, -38, 8, "lane"},
		-- The market's north walk, from the great avenue to the square.
		{-36, -6, -3, -4, "lane"},
		-- The waypoint plaza's approach, from the great avenue east.
		{3, -14, 12, -12, "lane"},
		-- The chapel's walk and the well court's, off the west lane.
		{-23, 26, -21, 28, "lane"},
		{-36, 12, -21, 14, "lane"},
		-- The principal service court east of the hall, laid in one piece
		-- with the streets and NOT after the plots: a court paved after the
		-- buildings that stand in it clears their walls to head height, and
		-- the composition still builds. The workyard and the store are
		-- stamped over this rectangle and keep their own aprons.
		{23, 7, 46, 37, "lane"},
		-- The doorsteps of the four houses on the outer ring.
		{-37, 24, -35, 26, "lane"},
		{34, -25, 36, -23, "lane"},
		{34, -12, 36, -10, "lane"},
		{-37, 37, -35, 39, "lane"},
		{-37, -25, -35, -23, "lane"},
		{29, -36, 33, -34, "lane"},
	}

	-- The plot roster. `make` is the generator, `module` the library it comes
	-- from, `x`/`z` the pad anchor of the rotated footprint and `turns` the
	-- rotation. `palette` names which of the three handles below the part is
	-- built with, `roof` which roof handle it carries.
	--
	-- `drop` and `recast` are the socket policy, and they exist because a
	-- part does not know how many of a thing a CAPITAL may have. Three roles
	-- name a singular runtime seam: one throne, one travel pad for WP17, and
	-- exactly two vendor families in `grug_traders`. A part that offers more
	-- of them -- the market's four booths, the hall's own waypoint -- has
	-- those sockets dropped or re-published as what they actually are: a
	-- market booth without a trader is a flair NPC's work spot, not a sixth
	-- vendor the runtime would try to fill. The KAT asserts the resulting
	-- multiset against the contract, so the policy cannot drift.
	local PLOTS = {
		-- 1. The king's hall, on the north-south axis, its great door
		-- looking down the approach to the south gate.
		-- The hall is built with the slate handle as well as roofed with it.
		-- Its four lucarnes per slope take their hoods from the palette's
		-- own `roof_slab` rather than from the roof palette, so a hall built
		-- with the plain human handle wears four plank hoods on a slate
		-- roof; the two handles differ in nothing but the five roof roles.
		{id = "kings_hall", module = "capitals", make = "king_hall",
			x = -15, z = 9, turns = 0, palette = "slate", roof = "slate",
			spec = {w = HALL.w, d = HALL.d, rise = HALL.rise},
			drop = {waypoint = true}},

		-- 2. The four gatehouses. Highcourt has no curtain wall, so these
		-- are not wall towers: they are the four gates of an open city, each
		-- carrying the five-wide passage of the gate corridor, its two guard
		-- chambers and its share of the one patrol loop. The field face of
		-- the part (its loopholes) is turned outward by the rotation.
		--
		-- Each gate keeps its own TOWER WATCH of two waypoints instead of a
		-- share of the city loop, and that is the part's geometry talking:
		-- its patrol waypoint stands on the wall walk at y = 7 and its deck
		-- waypoint on the fighting top at y = 12, five courses higher, with
		-- only the internal flight between them. A ground loop that took
		-- either one in would ask an NPC to step from the street to the
		-- wall walk through a wall -- and Highcourt has no curtain wall to
		-- carry a walk from one gate to the next, so the walk inside each
		-- gatehouse is all there is. `order = 2` puts the chamber above the
		-- deck the part always numbers 1, which makes each tower a loop of
		-- 1..2 that its own stair really joins.
		{id = "gate_south", module = "capitals", make = "gatehouse",
			x = -6, z = -RADIUS, turns = 0, palette = "white", roof = "slate",
			spec = {patrol_group = "highcourt_gate_south_tower",
				deck_group = "highcourt_gate_south_tower", order = 2}},
		{id = "gate_west", module = "capitals", make = "gatehouse",
			x = -RADIUS, z = -6, turns = 1, palette = "white", roof = "slate",
			spec = {patrol_group = "highcourt_gate_west_tower",
				deck_group = "highcourt_gate_west_tower", order = 2}},
		{id = "gate_north", module = "capitals", make = "gatehouse",
			x = -6, z = 41, turns = 2, palette = "white", roof = "slate",
			spec = {patrol_group = "highcourt_gate_north_tower",
				deck_group = "highcourt_gate_north_tower", order = 2}},
		{id = "gate_east", module = "capitals", make = "gatehouse",
			x = 41, z = -6, turns = 3, palette = "white", roof = "slate",
			spec = {patrol_group = "highcourt_gate_east_tower",
				deck_group = "highcourt_gate_east_tower", order = 2}},

		-- 3. The market square, west of the approach.
		{id = "market", module = "capitals", make = "market_square",
			x = -36, z = -31, turns = 0, palette = "white",
			spec = {size = 25},
			drop = {waypoint = true},
			-- and the booth's id says booth, not vendor: an id is a string
			-- the NPC lane reads in logs, and `market_vendor_1` with the
			-- role `idle` is a socket that argues with itself.
			recast = {vendor = {role = "idle", tags = {"work"},
				from = "_vendor_", to = "_booth_"}}},

		-- 4. The two colonnades flanking the approach, turned so their
		-- walks run with it.
		{id = "colonnade_west", module = "capitals", make = "colonnade",
			x = -9, z = -21, turns = 1, palette = "white",
			spec = {len = 15, patrol_group = WATCH, order = 9}},
		{id = "colonnade_east", module = "capitals", make = "colonnade",
			x = 4, z = -21, turns = 3, palette = "white",
			spec = {len = 15, patrol_group = WATCH, order = 10}},

		-- 5. The civic furniture: the king's statue on the east side of the
		-- crossing, the public well court on the west.
		{id = "statue", module = "capitals", make = "statue_plinth",
			x = 12, z = -11, turns = 0, palette = "white", spec = {}},
		{id = "well_court", module = "capitals", make = "well_court",
			x = -46, z = 8, turns = 0, palette = "white", spec = {size = 11}},

		-- 6. The open edge, in place of a wall: a kerbed ring street, a
		-- clipped hedge with a gate gap and two rows of fruit trees, both
		-- pieces on the southern face either side of the gate. Turned so the
		-- street lies on the city side and the orchard outside it.
		--
		-- The piece is 23 x 13, not the 21 x 11 of its own footprint: the
		-- fruit trees stand ON the far row and their crowns reach three
		-- nodes, so a piece stamped hard against the pad edge puts leaves
		-- two nodes outside the core. Both are therefore inset.
		{id = "orchard_east", module = "capitals", make = "orchard_edge",
			x = 8, z = -45, turns = 2, palette = "human",
			spec = {len = 21, patrol_group = WATCH, order = 1}},
		{id = "orchard_west", module = "capitals", make = "orchard_edge",
			x = -45, z = -45, turns = 2, palette = "human",
			spec = {len = 21, patrol_group = WATCH, order = 7}},

		-- 7. The chapel with its belfry, on the west lane; the belfry itself
		-- is stamped on its ridge below.
		{id = "chapel", module = "buildings", make = "chapel",
			x = -34, z = 20, turns = 0, palette = "human", roof = "slate",
			spec = {w = 11, d = 15, wall_h = 6, door_side = "x+",
				door_index = 7, infill = true}},

		-- 8. The household's own buildings, in the service court east of the
		-- hall: the open workyard and the store.
		{id = "service_yard", module = "buildings", make = "shed",
			x = 25, z = 7, turns = 0, palette = "human",
			spec = {w = 13, d = 9, wall_h = 4, open_sides = {"z-", "x+"}}},
		-- The store's door is at index 4 and single-leaved on purpose. The
		-- `store` interior kit stands its roof posts on the odd cells of the
		-- gable wall's inner run (x1 + 2, x1 + 4, ...), so the centred
		-- double door of an eleven-wide longhouse opens straight onto a
		-- post: the doorway is a real hole in the wall and still not a way
		-- in. Hearthpine's nine-wide store misses the post by one cell,
		-- which is why nothing caught this before a capital asked for a
		-- wider one.
		{id = "service_store", module = "buildings", make = "longhouse",
			x = 25, z = 22, turns = 0, palette = "human",
			spec = {w = 11, d = 15, wall_h = 5, infill = true,
				door_index = 4}},

		-- 9. The half-timbered city: a workshop on the south lane and four
		-- houses along the outer ring.
		{id = "city_workshop", module = "buildings", make = "workshop",
			x = 31, z = -46, turns = 0, palette = "human",
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true}},
		-- The three houses keep the generator's own door side (`z-`) and are
		-- TURNED to face their lane instead. A cottage's `home` kit furnishes
		-- the cell behind every other wall -- bed corner, hearth, table --
		-- and only the z- doorway is authored clear of it, which is what
		-- every start uses; asking the same generator for a door in the gable
		-- end instead opens it onto the furniture.
		{id = "north_house", module = "buildings", make = "cottage",
			x = -46, z = 23, turns = 3, palette = "human",
			spec = {w = 9, d = 9, wall_h = 5, roof = "gable",
				ridge_axis = "x", infill = true, shutters = true}},
		{id = "lane_house", module = "buildings", make = "cottage",
			x = 37, z = -17, turns = 1, palette = "human",
			spec = {w = 9, d = 9, wall_h = 5, roof = "hip",
				infill = true, fancy_bed = true}},
		{id = "orchard_house", module = "buildings", make = "cottage",
			x = 37, z = -30, turns = 1, palette = "human",
			spec = {w = 9, d = 9, wall_h = 5, roof = "saltbox",
				ridge_axis = "x", infill = true, shutters = true}},
		{id = "chapel_house", module = "buildings", make = "cottage",
			x = -46, z = 36, turns = 3, palette = "human",
			spec = {w = 9, d = 9, wall_h = 5, roof = "hip",
				infill = true, shutters = true}},
		{id = "market_house", module = "buildings", make = "cottage",
			x = -46, z = -30, turns = 1, palette = "human",
			spec = {w = 9, d = 9, wall_h = 5, roof = "gable",
				ridge_axis = "z", infill = true, shutters = true}},
	}

	-- Destination order is part of the consumer contract and never changes.
	local DESTINATION_ORDER = {"kings_hall", "gate_south", "gate_west",
		"gate_north", "gate_east", "chapel", "service_yard", "service_store",
		"city_workshop", "north_house", "lane_house", "orchard_house",
		"chapel_house", "market_house"}

	-- The four corner waypoints of the city's patrol loop, in the open ground
	-- between the outer plots that no part reaches, so the walk along the
	-- open edge has something to follow between one orchard street and the
	-- next.
	local CORNERS = {
		{id = "watch_south_east", x = 34, z = -31, face = 0, order = 3},
		{id = "watch_north_east", x = 42, z = 32, face = 2, order = 4},
		{id = "watch_north_west", x = -38, z = 34, face = 2, order = 5},
		{id = "watch_south_west", x = -40, z = -16, face = 0, order = 6},
	}

	-- The waypoint plaza reserved for WP17: a flat, open, kerbed square east
	-- of the approach, with its lamps outside the open area and nothing at
	-- all inside it. The travel pad WP17 will put here needs room and sky,
	-- and a plaza with furniture in the middle is a plaza that has to be
	-- re-authored the day the pad arrives.
	local PLAZA = {x1 = 12, z1 = -32, x2 = 32, z2 = -12}

	-- Where the four avenues and the ring street run in the 512 envelope.
	-- These are not cells: they are the runs `avenue.lua` projects onto
	-- whatever surface the terrain has, and the successor calls it per chunk.
	-- The gate stations sit at +-256 on each axis (WP40); the core edge is
	-- at +-47, so a run starts one node clear of it.
	--
	-- THEY REACH 261, not the gate station at 256, since the wall ring landed:
	-- the curtain's centre line is at +-256 and its gate tunnel runs through
	-- the whole seven-node thickness, so a road that stopped at the centre
	-- line would stop inside the gate. Dur Brannoc records the same number for
	-- the same reason.
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

	-- The ring street: the square circuit at 96 that the district plots sit
	-- along, in the same four runs. Every run reaches the centre line of the
	-- two it meets -- all four span the full -96..96 -- because a side that
	-- stops at 92 leaves the circuit a hole at each corner, which is a ring
	-- street a patrol cannot walk round.
	M.ring = {
		{id = "ring_west", axis = "z", at = -96, from = -96, to = 96},
		{id = "ring_east", axis = "z", at = 96, from = -96, to = 96},
		{id = "ring_south", axis = "x", at = -96, from = -96, to = 96},
		{id = "ring_north", axis = "x", at = 96, from = -96, to = 96},
	}

	-- THE WALL RING, on the four edges of the 512 envelope (user ruling,
	-- playtest round 3). Authored exactly the way Dur Brannoc's is, because
	-- the geometry question is the same one and the answer is not Highcourt's
	-- to re-decide:
	--
	--   * the z-runs (west and east) carry the four CORNER TURRETS and
	--     therefore reach 261, five nodes past the envelope edge, so a turret
	--     centred on the corner is whole;
	--   * the x-runs (south and north) stop at 252, one node short of the
	--     corner turret's own face, so the two never write into each other:
	--     the successor's first-run-wins arbitration would otherwise decide
	--     which half of a corner survives, and half a turret is not a corner.
	--
	-- `outside` says which lane sign faces the field, which is what turns the
	-- crenellated parapet, the loopholes and the merlon caps outward. Every
	-- side carries ONE gate, on its avenue, and the avenues are authored FIRST
	-- in the overlay's run list, so the road wins every cell of the passage and
	-- the four gates are walkable.
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
	M.wall_plan = {
		wall_west = {outside = -1, gates = {0},
			towers = turret_list({-WALL_AT, WALL_AT}),
			cross_towers = {-WALL_AT, WALL_AT}},
		wall_east = {outside = 1, gates = {0},
			towers = turret_list({-WALL_AT, WALL_AT}),
			cross_towers = {-WALL_AT, WALL_AT}},
		wall_south = {outside = -1, gates = {0}, towers = turret_list(),
			cross_towers = {}},
		wall_north = {outside = 1, gates = {0}, towers = turret_list(),
			cross_towers = {}},
	}

	-- The overlay seam, in one place, exactly as Dur Brannoc spells it: the
	-- avenues first, then the ring street, then the district lanes, then the
	-- wall. The successor's first-run-wins arbitration reads this order, so
	-- the avenue runs through the gate and the wall yields the cells of the
	-- road it lets past.
	--
	-- The district lanes belong to the four QUADRANTS and not to the districts
	-- standing in them, so the caller passes them in rather than this file
	-- reaching for `highcourt_quadrants.lua`: the core composition knows about
	-- the streets it authored itself and about nothing else.
	function M.overlay_runs(lanes)
		local runs = {}
		for _, list in ipairs({M.avenues, M.ring, lanes or {}, M.wall}) do
			for index = 1, #list do runs[#runs + 1] = list[index] end
		end
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

	M.district = district.market

	function M.core()
		local human = palettes.new("human")
		local white = palettes.new("human", WHITE)
		local slate = palettes.new("human", merged(WHITE, SLATE))
		local handles = {human = human, white = white, slate = slate}
		local buf = parts.buffer()
		local doorways, rooms, sockets = {}, {}, {}
		local placed, inside_by_id, plot_order = {}, {}, {}
		local claimed = {}

		-- The citadel paving of the avenues and the cobble of the lanes,
		-- each resolved the way `capitals.lua` resolves it: the capital
		-- vocabulary is optional and falls back into the start vocabulary.
		local AVENUE = white.maybe("castle_paving") or white.node("plaza")
		local LANE = human.node("path")
		local KERB = human.node("plaza_edge")

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
			GROUND[human.node(role)] = true
		end

		-- Every prop the composition asks for MUST land; a prop quietly
		-- skipped is a hole in the authored scene no fixture can see
		-- (the Dawnmere lesson, wp13-hearthpine-library.md round A).
		local function refuse(name, x, z, reason)
			error("wp13 highcourt: prop " .. name .. " at " .. x .. "," .. z ..
				" was not placed: " .. reason, 0)
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
						refuse(name, x1, z1, "the ground at " .. x .. "," ..
							z .. " is " ..
							(below and below.name or "air"))
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

		-- A paved rectangle with its headroom cleared, written from a NAME
		-- rather than from a role: the citadel paving is an optional role
		-- with a fallback, which `layout.pave` cannot take.
		local function pave(name, x1, z1, x2, z2, height)
			for z = z1, z2 do
				for x = x1, x2 do
					buf:put(x, 0, z, name)
				end
			end
			buf:clear(x1, 1, z1, x2, height or 4, z2)
		end

		-- 1. The plateau: turf over subsoil, worn where the city walks.
		layout.meadow(buf, human, RADIUS, 40)

		-- 2. The streets, and the kerbs of the three great avenues.
		for _, street in ipairs(STREETS) do
			local name = (street[5] == "avenue") and AVENUE or LANE
			pave(name, street[1], street[2], street[3], street[4], 5)
		end
		dressing.inlay(buf, human, 23, 7, 46, 37)
		for _, kerb in ipairs({{-3, -RADIUS, -3, 5}, {3, -RADIUS, 3, 5},
				{-3, 38, -3, RADIUS}, {3, 38, 3, RADIUS},
				{-RADIUS, -3, RADIUS, -3}, {-RADIUS, 3, RADIUS, 3}}) do
			for z = kerb[2], kerb[4] do
				for x = kerb[1], kerb[3] do
					buf:put(x, 0, z, KERB)
				end
			end
		end

		-- 3. The waypoint plaza: paving, a kerb, and nothing inside it.
		pave(AVENUE, PLAZA.x1, PLAZA.z1, PLAZA.x2, PLAZA.z2, 6)
		dressing.inlay(buf, human, PLAZA.x1, PLAZA.z1, PLAZA.x2, PLAZA.z2)
		dressing.inlay(buf, human, PLAZA.x1 + 4, PLAZA.z1 + 4,
			PLAZA.x2 - 4, PLAZA.z2 - 4)
		-- The pad itself, drawn INTO the ground course: a white stone cross
		-- and the diamond round it. An empty square of paving reads as
		-- nothing at all, and the one thing this plaza may not have is
		-- anything standing on it, so its whole decoration is the floor --
		-- which also marks the spot WP17's travel pad is being kept for.
		local pad_x = math.floor((PLAZA.x1 + PLAZA.x2) / 2)
		local pad_z = math.floor((PLAZA.z1 + PLAZA.z2) / 2)
		local WHITE_STONE = white.maybe("signature") or KERB
		for step = -6, 6 do
			buf:put(pad_x + step, 0, pad_z, WHITE_STONE)
			buf:put(pad_x, 0, pad_z + step, WHITE_STONE)
		end
		for step = 0, 6 do
			for _, corner in ipairs({{step, 6 - step}, {-step, 6 - step},
					{step, step - 6}, {-step, step - 6}}) do
				buf:put(pad_x + corner[1], 0, pad_z + corner[2], WHITE_STONE)
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
				error("wp13 highcourt: no generator " .. plot.make, 0)
			end
			local part = generator(handles[plot.palette], spec)
			-- Two plots may not share a cell.
			--
			-- `parts.stamp` writes; it does not ask. A plot laid over
			-- another one therefore cuts a silent hole in the first -- a
			-- wall, a roof valley or a doorway simply replaced -- and the
			-- pad still builds, which is the shape of defect that cost
			-- Dawnmere twenty-two props. Overwriting the STREETS and the
			-- ground under a plot is intended (a plot brings its own
			-- apron); overwriting another plot never is, so every cell a
			-- plot writes is claimed here and a second claim is fatal.
			-- Overhangs are included, because an eave over a neighbour's
			-- roof is exactly the case a footprint rectangle misses.
			local source, count = part.buffer:cells()
			for index = 1, count do
				local cell = source[index]
				local rx, rz = parts.rotate_footprint(cell.x, cell.z,
					part.w, part.d, plot.turns)
				local key = (plot.x + rx) .. ":" .. cell.y ..
					":" .. (plot.z + rz)
				local owner = claimed[key]
				if owner ~= nil then
					error("wp13 highcourt: the plot " .. plot.id ..
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
			for _, entry in ipairs(points.sockets or {}) do
				local drop = plot.drop and plot.drop[entry.role]
				if not drop then
					local recast = plot.recast and plot.recast[entry.role]
					local out = {id = entry.id, role = entry.role,
						x = entry.x, y = entry.y, z = entry.z,
						face = entry.face, group = entry.group,
						order = entry.order, kind = entry.kind,
						spawn = entry.spawn, tags = entry.tags}
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

		-- 5. The chapel's belfry, on its own ridge: the silhouette that
		-- marks the city's chapel from the far end of the west lane, the
		-- same way Dawnmere's meeting hall carries one.
		do
			local chapel = placed.chapel
			local height = 4
			local bx, bz = chapel.x + 3, chapel.z + 6
			parts.stamp(buf, buildings.belfry(human,
				{height = height, roof_palette = slate}),
				bx, chapel.peak, bz, 0)
			-- The bell's frame needs bearing. A lantern taller than three
			-- courses hangs its bell from a cross-beam at its own centre,
			-- and that beam touches nothing but the bell: the two of them
			-- are an island four courses above the ridge. `capitals.lua`
			-- carries the same two cells for the king's hall and the temple
			-- (`bear_bell`), which is a local function there, so the same
			-- fix is written at this call site -- the beam is landed on the
			-- lantern's own beam ring, on both sides.
			for _, offset in ipairs({1, 3}) do
				buf:put(bx + offset, chapel.peak + height, bz + 2,
					human.node("beam"))
			end
		end

		-- 5b. The hall's floor and its hangings.
		--
		-- The first render of the finished core showed what the section
		-- drawing could not: a nave twenty-five nodes long paved in one
		-- material, with the carpet the only thing on it. The generator
		-- owns the architecture and this lane does not change it, so the
		-- composition dresses the floor it stands on -- a white stone edging
		-- either side of the carpet, a band across the nave at every arcade
		-- bay, braziers between the bays and hangings on the aisle walls.
		local nave = {}
		do
			local hall = placed.kings_hall
			local floor_y = HALL.base
			local west = hall.x + HALL.arcade + 1
			local east = hall.x + HALL.w - 2 - HALL.arcade
			local carpet_from = hall.z + 1
			local carpet_to = hall.z + HALL.d - HALL.dais - 1
			local centre = hall.x + math.floor((HALL.w - 1) / 2)
			local marble = white.node("signature")
			-- Every cell this writes has to BE the hall's floor already: a
			-- band that lands on a dais step or outside the nave is a band
			-- the hall did not have room for.
			local paving_name = white.maybe("castle_paving") or
				white.node("plaza")
			local function inlay_floor(x, z)
				local cell = buf:at(x, floor_y, z)
				if cell == nil or cell.name ~= paving_name then
					error("wp13 highcourt: the hall's floor at " .. x .. "," ..
						z .. " is " .. (cell and cell.name or "air") ..
						", not the paving this band is laid into", 0)
				end
				buf:put(x, floor_y, z, marble)
				nave[#nave + 1] = {x = x, z = z}
			end
			for z = carpet_from, carpet_to do
				inlay_floor(centre - 2, z)
				inlay_floor(centre + 2, z)
			end
			-- A band at every arcade bay, broken by the carpet it crosses.
			for z = carpet_from + 3, carpet_to, 4 do
				for x = west, east do
					if x < centre - 2 or x > centre + 2 then
						inlay_floor(x, z)
					end
				end
			end
			-- Braziers between the bays, on the band's own stone. The
			-- clearance test is written here rather than taken from
			-- `layout.free`, which asks about the cells above the PAD: the
			-- hall's floor is two courses up and everything under it is the
			-- podium, so the pad test calls every cell in the building
			-- taken.
			for _, z in ipairs({carpet_from + 5, carpet_to - 4}) do
				for _, x in ipairs({centre - 4, centre + 4}) do
					for level = floor_y + 1, floor_y + 2 do
						local cell = buf:at(x, level, z)
						if cell ~= nil and cell.name ~= parts.AIR then
							error("wp13 highcourt: the brazier at " .. x ..
								"," .. z .. " stands in " .. cell.name, 0)
						end
					end
					parts.floor_torch(buf, human, x, floor_y + 1, z)
				end
			end
			-- Hangings on the aisle walls, clear of the wall lights and of
			-- the benches, each hung on the outer wall behind it.
			-- A hanging is a plain cloth cell against the wall behind it,
			-- not a wallmounted prop: `wool:red` carries no paramtype2, so
			-- `parts.wall_prop` refuses it -- and the hall's own royal
			-- hangings are written the same way. What has to hold is that
			-- the wall IS there and the cell is free.
			-- The bay is SEARCHED for, not counted out: the aisle wall
			-- carries a pane every fourth bay and a cloth hung over a window
			-- is a cloth hung over a hole. Each hanging walks along its own
			-- wall until it finds two courses of masonry, exactly as the
			-- library's entry torches do, and is fatal when the wall offers
			-- none.
			for _, wanted in ipairs({carpet_from + 4, carpet_to - 4}) do
				for _, side in ipairs({{hall.x + 1, -1},
						{hall.x + HALL.w - 2, 1}}) do
					local x, hung = side[1], false
					for _, step in ipairs({0, 1, -1, 2, -2}) do
						local z = wanted + step
						local usable = true
						for y = floor_y + 2, floor_y + 3 do
							local here = buf:at(x, y, z)
							if (here ~= nil and here.name ~= parts.AIR) or
									not parts.solid_at(buf, x + side[2], y, z) then
								usable = false
							end
						end
						if usable and not hung then
							for y = floor_y + 2, floor_y + 3 do
								buf:put(x, y, z, human.node("rug_accent"))
							end
							hung = true
						end
					end
					if not hung then
						error("wp13 highcourt: no bay of the aisle wall at " ..
							x .. " near " .. wanted .. " can carry a " ..
							"hanging", 0)
					end
				end
			end
		end

		-- 6. The principal service court, east of the hall: the two royal
		-- trading booths of the contract's `vendor` pair, the household's
		-- draw well, its stacked goods and its lamps. This is where the two
		-- fixed vendor offsets of `grug_traders/vendors.lua` come to rest.
		-- The court's paving is laid with the streets above; what follows is
		-- what stands ON it, between the workyard and the store.
		local VENDORS = {
			{id = "vendor_race", kind = "race", x = 41, z = 8},
			{id = "vendor_general", kind = "general", x = 41, z = 14},
		}
		for _, booth in ipairs(VENDORS) do
			paved_prop("booth", booth.x - 1, booth.z - 1, booth.x + 3,
				booth.z + 3, function()
					dressing.stall(buf, human, booth.x, booth.z, 0)
				end)
		end
		paved_prop("court_well", 43, 24, 45, 26, function()
			dressing.well(buf, human, 44, 25, nil)
		end)
		for _, stack in ipairs({{24, 20}, {24, 21}, {39, 20}, {39, 21}}) do
			paved_prop("crates", stack[1], stack[2], stack[1], stack[2],
				function()
					dressing.crates(buf, human, stack[1], stack[2], 2)
				end)
		end
		for _, pile in ipairs({{40, 30, 4, "z"}, {24, 30, 4, "z"}}) do
			local x2 = (pile[4] == "x") and pile[1] + pile[3] - 1 or pile[1]
			local z2 = (pile[4] == "z") and pile[2] + pile[3] - 1 or pile[2]
			paved_prop("wood_pile", pile[1], pile[2], x2, z2, function()
				dressing.wood_pile(buf, human, pile[1], pile[2], pile[3],
					pile[4])
			end)
		end
		for _, lamp in ipairs({{45, 7}, {23, 18}, {45, 20}, {38, 25},
				{45, 36}}) do
			paved_prop("court_lamp", lamp[1], lamp[2], lamp[1], lamp[2],
				function()
					dressing.path_light(buf, human, lamp[1], lamp[2])
				end)
		end

		-- 7. The market walk, the plaza lamps and the street lighting.
		--
		-- The plaza's four lamps stand on its kerb, OUTSIDE the open square,
		-- because the reserved area has to stay clear.
		for _, lamp in ipairs({{PLAZA.x1, PLAZA.z1}, {PLAZA.x2, PLAZA.z1},
				{PLAZA.x1, PLAZA.z2}, {PLAZA.x2, PLAZA.z2}}) do
			paved_prop("plaza_lamp", lamp[1], lamp[2], lamp[1], lamp[2],
				function()
					dressing.path_light(buf, human, lamp[1], lamp[2])
				end)
		end
		-- The great avenue's lamp line stops one node short of the crossing:
		-- a standard on the kerb at x = +-3 is on the verge of the
		-- north-south avenue and in the CARRIAGEWAY of the east-west one,
		-- and a lamp post in the middle of a gate road is a lamp post
		-- nothing can drive past.
		layout.street_lamps(buf, human, 0, -44, -4, 8, outdoors)
		layout.street_lamps(buf, human, 0, 40, RADIUS - 1, 8, outdoors)
		for _, spot in ipairs({{-6, -6}, {6, -6}, {-6, 6}, {6, 6},
				{-25, -6}, {-25, 6}, {25, -6}, {25, 6},
				{-40, -6}, {-40, 6}, {40, -6}, {40, 6},
				{-25, 24}, {25, 24}, {-25, -26}, {-25, 8},
				{34, -22}, {10, -22}, {-16, -6}, {16, -6}}) do
			if outdoors(spot[1], spot[2]) and
					layout.free(buf, spot[1], spot[2], 4) then
				paved_prop("street_lamp", spot[1], spot[2], spot[1], spot[2],
					function()
						dressing.path_light(buf, human, spot[1], spot[2])
					end)
			end
		end

		-- 8. Benches and planters where the city sits: the crossing, the
		-- hall's forecourt and the plaza's kerb.
		for _, seat in ipairs({{-6, -4, 0, "x"}, {4, -4, 0, "x"},
				{-6, 4, 2, "x"}, {4, 4, 2, "x"}}) do
			paved_prop("bench", seat[1], seat[2], seat[1] + 2, seat[2],
				function()
					dressing.bench(buf, human, seat[1], seat[2], seat[3], 3,
						"x")
				end)
		end
		for _, bed in ipairs({{-12, 3, -10, 5}, {9, 3, 11, 5}}) do
			paved_prop("planter", bed[1], bed[2], bed[3], bed[4], function()
				dressing.planter(buf, human, bed[1], bed[2], bed[3], bed[4])
			end)
		end

		-- 9. The orchards of the open edge, on whatever turf is left in the
		-- two outer corners, and the hedgerows that carry the boundary on
		-- between the orchard pieces.
		local orchard = 0
		for _, block in ipairs({{-46, -12, -38, 4, 4, 5},
				{-18, -46, -8, -38, 4, 5}, {-34, 40, -24, 45, 4, 5},
				{24, 40, 34, 45, 4, 5}, {-34, 8, -24, 18, 4, 5},
				{8, 8, 18, 18, 4, 5}, {-18, -34, -8, -14, 4, 5},
				{8, 30, 18, 44, 4, 5}, {-18, 30, -8, 44, 4, 5},
				{-34, -12, -24, -2, 4, 5}}) do
			orchard = orchard + layout.plant_orchard(buf, human, block[1],
				block[2], block[3], block[4], block[5], block[6])
		end
		-- The open edge. Highcourt has no curtain wall (the user's ruling of
		-- 2026-09-14), so what holds its boundary is a clipped hedge, and it
		-- runs round the WHOLE pad rather than in four authored stretches:
		-- every column of the boundary ring that is still open ground gets
		-- three courses of hedge, and the run breaks by itself wherever a
		-- gatehouse, an orchard piece, a house or a street already holds the
		-- edge. Hand-placed runs are how a hedge ends up planted through a
		-- cottage's apron, which is what the first version of this did.
		local hedge = 0
		for offset = -RADIUS + 1, RADIUS - 1 do
			for _, spot in ipairs({{offset, RADIUS - 1}, {offset, -RADIUS + 1},
					{RADIUS - 1, offset}, {-RADIUS + 1, offset}}) do
				local x, z = spot[1], spot[2]
				if layout.natural(buf, x, z) and layout.free(buf, x, z, 4) then
					hedge = hedge + dressing.hedge_line(buf, human, x, z, x, z,
						3)
				end
			end
		end

		-- 10. Meadow flora on the turf between the plots.
		dressing.undergrowth(buf, human, -RADIUS, -RADIUS, RADIUS, RADIUS, 5)

		-- 11. The sockets the composition owns: the two royal vendors, the
		-- quest shell at the chapel door, the travel waypoint on its plaza,
		-- the four corners of the patrol loop and the idle spots of the
		-- service court and the forecourt.
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
		-- `door`: the elder stands on the chapel's doorstep and its authored
		-- facing is the door, so the consumer turns it round to the west lane
		-- (start_npcs.lua `socket_face_yaw`, playtest round 2).
		socket("chapel_quest", "quest", -22, 1, 27, 3, {tags = {"door"}})
		socket("travel_waypoint", "waypoint",
			math.floor((PLAZA.x1 + PLAZA.x2) / 2), 1,
			math.floor((PLAZA.z1 + PLAZA.z2) / 2), 0)
		for _, corner in ipairs(CORNERS) do
			socket(corner.id, "guard_patrol", corner.x, 1, corner.z,
				corner.face, {group = WATCH, order = corner.order})
		end
		socket("court_idle_well", "idle", 44, 1, 27, 0, {tags = {"work"}})
		socket("court_idle_yard", "idle", 34, 1, 20, 0, {tags = {"work"}})
		socket("forecourt_idle_west", "idle", -6, 1, 3, 1, {tags = {"bench"}})
		socket("forecourt_idle_east", "idle", 7, 1, 3, 3, {tags = {"bench"}})
		--
		-- THE CORE'S SPARE IDLE SPOTS (playtest round 2, 2026-09-15).
		-- `spawn = false` is what makes them wander TARGETS and never homes: the
		-- roster places one citizen per SPAWN socket and `next_spot` walks every
		-- idle socket, so a city whose spots and citizens are the same thirty
		-- has an amble in which every destination is permanently taken. Ten
		-- spares along the avenues and courts is what gives the crowd somewhere
		-- to go. They are core sockets, so a villager wandering the core reaches
		-- them and a district plot's citizen keeps to its plot.
		--
		-- Each one is a legal standing position on the finished pad -- feet and
		-- head air, the core's own paving or turf under it, outdoors, reachable
		-- on foot from the south gate -- measured with `highcourt_kat.lua`'s own
		-- socket test, and at least 8 nodes from every authored socket. No tag:
		-- a spare is a place to stand, not a feature to talk about.
		local function spare(id, x, z, face)
			socket(id, "idle", x, 1, z, face, {spawn = false})
		end
		spare("core_spare_crossing_east", 12, -4, 3)
		spare("core_spare_crossing_west", -13, -1, 1)
		spare("core_spare_hall_green", 19, 13, 3)
		spare("core_spare_market_walk", -15, -20, 0)
		spare("core_spare_approach", 2, -26, 0)
		spare("core_spare_west_lane", -21, 16, 1)
		spare("core_spare_east_avenue", 30, -2, 3)
		spare("core_spare_west_avenue", -31, 0, 1)
		spare("core_spare_north_court", 17, 31, 2)
		spare("core_spare_plaza_south", 30, -20, 3)

		-- 12. Pane shapes, settled once over the finished pad, for the
		-- reason written in `parts.resolve_panes`.
		parts.resolve_panes(buf)

		-- 13. Canonical cell list, bounds and palette.
		local source, count = buf:cells()
		local cells = {}
		for index = 1, count do cells[index] = source[index] end
		table.sort(cells, function(a, b)
			if a.z ~= b.z then return a.z < b.z end
			if a.y ~= b.y then return a.y < b.y end
			return a.x < b.x
		end)
		local light_names = {[human.node("light_post")] = true,
			[human.node("light_wall")] = true,
			[human.node("light_indoor")] = true}
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
		-- ASCII byte order, not Lua's `<`, which is `strcoll`; see
		-- `parts.less_bytes`.
		table.sort(palette_list, parts.less_bytes)

		-- The sockets contract carries `dir` as a unit vector; the parts
		-- carry `face` as a facedir, because a facedir is what rotates with
		-- a stamped part. This is the settlement boundary, so it is
		-- converted here, with the library's own table rather than with
		-- `core.facedir_to_dir`, which is an engine call.
		for _, entry in ipairs(sockets) do
			local dx, dz = parts.facedir_step(entry.face)
			entry.dir = {x = dx, z = dz}
		end

		local destinations = {}
		for _, id in ipairs(DESTINATION_ORDER) do
			local spot = inside_by_id[id]
			if not spot then
				error("wp13 highcourt: destination " .. id .. " is missing", 0)
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
			error("wp13 highcourt: no door for " .. id, 0)
		end

		return {
			schema = SCHEMA,
			cells = cells,
			bounds = {min = minp, max = maxp},
			palette = palette_list,
			landmarks = {
				-- A capital core has no player spawn; `arrival` is the
				-- spawn-equivalent landmark, the crossing of the two great
				-- avenues, and every route below starts there.
				arrival = {x = 0, y = 1, z = 0},
				gate_south = {x = 0, y = 1, z = -RADIUS},
				gate_north = {x = 0, y = 1, z = RADIUS},
				gate_east = {x = RADIUS, y = 1, z = 0},
				gate_west = {x = -RADIUS, y = 1, z = 0},
				-- The four axis boxes, each a five-wide corridor from the
				-- crossing to its gate. `main_street` is the throne
				-- approach, and keeps the start compositions' key so a
				-- consumer that knows only that name finds the great street.
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
				-- The reserved square is the plaza INSIDE its kerb: the
				-- four lamp standards stand on the kerb ring itself, so a
				-- box drawn on the kerb is a box with four lamps in it and
				-- "nothing inside" would have to be qualified. The landmark
				-- is what WP17 may fill, and the KAT holds every column of
				-- it empty, edge included.
				waypoint_plaza = {min = {x = PLAZA.x1 + 1, y = 0,
						z = PLAZA.z1 + 1},
					max = {x = PLAZA.x2 - 1, y = 4, z = PLAZA.z2 - 1}},
				service_court = {min = {x = 23, y = 0, z = 6},
					max = {x = 46, y = 6, z = 37}},
				kings_hall = box("kings_hall", 2, 2),
				kings_hall_door = door_of("kings_hall"),
				market = box("market", 1, 1),
				chapel = box("chapel", 2, 9),
				chapel_door = door_of("chapel"),
				destinations = destinations,
				doors = doorways,
				rooms = rooms,
				lights = lights,
				sockets = sockets,
				orchard_trees = orchard,
				hedge_cells = hedge,
				nave_floor = #nave,
			},
		}
	end

	return M
end

return loader
