-- Lethariel: the elf capital, the second OPEN capital of the game, and the
-- only one of the six that stands on a lake.
--
-- This file is the CORE composition of docs/research/wp13-capitals-pois-
-- contract.md section 2.1 -- the 96 x 96 civic core, anchor-relative exactly
-- like a start, inside the contract's bounds of x/z [-47, 47] and y [-2, 40] --
-- plus the run specifications the two OVERLAY modules turn into the avenues,
-- the ring street and the grove edge.
--
-- The contract's section 2.4 elf row is "silverwood and marble, tall narrow
-- halls, colonnades, lantern-lit walks, groves between plots, no curtain
-- wall", and its section 4 makes Lethariel one of the two capitals with an
-- open edge. The Silverleaf palette is the city, marble is the signature, and
-- the castle kit appears only where it reads elven: pillars and paving.
--
-- THE MERE, and why this core is not a square.
-- -------------------------------------------
-- WP40 fits and flattens the 96 x 96 civic core at the anchor's own height --
-- and then leaves the lake that was already there. Measured offline on the two
-- gate seeds and on the user's seed, and identical on all three because a
-- planned water body is a property of the static world plan and not of the
-- seed: 1 393 of the 9 409 columns inside +-47 are `planned_water`, in ONE
-- contiguous wedge whose tip is at (0, 22) and which widens northward to the
-- pad's own north-east corner. The lake surface stands some thirteen nodes
-- BELOW the core's ground course.
--
-- A composition that laid its pad across that wedge would hang a one-node
-- slab of turf thirteen nodes over open water, and no blueprint can reach
-- down to meet it: the core's authorized volume starts at y = -2. So this
-- composition DOES NOT WRITE THERE. The wedge is committed as `MERE` below
-- with a one-node margin, everything the core lays is masked against it, and
-- what the player gets is the thing the ground already was: a civic terrace
-- above a mere, with a marble quay along its edge.
--
-- The four avenues run to the gate stations exactly as every capital's do.
-- The north avenue crosses the lake, which needs no code at all: the seam
-- hands a road the WATER surface where water stands rather than the bed under
-- it (`r7_settlement.lua`, `walkable_values`), so `avenue.lua` builds a solid
-- CAUSEWAY at the water line. The east avenue crosses the same lake's southern
-- arm for the same reason.
--
--   * `M.core()` returns the core composition in the exact shape of a start
--     composition (schema, canonical cells, bounds, sorted palette, landmarks)
--     plus `landmarks.sockets`, the NPC seam of
--     docs/research/wp13-npc-sockets-contract.md.
--   * `M.district` is the market district, kept for the tools that ask a
--     capital for "a" district; the four are `lethariel_districts.lua`.
--   * `M.avenues`, `M.ring` are the runs `avenue.lua` turns into pavement and
--     `M.edge` the four runs `elf_grove.lua` turns into the grove belt that
--     stands where another capital has a curtain wall.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local buildings = dofile(directory .. "/buildings.lua")(directory)
	local capitals = dofile(directory .. "/capitals.lua")(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local layout = dofile(directory .. "/layout.lua")(directory)
	local precinct_ring = dofile(directory .. "/precinct_ring.lua")
	local elf = dofile(directory .. "/elf_parts.lua")(directory)
	local grove = dofile(directory .. "/elf_grove.lua")(directory)
	local districts = dofile(directory .. "/lethariel_districts.lua")(directory)
	local street_plan = dofile(directory .. "/street_plan.lua")(directory)

	local M = {}

	local RADIUS = 49
	local SCHEMA = "grug_wp13_lethariel_core_v1"

	-- The city's own patrol loop.
	local WATCH = "lethariel_watch"

	-- THE MERE, as the static world plan draws it inside the core pad: for
	-- every z from the tip northward, the first and last x of the water.
	-- Measured by `tools/wp13/lethariel_plots.lua --shore`, which reads the
	-- same `water_class_at` the engine does and re-checks this table on all
	-- nine seeds of the capital anchor fixture.
	--
	-- It is committed as DATA and not derived, because a blueprint is a fixed
	-- cell list built once at load with no world to ask. The fixture is what
	-- keeps the data honest: the day WP40 moves this lake, the fixture says so
	-- and this table is re-taken, exactly as the built-road digests are.
	local MERE_FIRST = 22
	local MERE = {
		[22] = {0, 0}, [23] = {-8, 8}, [24] = {-12, 12}, [25] = {-14, 14},
		[26] = {-16, 16}, [27] = {-18, 18}, [28] = {-20, 20},
		[29] = {-21, 21}, [30] = {-23, 23}, [31] = {-24, 24},
		[32] = {-25, 25}, [33] = {-26, 26}, [34] = {-27, 27},
		[35] = {-28, 28}, [36] = {-29, 29}, [37] = {-30, 30},
		[38] = {-30, 32}, [39] = {-31, 34}, [40] = {-32, 35},
		[41] = {-32, 37}, [42] = {-33, 39}, [43] = {-33, 40},
		[44] = {-34, 42}, [45] = {-34, 44}, [46] = {-35, 46},
		[47] = {-35, 47}, [48] = {-36, 49}, [49] = {-36, 49},
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

	-- Where the NORTH AVENUE takes over from the pad. The causeway across the
	-- mere is the overlay's, it starts at z = 22, and the seam forbids a core
	-- cell and an overlay cell in the same place (the integration fixture
	-- asserts it for every settlement), so the pad lays nothing inside the
	-- run's own seven-lane band from that row northward.
	local CAUSEWAY_FROM = 22
	local CAUSEWAY_HALF = 3

	-- Ground the CORE itself may lay: dry, and not the causeway's.
	local function pad(x, z)
		if z >= CAUSEWAY_FROM and math.abs(x) <= CAUSEWAY_HALF then
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

	-- The civic roof and the two handles, from this capital's own parts file.
	local handles = elf.handles()

	-- The travel plaza reserved for WP17: kerbed, lit from its own kerb and
	-- empty of everything above its paving.
	local PLAZA = {x1 = 18, z1 = -20, x2 = 32, z2 = -8}

	-- The QUAY: the marble promenade along the mere's edge. It is authored as
	-- a band that follows the committed shore rather than as a rectangle,
	-- because the shore is a diagonal.
	local QUAY_WIDTH = 3

	local STREETS = {
		-- The throne approach, from the south gate through the crossing.
		{-2, -RADIUS, 2, 4, "avenue"},
		-- The quay approach, from the crossing north to the head of the
		-- causeway. It stops at the last dry row on the axis: the causeway
		-- itself is the north avenue's, and it starts in the water.
		{-2, 5, 2, 20, "avenue"},
		-- The east-west avenue, gate to gate through the same crossing.
		{-RADIUS, -2, RADIUS, 2, "avenue"},
		-- The hall's forecourt and the flank lane past it.
		{-9, -24, -5, -6, "lane"},
		{-38, -42, -34, -40, "lane"},
		-- The market walk, the booth row on it and the plaza approach.
		{4, -25, 30, -23, "lane"},
		{2, -25, 4, -14, "lane"},
		{18, -22, 20, -20, "lane"},
		-- The west quarter's walks: the star hall's doorstep and the fountain
		-- court.
		{-40, 5, -36, 9, "lane"},
		{-35, 7, -31, 9, "lane"},
		{-30, 12, -21, 14, "lane"},
		-- The east quarter's walk to the sacred grove and the shrine.
		{6, 8, 24, 10, "lane"},
		{26, 5, 28, 8, "lane"},
		-- The doorsteps of the outer houses.
		{-46, 27, -38, 29, "lane"},
		{-44, -20, -42, -18, "lane"},
		{40, -40, 42, -38, "lane"},
		{-16, -44, -14, -42, "lane"},
	}

	-- The plot roster. `make` is the generator, `module` the library it comes
	-- from, `x`/`z` the pad anchor of the rotated footprint, `turns` the
	-- rotation, `palette` and `roof` which handle it is built and roofed with.
	--
	-- `drop` and `recast` are the socket policy of the sockets contract: a
	-- part cannot know how many of a thing a CAPITAL may have -- one throne,
	-- one travel pad for WP17, one vendor per kind.
	local PLOTS = {
		-- 1. THE HALL OF THE SILVER BOUGHS, the king's hall. It stands WEST of
		-- the throne approach with its great door on the east, and not north
		-- of the crossing where Highcourt and Dur Brannoc put theirs, because
		-- north of the crossing at Lethariel is the mere: the dry ground on
		-- the axis runs out at z = 21 and a 36-node hall does not fit in it.
		-- So the approach is the SOUTH avenue and the hall looks across it.
		{id = "kings_hall", module = "capitals", make = "king_hall",
			x = -41, z = -40, turns = 3, palette = "pale", roof = "pale",
			spec = {w = 31, d = 27, rise = 7},
			drop = {waypoint = true}},

		-- 2. The three inner gates. Lethariel has no curtain wall, so these
		-- are the civic precinct's own gates and the fourth "gate" is the
		-- quay: the north avenue leaves the pad over water.
		{id = "gate_south", module = "capitals", make = "gatehouse",
			x = -6, z = -RADIUS, turns = 0, palette = "pale", roof = "pale",
			spec = {patrol_group = "lethariel_gate_south_tower",
				deck_group = "lethariel_gate_south_tower", order = 2}},
		{id = "gate_west", module = "capitals", make = "gatehouse",
			x = -RADIUS, z = -6, turns = 1, palette = "pale", roof = "pale",
			spec = {patrol_group = "lethariel_gate_west_tower",
				deck_group = "lethariel_gate_west_tower", order = 2}},
		{id = "gate_east", module = "capitals", make = "gatehouse",
			x = 43, z = -6, turns = 3, palette = "pale", roof = "pale",
			spec = {patrol_group = "lethariel_gate_east_tower",
				deck_group = "lethariel_gate_east_tower", order = 2}},

		-- 3. The market square, east of the approach in the south quarter.
		{id = "market", module = "capitals", make = "market_square",
			x = 14, z = -46, turns = 0, palette = "elf",
			spec = {size = 21},
			drop = {waypoint = true},
			-- A booth without a trader is a flair NPC's work spot, and its id
			-- has to say booth: `market_vendor_1` with the role `idle` is a
			-- socket that argues with itself.
			recast = {vendor = {role = "idle", tags = {"work"},
				from = "_vendor_", to = "_booth_"}}},

		-- 4. The two colonnades flanking the throne approach -- the
		-- contract's own word for this race, and the piece that makes the
		-- approach a processional rather than a road.
		{id = "colonnade_west", module = "capitals", make = "colonnade",
			x = -9, z = -31, turns = 1, palette = "pale",
			spec = {len = 15, patrol_group = WATCH, order = 1}},
		{id = "colonnade_east", module = "capitals", make = "colonnade",
			x = 6, z = -31, turns = 3, palette = "pale",
			spec = {len = 15, patrol_group = WATCH, order = 6}},

		-- 5. The civic furniture: the king's statue north-east of the
		-- crossing and the fountain court in the west quarter.
		{id = "statue", module = "capitals", make = "statue_plinth",
			x = 6, z = 4, turns = 0, palette = "pale", spec = {}},
		{id = "fountain_court", module = "capitals", make = "well_court",
			x = -44, z = 8, turns = 0, palette = "pale", spec = {size = 11}},

		-- 6. THE HALL OF STARS: the capital library's temple, in the west
		-- quarter, and where this capital's core quest shell stands.
		{id = "star_hall", module = "capitals", make = "temple",
			x = -31, z = 6, turns = 0, palette = "pale", roof = "pale",
			spec = {w = 13, d = 19, wall_h = 7, rise = 5},
			-- The temple publishes its own quest shell, and a capital has
			-- exactly one. It is MOVED AND RETAGGED: `capitals.temple` stands
			-- it three nodes inside its own door, in the nave, where a
			-- shrine's keeper belongs and a quest-giver does not. The user's
			-- playtest-round-2 ruling is that the elder stands on the doorstep
			-- and shows the street his face, so this plot puts him one node
			-- outside the door on the temple walk and tags him `door`.
			socket_overrides = function(placed)
				return {star_hall_quest = {x = placed.x + 6,
					z = placed.z - 1, face = 0, tags = {"door"}}}
			end},

		-- 7. THE SACRED GROVE, the east quarter and this capital's signature:
		-- standing silverwood inside the civic core, which is what the WP40
		-- profile `terraced_grove` means when a city is built in it.
		{id = "sacred_grove", module = "capitals", make = "grove",
			x = 25, z = 8, turns = 0, palette = "elf",
			spec = {size = 17, kind = "columnar", height = 9}},
		-- The shrine at the head of the grove walk.
		{id = "mere_shrine", module = "elf", make = "shrine",
			x = 16, z = 12, turns = 0, palette = "pale",
			spec = {size = 9, rise = 5}},

		-- 8. Two BOUGH HOUSES: the tree platforms of this race, one either
		-- side of the city.
		{id = "bough_west", module = "elf", make = "tree_platform",
			x = -16, z = 8, turns = 0, palette = "elf",
			spec = {size = 11, deck = 7, wall_h = 3}},
		{id = "bough_east", module = "elf", make = "tree_platform",
			x = 34, z = -22, turns = 0, palette = "elf",
			spec = {size = 11, deck = 6, wall_h = 3}},

		-- 9. The citizens' quarter: four houses on the outer ground. The
		-- cottages keep the generator's own door side (`z-`) and are TURNED
		-- to face their ground instead: the `home` kit furnishes the cell
		-- behind every other wall and only the z- doorway is authored clear
		-- of it.
		{id = "quay_house", module = "buildings", make = "cottage",
			x = -43, z = 25, turns = 1, palette = "elf",
			spec = {w = 9, d = 9, wall_h = 5, roof = "gable",
				ridge_axis = "z", infill = true, shutters = true}},
		{id = "south_house", module = "buildings", make = "cottage",
			x = 38, z = -46, turns = 1, palette = "elf",
			spec = {w = 9, d = 9, wall_h = 5, roof = "hip",
				infill = true, shutters = true}},
		{id = "plaza_house", module = "buildings", make = "cottage",
			x = 38, z = -34, turns = 1, palette = "elf",
			spec = {w = 9, d = 9, wall_h = 5, roof = "saltbox",
				ridge_axis = "x", infill = true, fancy_bed = true}},
		{id = "shore_house", module = "buildings", make = "cottage",
			x = -46, z = 37, turns = 3, palette = "elf",
			spec = {w = 9, d = 9, wall_h = 5, roof = "gable",
				ridge_axis = "x", infill = true, shutters = true}},

	}

	-- Destination order is part of the consumer contract and never changes.
	local DESTINATION_ORDER = {"kings_hall", "gate_south", "gate_west",
		"gate_east", "star_hall", "bough_west", "bough_east", "quay_house",
		"south_house", "plaza_house", "shore_house"}

	-- The corner waypoints of the city loop, in the open ground between the
	-- outer plots.
	-- The corner waypoints of the city loop. They stand ON THE GREAT STREETS
	-- and not on the turf between the quarters, which is where the first
	-- version put them: this core is crowded -- a 32 x 36 king's hall, a
	-- twenty-one-node market and a seventeen-node sacred grove -- and three of
	-- the four landed inside a building. A paved cell is one the composition
	-- itself cleared, so a waypoint on one is a waypoint an NPC can stand on.
	local CORNERS = {
		{id = "watch_south_west", x = -2, z = -36, face = 0, order = 2},
		{id = "watch_west", x = -36, z = 2, face = 2, order = 3},
		{id = "watch_quay", x = 2, z = 16, face = 2, order = 4},
		{id = "watch_south_east", x = 36, z = -2, face = 0, order = 5},
	}

	-- Where the four avenues and the ring street run in the 512 envelope.
	-- These are not cells: they are the runs `avenue.lua` projects onto
	-- whatever surface the terrain has when a chunk is emerged.
	--
	-- THE NORTH RUN STARTS AT 22 AND NOT AT 48. Every other capital's avenues
	-- start one node clear of the core's own edge because the core paves the
	-- ground inside it. Lethariel's core cannot: the axis is under water from
	-- z = 22, and a run that began at 48 would leave the twenty-six nodes
	-- between the quay and the open lake as a hole in the road. The run
	-- therefore starts one node past where the composition's own paving
	-- stops -- the two may not share a cell, which the integration fixture
	-- asserts for every settlement -- and
	-- `avenue.lua`'s one-Lipschitz envelope walks it down from the civic
	-- terrace to the water line and out across the mere as a causeway.
	--
	-- They reach 261 and not the gate station at 256 so that the road runs a
	-- little past the threshold rather than stopping inside it, which is the
	-- same number Highcourt and Dur Brannoc use for their gates.
	local GATE_OUT = 261
	M.avenues = {
		{id = "avenue_south", axis = "z", at = 0, from = -GATE_OUT, to = -(RADIUS + 1),
			gate = "gate_south"},
		{id = "avenue_north", axis = "z", at = 0, from = 22, to = GATE_OUT,
			gate = "gate_north"},
		{id = "avenue_west", axis = "x", at = 0, from = -GATE_OUT, to = -(RADIUS + 1),
			gate = "gate_west"},
		{id = "avenue_east", axis = "x", at = 0, from = RADIUS + 1, to = GATE_OUT,
			gate = "gate_east"},
	}

	-- The ring street at 96, which the district plots stand along. Every run
	-- spans the full -96..96 so the circuit closes at all four corners; the
	-- north and east sides cross the mere and are causeways there, for the
	-- same reason the north avenue is.
	M.ring = {
		{id = "ring_west", axis = "z", at = -96, from = -96, to = 96},
		{id = "ring_east", axis = "z", at = 96, from = -96, to = 96},
		{id = "ring_south", axis = "x", at = -96, from = -96, to = 96},
		{id = "ring_north", axis = "x", at = 96, from = -96, to = 96},
	}

	-- WHERE A ROAD RUN CROSSES THE MERE, and why this capital no longer says.
	--
	-- The seam hands a road the WATER surface where water stands rather than
	-- the bed under it, so the first `avenue.lua` laid a solid CAUSEWAY at the
	-- water line: measured by `tools/wp13/lethariel_plots.lua --bodies`, the
	-- mere is ONE body of 38 527 columns and the six road runs that cross it
	-- paved 2 410 of them, cutting it into SIX lakes -- the north avenue alone
	-- shearing a two-thousand-column bay off the main water. The independent
	-- review of 2026-09-16 found it and the coordinator ruled that a water body
	-- stays one body, and this capital answered with a hand-measured span table
	-- and a bridge module of its own.
	--
	-- Playtest 5 turned that answer into a rule for all six capitals: the user
	-- saw the piers and the rails here and asked for them "in Highcourt (and
	-- every other city where it is missing)". So the bridge is `wp13/avenue.lua`
	-- now, the seam publishes whether a column is water the same way it already
	-- published the ground and the route deck (`wp40/r7_settlement.lua`,
	-- `walkable_values`), and the span table is gone: it said what the world
	-- plan already knew, and a second authority for where the lake is could only
	-- ever drift from the first.

	-- THE GROVE EDGE, on the four edges of the 512 envelope, and the four
	-- THRESHOLDS on the gate axes. This is what an OPEN capital has in place
	-- of a curtain wall (contract section 4): a planted belt that says where
	-- the city ends without shutting it, and a pair of marble pillars at each
	-- of the four points Lane R ends its routes at.
	--
	-- Authored exactly the way a wall run is, and for the same geometric
	-- reasons: the z-runs reach 261 so a corner piece is whole and the x-runs
	-- stop at 252, one node short of it, so the two never write into each
	-- other -- the successor's first-run-wins arbitration would otherwise
	-- decide which half of a corner survives.
	local EDGE_AT = 256
	local EDGE_END = 261
	local EDGE_SIDE = 252
	M.edge = {
		{id = "edge_west", axis = "z", at = -EDGE_AT,
			from = -EDGE_END, to = EDGE_END},
		{id = "edge_east", axis = "z", at = EDGE_AT,
			from = -EDGE_END, to = EDGE_END},
		{id = "edge_south", axis = "x", at = -EDGE_AT,
			from = -EDGE_SIDE, to = EDGE_SIDE},
		{id = "edge_north", axis = "x", at = EDGE_AT,
			from = -EDGE_SIDE, to = EDGE_SIDE},
	}
	-- `water` is the span of a run that stands over a planned water body, and
	-- the belt writes nothing there: the water already is an edge. Measured by
	-- `tools/wp13/lethariel_plots.lua --edge` over the seven lanes of each
	-- line, on ALL NINE seeds of `capital_anchor_fixture.lua`, and identical on
	-- every one of them -- a planned water body is a property of the static
	-- world plan and not of the seed. Only the west line has one.
	M.edge_plan = {
		edge_west = {outside = -1, gates = {0}, corners = {-EDGE_AT, EDGE_AT},
			water = {{-143, -80}}},
		edge_east = {outside = 1, gates = {0}, corners = {-EDGE_AT, EDGE_AT},
			water = {}},
		edge_south = {outside = -1, gates = {0}, corners = {}, water = {}},
		edge_north = {outside = 1, gates = {0}, corners = {}, water = {}},
	}

	M.district = districts.districts[1]
	M.districts = districts

	function M.core()
		local elf_palette = handles.elf
		local pale = handles.pale
		local by_handle = {elf = elf_palette, pale = pale}
		local buf = parts.buffer()
		local doorways, rooms, sockets = {}, {}, {}
		local placed, inside_by_id, plot_order = {}, {}, {}
		local claimed = {}

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
		local laid, water, causeway = 0, 0, 0
		for z = -RADIUS, RADIUS do
			for x = -RADIUS, RADIUS do
				if pad(x, z) then
					buf:put(x, -1, z, elf_palette.node("subsoil"))
					buf:put(x, 0, z, elf_palette.node("ground"))
					laid = laid + 1
				elseif dry(x, z) then
					causeway = causeway + 1
				else
					water = water + 1
				end
			end
		end
		for z = -34, 34, 4 do
			for x = -34, 34, 7 do
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
		for _, kerb in ipairs({{-3, -RADIUS, -3, 20}, {3, -RADIUS, 3, 20},
				{-RADIUS, -3, RADIUS, -3}, {-RADIUS, 3, RADIUS, 3}}) do
			for z = kerb[2], kerb[4] do
				for x = kerb[1], kerb[3] do
					if dry(x, z) then buf:put(x, 0, z, KERB) end
				end
			end
		end

		-- 3. THE QUAY: a marble promenade following the mere's own edge, one
		-- node of natural shore outside it, with a low kerb on the water side
		-- so a citizen walking it does not walk off it. It is written from
		-- the committed shore table, so it is the same diagonal the lake is.
		local quay = 0
		for z = MERE_FIRST, RADIUS do
			local span = MERE[z]
			for _, side in ipairs({-1, 1}) do
				local edge = (side < 0) and (span[1] - SHORE_MARGIN - 1) or
					(span[2] + SHORE_MARGIN + 1)
				for step = 0, QUAY_WIDTH - 1 do
					local x = edge - side * step
					-- Never inside the north avenue's own band: that run
					-- starts at z = 22 and the two may not share a cell (the
					-- integration fixture asserts it for every settlement).
					if x >= -RADIUS and x <= RADIUS and dry(x, z) and
							math.abs(x) > 3 then
						buf:put(x, 0, z, (step == 0) and KERB or AVENUE)
						buf:clear(x, 1, z, x, 4, z)
						quay = quay + 1
					end
				end
			end
		end
		-- The quay's own head on the axis, where the causeway leaves the pad.
		for z = 18, 21 do
			for x = -6, 6 do
				if dry(x, z) then
					buf:put(x, 0, z, AVENUE)
					buf:clear(x, 1, z, x, 5, z)
					quay = quay + 1
				end
			end
		end

		-- 4. The travel plaza: paving, two kerb rings and nothing inside it.
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

		-- 5. The plots.
		for _, plot in ipairs(PLOTS) do
			local spec = {}
			for key, value in pairs(plot.spec) do spec[key] = value end
			spec.id = plot.id
			if plot.roof then spec.roof_palette = by_handle[plot.roof] end
			local module = capitals
			if plot.module == "buildings" then module = buildings end
			if plot.module == "elf" then module = elf end
			local generator = module[plot.make]
			if type(generator) ~= "function" then
				error("wp13 lethariel: no generator " .. plot.make, 0)
			end
			local part = generator(by_handle[plot.palette], spec)
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
						out.activity = nil
						if recast.from then
							out.id = out.id:gsub(recast.from, recast.to, 1)
						end
					end
					sockets[#sockets + 1] = out
				end
			end
		end

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
				{-6, -12}, {6, -12}, {-6, -36}, {6, -36},
				{-14, -6}, {14, -6}, {-14, 6}, {18, 6}, {22, 6},
				{-24, -6}, {24, -6}, {-36, -6}, {36, -6}, {-36, 6}, {36, 6},
				{-6, 16}, {6, 16}, {-6, 20}, {6, 20}, {16, -16}}) do
			if dry_area(spot[1] - 1, spot[2] - 1, spot[1] + 1, spot[2] + 1) and
					layout.free_area(buf, spot[1] - 1, spot[2] - 1,
						spot[1] + 1, spot[2] + 1, 5) then
				dressing.lantern_pillar(buf, elf_palette, spot[1], spot[2])
				lanterns = lanterns + 1
			end
		end
		-- The quay's own lantern line, on its landward kerb.
		for z = MERE_FIRST + 4, RADIUS - 2, 6 do
			local span = MERE[z]
			for _, side in ipairs({-1, 1}) do
				local edge = (side < 0) and (span[1] - SHORE_MARGIN - 3) or
					(span[2] + SHORE_MARGIN + 3)
				if edge >= -RADIUS + 1 and edge <= RADIUS - 1 and
						math.abs(edge) > 4 and
						dry_area(edge - 1, z - 1, edge + 1, z + 1) and
						layout.free_area(buf, edge - 1, z - 1, edge + 1,
							z + 1, 5) then
					dressing.lantern_pillar(buf, elf_palette, edge, z)
					lanterns = lanterns + 1
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
		}
		for _, seat in ipairs(BENCHES) do
			local x2 = (seat[4] == "x") and seat[1] + 2 or seat[1]
			local z2 = (seat[4] == "z") and seat[2] + 2 or seat[2]
			paved_prop("bench", seat[1], seat[2], x2, z2, function()
				dressing.bench(buf, elf_palette, seat[1], seat[2], seat[3], 3,
					seat[4])
			end)
		end
		for _, bed in ipairs({{-14, -3, -12, -1}, {12, 1, 14, 3}}) do
			paved_prop("planter", bed[1], bed[2], bed[3], bed[4], function()
				dressing.planter(buf, elf_palette, bed[1], bed[2], bed[3],
					bed[4])
			end)
		end

		-- 8b. THE SHORE WORKS, on the last dry rows east of the quay
		-- approach: the fish counter the mere feeds, the wood the city burns,
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
			{-10, -44, 11}, {9, -44, 11}, {-10, -37, 11}, {10, -37, 11},
			{32, -24, 11}, {13, -12, 11}, {34, -10, 11}, {41, -10, 11},
			{-32, -6, 11}, {-20, -6, 11}, {20, -6, 11}, {-10, 5, 11},
			{30, 5, 11}, {44, 9, 11}, {13, 14, 11}, {43, 16, 11},
			{-44, 20, 11}, {-37, 20, 11}, {-15, 20, 11}, {12, 21, 11},
			{19, 23, 11}, {44, 23, 11}, {34, 26, 11}, {26, 27, 11},
			{-31, 28, 11}, {41, 30, 11}, {33, 33, 11}, {40, 37, 11},
		})
		if standards < 16 then
			error("wp13 lethariel: only " .. standards ..
				" silverwood standards found open ground", 0)
		end

		-- 10. THE CORE EDGE: groves and hedges, not masonry. Lethariel's
		-- precinct is open, so its boundary is a clipped silverwood hedge with
		-- the standards of section 9 standing behind it. The protected hedge wins
		-- every dry non-gate column; only the mere itself replaces the boundary.
		local hedge = 0
		precinct_ring.walk(function(x, z)
			precinct_ring.clear_wallmounted(buf, parts, x, z, 4)
			hedge = hedge + dressing.hedge_line(buf, elf_palette,
				x, z, x, z, 3)
		end, {skip = function(x, z) return not dry(x, z) end})

		-- 11. Undergrowth on the turf between the quarters.
		dressing.undergrowth(buf, elf_palette, -RADIUS, -RADIUS, RADIUS,
			RADIUS, 5)

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
		-- The quay's own life: three anglers on the promenade looking at the
		-- mere. `fish` is capital-only and this is the capital that has a lake
		-- in its core; the water they face is the world's, one node beyond the
		-- quay's kerb, not a cell this blueprint writes.
		-- On the QUAY ITSELF, which is a diagonal: at z = 28 the mere spans
		-- x -20..20, the walk starts two nodes outside that, and a socket on
		-- the round number would have stood in the water.
		socket("quay_idle_west", "idle", -23, 1, 28, 0, {tags = {"bench"}})
		socket("quay_idle_east", "idle", 23, 1, 28, 0, {tags = {"bench"}})
		socket("quay_idle_head", "idle", -4, 1, 19, 0, {tags = {"work"}})
		socket("grove_idle_walk", "idle", 22, 1, 9, 1, {tags = {"work"}})
		socket("grove_idle_shrine", "idle", 18, 1, 11, 2, {tags = {"work"}})
		socket("forecourt_idle_west", "idle", -6, 1, -14, 1, {tags = {"bench"}})
		socket("forecourt_idle_east", "idle", 7, 1, -14, 3, {tags = {"bench"}})
		socket("market_idle_walk", "idle", 12, 1, -24, 2, {tags = {"work"}})
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
		socket("shore_work_sweep", "work", -4, 1, 19, 0, {activity = "sweep"})
		socket("crossing_work_west", "work", -5, 2, -4, 2,
			{activity = "sit", tags = {"bench"}})
		socket("crossing_work_east", "work", 5, 2, -4, 2,
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
			{"core_spare_quay_west", -28, 30, 0},
			{"core_spare_quay_east", 24, 24, 0},
			{"core_spare_approach", 5, -26, 0},
			{"core_spare_market_walk", 12, -31, 0},
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
		local source, count = buf:cells()
		local cells = {}
		for index = 1, count do cells[index] = source[index] end
		table.sort(cells, function(a, b)
			if a.z ~= b.z then return a.z < b.z end
			if a.y ~= b.y then return a.y < b.y end
			return a.x < b.x
		end)
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
				-- The north "gate" is the head of the causeway and stands on
				-- the last dry row of the axis, not on the pad edge.
				gate_north = {x = 0, y = 1, z = 20},
				main_street = {min = {x = -2, y = 0, z = -RADIUS},
					max = {x = 2, y = 5, z = 4}},
				avenue_south = {min = {x = -2, y = 0, z = -RADIUS},
					max = {x = 2, y = 5, z = 4}},
				avenue_north = {min = {x = -2, y = 0, z = 5},
					max = {x = 2, y = 5, z = 21}},
				avenue_west = {min = {x = -RADIUS, y = 0, z = -2},
					max = {x = -3, y = 5, z = 2}},
				avenue_east = {min = {x = 3, y = 0, z = -2},
					max = {x = RADIUS, y = 5, z = 2}},
				throne_approach = {min = {x = -2, y = 0, z = -30},
					max = {x = 2, y = 8, z = -6}},
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
				causeway_columns = causeway,
				lantern_pillars = lanterns,
				hedge_columns = hedge,
				standards = standards,
			},
		}
	end

	-- The overlay seam, in one place: the run list in authored order (avenues
	-- first, then the ring street, then the district lanes, then the grove
	-- edge) and the one function that turns a run into cells. The successor's
	-- first-run-wins arbitration reads this order, so the avenue runs through
	-- the threshold and the edge yields the cells of the road it lets past.
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
			{{runs = M.edge, half = grove.HALF}})
		for index = 1, #M.edge do runs[#runs + 1] = M.edge[index] end
		return runs
	end

	-- Every node name either overlay may write, byte-sorted and without
	-- duplicates: the union of the road's vocabulary and the edge's, which is
	-- what the settlement's shared content channel is closed over and what the
	-- overlay's specification identity is written from.
	function M.overlay_names(avenue, palette)
		local seen, list = {}, {}
		for _, source in ipairs({avenue.palette_names(palette),
				grove.palette_names(palette)}) do
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

	-- One run, dispatched by its own id. An edge run carries authored geometry
	-- the seam's overlay spec has no field for -- which side is the field,
	-- where the thresholds and the corner groves stand -- so it is looked up
	-- here, from the same table for every piece, which is what keeps a piece
	-- of a run exactly that stretch of the whole run.
	--
	-- THE EDGE DOES NOT OBEY THE CROSSING RULE, and this is where that is
	-- decided. The seam hands every run of an overlay an `overhead(x, z)`
	-- callback and `avenue.run` uses it to ramp a carriageway up to a WP40
	-- bridge deck. That is right for a road, whose job is to be walkable end
	-- to end, and wrong for a planted belt, which follows the ground. The spec
	-- is therefore copied field by field WITHOUT `overhead` rather than handed
	-- over and hoped about.
	function M.overlay_run(avenue, palette, spec, surface)
		local plan = M.edge_plan[spec.id]
		if not plan then
			-- A ROAD RUN, and where it crosses the mere a BRIDGE -- built by
			-- the road module itself now, out of the seam's own `wet(x, z)`.
			-- The spec goes over untouched, including the seam's `overhead`,
			-- because a road's job is to be walkable end to end.
			return avenue.run(palette, spec, surface)
		end
		return grove.run(palette, {
			id = spec.id, axis = spec.axis, at = spec.at,
			from = spec.from, to = spec.to, width = spec.width,
			lamp_spacing = spec.lamp_spacing, lamp_phase = spec.lamp_phase,
			reach = spec.reach,
		}, surface, plan)
	end

	return M
end

return loader
