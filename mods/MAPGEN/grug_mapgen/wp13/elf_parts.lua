-- Lethariel's own building parts and palette handles: the pieces the shared
-- WP13 library has no generator for because no capital before this one was
-- ELVEN and none before this one stood on a lake.
--
-- The capitals contract's section 2.4 elf row is "silverwood and marble, tall
-- narrow halls, colonnades, lantern-lit walks, groves between plots, no
-- curtain wall", and its section 4 makes Lethariel one of the two OPEN
-- capitals. Everything here serves one of those five words:
--
--   * `M.PALETTES` -- the capital handles. The elf palette already carries the
--     marble signature and the castle kit (`wp13/palette.lua`, the elf capital
--     block); what it does NOT carry is a hedge, water, a crop or a field gate,
--     because Silverleaf is a glade hamlet with none of those. A CAPITAL has a
--     pond its citizens fish in, garden rows its citizens hoe and a hedge
--     round its groves, so this file binds those four roles as OVERRIDES on
--     the handle rather than editing the shared palette: the six start
--     blueprints are frozen and `palettes.new(race, overrides)` is the seam
--     that exists for exactly this.
--   * `M.threshold` -- what an OPEN capital has instead of a gatehouse. A pair
--     of marble pillars carrying a lintel, a lantern on each, and the road
--     running between them: the thing Lane R's four route ends arrive at.
--   * `M.tree_platform` -- a silverwood standard carrying a railed deck and a
--     small hall on it. The WP40 profile of this capital is a TERRACED GROVE
--     and this is the one piece that says so from a distance.
--   * `M.shrine` -- an open marble shrine with an altar, which is what a `pray`
--     work socket needs a feature for (sockets contract section 8.1: the
--     socket stands OUTSIDE and the altar, candle or grave marker stands
--     within three nodes under its `dir`).
--   * `M.boat_stage` -- the fishing stage of a lakeside city: a plank deck on
--     posts over its own water, drying racks behind it.
--
-- Every generator returns a part in the exact shape `wp13/capitals.lua`
-- returns one (buffer, w, d, peak, points), so `parts.stamp` and both plot
-- builders take it without knowing it came from here.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local palettes = dofile(directory .. "/palette.lua")
	local dressing = dofile(directory .. "/dressing.lua")(directory)

	local M = {}

	-- ------------------------------------------------------------------
	-- The palette handles
	-- ------------------------------------------------------------------

	-- The civic roof: the brick cut of the same silver sandstone Silverleaf
	-- roofs its three public buildings with (`wp13/silverleaf.lua`,
	-- `PALE_ROOF`). A civic hall roofed in the domestic slate reads as a big
	-- cottage; the pale cut reads against it.
	M.PALE_ROOF = {
		roof_stair = "stairs:stair_silver_sandstone_brick",
		roof_stair_outer = "stairs:stair_outer_silver_sandstone_brick",
		roof_stair_inner = "stairs:stair_inner_silver_sandstone_brick",
		roof_slab = "stairs:slab_silver_sandstone_brick",
		roof_ridge = "default:silver_sandstone_brick",
	}

	-- The four roles a capital needs and a glade hamlet never did. Every name
	-- is one the human palette already binds, so every one of them is a node
	-- this game registers and R7's content manifest accepts.
	--
	--   `water`      the town pond's river water (playtest round 3, the only
	--                water a WP13 composition writes; `liquid_renewable =
	--                false`, `liquid_range = 2`, so a lined basin cannot leak);
	--   `hedge`/`hedge_stem`  the clipped boundary of a grove. Silverwood
	--                leaves on a silverwood stem, not default's bush: the hedge
	--                between two elf plots is the same wood the plots are built
	--                of, which is what "groves between plots" means;
	--   `crop_soil`  the tilled row of a garden. `grug_nodes:tilled_soil` is
	--                outside default's grass-spread ABM, so a field stays a
	--                field (the lesson `dressing.crop_rows` records);
	--   `crop`       what grows in it.
	M.GREEN = {
		water = "default:river_water_source",
		hedge = "grug_trees:silverwood_leaves",
		hedge_stem = "grug_trees:silverwood_tree",
		crop_soil = "grug_nodes:tilled_soil",
		crop = "default:junglegrass",
	}

	local function merged(...)
		local out = {}
		for _, source in ipairs({...}) do
			for key, value in pairs(source) do out[key] = value end
		end
		return out
	end

	-- The three handles every Lethariel composition builds from, made once per
	-- caller: `elf` is the city, `pale` is the same city under the civic roof,
	-- and both carry the four capital roles above.
	function M.handles()
		local green = M.GREEN
		return {
			elf = palettes.new("elf", green),
			pale = palettes.new("elf", merged(green, M.PALE_ROOF)),
		}
	end

	-- ------------------------------------------------------------------
	-- Shared resolvers, the same fallbacks `capitals.lua` uses
	-- ------------------------------------------------------------------

	local function stone(palette)
		return palette.maybe("castle_wall") or palette.node("wall_accent")
	end
	local function paving(palette)
		return palette.maybe("castle_paving") or palette.node("plaza")
	end
	local function mark(palette)
		return palette.maybe("signature") or palette.node("wall_accent")
	end
	local function mark_slab(palette)
		return palette.maybe("signature_slab") or palette.node("roof_slab")
	end
	local function mark_stair(palette)
		return palette.maybe("signature_stair") or palette.node("roof_stair")
	end
	-- A dressed column. `pillar` is a FAMILY role -- three registered shapes
	-- that only read as a pillar stacked bottom, middle, top -- so it is
	-- reached through `palette.variant`, which answers nil for a race that
	-- does not bind it and lets the column fall back to plain masonry.
	local function pillar(palette, buf, x, y0, y1, z)
		local bottom = palette.variant("pillar", "_bottom")
		if bottom == nil or y1 <= y0 then
			for y = y0, y1 do buf:put(x, y, z, stone(palette)) end
			return
		end
		buf:put(x, y0, z, bottom)
		for y = y0 + 1, y1 - 1 do
			buf:put(x, y, z, palette.variant("pillar", "_middle"))
		end
		buf:put(x, y1, z, palette.variant("pillar", "_top"))
	end

	local SOCKET_ROLES = {guard_post = true, guard_patrol = true,
		vendor = true, idle = true, quest = true, king = true,
		waypoint = true, work = true}

	local function socket(list, id, role, x, y, z, face, extra)
		local entry = {id = id, role = role, x = x, y = y, z = z,
			face = face % 4}
		for key, value in pairs(extra or {}) do entry[key] = value end
		list[#list + 1] = entry
		return entry
	end

	local function top_of(buf)
		local order, count = buf:cells()
		local peak = 0
		for index = 1, count do
			local cell = order[index]
			if cell.name ~= parts.AIR and cell.y > peak then peak = cell.y end
		end
		return peak
	end

	-- The same closing contract `capitals.finish` holds a part to: every
	-- socket's feet and head cell free in the finished buffer and the cell
	-- below it not air. Spelled here rather than reached for, because
	-- `capitals.lua` keeps it private and this file may not edit it.
	local function finish(buf, w, d, peak, points, extra)
		local seen = {}
		for _, entry in ipairs(points.sockets or {}) do
			if not SOCKET_ROLES[entry.role] then
				error("wp13 elf parts: socket " .. tostring(entry.id) ..
					" has the unknown role " .. tostring(entry.role), 0)
			end
			if seen[entry.id] then
				error("wp13 elf parts: duplicate socket id " ..
					tostring(entry.id), 0)
			end
			seen[entry.id] = true
			for _, level in ipairs({entry.y, entry.y + 1}) do
				local cell = buf:at(entry.x, level, entry.z)
				if cell ~= nil and cell.name ~= parts.AIR then
					error("wp13 elf parts: socket " .. entry.id .. " at " ..
						entry.x .. "," .. entry.y .. "," .. entry.z ..
						" is blocked by " .. cell.name, 0)
				end
			end
			local below = buf:at(entry.x, entry.y - 1, entry.z)
			if below == nil or below.name == parts.AIR then
				error("wp13 elf parts: socket " .. entry.id .. " at " ..
					entry.x .. "," .. entry.y .. "," .. entry.z ..
					" stands on air", 0)
			end
		end
		local part = {buffer = buf, w = w, d = d, peak = peak, points = points}
		for key, value in pairs(extra or {}) do
			if part[key] ~= nil then
				error("wp13 elf parts: the population " .. tostring(key) ..
					" collides with a part field", 0)
			end
			part[key] = value
		end
		return part
	end

	-- ------------------------------------------------------------------
	-- 1. The threshold: what an open capital has instead of a gate
	-- ------------------------------------------------------------------

	-- Two marble pillars either side of the road, a lintel across them, a
	-- lantern hung under it and a paved landing between. Lethariel carries no
	-- curtain wall (contract section 4), so this is the whole of what marks
	-- the four gate points Lane R ends its routes at: a threshold you walk
	-- through, not a gate you are let through.
	--
	-- Extent: 9 x 5 (x across the road, z along it), y 0..(rise + 2).
	function M.threshold(palette, spec)
		local rise = spec.rise or 6
		local w, d = 9, 5
		local buf = parts.buffer()
		local lights, sockets = {}, {}
		if rise < 4 then error("wp13 elf parts: threshold too low", 0) end

		buf:clear(0, 1, 0, w - 1, rise + 3, d - 1)
		buf:fill(0, 0, 0, w - 1, 0, d - 1, paving(palette))
		dressing.inlay(buf, palette, 0, 0, w - 1, d - 1, "plaza_edge")

		-- The two pillars, on the verge columns of a five-wide carriageway.
		for _, x in ipairs({1, w - 2}) do
			for _, z in ipairs({1, d - 2}) do
				buf:fill(x, 1, z, x, 1, z, mark(palette))
				pillar(palette, buf, x, 2, rise - 1, z)
				buf:put(x, rise, z, mark(palette))
			end
			-- The head of each pair, carried across its own two pillars.
			buf:put(x, rise + 1, 1, mark_slab(palette))
			buf:put(x, rise + 1, d - 2, mark_slab(palette))
		end
		-- The lintel: one course of the signature material from pillar to
		-- pillar on both faces, with the crown slab over it.
		local beams = 0
		for x = 1, w - 2 do
			for _, z in ipairs({1, d - 2}) do
				if x > 1 and x < w - 2 then
					buf:put(x, rise, z, mark(palette))
					beams = beams + 1
				end
				buf:put(x, rise + 1, z, mark_slab(palette))
			end
		end
		-- A lantern under the middle of each face.
		local lit = 0
		for _, z in ipairs({1, d - 2}) do
			if parts.hanging_light(buf, palette, math.floor(w / 2), rise - 1, z)
					~= false then
				lights[#lights + 1] = {x = math.floor(w / 2), y = rise - 1,
					z = z}
				lit = lit + 1
			end
		end
		-- The two standing stones outside the pillars, which is what turns a
		-- gateway into a threshold: something to walk past before you walk
		-- through.
		for _, x in ipairs({0, w - 1}) do
			for _, z in ipairs({0, d - 1}) do
				buf:put(x, 1, z, mark(palette))
				buf:put(x, 2, z, mark_slab(palette))
			end
		end

		local id = spec.id or "threshold"
		local centre = math.floor(w / 2)
		if spec.patrol_group then
			socket(sockets, id .. "_watch_a", "guard_patrol", 2, 1, 0,
				0, {group = spec.patrol_group, order = spec.order or 1})
			socket(sockets, id .. "_watch_b", "guard_patrol", w - 3, 1, d - 1,
				2, {group = spec.patrol_group, order = (spec.order or 1) + 1})
		end
		socket(sockets, id .. "_post", "guard_post", centre - 2, 1, d - 1, 2)
		socket(sockets, id .. "_idle", "idle", centre + 2, 1, d - 1, 2,
			{tags = {"door"}})

		return finish(buf, w, d, top_of(buf), {
			doors = {}, lights = lights, sockets = sockets,
			inside = {}, room_corner = {},
		}, {lanterns = lit, lintel = beams})
	end

	-- ------------------------------------------------------------------
	-- 2. The tree platform
	-- ------------------------------------------------------------------

	-- A silverwood standard with a railed deck round its stem and a small
	-- planked hall on the deck, reached by a flight winding up the outside.
	-- The WP40 profile of this capital is `terraced_grove`; this is the piece
	-- that says so.
	--
	-- Extent: size x size, y 0..(deck + wall_h + 3). The stem rises from the
	-- ground course, so the part carries its own tree and needs no kept one.
	function M.tree_platform(palette, spec)
		local size = spec.size or 11
		local deck = spec.deck or 7
		local wall_h = spec.wall_h or 3
		local buf = parts.buffer()
		local lights, sockets, doors = {}, {}, {}
		if size < 9 or size % 2 == 0 then
			error("wp13 elf parts: the tree platform is not an odd pad", 0)
		end
		-- The flight is ONE straight run up the x+ face and the deck is seven
		-- columns across, so a deck higher than seven would need a second
		-- flight and a landing to turn on. Seven is the number this part is
		-- authored for and the refusal says so instead of running the stair
		-- off the end of its own pad.
		if deck < 5 or deck > 7 then
			error("wp13 elf parts: the deck must stand 5..7 courses up", 0)
		end
		local last = size - 1
		local c = math.floor(last / 2)

		buf:clear(0, 1, 0, last, deck + wall_h + 4, last)
		buf:fill(0, 0, 0, last, 0, last, palette.node("ground"))
		-- The paved apron round the foot of the stem, laid BEFORE the ground
		-- cover: `dressing.undergrowth` plants only on wild soil, so paving
		-- first is what keeps a tuft of fern out of the apron's own cells.
		for z = c - 2, c + 2 do
			for x = c - 2, c + 2 do
				buf:put(x, 0, z, palette.node("path"))
			end
		end
		dressing.undergrowth(buf, palette, 0, 0, last, last, 5)

		-- The stem, a four-column trunk so the deck has something to stand on
		-- that is wider than one node.
		local log = palette.node("tree_log")
		for y = 1, deck - 1 do
			for _, spot in ipairs({{c, c}, {c - 1, c}, {c, c - 1},
					{c - 1, c - 1}}) do
				buf:put(spot[1], y, spot[2], log)
			end
		end

		-- The deck: a square of plank on beam bearers, railed all round but at
		-- the head of the stair.
		local floor = palette.node("floor")
		local stair_x = c + 4
		for z = c - 3, c + 3 do
			for x = c - 3, c + 3 do
				buf:put(x, deck, z, floor)
			end
		end
		for _, spot in ipairs({{c - 4, c}, {c + 4, c}, {c, c - 4}, {c, c + 4}}) do
			buf:put(spot[1], deck, spot[2], palette.node("beam"))
		end
		-- The flight: one straight run of marble treads up the x+ face,
		-- outside the deck's own footprint, climbing from z = c + 3 towards
		-- the head. Each tread stands on its own masonry, so the flight is a
		-- staircase and not a row of floating steps.
		local tread = mark_stair(palette)
		local head_z = c + 3 - (deck - 1)
		local steps = 0
		for step = 1, deck do
			local z = c + 3 - (step - 1)
			for y = 0, step - 1 do buf:put(stair_x, y, z, mark(palette)) end
			-- Facedir 0 is the tread rising towards z-, which is the way the
			-- flight climbs.
			buf:put(stair_x, step, z, tread, 0)
			steps = steps + 1
		end
		buf:clear(stair_x, deck + 1, head_z, stair_x, deck + 3, head_z)

		-- The rail, all round the deck but at the head of the flight.
		local rail = palette.node("railing")
		local rails = 0
		for step = c - 3, c + 3 do
			for _, spot in ipairs({{step, c - 3}, {step, c + 3},
					{c - 3, step}, {c + 3, step}}) do
				if not (spot[1] == c + 3 and spot[2] == head_z) then
					buf:put(spot[1], deck + 1, spot[2], rail)
					rails = rails + 1
				end
			end
		end

		-- The hall on the deck: three walls of plank, an open face to the
		-- stair head, a pale roof over it.
		local wall = palette.node("wall")
		for y = deck + 1, deck + wall_h do
			for z = c - 2, c + 2 do
				for x = c - 2, c + 2 do
					local edge = (x == c - 2 or x == c + 2 or z == c - 2 or
						z == c + 2)
					if edge and not (x == c + 2 and z == c) then
						buf:put(x, y, z, wall)
					end
				end
			end
		end
		buf:clear(c - 1, deck + 1, c - 1, c + 1, deck + wall_h, c + 1)
		for _, spot in ipairs({{c - 2, c - 1}, {c - 2, c + 1}}) do
			parts.pane(buf, palette, spot[1], deck + 2, spot[2], "z")
		end
		for z = c - 3, c + 3 do
			for x = c - 3, c + 3 do
				buf:put(x, deck + wall_h + 1, z, mark_slab(palette))
			end
		end
		parts.wall_torch(buf, palette, c - 1, deck + 2, c - 1, 0, 0, -1)
		lights[#lights + 1] = {x = c - 1, y = deck + 2, z = c - 1}
		doors[#doors + 1] = {x = c + 2, y = deck + 1, z = c, face = 3}

		local id = spec.id or "tree_platform"
		socket(sockets, id .. "_deck", "idle", c + 1, deck + 1, c, 3,
			{tags = {"door"}})
		socket(sockets, id .. "_foot", "idle", c, 1, c + 2, 2,
			{tags = {"bench"}})

		return finish(buf, size, size, top_of(buf), {
			doors = doors, lights = lights, sockets = sockets,
			inside = {{x = c, y = deck + 1, z = c}},
			room_corner = {
				{x = c - 1, y = deck + 1, z = c - 1, top = deck + wall_h,
					closed = false},
				{x = c + 1, y = deck + 1, z = c + 1},
			},
		}, {rails = rails, steps = steps})
	end

	-- ------------------------------------------------------------------
	-- 3. The shrine
	-- ------------------------------------------------------------------

	-- An open marble shrine: four pillars on a stepped podium, an architrave
	-- and a crown over them, an ALTAR on the podium and candles at its
	-- corners. It is open on every side, so a `pray` socket outside it looks
	-- straight at the altar, which is the feature the sockets contract's
	-- section 8.1 names for that activity.
	--
	-- Extent: size x size, y 0..(rise + 3).
	function M.shrine(palette, spec)
		local size = spec.size or 9
		local rise = spec.rise or 5
		local buf = parts.buffer()
		local lights, sockets = {}, {}
		if size < 7 or size % 2 == 0 then
			error("wp13 elf parts: the shrine is not an odd pad", 0)
		end
		local last = size - 1
		local c = math.floor(last / 2)

		buf:clear(0, 1, 0, last, rise + 4, last)
		buf:fill(0, 0, 0, last, 0, last, paving(palette))
		dressing.inlay(buf, palette, 0, 0, last, last, "plaza_edge")
		-- The podium, and ONE FLIGHT OF THREE TREADS on each side rather than
		-- a tread all round it. A step round the whole podium leaves nowhere
		-- on the outer ring for a pilgrim to stand: every cell of it is a
		-- stair, and a stair in a socket's feet cell is a socket with no
		-- headroom. Three treads centred on each face is a flight, and the
		-- rest of the ring is open paving.
		buf:fill(1, 1, 1, last - 1, 1, last - 1, mark(palette))
		for step = c - 1, c + 1 do
			parts.stair(buf, step, 1, 0, mark_stair(palette), 0)
			parts.stair(buf, step, 1, last, mark_stair(palette), 2)
			parts.stair(buf, 0, 1, step, mark_stair(palette), 1)
			parts.stair(buf, last, 1, step, mark_stair(palette), 3)
		end

		-- Four pillars, an architrave and the crown.
		for _, spot in ipairs({{1, 1}, {last - 1, 1}, {1, last - 1},
				{last - 1, last - 1}}) do
			pillar(palette, buf, spot[1], 2, rise, spot[2])
		end
		for step = 1, last - 1 do
			for _, z in ipairs({1, last - 1}) do
				buf:put(step, rise + 1, z, mark(palette))
			end
			for _, x in ipairs({1, last - 1}) do
				buf:put(x, rise + 1, step, mark(palette))
			end
		end
		for z = 1, last - 1 do
			for x = 1, last - 1 do
				buf:put(x, rise + 2, z, mark_slab(palette))
			end
		end

		-- THE ALTAR, on the podium: a block of the signature stone with a
		-- candle at each of its two ends, which is what a `pray` socket's
		-- `dir` finds within three nodes.
		buf:put(c, 2, c, mark(palette))
		buf:put(c, 3, c, mark_slab(palette))
		for _, spot in ipairs({{c - 1, c}, {c + 1, c}}) do
			parts.floor_torch(buf, palette, spot[1], 2, spot[2])
			lights[#lights + 1] = {x = spot[1], y = 2, z = spot[2]}
		end

		local id = spec.id or "shrine"
		-- Three who pray, standing ON the podium two nodes from the altar and
		-- facing it -- the sockets contract's `pray` wants a candle, an altar
		-- or a grave marker under `dir` within three nodes (section 8.1), and
		-- the altar block and its two candles are exactly two away from each
		-- of these. The podium is outside every room (the shrine has none: it
		-- is open on all four sides), which is the other half of the rule.
		socket(sockets, id .. "_keeper", "work", c - 2, 2, c, 1,
			{activity = "pray"})
		socket(sockets, id .. "_south", "work", c, 2, c - 2, 0,
			{activity = "pray"})
		socket(sockets, id .. "_north", "work", c, 2, c + 2, 2,
			{activity = "pray"})
		if spec.quest then
			-- The quest shell stands OUTSIDE, on the shrine's own south
			-- landing, and carries the `door` tag: the sockets contract's
			-- section 7 turn puts the elder's face on the street he is
			-- standing at the head of.
			socket(sockets, id .. "_quest", "quest", c + 2, 1, 0, 0,
				{tags = {"door"}})
		end

		return finish(buf, size, size, top_of(buf), {
			doors = {}, lights = lights, sockets = sockets,
			inside = {{x = c, y = 1, z = c - 2}},
			room_corner = {},
		}, {})
	end

	-- ------------------------------------------------------------------
	-- 4. The boat stage
	-- ------------------------------------------------------------------

	-- The fishing stage of a lakeside city: the plot digs its OWN basin (the
	-- pond of playtest round 3, lined on five sides, so it is water the
	-- capital dug and not a lake the capital was built into), and the stage is
	-- a plank deck on posts reaching over it with a drying rack behind.
	--
	-- `w` is the pad across the water and `d` along it. The basin fills the
	-- far half, the deck the near half, and the three `fish` sockets stand on
	-- the deck's own planks looking at the water one node in front of them.
	--
	-- Extent: w x d, y -4..3.
	function M.boat_stage(palette, spec)
		local w = spec.w or 17
		local d = spec.d or 13
		local buf = parts.buffer()
		local lights, sockets = {}, {}
		if w < 13 or d < 11 then
			error("wp13 elf parts: the boat stage is too small", 0)
		end
		local last_x, last_z = w - 1, d - 1
		local c = math.floor(last_x / 2)

		buf:clear(0, 1, 0, last_x, 6, last_z)
		buf:fill(0, 0, 0, last_x, 0, last_z, palette.node("ground"))
		-- The bank walk along the near edge, and the shore behind it.
		for x = 0, last_x do
			buf:put(x, 0, 0, palette.node("path"))
			buf:put(x, 0, 1, palette.node("path"))
		end
		local filled = dressing.pond(buf, palette, 2, 5, last_x - 2,
			last_z - 1, 3)
		if filled == 0 then
			error("wp13 elf parts: the boat stage has no water", 0)
		end

		-- The stage itself: two rows of posts carrying a plank deck that
		-- reaches three nodes out over the basin.
		local posts = 0
		for _, x in ipairs({c - 2, c + 2}) do
			for z = 5, 7 do
				for y = -2, 0 do buf:put(x, y, z, palette.node("post")) end
				posts = posts + 1
			end
		end
		for z = 2, 7 do
			for x = c - 2, c + 2 do
				buf:put(x, 1, z, palette.node("floor"))
			end
		end
		for z = 2, 7 do
			for _, x in ipairs({c - 3, c + 3}) do
				buf:put(x, 1, z, palette.node("railing"))
			end
		end
		buf:put(c - 2, 2, 7, palette.node("railing"))
		buf:put(c + 2, 2, 7, palette.node("railing"))

		-- The rack and the crates on the bank.
		dressing.drying_rack(buf, palette, 2, 2, 4, "x")
		dressing.crates(buf, palette, last_x - 3, 2, 0)
		dressing.path_light(buf, palette, 1, 1, lights)
		dressing.path_light(buf, palette, last_x - 1, 1, lights)

		local id = spec.id or "stage"
		-- Three anglers on the deck, each looking at the water beside it.
		socket(sockets, id .. "_rod_west", "work", c - 2, 2, 6, 1,
			{activity = "fish"})
		socket(sockets, id .. "_rod_east", "work", c + 2, 2, 6, 3,
			{activity = "fish"})
		socket(sockets, id .. "_rod_head", "work", c, 2, 7, 2,
			{activity = "fish"})
		socket(sockets, id .. "_rack", "work", 2, 1, 1, 2,
			{activity = "tend"})

		return finish(buf, w, d, top_of(buf), {
			doors = {}, lights = lights, sockets = sockets,
			inside = {}, room_corner = {},
		}, {water = filled, posts = posts})
	end

	return M
end

return loader
