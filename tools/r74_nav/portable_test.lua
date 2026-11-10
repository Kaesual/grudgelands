-- Round 74 lane NAV portable test (LuaJIT; round74-plan.md section 4 NAV, verification 2):
-- the walk grid of every shipped Expedition template, written by
-- tools/expedition_templates/build.py and read by grug_expeditions/template.lua and
-- walkgrid.lua, and its two users in grug_expeditions/navigation.lua: grug_nav's
-- Expedition backend (the real mobs/grug_nav.lua) and the evade guide. One run, many
-- cases; prints the numbers the lane reports and "R74 NAV PORTABLE PASS checks=<n>".
--
--   luajit tools/r74_nav/portable_test.lua [REPO]
--
-- A. The independent derivation: per template, the grid read from the written file
--    against tools/expedition_templates/proofs.lua's height map of the same file (the
--    door open, the ore solid), cell by cell: heights, every move, the door cells, the
--    clearance and the 2 x 2 blocks, each re-derived here from the proof's map. And the
--    walk model against grug_nav's node model on a fake world holding the template:
--    every walking cell is standable there, every move a walkable line.
-- B. A* against a breadth-first search (a bucket queue written here, costs 5 and 7):
--    thousands of random pairs per template and three body classes; the path's cost is
--    the search's distance, every step a legal move on a cell the body may stand on, no
--    path where the search finds none. The grid's line never says yes where grug_nav's
--    node line says no.
-- C. Every field, exhaustively: per home of every marker (the spread of encounters.lua)
--    and its mob's class, every walking cell's move lies on a shortest way home, a cell
--    with no way has none; the full walk home from every cell for one home per template;
--    the evade guide walked from every cell for one home per template.
-- D. The offset: two slots of one template answer the same, translated; one grid shared.
-- E. Off the grid (in the air, in a wall corner, in lava), the door shut and open, the
--    clearance of a wide body.
-- F. The chase over grug_nav: a blocked line searches at once, the path leads round the
--    wall to striking range, a free line searches nothing; a mob outside an Expedition
--    keeps the engine's search. The guide's registration through the evade seam.
-- G. The reader: the grid section, a cut or trailing one refused; `load` requires it.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local floor, abs, sqrt, max, min = math.floor, math.abs, math.sqrt, math.max, math.min
math.randomseed(74)
local started = os.clock()

local T = dofile(repo .. "/mods/PLAYER/grug_expeditions/template.lua")
local PR = dofile(repo .. "/tools/expedition_templates/proofs.lua")
local W = dofile(repo .. "/mods/PLAYER/grug_expeditions/walkgrid.lua")
local REG = PR.registry(repo)
local _, ffi = pcall(require, "ffi")
ffi.cdef[[int uncompress(uint8_t *dest, unsigned long *destLen, const uint8_t *src, unsigned long srcLen);]]
local zlib = ffi.load("z")
local function inflate(bytes)
	local out, size = ffi.new("uint8_t[?]", 4194304), ffi.new("unsigned long[1]", 4194304)
	assert(zlib.uncompress(out, size, bytes, #bytes) == 0)
	return ffi.string(out, size[0])
end
-- The end of a file's cell stream: its `data` line's count after the line.
local function data_end(text)
	local _, stop, bytes = text:find("\ndata (%d+)\n")
	return stop + tonumber(bytes)
end
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local NAMES = {"test_vault", "stilled_seam", "second_shift", "last_mint"}
local DOOR = "grug_expeditions:reward_door"
local NONE = W.NONE
-- The live collision box's larger side at the marker's tier: elite and boss markers grow
-- by the elite scale 1.4 (levels.lua; a boss spawns as an elite, packs.lua spawn). From
-- the definitions' collisionbox (grug_mobs/*.lua).
local WIDTH = {
	["grug_mobs:giant_spider"] = 2.1, ["grug_mobs:stone_golem"] = 0.6, ["grug_mobs:flintback"] = 0.6,
	["grug_mobs:lava_flan"] = 1.0, ["grug_mobs:ember_wisp"] = 0.4, ["grug_mobs:land_guard"] = 1.0,
	["grug_mobs:duewarden"] = 1.0, ["grug_mobs:zombie"] = 0.6, ["grug_mobs:skeleton_raider"] = 0.6,
	["grug_mobs:auditor_nemm"] = 0.6, ["grug_mobs:cave_bat"] = 0.5, ["grug_mobs:cave_crawler"] = 0.8,
	["grug_mobs:bone_weevil"] = 0.8,
}
local function width_of(row)
	return WIDTH[row.mob] * ((row.tier == "elite" or row.tier == "boss") and 1.4 or 1)
end
local SPREAD = {{0, 0}, {3, 0}, {-3, 0}, {0, 3}, {0, -3}, {3, 3}, {-3, 3}, {3, -3}, {-3, -3}} -- encounters.lua

-- ---- The templates --------------------------------------------------------------------
local tpls, grids, maps, files = {}, {}, {}, {}
for _, name in ipairs(NAMES) do
	local text = read("mods/PLAYER/grug_expeditions/templates/" .. name .. ".exp")
	files[name] = text
	local tpl = T.parse(text, inflate, name)
	check(tpl.grid and #tpl.grid == 4 * tpl.size.x * tpl.size.z, "G " .. name .. " has its grid")
	tpls[name], grids[name] = tpl, W.new(tpl)
	maps[name] = PR.map(tpl, REG, {open = {[DOOR] = true}})
end

-- ---- A. The independent derivation ------------------------------------------------------
-- Per template, from the proof's map: the walking height, the moves, the door cells, the
-- clearance and the 2 x 2 blocks, as tools/expedition_templates/walkgrid.py states them.
local derived = {}
for _, name in ipairs(NAMES) do
	local tpl, g, m = tpls[name], grids[name], maps[name]
	local sx, sz = g.sx, g.sz
	local function free(x, z, y)
		local c = m.class(x, y, z)
		return c == "air" or c == "open" or c == "climb" or (c == "flat" and m.height(x, z) == y)
	end
	local function straight(x, z, nx, nz)
		local h, nh = m.height(x, z), m.height(nx, nz)
		if not h or not nh or abs(h - nh) > 1 then return false end
		local top = max(h, nh)
		return free(x, z, top) and free(x, z, top + 1) and free(nx, nz, top) and free(nx, nz, top + 1)
	end
	local function blocked(x, z, h, nx, nz)
		local nh = m.height(nx, nz)
		if nh then return nh >= h + 2 end
		if not m.inside(nx, h, nz) then return true end
		for y = h, h + 1 do
			local c = m.class(nx, y, nz)
			if not (c == "air" or c == "open" or c == "climb") then return true end
		end
		return false
	end
	local d = {clear = {}, quads = {}, door = {}}
	local bad, first, cells, doors = 0, nil, 0, 0
	local function miss(text)
		bad = bad + 1
		first = first or text
	end
	for z = 0, sz - 1 do
		for x = 0, sx - 1 do
			local i = W.index(g, x, z)
			local h = m.height(x, z)
			if W.height(g, i) ~= h then miss(("height %d,%d: grid %s, proof %s"):format(x, z,
				tostring(W.height(g, i)), tostring(h))) end
			if h then
				cells = cells + 1
				if #m.surfaces[m.key(x, z)] ~= 1 then miss(("two surfaces at %d,%d"):format(x, z)) end
				local mask = 0
				for k, mv in ipairs(W.MOVES) do
					local dx, dz = mv[1], mv[2]
					local ok
					if k <= 4 then
						ok = straight(x, z, x + dx, z + dz)
					else
						ok = straight(x, z, x + dx, z) and straight(x, z, x, z + dz) and
							straight(x + dx, z, x + dx, z + dz) and straight(x, z + dz, x + dx, z + dz)
					end
					if ok then mask = mask + 2 ^ (k - 1) end
				end
				if W.mask(g, i) ~= mask then miss(("moves at %d,%d: grid %d, derived %d"):format(x, z, W.mask(g, i), mask)) end
				local clear = 6
				for r = 1, 5 do
					local hit = false
					for dz = -r, r do
						for dx = -r, r do
							if max(abs(dx), abs(dz)) == r and blocked(x, z, h, x + dx, z + dz) then hit = true end
						end
					end
					if hit then clear = r break end
				end
				if W.clearance(g, i) ~= clear then miss(("clearance at %d,%d: grid %d, derived %d"):format(x, z,
					W.clearance(g, i), clear)) end
				local flags = 0
				for y = h, h + 1 do
					if m.name(x, y, z) == DOOR then flags = 1 end
				end
				if flags == 1 then doors = doors + 1 end
				for k, q in ipairs(W.QUADS) do
					if not (blocked(x, z, h, x + q[1], z) or blocked(x, z, h, x, z + q[2]) or
							blocked(x, z, h, x + q[1], z + q[2])) then
						flags = flags + 2 ^ k
					end
				end
				if W.flags(g, i) ~= flags then miss(("flags at %d,%d: grid %d, derived %d"):format(x, z, W.flags(g, i), flags)) end
				d.clear[i], d.quads[i], d.door[i] = clear, floor(flags / 2) > 0, flags % 2 == 1
			elseif W.mask(g, i) ~= 0 or W.flags(g, i) ~= 0 or W.clearance(g, i) ~= 0 then
				miss(("a column without floor has data at %d,%d"):format(x, z))
			end
		end
	end
	check(bad == 0, ("A %s: the grid against the proof's map: %d differences, the first %s"):format(name, bad,
		tostring(first)))
	check(doors > 0, "A " .. name .. " has door cells")
	derived[name] = d
	print(("A %s: %d walking cells, %d door cells, grid section %d bytes, %d in memory"):format(name, cells,
		doors, #files[name] - data_end(files[name]) - #files[name]:sub(data_end(files[name]) + 1):match("^grid %d+\n"),
		4 * g.n))
end

-- The independent body test: a body of `class` may stand on cell i (door: open or not).
local function may(name, i, class, door)
	local d = derived[name]
	if d.clear[i] == nil then return false end
	if d.door[i] and not door then return false end
	if class == 1 then return true end
	if class == 2 then return d.quads[i] end
	return d.clear[i] >= class - 1
end

-- ---- The fake engine: a world holding one template, grug_nav and grug_obstacle --------
local us = 1000000
-- The templates placed in the fake map: {tpl, ox, oy, oz} each; outside them stone.
local world = {boxes = {}, door_open = false}
local defs = {}
core = {
	registered_nodes = setmetatable({}, {__index = function(_, name)
		if defs[name] == nil then
			local def = REG(name)
			defs[name] = {name = name, walkable = name ~= "air" and def.walkable ~= false,
				liquidtype = def.liquidtype, groups = def.groups or {}, damage_per_second = def.damage_per_second,
				climbable = def.climbable}
		end
		return defs[name]
	end}),
	get_us_time = function() return us end,
	get_modpath = function() return repo .. "/mods/PLAYER/grug_expeditions" end,
	get_current_modname = function() return "grug_expeditions" end,
	find_path = function() return nil end,
}
local find_calls = 0
core.find_path = function() find_calls = find_calls + 1 return nil end
function core.get_node_or_nil(pos)
	for _, box in ipairs(world.boxes) do
		local tpl = box[1]
		local x, y, z = floor(pos.x + 0.5) - box[2], floor(pos.y + 0.5) - box[3], floor(pos.z + 0.5) - box[4]
		if x >= 0 and y >= 0 and z >= 0 and x < tpl.size.x and y < tpl.size.y and z < tpl.size.z then
			local name = tpl.nodes[tpl.cells:byte(z * tpl.size.y * tpl.size.x + y * tpl.size.x + x + 1) + 1]
			if name == DOOR and world.door_open then name = "air" end
			return {name = name}
		end
	end
	return {name = "default:stone"}
end
local O = dofile(repo .. "/mods/ENTITIES/mobs/grug_obstacle.lua")
local nav = dofile(repo .. "/mods/ENTITIES/mobs/grug_nav.lua")
nav.init({obstacle = O, max_jump = 4, max_drop = 6})
local events = {}
nav.on_event = function(self, kind) events[#events + 1] = kind end

local function place(name, ox, oy, oz, more)
	if not more then world.boxes = {} end
	table.insert(world.boxes, {tpls[name], ox, oy, oz})
end
local function mob(width, fields)
	local hw = width / 2
	local m = {_grug_cbox = {-hw, -0.01, -hw, hw, 1.9, hw}, initial_properties = {stepheight = 1.1},
		jump_height = 4, fear_height = 6, floats = false, temp = {}, reach = 3}
	for k, v in pairs(fields or {}) do m[k] = v end
	return m
end

-- A. The walk model against grug_nav's node model: every walking cell standable for a
-- body 0.6 wide and 2 high, every straight move and every diagonal one over a level 2 x 2
-- block a walkable straight line, read from nodes (no grid installed yet). Two things the
-- node model refuses that the engine walks are counted, not tested: a rail in the feet row
-- (grug_nav calls it walkable, the body steps onto its flat box) and a diagonal move past a
-- column a step higher (grug_nav wants both corner cells standable at the start's level;
-- the engine steps a body up onto any box within its stepheight, 1.1 for every Expedition
-- mob, collision.cpp collisionMoveSimple's step_up).
for _, name in ipairs(NAMES) do
	local g, m = grids[name], maps[name]
	place(name, 0, 0, 0)
	world.door_open = true
	local body = nav.body(mob(0.6))
	local bad, first, rails, moves, stepped = 0, nil, 0, 0, 0
	for i = 1, g.n do
		local h = W.height(g, i)
		if h then
			local x, z = W.xz(g, i)
			if m.class(x, h, z) == "flat" then
				rails = rails + 1
			else
				if nav.stand_y(body, x, z, h, 0) ~= h then
					bad = bad + 1
					first = first or ("%d,%d,%d not standable"):format(x, h, z)
				end
				for _, k in ipairs({1, 3, 5, 6}) do
					local j = i + g.step[k]
					if floor(W.mask(g, i) / 2 ^ (k - 1)) % 2 == 1 then
						local jx, jz = W.xz(g, j)
						local level = k <= 4
						if not level then
							local b, c = W.height(g, i + g.step[1]), W.height(g, i + g.step[k == 5 and 3 or 4])
							level = b == h and c == h and W.height(g, j) == h
						end
						local railed = m.class(jx, W.height(g, j), jz) == "flat"
						if k > 4 then
							for _, c in ipairs({i + g.step[1], i + g.step[k == 5 and 3 or 4]}) do
								local cx, cz = W.xz(g, c)
								railed = railed or m.class(cx, W.height(g, c), cz) == "flat"
							end
						end
						if not level then
							stepped = stepped + 1
						elseif not railed then
							moves = moves + 1
							if not nav.line_walkable(body, {x = x, y = h - 0.5, z = z}, {x = jx, y = W.height(g, j), z = jz}) then
								bad = bad + 1
								first = first or ("move %d,%d -> %d,%d not walkable"):format(x, z, jx, jz)
							end
						end
					end
				end
			end
		end
	end
	check(bad == 0, ("A %s: the walk model against the node model: %d, the first %s"):format(name, bad, tostring(first)))
	print(("A %s: %d moves walked on nodes; counted: %d rail cells, %d diagonals past a step"):format(name, moves,
		rails, stepped))
	world.door_open = false
end

-- ---- B. A* against a breadth-first search -----------------------------------------------
-- The fixture's own search: a bucket queue over the costs 5 and 7, the moves read from
-- the mask, the body test from A.
local function reference(name, t, class, door)
	local g = grids[name]
	local dist, buckets, top = {[t] = 0}, {[0] = {t}}, 0
	local d = 0
	while d <= top do
		local list = buckets[d]
		if list then
			for _, i in ipairs(list) do
				if dist[i] == d then
					local mask = W.mask(g, i)
					for k = 1, 8 do
						if floor(mask / 2 ^ (k - 1)) % 2 == 1 then
							local j = i + g.step[k]
							local nd = d + (k > 4 and 7 or 5)
							if may(name, j, class, door) and (not dist[j] or nd < dist[j]) then
								dist[j] = nd
								buckets[nd] = buckets[nd] or {}
								table.insert(buckets[nd], j)
								if nd > top then top = nd end
							end
						end
					end
				end
			end
		end
		d = d + 1
	end
	return dist
end

local function walking(name)
	local g, list = grids[name], {}
	for i = 1, g.n do if W.height(g, i) then list[#list + 1] = i end end
	return list
end
local CELLS = {}
for _, name in ipairs(NAMES) do CELLS[name] = walking(name) end
local function pick(name, class)
	local list = CELLS[name]
	for _ = 1, 1000 do
		local i = list[math.random(#list)]
		if may(name, i, class, false) then return i end
	end
end

-- A path's legality, independently: neighbours, a move of the proof's map, every cell
-- one the body may stand on, the diagonal's two straight cells walking, the cost summed.
local function legal(name, cells, class, door)
	local g, m = grids[name], maps[name]
	local cost = 0
	for k = 2, #cells do
		local a, b = cells[k - 1], cells[k]
		local ax, az = W.xz(g, a)
		local bx, bz = W.xz(g, b)
		local dx, dz = bx - ax, bz - az
		if max(abs(dx), abs(dz)) ~= 1 then return false, "not neighbours" end
		local ha, hb = m.height(ax, az), m.height(bx, bz)
		if not ha or not hb or abs(ha - hb) > 1 then return false, "a step over one" end
		if not may(name, b, class, door) then return false, "a cell the body may not stand on" end
		if dx ~= 0 and dz ~= 0 then
			if not (m.height(ax + dx, az) and m.height(ax, az + dz)) then return false, "a cut corner" end
			cost = cost + 7
		else
			cost = cost + 5
		end
	end
	return true, cost
end

local timing = {}
for _, name in ipairs(NAMES) do
	local g = grids[name]
	local pairs_done, mismatch, illegal, first = 0, 0, 0, nil
	local times, near, worst, worst_cost = {}, {}, 0, 0
	for _, plan in ipairs({{class = 1, targets = 12, sources = 250}, {class = 2, targets = 4, sources = 150},
			{class = 3, targets = 4, sources = 150}}) do
		for _ = 1, plan.targets do
			local t = pick(name, plan.class)
			local ref = reference(name, t, plan.class, false)
			for _ = 1, plan.sources do
				local s = pick(name, plan.class)
				local c0 = os.clock()
				local cells, cost = W.path(g, s, t, plan.class, false)
				local spent = os.clock() - c0
				pairs_done = pairs_done + 1
				if plan.class == 1 then
					times[#times + 1] = spent
					local sx0, sz0 = W.xz(g, s)
					local tx0, tz0 = W.xz(g, t)
					if (sx0 - tx0) ^ 2 + (sz0 - tz0) ^ 2 <= 24 * 24 then near[#near + 1] = spent end
					if spent > worst then worst, worst_cost = spent, cost or -1 end
				end
				if (cells ~= nil) ~= (ref[s] ~= nil) or (cells and cost ~= ref[s]) then
					mismatch = mismatch + 1
					first = first or ("class %d %d -> %d: A* %s, search %s"):format(plan.class, s, t,
						tostring(cost), tostring(ref[s]))
				elseif cells then
					local ok, summed = legal(name, cells, plan.class, false)
					if not ok or summed ~= cost or cells[1] ~= s or cells[#cells] ~= t then
						illegal = illegal + 1
						first = first or ("class %d %d -> %d: %s"):format(plan.class, s, t, tostring(summed))
					end
				end
			end
		end
	end
	check(mismatch == 0 and illegal == 0, ("B %s: %d pairs, %d off the search, %d illegal, the first %s"):format(
		name, pairs_done, mismatch, illegal, tostring(first)))
	table.sort(times)
	table.sort(near)
	-- The worst: the longest way the grid holds, from the cell farthest from a far cell.
	local far = reference(name, CELLS[name][1], 1, true)
	local a, best = CELLS[name][1], -1
	for i, d in pairs(far) do if d > best then a, best = i, d end end
	local back = reference(name, a, 1, true)
	local b = a
	best = -1
	for i, d in pairs(back) do if d > best then b, best = i, d end end
	local c0 = os.clock()
	local cells, cost, expanded = W.path(g, a, b, 1, true)
	local longest = os.clock() - c0
	check(cells and cost == best, "B " .. name .. " the longest way")
	timing[name] = {median = times[floor(#times / 2) + 1], near = near[floor(#near / 2) + 1] or 0, worst = worst,
		longest = longest, steps = #cells, expanded = expanded}
	print(("B %s: %d pairs agree; A* median %.0f us (%d pairs within 24 nodes: %.0f us), worst of the pairs %.0f us, the longest way (%d cells, %d expanded) %.0f us"):format(
		name, pairs_done, timing[name].median * 1e6, #near, timing[name].near * 1e6, worst * 1e6, #cells, expanded,
		longest * 1e6))
end

-- ---- C. Every field, exhaustively -------------------------------------------------------
local function standable(tpl, x, y, z)
	local function name(px, py, pz)
		if px < 0 or py < 0 or pz < 0 or px >= tpl.size.x or py >= tpl.size.y or pz >= tpl.size.z then return "default:stone" end
		return tpl.nodes[tpl.cells:byte(pz * tpl.size.y * tpl.size.x + py * tpl.size.x + px + 1) + 1]
	end
	for dy = 0, 1 do
		local def = core.registered_nodes[name(x, y + dy, z)]
		if def.walkable or (def.damage_per_second or 0) > 0 or (def.groups.lava or 0) > 0 then return false end
	end
	return core.registered_nodes[name(x, y - 1, z)].walkable
end
-- The homes of a template: marker + spread (encounters.lua spot), with the mob's class.
local function homes(name)
	local tpl, list = tpls[name], {}
	for _, row in ipairs(tpl.encounters) do
		for k = 1, row.count do
			local o = SPREAD[(k - 1) % #SPREAD + 1]
			local p = {x = row.pos.x + o[1], y = row.pos.y, z = row.pos.z + o[2]}
			if not standable(tpl, p.x, p.y, p.z) then p = {x = row.pos.x, y = row.pos.y, z = row.pos.z} end
			list[#list + 1] = {pos = p, row = row, class = W.class(width_of(row))}
		end
	end
	return list
end

local field_times = {}
for _, name in ipairs(NAMES) do
	local g = grids[name]
	local fields, cells_checked, bad, first, wide = 0, 0, 0, nil, {}
	local spent = 0
	for _, home in ipairs(homes(name)) do
		local p = home.pos
		local t = W.cell(g, p.x, p.y, p.z, home.class, false)
		check(t ~= nil, ("C %s: the home of %s at %d,%d,%d is on the grid for its class"):format(name, home.row.mob,
			p.x, p.y, p.z))
		if home.class > 1 then wide[home.row.mob .. " " .. home.row.tier] = home.class end
		for _, door in ipairs({false, true}) do
			local c0 = os.clock()
			local field = W.field(g, t, home.class, door)
			spent = spent + (os.clock() - c0)
			fields = fields + 1
			check(W.field(g, t, home.class, door) == field, "C a field is kept")
			local ref = reference(name, t, home.class, door)
			for i = 1, g.n do
				local move = field:byte(i)
				if ref[i] then
					cells_checked = cells_checked + 1
					local ok
					if i == t then
						ok = move == 0
					elseif move >= 1 and move <= 8 then
						local j = i + g.step[move]
						ok = floor(W.mask(g, i) / 2 ^ (move - 1)) % 2 == 1 and ref[j] ~= nil and
							ref[j] + (move > 4 and 7 or 5) == ref[i]
					end
					if not ok then
						bad = bad + 1
						first = first or ("home %d cell %d move %d"):format(t, i, move)
					end
				elseif move ~= NONE then
					bad = bad + 1
					first = first or ("home %d cell %d: a move where no way is"):format(t, i)
				end
			end
		end
	end
	check(bad == 0, ("C %s: %d fields, %d cells: %d off a shortest way, the first %s"):format(name, fields,
		cells_checked, bad, tostring(first)))
	field_times[name] = spent / fields
	local list = {}
	for k, v in pairs(wide) do list[#list + 1] = k .. " class " .. v end
	table.sort(list)
	print(("C %s: %d fields (every home, door shut and open), %d cells on a shortest way; a field %.1f ms, %d bytes; wide: %s"):format(
		name, fields, cells_checked, field_times[name] * 1000, g.n, table.concat(list, ", ")))
	-- The whole walk home from every cell, for the first pack's first home.
	local home = homes(name)[1]
	for _, h in ipairs(homes(name)) do
		if h.row.tier ~= "critter" then home = h break end
	end
	local t = W.cell(g, home.pos.x, home.pos.y, home.pos.z, home.class, false)
	local field = W.field(g, t, home.class, false)
	local ref = reference(name, t, home.class, false)
	local walked = 0
	for i, d in pairs(ref) do
		local cells = W.descend(g, field, i, g.n)
		local ok, cost = legal(name, {i, unpack(cells)}, home.class, false)
		check(ok and cost == d and (cells[#cells] or i) == t, "C " .. name .. " the walk home from " .. i)
		walked = walked + 1
	end
	print(("C %s: the walk home from all %d cells that have one"):format(name, walked))
end

-- ---- The glue: navigation.lua on a fake grug_expeditions -------------------------------
local registered
-- place_on_ground as grug_mobs/init.lua's: the object's position, feet raised by its box.
grug_mobs = {register_evade_guide = function(fn) registered = fn end,
	place_on_ground = function(object, pos) object.placed = {x = pos.x, y = pos.y, z = pos.z} end}
mobs = {grug_nav = nav}
local runs = {}
grug_expeditions = {templates = tpls, catalogue = {definition = function(id) return {template = id} end}}
function grug_expeditions.run_at(pos)
	for _, run in ipairs(runs) do
		local t = tpls[run.expedition]
		if pos.x >= run.minp.x and pos.y >= run.minp.y and pos.z >= run.minp.z and pos.x < run.minp.x + t.size.x
				and pos.y < run.minp.y + t.size.y and pos.z < run.minp.z + t.size.z then
			return run
		end
	end
end
dofile(repo .. "/mods/PLAYER/grug_expeditions/navigation.lua")
local M = grug_expeditions
check(registered == M.evade_guide and nav.grid ~= nil, "F the guide registered through the evade seam, the backend set")
for _, name in ipairs(NAMES) do
	check(tpls[name].walkgrid and tpls[name].walkgrid.raw == tpls[name].grid, "D " .. name .. ": one grid per template")
end
local function run_of(id, name, minp)
	local tpl = tpls[name]
	local door = tpl.places.door
	local run = {id = id, expedition = name, minp = minp,
		places = {door = door and {x = minp.x + door.x, y = minp.y + door.y, z = minp.z + door.z}}}
	runs[#runs + 1] = run
	return run
end
local SLOT = {{x = 4000, y = -3000, z = 0}, {x = 4144, y = -3000, z = 2304}}
local function at(minp, i, g)
	local x, z = W.xz(g, i)
	return {x = minp.x + x, y = minp.y + W.height(g, i), z = minp.z + z}
end
local function expedition_mob(width, run, home)
	return mob(width, {_grug_expedition = run.id, _grug_home = home,
		object = {set_velocity = function(self, v) self.velocity = v end}})
end

-- ---- C (end). The evade guide from every cell, for one home per template ---------------
for k, name in ipairs(NAMES) do
	runs = {}
	local run = run_of(k, name, SLOT[1])
	place(name, SLOT[1].x, SLOT[1].y, SLOT[1].z)
	local g = grids[name]
	local home = homes(name)[1]
	for _, h in ipairs(homes(name)) do
		if h.row.tier ~= "critter" then home = h break end
	end
	local hp = {x = SLOT[1].x + home.pos.x, y = SLOT[1].y + home.pos.y, z = SLOT[1].z + home.pos.z}
	local width = width_of(home.row)
	local t = W.cell(g, home.pos.x, home.pos.y, home.pos.z, home.class, false)
	local ref = reference(name, t, home.class, false)
	local m = expedition_mob(width, run, hp)
	local starts, calls, longest, nodeless, railed, level, bad, first, rounded = 0, 0, 0, 0, 0, 0, 0, nil, 0
	-- A leg with a rail or a step beside it (a node round its box): grug_nav's node model
	-- refuses what the engine walks (A above); such legs are counted.
	local function over_rail(a, b)
		local h0 = a.y - SLOT[1].y
		for z = min(a.z, b.z) - 1 - SLOT[1].z, max(a.z, b.z) + 1 - SLOT[1].z do
			for x = min(a.x, b.x) - 1 - SLOT[1].x, max(a.x, b.x) + 1 - SLOT[1].x do
				local i = W.index(g, x, z)
				local h = i and W.height(g, i)
				if h and (h ~= h0 or maps[name].class(x, h, z) == "flat") then return true end
			end
		end
		return false
	end
	for s in pairs(ref) do
		starts = starts + 1
		m.temp.grug_guide = nil
		local p = at(SLOT[1], s, g)
		local feet = {x = p.x, y = p.y, z = p.z}
		local n = 0
		while (feet.x - hp.x) ^ 2 + (feet.z - hp.z) ^ 2 > 16 do
			local nxt = M.evade_guide(m, {x = feet.x, y = feet.y + 0.01, z = feet.z}, hp)
			n = n + 1
			if not nxt or n > 200 then
				bad = bad + 1
				first = first or ("from %d: %s after %d"):format(s, nxt and "no arrival" or "no answer", n)
				break
			end
			-- Each leg a straight walk in grug_nav's node model too (a body 0.6 wide).
			-- A point round a corner (the guide's GUIDE_NEAR) is walked over the grid's
			-- path, not straight: only straight legs are checked on nodes.
			local straight = W.line(g, {x = feet.x - SLOT[1].x, y = feet.y - SLOT[1].y, z = feet.z - SLOT[1].z},
				{x = nxt.x - SLOT[1].x, y = nxt.y - SLOT[1].y, z = nxt.z - SLOT[1].z}, home.class, width / 2, false, 0)
			if not straight then rounded = rounded + 1 end
			if width <= 1 and n <= 3 and straight then
				local body = nav.body(mob(0.6))
				if over_rail(feet, nxt) then
					railed = railed + 1
				else
					level = level + 1
					if not nav.line_walkable(body, {x = feet.x, y = feet.y - 0.5, z = feet.z}, nxt) then
						nodeless = nodeless + 1
						first = first or ("leg %d,%d -> %d,%d not walkable on nodes"):format(feet.x, feet.z, nxt.x, nxt.z)
					end
				end
			end
			feet = {x = nxt.x, y = nxt.y, z = nxt.z}
		end
		calls = calls + n
		if n > longest then longest = n end
	end
	check(bad == 0 and nodeless == 0, ("C %s: the guide from %d cells: %d failed, %d legs not walkable on nodes, the first %s"):format(
		name, starts, bad, nodeless, tostring(first)))
	print(("C %s: the guide brings a %s home from all %d cells, %.1f answers on average, at most %d; of its first legs %d level ones walk on nodes, %d by a rail or a step counted; %d points round a corner"):format(name,
		home.row.mob, starts, calls / starts, longest, level, railed, rounded))
end

-- ---- D. The offset ----------------------------------------------------------------------
for k, name in ipairs(NAMES) do
	runs = {}
	local r1, r2 = run_of(10 + k, name, SLOT[1]), run_of(20 + k, name, SLOT[2])
	place(name, SLOT[1].x, SLOT[1].y, SLOT[1].z)
	place(name, SLOT[2].x, SLOT[2].y, SLOT[2].z, true)
	local g = grids[name]
	local m1, m2 = expedition_mob(0.6, r1, at(SLOT[1], CELLS[name][1], g)), expedition_mob(0.6, r2, at(SLOT[2], CELLS[name][1], g))
	local v1, v2 = nav.grid.view(m1), nav.grid.view(m2)
	check(v1 and v2 and v1 ~= v2 and v1.g == v2.g and nav.grid.view(m1) == v1, "D " .. name .. ": two runs, one grid")
	local body = nav.body(m1)
	local same = 0
	for _ = 1, 200 do
		local s, t = pick(name, 1), pick(name, 1)
		local a = nav.grid.path(v1, body, at(SLOT[1], s, g), at(SLOT[1], t, g))
		local b = nav.grid.path(v2, body, at(SLOT[2], s, g), at(SLOT[2], t, g))
		local ok = (a == nil) == (b == nil)
		if a and b then
			ok = #a == #b
			for j = 1, #a do
				ok = ok and a[j].x - SLOT[1].x == b[j].x - SLOT[2].x and a[j].y - SLOT[1].y == b[j].y - SLOT[2].y
					and a[j].z - SLOT[1].z == b[j].z - SLOT[2].z
			end
		end
		if ok then same = same + 1 end
	end
	check(same == 200, ("D %s: %d of 200 answers the same in both slots"):format(name, same))
	-- The guide too, and a mob of another run or outside any is no grid's.
	local h = CELLS[name][#CELLS[name]]
	local e1 = expedition_mob(0.6, r1, at(SLOT[1], h, g))
	local e2 = expedition_mob(0.6, r2, at(SLOT[2], h, g))
	local s = CELLS[name][floor(#CELLS[name] / 2)]
	local q1 = M.evade_guide(e1, at(SLOT[1], s, g), e1._grug_home)
	local q2 = M.evade_guide(e2, at(SLOT[2], s, g), e2._grug_home)
	check((q1 == nil) == (q2 == nil) and (not q1 or (q1.x - SLOT[1].x == q2.x - SLOT[2].x and q1.z - SLOT[1].z == q2.z - SLOT[2].z)),
		"D " .. name .. ": the guide answers the same in both slots")
	check(nav.grid.view(mob(0.6)) == nil and nav.grid.view(expedition_mob(0.6, {id = 99}, e1._grug_home)) == nil,
		"D " .. name .. ": no grid for a mob outside an Expedition or of another run")
end

-- ---- E. Off the grid, the door, the clearance -------------------------------------------
do
	runs = {}
	local name = "last_mint"
	local run = run_of(31, name, SLOT[1])
	place(name, SLOT[1].x, SLOT[1].y, SLOT[1].z)
	local g = grids[name]
	local m = expedition_mob(0.6, run, at(SLOT[1], CELLS[name][1], g))
	local v = nav.grid.view(m)
	-- In the air: two nodes over a walking cell it is that cell, three over it is none.
	local i = CELLS[name][100]
	local x, z = W.xz(g, i)
	local h = W.height(g, i)
	local function cell(px, py, pz) return W.cell(g, px, py, pz, 1, false) end
	check(cell(x, h + 2, z) == i, "E in the air two nodes up: its cell")
	local high = true
	for dz = -2, 2 do for dx = -2, 2 do
		local j = W.index(g, x + dx, z + dz)
		if j and W.height(g, j) and W.height(g, j) >= h + 1 then high = false end
	end end
	if high then check(cell(x, h + 3, z) == nil, "E three nodes up: off the grid") end
	-- In a wall corner: a column without floor beside walking cells snaps to the nearest.
	local wall
	for _, j in ipairs(CELLS[name]) do
		local jx, jz = W.xz(g, j)
		local k = W.index(g, jx + 1, jz)
		if k and not W.height(g, k) and maps[name].class(jx + 1, W.height(g, j), jz) == "full" then wall = j break end
	end
	local wx, wz = W.xz(g, wall)
	check(cell(wx + 0.9, W.height(g, wall), wz) == wall, "E pressed into a wall: the cell beside it")
	-- In the lava lake: far under every walking cell, none within two nodes.
	check(cell(108, 8, 60) == nil and cell(100, 8, 50) == nil, "E in the lava: off the grid")
	check(M.evade_guide(m, {x = SLOT[1].x + 100, y = SLOT[1].y + 8, z = SLOT[1].z + 50}, m._grug_home) == nil,
		"E the guide answers nil for a mob in the lava")
	-- A moment off the grid keeps the last point for two seconds (no flapping walk keys).
	local away = at(SLOT[1], CELLS[name][2000], g)
	local p0 = M.evade_guide(m, away, m._grug_home)
	us = us + 1500000
	local held = M.evade_guide(m, {x = SLOT[1].x + 100, y = SLOT[1].y + 8, z = SLOT[1].z + 50}, m._grug_home)
	us = us + 1000000
	local gone = M.evade_guide(m, {x = SLOT[1].x + 100, y = SLOT[1].y + 8, z = SLOT[1].z + 50}, m._grug_home)
	check(p0 ~= nil and held == p0 and gone == nil and m.object.placed == nil,
		"E the last point held two seconds off the grid, then nil")
	-- Off the grid longer than that (fallen into the lake): set home at once (the user,
	-- 2026-11-10), placed like a pack's jump.
	us = us + 1000000
	local still = M.evade_guide(m, {x = SLOT[1].x + 100, y = SLOT[1].y + 8, z = SLOT[1].z + 50}, m._grug_home)
	check(still == nil and m.object.placed == nil, "E off the grid two seconds: still nothing")
	us = us + 1100000
	local home = M.evade_guide(m, {x = SLOT[1].x + 100, y = SLOT[1].y + 8, z = SLOT[1].z + 50}, m._grug_home)
	check(home and home.x == m._grug_home.x and home.z == m._grug_home.z and m.object.placed and
		m.object.placed.x == m._grug_home.x and m.object.velocity and m.object.velocity.x == 0 and
		m.temp.grug_nav == nil, "E off the grid longer: set home at once, stopped, its navigation forgotten")
	-- A new stretch off the grid starts its own count: a stale one does not set home.
	us = us + 10000000
	m.object.placed = nil
	check(M.evade_guide(m, {x = SLOT[1].x + 100, y = SLOT[1].y + 8, z = SLOT[1].z + 50}, m._grug_home) == nil
		and m.object.placed == nil, "E a later stretch off the grid counts afresh")
	-- An elite of two nodes (1.4 wide) pressed against a passage's wall by the engine (the
	-- Round 74 engine run's trace: x 86.2 in the passage x 86..90) sees its way along it.
	local guard_home = {x = SLOT[1].x + 64, y = SLOT[1].y + 32, z = SLOT[1].z + 58}
	local guard = expedition_mob(1.4, run, guard_home)
	local ahead = M.evade_guide(guard, {x = SLOT[1].x + 86.2, y = SLOT[1].y + 33.01, z = SLOT[1].z + 44.8}, guard_home)
	check(ahead and ahead.z - SLOT[1].z >= 52, "E a wide body along a wall: a point far ahead, " ..
		tostring(ahead and ahead.z - SLOT[1].z))
	-- The flue (the fix round's run): a Lava Flan in an ambush alcove, whose only straight
	-- cell is the next, is given the far end of its next twelve cells, not a point it
	-- overruns into the opposite alcove.
	local flan_home = {x = SLOT[1].x + 65, y = SLOT[1].y + 30, z = SLOT[1].z + 97}
	local flan = expedition_mob(1.0, run, flan_home)
	flan._grug_cbox = {-0.5, -0.5, -0.5, 0.5, 1.2, 0.5}
	for _, z in ipairs({89.2, 82.8}) do
		flan.temp.grug_guide = nil
		local q = M.evade_guide(flan, {x = SLOT[1].x + 80, y = SLOT[1].y + 32, z = SLOT[1].z + z}, flan_home)
		local d = q and math.sqrt((q.x - SLOT[1].x - 80) ^ 2 + (q.z - SLOT[1].z - z) ^ 2)
		check(d and d >= 6, ("E in an alcove of the flue at z %.1f: a far point (%s)"):format(z, tostring(d)))
		-- and the fixed walk there searches the grid at once, its line being blocked.
		local walker = expedition_mob(1.0, run, flan_home)
		walker._grug_cbox = flan._grug_cbox
		events = {}
		us = us + 100000
		nav.begin_server_step(0.1)
		local steer = nav.fixed_step(walker, {x = SLOT[1].x + 80, y = SLOT[1].y + 32, z = SLOT[1].z + z}, 1, q, "evade_guide1")
		check(events[1] == "blocked" and events[2] == "found" and steer ~= nil,
			"E the walk to a point round the corner follows the grid's path at once: " .. table.concat(events, ","))
	end
	-- The lake: a mob across it has no way home over the grid (mobs do not leap).
	local near_home = at(SLOT[1], W.cell(g, 57, 31, 99, 1, false), g) -- pack_a's marker
	local across = expedition_mob(1.0, run, near_home)
	local back = M.evade_guide(across, at(SLOT[1], W.cell(g, 64, 30, 23, 1, false), g), near_home)
	check(back and back.x == near_home.x and back.z == near_home.z and across.object.placed and
		across.object.placed.z == near_home.z, "E across the lake: no way home over the grid, set home at once")
	-- A flier as well (an Ember Wisp of pack_b across the lake).
	local wisp = expedition_mob(0.4, run, near_home)
	check(M.evade_guide(wisp, at(SLOT[1], W.cell(g, 108, 32, 40, 1, false), g), near_home) and wisp.object.placed,
		"E a flier across the lake: set home at once too")
	-- The door: from the boss's floor to the chest, shut none, open one through it.
	local body = nav.body(m)
	local boss = at(SLOT[1], W.cell(g, 64, 30, 23, 1, false), g)
	local chest = tpls[name].places.chest
	local goal = {x = SLOT[1].x + chest.x + 1, y = SLOT[1].y + chest.y, z = SLOT[1].z + chest.z}
	world.door_open = false
	check(nav.grid.path(v, body, boss, goal) == nil, "E the door shut: no way to the chest")
	world.door_open = true
	local open = nav.grid.path(v, body, boss, goal)
	check(open ~= nil, "E the door open: a way to the chest")
	local through = false
	for _, p in ipairs(open) do
		local j = W.index(g, p.x - SLOT[1].x, p.z - SLOT[1].z)
		if W.flags(g, j) % 2 == 1 then through = true end
	end
	check(through, "E the way leads through the door's cells")
	world.door_open = false
	-- The clearance: a spider (2.1 wide) in The Stilled Seam never steps on a cell with
	-- less than two nodes to a wall; a one-wide body does, and its way is never longer.
	name = "stilled_seam"
	runs = {}
	local seam = run_of(32, name, SLOT[1])
	place(name, SLOT[1].x, SLOT[1].y, SLOT[1].z)
	g = grids[name]
	local spider = expedition_mob(2.1, seam, at(SLOT[1], CELLS[name][1], g))
	local thin = expedition_mob(0.6, seam, at(SLOT[1], CELLS[name][1], g))
	local sv, sb, tb = nav.grid.view(spider), nav.body(spider), nav.body(thin)
	check(W.class(sb.width) == 3 and W.class(1.4) == 2 and W.class(0.84) == 1 and W.class(2.94) == 3 and W.class(3.2) == 4,
		"E the classes by width")
	local narrow_used, pairs_wide = 0, 0
	for _ = 1, 200 do
		local s, t = pick(name, 3), pick(name, 3)
		local a = nav.grid.path(sv, sb, at(SLOT[1], s, g), at(SLOT[1], t, g))
		local b = nav.grid.path(sv, tb, at(SLOT[1], s, g), at(SLOT[1], t, g))
		check(b ~= nil or a == nil, "E where a spider walks, a thin body walks")
		if a then
			pairs_wide = pairs_wide + 1
			for _, p in ipairs(a) do
				if W.clearance(g, W.index(g, p.x - SLOT[1].x, p.z - SLOT[1].z)) < 2 then narrow_used = narrow_used + 1 end
			end
		end
	end
	check(pairs_wide > 100 and narrow_used == 0, ("E a spider's ways keep two nodes from walls (%d ways)"):format(pairs_wide))
	-- A two-node body steers at the middle of its free 2 x 2 block.
	local flan = expedition_mob(1.4, seam, at(SLOT[1], CELLS[name][1], g))
	local fp
	for _ = 1, 50 do
		fp = nav.grid.path(sv, nav.body(flan), at(SLOT[1], pick(name, 2), g), at(SLOT[1], pick(name, 2), g))
		if fp and #fp > 5 then break end
	end
	local middle = fp ~= nil and #fp > 5
	for k = 1, fp and #fp or 0 do middle = middle and fp[k].x % 1 == 0.5 and fp[k].z % 1 == 0.5 end
	check(middle, "E a two-node body at its block's middle")
end

-- ---- F. The chase over grug_nav ---------------------------------------------------------
do
	runs = {}
	local name = "stilled_seam"
	local run = run_of(41, name, SLOT[1])
	place(name, SLOT[1].x, SLOT[1].y, SLOT[1].z)
	local g = grids[name]
	local DT = 0.1
	local function target_at(p)
		return {get_luaentity = function() return nil end, is_player = function() return true end,
			get_properties = function() return {collisionbox = {-0.3, 0, -0.3, 0.3, 1.77, 0.3}} end, pos = p}
	end
	-- Pairs whose straight line is blocked (a wall between) but which a way joins: the mob
	-- chases a still target and must reach striking range.
	local chases, reached, steps_total, searched_late = 0, 0, 0, 0
	local tries = 0
	while chases < 40 and tries < 4000 do
		tries = tries + 1
		local s, t = pick(name, 1), pick(name, 1)
		local sp, tp = at(SLOT[1], s, g), at(SLOT[1], t, g)
		local d2 = (sp.x - tp.x) ^ 2 + (sp.z - tp.z) ^ 2
		if d2 > 64 and d2 < 900 and not W.line(g, {x = sp.x - SLOT[1].x, y = sp.y - SLOT[1].y, z = sp.z - SLOT[1].z},
				{x = tp.x - SLOT[1].x, y = tp.y - SLOT[1].y, z = tp.z - SLOT[1].z}, 1, 0.3, false, 1)
				and W.path(g, s, t, 1, false) then
			chases = chases + 1
			local m = expedition_mob(0.6, run, sp)
			local target = target_at(tp)
			local p = {x = sp.x, y = sp.y + 0.01, z = sp.z}
			events = {}
			local done = false
			for n = 1, 600 do
				us = us + floor(DT * 1e6)
				nav.begin_server_step(DT)
				O.begin_server_step()
				local dist = sqrt((tp.x - p.x) ^ 2 + (tp.z - p.z) ^ 2)
				local striking = dist <= 2.5
				if striking then
					done = true
					steps_total = steps_total + n
					break
				end
				local steer = nav.combat_step(m, p, DT, target, {x = tp.x, y = tp.y, z = tp.z}, dist, false, false)
				if n == 1 and not (events[1] == "blocked" and steer) then searched_late = searched_late + 1 end
				local aim = steer or tp
				-- Move 4.6 nodes a second towards the aim over walking cells a step apart at
				-- most (a body that would walk into a wall stays where it is, wanting to move:
				-- the stuck detector reads it).
				local dx, dz = aim.x - p.x, aim.z - p.z
				local l = sqrt(dx * dx + dz * dz)
				if l > 1e-6 then
					local step = min(l, 4.6 * DT)
					local np = {x = p.x + dx / l * step, y = p.y, z = p.z + dz / l * step}
					local i = W.index(g, floor(np.x - SLOT[1].x + 0.5), floor(np.z - SLOT[1].z + 0.5))
					local feet = floor(p.y - SLOT[1].y + 0.5)
					if i and W.height(g, i) and abs(W.height(g, i) - feet) <= 1 then
						np.y = SLOT[1].y + W.height(g, i) + 0.01
						p = np
					end
				end
				nav.command(m, p, 4.6)
			end
			if done then reached = reached + 1 end
		end
	end
	check(chases == 40 and reached == chases, ("F %d chases round a wall, %d reached striking range"):format(chases, reached))
	check(searched_late == 0, "F a blocked line searches on the first step")
	print(("F %s: %d chases round walls reach striking range, %.1f s on average"):format(name, reached,
		steps_total / reached * DT))
	-- A free line: no search at all.
	local s = CELLS[name][1]
	local sp = at(SLOT[1], s, g)
	local tp
	for _, j in ipairs(CELLS[name]) do
		local q = at(SLOT[1], j, g)
		local d2 = (q.x - sp.x) ^ 2 + (q.z - sp.z) ^ 2
		if d2 > 25 and d2 < 100 and W.line(g, {x = sp.x - SLOT[1].x, y = sp.y - SLOT[1].y, z = sp.z - SLOT[1].z},
				{x = q.x - SLOT[1].x, y = q.y - SLOT[1].y, z = q.z - SLOT[1].z}, 1, 0.3, false, 1) then tp = q break end
	end
	local m = expedition_mob(0.6, run, sp)
	events = {}
	for _ = 1, 10 do
		us = us + 100000
		nav.begin_server_step(DT)
		local steer = nav.combat_step(m, {x = sp.x, y = sp.y + 0.01, z = sp.z}, DT, target_at(tp), tp, 5, false, false)
		check(steer == nil, "F a free line: straight at the target")
		nav.command(m, sp, 0)
	end
	check(#events == 0, "F a free line: no search")
	-- Outside an Expedition: no grid, the engine's search after the mob is stuck.
	local plain = mob(0.6)
	events = {}
	find_calls = 0
	for _ = 1, 12 do
		us = us + 100000
		nav.begin_server_step(DT)
		O.begin_server_step()
		nav.combat_step(plain, {x = sp.x, y = sp.y + 0.01, z = sp.z}, DT, target_at(tp), tp, 5, false, false)
		nav.command(plain, sp, 4.6)
	end
	local blocked = false
	for _, e in ipairs(events) do if e == "blocked" then blocked = true end end
	check(not blocked and plain.temp.grug_nav.grid_lt == false and nav.body(plain).grid == nil,
		"F a mob outside an Expedition is not tested on the grid")
	find_calls = 0
	nav.search({x = sp.x, y = sp.y, z = sp.z}, tp, 6, 4, 6, nav.body(plain))
	check(find_calls == 1, "F a mob outside an Expedition keeps the engine's search")
	local inside = expedition_mob(0.6, run, sp)
	local found = nav.search({x = sp.x, y = sp.y, z = sp.z}, tp, 6, 4, 6, nav.body(inside))
	check(find_calls == 1 and found and #found >= 2, "F an Expedition mob's search is the grid's")
end

-- ---- G. The reader ----------------------------------------------------------------------
do
	local text = files.test_vault
	local cut = text:sub(1, #text - 3)
	check(not pcall(T.parse, cut, inflate, "t"), "G a grid cut short is refused")
	check(not pcall(T.parse, text .. "x", inflate, "t"), "G bytes after the grid are refused")
	local bare = text:sub(1, data_end(text))
	check(text:sub(#bare + 1, #bare + 5) == "grid ", "G the grid line follows the cells")
	local tpl = T.parse(bare, inflate, "t")
	check(tpl.grid == nil and tpl.cells == tpls.test_vault.cells, "G a file without a grid parses, without one")
	check(not pcall(T.parse, bare .. "nonsense 4\nabcd", inflate, "t"), "G another section is refused")
	core.decompress = function(bytes) return inflate(bytes) end
	local path = os.tmpname()
	local handle = assert(io.open(path, "wb"))
	handle:write(bare)
	handle:close()
	local ok, message = pcall(T.load, path, "test_vault", {x = 128, y = 64, z = 128}, {"arrival"})
	os.remove(path)
	check(not ok and tostring(message):find("no walk grid", 1, true), "G load requires the grid: " .. tostring(message))
end

print(("R74 NAV numbers: %s"):format(table.concat((function()
	local out = {}
	for _, name in ipairs(NAMES) do
		out[#out + 1] = ("%s A* median %.0f us (within 24 nodes %.0f us) worst %.0f us longest %.0f us, field %.1f ms"):format(
			name, timing[name].median * 1e6, timing[name].near * 1e6, timing[name].worst * 1e6, timing[name].longest * 1e6,
			field_times[name] * 1000)
	end
	return out
end)(), "; ")))
print(("R74 NAV PORTABLE PASS checks=%d (%.1f s)"):format(checks, os.clock() - started))
