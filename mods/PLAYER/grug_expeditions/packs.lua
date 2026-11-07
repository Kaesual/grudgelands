-- Packs (Round 71, concept section 2, the user's rulings): the mobs of one encounter
-- `room` are one pack. A pack is pulled whole, never gives up, and ends in a win, a
-- wipe or a logout. Expedition mobs have no second aggro path: every mob is an
-- ordinary grug mob with a body key in `_grug_pack`, and the seams that read the field
-- are in grug_mobs (leash, evade, give-up: aggro.lua; the stuck and dawn cleanup:
-- dawn.lua's mob_bound; every accepted do_attack: init.lua).
--
-- THE STATES OF A PACK
--   waiting  nobody on its list; `pulled` holds it not, and it costs nothing
--   pulled   engaged by someone: on `pulled`, visited by the tick once a second
--   dead     every mob dead; it stays dead
-- pull: a player's hit, a threat gain, a hit taken or a mob taking them as its target
-- (engage_mob, do_attack) puts them on the list and sets every member on them.
-- wipe: the list ran empty (a death, a logout, leaving the box). Then the living run
-- home healed and forgetting, the dead stand at their place at once, and it waits.
--
-- WHY NOBODY IS HELD WITH NOTHING ABLE TO REACH THEM
-- The tick alone keeps a player in combat: it renews a short timer (`mark_in_combat`)
-- for the names on a list, and only while the pack holds a living member, so
-- any way out of the list, and a tick that stopped, ends combat by itself. The tick
-- does not depend on a mob's own step, which an inactive block does not run. For each
-- living member, each second, one of these holds:
--   * no live body (its block went inactive, or it vanished): a new body stands beside
--     the player now, at the old health; the old copy, whenever it activates, finds
--     its key gone and removes itself. A body the engine refuses counts as dead.
--   * further than JUMP_RANGE from its target, inside the active blocks of any player
--     near it (active_block_range 4, 64 nodes): it jumps beside the target.
--   * WEDGED_SECONDS without getting a node closer: it strikes (in reach or a shot,
--     in sight) or it jumps. So a corner, a pit, a pillar or a wall ends in at most
--     that time, whatever the navigation thinks; a navigation give-up jumps at once.
-- A jump lands on a free cell the player can see, else on the player's own cell, so a
-- jumped mob is in reach. The list itself is checked every tick against who is
-- online, alive and inside.
local M = grug_expeditions
local P = {}

local LIFETIMER = 30000
-- Chase range in nodes, patience in seconds: without an end, and plain numbers in
-- staticdata. mobs_redo's own give-ups read these two fields (do_states).
local NEVER = 1000000
local TICK_SECONDS = 1
-- `in_combat` from one tick to the next, with room for a late tick.
local COMBAT_SECONDS = 3
local JUMP_RANGE = 32
local WEDGED_SECONDS = 8
local CLOSER = 1
local HOME_REACH = 4
local SIDES = {{2, 0}, {-2, 0}, {0, 2}, {0, -2}}

local bodies = {}    -- body key -> its member: a copy whose key is gone is stale
local next_body = 0
local by_run = {}    -- run -> its packs
local fights = {}    -- player name -> {[pack] = true}, the lists they are on
local pulled = {}    -- pack -> true: all the tick visits
local ticking, shutting_down = false, false

local function live_entity(member)
	local object = member.object
	return object and object:get_pos() and object:get_luaentity() or nil
end

function P.standable(pos)
	for dy = 0, 1 do
		local node = core.get_node_or_nil({x = pos.x, y = pos.y + dy, z = pos.z})
		local def = node and core.registered_nodes[node.name]
		if not def or def.walkable then return false end
	end
	return true
end

-- A cell beside the player that the player can see, else their own: always one a
-- mob can stand on and strike from.
local function beside(player)
	local at = vector.round(player:get_pos())
	local eye = {x = at.x, y = at.y + 1, z = at.z}
	for _, side in ipairs(SIDES) do
		local pos = {x = at.x + side[1], y = at.y, z = at.z + side[2]}
		if P.standable(pos) and core.line_of_sight(eye, {x = pos.x, y = pos.y + 1, z = pos.z}) then
			return pos
		end
	end
	return at
end

-- ---- Bodies -----------------------------------------------------------------------

-- A new body of `member` at `pos`, at `health` or full. The key is known before
-- add_entity, whose activation asks for it. Whatever carried the old key is stale.
local function spawn(member, pos, health)
	local pack, row = member.pack, member.row
	local run = pack.run
	local boss = row.tier == "boss"
	next_body = next_body + 1
	local key = next_body
	bodies[key] = member
	local object = core.add_entity(pos, row.mob, core.serialize({
		_grug_spawn_level = run.level, _grug_expedition = run.id,
		_grug_authored = true, lifetimer = LIFETIMER,
		_grug_boss_id = boss and pack.boss_id or nil,
		_grug_home = {x = member.home.x, y = member.home.y, z = member.home.z},
		_grug_pack = key, _grug_chase_range = NEVER, attack_patience = NEVER,
		_grug_soft_deaggro = false,
		-- The pack's pull is the only alert: no call reaches another pack.
		group_attack = false}))
	local ent = object and object:get_luaentity()
	if not ent then
		bodies[key] = nil
		return nil
	end
	grug_mobs.place_on_ground(object, pos)
	grug_mobs.set_tier(ent, boss and "elite" or row.tier)
	if health then
		grug_mobs.ensure_init(ent) -- the level's maximum first, it sets the health too
		ent.health, ent.old_health = health, health
		if type(ent.update_tag) == "function" then ent:update_tag() end
	end
	if member.key then bodies[member.key] = nil end
	member.key, member.object, member.closest = key, object, nil
	return ent
end

local function leave_list(pack, name)
	pack.players[name] = nil
	local set = fights[name]
	if set then
		set[pack] = nil
		if not next(set) then fights[name] = nil end
	end
end

-- One member less, whoever or whatever ended it. A pack without a living member is
-- dead: its players are free in this very step.
local function gone(member)
	if member.key then bodies[member.key] = nil end
	member.key, member.object, member.dead = nil, nil, true
	local pack = member.pack
	pack.alive = pack.alive - 1
	if pack.alive > 0 then return end
	pulled[pack] = nil
	for name in pairs(pack.players) do leave_list(pack, name) end
end

-- Off every list. The mobs forget the name too: a player who came back is hunted
-- only after engaging again (check_switch would hand them back by old threat).
local function drop_player(name)
	for pack in pairs(fights[name] or {}) do
		leave_list(pack, name)
		for _, member in ipairs(pack.members) do
			local ent = live_entity(member)
			local threat = ent and ent.temp and ent.temp.grug_threat
			if threat then threat[name] = nil end
		end
	end
end

-- ---- The pull ---------------------------------------------------------------------

-- Sets a member on a player: out of an evade run, and past a truce (the pack is
-- provoked as a whole).
local function wake(ent, player)
	ent.temp = ent.temp or {}
	local temp = ent.temp
	if temp.grug_evading then
		temp.grug_evading = nil
		grug_mobs.walk_clear(ent, "evade")
	end
	temp.grug_provoked = temp.grug_provoked or {}
	temp.grug_provoked[player:get_player_name()] = true
	ent:do_attack(player, true)
end

local tick
local function start_tick()
	if ticking then return end
	ticking = true
	core.after(TICK_SECONDS, tick)
end

local function contact(ent, player)
	local member = bodies[ent._grug_pack]
	if not member or not core.is_player(player) or player:get_hp() <= 0 then return end
	local pack = member.pack
	local name = player:get_player_name()
	if pack.players[name] or (ent.health or 1) <= 0 or M.run_inside(name) ~= pack.run then
		return
	end
	pack.players[name] = true
	fights[name] = fights[name] or {}
	fights[name][pack] = true
	grug_core.mark_in_combat(player, COMBAT_SECONDS)
	if pulled[pack] then return end
	pulled[pack] = true
	start_tick()
	for _, other in ipairs(pack.members) do
		local body = live_entity(other)
		if body then wake(body, player) end
	end
end
-- A mob taking a target (grug_mobs' do_attack seam): sight, a retaliation, a taunt.
grug_mobs.pack_contact = contact

-- Every other way into a fight: a hit, a threat gain, a hit taken (grug_core).
local engage_mob = grug_core.engage_mob
function grug_core.engage_mob(mob_ent, player)
	engage_mob(mob_ent, player)
	if mob_ent and mob_ent._grug_pack then contact(mob_ent, player) end
end

-- ---- The hunt ---------------------------------------------------------------------

local function nearest(pack, pos)
	local best, best_d
	for name in pairs(pack.players) do
		local player = core.get_player_by_name(name)
		local at = player and player:get_pos()
		local d = at and vector.distance(pos, at)
		if d and (not best_d or d < best_d) then best, best_d = player, d end
	end
	return best
end

local function jump(ent, member, player)
	grug_mobs.place_on_ground(ent.object, beside(player))
	ent.object:set_velocity({x = 0, y = 0, z = 0})
	mobs.grug_nav.forget(ent.temp)
	member.closest = nil
end

-- The navigation gave its target up: on a list, that is a jump, never a reset
-- (aggro.lua give_up_target).
function grug_mobs.pack_left_behind(ent)
	local member = bodies[ent._grug_pack]
	local player = ent.attack
	if member and core.is_player(player) and player:get_hp() > 0
			and member.pack.players[player:get_player_name()] then
		jump(ent, member, player)
	end
end

local function can_strike(ent, pos, at, distance)
	local ranged = ent.attack_type == "shoot" or ent.attack_type == "dogshoot"
	local range = ranged and ent.view_range or (ent.reach or 3) + 1
	return distance <= range and core.line_of_sight(
		{x = pos.x, y = pos.y + 1, z = pos.z}, {x = at.x, y = at.y + 1, z = at.z})
end

-- One member, one second: the three cases of the header.
local function hunt(pack, member, now)
	local ent = live_entity(member)
	if not ent then
		local player = nearest(pack, member.last or member.home)
		local body = spawn(member, beside(player), member.health)
		if body then return wake(body, player) end
		core.log("error", "[grug_expeditions] a pack lost its " .. member.row.mob)
		return gone(member)
	end
	if (ent.health or 0) <= 0 then return end
	local pos = ent.object:get_pos()
	member.health, member.last = ent.health, pos
	local target = ent.attack
	if ent.state ~= "attack" or not core.is_player(target)
			or not pack.players[target:get_player_name()] then
		target = nearest(pack, pos)
		wake(ent, target)
		member.closest = nil
	end
	local at = target:get_pos()
	local distance = vector.distance(pos, at)
	if distance > JUMP_RANGE then return jump(ent, member, target) end
	if not member.closest or distance < member.closest - CLOSER then
		member.closest, member.since = distance, now
	elseif now - member.since >= WEDGED_SECONDS then
		if can_strike(ent, pos, at, distance) then
			member.closest, member.since = distance, now
		else
			jump(ent, member, target)
		end
	end
end

-- The list ran empty: the pack leaves combat, whole, at its place. The boss's attempt
-- ends with it, so a later kill credits only who fought that one.
local function wipe(pack)
	pulled[pack] = nil
	for _, member in ipairs(pack.members) do
		if member.row.tier == "boss" then grug_mobs.boss_attempt_reset(pack.boss_id) end
		member.health, member.last, member.closest = nil, nil, nil
		local ent = live_entity(member)
		if ent then
			grug_mobs.leash_reset(ent)
			grug_mobs.evade_home(ent)
		else
			core.load_area(vector.subtract(member.home, HOME_REACH), vector.add(member.home, HOME_REACH))
			local dead = member.dead
			if spawn(member, member.home) then
				member.dead = nil
				if dead then pack.alive = pack.alive + 1 end
			elseif not dead then
				gone(member)
			end
		end
	end
end

local function tick_pack(pack, now)
	for name in pairs(pack.players) do
		local player = core.get_player_by_name(name)
		if not player or player:get_hp() <= 0 or M.run_inside(name) ~= pack.run then
			drop_player(name)
		end
	end
	if not next(pack.players) then return wipe(pack) end
	for _, member in ipairs(pack.members) do
		if not member.dead then hunt(pack, member, now) end
	end
	-- Only while it lasts: the last member may have gone a line above.
	for name in pairs(pack.players) do
		grug_core.mark_in_combat(core.get_player_by_name(name), COMBAT_SECONDS)
	end
end

tick = function()
	local now = grug_core.mono_time()
	for pack in pairs(pulled) do tick_pack(pack, now) end
	if next(pulled) then
		core.after(TICK_SECONDS, tick)
	else
		ticking = false
	end
end

-- ---- What encounters.lua and the engine hand in -----------------------------------

function P.new(run, boss_id)
	local pack = {run = run, boss_id = boss_id, members = {}, alive = 0, players = {}}
	by_run[run] = by_run[run] or {}
	table.insert(by_run[run], pack)
	return pack
end

-- A first body at the room's marker; false when the engine refused it.
function P.add(pack, row, pos)
	local member = {pack = pack, row = row, home = pos}
	if not spawn(member, pos) then return false end
	pack.members[#pack.members + 1] = member
	pack.alive = pack.alive + 1
	return true
end

-- Every death cause reaches this boundary (settle_mob_death); a stale copy never does.
local settle_mob_death = grug_mobs.settle_mob_death
function grug_mobs.settle_mob_death(self)
	local result = settle_mob_death(self)
	local member = self._grug_pack and bodies[self._grug_pack]
	if member then gone(member) end
	return result
end

-- On every activation, before anything else of the mob runs (the rule of
-- liveness.lua, without its storage: a pack lasts a run): the body of its member, or
-- a stale copy that removes itself. A restart leaves only stale copies. An evade run
-- is lost with its block, so a waiting pack's mob away from home starts it again.
local live_claim = grug_mobs.live_claim
function grug_mobs.live_claim(self)
	if self._grug_pack then
		local member = bodies[self._grug_pack]
		if not member then
			self.object:set_properties({static_save = false})
			self.object:remove()
			return false
		end
		member.object = self.object
		if not pulled[member.pack] then grug_mobs.evade_home(self) end
	end
	return live_claim(self)
end

M.register_on_end(function(run)
	for _, pack in ipairs(by_run[run] or {}) do
		pulled[pack] = nil
		for name in pairs(pack.players) do leave_list(pack, name) end
		for _, member in ipairs(pack.members) do
			if member.key then bodies[member.key] = nil end
		end
	end
	by_run[run] = nil
end)

-- ---- Leaving the list --------------------------------------------------------------

core.register_on_dieplayer(function(player)
	drop_player(player:get_player_name())
end)

-- A logout has its own rule below, with the player object in hand.
M.register_on_leave(function(_, name, reason)
	if reason ~= "logout" then drop_player(name) end
end)

-- Logging out on a pack's list is a death (ruling 7), Round 70's penalty once. As with
-- PvP (grug_pvp logout_death) the death itself happens at the next join: the leave
-- callback is no place to kill. A server shutdown is no logout.
core.register_on_shutdown(function() shutting_down = true end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	if fights[name] and not shutting_down and player:get_hp() > 0 then
		player:get_meta():set_string(M.LOGOUT_DEATH, "1")
		local _, message = grug_core.death_message(name,
			{type = "set_hp", custom_type = grug_core.LOGOUT_DEATH_CUSTOM_TYPE})
		core.chat_send_all(message)
	end
	drop_player(name)
end)

-- After every join callback, so the ordinary respawn path decides where they stand:
-- the start waystone, or the capital when the run is gone (guard.lua).
core.register_on_joinplayer(function(player)
	if player:get_meta():get_string(M.LOGOUT_DEATH) == "" then return end
	local name = player:get_player_name()
	core.after(0, function()
		local p = core.get_player_by_name(name)
		if not p then return end
		p:get_meta():set_string(M.LOGOUT_DEATH, "")
		if p:get_hp() > 0 then
			p:set_hp(0, {type = "set_hp", custom_type = grug_core.LOGOUT_DEATH_CUSTOM_TYPE})
		end
	end)
end)

return P
