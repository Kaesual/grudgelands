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

-- ---------------------------------------------------------------------------
-- the orientation-bearing families
-- ---------------------------------------------------------------------------
--
-- Only a node whose param2 actually carries an orientation may be rotated.
-- Several vendored full cubes declare `paramtype2 = "facedir"` merely so a
-- player can align a texture, and then pin `place_param2 = 0` so the engine
-- itself never writes anything else: `default:pine_wood` and
-- `default:stonebrick` are exactly that. Turning their param2 with the part
-- writes a value the engine would never produce, which is how 440 plank and
-- 144 stone-brick cells ended up carrying a rotation that means nothing.
--
-- So the rule is the other way round from the mod's own paramtype2: a node
-- is orientation-bearing only if it is listed here, and everything else must
-- be written at param2 0 and stays there through every rotation. The
-- families are the shaped ones -- stairs and slabs (including the
-- upside-down family), doors, beds, panes -- plus wallmounted fittings and
-- the handful of facedir furniture pieces whose front tile is their point.
local PARAM2_KIND = {
	-- wallmounted fittings: param2 points from the node to its support
	["default:torch"] = M.WALLMOUNTED,
	["default:torch_wall"] = M.WALLMOUNTED,
	["default:torch_ceiling"] = M.WALLMOUNTED,
	["default:ladder_wood"] = M.WALLMOUNTED,
	["default:sign_wall_wood"] = M.WALLMOUNTED,
	-- panes: a flat pane records the axis it spans. The connected
	-- `xpanes:pane` has no paramtype2 at all and is always written at 0.
	["xpanes:pane_flat"] = M.FACEDIR,
	["xpanes:bar_flat"] = M.FACEDIR,
	["xpanes:obsidian_pane_flat"] = M.FACEDIR,
	-- static decor furniture whose front tile faces the room
	["grug_decor:xdecor_barrel"] = M.FACEDIR,
	["grug_decor:xdecor_empty_shelf"] = M.FACEDIR,
	["grug_decor:xdecor_cauldron"] = M.FACEDIR,
	["grug_decor:cottages_shelf"] = M.FACEDIR,
}

-- Whole families whose every member is shaped.
local PREFIX_KIND = {
	["stairs:"] = M.FACEDIR,
	["doors:"] = M.FACEDIR,
	["beds:"] = M.FACEDIR,
}

function M.param2_kind(name)
	local kind = PARAM2_KIND[name]
	if kind then return kind end
	for prefix, value in pairs(PREFIX_KIND) do
		if name:sub(1, #prefix) == prefix then return value end
	end
	return M.NONE
end

-- ---------------------------------------------------------------------------
-- two node properties the construction-time code needs and cannot ask for
-- ---------------------------------------------------------------------------
--
-- A blueprint is built with no engine, so `core.registered_nodes` is out of
-- reach; both tables below are therefore authored, and
-- `tools/wp13/library_kat.lua` proves them equal to the real registry (loaded
-- under a stub `core` by `tools/wp13/stub_registry.lua`) for every node name
-- the blueprint actually emits, in both directions. A stale or invented entry
-- fails the KAT.

-- Nodes an `xpanes` pane connects to: `group:pane`, `group:stone`,
-- `group:glass`, `group:wood` or `group:tree` (mods/BASE/xpanes/init.lua,
-- the `connects_to` of the connected pane node).
local PANE_CONNECTS = {
	["default:cobble"] = true,
	["default:pine_tree"] = true,
	["default:pine_wood"] = true,
	["default:stone_block"] = true,
	["default:stonebrick"] = true,
	["walls:cobble"] = true,
	["xpanes:pane"] = true,
	["xpanes:pane_flat"] = true,
}

function M.pane_connects(name)
	return PANE_CONNECTS[name] == true
end

-- Opaque full cubes: the only nodes a wallmounted torch may hang on, and the
-- only nodes that read as a wall. A nodebox, a mesh, a plant or a pane is
-- not one of them, and neither is a full cube that light passes through.
local FULL_SOLID = {
	["default:cobble"] = true,
	["default:dirt"] = true,
	["default:dirt_with_coniferous_litter"] = true,
	["default:dirt_with_grass"] = true,
	["default:gravel"] = true,
	["default:pine_tree"] = true,
	["default:pine_wood"] = true,
	["default:stone_block"] = true,
	["default:stonebrick"] = true,
	["grug_decor:xdecor_barrel"] = true,
	["grug_decor:xdecor_cauldron"] = true,
	["grug_decor:xdecor_empty_shelf"] = true,
	["grug_materials:iron_block"] = true,
	["wool:brown"] = true,
	["wool:red"] = true,
}

function M.full_solid(name)
	return FULL_SOLID[name] == true
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
	local suffix = "_a"
	local top = face % 4
	if right_hinge then
		suffix = "_b"
		top = (face + 3) % 4
	end
	buf:put(x, y, z, palette.variant("door", suffix), face % 4)
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

-- A pane in a wall running along `axis`. This is the provisional value: a
-- window in a straight wall is a flat pane spanning that axis, which is what
-- update_pane settles on for two opposite connections. `resolve_panes` below
-- then runs the real rule over the finished blueprint, because a pane's
-- shape depends on neighbours the part that wrote it cannot see.
function M.pane(buf, palette, x, y, z, axis)
	if axis ~= "x" and axis ~= "z" then
		error("wp13 parts: pane axis differs", 0)
	end
	buf:put(x, y, z, palette.node("window"), axis == "x" and 0 or 3)
end

-- The connected name behind a pane node, or nil if this is not a pane.
local function pane_base(name)
	if name:sub(1, 7) ~= "xpanes:" then return nil end
	if name:sub(-5) == "_flat" then return name:sub(1, -6) end
	return name
end

-- `xpanes` decides a pane's node and param2 from its four horizontal
-- neighbours, in `update_pane` (mods/BASE/xpanes/init.lua). The engine runs
-- that from `register_on_placenode`, which a VoxelManip write never fires, so
-- a blueprint has to write the settled shape itself or leave the wrong node
-- in the world forever. This is that decision, transcribed:
--
--   `any` starts at the pane's own param2 and becomes the LAST connecting
--   direction, scanning dir 0..3 (facedir_to_dir: +Z, +X, -Z, -X);
--   count 0                  -> flat, param2 unchanged;
--   count 1                  -> flat, param2 (any + 1) % 4;
--   count 2 opposite         -> flat, param2 (any + 1) % 4;
--   count 2 adjacent, 3 or 4 -> the connected node, param2 0.
--
-- A straight wall along X therefore settles on flat/0 and one along Z on
-- flat/3, which is what `M.pane` already guesses; the branch that matters is
-- a third neighbour, such as the stone chimney breast standing behind a
-- window, which turns the window into the connected node at param2 0.
--
-- Run this once over the whole pad, after every cell is written: rewriting a
-- pane never changes whether a neighbour connects, because both pane shapes
-- are in `group:pane`, so one pass is exact and order-independent.
function M.resolve_panes(buf)
	local order, count = buf:cells()
	local panes = {}
	for index = 1, count do
		local cell = order[index]
		local base = pane_base(cell.name)
		if base then
			panes[#panes + 1] = {cell = cell, base = base}
		end
	end
	for index = 1, #panes do
		local cell, base = panes[index].cell, panes[index].base
		local any, total = cell.param2, 0
		local connected = {}
		for dir = 0, 3 do
			local dx, dz = M.facedir_step(dir)
			local neighbour = buf:at(cell.x + dx, cell.y, cell.z + dz)
			local hit = neighbour ~= nil and M.pane_connects(neighbour.name)
			connected[dir] = hit
			if hit then
				any = dir
				total = total + 1
			end
		end
		if total == 0 then
			buf:put(cell.x, cell.y, cell.z, base .. "_flat", cell.param2)
		elseif total == 1 or (total == 2 and
				((connected[0] and connected[2]) or
					(connected[1] and connected[3]))) then
			buf:put(cell.x, cell.y, cell.z, base .. "_flat", (any + 1) % 4)
		else
			buf:put(cell.x, cell.y, cell.z, base, 0)
		end
	end
	return #panes
end

-- Is the cell at these coordinates an opaque full cube?
function M.solid_at(buf, x, y, z)
	local cell = buf:at(x, y, z)
	return cell ~= nil and M.full_solid(cell.name)
end

-- A torch on a wall. `dx/dy/dz` is the unit step from the torch to the node
-- carrying it, which must be an opaque full cube: a wallmounted torch on a
-- pane, a door leaf or a slab hangs in the air with a window behind it,
-- which is exactly what fifteen of them did. Callers pick the cell; this
-- refuses to write a torch onto anything that is not a wall.
function M.wall_torch(buf, palette, x, y, z, dx, dy, dz)
	if not M.solid_at(buf, x + dx, y + dy, z + dz) then
		local cell = buf:at(x + dx, y + dy, z + dz)
		error("wp13 parts: wall torch at " .. x .. "," .. y .. "," .. z ..
			" has no solid support (" .. (cell and cell.name or "air") .. ")", 0)
	end
	buf:put(x, y, z, palette.node("light_wall"),
		M.wallmounted_support(dx, dy, dz))
end

function M.floor_torch(buf, palette, x, y, z)
	if not M.solid_at(buf, x, y - 1, z) then
		local cell = buf:at(x, y - 1, z)
		error("wp13 parts: floor torch at " .. x .. "," .. y .. "," .. z ..
			" stands on " .. (cell and cell.name or "air"), 0)
	end
	buf:put(x, y, z, palette.node("light_post"), M.wallmounted_support(0, -1, 0))
end

-- A bed exactly as beds' on_place writes it: the foot node carries the
-- facedir, the head node sits one step along facedir_to_dir and repeats it.
function M.bed(buf, palette, x, y, z, face, fancy)
	local role = fancy and "bed_fancy" or "bed"
	local foot = palette.variant(role, "_bottom")
	if foot == nil then
		-- An optional fancy bed the race does not carry falls back to the
		-- plain one, which every race must bind.
		role = "bed"
		foot = palette.variant(role, "_bottom")
	end
	local dx, dz = M.facedir_step(face)
	buf:put(x, y, z, foot, face % 4)
	buf:put(x + dx, y, z + dz, palette.variant(role, "_top"), face % 4)
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
