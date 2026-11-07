-- The one scenario, on test_vault with its markers replaced so a mixed pack, a split
-- pack and the boss stand apart, in rooms the probe cuts into the box's stone:
-- pull, pause, far run, inactive block, wipe, logouts, a pack dead for good, the boss.
local E = grug_expeditions
local SPIDER, GOLEM = "grug_mobs:giant_spider", "grug_mobs:stone_golem"

local ROOMS = {
	{52, 52}, -- the split pack's near half
	{122, 122}, -- its far half: an inactive block for a player in the first room
	{70, 30}, -- the boss
	{20, 118}, -- empty: the far run's end
	{52, 30}, -- empty: a walled room within spawn range of the split pack and the boss
}
local SPLIT, FAR, COURT, RUNAWAY, WATCH = ROOMS[1], ROOMS[2], ROOMS[3], ROOMS[4], ROOMS[5]
local HALL_IDS = {[30] = true, [33] = true, [38] = true}
local FLOOR = 4

local function cell(run, room, dx, dz)
	return {x = run.minp.x + room[1] + (dx or 0), y = run.minp.y + FLOOR + 1,
		z = run.minp.z + room[2] + (dz or 0)}
end

local function cut(run, room)
	local middle = cell(run, room)
	core.load_area(vector.offset(middle, -6, -2, -6), vector.offset(middle, 6, 5, 6))
	for dx = -5, 5 do
		for dz = -5, 5 do
			for dy = 0, 3 do
				core.set_node(vector.offset(middle, dx, dy, dz), {name = "air"})
			end
			core.set_node(vector.offset(middle, dx, -1, dz), {name = "default:stonebrick"})
		end
	end
end

local function mobs_in(run)
	local out = {}
	for object in core.objects_in_area(run.minp, run.maxp) do
		local ent = object:get_luaentity()
		if ent and ent._grug_expedition then out[#out + 1] = ent end
	end
	return out
end

local function by_room(run, room)
	local out = {}
	for _, ent in ipairs(mobs_in(run)) do
		local home = ent._grug_home
		if home and home.x - run.minp.x == room then out[#out + 1] = ent end
	end
	return out
end

local function pack_of(run, ids)
	local out = {}
	for _, ent in ipairs(mobs_in(run)) do
		if ids[ent._grug_home.x - run.minp.x] then out[#out + 1] = ent end
	end
	return out
end

local function hall_now(run) return pack_of(run, HALL_IDS) end

local function kill_silently(ent)
	ent.health = 0
	ent:check_for_death({type = "unknown"})
end

local function stand(player, pos)
	player:set_pos({x = pos.x, y = pos.y - 0.49, z = pos.z})
end

local function back_in(lib, player, run)
	lib.check(E.enter(player, "highcourt"), "enter starts")
	lib.wait_for(function() return E.run_inside(player) == run end, 40)
	lib.check(E.run_inside(player) == run, "inside the box")
end

local function spread(ents, player)
	local far, near = 0, 1000
	local at = player:get_pos()
	for _, ent in ipairs(ents) do
		local d = vector.distance(ent.object:get_pos(), at)
		far, near = math.max(far, d), math.min(near, d)
	end
	return far, near
end

local function relogin(lib, number)
	lib.log("RELOGIN " .. number)
	lib.wait_for(function()
		local p = lib.player()
		return p and p:get_pos() ~= nil
	end, 60)
	lib.wait(2)
	return assert(lib.player())
end

local function die_and_return(lib, player)
	lib.wait_for(function() return player:get_hp() <= 0 end, 6)
	lib.check(player:get_hp() <= 0, "dead")
	lib.wait(0.5)
	player:respawn()
	lib.wait(3)
end

return function(lib, player)
	lib.logf("active_block_range %s", tostring(core.settings:get("active_block_range") or "default"))
	grug_xp.set_xp(player, grug_xp.xp_for_level(22))
	local wear = 0
	local wear_death = grug_repair.wear_death
	function grug_repair.wear_death(p)
		wear = wear + 1
		return wear_death(p)
	end
	local kills = {}
	grug_mobs.register_on_boss_kill(function(_, id) kills[#kills + 1] = id end)
	local stale = 0
	local live_claim = grug_mobs.live_claim
	function grug_mobs.live_claim(self)
		local ok = live_claim(self)
		if not ok then
			stale = stale + 1
			lib.logf("a stale copy of %s removed itself", self.name)
		end
		return ok
	end

	local rows = E.templates.test_vault.encounters
	local original = {}
	for index, row in ipairs(rows) do original[index] = row end
	for index in ipairs(original) do rows[index] = nil end
	local function row(room, mob, count, tier, at)
		rows[#rows + 1] = {room = room, mob = mob, count = count, tier = tier,
			pos = {x = at[1], y = FLOOR + 1, z = at[2]}}
	end
	row("hall", SPIDER, 2, "normal", {30, 12})
	row("hall", GOLEM, 1, "elite", {38, 22})
	row("split", SPIDER, 1, "normal", SPLIT)
	row("split", SPIDER, 1, "normal", FAR)
	row("court", GOLEM, 1, "boss", COURT)

	-- The way back's stone: a real player came from there, so it is generated.
	local capital = grug_home.waystone_pos("highcourt")
	local emerged = false
	core.emerge_area(vector.offset(capital, -16, -8, -16), vector.offset(capital, 16, 8, 16),
		function(_, _, remaining) emerged = emerged or remaining == 0 end)
	lib.wait_for(function() return emerged end, 40)

	local run = assert(E.create(player, "test_vault", 0))
	lib.wait_for(function() return run.state == "ready" end, 90)
	lib.check(run.state == "ready", "ready")
	for _, room in ipairs(ROOMS) do cut(run, room) end
	lib.heal = true
	back_in(lib, player, run)
	lib.wait(3)
	local hall = hall_now(run)
	lib.logf("the hall pack %d", #hall)
	lib.check(#hall == 3, "a mixed pack of three stands")
	local golem
	for _, ent in ipairs(hall) do
		lib.logf("  %s tier %s group_attack %s state %s", ent.name, tostring(ent._grug_tier),
			tostring(ent.group_attack), tostring(ent.state))
		if ent.name == GOLEM then golem = ent end
	end
	lib.check(golem ~= nil and core.registered_entities[GOLEM].group_attack == false,
		"the golem's family ignores group alerts")

	lib.phase("pull")
	lib.check(not grug_core.in_combat(player), "out of combat before the pull")
	grug_core.deal_ability_damage(player, golem.object, 5)
	lib.wait(0.3)
	local all = true
	for _, ent in ipairs(hall) do
		lib.logf("  after the hit: %s state %s target %s", ent.name, tostring(ent.state),
			ent.attack and "the player" or "none")
		all = all and ent.state == "attack" and ent.attack == player
	end
	lib.check(all, "one hit on the golem pulled the whole pack")
	lib.check(grug_core.in_combat(player), "in combat")
	local came = lib.wait_for(function()
		return (spread(hall, player)) <= 8
	end, 30)
	lib.logf("the whole pack within 8 nodes after %s s", tostring(came))
	lib.check(came ~= nil, "all came")
	lib.phase_end()

	lib.phase("pause")
	local held = true
	for _ = 1, 15 do
		lib.wait(1)
		held = held and grug_core.in_combat(player)
	end
	lib.check(held, "in combat through 15 s without a hit of the player's")
	lib.check(not E.leave(player), "the waystone refuses")
	lib.check(not grug_home.return_home(player), "Return Home refuses")
	lib.phase_end()

	lib.phase("run")
	-- A body that went with its block comes back as a new one: read the pack afresh.
	local function beside(limit)
		return function()
			local now = hall_now(run)
			return #now == 3 and (spread(now, player)) <= limit
		end
	end
	stand(player, cell(run, RUNAWAY))
	local t = lib.wait_for(beside(4), 15)
	lib.logf("the far run: all beside the player after %s s", tostring(t))
	lib.check(t ~= nil, "a mob left behind jumps after its player")
	for _, ent in ipairs(hall_now(run)) do lib.check(ent.attack == player, "it fights on") end
	lib.check(grug_core.in_combat(player), "still in combat")
	-- Back to the hall for the wipe: blocks round the start stay active there.
	stand(player, cell(run, {28, 8}))
	lib.logf("back in the hall: all beside the player after %s s", tostring(lib.wait_for(beside(5), 10)))
	lib.phase_end()

	lib.phase("wipe")
	local spider
	for _, ent in ipairs(hall_now(run)) do
		if ent.name == SPIDER then spider = ent end
	end
	kill_silently(spider)
	lib.wait(0.5)
	lib.check(#hall_now(run) == 2, "one dead, the fight goes on")
	lib.heal = false
	player:set_hp(0)
	lib.check(not grug_core.in_combat(player), "dead, out of combat")
	lib.wait(2)
	local refilled = hall_now(run)
	lib.logf("after the wipe %d mobs", #refilled)
	lib.check(#refilled == 3, "the pack refilled at once")
	for _, ent in ipairs(refilled) do
		lib.logf("  %s hp %s/%s evading %s attack %s", ent.name, tostring(ent.health),
			tostring(ent.hp_max), tostring(ent.temp and ent.temp.grug_evading ~= nil), tostring(ent.attack))
		lib.check(ent.health == ent.hp_max and ent.attack == nil, "whole and forgetting")
	end
	lib.wait(0.5)
	player:respawn()
	lib.wait(3)
	lib.heal = true
	lib.logf("back at %s", core.pos_to_string(vector.round(player:get_pos())))
	lib.check(vector.distance(player:get_pos(), E.start_arrival(run)) < 2, "at the start waystone")
	local home_at = lib.wait_for(function()
		local now = hall_now(run)
		for _, ent in ipairs(now) do
			if vector.distance(ent.object:get_pos(), ent._grug_home) > 6 then return false end
		end
		return #now == 3
	end, 45)
	lib.logf("all at their place after %s s", tostring(home_at))
	lib.check(home_at ~= nil, "they ran home")
	lib.check(not grug_core.in_combat(player), "not hunted at the start")
	lib.phase_end()

	lib.phase("inactive")
	-- A walled room: the split pack and the boss spawn, nobody sees the player.
	stand(player, cell(run, WATCH))
	lib.wait(6)
	local near = by_room(run, SPLIT[1])
	lib.logf("the split pack: live bodies %d, in the far room %d", #near, #by_room(run, FAR[1]))
	lib.check(#near == 1 and #by_room(run, FAR[1]) == 0, "its far half stands in an inactive block")
	lib.check(core.compare_block_status(cell(run, FAR), "active") ~= true, "the far block is inactive")
	lib.check(not grug_core.in_combat(player), "nobody saw the player")
	local wedged = near[1]
	grug_core.deal_ability_damage(player, wedged.object, 5)
	local brought = lib.wait_for(function() return #by_room(run, FAR[1]) == 1 end, 5)
	lib.logf("the far half stands by the player after %s s", tostring(brought))
	lib.check(brought ~= nil, "a member in an inactive block comes")
	local fetched = by_room(run, FAR[1])[1]
	lib.check(fetched ~= nil and vector.distance(fetched.object:get_pos(), player:get_pos()) <= 5,
		"beside the player")
	lib.check(fetched ~= nil and fetched.attack == player, "and fights")
	-- Walled off: the near half cannot walk here. It jumps by the wedge or a give-up.
	local reached = lib.wait_for(function()
		return vector.distance(wedged.object:get_pos(), player:get_pos()) <= 5
	end, 15)
	lib.logf("the walled-off mob stands by the player after %s s", tostring(reached))
	lib.check(reached ~= nil, "a wedged mob reaches the player")
	lib.heal = false
	player:set_hp(0)
	lib.wait(2.5)
	player:respawn()
	lib.wait(3)
	lib.heal = true
	-- The old copy, when its block wakes: seen from a player standing there, before
	-- the new body's run home is over.
	local stale_before = stale
	stand(player, cell(run, FAR, -4, -4))
	lib.wait_for(function() return stale > stale_before end, 12)
	lib.logf("stale copies removed %d", stale)
	lib.check(stale > stale_before, "the old copy removed itself")
	stand(player, E.start_arrival(run))
	lib.wait(4)
	lib.check(not grug_core.in_combat(player), "out of combat")
	lib.phase_end()

	lib.phase("logout")
	lib.wait(4) -- a mob that woke away from home takes no hit on its run
	hall = hall_now(run)
	lib.check(#hall == 3, "the hall pack waits")
	grug_core.deal_ability_damage(player, hall[1].object, 5)
	lib.wait(1)
	lib.check(grug_core.in_combat(player), "in combat with a pack")
	local before = wear
	core.kick_player(lib.NAME, "probe")
	lib.wait(2)
	player = relogin(lib, 1)
	lib.logf("logged in: hp %d", player:get_hp())
	lib.wait_for(function() return player:get_hp() <= 0 end, 5)
	lib.check(player:get_hp() <= 0, "a logout in combat with a pack is a death at the next login")
	lib.check(wear == before + 1, "the penalty once: " .. (wear - before))
	lib.wait(0.5)
	player:respawn()
	lib.wait(3)
	lib.logf("stands at %s", core.pos_to_string(vector.round(player:get_pos())))
	lib.check(vector.distance(player:get_pos(), E.start_arrival(run)) < 2, "at the start waystone")
	lib.check(E.run_inside(player) == run, "inside the run")
	lib.check(not grug_core.in_combat(player), "out of combat")
	lib.wait(1)
	for _, ent in ipairs(hall_now(run)) do lib.check(ent.attack == nil, "the pack let go") end

	-- out of combat a logout costs nothing and the player stands where they stood
	lib.wait(2)
	stand(player, cell(run, RUNAWAY, 2, 2))
	lib.wait(2)
	local stood = player:get_pos()
	before = wear
	core.kick_player(lib.NAME, "probe")
	lib.wait(2)
	player = relogin(lib, 2)
	lib.wait(2)
	lib.check(player:get_hp() > 0 and wear == before, "out of combat a logout costs nothing")
	lib.check(vector.distance(player:get_pos(), stood) < 2, "and they stand where they stood")
	lib.check(E.run_inside(player) == run, "inside again")
	lib.heal = true
	lib.phase_end()

	lib.phase("dead")
	stand(player, E.start_arrival(run))
	lib.wait_for(function() return #hall_now(run) == 3 end, 10)
	lib.wait(4) -- a mob away from home runs home when it wakes, and takes no hit
	hall = hall_now(run)
	grug_core.deal_ability_damage(player, hall[1].object, 5)
	lib.wait(1)
	lib.check(grug_core.in_combat(player), "pulled before the kills")
	for _, ent in ipairs(hall) do kill_silently(ent) end
	lib.wait(0.2)
	local free = lib.wait_for(function() return not grug_core.in_combat(player) end, 5)
	lib.logf("out of combat %s s after the last death", tostring(free))
	lib.check(free ~= nil, "a dead pack lets go")
	lib.heal = false
	player:set_hp(0)
	lib.wait(0.5)
	player:respawn()
	lib.wait(3)
	lib.heal = true
	lib.check(#hall_now(run) == 0, "a pack dead for good stays dead")
	lib.phase_end()

	lib.phase("boss")
	stand(player, cell(run, COURT, 4, 0))
	lib.wait(2)
	local boss = by_room(run, COURT[1])[1]
	lib.check(boss ~= nil and boss._grug_boss_id ~= nil, "the boss stands")
	grug_core.deal_ability_damage(player, boss.object, 50)
	lib.wait(1)
	local wounded = boss.health
	lib.logf("boss %s/%s", tostring(boss.health), tostring(boss.hp_max))
	lib.check(wounded > 0 and wounded < boss.hp_max, "wounded")
	lib.check(grug_core.in_combat(player), "the boss holds the player")
	lib.heal = false
	player:set_hp(0)
	lib.wait(2)
	lib.check(boss.health == boss.hp_max and boss.attack == nil, "a wipe heals the boss")
	lib.wait(0.5)
	player:respawn()
	lib.wait(3)
	lib.heal = true
	lib.check(not E.rewards_open(run), "the chest stays shut")
	stand(player, cell(run, COURT, 4, 0))
	lib.wait_for(function() return by_room(run, COURT[1])[1] ~= nil end, 6)
	boss = assert(by_room(run, COURT[1])[1]) -- its block may have left the active set
	grug_core.deal_ability_damage(player, boss.object, 50)
	lib.wait(0.5)
	grug_core.deal_ability_damage(player, boss.object, 1000000)
	lib.wait(1)
	lib.logf("kill credit %s", table.concat(kills, " "))
	lib.check(#kills == 1 and kills[1] == "expedition:test_vault", "one credit after the reset")
	lib.check(E.rewards_open(run), "its death opens the chest")
	lib.phase_end()

	lib.phase("run gone")
	stand(player, cell(run, WATCH))
	lib.wait_for(function() return by_room(run, SPLIT[1])[1] ~= nil end, 8)
	lib.wait(4)
	local rest = by_room(run, SPLIT[1])
	lib.check(#rest >= 1, "a living pack to log out of")
	grug_core.deal_ability_damage(player, rest[1].object, 5)
	lib.wait(1)
	lib.check(grug_core.in_combat(player), "in combat with it")
	before = wear
	core.kick_player(lib.NAME, "probe")
	lib.wait(1)
	E.end_run(run, "probe")
	player = relogin(lib, 3)
	lib.wait_for(function() return player:get_hp() <= 0 end, 5)
	lib.check(player:get_hp() <= 0 and wear == before + 1, "the death counts with the run gone too")
	lib.wait(0.5)
	if player:get_hp() <= 0 then player:respawn() end
	local home = lib.wait_for(function()
		return vector.distance(player:get_pos(), capital) < 6
	end, 30)
	lib.logf("stands at %s, the capital's stone %s", core.pos_to_string(vector.round(player:get_pos())),
		core.pos_to_string(capital))
	lib.check(home ~= nil, "the capital they came from")
end
