-- Kezamba: the troll capital, and the only one of the six whose civic core has
-- a lake in it.
--
-- This file is the CORE composition of docs/research/wp13-capitals-pois-
-- contract.md section 2.1 -- the 96 x 96 civic core, anchor-relative exactly
-- like a start, inside the contract's bounds of x/z [-47, 47] and y [-2, 40] --
-- plus the run specifications the overlay turns into the four avenues, the ring
-- street and the four gate thresholds.
--
-- Contract section 2.4, the troll row, quoted in full because everything below
-- is an answer to it: "Kezamba | troll | stilted cenote terrace, step 3 | stilt
-- halls on basalt platforms, junglewood walkways, totem posts, cauldron courts,
-- emergent trees kept". Section 4's wall ruling of 2026-09-14, unchanged by the
-- round-3 plan: Kezamba is one of the two OPEN capitals, so there is NO curtain
-- wall and the four gate points at +-256 carry a threshold instead.
--
-- WHAT IS DIFFERENT HERE, AND IT IS NOT A STYLE CHOICE
-- ---------------------------------------------------
-- The contract's section 1 says "the 96 x 96 civic core is flat at the fitted
-- reference height". At Kezamba that is true of 6 192 of its 9 025 columns and
-- false of the other 2 833, and `tools/wp13/kezamba_water.lua` is the
-- measurement rather than the impression:
--
--   * 2 645 columns are the CENOTE. WP40's `hydro_kezamba_cenote` is an
--     authored `deep_cenote` at fixed world coordinates and its north-east
--     wedge reaches into the core. Its surface stands at y = 65, exactly ONE
--     NODE below the fitted reference of 66, on all nine seeds of
--     `tools/wp13/capital_anchor_fixture.lua` -- which is the WP40 water
--     correction of 2026-09-13 doing what it says.
--   * 188 to 273 columns are a RAVINE: one diagonal cut running into the pad
--     from its south-west edge, up to 26 nodes deep. Its footprint is the same
--     in every world and only its depth moves.
--
-- Both masks are committed in `wp13/kezamba_lagoon.lua`, generated and verified
-- by that tool against the planner on nine seeds. THE COMPOSITION LAYS NO
-- GROUND IN EITHER. A ground course written at y = 0 over the lake would fill
-- the cenote with mud, and over the ravine it would be a slab hanging in the
-- air; both are refused at construction time by `pad_area`, loudly, naming the
-- column.
--
-- What that buys is the capital the contract asked for. The city stands on the
-- dry south-west of its own pad; the lake is its north-east quarter; the east
-- and north avenues leave the crossing and become JUNGLEWOOD BOARDWALKS ON
-- BASALT PIERS the moment they reach the water, which is the "stilt halls on
-- basalt platforms, junglewood walkways" of the contract built out of the
-- terrain instead of on top of it.
--
--   * `M.core()` returns the core composition in the exact shape of a start
--     composition, plus `landmarks.sockets`.
--   * `M.district` is resolved by `kezamba_districts.lua` from the four
--     district rosters and the searched lots of `kezamba_lots.lua`.
--   * `M.avenues`, `M.ring` and `M.gates` are the overlay's runs.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local palettes = dofile(directory .. "/palette.lua")
	local buildings = dofile(directory .. "/buildings.lua")(directory)
	local capitals = dofile(directory .. "/capitals.lua")(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local layout = dofile(directory .. "/layout.lua")(directory)
	local troll = dofile(directory .. "/troll_parts.lua")(directory)
	local handles = dofile(directory .. "/troll_palette.lua")()
	local mask = dofile(directory .. "/kezamba_lagoon.lua")()
	local gates = dofile(directory .. "/kezamba_gate.lua")(directory)

	local M = {}

	local RADIUS = 47
	local SCHEMA = "grug_wp13_kezamba_core_v1"
	local WATCH = "kezamba_watch"

	M.mask = mask

	-- The travel plaza reserved for WP17.
	local PLAZA = {x1 = -44, z1 = -30, x2 = -32, z2 = -18}

	-- THE STREETS. The four avenues are five wide on the two axes; the lanes
	-- are the quarters' own. Every run is checked against the ravine mask at
	-- construction time, because a lane laid across a 26-node gorge is a lane
	-- hanging in the air.
	local STREETS = {
		{-2, -RADIUS, 2, -3, "avenue"},
		{-2, 3, 2, RADIUS, "avenue"},
		{-RADIUS, -2, -3, 2, "avenue"},
		{3, -2, RADIUS, 2, "avenue"},
		-- The crossing itself.
		{-2, -2, 2, 2, "avenue"},
		-- The king's forecourt, a strip along the hall's west front off the
		-- south avenue's east kerb.
		{3, -40, 5, -22, "lane"},
		-- The market walk, from the crossing west to the travel plaza. It runs
		-- at z -20..-16 and not further south because the RAVINE reaches z =
		-- -21: a lane one node south of here would be a lane over a gorge, and
		-- the composition refuses one.
		{-31, -20, -3, -16, "lane"},
		{-32, -20, -30, -16, "lane"},
		-- The quay walk, north along the lake's west bank, and its two links
		-- back to the avenues.
		{-20, 6, -16, 44, "lane"},
		{-16, 6, -3, 10, "lane"},
		{-16, 32, -3, 36, "lane"},
		-- The east quarter's lanes.
		{24, -22, 44, -18, "lane"},
		{36, -30, 40, -22, "lane"},
		-- The west quarter's lane, from the west avenue to the shrine walk.
		{-44, 6, -40, 24, "lane"},
	}

	-- The plot roster. `make` is the generator, `module` the library it comes
	-- from, `x`/`z` the pad anchor of the rotated footprint, `turns` the
	-- rotation, `handle` which palette handle it is built with.
	local PLOTS = {
		-- 1. The king's hall, east of the throne approach with its great door
		-- looking west onto it. It is NOT on the axis, and that is the ravine's
		-- doing rather than a choice: the approach has to reach the south gate
		-- and the gorge takes the ground west of it from z = -47 to z = -21.
		{id = "kings_hall", module = "capitals", make = "king_hall",
			x = 8, z = -42, turns = 3, handle = "basalt",
			spec = {w = 23, d = 23, rise = 6},
			drop = {waypoint = true}},

		-- 2. The moot house: a stilt hall STRADDLING THE LAKE'S WEST BANK, its
		-- flight on the shore, its platform half on land and half on piers over
		-- the water, its walkway running out over the cenote. This is the
		-- building the contract's troll row is about, and it is the reason the
		-- lake is left alone rather than filled. `turns = 1` puts the flight at
		-- the -x end, which is the bank.
		{id = "moot_house", module = "troll", make = "stilt_hall",
			x = -24, z = 30, turns = 1, handle = "basalt",
			spec = {w = 11, d = 11, deck = 4, spur = 6,
				patrol_group = WATCH, order = 3},
			water = true, land_rows = 4},

		-- 3. The cauldron court: the troll market, in the south-west corner.
		{id = "cauldron_court", module = "troll", make = "cauldron_court",
			x = -46, z = -46, turns = 0, handle = "troll",
			spec = {size = 15, patrol_group = WATCH, order = 1}},

		-- 4. The shaman's shrine, on the pad's north-west shoulder. It carries
		-- this capital's one quest shell.
		{id = "shrine", module = "troll", make = "shaman_shrine",
			x = -46, z = 26, turns = 0, handle = "troll",
			spec = {size = 13, patrol_group = WATCH, order = 5}},

		-- 5. The carvers' yard, on the west avenue's south flank.
		{id = "carver_yard", module = "troll", make = "carver_yard",
			x = -46, z = -16, turns = 0, handle = "troll",
			spec = {size = 13}},

		-- 6. The granary and the pack stable of the east quarter.
		{id = "granary", module = "capitals", make = "granary",
			x = 6, z = -16, turns = 1, handle = "troll",
			spec = {w = 11, d = 15, wall_h = 5}},
		{id = "stable", module = "capitals", make = "stable",
			x = 35, z = -45, turns = 1, handle = "troll",
			spec = {w = 15, d = 11, wall_h = 5}},

		-- 7. Four houses on the outer ground.
		{id = "gate_house_south", module = "buildings", make = "cottage",
			x = 24, z = -16, turns = 1, handle = "troll",
			spec = {w = 9, d = 9, wall_h = 5, roof = "gable",
				ridge_axis = "z", infill = true, shutters = true}},
		{id = "lane_house", module = "buildings", make = "cottage",
			x = 36, z = -24, turns = 1, handle = "troll",
			spec = {w = 9, d = 9, wall_h = 5, roof = "hip",
				infill = true, shutters = true}},
		{id = "west_house", module = "buildings", make = "cottage",
			x = -29, z = -44, turns = 1, handle = "troll",
			spec = {w = 9, d = 9, wall_h = 5, roof = "saltbox",
				ridge_axis = "x", infill = true, fancy_bed = true}},
		{id = "shore_house", module = "buildings", make = "cottage",
			x = -44, z = 4, turns = 1, handle = "troll",
			spec = {w = 9, d = 9, wall_h = 5, roof = "gable",
				ridge_axis = "x", infill = true, shutters = true}},

		-- 8. The trade shed on the market walk, where the two royal vendors
		-- stand.
		{id = "trade_shed", module = "buildings", make = "shed",
			x = -20, z = -14, turns = 0, handle = "troll",
			spec = {w = 13, d = 9, wall_h = 4, open_sides = {"z-", "x+"}}},
	}

	-- Destination order is part of the consumer contract and never changes.
	local DESTINATION_ORDER = {"kings_hall", "moot_house", "cauldron_court",
		"shrine", "carver_yard", "granary", "stable",
		"gate_house_south", "lane_house", "west_house", "shore_house",
		"trade_shed"}

	-- The city loop's corner waypoints, on the open ground between quarters.
	local CORNERS = {
		{id = "watch_south_west", x = -34, z = -44, face = 0, order = 6},
		{id = "watch_south_east", x = 44, z = -44, face = 0, order = 7},
		{id = "watch_crossing", x = -8, z = -8, face = 2, order = 8},
		{id = "watch_quay", x = -24, z = 20, face = 1, order = 9},
	}

	-- Where the four avenues and the ring street run in the 512 envelope.
	--
	-- THEY REACH 256 AND NOT 261. Dur Brannoc's and Highcourt's avenues run five
	-- nodes past the envelope edge because a gate TUNNEL through seven nodes of
	-- curtain has to be driven through; Kezamba is open and its threshold
	-- straddles the gate point, so the road ends on it.
	local GATE_OUT = 256
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

	M.ring = {
		{id = "ring_west", axis = "z", at = -96, from = -96, to = 96},
		{id = "ring_east", axis = "z", at = 96, from = -96, to = 96},
		{id = "ring_south", axis = "x", at = -96, from = -96, to = 96},
		{id = "ring_north", axis = "x", at = 96, from = -96, to = 96},
	}

	-- THE FOUR GATE THRESHOLDS, which are what an OPEN capital has where a
	-- walled one has a gatehouse. Each is a short run astride its own gate
	-- point, so the piece the seam activates for it is inside the same
	-- `at +- (half + 1)` band the road's is.
	local THRESHOLD = 10
	M.gates = {
		{id = "gate_south", axis = "z", at = 0,
			from = -GATE_OUT - THRESHOLD, to = -GATE_OUT + THRESHOLD},
		{id = "gate_north", axis = "z", at = 0,
			from = GATE_OUT - THRESHOLD, to = GATE_OUT + THRESHOLD},
		{id = "gate_west", axis = "x", at = 0,
			from = -GATE_OUT - THRESHOLD, to = -GATE_OUT + THRESHOLD},
		{id = "gate_east", axis = "x", at = 0,
			from = GATE_OUT - THRESHOLD, to = GATE_OUT + THRESHOLD},
	}
	M.gate_plan = {
		gate_south = {centre = -GATE_OUT}, gate_north = {centre = GATE_OUT},
		gate_west = {centre = -GATE_OUT}, gate_east = {centre = GATE_OUT},
	}

	function M.core()
		local timber = palettes.new("troll")
		local basalt = palettes.new("troll", handles.BASALT)
		local by_handle = {troll = timber, basalt = basalt}
		local buf = parts.buffer()
		local doorways, rooms, sockets = {}, {}, {}
		local placed, inside_by_id, plot_order = {}, {}, {}
		local claimed = {}

		local DECK = timber.node("path")              -- junglewood boardwalk
		local PAVE = timber.maybe("castle_paving") or timber.node("plaza")
		local KERB = timber.node("plaza_edge")
		local PIER = timber.maybe("signature") or timber.node("foundation")
		local RAIL = timber.node("railing")

		local function outdoors(x, z)
			for _, plot in ipairs(plot_order) do
				if x >= plot.x and x <= plot.x + plot.w - 1 and
						z >= plot.z and z <= plot.z + plot.d - 1 then
					return false
				end
			end
			return true
		end

		local GROUND = {}
		for _, role in ipairs({"ground", "ground_patch", "ground_bare"}) do
			GROUND[timber.node(role)] = true
		end

		-- EVERY CELL THE COMPOSITION DELIBERATELY PUTS OVER THE LAKE OR THE
		-- GORGE, by key. Nothing else of this composition may end up in a
		-- masked column: an AIR cell there would drain the cenote (the
		-- settlement writer writes what the blueprint says, air included), and
		-- a ground cell there would fill it. The final pass drops everything in
		-- a masked column that is not registered here, which is cheaper and
		-- more honest than teaching `layout` and `dressing` about a mask they
		-- have no business knowing.
		local over_water = {}
		local function claim_water(x, y, z)
			over_water[x .. ":" .. y .. ":" .. z] = true
		end

		local function refuse(name, x, z, reason)
			error("wp13 kezamba: prop " .. name .. " at " .. x .. "," ..
				z .. " was not placed: " .. reason, 0)
		end

		-- 1. THE PAD. Litter over mud on every column the masks leave, and
		-- NOTHING at all on the ones they do not: the cenote keeps its water
		-- and the ravine keeps its air.
		local pad_columns, lagoon_columns, ravine_columns = 0, 0, 0
		for z = -RADIUS, RADIUS do
			for x = -RADIUS, RADIUS do
				if mask.lagoon(x, z) then
					lagoon_columns = lagoon_columns + 1
				elseif mask.ravine(x, z) then
					ravine_columns = ravine_columns + 1
				else
					buf:put(x, -1, z, timber.node("subsoil"))
					buf:put(x, 0, z, timber.node("ground"))
					pad_columns = pad_columns + 1
				end
			end
		end
		if pad_columns + lagoon_columns + ravine_columns ~=
				(2 * RADIUS + 1) * (2 * RADIUS + 1) then
			error("wp13 kezamba: the pad does not cover its own core", 0)
		end

		-- 2. THE STREETS. A street column on the pad is boardwalk laid into the
		-- ground course; a street column over the lake is a DECK on basalt
		-- piers, with a rail on the verge. The piers reach y = -2, the
		-- contract's floor for a core, which is one node under the lake's
		-- surface: the cenote's bed is ten or more nodes lower and a pier that
		-- tried to reach it would leave the authorized volume. What the player
		-- sees is a leg going into the water, which is what a stilt is.
		local boardwalk, piers = 0, 0
		local function street(x1, z1, x2, z2, kind)
			local name = (kind == "avenue") and DECK or DECK
			for z = z1, z2 do
				for x = x1, x2 do
					if mask.ravine(x, z) then
						error("wp13 kezamba: the street at " .. x .. "," .. z ..
							" crosses the ravine", 0)
					end
					local edge = (x == x1 or x == x2 or z == z1 or z == z2)
					if mask.lagoon(x, z) then
						buf:put(x, 0, z, name)
						claim_water(x, 0, z)
						boardwalk = boardwalk + 1
						if ((x + z) % 3 == 0) and edge then
							for y = -2, -1 do
								buf:put(x, y, z, PIER)
								claim_water(x, y, z)
							end
							piers = piers + 1
						end
						if edge and kind == "avenue" then
							buf:put(x, 1, z, RAIL)
							claim_water(x, 1, z)
						end
					else
						buf:put(x, 0, z, name)
						buf:clear(x, 1, z, x, 5, z)
					end
				end
			end
			-- The kerb: a signature band down both flanks of an avenue.
			if kind == "avenue" then
				for z = z1, z2 do
					for x = x1, x2 do
						if (x == x1 or x == x2 or z == z1 or z == z2) and
								not mask.lagoon(x, z) then
							buf:put(x, 0, z, KERB)
						end
					end
				end
			end
		end
		for _, run in ipairs(STREETS) do
			street(run[1], run[2], run[3], run[4], run[5])
		end

		-- 3. THE TRAVEL PLAZA reserved for WP17: paving, two kerb rings and
		-- nothing above the ground course.
		do
			local ok, bx, bz = mask.pad_area(PLAZA.x1, PLAZA.z1, PLAZA.x2,
				PLAZA.z2)
			if not ok then
				error("wp13 kezamba: the travel plaza reaches the water at " ..
					bx .. "," .. bz, 0)
			end
		end
		for z = PLAZA.z1, PLAZA.z2 do
			for x = PLAZA.x1, PLAZA.x2 do
				buf:put(x, 0, z, PAVE)
			end
		end
		buf:clear(PLAZA.x1, 1, PLAZA.z1, PLAZA.x2, 6, PLAZA.z2)
		dressing.inlay(buf, timber, PLAZA.x1, PLAZA.z1, PLAZA.x2, PLAZA.z2)
		dressing.inlay(buf, timber, PLAZA.x1 + 4, PLAZA.z1 + 4,
			PLAZA.x2 - 4, PLAZA.z2 - 4)
		local pad_x = math.floor((PLAZA.x1 + PLAZA.x2) / 2)
		local pad_z = math.floor((PLAZA.z1 + PLAZA.z2) / 2)
		local SIGNATURE = timber.maybe("signature") or KERB
		for step = -6, 6 do
			buf:put(pad_x + step, 0, pad_z, SIGNATURE)
			buf:put(pad_x, 0, pad_z + step, SIGNATURE)
		end

		-- 4. THE PLOTS.
		for _, plot in ipairs(PLOTS) do
			local spec = {}
			for key, value in pairs(plot.spec) do spec[key] = value end
			spec.id = plot.id
			local module = capitals
			if plot.module == "buildings" then module = buildings
			elseif plot.module == "troll" then module = troll end
			local generator = module[plot.make]
			if type(generator) ~= "function" then
				error("wp13 kezamba: no generator " .. plot.make, 0)
			end
			local part = generator(by_handle[plot.handle], spec)
			local turns = plot.turns % 4
			local rw = (turns % 2 == 1) and part.d or part.w
			local rd = (turns % 2 == 1) and part.w or part.d
			-- EVERY PLOT STANDS ON THE PAD, unless it is one of the two that
			-- deliberately stand over the lake and say so. A part laid over the
			-- cenote lays its ground course on the water; a part laid over the
			-- ravine lays it in the air. Neither is a thing to discover in a
			-- render.
			if not plot.water then
				local ok, bx, bz = mask.pad_area(plot.x, plot.z,
					plot.x + rw - 1, plot.z + rd - 1)
				if not ok then
					error("wp13 kezamba: the plot " .. plot.id ..
						" reaches the lake or the ravine at " .. bx .. "," ..
						bz, 0)
				end
			else
				-- A WATER PLOT stands over the lake on its own piers, and two
				-- things still have to hold of it. Its `land_rows` -- the band
				-- its flight occupies, at the -x end after `turns = 1` -- must
				-- be dry ground, or the stair climbs out of the water; and no
				-- cell of it may touch the ravine, because a stilt stands in
				-- water and not over a gorge.
				local rows = plot.land_rows or 0
				for z = plot.z, plot.z + rd - 1 do
					for x = plot.x, plot.x + rw - 1 do
						if mask.ravine(x, z) then
							error("wp13 kezamba: the water plot " .. plot.id ..
								" reaches the ravine at " .. x .. "," .. z, 0)
						end
						local near = (turns == 1 and x < plot.x + rows) or
							(turns == 3 and x > plot.x + rw - 1 - rows) or
							(turns == 0 and z < plot.z + rows) or
							(turns == 2 and z > plot.z + rd - 1 - rows)
						if near and not mask.pad(x, z) then
							error("wp13 kezamba: the flight of " .. plot.id ..
								" stands in the water at " .. x .. "," .. z, 0)
						end
					end
				end
			end
			-- Two plots may not share a cell. `parts.stamp` writes; it does not
			-- ask, so a plot laid over another cuts a silent hole in the first.
			--
			-- And no plot may leave the core's own envelope. That is not
			-- paranoia: several library parts carry authored cells at NEGATIVE
			-- local coordinates -- `capitals.king_hall`'s forecourt steps reach
			-- x -3 and z -3 of its own frame -- so a part's real extent is
			-- wider than the `w` and `d` it declares, and under a quarter turn
			-- the overhang moves to another side. The first layout of this
			-- composition put 408 cells outside +-47 for exactly that reason.
			local source, count = part.buffer:cells()
			for index = 1, count do
				local cell = source[index]
				local rx, rz = parts.rotate_footprint(cell.x, cell.z,
					part.w, part.d, turns)
				local wx, wz = plot.x + rx, plot.z + rz
				if wx < -RADIUS or wx > RADIUS or wz < -RADIUS or
						wz > RADIUS or cell.y < -2 or cell.y > 40 then
					error("wp13 kezamba: the plot " .. plot.id ..
						" leaves the core envelope at " .. wx .. "," ..
						cell.y .. "," .. wz, 0)
				end
				local key = wx .. ":" .. cell.y .. ":" .. wz
				local owner = claimed[key]
				if owner ~= nil then
					error("wp13 kezamba: the plot " .. plot.id ..
						" writes " .. cell.name .. " into " .. owner ..
						" at " .. key, 0)
				end
				claimed[key] = plot.id
			end
			local points = parts.stamp(buf, part, plot.x, 0, plot.z, turns)
			if plot.water then
				local source2, count2 = part.buffer:cells()
				for index = 1, count2 do
					local cell = source2[index]
					local rx, rz = parts.rotate_footprint(cell.x, cell.z,
						part.w, part.d, turns)
					claim_water(plot.x + rx, cell.y, plot.z + rz)
				end
			end
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
					local override = overrides[entry.id] or {}
					sockets[#sockets + 1] = {id = entry.id, role = entry.role,
						x = override.x or entry.x, y = override.y or entry.y,
						z = override.z or entry.z,
						face = override.face or entry.face,
						group = entry.group, order = entry.order,
						kind = entry.kind, activity = entry.activity,
						spawn = entry.spawn,
						tags = override.tags or entry.tags}
				end
			end
		end

		-- 5. THE QUAY. Every pad column on the water's edge that the city has
		-- not already built on gets a course of basalt kerb, which is what
		-- keeps the shoreline from reading as grass stopping at water.
		local quay = 0
		for z = -RADIUS, RADIUS do
			for x = -RADIUS, RADIUS do
				if mask.shore(x, z) then
					local here = buf:at(x, 0, z)
					if here ~= nil and GROUND[here.name] and
							layout.free(buf, x, z, 3) then
						buf:put(x, 0, z, PIER)
						quay = quay + 1
					end
				end
			end
		end

		-- 6. THE RAVINE: a rope-and-post rail along its rim, and ONE plank
		-- footbridge over it at its narrowest, which is where it leaves the pad
		-- on its way north-east.
		local rim = 0
		for z = -RADIUS, RADIUS do
			for x = -RADIUS, RADIUS do
				if not mask.ravine(x, z) and not mask.lagoon(x, z) then
					local beside = false
					for _, step in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
						if mask.ravine(x + step[1], z + step[2]) then
							beside = true
						end
					end
					if beside and layout.free(buf, x, z, 3) and
							layout.natural(buf, x, z) and (x + z) % 2 == 0 then
						buf:put(x, 1, z, RAIL)
						rim = rim + 1
					end
				end
			end
		end
		local bridge = 0
		do
			local z = -22
			local x1, x2
			for x = -RADIUS, RADIUS do
				if mask.ravine(x, z) then
					if x1 == nil then x1 = x end
					x2 = x
				end
			end
			if x1 == nil then
				error("wp13 kezamba: the ravine does not reach z = -22", 0)
			end
			for step = -2, 2 do
				for x = x1 - 2, x2 + 2 do
					buf:put(x, 0, z + step, DECK)
					claim_water(x, 0, z + step)
					bridge = bridge + 1
					if step == -2 or step == 2 then
						buf:put(x, 1, z + step, RAIL)
						claim_water(x, 1, z + step)
					end
				end
			end
		end

		-- 7. The quay's own props: the two royal booths in the trade shed's
		-- apron, drying racks on the shore walk and crates on the landing.
		local VENDORS = {
			{id = "vendor_race", kind = "race", x = -25, z = -12},
			{id = "vendor_general", kind = "general", x = -25, z = -6},
		}
		local function paved_prop(name, x1, z1, x2, z2, build)
			if not layout.free_area(buf, x1, z1, x2, z2, 4) then
				refuse(name, x1, z1, "the space is taken")
			end
			local ok, bx, bz = mask.pad_area(x1, z1, x2, z2)
			if not ok then
				refuse(name, x1, z1, "the ground at " .. bx .. "," .. bz ..
					" is lake or gorge")
			end
			if build() == false then
				refuse(name, x1, z1, "the prop could not be completed")
			end
		end
		-- A prop that CARRIES A SOCKET must land, because a socket in front of
		-- a stall that was skipped is a trader standing in a field: those go
		-- through `paved_prop`, which refuses loudly. A prop that is only
		-- scenery may be skipped where the ground is taken, and `scatter`
		-- counts what landed and refuses a floor -- which is the Dawnmere
		-- lesson (a silently skipped prop is a hole nobody sees) answered with
		-- a number rather than with a list of coordinates nobody may touch.
		local function scatter(name, spots, least, build)
			local placed_count = 0
			for _, spot in ipairs(spots) do
				local x1, z1 = spot[1], spot[2]
				local x2, z2 = spot[3] or x1, spot[4] or z1
				if mask.pad_area(x1, z1, x2, z2) and
						layout.free_area(buf, x1, z1, x2, z2, 4) then
					build(spot)
					placed_count = placed_count + 1
				end
			end
			if placed_count < least then
				error("wp13 kezamba: only " .. placed_count .. " of " ..
					#spots .. " " .. name .. " found open ground, " .. least ..
					" wanted", 0)
			end
			return placed_count
		end

		for _, booth in ipairs(VENDORS) do
			paved_prop("booth", booth.x - 1, booth.z - 1, booth.x + 3,
				booth.z + 3, function()
					dressing.stall(buf, timber, booth.x, booth.z, 0)
				end)
		end
		local crates = scatter("crate stack", {{-22, 12}, {-22, 42},
			{-30, -8}, {-28, -6}, {26, -20}, {44, -20}, {-14, -18},
			{20, -8}, {-34, 8}, {-22, 28}}, 5, function(spot)
				dressing.crates(buf, timber, spot[1], spot[2], 2)
			end)
		local benches = scatter("bench", {{-8, 4, -6, 4}, {4, 4, 6, 4},
			{-30, -10, -28, -10}, {-26, 8, -24, 8}, {-14, -22, -12, -22},
			{22, -12, 24, -12}}, 4, function(spot)
				dressing.bench(buf, timber, spot[1], spot[2],
					(spot[2] > 0) and 2 or 0, 3, "x")
			end)
		local lamps_placed = scatter("street lamp",
			{{PLAZA.x1, PLAZA.z1}, {PLAZA.x2, PLAZA.z1}, {PLAZA.x1, PLAZA.z2},
			{PLAZA.x2, PLAZA.z2}, {-6, -6}, {6, -6}, {-6, 6}, {-26, -6},
			{26, -6}, {-40, -6}, {40, -6}, {-19, 14}, {-19, 26}, {-19, 42},
			{-6, -34}, {-34, -34}, {44, -12}, {14, -34}, {-22, -16},
			{-36, -14}, {-6, -16}, {6, -16}, {34, -16}, {-42, 26},
			{-22, 34}, {-4, 4}, {4, -4}}, 14, function(spot)
				dressing.path_light(buf, timber, spot[1], spot[2])
			end)

		-- 7b. THE FISHING QUAY, and why it is authored column by column rather
		-- than stamped as a part.
		--
		-- `troll_parts` has no landing generator, and the reason is geometry:
		-- Kezamba's shoreline runs DIAGONALLY across the pad -- from (39, -7) to
		-- (-16, 47) -- so a rectangular apron with a jetty off one face either
		-- has its apron in the water or its jetty on the land, at every position
		-- and every rotation. Four were tried against the committed mask before
		-- this was written down.
		--
		-- What fits a diagonal shore is a quay that follows it. The counter, the
		-- racks and the fishmonger stand on the walk; the three anglers stand on
		-- chosen SHORE columns with open water inside the sockets contract's
		-- three-node reach of where they look, which is exactly what section
		-- 8.1's `fish` rule asks and what the KAT re-measures against the mask.
		do
			paved_prop("fish_counter", -25, 22, -22, 22, function()
				dressing.counter(buf, timber, -25, 22, 4, "x")
			end)
			scatter("drying rack", {{-28, 14, -28, 18}, {-28, 26, -28, 30},
				{-28, 36, -28, 40}, {-24, 6, -24, 10}}, 3, function(spot)
					dressing.drying_rack(buf, timber, spot[1], spot[2], 5, "z")
				end)
		end

		-- 8. TOTEM POSTS at the four core gate mouths: the open capital's own
		-- threshold, repeated in miniature where each avenue leaves the pad.
		local totems = 0
		for _, post in ipairs({{-4, -RADIUS + 1}, {4, -RADIUS + 1},
				{-RADIUS + 1, -4}, {-RADIUS + 1, 4},
				{-4, RADIUS - 1}, {4, RADIUS - 1},
				{RADIUS - 1, -4}, {RADIUS - 1, 4}}) do
			if mask.pad(post[1], post[2]) and
					layout.free(buf, post[1], post[2], 8) then
				dressing.totem(buf, timber, post[1], post[2], 6)
				totems = totems + 1
			end
		end

		-- 9. EMERGENT TREES ARE KEPT (contract section 2.4). The pad's own
		-- kapoks: five emergents on the open litter, plus jungle trees and
		-- basin flora on whatever the city has not built on. `plant_jungle`
		-- would scatter over the lake, so the spots are authored and each one
		-- is checked against the mask first.
		local emergents = 0
		for _, spot in ipairs({{-25, -30, 16}, {-6, -42, 15}, {-32, -8, 16},
				{-30, 16, 15}, {-28, 44, 16}, {40, -12, 15}, {-12, 8, 16},
				{-38, 20, 15}, {44, -20, 16}, {-36, 30, 15}, {-16, -26, 16},
				{-42, -20, 15}, {16, -8, 16}, {-40, 44, 15}}) do
			if mask.pad_area(spot[1] - 3, spot[2] - 3, spot[1] + 3, spot[2] + 3)
					and layout.free_area(buf, spot[1] - 3, spot[2] - 3,
						spot[1] + 3, spot[2] + 3, 21) then
				dressing.emergent(buf, timber, spot[1], spot[2], spot[3])
				emergents = emergents + 1
			end
		end
		if emergents < 4 then
			error("wp13 kezamba: only " .. emergents ..
				" emergent kapoks found open ground", 0)
		end
		local canopy = 0
		for _, spot in ipairs({{-44, -26, 8}, {-36, -26, 9}, {-8, -20, 8},
				{-24, 4, 9}, {-44, 20, 8}, {-30, 24, 9}, {-28, 40, 8},
				{44, -40, 9}, {-8, -36, 8}, {-12, -4, 9}, {-34, 44, 8},
				{44, -8, 9}, {36, -10, 8}, {-22, -28, 9}, {-40, 12, 8},
				{-6, -28, 9}, {12, -8, 8}, {-16, 16, 9}, {-24, 16, 8},
				{-38, 40, 9}, {-44, 36, 8}, {28, -8, 9}}) do
			if mask.pad_area(spot[1] - 2, spot[2] - 2, spot[1] + 2, spot[2] + 2)
					and layout.free_area(buf, spot[1] - 2, spot[2] - 2,
						spot[1] + 2, spot[2] + 2, 14) then
				dressing.jungle_tree(buf, timber, spot[1], spot[2], spot[3])
				canopy = canopy + 1
			end
		end

		-- 10. Basin flora on the litter the city has not taken, in the four
		-- quadrants of the pad, never over the water.
		for _, area in ipairs({{-RADIUS, -RADIUS, -1, -1},
				{1, -RADIUS, RADIUS, -1}, {-RADIUS, 1, -1, RADIUS}}) do
			dressing.basin_flora(buf, timber, area[1], area[2], area[3],
				area[4])
		end
		-- `basin_flora`, `undergrowth` and the lamp scatter all write where they
		-- are told, so whatever landed in a masked column comes straight back
		-- out here. `buf` has no delete, so the drop happens in the canonical
		-- list below; this pass only counts what will go.
		local cleaned = 0
		do
			local order, count = buf:cells()
			for index = 1, count do
				local cell = order[index]
				if (mask.lagoon(cell.x, cell.z) or
						mask.ravine(cell.x, cell.z)) and
						not over_water[cell.x .. ":" .. cell.y .. ":" ..
							cell.z] then
					cleaned = cleaned + 1
				end
			end
		end

		-- 10b. THE RESERVED SQUARE IS EMPTIED LAST. WP17's travel pad needs room
		-- and sky, and the scatter routines above -- the basin flora, the
		-- canopy, the undergrowth -- write where they are told and know nothing
		-- about it. Clearing it after them is one line; teaching four shared
		-- routines about one composition's reservation is four files.
		buf:clear(PLAZA.x1, 1, PLAZA.z1, PLAZA.x2, 24, PLAZA.z2)

		-- 11. The sockets the composition owns.
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
		socket("gate_post_south", "guard_post", -4, 1, -RADIUS + 3, 2)
		socket("gate_post_west", "guard_post", -RADIUS + 3, 1, -4, 1)
		-- The fishmonger behind his counter and his `stall` workplace beside
		-- him. `stall` is answered geometrically -- "a counter (any solid node
		-- at waist height)" -- and the counter is exactly that.
		socket("vendor_fishmonger", "vendor", -25, 1, 21, 0,
			{kind = "fishmonger"})
		socket("quay_stall", "work", -22, 1, 21, 0, {activity = "stall"})
		-- THE THREE ANGLERS, on shore columns of the committed mask, each
		-- looking east into the cenote. Every one of them has open water within
		-- three nodes of where it looks, which the KAT re-measures.
		for index, spot in ipairs({{-5, 20}, {-9, 26}, {-13, 32}}) do
			socket("cenote_fish_" .. index, "work", spot[1], 1, spot[2], 1,
				{activity = "fish"})
		end
		socket("quay_idle_north", "idle", -18, 1, 30, 1, {tags = {"work"}})
		socket("quay_idle_south", "idle", -18, 1, 14, 1, {tags = {"work"}})
		-- The two crossing spots sit ON their benches: a seat is a walkable node
		-- and the villager stands on top of it, which is why y is 2.
		socket("crossing_idle_west", "idle", -7, 2, 4, 2, {tags = {"bench"}})
		socket("crossing_idle_east", "idle", 5, 2, 4, 2, {tags = {"bench"}})
		socket("plaza_idle", "idle", PLAZA.x2 - 2, 1, PLAZA.z1 + 2, 3,
			{tags = {"work"}})
		socket("forecourt_idle", "idle", 5, 1, -24, 3, {tags = {"door"}})
		-- Two SPARE spots. `spawn = false` is the sockets contract's own word
		-- for them (section 6): a real authored standing position that reaches
		-- every consumer and that NOBODY IS PLACED ON, so a villager's amble
		-- has somewhere to go that is not another villager's doorstep. No tag:
		-- a tag is what the spoken line and the facing rule read, and a spare
		-- has neither a line nor a door.
		socket("shore_walk_north", "idle", -18, 1, 40, 0, {spawn = false})
		socket("shore_walk_south", "idle", -18, 1, 8, 2, {spawn = false})

		-- 11b. GROUND COVER GIVES WAY TO A STANDING POSITION.
		--
		-- `dressing.basin_flora` plants on any column whose ground is wild soil
		-- and whose first course is free -- and a socket's feet cell is exactly
		-- a column whose first course is free. A tuft of grass in it is a
		-- socket with no headroom, which is the defect the Highcourt fill wrote
		-- down ("nothing authored there may land on a standing position") and
		-- solved by authoring its fields row by row. This composition scatters
		-- over the whole pad instead, so it takes the cover back off the
		-- sockets afterwards -- and ONLY the cover: anything else standing in a
		-- socket is a defect, and the KAT still refuses it.
		local uncovered = 0
		do
			local COVER = {}
			for _, role in ipairs({"undergrowth", "fern", "grass_tuft",
					"flower", "flower_alt"}) do
				local name = timber.maybe(role)
				if name then COVER[name] = true end
			end
			for _, entry in ipairs(sockets) do
				for _, level in ipairs({entry.y, entry.y + 1}) do
					local cell = buf:at(entry.x, level, entry.z)
					if cell ~= nil and COVER[cell.name] then
						buf:put(entry.x, level, entry.z, parts.AIR, 0)
						uncovered = uncovered + 1
					end
				end
			end
		end

		-- 12. Pane shapes, settled once over the finished pad.
		parts.resolve_panes(buf)

		-- 13. Canonical cell list, bounds and palette.
		-- AIR CELLS STAY IN THE LIST. A settlement blueprint's air is what
		-- clears the terrace out of a doorway, and every start and both shipped
		-- capitals carry theirs. What does NOT stay is anything -- air most of
		-- all -- that landed in a lagoon or ravine column without being
		-- authored there: an air cell over the cenote is a hole in the lake.
		local source, count = buf:cells()
		local cells = {}
		for index = 1, count do
			local cell = source[index]
			local masked = mask.lagoon(cell.x, cell.z) or
				mask.ravine(cell.x, cell.z)
			if not masked or
					over_water[cell.x .. ":" .. cell.y .. ":" .. cell.z] then
				cells[#cells + 1] = cell
			end
		end
		table.sort(cells, function(a, b)
			if a.z ~= b.z then return a.z < b.z end
			if a.y ~= b.y then return a.y < b.y end
			return a.x < b.x
		end)
		local light_names = {[timber.node("light_post")] = true,
			[timber.node("light_wall")] = true,
			[timber.node("light_indoor")] = true}
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

		for _, entry in ipairs(sockets) do
			local dx, dz = parts.facedir_step(entry.face)
			entry.dir = {x = dx, z = dz}
		end

		local destinations = {}
		for _, id in ipairs(DESTINATION_ORDER) do
			local spot = inside_by_id[id]
			if not spot then
				error("wp13 kezamba: destination " .. id .. " is missing", 0)
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
			error("wp13 kezamba: no door for " .. id, 0)
		end

		return {
			schema = SCHEMA,
			cells = cells,
			bounds = {min = minp, max = maxp},
			palette = palette_list,
			landmarks = {
				arrival = {x = 0, y = 1, z = 0},
				gate_south = {x = 0, y = 1, z = -RADIUS},
				gate_north = {x = 0, y = 1, z = RADIUS},
				gate_east = {x = RADIUS, y = 1, z = 0},
				gate_west = {x = -RADIUS, y = 1, z = 0},
				main_street = {min = {x = -2, y = 0, z = -RADIUS},
					max = {x = 2, y = 5, z = 2}},
				avenue_south = {min = {x = -2, y = 0, z = -RADIUS},
					max = {x = 2, y = 5, z = 2}},
				avenue_north = {min = {x = -2, y = 0, z = 3},
					max = {x = 2, y = 5, z = RADIUS}},
				avenue_west = {min = {x = -RADIUS, y = 0, z = -2},
					max = {x = -3, y = 5, z = 2}},
				avenue_east = {min = {x = 3, y = 0, z = -2},
					max = {x = RADIUS, y = 5, z = 2}},
				waypoint_plaza = {min = {x = PLAZA.x1 + 1, y = 0,
						z = PLAZA.z1 + 1},
					max = {x = PLAZA.x2 - 1, y = 4, z = PLAZA.z2 - 1}},
				cenote = {min = {x = -16, y = -2, z = -8},
					max = {x = RADIUS, y = 1, z = RADIUS}},
				kings_hall = box("kings_hall", 2, 2),
				kings_hall_door = door_of("kings_hall"),
				moot_house = box("moot_house", 1, 1),
				shrine = box("shrine", 2, 2),
				destinations = destinations,
				doors = doorways,
				rooms = rooms,
				lights = lights,
				sockets = sockets,
				crates = crates,
				uncovered = uncovered,
				benches = benches,
				lamps_placed = lamps_placed,
				pad_columns = pad_columns,
				lagoon_columns = lagoon_columns,
				ravine_columns = ravine_columns,
				boardwalk = boardwalk,
				piers = piers,
				quay = quay,
				rim = rim,
				bridge = bridge,
				totems = totems,
				emergents = emergents,
				canopy = canopy,
				cleaned = cleaned,
			},
		}
	end

	-- The overlay seam: the run list in authored order -- avenues first, then
	-- the ring street, then the four gate thresholds -- and the one function
	-- that turns a run into cells. The successor's first-run-wins arbitration
	-- reads this order, so the road wins the cells of its own carriageway where
	-- it passes between a threshold's posts.
	function M.overlay_runs()
		local runs = {}
		for _, list in ipairs({M.avenues, M.ring, M.gates}) do
			for index = 1, #list do runs[#runs + 1] = list[index] end
		end
		return runs
	end

	-- Every node name either kind of run may write, byte-sorted and without
	-- duplicates: the road's vocabulary, the threshold's, and the RAILING the
	-- lake rail below adds, which belongs to neither module and would otherwise
	-- only fail on the first mapchunk that crossed the water.
	function M.overlay_names(avenue, palette)
		local seen, list = {}, {}
		for _, source in ipairs({avenue.palette_names(palette),
				gates.palette_names(palette), {palette.node("railing")}}) do
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

	-- THE LAKE RAIL AND THE CAUSEWAY RAIL, which are one rule with two halves.
	--
	-- The seam hands an overlay the WALKABLE surface of a column, which over
	-- water is the water's own surface (`r7_settlement.lua`), so the east and
	-- north avenues cross the cenote as a solid causeway one node over it. That
	-- is the right geometry and the wrong picture for a troll capital: what
	-- belongs there is a railed timber walk. And where the road leaves the lake
	-- it runs down the blend from the flat civic pad to the terraces, which
	-- falls faster than a one-Lipschitz road may descend, so the avenue leaves
	-- the ground on an embankment with nothing at its edge -- the same thing the
	-- first engine pass of Dur Brannoc found and the seam package called "the
	-- causeway has no parapet".
	--
	-- `avenue.lua` is NOT where either goes: it is the shared road module and
	-- Highcourt's and Dur Brannoc's built roads are frozen against it. Both go
	-- here, as a pure function of the piece the road module just returned and of
	-- the COMMITTED LAKE MASK:
	--
	--   * the two KERB lanes are the road's outermost, at `at +- half`;
	--   * a kerb column inside the mask is a column of road standing on the
	--     cenote, and gets a rail;
	--   * a kerb column whose cells span `RAIL_FILL` or more courses is a column
	--     the road had to FILL, which is exactly where the drop is, and gets one
	--     too. Three courses and not two, for Dur Brannoc's reason: a column one
	--     or two above its own ground is a terrace stair, and a rail on every
	--     tread would turn the ordinary road into a trench.
	--
	-- Both inputs are chunk-independent -- a piece of a run is exactly that
	-- stretch of the whole run, and the mask is a constant -- so the rail is
	-- too, which is what the KAT's cut-at-every-column test proves.
	local RAIL_FILL = 3
	local function lake_rail(palette, spec, piece)
		local width = spec.width
		if type(width) ~= "number" or width % 2 ~= 1 then
			error("wp13 kezamba: the overlay run has no carriageway", 0)
		end
		local half = (width - 1) / 2
		local kerb_a, kerb_b = spec.at - half, spec.at + half
		local low, high, order = {}, {}, {}
		for index = 1, #piece.cells do
			local cell = piece.cells[index]
			local across = (spec.axis == "x") and cell.z or cell.x
			if across == kerb_a or across == kerb_b then
				local key = cell.x .. ":" .. cell.z
				if high[key] == nil then
					low[key], high[key] = cell.y, cell.y
					order[#order + 1] = {key = key, x = cell.x, z = cell.z}
				else
					if cell.y < low[key] then low[key] = cell.y end
					if cell.y > high[key] then high[key] = cell.y end
				end
			end
		end
		local name = palette.node("railing")
		local added, over_water = 0, 0
		for index = 1, #order do
			local column = order[index]
			local wet = mask.lagoon(column.x, column.z)
			if wet or high[column.key] - low[column.key] >= RAIL_FILL then
				piece.cells[#piece.cells + 1] = {x = column.x,
					y = high[column.key] + 1, z = column.z, name = name,
					param2 = 0}
				added = added + 1
				if wet then over_water = over_water + 1 end
			end
		end
		piece.rail = added
		piece.rail_over_water = over_water
		piece.rail_fill = RAIL_FILL
		return piece
	end

	function M.overlay_run(avenue, palette, spec, surface)
		local plan = M.gate_plan[spec.id]
		if plan then return gates.run(palette, spec, surface, plan) end
		return lake_rail(palette, spec, avenue.run(palette, spec, surface))
	end

	return M
end

return loader
