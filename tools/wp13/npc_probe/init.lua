-- Disposable headless probe for the settlement NPC roster (WP13 playtest round
-- 1, 2026-09-15). Staged into a scratch game copy by
-- `tools/wp13/run_npc_probe.sh` (PROBE= of tools/luanti_headless.sh); never
-- shipped with the game, never loaded by a normal server.
--
-- It answers the three questions of this round that only the engine can:
--
--   1. UNBOUNDED SPAWNS. Every NPC of one start is moved 40 nodes off its
--      socket and the heartbeat is then left alone for well over ten beats. The
--      population, counted BY IDENTITY out of the map rather than out of the
--      log, must stay at the roster. Before the fix each heartbeat freed the
--      marker of every NPC that was not standing exactly on its socket and
--      placed a twin.
--   3. VILLAGERS WANDER. The idle NPCs' positions are logged every ten seconds
--      for three minutes, which is the trace the dwell/walk cycle has to show.
--   8. THE ELITE HP LABEL. The full (level, tier, self.hp_max, property hp_max,
--      health, nametag) tuple per guard, on a fresh world and again after two
--      reboots on the SAME world -- two reload cycles is what it took for
--      mob_activate's lost `hp_max` to reach the label. Plus an injection that
--      reproduces the broken state on purpose and shows the activation path
--      healing it.
--
-- WHY A FORCELOAD AND NOT A FAKE PLAYER: an object exists in the environment
-- only while its mapblock is ACTIVE, and `ActiveBlockList::update` starts its
-- new list from the forceloaded set (serverenvironment.cpp), so a forceload
-- activates blocks exactly like a nearby player without any of an
-- impersonated PlayerSAO's side effects on other mods. Everything under test
-- reads the map, never `core.get_connected_players`.
--
-- Plain Lua 5.1.

grug_wp13_npc_probe = {}

local storage = core.get_mod_storage()
local BOOT = (tonumber(storage:get_string("boots")) or 0) + 1
storage:set_string("boots", tostring(BOOT))

local FORCE_REACH = 64 -- nodes each way; the block grid that stays active
local MOVE_AWAY = 40 -- nodes off the socket, the playtest's own distance

local function log(fields)
	local parts = {"GRUG_WP13_NPC", "boot=" .. BOOT}
	for index = 1, #fields do parts[#parts + 1] = fields[index] end
	core.log("action", table.concat(parts, " "))
end

local function fail(message)
	core.log("error", "GRUG_WP13_NPC boot=" .. BOOT .. " event=fail " .. message)
end

--
-- The settlement under test: the first registered one, which the loader
-- publishes as a race's START.
--
local settlement

local function find_settlement()
	if settlement then return settlement end
	local list = grug_core.settlement_socket_settlements()
	if #list == 0 then return nil end
	settlement = list[1]
	settlement.sockets = grug_core.settlement_sockets_at(settlement.key)
	return settlement
end

local function forceload_area(anchor)
	local blocks = 0
	local step = 16
	local y
	for dx = -FORCE_REACH, FORCE_REACH, step do
		for dz = -FORCE_REACH, FORCE_REACH, step do
			for dy = 0, step, step do
				y = anchor.y + dy
				if core.forceload_block({x = anchor.x + dx, y = y,
						z = anchor.z + dz}, true, -1) then
					blocks = blocks + 1
				end
			end
		end
	end
	return blocks
end

-- Every NPC of this settlement, by identity: the field the placement engine
-- writes, not a position and not an entity name.
local function settlement_npcs()
	local found = {}
	local objects = core.get_objects_inside_radius(
		{x = settlement.anchor.x, y = settlement.anchor.y,
			z = settlement.anchor.z}, 200)
	for index = 1, #objects do
		local entity = objects[index]:get_luaentity()
		if entity and entity._grug_start == settlement.key then
			found[#found + 1] = entity
		end
	end
	return found
end

--
-- `strict` asserts the whole population property and not just half of it: the
-- count must EQUAL the roster, no two NPCs may share a socket, and every socket
-- that carries a marker must have exactly one holder. The first version only
-- failed on live > roster, so a run that read live = 0 passed (the review of this
-- round found exactly that). It is passed at every terminal phase; the two
-- phases where a number other than the roster is the point say so themselves.
--
local function census_line(tag, strict)
	local rows = grug_mobs.start_npc_census()
	local roster, marked = 0, 0
	for index = 1, #rows do
		if rows[index].key == settlement.key then
			roster = rows[index].roster
			marked = rows[index].marked
		end
	end
	local npcs = settlement_npcs()
	local by_socket, twins, shared = {}, 0, nil
	for index = 1, #npcs do
		local id = npcs[index]._grug_socket or "?"
		if by_socket[id] then
			twins = twins + 1
			shared = id
		end
		by_socket[id] = true
	end
	log({"event=census", "phase=" .. tag, "key=" .. settlement.key,
		"roster=" .. roster, "marked=" .. marked, "live=" .. #npcs,
		"twins=" .. twins, "strict=" .. tostring(strict == true)})
	if #npcs > roster then
		fail("live=" .. #npcs .. " exceeds roster=" .. roster)
	end
	if twins > 0 then
		fail(twins .. " NPCs share a socket (" .. tostring(shared) .. ")")
	end
	if strict then
		if #npcs ~= roster then
			fail("phase " .. tag .. ": live=" .. #npcs .. " differs from " ..
				"roster=" .. roster)
		end
		if marked ~= roster then
			fail("phase " .. tag .. ": marked=" .. marked .. " differs from " ..
				"roster=" .. roster)
		end
	end
	return #npcs, roster
end

local function positions_line()
	local npcs = settlement_npcs()
	for index = 1, #npcs do
		local entity = npcs[index]
		if entity.name:find("villager", 1, true) then
			local pos = entity.object and entity.object:get_pos()
			if pos then
				log({"event=pos", "socket=" .. tostring(entity._grug_socket),
					"spot=" .. tostring(entity._grug_idle_spot),
					"dwell=" .. string.format("%.1f",
						tonumber(entity._grug_idle_dwell) or -1),
					"state=" .. tostring(entity.state),
					"x=" .. string.format("%.1f", pos.x),
					"z=" .. string.format("%.1f", pos.z)})
			end
		end
	end
end

local function hp_lines(tag)
	local npcs = settlement_npcs()
	for index = 1, #npcs do
		local entity = npcs[index]
		if entity.name:find("guard", 1, true) then
			local props = entity.object:get_properties()
			log({"event=hp", "phase=" .. tag,
				"socket=" .. tostring(entity._grug_socket),
				"level=" .. tostring(entity._grug_level),
				"tier=" .. tostring(entity._grug_tier),
				"self_hp_max=" .. tostring(entity.hp_max),
				"prop_hp_max=" .. tostring(props and props.hp_max),
				"health=" .. tostring(entity.health),
				"tag=" .. (string.gsub(grug_mobs.tag_text(entity), " ", "_"))})
		end
	end
end

-- Reproduce the exact broken state mob_activate leaves behind -- `self.hp_max`
-- gone and the object back on the definition default -- and show the activation
-- path putting both back.
local function hp_injection()
	local npcs = settlement_npcs()
	for index = 1, #npcs do
		local entity = npcs[index]
		if entity.name:find("guard", 1, true) then
			local before = entity.hp_max
			entity.hp_max = nil
			entity.object:set_properties({hp_max = 10})
			grug_mobs.ensure_init(entity)
			local props = entity.object:get_properties()
			log({"event=hp_heal", "socket=" .. tostring(entity._grug_socket),
				"before=" .. tostring(before),
				"injected_self=nil", "injected_prop=10",
				"after_self=" .. tostring(entity.hp_max),
				"after_prop=" .. tostring(props and props.hp_max),
				"tag=" .. (string.gsub(grug_mobs.tag_text(entity), " ", "_"))})
			if entity.hp_max ~= before then
				fail("the activation path did not restore hp_max")
			end
			return
		end
	end
	fail("no guard to injection-test")
end

--
-- Item 5 in the engine. One wolf beside a villager and one beside a guard post:
--   * NEITHER may acquire an NPC (`attack_npcs = false`, now applied by the
--     registration wrapper to every mob) -- that is the boar standing in front
--     of an invulnerable villager the playtest found;
--   * a guard must still acquire the wolf (`attack_monsters` is untouched);
--   * and the wolf must still hit back once the guard hits it, because on_punch's
--     retaliation (api.lua:3208-3213) reads `passive`, `state`, `child` and
--     ownership and never any `attack_*` field.
--
local HOSTILE = "grug_mobs:wolf"
local hostiles = {}
local cleared_socket

local function target_name(target)
	if not target then return "nil" end
	if core.is_player(target) then return "player" end
	local entity = target:get_luaentity()
	return entity and entity.name or "?"
end

local function spawn_hostiles()
	local npcs = settlement_npcs()
	local hosts = {}
	for index = 1, #npcs do
		local entity = npcs[index]
		if not hosts.villager and entity.name:find("villager", 1, true) then
			hosts.villager = entity
		end
		if not hosts.guard and entity.name:find("guard", 1, true) then
			hosts.guard = entity
		end
	end
	local order = {{label = "at_villager", host = hosts.villager},
		{label = "at_guard", host = hosts.guard}}
	for index = 1, #order do
		local row = order[index]
		local pos = row.host and row.host.object and row.host.object:get_pos()
		if pos then
			local object = core.add_entity(
				{x = pos.x + 2, y = pos.y, z = pos.z}, HOSTILE)
			if object then
				hostiles[#hostiles + 1] = {label = row.label, object = object}
				log({"event=hostile_spawn", "at=" .. row.label,
					"host=" .. tostring(row.host.name),
					"pos=" .. core.pos_to_string(pos)})
			else
				fail("could not place " .. HOSTILE .. " " .. row.label)
			end
		else
			fail("no host for " .. row.label)
		end
	end
end

local function hostile_lines(tag)
	for index = 1, #hostiles do
		local row = hostiles[index]
		local entity = row.object:get_luaentity()
		if not entity then
			log({"event=hostile", "phase=" .. tag, "at=" .. row.label,
				"state=gone"})
		else
			log({"event=hostile", "phase=" .. tag, "at=" .. row.label,
				"attack_npcs=" .. tostring(entity.attack_npcs),
				"attack_players=" .. tostring(entity.attack_players),
				"state=" .. tostring(entity.state),
				"target=" .. target_name(entity.attack),
				"health=" .. tostring(entity.health)})
			if target_name(entity.attack):find("villager", 1, true) or
					target_name(entity.attack):find("elder", 1, true) or
					target_name(entity.attack):find("vendor", 1, true) then
				fail("a hostile mob acquired a settlement NPC")
			end
		end
	end
	local npcs = settlement_npcs()
	for index = 1, #npcs do
		local entity = npcs[index]
		if entity.name:find("guard", 1, true) then
			log({"event=guard_target", "phase=" .. tag,
				"socket=" .. tostring(entity._grug_socket),
				"state=" .. tostring(entity.state),
				"target=" .. target_name(entity.attack)})
		end
	end
end

--
-- The programme. Boot 1 exercises everything; a reboot on the same world only
-- has to show what the reload does to the roster and to the HP label.
--
local FULL = {
	{at = 0, what = function()
		log({"event=forceload", "blocks=" .. forceload_area(settlement.anchor)})
		-- NOT strict: the forceload is registered in this globalstep and the
		-- engine's active-block management runs on its own two-second interval,
		-- so nothing it just asked for is activated yet. That is also why the
		-- free path cannot misfire here -- `compare_block_status` answers
		-- "loaded" until the pass that activates the block activates its
		-- objects.
		census_line("ready")
	end},
	{at = 10, what = function() positions_line() end},
	{at = 30, what = function() positions_line() end},
	{at = 50, what = function() positions_line() end},
	{at = 70, what = function() positions_line() end},
	{at = 90, what = function() positions_line() end},
	{at = 110, what = function() positions_line() end},
	{at = 130, what = function() positions_line() end},
	{at = 150, what = function() positions_line() end},
	{at = 170, what = function()
		positions_line()
		census_line("ambled", true)
	end},
	{at = 180, what = function()
		-- Off the socket, and always toward the middle of the forceloaded grid
		-- so the NPC stays in an ACTIVE mapblock: what is under test is the
		-- occupancy rule, not the activation radius.
		local npcs = settlement_npcs()
		local moved = 0
		for index = 1, #npcs do
			local entity = npcs[index]
			local pos = entity.object and entity.object:get_pos()
			if pos then
				local dx = MOVE_AWAY
				if pos.x > settlement.anchor.x then dx = -MOVE_AWAY end
				entity.object:set_pos({x = pos.x + dx, y = pos.y, z = pos.z})
				moved = moved + 1
			end
		end
		log({"event=moved", "n=" .. moved, "nodes=" .. MOVE_AWAY})
		census_line("moved", true)
	end},
	{at = 200, what = function() census_line("beat4", true) end},
	{at = 230, what = function() census_line("beat10", true) end},
	{at = 260, what = function() census_line("beat16", true) end},
	{at = 265, what = function()
		-- THE OTHER HALF OF ITEM 1: a marker whose NPC is really gone must be
		-- freed and refilled. One villager is removed outright -- what
		-- /clearobjects does to a whole settlement -- and this is also the only
		-- place `core.compare_block_status` is exercised against the real
		-- engine, because a marked socket is freed only where the map says its
		-- own mapblock is active.
		local npcs = settlement_npcs()
		for index = 1, #npcs do
			local entity = npcs[index]
			if entity.name:find("villager", 1, true) then
				cleared_socket = entity._grug_socket
				log({"event=cleared", "socket=" .. tostring(cleared_socket)})
				mobs:remove(entity, true)
				return
			end
		end
		fail("no villager to clear")
	end},
	{at = 270, what = function()
		-- One heartbeat later: still nine markers and only eight NPCs, because
		-- three passes have to agree before a marker is freed. The one phase
		-- whose whole point is a count OTHER than the roster, hence not strict.
		local live = census_line("one_strike")
		if live ~= 8 then
			fail("the cleared villager is still counted: live=" .. live)
		end
	end},
	{at = 290, what = function()
		local live, roster = census_line("refilled", true)
		if live ~= roster then
			fail("the cleared socket was not refilled: live=" .. live ..
				" of " .. roster)
		end
		log({"event=refill", "socket=" .. tostring(cleared_socket),
			"live=" .. live})
	end},
	{at = 295, what = function()
		hp_lines("fresh")
		hp_injection()
	end},
	-- The hostile pass runs LAST, after every census: a wolf that killed a guard
	-- would free a socket, and the roster count must not have to explain that.
	{at = 300, what = spawn_hostiles},
	-- Three and six seconds in: `general_attack` runs once a second, so this is
	-- where the guard has just acquired the wolf and the wolf, once punched, has
	-- just acquired the guard back. Fifteen seconds was too late -- a level-20
	-- guard had already killed it.
	{at = 303, what = function() hostile_lines("t3") end},
	{at = 306, what = function() hostile_lines("t6") end},
	{at = 315, what = function() hostile_lines("acquired") end},
	{at = 340, what = function()
		hostile_lines("fought")
		census_line("after_fight", true)
		log({"event=complete", "programme=full"})
		core.request_shutdown("wp13 npc probe done", false, 1)
	end},
}

local RELOAD = {
	{at = 0, what = function()
		log({"event=forceload", "blocks=" .. forceload_area(settlement.anchor)})
	end},
	{at = 20, what = function()
		census_line("reloaded", true)
		hp_lines("reloaded")
		positions_line()
		log({"event=complete", "programme=reload"})
		core.request_shutdown("wp13 npc probe done", false, 1)
	end},
}

local programme = BOOT == 1 and FULL or RELOAD
local next_step = 1
local clock = 0
local accumulator = 0
local started = false

core.register_globalstep(function(dtime)
	accumulator = accumulator + dtime
	if accumulator < 1 then return end
	-- The clock counts SERVER SECONDS, not ticks: under load a step can be
	-- several seconds long, and a tick-counting clock then runs slower than the
	-- wall clock the run script's timeout is measured in.
	local elapsed = accumulator
	accumulator = 0
	if not started then
		local row = find_settlement()
		if not row then return end
		if not grug_core.start_ready(row.race_id) then return end
		started = true
		log({"event=ready", "key=" .. row.key, "race=" .. row.race_id,
			"anchor=" .. core.pos_to_string(row.anchor),
			"sockets=" .. #row.sockets, "programme=" ..
			(BOOT == 1 and "full" or "reload")})
	end
	clock = clock + elapsed
	while next_step <= #programme and programme[next_step].at <= clock do
		local job = programme[next_step]
		next_step = next_step + 1
		job.what()
	end
end)
