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
-- PLAYTEST ROUND 2 (2026-09-15) adds four, and they are the four the user's
-- rulings turn on:
--
--   R1. SPARE SOCKETS NEVER SPAWN. The settlement's roster is its SPAWN
--       sockets; every `spawn = false` idle socket is a wander target and
--       nothing may ever be booked on one. Read out of the map by identity,
--       like every other census here.
--   R2. VILLAGERS VISIT MORE THAN ONE SPOT. The spot index of every flair NPC
--       is collected over the whole three-minute window and each of them has
--       to have stood at two different ones -- which is only possible at all
--       because the spares give them somewhere to go. ROUND 3 SPLIT THIS IN
--       TWO (see `wander_verdict`): only a WALKER has to reach a second spot,
--       and a static resident must reach none.
--   R3. THE ELDER FACES THE STREET. Its authored socket faces the hall door
--       (`door` tag); the placement engine turns it round, so the entity's own
--       yaw must be the socket's plus pi.
--   R4. MUTUAL COMBAT, AND NOT WITH CIVILIANS. A hostile beside a guard post
--       engages the watch and the watch engages it -- round 1's blanket
--       `attack_npcs = false` had made that impossible -- while a hostile
--       standing two nodes from a villager never acquires it, and no mob in
--       the settlement ever holds a non-combatant as its target.
--
-- PLAYTEST ROUND 3 (2026-09-15) adds three more, the user's rulings of that
-- round (sockets contract section 8):
--
--   W1. WORK RESIDENTS. A `work` socket produces a resident that stands ON it
--       with no wander ring, carrying the activity the socket names and the
--       animation and tool that activity means -- on a fresh world and again
--       after a reboot, because the activity lives in staticdata while the
--       animation and the wield entity are re-applied on activation.
--   W2. THE NAMETAG PROXIMITY GATE. The villager, elder and vendor families
--       write no nametag property at 40 m and the right one at 20 m. The
--       property is read off the real object; only the distance source is
--       substituted, because a headless server has no connected player.
--   W3. PROFESSION VENDORS. The five entities of section 8.4 exist and their
--       shelves survived the load-time item audit with offers on them.
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

-- socket id -> the registry entry, and the subset that is SPARE. Both read
-- once out of grug_core, which is the authority on what a settlement exports.
local socket_by_id = {}
local spare_sockets = {}

local function find_settlement()
	if settlement then return settlement end
	local list = grug_core.settlement_socket_settlements()
	if #list == 0 then return nil end
	settlement = list[1]
	settlement.sockets = grug_core.settlement_sockets_at(settlement.key)
	for index = 1, #settlement.sockets do
		local socket = settlement.sockets[index]
		socket_by_id[socket.id] = socket
		if socket.spawn == false then spare_sockets[socket.id] = true end
	end
	return settlement
end

-- R2. Which idle spots each flair NPC has actually stood at, over the whole
-- window: socket id -> spot index -> true. Filled by `positions_line`.
local spots_seen = {}

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
local function census_line(tag, strict, expect_live)
	local rows = grug_mobs.start_npc_census()
	local roster, marked, spare = 0, 0, 0
	for index = 1, #rows do
		if rows[index].key == settlement.key then
			roster = rows[index].roster
			marked = rows[index].marked
			spare = rows[index].spare or 0
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
		"twins=" .. twins, "spare=" .. spare,
		"strict=" .. tostring(strict == true)})
	-- R1. A SPARE SOCKET IS NEVER A HOME. Nothing may be booked on one, in any
	-- phase, whatever the roster count happens to be.
	if spare < 1 then
		fail("the settlement publishes no spare idle socket")
	end
	for index = 1, #npcs do
		local socket_id = npcs[index]._grug_socket
		if socket_id and spare_sockets[socket_id] then
			fail("an NPC is booked on the spare socket " .. socket_id)
		end
	end
	if #npcs > roster then
		fail("live=" .. #npcs .. " exceeds roster=" .. roster)
	end
	if twins > 0 then
		fail(twins .. " NPCs share a socket (" .. tostring(shared) .. ")")
	end
	if expect_live then
		if #npcs ~= expect_live then
			fail("phase " .. tag .. ": live=" .. #npcs .. " differs from the " ..
				"expected " .. expect_live)
		end
		if marked ~= roster then
			fail("phase " .. tag .. ": marked=" .. marked .. " differs from " ..
				"roster=" .. roster .. " -- a marker was freed for an NPC that " ..
				"is merely unloaded")
		end
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
	return #npcs, roster, marked
end

-- The settlement's roster size, out of the placement engine's own census. Used
-- where a phase expects "one fewer than the roster": the roster grows whenever
-- a composition gains a socket, and a literal written here goes stale silently
-- (round 3 added two `work` sockets per start).
local function roster_size()
	local rows = grug_mobs.start_npc_census()
	for index = 1, #rows do
		if rows[index].key == settlement.key then return rows[index].roster end
	end
	return 0
end

local SPOT_ARRIVED = 1.6

--
-- R2. WHERE A VILLAGER IS STANDING, not where it is heading: a target index
-- proves an intention, an arrival proves a walk. The spots are the ones the
-- placement engine handed this NPC, spares included.
--
-- Sampled once a SECOND from the globalstep rather than at the nine logging
-- points, because a dwell is 20 to 60 s and a walk between two Hearthpine spots
-- is about 25 s: a twenty-second sampler can miss a whole visit and would make
-- this assertion a coin toss instead of a measurement. It is a distance test
-- over at most a handful of entities, so it costs nothing.
--
local function sample_spots()
	local npcs = settlement_npcs()
	for index = 1, #npcs do
		local entity = npcs[index]
		if entity.name:find("villager", 1, true) then
			local pos = entity.object and entity.object:get_pos()
			local spots = entity._grug_idle_spots
			if pos and spots then
				for spot_index = 1, #spots do
					local spot = spots[spot_index]
					local dx, dz = spot.x - pos.x, spot.z - pos.z
					if dx * dx + dz * dz <= SPOT_ARRIVED * SPOT_ARRIVED then
						local socket_id = entity._grug_socket or "?"
						local row = spots_seen[socket_id]
						if not row then
							-- WHICH SIDE OF THE 80/20 SPLIT this resident is on
							-- (playtest round 3). Recorded here, with the
							-- sample, because the verdict below asks a
							-- different question of a walker than of a static
							-- resident and a name cannot tell them apart.
							row = {walker = entity._grug_walker == true,
								seen = {}, spots = #spots}
							spots_seen[socket_id] = row
						end
						row.seen[spot_index] = true
					end
				end
			end
		end
	end
end

local function standing_at(entity, pos)
	local spots = entity._grug_idle_spots or {}
	for spot_index = 1, #spots do
		local spot = spots[spot_index]
		local dx, dz = spot.x - pos.x, spot.z - pos.z
		if dx * dx + dz * dz <= SPOT_ARRIVED * SPOT_ARRIVED then
			return tostring(spot_index)
		end
	end
	return "-"
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
					"at=" .. standing_at(entity, pos),
					"spots=" .. #(entity._grug_idle_spots or {}),
					"dwell=" .. string.format("%.1f",
						tonumber(entity._grug_idle_dwell) or -1),
					"state=" .. tostring(entity.state),
					"x=" .. string.format("%.1f", pos.x),
					"z=" .. string.format("%.1f", pos.z)})
			end
		end
	end
end

--
-- R2's verdict, once, at the end of the amble window -- and since playtest
-- round 3 it asks TWO questions instead of one, because "every villager wanders"
-- stopped being the rule. The user's 80/20 ruling (contract section 8.3) makes
-- about one resident in five a walker and the rest static, so:
--
--   * a WALKER has to have stood at two different spots over the window. That
--     is round 2's claim, unchanged, applied to the people it is now about.
--   * a STATIC idle resident has to have stood at exactly ONE -- its own. Its
--     dwell is three to seven minutes and the window is 170 seconds, so a
--     second spot in that time is a static resident behaving like a walker,
--     which is the defect this half is here to catch.
--
-- Work residents never appear here at all: they carry no spot ring, and
-- `sample_spots` therefore never records one.
--
local function wander_verdict()
	local walkers, movers, statics, strayed = 0, 0, 0, 0
	for socket_id, row in pairs(spots_seen) do
		local count = 0
		for _ in pairs(row.seen) do count = count + 1 end
		log({"event=wander", "socket=" .. socket_id,
			"walker=" .. tostring(row.walker), "ring=" .. row.spots,
			"distinct=" .. count})
		if row.walker then
			walkers = walkers + 1
			if count >= 2 then movers = movers + 1 end
			if count < 2 then
				fail("the walker on " .. socket_id .. " stood at " .. count ..
					" idle spot over the whole window")
			end
		else
			statics = statics + 1
			if count > 1 then
				strayed = strayed + 1
				fail("the static resident on " .. socket_id .. " stood at " ..
					count .. " idle spots inside its own dwell")
			end
		end
	end
	log({"event=wander_done", "walkers=" .. walkers, "moved=" .. movers,
		"static=" .. statics, "strayed=" .. strayed})
	if walkers < 1 then
		fail("the settlement has no walking resident at all")
	end
	if statics < 1 then
		fail("the settlement has no static idle resident at all")
	end
end

--
-- R3. THE ELDER FACES THE STREET. Its socket is tagged `door` and its authored
-- facing is the door, so the placement engine turns it round -- the entity's
-- yaw must be the socket's plus pi, and that is read off the OBJECT, not off
-- the field the engine wrote, because what the player sees is the object.
--
local TWO_PI = 2 * math.pi

local function facing_lines()
	local npcs = settlement_npcs()
	local checked = 0
	for index = 1, #npcs do
		local entity = npcs[index]
		local socket = socket_by_id[entity._grug_socket or ""]
		-- QUEST SOCKETS ONLY, and that is not a convenience: an elder is the one
		-- family with no movement at all, so its yaw is the authored rule and
		-- nothing else. A villager faces whichever idle spot it is standing at
		-- and a guard faces its post only while it is on it, so neither is a
		-- statement about the door rule at an arbitrary second.
		if socket and socket.role == "quest" and entity.object then
			local tag = socket.tags and socket.tags[1] or "-"
			local want = socket.yaw
			if tag == "door" then want = (want + math.pi) % TWO_PI end
			local have = entity.object:get_yaw() % TWO_PI
			local delta = math.abs((have - (want % TWO_PI) + math.pi) %
				TWO_PI - math.pi)
			log({"event=facing", "socket=" .. socket.id,
				"role=" .. socket.role, "tag=" .. tag,
				"authored=" .. string.format("%.3f", socket.yaw % TWO_PI),
				"want=" .. string.format("%.3f", want % TWO_PI),
				"have=" .. string.format("%.3f", have),
				"delta=" .. string.format("%.3f", delta)})
			if delta > 0.01 then
				fail("socket " .. socket.id .. " is faced " ..
					string.format("%.3f", delta) .. " rad away from its rule")
			end
			checked = checked + 1
		end
	end
	if checked < 1 then fail("no facing could be checked") end
end

--
-- WORK RESIDENTS (playtest round 3, contract sections 8.1 and 8.2). What only
-- the engine can answer: the socket really produced a resident, it is standing
-- ON the socket rather than somewhere near it, mobs_redo really put the
-- activity's animation on the object, and it is holding the activity's tool.
--
-- `animation_current` is mobs_redo's own record of what it last wrote
-- (api.lua:464) and `_grug_wield_item` is grug_visuals' record of what the
-- attached wielditem entity is showing, so both are read off the entity rather
-- than guessed from the definition.
--
local function work_lines(tag)
	local npcs = settlement_npcs()
	local seen = 0
	for index = 1, #npcs do
		local entity = npcs[index]
		if entity._grug_socket_role == "work" then
			seen = seen + 1
			local socket = socket_by_id[entity._grug_socket or ""]
			local pos = entity.object and entity.object:get_pos()
			local drift = -1
			if pos and socket then
				local dx = pos.x - socket.pos.x
				local dz = pos.z - socket.pos.z
				drift = math.sqrt(dx * dx + dz * dz)
			end
			log({"event=work", "phase=" .. tag,
				"socket=" .. tostring(entity._grug_socket),
				"activity=" .. tostring(entity._grug_work_activity),
				"anim=" .. tostring(entity.animation_current),
				"item=" .. tostring(entity._grug_wield_item),
				"walker=" .. tostring(entity._grug_walker),
				"ring=" .. tostring(entity._grug_idle_spots and
					#entity._grug_idle_spots or "none"),
				"drift=" .. string.format("%.2f", drift)})
			if entity._grug_work_activity == nil then
				fail("the resident on work socket " ..
					tostring(entity._grug_socket) .. " has no activity")
			end
			if entity._grug_idle_spots ~= nil then
				fail("the resident on work socket " ..
					tostring(entity._grug_socket) .. " was handed a wander ring")
			end
			-- A work resident never leaves its socket. One node of slack for
			-- the collision-box lift `place_on_ground` applies and for the
			-- engine's own settling.
			if drift < 0 or drift > 1.5 then
				fail("the resident on work socket " ..
					tostring(entity._grug_socket) .. " is " ..
					string.format("%.2f", drift) .. " nodes off it")
			end
		end
	end
	if seen < 1 then
		fail("the settlement placed nobody on a work socket")
	end
end

--
-- THE NAMETAG PROXIMITY GATE (the user's second round-3 finding). A villager,
-- an elder and a vendor used to write a static nametag property once, and the
-- engine has no distance cull of its own -- so their names rendered out to the
-- ~128 m object-send range while a guard's disappeared at thirty.
--
-- WHAT IS MEASURED HERE IS THE PROPERTY, on the real object: empty at 40 m,
-- the name at 20 m, and back to empty at 40 m. What is SUBSTITUTED is the
-- distance source: a headless server has no client to connect and therefore no
-- connected player, so `grug_mobs.nearest_player_d2` -- which the gate calls
-- through the table for exactly this reason -- is swapped for a constant while
-- the three ticks run and put back afterwards. Everything else, including the
-- hysteresis and the single write per flip, is the shipped code.
--
local function tag_gate_lines()
	local npcs = settlement_npcs()
	local subjects = {}
	for index = 1, #npcs do
		local entity = npcs[index]
		local family
		if entity.name:find("villager", 1, true) then family = "villager"
		elseif entity.name:find("elder", 1, true) then family = "elder"
		elseif entity.name:find("vendor", 1, true) then family = "vendor" end
		if family and not subjects[family] then subjects[family] = entity end
	end
	local order = {"villager", "elder", "vendor"}
	for _, family in ipairs(order) do
		if not subjects[family] then
			fail("no " .. family .. " to measure the nametag gate on")
			return
		end
	end
	local real = grug_mobs.nearest_player_d2
	local function at_distance(metres)
		grug_mobs.nearest_player_d2 = function() return metres * metres end
		for _, family in ipairs(order) do
			local entity = subjects[family]
			-- One second of the entity's OWN tick, which is where every one of
			-- the three families reaches the gate.
			if entity.do_custom then entity:do_custom(1) end
		end
	end
	local function read(metres, phase)
		local ok = true
		for _, family in ipairs(order) do
			local entity = subjects[family]
			local props = entity.object and entity.object:get_properties()
			local shown = props and props.nametag or ""
			local want = entity._grug_tag_want or "?"
			log({"event=tag", "phase=" .. phase, "family=" .. family,
				"metres=" .. metres, "want=" .. tostring(want),
				"shown=" .. (shown == "" and "-" or shown)})
			if phase == "near" and shown ~= want then
				fail("the " .. family .. " shows no nametag at " .. metres ..
					" m")
				ok = false
			elseif phase ~= "near" and shown ~= "" then
				fail("the " .. family .. " still shows a nametag at " ..
					metres .. " m")
				ok = false
			end
		end
		return ok
	end
	at_distance(40)
	read(40, "far")
	at_distance(20)
	read(20, "near")
	at_distance(40)
	read(40, "far_again")
	grug_mobs.nearest_player_d2 = real
end

--
-- PROFESSION VENDORS (contract section 8.4). The six starts carry no
-- profession socket -- the Highcourt fill lane places those -- so what the
-- engine can say here is that the five entities exist and that their shelves
-- survived the load-time audit with something on them. A shelf that lost every
-- offer to an unregistered item is a shopkeeper with an empty counter.
--
local function profession_lines()
	local kinds = {"butcher", "smith", "fishmonger", "baker", "tailor"}
	for _, kind in ipairs(kinds) do
		local name = "grug_traders:vendor_" .. kind
		local vendor = grug_traders.get_vendor(name)
		local shelf = grug_traders.profession_stock[kind]
		log({"event=profession", "kind=" .. kind,
			"entity=" .. tostring(core.registered_entities[name] ~= nil),
			"nametag=" .. tostring(vendor and vendor.nametag),
			"offers=" .. tostring(shelf and #shelf),
			"brackets=" .. tostring(vendor and vendor.brackets == true)})
		if not core.registered_entities[name] then
			fail("no entity for the profession vendor " .. kind)
		end
		if not shelf or #shelf < 1 then
			fail("the " .. kind .. " shelf is empty")
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
-- R4 in the engine (playtest round 2, the user's ruling). One wolf beside a
-- villager and one beside a guard post:
--   * the wolf keeps its own `attack_npcs` -- round 1 forced it to false for
--     every mob in the game, which also removed the only NPC-vs-monster fight
--     the settlements have -- so the pair at the gate ENGAGES EACH OTHER;
--   * neither wolf may ever acquire a NON-COMBATANT (`_grug_noncombatant` on
--     the villager, the elder and the vendor, vetoed in general_attack's
--     candidate filter) -- that is the boar standing in front of an
--     invulnerable villager the playtest found, and the fight that can never
--     end because a civilian cancels every punch;
--   * a guard still acquires the wolf (`attack_monsters` is untouched);
--   * and the wolf still hits back once the guard hits it, because on_punch's
--     retaliation (api.lua:3208-3213) reads `passive`, `state`, `child` and
--     ownership and never any `attack_*` field.
--
local HOSTILE = "grug_mobs:wolf"
local hostiles = {}
local cleared_socket
local unloaded_socket, unloaded_home, unloaded_away
-- THE POSITION ACTUALLY FORCELOADED, kept apart from `unloaded_away`, whose y is
-- later overwritten with the ground the probe measures. Those two can be five
-- mapblocks apart, and `forceload_free_block` frees the block containing the
-- position it is handed: freeing the measured one would release a block nobody
-- requested and leak the one that was.
local unloaded_request
-- Did the unload case get as far as a real NPC on real ground? Everything after
-- the move is meaningless otherwise, so it is skipped rather than run against a
-- stale position.
local unload_ready = false

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

-- Did the guard-side pair ever hold each other as a target? Either direction
-- counts: the ruling is that they MAY fight, and which of the two saw the other
-- first is a matter of a tick.
local engaged_hostile, engaged_guard = false, false

-- Is this target a non-combatant? Asked of the entity, which is where the flag
-- lives, and not of a name list -- a name list is exactly what a new civilian
-- family would be missing from.
local function target_is_civilian(target)
	if not target or core.is_player(target) then return false end
	local entity = target:get_luaentity()
	return grug_mobs.is_noncombatant(entity)
end

local function hostile_lines(tag)
	for index = 1, #hostiles do
		local row = hostiles[index]
		local entity = row.object:get_luaentity()
		if not entity then
			log({"event=hostile", "phase=" .. tag, "at=" .. row.label,
				"state=gone"})
		else
			local target = target_name(entity.attack)
			log({"event=hostile", "phase=" .. tag, "at=" .. row.label,
				"attack_npcs=" .. tostring(entity.attack_npcs),
				"attack_players=" .. tostring(entity.attack_players),
				"noncombatant=" .. tostring(entity._grug_noncombatant),
				"state=" .. tostring(entity.state),
				"target=" .. target,
				"health=" .. tostring(entity.health)})
			-- R4a. A hostile keeps its own targeting: round 1's blanket veto is
			-- gone, so this must not read false any more.
			if entity.attack_npcs == false then
				fail("a hostile still carries attack_npcs = false, so it can " ..
					"never fight the watch")
			end
			-- R4b. And it may never hold a civilian, by flag and not by name.
			if target_is_civilian(entity.attack) then
				fail("a hostile mob acquired a non-combatant settlement NPC (" ..
					target .. ")")
			end
			if target:find("guard", 1, true) then engaged_hostile = true end
		end
	end
	local npcs = settlement_npcs()
	for index = 1, #npcs do
		local entity = npcs[index]
		if entity.name:find("guard", 1, true) then
			local target = target_name(entity.attack)
			log({"event=guard_target", "phase=" .. tag,
				"socket=" .. tostring(entity._grug_socket),
				"state=" .. tostring(entity.state),
				"target=" .. target})
			if target ~= "nil" then engaged_guard = true end
		end
		-- R4c. NOTHING in the settlement holds a civilian as its target, which
		-- covers the guards and every other mob this scan reaches, not only the
		-- two wolves the probe placed.
		if target_is_civilian(entity.attack) then
			fail(entity.name .. " acquired a non-combatant settlement NPC")
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
	{at = 10, what = function()
		positions_line()
		-- R3, as early as the roster is activated: an elder placed on a
		-- door-tagged socket looks at the street.
		facing_lines()
	end},
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
		-- R2's verdict over the whole 170-second window.
		wander_verdict()
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
		-- One heartbeat later: every marker still standing and one NPC fewer,
		-- because three passes have to agree before a marker is freed. The one
		-- phase whose whole point is a count OTHER than the roster, hence not
		-- strict -- and the count is ROSTER MINUS ONE rather than a literal,
		-- because the roster grows whenever a composition gains a socket (round
		-- 3 added two `work` sockets per start and this read 8 against 10).
		local live, roster = census_line("one_strike")
		if live ~= roster - 1 then
			fail("the cleared villager is still counted: live=" .. live ..
				" of a roster of " .. roster)
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
	-- Playtest round 3, all before the wolves arrive: a fight moves people.
	{at = 296, what = function() work_lines("fresh") end},
	{at = 297, what = tag_gate_lines},
	{at = 298, what = profession_lines},
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
		-- R4's verdict: the gate pair really did engage, in at least one
		-- direction. A guard that killed its wolf outright still counts -- it
		-- held it as a target on the way there, which every earlier phase logged.
		log({"event=engagement", "hostile_held_guard=" ..
			tostring(engaged_hostile), "guard_held_target=" ..
			tostring(engaged_guard)})
		if not (engaged_hostile or engaged_guard) then
			fail("the hostile beside the gate and the watch never engaged")
		end
		-- NOT strict: a wolf that kills a guard frees that socket with a
		-- respawn slot, which is world.md §4a working rather than a defect. The
		-- invariant that must hold either way is that every marked socket has
		-- its NPC and nothing else stands around.
		local live, roster, marked = census_line("after_fight")
		if live ~= marked then
			fail("after the fight live=" .. live .. " differs from marked=" ..
				marked .. " (roster " .. roster .. ")")
		end
	end},
	--
	-- THE REVIEW'S FINDING, in the engine. One NPC is put OUTSIDE the forceloaded
	-- grid, so its own mapblock goes inactive while the socket it is booked on
	-- stays active: `compare_block_status` answers for the block containing the
	-- position it is handed, and the two positions are different blocks. The NPC
	-- is then not in the environment at all, and the marker must survive that --
	-- it is unloaded, not gone -- and the NPC must come back when its block does.
	--
	-- THE DESTINATION IS PREPARED FIRST, and round 2 had to learn why. The first
	-- version teleported the NPC to `its own position + 128` and hoped. That
	-- volume is 150-odd nodes from the anchor, i.e. outside everything the
	-- preload and this probe's own grid ever generated, so where the NPC landed
	-- was whatever the map had there: sometimes generated ground (the case
	-- passed), sometimes nothing at all -- and an object moved into a block that
	-- does not exist is not unloaded, it is LOST. Two runs of this round proved
	-- exactly that: the block read `active=true loaded=true` at the check and the
	-- NPC was still missing, and the NEXT boot then freed the marker and placed a
	-- replacement, which is the engine telling us the object was gone rather than
	-- asleep.
	--
	-- So the away point is now a FIXED offset from the anchor (deterministic
	-- across runs, unlike a wandering villager's position), the block is
	-- forceloaded -- which generates it -- before anything is moved there, and
	-- the NPC is put on the ground the probe actually reads out of that column.
	-- Only then is the forceload released, which is what makes the block go
	-- inactive and is the state under test.
	--
	{at = 342, what = function()
		-- Generate and load the destination. Eight seconds ahead of the move, so
		-- the emerge has time even on a cold map. This exact position is what
		-- gets freed again below -- not the measured ground, which may be in
		-- another block.
		unloaded_request = {x = settlement.anchor.x + FORCE_REACH * 2,
			y = settlement.anchor.y, z = settlement.anchor.z}
		log({"event=away_request",
			"to=" .. core.pos_to_string(unloaded_request),
			"ok=" .. tostring(core.forceload_block(unloaded_request, true, -1))})
	end},
	{at = 350, what = function()
		-- The ground of that column, read rather than assumed: the first air
		-- node with air above it that stands on something walkable. Searched
		-- from well above the anchor down to well below it, which is the whole
		-- range mgv7 can put a surface in around a start.
		local ground
		for y = settlement.anchor.y + 40, settlement.anchor.y - 40, -1 do
			local here = core.get_node_or_nil(
				{x = unloaded_request.x, y = y, z = unloaded_request.z})
			local over = core.get_node_or_nil(
				{x = unloaded_request.x, y = y + 1, z = unloaded_request.z})
			local under = core.get_node_or_nil(
				{x = unloaded_request.x, y = y - 1, z = unloaded_request.z})
			if here and over and under and here.name == "air" and
					over.name == "air" and under.name ~= "air" and
					under.name ~= "ignore" then
				ground = y
				break
			end
		end
		-- NO GROUND IS THE END OF THE CASE, not a reason to carry on with a
		-- position nothing was measured at. The block that WAS requested is
		-- released so the run leaks nothing, the failure is logged (which is what
		-- makes the whole probe run fail), and every later step of this case
		-- skips on `unload_ready`.
		if not ground then
			core.forceload_free_block(unloaded_request, true)
			fail("the away column never loaded or has no ground at " ..
				core.pos_to_string(unloaded_request))
			log({"event=unload_aborted",
				"at=" .. core.pos_to_string(unloaded_request)})
			return
		end
		unloaded_away = {x = unloaded_request.x, y = ground,
			z = unloaded_request.z}
		local npcs = settlement_npcs()
		for index = 1, #npcs do
			local entity = npcs[index]
			if entity.name:find("villager", 1, true) then
				local pos = entity.object:get_pos()
				unloaded_socket = entity._grug_socket
				unloaded_home = {x = pos.x, y = pos.y, z = pos.z}
				entity.object:set_pos(unloaded_away)
				-- AND RELEASE THE BLOCK THAT WAS REQUESTED. Holding it would
				-- keep the NPC active, which is the opposite of the case under
				-- test; freeing `unloaded_away` instead would free a block that
				-- was never forceloaded and leak this one.
				core.forceload_free_block(unloaded_request, true)
				unload_ready = true
				log({"event=unload", "socket=" .. tostring(unloaded_socket),
					"to=" .. core.pos_to_string(unloaded_away),
					"requested=" .. core.pos_to_string(unloaded_request),
					"socket_block_active=" .. tostring(
						core.compare_block_status(
							{x = pos.x, y = pos.y, z = pos.z}, "active")),
					"npc_block_active=" .. tostring(
						core.compare_block_status(unloaded_away, "active"))})
				return
			end
		end
		core.forceload_free_block(unloaded_request, true)
		fail("no villager to unload")
		log({"event=unload_aborted", "at=no_villager"})
	end},
	{at = 360, what = function()
		if not unload_ready then return end
		-- Eight of nine, and still nine markers: this is the count that must NOT
		-- become nine again by a fresh NPC being placed on the marked socket.
		census_line("unloaded", false, roster_size() - 1)
	end},
	{at = 385, what = function()
		if not unload_ready then return end
		census_line("still_unloaded", false, roster_size() - 1)
	end},
	{at = 390, what = function()
		if not unload_ready then return end
		-- And it comes back when its block does, which is the other half of the
		-- same claim. THE NPC's OWN block this time, which is the one that has
		-- to go active for the object to be in the environment again.
		log({"event=reload_request", "ok=" ..
			tostring(core.forceload_block(unloaded_away, true, -1)),
			"active=" .. tostring(
				core.compare_block_status(unloaded_away, "active"))})
	end},
	{at = 400, what = function()
		if not unload_ready then return end
		-- One intermediate reading, for the same reason the strike rule needs
		-- three passes: a forceload is a REQUEST. `ActiveBlockList::update`
		-- runs on `active_block_mgmt_interval` (2 s by default) and the block
		-- itself has to come off the disk first, so "the object is back" is not
		-- a thing that happens in the same step. If the check below ever fails,
		-- this line says whether the block was the problem or the object.
		log({"event=reload_wait", "active=" .. tostring(
			core.compare_block_status(unloaded_away, "active")),
			"loaded=" .. tostring(
				core.compare_block_status(unloaded_away, "loaded"))})
	end},
	--
	-- TWENTY-FIVE SECONDS after the forceload, not six. Six was a coin toss: the
	-- engine has to read the mapblock off the disk and then wait for its own
	-- active-block management interval before the objects in it are in the
	-- environment at all, and neither is bounded by anything the probe controls.
	-- Nothing else in the programme depends on this delay, and the claim under
	-- test is a statement about what happens, not about how fast.
	--
	{at = 415, what = function()
		if not unload_ready then
			log({"event=complete", "programme=full"})
			core.request_shutdown("wp13 npc probe done", false, 1)
			return
		end
		-- Back where it belongs FIRST: twice the grid's reach is also outside
		-- the settlement's own scan radius, and the two reboots should start
		-- from the ordinary world rather than from this experiment.
		local back = false
		local npcs = settlement_npcs()
		for index = 1, #npcs do
			if npcs[index]._grug_socket == unloaded_socket then
				npcs[index].object:set_pos(unloaded_home)
				back = true
			end
		end
		log({"event=reload_seen", "back=" .. tostring(back),
			"active=" .. tostring(
				core.compare_block_status(unloaded_away, "active"))})
		core.forceload_free_block(unloaded_away, true)
		if not back then
			fail("the unloaded NPC did not come back with its mapblock")
		end
		local live = census_line("reloaded_npc", true)
		log({"event=unload_done", "socket=" .. tostring(unloaded_socket),
			"live=" .. live})
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
		-- A work resident has to come back onto its socket with its activity
		-- and its tool: the activity is a plain field in staticdata and the
		-- animation and the wield entity are re-applied on activation, which is
		-- exactly the kind of thing only a reboot proves.
		work_lines("reloaded")
		-- R3 again: mob_activate hands every mob a random yaw, so the authored
		-- facing has to be re-asserted on every activation. A reboot is the only
		-- thing that proves it.
		facing_lines()
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
	-- R2's sampler, every second of the amble window (boot 1 only; the reload
	-- boots are twenty seconds long and prove something else).
	if BOOT == 1 and clock <= 170 then sample_spots() end
	while next_step <= #programme and programme[next_step].at <= clock do
		local job = programme[next_step]
		next_step = next_step + 1
		job.what()
	end
end)
