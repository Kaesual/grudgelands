-- Round 88 lane KNOCK portable test (LuaJIT): knockback on players by the
-- attack's weight class (round88-plan.md §2.7, §3), on the real
-- grug_core/knockback.lua, the real grug_core.knockback_pushes (cut out of
-- combat.lua), the real grug_mobs/knockback.lua over the real sub-type
-- catalogue, and the real bosses.lua hit_players (cut out). Checks:
--   A  the classes: none, light, medium, heavy by family; a sub-type by its
--      family, a base by its sub-types' family; a guard the default medium;
--      never the damage or the level (the same push at damage 1 and 500, at
--      level 1 and 60); builtin itself always gets 0;
--   B  the elite factor; a critter; a rare and the bosses one by one;
--   C  projectiles push nothing; PvP melee the fixed push; a refused or
--      ability punch, a hit without damage, an immortal player 0;
--   D  the window: a weaker push adds nothing, a stronger the difference,
--      after the window a full push; the lift once per window;
--   E  the direction: horizontal from the attacker, the one fixed lift, a
--      mob above never pushes into the floor, straight below no push;
--   F  riders: an attached player and player_api's flag push 0;
--   G  a king's Shatter: his own class, then its own 8 m/s and lift 4 in the
--      same window (the stronger counts); Cleave his class only;
--   H  the roster: every classified mob and every sub-type has a row (none
--      falls to the default), every row names a real family, rare or mob.
-- Prints "R88 KNOCK PORTABLE PASS checks=<n>" or the failures.
--
--   luajit tools/r88_knock/portable_test.lua [REPO]

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
local function near(a, b) return math.abs(a - b) < 1e-9 end
local function read(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), path)
	local text = handle:read("*a")
	handle:close()
	return text
end
local function cut(text, start, stop, label)
	local a = text:find(start, 1, true)
	assert(a, label .. ": start not found")
	local b = text:find(stop, a, true)
	assert(b, label .. ": end not found")
	return text:sub(a, b + #stop - 1)
end

-- ---- The fake engine ---------------------------------------------------------
local us = 1000000
core = {get_us_time = function() return us end}
local function advance(seconds) us = us + math.floor(seconds * 1000000 + 0.5) end

local function new_player(name, pos)
	local p = {name = name, pos = pos, pushes = {}, attach = nil, immortal = false}
	function p:is_player() return true end
	function p:get_player_name() return self.name end
	function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function p:get_luaentity() return nil end
	function p:get_attach() return self.attach end
	function p:get_armor_groups() return {fleshy = 100, immortal = self.immortal and 1 or nil} end
	function p:add_velocity(v) self.pushes[#self.pushes + 1] = v end
	-- builtin's on_punchplayer: knockback.lua's override decides, builtin adds
	-- what it returns (nothing ever).
	function p:punch(hitter, _, caps)
		local damage = caps and caps.damage_groups and caps.damage_groups.fleshy or 0
		local k = core.calculate_knockback(self, hitter, 1, caps, {x = 1, y = 0, z = 0}, 1, damage)
		check(k == 0, "builtin itself never pushes")
	end
	return p
end
local function new_mob(name, pos, fields)
	local ent = {name = name, _cmi_is_mob = true}
	for k, v in pairs(fields or {}) do ent[k] = v end
	local object = {}
	function object:is_player() return false end
	function object:get_luaentity() return ent end
	function object:get_pos() return {x = pos.x, y = pos.y, z = pos.z} end
	ent.object = object
	return object, ent
end
local function projectile(pos, source)
	local object = {}
	function object:is_player() return false end
	function object:get_luaentity() return {name = "grug_mobs:arrow_entity", _grug_source = source} end
	function object:get_pos() return pos end
	return object
end

-- ---- The real code -------------------------------------------------------------
grug_core = {in_ability_punch = false}
authoritative_swing = nil -- combat.lua's local, a global in the cut
assert(loadstring(cut(read("mods/CORE/grug_core/combat.lua"),
	"function grug_core.knockback_pushes(", "\nend\n", "knockback_pushes"),
	"=knockback_pushes"))()
assert(loadfile(ROOT .. "/mods/CORE/grug_core/knockback.lua"))()
local K = grug_core.KNOCKBACK

-- grug_mobs: family_of and the sub-types as subtypes.lua builds them.
local json = dofile(ROOT .. "/tools/r28_b1/json.lua")
local catalogue = json.parse(read("mods/ENTITIES/grug_mobs/data/subtypes.json"))
catalogue = catalogue.subtypes or catalogue
grug_mobs = {subtypes = {}}
for _, row in ipairs(catalogue) do
	grug_mobs.subtypes[row.role] = {role = row.role, base = row.base, family = row.family}
end
local function role_of(name) return name:match("^grug_mobs:(.+)$") or name end
function grug_mobs.family_of(name)
	local sub = grug_mobs.subtypes[role_of(name)]
	return sub and sub.family or role_of(name)
end
assert(loadfile(ROOT .. "/mods/ENTITIES/grug_mobs/knockback.lua"))()
check(grug_core.mob_knockback == grug_mobs.knockback_speed, "the seam is installed")

-- One hit of `hitter` on a fresh player 1 m east of the origin, in a window of
-- its own; returns the horizontal speed added (0 for none) and the velocity.
local function hit(hitter, damage, pos)
	advance(10)
	local p = new_player("ana", pos or {x = 1, y = 0, z = 0})
	p:punch(hitter, 1, {full_punch_interval = 1, damage_groups = {fleshy = damage or 10}})
	local v = p.pushes[1]
	check(#p.pushes <= 1, "one punch adds at most one velocity")
	return v and math.sqrt(v.x * v.x + v.z * v.z) or 0, v
end
local ORIGIN = {x = 0, y = 0, z = 0}
local function mob_hit(name, fields, damage)
	return hit((new_mob(name, ORIGIN, fields)), damage)
end

-- ---- A. The classes ------------------------------------------------------------
do
	check(K.none == 0 and K.light > 0 and K.light < K.medium and K.medium < K.heavy,
		"A the four classes: none 0 < light < medium < heavy")
	check(near(mob_hit("grug_mobs:bog_ooze"), 0), "A an ooze (none) pushes nothing")
	check(near(mob_hit("grug_mobs:fox"), K.light), "A a fox pushes light")
	check(near(mob_hit("grug_mobs:wolf"), K.medium), "A a wolf pushes medium")
	check(near(mob_hit("grug_mobs:bear"), K.heavy), "A a bear pushes heavy")
	-- A sub-type by its family; a base whose own role is not the family.
	check(near(mob_hit("grug_mobs:small_boar"), K.medium), "A a boar sub-type pushes as the boar family")
	check(grug_mobs.family_of("grug_mobs:jungle_ape") == "jungle_ape" and
		near(mob_hit("grug_mobs:jungle_ape"), K.heavy), "A the Jungle Ape base pushes as its sub-types' ape family")
	check(near(mob_hit("grug_mobs:bandit_archer"), K.medium), "A a bandit archer's melee pushes as the outlaws")
	check(near(mob_hit("grug_mobs:guard_accord"), K.medium), "A a guard pushes the default medium")
	-- Never the damage, never the level.
	local low = mob_hit("grug_mobs:wolf", {_grug_level = 1}, 1)
	local high = mob_hit("grug_mobs:wolf", {_grug_level = 60}, 500)
	check(near(low, K.medium) and near(high, K.medium), "A damage 1 at level 1 and 500 at level 60 push alike")
end

-- ---- B. Tiers, rares, bosses ---------------------------------------------------
do
	check(K.elite > 1, "B the elite factor raises the push")
	check(near(mob_hit("grug_mobs:wolf", {_grug_tier = "elite"}), K.medium * K.elite),
		"B an elite wolf pushes medium x the elite factor")
	check(near(mob_hit("grug_mobs:stone_golem", {_grug_tier = "elite"}), K.heavy * K.elite),
		"B an elite golem pushes heavy x the elite factor")
	check(near(mob_hit("grug_mobs:wolf", {_grug_tier = "critter"}), 0), "B a critter pushes nothing")
	check(near(mob_hit("grug_mobs:boar", {_grug_tier = "rare", _grug_rare_id = "grimtusk"}), K.heavy),
		"B Grimtusk (a rare boar) pushes heavy, no tier factor")
	check(near(mob_hit("grug_mobs:jungle_spider", {_grug_tier = "rare", _grug_rare_id = "silkfang"}), K.medium),
		"B Silkfang pushes medium")
	check(near(mob_hit("grug_mobs:kraken", {_grug_tier = "elite"}), K.heavy * K.elite), "B the Kraken, one by one")
	check(near(mob_hit("grug_mobs:ice_dragon", {_grug_tier = "boss"}), K.heavy * K.elite), "B a dragon, one by one")
	check(near(mob_hit("grug_mobs:king_dwarf", {_grug_tier = "elite"}), K.heavy * K.elite), "B a King, one by one")
	check(near(mob_hit("grug_mobs:general_accord", {_grug_tier = "elite"}), K.heavy * K.elite), "B a General")
	check(near(mob_hit("grug_mobs:auditor_nemm", {_grug_tier = "elite"}), K.medium * K.elite),
		"B Auditor Nemm, an Expedition boss, one by one")
	check(grug_mobs.knockback_class("grug_mobs:king_orc") == "heavy", "B knockback_class names a boss's class")
end

-- ---- C. Sources ----------------------------------------------------------------
do
	local shooter = new_mob("grug_mobs:skeleton_archer", ORIGIN)
	check(hit(projectile(ORIGIN, shooter)) == 0, "C a mob's arrow pushes nothing")
	check(hit(projectile(ORIGIN, nil)) == 0, "C a stray projectile pushes nothing")
	check(hit(nil) == 0, "C a punch without hitter pushes nothing")
	local bob = new_player("bob", ORIGIN)
	check(hit(bob) == 0, "C a player's plain punch (no swing) pushes nothing")
	grug_core.pvp_can_harm = function() return true end
	advance(10)
	local ana = new_player("ana", {x = 1, y = 0, z = 0})
	authoritative_swing = {player = bob, target = ana, claimed = false}
	ana:punch(bob, 1, {damage_groups = {fleshy = 30}})
	check(#ana.pushes == 1 and near(ana.pushes[1].x, K.pvp), "C PvP melee pushes the fixed PvP push")
	authoritative_swing = nil
	grug_core.in_ability_punch = true
	check(mob_hit("grug_mobs:bear") == 0, "C ability damage pushes nothing")
	grug_core.in_ability_punch = false
	check(mob_hit("grug_mobs:bear", nil, 0) == 0, "C a punch that deals nothing pushes nothing")
	advance(10)
	local stone = new_player("stone", {x = 1, y = 0, z = 0})
	stone.immortal = true
	stone:punch((new_mob("grug_mobs:bear", ORIGIN)), 1, {damage_groups = {fleshy = 10}})
	check(#stone.pushes == 0, "C an immortal player is not pushed")
end

-- ---- D. The window -------------------------------------------------------------
do
	check(K.window >= 0.5 and K.window <= 0.75, "D the window is 0.5-0.75 s")
	advance(10)
	local p = new_player("ana", {x = 1, y = 0, z = 0})
	local bear = new_mob("grug_mobs:bear", ORIGIN)
	local fox = new_mob("grug_mobs:fox", ORIGIN)
	local elite_bear = new_mob("grug_mobs:bear", ORIGIN, {_grug_tier = "elite"})
	local caps = {damage_groups = {fleshy = 10}}
	p:punch(bear, 1, caps)
	check(#p.pushes == 1 and near(p.pushes[1].x, K.heavy) and near(p.pushes[1].y, K.lift),
		"D the first push in full, with the lift")
	advance(0.1)
	p:punch(fox, 1, caps)
	p:punch(bear, 1, caps)
	check(#p.pushes == 1, "D inside the window a weaker or equal push adds nothing (pushes do not add up)")
	advance(0.2)
	p:punch(elite_bear, 1, caps)
	check(#p.pushes == 2 and near(p.pushes[2].x, K.heavy * K.elite - K.heavy) and p.pushes[2].y == 0,
		"D a stronger push adds only the difference, and no second lift")
	advance(K.window)
	p:punch(fox, 1, caps)
	check(#p.pushes == 3 and near(p.pushes[3].x, K.light) and near(p.pushes[3].y, K.lift),
		"D after the window the next push counts in full")
	-- A pack of five swinging in one step: one push.
	advance(10)
	local q = new_player("bea", {x = 1, y = 0, z = 0})
	for _ = 1, 5 do q:punch((new_mob("grug_mobs:lava_flan", ORIGIN, {_grug_pack = 1})), 1, caps) end
	check(#q.pushes == 1 and near(q.pushes[1].x, K.light), "D a pack of five pushes once")
	-- The window is per player.
	advance(10)
	local r, s = new_player("r", {x = 1, y = 0, z = 0}), new_player("s", {x = 1, y = 0, z = 0})
	r:punch(bear, 1, caps)
	s:punch(bear, 1, caps)
	check(#r.pushes == 1 and #s.pushes == 1, "D one window per player")
end

-- ---- E. Direction and lift -----------------------------------------------------
do
	local speed, v = hit((new_mob("grug_mobs:bear", {x = 0, y = 3, z = 0})), 10, {x = 3, y = 0, z = 4})
	check(near(speed, K.heavy) and near(v.x, K.heavy * 0.6) and near(v.z, K.heavy * 0.8),
		"E horizontal, from the attacker to the player")
	check(near(v.y, K.lift) and v.y > 0, "E a mob above pushes level with the one lift, never into the floor")
	local _, w = hit((new_mob("grug_mobs:bear", {x = 0, y = -2, z = 0})), 10, {x = 0, y = 0, z = -2})
	check(near(w.y, K.lift) and near(w.z, -K.heavy), "E a mob below: the same lift")
	check(hit((new_mob("grug_mobs:bear", {x = 1, y = -3, z = 0}))) == 0, "E straight below: no direction, no push")
end

-- ---- F. Riders -----------------------------------------------------------------
do
	advance(10)
	local p = new_player("rider", {x = 1, y = 0, z = 0})
	p.attach = {}
	p:punch((new_mob("grug_mobs:bear", ORIGIN)), 1, {damage_groups = {fleshy = 10}})
	check(#p.pushes == 0, "F an attached player is not pushed")
	check(grug_core.push_player(p, ORIGIN, 8, 4) == nil and #p.pushes == 0, "F nor by a boss's own push")
	p.attach = nil
	player_api = {player_attached = {rider = true}}
	p:punch((new_mob("grug_mobs:bear", ORIGIN)), 1, {damage_groups = {fleshy = 10}})
	check(#p.pushes == 0, "F player_api's attached flag: not pushed")
	player_api = nil
end

-- ---- G. A king's Shatter and Cleave --------------------------------------------
do
	local players = {}
	local env = setmetatable({
		player_enemy_of = function() return true end,
		core = setmetatable({
			get_objects_inside_radius = function() return players end,
			is_player = function(o) return o.is_player ~= nil and o:is_player() end,
			yaw_to_dir = function() return {x = 1, y = 0, z = 0} end,
		}, {__index = core}),
	}, {__index = _G})
	local chunk = assert(loadstring(cut(read("mods/ENTITIES/grug_mobs/bosses.lua"),
		"local function hit_players(", "\nend\n", "hit_players") .. "\nreturn hit_players", "=hit_players"))
	setfenv(chunk, env)
	local hit_players = chunk()
	local king_object, king = new_mob("grug_mobs:king_dwarf", ORIGIN, {_grug_tier = "elite", damage = 10})
	function king_object:get_yaw() return 0 end
	advance(10)
	local p = new_player("ana", {x = 2, y = 0, z = 0})
	function p:get_hp() return 20 end
	players = {p}
	hit_players(king, 6, 3, false, 8, "throng")
	local total_x, total_y = 0, 0
	for _, v in ipairs(p.pushes) do total_x, total_y = total_x + v.x, total_y + v.y end
	check(#p.pushes == 2 and near(p.pushes[1].x, K.heavy * K.elite), "G Shatter's hit pushes by the King's class")
	check(near(total_x, 8) and near(total_y, 4), "G then its own 8 m/s with lift 4 adds only the difference")
	advance(10)
	local q = new_player("bea", {x = 2, y = 0, z = 0})
	function q:get_hp() return 20 end
	players = {q}
	hit_players(king, 6, 3, true, 0, "throng")
	check(#q.pushes == 1 and near(q.pushes[1].x, K.heavy * K.elite), "G Cleave pushes by the King's class only")
end

-- ---- H. The roster -------------------------------------------------------------
do
	local FAMILIES, BOSSES, RARES = grug_mobs.KNOCKBACK_FAMILIES, grug_mobs.KNOCKBACK_BOSSES,
		grug_mobs.KNOCKBACK_RARES
	local base_family = {}
	for _, sub in pairs(grug_mobs.subtypes) do base_family[role_of(sub.base)] = sub.family end
	local function has_row(name)
		return BOSSES[name] ~= nil or FAMILIES[grug_mobs.family_of(name)] ~= nil
			or FAMILIES[base_family[role_of(name)] or ""] ~= nil
	end
	-- Every mob with a fixed disposition (disposition.lua) and every sub-type.
	local roster, families = {}, {}
	local text = read("mods/ENTITIES/grug_mobs/disposition.lua")
	for list in text:gmatch('classify%("%a+", {(.-)}%)') do
		for role in list:gmatch('"([%w_]+)"') do roster[#roster + 1] = "grug_mobs:" .. role end
	end
	for role in pairs(grug_mobs.subtypes) do roster[#roster + 1] = "grug_mobs:" .. role end
	check(#roster > 250, "H the roster is read (" .. #roster .. ")")
	for _, name in ipairs(roster) do
		check(has_row(name), "H " .. name .. " has a row of its own")
		families[grug_mobs.family_of(name)] = true
		families[base_family[role_of(name)] or ""] = true
	end
	for family, class in pairs(FAMILIES) do
		check(families[family] == true, "H family " .. family .. " exists")
		check(K[class] ~= nil, "H family " .. family .. ": class " .. tostring(class))
	end
	for name, row in pairs(BOSSES) do
		check(text:find('"' .. role_of(name) .. '"', 1, true) ~= nil, "H boss " .. name .. " is a mob")
		check(K[row[1]] ~= nil, "H boss " .. name .. ": class " .. tostring(row[1]))
	end
	local rares, count = read("mods/ENTITIES/grug_mobs/rares.lua"), 0
	for id in rares:gmatch('\ngrug_mobs%.register_rare%("([%w_]+)"') do
		count = count + 1
		check(RARES[id] ~= nil, "H rare " .. id .. " has a row")
	end
	local rows = 0
	for id, class in pairs(RARES) do
		rows = rows + 1
		check(K[class] ~= nil, "H rare " .. id .. ": class " .. tostring(class))
	end
	check(count == 10 and rows == count, "H every rare has a row and every row a rare (" .. count .. ", " .. rows .. ")")
end

if failures > 0 then
	error(("R88 KNOCK PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R88 KNOCK PORTABLE PASS checks=%d"):format(checks))
