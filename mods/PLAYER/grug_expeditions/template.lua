-- The Expedition template file (Round 71). tools/expedition_templates/build.py
-- writes it; docs/technical/expedition-template-format.md is the format. The
-- text head is read here; the packed cells stay strings of one byte per node.
--
--   grudgelands-expedition-template 1
--   name test_vault
--   size 48 32 48                     multiples of 16, at most the slot's box
--   node default:stone                the palette, one line per byte value from 0
--   dig default:stone_with_tin        a palette node players may dig in a run
--   place arrival 8 5 8               a named cell, box-relative
--   encounter hall grug_mobs:spider 2 normal 30 5 30    room, mob, count, tier, cell
--   trap f1 2 floor 27 8 20           group, pick, a floor trap's cell (traps.lua)
--   trap w1 1 wall 43 8.5 15.6 +z 8 0 group, pick, a muzzle point, axis, period, offset
--   ambush a1 1 drift 12 5 18 14 22   group, pick, room, the zone x0 y z0 x1 z1 (Round 73)
--   particles dust 4 5 4 9 8 9 24     style, a box x0 y0 z0 x1 y1 z1, its most live particles
--   data 1234                         the bytes of the zlib stream after this line
--   grid 567                          after that stream: the walk grid's (Round 74)
--
-- The stream holds sx * sy * sz palette bytes in VoxelManip order
-- (z * sy * sx + y * sx + x + 1), then as many param2 bytes. The grid's stream
-- holds four planes of sx * sz bytes, column z * sx + x + 1: the walking height,
-- the move mask, the clearance and the flags (walkgrid.lua reads them;
-- tools/expedition_templates/walkgrid.py writes them). `parse` keeps it packed in
-- tpl.grid, nil when the file has none; `load` requires it.
local M = {}
M.EXTENSION = ".exp"
local MAGIC = "grudgelands-expedition-template 1"

-- The particle styles a `particles` line may name (Round 73, particles.lua draws them).
M.PARTICLE_STYLES = {drip = true, dust = true, ash = true, paper = true, ember = true, spark = true}
-- The most live particles a template's `particles` lines may add up to: the web
-- budget, a few hundred per Expedition (concept section 4.8).
M.PARTICLE_BUDGET = 300

-- The four directions a wall trap shoots along.
M.AXES = {["+x"] = {x = 1, y = 0, z = 0}, ["-x"] = {x = -1, y = 0, z = 0},
	["+z"] = {x = 0, y = 0, z = 1}, ["-z"] = {x = 0, y = 0, z = -1}}

-- One trap candidate (Round 72), the text after `trap`, or nil when malformed:
--   <group> <pick> floor <x> <y> <z>        the cell a player stands in over it
--   <group> <pick> wall <x> <y> <z> <axis> <period> <offset>
-- A wall's point is its muzzle in node coordinates (whole numbers are node
-- centres), decimals allowed; axis +x, -x, +z or -z; period and offset in seconds,
-- the first shot `offset` after readiness. A run arms `pick` of its group's lines.
function M.parse_trap(rest)
	local group, pick, kind, tail = rest:match("^(%S+) (%d+) (%S+) (.*)$")
	if not group or tonumber(pick) < 1 then return nil end
	local row = {group = group, pick = tonumber(pick), kind = kind}
	if kind == "floor" then
		local x, y, z = tail:match("^(%d+) (%d+) (%d+)$")
		if not x then return nil end
		row.pos = {x = tonumber(x), y = tonumber(y), z = tonumber(z)}
		return row
	elseif kind == "wall" then
		local num = "(%d+%.?%d*)"
		local x, y, z, axis, period, offset = tail:match("^" .. num .. " " .. num .. " " .. num ..
			" ([%+%-][xz]) " .. num .. " " .. num .. "$")
		if not x or tonumber(period) <= 0 then return nil end
		row.pos = {x = tonumber(x), y = tonumber(y), z = tonumber(z)}
		row.axis, row.period, row.offset = axis, tonumber(period), tonumber(offset)
		return row
	end
	return nil
end

-- One ambush candidate (Round 73), the text after `ambush`, or nil when malformed:
--   <group> <pick> <room> <x0> <y> <z0> <x1> <z1>
-- The zone is every cell from (x0, y, z0) to (x1, y, z1), both corners included, y
-- the feet's row; `room` names its markers. A run arms `pick` of its group's lines.
function M.parse_ambush(rest)
	local group, pick, room, x0, y, z0, x1, z1 =
		rest:match("^(%S+) (%d+) (%S+) (%d+) (%d+) (%d+) (%d+) (%d+)$")
	if not group or tonumber(pick) < 1 then return nil end
	x0, z0, x1, z1 = tonumber(x0), tonumber(z0), tonumber(x1), tonumber(z1)
	return {group = group, pick = tonumber(pick), kind = "ambush", room = room,
		min = {x = math.min(x0, x1), y = tonumber(y), z = math.min(z0, z1)},
		max = {x = math.max(x0, x1), y = tonumber(y), z = math.max(z0, z1)}}
end

-- One particle spawner (Round 73), the text after `particles`, or nil when malformed:
--   <style> <x0> <y0> <z0> <x1> <y1> <z1> <amount>
-- a box, both corners included, and the most live particles it keeps (1 or more).
function M.parse_particles(rest)
	local style, x0, y0, z0, x1, y1, z1, amount =
		rest:match("^(%S+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+)$")
	if not style or not M.PARTICLE_STYLES[style] or tonumber(amount) < 1 then return nil end
	x0, y0, z0, x1, y1, z1 = tonumber(x0), tonumber(y0), tonumber(z0), tonumber(x1),
		tonumber(y1), tonumber(z1)
	return {style = style, amount = tonumber(amount),
		min = {x = math.min(x0, x1), y = math.min(y0, y1), z = math.min(z0, z1)},
		max = {x = math.max(x0, x1), y = math.max(y0, y1), z = math.max(z0, z1)}}
end

-- A group's lines agree on kind, pick, period and offset, and pick at most as many
-- as they are: the first problem, else nil. Trap and ambush lines (kind "ambush")
-- share one name space, so a group of both disagrees with itself.
function M.trap_groups_problem(traps)
	local groups = {}
	for _, row in ipairs(traps) do
		local group = groups[row.group]
		if not group then
			groups[row.group] = {first = row, count = 1}
		else
			local first = group.first
			if first.kind ~= row.kind or first.pick ~= row.pick or first.period ~= row.period or
					first.offset ~= row.offset then
				return "trap group " .. row.group .. " disagrees with itself"
			end
			group.count = group.count + 1
		end
	end
	for name, group in pairs(groups) do
		if group.first.pick > group.count then
			return "trap group " .. name .. " picks more than it has"
		end
	end
end

-- The Round 73 rules between the lines: an ambush's room holds markers, `normal` only,
-- and no other ambush names it; a room with a `critter` marker holds critters only;
-- the particles stay within the budget. The first problem, else nil.
function M.lines_problem(tpl)
	local tiers = {}
	for _, row in ipairs(tpl.encounters) do
		local room = tiers[row.room] or {}
		tiers[row.room] = room
		room[row.tier] = true
	end
	local named = {}
	for _, row in ipairs(tpl.ambushes) do
		local room = tiers[row.room]
		if named[row.room] then return "room " .. row.room .. " has two ambushes" end
		named[row.room] = true
		if not room then return "ambush " .. row.group .. " names no markers" end
		for tier in pairs(room) do
			if tier ~= "normal" then return "ambush room " .. row.room .. " holds a " .. tier end
		end
	end
	for name, room in pairs(tiers) do
		if room.critter and (room.normal or room.elite or room.boss) then
			return "room " .. name .. " mixes critters and a pack"
		end
	end
	local total = 0
	for _, row in ipairs(tpl.particles) do total = total + row.amount end
	if total > M.PARTICLE_BUDGET then
		return "particles " .. total .. " over the budget of " .. M.PARTICLE_BUDGET
	end
end

-- `decompress(bytes)` is core.decompress in the game. `source` names the file in
-- errors: a malformed template stops the server at load, never in a preparation.
function M.parse(text, decompress, source)
	local function fail(reason)
		error("[grug_expeditions] template " .. source .. ": " .. reason, 0)
	end
	local tpl = {nodes = {}, dig = {}, places = {}, encounters = {}, traps = {}, ambushes = {},
		particles = {}}
	local at, number, stream = 1, 0, nil
	while not stream do
		local stop = text:find("\n", at, true)
		if not stop then fail("the data line is missing") end
		local line = text:sub(at, stop - 1)
		at, number = stop + 1, number + 1
		local word, rest = line:match("^(%S+)%s*(.*)$")
		local function bad() fail("line " .. number .. " is malformed: " .. line) end
		if number == 1 then
			if line ~= MAGIC then fail("not a version 1 template") end
		elseif word == "name" then
			tpl.name = rest
		elseif word == "size" then
			local sx, sy, sz = rest:match("^(%d+) (%d+) (%d+)$")
			if not sx then bad() end
			tpl.size = {x = tonumber(sx), y = tonumber(sy), z = tonumber(sz)}
		elseif word == "node" then
			if rest == "" then bad() end
			tpl.nodes[#tpl.nodes + 1] = rest
		elseif word == "dig" then
			if rest == "" then bad() end
			tpl.dig[rest] = true
		elseif word == "place" then
			local place, x, y, z = rest:match("^(%S+) (%d+) (%d+) (%d+)$")
			if not place then bad() end
			tpl.places[place] = {x = tonumber(x), y = tonumber(y), z = tonumber(z)}
		elseif word == "encounter" then
			local room, mob, count, tier, x, y, z =
				rest:match("^(%S+) (%S+) (%d+) (%S+) (%d+) (%d+) (%d+)$")
			if not room then bad() end
			tpl.encounters[#tpl.encounters + 1] = {room = room, mob = mob,
				count = tonumber(count), tier = tier,
				pos = {x = tonumber(x), y = tonumber(y), z = tonumber(z)}}
		elseif word == "trap" then
			local row = M.parse_trap(rest)
			if not row then bad() end
			tpl.traps[#tpl.traps + 1] = row
		elseif word == "ambush" then
			local row = M.parse_ambush(rest)
			if not row then bad() end
			tpl.ambushes[#tpl.ambushes + 1] = row
		elseif word == "particles" then
			local row = M.parse_particles(rest)
			if not row then bad() end
			tpl.particles[#tpl.particles + 1] = row
		elseif word == "data" then
			local bytes = tonumber(rest)
			if not bytes then bad() end
			stream = text:sub(at, at + bytes - 1)
			if #stream ~= bytes then fail("the data is cut short") end
		else
			bad()
		end
	end
	-- The walk grid section after the cells (Round 74), optional here.
	local grid_stream
	local after = at + #stream
	if after <= #text then
		local line_end = text:find("\n", after, true)
		local bytes = line_end and text:sub(after, line_end - 1):match("^grid (%d+)$")
		if not bytes then fail("trailing bytes after the data") end
		grid_stream = text:sub(line_end + 1)
		if #grid_stream ~= tonumber(bytes) then fail("the grid is cut short or followed by more") end
	end
	if not tpl.size then fail("no size") end
	if #tpl.nodes == 0 then fail("no palette") end
	local groups = {}
	for _, row in ipairs(tpl.traps) do groups[#groups + 1] = row end
	for _, row in ipairs(tpl.ambushes) do groups[#groups + 1] = row end
	local problem = M.trap_groups_problem(groups) or M.lines_problem(tpl)
	if problem then fail(problem) end
	local palette = {}
	for _, name in ipairs(tpl.nodes) do palette[name] = true end
	for name in pairs(tpl.dig) do
		if not palette[name] then fail("dig names " .. name .. ", not in the palette") end
	end
	local size = tpl.size
	local total = size.x * size.y * size.z
	local cells = decompress(stream)
	if #cells ~= 2 * total then fail("the data does not fit the size") end
	tpl.cells = cells
	if grid_stream then
		local grid = decompress(grid_stream)
		if #grid ~= 4 * size.x * size.z then fail("the grid does not fit the size") end
		tpl.grid = grid
	end
	-- A floor trap's mark goes into its cell: air only (template.py refuses the rest).
	for _, row in ipairs(tpl.traps) do
		local pos = row.pos
		if row.kind == "floor" and pos.x < size.x and pos.y < size.y and pos.z < size.z and
				tpl.nodes[cells:byte(pos.z * size.y * size.x + pos.y * size.x + pos.x + 1) + 1] ~= "air" then
			fail("floor trap " .. row.group .. " is not in air")
		end
	end
	return tpl
end

-- A template fits a slot: mapblock multiples for the writer, inside the box, its
-- named cells inside itself and the `required` places present.
function M.check_fits(tpl, box, required, source)
	local function fail(reason)
		error("[grug_expeditions] template " .. source .. ": " .. reason, 0)
	end
	local size = tpl.size
	for _, axis in ipairs({"x", "y", "z"}) do
		if size[axis] % 16 ~= 0 or size[axis] > box[axis] or size[axis] == 0 then
			fail("size " .. axis .. " must be a multiple of 16 within the box")
		end
	end
	local function inside(pos)
		return pos.x < size.x and pos.y < size.y and pos.z < size.z
	end
	for name, pos in pairs(tpl.places) do
		if not inside(pos) then fail("place " .. name .. " lies outside") end
	end
	for _, row in ipairs(tpl.encounters) do
		if not inside(row.pos) then fail("encounter " .. row.room .. " lies outside") end
	end
	for _, row in ipairs(tpl.traps or {}) do
		local cell = {x = math.floor(row.pos.x + 0.5), y = math.floor(row.pos.y + 0.5),
			z = math.floor(row.pos.z + 0.5)}
		if not inside(cell) then fail("trap group " .. row.group .. " lies outside") end
	end
	for _, row in ipairs(tpl.ambushes or {}) do
		if not (inside(row.min) and inside(row.max)) then fail("ambush " .. row.group .. " lies outside") end
	end
	for _, row in ipairs(tpl.particles or {}) do
		if not (inside(row.min) and inside(row.max)) then fail("particles " .. row.style .. " lie outside") end
	end
	for _, name in ipairs(required) do
		if not tpl.places[name] then fail("place " .. name .. " is missing") end
	end
end

function M.load(path, name, box, required)
	local file = io.open(path, "rb")
	if not file then error("[grug_expeditions] template file missing: " .. path, 0) end
	local text = file:read("*a")
	file:close()
	local tpl = M.parse(text, function(bytes) return core.decompress(bytes, "deflate") end, name)
	if tpl.name ~= name then
		error("[grug_expeditions] template " .. name .. ": the file names " .. tostring(tpl.name), 0)
	end
	M.check_fits(tpl, box, required, name)
	if not tpl.grid then error("[grug_expeditions] template " .. name .. ": no walk grid (build.py writes it)", 0) end
	return tpl
end

-- Content ids exist once every mod has registered its nodes; an unknown node
-- stops the server there. `swaps` ({[key] = {[node] = node}}, catalogue.swaps)
-- gives the variants a run writes: tpl.variants[key] = {ids, dig}, the palette and
-- the marks with those nodes swapped. tpl.ids and tpl.dig stay the file's, but for
-- `static` ({[node] = node}, catalogue.STATIC, Round 78): every palette and variant
-- writes those nodes' static copies; a static node is never a mark.
function M.resolve(tpl, swaps, static)
	static = static or {}
	for name in pairs(tpl.dig) do
		if static[name] then
			error("[grug_expeditions] template " .. tpl.name .. ": dig names the static " .. name, 0)
		end
	end
	local function id_of(name)
		name = static[name] or name
		if not core.registered_nodes[name] then
			error("[grug_expeditions] template " .. tpl.name .. ": unknown node " .. name, 0)
		end
		return core.get_content_id(name)
	end
	local ids = {}
	for index, name in ipairs(tpl.nodes) do ids[index - 1] = id_of(name) end
	tpl.ids = ids
	tpl.variants = {}
	for key, swap in pairs(swaps or {}) do
		local variant = {ids = {}, dig = {}}
		for index, name in ipairs(tpl.nodes) do
			variant.ids[index - 1] = swap[name] and id_of(swap[name]) or ids[index - 1]
		end
		for name in pairs(tpl.dig) do variant.dig[swap[name] or name] = true end
		tpl.variants[key] = variant
	end
end

return M
