-- Bounded fixture for the common 30-second out-of-combat full-health reset.
local repo = assert(arg[1], "repository path required")
local now = 0

core = {}
grug_core = {
	mono_time = function() return now end,
	clear_threat = function(self)
		self.temp.grug_threat = nil
		self.temp.grug_forced_until = nil
	end,
}
grug_mobs = {}
vector = {
	distance = function(a, b)
		local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(x * x + y * y + z * z)
	end,
}

assert(loadfile(repo .. "/mods/ENTITIES/grug_mobs/aggro.lua"))()
assert(loadfile(repo .. "/mods/ENTITIES/grug_mobs/idle_health.lua"))()

local function mob(id)
	local object = {
		get_pos = function() return {x = 0, y = 0, z = 0} end,
	}
	local self = {
		object = object, health = 40, hp_max = 100, old_health = 40,
		state = "stand", temp = {grug_threat = {player = 10}},
		_grug_player_tag = {name = "player"}, _grug_boss_id = id,
		update_tag = function(s) s.tags = (s.tags or 0) + 1 end,
		stop_attack = function(s) s.attack = nil; s.state = "stand" end,
	}
	return self
end

local function tick(self, at)
	now = at
	return grug_mobs.idle_health_tick(self)
end

-- Activation seeds a full grace; exact expiry performs the established reset.
local idle = mob()
assert(not tick(idle, 0) and not tick(idle, 29))
assert(tick(idle, 30) and idle.health == 100 and idle.old_health == 100)
assert(not idle.temp.grug_threat and not idle._grug_player_tag and idle.tags == 1)

-- Melee/ranged and short target gaps continually restart the quiet window.
local fighting = mob()
fighting.attack = {}
fighting.state = "attack"
assert(not tick(fighting, 40))
assert(not tick(fighting, 100) and fighting.health == 40)
fighting.attack = nil; fighting.state = "stand"
assert(not tick(fighting, 129) and tick(fighting, 130))

-- Any-source repeated loss (environment or DoT) prevents a targetless reset.
local dot = mob()
assert(not tick(dot, 200))
for at = 210, 250, 10 do
	dot.health = dot.health - 1
	assert(not tick(dot, at) and dot.health < 100)
end
assert(not tick(dot, 279) and tick(dot, 280))

-- Death is sampled but never healed or resurrected.
local dead = mob()
dead.health = 0; dead.state = "die"
assert(not tick(dead, 300) and not tick(dead, 400) and dead.health == 0)

-- Runtime state never carries across activation.
local reloaded = mob()
assert(not tick(reloaded, 500))
assert(not tick(reloaded, 529) and tick(reloaded, 530))

-- One active royal blocks its calm buddy. Shared quiet is exactly 30 seconds,
-- not a local 30 plus an accidentally amplified shared 30.
local king, guard = mob("king:human"), mob("king:human")
king.attack = {}; king.state = "attack"
assert(not tick(king, 600)); assert(not tick(guard, 600))
assert(not tick(king, 620)); assert(not tick(guard, 620))
king.attack = nil; king.state = "stand"
assert(not tick(king, 621)); assert(not tick(guard, 621))
assert(not tick(guard, 649) and tick(guard, 650) and tick(king, 650))

-- Summons use the same bounded group clock even with no target of their own.
local dragon, whelp = mob("dragon:wyrmglass"), mob()
whelp._grug_boss_summon = "dragon:wyrmglass"
dragon.temp.grug_dragon = {action = {kind = "breath"}}
assert(not tick(dragon, 700)); assert(not tick(whelp, 700))
dragon.temp.grug_dragon.action = nil
assert(not tick(whelp, 729) and tick(whelp, 730))

-- A boss with no runtime activity recovers after the same bounded quiet time;
-- the production predicate has no reward-participation input.
local boss = mob("dragon:stormscale")
assert(not tick(boss, 800))
assert(tick(boss, 830))

-- Load the actual boss lifecycle module with bounded registration stubs and
-- verify its public attempt reset clears the production shared-activity store.
local function noop() end
core.get_mod_storage = function()
	return {get_string = function() return "" end, set_string = noop}
end
core.register_on_joinplayer = noop
core.register_on_dieplayer = noop
core.register_craftitem = noop
core.register_globalstep = noop
core.get_player_by_name = function() return nil end
core.get_objects_inside_radius = function() return {} end
grug_core.register_on_player_hit_mob = noop
grug_core.register_on_effective_heal = noop
grug_core.register_on_effective_absorb = noop
grug_core.get_player_faction = function() return nil end
grug_core.opposing_faction = function() return nil end
grug_mobs.register_dragon_bosses = noop
grug_mobs.register_mob = noop
grug_mobs.guard_definition = function() return {do_custom = noop} end
mobs = {spawn = noop}
assert(loadfile(repo .. "/mods/ENTITIES/grug_mobs/bosses.lua"))()
local lifecycle = mob("dragon:lifecycle")
grug_mobs.touch_boss_activity(lifecycle, 900)
assert(grug_mobs.boss_recently_active(lifecycle, 901, 30))
grug_mobs.boss_attempt_reset("dragon:lifecycle")
assert(not grug_mobs.boss_recently_active(lifecycle, 901, 30))

print("r19 idle health micro: ok")
