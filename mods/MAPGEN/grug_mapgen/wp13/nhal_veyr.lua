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
-- "raised necropolis, step 3 | dungeon stone and obsidian brick, mausoleum
-- core, stepped terraces with ruins mixed among kept houses, candles and iron
-- bars", and -- by the user's ruling of 2026-09-14 -- a WALLED one. The
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
	local wall = dofile(directory .. "/wall.lua")(directory)
	local plots = dofile(directory .. "/nhal_veyr_plot.lua")(directory)

	local M = {}

	local RADIUS = 47
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
		{-8, -40, 8, -38, "lane"},
		{38, -8, 40, 8, "lane"},
		{-40, -8, -38, 8, "lane"},
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
			x = -6, z = 41, turns = 2, palette = "crypt", roof = "vault",
			spec = {patrol_group = "nhal_veyr_gate_north_tower",
				deck_group = "nhal_veyr_gate_north_tower", order = 2}},
		{id = "gate_east", module = "capitals", make = "gatehouse",
			x = 41, z = -6, turns = 3, palette = "crypt", roof = "vault",
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
			x = 29, z = -46, turns = 0, palette = "crypt", roof = "vault",
			spec = {w = 13, d = 17, wall_h = 6}},

		-- 9. The kept houses: four on the outer ground, and the contract's
		-- "ruins mixed among kept houses" -- one fallen shell between two of
		-- them, which is the line's whole point at core scale.
		--
		-- The cottages keep the generator's own door side (`z-`) and are TURNED
		-- to face their ground instead: the `home` kit furnishes the cell
		-- behind every other wall and only the z- doorway is authored clear.
		{id = "market_house", module = "buildings", make = "cottage",
			x = -45, z = -20, turns = 1, palette = "undead",
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
	-- THEY REACH 261, not the gate station at 256, because Nhal Veyr has a
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
		for _, spot in ipairs({{26, 23}, {28, 23}, {36, 23}, {38, 23}}) do
			paved_prop("slab", spot[1], spot[2], spot[1], spot[2],
				function()
					buf:put(spot[1], 1, spot[2], SIGNATURE)
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

		-- 9. The gravewood stands, BEFORE the burial ground and not after it.
		-- A tree needs three nodes of clear ground round its stem and a graveyard
		-- leaves none: `dressing.graveyard` sets a marker on every other column
		-- of its rectangle, so run the other way round only one stand in the
		-- whole pad finds room. The markers break round the trees instead, which
		-- is also what a burial ground under trees looks like.
		--
		-- THREE NODES CLEAR OF THE PRECINCT RING, every stand. A crown reaches three nodes
		-- from its stem, the parapet is written after the trees and only asks
		-- whether the four courses above the ground are free -- so a stem at
		-- the ring's own column lets the wall be built under it and hangs
		-- leaves on the merlon cap. That is the defect Dur Brannoc's pines had
		-- and the KAT's shape rule is what found it.
		local trees = layout.plant_gravewood(buf, undead, -42, -42, 42, 42, 4)
		if trees < 12 then
			error("wp13 nhal veyr: only " .. trees ..
				" gravewood stands found open ground", 0)
		end

		-- 10. THE BURIAL GROUND between the quarters, which is what a necropolis
		-- puts on the turf its plots leave. Four stretches of open ground get
		-- rows of markers; `dressing.graveyard` sets one only where the ground
		-- is its own and the cell above is free, so the run breaks by itself at
		-- a street, a plot or a lamp standard.
		local graves = 0
		for _, field in ipairs({{-20, -44, -8, -20}, {6, -44, 18, -20},
				{-20, 8, -8, 34}, {24, -36, 36, -20}}) do
			graves = graves + dressing.graveyard(buf, undead, field[1],
				field[2], field[3], field[4])
		end
		if graves < 60 then
			error("wp13 nhal veyr: only " .. graves ..
				" grave markers found open ground", 0)
		end

		-- 11. THE CITADEL PARAPET, and the four drums at the corners of the
		-- pad: Nhal Veyr's core edge, the piece Dur Brannoc landed, in dungeon
		-- stone.
		--
		-- The DRUMS FIRST, because the parapet runs into them and not the other
		-- way round: the ring is walked column by column and stops at whatever
		-- already stands on the boundary, so a drum authored afterwards would
		-- find its own corner built over and quietly not appear.
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
			error("wp13 nhal veyr: " .. drums ..
				" of the four corner drums found room", 0)
		end
		-- The parapet is walked round the WHOLE pad rather than authored in
		-- four stretches: every column of the boundary ring that is still open
		-- ground gets its courses, and the run breaks by itself at a gatehouse,
		-- a drum, a plot or a street. Hand-placed runs are how a boundary ends
		-- up built through a cottage's apron.
		--
		-- IRON BARS ON THE RHYTHM, which is where the contract's "candles and
		-- iron bars" reaches the core's own edge: every fourth column of the
		-- parapet carries a barred opening instead of a merlon -- the palette's
		-- `window`, an `xpanes` flat pane, standing in the gap between two
		-- courses of masonry.
		local parapet, bars = 0, 0
		for offset = -RADIUS + 1, RADIUS - 1 do
			for _, spot in ipairs({{offset, RADIUS - 1}, {offset, -RADIUS + 1},
					{RADIUS - 1, offset}, {-RADIUS + 1, offset}}) do
				local x, z = spot[1], spot[2]
				-- Only on the ground the settlement has NOT paved. A precinct
				-- wall walked across a gate road is a gate nothing can drive
				-- through, and `layout.free` says "nothing stands here", not
				-- "this is not a street".
				if layout.natural(buf, x, z) and layout.free(buf, x, z, 4) then
					buf:put(x, 1, z, STONE)
					buf:put(x, 2, z, STONE)
					if (x + z) % 4 == 0 then
						buf:put(x, 3, z, STONE)
						buf:put(x, 4, z, CAP)
					elseif (x + z) % 4 == 2 then
						buf:put(x, 3, z, undead.node("window"))
						bars = bars + 1
					end
					parapet = parapet + 1
				end
			end
		end

		-- 12. Blight flora on the turf between the quarters.
		dressing.blight_flora(buf, undead, -RADIUS, -RADIUS, RADIUS, RADIUS,
			11, 3, 4)

		-- 13. The sockets the composition owns.
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
		socket("court_idle_works", "idle", 41, 1, 23, 3, {tags = {"work"}})
		socket("court_idle_yard", "idle", 28, 1, 24, 0, {tags = {"work"}})
		socket("court_idle_fire", "idle", 35, 1, 39, 0, {tags = {"fire"}})
		socket("forecourt_idle_west", "idle", -6, 1, 3, 1, {tags = {"bench"}})
		socket("forecourt_idle_east", "idle", 7, 1, 3, 3, {tags = {"bench"}})

		-- THE CORE'S OWN WORKPLACES (sockets contract section 8.1). Each one
		-- stands on the composition's own paving and faces a feature the
		-- composition itself wrote three lines above, which is the whole point
		-- of the feature rule: the KAT re-derives it from the finished cells,
		-- so a slab or a pot that moves takes its socket's acceptance with it.
		local function work(id, activity, x, z, face, tags)
			socket(id, "work", x, 1, z, face, {activity = activity,
				tags = tags})
		end
		work("court_work_slab", "carve", 27, 23, 1)
		work("court_work_pot", "brew", 31, 23, 1)
		work("court_work_stack", "carve", 22, 13, 0)

		-- 14. THE CORE'S SPARE IDLE SPOTS (playtest round 2, 2026-09-15).
		-- `spawn = false` is what makes them wander TARGETS and never homes:
		-- the roster places one citizen per SPAWN socket and `next_spot` walks
		-- every idle socket, so a city whose spots and citizens are the same
		-- thirty has an amble in which every destination is permanently taken.
		-- Ten spares along the avenues and courts is what gives the crowd
		-- somewhere to go, and is the population Highcourt's core carries.
		--
		-- No tag: a tag is what the spoken line and the facing rule read
		-- (`_grug_idle_tag`, `FACE_AWAY_TAGS`), and a spare has neither a line
		-- nor a door.
		local function spare(id, x, z, face)
			socket(id, "idle", x, 1, z, face, {spawn = false})
		end
		spare("core_spare_crossing_east", 12, -4, 3)
		spare("core_spare_crossing_west", -13, -1, 1)
		spare("core_spare_hall_green", 19, 13, 3)
		spare("core_spare_market_walk", -15, -20, 0)
		spare("core_spare_approach", 2, -26, 0)
		spare("core_spare_west_lane", -23, 16, 1)
		spare("core_spare_east_avenue", 30, -2, 3)
		spare("core_spare_west_avenue", -31, 0, 1)
		spare("core_spare_north_court", 20, 31, 2)
		spare("core_spare_plaza_south", 24, -20, 3)

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
				mausoleum = box("mausoleum", 2, 2),
				mausoleum_door = door_of("mausoleum"),
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
	function M.overlay_run(avenue, palette, spec, surface)
		local plan = M.wall_plan[spec.id]
		if not plan then return avenue.run(palette, spec, surface) end
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
