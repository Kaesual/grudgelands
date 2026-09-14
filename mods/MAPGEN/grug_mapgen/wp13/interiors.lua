-- WP13 interior kits: furniture placed inside an already cleared room.
--
-- A kit receives the room rectangle in the building's own local frame
-- (`x1/z1/x2/z2` are the inner floor cells, `y` is the floor node, `h` the
-- top wall course) and returns the list of light cells it produced, so the
-- caller can publish them as landmarks. Kits never write walls or roofs.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local M = {}

-- Facedir for a node whose visible front must look along `face`. A facedir
-- node shows its front tile on the face OPPOSITE facedir_to_dir(param2) --
-- that is the side the placing player stood on -- so the stored value is the
-- half turn of the direction the furniture looks at.
local function front(face)
	return (face + 2) % 4
end

local function torch_side(room, x, z)
	-- Pick the wall this interior cell touches, as a step from the torch to
	-- its support. Cells that touch two walls prefer the x wall.
	if x == room.x1 then return -1, 0, 0 end
	if x == room.x2 then return 1, 0, 0 end
	if z == room.z1 then return 0, 0, -1 end
	if z == room.z2 then return 0, 0, 1 end
	return nil
end

-- A wall torch on the inner face of the room wall next to (x, z).
--
-- The wanted cell is only a wish: interior lights sit at the height of the
-- window band, so the wall cell behind the wish is often a pane, and a
-- wallmounted torch on a pane hangs in a window instead of on a wall. The
-- torch therefore slides along its own wall to the nearest cell whose
-- support is an opaque full node and whose own cell is still free.
function M.wall_light(buf, parts, palette, room, x, y, z, lights)
	local dx, dy, dz = torch_side(room, x, z)
	if not dx then error("wp13 interiors: light is not against a wall", 0) end
	-- The wall runs perpendicular to the direction of its support.
	local sx, sz = (dx == 0) and 1 or 0, (dz == 0) and 1 or 0
	for _, offset in ipairs({0, 1, -1, 2, -2, 3, -3}) do
		local cx, cz = x + sx * offset, z + sz * offset
		if cx >= room.x1 and cx <= room.x2 and cz >= room.z1 and cz <= room.z2 and
				parts.solid_at(buf, cx + dx, y + dy, cz + dz) then
			local here = buf:at(cx, y, cz)
			if here == nil or here.name == "air" then
				parts.wall_torch(buf, palette, cx, y, cz, dx, dy, dz)
				lights[#lights + 1] = {x = cx, y = y, z = cz}
				return
			end
		end
	end
	error("wp13 interiors: indoor light near " .. x .. "," .. y .. "," .. z ..
		" found no solid wall", 0)
end

function M.rug(buf, palette, room, x1, z1, x2, z2, accent)
	local name = palette.node(accent and "rug_accent" or "rug")
	for z = z1, z2 do
		for x = x1, x2 do
			buf:put(x, room.y, z, name)
		end
	end
end

-- A bed with its foot at (x, z) and its head one step along `face`.
function M.bed(buf, parts, palette, room, x, z, face, fancy)
	parts.bed(buf, palette, x, room.y + 1, z, face, fancy)
end

-- A trestle table of `len` cells running along `axis`, with a seat on each
-- long side of the middle cell.
function M.table_set(buf, parts, palette, room, x, z, axis, len)
	for step = 0, len - 1 do
		local cx = axis == "x" and x + step or x
		local cz = axis == "z" and z + step or z
		parts.table_cell(buf, palette, cx, room.y + 1, cz)
	end
	local mid = math.floor((len - 1) / 2)
	local mx = axis == "x" and x + mid or x
	local mz = axis == "z" and z + mid or z
	if axis == "x" then
		parts.seat(buf, palette, mx, room.y + 1, mz - 1, 0)
		parts.seat(buf, palette, mx, room.y + 1, mz + 1, 2)
	else
		parts.seat(buf, palette, mx - 1, room.y + 1, mz, 1)
		parts.seat(buf, palette, mx + 1, room.y + 1, mz, 3)
	end
end

-- A run of shelving against a wall. `face` points away from the wall.
function M.shelves(buf, palette, room, x, z, axis, len, face)
	for step = 0, len - 1 do
		local cx = axis == "x" and x + step or x
		local cz = axis == "z" and z + step or z
		local role = (step % 2 == 0) and "shelf" or "shelf_vessels"
		buf:put(cx, room.y + 1, cz, palette.node(role), front(face))
	end
end

-- Barrels standing against a wall, their lid ring toward the room.
function M.storage(buf, palette, room, x, z, axis, len, face)
	for step = 0, len - 1 do
		local cx = axis == "x" and x + step or x
		local cz = axis == "z" and z + step or z
		buf:put(cx, room.y + 1, cz, palette.node("storage"), front(face))
	end
end

-- A hearth: the iron pot in the fire opening, the fire itself, and the stone
-- breast carrying the flue on up to the caller's chimney.
--
-- There is deliberately no `default:furnace` here. A furnace written through
-- VoxelManip never runs its `on_construct`, so it has no inventory, no
-- formspec and no timer: it is a prop that looks like a service the
-- settlement design does not offer (docs/design/settlements.md: "Furniture
-- does not introduce profession, storage, quest, innkeeper or travel
-- services"). Three static nodes say the same thing honestly, and the torch
-- makes it the warmest corner of the room.
function M.hearth(buf, parts, palette, room, x, z, face, top, lights)
	buf:put(x, room.y + 1, z, palette.node("hearth"), front(face))
	parts.floor_torch(buf, palette, x, room.y + 2, z)
	if lights then lights[#lights + 1] = {x = x, y = room.y + 2, z = z} end
	for y = room.y + 3, top do
		buf:put(x, y, z, palette.node("chimney"))
	end
end

-- ---------------------------------------------------------------------------
-- kits
-- ---------------------------------------------------------------------------

M.kits = {}

-- A lived-in home: bed corner, rug, table and seats, shelf wall, barrel,
-- hearth under the chimney and two wall torches.
function M.kits.home(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	local cz = math.floor((room.z1 + room.z2) / 2)
	M.bed(buf, parts, palette, room, room.x1, room.z1, 0, spec.fancy_bed)
	M.storage(buf, palette, room, room.x1, room.z1 + 2, "z", 1, 1)
	M.rug(buf, palette, room, cx - 1, cz - 1, cx, cz, false)
	M.table_set(buf, parts, palette, room, cx, cz, "x", 2)
	M.shelves(buf, palette, room, room.x2, room.z2 - 1, "z", 2, 3)
	-- A dresser and a crock shelf give the room a second storey of detail.
	buf:put(room.x1, room.y + 1, room.z1 + 3, palette.node("shelf"), front(1))
	buf:put(room.x1, room.y + 2, room.z1 + 3, palette.node("shelf"), front(1))
	buf:put(room.x2, room.y + 2, room.z2 - 1, palette.node("shelf_vessels"),
		front(3))
	-- Hearthside: a stool on a small rug.
	M.rug(buf, palette, room, room.x2 - 1, room.z1, room.x2 - 1, room.z1 + 1,
		true)
	parts.seat(buf, palette, room.x2 - 1, room.y + 1, room.z1 + 1, 1)
	if spec.hearth ~= false then
		M.hearth(buf, parts, palette, room, spec.hearth_x or room.x2,
			spec.hearth_z or room.z1, spec.hearth_face or 3, room.h, lights)
	end
	M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, cz, lights)
	M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, cz, lights)
	return lights
end

-- The forge floor: three hearths on the back wall, two iron anvil blocks,
-- benches, storage and four wall torches.
function M.kits.workshop(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	local cz = math.floor((room.z1 + room.z2) / 2)
	for offset = -2, 2, 2 do
		M.hearth(buf, parts, palette, room, cx + offset, room.z1, 0, room.h,
			lights)
	end
	buf:put(cx - 3, room.y + 1, room.z1, palette.node("workbench"))
	buf:put(cx + 3, room.y + 1, room.z1, palette.node("workbench"))
	M.table_set(buf, parts, palette, room, cx - 1, cz, "x", 3)
	M.storage(buf, palette, room, room.x1, room.z2 - 2, "z", 3, 1)
	M.shelves(buf, palette, room, room.x2, room.z2 - 2, "z", 3, 3)
	M.rug(buf, palette, room, cx - 1, cz + 2, cx + 1, cz + 2, true)
	for _, z in ipairs({room.z1 + 1, room.z2 - 1}) do
		M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, z, lights)
		M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, z, lights)
	end
	return lights
end

-- The smithy wing of the forge: forge fire, anvil block, quench tub bench and
-- a rack of tools. It opens onto the main hall, so its lights hang on the
-- three closed walls only.
function M.kits.smithy(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	local cz = math.floor((room.z1 + room.z2) / 2)
	M.hearth(buf, parts, palette, room, room.x2, cz, 3, room.h, lights)
	buf:put(cx, room.y + 1, cz, palette.node("workbench"))
	buf:put(cx, room.y + 2, cz, palette.node("chimney_cap"))
	M.storage(buf, palette, room, room.x1 + 1, room.z1, "x", 2, 0)
	M.shelves(buf, palette, room, room.x1 + 1, room.z2, "x", 2, 2)
	M.rug(buf, palette, room, cx - 1, cz + 1, cx + 1, cz + 1, true)
	M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, room.z1, lights)
	M.wall_light(buf, parts, palette, room, cx, room.y + 3, room.z2, lights)
	return lights
end

-- The storage building: barrel rows, stacked timber and a work table.
function M.kits.store(buf, parts, palette, room, spec)
	local lights = {}
	local cz = math.floor((room.z1 + room.z2) / 2)
	M.storage(buf, palette, room, room.x1, room.z1 + 1, "z",
		room.z2 - room.z1 - 1, 1)
	M.storage(buf, palette, room, room.x2, room.z1 + 1, "z",
		room.z2 - room.z1 - 1, 3)
	for x = room.x1 + 2, room.x2 - 2, 2 do
		for y = room.y + 1, room.y + 2 do
			buf:put(x, y, room.z1, palette.node("tree_log"))
		end
		buf:put(x, room.y + 3, room.z1, palette.node("roof_slab"))
	end
	M.table_set(buf, parts, palette, room, room.x1 + 2, cz, "x", 3)
	M.shelves(buf, palette, room, room.x1 + 2, room.z2, "x", 3, 2)
	M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, cz, lights)
	M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, cz, lights)
	return lights
end

-- The community hall: two long tables with benches, a hearth, shelf wall and
-- carpet runner down the middle.
function M.kits.hall(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	local cz = math.floor((room.z1 + room.z2) / 2)
	for z = room.z1 + 1, room.z2 - 1 do
		buf:put(cx, room.y, z, palette.node("rug_accent"))
	end
	for _, offset in ipairs({-3, 3}) do
		M.table_set(buf, parts, palette, room, cx + offset, cz - 2, "z", 5)
	end
	M.hearth(buf, parts, palette, room, spec.hearth_x or cx,
		spec.hearth_z or room.z1, spec.hearth_face or 0, room.h, lights)
	M.shelves(buf, palette, room, room.x1, room.z1 + 2, "z", 4, 1)
	M.shelves(buf, palette, room, room.x2, room.z1 + 2, "z", 4, 3)
	M.storage(buf, palette, room, room.x1 + 1, room.z2, "x", 2, 2)
	M.storage(buf, palette, room, room.x2 - 2, room.z2, "x", 2, 2)
	for _, z in ipairs({room.z1 + 2, cz, room.z2 - 2}) do
		M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, z, lights)
		M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, z, lights)
	end
	return lights
end

-- The gate watchpost guard room: one bed, a barrel, a table and a torch.
function M.kits.watch(buf, parts, palette, room, spec)
	local lights = {}
	local cz = math.floor((room.z1 + room.z2) / 2)
	M.bed(buf, parts, palette, room, room.x1, room.z1, 0, false)
	M.storage(buf, palette, room, room.x2, room.z1, "z", 1, 3)
	M.table_set(buf, parts, palette, room, room.x2 - 1, room.z2 - 1, "x", 2)
	M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, cz, lights)
	return lights
end

-- A bench that prefers the palette's own joinery. A race with a
-- `bench_seat` gets the long settle; every other race gets a stair seat,
-- which is what `parts.seat` writes.
function M.settle(buf, parts, palette, room, x, z, axis, len, face)
	local bench = palette.maybe("bench_seat")
	for step = 0, len - 1 do
		local cx = axis == "x" and x + step or x
		local cz = axis == "z" and z + step or z
		if bench then
			buf:put(cx, room.y + 1, cz, bench, front(face))
		else
			parts.seat(buf, palette, cx, room.y + 1, cz, face)
		end
	end
end

-- A board table: the palette's own table where it has one, otherwise the
-- trestle of `table_cell`.
function M.board(buf, parts, palette, room, x, z, axis, len)
	local board = palette.maybe("board_table")
	for step = 0, len - 1 do
		local cx = axis == "x" and x + step or x
		local cz = axis == "z" and z + step or z
		if board then
			buf:put(cx, room.y + 1, cz, board, 0)
		else
			parts.table_cell(buf, palette, cx, room.y + 1, cz)
		end
	end
end

-- The meeting hall: two blocks of benches down a runner, a lectern table on
-- a low dais at the far end, shelves of crocks along the walls and lamps
-- between every second window. Deliberately no bed and no hearth: this is
-- the room the hamlet meets in, not a house.
function M.kits.chapel(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	for z = room.z1, room.z2 do
		buf:put(cx, room.y, z, palette.node("rug_accent"))
	end
	for z = room.z1 + 2, room.z2 - 3, 2 do
		M.settle(buf, parts, palette, room, room.x1 + 1, z, "x", cx - room.x1 - 1, 0)
		M.settle(buf, parts, palette, room, cx + 1, z, "x", room.x2 - cx - 1, 0)
	end
	-- The dais: a step of slab, the lectern on it and a pair of standing
	-- lamps that make the end of the room the bright one.
	for x = cx - 2, cx + 2 do
		buf:put(x, room.y, room.z1, palette.node("plaza_edge"))
	end
	M.board(buf, parts, palette, room, cx, room.z1 + 1, "x", 1)
	M.shelves(buf, palette, room, room.x1, room.z1, "z", 2, 1)
	M.shelves(buf, palette, room, room.x2, room.z1, "z", 2, 3)
	for _, z in ipairs({room.z1 + 2, room.z2 - 2}) do
		M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, z, lights)
		M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, z, lights)
	end
	M.wall_light(buf, parts, palette, room, cx - 2, room.y + 3, room.z1, lights)
	M.wall_light(buf, parts, palette, room, cx + 2, room.y + 3, room.z1, lights)
	return lights
end

-- The inn: a long common table with settles down both sides, the hearth on
-- the gable wall, barrels behind the counter and two made-up beds in the
-- back corner for travellers.
function M.kits.inn(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	local cz = math.floor((room.z1 + room.z2) / 2)
	M.board(buf, parts, palette, room, cx, room.z1 + 2, "z",
		room.z2 - room.z1 - 3)
	M.settle(buf, parts, palette, room, cx - 1, room.z1 + 2, "z",
		room.z2 - room.z1 - 3, 1)
	M.settle(buf, parts, palette, room, cx + 1, room.z1 + 2, "z",
		room.z2 - room.z1 - 3, 3)
	M.rug(buf, palette, room, cx - 1, cz, cx + 1, cz, true)
	M.hearth(buf, parts, palette, room, spec.hearth_x or room.x1,
		spec.hearth_z or room.z1 + 1, spec.hearth_face or 1, room.h, lights)
	M.storage(buf, palette, room, room.x2, room.z1 + 1, "z", 3, 3)
	M.shelves(buf, palette, room, room.x2, room.z2 - 2, "z", 2, 3)
	M.bed(buf, parts, palette, room, room.x1, room.z2, 0)
	M.bed(buf, parts, palette, room, room.x1 + 2, room.z2, 0)
	local mat = palette.maybe("mat")
	if mat then
		buf:put(room.x1 + 1, room.y + 1, room.z2, mat, 0)
	end
	for _, z in ipairs({room.z1 + 2, cz, room.z2 - 1}) do
		M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, z, lights)
		M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, z, lights)
	end
	return lights
end

-- The barn: a straw floor, stacked bales against the gable wall, feed
-- barrels, a work bench and the cart wheels leaning where they were left.
function M.kits.barn(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	local cz = math.floor((room.z1 + room.z2) / 2)
	local straw = palette.maybe("ground_straw")
	if straw then
		for z = room.z1, room.z2 do
			for x = room.x1, room.x2 do
				if (x + z) % 3 ~= 0 then buf:put(x, room.y, z, straw) end
			end
		end
	end
	local bale = palette.maybe("bale")
	if bale then
		for x = room.x1, room.x1 + 2 do
			for z = room.z1, room.z1 + 1 do
				for y = room.y + 1, room.y + 2 + (x % 2) do
					buf:put(x, y, z, bale)
				end
			end
		end
		for y = room.y + 1, room.y + 2 do
			buf:put(room.x2, y, room.z1, bale)
		end
	end
	M.storage(buf, palette, room, room.x2, room.z1 + 2, "z", 3, 3)
	M.board(buf, parts, palette, room, cx + 1, cz, "x", 2)
	M.shelves(buf, palette, room, room.x1, cz, "z", 2, 1)
	-- Timber stacked against the back wall, and the cart wheels on it.
	for x = cx - 1, cx + 1 do
		for y = room.y + 1, room.y + 2 do
			buf:put(x, y, room.z2, palette.node("tree_log"))
		end
	end
	parts.wall_prop(buf, palette, "wheel", cx, room.y + 2, room.z2 - 1, 0, 0, 1)
	parts.wall_prop(buf, palette, "wheel", cx + 1, room.y + 2, room.z2 - 1,
		0, 0, 1)
	for _, z in ipairs({room.z1 + 2, room.z2 - 2}) do
		M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, z, lights)
		M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, z, lights)
	end
	return lights
end

-- An open timber workyard: saw trestles, log stacks, benches and a lamp.
function M.kits.yard(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	local cz = math.floor((room.z1 + room.z2) / 2)
	M.table_set(buf, parts, palette, room, cx - 1, cz, "x", 3)
	for _, corner in ipairs({{room.x1, room.z1}, {room.x2 - 1, room.z1}}) do
		for step = 0, 1 do
			for y = room.y + 1, room.y + 2 do
				buf:put(corner[1] + step, y, corner[2], palette.node("tree_log"))
			end
			buf:put(corner[1] + step, room.y + 3, corner[2],
				palette.node("roof_slab"))
		end
	end
	M.storage(buf, palette, room, room.x1, room.z2, "x", 2, 2)
	buf:put(cx, room.y + 1, room.z2, palette.node("workbench"))
	M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, cz, lights)
	M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, room.z2 - 1,
		lights)
	return lights
end

function M.furnish(kit, buf, parts, palette, room, spec)
	local builder = M.kits[kit]
	if not builder then
		error("wp13 interiors: unknown kit " .. tostring(kit), 0)
	end
	return builder(buf, parts, palette, room, spec or {})
end

return M
