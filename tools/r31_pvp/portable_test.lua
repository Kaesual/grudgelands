-- Round 31 Lane P1 portable test (docs/planning/pvp-plan.md §8, "headless").
-- Loads the REAL grug_pvp (rules.lua and init.lua) and grug_core's
-- combat.lua, combat_ray.lua, death_messages.lua and environment_damage.lua
-- under small stubs, with os.time and the engine clock under test control:
--   L  location flag: contested and enemy land flag, own peaceful land
--      clears, deep ocean and dragon channels keep the last value (sail out
--      unflagged, sail home flagged), land below y -701 under a capital;
--   B  the button: 60 s from the press, a press restarts it;
--   C  contact: 60 s flag and 10 s PvP combat for dealer and receiver, the
--      shared combat timer for 10 s (a later 5 s mark does not shorten it),
--      support contact only on a player in PvP combat;
--   H  the hp-change seam: a landed enemy player hit (HP or absorb) is
--      contact, a dodge, a mob hit or an own-faction pair is not;
--   T  the can_harm / can_support table;
--   G  the gate at impact: deal_ability_damage punches nobody unless both
--      enemy players are flagged; the crosshair ray classifies an unflagged
--      enemy as "protected" (no target), a flagged one as hostile;
--   D  death clears button, contact and location; kill credit to every
--      enemy with landed damage in the last 15 s, the killing blow to the
--      lethal hit's owner; NPC counters;
--   O  logout death: leaving in PvP combat credits the kill and announces it,
--      the next join dies through the normal path without a second message
--      or credit; leaving outside PvP combat, or at shutdown, is no death;
--   R  change callbacks fire once per change (and once at join).
-- Usage (repo root): luajit tools/r31_pvp/portable_test.lua [REPO]
local repo = arg[1] or "."

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

local function deep_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deep_copy(v) end
	return out
end
table.copy = deep_copy
function string.trim(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end

-- Clocks: os.time() for the PvP timers, core.get_us_time() for combat.
local clock = 1700000000
local us_time = 1000000
os.time = function() return clock end -- luacheck: ignore
local function advance(seconds)
	clock = clock + seconds
	us_time = us_time + seconds * 1000000
end

local hp_modifiers, globalsteps = {}, {}
local callbacks = {join = {}, leave = {}, die = {}, shutdown = {}}
local commands, afters, chat = {}, {}, {}
local connected = {}
local raycast_hits = {}
core = {
	registered_items = {}, registered_entities = {}, registered_nodes = {},
	get_us_time = function() return us_time end,
	get_item_group = function() return 0 end,
	register_on_player_hpchange = function(fn, modifier)
		if modifier then hp_modifiers[#hp_modifiers + 1] = fn end
	end,
	register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
	register_on_joinplayer = function(fn) table.insert(callbacks.join, fn) end,
	register_on_leaveplayer = function(fn) table.insert(callbacks.leave, fn) end,
	register_on_dieplayer = function(fn) table.insert(callbacks.die, fn) end,
	register_on_shutdown = function(fn) table.insert(callbacks.shutdown, fn) end,
	register_chatcommand = function(name, def) commands[name] = def end,
	get_connected_players = function()
		local out = {}
		for _, p in ipairs(connected) do out[#out + 1] = p end
		return out
	end,
	get_player_by_name = function(name)
		for _, p in ipairs(connected) do
			if p.name == name then return p end
		end
	end,
	is_player = function(obj) return type(obj) == "table" and obj.is_player ~= nil and obj:is_player() end,
	chat_send_player = function() end,
	chat_send_all = function(text) chat[#chat + 1] = text end,
	colorize = function(_, text) return text end,
	add_particlespawner = function() end,
	after = function(_, fn) afters[#afters + 1] = fn end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	get_modpath = function() return repo .. "/mods/PLAYER/grug_pvp" end,
	get_current_modname = function() return "grug_pvp" end,
	log = function() end,
	raycast = function()
		local index = 0
		return function()
			index = index + 1
			return raycast_hits[index]
		end
	end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
local function vec(x, y, z) return {x = x, y = y, z = z} end
vector = {
	new = function(x, y, z)
		if type(x) == "table" then return vec(x.x, x.y, x.z) end
		return vec(x, y, z)
	end,
	offset = function(p, x, y, z) return vec(p.x + x, p.y + y, p.z + z) end,
	add = function(a, b) return vec(a.x + b.x, a.y + b.y, a.z + b.z) end,
	multiply = function(a, s) return vec(a.x * s, a.y * s, a.z * s) end,
	length = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end,
	normalize = function(a)
		local l = math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
		return vec(a.x / l, a.y / l, a.z / l)
	end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
}

local function run_afters()
	local pending = afters
	afters = {}
	for _, fn in ipairs(pending) do fn() end
end

-- World stub: x < 0 own (accord) peaceful land, 0 <= x < 100 contested,
-- 100 <= x < 200 deep ocean, x >= 200 throng peaceful land; land at
-- y <= -701 is contested (grug_zones' order: ocean first, then depth).
grug_zones = {
	pvp_rule_at = function(pos)
		if pos.x >= 100 and pos.x < 200 then return nil end
		if pos.y <= -701 then return "contested" end
		if pos.x >= 0 and pos.x < 100 then return "contested" end
		return "peaceful"
	end,
	faction_at = function(pos)
		if pos.x < 0 then return "accord" end
		if pos.x >= 200 then return "throng" end
		return nil
	end,
}

grug_core = {}
dofile(repo .. "/mods/CORE/grug_core/combat_ray.lua")
dofile(repo .. "/mods/CORE/grug_core/combat.lua")
dofile(repo .. "/mods/CORE/grug_core/death_messages.lua")
dofile(repo .. "/mods/CORE/grug_core/environment_damage.lua")
eq(#hp_modifiers, 1, "one central hp-change modifier")
local modifier = hp_modifiers[1]
function grug_core.player_in_creation_stasis() return false end
-- Armor is not under test: the damage the gate lets through lands whole.
function grug_core.apply_player_armor(_, damage) return damage end

grug_factions = {}
function grug_factions.get_faction(p) return p.faction end
function grug_factions.get_object_faction(obj)
	if obj:is_player() then return obj.faction end
	local ent = obj:get_luaentity()
	return ent and ent._grug_faction
end
function grug_factions.hostile(a, b)
	local fa, fb = grug_factions.get_object_faction(a), grug_factions.get_object_faction(b)
	return fa ~= nil and fb ~= nil and fa ~= fb
end
function grug_factions.same_faction(a, b)
	local fa, fb = grug_factions.get_object_faction(a), grug_factions.get_object_faction(b)
	return fa ~= nil and fa == fb
end
function grug_core.opposing_faction(id) return id == "accord" and "throng" or "accord" end
function grug_core.get_player_faction(name)
	local p = core.get_player_by_name(name)
	return p and p.faction
end

local eligible_kill
grug_mobs = {register_on_eligible_kill = function(fn) eligible_kill = fn end}

dofile(repo .. "/mods/PLAYER/grug_pvp/init.lua")
check(grug_core.pvp_can_harm == grug_pvp.can_harm, "grug_pvp installs the impact gate")
check(type(grug_core.pvp_hit_landed) == "function", "grug_pvp installs the landed-hit hook")
check(eligible_kill ~= nil, "NPC counters hook grug_mobs' eligible kills")
local R = grug_pvp.rules

local function new_meta()
	local store = {}
	local m = {store = store}
	function m:get_string(k) return store[k] or "" end
	function m:set_string(k, v) store[k] = (v ~= "" and v) or nil end
	function m:get_int(k) return math.floor(tonumber(store[k]) or 0) end
	function m:set_int(k, v) store[k] = tostring(v) end
	return m
end

local function new_player(name, faction, pos)
	local p = {name = name, faction = faction, hp = 100, hp_max = 100,
		pos = pos or vec(-50, 10, 0), meta = new_meta(), punched = 0}
	function p:get_player_name() return self.name end
	function p:get_hp() return self.hp end
	function p:get_properties() return {hp_max = self.hp_max, eye_height = 1.5} end
	function p:get_pos() return vec(self.pos.x, self.pos.y, self.pos.z) end
	function p:get_meta() return self.meta end
	function p:is_player() return true end
	function p:get_luaentity() return nil end
	function p:punch(attacker, _, caps)
		self.punched = self.punched + 1
		local damage = caps.damage_groups.fleshy
		self:set_hp(self.hp - damage, {type = "punch", object = attacker})
	end
	function p:set_hp(hp, reason)
		local change = hp - self.hp
		if change < 0 then change = modifier(self, change, reason or {type = "set_hp"}) end
		self.hp = math.max(0, math.min(self.hp_max, self.hp + change))
		if self.hp == 0 then
			for _, fn in ipairs(callbacks.die) do fn(self, reason or {type = "set_hp"}) end
		end
	end
	return p
end

local function join(p)
	connected[#connected + 1] = p
	for _, fn in ipairs(callbacks.join) do fn(p) end
end
local function leave(p, keep_connected)
	for _, fn in ipairs(callbacks.leave) do fn(p, false) end
	if keep_connected then return end
	for i, q in ipairs(connected) do
		if q == p then table.remove(connected, i) break end
	end
end
local function tick()
	grug_pvp.location_tick()
end
local function state(p) return grug_pvp.state(p) end

-- Change callback recorder.
local changes = {}
grug_pvp.register_on_change(function(player, s)
	changes[#changes + 1] = {name = player:get_player_name(), flagged = s.flagged,
		reason = s.reason, pvp_combat = s.pvp_combat}
end)
local function changes_of(name)
	local out = {}
	for _, c in ipairs(changes) do
		if c.name == name then out[#out + 1] = c end
	end
	return out
end

------------------------------------------------------------------------------
-- L: location flag (rulings 2 and 3), through the real tick.
------------------------------------------------------------------------------
do
	-- Pure mapping first.
	eq(R.location(false, "contested", nil, "accord"), "contested", "L: contested flags")
	eq(R.location(false, "peaceful", "throng", "accord"), "enemy", "L: enemy territory flags")
	eq(R.location("contested", "peaceful", "accord", "accord"), false, "L: own peaceful clears")
	eq(R.location("contested", nil, nil, "accord"), "contested", "L: ocean keeps flagged")
	eq(R.location(false, nil, nil, "accord"), false, "L: ocean keeps unflagged")

	local a = new_player("loc_a", "accord", vec(-50, 10, 0))
	join(a)
	local s = state(a)
	check(not s.flagged and s.reason == nil, "L: own peaceful land at join is safe")
	eq(#changes_of("loc_a"), 1, "R: one change report at join")
	tick()
	eq(#changes_of("loc_a"), 1, "R: an unchanged tick reports nothing")
	-- Sail out from own coast: stays unflagged at sea.
	a.pos = vec(150, 0, 0); tick()
	check(not state(a).flagged, "L: sailing out from own land stays unflagged")
	-- Arrive on contested land (an island): flagged.
	a.pos = vec(50, 10, 0); tick()
	s = state(a)
	check(s.flagged and s.reason == "location_contested", "L: contested land flags")
	eq(#changes_of("loc_a"), 2, "R: flagging reports once")
	-- Sail home: flagged at sea until own land.
	a.pos = vec(150, 0, 0); tick()
	check(state(a).flagged, "L: sailing home keeps the flag at sea")
	a.pos = vec(-10, 10, 0); tick()
	check(not state(a).flagged, "L: own peaceful land clears at once without contact")
	eq(#changes_of("loc_a"), 3, "R: unflagging reports once")
	-- Enemy territory.
	a.pos = vec(250, 10, 0); tick()
	s = state(a)
	check(s.flagged and s.reason == "location_enemy", "L: enemy peaceful land flags")
	-- Below -701 under an own capital (own peaceful surface).
	a.pos = vec(-50, -701, 0); tick()
	eq(state(a).reason, "location_contested", "L: own land at y -701 is contested")
	a.pos = vec(-50, -700, 0); tick()
	check(not state(a).flagged, "L: own land at y -700 is safe")
	-- Persisted on change; join recomputes from the position, ocean keeps it.
	a.pos = vec(50, 10, 0); tick()
	eq(a.meta:get_string("grug_pvp:loc"), "contested", "L: location persisted on change")
	a.pos = vec(150, 0, 0)
	leave(a)
	join(a)
	eq(state(a).reason, "location_contested", "L: join at sea keeps the stored flag")
	leave(a)
	a.pos = vec(-50, 10, 0)
	join(a)
	check(not state(a).flagged, "L: join on own land recomputes to safe")
	-- A dead player is not sampled (death cleared the record).
	a.hp = 0
	a.pos = vec(50, 10, 0); tick()
	check(not state(a).flagged, "L: a dead player's location is not sampled")
	a.hp = 100
	leave(a)
end

------------------------------------------------------------------------------
-- B: the button.
------------------------------------------------------------------------------
do
	local a = new_player("btn_a", "accord")
	join(a)
	check(grug_pvp.flag_now(a), "B: the button works")
	local s = state(a)
	check(s.flagged and s.reason == "button" and s.seconds_left == 60,
		"B: flagged for 60 s with the button reason")
	eq(a.meta:get_string("grug_pvp:button_until"), tostring(clock + 60), "B: persisted on press")
	advance(59); tick()
	check(state(a).flagged and state(a).seconds_left == 1, "B: still flagged at 59 s")
	grug_pvp.flag_now(a)
	eq(state(a).seconds_left, 60, "B: pressing again restarts the 60 s")
	advance(60); tick()
	check(not state(a).flagged, "B: safe after 60 s")
	local own = changes_of("btn_a")
	eq(own[#own].flagged, false, "R: the expiry is reported by the tick")
	-- Inside contested ground the location wins the reason.
	grug_pvp.flag_now(a)
	a.pos = vec(50, 10, 0); tick()
	eq(state(a).reason, "location_contested", "B: the location is the stronger reason")
	leave(a)
end

------------------------------------------------------------------------------
-- T, C, H, G: the gate, contact, the seam, impact and ray.
------------------------------------------------------------------------------
local function fresh_pair(prefix)
	local a = new_player(prefix .. "_a", "accord", vec(-50, 10, 0))
	local t = new_player(prefix .. "_t", "throng", vec(250, 10, 0))
	local h = new_player(prefix .. "_h", "accord", vec(-50, 10, 0))
	join(a); join(t); join(h)
	return a, t, h
end

do
	local a, t, h = fresh_pair("gate")
	-- T: the table. a (accord) and t (throng); t stands in its own land.
	t.pos = vec(250, 10, 0)
	local function set(p, flagged)
		p.pos = flagged and vec(50, 10, 0) or (p.faction == "accord" and vec(-50, 10, 0) or vec(250, 10, 0))
	end
	for _, row in ipairs({{false, false, false}, {true, false, false},
			{false, true, false}, {true, true, true}}) do
		set(a, row[1]); set(t, row[2]); tick()
		eq(grug_pvp.can_harm(a, t), row[3], "T: can_harm a=" .. tostring(row[1]) .. " t=" .. tostring(row[2]))
		eq(grug_pvp.can_harm(t, a), row[3], "T: can_harm is symmetric a=" .. tostring(row[1]) .. " t=" .. tostring(row[2]))
	end
	check(not grug_pvp.can_harm(a, h), "T: own faction is never harmable")
	for _, row in ipairs({{false, false, true}, {true, false, true},
			{false, true, false}, {true, true, true}}) do
		set(h, row[1]); set(a, row[2]); tick()
		eq(grug_pvp.can_support(h, a), row[3], "T: can_support helper=" .. tostring(row[1]) .. " target=" .. tostring(row[2]))
	end

	-- G: the gate at impact.
	set(a, false); set(t, true); tick()
	local hp = t.hp
	eq(grug_core.deal_ability_damage(a, t, 10), 0, "G: unflagged attacker deals nothing")
	eq(t.punched, 0, "G: no punch reaches an unflagged pair")
	eq(t.hp, hp, "G: no HP lost")
	check(not grug_core.in_combat(a) and not grug_core.in_combat(t), "G: a refused cast arms no combat")
	set(a, true); tick()
	local dealt = grug_core.deal_ability_damage(a, t, 10)
	check(dealt > 0, "G: both flagged: the cast lands")
	eq(t.punched, 1, "G: one punch")
	eq(t.hp, hp - dealt, "G: HP lost")

	-- C/H: that landed hit was contact for both through the hp-change seam.
	local sa, st = state(a), state(t)
	check(sa.pvp_combat and st.pvp_combat, "C: landed damage: PvP combat for both")
	check(grug_core.in_combat(a) and grug_core.in_combat(t), "C: shared combat state for both")
	-- Back home, the contact keeps both flagged for 60 s.
	set(a, false); set(t, false); tick()
	sa = state(a)
	check(sa.flagged and sa.reason == "contact" and sa.seconds_left == 60,
		"C: contact keeps the flag in own land")
	advance(1)
	grug_core.mark_in_combat(a) -- a 5 s mark (e.g. a dodged hit) inside it
	advance(8); tick()
	check(state(a).pvp_combat, "C: PvP combat at 9 s")
	check(grug_core.in_combat(a), "C: a 5 s mark does not cut the 10 s timer short")
	advance(1); tick()
	check(not state(a).pvp_combat, "C: PvP combat ends at 10 s")
	check(not grug_core.in_combat(a), "C: the combat timer ends at 10 s")
	advance(49); tick()
	check(state(a).flagged and state(a).seconds_left == 1, "C: flagged at 59 s")
	advance(1); tick()
	check(not state(a).flagged and not state(t).flagged, "C: safe 60 s after the last contact")

	-- H: what is and is not contact.
	set(a, true); set(t, true); tick()
	grug_core.get_dodge_chance = function() return 1 end
	local before = state(t).pvp_combat
	eq(modifier(t, -5, {type = "punch", object = a}), 0, "H: a dodged hit loses nothing")
	eq(state(t).pvp_combat, before, "H: a dodge is no contact")
	grug_core.get_dodge_chance = function() return 0 end
	grug_core.add_absorb(t, "test", 50, 30, h)
	eq(modifier(t, -5, {type = "punch", object = a,
		custom_type = grug_core.ARMOR_APPLIED_CUSTOM_TYPE}), 0, "H: fully absorbed")
	check(state(t).pvp_combat and state(a).pvp_combat, "H: absorb consumed is contact")
	local mob = {is_player = function() return false end,
		get_luaentity = function() return {name = "grug_mobs:wolf"} end}
	local g = new_player("gate_g", "throng", vec(50, 10, 0))
	join(g); tick()
	modifier(g, -5, {type = "punch", object = mob})
	check(not state(g).pvp_combat, "H: a mob hit is no contact")
	modifier(g, -5, {type = "punch", object = t, custom_type = grug_core.ARMOR_APPLIED_CUSTOM_TYPE})
	check(not state(g).pvp_combat, "H: an own-faction pair is no contact")

	-- C: support contact (ruling 7b).
	advance(20); tick()
	set(h, true); tick()
	grug_pvp.support_contact(h, a)
	check(not state(h).pvp_combat, "C: support on a player out of PvP combat is no contact")
	grug_pvp.contact(t, a)
	set(h, false); tick()
	grug_pvp.support_contact(h, a)
	check(state(h).pvp_combat and state(h).reason == "contact", "C: support on a player in PvP combat is contact")

	-- G: the crosshair ray.
	advance(120); tick()
	set(a, false); set(t, true); tick()
	raycast_hits = {{type = "object", ref = t, intersection_point = vec(3, 0, 0)}}
	local ray = grug_core.combat_ray(a, 10, {origin = vec(0, 0, 0), direction = vec(1, 0, 0)})
	check(ray.status == "aim_miss" and ray.reason == "protected" and ray.relation == "protected"
		and ray.blocker == t, "G: an unflagged enemy is a protected blocker, no target")
	set(a, true); tick()
	ray = grug_core.combat_ray(a, 10, {origin = vec(0, 0, 0), direction = vec(1, 0, 0)})
	check(ray.status == "target" and ray.reason == "hostile", "G: a flagged pair is a target")
	raycast_hits = {{type = "object", ref = h, intersection_point = vec(3, 0, 0)}}
	ray = grug_core.combat_ray(a, 10, {origin = vec(0, 0, 0), direction = vec(1, 0, 0)})
	eq(ray.reason, "friendly", "G: an ally stays friendly")
	raycast_hits = {}
	leave(a); leave(t); leave(h); leave(g)
end

------------------------------------------------------------------------------
-- D: death clear, kill credit, NPC counters.
------------------------------------------------------------------------------
do
	local a, t, h = fresh_pair("kill")
	local b = new_player("kill_b", "accord", vec(50, 10, 0))
	join(b)
	a.pos, t.pos, h.pos = vec(50, 10, 0), vec(50, 10, 0), vec(50, 10, 0)
	tick()
	grug_pvp.flag_now(t)
	-- b hit t 16 s ago (no credit), h 10 s ago (credit), a lands the kill.
	grug_pvp.contact(b, t)
	advance(6)
	grug_pvp.contact(h, t)
	advance(10)
	t.hp = 5
	grug_core.deal_ability_damage(a, t, 10)
	eq(t.hp, 0, "D: lethal hit")
	local sa, sh, sb, st = grug_pvp.stats(a), grug_pvp.stats(h), grug_pvp.stats(b), grug_pvp.stats(t)
	check(sa.kills == 1 and sa.killing_blows == 1, "D: the lethal hit's owner gets the kill and the killing blow")
	check(sh.kills == 1 and sh.killing_blows == 0, "D: damage within 15 s is a kill without the blow")
	eq(sb.kills, 0, "D: damage 16 s ago earns nothing")
	eq(st.deaths, 1, "D: the victim counts a death to players")
	eq(t.meta:get_int("grug_pvp:stat_deaths"), 1, "D: counters persisted on death")
	local s = state(t)
	check(not s.flagged and not s.pvp_combat, "D: death clears location, button and contact")
	check(not grug_core.in_combat(t), "D: death ends combat")
	eq(t.meta:get_string("grug_pvp:button_until"), "", "D: cleared timers persisted")
	-- An environmental death credits nobody.
	t.hp = 100
	advance(30)
	t:set_hp(0, {type = "fall"})
	eq(grug_pvp.stats(t).deaths, 1, "D: a fall without PvP damage is no PvP death")
	t.hp = 100
	-- NPC counters: enemy guards, royal guards and kings; own guards do not count.
	eligible_kill(a, {name = "grug_mobs:guard_throng", _grug_faction = "throng"})
	eligible_kill(a, {name = "grug_mobs:royal_guard_orc", _grug_faction = "throng"})
	eligible_kill(a, {name = "grug_mobs:king_orc", _grug_faction = "throng"})
	eligible_kill(a, {name = "grug_mobs:guard_accord", _grug_faction = "accord"})
	eligible_kill(a, {name = "grug_mobs:wolf"})
	eligible_kill(a, {name = "grug_mobs:fortress_x", _grug_faction = "throng", _grug_pvp_kind = "general"})
	grug_pvp.count_npc_kill(a, "captain")
	sa = grug_pvp.stats(a)
	check(sa.guards == 2 and sa.kings == 1 and sa.generals == 1 and sa.captains == 1,
		"D: NPC counters (guards 2, kings 1, generals 1, captains 1)")
	leave(a); leave(t); leave(h); leave(b)
end

------------------------------------------------------------------------------
-- O: logout death (ruling 9).
------------------------------------------------------------------------------
do
	local a, t = fresh_pair("out")
	a.pos, t.pos = vec(50, 10, 0), vec(50, 10, 0)
	tick()
	grug_core.deal_ability_damage(a, t, 10)
	advance(3)
	chat = {}
	leave(t)
	eq(t.meta:get_string("grug_pvp:logout_death"), "1", "O: leaving in PvP combat marks the death")
	eq(#chat, 1, "O: one announcement")
	check(chat[1] and chat[1]:find("out_t", 1, true) and chat[1]:find("fled", 1, true),
		"O: the announcement names the deserter")
	local sa = grug_pvp.stats(a)
	check(sa.kills == 1 and sa.killing_blows == 0, "O: the damage dealer gets the kill, no killing blow")
	eq(grug_pvp.stats(t).deaths, 1, "O: the deserter counts a death")
	-- Next join: dies through the ordinary death path, no second message or credit.
	t.pos = vec(50, 10, 0)
	join(t)
	check(not state(t).flagged, "O: the join starts with a cleared record")
	check(t.hp > 0, "O: the death waits for the end of the join")
	run_afters()
	eq(t.hp, 0, "O: the character starts dead")
	eq(#chat, 1, "O: no second announcement")
	eq(grug_pvp.stats(a).kills, 1, "O: no second credit")
	eq(grug_pvp.stats(t).deaths, 1, "O: no second death count")
	eq(t.meta:get_string("grug_pvp:logout_death"), "", "O: the mark is consumed")
	t.hp = 100
	-- Leaving while flagged but out of PvP combat (11 s later) is no death.
	grug_pvp.contact(a, t)
	advance(11)
	leave(t)
	eq(t.meta:get_string("grug_pvp:logout_death"), "", "O: leaving after 10 s is no death")
	eq(t.meta:get_string("grug_pvp:contact_at"), tostring(clock - 11), "O: the contact is persisted at leave")
	join(t)
	check(state(t).flagged and state(t).reason == "location_contested", "O: rejoin keeps its flag")
	-- A shutdown is no logout.
	grug_pvp.contact(a, t)
	for _, fn in ipairs(callbacks.shutdown) do fn() end
	leave(t); leave(a)
	eq(t.meta:get_string("grug_pvp:logout_death"), "", "O: a shutdown is no logout death")
	eq(t.meta:get_string("grug_pvp:contact_at"), tostring(clock), "O: the shutdown wrote the timers")
end

------------------------------------------------------------------------------
-- The admin command.
------------------------------------------------------------------------------
do
	check(commands.pvpstate and commands.pvpstate.privs.server, "/pvpstate is privileged")
end

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then error("R31 PVP PORTABLE FAIL") end
print("R31 PVP PORTABLE PASS checks=" .. checks)
