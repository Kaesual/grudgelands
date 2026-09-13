-- Compact production-module fixture for the AIR-flight near-ground nudge.

return function(repo)
repo = assert(repo, "repository root required")

local nodes = {}
local probe_calls = 0
local environment = {math = math}
setmetatable(environment, {__index = _G})
environment.grug_mobs = {}
environment.core = {
	registered_nodes = {
		air = {walkable = false},
		stone = {walkable = true},
		water = {walkable = false, groups = {liquid = 3}},
	},
	get_node_or_nil = function(pos)
		probe_calls = probe_calls + 1
		local value = nodes[pos.x .. ":" .. pos.y .. ":" .. pos.z]
		if value == false then return nil end
		return {name = value or "air"}
	end,
}
local grug_mobs = environment.grug_mobs

local production = assert(loadfile(repo .. "/mods/ENTITIES/grug_mobs/flight.lua"))
setfenv(production, environment)
production()

local function check(value, message)
	if not value then error("flight fixture: " .. message, 0) end
end

local function near(value, expected)
	return math.abs(value - expected) < 0.000001
end

local function object(id, y, velocity, box)
	local obj = {id = id, pos = {x = 0, y = y, z = 0}, velocity = velocity,
		box = box or {-0.3, 0, -0.3, 0.3, 0.6, 0.3}, writes = 0}
	function obj:get_id() return self.id end
	function obj:get_pos() return self.pos end
	function obj:get_velocity() return self.velocity end
	function obj:get_properties() return {collisionbox = self.box} end
	function obj:set_velocity(value) self.velocity = value; self.writes = self.writes + 1 end
	return obj
end

local function mob(obj)
	return {fly = true, fly_in = "air", state = "walk", object = obj, temp = {}}
end

local function ground(y, value)
	nodes["0:" .. y .. ":0"] = value or "stone"
end

ground(0)
local original_calls = 0
local wrapped = {do_custom = function(_, _, moveresult)
	original_calls = original_calls + 1
	return moveresult
end}
grug_mobs.install_flight_nudge(wrapped)
local high = mob(object(0, 8, {x = 2, y = 0.4, z = -1}))
check(wrapped.do_custom(high, 0.75, "original-result") == "original-result"
	and original_calls == 1, "production wrapper did not preserve callback")
check(high.object.velocity.x == 2 and high.object.velocity.z == -1,
	"horizontal velocity changed")
check(near(high.object.velocity.y, -0.2), "high hover did not ease downward")

local low = mob(object(0, 1.5, {x = 0, y = -0.3, z = 0}))
grug_mobs.flight_nudge_tick(low, 0.75)
check(near(low.object.velocity.y, 0.25), "low flyer did not avoid ground")

local canyon = mob(object(0, 8, {x = 0, y = 0, z = 0}))
grug_mobs.flight_nudge_tick(canyon, 0.75)
check(near(canyon.temp.grug_flight_bias, -0.6), "initial descent bias differs")
nodes = {}
canyon.object.pos.y = 9
grug_mobs.flight_nudge_tick(canyon, 0.75)
check(near(canyon.temp.grug_flight_bias, -0.65)
	and near(canyon.object.velocity.y, -0.65),
	"loaded canyon did not retain bounded gentle descent")

ground(0)
local attack = mob(object(0, 8, {x = 0, y = 0.4, z = 0}))
wrapped.do_custom(attack, 0.75, true) -- acquisition happens after do_custom
check(near(attack.object.velocity.y, -0.2), "pre-acquisition nudge differs")
attack.state = "attack"
-- In-reach mobs_redo movement preserves Y; the next custom tick must remove
-- the controller's own -0.6 while leaving the native +0.4 baseline intact.
grug_mobs.flight_nudge_tick(attack, 0.05)
check(near(attack.object.velocity.y, 0.4)
	and attack.temp.grug_flight_bias == nil,
	"same-step attack acquisition retained flight bias")

local replaced = mob(object(0, 8, {x = 0, y = 1.25, z = 0}))
replaced.state = "attack"
replaced.temp.grug_flight_bias = -0.6
replaced.temp.grug_flight_applied_y = -0.6
grug_mobs.flight_nudge_tick(replaced, 0.75)
check(replaced.object.velocity.y == 1.25 and replaced.temp.grug_flight_bias == nil,
	"authoritative attack Y was overwritten")

nodes = {}
ground(0)
local moved = mob(object(0, 8, {x = 0, y = 0, z = 0}))
grug_mobs.flight_nudge_tick(moved, 0.75)
check(moved.temp.grug_flight_clearance ~= nil, "terrain cache was not primed")
moved.state = "attack"
grug_mobs.flight_nudge_tick(moved, 0.05)
check(moved.temp.grug_flight_clearance == nil
	and moved.temp.grug_flight_probe_left == nil,
	"steering owner retained stale terrain cache")
moved.object.pos.x = 10
moved.state = "walk"
nodes["10:7:0"] = false
local writes_before_release = moved.object.writes
grug_mobs.flight_nudge_tick(moved, 0.05)
check(moved.object.writes == writes_before_release
	and moved.temp.grug_flight_clearance == nil,
	"release over unknown column reused stale terrain")

local rooted = mob(object(0, 8, {x = 0, y = 0, z = 0}))
rooted._grug_root_left = 1
grug_mobs.flight_nudge_tick(rooted, 0.75)
check(rooted.object.writes == 0, "rooted flyer received a nudge")

local ground_mob = mob(object(0, 8, {x = 0, y = 0, z = 0}))
ground_mob.fly = false
grug_mobs.flight_nudge_tick(ground_mob, 0.75)
check(ground_mob.temp.grug_flight_probe_left == nil, "ground mob gained state")

local water = mob(object(0, 8, {x = 0, y = 0, z = 0}))
water.fly_in = "default:water_source"
grug_mobs.flight_nudge_tick(water, 0.75)
check(water.temp.grug_flight_probe_left == nil, "water flyer gained state")

nodes["0:7:0"] = false
local unloaded = mob(object(0, 8, {x = 0, y = -0.4, z = 0}))
grug_mobs.flight_nudge_tick(unloaded, 0.75)
check(unloaded.object.writes == 0 and unloaded.temp.grug_flight_clearance == nil,
	"unknown ground changed native velocity")
local unknown_release = mob(object(0, 8, {x = 0, y = -0.6, z = 0}))
unknown_release.temp.grug_flight_bias = -0.6
unknown_release.temp.grug_flight_applied_y = -0.6
grug_mobs.flight_nudge_tick(unknown_release, 0.25)
check(near(unknown_release.object.velocity.y, -0.4)
	and near(unknown_release.temp.grug_flight_bias, -0.4),
	"unknown ground did not gradually remove owned bias")

nodes = {}
ground(0, "water")
local over_water = mob(object(0, 1.5, {x = 0, y = -0.3, z = 0}))
grug_mobs.flight_nudge_tick(over_water, 0.75)
check(near(over_water.object.velocity.y, 0.25),
	"liquid surface did not protect air flyer")

local fresh = mob(object(0, 8, {x = 0, y = 0, z = 0}))
check(fresh.temp.grug_flight_bias == nil and fresh.temp.grug_flight_probe_left == nil,
	"controller state did not start transient and empty")

nodes = {}
probe_calls = 0
local staggered = mob(object(0, 5, {x = 0, y = 0, z = 0}))
grug_mobs.flight_nudge_tick(staggered, 0.1)
check(probe_calls == 0, "first probe was not staggered")
grug_mobs.flight_nudge_tick(staggered, 0.7)
check(probe_calls == 12, "probe was not bounded to twelve nodes")
grug_mobs.flight_nudge_tick(staggered, 0.1)
check(probe_calls == 12, "probe was not throttled")

return "schema\tgrug_wp40_flight_nudge_v1\n"
	.. "cases\thigh,low,canyon,unknown,water,attack,root,nonair,lifecycle,probe\n"
	.. "result\tpass\n"
end
