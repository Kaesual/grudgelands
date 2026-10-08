-- Round 42 lane ST portable test (round42-plan.md §2 ruling 25): no random
-- stops on our routes, and mobs_redo's fence stop only for blocking nodes.
-- Loads the REAL mobs/grug_nav.lua (the steer mark and its clock) and
-- grug_mobs/patrol.lua (walk_toward, the patrols' route_tick on walk_fixed,
-- with the navigation's search reduced to "walk straight"), and cuts the
-- REAL do_states walk branch, get_nodes and do_jump out of the vendored
-- mobs/api.lua. Checks:
--   S  the random stop: a walker one of our movers drives (the nudge
--      primitive, and a patrol on route_tick) is never stood by it, at any
--      phase between the mover's tick and do_states' and at several server
--      steps; a free wanderer still is, at once; once the mover lets go, the
--      stop is back within the hold; the stops at a fence and at a cliff
--      still stop a driven walker; every walk-state write in our mob mods is
--      walk_toward's (the one signal);
--   F  facing_fence: a wall torch, a wall sign and air are no fence; a real
--      fence, a wall, a connected wall, a castle stonewall and a fence gate,
--      closed or open (both walkable), are;
--   J  the jump logic for real fences is unchanged: no jump at a fence, a
--      turn after three blocked counts, a jump onto a plain block; at a wall
--      torch it neither jumps nor turns.
-- Usage (repo root): luajit tools/r42_st/portable_test.lua [REPO]
-- Prints "R42 ST PORTABLE PASS checks=<n>" or raises.
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
local floor, sin, cos, sqrt = math.floor, math.sin, math.cos, math.sqrt
local function noop() end

-- ---------------------------------------------------------------------------
-- The engine pieces the code under test reads.
-- ---------------------------------------------------------------------------
local nodes = {}
local function reg(name, def)
	def.name = name
	def.drawtype = def.drawtype or "normal"
	def.groups = def.groups or {}
	-- The engine's registration fills the default (builtin register.lua).
	if def.walkable == nil then def.walkable = true end
	nodes[name] = def
end
-- walkable as the real registrations set it (nil: the default, true).
reg("air", {walkable = false, drawtype = "airlike"})
reg("default:stone", {})
reg("default:dirt", {})
reg("default:torch_wall", {walkable = false, drawtype = "mesh"}) -- torch.lua
reg("default:sign_wall_wood", {walkable = false, drawtype = "nodebox"}) -- nodes.lua
reg("grug_materials:iron_sign_wall", {walkable = false, drawtype = "nodebox"})
reg("default:fence_wood", {drawtype = "fencelike"})
reg("default:fence_rail_wood", {drawtype = "fencelike"})
reg("walls:cobble", {drawtype = "nodebox"})
reg("grug_decor:darkage_stone_brick_wall", {walkable = true, drawtype = "nodebox"})
reg("grug_decor:castle_stonewall", {})
reg("doors:gate_wood_closed", {drawtype = "mesh"}) -- doors/init.lua: no walkable
reg("doors:gate_wood_open", {drawtype = "mesh"}) -- field, open or closed
reg("doors:door_wood_a", {drawtype = "mesh"})

local world = {}
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local function set(x, y, z, name) world[key(x, y, z)] = name end
local function get_node(p)
	return {name = world[key(floor(p.x + 0.5), floor(p.y + 0.5), floor(p.z + 0.5))]
		or "air"}
end

_G.core = {
	registered_nodes = nodes,
	get_node = get_node,
	get_node_or_nil = get_node,
	get_us_time = function() return 0 end,
	log = noop,
	after = noop,
}
_G.minetest = core
_G.vector = {new = function(x, y, z) return {x = x, y = y, z = z} end}

-- ---------------------------------------------------------------------------
-- The real navigation; its search reduced to "walk straight" (its own tests
-- are tools/r42_nv1-nv3). The steer mark and the clock are the real ones.
-- ---------------------------------------------------------------------------
local nav = dofile(repo .. "/mods/ENTITIES/mobs/grug_nav.lua")
local walk_nav = setmetatable({
	fixed_step = function() return nil end,
	command = noop,
	forget = function(temp) if temp then temp.grug_nav = nil end end,
}, {__index = nav})
_G.mobs = {grug_nav = walk_nav, grug_obstacle = {
	mob_cbox = function(self) return self._grug_cbox end,
	cancel_path_request = noop,
}}
_G.grug_mobs = {npc_doors = {}}
dofile(repo .. "/mods/ENTITIES/grug_mobs/patrol.lua")

-- ---------------------------------------------------------------------------
-- The mobs_redo pieces, cut out of the vendored api.lua.
-- ---------------------------------------------------------------------------
local api = read("mods/ENTITIES/mobs/api.lua")
local function cut(from, to, label)
	local a = api:find(from, 1, true)
	check(a ~= nil, label .. ": start anchor in api.lua")
	local b, e = api:find(to, a, true)
	check(b ~= nil, label .. ": end anchor in api.lua")
	return api:sub(a, e)
end
local rolls = 1 -- what random(100) answers: 1 is a stop whatever stand_chance
local mob_class = {}
local api_env = setmetatable({
	mob_class = mob_class,
	grug_nav = nav,
	random = function(a, b)
		if b then return a end
		return rolls
	end,
	sin = sin, cos = cos,
	mob_cbox = function(self) return self._grug_cbox end,
	node_ok = function(pos, fallback)
		local node = get_node(pos)
		if nodes[node.name] then return node end
		return nodes[fallback or "default:dirt"]
	end,
}, {__index = _G})
local function load_api(source, label)
	local chunk = assert(loadstring(source, "=" .. label))
	setfenv(chunk, api_env)
	return chunk()
end
-- do_states' walk branch, from its state test to the runaway state.
local walk_src = cut("\telseif self.state == \"walk\" and not self.following then",
	"\telseif self.state == \"runaway\" then", "walk branch")
	:gsub("\telseif self.state == \"runaway\" then$", "")
local walk_branch = load_api("return function(self, yaw)\n\tif false then\n" ..
	walk_src .. "\tend\nend\n", "walk branch")
load_api(cut("function mob_class:get_nodes()", "\nend\n", "get_nodes"), "get_nodes")
load_api(cut("function mob_class:do_jump()", "\nend\n", "do_jump"), "do_jump")
check(walk_src:find("grug_nav.steered(self)", 1, true) ~= nil,
	"S0 the walk branch asks the steer mark")

-- A mob, reduced to what the pieces read. Yaw and velocity follow mobs_redo:
-- set_velocity builds from the object's yaw.
function mob_class:set_yaw(yaw, delay)
	if (delay or 0) == 0 then
		self.object.yaw = yaw
		self.delay = 0
	else
		self.target_yaw, self.delay = yaw, delay
	end
	self.turns = (self.turns or 0) + 1
	return yaw
end
function mob_class:yaw_to_pos(target)
	local p = self.object.pos
	return self:set_yaw(math.atan2(-(target.x - p.x), target.z - p.z), 0)
end
function mob_class:set_velocity(v)
	local yaw = self.object.yaw
	self.velocity = v
	self.object.vel = {x = -sin(yaw) * v, y = self.object.vel.y, z = cos(yaw) * v}
end
function mob_class:set_animation(name) self.animation_current = name end
function mob_class:flight_check() return false end
function mob_class:get_velocity()
	local v = self.object.vel
	return sqrt(v.x * v.x + v.z * v.z)
end
function mob_class:mob_sound() end
local function mob(x, z, fields)
	local m = setmetatable({
		state = "walk", stand_chance = 30, walk_velocity = 1.2, jump_height = 4,
		walk_chance = 50, randomly_turn = false, sounds = {},
		standing_on = "default:dirt", standing_in = "air",
		_grug_cbox = {-0.3, -0.85, -0.3, 0.3, 0.85, 0.3}, temp = {},
	}, {__index = mob_class})
	m.object = {
		pos = {x = x, y = 1.35, z = z}, vel = {x = 0, y = 0, z = 0}, yaw = 0,
		get_pos = function(o) return {x = o.pos.x, y = o.pos.y, z = o.pos.z} end,
		get_velocity = function(o) return {x = o.vel.x, y = o.vel.y, z = o.vel.z} end,
		set_velocity = function(o, v) o.vel = {x = v.x, y = v.y, z = v.z} end,
		set_acceleration = noop,
		get_yaw = function(o) return o.yaw end,
		get_luaentity = function() return m end,
	}
	for k, v in pairs(fields or {}) do m[k] = v end
	return m
end

-- ---------------------------------------------------------------------------
-- S. The random stop.
-- ---------------------------------------------------------------------------
-- Runs `m` for `seconds` at server step `dt`: the mover's own once-a-second
-- decision (`mover`, from `phase` s into its second) and do_states' once a
-- second; returns how often do_states stood it and when it first did.
local function run(m, seconds, dt, phase, mover, stop_mover_at)
	local acc, st, t, stands, first = phase, 0, 0, 0, nil
	for _ = 1, floor(seconds / dt + 0.5) do
		t = t + dt
		nav.begin_server_step(dt)
		if mover and not (stop_mover_at and t >= stop_mover_at) then
			acc = acc + dt
			if acc >= 1 - 1e-9 then
				local e = acc
				acc = 0
				mover(m, e)
			end
		end
		st = st + dt
		if st >= 1 - 1e-9 then
			st = 0
			if m.state == "walk" then
				walk_branch(m, m.object.yaw)
				if m.state == "stand" then
					stands = stands + 1
					first = first or t
					-- mobs_redo's stand state starts the walk again (walk_chance).
					m.state = "walk"
					m:set_velocity(m.walk_velocity)
				end
			end
		end
		local p, v = m.object.pos, m.object.vel
		p.x, p.z = p.x + v.x * dt, p.z + v.z * dt
	end
	return stands, first
end
local function nudger(m)
	local p = m.object.pos
	grug_mobs.walk_toward(m, p.x + 10, p.z, p)
end

do
	-- S1 a walker the nudge drives is never stood, at any phase and step.
	local worst = 0
	for _, dt in ipairs({0.05, 0.09, 0.1, 0.2}) do
		for phase10 = 0, 9 do
			local m = mob(0, 0)
			local stands = run(m, 60, dt, phase10 / 10, nudger)
			if stands > worst then worst = stands end
		end
	end
	check(worst == 0, "S1 a driven walker is never randomly stopped (" .. worst .. ")")
	-- S2 a free wanderer (nobody nudges it) is stood by the first do_states.
	local m = mob(0, 0)
	m:set_velocity(m.walk_velocity)
	local stands, first = run(m, 10, 0.09, 0, nil)
	check(stands >= 9 and first and first <= 1.1, "S2 a free wanderer still stops at every do_states (" ..
		stands .. ")")
	-- S2b ...and only at its stand chance: a roll above it walks on.
	rolls = 31
	m = mob(0, 0)
	stands = run(m, 10, 0.09, 0, nil)
	check(stands == 0, "S2b a roll above stand_chance walks on")
	rolls = 1
	-- S3 the mover lets go (arrived, the post's wander): the stop is back
	-- within the hold and the next do_states.
	local latest = 0
	for phase10 = 0, 9 do
		m = mob(0, 0)
		local _, at = run(m, 20, 0.09, phase10 / 10, nudger, 10)
		local after = (at or 99) - 10
		if after > latest then latest = after end
		check(at ~= nil and at > 10, "S3 no stop while driven (phase " .. phase10 .. ")")
	end
	check(latest <= nav.STEER_HOLD + 1.1, "S3 the stop is back after the hold (" ..
		latest .. " s)")
	-- S4 the patrols' route_tick (walk_fixed, the shared fixed walk under the
	-- routes and the amble): a loop of waypoints, never stood.
	local worst4 = 0
	for phase10 = 0, 9, 3 do
		m = mob(0, 0)
		m.route = {points = {{x = 20, y = 0, z = 0}, {x = 20, y = 0, z = 20},
			{x = 0, y = 0, z = 20}, {x = 0, y = 0, z = 0}}, wp = 1}
		local wps = 0
		local tick = function(s, e)
			local before = s.route.wp
			grug_mobs.route_tick(s, e, s.route.points, s.route, "wp", false)
			if s.route.wp ~= before then wps = wps + 1 end
		end
		local stands4 = run(m, 90, 0.09, phase10 / 10, tick)
		if stands4 > worst4 then worst4 = stands4 end
		check(wps >= 3, "S4 the patrol walks its loop (" .. wps .. " waypoints)")
	end
	check(worst4 == 0, "S4 a patrol on route_tick is never randomly stopped (" ..
		worst4 .. ")")
	-- S5 the real holds stay: a driven walker facing a blocking fence, or at
	-- a cliff, is stood.
	m = mob(0, 0)
	nudger(m)
	m.facing_fence = true
	walk_branch(m, m.object.yaw)
	check(m.state == "stand" and m.velocity == 0, "S5 a driven walker stops at a fence")
	m = mob(0, 0)
	nudger(m)
	m.at_cliff = true
	rolls = 100
	walk_branch(m, m.object.yaw)
	check(m.state == "stand", "S5 ...and at a cliff")
	rolls = 1
	-- S6 one signal: every walk-state write in our mob mods is walk_toward's.
	-- The mods' files: init.lua and every file it (or a loaded file) names.
	local writers = {}
	for _, dir in ipairs({"mods/ENTITIES/grug_mobs", "mods/ENTITIES/grug_traders"}) do
		local queue, seen = {"init.lua"}, {["init.lua"] = true}
		local i = 1
		while queue[i] do
			local handle = io.open(repo .. "/" .. dir .. "/" .. queue[i], "rb")
			if handle then
				local text = handle:read("*a")
				handle:close()
				for name in text:gmatch("\"/([%w_]+%.lua)\"") do
					if not seen[name] then
						seen[name] = true
						queue[#queue + 1] = name
					end
				end
				local n = 0
				for line in (text .. "\n"):gmatch("([^\n]*)\n") do
					n = n + 1
					if line:find("state = \"walk\"", 1, true) and not line:match("^%s*%-%-") then
						writers[#writers + 1] = dir .. "/" .. queue[i] .. ":" .. n
					end
				end
			end
			i = i + 1
		end
		check(i > 10 or dir:find("traders"), "S6 " .. dir .. ": its files read (" .. (i - 1) .. ")")
	end
	check(#writers == 1 and writers[1]:find("grug_mobs/patrol.lua", 1, true) ~= nil,
		"S6 the walk state is written only by walk_toward (" .. #writers .. ")")
	local patrol = read("mods/ENTITIES/grug_mobs/patrol.lua")
	local body = patrol:match("function grug_mobs%.walk_toward%(.-\nend\n")
	check(body and body:find("nav.steer(self)", 1, true) and
		body:find("self.state = \"walk\"", 1, true), "S6 ...which marks the mob")
end

-- ---------------------------------------------------------------------------
-- F. facing_fence (get_nodes): the node in front at the feet.
-- ---------------------------------------------------------------------------
-- The mob stands at the origin on the ground (y 0, feet at 0.5) facing +z
-- (yaw 0); the node in front of its feet is (0, 1, 1).
local function ground()
	world = {}
	for x = -2, 2 do
		for z = -2, 2 do set(x, 0, z, "default:dirt") end
	end
end
local function facing(name)
	ground()
	if name then set(0, 1, 1, name) end
	local m = mob(0, 0)
	m:get_nodes()
	return m.facing_fence, m
end
do
	for _, name in ipairs({"default:torch_wall", "default:sign_wall_wood",
			"grug_materials:iron_sign_wall"}) do
		check(facing(name) == false, "F1 " .. name .. " is no fence")
	end
	check(facing(nil) == false and facing("default:stone") == false,
		"F1 air and a plain block are no fence")
	check(facing("doors:door_wood_a") == false, "F1 a door is no fence (no name match)")
	for _, name in ipairs({"default:fence_wood", "default:fence_rail_wood",
			"walls:cobble", "grug_decor:darkage_stone_brick_wall",
			"grug_decor:castle_stonewall", "doors:gate_wood_closed",
			"doors:gate_wood_open"}) do
		check(facing(name) == true, "F2 " .. name .. " is a fence")
	end
	local _, m = facing("default:torch_wall")
	check(m.looking_at == "default:torch_wall", "F3 get_nodes saw the torch in front")
end

-- ---------------------------------------------------------------------------
-- J. do_jump with the new facing_fence.
-- ---------------------------------------------------------------------------
local function jumper(front)
	ground()
	if front then set(0, 1, 1, front) end
	local m = mob(0, 0)
	m:set_velocity(m.walk_velocity)
	m:get_nodes()
	m.turns = 0
	return m
end
do
	-- J1 a real fence: no jump, and the third blocked count turns the mob.
	local m = jumper("default:fence_wood")
	local jumped = false
	for _ = 1, 3 do
		if m:do_jump() then jumped = true end
		m.object.vel.y = 0
	end
	check(not jumped and m.object.vel.y == 0, "J1 no jump at a real fence")
	check(m.turns == 1, "J1 ...a turn after three blocked counts (" .. m.turns .. ")")
	-- J2 a closed gate and a wall the same.
	for _, name in ipairs({"doors:gate_wood_closed", "walls:cobble"}) do
		m = jumper(name)
		jumped = false
		for _ = 1, 3 do
			if m:do_jump() then jumped = true end
		end
		check(not jumped and m.turns == 1, "J2 " .. name .. ": no jump, a turn")
	end
	-- J3 a plain block with room above: a jump.
	m = jumper("default:stone")
	check(m:do_jump() == true and m.object.vel.y == m.jump_height, "J3 a jump onto a block")
	-- J4 a wall torch: no fence, so no turn; no jump either (no block to
	-- climb), and the walk goes on through it.
	m = jumper("default:torch_wall")
	jumped = false
	for _ = 1, 4 do
		if m:do_jump() then jumped = true end
	end
	check(not jumped and m.turns == 0 and m.jump_count == nil,
		"J4 a wall torch neither jumps nor turns the mob")
	-- J5 ...and the walk branch does not stand it (a walker driven or not).
	rolls = 100
	m = jumper("default:torch_wall")
	walk_branch(m, m.object.yaw)
	check(m.state == "walk", "J5 a walker in front of a wall torch walks on")
	rolls = 1
end

print("R42 ST portable test: " .. checks .. " checks, 0 failures")
print("R42 ST PORTABLE PASS checks=" .. checks)
