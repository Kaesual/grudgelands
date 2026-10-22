-- Round 56 lane MOBAI portable test (LuaJIT; round56-plan.md rulings 1-3,
-- D1, D2). Loads the REAL grug_core/homing.lua and mobs/grug_obstacle.lua,
-- and cuts the touched pieces out of the vendored mobs/api.lua and of
-- grug_mobs/aggro.lua, on a small fake engine (a node grid and a raycast
-- that samples the segment). Checks:
--   R  the aggro radius by level gap: gaps 0, 5, 6, 7, 9, 10, 15 and the
--      1 m floor;
--   F  general_attack's filter: a monster far below a player's level does not
--      pick the player outside the radius (and casts no sight ray for it),
--      picks it inside; guards, faction mobs and mob targets keep the full
--      view range;
--   N  the numbers: objects scanned and sight rays per scan on one probe (a
--      player among mobs of mixed level gaps), the rule off and on;
--   A  the hit alert: centred on the hit mob, its view range, and an alerted
--      mob (do_attack, the camp swarm's mark) calls nobody;
--   S  the shot range: view_range + 4, a definition's own value (copied by
--      register_mob), read at call time;
--   W  the approach: beyond the shot range a ranged mob walks (the dogfight
--      branch), stops 3 m inside and shoots there, no hovering; a blocked
--      mob (stuck, a failed search) stops inside its shot range; the melee
--      phase and stop_attack clear it; the ranged kings, fliers, melee mobs;
--   G  the review's ravine on the real navigation: blocked at 19 m it shoots
--      instead of giving its target up;
--   L  the projectile lock: the shot range and the sight check's geometry,
--      so a target seen at the edge of the shot range is locked, one beyond
--      it is not, and lock and sight agree on every probe scene;
--   B  the Bandit Archer's shoot clip.
-- Usage (repo root): luajit tools/r56_mobai/portable_test.lua [REPO]
-- Prints "R56 MOBAI PORTABLE PASS checks=<n>" or raises.
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
-- The text from `from` up to (not including) `to`.
local function cut(src, from, to, label)
	local s = src:find(from, 1, true)
	check(s ~= nil, "anchor " .. label)
	local e = src:find(to, s + #from, true)
	check(e ~= nil, "end anchor " .. label)
	return src:sub(s, e - 1)
end
local function load_in(src, env, label)
	local chunk = assert(loadstring(src, "=" .. label))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	return chunk()
end
local function near(a, b) return math.abs(a - b) < 1e-9 end

local api = read("mods/ENTITIES/mobs/api.lua")
local aggro = read("mods/ENTITIES/grug_mobs/aggro.lua")

-- ---------------------------------------------------------------------------
-- The fake engine: a node grid ("x,y,z" -> name; unset is air) and a raycast
-- that walks the segment in small steps and yields each non-air node once.
-- ---------------------------------------------------------------------------
local world = {}
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local function round(v) return math.floor(v + 0.5) end
local nodes = {
	air = {walkable = false},
	stone = {walkable = true},
	grass = {walkable = false}, -- harmless vegetation: no cover
}
vector = {
	new = function(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x, y = y, z = z}
	end,
	offset = function(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end,
	distance = function(a, b)
		local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(x * x + y * y + z * z)
	end,
	length = function(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end,
}
local rays = 0
local players_by_name = {}
core = {
	registered_nodes = nodes,
	registered_items = nodes,
	get_node = function(p)
		return {name = world[key(round(p.x), round(p.y), round(p.z))] or "air"}
	end,
	raycast = function(from, to)
		rays = rays + 1
		local list, seen = {}, {}
		local length = vector.distance(from, to)
		local steps = math.max(1, math.ceil(length / 0.01))
		for i = 0, steps do
			local t = i / steps
			local x = round(from.x + (to.x - from.x) * t)
			local y = round(from.y + (to.y - from.y) * t)
			local z = round(from.z + (to.z - from.z) * t)
			local k = key(x, y, z)
			if not seen[k] and world[k] then
				seen[k] = true
				list[#list + 1] = {type = "node", under = {x = x, y = y, z = z}}
			end
		end
		local i = 0
		local ray = {next = function()
			i = i + 1
			return list[i]
		end}
		return setmetatable(ray, {__call = function(self) return self.next() end})
	end,
	register_on_joinplayer = function() end,
	register_on_dieplayer = function() end,
	register_on_respawnplayer = function() end,
	register_on_leaveplayer = function() end,
	get_player_by_name = function(name) return players_by_name[name] end,
}

local function new_player(name, pos, level)
	local player = {player = true, level = level, pos = pos}
	function player.get_pos() return {x = player.pos.x, y = player.pos.y, z = player.pos.z} end
	function player.is_player() return true end
	function player.get_hp() return 20 end
	function player.get_player_name() return name end
	function player.get_luaentity() return nil end
	function player.get_velocity() return {x = 0, y = 0, z = 0} end
	function player.get_attach() return nil end
	function player.get_properties() return {collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}} end
	players_by_name[name] = player
	return player
end

-- mobs_redo's line_of_sight, cut out of api.lua (the sight ray of every mob).
local line_of_sight = load_in("local mob_class = {}\n" ..
	cut(api, "function mob_class:line_of_sight(pos1, pos2)", "\n-- if not flying", "line_of_sight") ..
	"\nreturn mob_class.line_of_sight",
	{get_node = core.get_node}, "line_of_sight")

-- ---------------------------------------------------------------------------
-- R. The radius table (aggro.lua's section, cut out).
-- ---------------------------------------------------------------------------
local grug_mobs = {}
local grug_core = {get_player_level = function(player) return player.level end}
load_in(cut(aggro, "grug_mobs.AGGRO_FULL_GAP = 5",
	"\n--\n-- Target acquisition for a mob that may target nobody", "aggro radius"),
	{grug_mobs = grug_mobs, grug_core = grug_core}, "aggro radius")
do
	local R = grug_mobs.aggro_radius
	check(near(R(16, 0), 16) and near(R(16, -8), 16), "R1 gap 0 and below: the full view range")
	check(near(R(16, 5), 16), "R2 gap 5: the full view range")
	check(near(R(16, 6), 12.8), "R3 gap 6: 80 % (12.8 m)")
	check(near(R(16, 7), 9.6), "R4 gap 7: 60 % (9.6 m)")
	check(near(R(16, 9), 3.2), "R5 gap 9: 20 % (3.2 m)")
	check(R(16, 10) == 1 and R(16, 15) == 1, "R6 gap 10 and 15: the 1 m floor")
	check(R(4, 8) == 1.6 or near(R(4, 8), 1.6), "R7 gap 8 of a 4 m view range: 1.6 m")
	check(R(4, 9) == 1, "R8 the floor holds under 1 m (0.8 m -> 1 m)")
	local function mob(fields)
		local m = {type = "monster", view_range = 16, _grug_level = 10}
		for k, v in pairs(fields or {}) do m[k] = v end
		return m
	end
	local p = {level = 17}
	check(near(grug_mobs.player_aggro_radius(mob(), p), 9.6), "R9 a monster 7 below: 9.6 m")
	check(grug_mobs.player_aggro_radius(mob(), {level = 15}) == nil, "R10 gap 5: no radius (full view)")
	check(grug_mobs.player_aggro_radius(mob({type = "npc"}), p) == nil, "R11 a guard (npc): full view")
	check(grug_mobs.player_aggro_radius(mob({_grug_faction = "throng"}), p) == nil,
		"R12 a mob of a faction (the King's raiders): full view")
	check(grug_mobs.player_aggro_radius(mob({type = "animal"}), p) == nil, "R13 an animal: full view")
	check(grug_mobs.player_aggro_radius(mob({_grug_level = false}), p) == nil,
		"R14 a mob without a level (vanilla mobs_redo): full view")
end

-- ---------------------------------------------------------------------------
-- F. general_attack, cut out of api.lua, with the real radius and sight ray.
-- ---------------------------------------------------------------------------
local GA_body = api:match("\nfunction mob_class:general_attack%(%)\n(.-)\nend\n")
check(GA_body ~= nil, "F general_attack found")
local scanned = 0
local function make_general_attack(rule_on)
	local env = {
		damage_enabled = true, creatura = false,
		is_player = function(o) return o.player == true end,
		is_invisible = function() return false end,
		is_peaceful_player = function() return false end,
		check_for = function() return false end,
		random = function() return 100 end,
		pairs = pairs,
		get_distance = vector.distance,
		grug_mobs = rule_on and grug_mobs or nil,
		core = {get_objects_inside_radius = nil},
	}
	return load_in("local mob_class = {}\nfunction mob_class:general_attack()\n" ..
		GA_body .. "\nend\nreturn mob_class.general_attack", env, "general_attack"), env
end
local GA_on, env_on = make_general_attack(true)
local GA_off, env_off = make_general_attack(false)

-- Every mob and player of a scene; the scan returns those within the radius.
local scene = {}
local function scan(center, radius)
	scanned = scanned + 1
	local out = {}
	for _, o in ipairs(scene) do
		if vector.distance(o.get_pos(), center) <= radius then out[#out + 1] = o end
	end
	return out
end
env_on.core.get_objects_inside_radius = scan
env_off.core.get_objects_inside_radius = scan

local function new_mob(fields, pos)
	local m = {type = "monster", view_range = 16, _grug_level = 10, attack_players = true,
		attack_chance = 0, state = "stand", _cmi_is_mob = true, name = "grug_mobs:wolf",
		group_attack = true}
	for k, v in pairs(fields) do m[k] = v end
	m.object = {get_pos = function() return {x = pos.x, y = pos.y, z = pos.z} end,
		get_luaentity = function() return m end}
	m.day_docile = function() return false end
	m.line_of_sight = line_of_sight
	m.do_attack = function(self, target) self.target = target end
	-- The scene holds the mob's object; get_luaentity resolves it.
	m.get_pos = m.object.get_pos
	m.get_luaentity = function() return m end
	return m
end
local function pick(mob, rule_on)
	mob.target = nil
	;(rule_on and GA_on or GA_off)(mob)
	return mob.target
end
do
	local player = new_player("anna", {x = 0, y = 0, z = 0}, 20)
	-- Gap 10: the radius is the 1 m floor.
	local low = new_mob({_grug_level = 10}, {x = 3, y = 0, z = 0})
	scene = {player, low}
	rays = 0
	check(pick(low, true) == nil, "F1 a mob 10 levels below does not pick the player at 3 m")
	check(rays == 0, "F2 ... and casts no sight ray for it")
	check(pick(low, false) == player, "F3 (without the rule it did)")
	local touching = new_mob({_grug_level = 10}, {x = 0.9, y = 0, z = 0})
	scene = {player, touching}
	check(pick(touching, true) == player, "F4 it picks the player at 0.9 m (inside the 1 m floor)")
	-- Gap 7: 9.6 m.
	local mid_in = new_mob({_grug_level = 13}, {x = 9, y = 0, z = 0})
	local mid_out = new_mob({_grug_level = 13}, {x = 10, y = 0, z = 0})
	scene = {player, mid_in, mid_out}
	check(pick(mid_in, true) == player and pick(mid_out, true) == nil,
		"F5 gap 7: picked at 9 m, not at 10 m")
	-- Gap 5 and below: the full view range.
	local even = new_mob({_grug_level = 15}, {x = 15, y = 0, z = 0})
	scene = {player, even}
	check(pick(even, true) == player, "F6 gap 5: picked at 15 m")
	-- A guard and a faction mob keep the full range.
	local guard = new_mob({type = "npc", _grug_level = 5}, {x = 12, y = 0, z = 0})
	local raider = new_mob({_grug_faction = "throng", _grug_level = 5}, {x = 12, y = 0, z = 1})
	scene = {player, guard, raider}
	check(pick(guard, true) == player and pick(raider, true) == player,
		"F7 a guard and a faction mob 15 below still pick the player at 12 m")
	-- Mob targets are untouched: a low monster that attacks NPCs takes the
	-- villager at 8 m and skips the high player at 3 m.
	local villager = new_mob({type = "npc", _grug_level = 1, name = "grug_mobs:villager"},
		{x = 8, y = 0, z = 0})
	local hunter = new_mob({_grug_level = 1, attack_npcs = true}, {x = 0, y = 0, z = 3})
	scene = {player, villager, hunter}
	check(pick(hunter, true) == villager, "F8 a mob target keeps the full view range")
	-- A wall still hides an in-radius player (the sight ray runs after the radius).
	world[key(2, 1, 0)] = "stone"
	world[key(2, 0, 0)] = "stone"
	local behind = new_mob({_grug_level = 20}, {x = 4, y = 0, z = 0})
	scene = {player, behind}
	check(pick(behind, true) == nil, "F9 a wall still hides the player")
	world = {}
end

-- ---------------------------------------------------------------------------
-- N. The numbers: one probe, a player (level 30) among mobs of mixed level
-- gaps, every mob running one acquisition scan; the rule off, then on.
-- ---------------------------------------------------------------------------
do
	local player = new_player("probe", {x = 0, y = 0, z = 0}, 30)
	-- {mob level (gap), distance to the player}
	local rows = {
		{30, 14}, {25, 15}, {24, 10}, {23, 10}, {22, 5}, {21, 5}, {20, 3}, {20, 0.9},
		{15, 2}, {15, 8}, {12, 12}, {28, 6},
	}
	local mobs_list = {}
	scene = {player}
	for i, row in ipairs(rows) do
		local a = (i / #rows) * 2 * math.pi
		local m = new_mob({_grug_level = row[1]},
			{x = math.cos(a) * row[2], y = 0, z = math.sin(a) * row[2]})
		mobs_list[#mobs_list + 1] = m
		scene[#scene + 1] = m
	end
	local function run(rule_on)
		local objects, picked = 0, 0
		rays, scanned = 0, 0
		local real_scan = scan
		local counting = function(c, r)
			local out = real_scan(c, r)
			objects = objects + #out
			return out
		end
		env_on.core.get_objects_inside_radius = counting
		env_off.core.get_objects_inside_radius = counting
		for _, m in ipairs(mobs_list) do
			if pick(m, rule_on) == player then picked = picked + 1 end
		end
		env_on.core.get_objects_inside_radius = scan
		env_off.core.get_objects_inside_radius = scan
		return scanned, objects, rays, picked
	end
	local s0, o0, r0, p0 = run(false)
	local s1, o1, r1, p1 = run(true)
	print(string.format("N probe (%d mobs, 1 player of level 30): before: %d scans, %d objects, "
		.. "%d sight rays, %d pick the player; after: %d scans, %d objects, %d sight rays, "
		.. "%d pick the player", #mobs_list, s0, o0, r0, p0, s1, o1, r1, p1))
	check(s0 == s1 and o0 == o1, "N1 the scan itself is unchanged (same objects)")
	check(r0 == #mobs_list and r1 < r0, "N2 fewer sight rays")
	-- Gaps 0 (14 m), 5 (15 m), 6 (10 m of 12.8), 8 (5 m of 6.4), 10 (0.9 m of
	-- 1) and 2 (6 m) pick; 7 at 10 m, 9 at 5 m, 10 at 3 m, 15 and 18 do not.
	check(p1 == 6 and r1 == p1, "N3 exactly the in-radius players are rayed and picked")
end

-- ---------------------------------------------------------------------------
-- A. The hit alert, cut out of on_punch.
-- ---------------------------------------------------------------------------
do
	local alert_src = cut(api, "\t\t-- alert others to the attack\n", "\n\tend\n\n\treturn true\nend\n",
		"alert")
	check(alert_src:find("get_objects_inside_radius(self.object:get_pos(), self.view_range)", 1, true)
		~= nil, "A0 the alert scans around the hit mob with its view range")
	local centres = {}
	local verbs_src = read("mods/ENTITIES/grug_mobs/verbs.lua")
	local marks = {}
	load_in(cut(verbs_src, "function grug_mobs.mark_alerted(ent)", "\n--\n-- Aura", "mark_alerted"),
		{grug_mobs = marks}, "mark_alerted")
	local env = {
		is_player = function(o) return o.player == true end,
		grug_mobs = {alert_kin = function(a, b) return a.group_attack and b.group_attack end,
			mark_alerted = marks.mark_alerted},
		core = {get_objects_inside_radius = function(c, r)
			centres[#centres + 1] = {c = c, r = r}
			return scan(c, r)
		end},
	}
	local alert = load_in("return function(self, hitter, hitter_name)\n" .. alert_src .. "\nend",
		env, "alert")
	local shooter = new_player("mage", {x = 0, y = 0, z = 0}, 10)
	-- The hit mob 23 m from the mage, two of its kin beside it, one kin
	-- beside the mage and one 20 m beyond the hit mob.
	local hit = new_mob({}, {x = 23, y = 0, z = 0})
	hit.state = "attack"
	local kin_near = new_mob({}, {x = 26, y = 0, z = 0})
	local kin_near2 = new_mob({}, {x = 23, y = 0, z = 5})
	local kin_by_mage = new_mob({}, {x = 2, y = 0, z = 0})
	local kin_far = new_mob({}, {x = 43, y = 0, z = 0})
	local stranger = new_mob({group_attack = false, name = "grug_mobs:stag"}, {x = 24, y = 0, z = 0})
	scene = {shooter, hit, kin_near, kin_near2, kin_by_mage, kin_far, stranger}
	for _, m in ipairs({kin_near, kin_near2, kin_by_mage, kin_far, stranger}) do
		m.temp = {}
		m.do_attack = function(self, target) self.target = target; self.state = "attack" end
	end
	alert(hit, shooter, "mage")
	check(#centres == 1 and centres[1].c.x == 23 and centres[1].r == 16,
		"A1 one scan, centred on the hit mob, radius its view range")
	check(kin_near.target == shooter and kin_near2.target == shooter,
		"A2 the kin around the hit mob join against the hitter")
	check(kin_by_mage.target == nil, "A3 the kin around the hitter do not")
	check(kin_far.target == nil and stranger.target == nil,
		"A4 nothing beyond the view range, nothing without group_attack")
	check(kin_near.temp.grug_swarm_called == true and kin_near2.temp.grug_swarm_called == true
		and kin_far.temp.grug_swarm_called == nil and hit.temp == nil,
		"A4b the alerted mobs are marked as having made their swarm call; the hit mob is not")
	local swarm = cut(verbs_src, "function grug_mobs.camp_swarm(def, opts)", "\nend\n", "camp_swarm")
	check(swarm:find("if self.temp.grug_swarm_called then\n\t\t\treturn\n\t\tend", 1, true)
		~= nil and swarm:find("self.temp.grug_swarm_called = nil", 1, true) ~= nil,
		"A4c camp_swarm calls nobody while the mark stands, and clears it after the fight")
	-- No cascade: an alerted mob takes do_attack, and do_attack (cut out of
	-- api.lua, with grug_mobs' prototype wrapper) scans nobody.
	local do_attack = load_in("local mob_class = {}\n" ..
		cut(api, "function mob_class:do_attack(player, force)", "\n-- calculate distance", "do_attack") ..
		"\nreturn mob_class.do_attack", {
			grug_nav = {forget = function() end},
			grug_obstacle = {forget_no_path = function() end},
			grug_mobs = {start_damage_pursuit = function() end},
			random = function() return 50 end,
			core = {get_objects_inside_radius = function() error("an alerted mob scanned") end},
		}, "do_attack")
	local alerted = new_mob({sounds = {}, temp = {}}, {x = 26, y = 0, z = 0})
	alerted.mob_sound = function() end
	do_attack(alerted, shooter)
	check(alerted.state == "attack" and alerted.attack == shooter,
		"A5 an alerted mob attacks the hitter and calls nobody")
	local init = read("mods/ENTITIES/grug_mobs/init.lua")
	local wrapper = cut(init, "prototype.do_attack = function(self, target, force)", "\n\tend\n",
		"do_attack wrapper")
	local idle = read("mods/ENTITIES/grug_mobs/idle_health.lua")
	local touch = cut(idle, "function grug_mobs.touch_boss_activity(self, now)", "\nend\n", "touch")
	check(not wrapper:find("get_objects_inside_radius", 1, true)
		and not touch:find("get_objects_inside_radius", 1, true),
		"A6 grug_mobs' do_attack wrapper and the boss activity mark call nobody")
	local calls = 0
	for _ in api:gmatch("ent:do_attack%(") do calls = calls + 1 end
	check(calls == 2, "A7 api.lua's only kin call is on_punch's alert (two do_attack sites)")
end

-- ---------------------------------------------------------------------------
-- S. The shot range; W. the approach decision (cut out of api.lua).
-- ---------------------------------------------------------------------------
local mobs_env = {}
local helpers = load_in(cut(api, "local GRUG_SHOT_RANGE_EXTRA = 4", "-- stop attack & reset vars",
	"shot range helpers") .. "\nreturn {range = grug_shot_range, closing = grug_ranged_closing}",
	{mobs = mobs_env}, "shot range helpers")
do
	check(mobs_env.grug_shot_range == helpers.range, "S0 published as mobs.grug_shot_range")
	check(helpers.range({view_range = 16}) == 20, "S1 the default: view_range 16 -> 20")
	check(helpers.range({view_range = 18}) == 22, "S2 a king's 18 -> 22")
	check(helpers.range({view_range = 16, _grug_shot_range = 30}) == 30,
		"S3 a definition's own shot range")
	local m = {view_range = 12}
	check(helpers.range(m) == 16, "S4 read at call time (12 -> 16) ...")
	m.view_range = 14
	check(helpers.range(m) == 18, "S5 ... and after an underground spawn raises the view range")
	check(api:find("\t\t_grug_shot_range = def._grug_shot_range,\n", 1, true) ~= nil,
		"S6 register_mob copies a definition's _grug_shot_range onto the entity")
end
do
	local function fn(args, body)
		return assert(loadstring("return function(" .. args .. ") return " .. body .. " end"))()
	end
	local melee = fn("self, ds_var, dist, in_sight, grug_closing", cut(api,
		"self.attack_type == \"dogfight\" or (self.attack_type == \"dogshoot\"\n", " then\n",
		"melee branch"))
	local shoot = fn("self, ds_var", cut(api, "self.attack_type == \"shoot\"\n", " then\n", "shoot branch"))
	check(api:find("local grug_closing = grug_ranged_closing(self, ds_var, dist)", 1, true) ~= nil,
		"W0 do_states decides the approach before the branches")
	-- One do_states step: "walk" (the dogfight branch), "shoot" or nil.
	local function step(self, ds_var, dist, in_sight)
		self.velocity = self.velocity or "run"
		local closing = helpers.closing(self, ds_var, dist)
		if melee(self, ds_var, dist, in_sight, closing) then
			self.velocity = "run"
			return "walk"
		end
		if shoot(self, ds_var) then return "shoot" end
	end
	local function archer(fields)
		local m = {attack_type = "dogshoot", reach = 3, view_range = 16, dogshoot_switch = 1,
			temp = {}, animation_current = "stand"}
		for k, v in pairs(fields or {}) do m[k] = v end
		m.set_velocity = function(self, v) self.velocity = v end
		m.set_animation = function(self, a) self.animation_current = a end
		return m
	end
	local a = archer()
	check(step(a, 1, 23, true) == "walk", "W1 an archer 23 m from its target walks closer")
	a.animation_current = "run"
	check(step(a, 1, 19, true) == "walk", "W2 inside the shot range it keeps walking ...")
	check(step(a, 1, 17.5, true) == "walk", "W3 ... until 3 m inside (17.5 m: still walking)")
	check(step(a, 1, 17, true) == "shoot" and a.velocity == 0 and a.animation_current == "stand",
		"W4 at 17 m it stops, stands and shoots")
	check(step(a, 1, 18.5, true) == "shoot" and step(a, 1, 20, true) == "shoot",
		"W5 no hovering: the target backs off to 18.5 and 20 m, it keeps shooting")
	check(step(a, 1, 20.5, true) == "walk", "W6 beyond 20 m it walks again")
	local fresh = archer()
	check(step(fresh, 1, 19, true) == "shoot" and step(fresh, 1, 10, true) == "shoot",
		"W7 a target first seen inside the shot range is shot at once")
	check(step(fresh, 1, 10, false) == "walk", "W8 without sight a ground archer walks (Round 49)")
	check(step(fresh, 2, 30, true) == "walk" and fresh.temp.grug_closing == nil,
		"W9 the melee phase is the dogfight branch, no closing state")
	check(step(fresh, 1, 2, true) == "walk", "W10 in reach: melee")
	-- The ranged kings (ds_var 0): walk beyond 22 m, then hold (no branch).
	local king = archer({dogshoot_switch = nil, view_range = 18, animation_current = "shoot"})
	check(step(king, 0, 25, true) == "walk", "W11 a ranged king closes in")
	king.animation_current = "shoot" -- a cast's clip
	check(step(king, 0, 18.5, true) == nil and king.velocity == 0
		and king.animation_current == "shoot", "W12 ... holds at 19 m and keeps its cast clip")
	check(step(king, 0, 10, true) == nil, "W13 inside the shot range it stands as before")
	-- A flier: the same fault, the same rule; without sight it still shoots.
	local wisp = archer({fly = true})
	check(step(wisp, 1, 24, true) == "walk", "W14 a flier beyond its shot range flies closer")
	local wisp2 = archer({fly = true})
	check(step(wisp2, 1, 10, false) == "shoot", "W15 a flier inside it keeps upstream's switch")
	local zombie = archer({attack_type = "dogfight", dogshoot_switch = nil})
	check(step(zombie, 0, 30, true) == "walk" and zombie.temp.grug_closing == nil,
		"W16 a melee mob is untouched")
	local pure = archer({attack_type = "shoot", dogshoot_switch = nil})
	check(step(pure, 0, 25, true) == "walk" and step(pure, 0, 16, true) == "shoot",
		"W17 a pure shooter closes in the same way")
	-- Blocked inside the shot range: the navigation's trouble ends the walk.
	local blocked = archer()
	check(step(blocked, 1, 21, true) == "walk", "W18 a blocked archer starts closing at 21 m")
	blocked.temp.grug_nav = {fails = 0}
	check(step(blocked, 1, 19, true) == "walk", "W19 at 19 m with a free way it keeps walking")
	blocked.temp.grug_nav.want = true -- stuck
	check(step(blocked, 1, 19, true) == "shoot" and blocked.temp.grug_closing == nil
		and blocked.velocity == 0, "W20 stuck at 19 m (inside 20): it stops and shoots")
	local failed = archer()
	step(failed, 1, 21, true)
	failed.temp.grug_nav = {fails = 1}
	check(step(failed, 1, 19.5, true) == "shoot", "W21 a failed search at 19.5 m: it shoots")
	local far = archer()
	far.temp.grug_nav = {fails = 2, want = true}
	check(step(far, 1, 21, true) == "walk", "W22 beyond the shot range trouble changes nothing")
	-- The melee phase clears the approach.
	local phase = archer()
	step(phase, 1, 21, true)
	check(phase.temp.grug_closing == true, "W23 closing ...")
	step(phase, 2, 19, true)
	check(phase.temp.grug_closing == nil, "W24 ... cleared by the melee phase")
	check(step(phase, 1, 19, true) == "shoot", "W25 back in the ranged phase at 19 m it shoots")
	-- stop_attack clears it too (cut out of api.lua).
	local stop_attack = load_in("local mob_class = {}\n" ..
		cut(api, "function mob_class:stop_attack()", "\n-- execute current state", "stop_attack") ..
		"\nreturn mob_class.stop_attack", {
			grug_nav = {forget = function(t) t.grug_nav = nil end},
			grug_obstacle = {forget_no_path = function() end},
		}, "stop_attack")
	local stopped = archer()
	step(stopped, 1, 25, true)
	stop_attack(stopped)
	check(stopped.temp.grug_closing == nil and stopped.state == "stand",
		"W26 stop_attack clears the approach")
end

-- ---------------------------------------------------------------------------
-- G. The review's ravine (the REAL grug_nav.lua and grug_obstacle.lua): an
-- archer that came from 21 m stands blocked 19 m from its target (no path,
-- it cannot move). It shoots and keeps its target; walking on, the
-- navigation's failed searches would give the target up.
-- ---------------------------------------------------------------------------
do
	local saved_core = core
	local us = 1000000
	local searches = 0
	core = {
		registered_nodes = {air = {name = "air", walkable = false},
			stone = {name = "stone", walkable = true}},
		get_us_time = function() return us end,
		get_node_or_nil = function(p) return {name = p.y <= 0 and "stone" or "air"} end,
		find_path = function()
			searches = searches + 1
			us = us + 50
			return nil -- the ravine: no way across
		end,
	}
	local O2 = dofile(repo .. "/mods/ENTITIES/mobs/grug_obstacle.lua")
	local nav = dofile(repo .. "/mods/ENTITIES/mobs/grug_nav.lua")
	nav.init({obstacle = O2, max_jump = 4, max_drop = 6})
	local DT = 0.1
	local target = {get_luaentity = function() return nil end,
		is_player = function() return true end,
		get_properties = function() return {collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}} end}
	local function run(fixed)
		local a = {attack_type = "dogshoot", reach = 3, view_range = 16, dogshoot_switch = 1,
			_grug_cbox = {-0.3, -0.01, -0.3, 0.3, 1.7, 0.3}, initial_properties = {stepheight = 1.1},
			jump_height = 4, fear_height = 6, temp = {grug_closing = true},
			animation_current = "run"}
		a.set_velocity = function() end
		a.set_animation = function(self, an) self.animation_current = an end
		local p, tpos = {x = 0, y = 0.51, z = 0}, {x = 19, y = 0.51, z = 0}
		local shots, gave_up = 0, false
		for _ = 1, 150 do
			us = us + math.floor(DT * 1e6)
			nav.begin_server_step(DT)
			O2.begin_server_step()
			local closing = helpers.closing(a, 1, 19)
			if not fixed then closing = true end -- the walk before the fix
			if closing then
				local _, outcome = nav.combat_step(a, p, DT, target, tpos, 19, false, false)
				if outcome == "give_up" then
					gave_up = true
					break
				end
				nav.command(a, p, 4) -- it runs and does not move
			else
				shots = shots + 1
				nav.combat_step(a, p, DT, target, tpos, 19, true, false)
				nav.command(a, p, 0)
			end
		end
		return shots, gave_up
	end
	local shots_before, gave_up_before = run(false)
	searches = 0
	local shots, gave_up = run(true)
	check(gave_up_before and shots_before == 0,
		"G1 walking on, the failed searches give the target up (the review's case)")
	check(not gave_up and shots > 0 and searches <= 1,
		"G2 with the fix it stops once stuck (" .. searches .. " failed search), shoots and keeps "
		.. "its target (" .. shots .. " shot steps of 150)")
	core = saved_core
end

-- ---------------------------------------------------------------------------
-- L. The projectile lock (the REAL homing.lua) against the sight check (the
-- REAL grug_obstacle.target_visible with mobs_redo's line_of_sight).
-- ---------------------------------------------------------------------------
do
	_G.grug_core = {}
	dofile(repo .. "/mods/CORE/grug_core/homing.lua")
	local lock = _G.grug_core.actor_projectile_lock
	local O = dofile(repo .. "/mods/ENTITIES/mobs/grug_obstacle.lua")
	local mob_pos = {x = 0, y = 10, z = 0}
	local shooter = {health = 20, line_of_sight = line_of_sight, view_range = 16}
	shooter.object = {get_pos = function() return {x = mob_pos.x, y = mob_pos.y, z = mob_pos.z} end,
		is_player = function() return false end,
		get_luaentity = function() return shooter end}
	local range = helpers.range(shooter)
	local target = new_player("tess", {x = 0, y = 10, z = 0}, 10)
	-- The arrow spawns at the body centre (do_states: cbox centre).
	local function origin() return {x = mob_pos.x, y = mob_pos.y + 0.85, z = mob_pos.z} end
	local function locked() return lock(shooter.object, target, origin(), 14, range) ~= nil end
	local function seen()
		local tp = target.get_pos()
		return vector.distance(mob_pos, tp) <= range and O.target_visible(shooter, mob_pos, tp, false)
	end
	target.pos = {x = 20, y = 10, z = 0}
	check(seen() and locked(), "L1 a target seen at the edge of the shot range (20 m) is locked")
	target.pos = {x = 18, y = 10, z = 0}
	check(locked(), "L2 18 m: locked (refused before: the lock's range was the 16 m view range)")
	target.pos = {x = 20.2, y = 10, z = 0}
	check(not locked(), "L3 20.2 m: beyond the shot range, no lock")
	-- A target one node up on a ledge, 3 m away, behind a block at the arrow's
	-- height but not at the sight ray's: seen, so locked.
	world = {}
	-- Ground under both; the target stands on a block at x = 3.
	for x = -1, 25 do world[key(x, 9, 0)] = "stone" end
	world[key(3, 10, 0)] = "stone"
	target.pos = {x = 3, y = 10.5, z = 0}
	check(seen() == locked(), "L4 a target on a ledge: lock and sight agree")
	-- Many scenes: random walls and targets; lock and sight agree on all.
	local seed = 12345
	local function rnd(n)
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed % n
	end
	local agree, accepted = 0, 0
	for _ = 1, 300 do
		world = {}
		for x = -1, 25 do world[key(x, 9, 0)] = "stone" end
		for _ = 1, rnd(4) do
			world[key(1 + rnd(20), 10 + rnd(3), rnd(3) - 1)] = rnd(3) == 0 and "grass" or "stone"
		end
		target.pos = {x = 1 + rnd(240) / 10, y = 10 + rnd(3) / 2, z = (rnd(21) - 10) / 10}
		if seen() == locked() then agree = agree + 1 end
		if locked() then accepted = accepted + 1 end
	end
	check(agree == 300 and accepted > 50 and accepted < 300,
		"L5 lock and sight agree on 300 scenes (" .. accepted .. " locked)")
	-- Vegetation is no cover for either.
	world = {[key(5, 10, 0)] = "grass", [key(5, 11, 0)] = "grass"}
	target.pos = {x = 10, y = 10, z = 0}
	check(seen() and locked(), "L6 harmless vegetation hides nobody")
	-- A dragon passes its own eye height and target lift (its line_of_sight).
	world = {[key(6, 10, 0)] = "stone", [key(6, 11, 0)] = "stone"}
	target.pos = {x = 12, y = 10, z = 0}
	check(not locked() and lock(shooter.object, target, origin(), 14, range, 5, 1) ~= nil,
		"L7 a low wall blocks the ranged sight, not a dragon's eye 5 nodes up")
	world = {}
	local verbs = read("mods/ENTITIES/grug_mobs/verbs.lua")
	check(cut(verbs, "function grug_mobs.stamp_arrow_damage(ent, mob, eye_lift, target_lift)",
		"\nend\n", "stamp"):find("mobs.grug_shot_range(mob), eye_lift, target_lift)", 1, true) ~= nil,
		"L8 every mob arrow locks with the shooter's shot range")
	check(read("mods/ENTITIES/grug_mobs/boss_dragons.lua"):find(
		"grug_mobs.stamp_arrow_damage(ent, self, opts.eye_height, 1)", 1, true) ~= nil,
		"L9 the dragon's breath locks with its own sight geometry")
end

-- ---------------------------------------------------------------------------
-- B. The Bandit Archer's shoot clip (the Poacher's mechanism).
-- ---------------------------------------------------------------------------
do
	local src = read("mods/ENTITIES/grug_mobs/bandit_archer.lua")
	check(src:find("archer.animation.shoot_start = archer.animation.punch_start", 1, true)
		and src:find("archer.animation.shoot_end = archer.animation.punch_end", 1, true)
		and src:find("archer.animation.shoot_speed = archer.animation.punch_speed", 1, true)
		and src:find("archer.animation.shoot_speed", 1, true)
			< src:find("grug_mobs.register_mob(\"grug_mobs:bandit_archer\"", 1, true),
		"B1 the Bandit Archer plays the punch clip as its shoot clip")
end

print("R56 MOBAI PORTABLE PASS checks=" .. checks)
