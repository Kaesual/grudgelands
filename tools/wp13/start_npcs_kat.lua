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
--   7b. out of range -- THE REVIEW'S FINDING on the same item. The NPC's OWN
--                     mapblock is inactive while the socket's is active, which is
--                     the north-west patroller of a capital ring loop while a
--                     player stands at the south gate: `compare_block_status`
--                     answers for the block containing the position it is handed,
--                     and `active_block_range` is 64 nodes against a ~100-node
--                     loop. Nothing may be struck and nothing may be placed.
--   8. twin        -- a world that already has twins heals: the second entity
--                     booked on a socket is removed, the YOUNGER one goes
--                     whichever way round the two arrive, and one that activates
--                     onto a held socket removes itself.
--   9. amble       -- a villager walks to another idle socket and dwells there.
--                     The old ring advance deadlocked as soon as every spot was
--                     occupied, which is always, so nobody ever moved.
--  10. no jump     -- the villager families cannot reach mobs_redo's do_jump.
--  11. stuck route -- the three-stage patrol rescue, including the user's
--                     ruling that the teleport happens out of sight only.
--  12. noncombatant -- the round-2 ruling's half that lives in this fixture:
--                     the verb, the flag it installs at activation, and the
--                     declaration on every definition the fixture registers.
--                     The other half -- a guard is acquirable and the
--                     registration wrapper narrows nobody's `attack_npcs` --
--                     needs guard.lua and init.lua, which this fixture
--                     deliberately does not load, and is measured by the engine
--                     probe instead.
--
-- ROUND 2 (2026-09-15) also adds, inside the states above: the door flip on a
-- QUEST socket (1b), the spare idle socket that is a wander target and never a
-- home (1d, 6, 9), and the census field that reports how many a settlement has.
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
		-- A SPARE of the CORE composition: a wander target for the core's own
		-- citizen and for nobody in the district, which is what makes the two
		-- assertions on `_grug_idle_spots` below say something.
		{id = "core_spare", role = "idle", spawn = false, x = 4, y = 1, z = 10,
			dir = {x = -1, z = 0}},
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
		-- TWO tags, and `door` is the SECOND. `tags` is a list in the contract:
		-- the first entry is the one the spoken line reads off, the door rule is
		-- a statement about any of them, and reading `tags[1]` alone would turn
		-- the rule off for exactly this shape.
		{id = "idle_a", role = "idle", tags = {"bench", "door"}, x = -16, y = 1,
			z = 4, dir = {x = -1, z = 0}},
		{id = "idle_b", role = "idle", tags = {"bench"}, x = 7, y = 1, z = 1,
			dir = {x = 1, z = 0}},
		-- `door` on a QUEST socket: round 1 turned only `idle` sockets round, so
		-- every Village Elder kept its face in the hall door and its back to the
		-- street (playtest round 2). The tag describes the GEOMETRY, so the rule
		-- follows the tag and not the role.
		{id = "hall_quest", role = "quest", tags = {"door"}, x = -28, y = 1,
			z = 26, dir = {x = 0, z = 1}},
		-- A SPARE idle socket: a wander target the amble may use and a home
		-- nobody is ever placed on (`spawn = false`). Authored LAST on purpose,
		-- so a spot ring built from a count of the placed sockets instead of
		-- from the authored order would still pass -- the capital's spare, which
		-- sits in the middle of its list, is what catches that.
		{id = "idle_spare", role = "idle", spawn = false, x = -4, y = 1, z = 12,
			dir = {x = 0, z = -1}},
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
	local deactivate

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

	-- The engine's own `on_deactivate` dispatch: it is a field on the entity's
	-- table, reached through mobs_redo's shared `mob_class` metatable, and it is
	-- called with `removal = true` for an object being removed and `false` for an
	-- object whose mapblock is being unloaded. Never called for an object that
	-- was not active in the first place.
	function deactivate(mob, removal)
		if mob.removed or not mob.was_active then
			return
		end
		local mobs_api = rawget(_G, "mobs")
		local hook = mobs_api and mobs_api.mob_class and
			mobs_api.mob_class.on_deactivate
		-- The hook runs BEFORE the object stops existing, which is what lets it
		-- read the position the NPC went out of memory at.
		if hook then hook(mob, removal) end
		mob.was_active = false
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
				-- one engine fact the whole placement design hangs off. It is
				-- still true DURING `on_deactivate`, which is called while the
				-- object is alive ("about to get removed or unloaded").
				if mob.removed or not mob.was_active then return nil end
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
				-- `on_deactivate(self, true)` fires for an ACTIVE object that is
				-- removed (lua_api.md), which is what tells the placement engine
				-- this socket is really empty rather than merely out of range.
				deactivate(mob, true)
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
		mob.was_active = true
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
		-- A restart activates the objects of the blocks that are active, and no
		-- others; the previous session's `on_deactivate` handler died with its
		-- Lua environment, so nothing is dispatched here.
		for index = 1, #world.objects do
			local mob = world.objects[index].mob
			mob.was_active = activated(mob.pos)
		end

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

		-- `mob_class` is mobs_redo's SHARED entity class, which is where the
		-- placement engine installs its `on_deactivate` hook -- the engine looks
		-- that callback up on the entity's table and reaches the class through
		-- its metatable.
		local mobs_api = {mob_class = {}}
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
					-- Normalized exactly as the real registry normalizes it
					-- (grug_core/settlement_sockets.lua): a consumer reads one
					-- boolean and never spells "nil means true" itself. The
					-- registry's own validation is settlement_sockets_kat's.
					spawn = socket.spawn ~= false,
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
				if object.mob.was_active and
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

	-- What the engine's active-block management does between steps: an object
	-- whose block has gone inactive is deactivated (and is then invisible to
	-- every query), one whose block came back is active again.
	local function settle_activation()
		for index = 1, #world.objects do
			local mob = world.objects[index].mob
			local now_active = activated(mob.pos)
			if mob.was_active and not now_active then
				deactivate(mob, false)
			elseif now_active then
				mob.was_active = true
			end
		end
	end

	local function step(seconds)
		harness.clock = harness.clock + seconds
		settle_activation()
		for index = 1, #harness.globalsteps do
			harness.globalsteps[index](seconds)
		end
		local queued = harness.after
		harness.after = {}
		for index = 1, #queued do queued[index]() end
	end

	local function become_ready()
		-- Whatever the fixture has just changed about where the players are has
		-- already reached the engine's block management by the time a readiness
		-- pass runs.
		settle_activation()
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

	-- Does the placement engine's own claim registry hold this socket right now?
	-- Asked through the census, which is its only public view.
	local function claims_hold(socket_id)
		for index = 1, #world.objects do
			local mob = world.objects[index].mob
			if mob._grug_socket == socket_id and mob.object:get_pos() then
				return true
			end
		end
		return false
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
	-- Seven of the ten sockets carry an entity: the loop's SECOND waypoint is
	-- route data, not a standing position (one guard walks the whole loop), and
	-- the SPARE idle socket is a wander target nobody lives on. The roster is
	-- what is placed, marked, capped and censused -- so a spare must not enter
	-- any of those counts.
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
	-- ...and the LINE still follows the first tag, which is the other half of
	-- the split: the turn is about every tag, the flavour about the first one.
	check(door_mob._grug_idle_tag == "bench",
		"the spoken tag no longer follows the socket's first tag: " ..
		tostring(door_mob._grug_idle_tag))
	check(math.abs(bench_mob._grug_face_yaw - bench_authored) < 1e-9,
		"a bench socket's authored facing was changed")
	-- ROUND 2: the same rule for the QUEST socket. Round 1 keyed the flip on
	-- `role == "idle"`, so all seven elders faced their hall door.
	local elder_mob = entity_at("hall_quest")
	check(elder_mob ~= nil, "the quest socket is empty")
	check(turned(elder_mob._grug_face_yaw, dir_to_yaw({x = 0, z = 1})),
		"an elder on a door socket still faces the door")
	line("door_facing", "door_turned_on_second_tag", "line_keeps_first_tag",
		"bench_kept", "elder_turned")

	--
	-- 1d. THE SPARE SOCKET. Nothing is ever placed on it, no marker is written
	--     for it, it is no part of the roster -- and it IS part of every
	--     villager's spot ring, at the index the authored order gives it.
	--
	check(entity_at("idle_spare") == nil,
		"an NPC was placed on a spare idle socket")
	check(world.storage["startnpc:hearthpine:idle_spare"] ~= "1",
		"a spare idle socket was marked as placed")
	local spare_ring = entity_at("idle_a")._grug_idle_spots
	check(#spare_ring == 3,
		"the spare socket is not a wander target: " .. #spare_ring .. " spots")
	check(entity_at("idle_a")._grug_idle_spot == 1 and
		entity_at("idle_b")._grug_idle_spot == 2,
		"a villager was pointed at the wrong spot of its own ring")
	local spare_spot = spare_ring[3]
	check(math.abs(spare_spot.x - (ANCHOR.x - 4)) < 1e-9 and
		math.abs(spare_spot.z - (ANCHOR.z + 12)) < 1e-9,
		"the spare spot is not the authored one")
	line("spare", "unplaced", "unmarked", "ring_3", "spots_1_2")

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
		local carries = socket.spawn ~= false and
			(socket.role ~= "guard_patrol" or socket.order == 1)
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
				socket.spawn ~= false and
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
	-- The core's citizen has its own idle socket AND the core's spare; the
	-- district plot's has only its own. A spare belongs to the composition that
	-- authored it, like every other spot.
	check(district_spots == 1 and core_spots == 2,
		"a capital villager was given another composition's idle spots")
	check(entity_at("core_spare") == nil,
		"the capital placed an NPC on a spare socket")
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
	-- The player arrives first, which is what activates the blocks and the NPCs
	-- standing in them; then the NPC walks off its socket without leaving the
	-- activated area, which is a patrol.
	step(5)
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
	-- 7b. THE NPC'S OWN MAPBLOCK IS INACTIVE while its socket's is active.
	--
	-- The engine answers `compare_block_status` for the block containing the
	-- position it is handed (`ServerEnvironment::getBlockStatus`), and
	-- `active_block_range` reaches 64 nodes, so a capital's ring patroller can be
	-- outside the activated area while the socket it is booked on is inside it.
	-- Its object is then not in the environment at all -- `get_pos()` nil, no
	-- claim -- and striking on the socket's block alone would replace a guard
	-- that is merely out of range.
	--
	local far = entity_at("gate_east")
	check(far ~= nil, "no guard stands on the east post")
	local far_socket = socket_world_pos(SOCKETS[2])
	-- The player stands ON the socket, so its block is active; the NPC is moved
	-- to 100 nodes away, so its own block is not.
	harness.players = {{x = far_socket.x, y = far_socket.y, z = far_socket.z}}
	-- One pass with the guard still in range, so the fixture has SEEN it there:
	-- that is what `strikeable` remembers.
	step(5)
	check(claims_hold("gate_east"), "the fixture never saw the east guard")
	far.pos.x = far.pos.x + 100
	local before_far = #world.objects
	local freed_far = logged("is marked but empty")
	-- One pass for the engine's block management to notice, exactly as the
	-- engine does it: the object stays in the environment until then.
	step(5)
	check(far.object:get_pos() == nil,
		"the fixture's far NPC must be outside the activation radius")
	check(core.compare_block_status(far_socket, "active") == true,
		"the fixture's socket must still be active")
	for _ = 1, 10 do step(5) end
	check(#world.objects == before_far,
		"an out-of-range NPC was replaced: " .. #world.objects .. " instead of " ..
		before_far)
	check(logged("is marked but empty") == freed_far,
		"an out-of-range NPC's marker was freed")
	check(world.storage["startnpc:hearthpine:gate_east"] == "1",
		"an out-of-range NPC lost its marker")
	line("out_of_range", before_far, #world.objects, "no_strike")
	-- Bring it back for the twin case below.
	far.pos.x = far.pos.x - 100

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
	check(start_row.spare == 1,
		"the census does not report the settlement's spare sockets: " ..
		tostring(start_row.spare))
	line("census", start_row.key, start_row.kind, start_row.roster,
		start_row.marked, "spare_" .. start_row.spare)

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
	-- THREE spots for TWO villagers (playtest round 2): the third is the spare,
	-- and it is what makes a hop possible at all while both homes are occupied.
	check(#ambling[1]._grug_idle_spots == 3,
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
	check(count_visited(visited[1]) >= 2 and count_visited(visited[2]) >= 2,
		"a villager never reached another idle spot: " ..
		count_visited(visited[1]) .. "/" .. count_visited(visited[2]))
	-- AND THE SPARE IS ONE OF THE SPOTS THEY REACH. Without it two villagers on
	-- two sockets can only trade places; with it the settlement offers somewhere
	-- to stand that is not another villager's doorstep, which is the user's own
	-- item 3.
	check(visited[1][3] or visited[2][3],
		"no villager ever reached the spare idle spot")
	check(ambling[1].state == "stand" or ambling[1].state == "walk",
		"an ambling villager left the idle states")
	line("amble", "moved_at_" .. moved_at,
		"spots_" .. count_visited(visited[1]) .. "_and_" ..
		count_visited(visited[2]) .. "_of_3", "spare_reached",
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
	-- Two minutes of a loop nobody can walk, with a player standing on the mob:
	-- the give-ups keep coming but the LOG goes quiet after QUIET_AFTER of them,
	-- and the refused teleport is retried on a back-off rather than every tick.
	run_route(120)
	check(stuck.pos.x == stuck_pos.x and stuck.pos.z == stuck_pos.z,
		"a stuck guard was teleported while a player was watching it")
	check(logged("with no player within") == 0,
		"the out-of-sight teleport ran with a player in sight")
	local reported = logged("walks on to the next one")
	check(reported == 3, "the give-up log did not go quiet after three lines: " ..
		reported)
	check(logged("keeps trying without") == 1,
		"the mob never said it was going quiet")
	run_route(60)
	check(logged("walks on to the next one") == reported and
		logged("keeps trying without") == 1,
		"a mob that had gone quiet started reporting again")
	-- The player walks off to 50 nodes: past the 48 the ruling names, still
	-- inside the activation radius, so the mob is ticking and unwatched at once.
	-- (An empty player list would deactivate the mapblock and stop the tick
	-- altogether, which is the engine's behaviour and not what is under test.)
	harness.players = {{x = stuck.pos.x + 50, y = stuck.pos.y, z = stuck.pos.z}}
	-- The teleport is due, but the back-off holds it for up to SNAP_RETRY
	-- seconds after the refusal that happened while the player was watching.
	run_route(1)
	check(stuck.pos.x == stuck_pos.x and stuck.pos.z == stuck_pos.z,
		"the refused teleport was retried on the very next tick")
	run_route(10)
	check(stuck.pos.x ~= stuck_pos.x or stuck.pos.z ~= stuck_pos.z,
		"a stuck guard with nobody watching was not moved")
	check(logged("with no player within") >= 1,
		"the out-of-sight teleport was not reported")
	-- On A waypoint of its own loop, not merely somewhere else: which one is
	-- whichever it was heading for when the back-off let the snap through.
	local landed = false
	for index = 1, #route_points do
		if math.abs(stuck.pos.x - route_points[index].x) < 1e-9 and
				math.abs(stuck.pos.z - route_points[index].z) < 1e-9 then
			landed = true
		end
	end
	check(landed, "the snap did not land on a waypoint of the loop")
	line("stuck_route", "path_at_20", "skip_at_45", "quiet_after_3_lines",
		"no_snap_in_sight", "snap_out_of_sight_after_backoff")

	--
	-- 12. THE NON-COMBATANT VETO (user ruling, playtest round 2, 2026-09-15).
	--
	--     Round 1 gave EVERY mob `attack_npcs = false`, which bought the
	--     villagers their peace and paid for it with the only NPC-vs-monster
	--     fight the settlements have. The ruling splits the two: hostiles and
	--     guards may engage each other, civilians are never a target for
	--     anything, and guard vs. guard stays off.
	--
	--     What is checked here is the PURE FILTER and the verb that feeds it --
	--     the flag a target carries, the activation path that installs it, and
	--     the fact that the registration wrapper no longer narrows anybody's
	--     `attack_npcs`. The api.lua candidate loop that reads the flag is the
	--     engine's, so the probe is what exercises it.
	--
	local civilian = grug_mobs.noncombatant({})
	check(civilian._grug_noncombatant == true,
		"the verb did not declare the definition a non-combatant")
	check(grug_mobs.is_noncombatant({_grug_noncombatant = true}) == true,
		"the filter does not recognise a non-combatant")
	check(grug_mobs.is_noncombatant({}) == false and
		grug_mobs.is_noncombatant(nil) == false and
		grug_mobs.is_noncombatant("grug_mobs:wolf") == false,
		"the filter vetoes something that carries no flag")
	-- The flag reaches the ENTITY, because mobs_redo copies only its own def
	-- whitelist onto one (api.lua:3196ff) -- so the verb wraps after_activate,
	-- and it must chain whatever the definition already had there.
	local chained = {}
	local wrapped = grug_mobs.noncombatant({
		after_activate = function(self, staticdata, entity_def, dtime)
			chained[#chained + 1] = {staticdata, entity_def, dtime}
		end,
	})
	local fresh = {}
	wrapped.after_activate(fresh, "static", wrapped, 0.5)
	check(fresh._grug_noncombatant == true,
		"activation did not install the non-combatant flag on the entity")
	check(grug_mobs.is_noncombatant(fresh),
		"an activated non-combatant is not recognised by the filter")
	check(#chained == 1 and chained[1][1] == "static" and
		chained[1][2] == wrapped and chained[1][3] == 0.5,
		"the wrapper dropped the definition's own after_activate arguments")
	--
	-- EVERY DEFINITION THIS FIXTURE REGISTERS, and the flag is right on all of
	-- them. A complete statement over a closed set is worth something; a lookup
	-- of a name the fixture never registers is not, and the first cut of this
	-- block had two of those. `harness.defs["grug_mobs:guard_accord"] == nil` is
	-- always true here (the fixture dofiles patrol/verbs/start_villagers/
	-- start_npcs and neither guard.lua nor init.lua), and a bare table literal
	-- never passes through `grug_mobs.register_mob`, so both would have passed
	-- with the blanket veto restored.
	--
	-- THE OTHER TWO HALVES OF THE RULING ARE MEASURED IN THE ENGINE, by the
	-- probe, because that is where `grug_mobs.register_mob` and guard.lua
	-- actually run: `event=hostile … attack_npcs=true … state=attack
	-- target=grug_mobs:guard_accord` is both of them in one line -- the wrapper
	-- narrowed nobody, and a guard is acquirable and therefore no
	-- non-combatant -- and the probe fails outright if a hostile reads false or
	-- if anything holds a civilian as its target.
	--
	local registered, flagged = 0, 0
	for name, def in pairs(harness.defs) do
		registered = registered + 1
		local civilian = name:find("villager", 1, true) ~= nil or
			name:find("elder", 1, true) ~= nil
		if def._grug_noncombatant == true then flagged = flagged + 1 end
		check((def._grug_noncombatant == true) == civilian,
			name .. " carries the wrong non-combatant declaration")
	end
	-- One villager and one elder: the fixture publishes a single start identity.
	check(registered == 2 and flagged == 2,
		"the fixture registered " .. registered .. " definitions of which " ..
		flagged .. " are non-combatants, not 2 of 2")
	-- And the verb still touches nothing else: passive prey keeps the targeting
	-- fields its own verb set, which is the one neighbouring rule that could be
	-- clipped by a wider veto.
	local prey = grug_mobs.passive_prey({})
	check(prey.attack_npcs == false and prey.attack_players == false,
		"passive prey lost its own targeting fields")
	line("noncombatant", "declared", "installed_on_activate", "chained",
		"all_" .. registered .. "_defs_correct", "prey_unchanged")

	restore()
	return table.concat(report)
end
