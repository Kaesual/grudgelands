-- Nhal Veyr: the undead capital, the raised necropolis, and the third walled
-- capital of the game.
--
-- This file is the CORE composition of docs/research/wp13-capitals-pois-
-- contract.md section 2.1 -- the 96 x 96 civic core, anchor-relative exactly
-- like a start, flat at y = 0 by construction, inside the contract's bounds of
-- x/z [-47, 47] and y [-2, 40] -- plus the run specifications the overlay
-- modules turn into the avenues, the ring street, the district lanes and the
-- curtain wall.
--
-- Nhal Veyr is the undead capital of the contract's section 2.4 table:
-- "raised necropolis, step 3", and "dungeon stone and obsidian brick,
-- mausoleum core, stepped terraces with ruins mixed among kept houses, candles
-- and iron bars" -- and, by the user's ruling of 2026-09-14, a WALLED one. The
-- Stillgrave palette is the city, the castle kit is the necropolis, and
-- `default:obsidianbrick` is the signature material every capital part dresses
-- itself in.
--
--   * `M.core()` returns the core composition in the exact shape of a start
--     composition (schema, canonical cells, bounds, sorted palette, landmarks)
--     plus `landmarks.sockets`, the NPC seam of
--     docs/research/wp13-npc-sockets-contract.md.
--   * `M.districts` is the four districts' rosters and the quadrant
--     assignment; `nhal_veyr_districts.lua` is where the two meet.
--   * `M.avenues`, `M.ring` are the runs `avenue.lua` turns into pavement, and
--     the district lanes come from `nhal_veyr_quadrants.lua` through the
--     blueprint source.
--   * `M.wall` is the four runs `wall.lua` turns into curtain, turrets and
--     gatehouses at the 512 envelope edge, and `M.wall_plan` is the authored
--     geometry each of those runs carries. The wall is an overlay and not a
--     blueprint for the reasons written at the top of `wall.lua` and recorded
--     in docs/research/wp13-dur-brannoc.md section 2.
--
-- WHERE THIS CORE DIFFERS FROM THE OTHER TWO, and why
-- ---------------------------------------------------
--   * The north quarter is a MAUSOLEUM and not a hall. It is the library's
--     `king_hall` -- the contract's ruling of 2026-09-14 is that the core
--     builds the throne room the king encounter will use, so the architecture
--     may not be re-invented -- but it is built and roofed in dungeon stone
--     over obsidian brick, and the composition lays its nave floor in grave
--     slabs with four votive lights between the bays. A basilica in black
--     masonry with a crypt floor is a mausoleum; the throne is the king's
--     socket either way.
--   * The north-east quarter is the OSSUARY COURT, this capital's signature,
--     where Dur Brannoc has its forge court and Highcourt its service court.
--     The two royal booths stand in it, but so do the bone stacks, the
--     coffins, the embalmer's slab, the wax pot and the candle line.
--   * The turf between the quarters is a BURIAL GROUND. Highcourt's core plants
--     orchards on the ground its plots leave and Dur Brannoc plants pines;
--     a necropolis buries its dead there, so `dressing.graveyard` runs over
--     four stretches of open ground and gravewoods stand among the markers.
--   * The boundary is a citadel parapet with a drum at each corner, the same
--     piece Dur Brannoc landed, in this capital's masonry. A walled city's
--     civic core is a precinct inside the walls, not a field with four gate
--     towers in it.
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
	local plots = dofile(directory .. "/nhal_veyr_plot.lua")(directory)
	local districts = dofile(directory .. "/nhal_veyr_districts.lua")(directory)
	local street_plan = dofile(directory .. "/street_plan.lua")(directory)

	local M = {}

	local RADIUS = 49
	local SCHEMA = "grug_wp13_nhal_veyr_core_v1"

	-- The city's own patrol loop. The four gatehouses keep a two-waypoint
	-- watch each, for the reason Highcourt records: a gate tower's waypoints
	-- are on the wall walk and on the fighting deck five courses above it, and
	-- a ground loop that took either in would ask an NPC to step from the
	-- street to a rampart through a wall.
	local WATCH = "nhal_veyr_watch"

	-- The two handles, which are `nhal_veyr_plot.CRYPT` and `.VAULT` -- the
	-- district builder's own, read from there rather than spelled twice, so a
	-- civic building in the core and one on a lot are the same masonry.
	local CRYPT = plots.CRYPT
	local VAULT = plots.VAULT

	local function merged(...)
		local out = {}
		for _, source in ipairs({...}) do
			for role, name in pairs(source) do out[role] = name end
		end
		return out
	end

	-- The king's hall's own dimensions, in one place, so the floor this
	-- composition lays inside it cannot be left behind by a hall of another
	-- size. `base`, `arcade` and `dais` are `capitals.king_hall`'s own.
	local HALL = {w = 31, d = 27, rise = 7, base = 2, arcade = 5, dais = 9}

	-- The travel plaza reserved for WP17: kerbed, lit from its own kerb and
	-- empty of everything above its paving. x1 is 11 and not 8, for the reason
	-- Dur Brannoc records: the east colonnade's eaves oversail its own
	-- footprint to x = 9.
	local PLAZA = {x1 = 11, z1 = -32, x2 = 27, z2 = -12}

	-- The ossuary court: the whole north-east quarter, paved in one piece with
	-- the streets so a building stamped into it keeps its own apron.
	local COURT = {x1 = 22, z1 = 5, x2 = 45, z2 = 43}

	local STREETS = {
		-- The throne approach, from the south gate through the crossing to the
		-- mausoleum's forecourt.
		{-2, -RADIUS, 2, 5, "avenue"},
		-- The service avenue behind the mausoleum, out to the north gate.
		{-2, 38, 2, RADIUS, "avenue"},
		-- The east-west avenue, gate to gate through the same crossing.
		{-RADIUS, -2, RADIUS, 2, "avenue"},
		-- The two flank lanes past the mausoleum and the back lane joining them.
		{-24, 0, -22, 42, "lane"},
		{19, 0, 21, 42, "lane"},
		{-24, 38, 21, 40, "lane"},
		-- The mausoleum's forecourt.
		{-10, 3, 10, 5, "lane"},
		-- The gate forecourts: a gate chamber's door is in its city face and
		-- its doorstep is one node beyond the part's own footprint. The north
		-- gate's forecourt is the back lane, which already reaches it.
		{-8, -(RADIUS - 7), 8, -38, "lane"},
		{-8, 38, 8, RADIUS - 7, "lane"},
		{38, -8, RADIUS - 7, 8, "lane"},
		{-(RADIUS - 7), -8, -38, 8, "lane"},
		-- The travel plaza's approach off the east avenue.
		{4, -13, 11, -11, "lane"},
		-- The west quarter: the cistern court's walk and the vigil hall's.
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
	-- have: one throne, one travel pad for WP17 and exactly two `grug_traders`
	-- families. The KAT asserts the resulting multiset.
	local PLOTS = {
		-- 1. THE MAUSOLEUM, on the axis, its great door looking down the
		-- approach to the south gate. Built with the crypt handle as well as
		-- roofed with the vault: a lucarne takes its hood from the palette's
		-- own `roof_slab`, so a hall built with the plain handle would wear
		-- obsidian hoods on a dungeon-stone roof.
		{id = "mausoleum", module = "capitals", make = "king_hall",
			x = -15, z = 9, turns = 0, palette = "crypt", roof = "vault",
			spec = {w = HALL.w, d = HALL.d, rise = HALL.rise},
			drop = {waypoint = true}},

		-- 2. The four inner gatehouses, where the avenues leave the precinct.
		-- Nhal Veyr's curtain wall is 209 nodes further out, so these are the
		-- necropolis's own gates and not the city's.
		{id = "gate_south", module = "capitals", make = "gatehouse",
			x = -6, z = -RADIUS, turns = 0, palette = "crypt", roof = "vault",
			spec = {patrol_group = "nhal_veyr_gate_south_tower",
				deck_group = "nhal_veyr_gate_south_tower", order = 2}},
		{id = "gate_west", module = "capitals", make = "gatehouse",
			x = -RADIUS, z = -6, turns = 1, palette = "crypt", roof = "vault",
			spec = {patrol_group = "nhal_veyr_gate_west_tower",
				deck_group = "nhal_veyr_gate_west_tower", order = 2}},
		{id = "gate_north", module = "capitals", make = "gatehouse",
			x = -6, z = 43, turns = 2, palette = "crypt", roof = "vault",
			spec = {patrol_group = "nhal_veyr_gate_north_tower",
				deck_group = "nhal_veyr_gate_north_tower", order = 2}},
		{id = "gate_east", module = "capitals", make = "gatehouse",
			x = 43, z = -6, turns = 3, palette = "crypt", roof = "vault",
			spec = {patrol_group = "nhal_veyr_gate_east_tower",
				deck_group = "nhal_veyr_gate_east_tower", order = 2}},

		-- 3. The market square, west of the approach.
		{id = "market", module = "capitals", make = "market_square",
			x = -35, z = -28, turns = 0, palette = "undead",
			spec = {size = 25},
			drop = {waypoint = true},
			-- A booth without a trader is a flair NPC's work spot, and its id
			-- has to say booth: `market_vendor_1` with the role `idle` is a
			-- socket that argues with itself.
			recast = {vendor = {role = "idle", tags = {"work"},
				from = "_vendor_", to = "_booth_"}}},

		-- 4. The two colonnades flanking the approach.
		{id = "colonnade_west", module = "capitals", make = "colonnade",
			x = -9, z = -21, turns = 1, palette = "crypt",
			spec = {len = 15, patrol_group = WATCH, order = 1}},
		{id = "colonnade_east", module = "capitals", make = "colonnade",
			x = 4, z = -21, turns = 3, palette = "crypt",
			spec = {len = 15, patrol_group = WATCH, order = 6}},

		-- 5. The civic furniture: the king's statue east of the crossing and
		-- the cistern court in the west quarter.
		{id = "statue", module = "capitals", make = "statue_plinth",
			x = 12, z = -11, turns = 0, palette = "crypt", spec = {}},
		{id = "cistern_court", module = "capitals", make = "well_court",
			x = -45, z = 9, turns = 0, palette = "undead", spec = {size = 11}},

		-- 6. The hall of vigil: the capital library's temple, in the west
		-- quarter, and where this capital's quest shell stands.
		{id = "vigil_hall", module = "capitals", make = "temple",
			x = -44, z = 22, turns = 0, palette = "crypt", roof = "vault",
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
			socket_overrides = function(placed)
				return {vigil_hall_quest = {x = placed.x + 6,
					z = placed.z - 1, face = 0, tags = {"door"}}}
			end},

		-- 7. The ossuary court, the north-east quarter and this capital's
		-- signature. The bone works opens in its x- wall, like every workshop
		-- in this capital: the `workshop` interior kit stands the cauldrons on
		-- the odd cells of the z- gable's inner run, and the generator's own
		-- chimney stack stands on the middle cell of that same wall.
		{id = "bone_works", module = "buildings", make = "workshop",
			x = 24, z = 8, turns = 0, palette = "undead",
			spec = {w = 11, d = 13, wing = 7, wall_h = 5, door_side = "x-",
				door_index = 6, infill = true}},
		{id = "charnel_yard", module = "buildings", make = "shed",
			x = 24, z = 27, turns = 0, palette = "undead",
			spec = {w = 13, d = 9, wall_h = 4, open_sides = {"z-", "x+"}}},

		-- 8. The bonesmiths' guild, in the south-east corner.
		{id = "bonesmith_guild", module = "capitals", make = "scriptorium",
			x = 29, z = -46, turns = 2, palette = "crypt", roof = "vault",
			spec = {w = 13, d = 17, wall_h = 6}},

		-- 9. The kept houses: four on the outer ground, and the contract's
		-- "ruins mixed among kept houses" -- one fallen shell between two of
		-- them, which is the line's whole point at core scale.
		--
		-- The cottages keep the generator's own door side (`z-`) and are TURNED
		-- to face their ground instead: the `home` kit furnishes the cell
		-- behind every other wall and only the z- doorway is authored clear.
		{id = "market_house", module = "buildings", make = "cottage",
			x = -45, z = -20, turns = 3, palette = "undead",
			spec = {w = 9, d = 9, wall_h = 5, roof = "gable",
				ridge_axis = "z", infill = true, shutters = true}},
		{id = "south_house", module = "buildings", make = "cottage",
			x = -41, z = -41, turns = 1, palette = "undead",
			spec = {w = 9, d = 9, wall_h = 5, roof = "hip",
				infill = true, shutters = true}},
		{id = "lane_house", module = "buildings", make = "cottage",
			x = 37, z = -17, turns = 1, palette = "undead",
			spec = {w = 9, d = 9, wall_h = 5, roof = "saltbox",
				ridge_axis = "x", infill = true, fancy_bed = true}},
		{id = "plaza_house", module = "buildings", make = "cottage",
			x = 9, z = -46, turns = 1, palette = "undead",
			spec = {w = 9, d = 9, wall_h = 5, roof = "gable",
				ridge_axis = "x", infill = true, shutters = true}},
		-- The fallen one stands BETWEEN the two west houses, which is the only
		-- place on this pad where the contract's line reads: a ruin on its own
		-- is a heap in a field, and a ruin with a kept cottage on either side
		-- of it is a street that lost a house. Its apron ring stops one node
		-- clear of the south house's and two clear of the market house's; the
		-- market square's west kerb is one node further out again.
		{id = "fallen_house", module = "buildings", make = "ruin",
			x = -45, z = -30, turns = 0, palette = "undead",
			spec = {w = 9, d = 7, wall_h = 5, phase = 1}},
	}

	-- Destination order is part of the consumer contract and never changes.
	-- The ruin is NOT in it: `buildings.ruin` publishes no `inside` point and
	-- nobody keeps that room, which is the same choice Stillgrave made about
	-- its two.
	local DESTINATION_ORDER = {"mausoleum", "gate_south", "gate_west",
		"gate_north", "gate_east", "vigil_hall", "bone_works",
		"charnel_yard", "bonesmith_guild", "market_house", "south_house",
		"lane_house", "plaza_house"}

	-- THE STANDING POSITIONS THIS COMPOSITION PUBLISHES ARE DATA, and they are
	-- declared up here rather than written at the socket step, because three
	-- SCATTERS run over the same ground before that step and every one of them
	-- would happily plant on a place somebody has to stand:
	--
	--   * the gravewood stands, whose branches reach three nodes from the stem
	--     and a course or two above it;
	--   * the burial ground, whose markers are set two nodes apart over every
	--     open column of four rectangles;
	--   * the blight flora, which sows about a fifth of every unbuilt column
	--     on the pad.
	--
	-- None of the three can see a socket, because a socket is an absence of
	-- cells. The first version of this composition let them loose and the KAT
	-- found a bone pile in a patrol waypoint's headroom. So the positions are
	-- a table, `STANDING` is built from it before the scatters, and the three
	-- of them ask it.
	--
	-- The corner waypoints of the city loop stand on the lanes that box the
	-- mausoleum, which closes the circuit the two colonnades open at the
	-- south. On a LANE and not on the turf between the plots, deliberately:
	-- the guard that walks this loop is walking the city's own streets, and a
	-- waypoint on paving is one the burial ground can never reach.
	local CORNERS = {
		{id = "watch_south_west", x = -23, z = 10, face = 0, order = 2},
		{id = "watch_north_west", x = -23, z = 39, face = 1, order = 3},
		{id = "watch_north_east", x = 20, z = 39, face = 3, order = 4},
		{id = "watch_south_east", x = 20, z = 10, face = 2, order = 5},
	}

	-- The flair spots the composition owns, beside the ones its parts publish.
	local IDLES = {
		{id = "court_idle_works", x = 41, z = 23, face = 3, tags = {"work"}},
		{id = "court_idle_yard", x = 28, z = 24, face = 0, tags = {"work"}},
		{id = "court_idle_fire", x = 35, z = 39, face = 0, tags = {"fire"}},
		{id = "forecourt_idle_west", x = -6, z = 3, face = 1,
			tags = {"bench"}},
		{id = "forecourt_idle_east", x = 7, z = 3, face = 3,
			tags = {"bench"}},
	}

	-- THE CORE'S OWN WORKPLACES (sockets contract section 8.1). Each stands on
	-- the ossuary court's paving and faces a feature the composition itself
	-- writes -- an embalmer's slab, a wax pot, a gravewood stack -- which is
	-- the whole point of the feature rule: the KAT re-derives it from the
	-- finished cells, so a prop that moves takes its socket's acceptance with
	-- it.
	local WORKS = {
		{id = "court_work_slab", activity = "carve", x = 27, z = 23, face = 1},
		{id = "court_work_pot", activity = "brew", x = 31, z = 23, face = 1},
		-- One node east of the gravewood stack at (22, 12..15) and looking at
		-- it: the stack's own column is four courses of log and a socket on it
		-- has no feet, which is what the KAT's headroom rule said about the
		-- first version of this row.
		{id = "court_work_stack", activity = "carve", x = 23, z = 13,
			face = 3},
	}

	-- THE CORE'S SPARE IDLE SPOTS (playtest round 2, 2026-09-15).
	-- `spawn = false` is what makes them wander TARGETS and never homes: the
	-- roster places one citizen per SPAWN socket and `next_spot` walks every
	-- idle socket, so a city whose spots and citizens are the same thirty has
	-- an amble in which every destination is permanently taken. Ten spares
	-- along the avenues and courts is what gives the crowd somewhere to go,
	-- and is the population Highcourt's core carries.
	--
	-- No tag: a tag is what the spoken line and the facing rule read
	-- (`_grug_idle_tag`, `FACE_AWAY_TAGS`), and a spare has neither a line nor
	-- a door.
	local SPARES = {
		{id = "core_spare_crossing_east", x = 12, z = -1, face = 3},
		{id = "core_spare_crossing_west", x = -13, z = 1, face = 1},
		{id = "core_spare_hall_green", x = 20, z = 13, face = 3},
		{id = "core_spare_market_walk", x = -15, z = -20, face = 0},
		{id = "core_spare_approach", x = 2, z = -26, face = 0},
		{id = "core_spare_west_lane", x = -23, z = 16, face = 1},
		{id = "core_spare_east_avenue", x = 30, z = -1, face = 3},
		{id = "core_spare_west_avenue", x = -31, z = 1, face = 1},
		{id = "core_spare_north_court", x = 20, z = 31, face = 2},
		{id = "core_spare_plaza_south", x = 24, z = -20, face = 3},
	}

	-- Where the four avenues and the ring street run in the 512 envelope.
	-- These are not cells: they are the runs `avenue.lua` projects onto
	-- whatever surface the terrain has when a chunk is emerged.
	--
	-- THEY REACH 261, not the gate station at 256, because Nhal Veyr has a
	-- wall: the curtain's centre line is at +-256 and its gate tunnel runs
	-- through the whole seven-node thickness, so a road that stopped at the
	-- centre line would stop inside the gate.
	local GATE_OUT = 261
	M.avenues = {
		{id = "avenue_south", axis = "z", at = 0, from = -GATE_OUT, to = -(RADIUS + 1),
			gate = "gate_south"},
		{id = "avenue_north", axis = "z", at = 0, from = RADIUS + 1, to = GATE_OUT,
			gate = "gate_north"},
		{id = "avenue_west", axis = "x", at = 0, from = -GATE_OUT, to = -(RADIUS + 1),
			gate = "gate_west"},
		{id = "avenue_east", axis = "x", at = 0, from = RADIUS + 1, to = GATE_OUT,
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

	-- THE CURTAIN WALL, on the four edges of the 512 envelope (the user's
	-- ruling of 2026-09-14: walls for Dur Brannoc, Nhal Veyr and Gor Drazhak).
	--
	-- Authored exactly the way Dur Brannoc's is, because the geometry question
	-- is the same one and the answer is not this capital's to re-decide:
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
	-- The four districts and their 36 + 16 plots, the roster the blueprint
	-- source resolves against this world's quadrant permutation
	-- (`nhal_veyr_districts.lua`). It is published HERE as well, the way Dur
	-- Brannoc publishes its own, because a whole-capital tool reads the
	-- composition and not the blueprint: `tools/wp13/dump_capital_plan.lua`
	-- refused this capital with "publishes no district plots" until it did, and
	-- this file's own header had claimed the field existed since it was written.
	M.districts = districts

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

	function M.core()
		local undead = palettes.new("undead")
		local crypt = palettes.new("undead", CRYPT)
		local vault = palettes.new("undead", merged(CRYPT, VAULT))
		local handles = {undead = undead, crypt = crypt, vault = vault}
		local buf = parts.buffer()
		local doorways, rooms, sockets = {}, {}, {}
		local placed, inside_by_id, plot_order = {}, {}, {}
		local claimed = {}

		-- The citadel paving of the avenues and the mossy cobble of the lanes,
		-- each resolved the way `capitals.lua` resolves it: the capital
		-- vocabulary is optional and falls back into the start vocabulary.
		local AVENUE = undead.maybe("castle_paving") or undead.node("plaza")
		local LANE = undead.node("path")
		local KERB = undead.node("plaza_edge")
		local STONE = undead.maybe("castle_wall") or undead.node("wall_accent")
		local CAP = undead.maybe("signature_slab") or undead.node("roof_slab")
		local SIGNATURE = undead.maybe("signature") or KERB

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
			GROUND[undead.node(role)] = true
		end

		-- Every prop the composition asks for MUST land; a prop quietly
		-- skipped is a hole in the authored scene no fixture can see (the
		-- Dawnmere lesson, wp13-hearthpine-library.md round A).
		local function refuse(name, x, z, reason)
			error("wp13 nhal veyr: prop " .. name .. " at " .. x .. "," ..
				z .. " was not placed: " .. reason, 0)
		end
		local function place(name, x1, z1, build)
			if build() == false then
				refuse(name, x1, z1, "the prop could not be completed")
			end
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

		-- 1. The blight: dead earth with bone-litter drifts and gravel scars,
		-- which is what the Kragmar necropolis stands on.
		layout.blight(buf, undead, RADIUS)

		-- 2. The streets, the ossuary court and the kerbs of the great avenues.
		for _, street in ipairs(STREETS) do
			local name = (street[5] == "avenue") and AVENUE or LANE
			pave(name, street[1], street[2], street[3], street[4], 5)
		end
		pave(AVENUE, COURT.x1, COURT.z1, COURT.x2, COURT.z2, 5)
		dressing.inlay(buf, undead, COURT.x1, COURT.z1, COURT.x2, COURT.z2)
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
		dressing.inlay(buf, undead, PLAZA.x1, PLAZA.z1, PLAZA.x2, PLAZA.z2)
		dressing.inlay(buf, undead, PLAZA.x1 + 4, PLAZA.z1 + 4,
			PLAZA.x2 - 4, PLAZA.z2 - 4)
		local pad_x = math.floor((PLAZA.x1 + PLAZA.x2) / 2)
		local pad_z = math.floor((PLAZA.z1 + PLAZA.z2) / 2)
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
				error("wp13 nhal veyr: no generator " .. plot.make, 0)
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
					error("wp13 nhal veyr: the plot " .. plot.id ..
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
			-- instead of the library being edited per composition.
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
						activity = entry.activity,
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

		-- 5. The mausoleum's floor: a grave-slab edging either side of the
		-- carpet and a band across the nave at every arcade bay, with votive
		-- lights between the bays. The generator owns the architecture; what a
		-- twenty-five-node nave of one paving material needs is a floor
		-- somebody drew.
		local nave = {}
		do
			local hall = placed.mausoleum
			local floor_y = HALL.base
			local west = hall.x + HALL.arcade + 1
			local east = hall.x + HALL.w - 2 - HALL.arcade
			local carpet_from = hall.z + 1
			local carpet_to = hall.z + HALL.d - HALL.dais - 1
			local centre = hall.x + math.floor((HALL.w - 1) / 2)
			local paving_name = crypt.maybe("castle_paving") or
				crypt.node("plaza")
			local function inlay_floor(x, z)
				local cell = buf:at(x, floor_y, z)
				if cell == nil or cell.name ~= paving_name then
					error("wp13 nhal veyr: the mausoleum floor at " .. x .. "," ..
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
							error("wp13 nhal veyr: the votive light at " .. x ..
								"," .. z .. " stands in " .. cell.name, 0)
						end
					end
					parts.floor_torch(buf, undead, x, floor_y + 1, z)
				end
			end
		end

		-- 6. THE OSSUARY COURT: the two royal booths of the contract's
		-- `vendor` pair, the bone stacks, the coffin crates, the embalmer's
		-- slab, the wax pots and the court's own candle line. This is where
		-- the two fixed vendor offsets of `grug_traders/vendors.lua` come to
		-- rest.
		local VENDORS = {
			{id = "vendor_race", kind = "race", x = 42, z = 10},
			{id = "vendor_general", kind = "general", x = 42, z = 17},
		}
		for _, booth in ipairs(VENDORS) do
			paved_prop("booth", booth.x - 1, booth.z - 1, booth.x + 3,
				booth.z + 3, function()
					dressing.stall(buf, undead, booth.x, booth.z, 0)
				end)
		end
		for _, pile in ipairs({{23, 38, 4, "z"}, {26, 38, 4, "z"},
				{42, 24, 4, "z"}, {30, 38, 4, "z"}, {34, 38, 4, "z"},
				{22, 12, 4, "z"}}) do
			local x2 = (pile[4] == "x") and pile[1] + pile[3] - 1 or pile[1]
			local z2 = (pile[4] == "z") and pile[2] + pile[3] - 1 or pile[2]
			paved_prop("gravewood_stack", pile[1], pile[2], x2, z2, function()
				dressing.wood_pile(buf, undead, pile[1], pile[2], pile[3],
					pile[4])
			end)
		end
		for _, stack in ipairs({{23, 23}, {24, 23}, {42, 30}, {42, 31},
				{42, 33}, {38, 41}, {39, 41}, {41, 41}, {44, 26}, {44, 27},
				{44, 34}, {22, 20}}) do
			paved_prop("coffin_crates", stack[1], stack[2], stack[1], stack[2],
				function()
					dressing.crates(buf, undead, stack[1], stack[2], 2)
				end)
		end
		-- The wax pots and the embalmer's slab line: the palette's own hearth
		-- (a cauldron) and its signature block, stood in the open between the
		-- bone works and the charnel yard, which is what the working half of
		-- an ossuary court is.
		for _, spot in ipairs({{30, 23}, {32, 23}, {34, 23}}) do
			paved_prop("wax_pot", spot[1], spot[2], spot[1], spot[2],
				function()
					buf:put(spot[1], 1, spot[2], undead.node("hearth"))
				end)
		end
		-- The embalmers' slab line: DUNGEON STONE and not the signature
		-- obsidian brick, for the reason the vigil district's own slab records.
		-- `signature` and `foundation` are the same node in this palette and
		-- between them they are the footing of every building in the city, so a
		-- `carve` feature set that accepted them would let any wall base read as
		-- a carver's block (the review of 2026-09-16).
		for _, spot in ipairs({{26, 23}, {28, 23}, {36, 23}, {38, 23}}) do
			paved_prop("slab", spot[1], spot[2], spot[1], spot[2],
				function()
					buf:put(spot[1], 1, spot[2], STONE)
				end)
		end
		for _, seat in ipairs({{44, 36, 0, "z"}, {22, 28, 1, "z"}}) do
			local x2 = (seat[4] == "x") and seat[1] + 2 or seat[1]
			local z2 = (seat[4] == "z") and seat[2] + 2 or seat[2]
			paved_prop("court_bench", seat[1], seat[2], x2, z2, function()
				dressing.bench(buf, undead, seat[1], seat[2], seat[3], 3,
					seat[4])
			end)
		end
		for _, lamp in ipairs({{22, 7}, {38, 6}, {22, 42}, {45, 42},
				{42, 22}, {22, 24}}) do
			paved_prop("court_candle", lamp[1], lamp[2], lamp[1], lamp[2],
				function()
					dressing.path_light(buf, undead, lamp[1], lamp[2])
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
					dressing.path_light(buf, undead, lamp[1], lamp[2])
				end)
		end
		layout.street_lamps(buf, undead, 0, -44, -6, 8, outdoors)
		layout.street_lamps(buf, undead, 0, 42, RADIUS - 2, 8, outdoors)
		for _, spot in ipairs({{-6, -6}, {6, -6}, {-6, 6}, {6, 6},
				{-25, -6}, {-25, 6}, {25, -6}, {25, 6},
				{-40, -6}, {-40, 6}, {40, -6}, {40, 6},
				{-25, 18}, {-25, 30}, {28, -16}, {-16, -6}, {16, -6},
				{-34, -8}, {34, 4}}) do
			if outdoors(spot[1], spot[2]) and
					layout.free(buf, spot[1], spot[2], 4) then
				paved_prop("street_lamp", spot[1], spot[2], spot[1], spot[2],
					function()
						dressing.path_light(buf, undead, spot[1], spot[2])
					end)
			end
		end

		-- 8. Benches at the crossing and on the mausoleum's forecourt, and two
		-- blight beds either side of its steps.
		for _, seat in ipairs({{-6, -4, 0, "x"}, {4, -4, 0, "x"},
				{-6, 4, 2, "x"}, {4, 4, 2, "x"}}) do
			paved_prop("bench", seat[1], seat[2], seat[1] + 2, seat[2],
				function()
					dressing.bench(buf, undead, seat[1], seat[2], seat[3], 3,
						"x")
				end)
		end
		for _, bed in ipairs({{-12, 3, -10, 5}, {9, 3, 11, 5}}) do
			paved_prop("planter", bed[1], bed[2], bed[3], bed[4], function()
				dressing.planter(buf, undead, bed[1], bed[2], bed[3], bed[4])
			end)
		end

		-- 9. THE STANDING POSITIONS, as a set, before anything is scattered
		-- over the ground they stand on. See the tables at the head of this
		-- file for what this is for and what it cost to learn.
		--
		-- A tree's guard is three nodes wider than a marker's, because a
		-- gravewood's arms reach three nodes from its stem and end a course or
		-- two above the ground -- which is exactly a standing position's head.
		local STANDING = {}
		local function reserve(x, z) STANDING[x .. ":" .. z] = true end
		for _, entry in ipairs(CORNERS) do reserve(entry.x, entry.z) end
		for _, entry in ipairs(IDLES) do reserve(entry.x, entry.z) end
		for _, entry in ipairs(WORKS) do reserve(entry.x, entry.z) end
		for _, entry in ipairs(SPARES) do reserve(entry.x, entry.z) end
		for _, entry in ipairs(sockets) do reserve(entry.x, entry.z) end
		local function open_ground(x, z)
			return layout.natural(buf, x, z) and layout.free(buf, x, z, 4) and
				not STANDING[x .. ":" .. z]
		end
		local function tree_ground(x, z)
			for dz = -3, 3 do
				for dx = -3, 3 do
					if STANDING[(x + dx) .. ":" .. (z + dz)] then return false end
				end
			end
			return layout.natural(buf, x, z)
		end

		-- 10. The gravewood stands, BEFORE the burial ground and not after it:
		-- a tree needs seven clear columns round its stem and a graveyard
		-- leaves none, so the other way round exactly one stand in the whole
		-- pad finds room. The markers break round the trees instead, which is
		-- also what a burial ground under trees looks like.
		--
		-- THREE NODES CLEAR OF THE PRECINCT RING, every stand, which is what
		-- the `-42` bound buys against a ring at 46: a crown reaches three
		-- nodes from its stem, the parapet is written after the trees and only
		-- asks whether the four courses above the ground are free -- so a stem
		-- at the ring's own column lets the wall be built under it and hangs
		-- leaves on the merlon cap. That is the defect Dur Brannoc's pines had
		-- and the KAT's shape rule is what found it.
		local trees = 0
		for z = -42, 42, 4 do
			for x = -42, 42, 4 do
				local hash = (x * 53 + z * 89 + x * z) % 101
				local tx = x + hash % 5 - 2
				local tz = z + math.floor(hash / 5) % 5 - 2
				local height = 5 + hash % 3
				if hash % 5 < 3 and tree_ground(tx, tz) and
						layout.natural_area(buf, tx - 1, tz - 1, tx + 1,
							tz + 1) and
						layout.free_area(buf, tx - 3, tz - 3, tx + 3, tz + 3,
							height + 2) then
					dressing.gravewood(buf, undead, tx, tz, height)
					trees = trees + 1
				end
			end
		end
		if trees < 12 then
			error("wp13 nhal veyr: only " .. trees ..
				" gravewood stands found open ground", 0)
		end

		-- 10. THE BURIAL GROUND between the quarters, which is what a
		-- necropolis puts on the turf its plots leave: rows of markers on
		-- flagstones, two nodes apart, with about one plot in six left open.
		--
		-- `dressing.graveyard` is NOT what writes it, and the reason is worth
		-- recording because it cost this composition a doorway. That routine
		-- sets a marker wherever the cell below is not air and the cell above
		-- is free, which on a hamlet pad means "on the turf" and on a CAPITAL
		-- pad means "on the turf, on the market square, on the travel plaza
		-- and on a cottage's own doorstep". The first version used it and the
		-- KAT's doorway rule found a grave marker on the step of the plaza
		-- house.
		--
		-- So the scatter is walked here with the guard the citadel parapet
		-- already uses: `layout.natural` says the column is ground this
		-- composition laid and has built nothing on -- which paving is not --
		-- and `layout.free` says nothing stands in the four courses above it.
		-- The run then breaks by itself at a street, a plot, a lamp standard
		-- or a gravewood stem, which is what a burial ground round a city
		-- looks like.
		local graves = 0
		for _, field in ipairs({{-20, -44, -8, -20}, {6, -44, 18, -20},
				{-20, 8, -8, 34}, {24, -36, 36, -20}}) do
			for z = field[2], field[4], 2 do
				for x = field[1], field[3], 2 do
					local hash = (x * 29 + z * 61) % 11
					if hash ~= 3 and open_ground(x, z) then
						dressing.grave(buf, undead, x, z, hash % 4 == 0)
						graves = graves + 1
					end
				end
			end
		end
		if graves < 60 then
			error("wp13 nhal veyr: only " .. graves ..
				" grave markers found open ground", 0)
		end

		-- 11. THE CITADEL PARAPET, and the four drums at the corners of the
		-- pad: Nhal Veyr's core edge, the piece Dur Brannoc landed, in dungeon
		-- stone.
		--
		-- The DRUMS FIRST. The protected parapet explicitly skips the five square
		-- boundary columns at each corner; each closed drum perimeter owns that
		-- detour and the first parapet column beyond the skip joins straight into
		-- it. This is an authored corner substitution, not an occupied-cell stop.
		local drums = 0
		for _, corner in ipairs({{-47, -47}, {47, -47}, {-47, 47}, {47, 47}}) do
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
			error("wp13 nhal veyr: " .. drums ..
				" of the four corner drums found room", 0)
		end
		-- The protected parapet is walked round the whole pad after the content.
		-- It wins every ordinary column; the shared mask omits the four authored
		-- gatehouse bands and the callback preserves the four corner drums.
		--
		-- IRON BARS ON THE RHYTHM, which is where the contract's "candles and
		-- iron bars" reaches the core's own edge: every fourth column of the
		-- parapet carries a barred opening instead of a merlon -- the palette's
		-- `window`, an `xpanes` flat pane, standing in the gap between two
		-- courses of masonry.
		local parapet, bars = 0, 0
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
			elseif (x + z) % 4 == 2 then
				buf:put(x, 3, z, undead.node("window"),
					math.abs(z) == precinct_ring.RADIUS and 0 or 3)
				bars = bars + 1
			end
			parapet = parapet + 1
		end, {skip = precinct_ring.is_corner})

		-- 13. Blight flora on the turf between the quarters: bone piles and
		-- dead shrubs on about a fifth of the columns the city has not built
		-- on. `dressing.blight_flora` is the shared routine and it does the
		-- same hash, but it has no notion of a standing position -- the
		-- reason the scatter is walked here instead is written at the head of
		-- this file, and it is a bone pile that stood in a patrol waypoint's
		-- headroom.
		local flora = 0
		for z = -RADIUS, RADIUS do
			for x = -RADIUS, RADIUS do
				local hash = (x * 89 + z * 151 + x * z * 7) % 11
				local role
				if hash < 3 then role = "undergrowth"
				elseif hash < 7 then role = "grass_tuft" end
				if role and open_ground(x, z) then
					local name = undead.node(role)
					buf:put(x, 1, z, name, parts.place_param2(name))
					flora = flora + 1
				end
			end
		end

		-- 14. The sockets the composition owns, out of the four tables at the
		-- head of this file. They are declared there and published here because
		-- the scatters above had to know about them first; see the comment over
		-- `CORNERS` for what that cost.
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
		for _, entry in ipairs(IDLES) do
			socket(entry.id, "idle", entry.x, 1, entry.z, entry.face,
				{tags = entry.tags})
		end
		for _, entry in ipairs(WORKS) do
			socket(entry.id, "work", entry.x, 1, entry.z, entry.face,
				{activity = entry.activity})
		end
		for _, entry in ipairs(SPARES) do
			socket(entry.id, "idle", entry.x, 1, entry.z, entry.face,
				{spawn = false})
		end

		-- 15. Pane shapes, settled once over the finished pad.
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
		local light_names = {[undead.node("light_post")] = true,
			[undead.node("light_wall")] = true,
			[undead.node("light_indoor")] = true}
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
				error("wp13 nhal veyr: destination " .. id .. " is missing", 0)
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
			error("wp13 nhal veyr: no door for " .. id, 0)
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
				ossuary_court = {min = {x = COURT.x1, y = 0, z = COURT.z1},
					max = {x = COURT.x2, y = 8, z = COURT.z2}},
				-- `kings_hall` and not `mausoleum`, even though the plot is
				-- called one: the landmark is the consumer seam every capital
				-- publishes (the king encounter, WP17), and a capital that
				-- renamed it for flavour would be a capital nothing could find
				-- the throne room of. The tomb is the hall; the name is the
				-- contract's.
				kings_hall = box("mausoleum", 2, 2),
				kings_hall_door = door_of("mausoleum"),
				market = box("market", 1, 1),
				vigil_hall = box("vigil_hall", 2, 4),
				vigil_hall_door = door_of("vigil_hall"),
				destinations = destinations,
				doors = doorways,
				rooms = rooms,
				lights = lights,
				sockets = sockets,
				parapet_columns = parapet,
				parapet_bars = bars,
				corner_drums = drums,
				graves = graves,
				gravewoods = trees,
				flora = flora,
				nave_floor = #nave,
			},
		}
	end

	-- The overlay seam, in one place: the run list in authored order (avenues
	-- first, then the ring street, then the district lanes, then the wall) and
	-- the one function that turns a run into cells. The successor's
	-- first-run-wins arbitration reads this order, so the avenue runs through
	-- the gate and the wall yields the cells of the road it lets past.
	--
	-- The district lanes belong to the four QUADRANTS and not to the districts
	-- standing in them, so the caller passes them in rather than this file
	-- reaching for `nhal_veyr_quadrants.lua`: the core composition knows about
	-- the streets it authored itself and about nothing else.
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

	-- One run, dispatched by its own id. A wall run carries authored geometry
	-- the seam's overlay spec has no field for -- which side is the field,
	-- where the turrets and the gate stand -- so it is looked up here, from the
	-- same table for every piece, which is what keeps a piece of a run exactly
	-- that stretch of the whole run.
	--
	-- A WALL DOES NOT OBEY THE CROSSING RULE, and this file repeats Highcourt's
	-- decision rather than re-deciding it. `r7_settlement.lua` hands every run
	-- of an overlay an `overhead(x, z)` callback and `avenue.run` uses it to
	-- ramp the carriageway up to a bridge deck wherever a WP40 route passes
	-- over the run. That is right for a road, whose job is to be walkable from
	-- end to end, and wrong for a curtain wall, whose job is to be a continuous
	-- line of masonry standing on the ground: a wall that climbed to meet a
	-- deck would leave the ground it was founded on and open exactly the gap
	-- the module's no-gap guarantee exists to make impossible.
	--
	-- So the seam is not passed on. The spec is copied field by field WITHOUT
	-- `overhead` rather than handed over and hoped about, because `wall.lua`
	-- ignoring a field today is not the same promise as this file never giving
	-- it one. The KAT holds the two to that.
	-- -------------------------------------------------------------------
	-- THE GATE RAMP, and why an avenue of this capital needs one
	-- -------------------------------------------------------------------
	--
	-- `avenue.lua` walks a road at the ONE-LIPSCHITZ UPPER ENVELOPE of the
	-- ground: at or above it everywhere, changing at most a node per column.
	-- Where the ground falls faster than a node per column the road therefore
	-- does not follow it down -- it cannot -- and rides out over its own fill.
	--
	-- Nhal Veyr's NORTH axis does exactly that. The free terrain on the centre
	-- line falls from 119 at z = 232 to 87 at z = 260 on the user gate seed --
	-- 32 nodes over 28 columns, 1.5 to 2.0 a column -- and it falls at that
	-- rate on ALL NINE seeds of `capital_anchor_fixture.lua`. A one-Lipschitz
	-- road starting at 119 can be no lower than 91 at 260, so the carriageway
	-- stands 4 courses above its ground at the gate point on the gate seed and
	-- 6 on seed 12345, with nothing at its edge. The east, south and west axes
	-- fall 0 to 3 nodes in total and ride their own ground the whole way, which
	-- is why the first version of this package measured the east avenue, found
	-- nothing, and wrote down that there was nothing to find. The independent
	-- review of 2026-09-16 measured the other three.
	--
	-- THE COORDINATOR'S RULING (2026-09-16, the same one Kezamba is built to):
	-- the avenue ARRIVES AT EACH GATE POINT -- (ax +- 256, az) and
	-- (ax, az +- 256), which is where Lane R ends its route at free-terrain
	-- height -- AT THE FREE-TERRAIN HEIGHT THERE, descending inside the
	-- envelope as a ramp of at most one node per column over as many columns as
	-- it needs, railed wherever the fill under it reaches Dur Brannoc's three
	-- courses, and nothing floating.
	--
	-- HOW IT IS BUILT WITHOUT TOUCHING `avenue.lua`. The road module is Lane
	-- R's and is frozen; what this composition owns is the SURFACE it hands it.
	-- So the ramp is a cap on that surface and nothing else:
	--
	--     cap(p) = gate_y + |p - gate_at|      (gate_y = the free terrain at
	--     capped(x, z) = min(surface(x, z), cap(p))    the gate point)
	--
	-- `cap` is itself one-Lipschitz and everywhere at or above `capped`, so the
	-- road's envelope E -- the LOWEST one-Lipschitz field at or above `capped`
	-- -- is at or below `cap` everywhere; and at the gate point
	-- `capped = min(ground, gate_y) = gate_y`, so
	--
	--     gate_y <= E(gate_at) <= cap(gate_at) = gate_y.
	--
	-- The road arrives at the gate at the free terrain, exactly, by arithmetic
	-- rather than by measurement -- and it gets there by CUTTING into the
	-- hillside further in rather than by riding out over fill. Two corrections
	-- follow from that and are made here:
	--
	--   * A CUTTING HAS TO BE EXCAVATED. `avenue.run` fills from the surface it
	--     was given up to its envelope and writes nothing above; where the cap
	--     bit, the real hillside stands over the road. Every such column is
	--     cleared from one course over the road to the natural ground, using
	--     the natural heights the cap already read -- no second query.
	--   * WHAT FILL IS LEFT IS RAILED. Past the gate point the ground keeps
	--     falling and the road can still only descend a node a column, so the
	--     last few columns under the gatehouse stand on fill. Dur Brannoc's
	--     rule, unchanged and re-derived from the piece's own cells: a kerb
	--     column whose cells span three or more courses is a column the road
	--     had to fill, and one course of citadel masonry on top of it is the
	--     rail.
	--
	-- Both read only the piece's own cells and the surface the piece already
	-- asked for, so a piece of a run is still exactly that stretch of the whole
	-- run and the KAT cuts it at every column to prove it.
	local GATE_POINT = 256
	-- Three courses of fill, not two: a column standing one or two above its
	-- own ground is a terrace stair, and a rail on every tread would turn the
	-- ordinary road into a trench. Three is an embankment. Dur Brannoc's own
	-- number, and its reasoning.

	local function axis_column(spec, p, offset)
		if spec.axis == "x" then return p, spec.at + offset end
		return spec.at + offset, p
	end
	local function axis_along(spec, x, z)
		if spec.axis == "x" then return x end
		return z
	end
	-- The lane a column stands in, signed: 0 is the centre line, +-half the
	-- kerbs, +-(half + 1) the verges the lamp standards stand on.
	local function axis_across(spec, x, z)
		if spec.axis == "x" then return z - spec.at end
		return x - spec.at
	end

	-- Which end of a RUN carries a gate station, by the run's own id, or nil
	-- for a run that has none: the ring street and the eight district lanes
	-- never leave the envelope, so they are handed to the road module
	-- untouched.
	--
	-- BY ITS ID AND NOT BY ITS SPAN, and the KAT's own split test is what said
	-- so. The successor calls a run once per mapchunk with `from`/`to` clipped
	-- to that chunk, so a PIECE of the north avenue two hundred nodes inside
	-- the envelope has neither end of its run in it -- and the first version of
	-- this table asked the spec where it ended, lost the gate, and built that
	-- piece with no cap on it. The two halves of one run then disagreed about
	-- the road forty columns from the join, which is exactly the chunk seam the
	-- road module's whole design exists to make impossible.
	local GATE_OF = {}
	for _, run in ipairs(M.avenues) do
		if run.to >= GATE_POINT then
			GATE_OF[run.id] = GATE_POINT
		elseif run.from <= -GATE_POINT then
			GATE_OF[run.id] = -GATE_POINT
		end
	end

	local function gate_road(avenue, palette, spec, surface)
		local gate_at = GATE_OF[spec.id]
		if gate_at == nil then return avenue.run(palette, spec, surface) end
		local gx, gz = axis_column(spec, gate_at, 0)
		local gate_y = surface(gx, gz)
		if type(gate_y) ~= "number" or gate_y % 1 ~= 0 then
			error("wp13 nhal veyr: the surface at the gate point of " ..
				tostring(spec.id) .. " is " .. tostring(gate_y) ..
				", not a node height", 0)
		end
		-- The natural height of every column the road reads, memoised as it is
		-- read, so the cutting and the rail below cost no query of their own.
		local natural = {}
		local function capped(x, z)
			local y = surface(x, z)
			natural[x .. ":" .. z] = y
			local cap = gate_y + math.abs(axis_along(spec, x, z) - gate_at)
			if y > cap then return cap end
			return y
		end
		local piece = avenue.run(palette, spec, capped)

		-- The piece's own columns: the lowest and highest cell of each.
		local low, high, order = {}, {}, {}
		for index = 1, #piece.cells do
			local cell = piece.cells[index]
			local key = cell.x .. ":" .. cell.z
			if low[key] == nil then
				low[key], high[key] = cell.y, cell.y
				order[#order + 1] = {key = key, x = cell.x, z = cell.z}
			else
				if cell.y < low[key] then low[key] = cell.y end
				if cell.y > high[key] then high[key] = cell.y end
			end
		end

		local half = ((spec.width or avenue.WIDTH) - 1) / 2
		local PAVING = palette.maybe("castle_paving") or palette.node("plaza")
		local cut, rail, fill_max, cut_max = 0, 0, 0, 0
		for index = 1, #order do
			local entry = order[index]
			local top = high[entry.key]
			local ground = natural[entry.key]
			local across = math.abs(axis_across(spec, entry.x, entry.z))
			-- What this column cost, measured BEFORE either addition below, so
			-- the numbers a tool reads are the road's and not the rail's. The
			-- carriageway only: a VERGE column carries a lamp standard -- a
			-- footing, two posts and a torch -- and its top stands three
			-- courses over its own ground whatever the road does.
			if across <= half and ground ~= nil then
				if top - ground > fill_max then fill_max = top - ground end
				if ground - top > cut_max then cut_max = ground - top end
			end
			-- 1. The cutting: the hillside standing over a road the cap put
			-- below it. `natural` is the RAW surface, so this is the excavation
			-- and nothing more.
			if ground ~= nil and ground > top then
				for y = top + 1, ground do
					piece.cells[#piece.cells + 1] = {x = entry.x, y = y,
						z = entry.z, name = parts.AIR, param2 = 0}
					cut = cut + 1
				end
			end
			-- 2. THE RAIL IS THE ROAD MODULE'S NOW. A kerb course on a column
			-- the road had filled by three or more was this capital's parapet;
			-- since playtest 5 (2026-09-16) such a column is not filled at all
			-- but carried on pillars, and `wp13/avenue.lua` rails the two VERGE
			-- lanes of every raised or bridged span in every capital -- outside
			-- the carriageway, where a rail belongs, and not on its outermost
			-- lane. What is left here is this capital's own gate geometry: the
			-- cap, the cutting and the tunnel floor.
		end
		-- 3. THE GATE TUNNEL'S FLOOR, which only a FINISHED MAP shows.
		--
		-- `wall.lua` cuts its gate passage as air from the column's own LOWEST
		-- ground over the curtain's seven lanes up to one course under the deck,
		-- and it does that on the strength of a comment that the avenue "writes
		-- its pavement from the GROUND upward" and therefore holds its own road
		-- up. That is true of a road laid on its own ground -- Highcourt's and
		-- Dur Brannoc's gate columns are solid from the tunnel floor to the road
		-- stair, measured -- and it stops being true the moment a road is laid
		-- ABOVE the lowest ground of that band, which is exactly what arriving
		-- at the gate point's own height does here: at Nhal Veyr's north gate
		-- the curtain's tunnel floor is 91 and the road is 94, and the two
		-- courses between them were air with the carriageway riding over them.
		--
		-- No offline check could see it: the road piece is solid, and the hole
		-- is opened by ANOTHER run afterwards. The engine's own read-back is
		-- what found it (`evidence/.../nhal_veyr/approach.py`).
		--
		-- So the road carries its own tunnel: over the band the curtain clears --
		-- `wall.HALF` columns either side of the gate point, and
		-- `wall.GATE_PASSAGE` lanes either side of the centre line, which are the
		-- curtain's own two numbers and not new ones -- every column is filled
		-- from the LOWEST ground of that band up to the road. The avenue is the
		-- first run and wins every cell it and the curtain share, so what it
		-- writes here is what the map gets.
		local tunnel = 0
		local band_low = gate_at - wall.HALF
		local band_high = gate_at + wall.HALF
		if spec.from <= band_high and spec.to >= band_low then
			local floor_of = {}
			for lane = -wall.GATE_PASSAGE, wall.GATE_PASSAGE do
				local lowest
				for p = band_low, band_high do
					local x, z = axis_column(spec, p, lane)
					local y = surface(x, z)
					if lowest == nil or y < lowest then lowest = y end
				end
				floor_of[lane] = lowest
			end
			for index = 1, #order do
				local entry = order[index]
				local p = axis_along(spec, entry.x, entry.z)
				local lane = axis_across(spec, entry.x, entry.z)
				local bottom = floor_of[lane]
				if bottom ~= nil and p >= band_low and p <= band_high then
					for y = bottom, low[entry.key] - 1 do
						piece.cells[#piece.cells + 1] = {x = entry.x, y = y,
							z = entry.z, name = PAVING, param2 = 0}
						tunnel = tunnel + 1
					end
				end
			end
		end

		piece.gate_at = gate_at
		piece.gate_y = gate_y
		piece.cut = cut
		piece.rail = rail
		piece.tunnel = tunnel
		piece.fill_max = fill_max
		piece.cut_max = cut_max
		return piece
	end

	function M.overlay_run(avenue, palette, spec, surface)
		local plan = M.wall_plan[spec.id]
		if not plan then return gate_road(avenue, palette, spec, surface) end
		return wall.run(palette, {
			id = spec.id, axis = spec.axis, at = spec.at,
			from = spec.from, to = spec.to, width = spec.width,
			lamp_spacing = spec.lamp_spacing, lamp_phase = spec.lamp_phase,
			reach = spec.reach,
		}, surface, plan)
	end

	return M
end

return loader
