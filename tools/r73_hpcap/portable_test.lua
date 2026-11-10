-- Round 73 lane HPCAP portable test (LuaJIT): mobs keep health above 65,535. The
-- engine stores an object's `hp_max` property as u16 (src/object_properties.h:68,
-- clamped by read_object_properties, src/script/common/c_content.cpp:350), so the
-- game's max lives in `self.hp_max` and every reader asks it first. Loads the REAL
-- grug_mobs/levels.lua in full and cuts out of mobs/api.lua check_for_death,
-- update_tag (the infotext), clean_staticdata, mob_staticdata, is_property_name,
-- mob_activate and feed_tame, out of grug_mobs/aggro.lua the leash reset's heal, out
-- of grug_core/tag_carrier.lua refresh_hp_bar, out of grug_core/combat.lua format_k
-- and out of grug_abilities/kits_warrior.lua health_share; the fake object clamps
-- `hp_max` as the engine does. Checks:
--   A  Auditor Nemm at level 60 (113,232 HP): the property is written as 65,535, a
--      hit leaves design minus the hit, the nametag, infotext and health bar show it;
--   H  the leash reset (also idle regen's path) and feeding heal to the design max;
--   L  a level change keeps the wounded fraction above the engine limit;
--   S  save and reload: the max is back before the first tick, a hit then keeps it,
--      the first tick changes nothing; a saved boss at 0 health rolls its spawn
--      health without "interval is empty";
--   W  the warrior's below-30 % test reads the game's max;
--   N  a mob below the limit behaves as before (its max is its property);
--   D  the bosses above the limit and their numbers;
--   G  a dragon on the flat boss tier (100,000 HP) and its enrage line.
-- Usage (repo root): luajit tools/r73_hpcap/portable_test.lua [REPO]
-- Prints "R73 HPCAP PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function eq(a, b, label)
	check(a == b, label .. " (" .. tostring(a) .. " vs " .. tostring(b) .. ")")
end
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end
local function cut(text, from, to, label)
	local a = text:find(from, 1, true)
	check(a ~= nil, label .. ": start anchor")
	local b, e = text:find(to, a, true)
	check(b ~= nil, label .. ": end anchor")
	return text:sub(a, e)
end
local function load_in(source, env, label)
	local chunk = assert(loadstring(source, "=" .. label))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	return chunk()
end
local function copy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = copy(v) end
	return c
end

local U16_MAX = 65535

-- ---------------------------------------------------------------------------
-- The fake engine object: `hp_max` and the entity's own HP clamp as the engine's.
-- ---------------------------------------------------------------------------
local function new_object()
	local o = {props = {hp_max = 10, infotext = ""}, hp = 10, hp_writes = {},
		pos = {x = 0, y = 10, z = 0}}
	function o:set_properties(t)
		for k, v in pairs(t) do
			if k == "hp_max" then
				self.hp_writes[#self.hp_writes + 1] = v
				v = math.max(0, math.min(U16_MAX, math.floor(v)))
				-- c_content.cpp:356: a lower max clamps the object's own HP.
				if v < self.hp then self.hp = v end
			end
			self.props[k] = v
		end
	end
	function o:get_properties() return copy(self.props) end
	function o:set_hp(hp) self.hp = math.max(0, math.min(U16_MAX, math.floor(hp))) end
	function o:get_hp() return self.hp end
	function o:get_pos() return copy(self.pos) end
	function o:set_pos(p) self.pos = copy(p) end
	function o:set_armor_groups(g) self.armor = g end
	function o:set_texture_mod() end
	function o:get_luaentity() return self.ent end
	function o:is_player() return false end
	return o
end

-- ---------------------------------------------------------------------------
-- The real levels.lua.
-- ---------------------------------------------------------------------------
local tags = {}
local combat = read("mods/CORE/grug_core/combat.lua")
local format_k = load_in(cut(combat, "function grug_core.format_k(value)", "\nend\n", "format_k")
	.. "return grug_core.format_k\n", {grug_core = {}}, "format_k")
rawset(_G, "core", {settings = {get = function() return nil end}, log = function() end,
	serialize = function(t) return copy(t) end, deserialize = function(t) return copy(t) end})
rawset(_G, "grug_mobs", {})
rawset(_G, "grug_core", {
	nearest_tag_player_d2 = function() end,
	format_k = format_k,
	set_tag_carrier_text = function(carrier, text) tags[carrier] = text end,
})
rawset(_G, "grug_xp", {mob_xp = function(level) return 25 + 5 * level end})
dofile(repo .. "/mods/ENTITIES/grug_mobs/levels.lua")
grug_mobs.ensure_tag_carrier = function(self) return self.object end
local NEMM = "grug_mobs:auditor_nemm"
local BOAR = "grug_mobs:boar"
-- Round 73 BOSSHP: Nemm x14 (it was x20), the dragons 100,000 (it was 30,000); the
-- numbers below follow (the user, 2026-11-10).
grug_mobs.register_level_cfg(NEMM, {_grug_tier = "elite", _grug_hp_scale = 14})
grug_mobs.register_level_cfg(BOAR, {})
local DRAGON = "grug_mobs:ice_dragon"
grug_mobs.register_level_cfg(DRAGON, {_grug_tier = "boss", _grug_fixed_level = 70})

-- ---------------------------------------------------------------------------
-- The touched pieces of mobs/api.lua.
-- ---------------------------------------------------------------------------
local api = read("mods/ENTITIES/mobs/api.lua")
local function api_cut(from, to, label) return cut(api, from, to, "api " .. label) end
local mob_class = {}
function mob_class:mob_sound() end
function mob_class:set_yaw() end
function mob_class:set_animation() end
function mob_class:follow_holding() return true end
local api_env = {
	mob_class = mob_class, random = math.random, min = math.min, floor = math.floor,
	pi = math.pi, use_cmi = false, use_vh1 = false, mob_infotext = true,
	remove_far = false, grug_shutting_down = false, CHILD_GROW_TIME = 240,
	S = function(text, ...)
		local args = {...}
		return (text:gsub("@(%d)", function(i) return tostring(args[tonumber(i)]) end))
	end,
	table_copy = copy,
	grug_obstacle = {cancel_path_request = function() end,
		physics_box = function(box) return box end},
	grug_authored = function() return true end,
	at_limit = function() return false end,
	set_active_mob_counted = function() end,
	remove_mob = function() end,
	mobs = {is_creative = function() return true end, scale_mob = function() end},
}
load_in(table.concat({
	api_cut("function mob_class:update_tag(newname)", "\nend\n", "update_tag"),
	api_cut("function mob_class:check_for_death(cmi_cause)", "\nend\n", "check_for_death"),
	api_cut("local function clean_staticdata(self)", "\nend\n", "clean_staticdata"),
	api_cut("function mob_class:mob_staticdata()", "\nend\n", "staticdata"),
	api_cut("local is_property_name = {", "\n}\n", "properties"),
	api_cut("function mob_class:mob_activate(staticdata, def, dtime)", "\nend\n", "activate"),
	api_cut("function mobs:feed_tame(self, clicker, feed_count, breed, tame)", "\nend\n", "feed"),
}, "\n"), api_env, "api")
local feed_tame = api_env.mobs.feed_tame

-- The leash reset's heal (aggro.lua), the step idle regen takes as well.
local leash_heal = load_in("return function(self)\n" .. cut(read("mods/ENTITIES/grug_mobs/aggro.lua"),
	"\tlocal hp_max = self.hp_max\n\tif hp_max and hp_max > 0 then", "\t\tend\n\tend\n", "leash heal")
	.. "end\n", {}, "leash heal")

-- The health bar (tag_carrier.lua refresh_hp_bar): the percent it draws.
local bar_env = {
	HP_BARS_ENABLED = true,
	remove_hp_bar = function(row) row.removed = true end,
	object_valid = function(o) return o ~= nil end,
	same_set = function() return true end,
	ensure_hp_bar = function(row) row.hp_bar = row.hp_bar or {set_properties = function() end,
		set_observers = function() end, set_attach = function() end} return row.hp_bar end,
	bar_height_and_scale = function() return 1, 1, 1 end,
	hp_texture = function(percent) return percent end,
}
local refresh_hp_bar = load_in(cut(read("mods/CORE/grug_core/tag_carrier.lua"),
	"local function refresh_hp_bar(row, observers)", "\nend\n", "hp bar")
	.. "return refresh_hp_bar\n", bar_env, "hp bar")
local function bar_percent(ent)
	local row = {kind = "combat", parent = ent.object}
	refresh_hp_bar(row, {viewer = true})
	return not row.removed and row.hp_percent or nil
end

-- The warrior's below-30 % test (kits_warrior.lua health_share).
local health_share = load_in(cut(read("mods/PLAYER/grug_abilities/kits_warrior.lua"),
	"local function health_share(target)", "\nend\n", "health_share")
	.. "return health_share\n", {mob_ent = function(t) return t:get_luaentity() end},
	"health_share")

-- A mob as the engine makes it: a fresh table over its prototype, then activation.
local protos = {}
local function proto(name, fields)
	local p = setmetatable({name = name, type = "monster", hp_min = 5, health = 0,
		armor = 100, texture_mods = "", lifetimer = 180, sounds = {}, follow = {"x"},
		base_texture = {"x.png"}, base_colbox = {-0.5, 0, -0.5, 0.5, 1, 0.5}},
		{__index = mob_class})
	for k, v in pairs(fields or {}) do p[k] = v end
	protos[name] = p
	return p
end
proto(NEMM, {description = "Auditor Nemm", hornytimer = 0,
	_grug_visual_tier = "elite"}) -- no rescale in this fake engine
proto(BOAR)
proto(DRAGON, {description = "Ice Dragon", _grug_visual_tier = "boss"})
local function activate(name, staticdata, fields)
	local ent = setmetatable({}, {__index = protos[name]})
	ent.object = new_object()
	ent.object.ent = ent
	for k, v in pairs(fields or {}) do ent[k] = v end
	ent:mob_activate(staticdata, {textures = {{"x.png"}}}, 0)
	return ent
end
local function hit(ent, damage)
	ent.health = ent.health - damage
	ent:check_for_death("hit")
end
local function infotext(ent)
	mob_class.update_tag(ent)
	return ent.object.props.infotext
end

-- ---------------------------------------------------------------------------
-- D  the bosses above the limit (the derived HP: elite times the def's factor).
-- ---------------------------------------------------------------------------
local function boss_hp(level, scale)
	return math.floor((grug_mobs.stats_for(level, "elite")) * scale + 0.5)
end
eq(boss_hp(60, 14), 113232, "D Nemm at 60")
eq(boss_hp(69, 14), 147308, "D Nemm at 69")
eq(boss_hp(40, 14), 53592, "D Nemm at 40, its lowest level, is below the limit")
check(boss_hp(44, 14) <= U16_MAX and boss_hp(45, 14) > U16_MAX, "D Nemm crosses it at 45")
eq(boss_hp(60, 14), 113232, "D the Duewarden at 60")
eq(boss_hp(69, 14), 147308, "D the Duewarden at 69")
check(boss_hp(60, 8) <= U16_MAX and boss_hp(61, 8) > U16_MAX, "D Flintback crosses it at 61")
eq((grug_mobs.stats_for(70, "boss")), 100000, "D a dragon is above it")
check(boss_hp(70, 3) == 32436 and boss_hp(65, 3) == 28203 and
	(grug_mobs.stats_for(70, "elite")) * 1.5 <= U16_MAX,
	"D no King (x3), General (x3), leader or rift boss reaches it")
for file, scale in pairs({["skeleton_raider.lua"] = "nemm._grug_hp_scale = 14",
		["land_guard.lua"] = "duewarden._grug_hp_scale = 14",
		["golem.lua"] = "flintback._grug_hp_scale = 8"}) do
	check(read("mods/ENTITIES/grug_mobs/" .. file):find(scale, 1, true) ~= nil,
		"D " .. file .. " keeps " .. scale)
end

-- ---------------------------------------------------------------------------
-- A  a fresh Nemm at level 60, hit once.
-- ---------------------------------------------------------------------------
local nemm = activate(NEMM, nil, {_grug_spawn_level = 60})
grug_mobs.ensure_init(nemm)
eq(nemm.hp_max, 113232, "A1 the game's max is the design HP")
eq(nemm.health, 113232, "A1 full health")
eq(nemm.object.hp_writes[#nemm.object.hp_writes], U16_MAX,
	"A2 the property is written as the engine's limit, never above it")
eq(nemm.object.props.hp_max, U16_MAX, "A2 the engine property")
hit(nemm, 1234)
eq(nemm.health, 113232 - 1234, "A3 a hit leaves design minus the hit (it was 65,535)")
eq(tags[nemm.object], "Elite Auditor Nemm [Lv 60] 112k/113k", "A4 the nametag shows both numbers")
check(infotext(nemm):find("Health: 111998 / 113232", 1, true) ~= nil, "A5 the infotext's max")
eq(bar_percent(nemm), 99, "A6 the health bar after the first hit")
hit(nemm, 55382)
eq(nemm.health, 56616, "A7 a second hit")
eq(bar_percent(nemm), 50, "A7 the bar at half")
eq(tags[nemm.object], "Elite Auditor Nemm [Lv 60] 57k/113k", "A7 the nametag at half")
nemm.health = nemm.hp_max + 5000
nemm:check_for_death("heal")
eq(nemm.health, 113232, "A8 health above the game's max is clamped to it")

-- ---------------------------------------------------------------------------
-- H  heals: the leash reset (and idle regen through it) and feeding.
-- ---------------------------------------------------------------------------
hit(nemm, 100000)
leash_heal(nemm)
eq(nemm.health, 113232, "H1 the reset heals to the design max")
hit(nemm, 1)
eq(nemm.health, 113231, "H1 and the next hit does not clamp it to 65,535")
nemm.child = true -- feed_tame's shortest path: heal, then return
check(feed_tame(api_env.mobs, nemm, {get_player_name = function() return "p" end}, 8) == true,
	"H2 feeding runs")
eq(nemm.health, 113232, "H2 feeding heals to the design max, not above")
eq(nemm.object.hp, U16_MAX, "H2 the engine's own HP stays at its limit")
nemm.child = nil

-- ---------------------------------------------------------------------------
-- L  a level change keeps the wounded fraction.
-- ---------------------------------------------------------------------------
hit(nemm, 113232 - 56616) -- exactly half
grug_mobs.relevel(nemm, 69)
eq(nemm.hp_max, 147308, "L1 the new max")
eq(nemm.health, 73654, "L1 half of the new max (the old max was read, not 65,535)")
eq(nemm.object.props.hp_max, U16_MAX, "L1 the property still at the limit")
eq(tags[nemm.object], "Elite Auditor Nemm [Lv 69] 74k/147k", "L1 the nametag")

-- ---------------------------------------------------------------------------
-- S  save and reload.
-- ---------------------------------------------------------------------------
hit(nemm, 3654) -- 70000 left
local saved = nemm:mob_staticdata()
eq(saved.hp_max, 147308, "S1 the save carries the game's max")
eq(saved.health, 70000, "S1 and the health")
local back = activate(NEMM, saved)
eq(back.hp_max, 147308, "S2 the max is back on the mob before its first tick")
eq(back.object.props.hp_max, U16_MAX, "S2 the property at the limit")
eq(back.health, 70000, "S2 a wounded boss stays wounded")
hit(back, 500) -- e.g. an environment tick before the first do_custom
eq(back.health, 69500, "S3 a hit before the first tick keeps the health")
local writes = #back.object.hp_writes
grug_mobs.ensure_init(back)
eq(back.health, 69500, "S4 the first tick changes nothing")
eq(back.hp_max, 147308, "S4 the max")
eq(#back.object.hp_writes, writes, "S4 steady state: no property write")
saved = back:mob_staticdata()
saved.health = 0
local rolled = activate(NEMM, saved)
eq(rolled.health, 147308, "S5 a saved boss at 0 rolls hp_min..hp_max without an error")
-- A save from before the game kept the max on the mob (0.72.2, two reload cycles):
-- no hp_max at all; the first tick re-derives it.
saved = back:mob_staticdata()
saved.hp_max = nil
local old = activate(NEMM, saved)
eq(old.hp_max, nil, "S6 an old save without the max")
grug_mobs.ensure_init(old)
eq(old.hp_max, 147308, "S6 the first tick re-derives it")
eq(old.health, 69500, "S6 and keeps the health")

-- ---------------------------------------------------------------------------
-- W  the warrior's below-30 % test.
-- ---------------------------------------------------------------------------
back.health = 40000
check(math.abs(health_share(back.object) - 40000 / 147308) < 1e-12,
	"W1 the share of the game's max (27.2 %, it read 61 %)")

-- ---------------------------------------------------------------------------
-- G  a dragon: the flat boss tier above the limit, and the enrage line it reads
--    (boss_dragons.lua enrage: health <= hp_max * 0.5).
-- ---------------------------------------------------------------------------
local dragon = activate(DRAGON, nil)
grug_mobs.ensure_init(dragon)
eq(dragon.hp_max, 100000, "G1 a dragon's max is 100,000")
eq(dragon.health, 100000, "G1 at full health")
eq(dragon.object.props.hp_max, U16_MAX, "G1 the property at the limit")
hit(dragon, 49000)
check(dragon.health == 51000 and dragon.health > dragon.hp_max * 0.5, "G2 above half: no enrage yet")
hit(dragon, 2000)
check(dragon.health == 49000 and dragon.health <= dragon.hp_max * 0.5,
	"G2 below half of 100,000, not of 65,535")
eq(bar_percent(dragon), 49, "G3 the health bar")

-- ---------------------------------------------------------------------------
-- N  a mob below the limit, as before.
-- ---------------------------------------------------------------------------
local boar = activate(BOAR, nil, {_grug_spawn_level = 10})
grug_mobs.ensure_init(boar)
eq(boar.hp_max, 136, "N1 a level 10 boar")
eq(boar.object.props.hp_max, 136, "N1 its property is its max")
eq(boar.object.hp_writes[#boar.object.hp_writes], 136, "N1 written as is")
hit(boar, 30)
eq(boar.health, 106, "N2 a hit")
boar.health = 500
boar:check_for_death("heal")
eq(boar.health, 136, "N3 clamped to its max")
check(infotext(boar):find("Health: 136 / 136", 1, true) ~= nil, "N4 its infotext")
hit(boar, 68)
eq(bar_percent(boar), 50, "N5 its bar")
local boar_back = activate(BOAR, boar:mob_staticdata())
eq(boar_back.hp_max, 136, "N6 reloaded with its max")
eq(boar_back.health, 68, "N6 and its health")
-- A vanilla mob that never set `self.hp_max` reads its property, as before.
local plain = activate(BOAR, nil)
plain.object.props.hp_max = 20
plain.health, plain.old_health = 20, 20
plain.health = 30
plain:check_for_death("heal")
eq(plain.health, 20, "N7 without a game max the property is the max")

print("R73 HPCAP PORTABLE PASS checks=" .. checks)
