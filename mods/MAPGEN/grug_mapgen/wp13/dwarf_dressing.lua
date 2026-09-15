-- Dwarf dressing: the pieces Dur Brannoc's districts need and the shared
-- `dressing.lua` has no generator for.
--
-- WHY A NEW FILE AND NOT SIX MORE FUNCTIONS IN `dressing.lua`. That module is
-- the shared library every settlement of every race is built from, and six
-- shipped start blueprints plus Highcourt are frozen against it byte for byte.
-- Everything here is race-specific -- an ore heap, a mine mouth in a cut rock
-- face, a mushroom bed, a brewer's vats, a carver's blocks, a goat pen -- and
-- the WP13 convention for that is a new `wp13/<race>_*.lua` that the
-- compositions of that race call. Nothing outside Dur Brannoc reads this file.
--
-- WHAT EVERY PIECE HERE OBEYS, because the KAT asserts it of the finished
-- composition and a piece of dressing is where it is easiest to break:
--
--   * NOTHING FLOATS. Every cell either sits on the ground course or on a cell
--     this piece itself wrote under it. The composition KAT walks the cells and
--     refuses a detached one or an island.
--   * A TORCH STANDS ON AN OPAQUE FULL NODE, never on a slab, a stair or a
--     fence. The pieces here that carry light put it on masonry they laid.
--   * A BOTTOM SLAB CARRIES NOTHING. Where a piece wants a step it writes a
--     stair or a full node, and where it wants a lid it writes the slab last.
--   * EVERY NODE NAME COMES FROM A PALETTE ROLE. `palette.lua` is a closed
--     vocabulary and its `optional` roles may be unbound for a race, so every
--     optional role here is read through `maybe` and the piece degrades. The
--     dwarf palette binds all of them; a future race using this file would not
--     have to.
--
-- THE FEATURE RULE OF THE SOCKETS CONTRACT (section 8.1) is why several of
-- these exist at all. A `mine` work socket must face "a stone, ore or cobble
-- node at head or chest height" within three nodes, `brew` "a cauldron, barrel
-- or a cooking pot node", `carve` "a log, a totem/statue part or a stone
-- block", `forage` "a mushroom, a bush, a plant, a vine or leaves", `mourn` "a
-- grave marker, a coffin or a candle". Each piece below is the feature its
-- activity names, built at the height the rule reads.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader(directory)
	local dressing = dofile(directory .. "/dressing.lua")(directory)

	local M = {}

	local function pick(palette, role, fallback)
		local name = palette.maybe(role)
		if name == nil then return palette.node(fallback) end
		return name
	end

	-- A CUT ROCK FACE: the terrace step a dwarf city is carved into, built as a
	-- solid wall of masonry `height` courses tall along one edge of a yard.
	--
	-- It is a wall and not a cliff because a composition may not write terrain:
	-- the plot clears its own airspace and lays its own ground, so the "rock" a
	-- miner swings at is masonry standing on the plot's ground course. It is
	-- the feature a `mine` socket faces, and the top course is at the socket's
	-- chest height when the socket stands one node away.
	--
	-- `axis` is the axis the face runs along; the face is one node thick.
	function M.rock_face(buf, palette, x1, z1, x2, z2, height)
		height = height or 4
		local rock = pick(palette, "castle_wall", "foundation")
		local seam = palette.node("plaza_edge")
		for z = math.min(z1, z2), math.max(z1, z2) do
			for x = math.min(x1, x2), math.max(x1, x2) do
				for y = 1, height do
					-- One banded course, so the face reads as bedded granite
					-- and not as a blank block of wall.
					local name = rock
					if y == height - 1 then name = seam end
					buf:put(x, y, z, name)
				end
			end
		end
	end

	-- A MINE MOUTH: a rock face with an arched opening in it, three wide and
	-- three high, the arch springing on the outer columns. The opening is left
	-- as authored AIR so the KAT's own "no cell floats" walk sees the lintel
	-- carried by the jambs either side of it.
	--
	-- The wall runs along x at the given z and the opening is cut in its
	-- middle, so a socket standing one node on the near side and facing the
	-- wall has masonry at chest and head height in front of it.
	function M.mine_mouth(buf, palette, x, z, width, height)
		width = width or 9
		height = height or 5
		local rock = pick(palette, "castle_wall", "foundation")
		-- THE ARCH AND THE LINTEL ARE RUBBLE MASONRY AND NOT THE BANDED
		-- COURSE, and the reason is a KAT rule rather than a taste: the
		-- composition KAT counts every PAVED cell that stands over air, and in
		-- the dwarf palette `plaza_edge`, `plaza`, `foundation` and `signature`
		-- are all the same two paving nodes. An arch over a three-wide opening
		-- is a cell over air by construction, so it is built out of a node that
		-- is masonry and not paving.
		local seam = pick(palette, "castle_rubble", "wall_accent")
		local half = math.floor(width / 2)
		for column = -half, half do
			for y = 1, height do
				local inside = math.abs(column) <= 1 and y <= 3
				local arch = math.abs(column) == 1 and y == 4
				if not inside then
					local name = rock
					if arch or y == height then name = seam end
					buf:put(x + column, y, z, name)
				end
			end
		end
		-- The lintel over the opening: the middle column's fourth course, which
		-- the two jambs carry.
		buf:put(x, 4, z, seam)
	end

	-- AN ORE HEAP: a stepped cone of spoil, `height` courses tall, every course
	-- standing on the one below it. The top two courses are ore-bearing rock,
	-- which is what a heap beside a mine mouth is and what a `mine` socket
	-- beside it faces.
	function M.ore_heap(buf, palette, x, z, height)
		height = height or 3
		local spoil = palette.node("rubble")
		local rock = palette.node("path")
		local ore = pick(palette, "castle_rubble", "rubble")
		for y = 1, height do
			local radius = height - y
			for dz = -radius, radius do
				for dx = -radius, radius do
					if math.abs(dx) + math.abs(dz) <= radius then
						local name = spoil
						if y == height then name = ore
						elseif y == height - 1 then name = rock end
						buf:put(x + dx, y, z + dz, name)
					end
				end
			end
		end
	end

	-- AN ORE CRATE LINE: cut blocks stacked two courses on a paved apron, the
	-- signature material a mason works. The feature a `carve` socket faces.
	function M.cut_blocks(buf, palette, x, z, length, axis)
		local block = pick(palette, "signature", "foundation")
		local rough = palette.node("wall_accent")
		for step = 0, (length or 3) - 1 do
			local bx, bz = x, z
			if axis == "x" then bx = x + step else bz = z + step end
			buf:put(bx, 1, bz, block)
			if step % 2 == 0 then buf:put(bx, 2, bz, rough) end
		end
	end

	-- A MASON'S BANKER: the low bench a carver works a block on, two courses of
	-- masonry with a half-worked block on top. `carve` faces it.
	function M.banker(buf, palette, x, z)
		local block = pick(palette, "signature", "foundation")
		buf:put(x, 1, z, palette.node("plaza_edge"))
		buf:put(x, 2, z, block)
		local stair = palette.maybe("signature_stair")
		if stair then buf:put(x + 1, 1, z, palette.node("plaza_edge")) end
		if stair then buf:put(x + 1, 2, z, stair) end
	end

	-- A MUSHROOM BED: a raised bed of planter masonry with soil in it and the
	-- growth on top -- ferns and tufts in a dwarf palette, which is what the
	-- `forage` rule calls "a plant". The kerb is written first and the soil
	-- inside it, so nothing stands on air.
	--
	-- THE KERB IS ON THREE SIDES AND NOT FOUR, and the reason is the feature
	-- rule rather than the look. A `forage` socket stands OUTSIDE the bed and
	-- faces it, and the contract's search stops at the first solid node on the
	-- socket's own course; a kerb of masonry on the near side is that node, so
	-- a bed ringed all round is a bed nobody can be said to be working. Open on
	-- the near side, the first thing the socket meets is the soil it forages,
	-- and the bed reads as one you step into rather than as a planter.
	function M.mushroom_bed(buf, palette, x1, z1, x2, z2)
		local low_x, high_x = math.min(x1, x2), math.max(x1, x2)
		local low_z, high_z = math.min(z1, z2), math.max(z1, z2)
		local kerb = palette.node("planter")
		local soil = palette.node("planter_soil")
		for z = low_z, high_z do
			for x = low_x, high_x do
				local edge = (x == low_x or x == high_x or z == high_z)
				buf:put(x, 1, z, edge and kerb or soil)
			end
		end
		-- The crop itself, on the soil and never on the kerb.
		local growth = {palette.node("fern"), palette.node("undergrowth"),
			palette.node("grass_tuft")}
		local index = 0
		for z = low_z, high_z - 1 do
			for x = low_x + 1, high_x - 1 do
				index = index + 1
				if index % 2 == 1 then
					buf:put(x, 2, z, growth[(index % #growth) + 1])
				end
			end
		end
	end

	-- A BREWER'S VAT LINE: cauldrons and barrels on a masonry bed, which is the
	-- feature the `brew` rule names. The bed is written first.
	function M.brew_vats(buf, palette, x, z, count, axis)
		count = count or 3
		local bed = palette.node("plaza_edge")
		local vat = palette.node("hearth")
		local cask = palette.node("storage")
		for step = 0, count - 1 do
			local bx, bz = x, z
			if axis == "x" then bx = x + step * 2 else bz = z + step * 2 end
			buf:put(bx, 1, bz, bed)
			buf:put(bx, 2, bz, (step % 2 == 0) and vat or cask)
		end
	end

	-- A GOAT PEN: a rail round trodden ground with a stone trough in it and a
	-- hay corner. The trough is the thing a `tend` socket stands at; the bed of
	-- growth is what makes the pen read as grazing rather than as a yard.
	function M.goat_pen(buf, palette, x1, z1, x2, z2)
		local low_x, high_x = math.min(x1, x2), math.max(x1, x2)
		local low_z, high_z = math.min(z1, z2), math.max(z1, z2)
		dressing.fence_line(buf, palette, low_x, low_z, high_x, low_z)
		dressing.fence_line(buf, palette, low_x, high_z, high_x, high_z)
		dressing.fence_line(buf, palette, low_x, low_z, low_x, high_z)
		dressing.fence_line(buf, palette, high_x, low_z, high_x, high_z)
		dressing.undergrowth(buf, palette, low_x + 1, low_z + 1, high_x - 1,
			high_z - 1, 3)
		-- The trough: a run of low wall with its own kerb, three long.
		local trough_z = math.floor((low_z + high_z) / 2)
		for step = -1, 1 do
			buf:put(low_x + 2 + step, 1, trough_z, palette.node("low_wall"))
		end
	end

	-- A BARROW LINE: grave markers in a row, the feature `mourn` faces. The
	-- shared `dressing.grave` writes one; this is the row and the kerb it
	-- stands behind, so a barrow field reads as kept ground and not as a
	-- scatter of stones.
	function M.barrow_line(buf, palette, x, z, count, axis, tall)
		count = count or 3
		for step = 0, count - 1 do
			local bx, bz = x, z
			if axis == "x" then bx = x + step * 3 else bz = z + step * 3 end
			dressing.grave(buf, palette, bx, bz, tall and (step % 2 == 0))
		end
	end

	-- A CHARCOAL CLAMP: the covered burn a charcoal burner tends, a squat dome
	-- of earth over a core of billets. `chop` faces the billets beside it.
	function M.charcoal_clamp(buf, palette, x, z)
		local earth = palette.node("ground_bare")
		local coal = palette.node("rubble")
		for dz = -2, 2 do
			for dx = -2, 2 do
				if math.abs(dx) + math.abs(dz) <= 2 then
					buf:put(x + dx, 1, z + dz, earth)
				end
			end
		end
		for dz = -1, 1 do
			for dx = -1, 1 do
				if math.abs(dx) + math.abs(dz) <= 1 then
					buf:put(x + dx, 2, z + dz, coal)
				end
			end
		end
		buf:put(x, 3, z, coal)
	end

	-- A STAIR FLIGHT between two terraces of one yard: `steps` treads of
	-- signature stair with a masonry cheek either side, so a lane that arrives
	-- above a court has a way down that is built rather than implied.
	function M.stair_flight(buf, palette, x, z, steps, axis, face)
		dressing.outer_stair(buf, palette, x, z, steps or 3, axis or "z",
			face or 0)
	end

	return M
end

return loader
