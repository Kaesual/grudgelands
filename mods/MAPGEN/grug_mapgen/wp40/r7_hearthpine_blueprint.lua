-- Hearthpine Vale is authored in local coordinates around the dwarf start.
-- The caller fits y = 0 to the settlement terrain before projecting the cells.
return function()
	local AIR = "air"
	local COBBLE = "default:cobble"
	local DIRT = "default:dirt"
	local FOREST_FLOOR = "default:dirt_with_coniferous_litter"
	local GRASS_FLOOR = "default:dirt_with_grass"
	local FERN = "default:fern_1"
	local GRASS = "default:grass_1"
	local GLASS = "default:glass"
	local PINE_LOG = "default:pine_tree"
	local PINE_NEEDLES = "default:pine_needles"
	local PINE_WOOD = "default:pine_wood"
	local STONE = "default:stone"
	local STONE_BLOCK = "default:stone_block"
	local STONEBRICK = "default:stonebrick"
	local TORCH = "default:torch"
	local TORCH_WALL = "default:torch_wall"
	local FENCE = "default:fence_pine_wood"
	local PINE_SLAB = "stairs:slab_pine_wood"
	local STONE_SLAB = "stairs:slab_stonebrick"
	local STONE_STAIR = "stairs:stair_stonebrick"

	local written = {}

	local function key(x, y, z)
		return x .. ":" .. y .. ":" .. z
	end

	local function put(x, y, z, name, param2)
		written[key(x, y, z)] = {
			x = x, y = y, z = z, name = name, param2 = param2 or 0,
		}
	end

	local function fill(x1, y1, z1, x2, y2, z2, name, param2)
		for z = z1, z2 do
			for y = y1, y2 do
				for x = x1, x2 do
					put(x, y, z, name, param2)
				end
			end
		end
	end

	local function clear(x1, y1, z1, x2, y2, z2)
		fill(x1, y1, z1, x2, y2, z2, AIR)
	end

	local function stone_floor(x1, z1, x2, z2)
		fill(x1, -1, z1, x2, -1, z2, STONE)
		fill(x1, 0, z1, x2, 0, z2, STONEBRICK)
	end

	local function timber_post(x, z, top)
		fill(x, 1, z, x, top, z, PINE_LOG)
	end

	local function framed_wall_x(x1, x2, y1, y2, z)
		fill(x1, y1, z, x2, y2, z, STONEBRICK)
		for x = x1 + 3, x2 - 3, 4 do
			if y2 >= y1 + 2 then
				put(x, y1 + 2, z, GLASS)
			end
		end
	end

	local function table_at(x, y, z, along_x)
		if along_x then
			put(x - 1, y, z, FENCE)
			put(x + 1, y, z, FENCE)
			fill(x - 1, y + 1, z, x + 1, y + 1, z, PINE_SLAB)
		else
			put(x, y, z - 1, FENCE)
			put(x, y, z + 1, FENCE)
			fill(x, y + 1, z - 1, x, y + 1, z + 1, PINE_SLAB)
		end
	end

	local function wall_torch(x, y, z, param2)
		put(x, y, z, TORCH_WALL, param2)
	end

	local function path_light(x, z)
		put(x, 1, z, STONEBRICK)
		put(x, 2, z, STONEBRICK)
		put(x, 3, z, TORCH, 1)
	end

	-- Fit a coherent piece of pine-vale ground beneath the whole authored
	-- footprint before paths and buildings replace selected surface cells.
	-- The sparse deterministic patches keep the pad natural without relying
	-- on mapgen decorations or introducing another random stream.
	fill(-63, -1, -63, 63, -1, 63, DIRT)
	fill(-63, 0, -63, 63, 0, 63, FOREST_FLOOR)
	for z = -61, 61, 7 do
		for x = -61, 61, 9 do
			if (x + z) % 4 == 0 then
				fill(x - 1, 0, z - 1, x + 1, 0, z + 1, GRASS_FLOOR)
			elseif (x - z) % 5 == 0 then
				fill(x - 1, 0, z - 1, x + 1, 0, z + 1, DIRT)
			end
		end
	end

	-- Five-wide arrival road and a small stone plaza. The air writes remove
	-- trees while leaving the surrounding vale untouched.
	fill(-2, -1, -9, 2, -1, 63, STONE)
	fill(-2, 0, -9, 2, 0, 63, COBBLE)
	clear(-2, 1, -9, 2, 3, 63)
	stone_floor(-9, -8, 9, 5)
	clear(-9, 1, -8, 9, 4, 5)
	for z = 8, 45, 6 do
		put(-3, 0, z, STONE_SLAB)
		put(3, 0, z, STONE_SLAB)
	end
	-- Narrow branches make each occupied building reachable without paving
	-- over the green space between them.
	fill(-25, 0, 8, -3, 0, 10, COBBLE)
	clear(-25, 1, 8, -3, 3, 10)
	fill(3, 0, 4, 20, 0, 6, COBBLE)
	clear(3, 1, 4, 20, 3, 6)
	fill(-19, 0, 24, -3, 0, 26, COBBLE)
	clear(-19, 1, 24, -3, 3, 26)
	fill(3, 0, 31, 25, 0, 33, COBBLE)
	clear(3, 1, 31, 25, 3, 33)
	fill(3, 0, 16, 47, 0, 18, COBBLE)
	clear(3, 1, 16, 47, 3, 18)
	fill(45, 0, 8, 47, 0, 18, COBBLE)
	clear(45, 1, 8, 47, 3, 18)
	fill(-45, 0, 9, -34, 0, 11, COBBLE)
	clear(-45, 1, 9, -34, 3, 11)
	fill(-45, 0, 33, -43, 0, 43, COBBLE)
	clear(-45, 1, 33, -43, 3, 43)
	fill(-45, 0, 34, -19, 0, 36, COBBLE)
	clear(-45, 1, 34, -19, 3, 36)
	fill(-41, 0, -18, -34, 0, -16, COBBLE)
	clear(-41, 1, -18, -34, 3, -16)
	fill(-36, 0, -16, -34, 0, 8, COBBLE)
	clear(-36, 1, -16, -34, 3, 8)
	fill(24, 0, 31, 36, 0, 33, COBBLE)
	clear(24, 1, 31, 36, 3, 33)

	-- The Forge Hall: a tall, stone-footed longhouse with pine framing,
	-- deep eaves, a raised hammer roof and a cold masonry hearth.
	clear(-12, 1, -27, 12, 16, -7)
	stone_floor(-10, -25, 10, -9)
	fill(-10, 1, -25, 10, 2, -25, STONEBRICK)
	fill(-10, 1, -9, 10, 2, -9, STONEBRICK)
	fill(-10, 1, -24, -10, 2, -10, STONEBRICK)
	fill(10, 1, -24, 10, 2, -10, STONEBRICK)
	framed_wall_x(-10, 10, 3, 7, -25)
	framed_wall_x(-10, 10, 3, 7, -9)
	fill(-10, 3, -24, -10, 7, -10, PINE_WOOD)
	fill(10, 3, -24, 10, 7, -10, PINE_WOOD)
	for z = -22, -12, 5 do
		put(-10, 5, z, GLASS)
		put(10, 5, z, GLASS)
	end
	for _, x in ipairs({-10, -5, 0, 5, 10}) do
		timber_post(x, -25, 8)
		timber_post(x, -9, 8)
	end
	for _, z in ipairs({-25, -17, -9}) do
		timber_post(-10, z, 8)
		timber_post(10, z, 8)
	end
	-- Broad two-node front door and a smaller rear service door.
	clear(-1, 1, -9, 1, 4, -9)
	clear(-1, 1, -25, 0, 3, -25)
	fill(-11, 8, -26, 11, 8, -8, PINE_WOOD)
	for rise = 0, 6 do
		fill(-11 + rise, 9 + rise, -26, 11 - rise, 9 + rise, -8,
			PINE_WOOD)
	end
	-- Eave silhouette and roof-ridge cap.
	fill(-12, 8, -27, 12, 8, -27, PINE_SLAB)
	fill(-12, 8, -7, 12, 8, -7, PINE_SLAB)
	fill(-5, 15, -27, 5, 15, -7, PINE_SLAB)
	fill(-2, 16, -23, 2, 16, -11, STONE_SLAB)
	-- Hearth, chimney and work benches (decorative blocks only).
	fill(-7, 1, -23, -3, 1, -20, COBBLE)
	fill(-7, 2, -23, -7, 5, -20, STONE_BLOCK)
	fill(-3, 2, -23, -3, 5, -20, STONE_BLOCK)
	fill(-7, 2, -23, -3, 2, -23, STONE_BLOCK)
	fill(-6, 2, -22, -4, 3, -21, AIR)
	fill(-6, 4, -22, -4, 15, -21, STONEBRICK)
	fill(-7, 15, -23, -3, 17, -20, STONEBRICK)
	for z = -21, -13, 4 do
		table_at(5, 1, z, true)
		fill(2, 1, z - 1, 2, 1, z + 1, PINE_SLAB)
	end
	wall_torch(-9, 5, -17, 3)
	wall_torch(9, 5, -17, 2)
	put(0, 1, -14, TORCH, 1)

	-- West home: compact saltbox, offset porch and loft window.
	clear(-33, 1, -7, -18, 11, 12)
	stone_floor(-30, -4, -20, 9)
	fill(-30, 1, -4, -20, 1, -4, STONEBRICK)
	fill(-30, 1, 9, -20, 1, 9, STONEBRICK)
	fill(-30, 1, -3, -30, 1, 8, STONEBRICK)
	fill(-20, 1, -3, -20, 1, 8, STONEBRICK)
	fill(-30, 2, -4, -20, 5, -4, PINE_WOOD)
	fill(-30, 2, 9, -20, 5, 9, PINE_WOOD)
	fill(-30, 2, -3, -30, 5, 8, PINE_WOOD)
	fill(-20, 2, -3, -20, 5, 8, PINE_WOOD)
	for _, p in ipairs({{-30, -4}, {-20, -4}, {-30, 9}, {-20, 9}}) do
		timber_post(p[1], p[2], 6)
	end
	clear(-26, 1, 9, -24, 4, 9)
	fill(-30, 3, 1, -30, 4, 2, GLASS)
	fill(-20, 3, 1, -20, 4, 2, GLASS)
	fill(-31, 6, -5, -19, 6, 10, PINE_WOOD)
	for rise = 0, 4 do
		fill(-31 + rise, 7 + rise, -5, -19 - rise, 7 + rise, 10,
			PINE_WOOD)
	end
	put(-25, 8, 9, GLASS)
	fill(-28, 1, 11, -22, 1, 11, PINE_SLAB)
	fill(-28, 1, 10, -28, 3, 10, FENCE)
	fill(-22, 1, 10, -22, 3, 10, FENCE)
	table_at(-25, 1, 3, true)
	fill(-29, 1, 6, -27, 1, 6, PINE_SLAB)
	wall_torch(-29, 4, 0, 3)
	wall_torch(-28, 3, 8, 4)
	wall_torch(-22, 3, 8, 4)

	-- East home: a wider cross-gabled mason's cottage with a stone bay.
	clear(18, 1, -5, 34, 12, 15)
	stone_floor(20, -2, 31, 12)
	fill(20, 1, -2, 31, 2, -2, STONEBRICK)
	fill(20, 1, 12, 31, 2, 12, STONEBRICK)
	fill(20, 1, -1, 20, 2, 11, STONEBRICK)
	fill(31, 1, -1, 31, 2, 11, STONEBRICK)
	fill(20, 3, -2, 31, 5, -2, PINE_WOOD)
	fill(20, 3, 12, 31, 5, 12, PINE_WOOD)
	fill(20, 3, -1, 20, 5, 11, PINE_WOOD)
	fill(31, 3, -1, 31, 5, 11, PINE_WOOD)
	clear(20, 1, 4, 20, 4, 6)
	fill(24, 3, -2, 25, 4, -2, GLASS)
	fill(25, 3, 12, 26, 4, 12, GLASS)
	fill(31, 3, 1, 31, 4, 2, GLASS)
	fill(19, 6, -3, 32, 6, 13, PINE_WOOD)
	for rise = 0, 5 do
		fill(19 + rise, 7 + rise, -3, 32 - rise, 7 + rise, 13,
			PINE_WOOD)
	end
	-- Stone bay breaks up the otherwise timber side wall.
	fill(28, 1, 3, 33, 3, 8, STONE_BLOCK)
	clear(29, 2, 4, 32, 3, 7)
	fill(28, 4, 3, 33, 4, 8, STONE_SLAB)
	table_at(25, 1, 5, false)
	fill(22, 1, 9, 24, 1, 9, PINE_SLAB)
	wall_torch(30, 4, 11, 4)
	wall_torch(21, 3, 3, 3)
	wall_torch(27, 3, 11, 4)

	-- Open workyard: paved cutting floor, heavy corner posts, asymmetric
	-- lean-to roof, timber racks and a stone shaping bench.
	clear(-38, 1, 17, -16, 10, 35)
	stone_floor(-35, 20, -19, 32)
	for _, p in ipairs({{-35, 20}, {-19, 20}, {-35, 32}, {-19, 32}}) do
		timber_post(p[1], p[2], 7)
	end
	fill(-36, 7, 19, -18, 7, 33, PINE_WOOD)
	fill(-36, 8, 19, -18, 8, 24, PINE_SLAB)
	fill(-34, 6, 25, -20, 6, 33, PINE_WOOD)
	fill(-35, 1, 31, -19, 3, 32, PINE_LOG)
	for x = -33, -21, 4 do
		fill(x, 1, 22, x, 4, 22, PINE_LOG)
		fill(x, 1, 24, x, 3, 24, PINE_LOG)
	end
	fill(-31, 1, 27, -24, 1, 29, STONE_BLOCK)
	fill(-30, 2, 28, -25, 2, 28, STONE_SLAB)
	fill(-35, 5, 24, -35, 5, 28, PINE_LOG)
	fill(-19, 5, 27, -19, 5, 29, PINE_LOG)
	wall_torch(-34, 5, 25, 3)
	wall_torch(-20, 5, 28, 2)

	-- Gatewatch: low twin turrets and an open three-wide arch at the end of
	-- the road. The exterior continuation begins outside the blueprint at z=64.
	clear(-10, 1, 48, 10, 14, 63)
	fill(-9, -1, 49, 9, -1, 63, STONE)
	for _, x1 in ipairs({-9, 4}) do
		local x2 = x1 + 5
		fill(x1, 0, 51, x2, 0, 59, STONEBRICK)
		fill(x1, 1, 51, x2, 6, 51, STONEBRICK)
		fill(x1, 1, 59, x2, 6, 59, STONEBRICK)
		fill(x1, 1, 52, x1, 6, 58, STONEBRICK)
		fill(x2, 1, 52, x2, 6, 58, STONEBRICK)
		clear(x1 + 1, 1, 52, x2 - 1, 5, 58)
		clear(x1 + 2, 1, 51, x1 + 3, 3, 51)
		-- Full-height bearing blocks meet the roof directly. Slabs remain only
		-- on the outside eaves, where their lower nodebox cannot open a gap.
		fill(x1, 7, 51, x2, 7, 59, STONEBRICK)
		fill(x1 - 1, 7, 50, x2 + 1, 7, 50, STONE_SLAB)
		fill(x1 - 1, 7, 60, x2 + 1, 7, 60, STONE_SLAB)
		fill(x1 - 1, 7, 51, x1 - 1, 7, 59, STONE_SLAB)
		fill(x2 + 1, 7, 51, x2 + 1, 7, 59, STONE_SLAB)
		for rise = 0, 3 do
			fill(x1 + rise, 8 + rise, 51, x2 - rise, 8 + rise, 59,
				PINE_WOOD)
		end
	end
	-- Side access links the west turret directly to the public gate passage.
	clear(-4, 1, 54, -3, 3, 56)
	-- A compact stair in the west turret makes its lookout roof playable.
	-- Two-wide treads preserve a human-sized route and conservative geometry
	-- checks may treat each stair node as a full solid block.
	for step = 0, 6 do
		fill(-8, 1 + step, 58 - step, -7, 1 + step, 58 - step,
			STONE_STAIR, 2)
	end
	clear(-8, 7, 53, -7, 10, 55)
	clear(-8, 8, 52, -7, 10, 52)
	clear(-9, 8, 53, -9, 10, 55)
	-- Timber bridge and braces span the entrance without blocking it.
	fill(-3, 5, 55, 3, 6, 55, PINE_LOG)
	fill(-3, 7, 54, 3, 7, 56, PINE_WOOD)
	fill(-2, 1, 51, 2, 4, 59, AIR)
	fill(-2, 0, 51, 2, 0, 63, COBBLE)
	for _, x in ipairs({-3, 3}) do
		fill(x, 1, 54, x, 4, 56, PINE_LOG)
	end
	wall_torch(-3, 4, 53, 4)
	wall_torch(3, 4, 53, 4)
	put(-9, 5, 55, GLASS)
	put(9, 5, 55, GLASS)

	-- South-west home: a narrow gable facing east, with an open porch and
	-- enough headroom around its simple table and sleeping bench.
	clear(-56, 1, -25, -38, 12, -6)
	stone_floor(-53, -22, -41, -9)
	fill(-53, 1, -22, -41, 2, -22, STONEBRICK)
	fill(-53, 1, -9, -41, 2, -9, STONEBRICK)
	fill(-53, 1, -21, -53, 2, -10, STONEBRICK)
	fill(-41, 1, -21, -41, 2, -10, STONEBRICK)
	fill(-53, 3, -22, -41, 6, -22, PINE_WOOD)
	fill(-53, 3, -9, -41, 6, -9, PINE_WOOD)
	fill(-53, 3, -21, -53, 6, -10, PINE_WOOD)
	fill(-41, 3, -21, -41, 6, -10, PINE_WOOD)
	clear(-41, 1, -17, -41, 3, -16)
	fill(-54, 7, -23, -40, 7, -8, PINE_WOOD)
	for rise = 0, 4 do
		fill(-54 + rise, 8 + rise, -23, -40 - rise, 8 + rise, -8,
			PINE_WOOD)
	end
	for _, p in ipairs({{-53, -22}, {-41, -22}, {-53, -9}, {-41, -9}}) do
		timber_post(p[1], p[2], 7)
	end
	put(-47, 4, -22, GLASS)
	put(-47, 4, -9, GLASS)
	table_at(-48, 1, -15, false)
	fill(-52, 1, -11, -49, 1, -11, PINE_SLAB)
	fill(-40, 1, -19, -38, 1, -14, PINE_SLAB)
	wall_torch(-42, 4, -12, 2)
	wall_torch(-40, 3, -15, 3)

	-- East home: rotated ninety degrees, with its broad gable and porch facing
	-- south toward the arrival branch.
	clear(38, 1, -12, 57, 12, 10)
	stone_floor(41, -9, 54, 7)
	fill(41, 1, -9, 54, 2, -9, STONEBRICK)
	fill(41, 1, 7, 54, 2, 7, STONEBRICK)
	fill(41, 1, -8, 41, 2, 6, STONEBRICK)
	fill(54, 1, -8, 54, 2, 6, STONEBRICK)
	fill(41, 3, -9, 54, 6, -9, PINE_WOOD)
	fill(41, 3, 7, 54, 6, 7, PINE_WOOD)
	fill(41, 3, -8, 41, 6, 6, PINE_WOOD)
	fill(54, 3, -8, 54, 6, 6, PINE_WOOD)
	clear(46, 1, 7, 48, 3, 7)
	fill(40, 7, -10, 55, 7, 8, PINE_WOOD)
	for rise = 0, 5 do
		fill(40, 8 + rise, -10 + rise, 55, 8 + rise, 8 - rise,
			PINE_WOOD)
	end
	for _, p in ipairs({{41, -9}, {54, -9}, {41, 7}, {54, 7}}) do
		timber_post(p[1], p[2], 7)
	end
	fill(46, 4, -9, 48, 4, -9, GLASS)
	put(41, 4, 0, GLASS)
	table_at(48, 1, -2, true)
	fill(51, 1, 3, 53, 1, 3, PINE_SLAB)
	fill(44, 1, 9, 51, 1, 9, PINE_SLAB)
	wall_torch(43, 4, 6, 4)
	wall_torch(50, 3, 6, 4)

	-- Lagerhouse: a broad, low store hall with two aisles, stacked timber and
	-- an open loading porch. It conveys use without functional storage nodes.
	clear(15, 1, 22, 39, 12, 45)
	stone_floor(18, 25, 36, 42)
	fill(18, 1, 25, 36, 2, 25, STONEBRICK)
	fill(18, 1, 42, 36, 2, 42, STONEBRICK)
	fill(18, 1, 26, 18, 2, 41, STONEBRICK)
	fill(36, 1, 26, 36, 2, 41, STONEBRICK)
	fill(18, 3, 25, 36, 6, 25, PINE_WOOD)
	fill(18, 3, 42, 36, 6, 42, PINE_WOOD)
	fill(18, 3, 26, 18, 6, 41, PINE_WOOD)
	fill(36, 3, 26, 36, 6, 41, PINE_WOOD)
	clear(25, 1, 25, 27, 3, 25)
	clear(36, 1, 34, 36, 3, 36)
	fill(17, 7, 24, 37, 7, 43, PINE_WOOD)
	for rise = 0, 6 do
		fill(17 + rise, 8 + rise, 24, 37 - rise, 8 + rise, 43,
			PINE_WOOD)
	end
	for _, x in ipairs({18, 24, 30, 36}) do
		timber_post(x, 25, 7)
		timber_post(x, 42, 7)
	end
	for z = 28, 39, 5 do
		fill(20, 1, z, 24, 2, z, PINE_LOG)
		fill(30, 1, z, 34, 3, z, PINE_LOG)
	end
	fill(22, 4, 25, 24, 4, 25, GLASS)
	fill(30, 4, 42, 32, 4, 42, GLASS)
	fill(23, 1, 23, 30, 1, 23, PINE_SLAB)
	wall_torch(19, 4, 33, 3)
	wall_torch(35, 4, 33, 2)
	wall_torch(24, 3, 24, 4)
	wall_torch(28, 3, 26, 5)

	-- Community hall: the largest social room, turned east-west and furnished
	-- with two long tables and perimeter benches.
	clear(-61, 1, 37, -36, 15, 60)
	stone_floor(-58, 40, -39, 57)
	fill(-58, 1, 40, -39, 2, 40, STONEBRICK)
	fill(-58, 1, 57, -39, 2, 57, STONEBRICK)
	fill(-58, 1, 41, -58, 2, 56, STONEBRICK)
	fill(-39, 1, 41, -39, 2, 56, STONEBRICK)
	fill(-58, 3, 40, -39, 7, 40, PINE_WOOD)
	fill(-58, 3, 57, -39, 7, 57, PINE_WOOD)
	fill(-58, 3, 41, -58, 7, 56, PINE_WOOD)
	fill(-39, 3, 41, -39, 7, 56, PINE_WOOD)
	clear(-46, 1, 40, -44, 3, 40)
	clear(-58, 1, 48, -58, 3, 50)
	fill(-59, 8, 39, -38, 8, 58, PINE_WOOD)
	for rise = 0, 7 do
		fill(-59, 9 + rise, 39 + rise, -38, 9 + rise, 58 - rise,
			PINE_WOOD)
	end
	for _, x in ipairs({-58, -52, -48, -39}) do
		timber_post(x, 40, 8)
		timber_post(x, 57, 8)
	end
	fill(-54, 4, 40, -52, 4, 40, GLASS)
	fill(-45, 4, 57, -43, 4, 57, GLASS)
	for x = -53, -43, 5 do
		table_at(x, 1, 48, false)
	end
	fill(-57, 1, 44, -57, 1, 53, PINE_SLAB)
	fill(-40, 1, 44, -40, 1, 53, PINE_SLAB)
	fill(-49, 1, 38, -42, 1, 38, PINE_SLAB)
	wall_torch(-57, 5, 48, 3)
	wall_torch(-40, 5, 48, 2)
	wall_torch(-48, 3, 39, 4)
	wall_torch(-49, 3, 41, 5)

	-- Low roadside lights, benches and material stacks make the routes usable
	-- and occupied after dark without enclosing the vale.
	for _, p in ipairs({{-4, 5}, {4, 5}, {-4, 16}, {4, 16},
		{-4, 27}, {4, 27}, {-4, 38}, {4, 38},
		{-4, 49}, {4, 49}, {-4, 60}, {4, 60},
		{-17, 9}, {17, 5}, {-43, 25}, {15, 32}}) do
		path_light(p[1], p[2])
	end
	fill(10, 1, 10, 14, 1, 10, PINE_SLAB)
	fill(-14, 1, 15, -10, 1, 15, PINE_SLAB)
	fill(10, 1, 17, 14, 3, 18, PINE_LOG)
	fill(-14, 1, 39, -10, 2, 40, PINE_LOG)
	for x = 10, 14 do put(x, 1, 28, STONEBRICK) end
	for x = 10, 14, 2 do put(x, 2, 28, STONE_SLAB) end

	-- A few hand-placed pine clusters and undergrowth soften the broad pad.
	-- Their coordinates stay well away from roads, doors and building shells.
	for _, p in ipairs({{-60, -31}, {-34, -39}, {43, -34}, {58, 20}}) do
		fill(p[1], 1, p[2], p[1], 4, p[2], PINE_LOG)
		fill(p[1] - 2, 4, p[2] - 2, p[1] + 2, 5, p[2] + 2,
			PINE_NEEDLES)
		fill(p[1] - 1, 6, p[2] - 1, p[1] + 1, 7, p[2] + 1,
			PINE_NEEDLES)
		put(p[1], 8, p[2], PINE_NEEDLES)
		fill(p[1], 1, p[2], p[1], 6, p[2], PINE_LOG)
	end
	for _, p in ipairs({{-57, -17}, {-36, -15}, {-15, -35}, {16, -35},
		{34, 18}, {48, 16}, {-31, 42}, {-18, 45}}) do
		put(p[1], 1, p[2], FERN)
	end
	for _, p in ipairs({{-55, 16}, {-32, 14}, {-15, 12}, {14, 13},
		{39, 15}, {53, 14}, {-31, 56}, {14, 43}}) do
		put(p[1], 1, p[2], GRASS)
	end

	-- Preserve the five-wide north road as a final, uninterrupted walkable
	-- strip through the arrival plaza and gate passage.
	fill(-2, 0, 0, 2, 0, 63, COBBLE)
	clear(-2, 1, 0, 2, 3, 63)

	local cells = {}
	for _, cell in pairs(written) do
		cells[#cells + 1] = cell
	end
	table.sort(cells, function(a, b)
		if a.z ~= b.z then return a.z < b.z end
		if a.y ~= b.y then return a.y < b.y end
		return a.x < b.x
	end)

	local final_names = {}
	for index = 1, #cells do final_names[cells[index].name] = true end
	local palette = {}
	for name in pairs(final_names) do palette[#palette + 1] = name end
	table.sort(palette)

	local first = cells[1]
	local minp = {x = first.x, y = first.y, z = first.z}
	local maxp = {x = first.x, y = first.y, z = first.z}
	for index = 2, #cells do
		local cell = cells[index]
		if cell.x < minp.x then minp.x = cell.x end
		if cell.y < minp.y then minp.y = cell.y end
		if cell.z < minp.z then minp.z = cell.z end
		if cell.x > maxp.x then maxp.x = cell.x end
		if cell.y > maxp.y then maxp.y = cell.y end
		if cell.z > maxp.z then maxp.z = cell.z end
	end

	return {
		schema = "grug_wp13_hearthpine_blueprint_v1",
		cells = cells,
		bounds = {min = minp, max = maxp},
		palette = palette,
		landmarks = {
			spawn = {x = 0, y = 1, z = 0},
			arrival = {x = 0, y = 1, z = 0},
			gate = {x = 0, y = 1, z = 63},
			arrival_plaza = {min = {x = -9, y = 0, z = -8},
				max = {x = 9, y = 4, z = 5}},
			main_street = {min = {x = -2, y = 0, z = 0},
				max = {x = 2, y = 3, z = 63}},
			forge_hall = {min = {x = -12, y = -1, z = -27},
				max = {x = 12, y = 17, z = -7}},
			forge_hall_door = {x = 0, y = 1, z = -9},
			west_home = {min = {x = -33, y = -1, z = -7},
				max = {x = -18, y = 11, z = 12}},
			west_home_door = {x = -25, y = 2, z = 9},
			east_home = {min = {x = 18, y = -1, z = -5},
				max = {x = 34, y = 12, z = 15}},
			east_home_door = {x = 20, y = 2, z = 5},
			workyard = {min = {x = -38, y = -1, z = 17},
				max = {x = -16, y = 8, z = 35}},
			gatewatch = {min = {x = -10, y = -1, z = 48},
				max = {x = 10, y = 11, z = 63}},
			gate_passage = {min = {x = -2, y = 1, z = 51},
				max = {x = 2, y = 4, z = 63}},
			southwest_home = {min = {x = -56, y = -1, z = -25},
				max = {x = -38, y = 12, z = -6}},
			east_gable_home = {min = {x = 38, y = -1, z = -12},
				max = {x = 57, y = 13, z = 10}},
			lagerhouse = {min = {x = 15, y = -1, z = 22},
				max = {x = 39, y = 14, z = 45}},
			community_hall = {min = {x = -61, y = -1, z = 37},
				max = {x = -36, y = 16, z = 60}},
			destinations = {
				{id = "forge_hall", x = 0, y = 1, z = -12},
				{id = "west_home", x = -25, y = 1, z = 7},
				{id = "east_home", x = 22, y = 1, z = 5},
				{id = "workyard", x = -27, y = 1, z = 26},
				{id = "gatewatch_roof", x = -9, y = 8, z = 55},
				{id = "southwest_home", x = -45, y = 1, z = -18},
				{id = "east_gable_home", x = 45, y = 1, z = 1},
				{id = "lagerhouse", x = 27, y = 1, z = 34},
				{id = "community_hall", x = -49, y = 1, z = 48},
			},
			lights = {
				{x = 28, y = 3, z = 26},
				{x = -49, y = 3, z = 41},
				{x = -9, y = 5, z = -17},
				{x = 9, y = 5, z = -17},
				{x = 0, y = 1, z = -14},
				{x = -29, y = 4, z = 0},
				{x = -28, y = 3, z = 8},
				{x = -22, y = 3, z = 8},
				{x = 30, y = 4, z = 11},
				{x = 21, y = 3, z = 3},
				{x = 27, y = 3, z = 11},
				{x = -34, y = 5, z = 25},
				{x = -20, y = 5, z = 28},
				{x = -3, y = 4, z = 53},
				{x = 3, y = 4, z = 53},
				{x = -42, y = 4, z = -12},
				{x = -40, y = 3, z = -15},
				{x = 43, y = 4, z = 6},
				{x = 50, y = 3, z = 6},
				{x = 19, y = 4, z = 33},
				{x = 35, y = 4, z = 33},
				{x = 24, y = 3, z = 24},
				{x = -57, y = 5, z = 48},
				{x = -40, y = 5, z = 48},
				{x = -48, y = 3, z = 39},
				{x = -4, y = 3, z = 5},
				{x = 4, y = 3, z = 5},
				{x = -4, y = 3, z = 16},
				{x = 4, y = 3, z = 16},
				{x = -4, y = 3, z = 27},
				{x = 4, y = 3, z = 27},
				{x = -4, y = 3, z = 38},
				{x = 4, y = 3, z = 38},
				{x = -4, y = 3, z = 49},
				{x = 4, y = 3, z = 49},
				{x = -4, y = 3, z = 60},
				{x = 4, y = 3, z = 60},
				{x = -17, y = 3, z = 9},
				{x = 17, y = 3, z = 5},
				{x = -43, y = 3, z = 25},
				{x = 15, y = 3, z = 32},
			},
		},
	}
end
