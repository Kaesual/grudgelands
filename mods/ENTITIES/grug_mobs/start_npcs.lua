--
-- The settlements' NPC roster: one socket-driven placement engine
-- (docs/design/settlements.md "Settlement NPCs";
-- docs/research/wp13-npc-sockets-contract.md sections 3 and 4).
--
-- WHAT STANDS WHERE comes entirely out of the `grug_core` socket registry, so
-- moving a guard post is a blueprint edit and nothing here changes:
--   guard_post    a faction guard holding an authored post
--   guard_patrol  ONE guard per LOOP, walking that loop's waypoints
--   idle          flair villagers (start_villagers.lua)
--   quest         the quest shell (start_villagers.lua)
--   vendor        resolved by grug_traders, which owns vendors
--   king          nothing yet (the encounter is a later work package)
--   waypoint      nothing (WP17's travel pad)
--
-- IT SERVES EVERY REGISTERED SETTLEMENT, not only the six starts. A capital
-- registers under its own key when its core lands, and three things about a
-- capital are different from a start; everything else is the same code:
--
--   1. WHEN. A start is placed when `grug_core.start_ready(race)` reports its
--      128 x 128 envelope prepared, which the server does at startup. Capitals
--      are NOT preloaded, so a capital is placed the first time its area is
--      actually emerged or loaded -- the anchor's own node answering at all is
--      the gate -- and its far plots follow on the heartbeat as a player walks
--      up to them. Nothing waits for the whole 512 envelope: `serve` already
--      skips a socket whose node is not loaded and keeps it pending.
--   2. HOW MANY LOOPS. A start has one patrol loop. Highcourt's core has five
--      (the city ring and one per gate tower) and its district one more, so a
--      waypoint's `group` is what decides which loop it belongs to, and each
--      loop carries its own guard, booked on its own first waypoint.
--   3. HOW FAR A VILLAGER WANDERS. A capital's idle spots are spread over 300
--      nodes, and one villager walking between all of them is not flair. The
--      spots are grouped by the composition they came from -- the registry
--      prefixes a district plot's socket ids with the plot id -- so a villager
--      wanders its own plot or the core, never the whole city.
--
-- WHY A REGISTRY-DRIVEN WATCH AND NOT A GUARD BANNER PLUS camps.lua
-- (the choice the work package asked to make, and the reasons it went this
-- way -- all four are blocking, not aesthetic):
--
--   1. A banner is a CELL. Every blueprint cell is an identity byte
--      (`r7_settlement.lua` hashes schema, bounds, palette and cells), so six
--      banners would move six frozen settlement identities, the R7 manifest
--      SHA and every piece of engine evidence recorded against them. Sockets
--      are landmarks and move none of it. `tools/wp13/blueprint_kat.lua` even
--      refuses a `grug_nodes:guard_banner` cell outright ("decorative
--      spawner") -- the blueprint side is closed by assertion.
--   2. camps.lua places its members at a RANDOM free spot in a radius
--      (`free_spot_near`). A start guard has an authored post and an authored
--      facing; "somewhere within 15 nodes of the banner, looking anywhere" is
--      not that, and teaching the camp mechanism exact positions plus facings
--      would be a second placement engine inside it.
--   3. The camp patrol route comes from `grug_core.outpost_at` /
--      `outpost_patrol_target`, i.e. the 24 authenticated OUTPOST anchors. A
--      start is not an outpost, so a banner there gets no route at all
--      (`assign_patrol` returns early) and the authored 4..6 waypoint loop
--      would have no way in.
--   4. A banner is written by mapgen, so it would drag the whole WP13 engine
--      gate (`tools/wp13/run_engine.sh`, four worlds, two seeds) behind every
--      NPC change. Nothing here touches what the mapgen writes.
--
-- What IS reused from the camp mechanism is its MODEL: world.md section 4a's
-- respawn slots. One slot per guard socket, refilled 180-360 s after that
-- guard dies, and a dormant settlement's owed refill is simply late, never
-- lost -- the same rhythm camps.lua gives an outpost.
--
-- PERSISTENCE AND IDEMPOTENCE: one mod-storage marker per socket.
--
--   A marker is set the moment an NPC is placed at its socket and cleared
--   only by that NPC's death. So a restart places nothing: the entities came
--   back with their mapblocks (all five families are `type = "npc"`, which
--   mobs_redo never expires or unloads away -- see start_villagers.lua and
--   vendors.lua for the api.lua evidence), and the markers say so.
--
--   The alternative -- decide by scanning for an existing entity near the
--   socket -- cannot be used as the primary gate here, and the reason is the
--   engine, not taste: `core.get_objects_inside_radius` only ever sees
--   ACTIVATED objects, and a mapblock is activated by a player being near it,
--   not by being loaded. Placement runs when `grug_core.start_ready(race)`
--   reports the area prepared, which is exactly when the blocks are loaded
--   and no player is anywhere near them, so on the second boot that scan
--   would find nothing at all and duplicate the entire roster -- forever,
--   because npc entities never expire. vendors.lua avoids that by only ever
--   looking at slots within 24 nodes of a player; a start roster that may
--   only appear once a player walks up cannot be placed at start-ready at
--   all.
--
--   The scan is still used, as a SECOND gate before every placement: if the
--   marker is missing but the entity BOOKED ON THAT SOCKET is standing there
--   anyway (a marker lost to an admin edit), the marker is restored instead of
--   a twin being spawned. It matches the socket and not just the entity name,
--   for the reason written at `socket_occupied`.
--
--   Guards are the one family that must come back after a death, so their
--   marker is cleared from `on_die` together with a due time; nothing else
--   here is mortal (every other family cancels every punch).
--
--   AND A MARKER IS NEVER LEFT STANDING ALONE. `on_die` is reached only from
--   `check_for_death` (api.lua:870-876), so it is not the only way an entity
--   can leave: `/clearobjects`, the `mob_active_limit` removal inside
--   `mob_activate` (api.lua:3311-3314) and a shutdown between the mod-storage
--   flush and the map flush all end with a marker and no NPC, and without a
--   re-check that socket would stay empty for the life of the world. So the
--   heartbeat pass -- the one where a player IS near, which is the only state
--   in which the scan can answer at all -- also frees a marked socket that has
--   nothing standing on it. That is the exact mirror of the second gate.
--
-- WHY `core.add_entity` AND NOT `grug_mobs.add_mob`: `mobs:add_mob` refuses
-- whenever no player is inside the active area (api.lua:3885-3890,
-- `count_mobs` -> `is_pla`) because it is the ABM spawner's own gate. Authored
-- settlement content decides its own position -- the same rule the start
-- footprint refusal states for camps, guards and rares -- and the whole point
-- of placing at start-ready is that the prepared area has no player in it.
-- The collision-box lift `add_mob` performs is kept (`place_on_ground`).
--

local storage = grug_mobs.storage

-- The placement retry heartbeat, and how close a player has to be for a
-- retry. PLAYER_RANGE is vendors.lua's 24 and for its documented reason: the
-- presence scan below only sees activated objects, and activation reaches
-- `active_block_range * 16` nodes, which is 32 in the smallest shipped
-- platform profile. 24 + PRESENCE_RADIUS 8 = 32 keeps the scan honest there.
local PLACE_INTERVAL = 5
local PLAYER_RANGE = 24
local PRESENCE_RADIUS = 8
-- One guard respawn slot, world.md section 4a's guard rhythm (the same
-- GUARD_RESPAWN_MIN/MAX camps.lua uses for an outpost picket).
local RESPAWN_MIN, RESPAWN_MAX = 180, 360
-- The post tick: once a second, like every other ambient movement here, and
-- two nodes of slack so a nudged guard is not permanently walking home.
local POST_TICK = 1
local POST_SLACK = 2

--
-- Role resolvers. A role with no resolver is a socket nobody stands on
-- (`king`, `waypoint`), which is not an error.
--
-- resolver(socket, start) -> entity name, or nil
--   socket — the world-space socket copy from grug_core
--   start  — {race_id, faction_id, key, anchor}
--
local resolvers = {}

function grug_mobs.register_start_socket_role(role, resolver)
	if type(role) ~= "string" or role == "" or type(resolver) ~= "function" then
		error("grug_mobs.register_start_socket_role: arguments differ", 0)
	end
	if resolvers[role] then
		error("grug_mobs.register_start_socket_role: " .. role ..
			" is already owned", 0)
	end
	resolvers[role] = resolver
end

grug_mobs.register_start_socket_role("guard_post", function(socket, start)
	return "grug_mobs:guard_" .. start.faction_id
end)
grug_mobs.register_start_socket_role("guard_patrol", function(socket, start)
	return "grug_mobs:guard_" .. start.faction_id
end)
grug_mobs.register_start_socket_role("idle", function(socket, start)
	return "grug_mobs:villager_" .. start.race_id
end)
grug_mobs.register_start_socket_role("quest", function(socket, start)
	return "grug_mobs:elder_" .. start.race_id
end)

--
-- State
--

-- One row per registered settlement; `slots` are the sockets something stands
-- on. Keyed by the settlement key, which is the unique identity (a race id is
-- not: it has a start and a capital).
local rows = {}
local by_key = {}

-- Which log family a role reports under.
local FAMILY = {guard_post = "guards", guard_patrol = "guards",
	idle = "flair", vendor = "vendor", quest = "quest"}
local FAMILY_ORDER = {"guards", "flair", "vendor", "quest"}

-- The marker is keyed by the SETTLEMENT KEY, not the race: every race has a
-- start and a capital, so a race is not a unique settlement (the sockets
-- contract's own rule) and two settlements of one race would otherwise share
-- one marker for every socket id they happen to share.
local function placed_key(settlement_key, socket_id)
	return "startnpc:" .. settlement_key .. ":" .. socket_id
end

local function due_key(settlement_key, socket_id)
	return "startnpcdue:" .. settlement_key .. ":" .. socket_id
end

local function mark_placed(row, slot)
	slot.placed = true
	slot.due = nil
	storage:set_string(placed_key(row.key, slot.id), "1")
	storage:set_string(due_key(row.key, slot.id), "")
	row.pending = row.pending - 1
	row.placed_count[slot.family] = row.placed_count[slot.family] + 1
end

-- The marker outlived its NPC: free the socket and queue it again. `due` is
-- what a DEATH books (a respawn slot); an entity that simply is not there any
-- more is refilled at once, because nothing was earned by its absence.
local function mark_free(row, slot, due)
	slot.placed = false
	slot.due = due
	storage:set_string(placed_key(row.key, slot.id), "")
	storage:set_string(due_key(row.key, slot.id), due and tostring(due) or "")
	row.pending = row.pending + 1
	row.placed_count[slot.family] = row.placed_count[slot.family] - 1
end

--
-- Row construction (after every mod has loaded, so grug_traders has claimed
-- the `vendor` role and every entity is registered).
--

-- Which composition a socket belongs to. The registry prefixes a district
-- plot's socket ids with the plot id and a slash (`r7_settlement.M.sockets`),
-- so the part before the first slash is the composition, and a socket with no
-- slash belongs to the settlement's own core or pad.
local function composition_of(socket_id)
	return socket_id:match("^([^/]+)/") or "-"
end

-- Is this settlement a race's START or its CAPITAL? The registry is keyed by
-- settlement and carries the fitted anchor it compiled against; grug_core
-- publishes both authoritative anchors for a race, so the anchor is what
-- answers, and nothing here has to restate a roster or trust a naming
-- convention.
local function settlement_kind(record, faction_id)
	local function same(published)
		return type(published) == "table" and published.x == record.anchor.x and
			published.y == record.anchor.y and published.z == record.anchor.z
	end
	if same(grug_core.start_anchor(faction_id, record.race_id)) then
		return "start"
	end
	if same(grug_core.capital_anchor(faction_id, record.race_id)) then
		return "capital"
	end
	return nil
end

local function build_rows()
	local identities = grug_core.start_identities()
	local faction_of = {}
	for index = 1, #identities do
		faction_of[identities[index].race_id] = identities[index].faction_id
	end
	local settlements = grug_core.settlement_socket_settlements()
	for index = 1, #settlements do
		local record = settlements[index]
		local faction_id = faction_of[record.race_id]
		local sockets = grug_core.settlement_sockets_at(record.key)
		-- The registry compiled its world positions against the anchor the
		-- settlement WRITER uses; the preload, the arrival and the capital
		-- authority use the ones the consumer payload publishes. They are the
		-- same anchor, and if they ever were not, every NPC in this settlement
		-- would stand at a different height from the buildings -- so the kind is
		-- DECIDED by that comparison, once per settlement at load, and a
		-- settlement that matches neither published anchor is a defect rather
		-- than a settlement placed against a guess.
		local kind = faction_id and settlement_kind(record, faction_id) or nil
		if not faction_id then
			core.log("error", "[grug_mobs] settlement npcs: no faction for race " ..
				record.race_id)
		elseif not kind then
			core.log("error", "[grug_mobs] settlement npcs: " .. record.key ..
				" socket anchor " .. core.pos_to_string(record.anchor) ..
				" is neither the published start nor the published capital anchor" ..
				" of " .. record.race_id)
		elseif #sockets == 0 then
			core.log("warning", "[grug_mobs] settlement npcs: " .. record.key ..
				" exports no socket")
		else
			local settlement = {race_id = record.race_id, faction_id = faction_id,
				key = record.key, kind = kind, anchor = record.anchor}
			local row = {race_id = record.race_id, faction_id = faction_id,
				key = record.key, kind = kind, anchor = record.anchor,
				slots = {}, by_socket = {}, pending = 0, idle_groups = {},
				patrols = {}, totals = {}, placed_count = {}}
			-- The patrol loops and the idle spots first: both are read by every
			-- entity the row places, so they are built before the slots. A loop
			-- is named by its waypoints' `group`, which is how a capital carries
			-- six of them without this file knowing there are six.
			local loops, loop_order = {}, {}
			for _, socket in ipairs(sockets) do
				if socket.role == "guard_patrol" then
					local loop = loops[socket.group]
					if not loop then
						loop = {by_order = {}, size = 0}
						loops[socket.group] = loop
						loop_order[#loop_order + 1] = socket.group
					end
					if loop.by_order[socket.order] then
						core.log("error", "[grug_mobs] settlement npcs: " .. record.key ..
							" repeats patrol order " .. socket.order .. " in loop " ..
							socket.group)
					end
					loop.by_order[socket.order] = socket
					if socket.order > loop.size then loop.size = socket.order end
				elseif socket.role == "idle" then
					local group = composition_of(socket.id)
					local spots = row.idle_groups[group]
					if not spots then
						spots = {}
						row.idle_groups[group] = spots
					end
					spots[#spots + 1] = {
						x = socket.pos.x, y = socket.pos.y, z = socket.pos.z,
						yaw = socket.yaw,
						tag = socket.tags and socket.tags[1] or nil,
					}
				end
			end
			for _, group in ipairs(loop_order) do
				local loop = loops[group]
				local points = {}
				for order = 1, loop.size do
					local socket = loop.by_order[order]
					if socket then
						points[#points + 1] = {x = socket.pos.x, z = socket.pos.z}
					end
				end
				row.patrols[group] = points
			end
			for family_index = 1, #FAMILY_ORDER do
				row.totals[FAMILY_ORDER[family_index]] = 0
				row.placed_count[FAMILY_ORDER[family_index]] = 0
			end
			local idle_index = {}
			for _, socket in ipairs(sockets) do
				local resolver = resolvers[socket.role]
				-- A patrol loop carries ONE guard, booked on its first
				-- waypoint; the rest of the loop is route data.
				local carries = resolver ~= nil and
					(socket.role ~= "guard_patrol" or socket.order == 1)
				if carries then
					local entity = resolver(socket, settlement)
					if type(entity) ~= "string" or
							not core.registered_entities[entity] then
						core.log("error", "[grug_mobs] settlement npcs: " ..
							record.key .. " socket " .. socket.id ..
							" resolves to no registered entity (" ..
							tostring(entity) .. ")")
					else
						local group = composition_of(socket.id)
						if socket.role == "idle" then
							idle_index[group] = (idle_index[group] or 0) + 1
						end
						local slot = {
							id = socket.id, role = socket.role, entity = entity,
							family = FAMILY[socket.role] or "flair",
							group = socket.group, composition = group,
							pos = {x = socket.pos.x, y = socket.pos.y,
								z = socket.pos.z},
							yaw = socket.yaw,
							tag = socket.tags and socket.tags[1] or nil,
							idle_index = socket.role == "idle" and idle_index[group] or nil,
							placed = storage:get_string(
								placed_key(record.key, socket.id)) == "1",
						}
						if not slot.placed then
							local due = tonumber(storage:get_string(
								due_key(record.key, socket.id)))
							slot.due = due
							row.pending = row.pending + 1
						end
						row.totals[slot.family] = row.totals[slot.family] + 1
						if slot.placed then
							row.placed_count[slot.family] =
								row.placed_count[slot.family] + 1
						end
						row.slots[#row.slots + 1] = slot
						row.by_socket[socket.id] = slot
					end
				end
			end
			rows[#rows + 1] = row
			by_key[row.key] = row
		end
	end
end

--
-- Placement
--

local function player_near(positions, pos)
	for index = 1, #positions do
		local player_pos = positions[index]
		local dx = player_pos.x - pos.x
		local dy = player_pos.y - pos.y
		local dz = player_pos.z - pos.z
		if dx * dx + dy * dy + dz * dz <= PLAYER_RANGE * PLAYER_RANGE then
			return true
		end
	end
	return false
end

-- Second gate only (see the header): an activated entity ALREADY BOOKED ON
-- THIS SOCKET means the marker was lost, not that a twin is wanted.
--
-- The match is the socket, not merely the entity name, and that is not a
-- refinement: a start's two gate posts are eight nodes apart and carry the
-- same faction guard, and the patrol loop's first waypoint sits on the same
-- road. A name-only scan inside PRESENCE_RADIUS therefore saw the guard of
-- the post NEXT DOOR, "restored" a marker nobody had lost and left that post
-- empty -- measured on the first headless boot, where Hearthpine came up with
-- one guard instead of three.
local function socket_occupied(row, slot)
	local objects = core.get_objects_inside_radius(slot.pos, PRESENCE_RADIUS)
	for index = 1, #objects do
		local entity = objects[index]:get_luaentity()
		-- The settlement KEY, which is what `install` writes: a race has a start
		-- and a capital, and comparing the race here would make every socket of
		-- both read as empty, free its marker and spawn a twin on every
		-- heartbeat.
		if entity and entity.name == slot.entity and
				entity._grug_start == row.key and
				entity._grug_socket == slot.id then
			return true
		end
	end
	return false
end

local function copy_spots(spots)
	local out = {}
	for index = 1, #spots do
		local spot = spots[index]
		out[index] = {x = spot.x, y = spot.y, z = spot.z, yaw = spot.yaw,
			tag = spot.tag}
	end
	return out
end

-- Every field installed here is a plain number, string or flat table, so it
-- survives unload/reload inside the mob's staticdata (AGENTS.md's WP6 rule:
-- never an ObjectRef, never a function).
local function install(entity, row, slot)
	-- The settlement KEY, not the race: `start_guard_died` looks the row up by
	-- it, and a race has two settlements. The field name is the one guard.lua
	-- already reads.
	entity._grug_start = row.key
	entity._grug_socket = slot.id
	-- The facing to re-assert on every activation: mob_activate hands every mob
	-- a random yaw (api.lua:3401), so an authored one has to be written back.
	-- The two families with a tick of their own do it there; the quest shell has
	-- none and restores it from `after_activate`.
	entity._grug_face_yaw = slot.yaw
	if slot.role == "guard_post" then
		-- `_grug_home` is where aggro.lua's evade runs a guard back to after a
		-- chase; the post fields are what guard.lua's tick holds it at while
		-- idle. Deliberately NO `_grug_camp_pos`: that field switches on
		-- aggro.lua's 20-node camp roam cap, which would be a second, looser
		-- owner of the same behaviour.
		entity._grug_home = {x = slot.pos.x, y = slot.pos.y, z = slot.pos.z}
		-- Horizontal only, like every other "am I where I belong" rule in this
		-- mod (aggro.lua's evade and its roam cap): a guard standing on the
		-- step above its post is not off it. The full position lives in
		-- `_grug_home`.
		entity._grug_post_x = slot.pos.x
		entity._grug_post_z = slot.pos.z
		entity._grug_post_yaw = slot.yaw
	elseif slot.role == "guard_patrol" then
		-- guard.lua's own tick walks `_grug_patrol_route` through
		-- `grug_mobs.route_tick`, and aggro.lua exempts a route carrier from
		-- both the leash and the roam cap -- being away from the post IS its
		-- job. Its own copy of the points, because `wp` lives in that table, and
		-- its OWN LOOP's points: a capital has one per gate tower besides the
		-- city ring, and mixing them would walk a guard off a wall walk.
		local loop = row.patrols[slot.group] or {}
		local points = {}
		for index = 1, #loop do
			points[index] = {x = loop[index].x, z = loop[index].z}
		end
		entity._grug_home = {x = slot.pos.x, y = slot.pos.y, z = slot.pos.z}
		entity._grug_patrol_route = {points = points, wp = 1}
	elseif slot.role == "idle" then
		-- Its own composition's spots, so a district villager keeps to its plot
		-- and a core villager to the core.
		entity._grug_idle_spots = copy_spots(row.idle_groups[slot.composition] or {})
		entity._grug_idle_spot = slot.idle_index
		entity._grug_idle_tag = slot.tag
	end
end

local function place(row, slot)
	local object = core.add_entity(slot.pos, slot.entity)
	if not object then return false end
	local entity = object:get_luaentity()
	if not entity then
		-- The engine took the position but the entity did not come up (a
		-- mobs_redo removal path). Nothing to configure and nothing to mark.
		return false
	end
	-- The ground correction mobs:add_mob skips (init.lua place_on_ground).
	grug_mobs.place_on_ground(object, slot.pos)
	install(entity, row, slot)
	grug_mobs.face_yaw(entity, slot.yaw)
	return true
end

-- One pass over a start. `positions` is nil for the start-ready pass, which
-- runs while the prepared area is loaded and deliberately has no player in
-- it; a heartbeat pass hands the player positions in and only looks at
-- sockets one of them is near.
--
-- THE MARKER IS NOT ALLOWED TO OUTLIVE ITS NPC, and `on_die` alone does not
-- guarantee that: it is reached only from `check_for_death` (api.lua:870-876),
-- so `/clearobjects`, the `mob_active_limit` removal inside `mob_activate`
-- (api.lua:3311-3314) and a shutdown between the mod-storage flush and the map
-- flush all leave a marker with nothing standing on it -- and that socket
-- would then never refill again for the life of the world. So a HEARTBEAT pass
-- also re-checks the sockets it can actually see, which is the exact mirror of
-- the second gate below: a player within PLAYER_RANGE is what makes the
-- mapblock active, which is what makes `socket_occupied` able to answer at all
-- (on the start-ready pass, where no player is near, it can not, which is why
-- that pass never frees anything).
-- Is this settlement's area prepared? A start has the preload's own answer; a
-- capital is not preloaded at all, so what says "the area exists now" is its
-- anchor column answering with a real node. `get_node_or_nil` is nil for an
-- unloaded block and "ignore" for a loaded but ungenerated one, and the anchor
-- of a capital always carries the guard banner the anchor writer put there, so
-- a generated capital cannot answer "air" by accident either.
local function settlement_ready(row)
	if row.kind == "start" then return grug_core.start_ready(row.race_id) end
	local node = core.get_node_or_nil(row.anchor)
	return node ~= nil and node.name ~= "ignore"
end

local function serve(row, positions)
	if not settlement_ready(row) then return 0, 0 end
	if row.pending <= 0 and not positions then return 0, 0 end
	local now = core.get_gametime()
	local new, freed = 0, 0
	for index = 1, #row.slots do
		local slot = row.slots[index]
		local near = not positions or player_near(positions, slot.pos)
		if slot.placed and positions and near then
			local node = core.get_node_or_nil(slot.pos)
			if node and node.name ~= "ignore" and not socket_occupied(row, slot) then
				core.log("warning", "[grug_mobs] start npcs " .. row.key ..
					": socket " .. slot.id .. " is marked but empty; " ..
					slot.entity .. " is gone and the slot is queued again")
				mark_free(row, slot, nil)
				freed = freed + 1
			end
		end
		if not slot.placed and (not slot.due or now >= slot.due) and near then
			local node = core.get_node_or_nil(slot.pos)
			if node and node.name ~= "ignore" then
				if socket_occupied(row, slot) then
					core.log("warning", "[grug_mobs] start npcs " .. row.key ..
						": " .. slot.entity .. " already stands at socket " ..
						slot.id .. " without a marker; marker restored")
					mark_placed(row, slot)
				elseif place(row, slot) then
					mark_placed(row, slot)
					new = new + 1
					core.log("action", "[grug_mobs] start npcs " .. row.key ..
						": " .. slot.entity .. " placed at socket " .. slot.id ..
						" " .. core.pos_to_string(slot.pos))
				end
			end
		end
	end
	return new, freed
end

-- The countable per-settlement line every engine boot is read from.
local function log_row(row, new)
	local parts = {}
	for index = 1, #FAMILY_ORDER do
		local family = FAMILY_ORDER[index]
		parts[#parts + 1] = family .. " " .. row.placed_count[family] .. "/" ..
			row.totals[family]
	end
	core.log("action", "[grug_mobs] start npcs " .. row.race_id .. " " ..
		row.key .. ": " .. table.concat(parts, " ") .. " new " .. new ..
		" pending " .. row.pending)
end

--
-- Triggers
--
-- 1. A settlement becomes ready. For a START that is the preload reporting its
--    whole 128 x 128 envelope loaded, so the roster is placed in one pass with
--    no player anywhere near it; this is also the pass whose log line proves a
--    restart places nothing. For a CAPITAL, which is never preloaded, it is the
--    first heartbeat that finds its anchor column loaded -- i.e. the first time
--    a player's arrival has actually emerged the place -- and the same
--    no-player pass then fills every socket whose own node is already loaded.
-- 2. The heartbeat: whatever the ready pass could not place (a node that was
--    not loaded after all, which for a capital is most of its district) plus
--    every guard respawn slot that has fallen due, for sockets a player is
--    standing near.
--

local ready_served = {}

local function serve_ready_settlements()
	for index = 1, #rows do
		local row = rows[index]
		if not ready_served[row.key] and settlement_ready(row) then
			ready_served[row.key] = true
			local new = serve(row, nil)
			log_row(row, new)
		end
	end
end

local accumulator = 0

core.register_globalstep(function(dtime)
	accumulator = accumulator + dtime
	if accumulator < PLACE_INTERVAL then return end
	accumulator = 0
	-- A settlement's area becoming available is not a question about players: a
	-- capital is emerged by whoever walks there, and equally by an admin's
	-- forceload or a headless probe. So the readiness pass runs on every
	-- heartbeat, BEFORE the player check, and the first pass over a freshly
	-- emerged capital is the no-player one that fills every socket already
	-- loaded. Only the per-socket retry work below needs a player near.
	serve_ready_settlements()
	local players = core.get_connected_players()
	if #players == 0 then return end
	local positions = {}
	for index = 1, #players do
		local pos = players[index]:get_pos()
		if pos then positions[#positions + 1] = pos end
	end
	if #positions == 0 then return end
	for index = 1, #rows do
		local row = rows[index]
		-- Every row, every heartbeat, and not only the ones with something
		-- pending: a full row is exactly where a marker without an NPC hides.
		local new, freed = serve(row, positions)
		if new > 0 or freed > 0 then log_row(row, new) end
	end
end)

core.register_on_mods_loaded(function()
	build_rows()
	-- The preload reports progress from a deferred job, never from inside an
	-- emerge callback (starts_preload.lua), so reacting here is safe; a start
	-- that was already ready before this registration is caught by the
	-- first-step sweep below.
	grug_core.register_on_starts_progress(function()
		serve_ready_settlements()
	end)
	core.after(0, serve_ready_settlements)
end)

--
-- The post guard's idle behaviour, called from guard.lua's own tick for the
-- guards that carry a post (an outpost guard carries none and keeps
-- aggro.lua's camp roam cap instead).
--
function grug_mobs.start_post_tick(self, dtime)
	self.temp = self.temp or {}
	local temp = self.temp
	temp.grug_post_acc = (temp.grug_post_acc or 0) + dtime
	if temp.grug_post_acc < POST_TICK then return end
	temp.grug_post_acc = 0
	-- Idle only: fighting, fleeing and flopping own the movement, and an
	-- evading guard is already running home on aggro.lua's stricter target.
	if self.attack or (self.state ~= "stand" and self.state ~= "walk") then
		return
	end
	if temp.grug_evading then return end
	local pos = self.object and self.object:get_pos()
	if not pos then return end
	local dx = self._grug_post_x - pos.x
	local dz = self._grug_post_z - pos.z
	if dx * dx + dz * dz > POST_SLACK * POST_SLACK then
		grug_mobs.walk_toward(self, self._grug_post_x, self._grug_post_z, pos)
		return
	end
	self.state = "stand"
	self:set_velocity(0)
	grug_mobs.face_yaw(self, self._grug_post_yaw or 0)
end

--
-- A start guard died: free its slot and book the refill (world.md section 4a
-- -- one slot, 180-360 s, and a settlement nobody is standing in simply gets
-- its guard back late rather than never).
--
function grug_mobs.start_guard_died(self)
	local row = by_key[self._grug_start]
	local slot = row and row.by_socket[self._grug_socket]
	if not slot or not slot.placed then return end
	mark_free(row, slot,
		core.get_gametime() + math.random(RESPAWN_MIN, RESPAWN_MAX))
	core.log("action", "[grug_mobs] start npcs " .. row.key .. ": socket " ..
		slot.id .. " lost its guard, refill due at " .. slot.due)
end
