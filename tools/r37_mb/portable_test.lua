-- Round 37 lane MB portable test (round37-plan.md §2.1.1, §2.1.4, §4.2; audit
-- package P2). Loads the REAL code under small stubs: grug_core's combat.lua
-- (threat, check_switch, taunt) in full, grug_mobs/telegraph.lua in full,
-- mobs/grug_obstacle.lua in full, and the touched pieces cut out of the
-- vendored mobs/api.lua. Checks:
--   T  MOB-01 retaliation only through threat: a second player's hit on a
--      tank-held mob leaves the target until a rival passes 120 % of the
--      tank's threat; a taunt holds against every hit for its 3 s; a mob or
--      NPC hitter still turns the mob; a targetless mob takes its first
--      attacker (also when the hit adds no threat); the group alert still
--      calls idle kin while the hit mob keeps its target.
--   A  MOB-04 the punch clip plays to its end: "stand"/"walk"/"run" wait
--      until it ends, forced writes and other animations pass.
--   W  MOB-07 the wind-up: the facing freezes, the ordinary swings pause and
--      resume one interval after the cone; the target who stepped aside is
--      a clean miss, a bystander in the frozen cone is hit.
--   F  MOB-02 the follow scan does not run for a mob without `follow`; a mob
--      that follows an item or an owner's "follow" order still scans.
--   S  MOB-05 get_staticdata leaves the live mob unchanged; the saved copy
--      starts calm.
--   P  MOB-16 the pathfinding switch reads its default, not `or true`.
-- Usage (repo root): luajit tools/r37_mb/portable_test.lua [REPO]
-- Prints "R37 MB PORTABLE PASS checks=<n>" or raises.
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
local api = read("mods/ENTITIES/mobs/api.lua")
-- Cut a piece of api.lua (plain-text anchors) and load it in `env`.
local function cut(from, to, label)
	local a = api:find(from, 1, true)
	check(a ~= nil, label .. ": start anchor in api.lua")
	local b, e = api:find(to, a, true)
	check(b ~= nil, label .. ": end anchor in api.lua")
	return api:sub(a, e)
end
local function load_in(source, env, label)
	local chunk = assert(loadstring(source, "=" .. label))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	return chunk()
end

-- ---------------------------------------------------------------------------
-- Engine stubs: a controllable clock, players and objects.
-- ---------------------------------------------------------------------------
local us_time = 1000000
local function advance(seconds) us_time = us_time + math.floor(seconds * 1e6) end
local function vec(x, y, z) return {x = x, y = y, z = z} end
vector = {
	new = function(x, y, z)
		if type(x) == "table" then return vec(x.x, x.y, x.z) end
		return vec(x, y, z)
	end,
	offset = function(p, x, y, z) return vec(p.x + x, p.y + y, p.z + z) end,
	subtract = function(a, b) return vec(a.x - b.x, a.y - b.y, a.z - b.z) end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
}

local players = {}
local function new_player(name, pos)
	local p = {name = name, pos = pos, hp = 20, punched = 0, wield = ""}
	function p:is_player() return true end
	function p:get_player_name() return self.name end
	function p:get_pos() return self.pos and vector.new(self.pos) end
	function p:get_hp() return self.hp end
	function p:get_luaentity() return nil end
	function p:get_attach() return nil end
	function p:get_wielded_item()
		local w = self.wield
		return {get_name = function() return w end}
	end
	function p:punch() self.punched = self.punched + 1 end
	players[#players + 1] = p
	return p
end

local objects = {} -- every object near a hit, for the group alert
core = {
	get_us_time = function() return us_time end,
	is_player = function(obj)
		return type(obj) == "table" and obj.is_player ~= nil and obj:is_player()
	end,
	get_player_by_name = function(name)
		for _, p in ipairs(players) do
			if p.name == name then return p end
		end
	end,
	get_connected_players = function() return players end,
	get_objects_inside_radius = function() return objects end,
	yaw_to_dir = function(yaw) return vec(-math.sin(yaw), 0, math.cos(yaw)) end,
	dir_to_yaw = function(dir) return -math.atan2(dir.x, dir.z) end,
	line_of_sight = function() return true end,
	add_particlespawner = function() end,
	log = function() end,
	after = function() end,
	settings = {get = function() return nil end, get_bool = function() return nil end},
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
grug_sounds = {play = function() return false end}

-- ---------------------------------------------------------------------------
-- grug_core's threat code, the real file.
-- ---------------------------------------------------------------------------
grug_core = {}
grug_mobs = {registered_cadence = {["grug_mobs:wolf"] = true}}
dofile(repo .. "/mods/CORE/grug_core/combat_ray.lua")
dofile(repo .. "/mods/CORE/grug_core/combat.lua")
grug_mobs.damage_pursuit = function() return false end
grug_mobs.start_damage_pursuit = function() end

-- mobs_redo's do_attack and the on_punch retaliation tail, cut out of api.lua.
local mob_class = {}
local obstacle_stub = {cancel_path_request = function() end, forget_no_path = function() end}
load_in(cut("function mob_class:do_attack(player, force)", "\nend\n", "do_attack"),
	{mob_class = mob_class, random = function() return 100 end,
		grug_obstacle = obstacle_stub, grug_nav = {forget = function() end}}, "do_attack")
local tail = cut("\tlocal hitter_name = hitter:get_player_name() or \"\"",
	"\n\treturn true\nend\n", "retaliation")
check(tail:find("grug_mob_hit and self.attack and self.state == \"attack\"", 1, true) ~= nil,
	"T0 the retaliation tail asks whether the mob already fights")
local retaliate = load_in("return function(self, hitter, grug_mob_hit)\n" .. tail,
	{is_player = core.is_player, is_invisible = function() return false end},
	"retaliation")
function mob_class:mob_sound() end

local mob_mt = {__index = mob_class}
local function new_mob(name, pos, fields)
	local m = setmetatable({name = name, pos = pos, state = "stand", health = 100,
		attack_type = "dogfight", view_range = 14, group_attack = true,
		_cmi_is_mob = true, owner = "", sounds = {}, temp = {},
		path = {}}, mob_mt)
	m.object = {
		get_pos = function() return vector.new(m.pos) end,
		get_luaentity = function() return m end,
		get_player_name = function() return "" end,
		is_player = function() return false end,
	}
	for k, v in pairs(fields or {}) do m[k] = v end
	return m
end

-- One accepted hit in on_punch's order: the accepted-hit hook (threat and
-- check_switch for a player on a grug mob), then the retaliation tail.
local function hit(mob, hitter, damage)
	local grug_mob_hit = core.is_player(hitter)
		and grug_mobs.registered_cadence[mob.name] == true
	if grug_mob_hit then
		grug_core.run_player_hit_mob(hitter, mob, damage)
	end
	retaliate(mob, hitter.object or hitter, grug_mob_hit)
end
local function target_of(mob)
	local a = mob.attack
	if not a then return nil end
	if core.is_player(a) then return a:get_player_name() end
	return a
end

do
	local tank = new_player("tank", vec(0, 0, 2))
	local dps = new_player("dps", vec(2, 0, 0))
	local healer = new_player("healer", vec(-2, 0, 0))
	local wolf = new_mob("grug_mobs:wolf", vec(0, 0, 0))
	objects = {wolf.object}

	-- T1 first attacker.
	hit(wolf, tank, 10)
	check(target_of(wolf) == "tank" and wolf.state == "attack", "T1 a targetless mob takes its first attacker")
	-- T2 a second player hits; threat 11 < 12 = 120 % of 10.
	advance(0.3)
	hit(wolf, dps, 11)
	check(target_of(wolf) == "tank", "T2 a second player's hit leaves the tank's mob on the tank")
	advance(0.3)
	hit(wolf, healer, 1)
	check(target_of(wolf) == "tank", "T2 a third player's small hit leaves it too")
	-- T3 the rival passes 120 %: check_switch turns it (dps 13 > 12).
	advance(0.3)
	hit(wolf, dps, 2)
	check(target_of(wolf) == "dps", "T3 past 120 % of the tank's threat the mob switches")
	-- T4 within the 0.25 s throttle the switch is parked, not taken by retaliation.
	hit(wolf, tank, 30)
	check(target_of(wolf) == "dps" and wolf.temp.grug_switch_pending,
		"T4 a throttled switch is parked, the target holds")
	advance(1)
	grug_core.recheck_switch(wolf)
	check(target_of(wolf) == "tank", "T4 the parked check switches on the 1 Hz tick")

	-- T5 taunt holds against every hit for 3 s.
	advance(0.3)
	check(grug_core.taunt(wolf, dps), "T5 taunt accepted")
	wolf:do_attack(dps, true)
	check(target_of(wolf) == "dps", "T5 the taunt forces the target")
	advance(0.3)
	hit(wolf, tank, 500)
	check(target_of(wolf) == "dps", "T5 a big hit cannot break the taunt")
	advance(0.3)
	hit(wolf, healer, 500)
	check(target_of(wolf) == "dps", "T5 nor another player's")
	advance(3)
	grug_core.recheck_switch(wolf)
	check(target_of(wolf) ~= "dps", "T5 after the lock the parked switch runs")

	-- T6 a mob or NPC hitter still draws retaliation, even on a held mob.
	local bear = new_mob("grug_mobs:bear", vec(3, 0, 3))
	advance(0.3)
	hit(wolf, bear, 5)
	check(wolf.attack == bear.object, "T6 a mob hitter turns the mob")
	local guard = new_mob("grug_mobs:guard", vec(-3, 0, 3), {type = "npc"})
	hit(wolf, guard, 5)
	check(wolf.attack == guard.object, "T6 an NPC hitter turns the mob")

	-- T7 group alert while the hit mob holds its target.
	local wolf2 = new_mob("grug_mobs:wolf", vec(1, 0, 1))
	local wolf3 = new_mob("grug_mobs:wolf", vec(1, 0, -1), {state = "attack"})
	wolf3.attack = tank
	local loner = new_mob("grug_mobs:wolf", vec(-1, 0, 1), {group_attack = false})
	local held = new_mob("grug_mobs:wolf", vec(0, 0, 0))
	objects = {held.object, wolf2.object, wolf3.object, loner.object}
	hit(held, tank, 10)
	advance(0.3)
	wolf2.state, wolf2.attack = "stand", nil
	hit(held, dps, 1)
	check(target_of(held) == "tank", "T7 the hit mob keeps its target")
	check(target_of(wolf2) == "dps", "T7 the group alert still calls idle kin")
	check(target_of(wolf3) == "tank", "T7 kin already fighting keep their target")
	check(loner.attack == nil, "T7 a mob without group_attack is not called")

	-- T8 a zero-damage first hit adds no threat; the mob still takes its attacker.
	local idle = new_mob("grug_mobs:wolf", vec(0, 0, 0))
	objects = {idle.object}
	hit(idle, healer, 0)
	check(target_of(idle) == "healer", "T8 a targetless mob takes a no-threat first attacker")
	-- T9 a passive mob never retaliates (upstream guard kept).
	local prey = new_mob("grug_mobs:wolf", vec(0, 0, 0), {passive = true})
	hit(prey, tank, 5)
	check(prey.attack == nil, "T9 a passive mob does not fight back")
end

-- ---------------------------------------------------------------------------
-- A. MOB-04: set_animation holds the punch clip.
-- ---------------------------------------------------------------------------
do
	local env = {mob_class = {}, random = function(a) return a or 0 end}
	load_in(cut("function mob_class:set_animation(anim, force)", "\nend\n", "set_animation"),
		env, "set_animation")
	local sent = {}
	local m = setmetatable({temp = {}, animation = {
		speed_normal = 30,
		stand_start = 0, stand_end = 10, walk_start = 11, walk_end = 20,
		run_start = 21, run_end = 30, punch_start = 31, punch_end = 46,
		injured_start = 47, injured_end = 50,
	}}, {__index = env.mob_class})
	m.object = {set_animation = function(_, range) sent[#sent + 1] = range.x end}
	local function current() return m.animation_current end
	m:set_animation("run")
	check(current() == "run", "A0 run plays")
	m:set_animation("punch")
	check(current() == "punch", "A1 the punch plays")
	-- 15 frames at 30 fps = 0.5 s.
	advance(0.09)
	m:set_animation("stand")
	check(current() == "punch", "A2 the next step's stand waits for the clip")
	m:set_animation("run")
	m:set_animation("walk")
	check(current() == "punch", "A2 run and walk wait too")
	advance(0.3)
	m:set_animation("stand")
	check(current() == "punch", "A2 still inside the clip at 0.39 s")
	m:set_animation("injured")
	check(current() == "injured", "A3 a hit reaction passes")
	m:set_animation("punch")
	m:set_animation("die", true)
	m:set_animation("stand", true)
	check(current() == "stand", "A3 a forced write passes")
	m:set_animation("punch")
	advance(0.51)
	m:set_animation("stand")
	check(current() == "stand", "A4 after the clip the stand plays")
	check(m.temp.grug_punch_until == nil, "A4 the hold is gone")
	-- A clip speed of its own: 15 frames at 15 fps = 1 s.
	m.animation.punch_speed = 15
	m:set_animation("punch")
	advance(0.8)
	m:set_animation("run")
	check(current() == "punch", "A5 punch_speed sets the clip length")
	advance(0.25)
	m:set_animation("run")
	check(current() == "run", "A5 then the run plays")
	-- A mob without a punch clip is never held.
	m.animation.punch_start, m.animation.punch_end = nil, nil
	m:set_animation("punch")
	m:set_animation("stand")
	check(current() == "stand", "A6 no punch clip, no hold")
	check(api:find("punch = function()\n\t\t\t\t\tself:set_animation(\"punch\")", 1, true) ~= nil,
		"A7 the melee swing still sets the punch animation")
end

-- ---------------------------------------------------------------------------
-- W. MOB-07: the wind-up freezes the facing and pauses the swings.
-- ---------------------------------------------------------------------------
do
	local env = {mob_class = {}, pi = math.pi, mob_smooth_rotate = true}
	-- The piece starts with api.lua's local predicate; hand it out as well.
	local winding_up = load_in(cut("local function grug_winding_up(self)",
		"function mob_class:set_pitch", "set_yaw")
		:gsub("function mob_class:set_pitch$", "return grug_winding_up"), env, "set_yaw")
	load_in(cut("function mob_class:yaw_to_pos(target, rot, delay)", "\nend\n", "yaw_to_pos"),
		env, "yaw_to_pos")
	local O = dofile(repo .. "/mods/ENTITIES/mobs/grug_obstacle.lua")
	local swing_src = cut("\t\t\t-- GRUG PATCH (Round 37 MB, MOB-07): no ordinary swing",
		"if consume then self.punch_timer = 0 end", "swing")
	local swing = load_in("return function(self, dist, s, target_pos, in_sight, ground_melee)\n"
		.. swing_src .. "\nend", {
			random = function() return 1 end,
			grug_winding_up = winding_up,
			grug_obstacle = setmetatable({
				strike_target_visible = function(_, _, _, visible) return visible end,
			}, {__index = O}),
		}, "swing")
	check(swing_src:find("and not grug_winding_up(self)", 1, true) ~= nil,
		"W0 the swing asks grug_winding_up")
	check(api:find("and not grug_winding_up(self)\n\t\t\tand random(100) <= 60 then", 1, true) ~= nil,
		"W0 the shot asks grug_winding_up")

	grug_mobs.tier_telegraphs = function(tier) return tier == "elite" end
	grug_mobs.root = function(self) self.walk_velocity, self.run_velocity = 0, 0 end
	grug_core.particles = dofile(repo .. "/tools/r40_pm/helper_stub.lua")(repo) -- Round 40 PM
	dofile(repo .. "/mods/ENTITIES/grug_mobs/telegraph.lua")

	players = {}
	local target = new_player("target", vec(0, 0, 2))
	local bystander = new_player("bystander", vec(0, 0, 3))
	local m = setmetatable({_grug_tier = "elite", state = "attack", reach = 3,
		damage = 5, rotate = 0, punch_timer = 0, punch_interval = 1,
		temp = {}, sounds = {}, attack = target}, {__index = env.mob_class})
	local rot = {x = 0, y = 0, z = 0}
	m.object = {
		get_pos = function() return vec(0, 0, 0) end,
		get_rotation = function() return {x = rot.x, y = rot.y, z = rot.z} end,
		set_rotation = function(_, r) rot = {x = r.x, y = r.y, z = r.z} end,
		get_yaw = function() return rot.y end,
	}
	function m:set_animation() end
	function m:mob_sound() end
	local swings = 0
	target.punch = function(self) self.punched = self.punched + 1; swings = swings + 1 end
	-- One server step of the dogfight branch: turn to the target, advance the
	-- cadence (capped at one backlog), try the swing; then do_custom's tick.
	local function step(dt)
		m:yaw_to_pos(target:get_pos())
		m.punch_timer = math.min(m.punch_timer + dt, m.punch_interval)
		swing(m, vector.distance(vec(0, 0, 0), target:get_pos()), vec(0, 0, 0),
			target:get_pos(), true, true)
		grug_mobs.telegraph_tick(m, dt)
	end
	for _ = 1, 45 do step(0.1) end -- 4.5 s of melee: the wind-up has begun
	check(m.temp.grug_tg_left ~= nil, "W1 the wind-up started after 4 s of melee")
	check(swings >= 3, "W1 ordinary swings before the wind-up")
	local yaw0 = rot.y
	target.pos = vec(2.5, 0, 0) -- step aside (90 degrees), still in range
	local before = swings
	step(0.1)
	check(rot.y == yaw0, "W2 the facing stays frozen while the target moves")
	for _ = 1, 10 do step(0.1) end
	check(m.temp.grug_tg_left ~= nil and rot.y == yaw0, "W2 still frozen a second later")
	check(swings == before, "W3 no ordinary swing during the wind-up")
	local bystander_hits = bystander.punched
	for _ = 1, 10 do
		if m.temp.grug_tg_left == nil then break end
		step(0.1)
	end
	check(m.temp.grug_tg_left == nil, "W4 the wind-up resolved")
	check(bystander.punched == bystander_hits + 1, "W4 a bystander in the frozen cone is hit")
	check(swings == before, "W4 the target who stepped aside is a clean miss")
	check(m.punch_timer < m.punch_interval, "W5 the cone resets the swing clock")
	step(0.1)
	check(rot.y ~= yaw0, "W5 after the wind-up the mob turns again")
	for _ = 1, 12 do step(0.1) end
	check(swings > before, "W5 the ordinary swings resume")
	-- Out of the fight the facing is never frozen.
	m.temp.grug_tg_left, m.state = 1, "stand"
	m:set_yaw(1.0)
	check(math.abs(rot.y - 1.0) < 1e-9, "W6 a winding-up mob out of a fight may turn")
end

-- ---------------------------------------------------------------------------
-- F. MOB-02: no follow scan without `follow`.
-- ---------------------------------------------------------------------------
do
	local scans = 0
	local env = {
		mob_class = {},
		is_invisible = function() return false end,
		is_player = core.is_player,
		get_distance = function(a, b) return vector.distance(a, b) end,
		core = setmetatable({get_connected_players = function()
			scans = scans + 1
			return players
		end}, {__index = core}),
	}
	load_in(cut("local function check_for(look_for, look_inside)", "\nend\n", "check_for")
		.. "\n" .. cut("function mob_class:follow_holding(clicker)", "\nend\n", "follow_holding")
		.. "\n" .. cut("function mob_class:follow_flop(dtime)", "\nend\n", "follow_flop"),
		env, "follow")
	players = {}
	local p = new_player("p", vec(1, 0, 0))
	for i = 2, 20 do new_player("p" .. i, vec(i, 0, 0)) end
	local function mob(fields)
		local m = setmetatable({state = "stand", view_range = 14, owner = "",
			type = "monster"}, {__index = env.mob_class})
		m.object = {get_pos = function() return vec(0, 0, 0) end}
		function m:follow_target() return true end
		for k, v in pairs(fields or {}) do m[k] = v end
		return m
	end
	local m = mob()
	m:follow_flop(1)
	check(scans == 0 and m.following == nil, "F1 a mob without follow scans no players")
	mob({follow = ""}):follow_flop(1)
	check(scans == 0, "F1 an empty follow scans none either")
	local lured = mob({follow = "grug_farming:wheat"})
	lured:follow_flop(1)
	check(scans == 1 and lured.following == nil, "F2 a follow item scans; nobody holds it")
	p.wield = "grug_farming:wheat"
	lured:follow_flop(1)
	check(lured.following == p, "F2 the player holding the item is followed")
	local ordered = mob({order = "follow", type = "npc", owner = "p"})
	ordered:follow_flop(1)
	check(scans == 3 and ordered.following == p, "F3 an owner's follow order still scans and follows")
end

-- ---------------------------------------------------------------------------
-- S. MOB-05: get_staticdata leaves the live mob unchanged.
-- ---------------------------------------------------------------------------
do
	local saved
	local env = {
		mob_class = {}, mobs = {}, remove_far = true, use_cmi = false,
		active_mobs = 0, random = math.random,
		get_distance = function(a, b) return vector.distance(a, b) end,
		core = setmetatable({serialize = function(t) saved = t; return "data" end},
			{__index = core}),
	}
	load_in(cut("local function clean_staticdata(self)", "\nend\n", "clean_staticdata")
		.. "\n" .. cut("local DESPAWN_MIN_DISTANCE", "function mob_class:mob_staticdata()", "despawn")
			:gsub("function mob_class:mob_staticdata%(%)$", "")
		.. "\n" .. cut("function mob_class:mob_staticdata()", "\nend\n", "mob_staticdata"),
		env, "staticdata")
	players = {}
	local chased = new_player("chased", vec(0, 0, 40))
	local m = setmetatable({name = "grug_mobs:wolf", state = "attack", attack = chased,
		following = {object = {}}, type = "monster", lifetimer = 180, health = 50,
		temp = {grug_threat = {chased = 5}}}, {__index = env.mob_class})
	m.object = {get_pos = function() return vec(0, 0, 0) end}
	local out = m:mob_staticdata()
	check(out == "data", "S1 a fighting mob is saved, not culled")
	check(m.attack == chased and m.state == "attack" and m.following ~= nil,
		"S1 the live mob keeps its target, state and follow")
	check(m.remove_ok == true, "S1 remove_ok is still set on the live mob")
	check(saved.state == "stand" and saved.attack == nil and saved.following == nil,
		"S2 the saved copy starts calm")
	check(saved.temp == nil and saved.object == nil and saved.health == 50,
		"S2 the copy keeps the persisted fields only")
	-- A calm wild mob far from every player gets the terminal marker; the
	-- live mob is not touched either.
	players = {}
	local calm = setmetatable({name = "grug_mobs:wolf", state = "walk", type = "monster",
		lifetimer = 180, remove_ok = true}, {__index = env.mob_class})
	calm.object = {get_pos = function() return vec(0, 0, 0) end}
	calm:mob_staticdata()
	check(saved._grug_despawn_terminal == true and calm.state == "walk",
		"S3 the despawn marker leaves the live mob as it was")
end

-- ---------------------------------------------------------------------------
-- P. MOB-16
-- ---------------------------------------------------------------------------
check(api:find("settings:get_bool(\"mob_pathfinding_enable\", true)", 1, true) ~= nil,
	"P1 the pathfinding switch takes its default from get_bool")
check(api:find("get_bool(\"mob_pathfinding_enable\") or true", 1, true) == nil,
	"P1 the `or true` read is gone")

print("R37 MB PORTABLE PASS checks=" .. checks)
