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
	-- The dais sits at the end of the runner AWAY from the door: a door on
	-- the z+ wall puts it at z1, any other door side puts it at z2 (the
	-- runner always follows the room's z axis). Found by the user's Dawnmere
	-- playtest on 2026-09-14, where the lectern faced the entrance.
	local door_side = spec and spec.door_side or "z-"
	local dais_at_z1 = door_side == "z+"
	local function ez(k)
		if dais_at_z1 then return room.z1 + k end
		return room.z2 - k
	end
	for z = room.z1, room.z2 do
		buf:put(cx, room.y, z, palette.node("rug_accent"))
	end
	-- Bench rows start two cells from the dais and leave a two-cell aisle
	-- at the door end.
	for k = 2, room.z2 - room.z1 - 3, 2 do
		local z = ez(k)
		M.settle(buf, parts, palette, room, room.x1 + 1, z, "x", cx - room.x1 - 1, 0)
		M.settle(buf, parts, palette, room, cx + 1, z, "x", room.x2 - cx - 1, 0)
	end
	-- The dais: a step of slab, the lectern on it and a pair of standing
	-- lamps that make the end of the room the bright one.
	for x = cx - 2, cx + 2 do
		buf:put(x, room.y, ez(0), palette.node("plaza_edge"))
	end
	M.board(buf, parts, palette, room, cx, ez(1), "x", 1)
	local shelf_z = dais_at_z1 and room.z1 or room.z2 - 1
	M.shelves(buf, palette, room, room.x1, shelf_z, "z", 2, 1)
	M.shelves(buf, palette, room, room.x2, shelf_z, "z", 2, 3)
	for _, z in ipairs({room.z1 + 2, room.z2 - 2}) do
		M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, z, lights)
		M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, z, lights)
	end
	M.wall_light(buf, parts, palette, room, cx - 2, room.y + 3, ez(0), lights)
	M.wall_light(buf, parts, palette, room, cx + 2, room.y + 3, ez(0), lights)
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

-- The crypt-chapel: the hall of the Hollow, and the one room whose floor is
-- not flat. A board walkway runs round the inside of the walls at the usual
-- course; between the walkways the nave is sunk one node into stone, so the
-- room reads as a vault the hamlet built its chapel over rather than a hall
-- with a dark carpet.
--
-- The drop is exactly one node, which the conservative walk crosses, and the
-- doorway row stays at walkway level so the door's inside foot is standable
-- like every other door in the game. Sarcophagus lids line the nave, the
-- altar tomb closes the far end with a standing light at each shoulder, and
-- the only fire in the room is the vigil cauldron in the corner. There is
-- deliberately no bed: the dead keep this room, they do not sleep in it.
function M.kits.crypt(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	local nave = {x1 = room.x1 + 2, x2 = room.x2 - 2,
		z1 = room.z1 + 2, z2 = room.z2 - 2}

	-- Sink the nave and kerb its edge, so the walkway has a visible lip.
	for z = nave.z1, nave.z2 do
		for x = nave.x1, nave.x2 do
			buf:put(x, room.y - 1, z, palette.node("plaza"))
			buf:put(x, room.y, z, "air", 0)
		end
	end
	for z = nave.z1 - 1, nave.z2 + 1 do
		for x = nave.x1 - 1, nave.x2 + 1 do
			if x == nave.x1 - 1 or x == nave.x2 + 1 or
					z == nave.z1 - 1 or z == nave.z2 + 1 then
				buf:put(x, room.y, z, palette.node("plaza_edge"))
			end
		end
	end

	-- Sarcophagi: a lid of slab on a kerb of low wall, down both sides of
	-- the sunken nave.
	for z = nave.z1 + 1, nave.z2 - 2, 3 do
		for _, x in ipairs({nave.x1, nave.x2}) do
			buf:put(x, room.y, z, palette.node("low_wall"))
			buf:put(x, room.y, z + 1, palette.node("low_wall"))
			buf:put(x, room.y + 1, z, palette.node("roof_slab"), 0)
			buf:put(x, room.y + 1, z + 1, palette.node("roof_slab"), 0)
		end
	end

	-- The altar tomb at the head of the nave, with a standing light at each
	-- shoulder. Those two and the vigil cauldron are the room's only fires.
	for x = cx - 1, cx + 1 do
		buf:put(x, room.y, nave.z2, palette.node("foundation"))
		buf:put(x, room.y + 1, nave.z2, palette.node("chimney_cap"), 0)
	end
	for _, x in ipairs({cx - 2, cx + 2}) do
		buf:put(x, room.y, nave.z2, palette.node("foundation"))
		parts.floor_torch(buf, palette, x, room.y + 1, nave.z2)
		lights[#lights + 1] = {x = x, y = room.y + 1, z = nave.z2}
	end

	-- Pews on the walkway, the urn shelves on the side walls, the vigil
	-- cauldron in the near corner and its flue.
	for z = room.z1 + 2, room.z2 - 3, 2 do
		M.settle(buf, parts, palette, room, room.x1, z, "z", 1, 1)
		M.settle(buf, parts, palette, room, room.x2, z, "z", 1, 3)
	end
	M.shelves(buf, palette, room, room.x1, room.z2 - 1, "z", 2, 1)
	M.shelves(buf, palette, room, room.x2, room.z2 - 1, "z", 2, 3)
	M.hearth(buf, parts, palette, room, spec.hearth_x or room.x2,
		spec.hearth_z or room.z1, spec.hearth_face or 3, room.h, lights)
	for _, z in ipairs({room.z1 + 2, room.z2 - 2}) do
		M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, z, lights)
		M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, z, lights)
	end
	return lights
end

-- The bone-carver's floor: the stone bench under the window, the rack of
-- stock, the sorting barrels and a second bench in the wing. No forge fire --
-- carving bone is cold work -- so the light is candles, not a hearth.
function M.kits.carver(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	local cz = math.floor((room.z1 + room.z2) / 2)
	for x = cx - 2, cx + 2 do
		buf:put(x, room.y + 1, room.z1, palette.node("workbench"))
	end
	buf:put(cx, room.y + 2, room.z1, palette.node("chimney_cap"), 0)
	M.board(buf, parts, palette, room, cx - 1, cz, "x", 3)
	M.settle(buf, parts, palette, room, cx - 1, cz + 1, "x", 3, 2)
	M.storage(buf, palette, room, room.x1, room.z2 - 2, "z", 3, 1)
	M.shelves(buf, palette, room, room.x2, room.z2 - 2, "z", 3, 3)
	M.rug(buf, palette, room, cx - 1, cz + 2, cx + 1, cz + 2, true)
	for _, z in ipairs({room.z1 + 1, room.z2 - 1}) do
		M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, z, lights)
		M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, z, lights)
	end
	return lights
end

-- The carver's drying wing: the stock racks, a sorting table and one light.
-- It opens onto the main floor, so its light hangs on a closed wall only.
function M.kits.carver_wing(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	local cz = math.floor((room.z1 + room.z2) / 2)
	buf:put(cx, room.y + 1, cz, palette.node("workbench"))
	buf:put(cx, room.y + 2, cz, palette.node("chimney_cap"), 0)
	M.storage(buf, palette, room, room.x1 + 1, room.z1, "x", 2, 0)
	M.shelves(buf, palette, room, room.x1 + 1, room.z2, "x", 2, 2)
	M.rug(buf, palette, room, cx - 1, cz + 1, cx + 1, cz + 1, false)
	M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, room.z1, lights)
	M.wall_light(buf, parts, palette, room, cx, room.y + 3, room.z2, lights)
	return lights
end

-- The spirit lodge: one open floor round a central fire, woven mats and low
-- stair benches facing it, crocks on the side walls and lamps between every
-- window. Deliberately no bed: this is the room the throng meets in.
function M.kits.lodge(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	local cz = math.floor((room.z1 + room.z2) / 2)
	local mat = palette.maybe("mat")
	for z = cz - 2, cz + 2 do
		for x = cx - 2, cx + 2 do
			if math.abs(x - cx) + math.abs(z - cz) > 1 then
				buf:put(x, room.y, z, palette.node("rug"))
			end
		end
	end
	-- The fire in the middle of the floor, its flue rising to the ridge.
	M.hearth(buf, parts, palette, room, cx, cz, 0, room.h, lights)
	-- Two benches to each side, looking inward across the fire.
	for _, row in ipairs({{cz - 4, 0}, {cz + 4, 2}}) do
		M.settle(buf, parts, palette, room, cx - 3, row[1], "x", 7, row[2])
	end
	if mat then
		for _, row in ipairs({cz - 3, cz + 3}) do
			for x = cx - 3, cx + 3 do
				buf:put(x, room.y + 1, row, mat, 0)
			end
		end
	end
	M.shelves(buf, palette, room, room.x1, room.z1 + 1, "z", 3, 1)
	M.shelves(buf, palette, room, room.x2, room.z1 + 1, "z", 3, 3)
	M.storage(buf, palette, room, room.x1, room.z2 - 2, "z", 2, 1)
	M.storage(buf, palette, room, room.x2, room.z2 - 2, "z", 2, 3)
	M.rug(buf, palette, room, cx, room.z1, cx, room.z1, true)
	for _, z in ipairs({room.z1 + 2, cz, room.z2 - 2}) do
		M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, z, lights)
		M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, z, lights)
	end
	return lights
end

-- The fish smoker and kitchen: a row of smoking fires on the gable wall,
-- soaking tubs down the middle, crocks and barrels on the long walls and a
-- rope line of split fish hanging over the floor.
function M.kits.smoker(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	local cz = math.floor((room.z1 + room.z2) / 2)
	-- The smoking fires stand against the BACK wall, so the doorway in the
	-- front wall stays a doorway: an interior kit that furnishes the cell a
	-- door opens onto has built a wall, not a room.
	for offset = -2, 2, 2 do
		M.hearth(buf, parts, palette, room, cx + offset, room.z2, 2, room.h,
			lights)
	end
	for _, tub in ipairs({{cx - 1, cz}, {cx + 1, cz}, {cx, cz + 2}}) do
		buf:put(tub[1], room.y + 1, tub[2], palette.node("workbench"))
	end
	M.board(buf, parts, palette, room, cx - 1, cz - 2, "x", 3)
	M.storage(buf, palette, room, room.x1, room.z1 + 2, "z", 3, 1)
	M.shelves(buf, palette, room, room.x2, room.z1 + 2, "z", 3, 3)
	M.rug(buf, palette, room, cx, room.z1 + 1, cx, room.z1 + 1, true)
	-- The drying line: a tie beam across the room with rope hung off it. The
	-- beam is written first so every rope cell has a solid node above it, the
	-- same support rule the outdoor racks obey.
	local rope = palette.maybe("rope")
	if rope then
		for x = room.x1, room.x2 do
			buf:put(x, room.h, room.z2 - 2, palette.node("beam"))
		end
		for x = room.x1 + 1, room.x2 - 1, 2 do
			buf:put(x, room.h - 1, room.z2 - 2, rope)
		end
	end
	for _, z in ipairs({room.z1 + 2, room.z2 - 1}) do
		M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, z, lights)
		M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, z, lights)
	end
	return lights
end

-- ---------------------------------------------------------------------------
-- capital kits (docs/research/wp13-capital-library.md)
-- ---------------------------------------------------------------------------
--
-- The five district buildings of a capital are ordinary `buildings.build`
-- blocks with a kit of their own, so they inherit the walls, the framed
-- windows, the real doors and the rasterised roof of every other building in
-- the library. Each kit keeps the room's CENTRE COLUMN clear from wall to
-- wall: that aisle is where the generator publishes its NPC sockets, and a
-- socket has to stand on a walkable node with two free cells over it
-- (docs/research/wp13-npc-sockets-contract.md section 2). Nothing here writes
-- a node with an `on_construct`; the storage, shelf, workbench and hearth
-- roles are the same static decor the start kits use.

-- Bunks down both side walls, arms racked at the far end, a fire by the door.
function M.kits.barracks(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	for z = room.z1 + 1, room.z2 - 1 do
		buf:put(cx, room.y, z, palette.node("rug"))
	end
	-- Bunks: foot against the wall, head one step into the room, so the pair
	-- of bed nodes never crosses the aisle.
	local bunks = 0
	for z = room.z1 + 1, room.z2 - 2, 3 do
		M.bed(buf, parts, palette, room, room.x1, z, 1, false)
		M.bed(buf, parts, palette, room, room.x2, z, 3, false)
		bunks = bunks + 2
	end
	if bunks == 0 then error("wp13 interiors: barracks with no bunk", 0) end
	M.storage(buf, palette, room, room.x1 + 1, room.z2, "x", 2, 2)
	M.storage(buf, palette, room, room.x2 - 2, room.z2, "x", 2, 2)
	M.shelves(buf, palette, room, room.x1 + 1, room.z1, "x", 2, 0)
	-- The fire sits against the wall the generator runs its chimney stack
	-- up, the way `buildings.cottage` pairs them: the flue is the interior
	-- cell and the stack the wall cell beside it.
	M.hearth(buf, parts, palette, room, room.x2, room.z1,
		spec.hearth_face or 0, room.h, lights)
	for _, z in ipairs({room.z1 + 2, room.z2 - 2}) do
		M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, z, lights)
		M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, z, lights)
	end
	return lights
end

-- A temple or shrine: a runner up the middle, benches either side, and an
-- altar of the race's own board and candlelight at the far end.
function M.kits.temple(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	for z = room.z1 + 1, room.z2 - 1 do
		buf:put(cx, room.y, z, palette.node("rug_accent"))
	end
	local rows = 0
	for z = room.z1 + 2, room.z2 - 4, 2 do
		M.settle(buf, parts, palette, room, cx - 2, z, "x", 2, 1)
		M.settle(buf, parts, palette, room, cx + 1, z, "x", 2, 3)
		rows = rows + 1
	end
	if rows == 0 then error("wp13 interiors: temple with no bench row", 0) end
	-- The altar: a board table across the head of the nave with a standing
	-- light on each side of it, both on the floor and both against a table
	-- that carries nothing, so no prop stands on half a node of air.
	M.board(buf, parts, palette, room, cx - 1, room.z2 - 1, "x", 3)
	for _, offset in ipairs({-2, 2}) do
		parts.floor_torch(buf, palette, cx + offset, room.y + 1, room.z2 - 1)
		lights[#lights + 1] = {x = cx + offset, y = room.y + 1, z = room.z2 - 1}
	end
	M.shelves(buf, palette, room, room.x1, room.z1 + 1, "z", 2, 1)
	M.shelves(buf, palette, room, room.x2, room.z1 + 1, "z", 2, 3)
	for _, z in ipairs({room.z1 + 3, room.z2 - 3}) do
		M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, z, lights)
		M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, z, lights)
	end
	return lights
end

-- A scriptorium: shelving the length of both side walls, reading desks in
-- front of it, and a lamp over every second desk.
function M.kits.scriptorium(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	local shelf_len = room.z2 - room.z1 - 1
	M.shelves(buf, palette, room, room.x1, room.z1 + 1, "z", shelf_len, 1)
	M.shelves(buf, palette, room, room.x2, room.z1 + 1, "z", shelf_len, 3)
	local desks = 0
	for z = room.z1 + 2, room.z2 - 2, 3 do
		M.board(buf, parts, palette, room, room.x1 + 1, z, "z", 2)
		M.board(buf, parts, palette, room, room.x2 - 1, z, "z", 2)
		parts.seat(buf, palette, room.x1 + 2, room.y + 1, z, 3)
		parts.seat(buf, palette, room.x2 - 2, room.y + 1, z, 1)
		desks = desks + 2
	end
	if desks == 0 then error("wp13 interiors: scriptorium with no desk", 0) end
	M.storage(buf, palette, room, cx - 1, room.z2, "x", 3, 2)
	for _, z in ipairs({room.z1 + 2, room.z2 - 2}) do
		M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, z, lights)
		M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, z, lights)
	end
	return lights
end

-- A granary: bins of grain along both walls under a straw floor, sacks and
-- barrels stacked at the gable end.
function M.kits.granary(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	local straw = palette.maybe("ground_straw")
	if straw then
		for z = room.z1, room.z2 do
			for x = room.x1, room.x2 do
				if x ~= cx then buf:put(x, room.y, z, straw) end
			end
		end
	end
	local bins = 0
	for z = room.z1 + 1, room.z2 - 1 do
		buf:put(room.x1, room.y + 1, z, palette.node("wall_accent"))
		buf:put(room.x2, room.y + 1, z, palette.node("wall_accent"))
		bins = bins + 2
	end
	if bins == 0 then error("wp13 interiors: granary with no bin", 0) end
	local bale = palette.maybe("bale")
	for _, offset in ipairs({-1, 1}) do
		buf:put(cx + offset, room.y + 1, room.z2, bale or palette.node("storage"),
			bale and 0 or front(2))
	end
	M.storage(buf, palette, room, room.x1 + 1, room.z1, "x", 2, 0)
	M.storage(buf, palette, room, room.x2 - 2, room.z1, "x", 2, 0)
	for _, z in ipairs({room.z1 + 2, room.z2 - 2}) do
		M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, z, lights)
		M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, z, lights)
	end
	return lights
end

-- A stable: fence partitions between the boxes, bedding in each box and a
-- feed trough against the head wall, with the centre aisle left open.
function M.kits.stable(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	local mat = palette.maybe("mat")
	local boxes = 0
	for z = room.z1 + 1, room.z2 - 1, 2 do
		for _, side in ipairs({room.x1, room.x2}) do
			local step = (side == room.x1) and 1 or -1
			-- The water trough is the race's own cauldron, not its work top:
			-- `workbench` is an anvil in two palettes and an iron block in a
			-- third, and an anvil in a horse box is a prop that means the
			-- wrong thing. Only some of these carry an orientation, so the
			-- facedir is written only where the node has a paramtype2 to
			-- record one in -- a facedir on a node without one is a value no
			-- placement could have produced and `Buffer:put` refuses it.
			local trough = palette.node("hearth")
			buf:put(side, room.y + 1, z, trough,
				(parts.param2_kind(trough) == parts.FACEDIR) and
					front(step == 1 and 1 or 3) or 0)
			-- The bedding lies ON the floor, not in it: a straw mat is a thin
			-- nodebox at the bottom of its own cell, so it belongs one course
			-- above the floor node the way `kits.lodge` writes it.
			if mat then
				buf:put(side + step, room.y + 1, z, mat, 0)
			end
			buf:put(side + step, room.y + 1, z + 1, palette.node("fence"))
			boxes = boxes + 1
		end
	end
	if boxes == 0 then error("wp13 interiors: stable with no box", 0) end
	-- The feed store goes against the FAR wall. Against the near one it
	-- stands in the middle of the cart doorway, which is where the first
	-- version put it.
	M.storage(buf, palette, room, cx - 1, room.z2, "x", 3, 2)
	for _, z in ipairs({room.z1 + 2, room.z2 - 2}) do
		M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, z, lights)
		M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, z, lights)
	end
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
