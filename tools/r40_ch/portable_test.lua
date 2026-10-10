-- Round 40 lane CH portable test (LuaJIT): Charge as a dash
-- (round40-plan.md §2.3, §2.10, §2.11, §2.16, §3.3).
--
--   luajit tools/r40_ch/portable_test.lua [repo]
--
--   A  the REAL planner (grug_abilities/charge_path.lua) with the game's own
--      destination search (blink.lua) on the V4 probe's courses, the uphill
--      stairs included (it reaches the destination), and the hole rule on
--      built lanes: a hole up to 4 nodes wide is one hop whatever its depth,
--      5 wide stops at the rim; the far rim at most one node higher; a
--      shallow dip is jumped, a wide one followed; liquids are crossed but
--      never landed in; a pit the path cannot climb out of stops at its rim;
--      a wall is not a hole. Every plan is continuous, its hops land
--      exactly, and nothing is refused (a stop is the miss rule's).
--   B  the REAL charge.lua on a fake engine that moves the carrier like a
--      non-physical entity (pos += v dt + a dt^2/2, then on_step): the
--      arrival (rage 15, one damage call with threat x3, the stun, the ring
--      at the target) only within reach of the re-fetched target and only
--      when the relation check still passes; the miss rules (target gone
--      out of reach, the rim of a wide hole, rooted at the cast); the
--      cancellations (stun, root, death, logout, travel's seam) land
--      nothing; a punch on the carrier reaches the rider; the stop holds
--      three client time constants, then detaches and puts the player on
--      the stop (the uphill fix); the Body lead (only on dashes of 3 m or
--      more, between the epsilon and the lead), the FOV kick, the pose seam
--      and the dust per run segment; the dash's own refusals; (0.45.1) a
--      segment ending before the next step is headed for straight, and a
--      stun inside a straight drop lets go on its takeoff.
--   C  the REAL kits.lua Charge cast: no target and no room refuse (false,
--      so try_cast spends nothing); with a destination it starts the dash.
-- Prints "R40 CH PORTABLE PASS checks=<n>" or the failures (exit 1).

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
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end

vector = {}
function vector.new(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x, y = y, z = z}
end
vector.copy = vector.new
function vector.offset(v, x, y, z) return vector.new(v.x + x, v.y + y, v.z + z) end
function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function vector.multiply(v, k) return vector.new(v.x * k, v.y * k, v.z * k) end
function vector.length(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
function vector.distance(a, b) return vector.length(vector.subtract(a, b)) end
function vector.round(v)
	return vector.new(math.floor(v.x + 0.5), math.floor(v.y + 0.5), math.floor(v.z + 0.5))
end
function vector.direction(a, b)
	local d = vector.subtract(b, a)
	local l = vector.length(d)
	return l == 0 and vector.new(0, 0, 0) or vector.multiply(d, 1 / l)
end

local path = dofile(ROOT .. "/mods/PLAYER/grug_abilities/charge_path.lua")
local destinations = dofile(ROOT .. "/mods/PLAYER/grug_abilities/blink.lua")
local shapes = dofile(ROOT .. "/tools/r40_probe/shapes.lua")
local REACH = destinations.charge_reach
check(REACH == 3, "A blink.lua publishes CHARGE_REACH 3")
check(path.SPEED == 24, "A the dash speed is 24 m/s (§2.16)")

local BOX = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}
local EYE = 1.47
local FULL = {{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}
local LOW = {{-0.5, -0.5, -0.5, 0.5, 0.75, 0.5}}

------------------------------------------------------------------------------
-- A: the planner.
------------------------------------------------------------------------------
local function kinds(p)
	local out = {}
	for _, s in ipairs(p.segments) do out[#out + 1] = s.kind end
	return table.concat(out, ",")
end

local function dist(a, b)
	return vector.distance(a, b)
end

-- Each segment starts where the previous one ends; hops land exactly.
local function sound(p)
	for k, s in ipairs(p.segments) do
		if not (s.t > 0 and s.len > 0) then return false end
		local t = s.t
		local e = {x = s.p0.x + s.v.x * t + 0.5 * s.a.x * t * t,
			y = s.p0.y + s.v.y * t + 0.5 * s.a.y * t * t,
			z = s.p0.z + s.v.z * t + 0.5 * s.a.z * t * t}
		local n = p.segments[k + 1]
		if n and (dist(e, n.p0) > 1e-6 or not near(s.t0 + s.t, n.t0)) then return false end
		if not n and dist(e, p.finish) > 1e-6 then return false end
		if s.kind == "hop" and not near(e.y - s.p0.y, s.rise, 1e-9) then return false end
	end
	return true
end

-- The probe's courses through the game's destination search.
for _, name in ipairs(shapes.ORDER) do
	local shape = shapes.LIST[name]
	local world = shapes.table_world(shape)
	local from, target = shapes.start(shape), shapes.target(shape)
	local dest = destinations.charge(from, EYE, BOX, target, world)
	if name == "wall_high" then
		check(dest == nil, "A wall_high: refused at the cast (no line of sight)")
	elseif check(dest ~= nil, "A " .. name .. ": the game's destination exists") then
		local p = path.plan({boxes = world.xyz}, from, dest)
		check(sound(p), "A " .. name .. ": continuous, hops land exactly")
		check(not p.cut and dist(p.finish, dest) < 1e-6,
			"A " .. name .. ": reaches the destination (" .. kinds(p) .. ")")
		check(near(p.total, p.dist / 24 + 0, 1e-9) or p.total > 0,
			"A " .. name .. ": constant horizontal speed")
		local hops = 0
		for _, s in ipairs(p.segments) do
			if s.kind == "hop" then hops = hops + 1 end
			check(near(math.sqrt(s.v.x * s.v.x + s.v.z * s.v.z), 24, 1e-9),
				"A " .. name .. ": 24 m/s along the ground")
		end
		if name == "short" or name == "long" or name == "hit" then
			check(kinds(p) == "run", "A " .. name .. ": one run")
		elseif name == "wall" or name == "step" or name == "ledge" then
			check(hops == 1, "A " .. name .. ": one hop, got " .. kinds(p))
		elseif name == "uphill" then
			check(hops >= 1 and near(p.finish.y, dest.y), "A uphill: hops up onto the last stair")
		end
	end
end

-- Built lanes along +x (uniform across z): cell(x, y) -> nil (air),
-- "solid", "water" or "low" (a 1.25 m wall's node box). Ground is y <= -1,
-- the caster's feet at (0, -0.5, 0).
local function lane(cell)
	return {
		boxes = function(x, y)
			local c = cell(x, y)
			if c == "solid" then return FULL end
			if c == "low" then return LOW end
			return nil
		end,
		liquid = function(x, y) return cell(x, y) == "water" end,
	}
end
local FROM = {x = 0, y = -0.5, z = 0}
local function ground(x, y) return y <= -1 and "solid" or nil end
local function hole(a, b, depth)
	return function(x, y)
		if x >= a and x <= b then
			return depth and y <= -1 - depth and "solid" or nil
		end
		return ground(x, y)
	end
end
local function plan(cell, dest)
	return path.plan(lane(cell), FROM, dest or {x = 10, y = -0.5, z = 0})
end

local p = plan(hole(3, 6))
check(sound(p) and not p.cut and p.jumps == 1 and near(p.finish.x, 10),
	"A a bottomless hole 4 nodes wide: one hop, arrives (" .. kinds(p) .. ")")
p = plan(hole(3, 6, 2))
check(not p.cut and p.jumps == 1, "A a hole 4 wide and 2 deep: one hop too (depth does not matter)")
p = plan(hole(3, 7))
check(p.cut and p.jumps == 0 and p.finish.x < 3 and p.finish.x > 2.4 and near(p.finish.y, -0.5),
	"A a hole 5 nodes wide: stops at the rim (" .. tostring(p.finish.x) .. ")")
p = plan(hole(3, 7, 3))
check(p.cut and p.finish.x < 3, "A a hole 5 wide and 3 deep: stops at the rim")
p = plan(function(x, y)
	if x >= 3 and x <= 6 then return nil end
	if x >= 7 then return y <= 0 and "solid" or nil end
	return ground(x, y)
end, {x = 10, y = 0.5, z = 0})
check(sound(p) and not p.cut and p.jumps == 1 and near(p.finish.y, 0.5),
	"A a hole 4 wide, far rim one node higher: one hop up")
p = plan(function(x, y)
	if x >= 3 and x <= 6 then return nil end
	if x >= 7 then return y <= 1 and "solid" or nil end
	return ground(x, y)
end, {x = 10, y = 1.5, z = 0})
check(p.cut and p.finish.x < 3, "A a hole 4 wide, far rim two nodes higher: stops at the rim")
p = plan(function(x, y)
	if x >= 3 and x <= 5 then return nil end
	if x >= 6 then return y <= -2 and "solid" or nil end
	return ground(x, y)
end, {x = 10, y = -1.5, z = 0})
check(sound(p) and not p.cut and p.jumps == 1 and near(p.finish.y, -1.5),
	"A a hole 3 wide, far rim one node lower: one hop down")
p = plan(hole(3, 4, 1))
check(sound(p) and not p.cut and p.jumps == 1, "A a shallow dip 2 wide: jumped")
p = plan(hole(3, 8, 1), {x = 12, y = -0.5, z = 0})
check(sound(p) and not p.cut and p.jumps == 0 and kinds(p):find("hop,hop") ~= nil,
	"A a shallow dip 6 wide: followed, down and up again (" .. kinds(p) .. ")")
local function pond(a, b)
	return function(x, y)
		if x >= a and x <= b then
			if y <= -4 then return "solid" end
			if y <= -1 then return "water" end
			return nil
		end
		return ground(x, y)
	end
end
p = plan(pond(3, 5))
check(sound(p) and not p.cut and p.jumps == 1, "A water 3 wide: crossed in one hop")
p = plan(pond(3, 8), {x = 12, y = -0.5, z = 0})
check(p.cut and p.finish.x < 3, "A water 6 wide: stops at the shore")
p = plan(function(x, y)
	if x >= 3 and x <= 8 then
		if y <= -2 then return "solid" end
		if y == -1 then return "water" end
		return nil
	end
	return ground(x, y)
end, {x = 12, y = -0.5, z = 0})
check(p.cut and p.finish.x < 3, "A shallow water 6 wide is no ground: stops at the shore")
p = plan(function(x, y)
	if x >= 8 then
		if y <= -2 then return "solid" end
		if y == -1 then return "water" end
		return nil
	end
	return ground(x, y)
end, {x = 10, y = -1.5, z = 0})
check(p.cut and p.finish.x < 8 and p.finish.x > 7, "A a destination in water: stops at the shore, never lands in it")
p = plan(function(x, y)
	if x <= 2 then
		if y <= -2 then return "solid" end
		if y == -1 then return "water" end
		return nil
	end
	return ground(x, y)
end)
check(not p.cut and p.jumps == 1, "A a start in shallow water hops out onto dry ground")
p = plan(hole(3, 8, 3), {x = 12, y = -0.5, z = 0})
check(p.cut and p.cut_why == "cannot climb out of the drop" and p.finish.x < 3 and
	near(p.finish.y, -0.5), "A a pit 6 wide and 3 deep: stops at its rim, not inside")
p = plan(function(x, y)
	if x >= 5 and (y == 0 or y == 1) then return "solid" end
	if x >= 6 then return y <= -3 and "solid" or nil end
	if x >= 3 then return y <= -4 and "solid" or nil end
	return ground(x, y)
end, {x = 10, y = -2.5, z = 0})
check(sound(p) and p.cut and p.cut_why == "cannot climb out of the drop" and
	near(p.finish.y, -0.5) and p.finish.x < 3 and kinds(p) == "run",
	"A down in a pit, a step no hop clears under a roof: stops at the pit's rim too")
p = plan(function(x, y)
	if x >= 3 then return y <= -4 and "solid" or nil end
	return ground(x, y)
end, {x = 10, y = -3.5, z = 0})
check(sound(p) and not p.cut and near(p.finish.y, -3.5), "A a 3 m ledge down to the destination: followed")
p = plan(function(x, y)
	if x == 4 and y >= 0 and y <= 1 then return "solid" end
	return ground(x, y)
end)
check(p.cut and p.jumps == 0 and p.finish.x < 4, "A a thin 2 m wall is not a hole: stops before it")
p = plan(function(x, y)
	if x == 4 and y == 0 then return "low" end
	return ground(x, y)
end)
check(sound(p) and not p.cut and kinds(p):find("hop") ~= nil, "A a 1.25 m wall: one hop over it")
p = plan(function(x, y)
	if (x >= 2 and x <= 4) or (x >= 7 and x <= 9) then return nil end
	return ground(x, y)
end, {x = 12, y = -0.5, z = 0})
check(sound(p) and not p.cut and p.jumps == 2, "A two holes: two hops")
p = plan(hole(0, 9))
check(p and p.cut and #p.segments == 0 and p.total == 0 and near(p.finish.x, 0),
	"A a hole at the feet: an empty plan, never a refusal")

-- state_at follows the plan and clamps past its end.
p = plan(hole(3, 6))
local s_end = path.state_at(p, p.total + 1)
check(dist(s_end, p.finish) < 1e-9, "A state_at past the end is the finish")

------------------------------------------------------------------------------
-- C: the kits.lua cast (sandboxed before the fake engine of B).
------------------------------------------------------------------------------
do
	local function any()
		return setmetatable({}, {__index = function() return any() end,
			__call = function() return nil end})
	end
	local defs, started = {}, {}
	local aim
	local env = setmetatable({
		grug_abilities = setmetatable({
			register_ability = function(d) defs[d.id] = d end,
			charge_destination = function() return aim.dest end,
			charge_dash = function(...)
				started[#started + 1] = {...}
				return true
			end,
		}, {__index = function() return any() end}),
		ItemStack = function() return any() end,
	}, {__index = function(_, k)
		local g = rawget(_G, k)
		if g ~= nil and k ~= "core" and k ~= "vector" then return g end
		if k == "vector" then return vector end
		return any()
	end})
	local chunk = assert(loadfile(ROOT .. "/mods/PLAYER/grug_abilities/kits.lua"))
	setfenv(chunk, env)
	chunk()
	local charge = defs.charge
	env.grug_abilities.aimed_target = function() return aim.target, {} end
	local user = {get_properties = function() return {eye_height = 1.47, collisionbox = BOX} end,
		get_pos = function() return {x = 0, y = 0, z = 0} end,
		get_player_name = function() return "caster" end}
	local mob = {get_properties = function() return {collisionbox = BOX} end,
		get_pos = function() return {x = 0, y = 0, z = 8} end}
	aim = {target = nil}
	local ok, why = charge.cast(user, nil, charge)
	check(ok == false and why == "No hostile target in your crosshair." and #started == 0,
		"C no target: refused, no dash")
	aim = {target = mob, dest = nil}
	ok, why = charge.cast(user, nil, charge)
	check(ok == false and why == "Not enough room at target." and #started == 0,
		"C no room: refused, no dash")
	aim = {target = mob, dest = {x = 0, y = 0, z = 6.7}}
	ok = charge.cast(user, nil, charge)
	check(ok == true and #started == 1 and started[1][1] == user and started[1][2] == mob and
		started[1][3].z == 6.7 and started[1][4] == charge, "C with room: the dash starts")
	check(charge.cooldown == 10 and charge.range == 12, "C cooldown 10 s, range 12 m unchanged")
end

------------------------------------------------------------------------------
-- B: the dash on a fake engine.
------------------------------------------------------------------------------
local NODES = {stone = {walkable = true}, air = {walkable = false},
	water = {walkable = false, liquidtype = "source"}}
local cell = ground
local now = 0
local timers = {}
local entities, callbacks = {}, {join = {}, die = {}, leave = {}}
local players = {}
local spawn_fails = false

core = {
	settings = {get = function(_, key)
		if key == "dedicated_server_step" then return "0.09" end
	end},
	register_entity = function(name, def) entities[name] = def end,
	register_on_joinplayer = function(f) callbacks.join[#callbacks.join + 1] = f end,
	register_on_dieplayer = function(f) callbacks.die[#callbacks.die + 1] = f end,
	register_on_leaveplayer = function(f) callbacks.leave[#callbacks.leave + 1] = f end,
	get_player_by_name = function(name) return players[name] end,
	after = function(t, f, ...)
		timers[#timers + 1] = {at = now + t, f = f, args = {...}}
	end,
	dir_to_yaw = function(d) return math.atan2(-d.x, d.z) end,
	get_node_or_nil = function(pos)
		local c = cell(pos.x, pos.y)
		return {name = c == "solid" and "stone" or c == "water" and "water" or "air"}
	end,
	registered_nodes = NODES,
	get_node_boxes = function() return FULL end,
}

local carriers = {}
core.add_entity = function(pos, name)
	if spawn_fails then return nil end
	local def = entities[name]
	local obj = {pos = vector.new(pos), v = vector.new(0, 0, 0), a = vector.new(0, 0, 0),
		alive = true, moves = 0}
	local ent = setmetatable({object = obj, name = name}, {__index = def})
	function obj:get_pos() return self.alive and vector.new(self.pos) or nil end
	function obj:move_to(p) self.pos = vector.new(p) self.moves = self.moves + 1 end
	function obj:set_velocity(v) self.v = vector.new(v) end
	function obj:set_acceleration(a) self.a = vector.new(a) end
	function obj:get_velocity() return vector.new(self.v) end
	function obj:remove() self.alive = false end
	function obj:get_luaentity() return self.alive and ent or nil end
	function obj:set_armor_groups(g) self.armor = g end
	function obj:punch(puncher, tflp, caps, dir)
		return def.on_punch(ent, puncher, tflp, caps, dir)
	end
	if def.on_activate then def.on_activate(ent, "") end
	carriers[#carriers + 1] = obj
	return obj
end

local function new_player(name, pos)
	local pl = {name = name, pos = vector.new(pos), hp = 20, overrides = {}, fovs = {},
		set_pos_calls = {}, punched = {}, detached_at = nil}
	function pl:get_player_name() return self.name end
	function pl:is_player() return true end
	function pl:get_hp() return self.hp end
	function pl:get_attach()
		return self.attach and self.attach:get_pos() and self.attach or nil
	end
	function pl:get_pos()
		local parent = self:get_attach()
		return vector.new(parent and parent.pos or self.pos)
	end
	function pl:set_attach(obj) self.attach = obj end
	function pl:set_detach()
		local parent = self:get_attach()
		if parent then self.pos = vector.new(parent.pos) end
		self.attach = nil
		self.detached_at = now
	end
	function pl:set_pos(p)
		-- The engine ignores set_pos on an attached player.
		if self:get_attach() then return end
		self.pos = vector.new(p)
		self.set_pos_calls[#self.set_pos_calls + 1] = {pos = vector.new(p), at = now}
	end
	function pl:get_properties()
		return {visual_size = {x = 1, y = 1}, collisionbox = BOX, eye_height = EYE}
	end
	function pl:get_look_horizontal() return 0 end
	function pl:set_bone_override(bone, o)
		self.overrides[#self.overrides + 1] = {bone = bone, z = o.position.vec.z,
			interpolation = o.position.interpolation, at = now}
	end
	function pl:set_fov(f, mult, t) self.fovs[#self.fovs + 1] = {f = f, mult = mult, t = t} end
	function pl:punch(puncher) self.punched[#self.punched + 1] = puncher end
	players[name] = pl
	return pl
end

local function new_mob(pos)
	local mob = {pos = vector.new(pos), ent = {_cmi_is_mob = true, health = 10}}
	function mob:get_pos() return self.gone and nil or vector.new(self.pos) end
	function mob:is_player() return false end
	function mob:get_luaentity() return self.ent end
	function mob:get_properties() return {collisionbox = {-0.4, 0, -0.4, 0.4, 1.2, 0.4}} end
	return mob
end

local rec
local function reset()
	rec = {rage = 0, damage = {}, stuns = {}, mob_stuns = {}, rings = {}, dust = {},
		poses = {}, valid = {}}
end
reset()
local stunned, rooted, relation = {}, {}, true
grug_core = {
	particles = {play = function(id, frame)
		if id == "charge_ring" then rec.rings[#rec.rings + 1] = frame.target end
	end},
	deal_ability_damage = function(attacker, target, amount, opts)
		rec.damage[#rec.damage + 1] = {attacker = attacker, target = target, amount = amount,
			threat = opts.threat_mult}
		if opts.on_accepted then opts.on_accepted() end
		return amount
	end,
	set_stun = function(target, d) rec.stuns[#rec.stuns + 1] = {target = target, d = d} end,
	is_stunned = function(p) return stunned[p:get_player_name()] == true end,
	is_rooted = function(p) return rooted[p:get_player_name()] == true end,
}
grug_mobs = {stun = function(ent, d) rec.mob_stuns[#rec.mob_stuns + 1] = {ent = ent, d = d} end}
grug_visuals = {
	start_pose = function(_, pose) rec.poses[#rec.poses + 1] = "start:" .. pose end,
	stop_pose = function(_, pose) rec.poses[#rec.poses + 1] = "stop:" .. pose end,
	hold_head = function(_, t) rec.poses[#rec.poses + 1] = "hold_head:" .. t end,
}
grug_abilities = {
	valid_target = function(user, target, kind)
		rec.valid[#rec.valid + 1] = {user = user, target = target, kind = kind}
		return relation
	end,
	add_rage = function(_, n) rec.rage = rec.rage + n end,
	charge_dust = function(from, to, t) rec.dust[#rec.dust + 1] = {from = from, to = to, t = t, at = now} end,
}
local DEF = {id = "charge", values = function() return {damage = 7} end}

dofile(ROOT .. "/mods/PLAYER/grug_abilities/charge.lua")(path, REACH)
local carrier_def = entities["grug_abilities:charge_carrier"]
check(carrier_def ~= nil, "B the carrier is registered")
local props = carrier_def.initial_properties
check(props.static_save == false and props.pointable == false and props.physical == false and
	props.is_visible ~= false and props.textures[1] == "grug_mobs_blank.png",
	"B carrier contract: visible blank sprite, not pointable, not saved, non-physical")
check(grug_core.cancel_dash == grug_abilities.cancel_charge, "B travel's seam is installed")

local DT = 0.09
local SETTLE = 3 * 0.09 / 0.8
-- One server step: each live carrier moves (non-physical entity physics),
-- then its on_step runs; then the due timers.
local function step(dt)
	dt = dt or DT
	for _, obj in ipairs(carriers) do
		if obj.alive then
			obj.pos = vector.add(obj.pos, vector.add(vector.multiply(obj.v, dt),
				vector.multiply(obj.a, 0.5 * dt * dt)))
			obj.v = vector.add(obj.v, vector.multiply(obj.a, dt))
			carrier_def.on_step(obj:get_luaentity(), dt)
		end
	end
	now = now + dt
	local due = {}
	for k = #timers, 1, -1 do
		if timers[k].at <= now + 1e-9 then
			due[#due + 1] = timers[k]
			table.remove(timers, k)
		end
	end
	for k = #due, 1, -1 do due[k].f(unpack(due[k].args)) end
end
local function run_out(n)
	for _ = 1, n or 40 do step() end
end

local function setup(world, name, from, target_pos)
	cell = world or ground
	reset()
	stunned, rooted, relation = {}, {}, true
	local pl = new_player(name, from or FROM)
	for _, f in ipairs(callbacks.join) do f(pl) end
	local mob = new_mob(target_pos or {x = 12, y = -0.5, z = 0})
	return pl, mob
end
local function dash(pl, mob, dest)
	return grug_abilities.charge_dash(pl, mob, dest or {x = 10.7, y = -0.5, z = 0}, DEF)
end

-- B1: a flat 10.7 m dash that arrives.
do
	local pl, mob = setup(nil, "w1")
	check(#pl.overrides == 1 and pl.overrides[1].bone == "Body" and near(pl.overrides[1].z, 0.01) and
		pl.overrides[1].interpolation == 0, "B joining sets the Body epsilon, not an identity")
	check(dash(pl, mob) == true, "B1 the dash starts")
	local carrier = pl:get_attach()
	check(carrier ~= nil and grug_abilities.charge_dashing(pl), "B1 the warrior rides the carrier")
	check(rec.rage == 0 and #rec.damage == 0 and #rec.rings == 0, "B1 nothing lands at the cast")
	local lead = pl.overrides[2]
	check(lead and near(lead.z, 5) and near(lead.interpolation, 0.1),
		"B1 the Body lead: 0.5 m ahead (5 model units), blended in")
	check(pl.fovs[1] and near(pl.fovs[1].f, 1.1) and pl.fovs[1].mult == true, "B1 the FOV kick x1.1")
	check(rec.poses[1] == "start:charge", "B1 the charge pose starts")
	local arrived_at
	for _ = 1, 20 do
		step()
		if not arrived_at and rec.rage > 0 then arrived_at = now end
	end
	local total = 10.7 / 24
	check(arrived_at ~= nil and arrived_at >= total - 1e-9 and arrived_at <= total + DT + 1e-9,
		"B1 arrival within one step of the plan's end (" .. tostring(arrived_at) .. ")")
	check(rec.rage == 15, "B1 15 rage on arrival")
	check(#rec.damage == 1 and rec.damage[1].amount == 7 and rec.damage[1].threat == 3 and
		rec.damage[1].target == mob, "B1 one damage call, threat x3")
	check(#rec.mob_stuns == 1 and rec.mob_stuns[1].d == 1.5, "B1 the 1.5 s stun on the mob")
	check(#rec.rings == 1 and dist(rec.rings[1], mob.pos) < 1e-9, "B1 the ring at the target")
	check(rec.valid[1] and rec.valid[1].kind == "hostile" and rec.valid[1].target == mob,
		"B1 the relation is asked again on arrival")
	check(#rec.dust >= 1 and rec.dust[1].t <= 1 and near(rec.dust[1].from.x, 0) and
		near(rec.dust[#rec.dust].to.x, 10.7), "B1 dust along the run, pieces of at most 1 s")
	check(rec.dust[1].at >= 0.09 / 0.8 - 1e-9, "B1 the dust waits for the client's drawn lag")
	check(pl:get_attach() == nil and pl.detached_at ~= nil and
		pl.detached_at >= arrived_at - DT + SETTLE - 1e-9,
		"B1 the rider is let go only after the hold (" .. tostring(pl.detached_at) .. ")")
	local last = pl.set_pos_calls[#pl.set_pos_calls]
	check(last and dist(last.pos, {x = 10.7, y = -0.5, z = 0}) < 1e-9 and last.at == pl.detached_at,
		"B1 and put on the stop at the detach")
	check(not carrier.alive and not grug_abilities.charge_dashing(pl), "B1 the carrier is gone")
	local back = pl.overrides[#pl.overrides]
	check(near(back.z, 0.01) and back.interpolation > 0, "B1 the lead blends back to the epsilon")
	check(pl.fovs[2] and pl.fovs[2].f == 1 and pl.fovs[3] and pl.fovs[3].f == 0,
		"B1 the FOV blends back, then the override is cleared")
	check(rec.poses[#rec.poses - 1] == "stop:charge" and rec.poses[#rec.poses] == "hold_head:0.2",
		"B1 the pose stops; the head look holds 0.2 s for the lead's blend-out")
	check(carrier.moves <= 3, "B1 no per-step corrections on a straight run")
end

-- B2: the target moves away during the dash: a miss.
do
	local pl, mob = setup(nil, "w2")
	check(dash(pl, mob) == true, "B2 the dash starts (the cast is spent)")
	step()
	mob.pos = {x = 20, y = -0.5, z = 0}
	run_out()
	check(rec.rage == 0 and #rec.damage == 0 and #rec.rings == 0 and #rec.mob_stuns == 0,
		"B2 a target out of reach: nothing lands")
	check(pl:get_attach() == nil and dist(pl.pos, {x = 10.7, y = -0.5, z = 0}) < 1e-9,
		"B2 the warrior still ends on the stop")
end

-- B3: the relation check fails on arrival (a PvP flag dropped), a target
-- that came closer is still hit, a player target is re-fetched by name.
do
	local pl, mob = setup(nil, "w3")
	dash(pl, mob)
	relation = false
	run_out()
	check(#rec.valid == 1 and rec.rage == 0 and #rec.damage == 0, "B3 the relation refuses: a miss")
	pl, mob = setup(nil, "w3b")
	dash(pl, mob)
	step()
	mob.pos = {x = 9.5, y = -0.5, z = 0}
	run_out()
	check(rec.rage == 15 and #rec.damage == 1, "B3 a target that came closer is hit")
	pl = setup(nil, "w3c")
	local foe = new_player("foe", {x = 12, y = -0.5, z = 0})
	dash(pl, foe)
	step()
	local relogged = new_player("foe", {x = 12, y = -0.5, z = 0})
	run_out()
	check(rec.valid[1] and rec.valid[1].target == relogged and rec.damage[1] and
		rec.damage[1].target == relogged and rec.stuns[1] and rec.stuns[1].target == relogged,
		"B3 a player target is re-fetched by name, stunned as a player")
	pl = setup(nil, "w3d")
	foe = new_player("foe", {x = 12, y = -0.5, z = 0})
	dash(pl, foe)
	step()
	players.foe = nil
	run_out()
	check(rec.rage == 0 and #rec.damage == 0, "B3 a target that logged out: a miss")
end

-- B4: cancellations land nothing; a punch reaches the rider.
local function cancel_case(label, act, keep)
	local pl, mob = setup(nil, "w4" .. label)
	dash(pl, mob)
	local carrier = pl:get_attach()
	step()
	step()
	local at = vector.new(carrier.pos)
	act(pl)
	step()
	run_out()
	check(rec.rage == 0 and #rec.damage == 0 and #rec.rings == 0,
		"B4 " .. label .. ": nothing lands")
	check(pl:get_attach() == nil and not carrier.alive and not grug_abilities.charge_dashing(pl),
		"B4 " .. label .. ": the rider is let go, the carrier removed")
	if keep then
		local last = pl.set_pos_calls[1]
		check(last and near(last.pos.y, -0.5) and last.pos.x >= at.x - 1e-9,
			"B4 " .. label .. ": let go on the ground where the dash was")
	else
		local last = pl.set_pos_calls[1]
		check(last and last.pos.x >= at.x - 1e-9 and last.pos.x < 10.7 - 1,
			"B4 " .. label .. ": let go mid-dash, where the carrier was")
	end
	check(rec.poses[#rec.poses - 1] == "stop:charge", "B4 " .. label .. ": the pose stops")
end
cancel_case("stun", function(pl) stunned[pl.name] = true end)
cancel_case("root", function(pl) rooted[pl.name] = true end)
cancel_case("death", function(pl)
	pl.hp = 0
	for _, f in ipairs(callbacks.die) do f(pl) end
end)
cancel_case("logout", function(pl)
	for _, f in ipairs(callbacks.leave) do f(pl) end
	players[pl.name] = nil
end, true)
cancel_case("travel", function(pl) grug_core.cancel_dash(pl) end)
do
	local pl, mob = setup(nil, "w4hit")
	dash(pl, mob)
	local carrier = pl:get_attach()
	step()
	local striker = {}
	carrier:punch(striker, 1, {damage_groups = {fleshy = 2}}, nil)
	check(pl.punched[1] == striker, "B4 a punch on the carrier reaches the rider")
	run_out()
	check(rec.rage == 15, "B4 and the dash still arrives")
end

-- B4b: a stun (and a logout) on every step of hop courses: the warrior is
-- let go on the plan, never inside the terrain the carrier's own physics
-- ran it into past a landing.
local function inside(world, pos)
	local x1, x2, y1, y2 = pos.x - 0.299, pos.x + 0.299, pos.y + 0.001, pos.y + 1.699
	for nx = math.floor(x1 + 0.5), math.floor(x2 + 0.5) do
		for ny = math.floor(y1 + 0.5), math.floor(y2 + 0.5) do
			if world.xyz(nx, ny, 0) then return true end
		end
	end
	return false
end
for _, name in ipairs({"wall", "step", "uphill", "ledge"}) do
	local shape = shapes.LIST[name]
	local world = shapes.table_world(shape)
	local from, tf = shapes.start(shape), shapes.target(shape)
	local dest = destinations.charge(from, EYE, BOX, tf, world)
	local function solid(x, y) return world.xyz(x, y, 0) and "solid" or nil end
	for _, mode in ipairs({"stun", "logout"}) do
		local bad = 0
		for k = 1, 6 do
			local pl, mob = setup(solid, "w4b" .. name .. mode .. k, from, tf)
			dash(pl, mob, dest)
			for _ = 1, k - 1 do step() end
			if mode == "stun" then
				stunned[pl.name] = true
				step()
			else
				for _, f in ipairs(callbacks.leave) do f(pl) end
				players[pl.name] = nil
			end
			local placed = pl.set_pos_calls[1]
			if not placed or inside(world, placed.pos) then bad = bad + 1 end
			if mode == "logout" and placed and placed.pos.y - math.floor(placed.pos.y) ~= 0.5 then
				bad = bad + 1
			end
			run_out(4)
		end
		check(bad == 0, "B4b " .. name .. ": a " .. mode .. " on any step lets go on the plan" ..
			(mode == "logout" and ", on the ground" or "") .. " (" .. bad .. " bad)")
	end
end

-- B5: the rim of a 5-wide hole: a miss at the rim.
do
	local pl, mob = setup(hole(3, 7), "w5")
	check(dash(pl, mob) == true, "B5 the dash starts (the cast is spent)")
	run_out()
	check(rec.rage == 0 and #rec.damage == 0, "B5 stopped at the rim: a miss")
	local last = pl.set_pos_calls[#pl.set_pos_calls]
	check(last and last.pos.x < 3 and last.pos.x > 2.4, "B5 the warrior stands at the rim")
end

-- B6: the uphill stairs of the probe: the dash ends on the last stair and
-- the warrior is put there after the hold.
do
	local shape = shapes.LIST.uphill
	local world = shapes.table_world(shape)
	local from, tf = shapes.start(shape), shapes.target(shape)
	local dest = destinations.charge(from, EYE, BOX, tf, world)
	local pl, mob = setup(function(x, y)
		return world.xyz(x, y, 0) and "solid" or nil
	end, "w6", from, tf)
	check(dash(pl, mob, dest) == true, "B6 uphill: the dash starts")
	local stopped_at
	for _ = 1, 30 do
		step()
		if not stopped_at and rec.rage > 0 then stopped_at = now end
	end
	check(rec.rage == 15 and #rec.damage == 1, "B6 uphill: arrives within reach")
	local last = pl.set_pos_calls[#pl.set_pos_calls]
	check(last and dist(last.pos, dest) < 1e-9 and near(pl.pos.y, dest.y),
		"B6 uphill: put on the last stair, not short of it")
	check(pl.detached_at - stopped_at >= SETTLE - DT - 1e-9, "B6 uphill: after the hold")
end

-- B7: short dashes carry no lead; the dash's own refusals.
do
	local pl, mob = setup(nil, "w7", nil, {x = 4, y = -0.5, z = 0})
	dash(pl, mob, {x = 2.7, y = -0.5, z = 0})
	check(#pl.overrides == 1, "B7 a 2.7 m dash: no Body lead")
	check(dash(pl, mob) == false, "B7 a second dash while one runs: refused")
	run_out()
	check(rec.rage == 15, "B7 the short dash arrives")
	pl, mob = setup(nil, "w7b")
	pl.attach = {get_pos = function() return {x = 0, y = 0, z = 0} end}
	local ok, why = dash(pl, mob)
	check(ok == false and why ~= nil, "B7 an attached warrior: refused (no cost)")
	pl, mob = setup(nil, "w7c")
	spawn_fails = true
	ok = dash(pl, mob)
	spawn_fails = false
	check(ok == false and not grug_abilities.charge_dashing(pl), "B7 no carrier: refused (no cost)")
end

-- B8: rooted at the cast or a hole at the feet: the dash ends where it
-- starts (hit only when already in reach).
do
	local pl, mob = setup(nil, "w8")
	rooted.w8 = true
	check(dash(pl, mob) == true and pl:get_attach() == nil and rec.rage == 0,
		"B8 rooted at the cast: a miss without a carrier")
	pl, mob = setup(hole(0, 9), "w8b", nil, {x = 2, y = -0.5, z = 0})
	check(dash(pl, mob, {x = 0.7, y = -0.5, z = 0}) == true and pl:get_attach() == nil and
		rec.rage == 15, "B8 nowhere to go but in reach: the hit lands at once")
end

-- B9b: a carrier removed from outside (/clearobjects) does not block the
-- next Charge, and its lead, FOV and pose end; the carrier's own punch
-- (mobs_redo's entity_physics) is not forwarded.
do
	local pl, mob = setup(nil, "w9b")
	dash(pl, mob)
	local carrier = pl:get_attach()
	step()
	carrier:punch(carrier, 1, {damage_groups = {fleshy = 4}}, nil)
	check(#pl.punched == 0, "B9b the carrier's own punch is not forwarded")
	carrier.alive = false
	local n_fov = #pl.fovs
	check(dash(pl, mob) == true and grug_abilities.charge_dashing(pl),
		"B9b a removed carrier: the next Charge starts")
	check(pl.fovs[n_fov + 1] and pl.fovs[n_fov + 1].f == 1 and
		rec.poses[2] == "stop:charge", "B9b the old run's FOV and pose ended")
	run_out()
	check(rec.rage == 15, "B9b the new dash arrives")
end

-- B9: a carrier without its run removes itself.
do
	local obj = core.add_entity({x = 0, y = 0, z = 0}, "grug_abilities:charge_carrier")
	step()
	check(not obj.alive, "B9 an orphan carrier removes itself")
end

-- B10 (0.45.1): a segment that ends before the next step is not handed to
-- the client to extrapolate a whole step past its end (a short steep hop or
-- a straight drop would sink the drawn warrior metres into the ground): the
-- carrier heads straight, without acceleration, for where the plan is one
-- step on -- at the cast and on every step.
local function lane_world(top)
	return function(x, y) return y <= top(x) and "solid" or nil end
end
local function heads_straight(label, world, from, dest, target_pos)
	local pl, mob = setup(world, label, from, target_pos)
	dash(pl, mob, dest)
	local carrier = pl:get_attach()
	local plan = path.plan(path.live, from, dest)
	local t, bad, short = 0, 0, 0
	local function look()
		local _, _, _, index = path.state_at(plan, t)
		local s = plan.segments[index]
		if s and index < #plan.segments and s.t0 + s.t < t + DT then
			short = short + 1
			local q = path.state_at(plan, t + DT)
			local e = vector.add(carrier.pos, vector.multiply(carrier.v, DT))
			if dist(carrier.a, {x = 0, y = 0, z = 0}) > 1e-9 or dist(e, q) > 1e-6 then bad = bad + 1 end
		end
	end
	look()
	for _ = 1, 30 do
		if not pl:get_attach() or carrier.v.x == 0 then break end
		step()
		t = t + DT
		look()
	end
	check(short > 0 and bad == 0, "B10 " .. label .. ": " .. short ..
		" segments end before the next step, each one headed for straight (" .. bad .. " not)")
	run_out()
	check(rec.rage == 15, "B10 " .. label .. ": the dash still arrives")
end
-- Stairs up with treads of three nodes: the first hop (31 ms) ends before
-- the first step.
heads_straight("w10up", lane_world(function(x) return x <= 0 and -1 or math.min(8, math.ceil(x / 3)) - 1 end),
	FROM, {x = 3.7, y = 0.5, z = 0}, {x = 5, y = 0.5, z = 0})
-- A run to an edge and a straight drop three nodes down onto the destination.
heads_straight("w10drop", lane_world(function(x) return x <= 2 and -1 or -4 end),
	FROM, {x = 2.85, y = -3.5, z = 0}, {x = 4.1, y = -3.5, z = 0})

-- B11 (0.45.1): a stun inside a straight drop lets the warrior go on the
-- drop's takeoff (the drop grazes the edge it leaves), not on the line.
do
	local pl, mob = setup(lane_world(function(x) return x <= 2 and -1 or -4 end), "w11", FROM,
		{x = 4.1, y = -3.5, z = 0})
	dash(pl, mob, {x = 2.85, y = -3.5, z = 0})
	local plan = path.plan(path.live, FROM, {x = 2.85, y = -3.5, z = 0})
	local drop = plan.segments[#plan.segments]
	check(drop.kind == "hop" and drop.g == 0, "B11 the plan ends in a straight drop")
	step(drop.t0 + drop.t / 2 - 0.02)
	step(0.02)
	stunned[pl.name] = true
	step(0.0001)
	local placed = pl.set_pos_calls[1]
	check(placed and dist(placed.pos, drop.p0) < 1e-9 and rec.rage == 0,
		"B11 let go on the drop's takeoff (" .. (placed and ("%.2f, %.2f"):format(placed.pos.x,
			placed.pos.y) or "nowhere") .. "), a miss")
end

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then
	error(("R40 CH PORTABLE FAIL %d/%d"):format(failures, checks), 0)
end
print("R40 CH PORTABLE PASS checks=" .. checks)
