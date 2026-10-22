-- Round 56 lane FLOAT portable test (LuaJIT): items in water rise to the
-- surface and stay there.
--
--   luajit tools/r56_float/portable_test.lua [repo]
--
-- The REAL mods/BASE/default/item_entity.lua runs over a fake builtin item
-- (what the engine's builtin/game/item_entity.lua on_step does on a
-- collision: zero the velocity, moving_state false) in a stub world: a node
-- table and a small physics step (gravity, velocity, axis-aligned y
-- collisions with walkable nodes, the engine's order: move, then on_step).
--   F1  an item spawned at the floor of a 3-deep pool rises and holds at the
--       surface: position settles, velocity and acceleration zero, the 0.49.1
--       resync clock starts once (the settle and two resends), nothing after;
--   F2  an item thrown into the pool from above stops drifting where it
--       enters and rests at the surface;
--   F3  an item on land: the same flight, landing and two resends as before,
--       and no node lookup by the patch while it lies still;
--   F4  flowing water (the engine carries no entity): the item rests at the
--       level the engine draws, without drifting; river water (range 2) too;
--   F5  lava unchanged: the item sinks to the floor;
--   F6  the pool drained: a floating item falls as usual and lands;
--   F7  a 10-deep lake, F8 water under a stone roof (held under it), F9 a
--       flowing film below the item's centre does not lift it.
-- Every case prints one "CASE <id> <observed>" line. Prints
-- "R56 FLOAT PORTABLE PASS checks=<n>" or the failures.

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function case(id, observed) print(("CASE %-4s %s"):format(id, observed)) end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

vector = {}
function vector.new(x, y, z) return {x = x, y = y, z = z} end
function vector.copy(v) return {x = v.x, y = v.y, z = v.z} end
function table.copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = type(v) == "table" and table.copy(v) or v end
	return out
end

local GRAVITY = 9.81
local SIZE = 0.25 -- the item's collision box half size
local DT = 0.09

-- The stub world.
local nodes = {}
local lookups = 0
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local function round(v) return math.floor(v + 0.5) end
local function set(x, y, z, name, param2) nodes[key(x, y, z)] = {name = name, param2 = param2 or 0} end
local function node_at(x, y, z) return nodes[key(x, y, z)] or {name = "air", param2 = 0} end
local registered_nodes = {
	air = {liquidtype = "none", walkable = false, groups = {}},
	["default:stone"] = {liquidtype = "none", walkable = true, groups = {cracky = 3}},
	["default:water_source"] = {liquidtype = "source", walkable = false,
		groups = {water = 3, liquid = 3}},
	["default:water_flowing"] = {liquidtype = "flowing", walkable = false,
		groups = {water = 3, liquid = 3}},
	["default:river_water_flowing"] = {liquidtype = "flowing", walkable = false, liquid_range = 2,
		groups = {water = 3, liquid = 3}},
	["default:lava_source"] = {liquidtype = "source", walkable = false,
		groups = {lava = 3, liquid = 2}},
}

-- The fake builtin item: the collision part of its on_step.
local builtin = {
	physical_state = true,
	moving_state = true,
	itemstring = "",
	set_item = function() end,
	on_step = function(self, _, moveresult)
		if not moveresult or not moveresult.collides then return end
		self.object:set_velocity({x = 0, y = 0, z = 0})
		if self.moving_state == false then return end
		self.moving_state = false
	end,
}
local registered
minetest = {
	registered_entities = {["__builtin:item"] = builtin},
	registered_items = {},
	registered_nodes = registered_nodes,
	features = {},
	settings = {get = function(_, name) return name == "movement_gravity" and "9.81" or nil end},
	register_entity = function(_, def) registered = def end,
	log = function() end,
	get_node_or_nil = function(pos)
		lookups = lookups + 1
		return node_at(round(pos.x), round(pos.y), round(pos.z))
	end,
	get_item_group = function() return 0 end,
}
core = minetest
dofile(ROOT .. "/mods/BASE/default/item_entity.lua")
check(registered ~= nil, "item_entity.lua registers the item")

-- An item as the engine activates it: thrown up at 2 nodes/s under gravity.
local function new_item(x, y, z, vel)
	local obj = {pos = vector.new(x, y, z), vel = vel or vector.new(0, 2, 0),
		acc = vector.new(0, -GRAVITY, 0), sends = {}, clock = 0}
	function obj:get_pos() return vector.copy(self.pos) end
	function obj:set_pos(p)
		self.pos = vector.copy(p)
		self.sends[#self.sends + 1] = {t = self.clock, y = p.y}
	end
	function obj:get_velocity() return vector.copy(self.vel) end
	function obj:set_velocity(v) self.vel = vector.copy(v) end
	function obj:set_acceleration(a) self.acc = vector.copy(a) end
	return setmetatable({object = obj, itemstring = "default:stick"}, {__index = registered})
end

local function walkable(x, y, z)
	return registered_nodes[node_at(x, y, z).name].walkable
end

-- One engine step: move with collisions on y, then the entity's on_step.
-- Returns the patch's node lookups in this on_step.
local function step(e)
	local o = e.object
	o.clock = o.clock + DT
	o.vel.y = o.vel.y + o.acc.y * DT
	local moveresult = {collides = false, touching_ground = false, collisions = {}}
	local x, z = o.pos.x + o.vel.x * DT, o.pos.z + o.vel.z * DT
	local y = o.pos.y + o.vel.y * DT
	local nx, nz = round(x), round(z)
	if o.vel.y < 0 then
		for ny = round(o.pos.y - SIZE), round(y - SIZE), -1 do
			if walkable(nx, ny, nz) and y - SIZE < ny + 0.5 then
				y, o.vel.y = ny + 0.5 + SIZE, 0
				moveresult.collides, moveresult.touching_ground = true, true
				break
			end
		end
	elseif o.vel.y > 0 then
		for ny = round(o.pos.y + SIZE), round(y + SIZE) do
			if walkable(nx, ny, nz) and y + SIZE > ny - 0.5 then
				y, o.vel.y = ny - 0.5 - SIZE, 0
				moveresult.collides = true
				break
			end
		end
	end
	o.pos = vector.new(x, y, z)
	local before = lookups
	e:on_step(DT, moveresult)
	return lookups - before
end
local function run(e, seconds)
	local most = 0
	for _ = 1, math.floor(seconds / DT + 0.5) do most = math.max(most, step(e)) end
	return most
end

-- A stone floor at y = 0 (top 0.5) and a pool of `depth` sources above it
-- around x = z = 0, walls around; `name` fills it.
local function reset() nodes = {} end
local function floor_and_pool(depth, name)
	for x = -4, 4 do
		for z = -4, 4 do set(x, 0, z, "default:stone") end
	end
	for x = -3, 3 do
		for z = -3, 3 do
			for y = 1, depth do
				local wall = math.abs(x) == 3 or math.abs(z) == 3
				set(x, y, z, wall and "default:stone" or name)
			end
		end
	end
end

local function settled(e)
	local o = e.object
	return o.vel.x == 0 and o.vel.y == 0 and o.vel.z == 0 and o.acc.y == 0
end

do -- F1 3-deep pool, spawned at the floor.
	reset()
	floor_and_pool(3, "default:water_source")
	local e = new_item(0, 1 + 0.3, 0)
	run(e, 4)
	local o = e.object
	local surface = 3.5
	local settle = o.sends[1]
	local y_at_4 = o.pos.y
	local most = run(e, 10)
	case("F1", ("3-deep pool: y %.3f (surface %.1f) vel %.1f,%.1f,%.1f sends at %s"):format(o.pos.y,
		surface, o.vel.x, o.vel.y, o.vel.z, (function()
			local t = {}
			for i, s in ipairs(o.sends) do t[i] = ("%.2f"):format(s.t) end
			return table.concat(t, ",")
		end)()))
	check(near(o.pos.y, surface), "F1 rests at the surface")
	check(y_at_4 == o.pos.y, "F1 the position holds")
	check(settled(e), "F1 velocity and acceleration zero")
	check(#o.sends == 3, "F1 the settle and two resends, once")
	local function after(i, t)
		local d = o.sends[i] and settle and o.sends[i].t - settle.t
		return d and d >= t - 1e-9 and d < t + DT
	end
	check(after(2, 0.5) and after(3, 2), "F1 the resends 0.5 s and 2 s after the settle")
	check(most == 1, "F1 one node lookup per step while it floats")
	check(o.pos.x == 0 and o.pos.z == 0, "F1 no drift")
end

do -- F2 thrown into the pool from 5 nodes above, sideways.
	reset()
	floor_and_pool(3, "default:water_source")
	local e = new_item(-1.4, 8, 0, vector.new(1.5, 2, 0.5))
	local entered, lowest
	for _ = 1, math.floor(8 / DT) do
		step(e)
		local p = e.object.pos
		if not entered and e._grug_float then entered = vector.copy(p) end
		lowest = math.min(lowest or p.y, p.y)
	end
	local o = e.object
	case("F2", ("thrown in: entered x=%.3f z=%.3f, rests x=%.3f y=%.3f z=%.3f, lowest %.3f"):format(
		entered and entered.x or 0, entered and entered.z or 0, o.pos.x, o.pos.y, o.pos.z, lowest))
	check(entered ~= nil, "F2 the water caught it")
	check(near(o.pos.y, 3.5) and settled(e), "F2 rests at the surface")
	check(entered and o.pos.x == entered.x and o.pos.z == entered.z, "F2 no drift after entering")
	check(lowest > 1.5, "F2 it does not sink to the floor")
	check(#o.sends == 3, "F2 the settle and two resends")
end

do -- F3 on land: unchanged, and nothing looked up while it lies still.
	reset()
	floor_and_pool(0, "default:water_source")
	local e = new_item(0, 1.5, 0, vector.new(0.5, 5, 0))
	local flight, landed = 0, nil
	for i = 1, math.floor(3 / DT) do
		local n = step(e)
		if e.moving_state == false and not landed then landed = i end
		if not landed then flight = math.max(flight, n) end
	end
	local resting = run(e, 10)
	local o = e.object
	case("F3", ("land: rests y=%.3f, sends %d, lookups/step flying %d, lying %d"):format(o.pos.y,
		#o.sends, flight, resting))
	check(near(o.pos.y, 0.5 + SIZE) and e._grug_float == nil, "F3 rests on the ground")
	check(#o.sends == 2, "F3 the 0.49.1 two resends after the landing")
	check(flight <= 1, "F3 at most one lookup per step in flight")
	check(resting == 0, "F3 no lookup while it lies on land")
end

do -- F4 flowing water: the drawn level, no drift (no flow pushes entities).
	reset()
	floor_and_pool(0, "default:water_source")
	set(0, 1, 0, "default:water_flowing", 5) -- level 5: top 0.5 + 5.5/8
	local e = new_item(0, 1 + 0.3, 0)
	run(e, 6)
	local o = e.object
	local top = 0.5 + 5.5 / 8
	reset()
	floor_and_pool(0, "default:water_source")
	set(0, 1, 0, "default:river_water_flowing", 7) -- range 2: level 1, top 0.5 + 1.5/2
	local r = new_item(0, 1 + 0.3, 0)
	run(r, 6)
	case("F4", ("flowing level 5: y %.3f (drawn %.3f); river level 7: y %.3f (drawn %.3f)"):format(
		o.pos.y, top, r.object.pos.y, 0.5 + 1.5 / 2))
	check(near(o.pos.y, top) and settled(e), "F4 rests at the drawn flowing level")
	check(o.pos.x == 0 and o.pos.z == 0, "F4 no drift on flowing water")
	check(near(r.object.pos.y, 0.5 + 1.5 / 2) and settled(r), "F4 river water's range 2 level")
end

do -- F5 lava unchanged: sinks to the floor.
	reset()
	floor_and_pool(3, "default:lava_source")
	local e = new_item(0, 6, 0)
	run(e, 4)
	local o = e.object
	case("F5", ("lava: y %.3f, float %s"):format(o.pos.y, tostring(e._grug_float)))
	check(near(o.pos.y, 0.5 + SIZE) and e._grug_float == nil, "F5 an item in lava sinks as before")
end

do -- F6 drained: falls as usual and lands.
	reset()
	floor_and_pool(3, "default:water_source")
	local e = new_item(1, 1.3, 1)
	run(e, 6)
	local floated = e.object.pos.y
	for x = -2, 2 do
		for z = -2, 2 do
			for y = 1, 3 do set(x, y, z, "air") end
		end
	end
	local sends = #e.object.sends
	run(e, 4)
	local o = e.object
	case("F6", ("drained: floated %.3f, then y %.3f, resends after the landing %d"):format(floated,
		o.pos.y, #o.sends - sends))
	check(near(floated, 3.5), "F6 floated first")
	check(near(o.pos.y, 0.5 + SIZE) and e._grug_float == nil, "F6 falls to the floor and rests")
	check(#o.sends - sends == 2, "F6 the 0.49.1 resends after the landing")
end

do -- F7 a 10-deep lake, F8 under a stone roof, F9 a thin film.
	reset()
	floor_and_pool(10, "default:water_source")
	local deep = new_item(0, 1.3, 0)
	run(deep, 8)
	reset()
	floor_and_pool(4, "default:water_source")
	for x = -2, 2 do
		for z = -2, 2 do set(x, 4, z, "default:stone") end
	end
	local roof = new_item(0, 1.3, 0)
	run(roof, 5)
	local roof_y = roof.object.pos.y
	run(roof, 5)
	reset()
	floor_and_pool(0, "default:water_source")
	set(0, 1, 0, "default:water_flowing", 1) -- top 0.5 + 1.5/8, below the centre 0.75
	local film = new_item(0, 1.3, 0)
	run(film, 4)
	case("F7", ("10 deep: y %.3f; roof: y %.3f held %s; film: y %.3f"):format(deep.object.pos.y,
		roof.object.pos.y, tostring(roof_y == roof.object.pos.y), film.object.pos.y))
	check(near(deep.object.pos.y, 10.5) and settled(deep), "F7 a deep lake: the surface")
	check(near(roof.object.pos.y, 3.5 - SIZE) and settled(roof) and roof_y == roof.object.pos.y,
		"F8 held still under the roof")
	check(near(film.object.pos.y, 0.5 + SIZE) and film._grug_float == nil,
		"F9 a film below the centre does not lift it")
end

minetest, core = nil, nil
if failures == 0 then
	print(("R56 FLOAT PORTABLE PASS checks=%d"):format(checks))
else
	error(("R56 FLOAT PORTABLE FAIL %d/%d"):format(failures, checks), 0)
end
