-- Round 45 playtest fix 7 portable test (LuaJIT): fliers flap in the air and
-- the crabs climb a one-node step. Loads the REAL grug_mobs/flight.lua under
-- small stubs, with mobs_redo's set_animation (and its swing lock),
-- check_for, flight_check and do_states' stand branch cut out of the vendored
-- mobs/api.lua, and checks:
--   I  which prototypes get the fly-clip rule: an air flier (fly_in "air" or
--      a list holding it) with a fly clip, a dragon (`keep_flying`) too; a
--      swimmer, a flier without a fly clip and a ground mob do not;
--   A  in the air the stand branch, a walk, a run and a forced stand
--      (stop_attack) play the fly clip; on walkable ground the clip asked
--      for plays; in water (out of its element) too; other clips pass;
--   L  the swing lock still holds a stand back while a punch clip runs and
--      the fly clip follows once it ended;
--   D  a dragon on the ground (`fly` off) keeps its clips, with `fly` on it
--      flies;
--   H  grug_mobs/init.lua installs the rule right after mobs:register_mob;
--   S  every mob definition in grug_mobs/ steps up a node (stepheight > 1)
--      or never steps (0, the swimmers); the Shore Crab and Reef Lurker are
--      above 1.
-- Usage (repo root): luajit tools/r45_pt7/portable_test.lua [REPO]
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
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"), path)
	local text = handle:read("*a")
	handle:close()
	return text
end
local function noop() end

-- The mobs_redo pieces, cut out of the vendored api.lua.
local api = read("mods/ENTITIES/mobs/api.lua")
local function cut(from, to, label)
	local a = api:find(from, 1, true)
	check(a ~= nil, label .. ": start anchor in api.lua")
	local b, e = api:find(to, a, true)
	check(b ~= nil, label .. ": end anchor in api.lua")
	return api:sub(a, e)
end
local mob_class = {}
local api_env = setmetatable({mob_class = mob_class, random = function(a) return a or 0 end},
	{__index = _G})
local function load_api(source, label)
	local chunk = assert(loadstring(source, "=" .. label))
	setfenv(chunk, api_env)
	return chunk()
end
load_api(cut("function mob_class:set_animation(anim, force)", "\nend\n", "set_animation"),
	"set_animation")
api_env.check_for = load_api(cut("local function check_for(look_for, look_inside)",
	"\nend\n", "check_for") .. "return check_for\n", "check_for")
load_api(cut("function mob_class:flight_check()", "\nend\n", "flight_check"), "flight_check")
local stand_branch = load_api("return function(self, s, yaw)\n" ..
	cut("\tif self.state == \"stand\" then", "\telseif self.state == \"jump\" then", "stand branch")
		:gsub("\telseif self.state == \"jump\" then$", "") .. "\tend\nend\n", "stand branch")
function mob_class:set_velocity(v) self.velocity = v end
function mob_class:set_yaw(yaw) return yaw end

local us_time = 1000000
local function advance(seconds) us_time = us_time + math.floor(seconds * 1e6 + 0.5) end
local NODES = {
	air = {walkable = false, drawtype = "airlike", groups = {}},
	["default:dirt_with_grass"] = {walkable = true, drawtype = "normal", groups = {}},
	["default:water_source"] = {walkable = false, drawtype = "liquid", groups = {water = 3}},
}
core = {
	registered_entities = {},
	registered_nodes = NODES,
	registered_items = NODES,
	get_us_time = function() return us_time end,
	get_objects_inside_radius = function() return {} end,
}
grug_mobs = {}
mobs = {}
dofile(repo .. "/mods/ENTITIES/grug_mobs/flight.lua")

-- A prototype as mobs:register_mob leaves it, the rule installed on it.
local function register(name, fields)
	local proto = setmetatable(fields, {__index = mob_class})
	core.registered_entities[name] = proto
	return grug_mobs.install_flier_animation(name), proto
end
-- A live mob of `name`: an object that records its clip.
local function spawn(name, fields)
	local self = setmetatable({temp = {}, state = "stand", walk_chance = 0,
		standing_in = "air", standing_on = "air"}, {__index = core.registered_entities[name]})
	self.object = {set_animation = function(obj, range) obj.range = range end}
	for k, v in pairs(fields or {}) do self[k] = v end
	return self
end

-- The gull's clips (gull.lua) and the eagle's own punch clip (eagle.lua).
local GULL = {stand_start = 1, stand_end = 100, walk_start = 110, walk_end = 130,
	run_start = 140, run_end = 160, fly_start = 140, fly_end = 160, speed_normal = 30}
local EAGLE = {stand_start = 0, stand_end = 100, walk_start = 150, walk_end = 250,
	run_start = 150, run_end = 250, fly_start = 150, fly_end = 250,
	punch_start = 250, punch_end = 350, speed_normal = 100}

-- I. which prototypes get the rule
eq((register("t:gull", {fly = true, fly_in = "air", animation = GULL})), true, "I an air flier")
eq((register("t:eagle", {fly = true, fly_in = "air", animation = EAGLE})), true, "I the eagle")
eq((register("t:glowwing", {fly = true, fly_in = {"air"}, animation = GULL})), true,
	"I fly_in as a list holding air")
eq((register("t:dragon", {fly = false, keep_flying = true, fly_in = "air", animation = GULL})),
	true, "I a dragon (keep_flying)")
eq((register("t:kraken", {fly = true, fly_in = "default:water_source", animation = GULL})),
	false, "I a swimmer keeps mobs_redo's clips")
eq((register("t:wisp", {fly = true, fly_in = "air", animation = {stand_start = 40,
	stand_end = 80, walk_start = 1, walk_end = 40}})), false, "I no fly clip, no rule")
eq((register("t:boar", {fly = false, fly_in = "air", animation = GULL})), false, "I a ground mob")
local _, kraken = register("t:kraken", {fly = true, fly_in = "default:water_source", animation = GULL})
eq(rawget(kraken, "set_animation"), nil, "I the swimmer's prototype keeps mobs_redo's method")

-- A. in the air the wings beat
local bird = spawn("t:gull")
stand_branch(bird, {x = 0, y = 0, z = 0}, 0)
eq(bird.animation_current, "fly", "A the stand state in the air flies")
eq(bird.object.range and bird.object.range.x, 140, "A the fly clip's frames play")
eq(bird.velocity, 0, "A it still holds its place")
for _, clip in ipairs({"walk", "run"}) do
	bird = spawn("t:gull")
	bird:set_animation(clip)
	eq(bird.animation_current, "fly", "A " .. clip .. " in the air flies")
end
bird = spawn("t:gull")
bird:set_animation("stand", true)
eq(bird.animation_current, "fly", "A a forced stand (stop_attack) in the air flies")
bird = spawn("t:glowwing")
bird:set_animation("stand")
eq(bird.animation_current, "fly", "A a list fly_in in the air flies")

bird = spawn("t:gull", {standing_on = "default:dirt_with_grass"})
stand_branch(bird, {x = 0, y = 0, z = 0}, 0)
eq(bird.animation_current, "stand", "A on the ground it stands")
bird:set_animation("walk")
eq(bird.animation_current, "walk", "A on the ground it walks")
bird.standing_on = "air"
bird:set_animation("walk")
eq(bird.animation_current, "fly", "A off the ground again it flies")
bird = spawn("t:gull", {standing_in = "default:water_source", standing_on = "default:water_source"})
bird:set_animation("stand")
eq(bird.animation_current, "stand", "A in water (out of its element) mobs_redo's clip")
bird = spawn("t:eagle")
bird:set_animation("punch")
eq(bird.animation_current, "punch", "A a punch passes unchanged")

local swimmer = spawn("t:kraken", {standing_in = "default:water_source",
	standing_on = "default:water_source"})
swimmer:set_animation("stand")
eq(swimmer.animation_current, "stand", "A a swimmer stands")

-- L. the swing lock (100 frames at 100 fps: 1 s)
bird = spawn("t:eagle")
bird:set_animation("punch")
advance(0.5)
bird:set_animation("stand")
eq(bird.animation_current, "punch", "L inside the swing the stand waits")
bird:set_animation("run")
eq(bird.animation_current, "punch", "L inside the swing the run waits")
advance(0.6)
bird:set_animation("stand")
eq(bird.animation_current, "fly", "L after the swing it flies")
bird:set_animation("punch")
advance(0.1)
bird:set_animation("stand", true)
eq(bird.animation_current, "fly", "L a forced stand passes the lock")

-- D. the dragon switches `fly` at runtime
local dragon = spawn("t:dragon", {fly = false})
dragon:set_animation("stand", true)
eq(dragon.animation_current, "stand", "D flight off: its clip plays")
dragon.fly = true
dragon:set_animation("stand", true)
eq(dragon.animation_current, "fly", "D flight on, in the air: it flies")
dragon.standing_on = "default:dirt_with_grass"
dragon:set_animation("walk", true)
eq(dragon.animation_current, "walk", "D flight on, on the ground: it walks")

-- H. the hook in init.lua
local init = read("mods/ENTITIES/grug_mobs/init.lua")
local at_register = init:find("\tmobs:register_mob(name, def)\n", 1, true)
local at_hook = init:find("\tgrug_mobs.install_flier_animation(name)\n", 1, true)
check(at_register and at_hook and at_register < at_hook
	and not init:sub(at_register, at_hook):find("\nend\n", 1, true),
	"H installed in register_mob right after mobs:register_mob")
local at_flight = init:find('dofile(modpath .. "/flight.lua")', 1, true)
local at_first_mob = init:find('dofile(modpath .. "/shore_crab.lua")', 1, true)
check(at_flight and at_first_mob and at_flight < at_first_mob, "H flight.lua loads before the mobs")

-- S. stepheights: every value written in a file grug_mobs/init.lua loads
local seen = 0
for file in init:gmatch('dofile%(modpath %.%. "/([%w_]+%.lua)"%)') do
	local text = read("mods/ENTITIES/grug_mobs/" .. file)
	for value in text:gmatch("stepheight%s*=%s*([%d%.]+)") do
		seen = seen + 1
		local v = tonumber(value)
		check(v == 0 or v > 1, "S " .. file .. " stepheight " .. value ..
			" steps up a node or never steps")
	end
end
check(seen > 30, "S the definitions were read (" .. seen .. " values)")
local crab = read("mods/ENTITIES/grug_mobs/shore_crab.lua")
local crab_step = tonumber(crab:match("stepheight%s*=%s*([%d%.]+)"))
check(crab_step and crab_step > 1, "S the crabs climb a one-node step (" .. tostring(crab_step) .. ")")
-- The engine's rule (collision.cpp): bottom + stepheight strictly above the
-- obstacle's top. A crab on a node top (y 0.5) before a one-node step (top 1.5).
local function steps_up(stepheight) return 0.5 + stepheight > 1.5 end
check(not steps_up(1) and steps_up(crab_step or 0), "S 1 fails the engine's rule, the crab's value passes")

if failures > 0 then
	error(("R45 PT7 PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
end
print(("R45 PT7 PORTABLE PASS checks=%d"):format(checks))
