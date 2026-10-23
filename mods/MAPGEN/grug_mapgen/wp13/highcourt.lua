-- Highcourt: the human capital, and the first capital of the game.
--
-- This file is the CORE composition of docs/research/wp13-capitals-pois-
-- contract.md section 2.1: the 96 x 96 civic core, anchor-relative exactly
-- like a start, flat at y = 0 by construction, inside the contract's bounds
-- of x/z [-47, 47] and y [-2, 40] (it reaches y 31, the hall's ridge
-- lantern). Its buildings are building templates (Round 56), frozen from
-- the capital and start-town generators it was first authored out of, the
-- same way Dawnmere Fields' are frozen from the latter alone.
--
-- Highcourt is the human capital of the contract's section 2.4 table: a
-- brick-and-white-stone city on a river plateau, half-timbered lanes, a
-- market square, a chapel with a belfry, and an orchard belt.
--
-- THE WALL RING ARRIVED WITH THE PLAYTEST-ROUND-3 PLAN, approved 2026-09-15.
-- Its provenance is worth spelling out, because the capitals contract says
-- something else and only one of the two is a user ruling. On 2026-09-14 the
-- USER decided three walled capitals (dwarf, undead, orc) and three open ones,
-- Highcourt among the open; the "orchards inside the wall ring" phrase in the
-- contract's section 2.4 Look column is prose about an orchard belt and is not
-- a wall decision. On 2026-09-15 the COORDINATOR's round-3 plan proposed a wall
-- ring for Highcourt -- the coordinator's reason being that an open capital
-- reads as a field with houses in it -- and the user approved the plan. So the
-- wall stands on an approved plan, not on a ruling, and the user may reverse it;
-- nothing else in this file depends on it.
--
-- The city wall is the capital planner's (Round 22): `wp13/city_edge.lua`
-- raises it on the per-world outline in Highcourt's own palette, castle
-- stonewall over brick string courses, brick merlon caps, four gatehouses on
-- the avenues. The four gatehouses that stand where the avenues leave the
-- CORE stay where they are -- they are the precinct's gates.
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
--   * the district plots are `highcourt_districts.lua`; where they stand,
--     turned to their streets, is the capital planner's per-world layout
--     (`wp40/capital_planner.lua`, `wp40/r7_capital_blueprint.lua`).
--   * the buildings are building templates (Round 56,
--     docs/technical/building-template-format.md): each PLOTS row names its
--     template and palettes, and the roster
--     `building_templates/layouts/highcourt.roster` lists the templates and
--     palettes the core and the districts place. The templates carry what
--     the core used to add to its buildings afterwards: the chapel's belfry,
--     the hall's marble floor bands, braziers and hangings, and the chapel
--     elder's doorstep.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local layout = dofile(directory .. "/layout.lua")(directory)
	local precinct_ring = dofile(directory .. "/precinct_ring.lua")
	local templates = dofile(directory .. "/templates.lua")(directory)
	local gate_watch = dofile(directory .. "/gate_watch.lua")(directory)
	local CAPITAL = templates.capital("highcourt")

	local M = {}

	local RADIUS = 49
	local SCHEMA = "grug_wp13_highcourt_core_v1"

	-- The city's own patrol loop (the sockets contract's `group`), and every
	-- waypoint in it carries its place in the walk: out along the southern
	-- orchard street, round the four corners of the open edge, back along
	-- the western orchard street and up the great avenue through the two
	-- colonnades. The four gate towers keep their own two-waypoint watches;
	-- see the gatehouse rows below for why they cannot be in this one.
	local WATCH = "highcourt_watch"

	-- The crown's white stone and the civic slate roof are palettes of the
	-- roster: `white` rebinds `signature` (the role every capital part dresses
	-- itself in: podium, string courses, merlon caps, the market cross, the
	-- statue), so one building reads as a royal one; `white_slate` puts the
	-- darkage slate family on the civic roofs as well, which has the corner
	-- shapes the rasteriser needs. `town` is the plain human palette.

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
		{-8, -(RADIUS - 7), 8, -38, "lane"},
		{-8, 38, 8, RADIUS - 7, "lane"},
		{38, -8, RADIUS - 7, 8, "lane"},
		{-(RADIUS - 7), -8, -38, 8, "lane"},
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

	-- The plot roster. `template` is the building template, `x`/`z` the pad
	-- anchor of the rotated footprint and `turns` the rotation. `palette`
	-- names the roster palette the template is built with, `roof` the one
	-- its roof channel takes.
	--
	-- `watch` marks a core gatehouse whose guards gate_watch.lua sets (Round
	-- 58): the ground guards' rectangle and the tower guard's post.
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
		-- The hall is built with the slate palette as well as roofed with it:
		-- its four lucarnes per slope take their hoods from the main
		-- palette's own `roof_slab`, so a hall built with the plain one would
		-- wear four plank hoods on a slate roof.
		{id = "kings_hall", template = "highcourt_kings_hall",
			x = -15, z = 9, turns = 0, palette = "white_slate", roof = "white_slate",
			drop = {waypoint = true}},

		-- 2. The four gatehouses. Highcourt has no curtain wall, so these
		-- are not wall towers: they are the four gates of an open city, each
		-- carrying the five-wide passage of the gate corridor and its two
		-- guard chambers. The field face of the part (its loopholes) is
		-- turned outward by the rotation.
		--
		-- Each gate keeps its own watch instead of a share of the city loop
		-- (Round 58, `watch`, gate_watch.lua): two guards walk a rectangle on
		-- the city side in opposite directions and the tower guard holds a
		-- post on the fighting top, which the east chamber's inner stair and
		-- the roof stair reach from the street.
		{id = "gate_south", template = "highcourt_gate_south", watch = true,
			x = -6, z = -RADIUS, turns = 0, palette = "white", roof = "white_slate"},
		{id = "gate_west", template = "highcourt_gate_south", watch = true,
			x = -RADIUS, z = -6, turns = 1, palette = "white", roof = "white_slate"},
		{id = "gate_north", template = "highcourt_gate_south", watch = true,
			x = -6, z = 43, turns = 2, palette = "white", roof = "white_slate"},
		{id = "gate_east", template = "highcourt_gate_south", watch = true,
			x = 43, z = -6, turns = 3, palette = "white", roof = "white_slate"},

		-- 3. The market square, west of the approach.
		{id = "market", template = "highcourt_market",
			x = -36, z = -31, turns = 0, palette = "white",
			drop = {waypoint = true},
			-- and the booth's id says booth, not vendor: an id is a string
			-- the NPC lane reads in logs, and `market_vendor_1` with the
			-- role `idle` is a socket that argues with itself.
			recast = {vendor = {role = "idle", tags = {"work"},
				from = "_vendor_", to = "_booth_"}}},

		-- 4. The two colonnades flanking the approach, turned so their
		-- walks run with it.
		{id = "colonnade_west", template = "highcourt_colonnade_west",
			x = -9, z = -21, turns = 1, palette = "white"},
		{id = "colonnade_east", template = "highcourt_colonnade_east",
			x = 4, z = -21, turns = 3, palette = "white"},

		-- 5. The civic furniture: the king's statue on the east side of the
		-- crossing, the public well court on the west.
		{id = "statue", template = "highcourt_statue",
			x = 12, z = -11, turns = 0, palette = "white"},
		{id = "well_court", template = "highcourt_well_court",
			x = -46, z = 8, turns = 0, palette = "white"},

		-- 6. The open edge, in place of a wall: a kerbed ring street, a
		-- clipped hedge with a gate gap and two rows of fruit trees, both
		-- pieces on the southern face either side of the gate. Turned so the
		-- street lies on the city side and the orchard outside it.
		--
		-- The piece is 23 x 13, not the 21 x 11 of its own footprint: the
		-- fruit trees stand ON the far row and their crowns reach three
		-- nodes, so a piece stamped hard against the pad edge puts leaves
		-- two nodes outside the core. Both are therefore inset.
		{id = "orchard_east", template = "highcourt_orchard_east",
			x = 8, z = -45, turns = 2, palette = "town"},
		{id = "orchard_west", template = "highcourt_orchard_west",
			x = -45, z = -45, turns = 2, palette = "town"},

		-- 7. The chapel with its belfry, on the west lane.
		{id = "chapel", template = "highcourt_chapel",
			x = -34, z = 20, turns = 0, palette = "town", roof = "white_slate"},

		-- 8. The household's own buildings, in the service court east of the
		-- hall: the open workyard and the store.
		{id = "service_yard", template = "highcourt_service_yard",
			x = 25, z = 7, turns = 0, palette = "town"},
		-- The store's door is at index 4 and single-leaved on purpose. The
		-- `store` interior kit stands its roof posts on the odd cells of the
		-- gable wall's inner run (x1 + 2, x1 + 4, ...), so the centred
		-- double door of an eleven-wide longhouse opens straight onto a
		-- post: the doorway is a real hole in the wall and still not a way
		-- in. Hearthpine's nine-wide store misses the post by one cell,
		-- which is why nothing caught this before a capital asked for a
		-- wider one.
		{id = "service_store", template = "highcourt_service_store",
			x = 25, z = 22, turns = 0, palette = "town"},

		-- 9. The half-timbered city: a workshop on the south lane and four
		-- houses along the outer ring.
		{id = "city_workshop", template = "highcourt_city_workshop",
			x = 31, z = -46, turns = 0, palette = "town"},
		-- The three houses keep the generator's own door side (`z-`) and are
		-- TURNED to face their lane instead. A cottage's `home` kit furnishes
		-- the cell behind every other wall -- bed corner, hearth, table --
		-- and only the z- doorway is authored clear of it, which is what
		-- every start uses; asking the same generator for a door in the gable
		-- end instead opens it onto the furniture.
		{id = "north_house", template = "highcourt_north_house",
			x = -46, z = 23, turns = 3, palette = "town"},
		{id = "lane_house", template = "highcourt_lane_house",
			x = 37, z = -17, turns = 1, palette = "town"},
		{id = "orchard_house", template = "highcourt_orchard_house",
			x = 37, z = -30, turns = 1, palette = "town"},
		{id = "chapel_house", template = "highcourt_chapel_house",
			x = -46, z = 36, turns = 3, palette = "town"},
		{id = "market_house", template = "highcourt_market_house",
			x = -46, z = -30, turns = 3, palette = "town"},
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

	-- The waypoint plaza (WP17): a flat, open, kerbed square east of the
	-- approach, with its lamps outside the open area and nothing inside it
	-- but the waystone at the pad's centre and its mailbox. Travel needs room
	-- and sky: a player arrives beside the stone.
	local PLAZA = {x1 = 12, z1 = -32, x2 = 32, z2 = -12}

	-- The city around the core -- its outline, streets, walls or planted
	-- edge, gates and the placed district plots -- is laid out per world by
	-- the capital planner (`wp40/capital_planner.lua`, `wp13/city_edge.lua`,
	-- Round 22); this file is the civic core.

	function M.core()
		local human = CAPITAL.palettes.town
		local white = CAPITAL.palettes.white
		local buf = parts.buffer()
		local doorways, rooms, sockets = {}, {}, {}
		local placed, inside_by_id, plot_order = {}, {}, {}
		local claimed, stamped = {}, {}

		-- The citadel paving of the avenues and the cobble of the lanes,
		-- each resolved the way the templates resolve it: the capital
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

		-- 3. The waypoint plaza: paving, a kerb, and only the waystone and its
		-- mailbox in it.
		pave(AVENUE, PLAZA.x1, PLAZA.z1, PLAZA.x2, PLAZA.z2, 6)
		dressing.inlay(buf, human, PLAZA.x1, PLAZA.z1, PLAZA.x2, PLAZA.z2)
		dressing.inlay(buf, human, PLAZA.x1 + 4, PLAZA.z1 + 4,
			PLAZA.x2 - 4, PLAZA.z2 - 4)
		-- The pad itself, drawn INTO the ground course: a white stone cross
		-- and the diamond round it. An empty square of paving reads as
		-- nothing at all, and the plaza may have nothing standing on it but
		-- the waystone, so the rest of its decoration is the floor.
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

		-- The waystone (Round 29, WP17) stands at the pad's centre, in the
		-- travel waypoint socket's cell; grug_home owns what it does.
		dressing.waystone(buf, pad_x, pad_z)

		-- 4. The plots.
		for _, plot in ipairs(PLOTS) do
			local part = CAPITAL.part(plot.template, plot.id, plot.palette,
				plot.roof)
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
				d = footprint.d, peak = part.peak, nave_floor = part.nave_floor}
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
			-- position of one of the composition's own sockets below.
			templates.collect_sockets(stamped, points, plot.id)
			local first = #sockets + 1
			for _, entry in ipairs(points.sockets or {}) do
				local drop = entry.role == nil or (plot.drop and plot.drop[entry.role])
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
			-- A core gatehouse's watch (Round 58, gate_watch.lua): the ground
			-- guards' rectangle on the city side and the tower guard's post.
			if plot.watch then
				gate_watch.apply(sockets, first, plot, part.w, part.d, "highcourt")
			end
		end

		-- 5. The chapel's belfry and the hall's floor, braziers and hangings
		-- are the templates' own (Round 56).

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
		-- The PRECINCT WALL (Round 23, in place of the clipped hedge that held
		-- this boundary since the core was an open capital's): the curtain's
		-- castle stonewall, one node thick on exactly the hedge's columns, so
		-- nothing else in the core moves. Two courses of stonewall, the crown's
		-- marble band at y 3 -- the course the four gatehouse piers carry at
		-- the same height, so the band runs straight into them -- and merlons
		-- at y 4 on every other column, the rhythm of the gatehouses'
		-- battlements: four courses, one more than the hedge's three.
		--
		-- It runs round the WHOLE pad rather than in four authored stretches.
		-- The ring is protected and deliberately wins every non-gate column:
		-- content already placed in the core may meet it, but may not cut it.
		-- The shared mask leaves only the four authored gatehouse bands open,
		-- so every gate passage stays as the gatehouse built it.
		local PRECINCT_STONE = human.maybe("castle_wall") or human.node("wall_accent")
		local PRECINCT_BAND = white.node("signature")
		local wall = 0
		precinct_ring.walk(function(x, z)
			precinct_ring.clear_wallmounted(buf, parts, x, z, 4)
			buf:put(x, 1, z, PRECINCT_STONE)
			buf:put(x, 2, z, PRECINCT_STONE)
			buf:put(x, 3, z, PRECINCT_BAND)
			if (x + z) % 2 == 0 then buf:put(x, 4, z, PRECINCT_STONE) end
			wall = wall + 1
		end)

		-- 10. Meadow flora on the turf between the plots.
		-- Round 51 follow-up FT: in patches and gaps, far thinner than the
		-- plain scatter (`dressing.patch_keep`; the user: too dense, too even).
		dressing.undergrowth(buf, human, -RADIUS, -RADIUS, RADIUS, RADIUS, 5,
			dressing.CORE_PATCH)

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
		-- Where it stands is a point of the chapel's template.
		do
			local spot = templates.stamped_point(stamped, "chapel_quest", "chapel",
				"highcourt")
			socket("chapel_quest", "quest", spot.x, spot.y, spot.z, spot.face,
				{tags = {"door"}})
		end
		templates.all_used(stamped, "highcourt")
		socket("travel_waypoint", "waypoint",
			math.floor((PLAZA.x1 + PLAZA.x2) / 2), 1,
			math.floor((PLAZA.z1 + PLAZA.z2) / 2), 0)
		for _, corner in ipairs(CORNERS) do
			socket(corner.id, "guard_patrol", corner.x, 1, corner.z,
				corner.face, {group = WATCH, order = corner.order})
		end
		socket("court_idle_well", "idle", 44, 1, 27, 0, {tags = {"work"}})
		-- Round 47: faced 2 (0 faced a window).
		socket("court_idle_yard", "idle", 34, 1, 20, 2, {tags = {"work"}})
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
		-- on foot from the south gate -- measured with the retired Highcourt
		-- KAT's socket test, and at least 8 nodes from every authored socket.
		-- No tag: a spare is a place to stand, not a feature to talk about.
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
		-- Round 47 town greening: the race's trees on the open wild ground.
		layout.green(buf, human, RADIUS, sockets, doorways)
		-- Round 51 follow-up FT: the ground cover thinned, now the trees stand.
		dressing.thin_cover(buf)
		local source, count = buf:cells()
		local cells = {}
		for index = 1, count do cells[index] = source[index] end
		parts.sort_cells_zyx(cells)
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
				-- "nothing inside" would have to be qualified. The waystone
				-- at its centre is the one thing standing in it.
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
				precinct_wall_columns = wall,
				nave_floor = placed.kings_hall.nave_floor,
			},
		}
	end

	return M
end

return loader
