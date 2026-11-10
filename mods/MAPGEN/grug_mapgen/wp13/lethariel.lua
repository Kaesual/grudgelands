-- Lethariel: the elf capital, and the only one of the six that stands on a
-- lake. Open until Round 23; since then its city edge is a light stone
-- curtain (`city_edge.lua`) and its civic core a light wall of the same pale
-- stone.
--
-- This file is the CORE composition of docs/research/wp13-capitals-pois-
-- contract.md section 2.1 -- the civic core (radius 56 since Round 70,
-- `precinct_ring.lua` owns the size), anchor-relative exactly like a start,
-- inside `BOUNDS.capital_core`.
--
-- The contract's section 2.4 elf row is "silverwood and marble, tall narrow
-- halls, colonnades, lantern-lit walks, groves between plots, no curtain
-- wall", and its section 4 makes Lethariel one of the two capitals with an
-- open edge (the Round 23 walls replaced it). The Silverleaf palette is the city, marble is the signature, and
-- the castle kit appears only where it reads elven: pillars and paving.
--
-- THE MERE, and why this core is not a square.
-- -------------------------------------------
-- WP40 fits and flattens the civic core at the anchor's own height -- and then
-- lays the crown lake into it: the authored lake `lethariel_crown_lake` of
-- `wp40/water_authored.lua` (Round 22 Phase 5, plan D34), whose surface stands
-- two nodes below the core's ground course on every seed. Inside the pad it is
-- exactly the `MERE` wedge below, whose tip is at (0, 36) since Round 70 moved
-- the chain 14 nodes north, and which widens northward to the pad's north
-- edge; outside the core its shore is warped and its bed carved.
--
-- A composition that laid its pad across that wedge would lay a slab of turf
-- over open water. So this composition DOES NOT WRITE THERE. The wedge is committed as `MERE` below
-- with a one-node margin, everything the core lays is masked against it, and
-- what the player gets is the thing the ground already was: a civic terrace
-- above a mere, with a marble quay along its edge.
--
-- The avenues outside the core are the capital planner's streets (road-module
-- roads, Round 22). No street crosses the lake: `core_landing` finds nothing on
-- the pad's north edge, so the planner starts the north avenue on the shore
-- beyond the water.
--
--   * `M.core()` returns the core composition in the exact shape of a start
--     composition (schema, canonical cells, bounds, sorted palette, landmarks)
--     plus `landmarks.sockets`, the NPC seam of
--     docs/research/wp13-npc-sockets-contract.md.
--   * the district plots, the streets and the city edge are the capital
--     planner's per-world layout (Round 22, `wp40/capital_planner.lua`).
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local layout = dofile(directory .. "/layout.lua")(directory)
	local precinct_ring = dofile(directory .. "/precinct_ring.lua")
	local templates = dofile(directory .. "/templates.lua")(directory)
	local gate_watch = dofile(directory .. "/gate_watch.lua")(directory)
	local CAPITAL = templates.capital("lethariel")

	local M = {}

	local RADIUS = precinct_ring.PAD
	local SCHEMA = "grug_wp13_lethariel_core_v1"

	-- The city's own patrol loop.
	local WATCH = "lethariel_watch"

	-- THE MERE, as the crown lake lies inside the core pad: for every z from
	-- the tip northward, the first and last x of the water. It was measured
	-- from the real water function by `tools/r70_cap/lake_table.py`, with the
	-- calm square at the pad's half and the chain 14 north (Round 70).
	--
	-- It is committed as DATA and not derived, because a blueprint is a fixed
	-- cell list built once at load with no world to ask. The day the lake's
	-- chain moves, this table is re-taken with it.
	local MERE_FIRST = 36
	local MERE = {
		[36] = {0, 0}, [37] = {-8, 8}, [38] = {-12, 12}, [39] = {-14, 14},
		[40] = {-16, 16}, [41] = {-18, 18}, [42] = {-20, 20},
		[43] = {-21, 21}, [44] = {-23, 23}, [45] = {-24, 24},
		[46] = {-25, 25}, [47] = {-26, 26}, [48] = {-27, 27},
		[49] = {-28, 28}, [50] = {-29, 29}, [51] = {-30, 30},
		[52] = {-30, 32}, [53] = {-31, 34}, [54] = {-32, 35},
		[55] = {-32, 37}, [56] = {-33, 39}, [57] = {-33, 40},
	}
	-- One node of natural shore between anything this composition lays and the
	-- water itself, so a rounding difference in a future WP40 revision costs a
	-- node of turf rather than a slab over the lake.
	local SHORE_MARGIN = 1

	-- Is this column ground the core may build on?
	local function dry(x, z)
		local span = MERE[z]
		if span == nil then return true end
		return x < span[1] - SHORE_MARGIN or x > span[2] + SHORE_MARGIN
	end

	-- The axis ends at the lake's tip. Nothing crosses the mere, and the pad
	-- lays nothing inside the avenue's seven-wide band from that row northward,
	-- so the quay stays two arms and `core_landing` finds no landing on the
	-- north edge: the planner starts the north avenue on the shore.
	local AXIS_END = MERE_FIRST
	local AXIS_HALF = 3

	-- Ground the CORE itself may lay: dry, and not the axis band's.
	local function pad(x, z)
		if z >= AXIS_END and math.abs(x) <= AXIS_HALF then
			return false
		end
		return dry(x, z)
	end

	-- Is the whole rectangle dry? Every plot and every prop asks this before
	-- it is written, so a piece of the city cannot end up over the water by
	-- being moved two nodes.
	local function dry_area(x1, z1, x2, z2)
		for z = math.max(z1, MERE_FIRST), z2 do
			for x = x1, x2 do
				if not dry(x, z) then return false end
			end
		end
		return true
	end

	-- The two palettes are the roster's (`building_templates/layouts/
	-- lethariel.roster`): `elf` is the city, `pale` the civic quarter -- the
	-- same palette under the pale roof and the pale masonry.

	-- The travel plaza (WP17): kerbed, lit from its own kerb and empty of
	-- everything above its paving but the waystone and its mailbox.
	local PLAZA = {x1 = 18, z1 = -20, x2 = 32, z2 = -8}

	-- The QUAY: the marble promenade along the mere's edge. It is authored as
	-- a band that follows the committed shore rather than as a rectangle,
	-- because the shore is a diagonal. QUAY_HEAD is where it meets the north
	-- promenade, between the colonnades' feet.
	local QUAY_WIDTH = 3
	local QUAY_HEAD = {x1 = -4, z1 = MERE_FIRST - 4, x2 = 4, z2 = MERE_FIRST - 1}

	-- The castle (Round 70, form A): 35 x 45 turned once, its great door on the
	-- east looking across the court to the south avenue. COURT is that court,
	-- paved to the castle's foot; the approach runs on the door's row.
	local CASTLE = {x = -52, z = -51, w = 35, d = 45}
	local COURT = {x1 = CASTLE.x + CASTLE.w, z1 = -42, x2 = -4, z2 = -16}
	local APPROACH = {z1 = -32, z2 = -26}

	local STREETS = {
		-- The south avenue, from the south gate through the crossing.
		{-2, -RADIUS, 2, 4, "avenue"},
		-- The north promenade, from the crossing between the colonnades to the
		-- quay's head. It ends on the lake's tip: nothing crosses the mere.
		{-2, 5, 2, QUAY_HEAD.z1 + 1, "avenue"},
		-- The east-west avenue, gate to gate through the same crossing.
		{-RADIUS, -2, RADIUS, 2, "avenue"},
		-- The castle's approach, from the south avenue to the great door, and
		-- the court round it.
		{COURT.x1, COURT.z1, COURT.x2, COURT.z2, "avenue"},
		{COURT.x2, APPROACH.z1, -3, APPROACH.z2, "avenue"},
		-- The flank lane past the court, from the west avenue south.
		{-15, -15, -13, -3, "lane"},
		{-15, -45, -9, -43, "lane"},
		-- The gate forecourts: a gate chamber's door is in its city face and
		-- its doorstep is one node beyond the part's own footprint, and the
		-- ground watch walks here (`gate_watch.lua`). The west one stops at the
		-- castle's north wall.
		{-8, -(RADIUS - 7), 8, -(RADIUS - 12), "lane"},
		{RADIUS - 12, -8, RADIUS - 7, 8, "lane"},
		{-(RADIUS - 7), -6, -(RADIUS - 12), 8, "lane"},
		-- The market walk, the booth row on it and the plaza approach.
		{4, -25, 30, -23, "lane"},
		{2, -25, 4, -14, "lane"},
		{18, -22, 20, -20, "lane"},
		-- The west quarter's walks: the star hall's doorstep and the fountain
		-- court.
		{-40, 5, -36, 9, "lane"},
		{-35, 7, -31, 9, "lane"},
		{-30, 12, -21, 14, "lane"},
		-- The east quarter's walk to the sacred grove, and north up the old
		-- shrine ground to the mere shrine and on to the quay.
		{6, 8, 24, 10, "lane"},
		{26, 5, 28, 8, "lane"},
		{17, 11, 19, 25, "lane"},
		{19, 24, 27, 25, "lane"},
		{25, 26, 27, 44, "lane"},
		-- The doorsteps of the outer houses.
		{-46, 27, -38, 29, "lane"},
		{40, -40, 42, -38, "lane"},
	}

	-- The plot roster. `template` is the building template (Round 56,
	-- docs/technical/building-template-format.md), `x`/`z` the pad anchor of
	-- the rotated footprint, `turns` the rotation, `palette` and `roof` the
	-- roster palettes it is built and roofed with. The hall of stars'
	-- template carries its elder's doorstep.
	--
	-- `watch` marks a core gatehouse whose guards gate_watch.lua sets (Round
	-- 58): the ground guards' rectangle and the tower guard's post.
	--
	-- `drop` and `recast` are the socket policy of the sockets contract: a
	-- part cannot know how many of a thing a CAPITAL may have -- one throne,
	-- one travel pad for WP17, one vendor per kind.
	local PLOTS = {
		-- 1. THE HALL OF THE SILVER BOUGHS, the king's castle (Round 70, form
		-- A). It stands WEST of the south avenue with its great door on the
		-- east, and not north of the crossing where the other castles stand,
		-- because north of the crossing at Lethariel is the mere: the box
		-- would need the lake 24 nodes north, and the whole public quarter
		-- moved with it. So the castle turns once and looks across its court.
		{id = "kings_hall", template = "lethariel_kings_hall",
			x = CASTLE.x, z = CASTLE.z, turns = 3, palette = "pale", roof = "pale",
			drop = {waypoint = true}},

		-- 2. The three inner gates: the civic precinct's own, and the fourth
		-- side is the quay, because the lake closes the north.
		{id = "gate_south", template = "lethariel_gate_south", watch = true,
			x = -6, z = -RADIUS, turns = 0, palette = "pale", roof = "pale"},
		{id = "gate_west", template = "lethariel_gate_south", watch = true,
			x = -RADIUS, z = -6, turns = 1, palette = "pale", roof = "pale"},
		{id = "gate_east", template = "lethariel_gate_south", watch = true,
			x = RADIUS - 6, z = -6, turns = 3, palette = "pale", roof = "pale"},

		-- 3. The market square, east of the approach in the south quarter.
		{id = "market", template = "lethariel_market",
			x = 14, z = -46, turns = 0, palette = "elf",
			drop = {waypoint = true},
			-- A booth without a trader is a flair NPC's work spot, and its id
			-- has to say booth: `market_vendor_1` with the role `idle` is a
			-- socket that argues with itself.
			recast = {vendor = {role = "idle", tags = {"work"},
				from = "_vendor_", to = "_booth_"}}},

		-- 4. The two colonnades flanking the north promenade -- the contract's
		-- own word for this race, and the piece that makes the walk to the
		-- quay a processional rather than a road. They moved here from the
		-- south avenue in Round 70, when the castle's court took that land.
		{id = "colonnade_west", template = "lethariel_colonnade_west",
			x = -9, z = 20, turns = 1, palette = "pale"},
		{id = "colonnade_east", template = "lethariel_colonnade_east",
			x = 6, z = 20, turns = 3, palette = "pale"},

		-- 5. The civic furniture: the king's statue north-east of the
		-- crossing and the fountain court in the west quarter.
		{id = "statue", template = "highcourt_statue",
			x = 6, z = 4, turns = 0, palette = "pale"},
		{id = "fountain_court", template = "highcourt_well_court",
			x = -44, z = 8, turns = 0, palette = "pale"},

		-- 6. THE HALL OF STARS: the capital library's temple, in the west
		-- quarter, and where this capital's core quest shell stands.
		-- The temple publishes its own quest shell, and a capital has exactly
		-- one. It stands on the doorstep, one node outside the door on the
		-- temple walk, tagged `door` (the user's playtest-round-2 ruling): a
		-- point of the temple's template since Round 56, this row's socket
		-- override before.
		{id = "star_hall", template = "lethariel_star_hall",
			x = -31, z = 6, turns = 0, palette = "pale", roof = "pale"},

		-- 7. THE SACRED GROVE, the east quarter and this capital's signature:
		-- standing silverwood inside the civic core, which is what the WP40
		-- profile `terraced_grove` means when a city is built in it.
		{id = "sacred_grove", template = "lethariel_sacred_grove",
			x = 25, z = 8, turns = 0, palette = "elf"},
		-- The shrine at the head of the grove walk, near the shore it follows.
		{id = "mere_shrine", template = "lethariel_mere_shrine",
			x = 16, z = 26, turns = 0, palette = "pale"},

		-- 8. Two BOUGH HOUSES: the tree platforms of this race, one either
		-- side of the city.
		{id = "bough_west", template = "lethariel_bough_west",
			x = -16, z = 8, turns = 0, palette = "elf"},
		{id = "bough_east", template = "lethariel_bough_east",
			x = 34, z = -22, turns = 0, palette = "elf"},

		-- 9. The citizens' quarter: four houses on the outer ground. The
		-- cottages keep the generator's own door side (`z-`) and are TURNED
		-- to face their ground instead: the `home` kit furnishes the cell
		-- behind every other wall and only the z- doorway is authored clear
		-- of it.
		{id = "quay_house", template = "dur_brannoc_market_house",
			x = -43, z = 25, turns = 1, palette = "elf"},
		{id = "south_house", template = "dur_brannoc_south_house",
			x = 38, z = -46, turns = 1, palette = "elf"},
		{id = "plaza_house", template = "dur_brannoc_lane_house",
			x = 38, z = -34, turns = 1, palette = "elf"},
		{id = "shore_house", template = "dur_brannoc_plaza_house",
			x = -46, z = 37, turns = 3, palette = "elf"},

	}

	-- Destination order is part of the consumer contract and never changes.
	local DESTINATION_ORDER = {"kings_hall", "gate_south", "gate_west",
		"gate_east", "star_hall", "bough_west", "bough_east", "quay_house",
		"south_house", "plaza_house", "shore_house"}

	-- The corner waypoints of the city loop. They stand ON THE GREAT STREETS
	-- and not on the turf between the quarters, which is where the first
	-- version put them: this core is crowded -- a 35 x 45 castle, a
	-- twenty-one-node market and a seventeen-node sacred grove -- and three of
	-- the four landed inside a building. A paved cell is one the composition
	-- itself cleared, so a waypoint on one is a waypoint an NPC can stand on.
	-- The order keeps every leg clear of the castle (Round 70): the straight
	-- line from `watch_west` to `watch_south_west` runs through it, so the
	-- watch crosses to the east between the two and takes the court from there.
	local CORNERS = {
		{id = "watch_quay", x = 2, z = 30, face = 2, order = 2},
		{id = "watch_west", x = -36, z = 2, face = 2, order = 3},
		{id = "watch_south_east", x = 36, z = -2, face = 0, order = 4},
		{id = "watch_south_west", x = -11, z = -44, face = 0, order = 5},
	}

	-- The city around the core -- its outline, streets, walls or planted
	-- edge, gates and the placed district plots -- is laid out per world by
	-- the capital planner (`wp40/capital_planner.lua`, `wp13/city_edge.lua`,
	-- Round 22); this file is the civic core.

	function M.core()
		local elf_palette = CAPITAL.palettes.elf
		local pale = CAPITAL.palettes.pale
		local buf = parts.buffer()
		local doorways, rooms, sockets = {}, {}, {}
		local placed, inside_by_id, plot_order = {}, {}, {}
		local claimed, stamped = {}, {}

		local AVENUE = elf_palette.maybe("castle_paving") or
			elf_palette.node("plaza")
		local LANE = elf_palette.node("path")
		local KERB = elf_palette.node("plaza_edge")
		local MARBLE = elf_palette.maybe("signature") or
			elf_palette.node("wall_accent")
		local MARBLE_SLAB = elf_palette.maybe("signature_slab") or
			elf_palette.node("roof_slab")

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
			GROUND[elf_palette.node(role)] = true
		end

		-- Every prop the composition asks for MUST land; a prop quietly
		-- skipped is a hole in the authored scene no fixture can see.
		local function refuse(name, x, z, reason)
			error("wp13 lethariel: prop " .. name .. " at " .. x .. "," ..
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
			if not dry_area(x1, z1, x2, z2) then
				refuse(name, x1, z1, "the mere is there")
			end
			if not layout.free_area(buf, x1, z1, x2, z2, 4) then
				refuse(name, x1, z1, "the space is taken")
			end
			place(name, x1, z1, build)
		end

		local function pave(name, x1, z1, x2, z2, height)
			for z = z1, z2 do
				for x = x1, x2 do
					if dry(x, z) then
						buf:put(x, 0, z, name)
						buf:clear(x, 1, z, x, height or 4, z)
					end
				end
			end
		end

		-- 1. The glade floor, MASKED AGAINST THE MERE. This is
		-- `layout.glade`'s texture -- silver litter with trodden patches where
		-- the city walks -- written column by column instead of as one fill,
		-- because a fill would lay turf over the lake.
		local laid, water, axis = 0, 0, 0
		for z = -RADIUS, RADIUS do
			for x = -RADIUS, RADIUS do
				if pad(x, z) then
					buf:put(x, -1, z, elf_palette.node("subsoil"))
					buf:put(x, 0, z, elf_palette.node("ground"))
					laid = laid + 1
				elseif dry(x, z) then
					axis = axis + 1
				else
					water = water + 1
				end
			end
		end
		for z = -RADIUS + 3, RADIUS - 3, 4 do
			for x = -RADIUS + 3, RADIUS - 3, 7 do
				local hash = (x * 13 + z * 29) % 17
				local role
				if hash < 4 then role = "ground_patch"
				elseif hash == 11 or hash == 14 then role = "ground_bare" end
				if role then
					for oz = z - 1, z + 1 do
						for ox = x - 2, x + 2 do
							if ox >= -RADIUS and ox <= RADIUS and
									oz >= -RADIUS and oz <= RADIUS and
									pad(ox, oz) then
								buf:put(ox, 0, oz, elf_palette.node(role))
							end
						end
					end
				end
			end
		end

		-- 2. The streets and the kerbs of the great avenues.
		for _, street in ipairs(STREETS) do
			local name = (street[5] == "avenue") and AVENUE or LANE
			pave(name, street[1], street[2], street[3], street[4], 5)
		end
		for _, kerb in ipairs({{-3, -(RADIUS - 13), -3, APPROACH.z1 - 1},
				{-3, APPROACH.z2 + 1, -3, QUAY_HEAD.z1 - 1},
				{3, -(RADIUS - 13), 3, QUAY_HEAD.z1 - 1},
				{-(RADIUS - 13), -3, RADIUS - 13, -3},
				{-(RADIUS - 13), 3, RADIUS - 13, 3}}) do
			for z = kerb[2], kerb[4] do
				for x = kerb[1], kerb[3] do
					if dry(x, z) then buf:put(x, 0, z, KERB) end
				end
			end
		end

		-- The court: a kerb ring, the approach through it and a marble line
		-- from the south avenue to the great door.
		dressing.inlay(buf, elf_palette, COURT.x1, COURT.z1, COURT.x2, COURT.z2)
		pave(AVENUE, COURT.x1, APPROACH.z1, COURT.x2, APPROACH.z2, 5)
		local door_row = math.floor((APPROACH.z1 + APPROACH.z2) / 2)
		for x = COURT.x1, -3 do buf:put(x, 0, door_row, MARBLE) end

		-- 3. THE QUAY: a marble promenade following the mere's own edge, one
		-- node of natural shore outside it, three wide landward of that, with
		-- a low kerb on the water side so a citizen walking it does not walk
		-- off it. It is written from the committed shore table, so it is the
		-- same diagonal the lake is: a column is on the quay when the shore
		-- lies within QUAY_WIDTH of it along x or north along z.
		local function quay_step(x, z)
			for step = 1, QUAY_WIDTH do
				if not dry(x - step, z) or not dry(x + step, z) or
						not dry(x, z + step) then
					return step
				end
			end
			return nil
		end
		local quay = 0
		for z = MERE_FIRST - QUAY_WIDTH - 1, RADIUS - 2 do
			for x = -RADIUS + 2, RADIUS - 2 do
				local step = pad(x, z) and quay_step(x, z)
				if step then
					buf:put(x, 0, z, (step == 1) and KERB or AVENUE)
					buf:clear(x, 1, z, x, 4, z)
					quay = quay + 1
				end
			end
		end
		-- The quay's own head on the axis, where the promenade meets it.
		for z = QUAY_HEAD.z1, QUAY_HEAD.z2 do
			for x = QUAY_HEAD.x1, QUAY_HEAD.x2 do
				buf:put(x, 0, z, AVENUE)
				buf:clear(x, 1, z, x, 5, z)
				quay = quay + 1
			end
		end

		-- 4. The travel plaza: paving, two kerb rings and only the waystone and
		-- its mailbox inside it.
		pave(AVENUE, PLAZA.x1, PLAZA.z1, PLAZA.x2, PLAZA.z2, 6)
		dressing.inlay(buf, elf_palette, PLAZA.x1, PLAZA.z1, PLAZA.x2, PLAZA.z2)
		dressing.inlay(buf, elf_palette, PLAZA.x1 + 3, PLAZA.z1 + 3,
			PLAZA.x2 - 3, PLAZA.z2 - 3)
		local pad_x = math.floor((PLAZA.x1 + PLAZA.x2) / 2)
		local pad_z = math.floor((PLAZA.z1 + PLAZA.z2) / 2)
		for step = -5, 5 do
			buf:put(pad_x + step, 0, pad_z, MARBLE)
			buf:put(pad_x, 0, pad_z + step, MARBLE)
		end
		for step = 0, 5 do
			for _, corner in ipairs({{step, 5 - step}, {-step, 5 - step},
					{step, step - 5}, {-step, step - 5}}) do
				buf:put(pad_x + corner[1], 0, pad_z + corner[2], MARBLE)
			end
		end

		-- The waystone (Round 29, WP17) stands at the pad's centre, in the
		-- travel waypoint socket's cell; grug_home owns what it does.
		dressing.waystone(buf, pad_x, pad_z)

		-- 5. The plots.
		for _, plot in ipairs(PLOTS) do
			local part = CAPITAL.part(plot.template, plot.id, plot.palette,
				plot.roof)
			-- Two plots may not share a cell. `parts.stamp` writes; it does
			-- not ask, so a plot laid over another cuts a silent hole in the
			-- first and the pad still builds. Overwriting the STREETS and the
			-- ground under a plot is intended; overwriting another plot never
			-- is. And no plot may stand over the MERE.
			local source, count = part.buffer:cells()
			local min_x, max_x, min_z, max_z
			for index = 1, count do
				local cell = source[index]
				local rx, rz = parts.rotate_footprint(cell.x, cell.z,
					part.w, part.d, plot.turns)
				local x, z = plot.x + rx, plot.z + rz
				if min_x == nil or x < min_x then min_x = x end
				if max_x == nil or x > max_x then max_x = x end
				if min_z == nil or z < min_z then min_z = z end
				if max_z == nil or z > max_z then max_z = z end
				local key = x .. ":" .. cell.y .. ":" .. z
				local owner = claimed[key]
				if owner ~= nil then
					error("wp13 lethariel: the plot " .. plot.id ..
						" writes " .. cell.name .. " into " .. owner ..
						" at " .. key, 0)
				end
				claimed[key] = plot.id
			end
			if not dry_area(min_x, min_z, max_x, max_z) then
				error("wp13 lethariel: the plot " .. plot.id ..
					" stands over the mere (" .. min_x .. "," .. min_z ..
					" to " .. max_x .. "," .. max_z .. ")", 0)
			end
			if min_x < -RADIUS or max_x > RADIUS or min_z < -RADIUS or
					max_z > RADIUS then
				error("wp13 lethariel: the plot " .. plot.id ..
					" leaves the pad (" .. min_x .. "," .. min_z .. " to " ..
					max_x .. "," .. max_z .. ")", 0)
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
			-- The building's own sockets; a socket point without a role is the
			-- position of one of the composition's own sockets.
			templates.collect_sockets(stamped, points, plot.id)
			local first = #sockets + 1
			for _, entry in ipairs(points.sockets or {}) do
				local drop = entry.role == nil or (plot.drop and plot.drop[entry.role])
				if not drop then
					local recast = plot.recast and plot.recast[entry.role]
					local out = {id = entry.id, role = entry.role,
						x = entry.x, y = entry.y, z = entry.z,
						face = entry.face,
						group = entry.group,
						order = entry.order, kind = entry.kind,
						activity = entry.activity,
						-- `spawn` travels with the socket: a generator that
						-- publishes a spare must not lose it here.
						spawn = entry.spawn,
						tags = entry.tags}
					if recast then
						out.role = recast.role
						out.tags = recast.tags
						out.kind, out.group, out.order = nil, nil, nil
						out.activity = nil
						if recast.from then
							out.id = out.id:gsub(recast.from, recast.to, 1)
						end
					end
					sockets[#sockets + 1] = out
				end
			end
			-- A core gatehouse's watch (Round 58, gate_watch.lua): the ground
			-- guards' rectangle on the city side and the tower guard's post.
			if plot.watch then
				gate_watch.apply(sockets, first, plot, part.w, part.d, "lethariel", buf)
			end
		end

		templates.all_used(stamped, "lethariel")

		-- 6. The two royal booths of the contract's `vendor` pair, on the
		-- market walk. This is where the two fixed vendor offsets of
		-- `grug_traders/vendors.lua` come to rest.
		local VENDORS = {
			{id = "vendor_race", kind = "race", x = 16, z = -24},
			{id = "vendor_general", kind = "general", x = 23, z = -24},
		}
		for _, booth in ipairs(VENDORS) do
			paved_prop("booth", booth.x - 1, booth.z - 1, booth.x + 3,
				booth.z + 3, function()
					dressing.stall(buf, elf_palette, booth.x, booth.z, 0)
				end)
		end

		-- 7. The lantern walks. The contract's elf row asks for them by name,
		-- and `dressing.lantern_pillar` is the piece that uses the palette's
		-- own glowing block: a masonry plinth, four posts, a band of glazing
		-- and the light behind it.
		local lanterns = 0
		for _, spot in ipairs({{-6, -6}, {6, -6}, {-6, 6},
				{-6, -12}, {6, -12}, {6, -36}, {-11, -6}, {14, -6}, {-14, 6},
				{18, 6}, {22, 6}, {-24, -5}, {24, -6}, {-36, -5}, {36, -6},
				{-36, 6}, {36, 6}, {-6, 16}, {6, 16}, {16, -16},
				-- The court: two pairs framing the approach.
				{-7, -34}, {-7, -24}, {-15, -34}, {-15, -24},
				-- Outside the colonnades, and the gates' ground.
				{-12, 22}, {-12, 32}, {13, 22}, {13, 32},
				{-43, 6}, {43, -6}, {43, 6}, {-11, -48}, {11, -47}}) do
			if dry_area(spot[1] - 1, spot[2] - 1, spot[1] + 1, spot[2] + 1) and
					layout.free_area(buf, spot[1] - 1, spot[2] - 1,
						spot[1] + 1, spot[2] + 1, 5) then
				dressing.lantern_pillar(buf, elf_palette, spot[1], spot[2])
				lanterns = lanterns + 1
			end
		end
		-- The quay's own lantern line, on the turf behind its landward edge.
		-- The quay is a walk, and wider than QUAY_WIDTH where the shore runs
		-- diagonally, so each pillar steps inland until it stands off the
		-- paving.
		local function on_turf(x1, z1, x2, z2)
			for z = z1, z2 do
				for x = x1, x2 do
					local ground = buf:at(x, 0, z)
					if ground == nil or not GROUND[ground.name] then return false end
				end
			end
			return true
		end
		for z = MERE_FIRST + 6, RADIUS - 2, 6 do
			local span = MERE[z]
			for _, side in ipairs({-1, 1}) do
				for reach = SHORE_MARGIN + QUAY_WIDTH + 2, SHORE_MARGIN + QUAY_WIDTH + 9 do
					local edge = (side < 0) and (span[1] - reach) or (span[2] + reach)
					if math.abs(edge) <= RADIUS - 3 and
							on_turf(edge - 1, z - 1, edge + 1, z + 1) and
							layout.free_area(buf, edge - 1, z - 1, edge + 1,
								z + 1, 5) then
						dressing.lantern_pillar(buf, elf_palette, edge, z)
						lanterns = lanterns + 1
						break
					end
				end
			end
		end
		if lanterns < 16 then
			error("wp13 lethariel: only " .. lanterns ..
				" lantern pillars found room", 0)
		end

		-- 8. Benches at the crossing, on the quay and on the grove walk.
		local BENCHES = {
			{-6, -4, 0, "x"}, {4, -4, 0, "x"}, {-6, 4, 2, "x"},
			{4, 4, 2, "x"}, {8, 12, 0, "x"}, {-14, 15, 2, "x"},
			{-10, -12, 1, "z"}, {10, -12, 3, "z"},
			{-25, 40, 0, "x"}, {23, 40, 0, "x"},
		}
		for _, seat in ipairs(BENCHES) do
			local x2 = (seat[4] == "x") and seat[1] + 2 or seat[1]
			local z2 = (seat[4] == "z") and seat[2] + 2 or seat[2]
			paved_prop("bench", seat[1], seat[2], x2, z2, function()
				dressing.bench(buf, elf_palette, seat[1], seat[2], seat[3], 3,
					seat[4])
			end)
		end
		for _, bed in ipairs({{-12, -3, -10, -1}, {12, 1, 14, 3},
				{-13, -40, -9, -37}, {-13, -21, -9, -18}}) do
			paved_prop("planter", bed[1], bed[2], bed[3], bed[4], function()
				dressing.planter(buf, elf_palette, bed[1], bed[2], bed[3],
					bed[4])
			end)
		end

		-- 8b. THE SHORE WORKS, east of the north promenade (they stayed when
		-- Round 70 moved the shore north): the fish counter the mere feeds,
		-- the wood the city burns,
		-- the herb beds and a standing stone half carved. Each of them is the
		-- FEATURE one of this core's work sockets names (sockets contract
		-- section 8.1), and each is authored here rather than left to a piece
		-- of scatter, so the socket and the thing it faces cannot drift apart.
		paved_prop("shore_counter", 8, 14, 11, 14, function()
			dressing.counter(buf, elf_palette, 8, 14, 4, "x")
		end)
		paved_prop("shore_pile", 13, 14, 15, 14, function()
			dressing.wood_pile(buf, elf_palette, 13, 14, 3, "x")
		end)
		paved_prop("shore_beds", 8, 17, 11, 18, function()
			dressing.planter(buf, elf_palette, 8, 17, 11, 18)
			-- The kerb broken at the one cell the gardener reaches into. A
			-- raised bed is masonry round soil and the sockets contract's
			-- feature search stops at the first solid node on the socket's own
			-- course, so a gardener outside a bed otherwise looks at stone.
			dressing.plant(buf, elf_palette, 9, 17)
		end)
		paved_prop("carver_stone", 13, 17, 13, 17, function()
			buf:put(13, 1, 17, MARBLE)
			buf:put(13, 2, 17, MARBLE_SLAB)
		end)

		-- 9. The silverwood standards on the turf the quarters leave. A
		-- terraced grove with a city in it keeps its trees, and this is where
		-- the contract's "groves between plots" lands inside the core.
		local standards = layout.plant_grove(buf, elf_palette, RADIUS, 7, {
			{9, -44, 11}, {10, -37, 11},
			{32, -24, 11}, {13, -12, 11}, {34, -10, 11}, {41, -10, 11},
			{20, -6, 11}, {-10, 5, 11}, {30, 5, 11}, {44, 9, 11},
			{13, 14, 11}, {43, 16, 11}, {-44, 20, 11}, {-37, 20, 11},
			{-15, 20, 11}, {44, 23, 11}, {34, 26, 11}, {30, 29, 11},
			{-31, 28, 11}, {41, 30, 11}, {33, 33, 11}, {40, 37, 11},
			-- The old shrine ground, the walk to the quay and the shore.
			{21, 14, 11}, {15, 21, 11}, {22, 21, 11}, {14, 27, 11},
			{-20, 34, 11}, {-26, 36, 11}, {-32, 32, 11}, {-16, 30, 11},
			{21, 36, 11}, {30, 37, 11},
			-- The ground Round 70 added: the north shoulders, the east
			-- and the south band.
			{-50, 44, 11}, {-50, 34, 11}, {-46, 50, 11}, {-40, 52, 11},
			{48, 40, 11}, {52, 34, 11}, {46, 47, 11}, {52, 50, 11},
			{51, 22, 11}, {51, 12, 11}, {50, -14, 11}, {52, -24, 11},
			{51, -36, 11}, {48, -50, 11}, {38, -51, 11}, {28, -51, 11},
			{18, -50, 11}, {-12, -52, 11},
		})
		if standards < 16 then
			error("wp13 lethariel: only " .. standards ..
				" silverwood standards found open ground", 0)
		end

		-- 10. THE CORE EDGE: a light wall of the city curtain's stone (Round
		-- 23, in place of the silverwood hedge). One node thick on the
		-- hedge's columns, in the civic quarter's pale cut: two courses of
		-- silver sandstone brick, a marble coping at y 3 -- the height of the
		-- marble band the three pale gatehouses carry -- and on every other
		-- column a low merlon, a brick under a marble slab, which is the
		-- merlon the outer curtain carries too (the user's playtest ruling of
		-- 2026-09-28: the first version's pillar colonnettes stood too
		-- tall). The protected wall wins every dry non-gate column; only the
		-- mere itself replaces the boundary.
		local PRECINCT_STONE = pale.node("castle_wall")
		local PRECINCT_COPING = pale.node("signature")
		local PRECINCT_CAP = pale.node("signature_slab")
		local wall = 0
		precinct_ring.walk(function(x, z)
			precinct_ring.clear_wallmounted(buf, parts, x, z, 5)
			buf:put(x, 1, z, PRECINCT_STONE)
			buf:put(x, 2, z, PRECINCT_STONE)
			buf:put(x, 3, z, PRECINCT_COPING)
			if (x + z) % 2 == 0 then
				buf:put(x, 4, z, PRECINCT_STONE)
				buf:put(x, 5, z, PRECINCT_CAP)
			end
			wall = wall + 1
		end, {skip = function(x, z) return not dry(x, z) end})

		-- 11. Undergrowth on the turf between the quarters.
		-- Round 51 follow-up FT: in patches and gaps, far thinner than the
		-- plain scatter (`dressing.patch_keep`; the user: too dense, too even).
		dressing.undergrowth(buf, elf_palette, -RADIUS, -RADIUS, RADIUS,
			RADIUS, 5, dressing.CORE_PATCH)

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
		-- Public service a few nodes outside the {'highcourt': "king's hall", 'dur_brannoc': "king's hall", 'nhal_veyr': 'mausoleum', 'gor_drazhak': 'warlord hall', 'lethariel': "king's hall", 'kezamba': "king's hall"} door, beside its
		-- approach and facing away from it, in plain view (the user, 2026-11-10).
		socket("expedition_registrar", "idle", -16, 1, -26, 1, {tags = {"work"}})
		for _, corner in ipairs(CORNERS) do
			socket(corner.id, "guard_patrol", corner.x, 1, corner.z,
				corner.face, {group = WATCH, order = corner.order})
		end
		-- The quay's own life: three anglers on the promenade looking at the
		-- mere. `fish` is capital-only and this is the capital that has a lake
		-- in its core; the water they face is the world's, one node beyond the
		-- quay's kerb, not a cell this blueprint writes.
		-- On the QUAY ITSELF, which is a diagonal: at z = 42 the mere spans
		-- x -20..20, the walk starts two nodes outside that, and a socket on
		-- the round number would have stood in the water. Each stands on the
		-- walk in front of its bench, which keeps off the paving.
		socket("quay_idle_west", "idle", -23, 1, 42, 0, {tags = {"bench"}})
		socket("quay_idle_east", "idle", 23, 1, 42, 0, {tags = {"bench"}})
		socket("quay_idle_head", "idle", -4, 1, 33, 0, {tags = {"work"}})
		socket("grove_idle_walk", "idle", 22, 1, 9, 1, {tags = {"work"}})
		socket("grove_idle_shrine", "idle", 18, 1, 25, 2, {tags = {"work"}})
		socket("forecourt_idle_west", "idle", -6, 1, -14, 1, {tags = {"bench"}})
		socket("forecourt_idle_east", "idle", 7, 1, -14, 3, {tags = {"bench"}})
		socket("market_idle_walk", "idle", 12, 1, 27, 2, {tags = {"work"}})
		-- THE CORE'S OWN WORK SOCKETS (sockets contract section 8.1). Each
		-- faces the feature its activity names, one or two nodes away, and
		-- each of those features is authored in section 8b or is the bench the
		-- socket sits on. `sit` names no feature at all -- it sits on the
		-- ground it stands on -- so its `y` is 2, the seat being a walkable
		-- node the resident stands on top of.
		socket("shore_work_counter", "work", 8, 1, 13, 0,
			{activity = "stall"})
		socket("shore_work_pile", "work", 13, 1, 13, 0, {activity = "chop"})
		socket("shore_work_beds", "work", 9, 1, 16, 0, {activity = "tend"})
		socket("shore_work_stone", "work", 13, 1, 16, 0, {activity = "carve"})
		socket("shore_work_sweep", "work", -4, 1, 33, 0, {activity = "sweep"})
		-- The two sitters face where their benches look: into the crossing,
		-- their backs to the lantern pillars (Round 36 lane W2).
		socket("crossing_work_west", "work", -5, 2, -4, 0,
			{activity = "sit", tags = {"bench"}})
		socket("crossing_work_east", "work", 5, 2, -4, 0,
			{activity = "sit", tags = {"bench"}})
		-- TEN SPARE spots. `spawn = false` is the sockets contract's own word
		-- for them (playtest round 2): a real authored standing position that
		-- reaches every consumer and that NOBODY IS PLACED ON, so a villager's
		-- amble has somewhere to go that is not another villager's doorstep.
		-- No tag: a tag is what the spoken line and the facing rule read, and
		-- a spare has neither a line nor a door.
		local SPARES = {
			{"core_spare_crossing_east", 12, -4, 3},
			{"core_spare_crossing_west", -16, -1, 1},
			-- Round 47: 0 faced a tree; Round 70: 2 faced the lantern, now over the quay
			{"core_spare_quay_west", -28, 44, 1},
			{"core_spare_quay_east", 24, 38, 0},
			{"core_spare_approach", 5, 25, 0},
			{"core_spare_market_walk", 12, 20, 1}, -- Round 70: 0 faced the lantern
			{"core_spare_west_avenue", -34, -5, 1},
			{"core_spare_east_avenue", 34, 5, 3},
			{"core_spare_grove", 25, 2, 2},
			{"core_spare_plaza_south", 30, -24, 3},
		}
		for _, spare in ipairs(SPARES) do
			socket(spare[1], "idle", spare[2], 1, spare[3], spare[4],
				{spawn = false})
		end

		-- 13. Pane shapes, settled once over the finished pad.
		parts.resolve_panes(buf)

		-- 14. Canonical cell list, bounds and palette.
		-- Round 47 town greening: the race's trees on the open wild ground.
		layout.green(buf, elf_palette, RADIUS, sockets, doorways)
		-- Round 51 follow-up FT: the ground cover thinned, now the trees stand.
		-- Round 58: the gate watch's corners stand on open ground.
		gate_watch.clear_cover(buf, CAPITAL.palettes.town)
		dressing.thin_cover(buf)
		local source, count = buf:cells()
		local cells = {}
		for index = 1, count do cells[index] = source[index] end
		parts.sort_cells_zyx(cells)
		local light_names = {[elf_palette.node("light_post")] = true,
			[elf_palette.node("light_wall")] = true,
			[elf_palette.node("light_indoor")] = true}
		local beacon = elf_palette.maybe("light_beacon")
		if beacon then light_names[beacon] = true end
		local hanging = elf_palette.maybe("light_hanging")
		if hanging then light_names[hanging] = true end
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
				error("wp13 lethariel: destination " .. id .. " is missing", 0)
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
			error("wp13 lethariel: no door for " .. id, 0)
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
				gate_east = {x = RADIUS, y = 1, z = 0},
				gate_west = {x = -RADIUS, y = 1, z = 0},
				-- The north "gate" is the head of the quay and stands on the
				-- axis near its last dry row, not on the pad edge.
				gate_north = {x = 0, y = 1, z = QUAY_HEAD.z1 + 2},
				main_street = {min = {x = -2, y = 0, z = -RADIUS},
					max = {x = 2, y = 5, z = 4}},
				avenue_south = {min = {x = -2, y = 0, z = -RADIUS},
					max = {x = 2, y = 5, z = 4}},
				avenue_north = {min = {x = -2, y = 0, z = 5},
					max = {x = 2, y = 5, z = QUAY_HEAD.z2}},
				avenue_west = {min = {x = -RADIUS, y = 0, z = -2},
					max = {x = -3, y = 5, z = 2}},
				avenue_east = {min = {x = 3, y = 0, z = -2},
					max = {x = RADIUS, y = 5, z = 2}},
				throne_approach = {min = {x = COURT.x1, y = 0, z = APPROACH.z1},
					max = {x = -3, y = 8, z = APPROACH.z2}},
				-- The reserved square is the plaza INSIDE its kerb.
				waypoint_plaza = {min = {x = PLAZA.x1 + 1, y = 0,
						z = PLAZA.z1 + 1},
					max = {x = PLAZA.x2 - 1, y = 4, z = PLAZA.z2 - 1}},
				kings_hall = box("kings_hall", 2, 2),
				kings_hall_door = door_of("kings_hall"),
				market = box("market", 1, 1),
				star_hall = box("star_hall", 2, 4),
				star_hall_door = door_of("star_hall"),
				sacred_grove = box("sacred_grove", 1, 1),
				destinations = destinations,
				doors = doorways,
				rooms = rooms,
				lights = lights,
				sockets = sockets,
				-- The populations the KAT holds this composition to.
				ground_columns = laid,
				mere_columns = water,
				quay_columns = quay,
				axis_columns = axis,
				lantern_pillars = lanterns,
				precinct_wall_columns = wall,
				standards = standards,
			},
		}
	end

	return M
end

return loader
