-- Round 41 lane MOB portable test (LuaJIT; round41-plan.md §2 rulings 1 and 2,
-- §4.1): the walk animation on scripted walks, and kings and Generals that
-- hold their seat. Loads the REAL grug_mobs/patrol.lua, guard.lua, bosses.lua,
-- start_villagers.lua and start_npcs.lua under a small engine model (the
-- placement harness of tools/r31_g), with the touched mobs_redo methods cut
-- out of the vendored mobs/api.lua (set_animation with its swing lock,
-- stop_attack, flight_check and do_states' stand branch).
--
--   luajit tools/r41_mob/portable_test.lua [REPO]
--
--   W  walk_toward sets the walk clip at once, from standing; a second nudge
--      writes nothing; a flier in the air flies and on the ground walks; a
--      swimmer without a fly clip walks; a definition without a walk clip
--      keeps its clip; a mob without an animation table is left alone; the
--      swing lock holds the write back until the punch clip ends;
--   V  an idle villager walker's amble (the real start_villagers.lua tick)
--      starts with the walk clip;
--   R  a royal guard's follow (the real royal_guard_tick): the walk clip at
--      the nudge, re-asserted on every step after the swing lock let go,
--      a hit taken mid-follow is dropped and the guard walks on at once;
--   D  mobs_redo's stand branch never starts a random walk for a king or a
--      General (`_grug_no_wander` on the prototype), a post guard still
--      does;
--   S  the seat: a king and a General carry the post fields of their throne
--      socket (a bodyguard and a royal guard none); pushed away he walks back
--      with the walk clip and faces the socket's authored way; he does not
--      leave a fight for the seat, walks back after it and after a leash
--      reset; his bodyguards stand within the follow distance of the seat.
-- Prints "R41 MOB PORTABLE PASS checks=<n>" or the failures.

local repo = arg and arg[1] or "."
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function near(actual, expected, label)
	return check(type(actual) == "number" and math.abs(actual - expected) < 1e-6,
		label .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end

local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return out
end
table.copy = copy

local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"), path)
	local text = handle:read("*a")
	handle:close()
	return text
end
local function noop() end

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
local mob_class = {}
local api_env = setmetatable({mob_class = mob_class, random = function(a) return a or 0 end,
	grug_obstacle = {cancel_path_request = noop, forget_no_path = noop},
	grug_nav = {forget = noop}},
	{__index = _G})
local function load_api(source, label)
	local chunk = assert(loadstring(source, "=" .. label))
	setfenv(chunk, api_env)
	return chunk()
end
load_api(cut("function mob_class:set_animation(anim, force)", "\nend\n", "set_animation"),
	"set_animation")
load_api(cut("function mob_class:stop_attack()", "\nend\n", "stop_attack"), "stop_attack")
api_env.check_for = load_api(cut("local function check_for(look_for, look_inside)",
	"\nend\n", "check_for") .. "return check_for\n", "check_for")
load_api(cut("function mob_class:flight_check()", "\nend\n", "flight_check"), "flight_check")
-- do_states' stand branch, from its state test to the jump state.
local stand_branch = load_api("return function(self, s, yaw)\n" ..
	cut("\tif self.state == \"stand\" then", "\telseif self.state == \"jump\" then", "stand branch")
		:gsub("\telseif self.state == \"jump\" then$", "") .. "\tend\nend\n", "stand branch")

-- The rest of a mob's methods, reduced to what the ticks use. Yaw and
-- velocity follow mobs_redo: set_velocity builds from the object's yaw.
function mob_class:set_yaw(yaw, delay)
	if (delay or 0) == 0 then
		self.object.yaw = yaw
		self.delay = 0
	else
		self.target_yaw, self.delay = yaw, delay
	end
	return yaw
end
function mob_class:yaw_to_pos(target, rot, delay)
	local pos = self.object:get_pos()
	local yaw = core.dir_to_yaw({x = target.x - pos.x, y = 0, z = target.z - pos.z}) +
		(rot or 0) - (self.rotate or 0)
	return self:set_yaw(yaw, delay)
end
function mob_class:set_velocity(v)
	local yaw = self.object.yaw or 0
	self.velocity = v
	self.object.vel = {x = -math.sin(yaw) * v, y = 0, z = math.cos(yaw) * v}
end

-- ---------------------------------------------------------------------------
-- The engine model (tools/r31_g's placement harness) plus a clock and mob
-- objects that count their animation writes.
-- ---------------------------------------------------------------------------
grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
local us_time = 1000000
local function advance(seconds) us_time = us_time + math.floor(seconds * 1e6 + 0.5) end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local catalog = dofile(wp40 .. "/r31_pvp_catalog.lua")
local source = dofile(wp40 .. "/source/simple_map.lua")
local json = dofile(repo .. "/tools/r28_b1/json.lua")
local M = dofile(repo .. "/mods/ENTITIES/grug_mobs/pvp_garrison.lua")
local G = M.new(catalog, json.parse(read("mods/ENTITIES/grug_mobs/data/pvp_names.json")))
local zone_of = {}
for _, zone in ipairs(source.zones) do zone_of[zone.id] = zone end

_G.core = {}
local build = dofile(wp40 .. "/r31_pvp_poi_blueprint.lua")
local fortress_sockets, fortress_race = (function()
	local bp = build({}, {art = {kind = "pvp_fortress", faction = "accord", turns = 0},
		blueprint_schema = "r41_mob_test", numeric_id = 1})
	return bp.landmarks.sockets, bp.landmarks.race
end)()

local serial, steps, loaded, logs = {}, {}, {}, {}
local gametime, walltime = 5000, 1700000000
os.time = function() return walltime end -- luacheck: ignore
local store = {}
local storage = {
	get_string = function(_, k) return store[k] or "" end,
	set_string = function(_, k, v) store[k] = v end,
}
local live = {}
local NODES = {
	air = {walkable = false, drawtype = "airlike", groups = {}},
	["default:dirt_with_grass"] = {walkable = true, drawtype = "normal", groups = {}},
	["default:water_source"] = {walkable = false, drawtype = "liquid", groups = {water = 3}},
}
_G.core = setmetatable({
	registered_entities = {},
	registered_nodes = NODES,
	serialize = function(value) serial[#serial + 1] = copy(value); return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and copy(serial[index]) or nil
	end,
	log = function(level, text) logs[#logs + 1] = level .. ": " .. text end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
	after = noop,
	get_us_time = function() return us_time end,
	get_gametime = function() return gametime end,
	pos_to_string = function(p) return ("(%d,%d,%d)"):format(p.x, p.y, p.z) end,
	get_node_or_nil = function() return {name = "default:dirt_with_grass"} end,
	compare_block_status = function() return false end,
	dir_to_yaw = function(d) return math.atan2(-d.x, d.z) end,
	get_mod_storage = function() return storage end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	is_player = function(obj) return type(obj) == "table" and obj.is_player ~= nil and obj:is_player() end,
	get_objects_inside_radius = function(pos, radius)
		local out = {}
		for _, entity in ipairs(live) do
			local p = entity.object.valid and entity.object.pos
			if p then
				local dx, dy, dz = p.x - pos.x, p.y - pos.y, p.z - pos.z
				if dx * dx + dy * dy + dz * dz <= radius * radius then
					out[#out + 1] = entity.object
				end
			end
		end
		return out
	end,
}, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return noop end
	return nil
end})
_G.vector = {new = function(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x, y = y, z = z}
end}

local function new_object(pos)
	local object = {pos = copy(pos), valid = true, yaw = 0, vel = {x = 0, y = 0, z = 0}, writes = 0}
	function object:get_pos() return self.valid and copy(self.pos) or nil end
	function object:remove() self.valid = false end
	function object:is_player() return false end
	function object:get_yaw() return self.yaw end
	function object:get_velocity() return copy(self.vel) end
	function object:set_velocity(v) self.vel = copy(v) end
	function object:set_animation() self.writes = self.writes + 1 end
	return object
end

local function activate(name, staticdata, pos)
	local def = assert(core.registered_entities[name], name)
	local object = new_object(pos)
	local entity = setmetatable({name = name, object = object, state = "stand",
		temp = {}, rotate = 0, standing_on = "default:dirt_with_grass", standing_in = "air"},
		{__index = function(_, key)
			local value = def[key]
			if value ~= nil then return value end
			return mob_class[key]
		end})
	function object:get_luaentity() return self.valid and entity or nil end
	for k, v in pairs(core.deserialize(staticdata) or {}) do entity[k] = v end
	live[#live + 1] = entity
	return object, entity
end
core.add_entity = function(pos, name, staticdata) return (activate(name, staticdata, pos)) end

_G.grug_core = setmetatable({particles = {play = noop}}, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return noop end
	return nil
end})
dofile(repo .. "/mods/CORE/grug_core/settlement_sockets.lua")
-- The Accord: the fortress's seat race (human) has a capital in this test.
local CAPITAL_ANCHOR = {x = 400, y = 20, z = 400}
local IDENTITIES = {}
for faction, races in pairs(catalog.FACTION_RACES) do
	for _, race in ipairs(races) do IDENTITIES[#IDENTITIES + 1] = {race_id = race, faction_id = faction} end
end
grug_core.start_identities = function() return IDENTITIES end
grug_core.start_anchor = function() return nil end
grug_core.capital_anchor = function(faction, race)
	if faction == "accord" and race == "human" then return copy(CAPITAL_ANCHOR) end
end
grug_core.start_ready = function() return false end
grug_core.opposing_faction = function(id) return id == "accord" and "throng" or "accord" end
_G.grug_zones = {get = function(id) return zone_of[id] end}

-- The shared navigation (Round 42), reduced to "walk straight": its own
-- tests are tools/r42_nv1 and tools/r42_nv2.
local nav_stub = {
	fixed_step = function() return nil end,
	combat_step = function() return nil end,
	command = noop,
	forget = function(temp) if temp then temp.grug_nav = nil end end,
	steer = noop, -- walk_toward's mark (Round 42 ST; tools/r42_st)
}
_G.mobs = {mob_class = mob_class, grug_obstacle = {}, grug_nav = nav_stub}
function mobs:remove(entity) entity.object:remove() end
local function place_on_ground(object, pos) object.pos = copy(pos) end
_G.grug_mobs = {
	names = dofile(repo .. "/tools/r38_b1/names_stub.lua").shipped(repo),
	storage = storage,
	pvp_garrison = G,
	place_on_ground = place_on_ground,
	clear_boss_activity = noop,
	register_dragon_bosses = noop,
	LEADER = {size = 1.15, hp = 1.5},
	set_tier = function(entity, tier) entity._grug_tier = tier end,
	relevel = function(entity, level) entity._grug_level = level end,
	refresh_visual = noop,
	register_mob = function(name, def) core.registered_entities[name] = def end,
}
dofile(repo .. "/mods/ENTITIES/grug_mobs/npc_doors.lua")
dofile(repo .. "/mods/ENTITIES/grug_mobs/patrol.lua")
-- The route cache (Round 42 NV3) caches nothing here: its own test is
-- tools/r42_nv3, and the stub navigation only walks straight.
dofile(repo .. "/mods/ENTITIES/grug_mobs/routes.lua")
grug_mobs.route_settlement = noop
dofile(repo .. "/mods/ENTITIES/grug_mobs/guard.lua")
dofile(repo .. "/mods/ENTITIES/grug_mobs/bosses.lua")
grug_mobs.noncombatant = function(def) return def end
grug_mobs.set_plain_tag = noop
function mobs:register_mob(name, def) core.registered_entities[name] = def end
dofile(repo .. "/mods/ENTITIES/grug_mobs/start_villagers.lua")
steps = {}
dofile(repo .. "/mods/ENTITIES/grug_mobs/start_npcs.lua")

-- A small Accord capital of the human race: the king on his dais facing -z
-- (the hall's door), two throne guards, two idle spots for one walker.
local CAPITAL_SOCKETS = {
	{id = "king", role = "king", x = 0, y = 1, z = 20, dir = {x = 0, z = -1}},
	{id = "throne_guard_west", role = "guard_post", x = -7, y = 1, z = 17, dir = {x = 0, z = -1}},
	{id = "throne_guard_east", role = "guard_post", x = 7, y = 1, z = 17, dir = {x = 0, z = -1}},
	{id = "hall_idle_west", role = "idle", x = -20, y = 1, z = 0, dir = {x = 1, z = 0}},
	{id = "hall_idle_east", role = "idle", x = 20, y = 1, z = 0, dir = {x = -1, z = 0}, spawn = false},
}
grug_core.register_settlement_sockets("r41_capital", "human", CAPITAL_ANCHOR,
	CAPITAL_SOCKETS, "r41_capital")
local FORTRESS_ANCHOR = {x = 0, y = 20, z = -900}
grug_core.register_settlement_sockets("pvp_fortress_accord", fortress_race,
	FORTRESS_ANCHOR, fortress_sockets, "pvp_fortress_accord")
for _, fn in ipairs(loaded) do fn() end
local npc_steps = steps
gametime = gametime + 5
for _, fn in ipairs(npc_steps) do fn(5) end

local function holder(key, socket)
	for _, entity in ipairs(live) do
		if entity.object.valid and entity._grug_start == key and entity._grug_socket == socket then
			return entity
		end
	end
end
local function socket_of(key, id)
	for _, socket in ipairs(grug_core.settlement_sockets_at(key)) do
		if socket.id == id then return socket end
	end
end

-- One server step of a mob: its do_custom, then the movement it set.
local STEP = 0.1
local function step(entity)
	local result = entity.do_custom(entity, STEP)
	local o = entity.object
	if o.valid then
		o.pos = {x = o.pos.x + o.vel.x * STEP, y = o.pos.y, z = o.pos.z + o.vel.z * STEP}
	end
	advance(STEP)
	return result
end
local function run(entity, seconds)
	for _ = 1, math.floor(seconds / STEP + 0.5) do step(entity) end
end
local function dist2(entity, x, z)
	local p = entity.object.pos
	return (p.x - x) * (p.x - x) + (p.z - z) * (p.z - z)
end

-- A bare mob for the walk_toward checks.
local HUMANOID = {stand_start = 0, stand_end = 79, walk_start = 168, walk_end = 187,
	run_start = 168, run_end = 187, punch_start = 189, punch_end = 198, speed_normal = 30}
local function bare(animation, extra)
	local entity = setmetatable({name = "r41:bare", object = new_object({x = 0, y = 0, z = 0}),
		state = "stand", temp = {}, rotate = 0, walk_velocity = 1.2, animation = animation,
		standing_on = "default:dirt_with_grass", standing_in = "air"},
		{__index = mob_class})
	for k, v in pairs(extra or {}) do entity[k] = v end
	if animation then entity:set_animation("stand", true) end
	entity.object.writes = 0
	return entity
end
local ORIGIN = {x = 0, y = 0, z = 0}

------------------------------------------------------------------------------
-- W. walk_toward sets the clip.
------------------------------------------------------------------------------
do
	local mob = bare(HUMANOID)
	grug_mobs.walk_toward(mob, 10, 0, ORIGIN)
	eq(mob.animation_current, "walk", "W1 from standing the walk clip plays at once")
	eq(mob.object.writes, 1, "W1 one animation write")
	eq(mob.state, "walk", "W1 state walk")
	grug_mobs.walk_toward(mob, 10, 3, ORIGIN)
	grug_mobs.walk_animation(mob)
	eq(mob.object.writes, 1, "W2 a mob that walks gets no further write")

	-- The gull's clips (gull.lua): a ground waddle and a flight loop.
	local GULL = {stand_start = 1, stand_end = 100, walk_start = 110, walk_end = 130,
		run_start = 140, run_end = 160, fly_start = 140, fly_end = 160, speed_normal = 30}
	local bird = bare(GULL, {fly = true, fly_in = "air", standing_on = "air"})
	grug_mobs.walk_toward(bird, 10, 0, ORIGIN)
	eq(bird.animation_current, "fly", "W3 a flier in the air flies")
	bird.standing_on = "default:dirt_with_grass"
	grug_mobs.walk_toward(bird, 10, 0, ORIGIN)
	eq(bird.animation_current, "walk", "W3 a flier on the ground walks")
	bird.standing_in = "default:water_source"
	bird.fly_in = {"air", "default:water_source"}
	grug_mobs.walk_toward(bird, 10, 0, ORIGIN)
	eq(bird.animation_current, "fly", "W3 on ground in water it flies (do_states' rule)")

	-- A swimmer (kraken.lua): fly in water, one loop as walk, no fly clip.
	local fish = bare({stand_start = 1, stand_end = 41, walk_start = 1, walk_end = 41,
		speed_normal = 25}, {fly = true, fly_in = "default:water_source",
		standing_in = "default:water_source", standing_on = "default:water_source"})
	grug_mobs.walk_toward(fish, 10, 0, ORIGIN)
	eq(fish.animation_current, "walk", "W4 a swimmer without a fly clip walks")

	local still = bare({stand_start = 0, stand_end = 10, speed_normal = 15})
	grug_mobs.walk_toward(still, 10, 0, ORIGIN)
	eq(still.animation_current, "stand", "W5 no walk clip: the clip it has stays")
	eq(still.object.writes, 0, "W5 and nothing is written")

	local plain = bare(nil)
	check(pcall(grug_mobs.walk_toward, plain, 10, 0, ORIGIN), "W6 no animation table: no error")
	eq(plain.state, "walk", "W6 it still walks")

	-- The swing lock: a punch clip of 9 frames at 30 fps holds 0.3 s.
	local fighter = bare(HUMANOID)
	fighter:set_animation("punch")
	advance(0.1)
	grug_mobs.walk_toward(fighter, 10, 0, ORIGIN)
	eq(fighter.animation_current, "punch", "W7 inside the swing the walk waits")
	advance(0.25)
	grug_mobs.walk_toward(fighter, 10, 0, ORIGIN)
	eq(fighter.animation_current, "walk", "W7 after the swing the next nudge walks")
end

------------------------------------------------------------------------------
-- V. The idle villager walker's amble.
------------------------------------------------------------------------------
do
	local villager = holder("r41_capital", "hall_idle_west")
	check(villager ~= nil, "V the walker is placed")
	if villager then
		eq(villager._grug_walker, true, "V the first idle socket is a walker")
		villager:set_animation("stand", true)
		villager.object.writes = 0
		-- Away from its spot: the amble walks it back.
		villager.object.pos.x = villager.object.pos.x + 8
		run(villager, 1.1)
		eq(villager.state, "walk", "V the amble walks")
		eq(villager.animation_current, "walk", "V with the walk clip at once")
	end
end

------------------------------------------------------------------------------
-- D. mobs_redo's stand branch never starts a random walk from the seat.
------------------------------------------------------------------------------
do
	for _, name in ipairs({"grug_mobs:king_human", "grug_mobs:general_accord"}) do
		eq(core.registered_entities[name]._grug_no_wander, true, "D " .. name .. " holds its seat")
		eq(core.registered_entities[name].randomly_turn, false, "D " .. name .. " turns no random way")
	end
	check(core.registered_entities["grug_mobs:guard_accord"]._grug_no_wander == nil,
		"D a post guard is not marked")
	-- random(100) answers 1 here: every walk_chance would start a walk.
	api_env.random = function() return 1 end
	local king = bare(HUMANOID, {walk_chance = 50, _grug_no_wander = true, order = ""})
	stand_branch(king, {x = 0, y = 0, z = 0}, 0)
	eq(king.state, "stand", "D the seated king stays standing")
	local guard = bare(HUMANOID, {walk_chance = 50, order = ""})
	stand_branch(guard, {x = 0, y = 0, z = 0}, 0)
	eq(guard.state, "walk", "D a post guard still starts its walk (the branch is live)")
	api_env.random = function(a) return a or 0 end
end

------------------------------------------------------------------------------
-- S. The seat.
------------------------------------------------------------------------------
local function seat_case(label, key, leader_socket, retinue)
	local leader = holder(key, leader_socket)
	if not check(leader ~= nil, label .. " the leader is placed") then return end
	local socket = socket_of(key, leader_socket)
	near(leader._grug_post_x, socket.pos.x, label .. " post x is the seat")
	near(leader._grug_post_z, socket.pos.z, label .. " post z is the seat")
	near(leader._grug_post_yaw, socket.yaw, label .. " post yaw is the socket's authored facing")
	for _, id in ipairs(retinue) do
		local member = holder(key, id)
		check(member ~= nil and member._grug_post_x == nil,
			label .. " " .. id .. " carries no post (it follows)")
	end
	leader.temp.grug_royal_cooldown = 1e9 -- no signature casts in this test
	local seat_x, seat_z, yaw = socket.pos.x, socket.pos.z, socket.yaw

	-- Pushed six nodes off his seat.
	leader.object.pos = {x = seat_x + 6, y = socket.pos.y, z = seat_z}
	leader:set_animation("stand", true)
	run(leader, 1.1)
	eq(leader.state, "walk", label .. " pushed away he walks")
	eq(leader.animation_current, "walk", label .. " with the walk clip")
	check(leader.object.vel.x < -1, label .. " toward the seat")
	run(leader, 8)
	check(dist2(leader, seat_x, seat_z) <= 4, label .. " back at the seat")
	eq(leader.state, "stand", label .. " standing")
	near(leader.object.yaw, yaw, label .. " facing the authored way")
	eq(leader.object.vel.x, 0, label .. " still")

	-- A fight eight nodes off: he stays in it, then walks back.
	leader.object.pos = {x = seat_x, y = socket.pos.y, z = seat_z + 8}
	leader.attack = {get_pos = function() return {x = seat_x, y = socket.pos.y, z = seat_z + 10} end}
	leader.state = "attack"
	leader.object.vel = {x = 0, y = 0, z = 0}
	run(leader, 3)
	check(dist2(leader, seat_x, seat_z) > 60, label .. " no walk home while fighting")
	leader:stop_attack()
	run(leader, 10)
	check(dist2(leader, seat_x, seat_z) <= 4, label .. " after the fight back at the seat")
	near(leader.object.yaw, yaw, label .. " after the fight facing the authored way")

	-- A leash reset: the evade run (aggro.lua) ends four nodes out, the seat
	-- tick takes him the rest of the way.
	leader.object.pos = {x = seat_x - 4, y = socket.pos.y, z = seat_z}
	leader.temp.grug_evading = {started = 0}
	run(leader, 2)
	check(dist2(leader, seat_x, seat_z) >= 15, label .. " the evade owns the run")
	leader.temp.grug_evading = nil
	run(leader, 8)
	check(dist2(leader, seat_x, seat_z) <= 4, label .. " after the leash reset back at the seat")
	near(leader.object.yaw, yaw, label .. " after the leash reset facing the authored way")
	return leader, socket
end

seat_case("S king", "r41_capital", "king", {"throne_guard_west", "throne_guard_east"})
local general, general_socket = seat_case("S General", "pvp_fortress_accord", "general",
	{"bodyguard_west", "bodyguard_east"})
if general then
	for _, id in ipairs({"bodyguard_west", "bodyguard_east"}) do
		local s = socket_of("pvp_fortress_accord", id)
		check(dist2({object = {pos = s.pos}}, general_socket.pos.x, general_socket.pos.z) <= 25,
			"S " .. id .. " stands within the follow distance of the seat")
	end
end

------------------------------------------------------------------------------
-- R. The royal follow.
------------------------------------------------------------------------------
do
	-- S's leash reset sent the retinue back to its slots; the heartbeat
	-- places it again.
	check(holder("r41_capital", "throne_guard_west") == nil,
		"R the leash reset took the retinue off (start_npcs.lua)")
	gametime = gametime + 5
	for _, fn in ipairs(npc_steps) do fn(5) end
	local king = holder("r41_capital", "king")
	local guard = holder("r41_capital", "throne_guard_west")
	if check(king ~= nil and guard ~= nil, "R the king and his guard are placed") then
		local kp = king.object.pos
		guard.object.pos = {x = kp.x - 15, y = kp.y, z = kp.z}
		guard:set_animation("stand", true)
		guard.temp.grug_royal_follow = 0.95
		step(guard)
		eq(guard.temp.grug_royal_follow_active, true, "R1 fifteen nodes out the follow starts")
		eq(guard.animation_current, "walk", "R1 the nudge sets the walk clip")
		local writes = guard.object.writes
		eq(step(guard), false, "R2 the follow owns the step")
		eq(guard.object.writes, writes, "R2 a step that walks writes nothing")

		-- The swing-lock case: a punch clip still running, then a hit drops
		-- the target; stop_attack's forced stand passes, the walk waits.
		guard:set_animation("punch")
		guard.attack = {get_pos = function() return {x = 0, y = 0, z = 0} end}
		guard.state = "attack"
		step(guard)
		eq(guard.attack, nil, "R3 the hit's target is dropped")
		eq(guard.state, "walk", "R3 and the guard walks on at once")
		check(guard.velocity == guard.walk_velocity, "R3 at walk speed")
		eq(guard.animation_current, "stand", "R3 the swing lock holds the walk clip back")
		run(guard, 0.4)
		eq(guard.animation_current, "walk", "R4 the step after the lock re-asserts the walk")
		check(guard.temp.grug_royal_follow_active == true, "R4 still following")
	end
end

print(("R41 MOB portable test: %d checks, %d failures"):format(checks, failures))
if failures > 0 then error("R41 MOB PORTABLE FAIL", 0) end
print("R41 MOB PORTABLE PASS checks=" .. checks)
