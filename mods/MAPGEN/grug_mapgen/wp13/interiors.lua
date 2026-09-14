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
function M.wall_light(buf, parts, palette, room, x, y, z, lights)
	local dx, dy, dz = torch_side(room, x, z)
	if not dx then error("wp13 interiors: light is not against a wall", 0) end
	local support = buf:at(x + dx, y + dy, z + dz)
	if support == nil or support.name == "air" then
		error("wp13 interiors: indoor light has no support", 0)
	end
	parts.wall_torch(buf, palette, x, y, z, dx, dy, dz)
	lights[#lights + 1] = {x = x, y = y, z = z}
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

-- Chests standing against a wall, looking into the room.
function M.storage(buf, palette, room, x, z, axis, len, face)
	for step = 0, len - 1 do
		local cx = axis == "x" and x + step or x
		local cz = axis == "z" and z + step or z
		buf:put(cx, room.y + 1, cz, palette.node("storage"), front(face))
	end
end

-- A furnace with a stone breast above it; the caller runs the chimney on up
-- through the roof.
function M.hearth(buf, palette, room, x, z, face, top)
	buf:put(x, room.y + 1, z, palette.node("hearth"), front(face))
	for y = room.y + 2, top do
		buf:put(x, y, z, palette.node("chimney"))
	end
end

-- ---------------------------------------------------------------------------
-- kits
-- ---------------------------------------------------------------------------

M.kits = {}

-- A lived-in home: bed corner, rug, table and seats, shelf wall, chest,
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
		M.hearth(buf, palette, room, spec.hearth_x or room.x2,
			spec.hearth_z or room.z1, spec.hearth_face or 3, room.h)
	end
	M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, cz, lights)
	M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, cz, lights)
	return lights
end

-- The forge floor: furnaces on the back wall, a steel workbench, anvil block,
-- benches, storage and four torches.
function M.kits.workshop(buf, parts, palette, room, spec)
	local lights = {}
	local cx = math.floor((room.x1 + room.x2) / 2)
	local cz = math.floor((room.z1 + room.z2) / 2)
	for offset = -2, 2, 2 do
		M.hearth(buf, palette, room, cx + offset, room.z1, 0, room.h)
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
	M.hearth(buf, palette, room, room.x2, cz, 3, room.h)
	buf:put(cx, room.y + 1, cz, palette.node("workbench"))
	buf:put(cx, room.y + 2, cz, palette.node("chimney_cap"))
	M.storage(buf, palette, room, room.x1 + 1, room.z1, "x", 2, 0)
	M.shelves(buf, palette, room, room.x1 + 1, room.z2, "x", 2, 2)
	M.rug(buf, palette, room, cx - 1, cz + 1, cx + 1, cz + 1, true)
	M.wall_light(buf, parts, palette, room, room.x2, room.y + 3, room.z1, lights)
	M.wall_light(buf, parts, palette, room, cx, room.y + 3, room.z2, lights)
	return lights
end

-- The storage building: chest rows, stacked timber and a work table.
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

-- The community hall: two long tables with benches, a hearth, book wall and
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
	M.hearth(buf, palette, room, spec.hearth_x or cx,
		spec.hearth_z or room.z1, spec.hearth_face or 0, room.h)
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

-- The gate watchpost guard room: one bed, a chest, a table and a torch.
function M.kits.watch(buf, parts, palette, room, spec)
	local lights = {}
	local cz = math.floor((room.z1 + room.z2) / 2)
	M.bed(buf, parts, palette, room, room.x1, room.z1, 0, false)
	M.storage(buf, palette, room, room.x2, room.z1, "z", 1, 3)
	M.table_set(buf, parts, palette, room, room.x2 - 1, room.z2 - 1, "x", 2)
	M.wall_light(buf, parts, palette, room, room.x1, room.y + 3, cz, lights)
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
