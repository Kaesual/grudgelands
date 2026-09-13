-- Hearthpine Vale is authored in local coordinates around the dwarf start.
-- The caller fits y = 0 to the settlement terrain before projecting the cells.
return function()
	local AIR = "air"
	local COBBLE = "default:cobble"
	local GLASS = "default:glass"
	local PINE_LOG = "default:pine_tree"
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
	put(-29, 4, 2, GLASS)
	put(-20, 4, 2, GLASS)
	fill(-31, 6, -5, -19, 6, 10, PINE_WOOD)
	for rise = 0, 4 do
		fill(-31 + rise, 7 + rise, -5, -19 - rise, 7 + rise, 10,
			PINE_WOOD)
	end
	put(-25, 8, 9, GLASS)
	fill(-28, 1, 11, -22, 1, 11, PINE_SLAB)
	fill(-28, 1, 10, -28, 3, 10, FENCE)
	fill(-22, 1, 10, -22, 3, 10, FENCE)
	table_at(-25, 2, 3, true)
	fill(-29, 2, 6, -27, 2, 6, PINE_SLAB)
	wall_torch(-29, 4, -1, 3)

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
	put(25, 4, -2, GLASS)
	put(26, 4, 12, GLASS)
	put(31, 4, 1, GLASS)
	fill(19, 6, -3, 32, 6, 13, PINE_WOOD)
	for rise = 0, 5 do
		fill(19 + rise, 7 + rise, -3, 32 - rise, 7 + rise, 13,
			PINE_WOOD)
	end
	-- Stone bay breaks up the otherwise timber side wall.
	fill(28, 1, 3, 33, 3, 8, STONE_BLOCK)
	clear(29, 2, 4, 32, 3, 7)
	fill(28, 4, 3, 33, 4, 8, STONE_SLAB)
	table_at(25, 2, 5, false)
	fill(22, 2, 9, 24, 2, 9, PINE_SLAB)
	wall_torch(30, 4, 9, 2)

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
		fill(x1 - 1, 7, 50, x2 + 1, 7, 60, STONE_SLAB)
		for rise = 0, 3 do
			fill(x1 + rise, 8 + rise, 51, x2 - rise, 8 + rise, 59,
				PINE_WOOD)
		end
	end
	-- A compact stair in the west turret makes its lookout roof playable.
	-- Two-wide treads preserve a human-sized route and conservative geometry
	-- checks may treat each stair node as a full solid block.
	for step = 0, 6 do
		fill(-8, 1 + step, 58 - step, -7, 1 + step, 58 - step,
			STONE_STAIR, 2)
	end
	clear(-8, 7, 53, -7, 9, 53)
	clear(-8, 8, 52, -7, 10, 52)
	-- Timber bridge and braces span the entrance without blocking it.
	fill(-3, 5, 55, 3, 6, 55, PINE_LOG)
	fill(-3, 7, 54, 3, 7, 56, PINE_WOOD)
	fill(-2, 1, 51, 2, 4, 59, AIR)
	fill(-2, 0, 51, 2, 0, 63, COBBLE)
	for _, x in ipairs({-3, 3}) do
		fill(x, 1, 54, x, 4, 56, PINE_LOG)
	end
	wall_torch(-4, 4, 53, 3)
	wall_torch(4, 4, 53, 2)
	put(-7, 6, 55, GLASS)
	put(7, 6, 55, GLASS)

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
			destinations = {
				{id = "forge_hall", x = 0, y = 1, z = -12},
				{id = "west_home", x = -25, y = 1, z = 7},
				{id = "east_home", x = 22, y = 1, z = 5},
				{id = "workyard", x = -27, y = 1, z = 26},
				{id = "gatewatch_roof", x = -9, y = 9, z = 55},
			},
			lights = {
				{x = -9, y = 5, z = -17},
				{x = 9, y = 5, z = -17},
				{x = 0, y = 1, z = -14},
				{x = -29, y = 4, z = -1},
				{x = 30, y = 4, z = 9},
				{x = -34, y = 5, z = 25},
				{x = -20, y = 5, z = 28},
				{x = -4, y = 4, z = 53},
				{x = 4, y = 4, z = 53},
			},
		},
	}
end
