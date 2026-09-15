-- The two parts the undead capital needs and the shared library does not
-- carry: a MAUSOLEUM and a CANDLE COURT.
--
-- `capitals.lua` is the shared capital kit and this lane may not edit it
-- (the wave-2 brief's file ownership), so a part only Nhal Veyr wants lives
-- here, in a NEW `wp13/<race>_*.lua` file, and registers nothing: the two
-- generators below obey exactly the contract `capitals.lua`'s do -- take a
-- palette handle and a spec, return `{buffer, w, d, peak, points}` in the
-- part's own frame, x running 0..w-1, z running 0..d-1, y = 0 the ground node
-- and y = 1 the first walkable course -- so `parts.stamp` places them at any
-- of the four rotations and every composition and KAT in the tree already
-- knows what to do with them.
--
-- WHY THESE TWO. The capitals contract's section 2.4 line for Nhal Veyr is
-- "dungeon stone and obsidian brick, MAUSOLEUM core, stepped terraces with
-- ruins mixed among kept houses, CANDLES and iron bars". The library has a
-- temple, a scriptorium, a granary, a stable and a well court, and every one
-- of them is a room with a roof on it; what a necropolis is made of is tombs
-- and lights, and neither of those is a house.
--
-- Both are built on library machinery rather than from bare cells, which is
-- the whole reason they are short:
--
--   * the mausoleum is `buildings.build` with the `crypt` interior kit, the
--     same way `capitals.barracks` is `buildings.build` with the `barracks`
--     kit. Every invariant the KATs check -- the roof closing over its own
--     walls, the doorway passable with a walkable step on both sides, the
--     closed room roofed and lit, no detached cell -- is that builder's and
--     is not re-derived here;
--   * the candle court is `well_court`'s shape without the well: a paved
--     square with a kerb, an ALTAR block at its centre and a ring of candle
--     standards, which is the feature the sockets contract's `pray` and
--     `mourn` name.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local dressing = dofile(directory .. "/dressing.lua")(directory)
	local buildings = dofile(directory .. "/buildings.lua")(directory)

	local M = {}

	-- The capital vocabulary, each with the same fallback into the start
	-- vocabulary `capitals.lua` uses, so a palette without the capital roles
	-- still builds these two.
	local function stone(palette)
		return palette.maybe("castle_wall") or palette.node("wall_accent")
	end
	local function paving(palette)
		return palette.maybe("castle_paving") or palette.node("plaza")
	end
	local function mark(palette)
		return palette.maybe("signature") or palette.node("wall_accent")
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

	-- Close a part: the same three construction-time socket tests
	-- `capitals.finish` makes -- the feet cell and the one above it free, the
	-- cell below not air -- so a generator cannot publish a standing position
	-- nobody can stand in. Whether the cell below is WALKABLE is a registry
	-- question and belongs to the KAT.
	local function finish(buf, w, d, peak, points, extra)
		local seen = {}
		for _, entry in ipairs(points.sockets or {}) do
			if not SOCKET_ROLES[entry.role] then
				error("wp13 undead parts: socket " .. tostring(entry.id) ..
					" has the unknown role " .. tostring(entry.role), 0)
			end
			if seen[entry.id] then
				error("wp13 undead parts: duplicate socket id " ..
					tostring(entry.id), 0)
			end
			seen[entry.id] = true
			for _, level in ipairs({entry.y, entry.y + 1}) do
				local cell = buf:at(entry.x, level, entry.z)
				if cell ~= nil and cell.name ~= parts.AIR then
					error("wp13 undead parts: socket " .. entry.id .. " at " ..
						entry.x .. "," .. entry.y .. "," .. entry.z ..
						" is blocked by " .. cell.name .. " at y " .. level, 0)
				end
			end
			local below = buf:at(entry.x, entry.y - 1, entry.z)
			if below == nil or below.name == parts.AIR then
				error("wp13 undead parts: socket " .. entry.id .. " at " ..
					entry.x .. "," .. entry.y .. "," .. entry.z ..
					" stands on air", 0)
			end
		end
		local part = {buffer = buf, w = w, d = d, peak = peak, points = points}
		for key, value in pairs(extra or {}) do
			if part[key] ~= nil then
				error("wp13 undead parts: the population " .. tostring(key) ..
					" collides with a part field", 0)
			end
			part[key] = value
		end
		return part
	end

	-- -------------------------------------------------------------------
	-- 1. the mausoleum
	-- -------------------------------------------------------------------

	-- A walk-in tomb: a masonry box on a stepped plinth, one door in its z-
	-- gable, the `crypt` interior kit inside it, and a candle standard at
	-- each front corner of the plinth.
	--
	-- Extent at the defaults: 11 x 13 plus the plinth's own ring, y 0..8.
	--
	-- The PLINTH is why this is a part and not a roster row calling
	-- `buildings.build` directly. A tomb that stands straight on the ground
	-- reads as a shed; two courses of signature stone under it, stepped back
	-- a node, is the whole difference, and it has to be written UNDER the
	-- building rather than round it -- the shell is built first and the
	-- plinth then fills the ring the eaves oversail.
	function M.mausoleum(palette, spec)
		local w, d = spec.w or 11, spec.d or 13
		local wall_h = spec.wall_h or 4
		local cx = math.floor(w / 2)
		local part = buildings.build(palette, {
			id = spec.id, infill = false, shutters = false,
			roof_palette = spec.roof_palette,
			blocks = {{x0 = 0, z0 = 0, x1 = w - 1, z1 = d - 1,
				wall_h = wall_h, roof = spec.roof or "hip",
				rise = spec.rise or 3, kit = "crypt"}},
			doors = {{side = "z-", index = cx, double = false}},
			inside = {x = cx, y = 1, z = 3},
		})
		local buf = part.buffer
		local sockets = {}
		local points_lights = part.points.lights or {}
		part.points.lights = points_lights

		-- THE CRYPT FLOOR IS RE-LAID LEVEL, and this is the one thing this
		-- generator undoes rather than adds.
		--
		-- `interiors.kits.crypt` SINKS its nave: it lays paving one course
		-- below the room floor and writes AIR at the floor course itself, so
		-- the walkway round the sarcophagi has a visible lip. That is exactly
		-- right in Stillgrave's crypt-chapel, which stands on a start pad --
		-- and it is not survivable in a capital DISTRICT PLOT, because a
		-- terrain-relative plot levels to the final height of one reference
		-- column and the seam requires that column to be a column of the plot's
		-- own GROUND COURSE (`r7_settlement.prepare_cells`). The plot builder
		-- centres a part on its reference column, the centre of a tomb is in
		-- the middle of its nave, and the middle of a sunken nave is air. The
		-- seam said so at load, which is where a rule like that should bite.
		--
		-- So every interior cell the sink emptied is filled back with the same
		-- paving: the floor is level, the sarcophagi and the altar tomb -- which
		-- the kit wrote AT the floor course and which are therefore not air --
		-- keep their cells, and the kerb ring keeps its own. What is lost is one
		-- node of lip; what is kept is the whole of the kit's furniture.
		for z = 1, d - 2 do
			for x = 1, w - 2 do
				local here = buf:at(x, 0, z)
				if here == nil or here.name == parts.AIR then
					buf:put(x, 0, z, paving(palette))
				end
			end
		end

		-- The plinth: the ring one node outside the shell, two courses of
		-- signature stone with a slab lip, and the apron in front of the door
		-- laid in the capital paving so the doorstep is a step and not turf.
		local plinth = 0
		for z = -1, d do
			for x = -1, w do
				if x == -1 or x == w or z == -1 or z == d then
					local here = buf:at(x, 0, z)
					if here == nil or here.name == parts.AIR then
						buf:put(x, 0, z, mark(palette))
						plinth = plinth + 1
					end
				end
			end
		end
		for x = cx - 1, cx + 1 do
			buf:put(x, 0, -1, paving(palette))
		end

		-- A candle standard at each front corner of the plinth: ONE course of
		-- masonry with the palette's own floor light on it, which is what the
		-- sockets contract's `pray` and `mourn` name as their feature. Two
		-- things about that are deliberate.
		--
		-- It is masonry and not `dressing.path_light`, whose standard is a
		-- timber post two courses tall: a tomb's light stands on stone.
		--
		-- And it is KNEE HIGH rather than head high, which is the shape the
		-- socket rule forces. A work socket's feature search looks at the cells
		-- one course below, level with and one above its own FEET (sockets
		-- contract section 8.1, and both KATs implement it that way), so a
		-- candle on a two-course standard sits at y = 3 and a mourner standing
		-- at y = 1 never sees it. A votive light on a single block is at y = 2,
		-- which is in range -- and is also what a candle at a grave looks like.
		local candles = 0
		for _, spot in ipairs({{-1, -1}, {w, -1}}) do
			local x, z = spot[1], spot[2]
			buf:put(x, 1, z, stone(palette))
			parts.floor_torch(buf, palette, x, 2, z)
			points_lights[#points_lights + 1] = {x = x, y = 2, z = z}
			candles = candles + 1
		end

		-- The mourner's place: on the doorstep apron itself, looking at
		-- the door. The composition may retag it; what this generator knows
		-- is that a tomb is a thing people stand in front of.
		local id = spec.id or "mausoleum"
		socket(sockets, id .. "_mourn", "idle", cx, 1, -1, 0, {tags = {"door"}})

		local points = part.points
		points.sockets = sockets
		return finish(buf, w, d, top_of(buf), points,
			{plinth = plinth, candles = candles})
	end

	-- -------------------------------------------------------------------
	-- 2. the candle court
	-- -------------------------------------------------------------------

	-- A paved square with a stepped ALTAR at its centre, a kerb of low wall,
	-- four candle standards on the diagonals and two benches. It is the
	-- necropolis's answer to a village green: the one open place in a
	-- district where a light burns.
	--
	-- Extent: size x size, y 0..4; the default 11 is a quarter-plot.
	function M.candle_court(palette, spec)
		local size = spec.size or 11
		local buf = parts.buffer()
		local lights, sockets = {}, {}
		if size < 9 then error("wp13 undead parts: candle court too small", 0) end
		local last = size - 1
		local centre = math.floor(last / 2)

		buf:clear(0, 1, 0, last, 6, last)
		buf:fill(0, 0, 0, last, 0, last, paving(palette))
		dressing.inlay(buf, palette, 0, 0, last, last, "plaza_edge")

		-- The altar: a three-by-three step of signature stone with a single
		-- masonry block on it and a light on every face of that block. A
		-- wallmounted candle needs an opaque full node to hang on, which is
		-- what the block is for.
		for z = centre - 1, centre + 1 do
			for x = centre - 1, centre + 1 do
				buf:put(x, 1, z, mark(palette))
			end
		end
		buf:put(centre, 2, centre, stone(palette))
		-- The four lights stand ON the altar step rather than hanging off the
		-- block: a wallmounted candle needs an opaque full cube behind it and
		-- the block is one, but a torch on the step reads as a votive light
		-- and a torch on the block's side reads as a sconce on a pillar.
		local candles = 0
		for _, step in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local x, z = centre + step[1], centre + step[2]
			parts.floor_torch(buf, palette, x, 2, z)
			lights[#lights + 1] = {x = x, y = 2, z = z}
			candles = candles + 1
		end

		-- Four candle standards on the corners of the court, and two benches
		-- on the free sides.
		for _, spot in ipairs({{1, 1}, {last - 1, 1}, {1, last - 1},
				{last - 1, last - 1}}) do
			dressing.path_light(buf, palette, spot[1], spot[2], lights)
		end
		local benches = 0
		for _, entry in ipairs({{centre, 1, 0}, {centre, last - 1, 2}}) do
			parts.seat(buf, palette, entry[1], 1, entry[2], entry[3])
			benches = benches + 1
		end

		local id = spec.id or "candle_court"
		socket(sockets, id .. "_idle_a", "idle", centre - 2, 1, centre, 3,
			{tags = {"bench"}})
		socket(sockets, id .. "_idle_b", "idle", centre + 2, 1, centre, 1,
			{tags = {"bench"}})

		return finish(buf, size, size, top_of(buf), {
			doors = {},
			lights = lights,
			sockets = sockets,
			inside = {},
			room_corner = {},
		}, {candles = candles, benches = benches})
	end

	return M
end

return loader
