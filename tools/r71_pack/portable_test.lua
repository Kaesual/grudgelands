-- Round 71 lane PACK portable test (LuaJIT): the states of a pack, on the real
-- packs.lua and the real aggro.lua, with stubs of the engine and of a mob's body. The
-- engine half is tools/r71_pack/run.sh; the login rule's other half is in r71_frame,
-- the respawn row in r71_guard and r69_home. Section H is the proof of ruling 6: a seeded world of
-- walls, inactive blocks, deaths and logouts in which nobody is ever held with nothing
-- able to reach them. Prints "R71 PACK PORTABLE PASS checks=<n>".
--
--   luajit tools/r71_pack/portable_test.lua [REPO]
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

-- ---- The stubs ---------------------------------------------------------------
local clock = 0
local timers = {}
local callbacks = {die = {}, leave = {}, join = {}, shutdown = {}}
local players = {}
local statics = {}   -- what inactive blocks hold: staticdata tables
local refuse_spawn = false
local sight = function() return true end
local walls = {}     -- "x,y,z" -> true
local chat = {}

local function key(p) return p.x .. "," .. p.y .. "," .. p.z end
local function distance(a, b)
	local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(x * x + y * y + z * z)
end

vector = {
	add = function(a, n) return {x = a.x + n, y = a.y + n, z = a.z + n} end,
	subtract = function(a, n) return {x = a.x - n, y = a.y - n, z = a.z - n} end,
	distance = distance,
	round = function(p) return {x = math.floor(p.x + 0.5), y = math.floor(p.y + 0.5),
		z = math.floor(p.z + 0.5)} end,
}

local mob_objects = {}

local function new_body(pos, name, data)
	local ent = {name = name, state = "stand", temp = {}, health = 100, hp_max = 100, reach = 3,
		attack_type = "dogfight", view_range = 16, _grug_tier = "normal"}
	for field, value in pairs(data) do ent[field] = value end
	local at = {x = pos.x, y = pos.y, z = pos.z}
	local object = {}
	function object.get_pos() return at and {x = at.x, y = at.y, z = at.z} or nil end
	function object.set_pos(_, p) at = {x = p.x, y = p.y, z = p.z} end
	function object.set_velocity() end
	function object.set_properties() end
	function object.get_luaentity() return at and ent or nil end
	function object.remove()
		at = nil
		mob_objects[object] = nil
	end
	function object.go_inactive() -- the block leaves the active set
		local saved = {}
		for field, value in pairs(ent) do
			if type(value) ~= "function" and field ~= "temp" and field ~= "object" and
					field ~= "attack" and field ~= "state" then
				saved[field] = value
			end
		end
		saved._at = {x = at.x, y = at.y, z = at.z}
		statics[#statics + 1] = saved
		at = nil
		mob_objects[object] = nil
		return saved
	end
	ent.object = object
	function ent:do_attack(target, force)
		if self.state == "attack" and not force then return end
		self.attack, self.state = target, "attack"
		if self._grug_pack then grug_mobs.pack_contact(self, target) end
	end
	function ent:stop_attack() self.attack, self.state = nil, "stand" end
	function ent:update_tag() end
	mob_objects[object] = ent
	return ent
end

core = {
	registered_nodes = {air = {walkable = false}, stone = {walkable = true},
		lava = {walkable = false, damage_per_second = 8},
		hot = {walkable = true, damage_per_second = 4}},
	get_modpath = function() return repo .. "/mods/PLAYER/grug_expeditions" end,
	get_current_modname = function() return "grug_expeditions" end,
	log = function() end,
	serialize = function(t) return t end,
	after = function(seconds, fn) timers[#timers + 1] = {at = clock + seconds, fn = fn} end,
	load_area = function() end,
	line_of_sight = function(a, b) return sight(a, b) end,
	-- A floor at y 4 unless a cell says otherwise; `walls` holds true or a node name.
	get_node_or_nil = function(pos)
		local cell = walls[key(pos)]
		if type(cell) == "string" then return {name = cell} end
		return {name = (cell or pos.y == 4) and "stone" or "air"}
	end,
	get_player_by_name = function(name) local p = players[name]; return p and p.online and p or nil end,
	is_player = function(p) return type(p) == "table" and p.is_player ~= nil and p.is_player() end,
	chat_send_all = function(text) chat[#chat + 1] = text end,
	register_on_dieplayer = function(fn) table.insert(callbacks.die, fn) end,
	register_on_leaveplayer = function(fn) table.insert(callbacks.leave, fn) end,
	register_on_joinplayer = function(fn) table.insert(callbacks.join, fn) end,
	register_on_shutdown = function(fn) table.insert(callbacks.shutdown, fn) end,
	add_entity = function(pos, name, data)
		if refuse_spawn then return nil end
		local ent = new_body(pos, name, data)
		if not grug_mobs.live_claim(ent) then return nil end
		return ent.object
	end,
}

local function advance(seconds)
	local target = clock + seconds
	while true do
		local best
		for index, row in ipairs(timers) do
			if row.at <= target and (not best or row.at < timers[best].at) then best = index end
		end
		if not best then break end
		local row = table.remove(timers, best)
		clock = math.max(clock, row.at)
		row.fn()
	end
	clock = target
end

-- The real engine activates a static copy: mob_activate, then after_activate.
local function activate(saved)
	local at = saved._at
	local ent = new_body(at, saved.name, saved)
	ent._at = nil
	if not grug_mobs.live_claim(ent) then return nil end
	return ent
end

local fighting = {} -- player name -> the combat timer's end
local boss_resets, walks = {}, {}
grug_core = {
	mono_time = function() return clock end,
	mark_in_combat = function(player, seconds)
		if player:get_hp() <= 0 then return end
		local name = player:get_player_name()
		fighting[name] = math.max(fighting[name] or 0, clock + seconds)
	end,
	in_combat = function(player) return clock < (fighting[player:get_player_name()] or 0) end,
	engage_mob = function() end,
	disengage_mob = function() end,
	clear_threat = function(ent) ent.temp.grug_threat = nil end,
	recheck_switch = function() end,
	prune_engagement = function() end,
	LOGOUT_DEATH_CUSTOM_TYPE = "grug_core:logout_death",
	death_message = function(name) return "fled", name .. " fled" end,
}
grug_mobs = {
	place_on_ground = function(object, pos) object:set_pos(pos) end,
	set_tier = function(ent, tier) ent._grug_tier = tier end,
	ensure_init = function(ent) ent.health = ent.hp_max end,
	settle_mob_death = function() return true end,
	live_claim = function() return true end,
	boss_attempt_reset = function(id) boss_resets[#boss_resets + 1] = id end,
	boss_leash_reset = function(self)
		if self._grug_boss_id then grug_mobs.boss_attempt_reset(self._grug_boss_id) end
	end,
	walk_clear = function() end,
	walk_fixed = function(self) walks[#walks + 1] = self end,
	walk_toward = function(self) self._test_turned = (self._test_turned or 0) + 1 end,
	roam_avoid_tick = function() end,
	idle_health_tick = function() end,
	give_up_stuck = function() error("a pack mob reached the give-up") end,
	in_swimmer_reach = function() return true end,
}
mobs = {grug_nav = {forget = function() end}}

local run_of = {}
local left, ended = {}, {}
grug_expeditions = {
	LOGOUT_DEATH = "grug_expeditions:logout_death",
	run_inside = function(name)
		if type(name) ~= "string" then name = name:get_player_name() end
		return run_of[name]
	end,
	register_on_end = function(fn) ended[#ended + 1] = fn end,
	register_on_leave = function(fn) left[#left + 1] = fn end,
}
dofile(repo .. "/mods/ENTITIES/grug_mobs/aggro.lua")
local P = dofile(repo .. "/mods/PLAYER/grug_expeditions/packs.lua")

local function fake_player(name, run, x, z)
	local player = {name = name, hp = 20, online = true, at = {x = x or 0, y = 5, z = z or 0}, meta = {},
		killed = {}}
	function player.get_player_name() return name end
	function player.is_player() return true end
	function player.get_hp() return player.hp end
	function player.get_pos() return player.online and player.at or nil end
	function player.set_hp(_, hp, reason)
		player.hp = hp
		player.killed[#player.killed + 1] = reason
	end
	function player.get_meta()
		return {get_string = function(_, field) return player.meta[field] or "" end,
			set_string = function(_, field, value) player.meta[field] = value end}
	end
	players[name] = player
	run_of[name] = run
	return player
end

local function die(player)
	player.hp = 0
	fighting[player.name] = nil
	for _, fn in ipairs(callbacks.die) do fn(player) end
end
local function respawn(player, pos)
	player.hp, player.at = 20, pos
end
local function logout(player)
	-- The engine's order: runs.lua's mark_left fires the hooks first.
	for _, fn in ipairs(left) do fn(run_of[player.name], player.name, "logout") end
	fighting[player.name] = nil
	for _, fn in ipairs(callbacks.leave) do fn(player) end
	player.online = false
	run_of[player.name] = nil
end
local function login(player, run)
	player.online = true
	run_of[player.name] = run
	for _, fn in ipairs(callbacks.join) do fn(player) end
end
local function kill(ent)
	ent.health, ent.state = 0, "die"
	grug_mobs.settle_mob_death(ent)
	ent.object:remove()
end
local function hit(ent, player)
	grug_core.engage_mob(ent, player)
end

local next_run = 0
local all_runs = {}
local function new_run()
	next_run = next_run + 1
	local run = {id = next_run, level = 25}
	all_runs[#all_runs + 1] = run
	return run
end
local SPIDER = {mob = "grug_mobs:giant_spider", tier = "normal"}
local GOLEM = {mob = "grug_mobs:stone_golem", tier = "elite"}
local BOSS = {mob = "grug_mobs:flintback", tier = "boss"}
local function all_of(pack_name)
	local out = {}
	for _, ent in pairs(mob_objects) do
		if ent._test_pack == pack_name then out[#out + 1] = ent end
	end
	return out
end
local function living()
	local out = {}
	for _, ent in pairs(mob_objects) do out[#out + 1] = ent end
	table.sort(out, function(a, b) return a._grug_pack < b._grug_pack end)
	return out
end
local function reset_world()
	for object in pairs(mob_objects) do object:remove() end
	-- A running tick ends by itself once nothing is pulled.
	for _, run in ipairs(all_runs) do
		for _, fn in ipairs(ended) do fn(run, "test") end
	end
	all_runs = {}
	advance(2)
	timers, statics, walls, players, run_of, fighting = {}, {}, {}, {}, {}, {}
	boss_resets, walks, chat = {}, {}, {}
	sight = function() return true end
	refuse_spawn = false
end
local function mixed(run, x)
	x = x or 10
	local pack = P.new(run)
	assert(P.add(pack, SPIDER, {x = x, y = 5, z = 0}))
	assert(P.add(pack, SPIDER, {x = x + 3, y = 5, z = 0}))
	assert(P.add(pack, GOLEM, {x = x, y = 5, z = 3}))
	return pack
end
local function no_timers() return #timers == 0 end

-- ---- A. The pull -------------------------------------------------------------
do
	local run = new_run()
	local pack = mixed(run)
	local ana = fake_player("ana", run)
	local bodies = living()
	check(#bodies == 3 and no_timers(), "A a waiting pack costs nothing")
	for _, ent in ipairs(bodies) do
		check(ent._grug_pack ~= nil and ent._grug_home ~= nil and ent.lifetimer >= 20000 and ent._grug_authored,
			"A a body's key, home, far despawn and limit mark")
		check(ent.group_attack == false and ent._grug_soft_deaggro == false, "A no other alert, no soft de-aggro")
		check(ent._grug_chase_range >= 1000000 and ent.attack_patience >= 1000000, "A a chase without end")
		check(not grug_mobs.damage_pursuit(ent), "A not the ambient pursuit")
	end
	local golem
	for _, ent in ipairs(bodies) do
		if ent.name == GOLEM.mob then golem = ent end
	end
	check(bodies[1]._grug_pack >= os.time() * 1000 - 1000000, "A body keys above the session's clock")
	-- idle it stays by its marker: 8 nodes, not the 32 of a free roamer (the boss too)
	local idler = bodies[1]
	local home = idler._grug_home
	idler.object:set_pos({x = home.x + 7, y = 5, z = home.z})
	grug_mobs.leash_tick(idler, 1)
	check(not idler._test_turned, "A within 8 nodes of its marker it may idle")
	idler.object:set_pos({x = home.x + 9, y = 5, z = home.z})
	grug_mobs.leash_tick(idler, 1)
	check(idler._test_turned == 1, "A beyond them it turns back")
	idler.object:set_pos({x = home.x, y = 5, z = home.z})
	local standing = P.new(run, "expedition:x:9")
	assert(P.add(standing, BOSS, {x = 200, y = 5, z = 0}))
	local boss
	for _, ent in ipairs(living()) do
		if ent._grug_boss_id then boss = ent end
	end
	boss.object:set_pos({x = 209, y = 5, z = 0})
	grug_mobs.leash_tick(boss, 1)
	check(boss._test_turned == 1, "A a boss waits at its marker too")
	boss.object:remove()

	-- golem.lua: group_attack = false. The pull is the pack's, whatever the family.
	hit(golem, ana)
	for _, ent in ipairs(bodies) do
		check(ent.state == "attack" and ent.attack == ana, "A one hit on the golem pulls all of it")
	end
	check(grug_core.in_combat(ana), "A the puller is in combat at once")
	check(#timers == 1, "A one tick")

	-- a pack beside it stays where it stands: no call crosses packs
	local other = mixed(run, 60)
	for _, ent in ipairs(living()) do
		if ent.attack == nil then check(ent.state == "stand", "A the other pack waits") end
	end
	-- sight: a mob taking a target pulls too
	local bob = fake_player("bob", run, 60)
	local seen
	for _, ent in ipairs(living()) do
		if ent.state == "stand" then seen = ent; break end
	end
	seen:do_attack(bob)
	local count = 0
	for _, ent in ipairs(living()) do
		if ent.attack == bob then count = count + 1 end
	end
	check(count == 3, "A sight pulls the whole pack: " .. count)
	check(other.players.bob and not pack.players.bob and grug_core.in_combat(bob), "A bob on its list only")

	-- a second player joins by a hit, a heal's threat or being struck: engage_mob
	hit(bodies[1], bob)
	check(pack.players.bob, "A a second player joins the list")
	-- a killing blow's after-punch engages nobody
	local carol = fake_player("carol", run)
	bodies[1].health = 0
	hit(bodies[1], carol)
	check(not pack.players.carol, "A a dying mob adds nobody")
	bodies[1].health = 100
	-- nobody from outside the box
	run_of.carol = nil
	hit(bodies[1], carol)
	check(not pack.players.carol, "A a player not inside is not listed")
	reset_world()
end

-- ---- B. Never gives up ----------------------------------------------------------
do
	local run = new_run()
	local pack = mixed(run)
	local ana = fake_player("ana", run)
	local bodies = living()
	hit(bodies[1], ana)
	for second = 1, 120 do
		advance(1)
		for _, ent in ipairs(bodies) do
			-- the real 1 Hz slot: no leash, no timeout, no pursuit clock
			grug_mobs.leash_tick(ent, 1)
			check(ent.state == "attack" and ent.attack == ana and ent.health == 100, "B no reset at " .. second)
		end
		check(grug_core.in_combat(ana), "B in combat through a pause, second " .. second)
	end
	-- a dropped target (mobs_redo's own stop_attack) is taken up again within a tick
	bodies[1]:stop_attack()
	advance(1)
	check(bodies[1].attack == ana, "B the tick sets it on again")
	-- the navigation's give-up: no heal, no reset, a jump
	bodies[2].health = 50
	bodies[2].object:set_pos({x = 25, y = 5, z = 0})
	grug_mobs.give_up_target(bodies[2])
	check(bodies[2].health == 50 and bodies[2].attack == ana, "B a give-up resets nothing")
	check(distance(bodies[2].object:get_pos(), ana.at) <= 3, "B a give-up jumps")
	-- the pack dies: free in the step of the last death
	for _, ent in ipairs(bodies) do kill(ent) end
	check(next(pack.players) == nil, "B the last death frees the list")
	advance(1)
	check(no_timers(), "B the tick ends with the last pack")
	advance(4)
	check(not grug_core.in_combat(ana), "B out of combat after the timer")
	reset_world()
end

-- ---- C. Left behind ---------------------------------------------------------------
do
	local run = new_run()
	local pack = mixed(run)
	local ana = fake_player("ana", run)
	local bodies = living()
	hit(bodies[1], ana)
	-- far: jumps before its block can go inactive
	ana.at = {x = 100, y = 5, z = 0}
	advance(1)
	for _, ent in ipairs(bodies) do
		check(distance(ent.object:get_pos(), ana.at) <= 3, "C a mob left behind jumps beside the player")
		check(ent.attack == ana and ent.state == "attack", "C and fights on")
	end
	-- no live body: a new one at the old health, the old copy removes itself
	local deep = bodies[3]
	deep.health = 37
	advance(1)
	local copy = deep.object.go_inactive()
	advance(1)
	check(#living() == 3, "C a new body stands")
	local fresh
	for _, ent in ipairs(living()) do
		if ent.name == deep.name then fresh = ent end
	end
	check(fresh ~= deep and fresh.health == 37 and fresh.attack == ana, "C at the old health, on the player")
	check(fresh._grug_tier == "elite" and fresh._grug_home.x == 10 and fresh._grug_home.z == 3, "C its tier and home")
	check(activate(copy) == nil and #living() == 3, "C the old copy removes itself, no XP, no double")
	-- an idle pack's copy comes back as the same member
	reset_world()
	local run2 = new_run()
	local idle = mixed(run2)
	local one = living()[1]
	local saved = one.object.go_inactive()
	local back = activate(saved)
	check(back ~= nil and back._grug_pack == saved._grug_pack, "C an idle mob reactivates as itself")
	back.health = 41
	local bea = fake_player("bea", run2)
	hit(living()[2], bea)
	check(back.state == "attack", "C and answers the pull")
	-- pulled while its block is inactive: the tick brings it
	local bodies2 = living()
	local gone_copy = bodies2[3].object.go_inactive()
	advance(1)
	check(#living() == 3 and activate(gone_copy) == nil, "C an inactive member comes")
	-- a body the engine refuses counts as dead, so nobody waits for it
	refuse_spawn = true
	for _, ent in ipairs(living()) do ent.object.go_inactive() end
	advance(1)
	check(idle.alive == 0 and next(idle.players) == nil, "C a refused body frees the list")
	reset_world()
end

-- ---- D. Wedged ------------------------------------------------------------------
do
	local run = new_run()
	local pack = P.new(run)
	assert(P.add(pack, SPIDER, {x = 0, y = 5, z = 0}))
	local ana = fake_player("ana", run, 10)
	local mob = living()[1]
	hit(mob, ana)
	-- on a corner, in sight, out of reach: no node closer in 8 s, a jump
	for second = 1, 7 do
		advance(1)
		check(distance(mob.object:get_pos(), ana.at) == 10, "D waits at " .. second)
	end
	advance(2)
	check(distance(mob.object:get_pos(), ana.at) <= 3, "D wedged on a corner, it jumps")
	-- in reach and in sight: it fights, nothing moves it
	mob.object:set_pos({x = 8, y = 5, z = 0})
	advance(30)
	check(mob.object:get_pos().x == 8, "D a mob in reach stays")
	-- a swing lands at reach + reach_ext and no further: 3.5 nodes off, in clear sight,
	-- a reach of 3 strikes nothing and jumps; the extension on top of a player does
	mob.object:set_pos({x = 6.5, y = 5, z = 0})
	mob.reach_ext = 0.8
	advance(30)
	check(mob.object:get_pos().x == 6.5, "D within reach + reach_ext it stays")
	mob.reach_ext = 0
	advance(10)
	check(distance(mob.object:get_pos(), ana.at) <= 2, "D just out of reach, in sight: it jumps")
	mob.object:set_pos({x = 8, y = 5, z = 0})
	advance(1)
	-- a thin wall: in reach but no sight, a jump
	sight = function() return false end
	local before = mob.object:get_pos().x
	advance(10)
	check(mob.object:get_pos().x == 10, "D behind a wall, in reach: it lands on the player's own cell")
	check(before == 8, "D it stood there")
	sight = function() return true end
	-- a jump needs a floor: a pit, or one that burns, or lava in the cell: their own
	ana.at = {x = 400, y = 5, z = 0}
	for _, side in ipairs({{2, 0}, {-2, 0}, {0, 2}, {0, -2}}) do
		walls[key({x = 400 + side[1], y = 4, z = side[2]})] = "air"
	end
	advance(1)
	check(mob.object:get_pos().x == 400 and mob.object:get_pos().z == 0, "D no floor: the player's cell")
	ana.at = {x = 500, y = 5, z = 0}
	for index, side in ipairs({{2, 0}, {-2, 0}, {0, 2}, {0, -2}}) do
		if index % 2 == 0 then
			walls[key({x = 500 + side[1], y = 4, z = side[2]})] = "hot"
		else
			walls[key({x = 500 + side[1], y = 5, z = side[2]})] = "lava"
		end
	end
	advance(1)
	check(mob.object:get_pos().x == 500 and mob.object:get_pos().z == 0, "D never onto what burns")
	ana.at = {x = 10, y = 5, z = 0}
	advance(1)
	-- walking towards the player is progress, whatever the time
	sight = function() return true end
	mob.object:set_pos({x = 31, y = 5, z = 30}) -- 36.4 away: jumps as far
	advance(1)
	check(distance(mob.object:get_pos(), ana.at) <= 3, "D far enough to jump")
	mob.object:set_pos({x = 40, y = 5, z = 0})
	advance(1)
	for second = 1, 12 do
		mob.object:set_pos({x = 40 - 2 * second, y = 5, z = 0})
		advance(1)
		check(mob.object:get_pos().x == 40 - 2 * second, "D closing in never jumps")
	end
	-- a jump lands on a free cell the player sees
	ana.at = {x = 200, y = 5, z = 0}
	walls[key({x = 202, y = 5, z = 0})] = true
	sight = function(_, b) return b.x ~= 198 end
	advance(1)
	local landed = mob.object:get_pos()
	check(landed.x == 200 and math.abs(landed.z) == 2, "D the first free cell in sight: " .. key(landed))
	-- a pillar: no free cell, the player's own
	ana.at = {x = 300, y = 5, z = 0}
	for _, side in ipairs({{2, 0}, {-2, 0}, {0, 2}, {0, -2}}) do
		walls[key({x = 300 + side[1], y = 5, z = side[2]})] = true
	end
	advance(1)
	check(mob.object:get_pos().x == 300 and mob.object:get_pos().z == 0, "D on a pillar it reaches them")
	reset_world()
end

-- ---- E. The wipe ----------------------------------------------------------------
do
	local run = new_run()
	local pack = mixed(run)
	local ana, bob = fake_player("ana", run), fake_player("bob", run)
	local bodies = living()
	hit(bodies[1], ana)
	hit(bodies[2], bob)
	bodies[1].temp.grug_threat = {ana = 5, bob = 2}
	bodies[3].temp.grug_threat = {ana = 9}
	kill(bodies[2])
	check(#living() == 2 and pack.alive == 2, "E one dead while the fight goes on")
	bodies[1].health, bodies[3].health = 30, 40
	bodies[1]._grug_player_tag = {name = "ana"}
	bodies[1].object:set_pos({x = 20, y = 5, z = 0})

	die(ana)
	check(not pack.players.ana and pack.players.bob, "E a dead player leaves the list")
	check(bodies[1].temp.grug_threat.ana == nil and bodies[1].temp.grug_threat.bob == 2, "E the mobs forget the name")
	check(not grug_core.in_combat(ana), "E dead, out of combat")
	bodies[1].attack = nil
	bodies[1].state = "stand"
	bodies[3]:stop_attack()
	advance(1)
	check(bodies[1].attack == bob and bodies[3].attack == bob, "E the others turn on bob")
	check(grug_core.in_combat(bob), "E bob fights on")
	respawn(ana, {x = 0, y = 5, z = 0})
	advance(5)
	check(not grug_core.in_combat(ana) and bodies[1].attack == bob, "E back at the start, not hunted")

	die(bob)
	bodies[1].object:set_pos({x = 20, y = 5, z = 0})
	advance(1)
	check(no_timers() or #timers == 0, "E the tick ends with the wipe")
	check(#living() == 3 and pack.alive == 3, "E the dead mob stands again, at once")
	for _, ent in ipairs(living()) do
		check(ent.health == 100 and ent.attack == nil, "E whole and forgetting")
		check(ent._grug_player_tag == nil, "E no loot tag survives")
	end
	check(bodies[1].temp.grug_evading ~= nil, "E the living run home")
	check(bodies[3].temp.grug_evading == nil, "E one that stands at home has no run")
	local refilled
	for _, ent in ipairs(living()) do
		if ent ~= bodies[1] and ent ~= bodies[3] then refilled = ent end
	end
	check(distance(refilled.object:get_pos(), {x = 13, y = 5, z = 0}) == 0, "E at its place")
	check(pack.alive == 3 and next(pack.players) == nil, "E the list is empty, the pack waits")

	-- engaging again is a fresh pull; an evading mob wakes
	hit(bodies[3], ana)
	check(pack.players.ana and bodies[1].state == "attack" and bodies[1].temp.grug_evading == nil and
		refilled.attack == ana, "E a fresh pull, the run home ended")

	-- a body-less member at a wipe stands at its place too
	local saved = refilled.object.go_inactive()
	die(ana)
	advance(1)
	check(#living() == 3 and pack.alive == 3 and activate(saved) == nil, "E a body gets its place back")

	-- a run home lost with its block starts again when the mob wakes
	local walker = living()[1]
	walker.object:set_pos({x = 30, y = 5, z = 30})
	walker.temp.grug_evading = nil
	local woken = activate(walker.object.go_inactive())
	check(woken and woken.temp.grug_evading ~= nil, "E a waiting pack's mob away from home runs on")

	-- a fully dead pack stays dead
	local cleo = fake_player("cleo", run)
	hit(living()[1], cleo)
	for _, ent in ipairs(living()) do kill(ent) end
	die(cleo)
	advance(5)
	check(#living() == 0 and pack.alive == 0 and no_timers(), "E a dead pack stays dead")
	reset_world()
end

-- ---- F. The boss, a pack of one -----------------------------------------------------
do
	local run = new_run()
	local pack = P.new(run, "expedition:x:1")
	assert(P.add(pack, BOSS, {x = 0, y = 5, z = 0}))
	local ana = fake_player("ana", run, 5)
	local boss = living()[1]
	check(boss._grug_boss_id == "expedition:x:1" and boss._grug_tier == "elite", "F an elite with the ledger id")
	hit(boss, ana)
	boss.health = 10
	boss.object:set_pos({x = 5, y = 5, z = 3})
	die(ana)
	advance(1)
	check(boss.health == 100 and boss.temp.grug_evading ~= nil, "F a wipe heals it and sends it home")
	check(#boss_resets >= 1 and boss_resets[1] == "expedition:x:1", "F the attempt's ledger starts over")
	-- a boss without a body gets a new one at its place, ledger cleared
	local count = #boss_resets
	local bea = fake_player("bea", run, 5)
	hit(boss, bea)
	boss.object.go_inactive()
	die(bea)
	advance(1)
	check(#living() == 1 and living()[1]._grug_boss_id == "expedition:x:1", "F a boss without a body stands again")
	check(#boss_resets > count, "F that attempt's ledger too")
	-- dead it stays dead, and a wipe of nobody can bring it back
	local cleo = fake_player("cleo", run, 5)
	hit(living()[1], cleo)
	kill(living()[1])
	die(cleo)
	advance(2)
	check(#living() == 0, "F a dead boss stays dead")
	reset_world()
end

-- ---- G. Logging out and the end of a run ----------------------------------------------
do
	local run = new_run()
	local pack = mixed(run)
	local ana, bob = fake_player("ana", run), fake_player("bob", run)
	hit(living()[1], ana)
	hit(living()[1], bob)
	logout(ana)
	check(ana.meta[grug_expeditions.LOGOUT_DEATH] == "1" and #chat == 1, "G a logout in combat with a pack: a death")
	check(not pack.players.ana and pack.players.bob, "G off the list")
	advance(1)
	check(living()[1].attack == bob, "G the pack holds bob")

	login(ana, run)
	check(#ana.killed == 0, "G not inside the join callback")
	advance(0)
	check(ana.hp == 0 and #ana.killed == 1 and
		ana.killed[1].custom_type == grug_core.LOGOUT_DEATH_CUSTOM_TYPE, "G the death at the next join")
	check(ana.meta[grug_expeditions.LOGOUT_DEATH] == "", "G settled")
	check(not ana.killed[1].pvp_death, "G a death with Round 70's penalty, not a PvP one")
	-- the penalty once: the second login is free
	respawn(ana, {x = 0, y = 5, z = 0})
	logout(ana)
	login(ana, run)
	advance(1)
	check(ana.hp == 20 and #ana.killed == 1 and #chat == 1, "G once; out of combat a logout costs nothing")
	-- the last player's logout wipes
	logout(bob)
	advance(1)
	check(no_timers() and #chat == 2 and pack.alive == 3 and next(pack.players) == nil, "G the last logout wipes")
	-- dead at logout is no second death
	hit(living()[1], ana)
	die(ana)
	logout(ana)
	check(ana.meta[grug_expeditions.LOGOUT_DEATH] == "", "G a dead player is not listed")
	-- a shutdown is no logout
	login(ana, run)
	ana.hp = 20
	advance(0)
	hit(living()[1], ana)
	for _, fn in ipairs(callbacks.shutdown) do fn() end
	logout(ana)
	check(ana.meta[grug_expeditions.LOGOUT_DEATH] == "", "G a shutdown is no logout")
	reset_world()
end

-- The shutdown flag above stays set: from here on no logout marks, which H does not read.
do
	local run = new_run()
	local pack = mixed(run)
	local ana = fake_player("ana", run)
	local bodies = living()
	hit(bodies[1], ana)
	local saved = bodies[2].object.go_inactive()
	for _, fn in ipairs(ended) do fn(run, "empty") end
	advance(2)
	check(no_timers(), "G a run's end stops the tick")
	check(next(pack.players) == nil, "G its lists are gone")
	check(activate(saved) == nil, "G a copy of an ended run removes itself")
	-- leaving by a forced way out
	reset_world()
	local run2 = new_run()
	local pack2 = mixed(run2)
	local bea = fake_player("bea", run2)
	hit(living()[1], bea)
	for _, fn in ipairs(left) do fn(run2, "bea", "expelled") end
	check(next(pack2.players) == nil, "G expelled: off the list")
	-- out of the box by anything else: the tick's own check
	reset_world()
	local run3 = new_run()
	local pack3 = mixed(run3)
	local cora = fake_player("cora", run3)
	hit(living()[1], cora)
	run_of.cora = nil
	advance(1)
	check(next(pack3.players) == nil and no_timers(), "G the tick checks who is inside")
	reset_world()
end

-- ---- H. Ruling 6: nobody is held with nothing able to reach them ---------------------
-- A seeded world: packs, walls that blind and hold, blocks that go inactive, players who
-- run, die, log out or fight. After every second: whoever the timer holds is on a list,
-- alive and inside (or within the timer's last seconds), and every living member of a
-- pulled pack was able to strike or closing within the wedge limit.
local function world(seed)
	math.randomseed(seed)
	local random = math.random
	local run = new_run()
	local pack = mixed(run, random(5, 40))
	local crew = {}
	for index = 1, random(1, 3) do
		crew[index] = fake_player("p" .. index, run, random(0, 30), random(0, 30))
	end
	local wedged = {}     -- body -> since when it has been out of reach, not closing
	local blocked = {}    -- a mob that will not move while set
	local dark = random() < 0.3
	sight = function() return not dark end
	hit(living()[1], crew[1])
	local limit = 8 + 1
	for _ = 1, 150 do
		-- movement
		for _, ent in ipairs(living()) do
			local target = ent.attack
			if target and not blocked[ent.object] and target:get_pos() then
				local from, to = ent.object:get_pos(), target:get_pos()
				local d = distance(from, to)
				if d > 2 then
					local f = math.min(4 / d, 1)
					ent.object:set_pos({x = from.x + (to.x - from.x) * f, y = from.y,
						z = from.z + (to.z - from.z) * f})
				end
			end
		end
		-- the world happens
		local roll = random(100)
		if roll <= 8 then
			local ents = living()
			if ents[1] then blocked[ents[random(#ents)].object] = true end
		elseif roll <= 14 then
			local ents = living()
			if ents[1] then ents[random(#ents)].object.go_inactive() end
		elseif roll <= 22 then
			local player = crew[random(#crew)]
			if player.online and player.hp > 0 then
				player.at = {x = random(0, 127), y = 5, z = random(0, 127)}
			end
		elseif roll <= 25 then
			dark = not dark
		elseif roll <= 29 then
			local player = crew[random(#crew)]
			if player.online and player.hp > 0 then die(player) end
		elseif roll <= 31 then
			local player = crew[random(#crew)]
			if player.online and player.hp > 0 then logout(player) end
		elseif roll <= 35 then
			local ents = living()
			if ents[1] and random() < 0.5 then kill(ents[random(#ents)]) end
		elseif roll <= 60 then
			local player = crew[random(#crew)]
			local ents = living()
			if not player.online then
				login(player, run)
			elseif player.hp <= 0 then
				respawn(player, {x = 0, y = 5, z = 0})
			elseif ents[1] then
				hit(ents[random(#ents)], player)
			end
		end
		advance(1)
		-- the invariants
		for _, player in ipairs(crew) do
			if player.online and player.hp > 0 and fighting[player.name] and pack.players[player.name] then
				check(pack.alive > 0, "H held by a dead pack, seed " .. seed)
			end
			if pack.players[player.name] then
				check(player.online and player.hp > 0 and run_of[player.name] == run,
					"H a list holds only the living inside, seed " .. seed)
				check(grug_core.in_combat(player), "H a listed player is in combat, seed " .. seed)
			end
		end
		if next(pack.players) then
			local bodies = 0
			for _, ent in ipairs(living()) do
				bodies = bodies + 1
				local at, to = ent.object:get_pos(), ent.attack and ent.attack:get_pos()
				check(to ~= nil, "H every living member hunts, seed " .. seed)
				local id = ent.object
				-- One node needs no ray: the darkness of this world is a stand-in for walls.
				local near = distance(at, to) <= 1 or (distance(at, to) <= ent.reach and sight())
				local row = wedged[id]
				if near or (row and row.target ~= ent.attack) then wedged[id] = nil end
				if not near then
					wedged[id] = wedged[id] or {since = clock, closest = distance(at, to), target = ent.attack}
					if distance(at, to) < wedged[id].closest - 1 then
						wedged[id].since, wedged[id].closest = clock, distance(at, to)
					end
					check(clock - wedged[id].since <= limit + 1,
						"H a member out of reach too long, seed " .. seed)
				end
			end
			check(bodies == pack.alive, "H a body for every living member, seed " .. seed .. ": " ..
				bodies .. "/" .. pack.alive)
		else
			wedged = {}
		end
		if pack.alive == 0 then break end
	end
	-- Whatever is left ends: everybody out, a wipe, nobody held.
	for _, player in ipairs(crew) do
		if player.online and player.hp > 0 then die(player) end
	end
	advance(4)
	for _, player in ipairs(crew) do
		check(not grug_core.in_combat(player), "H nobody held at the end, seed " .. seed)
	end
	check(no_timers(), "H no tick left, seed " .. seed)
	check(pack.alive == 0 or next(pack.players) == nil, "H the list ran empty, seed " .. seed)
	reset_world()
end
for seed = 1, 300 do world(seed) end

-- ---- I. The real markers ---------------------------------------------------------
-- The Stilled Seam's encounter lines, as the template file holds them: each room one
-- pack, and each pack, idling at the walk of the real roam cap for an hour, stays by
-- its markers and never meets another.
do
	local file = assert(io.open(repo .. "/mods/PLAYER/grug_expeditions/templates/stilled_seam.exp", "rb"))
	local text = file:read("*a")
	file:close()
	local rows = {}
	for room, mob, count, tier, x, y, z in text:sub(1, text:find("\ndata ")):gmatch(
			"encounter (%S+) (%S+) (%d+) (%S+) (%d+) (%d+) (%d+)") do
		rows[#rows + 1] = {room = room, mob = mob, count = tonumber(count), tier = tier,
			pos = {x = tonumber(x), y = tonumber(y), z = tonumber(z)}}
	end
	check(#rows == 8, "I the eight marker rows: " .. #rows)
	local SPREAD = {{0, 0}, {3, 0}, {-3, 0}, {0, 3}, {0, -3}, {3, 3}, {-3, 3}, {3, -3}, {-3, -3}}
	local run = new_run()
	local packs_by_room, of_pack = {}, {}
	for _, row in ipairs(rows) do
		packs_by_room[row.room] = packs_by_room[row.room] or P.new(run, "expedition:stilled_seam:1")
		for index = 1, row.count do
			local offset = SPREAD[index]
			assert(P.add(packs_by_room[row.room], row,
				{x = row.pos.x + offset[1], y = row.pos.y, z = row.pos.z + offset[2]}))
		end
	end
	local rooms = 0
	for _ in pairs(packs_by_room) do rooms = rooms + 1 end
	check(rooms == 5, "I pack_a to pack_d and the boss: " .. rooms)
	local bodies = living()
	check(#bodies == 16, "I sixteen mobs: " .. #bodies)
	for room, pack in pairs(packs_by_room) do
		for _, member in ipairs(pack.members) do of_pack[member.object] = room end
	end
	math.randomseed(71)
	local farthest, closest = 0, math.huge
	for _ = 1, 3600 do
		for _, ent in ipairs(bodies) do
			local before = ent._test_turned
			grug_mobs.leash_tick(ent, 1)
			local at, home = ent.object:get_pos(), ent._grug_home
			local step = 1 -- walk_velocity of the spider and the golem
			if ent._test_turned ~= before then
				local d = distance(at, home)
				ent.object:set_pos({x = at.x + (home.x - at.x) / d * step, y = at.y,
					z = at.z + (home.z - at.z) / d * step})
			else
				local yaw = math.random() * 6.283
				ent.object:set_pos({x = at.x + math.cos(yaw) * step, y = at.y,
					z = at.z + math.sin(yaw) * step})
			end
			farthest = math.max(farthest, distance(ent.object:get_pos(), home))
		end
		for _, a in ipairs(bodies) do
			for _, b in ipairs(bodies) do
				if of_pack[a.object] ~= of_pack[b.object] then
					closest = math.min(closest, distance(a.object:get_pos(), b.object:get_pos()))
				end
			end
		end
	end
	check(farthest <= 9.5, "I an idle mob stays by its marker: " .. farthest)
	check(closest >= 15, "I two packs never meet: " .. closest)
	check(no_timers(), "I an idle hour costs no tick")
	reset_world()
end

print("R71 PACK PORTABLE PASS checks=" .. checks)
