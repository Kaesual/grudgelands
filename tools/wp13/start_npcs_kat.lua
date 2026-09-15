-- Real-code KAT for the settlement NPC roster: the placement engine
-- (`mods/ENTITIES/grug_mobs/start_npcs.lua`), the two flair families
-- (`start_villagers.lua`), the shared route/stuck movement (`patrol.lua`) and
-- the targeting verb the registration wrapper applies (`verbs.lua`).
--
-- Drives the production files against a stub engine through the states that
-- decide whether a settlement ends up with its roster exactly once and whether
-- the people in it behave:
--
--   1. cold        -- a prepared start with NO player near it is populated in
--                     full from the start-ready pass.
--   2. restart     -- the same world booted again places nothing.
--   3. lost entity -- markers that outlived their NPCs (/clearobjects, the
--                     mob_active_limit removal, a crash between the two
--                     flushes) are freed by the heartbeat and refilled -- but
--                     only where the map can actually answer, and only after
--                     FREE_STRIKES passes have agreed.
--   4. death       -- a guard's death books a respawn slot: no refill before
--                     it falls due, one after.
--   5. second gate -- a marker lost while the NPC still exists is restored
--                     instead of a twin being spawned.
--   6. capital     -- a settlement that is not preloaded, with two patrol loops
--                     and per-composition idle groups.
--   7. wanderer    -- THE 2026-09-15 PLAYTEST DEFECT. An NPC standing 40 nodes
--                     from its socket, with a player right next to that socket,
--                     over ten heartbeats: the count stays at the roster. The
--                     old position-based occupancy test freed the marker and
--                     placed a twin every single heartbeat.
--   8. twin        -- a world that already has twins heals: the second entity
--                     booked on a socket is removed, and one that activates
--                     later removes itself.
--   9. amble       -- a villager walks to another idle socket and dwells there.
--                     The old ring advance deadlocked as soon as every spot was
--                     occupied, which is always, so nobody ever moved.
--  10. no jump     -- the villager families cannot reach mobs_redo's do_jump.
--  11. stuck route -- the three-stage patrol rescue, including the user's
--                     ruling that the teleport happens out of sight only.
--  12. npc targets -- no mob registered through the wrapper hunts NPCs unless
--                     it is a declared war-front unit.
--
-- THE ONE THING THIS STUB MODELS EXACTLY, because the whole design hangs off
-- it: an object exists in the environment only while its mapblock is ACTIVE, and
-- a mapblock is activated by a player being near it, not by being loaded. So
-- `get_objects_inside_radius` is blind at start-ready -- where the area is
-- loaded and nobody is in it -- and `get_pos()` on an object whose block went
-- inactive answers nil. A stub that always answered would make state 2 pass for
-- the wrong reason and hide a duplicated roster.
--
-- Plain Lua 5.1; returns one canonical report. Nothing that `math.random`
-- decides reaches the report: the respawn interval and the dwell length are
-- rolled with it and the two interpreters do not share an RNG, so the report
-- only ever carries facts that are the same on both.

return function(repo)
	local report = {}
	local function line(...)
		report[#report + 1] = table.concat({...}, "\t") .. "\n"
	end

	local saved = {core = rawget(_G, "core"), grug_core = rawget(_G, "grug_core"),
		grug_mobs = rawget(_G, "grug_mobs"), mobs = rawget(_G, "mobs"),
		vector = rawget(_G, "vector")}
	local function restore()
		rawset(_G, "core", saved.core)
		rawset(_G, "grug_core", saved.grug_core)
		rawset(_G, "grug_mobs", saved.grug_mobs)
		rawset(_G, "mobs", saved.mobs)
		rawset(_G, "vector", saved.vector)
	end
	local function fail(message)
		restore()
		error("wp13 start npcs: " .. message, 0)
	end
	local function check(condition, message)
		if not condition then fail(message) end
	end

	-- The activation radius the stub honours: the engine's own default
	-- `active_block_range` of 4 mapblocks = 64 nodes. It is what decides both
	-- whether an object can be seen at all and whether a socket's own mapblock
	-- reads as active (`core.compare_block_status`).
	local ACTIVATION = 64

	local ANCHOR = {x = -1800, y = 25, z = -2550}
	-- Air at and above the socket course, stone below it: enough of a world for
	-- the "is this node loaded" gate and for the stuck rescue's standing-y probe.
	local GROUND_Y = ANCHOR.y + 1
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

	-- The engine's own `core.dir_to_yaw` one-liner (l_util.cpp: atan2(-x, z)),
	-- so the fixture's yaws are the registry's yaws and the door flip can be
	-- measured against them.
	local function dir_to_yaw(dir)
		return math.atan2(-dir.x, dir.z)
	end

	--
	-- One simulated second of walking: a mob that `walk_toward` aimed somewhere
	-- and that is in state "walk" covers `walk_velocity` nodes toward that
	-- point. `blocked` is the fixture saying "this mob cannot move at all",
	-- which is what the stuck rescue is about.
	--
	local function advance(mob, seconds)
		if mob.blocked or mob.state ~= "walk" or (mob.velocity or 0) <= 0 then
			return
		end
		local target = mob.walk_target
		if not target then return end
		local dx, dz = target.x - mob.pos.x, target.z - mob.pos.z
		local span = math.sqrt(dx * dx + dz * dz)
		local step = mob.velocity * seconds
		if span <= step or span == 0 then
			mob.pos.x, mob.pos.z = target.x, target.z
		else
			mob.pos.x = mob.pos.x + dx / span * step
			mob.pos.z = mob.pos.z + dz / span * step
		end
	end

	-- A stub mob: the methods `walk_toward`, `face_yaw` and the two families'
	-- own ticks call on `self`, plus the object handle the placement engine and
	-- the claim registry hold.
	local function new_mob(name, pos)
		local def = harness.defs[name]
		local mob = {name = name, state = "stand", temp = {}, velocity = 0,
			-- The def's own walking pace, exactly as mobs_redo copies it onto
			-- the entity: `walk_toward` issues `set_velocity(self.walk_velocity)`
			-- and the fixture's kinematics spend it.
			walk_velocity = def and def.walk_velocity or 1.2,
			pos = {x = pos.x, y = pos.y, z = pos.z}}
		local object
		object = {
			get_pos = function()
				-- AN OBJECT EXISTS ONLY WHILE ITS BLOCK IS ACTIVE. This is the
				-- one engine fact the whole placement design hangs off.
				if mob.removed or not activated(mob.pos) then return nil end
				return {x = mob.pos.x, y = mob.pos.y, z = mob.pos.z}
			end,
			set_pos = function(_, p)
				mob.pos.x, mob.pos.y, mob.pos.z = p.x, p.y, p.z
			end,
			get_properties = function()
				return {collisionbox = {0, 0, 0, 0, 0, 0}}
			end,
			set_properties = function() end,
			set_yaw = function(_, yaw) mob.yaw = yaw end,
			get_yaw = function() return mob.yaw or 0 end,
			is_player = function() return false end,
			remove = function()
				mob.removed = true
				for index = 1, #world.objects do
					if world.objects[index].mob == mob then
						table.remove(world.objects, index)
						break
					end
				end
			end,
			get_luaentity = function()
				if mob.removed then return nil end
				return mob
			end,
		}
		mob.object = object
		function mob:yaw_to_pos(target)
			self.walk_target = {x = target.x, z = target.z}
		end
		function mob:set_velocity(value) self.velocity = value end
		function mob:set_yaw(yaw) self.yaw = yaw end
		function mob:set_animation() end
		return mob
	end

	-- One boot: a fresh Lua environment for the production files, the same
	-- `world` underneath them.
	local function boot()
		harness = {players = {}, logs = {}, globalsteps = {}, mods_loaded = {},
			after = {}, clock = 1000, yaws = 0, defs = {}, paths = 0}

		local storage = {}
		function storage:get_string(key) return world.storage[key] or "" end
		function storage:set_string(key, value)
			if value == "" then world.storage[key] = nil
			else world.storage[key] = value end
		end

		local grug_mobs = {storage = storage}
		-- init.lua's own ground correction, which is not part of this fixture.
		function grug_mobs.place_on_ground(object, pos)
			object:set_pos(pos)
		end
		rawset(_G, "grug_mobs", grug_mobs)

		rawset(_G, "vector", {
			new = function(x, y, z) return {x = x, y = y, z = z} end,
		})

		local mobs_api = {}
		function mobs_api.register_mob(_, name, def) harness.defs[name] = def end
		-- mobs_redo's own public removal (api.lua:789), which is what the
		-- placement engine uses so the active-mob bookkeeping stays right.
		function mobs_api.remove(_, entity) entity.object:remove() end
		rawset(_G, "mobs", mobs_api)

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
					yaw = dir_to_yaw(socket.dir)}
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

		local core_api = {registered_entities = ENTITIES,
			registered_nodes = {air = {walkable = false},
				["default:stone"] = {walkable = true}}}
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
		function core_api.global_exists() return false end
		function core_api.chat_send_player() end
		function core_api.dir_to_yaw(dir) return dir_to_yaw(dir) end
		function core_api.register_on_joinplayer() end
		function core_api.register_on_leaveplayer() end
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
			if pos and pos.y < GROUND_Y then return {name = "default:stone"} end
			return {name = "air"}
		end
		-- A mapblock is active exactly while a player is inside the activation
		-- radius of it, which is the rule the engine's ActiveBlockList applies.
		function core_api.compare_block_status(pos, condition)
			if condition ~= "active" then return nil end
			return activated(pos)
		end
		function core_api.get_objects_inside_radius(pos, radius)
			local out = {}
			for index = 1, #harness.players do
				local player = harness.players[index]
				if distance(player, pos) <= radius then
					out[#out + 1] = {is_player = function() return true end,
						get_luaentity = function() return nil end,
						get_pos = function() return player end}
				end
			end
			for index = 1, #world.objects do
				local object = world.objects[index]
				if activated(object.mob.pos) and
						distance(object.mob.pos, pos) <= radius then
					out[#out + 1] = object.mob.object
				end
			end
			return out
		end
		-- A straight three-node path, or nil when the fixture says there is
		-- none. Counted, because "did the mob ask the pathfinder" is what
		-- stage 1 of the stuck rescue IS.
		function core_api.find_path(from, to)
			harness.paths = harness.paths + 1
			if harness.no_path then return nil end
			return {{x = from.x, y = from.y, z = from.z},
				{x = to.x, y = to.y, z = to.z}}
		end
		function core_api.add_entity(pos, name)
			if not ENTITIES[name] then return nil end
			local mob = new_mob(name, pos)
			world.objects[#world.objects + 1] = {mob = mob}
			-- The engine activates an entity synchronously inside add_entity, so
			-- after_activate has already run when the placement engine writes
			-- its fields. That ordering is why `place` re-asserts the facing and
			-- the nametag.
			local def = harness.defs[name]
			if def and def.after_activate then def.after_activate(mob) end
			return mob.object
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

		-- The real files, in init.lua's own order.
		local mod = repo .. "/mods/ENTITIES/grug_mobs/"
		dofile(mod .. "patrol.lua")
		dofile(mod .. "verbs.lua")
		dofile(mod .. "start_villagers.lua")
		dofile(mod .. "start_npcs.lua")
		-- grug_traders owns the vendor role in the real game.
		grug_mobs.register_start_socket_role("vendor", function(socket, start)
			return "grug_traders:vendor_race_" .. start.race_id
		end)
		local face_yaw = grug_mobs.face_yaw
		grug_mobs.face_yaw = function(self, yaw)
			if type(yaw) == "number" then harness.yaws = harness.yaws + 1 end
			return face_yaw(self, yaw)
		end
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

	local function entity_at(socket_id)
		for index = 1, #world.objects do
			local mob = world.objects[index].mob
			if mob._grug_socket == socket_id then return mob end
		end
		return nil
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
	check(harness.yaws >= SLOTS, "an NPC was placed without its authored facing")
	line("cold", #world.objects, markers(), logged("placed at socket"))

	--
	-- 1b. THE DOOR FLIP. An idle socket tagged `door` faces AWAY from the door,
	--     every other socket keeps the facing its blueprint authored.
	--
	local door_mob = entity_at("idle_a")
	local bench_mob = entity_at("idle_b")
	check(door_mob ~= nil and bench_mob ~= nil, "the two idle sockets are empty")
	local door_authored = dir_to_yaw({x = -1, z = 0})
	local bench_authored = dir_to_yaw({x = 1, z = 0})
	local function turned(yaw, authored)
		local delta = math.abs(yaw - authored) % (2 * math.pi)
		return math.abs(delta - math.pi) < 1e-9
	end
	check(turned(door_mob._grug_face_yaw, door_authored),
		"a door socket did not turn its NPC round")
	check(math.abs(bench_mob._grug_face_yaw - bench_authored) < 1e-9,
		"a bench socket's authored facing was changed")
	line("door_facing", "door_turned", "bench_kept")

	--
	-- 1c. THE NAMETAG FOLLOWS THE SETTLEMENT. A start keeps its authored
	--     flavour name; anything else is named after itself, and a capital
	--     villager must not wear the race's start name.
	--
	check(door_mob._grug_npc_name == "Vale Dwarf",
		"a start villager lost its authored name: " ..
		tostring(door_mob._grug_npc_name))
	check(door_mob._grug_npc_tag == "Vale Dwarf",
		"the placement did not re-assert the nametag after install")
	check(entity_at("hall_quest")._grug_npc_name == "Vale Elder",
		"a start elder lost its authored name")
	check(grug_mobs.settlement_npc_name("dur_brannoc", "capital", "dwarf",
		"villager") == "Dur Brannoc Citizen",
		"a capital villager is not named after its settlement")
	check(grug_mobs.settlement_npc_name("highcourt", "capital", "human",
		"elder") == "Highcourt Elder",
		"a capital elder is not named after its settlement")
	line("nametags", "Vale Dwarf", "Dur Brannoc Citizen", "Highcourt Elder")

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
	--    every socket whose mapblock she activates is freed -- after
	--    FREE_STRIKES agreeing passes -- and refilled; the rest stay marked,
	--    because a scan that cannot see must not decide.
	--
	world.objects = {}
	harness.players = {socket_world_pos(SOCKETS[1])}
	local seeable = 0
	for index = 1, #SOCKETS do
		local socket = SOCKETS[index]
		local carries = socket.role ~= "guard_patrol" or socket.order == 1
		if carries and
				distance(socket_world_pos(socket), harness.players[1]) <= ACTIVATION then
			seeable = seeable + 1
		end
	end
	check(seeable >= 2 and seeable < SLOTS,
		"the fixture's player must see some sockets and not all: " .. seeable)
	step(5)
	check(#world.objects == 0,
		"a single empty pass was enough to free a marker: " .. #world.objects)
	step(5)
	check(#world.objects == 0, "two passes were enough to free a marker")
	step(5)
	check(#world.objects == seeable, "the lost NPCs the player can see were not " ..
		"refilled: " .. #world.objects .. " of " .. seeable)
	check(logged("is marked but empty") == seeable,
		"the freed sockets were not reported")
	check(markers() == SLOTS, "a refilled socket lost its marker")
	line("lost_entities", seeable, #world.objects, logged("is marked but empty"))

	--
	-- 4. A guard dies: the slot is booked with a respawn delay, and refilled
	--    only once that has passed.
	--
	local guard = entity_at("gate_west")
	check(guard ~= nil, "no guard stands on the first post")
	guard.object:remove()
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
	-- 5. The second gate: a marker lost while its NPC still exists restores the
	--    marker instead of spawning a twin.
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
			local mob = world.objects[index].mob
			if mob._grug_start == "dur_brannoc" then count = count + 1 end
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
		local mob = world.objects[index].mob
		if mob._grug_start == "dur_brannoc" and mob._grug_patrol_route then
			patrollers = patrollers + 1
			local route = mob._grug_patrol_route
			check(#route.points == 2,
				"a capital patroller got a route of " .. #route.points ..
				" waypoints instead of its own loop's two")
			loops[mob._grug_socket] = #route.points
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
		local mob = world.objects[index].mob
		if mob._grug_start == "dur_brannoc" and mob._grug_idle_spots then
			if mob._grug_socket:find("/", 1, true) then
				district_spots = #mob._grug_idle_spots
			else
				core_spots = #mob._grug_idle_spots
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

	--
	-- 7. THE WANDERER (playtest round 1, 2026-09-15). An NPC 40 nodes from its
	--    socket, a player standing ON the socket, ten heartbeats. The count must
	--    not move: occupancy is an identity question.
	--
	-- The old test was `get_objects_inside_radius(socket, 8)`, and the assertion
	-- below that the wanderer is far outside that radius is what makes this case
	-- a regression test rather than a tautology.
	--
	local PRESENCE_RADIUS_BEFORE = 8
	local wanderer = entity_at("watch_gate")
	check(wanderer ~= nil, "the patrol guard was not placed")
	local socket_pos = socket_world_pos(SOCKETS[3])
	harness.players = {{x = socket_pos.x, y = socket_pos.y, z = socket_pos.z}}
	wanderer.pos.x = wanderer.pos.x + 40
	check(distance(wanderer.pos, socket_pos) > PRESENCE_RADIUS_BEFORE,
		"the wanderer must stand outside the old presence radius")
	check(wanderer.object:get_pos() ~= nil,
		"the wanderer must still be active where the fixture put it")
	local objects_before = #world.objects
	local markers_before = markers()
	local freed_before = logged("is marked but empty")
	for _ = 1, 10 do step(5) end
	check(#world.objects == objects_before,
		"ten heartbeats over a wandering NPC changed the population: " ..
		#world.objects .. " instead of " .. objects_before)
	check(markers() == markers_before, "a wandering NPC's marker was touched")
	check(logged("is marked but empty") == freed_before,
		"a wandering NPC was reported gone")
	line("wanderer", objects_before, #world.objects, markers(), "10_heartbeats")

	--
	-- 8. A world that ALREADY has twins heals, both ways round: the heartbeat
	--    removes the second entity booked on a socket, and an entity that
	--    activates onto a held socket removes itself.
	--
	local held_mob = entity_at("gate_east")
	check(held_mob ~= nil, "no guard stands on the east post")
	harness.players = {{x = held_mob.pos.x, y = held_mob.pos.y, z = held_mob.pos.z}}
	local twin = new_mob(held_mob.name, held_mob.pos)
	twin._grug_start = held_mob._grug_start
	twin._grug_socket = held_mob._grug_socket
	world.objects[#world.objects + 1] = {mob = twin}
	local with_twin = #world.objects
	step(5)
	check(#world.objects == with_twin - 1, "the heartbeat kept a twin")
	check(twin.removed == true or held_mob.removed == true,
		"the heartbeat removed something else")
	local survivor = entity_at("gate_east")
	check(survivor ~= nil, "the heartbeat removed the post's whole guard")
	local claimer = new_mob(survivor.name, survivor.pos)
	claimer._grug_start = survivor._grug_start
	claimer._grug_socket = survivor._grug_socket
	check(grug_mobs.start_npc_claim(claimer) == false,
		"a second NPC activating on a held socket did not remove itself")
	check(claimer.removed == true, "the refused claimer stayed in the world")
	check(grug_mobs.start_npc_claim(survivor) == true,
		"the socket's own holder was refused its claim")
	line("twins", with_twin, #world.objects, "claim_refused")

	--
	-- 8b. The census the engine probe reads: roster, markers and live NPCs per
	--     settlement, by identity.
	--
	local census = grug_mobs.start_npc_census()
	check(#census == 2, "the census does not cover both settlements")
	local start_row
	for index = 1, #census do
		if census[index].key == "hearthpine" then start_row = census[index] end
	end
	check(start_row ~= nil and start_row.roster == SLOTS,
		"the census reports the wrong roster size")
	line("census", start_row.key, start_row.kind, start_row.roster,
		start_row.marked)

	--
	-- 9. THE AMBLE. Two villagers, each standing on its own idle socket, i.e.
	--    the state in which EVERY candidate spot is occupied. Both must move.
	--
	-- This is the second half of the 2026-09-15 playtest: the first version
	-- walked the ring looking for a free spot and fell back to its own when it
	-- found none, so four villagers on four spots stood still for ever. The
	-- first dwell after an activation is capped at DWELL_MIN = 20 s, which is
	-- what makes the first hop happen at second 21 on both interpreters -- every
	-- later dwell is `math.random` and never reaches this report.
	--
	local villager_def = harness.defs["grug_mobs:villager_dwarf"]
	check(villager_def ~= nil and villager_def.do_custom ~= nil,
		"the villager family registered no amble")
	local ambling = {entity_at("idle_a"), entity_at("idle_b")}
	check(ambling[1] ~= nil and ambling[2] ~= nil, "the idle sockets are empty")
	check(#ambling[1]._grug_idle_spots == 2,
		"a start villager was given " .. #ambling[1]._grug_idle_spots ..
		" idle spots")
	-- A player next to both of them, so they are active and can see each other.
	harness.players = {{x = ambling[1].pos.x, y = ambling[1].pos.y,
		z = ambling[1].pos.z}}
	local origin = {}
	local visited = {{}, {}}
	for index = 1, 2 do
		origin[index] = {x = ambling[index].pos.x, z = ambling[index].pos.z}
	end
	local trace, moved_at = {}, nil
	for second = 1, 200 do
		for index = 1, 2 do
			villager_def.do_custom(ambling[index], 1)
			advance(ambling[index], 1)
			local spots = ambling[index]._grug_idle_spots
			for spot_index = 1, #spots do
				local spot = spots[spot_index]
				local dx = spot.x - ambling[index].pos.x
				local dz = spot.z - ambling[index].pos.z
				if dx * dx + dz * dz <= 1.6 * 1.6 then
					visited[index][spot_index] = true
				end
			end
		end
		if not moved_at and (ambling[1].pos.x ~= origin[1].x or
				ambling[1].pos.z ~= origin[1].z) then
			moved_at = second
		end
		if second % 10 == 0 and second <= 60 then
			trace[#trace + 1] = second .. ":" ..
				string.format("%.1f/%.1f", ambling[1].pos.x - ANCHOR.x,
					ambling[1].pos.z - ANCHOR.z)
		end
	end
	local function count_visited(row)
		local count = 0
		for _ in pairs(row) do count = count + 1 end
		return count
	end
	-- Second 21 spends the dwell's last tick and takes the next spot, second 22
	-- is the first one that walks: `moved_at` is measured after the step.
	check(moved_at == 22, "the first hop did not happen at second 22 but at " ..
		tostring(moved_at))
	check(count_visited(visited[1]) == 2 and count_visited(visited[2]) == 2,
		"a villager never reached another idle spot: " ..
		count_visited(visited[1]) .. "/" .. count_visited(visited[2]))
	check(ambling[1].state == "stand" or ambling[1].state == "walk",
		"an ambling villager left the idle states")
	line("amble", "moved_at_" .. moved_at, "spots_2_of_2",
		table.concat(trace, " "))

	-- 9b. A BLOCKED villager gives its spot up instead of pushing for ever. With
	--     two spots the target flips back and forth, so what is measured is the
	--     NUMBER of give-ups over 40 seconds, not the final index.
	local blocked = ambling[1]
	blocked.blocked = true
	blocked._grug_idle_dwell = 0
	local changes, last_spot = 0, blocked._grug_idle_spot
	for _ = 1, 40 do
		villager_def.do_custom(blocked, 1)
		advance(blocked, 1)
		if blocked._grug_idle_spot ~= last_spot then
			changes = changes + 1
			last_spot = blocked._grug_idle_spot
		end
	end
	-- One per SPOT_GIVE_UP window, so two inside forty seconds (whether the
	-- expired dwell adds a third depends on where the amble above left it).
	check(changes >= 2, "a blocked villager kept pushing at the same spot (" ..
		changes .. " changes in 40 s)")
	blocked.blocked = false
	line("amble_blocked", changes .. "_targets_in_40s")

	--
	-- 10. NO JUMP. mobs_redo's `do_jump` treats `walk_chance == 0` as "this is a
	--     jumping mob" (api.lua:1131) and runs four times a second, so a
	--     villager with a jump height hopped every time it landed. The gate that
	--     stops it is `jump_height == 0` (api.lua:1114), transcribed here.
	--
	local function would_jump(def, state)
		if state == "stand" or (def.jump_height or 4) == 0 then
			return false -- api.lua:1114
		end
		-- Standing on solid ground with nothing solid in front: the only clause
		-- left is mobs_redo's "or self.walk_chance == 0" (api.lua:1131).
		return def.walk_chance == 0
	end
	local elder_def = harness.defs["grug_mobs:elder_dwarf"]
	check(villager_def.jump_height == 0 and elder_def.jump_height == 0,
		"a settlement flair family can still jump")
	check(would_jump(villager_def, "walk") == false,
		"the villager def still reaches do_jump's jumping-mob clause")
	check(would_jump({walk_chance = 0, jump_height = 4}, "walk") == true,
		"the do_jump model does not reproduce the defect it guards")
	check(would_jump({jump_height = 4}, "walk") == false,
		"the do_jump model would stop a guard from stepping up")
	line("no_jump", villager_def.jump_height, elder_def.jump_height,
		"model_reproduces_defect")

	--
	-- 11. THE STUCK ROUTE (item 2). A guard that cannot move: the pathfinder is
	--     asked, then the waypoint is given up, then -- and only with no player
	--     within 48 nodes -- it is teleported.
	--
	local route_points = {{x = ANCHOR.x, z = ANCHOR.z + 52},
		{x = ANCHOR.x, z = ANCHOR.z + 24}}
	local stuck = new_mob("grug_mobs:guard_accord",
		{x = ANCHOR.x, y = GROUND_Y, z = ANCHOR.z + 40})
	stuck.walk_velocity = 1.2
	stuck.blocked = true
	world.objects[#world.objects + 1] = {mob = stuck}
	local route = {wp = 1}
	harness.players = {{x = stuck.pos.x, y = stuck.pos.y, z = stuck.pos.z}}
	harness.paths = 0
	local function run_route(seconds)
		for _ = 1, seconds do
			grug_mobs.route_tick(stuck, 1, route_points, route, "wp", true)
			advance(stuck, 1)
		end
	end
	run_route(19)
	check(harness.paths == 0,
		"the pathfinder was asked before the first stage was due")
	check(route.wp == 1, "the waypoint was given up before its stage was due")
	run_route(2)
	check(harness.paths >= 1, "stage 1 never asked the pathfinder")
	check(route.wp == 1, "stage 1 gave the waypoint up")
	run_route(25)
	check(route.wp == 2, "stage 2 never gave the unreachable waypoint up")
	check(logged("walks on to the next one") >= 1, "stage 2 was not reported")
	local stuck_pos = {x = stuck.pos.x, y = stuck.pos.y, z = stuck.pos.z}
	run_route(50)
	check(stuck.pos.x == stuck_pos.x and stuck.pos.z == stuck_pos.z,
		"a stuck guard was teleported while a player was watching it")
	check(logged("with no player within") == 0,
		"the out-of-sight teleport ran with a player in sight")
	-- The player walks off to 50 nodes: past the 48 the ruling names, still
	-- inside the activation radius, so the mob is ticking and unwatched at once.
	-- (An empty player list would deactivate the mapblock and stop the tick
	-- altogether, which is the engine's behaviour and not what is under test.)
	harness.players = {{x = stuck.pos.x + 50, y = stuck.pos.y, z = stuck.pos.z}}
	local target = route_points[route.wp]
	-- ONE tick: the snap lands the guard on its waypoint, and the tick after
	-- that legitimately reads it as arrived and takes the next one.
	run_route(1)
	check(stuck.pos.x ~= stuck_pos.x or stuck.pos.z ~= stuck_pos.z,
		"a stuck guard with nobody watching was not moved")
	check(logged("with no player within") >= 1,
		"the out-of-sight teleport was not reported")
	check(math.abs(stuck.pos.x - target.x) < 1e-9 and
		math.abs(stuck.pos.z - target.z) < 1e-9,
		"the snap did not land on the waypoint the guard could not reach")
	line("stuck_route", "path_at_20", "skip_at_45", "no_snap_in_sight",
		"snap_out_of_sight")

	--
	-- 12. NOBODY HUNTS NPCs (item 5, world.md section 4). The wrapper's verb,
	--     applied to every def, with the war-front opt-in as the exception.
	--
	local hostile = {attack_players = true, attack_monsters = false}
	grug_mobs.no_npc_targets(hostile)
	check(hostile.attack_npcs == false, "a hostile def may still hunt NPCs")
	check(hostile.attack_players == true and hostile.attack_monsters == false,
		"the verb changed a targeting field that is not its own")
	local soldier = {attack_players = true, _grug_attack_npcs = true}
	grug_mobs.no_npc_targets(soldier)
	check(soldier.attack_npcs == true,
		"a declared war-front unit lost its NPC targets")
	local prey = grug_mobs.passive_prey({})
	grug_mobs.no_npc_targets(prey)
	check(prey.attack_npcs == false and prey.attack_players == false,
		"the verb disturbed passive prey")
	line("npc_targets", "hostile_false", "warfront_true", "prey_unchanged")

	restore()
	return table.concat(report)
end
