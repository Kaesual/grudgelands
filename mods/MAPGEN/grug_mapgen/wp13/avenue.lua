-- WP13 capital avenues: the surface overlay that carries a gate road across
-- terraced ground.
--
-- The capitals contract (docs/research/wp13-capitals-pois-contract.md section
-- 2.1) gives a capital four avenues from the core edge to the four gate
-- stations, and says what they are: "pavement at surface, one stair node at
-- each terrace rise, lamp posts every 8 nodes, no height queries". The last
-- clause is the design: a blueprint is anchor-relative and an avenue is not,
-- because WP40's terraces put every node of it at a different height, so the
-- avenue cannot be authored as cells at all. It is authored as a FUNCTION of
-- the column surface, and the surface arrives through one callback the caller
-- owns.
--
-- That makes this module the one piece of WP13 a successor can run per
-- mapchunk: give it the run and a `surface(x, z)` that answers for the
-- columns of the chunk it is emerging, and it yields the cells of that piece
-- of road and nothing else. It queries no height of its own, reads no engine
-- and keeps no state; two calls with the same arguments produce the identical
-- cell list.
--
-- Where the contract's sentence is not enough
-- -------------------------------------------
-- "One stair node at each terrace rise" is one stair per NODE of rise, not
-- one per rise. A player walks up half a node and jumps a whole one, and the
-- race terrace steps of WP40 are 2 (human), 3 (elf, undead, troll) and 4
-- (dwarf, orc). A single stair in front of a two-node rise leaves the second
-- node to be jumped, which is not a road. A rise of `h` therefore gets a
-- FLIGHT of `h` treads in the `h` columns on the low side of the joint, each
-- one course above the last on its own riser of paving, so the walk climbs
-- in half nodes the whole way up. A rise of one is the contract's single
-- stair, unchanged.
--
-- Every lane of the road is profiled on its own, because a terrace joint
-- crossing the road at an angle arrives at the five lanes in five different
-- columns; a per-lane flight follows it, a road-wide one would step where
-- the ground does not.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")

	local M = {}

	-- The capitals contract's own numbers.
	M.WIDTH = 5
	M.LAMP_SPACING = 8

	-- The avenue vocabulary, each with its fallback into the start
	-- vocabulary, exactly as `capitals.lua` resolves the same roles: the
	-- capital roles are optional and a palette that has not been given them
	-- still builds a road.
	local function paving(palette)
		return palette.maybe("castle_paving") or palette.node("plaza")
	end
	local function kerb(palette)
		return palette.node("plaza_edge")
	end
	local function tread(palette)
		return palette.maybe("castle_wall_stair") or palette.node("roof_stair")
	end

	local function axis_steps(axis)
		if axis == "x" then return 1, 0 end
		if axis == "z" then return 0, 1 end
		error("wp13 avenue: unknown axis " .. tostring(axis), 0)
	end

	-- One run of avenue.
	--
	-- `spec`:
	--   axis          "x" or "z", the direction the road runs
	--   at            the OTHER coordinate: the centre line of the road
	--   from, to      inclusive span along `axis`, from <= to
	--   width         odd, default 5 (the contract's gate corridor)
	--   lamp_spacing  default 8
	--   lamp_phase    the position along `axis` the lamp rhythm is anchored
	--                 to, default `from`; a successor emerging the road in
	--                 pieces passes the same phase for every piece, which is
	--                 what keeps one lamp line across a chunk border
	--   id            a label carried into the returned table
	--
	-- `surface(x, z)` returns the y of the topmost terrain node of that
	-- column. It is called exactly once per column this run touches and is
	-- the ONLY source of height in here.
	--
	-- Returns `{cells, lamps, pavement, treads, risers, columns, queries}`:
	-- `cells` is the canonical cell list (z, then y, then x) a writer can
	-- project directly, `lamps` the lamp positions for a lighting landmark,
	-- and the counts are what the KAT holds the run to.
	function M.run(palette, spec, surface)
		if type(surface) ~= "function" then
			error("wp13 avenue: a run needs a surface callback", 0)
		end
		local dx, dz = axis_steps(spec.axis)
		local from, to = spec.from, spec.to
		if type(from) ~= "number" or type(to) ~= "number" or from > to then
			error("wp13 avenue: the run has no span", 0)
		end
		local width = spec.width or M.WIDTH
		if width % 2 ~= 1 or width < 3 then
			error("wp13 avenue: the width " .. tostring(width) ..
				" is not an odd carriageway", 0)
		end
		local half = (width - 1) / 2
		local spacing = spec.lamp_spacing or M.LAMP_SPACING
		local phase = spec.lamp_phase or from
		local at = spec.at
		local buf = parts.buffer()
		local lamps = {}
		local queries = 0

		-- The column (x, z) of position `p` along the run, `offset` lanes to
		-- the side. The side runs with the axis: +x is offset +1 for a road
		-- along z, +z for a road along x, so a lane index means the same
		-- hand of the road whichever way it points.
		local function column(p, offset)
			if dx == 1 then return p, at + offset end
			return at + offset, p
		end
		local function height(x, z)
			local y = surface(x, z)
			queries = queries + 1
			if type(y) ~= "number" or y % 1 ~= 0 then
				error("wp13 avenue: the surface at " .. x .. "," .. z ..
					" is " .. tostring(y) .. ", not a node height", 0)
			end
			return y
		end

		-- 1. The carriageway, lane by lane. Each lane is profiled first and
		-- paved afterwards, because the flight of a joint is written into the
		-- columns BEFORE the joint and has to know both sides of it.
		local pavement, treads, risers = 0, 0, 0
		for offset = -half, half do
			local profile = {}
			for p = from, to do
				local x, z = column(p, offset)
				profile[p] = height(x, z)
			end
			local surface_name = (offset == -half or offset == half) and
				kerb(palette) or paving(palette)
			for p = from, to do
				local x, z = column(p, offset)
				buf:put(x, profile[p], z, surface_name)
				pavement = pavement + 1
			end
			-- The flights. A joint between p and p + 1 whose two surfaces
			-- differ by `h` gets `h` treads, in the `h` columns on the LOW
			-- side counted away from the joint: the column next to the joint
			-- carries `h - 1` risers and the tread that lands level with the
			-- high side, the next one out carries one riser fewer, and so on
			-- down to a single tread `h - 1` columns away. Walking the other
			-- way the same flight is a stair down.
			for p = from, to - 1 do
				local low, high = profile[p], profile[p + 1]
				local step = 1
				local base = p
				if high < low then
					low, high = high, low
					step = -1
					base = p + 1
				end
				local rise = high - low
				for back = 0, rise - 1 do
					local q = base - step * back
					-- Only a column that really lies on the low terrace
					-- carries a tread of this flight. Two joints within `h`
					-- columns of each other would otherwise have the upper
					-- flight write risers under the lower terrace it does
					-- not stand on; each joint then climbs its own rise from
					-- its own column, which is what the profile 8-10-12
					-- needs and gets.
					if q >= from and q <= to and profile[q] == low then
						local x, z = column(q, offset)
						for y = low + 1, high - back - 1 do
							buf:put(x, y, z, surface_name)
							risers = risers + 1
						end
						parts.stair(buf, x, high - back, z, tread(palette),
							parts.step_facedir(dx * step, dz * step))
						treads = treads + 1
					end
				end
			end
		end

		-- 2. The lamps: a standard on each verge, one node outside the
		-- carriageway, every `spacing` nodes. The verge column carries the
		-- lamp at its OWN surface, so a standard beside a terrace joint
		-- stands on the ground it is next to and not on the road's level.
		for p = from, to do
			if (p - phase) % spacing == 0 then
				for _, offset in ipairs({-half - 1, half + 1}) do
					local x, z = column(p, offset)
					local y = height(x, z)
					buf:put(x, y + 1, z, palette.node("post"))
					buf:put(x, y + 2, z, palette.node("post"))
					parts.floor_torch(buf, palette, x, y + 3, z)
					lamps[#lamps + 1] = {x = x, y = y + 3, z = z}
				end
			end
		end

		local source, count = buf:cells()
		local cells = {}
		for index = 1, count do cells[index] = source[index] end
		table.sort(cells, function(a, b)
			if a.z ~= b.z then return a.z < b.z end
			if a.y ~= b.y then return a.y < b.y end
			return a.x < b.x
		end)
		return {
			id = spec.id, axis = spec.axis, at = at, from = from, to = to,
			width = width, cells = cells, lamps = lamps,
			pavement = pavement, treads = treads, risers = risers,
			columns = (to - from + 1) * width, queries = queries,
		}
	end

	return M
end

return loader
