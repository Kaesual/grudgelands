-- 0.49.1 lane DOOR portable test (LuaJIT; fix-0.49.1-plan.md ruling 8, §4
-- DOOR): a right-click on a closed door opens it, also with a dialog NPC
-- behind it. Loads the REAL grug_mobs/door_click.lua on a fake engine whose
-- ray orders its hits like the engine's RaycastSort (an object counts one
-- node squared nearer than a node, src/raycast.cpp; tools/r491_door/probe.sh
-- measures the real engine) over a box world: a floor, a door (the bottom
-- node's two-node box, the hidden top node unpointable) and an NPC with the
-- dialog NPCs' box. Checks:
--   E  the engine order reproduces the report: with the NPC just behind the
--      panel, a ray at the upper half meets the NPC first, a ray aimed low
--      the door;
--   C  closed door, NPC behind it: both halves, both sides, several
--      distances: the door takes the click (its on_rightclick, at the
--      door's foot) and the helper says so;
--   O  the door open, N no door, F the NPC in front of the closed door, S a
--      sneak click, X another node first: the helper does nothing, the NPC
--      answers;
--   W  every dialog NPC's on_rightclick (villager, quest giver, vendor) asks
--      the helper before anything else.
-- Usage (repo root): luajit tools/r491_door/portable_test.lua [REPO]
-- Prints "R491 DOOR PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

vector = {}
function vector.new(x, y, z) return {x = x, y = y, z = z} end
function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function vector.multiply(a, s) return vector.new(a.x * s, a.y * s, a.z * s) end
function vector.length(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function vector.distance(a, b) return vector.length(vector.subtract(a, b)) end
function vector.normalize(a) return vector.multiply(a, 1 / vector.length(a)) end

-- ---------------------------------------------------------------------------
-- A box world
-- ---------------------------------------------------------------------------
local nodes = {} -- "x,y,z" -> {name, param2}
local function key(p) return p.x .. "," .. p.y .. "," .. p.z end
local DOOR_CLOSED = {-0.5, -0.5, -0.5, 0.5, 1.5, -0.375} -- doors/init.lua, param2 0
local DOOR_OPEN = {-0.5, -0.5, -0.5, -0.375, 1.5, 0.5} -- the leaf along one side
local FULL = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}
local THIN = {-0.5, -0.5, -0.5, 0.5, 1.0, -0.375} -- a thin node that is no door
local defs = {}
local clicks = {}
local door_state = {} -- "x,y,z" -> 0 shut, 1 open
local function door_def(name, box)
	defs[name] = {box = box, on_rightclick = function(pos, node, clicker, stack, pointed)
		clicks[#clicks + 1] = {pos = pos, node = node.name, clicker = clicker,
			stack = stack, pointed = pointed}
		return stack
	end}
end
door_def("doors:door_wood_a", DOOR_CLOSED)
door_def("doors:door_wood_c", DOOR_OPEN)
defs["default:stone"] = {box = FULL}
defs["grug_probe:thin"] = {box = THIN, on_rightclick = function() clicks[#clicks + 1] = "thin" end}

doors = {registered_doors = {["doors:door_wood_a"] = true, ["doors:door_wood_c"] = true}}
function doors.get(pos)
	local node = nodes[key(pos)]
	if not node or not doors.registered_doors[node.name] then return nil end
	return {state = function() return (door_state[key(pos)] or 0) % 2 == 1 end}
end

local function slab(o, d, b, c)
	local t0, t1 = -math.huge, math.huge
	local lo = {c.x + b[1], c.y + b[2], c.z + b[3]}
	local hi = {c.x + b[4], c.y + b[5], c.z + b[6]}
	local oo, dd = {o.x, o.y, o.z}, {d.x, d.y, d.z}
	for i = 1, 3 do
		if math.abs(dd[i]) < 1e-12 then
			if oo[i] < lo[i] or oo[i] > hi[i] then return nil end
		else
			local a, z = (lo[i] - oo[i]) / dd[i], (hi[i] - oo[i]) / dd[i]
			if a > z then a, z = z, a end
			if a > t0 then t0 = a end
			if z < t1 then t1 = z end
		end
	end
	if t0 > t1 or t1 < 0 then return nil end
	return math.max(t0, 0)
end

local npc = {object = {}, pos = nil}
local NPC_BOX = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}
local engine_rays = 0

grug_core = {}
function grug_core.combat_eye_pos(player)
	local p = player:get_pos()
	return vector.new(p.x, p.y + 1.47, p.z)
end
-- The engine's order: every hit within the ray, an object one node squared
-- nearer than a node (RaycastSort), nodes by their true distance.
function grug_core.aim_raycast(origin, destination)
	engine_rays = engine_rays + 1
	local span = vector.subtract(destination, origin)
	local length = vector.length(span)
	local dir = vector.multiply(span, 1 / length)
	local hits = {}
	for k, node in pairs(nodes) do
		local def = defs[node.name]
		local x, y, z = k:match("^(-?%d+),(-?%d+),(-?%d+)$")
		local c = vector.new(tonumber(x), tonumber(y), tonumber(z))
		local t = def and def.box and slab(origin, dir, def.box, c)
		if t and t <= length then
			hits[#hits + 1] = {sort = t * t, pointed = {type = "node", under = c,
				above = c, intersection_point = vector.add(origin, vector.multiply(dir, t))}}
		end
	end
	if npc.pos then
		local t = slab(origin, dir, NPC_BOX, npc.pos)
		if t and t <= length then
			hits[#hits + 1] = {sort = t * t - 1, pointed = {type = "object", ref = npc.object,
				intersection_point = vector.add(origin, vector.multiply(dir, t))}}
		end
	end
	table.sort(hits, function(a, b) return a.sort < b.sort end)
	local i = 0
	return function()
		i = i + 1
		return hits[i] and hits[i].pointed
	end
end

core = {registered_nodes = defs}
function core.get_node_or_nil(pos)
	local node = nodes[key(pos)]
	return node and {name = node.name, param2 = node.param2} or {name = "air"}
end
grug_mobs = {}
dofile(repo .. "/mods/ENTITIES/grug_mobs/door_click.lua")
local helper = grug_mobs.door_before_npc
check(type(helper) == "function", "the helper is published")

-- ---------------------------------------------------------------------------
-- The scene: a floor, the door at (0,0,0), a player and the NPC
-- ---------------------------------------------------------------------------
local FLOOR_Y = -0.5
local DOOR_POS = vector.new(0, 0, 0)
local function scene(door, extra)
	nodes = {}
	for x = -4, 4 do
		for z = -6, 6 do nodes[key(vector.new(x, -1, z))] = {name = "default:stone"} end
	end
	door_state = {}
	if door == "closed" then
		nodes[key(DOOR_POS)] = {name = "doors:door_wood_a", param2 = 0}
	elseif door == "open" then
		nodes[key(DOOR_POS)] = {name = "doors:door_wood_c", param2 = 1}
		door_state[key(DOOR_POS)] = 1
	end
	if extra then nodes[key(extra.pos)] = {name = extra.name} end
	clicks = {}
end
-- Faces of the closed panel: the outer at z -0.5, the inner at -0.375.
local OUT_FACE, IN_FACE = -0.5, -0.375
local function npc_behind(side, gap)
	if side == "out" then return vector.new(0, FLOOR_Y, IN_FACE + 0.3 + gap) end
	return vector.new(0, FLOOR_Y, OUT_FACE - 0.3 - gap)
end
local function player_at(side, distance, aim_height, sneak, aim)
	local face = side == "out" and OUT_FACE or IN_FACE
	local sign = side == "out" and -1 or 1
	local feet = vector.new(0, FLOOR_Y, face + sign * distance)
	local eye = vector.new(0, FLOOR_Y + 1.47, feet.z)
	aim = aim or vector.new(0, FLOOR_Y + aim_height, face)
	local look = vector.normalize(vector.subtract(aim, eye))
	local p = {name = "ann"}
	function p:is_player() return true end
	function p:get_pos() return {x = feet.x, y = feet.y, z = feet.z} end
	function p:get_look_dir() return look end
	function p:get_player_control() return {sneak = sneak == true} end
	function p:get_wielded_item() return "wielded" end
	return p, eye, look
end
local function engine_first(eye, look)
	local first = grug_core.aim_raycast(eye, vector.add(eye, vector.multiply(look, 4)))()
	return first and first.type
end

-- E: the stub reproduces the report.
scene("closed")
npc.pos = npc_behind("out", 0.075)
do
	local _, eye, look = player_at("out", 2.0, 1.25)
	check(engine_first(eye, look) == "object", "E upper half at 2 m: the engine points at the NPC behind the door")
	_, eye, look = player_at("out", 2.0, 0.25)
	check(engine_first(eye, look) == "node", "E low on the door at 2 m: the engine points at the door")
end

-- C: closed door, NPC behind: the door takes every click.
local HALVES = {upper = {1.25, 1.6}, lower = {0.3, 0.75}}
local GAPS = {out = {0.0, 0.075, 0.15, 0.3}, ["in"] = {0.0, 0.1, 0.2, 0.3}}
local npc_first_seen = 0
for _, side in ipairs({"out", "in"}) do
	for _, gap in ipairs(GAPS[side]) do
		for half, heights in pairs(HALVES) do
			for _, h in ipairs(heights) do
				for _, d in ipairs({1.0, 1.5, 2.0, 2.5, 3.0}) do
					scene("closed")
					npc.pos = npc_behind(side, gap)
					local player, eye, look = player_at(side, d, h)
					if engine_first(eye, look) == "object" then npc_first_seen = npc_first_seen + 1 end
					local label = ("C %s gap %.3f %s %.2f at %.1f m"):format(side, gap, half, h, d)
					check(helper(npc, player) == true, label .. ": the door took the click")
					local c = clicks[1]
					check(#clicks == 1 and c.node == "doors:door_wood_a" and c.clicker == player and
						c.pos.x == 0 and c.pos.y == 0 and c.pos.z == 0 and c.stack == "wielded" and
						c.pointed.type == "node", label .. ": once, at the door's foot, as a node click")
				end
			end
		end
	end
end
check(npc_first_seen > 0, "C some of these clicks are the reported ones (the engine points at the NPC)")
-- The open leaf lies along the cell's -x side; an NPC beside the doorway,
-- behind the leaf as seen from the -z side.
local BESIDE_LEAF = vector.new(-0.85, FLOOR_Y, 0.6)
local AT_LEAF = vector.new(-0.44, FLOOR_Y + 0.75, 0)
scene("open")
npc.pos = BESIDE_LEAF
do
	local _, eye, look = player_at("out", 2.0, 0.75, false, AT_LEAF)
	local first_node, saw_npc
	for pointed in grug_core.aim_raycast(eye, vector.add(eye, vector.multiply(look, 4))) do
		if pointed.type == "node" and not first_node then first_node = pointed.under end
		if pointed.type == "object" then saw_npc = true end
	end
	check(first_node and first_node.x == 0 and first_node.y == 0 and first_node.z == 0 and saw_npc,
		"O the ray at the open leaf meets the leaf first, the NPC behind it")
end

-- O, N, F, S, X: the NPC answers.
local function untouched(label, door, npc_pos, side, d, h, sneak, extra, aim)
	scene(door, extra)
	npc.pos = npc_pos
	local player = player_at(side, d, h, sneak, aim)
	check(helper(npc, player) == false, label .. ": the NPC answers")
	check(#clicks == 0, label .. ": no node click")
end
for _, side in ipairs({"out", "in"}) do
	for half, heights in pairs(HALVES) do
		for _, d in ipairs({1.0, 2.0, 3.0}) do
			local h = heights[1]
			local where = (" %s %s at %.1f m"):format(side, half, d)
			untouched("O door open" .. where, "open", npc_behind(side, 0.1), side, d, h)
			-- At the open leaf itself, with the NPC behind the leaf.
			untouched("O at the open leaf" .. where, "open", BESIDE_LEAF,
				side, d, h, false, nil, AT_LEAF)
			untouched("N no door" .. where, "none", npc_behind(side, 0.1), side, d, h)
			untouched("F NPC in front of the closed door" .. where, "closed",
				npc_behind(side, -0.7), side, d, h)
			untouched("S sneak" .. where, "closed", npc_behind(side, 0.075), side, d, h, true)
		end
	end
end
untouched("X a thin node that is no door", "none", npc_behind("out", 0.075), "out", 2.0, 0.6,
	false, {pos = DOOR_POS, name = "grug_probe:thin"})
untouched("N the NPC with nothing between", "none", vector.new(0, FLOOR_Y, 0), "out", 2.0, 1.0)
check(helper(npc, nil) == false and helper(nil, player_at("out", 2, 1)) == false,
	"a click without clicker or NPC does nothing")
local robot = {is_player = function() return false end}
check(helper(npc, robot) == false, "a non-player clicker does nothing")

-- W: every dialog NPC asks the helper first.
local function body_after(text, anchor)
	local at = assert(text:find(anchor, 1, true), "anchor " .. anchor)
	return text:sub(at, at + 400)
end
local villagers = read("mods/ENTITIES/grug_mobs/start_villagers.lua")
local vendors = read("mods/ENTITIES/grug_traders/vendors.lua")
local count = 0
for chunk in villagers:gmatch("on_rightclick = function%(self, clicker%)(.-)\n\t\t\tend,") do
	count = count + 1
	local first = chunk:match("^%s*%-%-[^\n]*\n%s*([^\n]+)") or chunk:match("^%s*([^\n]+)")
	check(first == "if grug_mobs.door_before_npc(self, clicker) then return end",
		"W villager handler " .. count .. " asks the helper first")
end
check(count == 2, "W two villager handlers (resident, quest giver), got " .. count)
local vendor = body_after(vendors, "on_rightclick = function(self, clicker)")
check(vendor:match("^on_rightclick = function%(self, clicker%)%s*%-%-[^\n]*\n%s*([^\n]+)") ==
	"if grug_mobs.door_before_npc(self, clicker) then return end", "W the vendor asks the helper first")
local init = read("mods/ENTITIES/grug_mobs/init.lua")
check(init:find('dofile(modpath .. "/door_click.lua")', 1, true) ~= nil, "W grug_mobs loads the helper")

print(("R491 DOOR PORTABLE PASS checks=%d (rays %d)"):format(checks, engine_rays))
