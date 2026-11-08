-- Round 72 lane FIGHT portable test (LuaJIT): combat starts at targeting
-- (round72-plan.md §2.1). Loads the REAL code under small engine stubs:
-- grug_core/combat.lua in full, grug_mobs/aggro.lua in full (leash, give-up,
-- evade, the 1 Hz tick with prune_engagement), grug_expeditions/packs.lua in
-- full, mobs_redo's do_attack and stop_attack cut out of mobs/api.lua, and
-- out of grug_mobs/init.lua the class-level stop_attack wrapper, the truce
-- test and the do_attack seam with its holds_target test. Checks:
--   T  a mob that takes a player as its target puts them in combat with no
--      hit and no threat (sight aggro, a group alert, a forced switch); a
--      non-forced call on a mob already attacking someone else engages
--      nobody; a non-player target, a dead player, an evader's target, a
--      player under the undead truce (until provoked) and a player of the
--      mob's own faction are not engaged.
--   K  a king targeting a player on a ledge out of reach holds them in combat
--      until the bosses' 15 s rule resets him (then out at once); a king
--      whose navigation gives up (no floor: the "no way") resets at once,
--      the player out, and ignores the player for 15 s.
--   L  leaving as before: stop_attack (the mob drops the target), the death
--      boundary and the targetless backstop (prune_engagement, two ticks), a
--      leash reset of a camp mob behind a wall (give-up), an ambient pursuit
--      mob after its 15 s damage clock; in a group fight a switched-away
--      player stays engaged within 40 m and is dropped beyond it.
--   P  an Expedition pack: one member taking a player as its target pulls the
--      pack; the list holds only that player, every member engages them, a
--      bystander in the same run is neither on the list nor in combat.
--   C  cost: the seam is a field test per do_attack call, no scan, no tick.
-- Usage (repo root): luajit tools/r72_fight/portable_test.lua [REPO]
-- Prints "R72 FIGHT PORTABLE PASS checks=<n>" or raises.
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
-- Cut a piece of a source (plain-text anchors), the end anchor included.
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

-- ---------------------------------------------------------------------------
-- Engine stubs: a controllable clock, players and mob objects.
-- ---------------------------------------------------------------------------
local us_time = 1000000
local function advance(seconds) us_time = us_time + math.floor(seconds * 1e6) end
local function vec(x, y, z) return {x = x, y = y, z = z} end
vector = {
	new = function(x, y, z)
		if type(x) == "table" then return vec(x.x, x.y, x.z) end
		return vec(x, y, z)
	end,
	add = function(a, n) return vec(a.x + n, a.y + n, a.z + n) end,
	subtract = function(a, n) return vec(a.x - n, a.y - n, a.z - n) end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
}

local players = {}
local function new_player(name, pos, fields)
	local p = {name = name, pos = pos, hp = 20}
	function p:is_player() return true end
	function p:get_player_name() return self.name end
	function p:get_pos() return self.pos and vector.new(self.pos) end
	function p:get_hp() return self.hp end
	function p:get_luaentity() return nil end
	function p:get_attach() return nil end
	for k, v in pairs(fields or {}) do p[k] = v end
	players[name] = p
	return p
end

local die_callbacks = {}
local mob_class = {}
local mob_mt = {__index = mob_class}
local add_entity -- set below, once the seam is installed
core = {
	get_us_time = function() return us_time end,
	is_player = function(obj)
		return type(obj) == "table" and obj.is_player ~= nil and obj:is_player()
	end,
	get_player_by_name = function(name) return players[name] end,
	get_objects_inside_radius = function() error("the seam scanned objects") end,
	line_of_sight = function() return true end,
	log = function() end,
	after = function() end,
	serialize = function(t) return t end,
	get_node_or_nil = function() return nil end,
	registered_nodes = {},
	load_area = function() end,
	add_entity = function(...) return add_entity(...) end,
	register_on_dieplayer = function(fn) die_callbacks[#die_callbacks + 1] = fn end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})

-- ---------------------------------------------------------------------------
-- The real grug_core combat state and the real grug_mobs leash.
-- ---------------------------------------------------------------------------
grug_core = {}
local tracked = {}
grug_mobs = {registered_cadence = tracked}
dofile(repo .. "/mods/CORE/grug_core/combat.lua")
local perks = {} -- player name -> race perk key
grug_core.get_race_perk = function(player, key)
	return perks[player:get_player_name()] == key and {} or nil
end
grug_core.death_message = function(name) return "fled", name .. " fled" end

local boss_resets = 0
grug_mobs.give_up_stuck = function() end
grug_mobs.idle_health_tick = function() end
grug_mobs.walk_toward = function() end
grug_mobs.walk_fixed = function() end
grug_mobs.walk_follow = function() end
grug_mobs.walk_clear = function() end
grug_mobs.roam_avoid_tick = function() end
grug_mobs.in_swimmer_reach = function() return true end
grug_mobs.boss_leash_reset = function() boss_resets = boss_resets + 1 end
grug_mobs.touch_boss_activity = function() end
grug_mobs.place_on_ground = function(object, pos) object:set_pos(pos) end
grug_mobs.set_tier = function(ent, tier) ent._grug_tier = tier end
grug_mobs.ensure_init = function() end
grug_mobs.settle_mob_death = function() return true end
grug_mobs.live_claim = function() return true end
grug_mobs.boss_attempt_reset = function() end
dofile(repo .. "/mods/ENTITIES/grug_mobs/aggro.lua")
-- Round 72 BOSSRESET: a king's reset rules live in boss_floor.lua (its floor is
-- tools/r72_bossreset's; K's king has no seat, so no floor).
mobs = {grug_nav = {forget = function() end}}
dofile(repo .. "/mods/ENTITIES/grug_mobs/boss_floor.lua")

-- ---------------------------------------------------------------------------
-- mobs_redo's do_attack and stop_attack, and grug_mobs' wrappers round them.
-- ---------------------------------------------------------------------------
local api = read("mods/ENTITIES/mobs/api.lua")
local nav_stub = {forget = function() end}
local obstacle_stub = {forget_no_path = function() end}
load_in(cut(api, "function mob_class:do_attack(player, force)", "\nend\n", "do_attack"),
	{mob_class = mob_class, random = function() return 100 end,
		grug_obstacle = obstacle_stub, grug_nav = nav_stub}, "do_attack")
load_in(cut(api, "function mob_class:stop_attack()", "\nend\n", "stop_attack"),
	{mob_class = mob_class, grug_obstacle = obstacle_stub, grug_nav = nav_stub}, "stop_attack")
function mob_class:mob_sound() end
function mob_class:set_velocity() end
function mob_class:set_animation() end
function mob_class:update_tag() end

local init = read("mods/ENTITIES/grug_mobs/init.lua")
load_in(cut(init, "local engage_old_stop_attack = mobs.mob_class.stop_attack", "\nend\n",
	"stop_attack wrapper"), {mobs = {mob_class = mob_class}}, "stop_attack wrapper")
local truce_source = cut(init, "local function truce_active(self, player)", "\n\tend\n", "truce")
local holds_source = cut(init, "local function holds_target(self, target)", "\n\tend\n",
	"holds_target")
local seam_source = cut(init, "prototype.do_attack = function(self, target, force)", "\n\tend\n",
	"do_attack seam")
local factions_stub = {get_object_faction = function(obj)
	return obj.faction
end}
-- What register_mob does for one definition: its truce perk and faction as
-- upvalues, the seam on the registered prototype.
local install = load_in("return function(prototype, native_do_attack, truce_perk, faction)\n" ..
	truce_source .. "\n" .. holds_source .. "\n" .. seam_source .. "\nend\n",
	{grug_factions = factions_stub}, "register_mob seam")

local prototypes = {}
local function prototype_of(name, def)
	local proto = prototypes[name]
	if proto then return proto end
	proto = setmetatable({}, mob_mt)
	install(proto, mob_class.do_attack, def and def.truce_perk, def and def.faction)
	prototypes[name] = proto
	tracked[name] = true
	return proto
end

local function new_mob(name, pos, fields, def)
	local m = setmetatable({name = name, state = "stand", health = 100, hp_max = 100,
		attack_type = "dogfight", view_range = 16, reach = 3, sounds = {}, temp = {},
		_cmi_is_mob = true}, {__index = prototype_of(name, def)})
	local at = vector.new(pos)
	m.object = {
		get_pos = function() return at and vector.new(at) end,
		set_pos = function(_, p) at = vector.new(p) end,
		set_velocity = function() end,
		set_properties = function() end,
		get_luaentity = function() return at and m or nil end,
		remove = function() at = nil end,
		is_player = function() return false end,
	}
	for k, v in pairs(fields or {}) do m[k] = v end
	return m
end

local in_combat = grug_core.in_combat
local function ticks(mob, seconds)
	for _ = 1, seconds do
		advance(1)
		grug_mobs.leash_tick(mob, 1)
	end
end
local function engaged(mob, player)
	local edges = mob.temp and mob.temp.grug_engaged
	return edges ~= nil and edges[player:get_player_name()] == true
end
local function kill_player(player)
	player.hp = 0
	for _, fn in ipairs(die_callbacks) do fn(player) end
end

-- ---------------------------------------------------------------------------
-- T. Targeting is combat.
-- ---------------------------------------------------------------------------
do
	local ana = new_player("ana", vec(6, 0, 0))
	local bob = new_player("bob", vec(-6, 0, 0))
	local wolf = new_mob("grug_mobs:wolf", vec(0, 0, 0))
	check(not in_combat(ana), "T0 out of combat before")
	-- general_attack's sight aggro: a plain do_attack, no hit, no threat.
	wolf:do_attack(ana)
	check(wolf.attack == ana and in_combat(ana) and engaged(wolf, ana),
		"T1 a mob that takes a player as its target puts them in combat")
	check(wolf.temp.grug_threat == nil, "T1 with no threat entry and no hit")
	-- A second sight call on a mob already attacking returns early in mobs_redo.
	wolf:do_attack(bob)
	check(wolf.attack == ana and not in_combat(bob), "T2 a mob busy with another engages nobody new")
	-- A group alert on an idle kin: the same do_attack.
	local kin = new_mob("grug_mobs:wolf", vec(2, 0, 0))
	kin:do_attack(bob)
	check(in_combat(bob) and engaged(kin, bob), "T3 a group alert's target is in combat")
	-- A forced switch (taunt, threat): the new target is engaged at once.
	local ape = new_mob("grug_mobs:ape", vec(0, 0, 4))
	local cid = new_player("cid", vec(0, 0, 8))
	ape:do_attack(ana)
	ape:do_attack(cid, true)
	check(ape.attack == cid and engaged(ape, cid) and engaged(ape, ana),
		"T4 a forced switch engages the new target; the old one stays while near")
	-- Not a player: a patrol's go_to target, another mob.
	local marker = new_mob("mobs:_pos", vec(1, 0, 1))
	local boar = new_mob("grug_mobs:boar", vec(3, 0, 3))
	boar:do_attack(marker.object, true)
	check(boar.attack == marker.object and boar.temp.grug_engaged == nil,
		"T5 a non-player target engages nothing")
	-- A dead player is never put back into combat.
	local dan = new_player("dan", vec(0, 0, -6))
	kill_player(dan)
	local bat = new_mob("grug_mobs:bat", vec(0, 0, -3))
	bat:do_attack(dan, true)
	check(not in_combat(dan), "T6 a dead player is not engaged")
	-- An evader targets nobody; a call that reaches it engages nobody.
	local eve = new_player("eve", vec(10, 0, 10))
	local runner = new_mob("grug_mobs:bandit", vec(8, 0, 8))
	runner.temp.grug_evading = {started = 0}
	runner:do_attack(eve)
	check(not in_combat(eve), "T7 an evading mob's target is not engaged")
	-- The undead truce decides who may be targeted, until provoked.
	local ghoul = new_mob("grug_mobs:zombie", vec(20, 0, 0), nil, {truce_perk = "undead_truce"})
	local una = new_player("una", vec(22, 0, 0))
	perks.una = "undead_truce"
	ghoul:do_attack(una)
	check(not in_combat(una), "T8 a player under the truce is not engaged")
	ghoul:stop_attack()
	ghoul.temp.grug_provoked = {una = true}
	ghoul:do_attack(una)
	check(in_combat(una) and engaged(ghoul, una), "T8 once provoked, targeting engages")
	-- The faction rules: never the own faction.
	local guard = new_mob("grug_mobs:guard_accord", vec(30, 0, 0), {type = "npc"}, {faction = "accord"})
	local friend = new_player("friend", vec(32, 0, 0), {faction = "accord"})
	local foe = new_player("foe", vec(28, 0, 0), {faction = "throng"})
	guard:do_attack(friend)
	check(not in_combat(friend), "T9 an own-faction target is not engaged")
	guard:stop_attack()
	guard:do_attack(foe)
	check(in_combat(foe) and engaged(guard, foe), "T9 a guard targeting a foe engages them")
	-- An instance faction (the Undead King's raiders) works the same way.
	local raider = new_mob("grug_mobs:raider", vec(40, 0, 0), {_grug_faction = "throng"})
	local thane = new_player("thane", vec(41, 0, 0), {faction = "throng"})
	raider:do_attack(thane)
	check(not in_combat(thane), "T9 an instance faction spares its own side")
end

-- ---------------------------------------------------------------------------
-- K. A king targeting from out of reach.
-- ---------------------------------------------------------------------------
do
	local seat = vec(100, 0, 100)
	local king = new_mob("grug_mobs:king_test", seat, {type = "npc", _grug_royal_king = true,
		_grug_boss_id = "king:test", _grug_leash_range = 30})
	-- A Mage on a ledge 20 nodes away and 6 up: he sees her, cannot reach her.
	local mage = new_player("mage", vec(120, 6, 100))
	king:do_attack(mage)
	check(in_combat(mage) and king.temp.grug_threat == nil,
		"K1 a king targeting a player out of reach puts them in combat, no hit")
	ticks(king, 15)
	check(in_combat(mage) and king.attack == mage, "K2 the target holds through 15 s of no contact")
	-- The 15 s rule (boss_floor.lua, Round 72) fires on the first tick more than
	-- 15 s after the pull's seed, as the contact leash it replaced for kings did.
	ticks(king, 1)
	check(in_combat(mage), "K2 still at exactly 15 s")
	ticks(king, 1)
	check(not in_combat(mage) and king.attack == nil and king.health == king.hp_max,
		"K3 the 15 s rule resets him and the player is out at once")
	check(boss_resets >= 1, "K3 through the encounter's own reset")
	-- He sees her again on his next acquisition: combat again.
	king:do_attack(mage)
	check(in_combat(mage), "K4 a king who takes her again puts her back in combat")
	-- A melee king's navigation gives up: without a floor that is the "no way",
	-- and alone she leaves and he resets (Round 72): the player is out.
	grug_mobs.give_up_target(king)
	check(king.attack == nil and not in_combat(mage), "K5 a give-up drops her at once")
	check(grug_mobs.gave_up_on(king, mage), "K5 and keeps her out of acquisition for now")
	advance(16)
	check(not grug_mobs.gave_up_on(king, mage), "K5 for 15 s")
end

-- ---------------------------------------------------------------------------
-- L. Leaving combat as before.
-- ---------------------------------------------------------------------------
do
	-- The mob drops the target (lost, out of chase range, out of sight).
	local fay = new_player("fay", vec(200, 0, 0))
	local lynx = new_mob("grug_mobs:lynx", vec(204, 0, 0))
	lynx:do_attack(fay)
	check(in_combat(fay), "L1 targeted")
	lynx:stop_attack()
	check(not in_combat(fay), "L1 stop_attack ends it at once")
	-- The death boundary drops every edge (settle_mob_death's first statement).
	lynx:do_attack(fay)
	local settle = cut(init, "function grug_mobs.settle_mob_death(self)", "\nend\n", "settle")
	check(settle:find("grug_core.disengage_mob(self)", 1, true) ~= nil,
		"L2 the death boundary disengages the mob")
	grug_core.disengage_mob(lynx)
	check(not in_combat(fay), "L2 a dead mob holds nobody")
	-- mobs_redo's own death reset clears `attack` without stop_attack: the
	-- targetless backstop drops the edge on the second tick.
	lynx.health = 100
	lynx.state = "stand"
	lynx:do_attack(fay)
	lynx.attack, lynx.state = nil, "die"
	ticks(lynx, 1)
	check(in_combat(fay), "L3 one targetless tick is grace")
	ticks(lynx, 1)
	check(not in_combat(fay), "L3 the second drops the edge (prune_engagement)")
	-- A camp mob behind a wall: its navigation gives up, a full leash reset.
	local gus = new_player("gus", vec(300, 0, 0))
	local bandit = new_mob("grug_mobs:bandit", vec(306, 0, 0),
		{_grug_camp_pos = vec(306, 0, 0), _grug_home = vec(306, 0, 0)})
	bandit:do_attack(gus)
	ticks(bandit, 3)
	check(in_combat(gus), "L4 a camp mob behind a wall holds its target")
	grug_mobs.give_up_target(bandit)
	check(not in_combat(gus) and bandit.attack == nil, "L4 its give-up resets it and frees the player")
	-- Without a give-up the contact leash ends it after 15 s.
	bandit.temp.grug_gave_up = nil
	bandit:do_attack(gus)
	ticks(bandit, 15)
	check(in_combat(gus), "L5 within the 15 s contact leash")
	ticks(bandit, 2)
	check(not in_combat(gus), "L5 after it, out")
	-- An ambient pursuit mob chasing a fleeing player who never hits it.
	local hal = new_player("hal", vec(400, 0, 0))
	local hyena = new_mob("grug_mobs:hyena", vec(410, 0, 0), {_grug_damage_pursuit_candidate = true,
		_grug_home = vec(410, 0, 0)})
	hyena:do_attack(hal)
	check(in_combat(hal), "L6 a wild mob's target is in combat")
	for _ = 1, 14 do
		hal.pos = vec(hal.pos.x - 4, 0, 0)
		ticks(hyena, 1)
	end
	check(in_combat(hal), "L6 while its 15 s damage clock runs")
	for _ = 1, 2 do
		hal.pos = vec(hal.pos.x - 4, 0, 0)
		ticks(hyena, 1)
	end
	check(not in_combat(hal), "L6 after it, the moving target is let go")
	-- A group fight: the switched-away player stays engaged within 40 m.
	local ida = new_player("ida", vec(500, 0, 0))
	local jon = new_player("jon", vec(500, 0, 6))
	local troll = new_mob("grug_mobs:troll", vec(503, 0, 3))
	troll:do_attack(ida)
	troll:do_attack(jon, true)
	ticks(troll, 2)
	check(in_combat(ida) and in_combat(jon), "L7 both stay in a fight that goes on")
	ida.pos = vec(560, 0, 0)
	ticks(troll, 1)
	check(not in_combat(ida) and in_combat(jon), "L7 the one who left beyond 40 m is let go")
	-- A death and a logout end it for that player (unchanged).
	kill_player(jon)
	check(not in_combat(jon), "L8 death ends combat")
end

-- ---------------------------------------------------------------------------
-- P. An Expedition pack: the list keeps its meaning.
-- ---------------------------------------------------------------------------
do
	local run_of = {}
	grug_expeditions = {
		LOGOUT_DEATH = "grug_expeditions:logout_death",
		run_inside = function(name)
			if type(name) ~= "string" then name = name:get_player_name() end
			return run_of[name]
		end,
		register_on_end = function() end,
		register_on_leave = function() end,
	}
	add_entity = function(pos, name, data)
		return new_mob(name, pos, data).object
	end
	local P = dofile(repo .. "/mods/PLAYER/grug_expeditions/packs.lua")
	local run = {id = 1, level = 25}
	local kai = new_player("kai", vec(600, 5, 0))
	local lea = new_player("lea", vec(640, 5, 0))
	run_of.kai, run_of.lea = run, run
	local pack = P.new(run)
	local row = {mob = "grug_mobs:giant_spider", tier = "normal"}
	assert(P.add(pack, row, vec(610, 5, 0)))
	assert(P.add(pack, row, vec(612, 5, 0)))
	assert(P.add(pack, row, vec(611, 5, 3)))
	local members = {}
	for _, member in ipairs(pack.members) do
		members[#members + 1] = member.object:get_luaentity()
	end
	check(#members == 3 and not in_combat(kai), "P0 a waiting pack holds nobody")
	-- One member sees kai: the pull, by the same seam.
	members[1]:do_attack(kai)
	local listed = {}
	for name in pairs(pack.players) do listed[#listed + 1] = name end
	check(#listed == 1 and listed[1] == "kai", "P1 the list holds only who engaged")
	local all = true
	for _, ent in ipairs(members) do
		all = all and ent.attack == kai and engaged(ent, kai)
	end
	check(all and in_combat(kai), "P2 every member is set on them and engaged")
	check(not in_combat(lea) and pack.players.lea == nil,
		"P3 a bystander in the same run is neither listed nor in combat")
end

-- ---------------------------------------------------------------------------
-- C. Cost: a field test per do_attack call.
-- ---------------------------------------------------------------------------
check(not holds_source:find("for ", 1, true) and not holds_source:find("get_objects", 1, true)
	and not seam_source:find("get_objects", 1, true),
	"C the seam neither loops nor scans")
check(not holds_source:find("globalstep", 1, true) and not seam_source:find("globalstep", 1, true)
	and not seam_source:find("core.after", 1, true), "C no tick of its own")

print("R72 FIGHT PORTABLE PASS checks=" .. checks)
