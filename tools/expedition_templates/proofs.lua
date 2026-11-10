-- The one shared proof of an Expedition template (Round 72 PROOF, Round 73 TOOLS:
-- round73-expedition-redesign-concept.md section 7). Every fixture that owns a
-- template (tools/r71_l20, tools/r72_shift, tools/r72_mint) reads its written file and
-- asks these questions of it; the floor is a height map read from that file, never from
-- a source, with stairs as floor.
--
--   local PR = dofile(repo .. "/tools/expedition_templates/proofs.lua")
--   local m = PR.map(tpl, PR.registry(repo), {open = {[DOOR] = true, [ORE] = true}})
--   local report = PR.prove(m, spec)          -- every rule, see `P.RULES` and `spec` below
--   PR.enforce(report, check, spec.report)    -- fails a rule unless it is reported only
--
-- The rules, by id (concept section 7; the numbers are its items):
--   surface      1  one walking surface per column; the hull closed
--   relief       1  neighbours within one, a stair at every change facing the lower side
--                   (inner and outer at corners), no stair without a change, no ridge or
--                   trench one node wide
--   free_height  2  Round 72's three nodes of air over every walking cell
--   head_room    2  the tallest mob of the Expedition plus one node (spec.tallest)
--   perches      3  no place off the floor a walk, jump, leap or fall reaches but a
--                   waystone or the chest, and no rope in reach
--   dressing     4  no walkable decoration on a walking cell (furniture: P.FURNITURE and
--                   spec.props), no cobweb on one, no gathering source or crop anywhere
--   route        5  every marker and place reached over the height map from the arrival;
--                   with the door shut neither the chest nor the end waystone
--   packs        6  every floor cell of a pack's room noticed by its pack, and no walk from
--                   its way in to its way on (or its ore) round the cells it notices
--   light        7  the zones: fighting floor at 4 or more and 6 or more on 75 %, the
--                   arrival, waystones, chest and door at 6 or more
--   sight        7  from every walking cell below light 4 a light source in sight (in an
--                   ambush's alcoves, within two steps of a cell that sees one)
--   ambush       8  each zone flat, cutting the floor, at light 0 with its alcoves and a
--                   margin; never the first fight (no walk from the arrival reaches it
--                   past every pack room); alcoves joined and fitting; markers normal and
--                   melee; out of every pack's notice and room; zone and markers out of
--                   sight of the respawn place (the arrival); no trap in its dark stretch
--   lava         9  lava closed but for a falling column's open face; no basin at a
--                   stair's foot, a passage mouth (spec.mouths) or in an ambush's dark
--   traps       10  floor traps on flat cells, wall muzzles open and at body height over
--                   the local floor
--   particles   11  the live total within the budget (300), every box in the open
--
-- The switch: `spec.report` (a set of rule ids, or P.NEW for every rule a Round 72
-- template was not built for) turns those rules' failures into report lines. A wave 2
-- lane drops it for its template: every rule then fails the fixture.
local P = {}

P.RULES = {"surface", "relief", "free_height", "head_room", "perches", "dressing", "route", "packs",
	"light", "sight", "ambush", "lava", "traps", "particles"}
-- The rules Round 73 adds; the others are Round 72's in their height-map form.
P.NEW = {relief = true, head_room = true, dressing = true, light = true, sight = true, ambush = true,
	lava = true, particles = true}

-- The numbers (concept section 4.4, traps.lua, encounters.lua, player_api).
-- USUAL_SHARE 0.75: the user, 2026-11-10 (was 0.9), so pack rooms may have darker patches.
P.LIGHT_MIN, P.LIGHT_USUAL, P.USUAL_SHARE, P.BRIGHT = 4, 6, 0.75, 6
P.BRIGHT_REACH = 3      -- nodes round the arrival, the waystones, the chest and the door
P.SIGHT_REACH = 32      -- a light within this distance and in sight
P.TRAP_RADIUS = 2       -- traps.lua T.RADIUS
P.BALL = 0.4            -- traps.lua BALL
P.MOUTH_CLEAR = 2       -- no lava within this many nodes of a stair's foot or a mouth
P.FREE_HEIGHT = 3       -- Round 72
P.PLAYER_EYE = 1.47     -- player_api eye_height: a player's look at a light
P.MOB_EYE = 1           -- mobs_redo general_attack: both ends of a mob's look, feet + 1
P.AMBUSH_MARGIN = 2    -- nodes of light 0 round an ambush zone along the passage
P.PARTICLE_BUDGET = 300 -- template.lua M.PARTICLE_BUDGET: the most live particles a template keeps
-- The shooters of the Expeditions' rosters (attack_type shoot or dogshoot in grug_mobs):
-- never an ambush's marker (encounters.lua refuses them at load too). spec.ranged
-- replaces the set.
P.RANGED = {["grug_mobs:skeleton_raider"] = true, ["grug_mobs:ember_wisp"] = true,
	["grug_mobs:stone_golem"] = true, ["grug_mobs:skeleton_archer"] = true, ["grug_mobs:bandit_archer"] = true}
P.SPREAD = {{0, 0}, {3, 0}, {-3, 0}, {0, 3}, {0, -3}, {3, 3}, {-3, 3}, {3, -3}, {-3, -3}} -- encounters.lua

-- The mod's own nodes are not in the registry (template.py OWN_NODES).
P.OWN = {
	["grug_expeditions:waystone"] = {walkable = true, drawtype = "mesh", paramtype = "none"},
	["grug_expeditions:reward_chest"] = {walkable = true, drawtype = "mesh", paramtype = "none"},
	["grug_expeditions:reward_door"] = {walkable = true, drawtype = "normal", paramtype = "none"},
}
-- What a player may stand on off the floor (the user's exception), and furniture that may
-- stand on a floor cell: walkable, but no decoration (concept section 4.7). A walkable
-- node on the floor outside these is a step the height map does not know.
P.FLAT_OK = {["grug_mapgen:mine_rail"] = true} -- walkable and flat on a walking cell
P.ALLOWED = {["grug_expeditions:waystone"] = true, ["grug_expeditions:reward_chest"] = true}
P.FURNITURE = {["grug_expeditions:waystone"] = true, ["grug_expeditions:reward_chest"] = true,
	["grug_expeditions:reward_door"] = true, ["grug_decor:cottages_table"] = true,
	["grug_decor:cottages_bench"] = true, ["grug_decor:cottages_barrel"] = true,
	["grug_mapgen:mine_cart"] = true}

-- ---- The registry ----------------------------------------------------------------------
-- tools/building_templates/nodes.json holds one node per line: only the lines of the
-- names asked for are decoded.
function P.registry(repo)
	local handle = assert(io.open(repo .. "/tools/building_templates/nodes.json", "r"))
	local text = handle:read("*a")
	handle:close()
	local json = dofile(repo .. "/tools/r28_b4_quests/json.lua")
	local cache = {}
	return function(name)
		if cache[name] then return cache[name] end
		local def = P.OWN[name]
		if not def then
			local key = '\n"' .. name .. '":{'
			local at = assert(text:find(key, 1, true), "proofs: a node the registry does not know: " .. name)
			local stop = text:find("\n", at + 1, true)
			def = json.decode(text:sub(at + #key - 1, stop - 1):gsub(",$", ""))
		end
		cache[name] = def
		return def
	end
end

-- A box list from a registry node box: one box or many, `fixed` only.
local function boxes_of(box)
	if not box or box.type ~= "fixed" or not box.fixed then return nil end
	local fixed = box.fixed
	if type(fixed[1]) == "number" then fixed = {fixed} end
	return fixed
end

-- The stair shapes by their high quarters at param2 0 (mods/BASE/stairs/init.lua): a
-- quarter is {qx, qz}, -1 or 1, the node's corner it covers. Facedir p turns +z to +x
-- (mapnode.cpp transformNodeBox: rotateXZBy(-90) for facedir 1).
P.STAIR_HIGH = {normal = {{-1, 1}, {1, 1}}, inner = {{-1, 1}, {1, 1}, {-1, -1}}, outer = {{-1, 1}}}
local function turn(qx, qz, p)
	for _ = 1, p % 4 do qx, qz = qz, -qx end
	return qx, qz
end
-- The high quarters of a shape at param2 p, as a 4-bit mask (bit per corner).
local function corner_bit(qx, qz) return 2 ^ ((qx + 1) / 2 + (qz + 1)) end
function P.stair_mask(shape, p)
	local mask = 0
	for _, q in ipairs(P.STAIR_HIGH[shape]) do mask = mask + corner_bit(turn(q[1], q[2], p)) end
	return mask
end
-- The shape and param2 for a mask of high quarters, or nil (a peak or a diagonal ridge).
local MASK_SHAPE = {}
for _, shape in ipairs({"normal", "inner", "outer"}) do
	for p = 0, 3 do MASK_SHAPE[P.stair_mask(shape, p)] = {shape, p} end
end
function P.stair_for(mask) local s = MASK_SHAPE[mask]; if s then return s[1], s[2] end end

-- What a node is to a body: air, open (not walkable), climb (a rope), liquid (lava:
-- a fall into it ends), flat (a rail: walkable, flush with the floor), stair, full (a
-- whole node) or prop (walkable, any other shape).
local function facts(def, name)
	local f = {name = name, walkable = def.walkable ~= false, light = math.min(def.light_source or 0, 14),
		propagates = def.paramtype == "light", facedir = def.paramtype2 == "facedir",
		lava = def.groups and (def.groups.lava or 0) > 0}
	f.boxes = boxes_of(def.collision_box) or (def.drawtype == "nodebox" and boxes_of(def.node_box)) or nil
	f.sel = boxes_of(def.selection_box) or (def.drawtype == "nodebox" and boxes_of(def.node_box)) or f.boxes
	f.stair = name:match("^stairs:stair_inner_") and "inner" or name:match("^stairs:stair_outer_") and "outer" or
		name:match("^stairs:stair_") and "normal" or nil
	f.harvest = (name:match("^grug_mapgen:.*_source$") or name:match("^grug_gathering:") or
		name:match("^grug_farming:") or (def.groups and ((def.groups.plant or 0) > 0 or (def.groups.crop or 0) > 0)))
		and true or false
	f.cobweb = name:find("cobweb", 1, true) ~= nil
	if name == "air" then
		f.class = "air"
	elseif def.liquidtype and def.liquidtype ~= "none" then
		f.class = "liquid"
	elseif not f.walkable then
		f.class = def.climbable and "climb" or "open"
	elseif f.stair then
		f.class = "stair"
	elseif f.boxes then
		local top = -0.5
		for _, b in ipairs(f.boxes) do top = math.max(top, b[2], b[5]) end
		f.top = top
		f.class = top <= -0.25 and "flat" or "prop"
	else
		f.class = def.drawtype == "normal" and "full" or (P.FURNITURE[name] or P.ALLOWED[name]) and "prop" or "full"
	end
	return f
end

-- A walking cell: a player stands in it on a floor, a whole node or a stair (or on a rail
-- over a whole node), never on a prop.
local function on_floor(m, x, y, z, changed)
	if not m.stands(x, y, z, changed) then return false end
	local below = m.class(x, y - 1, z, changed)
	return below == "full" or below == "stair" or m.class(x, y, z, changed) == "flat"
end

-- The floor a player walks to from (x, y, z): a step to a neighbour's walking cell at the
-- same height or one down, one up only onto a stair (a step up a whole node is a jump,
-- and the perches find it), and a level leap over one or two open columns (The Last
-- Mint's lake). `blocked` columns ({[key] = true}) are neither walked nor leapt over.
-- Returns {cells = {[m.at] = steps}, columns = {[key] = {y...}}, count}.
function P.floor_walk(m, x, y, z, changed, blocked)
	blocked = blocked or {}
	local cells, columns, queue, head = {}, {}, {}, 1
	local function push(px, py, pz, steps)
		local index = m.at(px, py, pz)
		if cells[index] == nil then
			cells[index] = steps
			local key = m.key(px, pz)
			columns[key] = columns[key] or {}
			table.insert(columns[key], py)
			queue[#queue + 1] = {px, py, pz}
		end
	end
	if not (m.inside(x, y, z) and on_floor(m, x, y, z, changed)) then return {cells = cells, columns = columns, count = 0} end
	push(x, y, z, 0)
	while queue[head] do
		local cx, cy, cz = queue[head][1], queue[head][2], queue[head][3]
		head = head + 1
		local steps = cells[m.at(cx, cy, cz)] + 1
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local nx, nz = cx + d[1], cz + d[2]
			if m.inside(nx, cy, nz) then
				local moved = false
				for _, dy in ipairs({0, -1, 1}) do
					local ny = cy + dy
					if ny >= 1 and ny < m.sy - 1 and not blocked[m.key(nx, nz)] and on_floor(m, nx, ny, nz, changed)
							and (dy < 1 or m.class(nx, ny - 1, nz, changed) == "stair")
							and (dy > -1 or m.passes(nx, cy + 1, nz, changed)) then
						push(nx, ny, nz, steps)
						moved = true
					end
				end
				-- A level leap: the columns crossed open from the feet to a node over the head.
				if not moved and m.passes(cx, cy + 2, cz, changed) then
					for k = 1, 2 do
						local px, pz = cx + d[1] * k, cz + d[2] * k
						local clear = m.inside(px, cy, pz) and not blocked[m.key(px, pz)]
						for dy = 0, 2 do clear = clear and (dy == 0 and m.feet or m.passes)(px, cy + dy, pz, changed) end
						if not clear then break end
						local lx, lz = cx + d[1] * (k + 1), cz + d[2] * (k + 1)
						if m.inside(lx, cy, lz) and not blocked[m.key(lx, lz)] and on_floor(m, lx, cy, lz, changed) then
							push(lx, cy, lz, steps + k)
							break
						end
					end
				end
			end
		end
	end
	return {cells = cells, columns = columns, count = head - 1}
end

-- ---- The map ---------------------------------------------------------------------------
-- `tpl` is template.lua's parse; `opts.open` names nodes read as air (the door open, the
-- ore dug) for the floor a player walks; light and sight see the nodes as written (the
-- door shut), or `opts.view` read as air.
function P.map(tpl, registry, opts)
	opts = opts or {}
	local sx, sy, sz = tpl.size.x, tpl.size.y, tpl.size.z
	local rows, total = sx * sy, sx * sy * sz
	local byid = {}
	for index, name in ipairs(tpl.nodes) do byid[index - 1] = facts(registry(name), name) end
	local m = {tpl = tpl, sx = sx, sy = sy, sz = sz, byid = byid, open = opts.open or {}, view = opts.view or {}}
	local AIR = facts(registry("air"), "air")
	local ROCK = facts({walkable = true, drawtype = "normal", paramtype = "none"}, "outside")
	function m.inside(x, y, z) return x >= 0 and y >= 0 and z >= 0 and x < sx and y < sy and z < sz end
	function m.at(x, y, z) return z * rows + y * sx + x + 1 end
	function m.key(x, z) return z * sx + x end
	function m.name(x, y, z) return tpl.nodes[tpl.cells:byte(m.at(x, y, z)) + 1] end
	function m.param2(x, y, z) return tpl.cells:byte(total + m.at(x, y, z)) end
	-- The cell's facts; outside the box is rock. `changed` (or the map's own open set)
	-- reads named nodes as air.
	function m.node(x, y, z, changed)
		if not m.inside(x, y, z) then return ROCK end
		local f = byid[tpl.cells:byte(m.at(x, y, z))]
		if (changed or m.open)[f.name] then return AIR end
		return f
	end
	function m.class(x, y, z, changed) return m.node(x, y, z, changed).class end
	function m.passes(x, y, z, changed)
		local c = m.class(x, y, z, changed)
		return c == "air" or c == "open" or c == "climb"
	end
	-- A body's feet enter the cell: it passes, or it is a rail lying in it.
	function m.feet(x, y, z, changed)
		return m.passes(x, y, z, changed) or m.class(x, y, z, changed) == "flat"
	end
	-- A player stands in (x, y, z): something to stand on below (or a rail in the cell),
	-- the body's two cells free.
	function m.stands(x, y, z, changed)
		local here = m.class(x, y, z, changed)
		local below = m.class(x, y - 1, z, changed)
		local ground = below == "full" or below == "stair" or below == "prop"
		return (ground and m.passes(x, y, z, changed) or here == "flat" and below == "full")
			and m.passes(x, y + 1, z, changed)
	end
	-- The height map: the floor a player walks to from the arrival (P.floor_walk), each
	-- column's lowest walking cell; `surfaces` holds every walking cell of a column.
	local a = opts.from or {tpl.places.arrival.x, tpl.places.arrival.y, tpl.places.arrival.z}
	local reached = P.floor_walk(m, a[1], a[2], a[3])
	m.h, m.surfaces, m.list = {}, {}, {}
	for z = 0, sz - 1 do
		for x = 0, sx - 1 do
			local key = m.key(x, z)
			local cells = reached.columns[key]
			if cells then
				table.sort(cells)
				m.h[key], m.surfaces[key] = cells[1], cells
				m.list[#m.list + 1] = {x = x, z = z, h = cells[1]}
			end
		end
	end
	-- Heights by x, z (nil: no floor).
	function m.height(x, z)
		if x < 0 or z < 0 or x >= sx or z >= sz then return nil end
		return m.h[m.key(x, z)]
	end
	-- The lowest a foot stands on a cell: a stair's low half, else the node's top.
	function m.surface(x, z)
		local h = m.height(x, z)
		if not h then return nil end
		return m.class(x, h - 1, z) == "stair" and h - 1 or h - 0.5
	end
	-- A walk-round and floor set keyed by z * sx + x, as P.walk_round takes it.
	m.set = {}
	for _, cell in ipairs(m.list) do m.set[m.key(cell.x, cell.z)] = true end
	return m
end

-- Is the point inside a walkable node's selection boxes (a mob's look stops there)?
local function blocks(m, px, py, pz)
	local x, y, z = math.floor(px + 0.5), math.floor(py + 0.5), math.floor(pz + 0.5)
	local f = m.node(x, y, z, m.view)
	if not f.walkable then return false end
	if not f.sel then return true end
	local lx, ly, lz = px - x, py - y, pz - z
	local p = f.facedir and m.inside(x, y, z) and m.param2(x, y, z) % 4 or 0
	-- Turn the point back into the box's frame (the inverse of facedir p).
	for _ = 1, p do lx, lz = -lz, lx end
	for _, b in ipairs(f.sel) do
		if lx > b[1] and lx < b[4] and ly > b[2] and ly < b[5] and lz > b[3] and lz < b[6] then return true end
	end
	return false
end

-- A straight look between two points, sampled every eighth of a node, ends excluded:
-- walkable nodes stop it by their selection boxes (mobs_redo line_of_sight's raycast).
function P.clear(m, x0, y0, z0, x1, y1, z1, skip_end)
	local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
	local steps = math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz) * 8)
	for i = 1, steps - 1 do
		local t = i / steps
		local px, py, pz = x0 + dx * t, y0 + dy * t, z0 + dz * t
		if not (skip_end and math.floor(px + 0.5) == x1 and math.floor(py + 0.5) == y1 and math.floor(pz + 0.5) == z1)
				and blocks(m, px, py, pz) then
			return false
		end
	end
	return true
end

-- A mob at (x0, z0) sees a player at (x1, z1): both at their cell's surface plus their
-- eye (mobs_redo: feet + 1 at both ends), over the relief.
function P.sees(m, x0, z0, x1, z1, eye0, eye1)
	local s0, s1 = m.surface(x0, z0), m.surface(x1, z1)
	if not s0 or not s1 then return false end
	return P.clear(m, x0, s0 + (eye0 or P.MOB_EYE), z0, x1, s1 + (eye1 or P.MOB_EYE), z1)
end

-- ---- The Round 72 searches, on the height map ------------------------------------------

-- Perches: a search over every place a player can stand, from `from` ({x, y, z}), by
-- walking (a stair is a step), a jump of one node up (the pinned engine's jump climbs
-- 1.08 nodes; head room over the take-off), a leap over one or two open columns (one
-- node up over one, level or down over two) and a fall off an edge (never into lava).
-- Generous on purpose: the proof finds more places than a player could reach, never
-- fewer. Returns the places off the height map not on a waystone or the chest, the ropes
-- in reach (a body climbs a rope in its feet or the next cell, the next but one at a
-- jump's top), and the count of places searched.
function P.perches(m, from, changed)
	local seen, queue, head = {}, {}, 1
	local found, ropes = {}, {}
	local function push(x, y, z)
		local index = m.at(x, y, z)
		if not seen[index] then
			seen[index] = true
			queue[#queue + 1] = {x, y, z}
		end
	end
	-- Where a body stepping into (x, z) at y comes to rest, or nil (lava, nothing).
	local function land(x, y, z)
		if not (m.feet(x, y, z, changed) and m.passes(x, y + 1, z, changed)) then return nil end
		while y > 0 do
			if m.stands(x, y, z, changed) then return y end
			if m.class(x, y - 1, z, changed) == "liquid" or m.class(x, y, z, changed) == "liquid" then return nil end
			y = y - 1
		end
		return nil
	end
	push(from[1], from[2], from[3])
	while queue[head] do
		local x, y, z = queue[head][1], queue[head][2], queue[head][3]
		head = head + 1
		local below = m.name(x, y - 1, z)
		if y ~= m.height(x, z) and not (changed and changed[below]) and not m.open[below] and not P.ALLOWED[below] then
			found[#found + 1] = ("%d,%d,%d on %s"):format(x, y, z, below)
		end
		for dy = 0, 2 do
			if m.class(x, y + dy, z, changed) == "climb" then
				ropes[#ropes + 1] = ("%d,%d,%d"):format(x, y + dy, z)
			end
		end
		local head_room = m.passes(x, y + 2, z, changed)
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local nx, nz = x + d[1], z + d[2]
			if m.inside(nx, y, nz) then
				local to = land(nx, y, nz)
				if to then push(nx, to, nz) end
				if (head_room or m.class(nx, y, nz, changed) == "stair") and m.inside(nx, y + 1, nz)
						and m.stands(nx, y + 1, nz, changed) then
					push(nx, y + 1, nz)
				end
				-- A leap: the columns crossed open from y to y + 2.
				if head_room then
					for k = 1, 2 do
						local cx, cz = x + d[1] * k, z + d[2] * k
						local clear = m.inside(cx, y, cz)
						for dy = 0, 2 do clear = clear and (dy == 0 and m.feet or m.passes)(cx, y + dy, cz, changed) end
						if not clear then break end
						local lx, lz = x + d[1] * (k + 1), z + d[2] * (k + 1)
						if k == 1 and m.inside(lx, y + 1, lz) and m.stands(lx, y + 1, lz, changed) then
							push(lx, y + 1, lz)
						end
						if m.inside(lx, y, lz) then
							local to2 = land(lx, y, lz)
							if to2 then push(lx, to2, lz) end
						end
					end
				end
			end
		end
	end
	return found, ropes, head - 1
end

-- The mobs of `spots` that notice a player at (x, z): within view range less `margin`
-- and in sight. Returns the best spare range or nil. A spot is {x, z, view, eye?}.
function P.noticed(m, spots, x, z, margin)
	local best
	for _, spot in ipairs(spots) do
		local d = math.sqrt((spot.x - x) ^ 2 + (spot.z - z) ^ 2)
		if d <= spot.view - margin and P.sees(m, spot.x, spot.z, x, z, spot.eye) then
			local spare = spot.view - d
			if not best or spare > best then best = spare end
		end
	end
	return best
end

-- Coverage: every floor cell `in_room` holds is noticed by `spots` with `margin` to
-- spare. Returns the cells, the thinnest spare range and the cells nobody notices.
function P.coverage(m, in_room, spots, margin)
	local cells, thinnest, missed = 0, math.huge, {}
	for _, cell in ipairs(m.list) do
		if in_room(cell.x, cell.z) then
			cells = cells + 1
			local spare = P.noticed(m, spots, cell.x, cell.z, margin)
			if spare then
				thinnest = math.min(thinnest, spare)
			else
				missed[#missed + 1] = cell.x .. "," .. cell.z
			end
		end
	end
	return cells, thinnest, missed
end

-- One step of a walk on the height map: a neighbour with a floor within one node.
local function step_ok(m, set, x, z, nx, nz)
	local h, nh = m.height(x, z), m.height(nx, nz)
	return nh and set[m.key(nx, nz)] and math.abs(nh - h) <= 1
end

-- Walking round: a walk over the floor (`set`, keyed z * sx + x) from `from` ({x, z})
-- that never enters a cell `spots` notice (with `margin` to spare). The floor is the only
-- walking surface (the perches prove it). `from` must be a floor cell nobody notices; a
-- target the pack notices is no way round and drops out. Returns the first target
-- reached or nil, the targets kept and the cells noticed.
function P.walk_round(m, set, from, targets, spots, margin)
	local sx = m.sx
	local noticed, count = {}, 0
	for key in pairs(set) do
		if P.noticed(m, spots, key % sx, math.floor(key / sx), margin) then
			noticed[key] = true
			count = count + 1
		end
	end
	local function key(p) return p[2] * sx + p[1] end
	assert(set[key(from)] and not noticed[key(from)],
		("walk_round: the entrance %d,%d is a floor cell nobody notices"):format(from[1], from[2]))
	local want, kept = {}, 0
	for _, t in ipairs(targets) do
		if set[key(t)] and not noticed[key(t)] then
			want[key(t)] = t
			kept = kept + 1
		end
	end
	local seen, queue, head = {[key(from)] = true}, {from}, 1
	while queue[head] do
		local c = queue[head]
		head = head + 1
		if want[key(c)] then return want[key(c)], kept, count end
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local n = {c[1] + d[1], c[2] + d[2]}
			local k = key(n)
			if n[1] >= 0 and n[1] < sx and not noticed[k] and not seen[k] and step_ok(m, set, c[1], c[2], n[1], n[2]) then
				seen[k] = true
				queue[#queue + 1] = n
			end
		end
	end
	return nil, kept, count
end

-- The floor cells within `reach` of a node at (x, z) a player digs from (the hand's and
-- every tool's range, 4 nodes): an ore's targets.
function P.within_reach(m, x, z, reach)
	local list = {}
	for dz = -reach, reach do
		for dx = -reach, reach do
			if dx * dx + dz * dz <= reach * reach and m.set[(z + dz) * m.sx + x + dx] then
				list[#list + 1] = {x + dx, z + dz}
			end
		end
	end
	return list
end

-- The walk over the floor from (x, y, z) in another state (`changed`: names read as
-- air; {} reads every node as written): {[key] = true} of the columns reached.
function P.walk(m, x, y, z, changed)
	local seen = {}
	for key in pairs(P.floor_walk(m, x, y, z, changed).columns) do seen[key] = true end
	return seen
end

-- ---- Light ------------------------------------------------------------------------------
-- The engine's rule: a source's light (light_source, at most 14) loses one per node into
-- every node that lets light through (paramtype "light": air, torches, stairs, tables,
-- lava), never into one that does not (c_content.cpp: light_propagates). Returns
-- light[index], index m.at(x, y, z), and the list of source cells.
function P.light(m)
	local light, buckets, sources = {}, {}, {}
	local function raise(index, x, y, z, value)
		if value > (light[index] or 0) then
			light[index] = value
			buckets[value] = buckets[value] or {}
			table.insert(buckets[value], {x, y, z})
		end
	end
	for z = 0, m.sz - 1 do
		for y = 0, m.sy - 1 do
			for x = 0, m.sx - 1 do
				local level = m.node(x, y, z, m.view).light
				if level > 0 then
					raise(m.at(x, y, z), x, y, z, level)
					sources[#sources + 1] = {x = x, y = y, z = z}
				end
			end
		end
	end
	for value = 14, 2, -1 do
		for _, c in ipairs(buckets[value] or {}) do
			for _, d in ipairs({{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}}) do
				local x, y, z = c[1] + d[1], c[2] + d[2], c[3] + d[3]
				if m.inside(x, y, z) and m.node(x, y, z, m.view).propagates then raise(m.at(x, y, z), x, y, z, value - 1) end
			end
		end
	end
	return light, sources
end

-- ---- The proof --------------------------------------------------------------------------
-- `spec`:
--   name        the template's name, for the lines
--   arrival     {x, y, z}; default the arrival place
--   tallest     the tallest mob's height in nodes (head_room needs it plus one)
--   packs       {[key] = {spots = {{x, z, view, eye?}...}, room = function(x, z),
--                 ways = {{in}, {on}, {ore}?}, cover = false?}}: `room` is fighting floor
--               (the light zone, no ambush in it, before every ambush); coverage over it
--               unless `cover` is false (a boss behind the door); (when `ways`) no walk
--               round from in to on or to the ore's reach
--   bright      optional function(x, z): more cells that need light 6 (a store)
--   props       optional set of more furniture names
--   mouths      list of {x, z}: passage mouths no lava basin may lie at; required (may be
--               empty) once lava lies beside the floor
--   margin      the spare range coverage asks for (default 1)
--   sizes       optional {[mob] = {width, height}} in nodes at the marker's tier: an ambush
--               alcove fits it with a node of head room (default 1 wide, `tallest` high)
--   ranged      optional set of mob names that shoot (default P.RANGED)
--   ambushes    optional count of ambush candidates the template must have
--   report      a set of rule ids reported only (P.NEW for a Round 72 template)
function P.prove(m, spec)
	local report = {name = spec.name or m.tpl.name, rules = {}, order = P.RULES}
	local function rule(id)
		report.rules[id] = report.rules[id] or {problems = {}, notes = {}}
		return report.rules[id]
	end
	local function problem(id, text) table.insert(rule(id).problems, text) end
	local function note(id, text) table.insert(rule(id).notes, text) end
	for _, id in ipairs(P.RULES) do rule(id) end
	local places = m.tpl.places
	local arrival = spec.arrival or {places.arrival.x, places.arrival.y, places.arrival.z}

	-- 1. One surface per column; the hull.
	local doubled = 0
	for _, cell in ipairs(m.list) do
		local s = m.surfaces[m.key(cell.x, cell.z)]
		if #s > 1 then
			doubled = doubled + 1
			if doubled <= 8 then problem("surface", ("two surfaces at %d,%d: y %s"):format(cell.x, cell.z, table.concat(s, ", "))) end
		end
	end
	if doubled > 8 then problem("surface", ("... %d columns with two surfaces"):format(doubled)) end
	local digs, hull = m.tpl.dig or {}, nil
	for z = 0, m.sz - 1 do
		for y = 0, m.sy - 1 do
			for x = 0, m.sx - 1 do
				if not hull and (x == 0 or y == 0 or z == 0 or x == m.sx - 1 or y == m.sy - 1 or z == m.sz - 1) then
					local f = m.node(x, y, z, {})
					if not f.walkable or digs[f.name] then hull = ("%d,%d,%d"):format(x, y, z) end
				end
			end
		end
	end
	if hull then problem("surface", "the hull is open at " .. hull) end
	note("surface", ("%d walking columns"):format(#m.list))

	-- 1. Relief: neighbours within one, the right stair at every change, no ridge.
	local stairs, steps = 0, 0
	for _, cell in ipairs(m.list) do
		local x, z, h = cell.x, cell.z, cell.h
		local mask = 15
		for _, q in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
			for _, d in ipairs({{q[1], 0}, {0, q[2]}, {q[1], q[2]}}) do
				local nh = m.height(x + d[1], z + d[2])
				if nh and nh < h then
					mask = mask - corner_bit(q[1], q[2])
					break
				end
			end
		end
		for dz = -1, 1 do
			for dx = -1, 1 do
				local nh = m.height(x + dx, z + dz)
				if nh and math.abs(nh - h) > 1 then
					problem("relief", ("%d,%d at %d beside %d,%d at %d: more than one node"):format(x, z, h, x + dx, z + dz, nh))
				end
			end
		end
		for _, d in ipairs({{1, 0}, {0, 1}}) do
			local a, b = m.height(x - d[1], z - d[2]), m.height(x + d[1], z + d[2])
			if a and b and ((a < h and b < h) or (a > h and b > h)) then
				problem("relief", ("%d,%d: a %s one node wide along %s"):format(x, z, a < h and "ridge" or "trench",
					d[1] == 1 and "x" or "z"))
			end
		end
		local f = m.node(x, h - 1, z)
		if mask == 15 then
			if f.class == "stair" then problem("relief", ("%d,%d: a stair with no lower side"):format(x, z)) end
		else
			steps = steps + 1
			local shape, p = P.stair_for(mask)
			if not shape then
				problem("relief", ("%d,%d: no stair fits its lower sides (a peak or a diagonal ridge)"):format(x, z))
			elseif f.class ~= "stair" then
				problem("relief", ("%d,%d at %d: a step of %s, no stair"):format(x, z, h, f.name))
			elseif f.stair ~= shape or m.param2(x, h - 1, z) % 32 ~= p then
				problem("relief", ("%d,%d: %s param2 %d, wants a %s stair param2 %d"):format(x, z, f.name,
					m.param2(x, h - 1, z), shape, p))
			else
				stairs = stairs + 1
			end
		end
	end
	note("relief", ("%d steps, %d stairs right"):format(steps, stairs))

	-- 2. Free height from the local floor: air from the walking cell up (in the feet row
	-- anything a body passes: a carpet, moss, bones).
	local need = spec.tallest and math.ceil(spec.tallest + 1) or P.FREE_HEIGHT
	local lowest, low_at, short3, shortm = math.huge, "-", 0, 0
	for _, cell in ipairs(m.list) do
		local n = 0
		while true do
			local c = m.class(cell.x, cell.h + n, cell.z)
			if not (c == "air" or (n == 0 and (c == "flat" or c == "open"))) then break end
			n = n + 1
		end
		if n < lowest then lowest, low_at = n, cell.x .. "," .. cell.z end
		if n < P.FREE_HEIGHT then
			short3 = short3 + 1
			if short3 <= 8 then problem("free_height", ("%d,%d: %d nodes of air"):format(cell.x, cell.z, n)) end
		end
		if n < need then
			shortm = shortm + 1
			if shortm <= 8 then problem("head_room", ("%d,%d: %d nodes of air, %d wanted"):format(cell.x, cell.z, n, need)) end
		end
	end
	if short3 > 8 then problem("free_height", ("... %d cells below %d"):format(short3, P.FREE_HEIGHT)) end
	if shortm > 8 then problem("head_room", ("... %d cells below %d"):format(shortm, need)) end
	note("free_height", ("the lowest %d at %s"):format(lowest, low_at))
	note("head_room", ("%d nodes wanted (the tallest mob %s)"):format(need, tostring(spec.tallest)))

	-- 3. No perch: with the map's state (door open, ore dug) and with everything shut.
	for _, changed in ipairs({false, {}}) do
		local found, ropes, searched = P.perches(m, arrival, changed or nil)
		for i, line in ipairs(found) do if i <= 8 then problem("perches", "perch: " .. line) end end
		for i, line in ipairs(ropes) do if i <= 8 then problem("perches", "rope in reach: " .. line) end end
		note("perches", ("%d places searched%s"):format(searched, changed and ", all shut" or ""))
	end

	-- 4. Dressing: what stands on a walking cell, and what may never be written.
	local furniture = setmetatable({}, {__index = function(_, k) return P.FURNITURE[k] or (spec.props or {})[k] end})
	for _, f in pairs(m.byid) do
		if f.harvest then problem("dressing", "a gathering source or crop in the palette: " .. f.name) end
	end
	local floors = {}
	for _, cell in ipairs(m.list) do floors[m.key(cell.x, cell.z)] = cell.h end
	for _, cell in ipairs(m.list) do
		for dy = 0, 1 do
			local f = m.node(cell.x, cell.h + dy, cell.z)
			if f.cobweb then problem("dressing", ("a cobweb on the walking cell %d,%d,%d"):format(cell.x, cell.h + dy, cell.z)) end
			-- A walkable decoration lying flat on the floor: only the rails of the mine.
			if f.class == "flat" and not P.FLAT_OK[f.name] then
				problem("dressing", ("walkable %s on the walking cell %d,%d,%d"):format(f.name, cell.x, cell.h + dy, cell.z))
			end
		end
	end
	-- A walkable node in a body row of the floor beside it, on a whole node: furniture only.
	for z = 1, m.sz - 2 do
		for x = 1, m.sx - 2 do
			if not floors[m.key(x, z)] then
				for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
					local nh = floors[m.key(x + d[1], z + d[2])]
					if nh then
						local f = m.node(x, nh, z)
						if (f.class == "prop" or f.class == "flat") and not furniture[f.name]
								and m.class(x, nh - 1, z) ~= "air" then
							problem("dressing", ("walkable %s on the floor at %d,%d,%d"):format(f.name, x, nh, z))
						end
						break
					end
				end
			end
		end
	end

	-- 5. The route over the height map: from the arrival every marker and place; with
	-- everything shut, neither the chest nor the end waystone.
	local function reached(seen, p)
		for dz = -1, 1 do
			for dx = -1, 1 do
				if seen[m.key(p.x + dx, p.z + dz)] then return true end
			end
		end
		return false
	end
	local open_walk = m.set
	local targets = {}
	for _, row in ipairs(m.tpl.encounters) do targets[#targets + 1] = {row.room .. " " .. row.mob, row.pos} end
	for name, pos in pairs(places) do
		if not name:match("^boss_room_") then targets[#targets + 1] = {"place " .. name, pos} end
	end
	for _, t in ipairs(targets) do
		if not reached(open_walk, t[2]) then problem("route", t[1] .. " is not reached over the floor") end
	end
	local shut_walk = P.walk(m, arrival[1], arrival[2], arrival[3], {})
	for _, name in ipairs({"chest", "end_waystone"}) do
		if places[name] and reached(shut_walk, places[name]) then
			problem("route", name .. " is reached with the door shut")
		end
	end
	note("route", ("%d walking columns"):format(#m.list))

	-- 6. Packs: coverage and no walk round.
	local margin = spec.margin or 1
	local keys = {}
	for key in pairs(spec.packs or {}) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local pack = spec.packs[key]
		if pack.room and pack.cover ~= false then
			local cells, thinnest, missed = P.coverage(m, pack.room, pack.spots, margin)
			for i, at in ipairs(missed) do if i <= 8 then problem("packs", ("unseen in %s: %s"):format(key, at)) end end
			if #missed > 8 then problem("packs", ("... %d cells unseen in %s"):format(#missed, key)) end
			note("packs", ("%s: %d cells, the thinnest spare %.1f"):format(key, cells, thinnest))
		end
		if pack.ways then
			local way = pack.ways
			if not (m.set[m.key(way[2][1], way[2][2])] and not P.noticed(m, pack.spots, way[2][1], way[2][2], margin)) then
				problem("packs", key .. "'s way on is no floor nobody notices")
			else
				local list = {way[2]}
				if way[3] then
					for _, t in ipairs(P.within_reach(m, way[3][1], way[3][2], 4)) do list[#list + 1] = t end
				end
				local got, kept, noticed = P.walk_round(m, m.set, way[1], list, pack.spots, margin)
				if got then problem("packs", ("%s walked round to %d,%d"):format(key, got[1], got[2])) end
				if not P.walk_round(m, m.set, way[1], {way[2]}, {}, margin) then
					problem("packs", key .. "'s way on is not reached with the pack gone")
				end
				note("packs", ("%s: no way round its %d noticed cells to %d of %d targets"):format(key, noticed, kept, #list))
			end
		end
	end

	-- 7. Light zones and the line of sight.
	local light, sources = P.light(m)
	report.light, report.sources = light, sources
	-- The light at eye height (floor plus one); nil inside a node as written (the shut door).
	local function eye_light(cell)
		if not m.node(cell.x, cell.h + 1, cell.z, m.view).propagates then return nil end
		return light[m.at(cell.x, cell.h + 1, cell.z)] or 0
	end
	local fight = {}
	for _, key in ipairs(keys) do
		local room = spec.packs[key].room
		if room then
			for _, cell in ipairs(m.list) do
				if room(cell.x, cell.z) then fight[m.key(cell.x, cell.z)] = cell end
			end
		end
	end
	for _, row in ipairs(m.tpl.traps or {}) do
		local cx, cz = row.pos.x, row.pos.z
		local line = {{cx, cz}}
		if row.kind == "wall" then
			local axis = ({["+x"] = {1, 0}, ["-x"] = {-1, 0}, ["+z"] = {0, 1}, ["-z"] = {0, -1}})[row.axis]
			local y = math.floor(row.pos.y + 0.5)
			for k = 1, 64 do
				local px, pz = math.floor(cx + axis[1] * k + 0.5), math.floor(cz + axis[2] * k + 0.5)
				if not m.inside(px, y, pz) or m.node(px, y, pz).walkable then break end
				line[#line + 1] = {px, pz}
			end
		end
		for _, cell in ipairs(m.list) do
			for _, p in ipairs(line) do
				if (cell.x - p[1]) ^ 2 + (cell.z - p[2]) ^ 2 <= P.TRAP_RADIUS ^ 2 then
					fight[m.key(cell.x, cell.z)] = cell
					break
				end
			end
		end
	end
	local zone, usual, darkest, dark_at = 0, 0, 99, "-"
	for _, cell in pairs(fight) do
		local v = eye_light(cell) or 99
		zone = zone + 1
		if v >= P.LIGHT_USUAL then usual = usual + 1 end
		if v < darkest then darkest, dark_at = v, cell.x .. "," .. cell.z end
	end
	if zone > 0 then
		if darkest < P.LIGHT_MIN then problem("light", ("fighting floor at light %d at %s"):format(darkest, dark_at)) end
		if usual / zone < P.USUAL_SHARE then
			problem("light", ("fighting floor: %.0f %% at %d or more"):format(100 * usual / zone, P.LIGHT_USUAL))
		end
		note("light", ("fighting floor %d cells, darkest %d, %.0f %% at %d or more"):format(zone, darkest,
			100 * usual / zone, P.LIGHT_USUAL))
	end
	local bright_dark = 0
	for _, cell in ipairs(m.list) do
		local near = spec.bright and spec.bright(cell.x, cell.z)
		for _, name in ipairs({"arrival", "start_waystone", "end_waystone", "chest", "door"}) do
			local p = places[name]
			if p and (cell.x - p.x) ^ 2 + (cell.z - p.z) ^ 2 <= P.BRIGHT_REACH ^ 2 then near = true end
		end
		if near and (eye_light(cell) or 99) < P.BRIGHT then
			bright_dark = bright_dark + 1
			if bright_dark <= 8 then
				problem("light", ("%d,%d by a service place at light %d"):format(cell.x, cell.z, eye_light(cell)))
			end
		end
	end
	-- An ambush's alcoves (the floor within two nodes of its markers) are dark recesses
	-- off the passage: an alcove cell with no light in sight passes when a walk of two
	-- steps or less reaches a cell that sees one (or stands at light 4 or more).
	local alcove = {}
	for _, row in ipairs(m.tpl.ambushes or {}) do
		for _, enc in ipairs(m.tpl.encounters) do
			if enc.room == row.room then
				for dz = -2, 2 do
					for dx = -2, 2 do alcove[m.key(enc.pos.x + dx, enc.pos.z + dz)] = true end
				end
			end
		end
		for z = row.min.z, row.max.z do
			for x = row.min.x, row.max.x do alcove[m.key(x, z)] = nil end
		end
	end
	local sees_light = {}
	local function sight_of(cell)
		local key = m.key(cell.x, cell.z)
		if sees_light[key] == nil then
			local v = eye_light(cell) or 99
			local seen = v >= P.LIGHT_MIN
			if not seen then
				local s0 = m.surface(cell.x, cell.z) + P.PLAYER_EYE
				for _, src in ipairs(sources) do
					local d2 = (src.x - cell.x) ^ 2 + (src.y - s0) ^ 2 + (src.z - cell.z) ^ 2
					if d2 <= P.SIGHT_REACH ^ 2 and P.clear(m, cell.x, s0, cell.z, src.x, src.y, src.z, true) then
						seen = true
						break
					end
				end
			end
			sees_light[key] = seen
		end
		return sees_light[key]
	end
	local function near_sight(cell)
		local seen, frontier = {[m.key(cell.x, cell.z)] = true}, {{cell.x, cell.z}}
		for _ = 1, 2 do
			local next_frontier = {}
			for _, c in ipairs(frontier) do
				for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
					local nx, nz = c[1] + d[1], c[2] + d[2]
					local k = m.key(nx, nz)
					if not seen[k] and step_ok(m, m.set, c[1], c[2], nx, nz) then
						seen[k] = true
						if sight_of({x = nx, z = nz, h = m.height(nx, nz)}) then return true end
						next_frontier[#next_frontier + 1] = {nx, nz}
					end
				end
			end
			frontier = next_frontier
		end
		return false
	end
	local all, sum, below = 0, 0, 0
	for _, cell in ipairs(m.list) do
		local v = eye_light(cell) or 99
		if v < 99 then all, sum = all + 1, sum + v end
		if v < P.LIGHT_MIN then
			below = below + 1
			if not sight_of(cell) and not (alcove[m.key(cell.x, cell.z)] and near_sight(cell)) then
				problem("sight", ("%d,%d at light %d: no light in sight"):format(cell.x, cell.z, v))
			end
		end
	end
	if all > 0 then
		note("light", ("all floor: mean %.1f, %d cells below %d"):format(sum / all, below, P.LIGHT_MIN))
		note("sight", ("%d cells below light %d, %d sources"):format(below, P.LIGHT_MIN, #sources))
	end

	-- 8. The ambush (concept section 4.5): the zone flat, at light 0 with its alcoves and a
	-- margin, cutting the floor in two; alcoves joined to the floor at its height and
	-- fitting their mobs; markers normal and melee; out of every room pack's notice, out
	-- of sight of the start waystone; no Round 72 trap in its dark stretch, no pack room.
	local ambushes = m.tpl.ambushes or {}
	local dark_stretch = {}
	if spec.ambushes and #ambushes ~= spec.ambushes then
		problem("ambush", ("%d ambush candidates, %d wanted"):format(#ambushes, spec.ambushes))
	end
	local ranged = spec.ranged or P.RANGED
	local end_place = places.end_waystone or places.chest
	-- Never the first fight (user, 2026-11-10): with every pack room's fighting floor
	-- taken out, no zone cell is reached from the arrival.
	local fights = {}
	for _, key in ipairs(keys) do
		local room = spec.packs[key].room
		if room then
			for _, cell in ipairs(m.list) do
				if room(cell.x, cell.z) then fights[m.key(cell.x, cell.z)] = true end
			end
		end
	end
	local before_fight = #ambushes > 0 and P.floor_walk(m, arrival[1], arrival[2], arrival[3], nil, fights).columns or {}
	for _, row in ipairs(ambushes) do
		local tag = "ambush " .. row.group .. " (" .. row.room .. ")"
		local y = row.min.y
		local zone = {}
		for z = row.min.z, row.max.z do
			for x = row.min.x, row.max.x do
				zone[m.key(x, z)] = true
				if m.height(x, z) ~= y then
					problem("ambush", ("%s: %d,%d is no floor at %d (%s)"):format(tag, x, z, y, tostring(m.height(x, z))))
				end
				for dz = -1, 1 do
					for dx = -1, 1 do
						local nh = m.height(x + dx, z + dz)
						if nh and (nh ~= y or m.class(x + dx, y - 1, z + dz) == "stair") then
							problem("ambush", ("%s: not flat at %d,%d"):format(tag, x + dx, z + dz))
						end
					end
				end
			end
		end
		-- It cuts the floor: without its columns (no leap over them) the end is not reached.
		local function reaches(blocked)
			local cols = P.floor_walk(m, arrival[1], arrival[2], arrival[3], nil, blocked).columns
			for dz = -1, 1 do
				for dx = -1, 1 do
					if cols[m.key(end_place.x + dx, end_place.z + dz)] then return true end
				end
			end
			return false
		end
		local first = false
		for key in pairs(zone) do first = first or before_fight[key] ~= nil end
		if first then problem("ambush", tag .. ": reached from the arrival without a pack room (the first fight)") end
		if not reaches({}) then
			problem("ambush", tag .. ": the end is not reached even with the zone")
		elseif reaches(zone) then
			problem("ambush", tag .. ": a walk from the start to the end goes round the zone")
		end
		-- The markers: in alcoves joined to the floor at the zone's height, fitting.
		local markers = {}
		for _, enc in ipairs(m.tpl.encounters) do
			if enc.room == row.room then
				markers[#markers + 1] = enc
				local p = enc.pos
				if enc.tier ~= "normal" then problem("ambush", ("%s: %s is %s"):format(tag, enc.mob, enc.tier)) end
				if ranged[enc.mob] then problem("ambush", ("%s: %s shoots"):format(tag, enc.mob)) end
				local size = (spec.sizes or {})[enc.mob] or {1, spec.tallest or 2}
				local half = math.ceil(size[1] / 2 - 0.5)
				local need = math.ceil(size[2] + 1)
				for dz = -half, half do
					for dx = -half, half do
						local cx, cz = p.x + dx, p.z + dz
						if m.height(cx, cz) ~= y then
							problem("ambush", ("%s: %s at %d,%d has no floor at %d at %d,%d"):format(tag, enc.mob,
								p.x, p.z, y, cx, cz))
						else
							local n = 0
							while m.passes(cx, y + n, cz) and n < need do n = n + 1 end
							if n < need then
								problem("ambush", ("%s: %s at %d,%d: %d nodes of head room, %d wanted"):format(tag,
									enc.mob, p.x, p.z, n, need))
							end
						end
					end
				end
				-- Out of every room pack's notice.
				for _, key in ipairs(keys) do
					if P.noticed(m, spec.packs[key].spots, p.x, p.z, 0) then
						problem("ambush", ("%s: its marker at %d,%d is noticed by %s"):format(tag, p.x, p.z, key))
					end
				end
			end
		end
		-- Light 0 over the zone, its markers and a margin round the zone.
		local dark = {}
		for z = row.min.z - P.AMBUSH_MARGIN, row.max.z + P.AMBUSH_MARGIN do
			for x = row.min.x - P.AMBUSH_MARGIN, row.max.x + P.AMBUSH_MARGIN do
				if m.height(x, z) then dark[#dark + 1] = {x, z} end
			end
		end
		for _, enc in ipairs(markers) do dark[#dark + 1] = {enc.pos.x, enc.pos.z} end
		for _, c in ipairs(dark) do
			local h = m.height(c[1], c[2])
			local v = h and light[m.at(c[1], h + 1, c[2])] or 0
			if h and v > 0 then
				problem("ambush", ("%s: light %d at %d,%d"):format(tag, v, c[1], c[2]))
			end
		end
		-- The zone: out of every pack's notice and room.
		for z = row.min.z, row.max.z do
			for x = row.min.x, row.max.x do
				for _, key in ipairs(keys) do
					local pack = spec.packs[key]
					if pack.room and pack.room(x, z) then
						problem("ambush", ("%s: %d,%d lies in %s's room"):format(tag, x, z, key))
					end
					if P.noticed(m, pack.spots, x, z, 0) then
						problem("ambush", ("%s: %d,%d is noticed by %s"):format(tag, x, z, key))
					end
				end
			end
		end
		-- Out of sight of the respawn place (runs.lua start_arrival: the `arrival` cell): a
		-- player's eye there sees no zone cell and no marker.
		local seen_from = {}
		for z = row.min.z, row.max.z do
			for x = row.min.x, row.max.x do seen_from[#seen_from + 1] = {x, z, "the zone"} end
		end
		for _, enc in ipairs(markers) do seen_from[#seen_from + 1] = {enc.pos.x, enc.pos.z, enc.mob} end
		local a0 = m.surface(arrival[1], arrival[3])
		for _, c in ipairs(seen_from) do
			local s1 = m.surface(c[1], c[2])
			if a0 and s1 and P.clear(m, arrival[1], a0 + P.PLAYER_EYE, arrival[3], c[1], s1 + 1, c[2]) then
				problem("ambush", ("%s: %s at %d,%d in sight of the respawn place"):format(tag, c[3], c[1], c[2]))
			end
		end
		-- Its dark stretch: the floor below light 4 joined to the zone.
		local queue, head = {}, 1
		for key in pairs(zone) do
			if m.set[key] then queue[#queue + 1] = key; dark_stretch[key] = true end
		end
		while queue[head] do
			local key = queue[head]
			head = head + 1
			local x, z = key % m.sx, math.floor(key / m.sx)
			for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local nx, nz = x + d[1], z + d[2]
				local nk = m.key(nx, nz)
				local h = m.height(nx, nz)
				if h and not dark_stretch[nk] and (light[m.at(nx, h + 1, nz)] or 0) < P.LIGHT_MIN then
					dark_stretch[nk] = true
					queue[#queue + 1] = nk
				end
			end
		end
		for _, trap in ipairs(m.tpl.traps or {}) do
			local tx, tz = math.floor(trap.pos.x + 0.5), math.floor(trap.pos.z + 0.5)
			for dz = -P.TRAP_RADIUS, P.TRAP_RADIUS do
				for dx = -P.TRAP_RADIUS, P.TRAP_RADIUS do
					if dark_stretch[m.key(tx + dx, tz + dz)] then
						problem("ambush", ("%s: trap %s in its dark stretch"):format(tag, trap.group))
					end
				end
			end
		end
		note("ambush", ("%s: %d markers"):format(tag, #markers))
	end

	-- 9. Lava: closed, and no basin at a stair's foot or a passage mouth.
	local lava_cells, foot, beside = 0, {}, 0
	for _, cell in ipairs(m.list) do
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local nh = m.height(cell.x + d[1], cell.z + d[2])
			if nh == cell.h + 1 and m.class(cell.x + d[1], nh - 1, cell.z + d[2]) == "stair" then
				foot[#foot + 1] = {cell.x, cell.z, "a stair's foot"}
				break
			end
		end
	end
	for _, p in ipairs(spec.mouths or {}) do foot[#foot + 1] = {p[1], p[2], "a passage mouth"} end
	for z = 0, m.sz - 1 do
		for y = 0, m.sy - 1 do
			for x = 0, m.sx - 1 do
				local f = m.node(x, y, z)
				if f.lava then
					lava_cells = lava_cells + 1
					local falling = f.name:match("flowing") and math.floor(m.param2(x, y, z) / 8) % 2 == 1
					local below = m.node(x, y - 1, z)
					if not (below.lava or below.walkable) then
						problem("lava", ("lava at %d,%d,%d over %s"):format(x, y, z, below.name))
					end
					if not falling then
						for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
							local n = m.node(x + d[1], y, z + d[2])
							if not (n.lava or n.walkable) then
								problem("lava", ("lava at %d,%d,%d open to %d,%d,%d"):format(x, y, z, x + d[1], y, z + d[2]))
							end
						end
					end
					if dark_stretch[m.key(x, z)] or dark_stretch[m.key(x + 1, z)] or dark_stretch[m.key(x - 1, z)]
							or dark_stretch[m.key(x, z + 1)] or dark_stretch[m.key(x, z - 1)] then
						problem("lava", ("lava at %d,%d,%d in an ambush's dark stretch"):format(x, y, z))
					end
					-- Beside the floor: a basin or a fall within three nodes below a walking cell.
					for dz = -1, 1 do
						for dx = -1, 1 do
							local nh = m.height(x + dx, z + dz)
							if nh and y >= nh - 3 and y <= nh + 2 then
								beside = beside + 1
								for _, p in ipairs(foot) do
									if math.max(math.abs(p[1] - x), math.abs(p[2] - z)) <= P.MOUTH_CLEAR then
										problem("lava", ("lava at %d,%d,%d by %s at %d,%d"):format(x, y, z, p[3], p[1], p[2]))
									end
								end
							end
						end
					end
				end
			end
		end
	end
	for _, cell in ipairs(m.list) do
		for dy = 0, 1 do
			if m.node(cell.x, cell.h + dy, cell.z).lava then problem("lava", ("lava on the walking cell %d,%d"):format(cell.x, cell.z)) end
		end
	end
	-- The passage-mouth check needs the mouths: a fall beside the floor with none given
	-- would pass it unasked.
	if beside > 0 and not spec.mouths then
		problem("lava", "lava beside the floor, but no passage mouths given (spec.mouths)")
	end
	note("lava", ("%d lava cells"):format(lava_cells))

	-- 10. Traps on the local floor.
	for _, row in ipairs(m.tpl.traps or {}) do
		local p = row.pos
		if row.kind == "floor" then
			local h = m.height(p.x, p.z)
			if h ~= p.y then
				problem("traps", ("floor trap %s at %d,%d,%d: the floor is at %s"):format(row.group, p.x, p.y, p.z, tostring(h)))
			else
				for dz = -1, 1 do
					for dx = -1, 1 do
						local nh = m.height(p.x + dx, p.z + dz)
						if nh and (nh ~= h or m.class(p.x + dx, h - 1, p.z + dz) == "stair") then
							problem("traps", ("floor trap %s at %d,%d: not on flat floor at %d,%d"):format(row.group,
								p.x, p.z, p.x + dx, p.z + dz))
						end
					end
				end
			end
		else
			local axis = ({["+x"] = {1, 0}, ["-x"] = {-1, 0}, ["+z"] = {0, 1}, ["-z"] = {0, -1}})[row.axis]
			local function rows(v) return {math.floor(v - P.BALL + 0.5), math.floor(v + P.BALL + 0.5)} end
			for k = 0, 1 do
				for _, cy in ipairs(rows(p.y)) do
					for _, side in ipairs(axis[1] ~= 0 and rows(p.z) or rows(p.x)) do
						local cx = axis[1] ~= 0 and math.floor(p.x + 0.5) + axis[1] * k or side
						local cz = axis[1] ~= 0 and side or math.floor(p.z + 0.5) + axis[2] * k
						if m.node(cx, cy, cz).walkable then
							problem("traps", ("wall trap %s at %g,%g,%g: the muzzle is not open"):format(row.group, p.x, p.y, p.z))
						end
					end
				end
			end
			-- The local floor: the first walking cell along the line.
			for k = 0, 32 do
				local cx, cz = math.floor(p.x + axis[1] * k + 0.5), math.floor(p.z + axis[2] * k + 0.5)
				local h = m.height(cx, cz)
				if h then
					local over = p.y - (h - 0.5)
					if over < 0.5 or over > 1.8 then
						problem("traps", ("wall trap %s at %g,%g,%g: %.1f over the floor at %d,%d"):format(row.group,
							p.x, p.y, p.z, over, cx, cz))
					end
					break
				end
			end
		end
	end
	note("traps", ("%d trap lines"):format(#(m.tpl.traps or {})))

	-- 11. Particles: the live total within the web budget, each box in the open.
	local total = 0
	for _, row in ipairs(m.tpl.particles or {}) do
		total = total + row.amount
		local open = false
		for z = row.min.z, row.max.z do
			for y = row.min.y, row.max.y do
				for x = row.min.x, row.max.x do
					open = open or m.node(x, y, z, m.view).name == "air"
				end
			end
		end
		if not open then
			problem("particles", ("%s at %d,%d,%d: no air in its box"):format(row.style, row.min.x, row.min.y, row.min.z))
		end
	end
	if total > (spec.particle_budget or P.PARTICLE_BUDGET) then
		problem("particles", ("%d live particles, over the budget of %d"):format(total, spec.particle_budget or P.PARTICLE_BUDGET))
	end
	note("particles", ("%d boxes, %d live particles at most"):format(#(m.tpl.particles or {}), total))
	return report
end

-- Prints every rule's result, then fails (through `check`) each rule with problems that
-- `report_only` does not name. Returns the count of rules reported only with problems.
function P.enforce(report, check, report_only)
	local reported = 0
	for _, id in ipairs(report.order) do
		local r = report.rules[id]
		local only = report_only and report_only[id]
		local state = #r.problems == 0 and "pass" or only and "REPORTED" or "FAIL"
		print(("proof %s %s: %s%s%s"):format(report.name, id, state,
			#r.problems > 0 and (" " .. #r.problems .. " problems") or "",
			#r.notes > 0 and (" (" .. table.concat(r.notes, "; ") .. ")") or ""))
		for i, line in ipairs(r.problems) do
			if i <= 12 then print(("  %s %s: %s"):format(report.name, id, line)) end
		end
		if #r.problems > 12 then print(("  %s %s: ... %d more"):format(report.name, id, #r.problems - 12)) end
		if #r.problems > 0 and only then reported = reported + 1 end
		check(#r.problems == 0 or only, ("proof %s %s: %s"):format(report.name, id, r.problems[1] or ""))
	end
	return reported
end

return P
