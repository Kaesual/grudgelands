-- Round 40 lane PX portable test (LuaJIT): the particle helper and the
-- player-skill effects (round40-plan.md §2.4-§2.6, §2.15, §3.4).
--
--   luajit tools/r40_px/portable_test.lua [repo]
--
--   A  the REAL grug_core/particles.lua and particle_effects.lua on a fake
--      engine that records every add_particle / add_particlespawner call:
--      grug_particle_scale parsing (default 1, clamped 0..2), the count
--      arithmetic (rounded, a floor of one per emitter, none at 0), the
--      setting read once at load (0.5 halves, 0 plays nothing at all), exact
--      rings (Ice Nova's 48 and the proc's 8 evenly on their circle, each
--      Ice Nova mote landing on the nova's radius at the end of its life,
--      also at a reduced scale), the facing (Mighty Blow's slash turns with
--      the caster), every spawner unattached, public and 0 < time <= 1 (a
--      trail's frame time clamped), and the budget of every catalogue
--      effect (the check passes, at most 100 particles per occurrence).
--   B  the fallback rule (§2.4): the REAL kits.lua and scout.lua, and the
--      REAL finish_authoritative_swing, cast_refusal and try_cast cut out of
--      grug_abilities/init.lua, under stubs. Strike has no cast and no proc,
--      so it can play nothing; a swing skill's proc preparation
--      (proc_swing) plays nothing, only its post does, and the settlement
--      runs the post only for a committed, landed proc -- the Strike
--      fallback (no proc), a miss and a cancel play nothing; a cast on
--      cooldown never reaches the cast and plays nothing; a refused cast
--      (no target, no room) plays nothing; a cast that fires plays its
--      effect once. The REAL grug_projectiles plays a skill arrow's trail
--      only for a launch that is final (a rolled-back batch has none).
--   C  every effect id the game plays (grug_core.particles.play, kits.lua's
--      fx, grug_core.proc_flash, the arrow trails) is in the catalogue.
-- Prints "R40 PX PORTABLE PASS checks=<n>" or the failures (exit 1).

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
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function near(actual, expected, label)
	return check(type(actual) == "number" and math.abs(actual - expected) < 1e-6,
		label .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function read(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), "cannot read " .. path)
	local text = handle:read("*a")
	handle:close()
	return text
end

-- A small vector library (the engine's builtin is not loaded here).
vector = {}
function vector.new(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x or 0, y = y or 0, z = z or 0}
end
function vector.copy(v) return vector.new(v) end
function vector.offset(v, x, y, z) return vector.new(v.x + x, v.y + y, v.z + z) end
function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function vector.multiply(a, s) return vector.new(a.x * s, a.y * s, a.z * s) end
function vector.length(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
function vector.distance(a, b) return vector.length(vector.subtract(a, b)) end
function vector.normalize(v)
	local l = vector.length(v)
	return l > 0 and vector.multiply(v, 1 / l) or vector.new(0, 0, 0)
end
function vector.direction(a, b) return vector.normalize(vector.subtract(b, a)) end
function vector.dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end

------------------------------------------------------------------------------
-- A: the helper.
------------------------------------------------------------------------------
local calls, warnings = {}, {}
local setting
local function fake_core()
	return {
		settings = {get = function(_, key)
			if key == "grug_particle_scale" then return setting end
		end},
		add_particle = function(def) calls[#calls + 1] = {kind = "single", def = def} end,
		add_particlespawner = function(def) calls[#calls + 1] = {kind = "spawner", def = def} end,
		yaw_to_dir = function(yaw) return vector.new(-math.sin(yaw), 0, math.cos(yaw)) end,
		log = function(level, text) warnings[#warnings + 1] = level .. " " .. text end,
	}
end
local function load_helper(value)
	setting = value
	core = fake_core()
	grug_core = {}
	assert(loadfile(ROOT .. "/mods/CORE/grug_core/particles.lua"))()
	assert(loadfile(ROOT .. "/mods/CORE/grug_core/particle_effects.lua"))()
	return grug_core.particles
end

local P = load_helper(nil)
eq(P.SCALE, 1, "A the scale defaults to 1.0")
eq(P.parse_scale("0.5"), 0.5, "A scale 0.5 parses")
eq(P.parse_scale("-1"), 0, "A a negative scale clamps to 0")
eq(P.parse_scale("5"), 2, "A a scale above 2 clamps to 2")
eq(P.parse_scale("lots"), 1, "A a non-number falls back to 1")
eq(P.parse_scale("nan"), 1, "A NaN falls back to 1")
eq(P.count(48, 1), 48, "A count 48 at 1.0")
eq(P.count(48, 0.5), 24, "A count 48 at 0.5")
eq(P.count(48, 0.25), 12, "A count 48 at 0.25")
eq(P.count(3, 0.5), 2, "A count rounds half up (1.5 -> 2)")
eq(P.count(3, 0.1), 1, "A the floor of one particle per emitter")
eq(P.count(1, 0.01), 1, "A one stays one at any positive scale")
eq(P.count(30, 2), 60, "A scale 2 doubles")
eq(P.count(48, 0), 0, "A scale 0 is no particle")

local function total_particles()
	local n = 0
	for _, c in ipairs(calls) do
		n = n + (c.kind == "spawner" and c.def.amount or 1)
	end
	return n
end
local function spawners_ok(label)
	for _, c in ipairs(calls) do
		if c.kind == "spawner" then
			local d = c.def
			check(d.time > 0 and d.time <= 1, label .. ": spawner time in (0, 1] (" .. d.time .. ")")
			check(d.attached == nil and d.playername == nil and d.exclude_player == nil,
				label .. ": spawner unattached and public")
		else
			check(c.def.playername == nil, label .. ": single particle public")
		end
	end
end

-- Exact rings: Ice Nova's 48 on the 0.4 m circle at feet + 0.25, evenly
-- spaced, each reaching the nova's radius at the end of its life.
local CASTER = vector.new(10, 5, -20)
local function ring_check(label, reach, expected)
	calls = {}
	P.play("ice_nova", {caster = CASTER, reach = reach})
	local ring, angles = {}, {}
	for _, c in ipairs(calls) do
		if c.kind == "single" then ring[#ring + 1] = c.def end
	end
	eq(#ring, expected, label .. ": the ring's count")
	for i, d in ipairs(ring) do
		local dx, dz = d.pos.x - CASTER.x, d.pos.z - CASTER.z
		near(math.sqrt(dx * dx + dz * dz), 0.4, label .. ": mote " .. i .. " on the 0.4 m circle")
		near(d.pos.y, CASTER.y + 0.25, label .. ": mote " .. i .. " at feet + 0.25")
		angles[#angles + 1] = math.atan2(dz, dx) % (2 * math.pi)
		local ex = d.pos.x + d.velocity.x * d.expirationtime - CASTER.x
		local ez = d.pos.z + d.velocity.z * d.expirationtime - CASTER.z
		near(math.sqrt(ex * ex + ez * ez), reach, label .. ": mote " .. i .. " ends on the radius")
		near(d.velocity.y, 0, label .. ": mote " .. i .. " flies flat")
	end
	table.sort(angles)
	for i = 2, #angles do
		near(angles[i] - angles[i - 1], 2 * math.pi / expected, label .. ": even spacing " .. i)
	end
	spawners_ok(label)
end
ring_check("A Ice Nova at 1.0", 5, 48)
ring_check("A Frostbind's nova at 8 m", 8, 48)

-- The proc flash: 8 on the 0.6 m circle, in the proc's colour.
calls = {}
grug_core.proc_flash({get_pos = function() return CASTER end}, "untouchable")
eq(#calls, 8, "A the proc flash is 8 single motes")
for i, c in ipairs(calls) do
	local dx, dz = c.def.pos.x - CASTER.x, c.def.pos.z - CASTER.z
	near(math.sqrt(dx * dx + dz * dz), 0.6, "A proc mote " .. i .. " on the 0.6 m circle")
	check(c.def.texture.name:find(grug_core.PROC_COLORS.untouchable, 1, true) ~= nil,
		"A proc mote " .. i .. " in Untouchable's colour")
end

-- The facing: Mighty Blow's slash from local (1.2, 2, -0.5) turns with the
-- caster; facing north (+z) its left is west (-x), so it starts at
-- (+0.5, 2, +1.2) from the caster.
calls = {}
P.play("mighty_blow", {caster = CASTER, target = vector.new(10, 5, -18), dir = vector.new(0, 0, 1)})
local slash = calls[1] and calls[1].def
check(slash and slash.pos_tween ~= nil, "A Mighty Blow's slash is a tweened line spawner")
if slash then
	near(slash.pos_tween[1].x, CASTER.x + 0.5, "A the slash starts on the caster's right (x)")
	near(slash.pos_tween[1].y, CASTER.y + 2, "A the slash starts high")
	near(slash.pos_tween[1].z, CASTER.z + 1.2, "A the slash starts 1.2 m ahead")
	near(slash.pos_tween[2].x, CASTER.x - 0.6, "A the slash ends on the caster's left")
	eq(slash.amount, 20, "A the slash has 20 motes")
end
eq(calls[2] and calls[2].def.amount, 6, "A Mighty Blow keeps the 6 blood drops")
eq(calls[2] and calls[2].def.texture, "mobs_blood.png", "A the blood keeps today's look (no fade)")

-- A trail's frame time is clamped to the 1 s that keeps it nearby-only.
calls = {}
P.play("skill_arrow", {from = vector.new(0, 1, 0), to = vector.new(40, 1, 0), time = 2.5, color = "#79a65a"})
eq(calls[1] and calls[1].def.time, 1, "A a trail longer than 1 s is clamped to 1 s")
check(calls[1] and calls[1].def.texture.name:find("#79a65a", 1, true) ~= nil, "A the trail takes the skill's tint")
calls = {}
P.play("skill_arrow", {from = vector.new(0, 1, 0), to = vector.new(25, 1, 0), time = 0.5})
eq(calls[1] and calls[1].def.time, 0.5, "A a 0.5 s flight's trail lives 0.5 s")
spawners_ok("A trails")

-- Missing anchors skip, unknown ids warn, nothing raises.
calls = {}
P.play("smite", {caster = CASTER})
eq(#calls, 0, "A an effect at a missing target plays nothing")
P.play("no_such_effect", {caster = CASTER})
check(#warnings == 1 and warnings[1]:find("no_such_effect", 1, true) ~= nil, "A an unknown effect warns")

-- The budget: every catalogue effect passes the check and stays at most 100
-- particles per occurrence; at 0.25 every emitter still shows one.
local FRAME = {caster = CASTER, target = vector.new(16, 5, -20), dir = vector.new(1, 0, 0),
	from = vector.new(10, 6.5, -20), to = vector.new(30, 6, -20), time = 0.6, reach = 10,
	color = "#ffffff"}
local IDS = {"ice_nova", "fireball", "smite", "mighty_blow", "skill_arrow", "charge_ring",
	"charge_dust", "hamstring", "taunt", "bellow", "hold_ground", "blink", "cinderfall",
	"glacial_ward", "heal", "heal_splash", "shield_spell", "mend", "word_of_ruin", "snare_hit",
	"pinning_hit", "sidestep", "sprint", "opening", "proc", "crit", "absorb", "level_up"}
local per_effect = {}
for _, id in ipairs(IDS) do
	local effect = P.registered(id)
	if check(effect ~= nil, "A " .. id .. " is in the catalogue") then
		local list = type(effect) == "function" and effect(FRAME) or effect
		eq(P.check(list), nil, "A " .. id .. " keeps the budget rules")
		calls = {}
		P.play(id, FRAME)
		local n = total_particles()
		per_effect[#per_effect + 1] = id .. "=" .. n
		check(n >= 1 and n <= 100, "A " .. id .. " plays 1..100 particles (" .. n .. ")")
		eq(#calls - (function()
			local s = 0
			for _, c in ipairs(calls) do if c.kind == "single" then s = s + 1 end end
			return s
		end)(), (function()
			local s = 0
			for _, e in ipairs(list) do if e.kind == "spawner" then s = s + 1 end end
			return s
		end)(), "A " .. id .. " sends one call per spawner")
		spawners_ok("A " .. id)
	end
end
print("particles per occurrence at 1.0: " .. table.concat(per_effect, " "))
check(P.check({{kind = "spawner", n = 10, time = 2, exp = {0.3, 0.4}, shape = {"box", {0, 0, 0}, {1, 1, 1}}}}) ~= nil,
	"A the check refuses a spawner longer than 1 s")
check(P.check({{kind = "single", n = 500, exp = {0.3, 0.4}, shape = {"box", {0, 0, 0}, {1, 1, 1}}}}) ~= nil,
	"A the check refuses a count above the cap")
check(P.check({{kind = "spawner", n = 10, time = 0.5, attached = true, exp = {0.3, 0.4},
	shape = {"box", {0, 0, 0}, {1, 1, 1}}}}) ~= nil, "A the check refuses an attached spawner")

-- The setting is read once at load: 0.5 halves every emitter, 0 plays nothing.
P = load_helper("0.5")
eq(P.SCALE, 0.5, "A grug_particle_scale 0.5 is read at load")
ring_check("A Ice Nova at 0.5", 5, 24)
calls = {}
P.play("fireball", FRAME)
eq(calls[1] and calls[1].def.amount, 14, "A the Fireball's 28 embers at 0.5")
eq(calls[2] and calls[2].def.amount, 5, "A the Fireball's 10 smoke puffs at 0.5")
P = load_helper("0.01")
calls = {}
P.play("fireball", FRAME)
eq(total_particles(), 2, "A at 0.01 every emitter keeps one particle")
P = load_helper("0")
calls = {}
for _, id in ipairs(IDS) do P.play(id, FRAME) end
eq(#calls, 0, "A grug_particle_scale 0 plays nothing at all")

------------------------------------------------------------------------------
-- B: the fallback rule.
------------------------------------------------------------------------------
local played = {}
local function reset_played() played = {} end
local function played_ids()
	local out = {}
	for _, p in ipairs(played) do out[#out + 1] = p end
	return table.concat(out, ",")
end

core = setmetatable({
	get_us_time = function() return 1000000 end,
	get_objects_inside_radius = function() return {} end,
	yaw_to_dir = function(yaw) return vector.new(-math.sin(yaw), 0, math.cos(yaw)) end,
	after = function() end,
	log = function() end,
}, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})

local function object(fields)
	local o = fields or {}
	o.pos = o.pos or vector.new(0, 0, 0)
	function o:get_pos() return vector.new(self.pos) end
	function o:is_player() return self.player == true end
	function o:get_hp() return self.hp or 20 end
	function o:get_properties() return {eye_height = 1.5, hp_max = 20,
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}} end
	function o:get_luaentity() return self.entity end
	function o:get_player_name() return self.name or "" end
	function o:get_look_horizontal() return 0 end
	function o:get_look_dir() return vector.new(0, 0, 1) end
	function o:get_yaw() return self.yaw or 0 end
	function o:set_pos(p) self.pos = vector.new(p) end
	function o:get_meta() return {get_string = function() return "" end, set_string = function() end} end
	return o
end
local caster = object({player = true, name = "caster", pos = vector.new(0, 0, 0)})
local mob = object({pos = vector.new(0, 0, 6), entity = {_cmi_is_mob = true, health = 10}, yaw = 0})

local ray
grug_core = setmetatable({
	particles = {
		play = function(id) played[#played + 1] = id end,
		facing = function() return vector.new(0, 0, 1) end,
	},
	proc_flash = function(_, proc) played[#played + 1] = "proc:" .. proc end,
	combat_ray = function() return ray end,
	combat_debug_enabled = function() return false end,
	combat_debug_due = function() return false end,
	get_player_level = function() return 30 end,
	baseline_weapon_damage = function() return 10 end,
	baseline_melee_total = function() return 10 end,
	base_pool = function() return 100 end,
	get_absorb = function() return 0 end,
	is_stunned = function() return false end,
	deal_ability_damage = function() return 1 end,
	heal_player = function() return 1 end,
	add_absorb = function() return 1 end,
	invalidate_combat_identity = function() end,
	set_status = function() end,
	set_move_immunity = function() end,
	set_move_modifier = function() end,
	set_root = function() end,
	scale_player_damage = function(_, _, amount) return amount end,
	run_settled_outgoing_action = function() end,
	add_threat = function() end,
}, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
grug_classes = {
	get_talent_bonus = function() return 0 end,
	get_spell_power_bonus = function() return 0 end,
	get_spell_damage_percent = function() return 0 end,
	get_support_factor = function() return 1 end,
	get_race_perk = function() return 0 end,
	talent_rank = function() return 0 end,
	talent_trigger_ready = function() return false end,
	try_trigger_talent_window = function() return false end,
	start_talent_window = function() end,
	start_sidestep = function() end,
	get_class = function() return "warrior" end,
	registered_classes = {warrior = {name = "Warrior"}},
	registered_talents = {mend = {name = "Mend"}},
}
grug_projectiles = {register = function() end}
grug_mobs = {root = function() end, slow = function() end, stun = function() end,
	is_noncombatant = function() return false end}
grug_pvp = {support_contact = function() end, can_support = function() return true end}
grug_factions = {same_faction = function() return false end}
grug_sounds = {play = function() end}
player_api = {register_control_animation_override = function() end}
local abilities = {}
grug_abilities = {
	register_ability = function(def) abilities[def.id] = def end,
	get_range = function(_, def) return def.range or 4 end,
	set_target = function() end,
	valid_target = function(_, obj, kind)
		return kind == "hostile" and obj == mob
	end,
	charge_destination = function() return vector.new(0, 0, 4.7) end,
	-- Round 40 CH: the dash starts here and plays the ring on arrival
	-- (charge.lua, tools/r40_ch covers it): nothing plays at the cast.
	charge_dash = function() return true end,
	blink_destination = function() return vector.new(0, 0, 10) end,
	add_rage = function() end,
	crosshair = {set_ring = function() end},
	input = {hold_range = function() end},
}
assert(loadfile(ROOT .. "/mods/PLAYER/grug_abilities/kits.lua"))()
assert(loadfile(ROOT .. "/mods/PLAYER/grug_abilities/scout.lua"))()

-- Strike: no cast and no proc, so no path to an effect.
local strike = abilities.strike
check(strike ~= nil and strike.cast == nil and strike.proc_swing == nil,
	"B Strike has no cast and no proc: it plays nothing")

-- The settlement: the REAL finish_authoritative_swing.
local init = read("mods/PLAYER/grug_abilities/init.lua")
local finish_src = init:match("\n(local function finish_authoritative_swing%(context, result%).-\nend)\n")
check(finish_src ~= nil, "B finish_authoritative_swing found in init.lua")
local spent = 0
local finish = assert(loadstring("local spend, swing_rage, play_skill_pose = ...\n" .. finish_src ..
	"\nreturn finish_authoritative_swing", "=finish"))(
	function() spent = spent + 1; return true end, function() return 8 end,
	function() end) -- the pose (lane AN1) has its own fixture
grug_abilities.reset_charge = function() end

-- Each swing skill's preparation plays nothing; its post plays its effect.
for _, case in ipairs({{"mighty_blow", "mighty_blow"}, {"hamstring", "hamstring"},
		{"opening", "opening"}}) do
	local id, effect = case[1], case[2]
	local def = abilities[id]
	reset_played()
	mob.yaw = 0 -- the mob faces away from the caster: Opening is from behind
	local damage, threat, post = def.proc_swing(caster, mob,
		{weapon_damage = 10, melee_bonus = 0, melee_damage_add = 0, fpi = 1})
	check(damage ~= nil and type(post) == "function", "B " .. id .. " prepares a proc with a post")
	eq(played_ids(), "", "B " .. id .. ": the proc preparation plays nothing")
	local function settle(proc, result)
		reset_played()
		finish({player = caster, proc = proc, proc_cost = {}, post = post, threat_mult = threat or 1}, result)
		return played_ids()
	end
	eq(settle(nil, {landed = true, grant_rage = true}), "",
		"B " .. id .. ": the Strike fallback (no proc) plays nothing")
	eq(settle(def, {landed = false}), "", "B " .. id .. ": a missed proc plays nothing")
	eq(settle(def, {landed = true, cancelled = true}), "", "B " .. id .. ": a cancelled proc plays nothing")
	eq(settle(def, {landed = true}), effect, "B " .. id .. ": a landed proc plays " .. effect .. " once")
end

-- The cast dispatcher: the REAL cast_refusal and try_cast.
local refusal_src = init:match("\n(local function cast_refusal%(user, def%).-\nend)\n")
local try_src = init:match("\n(function grug_abilities%.try_cast%(user, def, pointed_thing, notify%).-\nend)\n")
check(refusal_src ~= nil and try_src ~= nil, "B cast_refusal and try_cast found in init.lua")
local ready = true
grug_abilities.is_unlocked = function() return true end
grug_abilities.ready = function() return ready end
grug_abilities.cost_for = function() return {} end
grug_abilities.flash = function() end
grug_abilities.arm_cooldown = function() end
grug_abilities.effective_cooldown = function() return 1 end
grug_abilities.CAST_SOUNDS = {}
grug_classes.registered_classes = {warrior = {name = "Warrior"}, mage = {name = "Mage"},
	priest = {name = "Priest"}, scout = {name = "Scout"}}
assert(loadstring("local reset_swing_boundary, refuse_mounted_attack, cast_interval_ready, " ..
	"affordable, spend, arm_cast_interval, play_skill_pose = ...\n" .. refusal_src .. "\n" ..
	try_src, "=try_cast"))(
	function() end, function() return false end, function() return true end,
	function() return true end, function() return true end, function() end, function() end)

local function cast(id, class, target_ray)
	grug_classes.get_class = function() return class end
	ray = target_ray
	reset_played()
	grug_abilities.try_cast(caster, abilities[id], nil, function() end)
	return played_ids()
end
local HIT = {status = "target", target = mob, reason = "target", distance = 6, range = 20,
	pointed = {intersection_point = vector.new(0, 1, 6)}}
local MISS = {status = "aim_miss", reason = "empty"}
local CASTS = {
	{"charge", "warrior", ""}, {"taunt", "warrior", "taunt"},
	{"hold_ground", "warrior", "hold_ground"}, {"ice_nova", "mage", "ice_nova"},
	{"blink", "mage", "blink"}, {"cinderfall", "mage", "cinderfall"},
	{"glacial_ward", "mage", "glacial_ward"}, {"smite", "priest", "smite"},
	{"heal", "priest", "heal"}, {"shield_spell", "priest", "shield_spell"},
	{"mend", "priest", "mend"}, {"word_of_ruin", "priest", "word_of_ruin"},
	{"sidestep", "scout", "sidestep"}, {"sprint", "scout", "sprint"},
}
mob.entity.attack_type = "dogfight"
mob.entity.do_attack = function() end
grug_core.taunt = function() return true end
for _, case in ipairs(CASTS) do
	local id, class, effect = case[1], case[2], case[3]
	ready = false
	eq(cast(id, class, HIT), "", "B " .. id .. " on cooldown plays nothing")
	ready = true
	eq(cast(id, class, HIT), effect, "B " .. id .. " that fires plays " .. effect .. " once")
end
-- Refused casts (no target in the crosshair, no room) play nothing.
for _, id in ipairs({"charge", "taunt", "cinderfall", "smite", "word_of_ruin"}) do
	local class = ({charge = "warrior", taunt = "warrior", cinderfall = "mage"})[id] or "priest"
	eq(cast(id, class, MISS), "", "B a refused " .. id .. " (no target) plays nothing")
end
grug_abilities.charge_destination = function() return nil end
eq(cast("charge", "warrior", HIT), "", "B a Charge without room plays nothing")
grug_abilities.blink_destination = function() return nil end
eq(cast("blink", "mage", HIT), "", "B a Blink without room plays nothing")

-- Bellow: the ring only when the area taunt affected someone.
grug_classes.get_talent_bonus = function(_, key) return key == "taunt_radius" and 8 or 0 end
eq(cast("taunt", "warrior", HIT), "", "B a Bellow that reaches nobody plays nothing")
core.get_objects_inside_radius = function() return {mob} end
eq(cast("taunt", "warrior", HIT), "bellow", "B a Bellow that taunts plays its ring")

-- The skill-arrow trail: the REAL grug_projectiles plays it once a launch is
-- final -- a batch whose commit fails (no arrow consumed) rolls back without
-- a trail; a launch without `trail` (the Fireball) has none.
do
	local frames = {}
	grug_core.particles.play = function(id, frame)
		played[#played + 1] = id
		frames[#frames + 1] = frame
	end
	local join
	core.register_on_joinplayer = function(fn) join = join or fn end
	core.register_entity = function() end
	core.serialize = function() return "" end
	core.get_player_by_name = function() return caster end
	core.add_entity = function(pos)
		local o = object({pos = pos})
		local entity = {}
		function o:get_luaentity() return entity end
		function o:set_velocity() end
		function o:set_rotation() end
		function o:remove() end
		return o
	end
	grug_core.homing_lock = function(_, target, origin, speed)
		local d = vector.distance(origin, target:get_pos())
		return {target = target, previous = target:get_pos(), duration = d / speed, age = 0}
	end
	grug_projectiles = nil
	assert(loadfile(ROOT .. "/mods/ENTITIES/grug_projectiles/init.lua"))()
	join(caster)
	grug_projectiles.register("arrow", {speed = 40, max_distance = 25, on_hit = function() end})
	ray = HIT
	local function launch(trail)
		return {owner = caster, origin = vector.new(0, 1.5, 0), direction = vector.new(0, 0, 1),
			trail = trail, data = {}}
	end
	local TRAIL = {effect = "skill_arrow", color = "#79a65a"}
	reset_played()
	check(not grug_projectiles.spawn_batch("arrow", {launch(TRAIL), launch(TRAIL)},
		function() return false end), "B a batch whose commit fails is refused")
	eq(played_ids(), "", "B a rolled-back batch leaves no trail")
	reset_played()
	check(grug_projectiles.spawn_batch("arrow", {launch(TRAIL), launch(TRAIL)},
		function() return true end), "B a committed batch launches")
	eq(played_ids(), "skill_arrow,skill_arrow", "B Twin Shot's two arrows trail once each")
	local f = frames[#frames]
	near(f.time, vector.distance(vector.new(0, 1.5, 0), mob:get_pos()) / 40,
		"B the trail lives the flight time (the lock's distance at 40 m/s)")
	near(f.from.z, 0.3, "B the trail starts 0.3 m ahead of the origin")
	near(f.to.z, vector.distance(vector.new(0, 1.5, 0), mob:get_pos()),
		"B the trail ends at the locked target's distance along the launch line")
	eq(f.color, "#79a65a", "B the trail carries the skill's tint")
	reset_played()
	check(grug_projectiles.spawn("arrow", launch(nil)), "B a launch without a trail flies")
	eq(played_ids(), "", "B a launch without a trail plays nothing")
	reset_played()
	ray = MISS
	check(not grug_projectiles.spawn("arrow", launch(TRAIL)), "B a launch with no target is refused")
	eq(played_ids(), "", "B a refused launch plays nothing")
end

------------------------------------------------------------------------------
-- C: every played id is in the catalogue.
------------------------------------------------------------------------------
P = load_helper(nil)
local FILES = {"mods/PLAYER/grug_abilities/kits.lua", "mods/PLAYER/grug_abilities/scout.lua",
	"mods/PLAYER/grug_abilities/charge.lua",
	"mods/CORE/grug_core/combat.lua", "mods/CORE/grug_core/particle_effects.lua",
	"mods/ENTITIES/grug_projectiles/init.lua", "mods/PLAYER/grug_xp/init.lua"}
local seen = 0
for _, path in ipairs(FILES) do
	local text = read(path)
	for id in text:gmatch('particles%.play%("([%w_]+)"') do
		seen = seen + 1
		check(P.registered(id) ~= nil, "C " .. path .. " plays a catalogue effect: " .. id)
	end
	for id in text:gmatch('fx%("([%w_]+)"') do
		seen = seen + 1
		check(P.registered(id) ~= nil, "C " .. path .. " plays a catalogue effect: " .. id)
	end
	for id in text:gmatch('effect = "([%w_]+)"') do
		seen = seen + 1
		check(P.registered(id) ~= nil, "C " .. path .. " trails a catalogue effect: " .. id)
	end
end
check(seen >= 25, "C the scan found the game's effect calls (" .. seen .. ")")
local PROC_FILES = {"mods/PLAYER/grug_abilities/kits.lua", "mods/PLAYER/grug_classes/scout.lua",
	"mods/PLAYER/grug_classes/talents.lua", "mods/PLAYER/grug_trinkets/init.lua"}
local procs = 0
for _, path in ipairs(PROC_FILES) do
	for proc in read(path):gmatch('proc_flash%([%w_]+, "([%w_]+)"%)') do
		procs = procs + 1
		check(grug_core.PROC_COLORS[proc] ~= nil, "C " .. path .. " flashes a known proc: " .. proc)
	end
end
eq(procs, 7, "C the seven proc sites flash")

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then
	error("R40 PX PORTABLE FAIL")
end
print("R40 PX PORTABLE PASS checks=" .. checks)
