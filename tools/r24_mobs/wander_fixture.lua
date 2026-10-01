-- Round 24 Lane D portable fixture (LuaJIT or Lua 5.1): the wander leash
-- (ruling 19) in the real grug_mobs/aggro.lua, run through its one-second
-- leash_tick on stub entities.
--
--   luajit tools/r24_mobs/wander_fixture.lua <repo>
--
-- A nudge is grug_mobs.walk_toward (patrol.lua), recorded here. Checks:
--   * an idle free-roaming mob is steered home beyond WANDER_RADIUS and left
--     alone inside it, standing or walking;
--   * it is never steered while fighting, fleeing, following or evading, so
--     pursuit keeps the ambient policy (no chase leash): a damage-pursuit mob
--     chasing a moving target 200 nodes from home is neither nudged nor reset
--     while incoming damage sustains the fight;
--   * camp members keep the 20-node roam cap and patrollers none;
--   * rares, bosses, summons, royals, no-leash actors, NPCs, swimmers and
--     tamed mobs are never steered by it.
local repo = assert(arg[1], "usage: wander_fixture.lua <repo>")

local failures, checks = 0, 0
local function check(ok, message)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. message)
	end
	return ok
end

local now = 1000
local nudges, resets = {}, 0
_G.core = {is_player = function(object) return object and object.is_player_ref == true end}
_G.vector = {distance = function(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end}
_G.grug_core = {
	mono_time = function() return now end,
	recheck_switch = function() end,
	prune_engagement = function() end,
	clear_threat = function() end,
}
_G.grug_mobs = {
	walk_toward = function(self, x, z) nudges[#nudges + 1] = {self = self, x = x, z = z} end,
	idle_health_tick = function() end,
	place_on_ground = function() end,
	-- Round 28 Lane A1 road/town push; this fixture checks the leash only.
	roam_avoid_tick = function() end,
}
dofile(repo .. "/mods/ENTITIES/grug_mobs/aggro.lua")
local original_reset = grug_mobs.leash_reset
grug_mobs.leash_reset = function(self)
	resets = resets + 1
	return original_reset(self)
end

local function mob(fields)
	local self = {type = "animal", state = "walk", health = 20, hp_max = 20,
		_grug_home = {x = 0, y = 10, z = 0}, temp = {}}
	for key, value in pairs(fields or {}) do self[key] = value end
	local pos = self.pos or {x = 0, y = 10, z = 0}
	self.object = {get_pos = function() return pos end}
	self.set_pos = function(p) pos = p end
	self.stop_attack = function(s) s.attack = nil; s.state = "stand" end
	return self
end

-- One leash_tick second; returns whether the mob was nudged home.
local function tick(self)
	local before = #nudges
	now = now + 1
	grug_mobs.leash_tick(self, 1)
	local nudged = #nudges > before
	if nudged then
		local n = nudges[#nudges]
		check(n.x == self._grug_home.x and n.z == self._grug_home.z,
			"a nudge steers toward the spawn point")
	end
	return nudged
end

local R = grug_mobs.WANDER_RADIUS
check(R == 32, "wander radius is 32 nodes")

-- Free roamers, idle: steered only beyond the radius.
for _, state in ipairs({"stand", "walk"}) do
	check(not tick(mob({state = state, pos = {x = R - 1, y = 10, z = 0}})),
		state .. ": inside the wander radius, left alone")
	check(not tick(mob({state = state, pos = {x = R, y = 10, z = 0}})),
		state .. ": on the wander radius, left alone")
	check(tick(mob({state = state, pos = {x = R + 1, y = 10, z = 0}})),
		state .. ": beyond the wander radius, steered home")
	check(tick(mob({state = state, pos = {x = 150, y = 10, z = -150}})),
		state .. ": far out, steered home")
	check(not tick(mob({state = state, pos = {x = 20, y = 80, z = 20}})),
		state .. ": height above home does not count")
end
check(tick(mob({type = "monster", state = "walk", pos = {x = 0, y = 10, z = 60}})),
	"a hostile free roamer is leashed too")

-- Not idle: never steered by the wander leash.
local far = {x = 200, y = 10, z = 0}
check(not tick(mob({state = "runaway", pos = far})), "fleeing is not wandering")
check(not tick(mob({state = "walk", following = {}, pos = far})),
	"following is not wandering")
check(not tick(mob({state = "attack", attack = {}, pos = far})),
	"fighting is not wandering")
check(not tick(mob({state = "walk", attack = {}, pos = far})),
	"a mob holding a target is not wandering")

-- No chase leash: a damage-pursuit mob 200 nodes from home, chasing a moving
-- player, keeps fighting while incoming damage sustains the fight.
do
	local target_pos = {x = 205, y = 10, z = 0}
	local target = {is_player_ref = true,
		get_pos = function() return target_pos end, get_hp = function() return 20 end}
	local chaser = mob({type = "monster", state = "attack", attack = target, pos = far,
		_grug_damage_pursuit_candidate = true})
	resets = 0
	local nudged = false
	for second = 1, 60 do
		target_pos = {x = 205 + second, y = 10, z = 0}
		if second % 10 == 0 then chaser.temp.grug_damage_at = now end
		nudged = tick(chaser) or nudged
	end
	check(not nudged and resets == 0 and chaser.attack == target,
		"a damage-sustained chase far from home is neither leashed nor nudged")
	-- The existing policy still ends it: 15 s without incoming damage while
	-- the target moves resets it (and the evade then runs home).
	for second = 1, 20 do
		target_pos = {x = 300 + second, y = 10, z = 0}
		tick(chaser)
	end
	check(resets == 1 and chaser.attack == nil and chaser.temp.grug_evading ~= nil,
		"the ambient pursuit clock still ends the fight and sends the mob home")
end

-- Camp members keep the 20-node roam cap; the patroller has none.
check(not tick(mob({_grug_camp_pos = {x = 0, y = 10, z = 0}, state = "stand",
	pos = {x = 19, y = 10, z = 0}})), "camp member inside 20 nodes left alone")
check(tick(mob({_grug_camp_pos = {x = 0, y = 10, z = 0}, state = "stand",
	pos = {x = 21, y = 10, z = 0}})), "camp member beyond 20 nodes steered home")
check(not tick(mob({_grug_camp_pos = {x = 0, y = 10, z = 0}, state = "stand",
	_grug_patrol_route = {}, pos = far})), "the patroller keeps its route")

-- Bound or bespoke actors keep their own movement rules.
local exempt = {
	{"named rare", {_grug_rare_id = "grimtusk"}},
	{"boss", {_grug_boss_id = "dragon"}},
	{"boss summon", {_grug_boss_summon = true}},
	{"royal summon", {_grug_royal_summon = true}},
	{"royal king", {_grug_royal_king = true}},
	{"no-leash actor", {_grug_no_leash = true}},
	{"swimmer", {_grug_swim_dy = 0.25}},
	{"NPC", {type = "npc"}},
	{"tamed mob", {tamed = true}},
	{"patroller", {_grug_patrol_route = {}}},
}
for _, row in ipairs(exempt) do
	local fields = {state = "walk", pos = far}
	for key, value in pairs(row[2]) do fields[key] = value end
	check(not tick(mob(fields)), row[1] .. " is not wander-leashed")
end

print(("checks %d failures %d"):format(checks, failures))
print(failures == 0 and "RESULT PASS" or "RESULT FAIL")
