-- Real-code KAT for the start-settlement placement engine
-- (`mods/ENTITIES/grug_mobs/start_npcs.lua`).
--
-- Drives the production file against a stub engine through the five states
-- that decide whether a settlement ends up with its roster exactly once:
--
--   1. cold        -- a prepared start with NO player near it is populated in
--                     full from the start-ready pass.
--   2. restart     -- the same world booted again places nothing.
--   3. lost entity -- markers that outlived their NPCs (/clearobjects, the
--                     mob_active_limit removal, a crash between the two
--                     flushes) are freed by the heartbeat and refilled.
--   4. death       -- a guard's death books a respawn slot: no refill before
--                     it falls due, one after.
--   5. second gate -- a marker lost while the NPC is still standing there is
--                     restored instead of a twin being spawned.
--
-- THE ONE THING THIS STUB MODELS EXACTLY, because the whole design hangs off
-- it: `core.get_objects_inside_radius` returns an object only while a player
-- is inside the engine's activation radius of it. A mapblock is activated by a
-- player being near, not by being loaded, so at start-ready -- where the area
-- is loaded and nobody is in it -- the scan is blind. A stub that always
-- answered would make state 2 pass for the wrong reason and hide a duplicated
-- roster.
--
-- Plain Lua 5.1; returns one canonical report. No `math.random` output: the
-- respawn interval is rolled with it and the two interpreters do not share an
-- RNG, so the report only ever says whether a refill happened before or after
-- the whole 180-360 s window.

return function(repo)
	local report = {}
	local function line(...)
		report[#report + 1] = table.concat({...}, "\t") .. "\n"
	end

	local saved = {core = rawget(_G, "core"), grug_core = rawget(_G, "grug_core"),
		grug_mobs = rawget(_G, "grug_mobs")}
	local function restore()
		rawset(_G, "core", saved.core)
		rawset(_G, "grug_core", saved.grug_core)
		rawset(_G, "grug_mobs", saved.grug_mobs)
	end
	local function fail(message)
		restore()
		error("wp13 start npcs: " .. message, 0)
	end
	local function check(condition, message)
		if not condition then fail(message) end
	end

	-- The activation radius the stub honours; 32 is the engine's smallest
	-- shipped `active_block_range * 16`, which is what PLAYER_RANGE 24 plus
	-- PRESENCE_RADIUS 8 is sized against.
	local ACTIVATION = 32

	local ANCHOR = {x = -1800, y = 25, z = -2550}
	-- A CAPITAL of the same race, registered under its own key. It is never
	-- preloaded, so nothing of it may be placed until its anchor column answers
	-- with a real node, and then the whole of it goes in on one pass with no
	-- player anywhere near -- which is exactly what happens when somebody walks
	-- up and the area emerges. Its two patrol loops are what a start does not
	-- have: a capital carries one per gate tower besides its city ring, and one
	-- guard has to come out of each.
	local CAPITAL = {x = -1800, y = 40, z = -1500}
	local CAPITAL_SOCKETS = {
		{id = "king", role = "king", x = 0, y = 6, z = 32, dir = {x = 0, z = -1}},
		{id = "hall_guard", role = "guard_post", x = -3, y = 1, z = 8,
			dir = {x = 0, z = 1}},
		{id = "ring_1", role = "guard_patrol", group = "city", order = 1,
			x = 0, y = 1, z = -20, dir = {x = 0, z = 1}},
		{id = "ring_2", role = "guard_patrol", group = "city", order = 2,
			x = 20, y = 1, z = -20, dir = {x = -1, z = 0}},
		{id = "tower_1", role = "guard_patrol", group = "gate_tower", order = 1,
			x = 0, y = 7, z = -46, dir = {x = 0, z = 1}},
		{id = "tower_2", role = "guard_patrol", group = "gate_tower", order = 2,
			x = 0, y = 12, z = -46, dir = {x = 0, z = -1}},
		{id = "vendor_race", role = "vendor", kind = "race", x = 42, y = 1,
			z = 7, dir = {x = -1, z = 0}},
		{id = "core_idle", role = "idle", tags = {"door"}, x = -8, y = 1, z = 4,
			dir = {x = 1, z = 0}},
		-- A district plot's socket, prefixed with its plot id by the seam.
		{id = "market_granary/market_granary_gate_idle", role = "idle",
			tags = {"door"}, x = 72, y = 1, z = -40, dir = {x = 0, z = 1}},
	}
	local SOCKETS = {
		{id = "gate_west", role = "guard_post", x = -4, y = 1, z = 59,
			dir = {x = 0, z = 1}},
		{id = "gate_east", role = "guard_post", x = 4, y = 1, z = 59,
			dir = {x = 0, z = 1}},
		{id = "watch_gate", role = "guard_patrol", group = "vale", order = 1,
			x = 0, y = 1, z = 52, dir = {x = 0, z = 1}},
		{id = "watch_street", role = "guard_patrol", group = "vale", order = 2,
			x = 0, y = 1, z = 24, dir = {x = 0, z = -1}},
		{id = "plaza_vendor", role = "vendor", kind = "race", x = 7, y = 1,
			z = -5, dir = {x = -1, z = 0}},
		{id = "idle_a", role = "idle", tags = {"door"}, x = -16, y = 1, z = 4,
			dir = {x = -1, z = 0}},
		{id = "idle_b", role = "idle", tags = {"bench"}, x = 7, y = 1, z = 1,
			dir = {x = 1, z = 0}},
		{id = "hall_quest", role = "quest", x = -28, y = 1, z = 26,
			dir = {x = 0, z = 1}},
	}
	local ENTITIES = {
		["grug_mobs:guard_accord"] = true,
		["grug_mobs:villager_dwarf"] = true,
		["grug_mobs:elder_dwarf"] = true,
		["grug_traders:vendor_race_dwarf"] = true,
	}
	-- Whether the capital's own area has been emerged yet. `get_node_or_nil`
	-- answers nil for a block that is not loaded, which is the gate a capital
	-- is placed behind.
	local capital_loaded = false

	--
	-- The world the stub keeps between boots: mod storage and the objects that
	-- are standing in the map. Both survive a "restart", which is the whole
	-- point of states 2 to 5.
	--
	local world = {storage = {}, objects = {}}
	local harness

	local function socket_world_pos(socket)
		return {x = ANCHOR.x + socket.x, y = ANCHOR.y + socket.y,
			z = ANCHOR.z + socket.z}
	end

	local function distance(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end

	local function activated(pos)
		for index = 1, #harness.players do
			if distance(harness.players[index], pos) <= ACTIVATION then
				return true
			end
		end
		return false
	end

	-- One boot: a fresh Lua environment for the production file, the same
	-- `world` underneath it.
	local function boot()
		harness = {players = {}, logs = {}, globalsteps = {}, mods_loaded = {},
			after = {}, clock = 1000, yaws = 0}

		local storage = {}
		function storage:get_string(key) return world.storage[key] or "" end
		function storage:set_string(key, value)
			if value == "" then world.storage[key] = nil
			else world.storage[key] = value end
		end

		local grug_mobs = {storage = storage}
		function grug_mobs.place_on_ground() end
		function grug_mobs.face_yaw() harness.yaws = harness.yaws + 1 end
		function grug_mobs.walk_toward() end
		rawset(_G, "grug_mobs", grug_mobs)

		local grug_core = {}
		function grug_core.start_identities()
			return {{race_id = "dwarf", faction_id = "accord",
				anchor = {x = ANCHOR.x, y = ANCHOR.y, z = ANCHOR.z}}}
		end
		function grug_core.settlement_socket_settlements()
			return {
				{key = "hearthpine", race_id = "dwarf",
					anchor = {x = ANCHOR.x, y = ANCHOR.y, z = ANCHOR.z}},
				{key = "dur_brannoc", race_id = "dwarf",
					anchor = {x = CAPITAL.x, y = CAPITAL.y, z = CAPITAL.z}},
			}
		end
		local function compile(list, anchor)
			local out = {}
			for index = 1, #list do
				local socket = list[index]
				out[index] = {id = socket.id, role = socket.role, x = socket.x,
					y = socket.y, z = socket.z,
					dir = {x = socket.dir.x, z = socket.dir.z},
					group = socket.group, order = socket.order,
					kind = socket.kind, tags = socket.tags,
					pos = {x = anchor.x + socket.x, y = anchor.y + socket.y,
						z = anchor.z + socket.z},
					yaw = 0}
			end
			return out
		end
		function grug_core.settlement_sockets(race_id)
			if race_id ~= "dwarf" then return {} end
			return compile(SOCKETS, ANCHOR)
		end
		function grug_core.settlement_sockets_at(key)
			if key == "hearthpine" then return compile(SOCKETS, ANCHOR) end
			if key == "dur_brannoc" then return compile(CAPITAL_SOCKETS, CAPITAL) end
			return {}
		end
		function grug_core.start_anchor()
			return {x = ANCHOR.x, y = ANCHOR.y, z = ANCHOR.z}
		end
		function grug_core.capital_anchor()
			return {x = CAPITAL.x, y = CAPITAL.y, z = CAPITAL.z}
		end
		function grug_core.start_ready() return harness.ready == true end
		function grug_core.register_on_starts_progress(fn)
			harness.progress = fn
		end
		rawset(_G, "grug_core", grug_core)

		local core_api = {registered_entities = ENTITIES}
		function core_api.log(level, message)
			-- Separated by a space rather than the obvious vertical bar: sweep 4
			-- of docs/research/luanti-lua.md hunts bitwise operators, and that
			-- character inside a string is a false hit a reader has to clear.
			harness.logs[#harness.logs + 1] = level .. " " .. message
		end
		function core_api.get_gametime() return harness.clock end
		function core_api.pos_to_string(pos)
			return "(" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ")"
		end
		function core_api.get_connected_players()
			local out = {}
			for index = 1, #harness.players do
				local pos = harness.players[index]
				out[index] = {get_pos = function() return pos end}
			end
			return out
		end
		-- A position inside the capital's envelope answers only once its area has
		-- been emerged; everything else is the loaded start. nil is what the
		-- engine returns for an unloaded block, and it is the capital's gate.
		function core_api.get_node_or_nil(pos)
			if pos and pos.z > -2000 and not capital_loaded then return nil end
			return {name = "air"}
		end
		function core_api.get_objects_inside_radius(pos, radius)
			local out = {}
			for index = 1, #world.objects do
				local object = world.objects[index]
				if activated(object.pos) and distance(object.pos, pos) <= radius then
					out[#out + 1] = object.ref
				end
			end
			return out
		end
		function core_api.add_entity(pos, name)
			if not ENTITIES[name] then return nil end
			local entity = {name = name}
			local object = {pos = {x = pos.x, y = pos.y, z = pos.z}}
			object.ref = {
				get_luaentity = function() return entity end,
				set_yaw = function() end,
				get_properties = function() return {collisionbox = {0, 0, 0, 0, 0, 0}} end,
				set_pos = function() end,
			}
			entity.object = object.ref
			world.objects[#world.objects + 1] = object
			return object.ref
		end
		function core_api.register_globalstep(fn)
			harness.globalsteps[#harness.globalsteps + 1] = fn
		end
		function core_api.register_on_mods_loaded(fn)
			harness.mods_loaded[#harness.mods_loaded + 1] = fn
		end
		function core_api.after(_, fn)
			harness.after[#harness.after + 1] = fn
		end
		rawset(_G, "core", core_api)

		dofile(repo .. "/mods/ENTITIES/grug_mobs/start_npcs.lua")
		-- grug_traders owns the vendor role in the real game.
		grug_mobs.register_start_socket_role("vendor", function(socket, start)
			return "grug_traders:vendor_race_" .. start.race_id
		end)
		for index = 1, #harness.mods_loaded do harness.mods_loaded[index]() end
		local queued = harness.after
		harness.after = {}
		for index = 1, #queued do queued[index]() end
	end

	local function step(seconds)
		harness.clock = harness.clock + seconds
		for index = 1, #harness.globalsteps do
			harness.globalsteps[index](seconds)
		end
		local queued = harness.after
		harness.after = {}
		for index = 1, #queued do queued[index]() end
	end

	local function become_ready()
		harness.ready = true
		if harness.progress then harness.progress(1, 1, false) end
		local queued = harness.after
		harness.after = {}
		for index = 1, #queued do queued[index]() end
	end

	local function markers()
		local count = 0
		for key in pairs(world.storage) do
			if key:sub(1, 9) == "startnpc:" then count = count + 1 end
		end
		return count
	end

	local function logged(needle)
		local count = 0
		for index = 1, #harness.logs do
			if harness.logs[index]:find(needle, 1, true) then count = count + 1 end
		end
		return count
	end

	--
	-- 1. Cold: a prepared start with nobody in it is populated in full.
	--
	-- Seven of the eight sockets carry an entity: the loop's SECOND waypoint
	-- is route data, not a standing position (one guard walks the whole loop).
	local SLOTS = 7
	boot()
	check(#world.objects == 0, "something stood there before the first boot")
	become_ready()
	check(#world.objects == SLOTS,
		"cold placement count differs: " .. #world.objects)
	check(markers() == SLOTS, "cold marker count differs: " .. markers())
	check(harness.yaws == SLOTS, "an NPC was placed without its authored facing")
	line("cold", #world.objects, markers(), logged("placed at socket"))

	--
	-- 2. Restart: same storage, same map, nobody near. Nothing is placed --
	--    and NOT because the scan saw the old NPCs (it cannot, they are not
	--    activated), but because the markers say the sockets are taken.
	--
	boot()
	become_ready()
	check(#world.objects == SLOTS, "a restart duplicated the roster: " ..
		#world.objects)
	check(markers() == SLOTS, "a restart changed the markers")
	check(logged("placed at socket") == 0, "a restart placed something")
	line("restart", #world.objects, markers(), logged("placed at socket"))

	--
	-- 3. The markers outlived their NPCs (/clearobjects). A player walks up:
	--    every socket she is near is freed and refilled; the rest stay marked,
	--    because a scan that cannot see must not decide.
	--
	world.objects = {}
	harness.players = {socket_world_pos(SOCKETS[1])}
	step(5)
	local near = 0
	for index = 1, #SOCKETS do
		local socket = SOCKETS[index]
		local carries = socket.role ~= "guard_patrol" or socket.order == 1
		if carries and
				distance(socket_world_pos(socket), harness.players[1]) <= 24 then
			near = near + 1
		end
	end
	check(near >= 2 and near < SLOTS,
		"the fixture's player must see some sockets and not all: " .. near)
	check(#world.objects == near, "the lost NPCs near the player were not " ..
		"refilled: " .. #world.objects .. " of " .. near)
	check(logged("is marked but empty") == near,
		"the freed sockets were not reported")
	check(markers() == SLOTS, "a refilled socket lost its marker")
	line("lost_entities", near, #world.objects, logged("is marked but empty"))

	--
	-- 4. A guard dies: the slot is booked with a respawn delay, and refilled
	--    only once that has passed.
	--
	local guard
	for index = 1, #world.objects do
		local entity = world.objects[index].ref:get_luaentity()
		if entity._grug_socket == "gate_west" then guard = entity end
	end
	check(guard ~= nil, "no guard stands on the first post")
	for index = 1, #world.objects do
		if world.objects[index].ref:get_luaentity() == guard then
			table.remove(world.objects, index)
			break
		end
	end
	grug_mobs.start_guard_died(guard)
	check(world.storage["startnpc:hearthpine:gate_west"] == nil,
		"a dead guard kept its marker")
	check(world.storage["startnpcdue:hearthpine:gate_west"] ~= nil,
		"a dead guard booked no refill")
	local before = #world.objects
	step(5)
	check(#world.objects == before,
		"a dead guard was replaced before its slot fell due")
	-- Past the whole 180-360 s window, whatever it rolled.
	step(400)
	check(#world.objects == before + 1,
		"a dead guard's slot never refilled: " .. #world.objects)
	check(world.storage["startnpcdue:hearthpine:gate_west"] == nil,
		"a served refill kept its due time")
	line("death_respawn", "not_before_due", "refilled_after_window")

	--
	-- 5. The second gate: a marker lost while its NPC is still standing there
	--    restores the marker instead of spawning a twin.
	--
	-- Cleared in STORAGE and then booted again: during a run the in-memory
	-- slot is authoritative, so this is the shape the loss really has -- a
	-- world whose markers no longer match the NPCs standing in it.
	world.storage["startnpc:hearthpine:gate_west"] = nil
	local standing = #world.objects
	boot()
	harness.players = {socket_world_pos(SOCKETS[1])}
	become_ready()
	check(#world.objects == standing, "the second gate spawned a twin")
	check(world.storage["startnpc:hearthpine:gate_west"] == "1",
		"the second gate did not restore the marker")
	check(logged("without a marker; marker restored") >= 1,
		"the restored marker was not reported")
	line("second_gate", "no_twin", "marker_restored")

	--
	-- 6. A CAPITAL, which is not preloaded. Nothing of it exists until its own
	--    area is emerged; then the whole of it goes in on one pass with no
	--    player near it, and each of its TWO patrol loops carries its own guard.
	--
	local function capital_slots()
		local count = 0
		for index = 1, #CAPITAL_SOCKETS do
			local socket = CAPITAL_SOCKETS[index]
			local carries = socket.role ~= "king" and socket.role ~= "waypoint" and
				(socket.role ~= "guard_patrol" or socket.order == 1)
			if carries then count = count + 1 end
		end
		return count
	end
	local CAPITAL_SLOTS = capital_slots()
	local function standing_at_capital()
		local count = 0
		for index = 1, #world.objects do
			local entity = world.objects[index].ref:get_luaentity()
			if entity and entity._grug_start == "dur_brannoc" then count = count + 1 end
		end
		return count
	end
	world.objects = {}
	world.storage = {}
	capital_loaded = false
	boot()
	harness.players = {}
	become_ready()
	check(standing_at_capital() == 0,
		"a capital was populated before its area was emerged")
	-- Several heartbeats with nobody anywhere: still nothing, because the
	-- capital's anchor column does not answer yet.
	step(5)
	step(5)
	check(standing_at_capital() == 0,
		"a capital was populated by a heartbeat before its area was emerged")
	-- Somebody walks up and the area emerges. No player is near any socket --
	-- the readiness pass is deliberately not a player question.
	capital_loaded = true
	step(5)
	check(standing_at_capital() == CAPITAL_SLOTS,
		"the emerged capital was not populated in one pass: " ..
		standing_at_capital() .. " of " .. CAPITAL_SLOTS)
	-- One guard per LOOP, each walking its own loop's waypoints and nobody
	-- else's. A start has one loop; a capital has as many as it authored.
	local loops, patrollers = {}, 0
	for index = 1, #world.objects do
		local entity = world.objects[index].ref:get_luaentity()
		if entity and entity._grug_start == "dur_brannoc" and
				entity._grug_patrol_route then
			patrollers = patrollers + 1
			local route = entity._grug_patrol_route
			check(#route.points == 2,
				"a capital patroller got a route of " .. #route.points ..
				" waypoints instead of its own loop's two")
			loops[entity._grug_socket] = #route.points
		end
	end
	check(patrollers == 2, "a capital's two loops produced " .. patrollers ..
		" guards")
	check(loops.ring_1 == 2 and loops.tower_1 == 2,
		"the two loops are not the two authored ones")
	-- A district villager wanders its own plot, never the whole city: the idle
	-- spots are grouped by the composition the socket id names.
	local district_spots, core_spots
	for index = 1, #world.objects do
		local entity = world.objects[index].ref:get_luaentity()
		if entity and entity._grug_start == "dur_brannoc" and
				entity._grug_idle_spots then
			if entity._grug_socket:find("/", 1, true) then
				district_spots = #entity._grug_idle_spots
			else
				core_spots = #entity._grug_idle_spots
			end
		end
	end
	check(district_spots == 1 and core_spots == 1,
		"a capital villager was given another composition's idle spots")
	-- And the START beside it is untouched: the two settlements of one race
	-- keep separate markers, which is why the key and not the race is the
	-- marker's identity.
	check(world.storage["startnpc:dur_brannoc:hall_guard"] == "1" and
		world.storage["startnpc:hearthpine:gate_west"] == "1",
		"the two settlements of one race share a marker")
	line("capital", CAPITAL_SLOTS, standing_at_capital(), patrollers,
		"loops_separate", "markers_separate")

	restore()
	return table.concat(report)
end
