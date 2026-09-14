-- WP13 cell writer, rotation and the primitive building parts.
--
-- WP13 blueprints are written straight into the map through VoxelManip, so a
-- part must emit exactly the node names and param2 values the engine's own
-- `on_place` would leave behind. The rotation semantics below were read off
-- the vendored mods (mods/BASE/doors/init.lua, mods/BASE/beds/api.lua,
-- mods/BASE/xpanes/init.lua, mods/BASE/walls/init.lua, mods/BASE/stairs)
-- and off the engine's facedir tables:
--
--   facedir 0/1/2/3 point at +Z / +X / -Z / -X (core.facedir_to_dir).
--   wallmounted 0..5 point from the node TO its support:
--   +Y, -Y, +X, -X, +Z, -Z.
--   A stair's raised half lies toward facedir_to_dir(param2).
--   An outer stair's single raised quarter lies at
--   (-x,+z) / (+x,+z) / (+x,-z) / (-x,-z) for param2 0..3.
--   An inner stair is raised everywhere except one quarter, which lies at
--   (+x,-z) / (-x,-z) / (-x,+z) / (+x,+z) for param2 0..3.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local M = {}

M.FACEDIR = "facedir"
M.WALLMOUNTED = "wallmounted"
M.NONE = "none"

-- Nodes whose paramtype2 cannot be guessed from the mod prefix.
local PARAM2_KIND = {
	["default:torch"] = M.WALLMOUNTED,
	["default:torch_wall"] = M.WALLMOUNTED,
	["default:torch_ceiling"] = M.WALLMOUNTED,
	["default:ladder_wood"] = M.WALLMOUNTED,
	["default:ladder_steel"] = M.WALLMOUNTED,
	["default:sign_wall_wood"] = M.WALLMOUNTED,
	["default:chest"] = M.FACEDIR,
	["default:chest_locked"] = M.FACEDIR,
	["default:bookshelf"] = M.FACEDIR,
	["default:furnace"] = M.FACEDIR,
	["default:pine_wood"] = M.FACEDIR,
	["default:pine_tree"] = M.FACEDIR,
	["default:stonebrick"] = M.FACEDIR,
	["default:brick"] = M.FACEDIR,
	["vessels:shelf"] = M.FACEDIR,
}

local PREFIX_KIND = {
	["stairs:"] = M.FACEDIR,
	["doors:"] = M.FACEDIR,
	["beds:"] = M.FACEDIR,
	["xpanes:"] = M.FACEDIR,
}

function M.param2_kind(name)
	local kind = PARAM2_KIND[name]
	if kind then return kind end
	for prefix, value in pairs(PREFIX_KIND) do
		if name:sub(1, #prefix) == prefix then return value end
	end
	return M.NONE
end

-- facedir index to unit step in the x/z plane.
local FACEDIR_STEP = {[0] = {0, 1}, [1] = {1, 0}, [2] = {0, -1}, [3] = {-1, 0}}

function M.facedir_step(dir)
	local step = FACEDIR_STEP[dir % 4]
	return step[1], step[2]
end

-- The facedir that points along the given unit step.
-- Lua 5.1 keeps a signed zero, and "-0" is not "0" once concatenated into a
-- lookup key, so every incoming step is normalised first.
local function unsign(value)
	if value == 0 then return 0 end
	return value
end

function M.step_facedir(dx, dz)
	dx, dz = unsign(dx), unsign(dz)
	if dx == 0 and dz == 1 then return 0 end
	if dx == 1 and dz == 0 then return 1 end
	if dx == 0 and dz == -1 then return 2 end
	if dx == -1 and dz == 0 then return 3 end
	error("wp13 parts: step is not axis aligned", 0)
end

-- wallmounted value whose support lies in the given step direction.
local WALLMOUNTED_SUPPORT = {
	["0,1,0"] = 0, ["0,-1,0"] = 1, ["1,0,0"] = 2,
	["-1,0,0"] = 3, ["0,0,1"] = 4, ["0,0,-1"] = 5,
}

function M.wallmounted_support(dx, dy, dz)
	local value = WALLMOUNTED_SUPPORT[
		unsign(dx) .. "," .. unsign(dy) .. "," .. unsign(dz)]
	if value == nil then error("wp13 parts: support is not axis aligned", 0) end
	return value
end

-- One quarter turn about +Y maps local +Z to world +X and local +X to
-- world -Z; that is the same convention the renderer's `--view` uses.
function M.rotate_param2(param2, kind, turns)
	turns = turns % 4
	if turns == 0 then return param2 end
	if kind == M.NONE then
		if param2 ~= 0 then
			error("wp13 parts: rotating an unoriented node with param2", 0)
		end
		return 0
	end
	if kind == M.WALLMOUNTED then
		local step = {[2] = 5, [5] = 3, [3] = 4, [4] = 2}
		local value = param2
		for _ = 1, turns do value = step[value] or value end
		return value
	end
	-- facedir: only the upright (axis 0) and the upside-down (axis 20)
	-- families occur in settlements. Upside-down nodes turn the other way,
	-- because flipping about a horizontal axis reverses the sense of Y.
	local axis = param2 - (param2 % 4)
	local rot = param2 % 4
	if axis == 0 then return (rot + turns) % 4 end
	if axis == 20 then return 20 + ((rot - turns) % 4) end
	error("wp13 parts: unsupported facedir axis " .. tostring(axis), 0)
end

-- An `xpanes` flat pane only records the axis it spans: its nodebox and its
-- tiles are symmetric under a half turn, and `update_pane` always settles on
-- param2 0 for a wall running along X and 3 for one running along Z. Rotating
-- a part must therefore land back on those two values, not on their half
-- turns, so that the blueprint keeps writing what the engine would write.
function M.canonical_param2(name, param2)
	if name:sub(1, 7) == "xpanes:" and name:sub(-5) == "_flat" then
		if param2 == 1 then return 3 end
		if param2 == 2 then return 0 end
	end
	return param2
end

-- Rotate a point inside a w by d footprint so that the rotated footprint
-- still starts at local (0, 0). Overhangs keep their negative coordinates.
function M.rotate_footprint(x, z, w, d, turns)
	turns = turns % 4
	if turns == 0 then return x, z end
	if turns == 1 then return z, w - 1 - x end
	if turns == 2 then return w - 1 - x, d - 1 - z end
	return d - 1 - z, x
end

-- ---------------------------------------------------------------------------
-- the cell buffer
-- ---------------------------------------------------------------------------

local Buffer = {}
Buffer.__index = Buffer

function M.buffer()
	return setmetatable({count = 0, order = {}, cell = {}}, Buffer)
end

function Buffer:put(x, y, z, name, param2)
	param2 = param2 or 0
	if type(name) ~= "string" or name == "" then
		error("wp13 parts: cell name differs", 0)
	end
	if param2 % 1 ~= 0 or param2 < 0 or param2 > 255 then
		error("wp13 parts: cell param2 differs", 0)
	end
	if param2 ~= 0 and M.param2_kind(name) == M.NONE then
		error("wp13 parts: " .. name .. " has no paramtype2", 0)
	end
	local key = x .. ":" .. y .. ":" .. z
	local cell = self.cell[key]
	if cell then
		cell.name, cell.param2 = name, param2
		return
	end
	cell = {x = x, y = y, z = z, name = name, param2 = param2}
	self.cell[key] = cell
	self.count = self.count + 1
	self.order[self.count] = cell
end

function Buffer:at(x, y, z)
	return self.cell[x .. ":" .. y .. ":" .. z]
end

function Buffer:fill(x1, y1, z1, x2, y2, z2, name, param2)
	for z = z1, z2 do
		for y = y1, y2 do
			for x = x1, x2 do
				self:put(x, y, z, name, param2)
			end
		end
	end
end

M.AIR = "air"

function Buffer:clear(x1, y1, z1, x2, y2, z2)
	self:fill(x1, y1, z1, x2, y2, z2, M.AIR, 0)
end

-- A solid box; `box` and `fill` differ only in reading order at the call site.
function Buffer:box(x1, y1, z1, x2, y2, z2, name, param2)
	self:fill(x1, y1, z1, x2, y2, z2, name, param2)
end

-- Shell only: the six faces of the box, nothing inside.
function Buffer:hollow_box(x1, y1, z1, x2, y2, z2, name, param2)
	for z = z1, z2 do
		for y = y1, y2 do
			for x = x1, x2 do
				if x == x1 or x == x2 or y == y1 or y == y2 or
						z == z1 or z == z2 then
					self:put(x, y, z, name, param2)
				end
			end
		end
	end
end

-- The four vertical faces of a box, used for every building wall.
function Buffer:ring(x1, z1, x2, z2, y1, y2, name, param2)
	for y = y1, y2 do
		for x = x1, x2 do
			self:put(x, y, z1, name, param2)
			self:put(x, y, z2, name, param2)
		end
		for z = z1 + 1, z2 - 1 do
			self:put(x1, y, z, name, param2)
			self:put(x2, y, z, name, param2)
		end
	end
end

function Buffer:cells()
	return self.order, self.count
end

-- ---------------------------------------------------------------------------
-- placing a whole part
-- ---------------------------------------------------------------------------

-- A part is {buffer, w, d, points}. `points` is a map of named point lists;
-- each point carries x/y/z and may carry `face` (a facedir) which rotates
-- with the part. Returns the rotated and translated point map.
function M.stamp(target, part, ox, oy, oz, turns)
	turns = turns % 4
	local source, count = part.buffer:cells()
	for index = 1, count do
		local cell = source[index]
		local rx, rz = M.rotate_footprint(cell.x, cell.z, part.w, part.d, turns)
		local param2 = M.canonical_param2(cell.name,
			M.rotate_param2(cell.param2, M.param2_kind(cell.name), turns))
		target:put(ox + rx, oy + cell.y, oz + rz, cell.name, param2)
	end
	local moved = {}
	for group, list in pairs(part.points or {}) do
		local out = {}
		for index = 1, #list do
			local point = list[index]
			local rx, rz = M.rotate_footprint(point.x, point.z, part.w, part.d, turns)
			local copy = {x = ox + rx, y = oy + point.y, z = oz + rz}
			for key, value in pairs(point) do
				if key ~= "x" and key ~= "y" and key ~= "z" and key ~= "face" then
					copy[key] = value
				end
			end
			if point.face then copy.face = (point.face + turns) % 4 end
			out[index] = copy
		end
		moved[group] = out
	end
	if part.w and part.d then
		if turns % 2 == 1 then
			moved.footprint = {{x = ox, y = oy, z = oz, w = part.d, d = part.w}}
		else
			moved.footprint = {{x = ox, y = oy, z = oz, w = part.w, d = part.d}}
		end
	end
	return moved
end

-- ---------------------------------------------------------------------------
-- primitive parts
-- ---------------------------------------------------------------------------

-- A wooden door exactly as `doors.register`'s on_place writes it: the leaf at
-- the foot with facedir `face` pointing the way the placer looked (that is,
-- inward), and the invisible `doors:hidden` collision node above it. A right
-- hinged twin uses the `_b` mesh and turns its hidden node by three quarters;
-- `doors.door_toggle` repairs the missing `state` meta for lvm placed doors.
function M.door(buf, palette, x, y, z, face, right_hinge)
	local base = palette.node("door")
	local suffix = "_a"
	local top = face % 4
	if right_hinge then
		suffix = "_b"
		top = (face + 3) % 4
	end
	buf:put(x, y, z, base .. suffix, face % 4)
	buf:put(x, y + 1, z, palette.node("door_hidden"), top)
end

-- Two leaves of one doorway. The right hinged leaf sits where the engine
-- looks for a neighbouring door: pos minus ref[dir + 1] of doors' on_place.
local DOUBLE_REF = {[0] = {-1, 0}, [1] = {0, 1}, [2] = {1, 0}, [3] = {0, -1}}

function M.double_door(buf, palette, x, y, z, face)
	local ref = DOUBLE_REF[face % 4]
	M.door(buf, palette, x, y, z, face, false)
	M.door(buf, palette, x - ref[1], y, z - ref[2], face, true)
	return x - ref[1], z - ref[2]
end

-- A pane between two solid neighbours. `xpanes:pane_flat` is a fixed nodebox,
-- so it renders correctly with no update callback; the connected
-- `xpanes:pane` variant is what update_pane swaps in only for three and four
-- way junctions. update_pane's two-opposite-connection branch is what a
-- window in a straight wall becomes, and it yields the flat node with
-- param2 0 for a wall running along X and param2 3 for one running along Z.
function M.pane(buf, palette, x, y, z, axis)
	if axis ~= "x" and axis ~= "z" then
		error("wp13 parts: pane axis differs", 0)
	end
	buf:put(x, y, z, palette.node("window"), axis == "x" and 0 or 3)
end

-- A torch on a wall. `support` is the unit step from the torch to the node
-- carrying it.
function M.wall_torch(buf, palette, x, y, z, dx, dy, dz)
	buf:put(x, y, z, palette.node("light_wall"),
		M.wallmounted_support(dx, dy, dz))
end

function M.floor_torch(buf, palette, x, y, z)
	buf:put(x, y, z, palette.node("light_post"), M.wallmounted_support(0, -1, 0))
end

-- A bed exactly as beds' on_place writes it: the foot node carries the
-- facedir, the head node sits one step along facedir_to_dir and repeats it.
function M.bed(buf, palette, x, y, z, face, fancy)
	local base = palette.maybe(fancy and "bed_fancy" or "bed") or
		palette.node("bed")
	local dx, dz = M.facedir_step(face)
	buf:put(x, y, z, base .. "_bottom", face % 4)
	buf:put(x + dx, y, z + dz, base .. "_top", face % 4)
end

-- A stair whose raised half points at `face`.
function M.stair(buf, x, y, z, name, face)
	buf:put(x, y, z, name, face % 4)
end

-- A seat looking at `face`: the backrest is on the opposite side.
function M.seat(buf, palette, x, y, z, face)
	buf:put(x, y, z, palette.node("seat"), (face + 2) % 4)
end

-- A trestle table cell: leg below, top slab above.
function M.table_cell(buf, palette, x, y, z)
	buf:put(x, y, z, palette.node("table_leg"))
	buf:put(x, y + 1, z, palette.node("table_top"))
end

return M
