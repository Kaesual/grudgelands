-- Gor Drazhak: the orc capital, and the war camp that became a city.
--
-- This file is the CORE composition of docs/research/wp13-capitals-pois-
-- contract.md section 2.1 -- the 96 x 96 civic core, anchor-relative exactly
-- like a start, flat at y = 0 by construction, inside the contract's bounds of
-- x/z [-47, 47] and y [-2, 40] -- plus the overlay dispatch for the avenues,
-- the ring street, the district lanes and the RAMPART.
--
-- Gor Drazhak is the orc capital of the contract's section 2.4 table:
--
--     "Gor Drazhak | orc | mesa shelf, step 4 | adobe flat roofs with
--      parapets, ors-stone base courses, palisade and earthworks, warlord hall
--      with fighting platform"
--
-- and section 4 makes it one of the walled capitals (the user's ruling of
-- 2026-09-14: walls for Dur Brannoc, Nhal Veyr and Gor Drazhak). Every one of
-- those six clauses is a thing in this file or in a file it loads:
--
--   * ADOBE FLAT ROOFS WITH PARAPETS -- `roof = "flat_deck"` on every dwelling
--     and every workshop, with a breastwork ring written over the finished deck
--     (`breastwork` below and `gor_drazhak_plot.lua`'s copy of it). Highcourt is
--     all ridges and Dur Brannoc all slate; this capital's skyline is a terrace
--     of fighting tops, and that is what it is recognised by.
--   * ORS-STONE BASE COURSES -- the second palette handle, which builds a civic
--     building out of `grug_decor:darkage_ors_block` where a dwelling is adobe.
--   * PALISADE AND EARTHWORKS -- `wp13/orc_palisade.lua` on the envelope edge,
--     and the precinct's own bank and stockade round this pad.
--   * WARLORD HALL WITH FIGHTING PLATFORM -- the library's great hall, and in
--     front of its door a raised ors-stone platform with its own breastwork,
--     stair, braziers and standards, which is section 5.2 below.
--   * MESA SHELF, STEP 4 -- the terrain WP40 already fits, and the reason every
--     district plot is terrain-relative.
--
--   * `M.core()` returns the core composition in the exact shape of a start
--     composition (schema, canonical cells, bounds, sorted palette, landmarks)
--     plus `landmarks.sockets`, the NPC seam of
--     docs/research/wp13-npc-sockets-contract.md.
--   * `M.district` is the 52-plot list of the four districts
--     (`gor_drazhak_districts.lua`), resolved against this world's quadrant
--     permutation.
--   * `M.avenues`, `M.ring`, `M.lanes` and `M.wall` are the overlay runs, all
--     four lists living in `gor_drazhak_quadrants.lua` because they are the
--     city's plan geometry and the lot predicate has to read them beside the
--     lots.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local palettes = dofile(directory .. "/palette.lua")
	local buildings = dofile(directory .. "/buildings.lua")(directory)
	local capitals = dofile(directory .. "/capitals.lua")(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local layout = dofile(directory .. "/layout.lua")(directory)
	local palisade = dofile(directory .. "/orc_palisade.lua")(directory)
	local precinct_ring = dofile(directory .. "/precinct_ring.lua")
	local quadrants = dofile(directory .. "/gor_drazhak_quadrants.lua")()
	local districts = dofile(directory .. "/gor_drazhak_districts.lua")(directory)
	local street_plan = dofile(directory .. "/street_plan.lua")(directory)

	local M = {}

	local RADIUS = 49
	local SCHEMA = "grug_wp13_gor_drazhak_core_v1"

	-- The city's own patrol loop. The four gatehouses keep a two-waypoint watch
	-- each, for the reason Highcourt records: a gate tower's waypoints are on
	-- the wall walk and on the fighting deck above it, and a ground loop that
	-- took either in would ask an NPC to step from the street to a rampart
	-- through a wall.
	local WATCH = "gor_drazhak_watch"

	-- THE SECOND PALETTE HANDLE, the same one the district plots use: ors
	-- block in place of adobe for the civic buildings, which is the contract's
	-- "ors-stone base courses" carried up the whole wall of a building that is
	-- meant to read as the warlord's and not as a dwelling.
	local ORS = {
		wall = "grug_decor:darkage_ors_block",
		wall_infill = "grug_decor:darkage_adobe",
	}

	-- The warlord hall's own dimensions, in one place, so the floor this
	-- composition lays inside it cannot be left behind by a hall of another
	-- size. `base`, `arcade` and `dais` are `capitals.king_hall`'s own.
	local HALL = {w = 31, d = 27, rise = 7, base = 2, arcade = 5, dais = 9}

	-- The travel plaza reserved for WP17: kerbed, lit from its own kerb and
	-- empty of everything above its paving. x1 is 11 and not 8, for the reason
	-- Dur Brannoc records: the east colonnade's eaves oversail its own
	-- footprint to x = 9, and a plaza that starts there has ten slabs hanging
	-- over the square WP17's pad is being kept clear for.
	local PLAZA = {x1 = 11, z1 = -32, x2 = 27, z2 = -12}

	-- THE MUSTER COURT: the whole north-east quarter, one floor of beaten red
	-- sand, which is this capital's signature quarter the way the forge court
	-- is Dur Brannoc's. It is where the host forms up, where the two royal
	-- booths stand, and where a visitor who walks in from the east gate first
	-- sees what kind of city this is.
	local COURT = {x1 = 22, z1 = 5, x2 = 45, z2 = 43}

	-- THE FIGHTING PLATFORM (contract section 2.4, "warlord hall with fighting
	-- platform"): a raised court on the hall's own forecourt, beside its great
	-- door, four courses up, with its own breastwork and one flight off its
	-- outer flank. Authored here and not in `capitals.lua`, because only this
	-- composition knows which way the hall faces and where its approach runs.
	--
	-- BESIDE THE DOOR AND NOT ACROSS IT. The first version put it on the axis
	-- between the crossing and the hall, which is where it looks best and where
	-- it makes the throne approach a four-node wall: the south gate road, the
	-- one route every consumer starts from, ran into it. It stands on the east
	-- half of the forecourt instead, so the carriageway and the door are clear
	-- and the platform still looks down the whole approach.
	local PLATFORM = {x1 = 4, z1 = 3, x2 = 14, z2 = 8, top = 4}

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
		{-8, -(RADIUS - 7), 8, -38, "lane"},
		{-8, 38, 8, RADIUS - 7, "lane"},
		{38, -8, RADIUS - 7, 8, "lane"},
		{-(RADIUS - 7), -8, -38, 8, "lane"},
		-- The travel plaza's approach off the east avenue.
		{4, -13, 11, -11, "lane"},
		-- The west quarter: the cistern court's walk and the skull hall's.
		{-34, 14, -25, 16, "lane"},
		{-38, 17, -36, 23, "lane"},
		-- The doorsteps of the outer houses and the council house.
		{-36, -17, -34, -15, "lane"},
		{-31, -38, -29, -36, "lane"},
		{34, -14, 36, -12, "lane"},
		{26, -40, 28, -38, "lane"},
		{17, -40, 19, -38, "lane"},
	}

	-- The plot roster. `make` is the generator, `module` the library it comes
	-- from, `x`/`z` the pad anchor of the rotated footprint, `turns` the
	-- rotation, `palette` which handle it is built with, `parapet` the deck
	-- ring a flat-roofed plot gets.
	--
	-- `drop` and `recast` are the socket policy of the sockets contract, and
	-- they exist because a part cannot know how many of a thing a CAPITAL may
	-- have: one throne, one travel pad for WP17 and one vendor per kind in
	-- `grug_traders`. The KAT asserts the resulting multiset.
	local PLOTS = {
		-- 1. THE WARLORD HALL, on the axis, its great door looking down the
		-- approach to the south gate and over the fighting platform.
		{id = "warlord_hall", module = "capitals", make = "king_hall",
			x = -15, z = 9, turns = 0, palette = "ors",
			spec = {w = HALL.w, d = HALL.d, rise = HALL.rise},
			drop = {waypoint = true}},

		-- 2. The four inner gatehouses, where the avenues leave the precinct.
		-- The rampart is 209 nodes further out, so these are the citadel's own
		-- gates and not the city's.
		{id = "gate_south", module = "capitals", make = "gatehouse",
			x = -6, z = -RADIUS, turns = 0, palette = "ors",
			spec = {patrol_group = "gor_drazhak_gate_south_tower",
				deck_group = "gor_drazhak_gate_south_tower", order = 2}},
		{id = "gate_west", module = "capitals", make = "gatehouse",
			x = -RADIUS, z = -6, turns = 1, palette = "ors",
			spec = {patrol_group = "gor_drazhak_gate_west_tower",
				deck_group = "gor_drazhak_gate_west_tower", order = 2}},
		{id = "gate_north", module = "capitals", make = "gatehouse",
			x = -6, z = 43, turns = 2, palette = "ors",
			spec = {patrol_group = "gor_drazhak_gate_north_tower",
				deck_group = "gor_drazhak_gate_north_tower", order = 2}},
		{id = "gate_east", module = "capitals", make = "gatehouse",
			x = 43, z = -6, turns = 3, palette = "ors",
			spec = {patrol_group = "gor_drazhak_gate_east_tower",
				deck_group = "gor_drazhak_gate_east_tower", order = 2}},

		-- 3. The great bazaar square, west of the approach.
		{id = "bazaar_square", module = "capitals", make = "market_square",
			x = -35, z = -28, turns = 0, palette = "orc",
			spec = {size = 25},
			drop = {waypoint = true},
			-- A booth without a trader is a flair NPC's work spot, and its id
			-- has to say booth: `market_vendor_1` with the role `idle` is a
			-- socket that argues with itself.
			recast = {vendor = {role = "idle", tags = {"work"},
				from = "_vendor_", to = "_booth_"}}},

		-- 4. The two colonnades flanking the approach.
		{id = "colonnade_west", module = "capitals", make = "colonnade",
			x = -9, z = -21, turns = 1, palette = "orc",
			spec = {len = 15, patrol_group = WATCH, order = 1}},
		{id = "colonnade_east", module = "capitals", make = "colonnade",
			x = 4, z = -21, turns = 3, palette = "orc",
			spec = {len = 15, patrol_group = WATCH, order = 6}},

		-- 5. The civic furniture: the warlord's statue east of the crossing and
		-- the cistern court in the west quarter. A mesa shelf has no standing
		-- water anywhere in its envelope -- measured on three worlds, section 1
		-- of `gor_drazhak_quadrants.lua` -- so the city's water is a tank and
		-- the well court is what stands over it.
		{id = "statue", module = "capitals", make = "statue_plinth",
			x = 12, z = -11, turns = 0, palette = "orc", spec = {}},
		{id = "cistern_court", module = "capitals", make = "well_court",
			x = -45, z = 9, turns = 0, palette = "orc", spec = {size = 11}},

		-- 6. THE SKULL HALL: the capital library's temple, in the west quarter,
		-- and where this capital's first quest shell stands.
		{id = "skull_hall", module = "capitals", make = "temple",
			x = -44, z = 22, turns = 0, palette = "ors",
			spec = {w = 13, d = 19, wall_h = 7, rise = 5},
			-- The temple publishes its own quest shell. It is MOVED AND
			-- RETAGGED here: `capitals.temple` stands it three nodes inside its
			-- own door, in the nave, where a shrine's keeper belongs and a
			-- quest-giver does not. The user's playtest-round-2 ruling is that
			-- the elder stands on the doorstep and shows the street his face,
			-- so this plot puts him one node outside the door on the temple
			-- walk and tags him `door`, which is what turns an NPC round
			-- (`grug_mobs/start_npcs.lua`, `socket_face_yaw`). Both halves are
			-- here and not in `capitals.lua` because the generator cannot know
			-- which of its walls this composition puts to a lane.
			socket_overrides = function(placed)
				return {skull_hall_quest = {x = placed.x + 6,
					z = placed.z - 1, face = 0, tags = {"door"}}}
			end},

		-- 7. The muster court's own buildings: the host's store and the beast
		-- shed, both standing on the red sand.
		{id = "host_store", module = "capitals", make = "granary",
			x = 24, z = 8, turns = 0, palette = "ors",
			spec = {w = 11, d = 15, wall_h = 5}},
		{id = "beast_shed", module = "buildings", make = "shed",
			x = 24, z = 27, turns = 0, palette = "orc",
			-- x 24..36, z 27..35: the north half of the court, which leaves
			-- the band at z 23..26 clear for the muster ground.
			spec = {w = 13, d = 9, wall_h = 4, open_sides = {"z-", "x+"}}},

		-- 8. THE WAR COUNCIL HOUSE, in the south-east corner: the bone record
		-- of the clans, which is this race's archive.
		{id = "council_house", module = "capitals", make = "scriptorium",
			x = 29, z = -46, turns = 2, palette = "ors",
			spec = {w = 13, d = 17, wall_h = 6}},

		-- 9. The clans' quarter: four dwellings on the outer ground, every one
		-- flat decked behind its own breastwork. The cottages keep the
		-- generator's own door side (`z-`) and are TURNED to face their ground
		-- instead: the `home` kit furnishes the cell behind every other wall
		-- and only the z- doorway is authored clear of it.
		{id = "bazaar_house", module = "buildings", make = "cottage",
			x = -45, z = -20, turns = 3, palette = "orc",
			parapet = {y = 6},
			spec = {w = 9, d = 9, wall_h = 4, roof = "flat_deck",
				infill = true, shutters = true}},
		{id = "south_house", module = "buildings", make = "cottage",
			x = -41, z = -41, turns = 1, palette = "orc",
			parapet = {y = 6},
			spec = {w = 9, d = 9, wall_h = 4, roof = "flat_deck",
				infill = true}},
		{id = "lane_house", module = "buildings", make = "cottage",
			x = 37, z = -17, turns = 1, palette = "orc",
			parapet = {y = 7},
			spec = {w = 9, d = 9, wall_h = 5, roof = "flat_deck",
				infill = true, fancy_bed = true}},
		{id = "plaza_house", module = "buildings", make = "cottage",
			x = 9, z = -46, turns = 1, palette = "orc",
			parapet = {y = 6},
			spec = {w = 9, d = 9, wall_h = 4, roof = "flat_deck",
				infill = true, shutters = true}},
	}

	-- Destination order is part of the consumer contract and never changes.
	local DESTINATION_ORDER = {"warlord_hall", "gate_south", "gate_west",
		"gate_north", "gate_east", "skull_hall", "host_store", "beast_shed",
		"council_house", "bazaar_house", "south_house", "lane_house",
		"plaza_house"}

	-- The corner waypoints of the city loop, in the open ground between the
	-- outer plots, so the walk along the precinct bank has something to follow
	-- between one quarter and the next.
	local CORNERS = {
		{id = "watch_south_west", x = -30, z = -35, face = 0, order = 2},
		{id = "watch_north_west", x = -28, z = 44, face = 2, order = 3},
		{id = "watch_north_east", x = 43, z = 33, face = 2, order = 4},
		{id = "watch_south_east", x = 22, z = -40, face = 0, order = 5},
	}

	-- The overlay run lists, all four from the plan module.
	M.avenues = quadrants.AVENUES
	M.ring = quadrants.RING
	M.lanes = quadrants.lane_runs()
	M.wall = quadrants.WALL
	M.wall_plan = quadrants.WALL_PLAN
	M.quadrants = quadrants
	M.districts = districts

	-- `tools/wp13/capital_plots.lua`, the KAT and the renderer expect
	-- `capital.district.plots`: a flat list of `{id, x, z, build}`. This
	-- capital's is the CANONICAL assignment's, which is the one every
	-- engine-free caller sees; a world with a seed asks `M.districts.resolve`
	-- for its own (`wp40/r7_gor_drazhak_blueprint.lua`).
	M.district = {plots = districts.resolve()}

	-- THE BREASTWORK over a finished flat deck: the ring of low wall with a
	-- merlon on a two-node rhythm that turns a flat roof from a shed lid into a
	-- fighting top. Written only where the course below it is an opaque full
	-- node, so a ring cannot float over an eave the rasteriser did not lay --
	-- the same rule and the same reason as `gor_drazhak_plot.lua`'s copy.
	local function breastwork(buf, palette, x0, z0, x1, z1, y)
		local low = palette.node("low_wall")
		local merlon = palette.maybe("signature") or palette.node("wall_accent")
		local placed = 0
		for z = z0, z1 do
			for x = x0, x1 do
				if x == x0 or x == x1 or z == z0 or z == z1 then
					if parts.solid_at(buf, x, y - 1, z) then
						buf:put(x, y, z, low)
						if (x + z) % 2 == 0 then
							buf:put(x, y + 1, z, merlon)
						end
						placed = placed + 1
					end
				end
			end
		end
		return placed
	end

	function M.core()
		local orc = palettes.new("orc")
		local ors = palettes.new("orc", ORS)
		local handles = {orc = orc, ors = ors}
		local buf = parts.buffer()
		local doorways, rooms, sockets = {}, {}, {}
		local placed, inside_by_id, plot_order = {}, {}, {}
		local claimed = {}

		-- The court paving of the avenues and the cobble of the lanes, each
		-- resolved the way `capitals.lua` resolves it: the capital vocabulary
		-- is optional and falls back into the start vocabulary.
		local AVENUE = orc.maybe("castle_paving") or orc.node("plaza")
		local LANE = orc.node("path")
		local KERB = orc.node("plaza_edge")
		local STONE = orc.maybe("castle_wall") or orc.node("wall_accent")
		local ORS_BLOCK = orc.maybe("wall_infill") or orc.node("foundation")
		local SAND = orc.node("plaza")
		local EARTH = orc.node("subsoil")
		local BEATEN = orc.node("ground_bare")
		local TIMBER = orc.node("tree_log")
		local POINT = orc.maybe("stake_cap") or orc.node("roof_stair_outer")
		local SIGNATURE = orc.maybe("signature") or KERB

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
			GROUND[orc.node(role)] = true
		end

		-- Every prop the composition asks for MUST land; a prop quietly skipped
		-- is a hole in the authored scene no fixture can see (the Dawnmere
		-- lesson, wp13-hearthpine-library.md round A).
		local function refuse(name, x, z, reason)
			error("wp13 gor drazhak: prop " .. name .. " at " .. x .. "," ..
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

		-- 1. The shelf: dry ochre grass with the bare dirt and blown sand of a
		-- city that walks on it.
		layout.meadow(buf, orc, RADIUS, 40)

		-- 2. The streets, the muster court and the kerbs of the great avenues.
		for _, street in ipairs(STREETS) do
			local name = (street[5] == "avenue") and AVENUE or LANE
			pave(name, street[1], street[2], street[3], street[4], 5)
		end
		pave(SAND, COURT.x1, COURT.z1, COURT.x2, COURT.z2, 5)
		dressing.inlay(buf, orc, COURT.x1, COURT.z1, COURT.x2, COURT.z2)
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
		dressing.inlay(buf, orc, PLAZA.x1, PLAZA.z1, PLAZA.x2, PLAZA.z2)
		dressing.inlay(buf, orc, PLAZA.x1 + 4, PLAZA.z1 + 4,
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
			local module = (plot.module == "capitals") and capitals or buildings
			local generator = module[plot.make]
			if type(generator) ~= "function" then
				error("wp13 gor drazhak: no generator " .. plot.make, 0)
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
					error("wp13 gor drazhak: the plot " .. plot.id ..
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

		-- 4b. THE BREASTWORKS over the flat decks. Every dwelling of this
		-- capital wears one; the ring is written over the finished pad rather
		-- than by the generator, because a deck's ring has to break where
		-- another building's eave passes over it and only the pad knows that.
		local deck_rings = 0
		for _, plot in ipairs(PLOTS) do
			if plot.parapet then
				local spot = placed[plot.id]
				local ring = breastwork(buf, handles[plot.palette],
					spot.x - 1, spot.z - 1, spot.x + spot.w, spot.z + spot.d,
					plot.parapet.y)
				if ring < 16 then
					error("wp13 gor drazhak: the breastwork of " .. plot.id ..
						" found only " .. ring .. " columns of deck", 0)
				end
				deck_rings = deck_rings + 1
			end
		end

		-- 5. The hall's floor: an ors-stone edging either side of the carpet
		-- and a band across the nave at every arcade bay, with braziers between
		-- the bays. The generator owns the architecture; what a twenty-five-node
		-- nave of one paving material needs is a floor somebody drew.
		local nave = {}
		do
			local hall = placed.warlord_hall
			local floor_y = HALL.base
			local west = hall.x + HALL.arcade + 1
			local east = hall.x + HALL.w - 2 - HALL.arcade
			local carpet_from = hall.z + 1
			local carpet_to = hall.z + HALL.d - HALL.dais - 1
			local centre = hall.x + math.floor((HALL.w - 1) / 2)
			local paving_name = ors.maybe("castle_paving") or ors.node("plaza")
			local function inlay_floor(x, z)
				local cell = buf:at(x, floor_y, z)
				if cell == nil or cell.name ~= paving_name then
					error("wp13 gor drazhak: the hall's floor at " .. x .. "," ..
						z .. " is " .. (cell and cell.name or "air") ..
						", not the paving this band is laid into", 0)
				end
				buf:put(x, floor_y, z, ORS_BLOCK)
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
							error("wp13 gor drazhak: the brazier at " .. x ..
								"," .. z .. " stands in " .. cell.name, 0)
						end
					end
					parts.floor_torch(buf, orc, x, floor_y + 1, z)
				end
			end
		end

		-- 5b. THE FIGHTING PLATFORM, in front of the hall's great door.
		--
		-- The contract's own phrase for this capital is "warlord hall with
		-- fighting platform", and the library's great hall is a basilica with
		-- no such thing: the platform is the composition's, standing on the
		-- forecourt between the hall and the crossing. Solid ors stone to its
		-- deck, a breastwork round it with the merlon rhythm every other piece
		-- of this city uses, an outer stair off each flank so it is reachable
		-- without a ladder, a brazier at each corner and a standard at each
		-- front corner. The two waypoints of the city loop that stand ON it are
		-- what makes it a place the watch goes rather than a plinth.
		local platform_cells = 0
		do
			for z = PLATFORM.z1, PLATFORM.z2 do
				for x = PLATFORM.x1, PLATFORM.x2 do
					for y = 1, PLATFORM.top - 1 do
						buf:put(x, y, z, ORS_BLOCK)
						platform_cells = platform_cells + 1
					end
					buf:put(x, PLATFORM.top, z, STONE)
					platform_cells = platform_cells + 1
				end
			end
			buf:clear(PLATFORM.x1, PLATFORM.top + 1, PLATFORM.z1,
				PLATFORM.x2, PLATFORM.top + 4, PLATFORM.z2)
			breastwork(buf, ors, PLATFORM.x1, PLATFORM.z1, PLATFORM.x2,
				PLATFORM.z2, PLATFORM.top + 1)
			-- ONE FLIGHT, off the outer flank, and the gap it needs in the
			-- ring it lands in: a stair that climbs into a breastwork is a
			-- stair to a wall. It runs outward from the platform's east face
			-- into the open ground between the forecourt and the east flank
			-- lane, so nothing of it stands in a street.
			local flight_z = PLATFORM.z2 - 2
			local tread = orc.maybe("castle_wall_stair") or
				orc.node("roof_stair")
			for step = 0, PLATFORM.top - 1 do
				local x = PLATFORM.x2 + 1 + step
				for y = 1, PLATFORM.top - 1 - step do
					buf:put(x, y, flight_z, ORS_BLOCK)
				end
				parts.stair(buf, x, PLATFORM.top - step, flight_z, tread, 3)
			end
			buf:clear(PLATFORM.x2, PLATFORM.top + 1, flight_z,
				PLATFORM.x2, PLATFORM.top + 2, flight_z)
			for _, corner in ipairs({{PLATFORM.x1 + 1, PLATFORM.z1 + 1},
					{PLATFORM.x2 - 1, PLATFORM.z1 + 1},
					{PLATFORM.x1 + 1, PLATFORM.z2 - 1},
					{PLATFORM.x2 - 1, PLATFORM.z2 - 1}}) do
				parts.floor_torch(buf, orc, corner[1], PLATFORM.top + 1,
					corner[2])
			end
		end

		-- 6. THE MUSTER COURT: the two royal booths of the contract's `vendor`
		-- pair, the drill posts, the weapon racks, the wains, the standards and
		-- the court's own fires. This is where the two fixed vendor offsets of
		-- `grug_traders/vendors.lua` come to rest.
		local VENDORS = {
			{id = "vendor_race", kind = "race", x = 42, z = 10},
			{id = "vendor_general", kind = "general", x = 42, z = 17},
		}
		for _, booth in ipairs(VENDORS) do
			paved_prop("booth", booth.x - 1, booth.z - 1, booth.x + 3,
				booth.z + 3, function()
					dressing.stall(buf, orc, booth.x, booth.z, 0)
				end)
		end
		-- The muster ground itself is the band between the host's store
		-- (z 8..22) and the beast shed (z 27..35): the one stretch of the
		-- court wide enough to form a rank on, which is why the store and the
		-- shed stand where they do.
		for _, post in ipairs({{24, 24}, {28, 24}, {32, 24}, {36, 24},
				{40, 24}, {44, 24}}) do
			paved_prop("drill_post", post[1], post[2], post[1], post[2],
				function()
					return dressing.drill_post(buf, orc, post[1], post[2], 3)
				end)
		end
		for _, rack in ipairs({{24, 38, 28, 38}, {31, 38, 35, 38},
				{24, 41, 28, 41}}) do
			paved_prop("weapon_rack", rack[1], rack[2], rack[3], rack[4],
				function()
					dressing.fence_line(buf, orc, rack[1], rack[2], rack[3],
						rack[4])
				end)
		end
		for _, wain in ipairs({{40, 30, "z"}, {40, 34, "z"}}) do
			paved_prop("wain", wain[1], wain[2], wain[1] + 1, wain[2] + 2,
				function()
					return dressing.wagon(buf, orc, wain[1], wain[2], wain[3])
				end)
		end
		for _, mast in ipairs({{22, 7}, {45, 7}, {22, 42}, {45, 42},
				{38, 24}}) do
			paved_prop("standard", mast[1], mast[2], mast[1], mast[2],
				function()
					dressing.standard(buf, orc, mast[1], mast[2], 5)
				end)
		end
		for _, fire in ipairs({{37, 20}, {22, 17}}) do
			paved_prop("court_fire", fire[1], fire[2], fire[1], fire[2],
				function()
					buf:put(fire[1], 1, fire[2], orc.node("hearth"))
				end)
		end
		for _, stack in ipairs({{36, 12}, {36, 13}, {38, 41}, {39, 41},
				{41, 41}, {44, 26}, {44, 27}, {22, 12}}) do
			paved_prop("crates", stack[1], stack[2], stack[1], stack[2],
				function()
					dressing.crates(buf, orc, stack[1], stack[2], 2)
				end)
		end
		for _, seat in ipairs({{44, 36, 0, "z"}, {22, 28, 1, "z"}}) do
			local x2 = (seat[4] == "x") and seat[1] + 2 or seat[1]
			local z2 = (seat[4] == "z") and seat[2] + 2 or seat[2]
			paved_prop("court_bench", seat[1], seat[2], x2, z2, function()
				dressing.bench(buf, orc, seat[1], seat[2], seat[3], 3, seat[4])
			end)
		end
		-- The court's lamps are the one prop list here that is CANDIDATES and
		-- not positions. Every other prop above must land where it is asked
		-- for, because each one is a piece of the authored scene; a lamp is a
		-- lamp wherever it stands, and a court whose corners are taken by a
		-- gate tower's own footprint would otherwise refuse the whole
		-- composition over a light. What the composition does insist on is HOW
		-- MANY: fewer than five and the muster court is dark at night.
		local court_lamps = 0
		-- None of them within three nodes of a corner tower: a lamp post is
		-- two courses of acacia and a torch, and one at (44, 43) is what left
		-- the north-east corner of the precinct with no tower in the first
		-- version of this composition.
		for _, lamp in ipairs({{22, 6}, {44, 14}, {22, 40}, {44, 40},
				{37, 24}, {22, 20}, {44, 22}, {30, 43}}) do
			if layout.free_area(buf, lamp[1], lamp[2], lamp[1], lamp[2], 4) then
				dressing.path_light(buf, orc, lamp[1], lamp[2])
				court_lamps = court_lamps + 1
			end
		end
		if court_lamps < 5 then
			error("wp13 gor drazhak: only " .. court_lamps ..
				" of the muster court's lamps found room", 0)
		end

		-- 7. The plaza's kerb lamps and the street lighting. The great avenue's
		-- lamp line stops one node short of the crossing: a standard on the kerb
		-- at x = +-3 is on the verge of one avenue and in the CARRIAGEWAY of the
		-- other.
		for _, lamp in ipairs({{PLAZA.x1, PLAZA.z1}, {PLAZA.x2, PLAZA.z1},
				{PLAZA.x1, PLAZA.z2}, {PLAZA.x2, PLAZA.z2}}) do
			paved_prop("plaza_lamp", lamp[1], lamp[2], lamp[1], lamp[2],
				function()
					dressing.path_light(buf, orc, lamp[1], lamp[2])
				end)
		end
		layout.street_lamps(buf, orc, 0, -44, -12, 8, outdoors)
		layout.street_lamps(buf, orc, 0, 42, RADIUS - 2, 8, outdoors)
		for _, spot in ipairs({{-6, -6}, {6, -6}, {-6, 6}, {6, 6},
				{-25, -6}, {-25, 6}, {25, -6}, {25, 6},
				{-40, -6}, {-40, 6}, {40, -6}, {40, 6},
				{-25, 18}, {-25, 30}, {28, -16}, {-16, -6}, {16, -6},
				{-34, -8}, {34, 4}}) do
			if outdoors(spot[1], spot[2]) and
					layout.free(buf, spot[1], spot[2], 4) then
				paved_prop("street_lamp", spot[1], spot[2], spot[1], spot[2],
					function()
						dressing.path_light(buf, orc, spot[1], spot[2])
					end)
			end
		end

		-- 8. Benches at the crossing, and the standards flanking the platform.
		-- The seating of the approach and the forecourt. Like the court's
		-- lamps this list is CANDIDATES with a floor under the count, not
		-- positions: a bench is a bench wherever it stands on the walk, and
		-- the colonnades' own open bays are ground whose occupancy a roster
		-- cannot predict from the outside. Fewer than four and the two great
		-- avenues have nowhere to sit.
		local benches = 0
		for _, seat in ipairs({{-20, 4, 2, "x"}, {16, 4, 2, "x"},
				{-8, 4, 2, "x"}, {-5, 4, 2, "x"}, {-20, -4, 0, "x"},
				{16, -4, 0, "x"}, {-14, -6, 0, "x"}, {12, 6, 2, "x"}}) do
			if layout.free_area(buf, seat[1], seat[2], seat[1] + 2,
					seat[2], 4) then
				dressing.bench(buf, orc, seat[1], seat[2], seat[3], 3, "x")
				benches = benches + 1
			end
		end
		if benches < 4 then
			error("wp13 gor drazhak: only " .. benches ..
				" of the avenue benches found room", 0)
		end
		for _, mast in ipairs({{-4, -6}, {4, -6}}) do
			paved_prop("approach_standard", mast[1], mast[2], mast[1], mast[2],
				function()
					dressing.standard(buf, orc, mast[1], mast[2], 6)
				end)
		end

		-- 9. Acacias on the turf the quarters leave, which is what the mesa
		-- shelf looks like where the city has not paved it. THREE NODES CLEAR
		-- OF THE PRECINCT BANK, every one of them: a crown reaches three nodes
		-- from its stem, the bank is written after the trees and only asks
		-- whether the four courses above the ground are free, so a stem on the
		-- ring's own column lets the earthwork be built under it and hangs
		-- leaves on the stakes. That is the defect Dur Brannoc's KAT found in
		-- its pines and this composition inherits the fix rather than the bug.
		local trees = 0
		-- EVERY BLOCK STOPS AT 40, and that is the whole of the fix Dur
		-- Brannoc's KAT found in its pines: a crown reaches three nodes from
		-- its stem, the boundary bank is written AFTER the trees and only asks
		-- whether the courses above the ground are free, so a stem at 43 lets
		-- the earthwork be built under it and hangs leaves on the stockade --
		-- and a stem at 45 takes a corner tower's room and the composition
		-- finds three towers where it wants four.
		for _, block in ipairs({{-40, -40, -14, -32, 6, 5},
				{14, -40, 26, -34, 6, 5}, {-40, 0, -28, 8, 6, 5},
				{-20, -40, -8, -34, 6, 5}, {-40, -30, -36, -10, 6, 5},
				{30, 0, 40, 2, 6, 5}, {18, -34, 28, -20, 6, 5},
				{-10, -34, -4, -18, 6, 5}, {4, -40, 6, -36, 6, 5},
				{-36, 24, -28, 38, 6, 5}, {24, -18, 34, -8, 6, 5}}) do
			trees = trees + layout.plant_orchard(buf, orc, block[1], block[2],
				block[3], block[4], block[5], block[6], "acacia")
		end
		-- FIVE, and not the twelve pine stands Dur Brannoc's precinct carries.
		-- That is a measurement and not a shortfall: a flat-crowned acacia needs
		-- seven nodes of clear ground and ten of clear air, and after the four
		-- avenues, the muster court, the bazaar square, the plaza and eighteen
		-- plots there are six such places left inside a 96-node orc precinct.
		-- What fills the ground between the quarters here is not a wood, it is
		-- the shelf itself: the rock outcrops below and the dry scrub of
		-- section 11.
		if trees < 5 then
			error("wp13 gor drazhak: only " .. trees ..
				" acacias found open ground", 0)
		end

		-- 9b. THE OUTCROPS: the mesa's own stone breaking through the shelf,
		-- one course or two of it, capped with the ground it sits in. Nothing
		-- grows on one (every column below the cap is rock), so they read as
		-- the country the city was built on rather than as landscaping -- which
		-- is the one thing a dry capital can put on its open ground that a
		-- green one cannot. Candidates with a floor under the count, like the
		-- lamps and the benches.
		local outcrops = 0
		for _, rock in ipairs({{-38, -26, -36, -24, 2}, {28, -30, 30, -28, 2},
				{-18, -30, -16, -28, 1}, {-38, 32, -36, 34, 2},
				{8, -28, 10, -26, 1}, {-30, 3, -28, 5, 2},
				{33, -6, 35, -4, 1}, {-12, 43, -10, 45, 1},
				{12, 43, 14, 45, 2}, {-44, -8, -42, -6, 1},
				{42, -24, 44, -22, 2}, {-6, -30, -4, -28, 1},
				{20, 43, 22, 45, 1}, {-22, -16, -20, -14, 2}}) do
			if layout.free_area(buf, rock[1], rock[2], rock[3], rock[4],
						rock[5] + 2) then
				dressing.rock_terrace(buf, orc, rock[1], rock[2], rock[3],
					rock[4], rock[5])
				outcrops = outcrops + 1
			end
		end
		if outcrops < 4 then
			error("wp13 gor drazhak: only " .. outcrops ..
				" rock outcrops found open ground", 0)
		end

		-- 10. THE PRECINCT BANK AND STOCKADE, and the four corner towers: Gor
		-- Drazhak's core edge in place of Highcourt's hedge and Dur Brannoc's
		-- citadel parapet. It is the outer rampart's own section at a quarter
		-- of its height -- two courses of dug earth beaten flat on top, with a
		-- sharpened stake every other column -- so the precinct and the city
		-- wall are recognisably one piece of engineering.
		--
		-- THE TOWERS FIRST. The protected bank explicitly skips the five square
		-- boundary columns at each corner; each closed tower perimeter owns that
		-- detour and the first bank column beyond the skip joins straight into
		-- it. This is an authored corner substitution, not an occupied-cell stop.
		local towers = 0
		for _, corner in ipairs({{-47, -47}, {47, -47}, {-47, 47}, {47, 47}}) do
			local cx, cz = corner[1], corner[2]
			if layout.free_area(buf, cx - 2, cz - 2, cx + 2, cz + 2, 10) then
				for y = 1, 5 do
					buf:ring(cx - 2, cz - 2, cx + 2, cz + 2, y, y, ORS_BLOCK)
				end
				buf:fill(cx - 1, 1, cz - 1, cx + 1, 5, cz + 1, ORS_BLOCK)
				buf:put(cx, 6, cz, AVENUE)
				for z = cz - 2, cz + 2 do
					for x = cx - 2, cx + 2 do
						if x == cx - 2 or x == cx + 2 or z == cz - 2 or
								z == cz + 2 then
							buf:put(x, 6, z, TIMBER)
							if (x + z) % 2 == 0 then
								buf:put(x, 7, z, TIMBER)
								buf:put(x, 8, z, POINT, (x + z) % 4)
							end
						end
					end
				end
				towers = towers + 1
			end
		end
		if towers ~= 4 then
			error("wp13 gor drazhak: " .. towers ..
				" of the four corner towers found room", 0)
		end
		-- The protected bank is walked round the whole pad after the content. It
		-- wins every ordinary column; the shared mask omits the four authored
		-- gatehouse bands and the callback preserves the four corner towers.
		local bank, stakes = 0, 0
		precinct_ring.walk(function(x, z)
			precinct_ring.clear_wallmounted(buf, parts, x, z, 4)
			buf:put(x, 1, z, EARTH)
			buf:put(x, 2, z, BEATEN)
			if (x + z) % 2 == 0 then
				buf:put(x, 3, z, TIMBER)
				buf:put(x, 4, z, POINT, (x + z) % 4)
				stakes = stakes + 1
			end
			bank = bank + 1
		end, {skip = precinct_ring.is_corner})

		-- 11. Dry undergrowth on the ground between the quarters.
		dressing.undergrowth(buf, orc, -RADIUS, -RADIUS, RADIUS, RADIUS, 6)

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
		-- THE PLATFORM'S OWN GARRISON: two posts on the deck, looking down the
		-- approach, which is what a fighting platform is for.
		socket("platform_post_west", "guard_post", PLATFORM.x1 + 2,
			PLATFORM.top + 1, PLATFORM.z1 + 1, 2)
		socket("platform_post_east", "guard_post", PLATFORM.x2 - 3,
			PLATFORM.top + 1, PLATFORM.z1 + 1, 2)
		socket("platform_idle", "idle", PLATFORM.x1 + 4, PLATFORM.top + 1,
			PLATFORM.z2 - 1, 0, {tags = {"work"}})
		-- The muster court's own people: four work spots at the court's
		-- features and the fires and benches the rest of the quarter stands at.
		-- THE MUSTER GROUND'S OWN PAIR. A `spar` socket's feature is its
		-- partner (sockets contract section 8.2, "another `spar` socket or a
		-- training dummy"), so the two stand a node apart on the rank line and
		-- look at each other.
		socket("court_work_spar_a", "work", 30, 1, 24, 1, {activity = "spar"})
		socket("court_work_spar_b", "work", 31, 1, 24, 3, {activity = "spar"})
		socket("court_work_fire", "work", 37, 1, 19, 0, {activity = "brew"})
		socket("court_work_rack", "work", 26, 1, 39, 0, {activity = "sweep"})
		socket("court_idle_store", "idle", 36, 1, 20, 3, {tags = {"work"}})
		socket("court_idle_wain", "idle", 37, 1, 31, 1, {tags = {"work"}})
		socket("court_idle_fire", "idle", 23, 1, 17, 1, {tags = {"fire"}})
		socket("court_idle_bench", "idle", 43, 1, 37, 1, {tags = {"bench"}})
		socket("forecourt_idle_west", "idle", -9, 1, 3, 1, {tags = {"door"}})
		socket("forecourt_idle_east", "idle", 3, 1, 4, 3, {tags = {"door"}})
		socket("crossing_idle_west", "idle", -5, 1, -4, 0, {tags = {"bench"}})
		socket("crossing_idle_east", "idle", 5, 1, -4, 2, {tags = {"bench"}})
		-- SPARE SPOTS. `spawn = false` is the sockets contract's own word for
		-- them (playtest round 2, 2026-09-15): a real authored standing position
		-- that reaches every consumer and that NOBODY IS PLACED ON, so a
		-- villager's amble has somewhere to go that is not another villager's
		-- doorstep. No tag: a tag is what the spoken line and the facing rule
		-- read, and a spare has neither a line nor a door.
		socket("precinct_walk_west", "idle", -26, 1, 20, 0, {spawn = false})
		socket("precinct_walk_north", "idle", -19, 1, 30, 2, {spawn = false})
		socket("precinct_walk_south", "idle", -14, 1, -30, 0, {spawn = false})
		socket("precinct_walk_east", "idle", 33, 1, -24, 2, {spawn = false})
		socket("precinct_walk_court", "idle", 34, 1, 29, 0, {spawn = false})

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
		local light_names = {[orc.node("light_post")] = true,
			[orc.node("light_wall")] = true,
			[orc.node("light_indoor")] = true}
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
		-- `face` as a facedir, because a facedir is what rotates with a stamped
		-- part. This is the settlement boundary, so it is converted here, with
		-- the library's own table rather than with an engine call.
		for _, entry in ipairs(sockets) do
			local dx, dz = parts.facedir_step(entry.face)
			entry.dir = {x = dx, z = dz}
		end

		local destinations = {}
		for _, id in ipairs(DESTINATION_ORDER) do
			local spot = inside_by_id[id]
			if not spot then
				error("wp13 gor drazhak: destination " .. id .. " is missing", 0)
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
			error("wp13 gor drazhak: no door for " .. id, 0)
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
				muster_court = {min = {x = COURT.x1, y = 0, z = COURT.z1},
					max = {x = COURT.x2, y = 8, z = COURT.z2}},
				fighting_platform = {min = {x = PLATFORM.x1, y = 0,
						z = PLATFORM.z1},
					max = {x = PLATFORM.x2, y = PLATFORM.top + 3,
						z = PLATFORM.z2}},
				warlord_hall = box("warlord_hall", 2, 2),
				warlord_hall_door = door_of("warlord_hall"),
				bazaar_square = box("bazaar_square", 1, 1),
				skull_hall = box("skull_hall", 2, 4),
				skull_hall_door = door_of("skull_hall"),
				destinations = destinations,
				doors = doorways,
				rooms = rooms,
				lights = lights,
				sockets = sockets,
				bank_columns = bank,
				bank_stakes = stakes,
				corner_towers = towers,
				deck_rings = deck_rings,
				acacias = trees,
				outcrops = outcrops,
				nave_floor = #nave,
				platform_cells = platform_cells,
			},
		}
	end

	-- The overlay seam, in one place: the run list in authored order (avenues
	-- first, then the ring street, then the district lanes, then the rampart)
	-- and the one function that turns a run into cells. The successor's
	-- first-run-wins arbitration reads this order, so the avenue runs through
	-- the gate and the rampart yields the cells of the road it lets past.
	function M.overlay_runs()
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
		for _, list in ipairs({M.avenues, M.ring, M.lanes}) do
			for index = 1, #list do streets[#streets + 1] = list[index] end
		end
		-- AND THE GATE PASSAGES, for the same reason and out of the same
		-- rectangles: a street runs THROUGH the structure that is not a street,
		-- and inside that passage the structure owns the lanes either side of
		-- the carriageway. `wp13/avenue.lua` writes no plank walk, no rail and
		-- no pillar there, which is the sentence the per-capital kerb parapets
		-- this rule replaced each carried in their own words.
		local runs = street_plan.attach(streets, nil,
			{{runs = M.wall, half = palisade.HALF}})
		for index = 1, #M.wall do runs[#runs + 1] = M.wall[index] end
		return runs
	end

	-- Every node name either overlay may write, byte-sorted and without
	-- duplicates: the union of the road's vocabulary and the rampart's, which
	-- is what the settlement's shared content channel is closed over and what
	-- the overlay's specification identity is written from.
	function M.overlay_names(avenue, palette)
		local seen, list = {}, {}
		for _, source in ipairs({avenue.palette_names(palette),
				palisade.palette_names(palette)}) do
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

	-- THE CAUSEWAY RAIL.
	--
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

	-- One run, dispatched by its own id. A rampart run carries authored
	-- geometry the seam's overlay spec has no field for -- which side is the
	-- field, where the towers and the gate stand -- so it is looked up here,
	-- from the same table for every piece, which is what keeps a piece of a run
	-- exactly that stretch of the whole run.
	function M.overlay_run(avenue, palette, spec, surface)
		local plan = M.wall_plan[spec.id]
		if plan then return palisade.run(palette, spec, surface, plan) end
		return avenue.run(palette, spec, surface)
	end

	return M
end

return loader
