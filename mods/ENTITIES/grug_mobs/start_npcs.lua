--
-- The start settlements' NPC roster: one socket-driven placement engine
-- (docs/design/settlements.md "Settlement NPCs";
-- docs/research/wp13-npc-sockets-contract.md sections 3 and 4).
--
-- WHAT STANDS WHERE comes entirely out of `grug_core.settlement_sockets`, so
-- moving a guard post is a blueprint edit and nothing here changes:
--   guard_post    2 per start -- a faction guard holding an authored post
--   guard_patrol  1 loop      -- ONE guard walking its 4..6 waypoints
--   idle          3-4         -- flair villagers (start_villagers.lua)
--   quest         1           -- the quest shell (start_villagers.lua)
--   vendor        1           -- resolved by grug_traders, which owns vendors
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

-- One row per start; `slots` are the sockets something stands on.
local rows = {}
local by_race = {}

-- Which log family a role reports under.
local FAMILY = {guard_post = "guards", guard_patrol = "guards",
	idle = "flair", vendor = "vendor", quest = "quest"}
local FAMILY_ORDER = {"guards", "flair", "vendor", "quest"}

local function placed_key(race_id, socket_id)
	return "startnpc:" .. race_id .. ":" .. socket_id
end

local function due_key(race_id, socket_id)
	return "startnpcdue:" .. race_id .. ":" .. socket_id
end

local function mark_placed(row, slot)
	slot.placed = true
	slot.due = nil
	storage:set_string(placed_key(row.race_id, slot.id), "1")
	storage:set_string(due_key(row.race_id, slot.id), "")
	row.pending = row.pending - 1
	row.placed_count[slot.family] = row.placed_count[slot.family] + 1
end

-- The marker outlived its NPC: free the socket and queue it again. `due` is
-- what a DEATH books (a respawn slot); an entity that simply is not there any
-- more is refilled at once, because nothing was earned by its absence.
local function mark_free(row, slot, due)
	slot.placed = false
	slot.due = due
	storage:set_string(placed_key(row.race_id, slot.id), "")
	storage:set_string(due_key(row.race_id, slot.id), due and tostring(due) or "")
	row.pending = row.pending + 1
	row.placed_count[slot.family] = row.placed_count[slot.family] - 1
end

--
-- Row construction (after every mod has loaded, so grug_traders has claimed
-- the `vendor` role and every entity is registered).
--

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
		local sockets = grug_core.settlement_sockets(record.race_id)
		-- The registry compiled its world positions against the anchor the
		-- settlement WRITER uses; the preload and the arrival use the one the
		-- consumer payload publishes. They are the same anchor, and if they
		-- ever were not, every NPC in this settlement would stand at a
		-- different height from the buildings -- so it is checked rather than
		-- assumed, once per start at load.
		local published = faction_id and
			grug_core.start_anchor(faction_id, record.race_id) or nil
		if published and (published.x ~= record.anchor.x or
				published.y ~= record.anchor.y or
				published.z ~= record.anchor.z) then
			core.log("error", "[grug_mobs] start npcs: " .. record.key ..
				" socket anchor " .. core.pos_to_string(record.anchor) ..
				" differs from the published start anchor " ..
				core.pos_to_string(published))
		end
		if not faction_id then
			core.log("error", "[grug_mobs] start npcs: no faction for race " ..
				record.race_id)
		elseif #sockets == 0 then
			core.log("warning", "[grug_mobs] start npcs: " .. record.key ..
				" exports no socket")
		else
			local start = {race_id = record.race_id, faction_id = faction_id,
				key = record.key, anchor = record.anchor}
			local row = {race_id = record.race_id, faction_id = faction_id,
				key = record.key, anchor = record.anchor,
				slots = {}, by_socket = {}, pending = 0, idle_spots = {},
				patrol = {}, totals = {}, placed_count = {}}
			-- The patrol loop and the idle spots first: both are read by every
			-- entity the row places, so they are built before the slots.
			local loop, loop_size = {}, 0
			for _, socket in ipairs(sockets) do
				if socket.role == "guard_patrol" then
					if loop[socket.order] then
						core.log("error", "[grug_mobs] start npcs: " .. record.key ..
							" repeats patrol order " .. socket.order)
					end
					loop[socket.order] = socket
					if socket.order > loop_size then loop_size = socket.order end
				elseif socket.role == "idle" then
					row.idle_spots[#row.idle_spots + 1] = {
						x = socket.pos.x, y = socket.pos.y, z = socket.pos.z,
						yaw = socket.yaw,
						tag = socket.tags and socket.tags[1] or nil,
					}
				end
			end
			for order = 1, loop_size do
				local socket = loop[order]
				if socket then
					row.patrol[#row.patrol + 1] =
						{x = socket.pos.x, z = socket.pos.z}
				end
			end
			for family_index = 1, #FAMILY_ORDER do
				row.totals[FAMILY_ORDER[family_index]] = 0
				row.placed_count[FAMILY_ORDER[family_index]] = 0
			end
			local idle_index = 0
			for _, socket in ipairs(sockets) do
				local resolver = resolvers[socket.role]
				-- A patrol loop carries ONE guard, booked on its first
				-- waypoint; the rest of the loop is route data.
				local carries = resolver ~= nil and
					(socket.role ~= "guard_patrol" or socket.order == 1)
				if carries then
					local entity = resolver(socket, start)
					if type(entity) ~= "string" or
							not core.registered_entities[entity] then
						core.log("error", "[grug_mobs] start npcs: " ..
							record.key .. " socket " .. socket.id ..
							" resolves to no registered entity (" ..
							tostring(entity) .. ")")
					else
						if socket.role == "idle" then
							idle_index = idle_index + 1
						end
						local slot = {
							id = socket.id, role = socket.role, entity = entity,
							family = FAMILY[socket.role] or "flair",
							pos = {x = socket.pos.x, y = socket.pos.y,
								z = socket.pos.z},
							yaw = socket.yaw,
							tag = socket.tags and socket.tags[1] or nil,
							idle_index = socket.role == "idle" and idle_index or nil,
							placed = storage:get_string(
								placed_key(record.race_id, socket.id)) == "1",
						}
						if not slot.placed then
							local due = tonumber(storage:get_string(
								due_key(record.race_id, socket.id)))
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
			by_race[row.race_id] = row
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
		if entity and entity.name == slot.entity and
				entity._grug_start == row.race_id and
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
	entity._grug_start = row.race_id
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
		-- job. Its own copy of the points, because `wp` lives in that table.
		local points = {}
		for index = 1, #row.patrol do
			points[index] = {x = row.patrol[index].x, z = row.patrol[index].z}
		end
		entity._grug_home = {x = slot.pos.x, y = slot.pos.y, z = slot.pos.z}
		entity._grug_patrol_route = {points = points, wp = 1}
	elseif slot.role == "idle" then
		entity._grug_idle_spots = copy_spots(row.idle_spots)
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
local function serve(row, positions)
	if not grug_core.start_ready(row.race_id) then return 0, 0 end
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

-- The countable per-start line both engine boots are read from.
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
-- 1. A start becomes ready: its whole 128 x 128 envelope is loaded right
--    then, so the roster can be placed in one pass with no player anywhere
--    near it. This is also the pass whose log line proves a restart places
--    nothing.
-- 2. The heartbeat: whatever the ready pass could not place (a node that was
--    not loaded after all) plus every guard respawn slot that has fallen due,
--    for sockets a player is standing near.
--

local ready_served = {}

local function serve_ready_starts()
	for index = 1, #rows do
		local row = rows[index]
		if not ready_served[row.race_id] and grug_core.start_ready(row.race_id) then
			ready_served[row.race_id] = true
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
		serve_ready_starts()
	end)
	core.after(0, serve_ready_starts)
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
	local row = by_race[self._grug_start]
	local slot = row and row.by_socket[self._grug_socket]
	if not slot or not slot.placed then return end
	mark_free(row, slot,
		core.get_gametime() + math.random(RESPAWN_MIN, RESPAWN_MAX))
	core.log("action", "[grug_mobs] start npcs " .. row.key .. ": socket " ..
		slot.id .. " lost its guard, refill due at " .. slot.due)
end
