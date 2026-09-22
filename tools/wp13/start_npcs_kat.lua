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

	local saved = {grug_home = rawget(_G, "grug_home"), core = rawget(_G, "core"), grug_core = rawget(_G, "grug_core"),
		grug_mobs = rawget(_G, "grug_mobs"), mobs = rawget(_G, "mobs"),
		vector = rawget(_G, "vector"), grug_jobs = rawget(_G, "grug_jobs"),
		-- Wave 2: the wield seam and the gear name builder (see GLOBALS in
		-- `boot`). Saved and restored like every other global this fixture
		-- installs, so the fixtures that run after it see the environment they
		-- had.
		grug_visuals = rawget(_G, "grug_visuals"),
		grug_gear = rawget(_G, "grug_gear")}
	local function restore()
		rawset(_G, "grug_home", saved.grug_home)
		rawset(_G, "core", saved.core)
		rawset(_G, "grug_core", saved.grug_core)
		rawset(_G, "grug_mobs", saved.grug_mobs)
		rawset(_G, "mobs", saved.mobs)
		rawset(_G, "vector", saved.vector)
		rawset(_G, "grug_jobs", saved.grug_jobs)
		rawset(_G, "grug_visuals", saved.grug_visuals)
		rawset(_G, "grug_gear", saved.grug_gear)
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
		-- Plain static entity: ObjectRef:set_yaw exists, while the luaentity
		-- deliberately has none of mobs_redo's methods.
		{id = "market_stable/mount_t1", role = "mount_display", tags = {"1"},
			x = 82, y = 1, z = -42, dir = {x = 1, z = 0}},
		{id = "outer_cooking/cooking", role = "trainer", profession = "cooking",
			x = 90, y = 1, z = 0, dir = {x = -1, z = 0}},
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
		--
		-- FOUR MORE IDLE SPAWN SOCKETS (playtest round 3): the 80/20 rule of
		-- contract section 8.3 counts `idle` spawn sockets in authored order
		-- and makes every FIFTH of them -- starting with the first -- a walker,
		-- so a fixture with two of them could never tell "the first" from
		-- "every fifth". With six, the walkers are the first and the sixth, and
		-- a rule that lost its stride would show up as one walker or as three.
		--
		-- Their positions are deliberate as well: c, e and f sit inside
		-- WALK_RADIUS of the walker at idle_a and b and d do not, which is what
		-- makes the bounded ring below a measurement rather than a copy of the
		-- whole composition.
		--
		{id = "idle_c", role = "idle", tags = {"work"}, x = -10, y = 1, z = 8,
			dir = {x = -1, z = 0}},
		{id = "idle_d", role = "idle", x = 10, y = 1, z = 6,
			dir = {x = 1, z = 0}},
		{id = "idle_e", role = "idle", x = -14, y = 1, z = 14,
			dir = {x = 0, z = 1}},
		{id = "idle_f", role = "idle", x = -18, y = 1, z = 8,
			dir = {x = -1, z = 0}},
		--
		-- TWO WORK SOCKETS (contract section 8.1). A `work` socket is a spawn
		-- socket like an `idle` one -- it is in the roster, it carries a marker
		-- and it is censused -- and its resident never walks: no ring, no
		-- dwell, no give-up clock. `activity` is required and comes from the
		-- closed vocabulary of section 8.2; the registry is what rejects a
		-- typo, and this fixture compiles sockets itself, so what it proves is
		-- what the PLACEMENT ENGINE does with a valid one.
		--
		{id = "forge_work", role = "work", activity = "smith", tags = {"fire"},
			x = 2, y = 1, z = -8, dir = {x = 0, z = -1}},
		{id = "bench_work", role = "work", activity = "sit", tags = {"bench"},
			x = 8, y = 1, z = 3, dir = {x = 1, z = 0}},
		--
		-- TWO WAVE-2 WORK SOCKETS (contract section 8.2's second table), and
		-- both of them are here to be measured rather than to be counted:
		--
		--   * `shrine_work` carries NO TAG, which is the case the wave-2 line
		--     rule is about -- an untagged work socket answers with its
		--     ACTIVITY's line instead of the settlement's `default` one -- and
		--     `mourn` is the one activity that writes a bone override;
		--   * `yard_work` is tagged, so it proves the same rule does NOT
		--     override an authored tag, and `spar` is the one activity that
		--     wields a grug_gear FAMILY rather than an item string.
		--
		{id = "shrine_work", role = "work", activity = "mourn",
			x = -6, y = 1, z = -14, dir = {x = 0, z = -1}},
		{id = "yard_work", role = "work", activity = "spar", tags = {"work"},
			x = 12, y = 1, z = -4, dir = {x = -1, z = 0}},
		-- `door` on a QUEST socket: round 1 turned only `idle` sockets round, so
		-- every Village Elder kept its face in the hall door and its back to the
		-- street (playtest round 2). The tag describes the GEOMETRY, so the rule
		-- follows the tag and not the role.
		{id = "hall_quest", role = "quest", tags = {"door"}, x = -28, y = 1,
			z = 26, dir = {x = 0, z = 1}},
		{id = "cooking_trainer", role = "trainer", profession = "cooking",
			x = 2, y = 1, z = 10, dir = {x = -1, z = 0}},
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
		["grug_mobs:guard_throng"] = true,
		["grug_mobs:villager_dwarf"] = true,
		["grug_mobs:elder_dwarf"] = true,
		["grug_traders:vendor_race_dwarf"] = true,
		["grug_mobs:capital_display"] = true,
	}

	--
	-- THE SIX REAL COMPOSITIONS (state 19, playtest round 3's review).
	--
	-- Everything above this line is a synthetic settlement, which is the right
	-- shape for the marker, twin and unload states: those are about the ENGINE's
	-- behaviour and a fixture that had to carry a whole village to express them
	-- would express them worse. But the 80/20 rule and the bounded ring are
	-- about the SETTLEMENTS THAT SHIP, and Stillgrave proved that: it passed
	-- every synthetic state while handing its one walker a ring of ONE, because
	-- its idle sockets are 27 nodes apart and the radius was a wall.
	--
	-- So the last state boots the real placement engine a second time over the
	-- six starts' own authored socket tables, read out of the same blueprints
	-- `tools/wp13/blueprint_kat.lua` reads. The anchors are this fixture's own
	-- -- a socket is anchor-relative and the ring is measured in world space
	-- against the same anchor, so the real anchors would prove nothing extra --
	-- and every other stub is the one above.
	--
	local START_RACE = {hearthpine = "dwarf", dawnmere = "human",
		silverleaf = "elf", stillgrave = "undead", sunscar = "orc",
		kapok = "troll"}
	local START_ORDER = {"hearthpine", "dawnmere", "silverleaf", "stillgrave",
		"sunscar", "kapok"}
	local RACE_FACTION = {human = "accord", dwarf = "accord", elf = "accord",
		orc = "throng", troll = "throng", undead = "throng"}
	for _, key in ipairs(START_ORDER) do
		local race = START_RACE[key]
		ENTITIES["grug_mobs:villager_" .. race] = true
		ENTITIES["grug_mobs:elder_" .. race] = true
		ENTITIES["grug_traders:vendor_race_" .. race] = true
	end

	-- Filled by state 19; nil means "the synthetic settlement above".
	local real_settlements = nil
	-- Whether the capital's own area has been emerged yet. `get_node_or_nil`
	-- answers nil for a block that is not loaded, which is the gate a capital
	-- is placed behind.
	local capital_loaded = false
	local capital_anchor_unloaded = false
	local capital_outer_unloaded = false

	--
	-- The world the stub keeps between boots: mod storage and the objects that
	-- are standing in the map. Both survive a "restart", which is the whole
	-- point of states 2 to 5.
	--
	local world = {storage = {}, objects = {}}
	local harness
	local trainer_mutation = tonumber(os.getenv("R8_PROF_NPC_MUTATION") or "") or 0

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
			-- Luanti >= 5.9's bone override, which is what a `mourn` resident
			-- bows its head with (start_villagers.lua's MOURN_PITCH). Recorded
			-- rather than applied: what this fixture can measure is that the
			-- override is written ONCE per activation, with the mesh's own
			-- `Head` bone and a RELATIVE rotation -- an absolute one would
			-- replace the animated pose instead of composing with it. The
			-- engine probe reads the real property off the real object.
			set_bone_override = function(_, bone, override)
				mob.bone_writes = (mob.bone_writes or 0) + 1
				mob.bone_overrides = mob.bone_overrides or {}
				mob.bone_overrides[bone] = override
			end,
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
		if name == "grug_mobs:capital_display" then
			mob._grug_capital_display = true
			return mob
		end
		function mob:yaw_to_pos(target)
			self.walk_target = {x = target.x, z = target.z}
		end
		function mob:set_velocity(value) self.velocity = value end
		function mob:set_yaw(yaw) self.yaw = yaw end
		--
		-- mobs_redo's own `set_animation` semantics, modelled exactly, because
		-- "one property write per change" is a claim of the work tick and a
		-- stub that counted every call would make it unmeasurable: api.lua:461
		-- returns without touching the object when the animation asked for is
		-- already the current one. `animation_writes` is therefore the number
		-- of CHANGES, which is what costs a client resend.
		--
		function mob:set_animation(anim, force)
			if anim == nil then return end
			if anim == self.animation_current and not force then return end
			self.animation_current = anim
			self.animation_writes = (self.animation_writes or 0) + 1
		end
		return mob
	end

	-- One boot: a fresh Lua environment for the production files, the same
	-- `world` underneath them.
	local function boot()
		harness = {players = {}, logs = {}, globalsteps = {}, mods_loaded = {},
			after = {}, clock = 1000, yaws = 0, defs = {}, paths = 0,
			trainer_clicks = {}}
		rawset(_G, "grug_jobs", {
			open_trainer = function(clicker, profession, pos)
				harness.trainer_clicks[#harness.trainer_clicks + 1] = {
					clicker = clicker, profession = profession, pos = pos}
			end,
		})
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
		function grug_mobs.configure_capital_display(entity)
			check(entity._grug_capital_display == true,
				"display configure received a mob")
			entity.object:set_yaw(entity._grug_face_yaw)
			harness.display_configures = (harness.display_configures or 0) + 1
		end
		function grug_mobs.ensure_tag_carrier(entity)
			entity._kat_tag_carrier = entity._kat_tag_carrier or {}
			return entity._kat_tag_carrier
		end
		harness.tags = {}
		function grug_mobs.set_plain_tag(entity, text)
			local row = harness.tags[entity] or {calls = 0}
			row.calls = row.calls + 1
			row.text = text
			harness.tags[entity] = row
			grug_mobs.ensure_tag_carrier(entity).text = text
		end
		rawset(_G, "grug_mobs", grug_mobs)

		rawset(_G, "vector", {
			new = function(x, y, z) return {x = x, y = y, z = z} end,
		})

		--
		-- The wield seam, as a RECORDER. `grug_visuals.apply_entity` is what
		-- `start_villagers.lua` hands a work resident's tool -- or, for `spar`,
		-- a weapon FAMILY and a bracket -- to, and the fixture only has to see
		-- the spec: composing a texture is the visuals lane's own KAT.
		-- `_grug_wield_item` is the field the real `apply_entity` writes, so
		-- the probe and this fixture read the same name.
		--
		harness.visuals = {}
		rawset(_G, "grug_visuals", {
			apply_entity = function(entity, spec)
				if type(spec) == "function" then spec = spec(entity) end
				harness.visuals[entity] = spec
				entity._grug_wield_item = spec.weapon or
					(spec.weapon_family and grug_gear.weapon_item(
						spec.weapon_family, spec.bracket or 1)) or nil
			end,
		})
		-- grug_gear's own naming rule, transcribed (see GLOBALS below):
		-- `grug_gear:<family>_<metal key of the bracket>`, the six material
		-- tiers of items_crafting.md section 3.0.3.
		local METALS = {"bronze", "iron", "steel", "silversteel", "embersteel",
			"abyssal_steel"}
		rawset(_G, "grug_gear", {
			weapon_item = function(family, bracket)
				local metal = METALS[bracket or 0]
				if type(family) ~= "string" or not metal then return nil end
				return "grug_gear:" .. family .. "_" .. metal
			end,
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
			if real_settlements then
				local out = {}
				for index = 1, #real_settlements do
					local row = real_settlements[index]
					out[index] = {race_id = row.race_id,
						faction_id = row.faction_id,
						anchor = {x = row.anchor.x, y = row.anchor.y,
							z = row.anchor.z}}
				end
				return out
			end
			return {{race_id = "dwarf", faction_id = "accord",
				anchor = {x = ANCHOR.x, y = ANCHOR.y, z = ANCHOR.z}}}
		end
		function grug_core.settlement_socket_settlements()
			if real_settlements then
				local out = {}
				for index = 1, #real_settlements do
					local row = real_settlements[index]
					out[index] = {key = row.key, race_id = row.race_id,
						anchor = {x = row.anchor.x, y = row.anchor.y,
							z = row.anchor.z}}
				end
				return out
			end
			return {
				{key = "hearthpine", race_id = "dwarf",
					anchor = {x = ANCHOR.x, y = ANCHOR.y, z = ANCHOR.z}},
				{key = "dur_brannoc", race_id = "dwarf",
					anchor = {x = CAPITAL.x, y = CAPITAL.y, z = CAPITAL.z}},
			}
		end
		local function real_row(key, race_id)
			if not real_settlements then return nil end
			for index = 1, #real_settlements do
				local row = real_settlements[index]
				if row.key == key or row.race_id == race_id then return row end
			end
			return nil
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
					-- Contract section 8.1; the registry validates it against
					-- the closed vocabulary before a consumer ever sees it
					-- (settlement_sockets_kat covers that half).
					activity = socket.activity,
					profession = socket.profession,
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
			if real_settlements then
				local row = real_row(nil, race_id)
				if not row then return {} end
				return compile(row.sockets, row.anchor)
			end
			if race_id ~= "dwarf" then return {} end
			return compile(SOCKETS, ANCHOR)
		end
		function grug_core.settlement_sockets_at(key)
			if real_settlements then
				local row = real_row(key, nil)
				if not row then return {} end
				return compile(row.sockets, row.anchor)
			end
			if key == "hearthpine" then return compile(SOCKETS, ANCHOR) end
			if key == "dur_brannoc" then return compile(CAPITAL_SOCKETS, CAPITAL) end
			return {}
		end
		function grug_core.start_anchor(_, race_id)
			if real_settlements then
				local row = real_row(nil, race_id)
				return row and {x = row.anchor.x, y = row.anchor.y,
					z = row.anchor.z} or nil
			end
			return {x = ANCHOR.x, y = ANCHOR.y, z = ANCHOR.z}
		end
		function grug_core.capital_anchor()
			-- In real mode there is no capital, and a published anchor that
			-- matched a start would make `settlement_kind` answer "capital".
			if real_settlements then return nil end
			return {x = CAPITAL.x, y = CAPITAL.y, z = CAPITAL.z}
		end
		function grug_core.start_ready() return harness.ready == true end
		function grug_core.register_on_starts_progress(fn)
			harness.progress = fn
		end
		function grug_core.set_tag_carrier_text(carrier, text)
			carrier.text = text
			return true
		end
		rawset(_G, "grug_core", grug_core)

		local core_api = {registered_entities = ENTITIES,
			-- The items a work resident may be handed (contract section 8.2).
			-- Transcribed here INDEPENDENTLY of start_villagers.lua's activity
			-- table, so a tool renamed on one side and not the other fails the
			-- startup audit this fixture then reads back.
			-- The wave-2 row adds no new TOOL name (`mine` reuses the bronze
			-- pick, `brew` the stick, `carve` the stone axe), and the one
			-- weapon it adds is resolved through grug_gear's own name builder,
			-- so the bronze sword is listed here for the audit to find.
			-- WAVE 3 (playtest round 5): `fish` no longer wields a stick but
			-- the real `grug_fishing:rod`; `brew` still stirs with the stick.
			registered_items = {
				["default:pick_bronze"] = true,
				["default:shovel_stone"] = true,
				["default:axe_stone"] = true,
				["default:stick"] = true,
				["grug_fishing:rod"] = true,
				["grug_gear:sword_bronze"] = true,
			},
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
		--
		-- TWO GLOBALS THIS FIXTURE NOW OFFERS (wave 2), and no more: the real
		-- `core.global_exists` is how `start_villagers.lua` probes an optional
		-- dependency without tripping strict.lua, and both of the things it
		-- probes for are things a wave-2 activity needs.
		--
		--   * `grug_visuals` -- the wield seam. Stubbed as a RECORDER, so the
		--     fixture can assert that a `mine` resident is handed its tool and
		--     a `spar` resident a weapon FAMILY at a bracket. Before this lane
		--     the fixture answered false and the whole seam was dead code here.
		--   * `grug_gear` -- the name builder the startup audit resolves that
		--     family through. Its `weapon_item` is TRANSCRIBED from
		--     grug_gear's own rule (`grug_gear:<family>_<metal of bracket>`)
		--     rather than loaded, exactly as `registered_items` above is, so a
		--     ladder renamed on one side and not the other fails the audit this
		--     fixture reads back.
		--
		local GLOBALS = {grug_visuals = true, grug_gear = true}
		function core_api.global_exists(name) return GLOBALS[name] == true end
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
			-- In real mode every start's envelope is loaded: that programme has
			-- no capital and nothing is gated behind an emerge.
			if real_settlements then
				if pos and pos.y < GROUND_Y then
					return {name = "default:stone"}
				end
				return {name = "air"}
			end
			if pos and pos.z > -2000 then
				if not capital_loaded then return nil end
				if capital_anchor_unloaded and pos.x == CAPITAL.x and
						pos.y == CAPITAL.y and pos.z == CAPITAL.z then return nil end
				if capital_outer_unloaded and pos.x >= CAPITAL.x + 80 then return nil end
			end
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
		grug_mobs.register_start_socket_role("mount_display", function()
			return "grug_mobs:capital_display"
		end)
		grug_mobs.register_start_socket_role("innkeeper", function(socket, start)
			return "grug_mobs:villager_" .. start.race_id
		end)
		grug_mobs.register_start_socket_role("trainer", function(socket, start)
			return "grug_mobs:villager_" .. start.race_id
		end)
		-- grug_traders owns the vendor role in the real game.
		grug_mobs.register_start_socket_role("vendor", function(socket, start)
			return "grug_traders:vendor_race_" .. start.race_id
		end)
		--
		-- THE RESTYLE HOOK, which exists because `core.add_entity` activates an
		-- entity synchronously: `after_activate` runs with none of the fields
		-- `install` is about to write. A profession vendor is DRAWN as the race
		-- of the settlement it stands in, read off `_grug_start`, so before the
		-- hook the first butcher in Hearthpine was composed as the Accord
		-- fallback and stayed human until the first reload (the review of round
		-- 3 found it). grug_traders is not part of this fixture, so what is
		-- recorded here is the ORDERING the fix hangs on: the hook is called,
		-- once per placement, and the fields are already there when it runs.
		--
		harness.restyled = {}
		grug_mobs.register_start_npc_restyle(function(entity)
			harness.restyled[#harness.restyled + 1] = {
				name = entity.name,
				start = entity._grug_start,
				socket = entity._grug_socket,
				role = entity._grug_socket_role,
				yaw = entity._grug_face_yaw,
			}
		end)
		--
		-- The carrier module owns observer updates centrally. This fixture records
		-- only the real activation-time text install; tools/r8_tags owns the
		-- observer and lifecycle rules.
		--
		-- The cached-player distance `levels.lua` publishes. The work tick asks
		-- it "is anybody close enough for this animation to be worth playing",
		-- the same question the vendor presence poll asks, and without it here
		-- the fixture could not tell the two halves of the tick apart: the walk
		-- home runs whatever the answer is, the animation does not.
		--
		function grug_mobs.nearest_player_d2(pos)
			local best
			for index = 1, #harness.players do
				local player = harness.players[index]
				local dx = pos.x - player.x
				local dy = pos.y - player.y
				local dz = pos.z - player.z
				local d2 = dx * dx + dy * dy + dz * dz
				if not best or d2 < best then best = d2 end
			end
			return best
		end
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
	-- The roster is
	-- what is placed, marked, capped and censused -- so a spare must not enter
	-- any of those counts.
	-- Sixteen of the nineteen sockets carry an entity: the loop's SECOND
	-- waypoint is route data (one guard walks the whole loop) and the SPARE
	-- idle socket is a wander target nobody lives on. Round 3 added four idle
	-- spawn sockets and two `work` sockets to the fixture, and the wave-2
	-- vocabulary lane two more `work` sockets (`mourn` and `spar`), which is
	-- where eight of the sixteen come from; this lane adds the trainer.
	local SLOTS = 16
	boot()
	check(#world.objects == 0, "something stood there before the first boot")
	become_ready()
	check(#world.objects == SLOTS,
		"cold placement count differs: " .. #world.objects)
	check(markers() == SLOTS, "cold marker count differs: " .. markers())
	check(harness.yaws >= SLOTS, "an NPC was placed without its authored facing")
	line("cold", #world.objects, markers(), logged("placed at socket"))

	-- The complete trainer path crosses both productive NPC files: build_rows
	-- carries the socket profession into a slot, install writes it onto the
	-- placed entity, and the villager definition's right-click opens that book.
	local trainer = entity_at("cooking_trainer")
	check(trainer ~= nil, "the trainer socket placed no villager")
	if trainer_mutation == 1 then trainer._grug_profession = nil end
	check(trainer._grug_profession == "cooking",
		"trainer placement lost the socket profession")
	local villager_def = harness.defs["grug_mobs:villager_dwarf"]
	local clicker = {name = "trainee"}
	villager_def.on_rightclick(trainer, clicker)
	local opened = harness.trainer_clicks[1]
	check(opened and opened.clicker == clicker and opened.profession == "cooking" and
		opened.pos.x == trainer.pos.x and opened.pos.z == trainer.pos.z,
		"trainer right-click did not open the socket profession")
	line("trainer", "socket", "placed", "profession_cooking", "rightclick_opened")

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
	--
	-- ROUND 3 BOUNDED THE RING (contract section 8.3), so "the spare is a
	-- wander target" is now a statement about the ring a resident is HANDED,
	-- not about the whole composition. The walker at idle_a keeps the four idle
	-- sockets within WALK_RADIUS = 20 of it -- idle_c, idle_e, idle_f and the
	-- spare -- and drops idle_b (23.0 nodes) and idle_d (26.1); the spare is
	-- the LAST of those five, because the ring keeps the authored order.
	--
	local spare_ring = entity_at("idle_a")._grug_idle_spots
	check(#spare_ring == 5,
		"the walker's bounded ring differs: " .. #spare_ring .. " spots")
	check(entity_at("idle_a")._grug_idle_spot == 1,
		"the walker was not re-based onto its own bounded ring")
	local spare_spot = spare_ring[5]
	check(math.abs(spare_spot.x - (ANCHOR.x - 4)) < 1e-9 and
		math.abs(spare_spot.z - (ANCHOR.z + 12)) < 1e-9,
		"the spare spot is not the authored one")
	check(spare_spot.spare == true, "the ring does not know its spare")
	--
	-- AND A STATIC RESIDENT'S RING IS THE SPARES AND NOTHING ELSE. idle_b is
	-- the second idle spawn socket, so it is static: its ring is itself plus
	-- the one spare within the radius, which is what makes its rare hop a hop
	-- to a place nobody lives rather than a trade of doorsteps.
	--
	local static_ring = entity_at("idle_b")._grug_idle_spots
	check(#static_ring == 2 and static_ring[2].spare == true,
		"a static resident's ring is not its socket plus the spares: " ..
		#static_ring)
	check(entity_at("idle_b")._grug_idle_spot == 1,
		"a static resident was pointed away from its own socket")
	line("spare", "unplaced", "unmarked", "walker_ring_5", "static_ring_2")

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
	local display = entity_at("market_stable/mount_t1")
	check(display ~= nil and display._grug_capital_display == true,
		"the capital did not place its plain display entity")
	check(type(display.set_yaw) == "nil",
		"the display fixture accidentally supplied a mobs_redo set_yaw method")
	check(math.abs(display.yaw - dir_to_yaw({x = 1, z = 0})) < 1e-9,
		"the plain display did not receive its authored ObjectRef yaw")
	check(harness.display_configures == 1,
		"the display appearance was configured more or less than once")
	local ordinary = entity_at("hall_guard")
	check(ordinary and ordinary.target_yaw == ordinary._grug_face_yaw,
		"ordinary mobs lost the pending-yaw cancellation on placement")
	line("capital_display", "plain_entity", "objectref_yaw", "configured_once",
		"mob_pending_yaw_preserved")
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
	-- 9. THE AMBLE, which since round 3 is what a WALKER does and nobody else.
	--    The two of them stand on their own sockets, i.e. the state in which
	--    every candidate home is occupied. Both must move.
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
	local ambling = {entity_at("idle_a"), entity_at("idle_f")}
	check(ambling[1] ~= nil and ambling[2] ~= nil, "the idle sockets are empty")
	check(ambling[1]._grug_walker == true and ambling[2]._grug_walker == true,
		"the every-fifth rule did not make the first and the sixth idle " ..
		"spawn socket walkers")
	-- FIVE spots each (playtest round 3): their own socket, the three idle
	-- sockets within WALK_RADIUS and the spare. The spare is what makes a hop
	-- possible at all while every home is occupied.
	check(#ambling[1]._grug_idle_spots == 5,
		"a start walker was given " .. #ambling[1]._grug_idle_spots ..
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
	--
	-- Found by the SPARE FLAG and not by a fixed index: round 3 bounds the ring
	-- per walker, so the spare's place in it is a property of where that walker
	-- lives, and an index written here would be a second, silently wrong copy
	-- of `bounded_spots`.
	--
	local reached_spare = false
	for index = 1, 2 do
		local spots = ambling[index]._grug_idle_spots
		for spot_index = 1, #spots do
			if spots[spot_index].spare and visited[index][spot_index] then
				reached_spare = true
			end
		end
	end
	check(reached_spare, "no walker ever reached the spare idle spot")
	check(ambling[1].state == "stand" or ambling[1].state == "walk",
		"an ambling villager left the idle states")
	line("amble", "moved_at_" .. moved_at,
		"spots_" .. count_visited(visited[1]) .. "_and_" ..
		count_visited(visited[2]) .. "_of_5", "spare_reached",
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
	-- THE COUNT ITSELF MAY NOT REACH THE REPORT. Two give-ups are guaranteed
	-- (one per SPOT_GIVE_UP window); whether the expired dwell adds a third
	-- depends on where the amble above left the dwell, which is a `math.random`
	-- roll -- and the two interpreters do not share an RNG. The header's rule
	-- for this fixture is that only facts that are the same on both are
	-- reported, so the assertion keeps the number and the line does not.
	blocked.blocked = false
	line("amble_blocked", "at_least_2_targets_in_40s")

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

	--
	-- 13. THE 80/20 SPLIT (contract section 8.3, user ruling of playtest round
	--     3). Deterministic, taken over the `idle` SPAWN sockets in authored
	--     order, and reported per settlement by the census the load probe and
	--     the engine probe both read.
	--
	--     The share is asserted against the contract's own band -- between 10
	--     and 30 percent of RESIDENTS -- so a composition that turned every
	--     resident into a static worker (zero walkers) fails here rather than
	--     shipping as a lifeless district.
	--
	local rows = grug_mobs.start_npc_census()
	local split
	for index = 1, #rows do
		if rows[index].key == "hearthpine" then split = rows[index] end
	end
	check(split ~= nil, "the census lost the start")
	-- Six idle spawn sockets and four work sockets: ten residents, of whom
	-- the first and the sixth idle one walk. (Two of the four work sockets are
	-- the wave-2 `mourn` and `spar` ones, which is why the share moved from
	-- 25.0 to 20.0 percent -- both inside the contract's band, and adding work
	-- sockets is exactly what lowers it.)
	check(split.residents == 10, "the census counts " ..
		tostring(split.residents) .. " residents, not 10")
	check(split.walkers == 2, "the census counts " .. tostring(split.walkers) ..
		" walkers, not 2")
	local share = split.walkers / split.residents * 100
	check(share >= 10 and share <= 30,
		"the walker share is " .. string.format("%.1f", share) ..
		" percent, outside the contract's 10 to 30")
	-- WHICH residents walk, by socket and not by count: every fifth idle spawn
	-- socket starting with the first, and no `work` socket ever.
	local walking = {}
	for _, socket_id in ipairs({"idle_a", "idle_b", "idle_c", "idle_d",
			"idle_e", "idle_f", "forge_work", "bench_work", "shrine_work",
			"yard_work"}) do
		local mob = entity_at(socket_id)
		check(mob ~= nil, "resident socket " .. socket_id .. " is empty")
		walking[#walking + 1] = socket_id .. "=" ..
			tostring(mob._grug_walker == true)
	end
	check(entity_at("idle_a")._grug_walker == true and
		entity_at("idle_f")._grug_walker == true and
		entity_at("idle_b")._grug_walker == false and
		entity_at("idle_c")._grug_walker == false and
		entity_at("idle_d")._grug_walker == false and
		entity_at("idle_e")._grug_walker == false and
		entity_at("forge_work")._grug_walker == false and
		entity_at("bench_work")._grug_walker == false and
		entity_at("shrine_work")._grug_walker == false and
		entity_at("yard_work")._grug_walker == false,
		"the every-fifth rule picked the wrong residents: " ..
		table.concat(walking, " "))
	line("walker_split", "residents_" .. split.residents,
		"walkers_" .. split.walkers,
		"share_" .. string.format("%.1f", share), table.concat(walking, " "))

	--
	-- 14. A STATIC IDLE RESIDENT DOES NOT WALK. A hundred and fifty seconds is
	--     seven times the walker's whole first dwell and still BELOW
	--     STATIC_DWELL_MIN = 180, so the claim is deterministic on both
	--     interpreters: whatever `math.random` rolled for this resident's dwell
	--     it is at least 180, and nothing may move inside the window. (The
	--     first-activation dwell cap is a walker's, for exactly this reason.)
	--
	local static = entity_at("idle_c")
	local static_origin = {x = static.pos.x, z = static.pos.z}
	for _ = 1, 150 do
		villager_def.do_custom(static, 1)
		advance(static, 1)
	end
	check(static.pos.x == static_origin.x and static.pos.z == static_origin.z,
		"a static idle resident walked away from its socket")
	check(static.state == "stand", "a static idle resident left the stand state")
	line("static_idle", "still_after_150s", "state_" .. static.state)

	--
	-- 15. THE WORK RESIDENT (contract sections 8.1 and 8.2).
	--
	--     What is asserted is exactly what the user's constraint is about: it
	--     stands on its socket, it faces the authored direction, it plays its
	--     activity's animation, it changes that animation only when the
	--     activity changes, it never asks the pathfinder, and it vetoes the
	--     rest of mobs_redo's step (`do_custom` returning exactly false), which
	--     is what stops `do_states` overwriting the animation once a second.
	--
	local smith = entity_at("forge_work")
	local sitter = entity_at("bench_work")
	-- A PLAYER BESIDE THEM, and the engine's block management run once, because
	-- an animation nobody can see is deliberately not played at all (the work
	-- tick's own "only while watched" rule, modelled on the vendor presence
	-- poll) and an object whose block is inactive has no position to work from.
	harness.players = {{x = smith.pos.x, y = smith.pos.y, z = smith.pos.z}}
	settle_activation()
	check(smith._grug_work_activity == "smith" and
		sitter._grug_work_activity == "sit",
		"a work resident did not receive its socket's activity")
	check(smith._grug_idle_spots == nil and sitter._grug_idle_spots == nil,
		"a work resident was handed a wander ring")
	check(smith._grug_socket_role == "work",
		"the placement engine did not publish the socket role")
	local paths_before = harness.paths
	local smith_origin = {x = smith.pos.x, z = smith.pos.z}
	local vetoed = 0
	for _ = 1, 120 do
		if villager_def.do_custom(smith, 1) == false then vetoed = vetoed + 1 end
		villager_def.do_custom(sitter, 1)
		advance(smith, 1)
		advance(sitter, 1)
	end
	check(vetoed == 120,
		"a work resident let mobs_redo run the rest of its step " ..
		vetoed .. " times in 120")
	check(smith.pos.x == smith_origin.x and smith.pos.z == smith_origin.z,
		"a work resident left its socket")
	check(harness.paths == paths_before,
		"a work resident asked the pathfinder " ..
		(harness.paths - paths_before) .. " times in 120 seconds")
	check(smith.animation_current == "work",
		"the smith is not playing the work animation but " ..
		tostring(smith.animation_current))
	check(sitter.animation_current == "sit",
		"the bench resident is not sitting but " ..
		tostring(sitter.animation_current))
	-- ONE ANIMATION WRITE for two minutes of hammering: mobs_redo's own
	-- set_animation writes nothing when the animation is already the one asked
	-- for, and nothing else in the work tick touches it.
	check(smith.animation_writes == 1,
		"the smith wrote its animation " .. tostring(smith.animation_writes) ..
		" times in 120 seconds")
	check(math.abs(smith.yaw - dir_to_yaw({x = 0, z = -1})) < 1e-9,
		"a work resident does not face its authored direction")
	--
	-- AND THE SWING IS TWO WRITES PER TEN SECONDS, not one per second. `fish`
	-- and `tend` stand with an occasional swing, which is the one activity
	-- shape that changes animation at all while it is being watched.
	--
	sitter._grug_work_activity = "tend"
	sitter.animation_writes = 0
	sitter.temp.grug_swing = 0
	for _ = 1, 30 do villager_def.do_custom(sitter, 1) end
	check(sitter.animation_writes >= 5 and sitter.animation_writes <= 7,
		"an occasional swing wrote its animation " ..
		sitter.animation_writes .. " times in 30 seconds, not six")
	--
	-- AND A DISPLACED WORK RESIDENT WALKS BACK. Things move an NPC -- a
	-- knockback, an admin teleport, an engine probe -- and a static resident
	-- that stayed where it was pushed would stand in the middle of a field for
	-- the life of the world. The round-3 engine probe found exactly that by
	-- moving the whole roster forty nodes: the walkers came home and the
	-- workers did not.
	--
	-- WITHOUT A PATHFINDER, which is the contract's rule for a static resident,
	-- and without the "is anybody watching" gate, because the correction has to
	-- have happened before the player arrives.
	--
	sitter._grug_work_activity = "sit"
	local pushed = entity_at("forge_work")
	local home = {x = pushed._grug_work_x, z = pushed._grug_work_z}
	pushed.pos.x = home.x + 8
	pushed.pos.z = home.z + 6
	-- A player 40 nodes away: inside the engine's activation radius, so the
	-- entity is in the environment and ticking, and OUTSIDE the work tick's own
	-- 24-node watch radius, so nothing about the animation may run. That band
	-- is exactly where a displaced resident has to correct itself.
	harness.players = {{x = pushed.pos.x + 40, y = pushed.pos.y,
		z = pushed.pos.z}}
	settle_activation()
	local paths_home = harness.paths
	local walked = 0
	for second = 1, 60 do
		villager_def.do_custom(pushed, 1)
		advance(pushed, 1)
		local dx, dz = pushed.pos.x - home.x, pushed.pos.z - home.z
		if walked == 0 and dx * dx + dz * dz <= 1.2 * 1.2 then
			walked = second
		end
	end
	check(walked > 0, "a displaced work resident never came home")
	check(harness.paths == paths_home,
		"the walk home asked the pathfinder " ..
		(harness.paths - paths_home) .. " times")
	-- HOME AND STANDING, not home and still jogging: out of the watch radius
	-- the tick plays no activity, and the one thing it does on arrival is stop.
	check(pushed.animation_current == "stand",
		"a work resident that came home out of sight is animated " ..
		tostring(pushed.animation_current))
	-- And it goes back to work the moment somebody is close enough to see it.
	harness.players = {{x = pushed.pos.x, y = pushed.pos.y, z = pushed.pos.z}}
	villager_def.do_custom(pushed, 1)
	check(pushed.animation_current == "work",
		"a work resident did not resume its activity when watched: " ..
		tostring(pushed.animation_current))
	line("work", "smith_work_anim", "sit_anim", "writes_1_in_120s",
		"swing_" .. sitter.animation_writes .. "_in_30s", "no_path",
		"step_vetoed_" .. vetoed, "home_at_" .. walked .. "s_unwatched",
		"resumed_when_watched")

	--
	-- 16. THE ANIMATION RANGES ARE THE MESH'S OWN, read out of the file that
	--     registers `character.b3d` rather than transcribed from a note. A
	--     wrong range is a villager stuck in a frame nobody authored, and it is
	--     invisible to every other test here.
	--
	local model_file = assert(io.open(repo ..
		"/mods/BASE/player_api/init.lua", "r"))
	local model_source = model_file:read("*a")
	model_file:close()
	local function model_range(name)
		local from, to = model_source:match(name ..
			"%s*=%s*{x%s*=%s*(%-?%d+),%s*y%s*=%s*(%-?%d+)")
		return tonumber(from), tonumber(to)
	end
	local anim = villager_def.animation
	local checks = {
		{"stand", "stand", anim.stand_start, anim.stand_end},
		{"walk", "walk", anim.walk_start, anim.walk_end},
		{"mine", "punch", anim.punch_start, anim.punch_end},
		{"mine", "work", anim.work_start, anim.work_end},
		{"sit", "sit", anim.sit_start, anim.sit_end},
	}
	local ranges = {}
	for _, row in ipairs(checks) do
		local from, to = model_range(row[1])
		check(from ~= nil and to ~= nil,
			"player_api registers no " .. row[1] .. " range")
		check(row[3] == from and row[4] == to,
			"the villager's " .. row[2] .. " animation is " ..
			tostring(row[3]) .. ".." .. tostring(row[4]) ..
			" and the mesh's " .. row[1] .. " is " .. from .. ".." .. to)
		ranges[#ranges + 1] = row[2] .. "=" .. from .. ".." .. to
	end
	-- The work swing is deliberately SLOWER than a punch: the same frames at a
	-- third of the speed is what reads as work rather than as a fight.
	check(anim.work_speed < anim.punch_speed,
		"the work swing is not slower than a punch")
	line("animation", table.concat(ranges, " "),
		"work_speed_" .. anim.work_speed)

	--
	-- 17. EVERY ACTIVITY OF THE CLOSED VOCABULARY IS IMPLEMENTED, and every
	--     tool it names is an item the game registers. The vocabulary is the
	--     registry's (contract section 8.2) and it is transcribed here rather
	--     than read off the implementation, so an activity that was added to
	--     the contract and forgotten here fails.
	--
	--     WAVE 2 (2026-09-15) added the second table of section 8.2 -- `mine`,
	--     `brew`, `carve`, `mourn`, `spar` and `forage` -- so the list below is
	--     fifteen names long and the two shapes neither of the first nine had
	--     get an assertion of their own: a bowed head and a weapon family.
	--
	local VOCABULARY = {"smith", "fish", "farm", "chop", "tend", "pray",
		"stall", "sit", "sweep",
		"mine", "brew", "carve", "mourn", "spar", "forage"}
	local ANIMS = {stand = true, walk = true, work = true, sit = true}
	local implemented = {}
	for _, name in ipairs(VOCABULARY) do
		local activity = grug_mobs.start_npc_activity(name)
		check(activity ~= nil, "no behaviour for the activity " .. name)
		check(ANIMS[activity.anim] == true,
			name .. " plays an animation the definition does not carry: " ..
			tostring(activity.anim))
		check(anim[activity.anim .. "_start"] ~= nil,
			name .. " names an animation the villager definition lacks")
		if activity.item then
			check(core.registered_items[activity.item] ~= nil,
				name .. " wields the unregistered " .. activity.item)
		end
		-- A weapon FAMILY is resolved through grug_gear's name builder, never
		-- spelled as an item (items_crafting.md section 3.0.3: the ladder is
		-- material-named and has no race axis, so "the settlement's tier-1
		-- weapon" is the T1 rung of a family).
		if activity.weapon_family then
			local resolved = grug_gear.weapon_item(activity.weapon_family,
				activity.bracket or 1)
			check(type(resolved) == "string" and
				core.registered_items[resolved] ~= nil,
				name .. " wields the unregistered " .. tostring(resolved))
			check(activity.item == nil,
				name .. " names both an item and a weapon family")
		end
		implemented[#implemented + 1] = name .. "=" .. activity.anim ..
			(activity.item and ("/" .. activity.item) or "") ..
			(activity.weapon_family and
				("/" .. activity.weapon_family .. "@" ..
					tostring(activity.bracket)) or "") ..
			(activity.bow and "/bow" or "")
	end
	-- `sweep` is the ONLY activity that moves, and since wave 2 `mourn` is the
	-- only one that bows (contract section 8.2).
	for _, name in ipairs(VOCABULARY) do
		local activity = grug_mobs.start_npc_activity(name)
		check((activity.sweep == true) == (name == "sweep"),
			name .. " disagrees with the contract about whether it moves")
		check((activity.bow == true) == (name == "mourn"),
			name .. " disagrees with the contract about the bowed head")
	end
	check(logged("work activities: tools 7, weapon families 1, " ..
		"all registered") == 1,
		"the activity tool audit did not report a clean roster")
	line("activities", table.concat(implemented, " "))

	--
	-- 17b. THE TWO WAVE-2 SHAPES, on the real residents the placement engine
	--      put on the two new sockets.
	--
	--      The MOURNER bows the mesh's own `Head` bone -- measured off
	--      `character.b3d`, which carries Head/Body/Arm_Left/Arm_Right/
	--      Leg_Left/Leg_Right -- with a RELATIVE rotation, so the override
	--      composes with the stand animation instead of replacing it, and it
	--      is written exactly ONCE for the life of an activation. (What the
	--      fixture cannot see is which way a negative pitch tips a head; that
	--      is the user's own playtest, and start_villagers.lua names the
	--      evidence for the sign.)
	--
	--      The SPARRING resident is handed a weapon FAMILY and a bracket
	--      rather than an item, and the visuals seam is what resolves it --
	--      which is the whole reason `grug_mobs` needs no grug_gear
	--      dependency for it.
	--
	local mourner = entity_at("shrine_work")
	local sparrer = entity_at("yard_work")
	check(mourner ~= nil and sparrer ~= nil,
		"the two wave-2 work sockets are empty")
	-- Ten more seconds of the real tick: it is idempotent, so the write count
	-- below is a claim about the whole activation and not about one call.
	harness.players[1] = {x = mourner.pos.x, y = mourner.pos.y,
		z = mourner.pos.z}
	for _ = 1, 10 do
		villager_def.do_custom(mourner, 1)
		villager_def.do_custom(sparrer, 1)
	end
	local override = (mourner.bone_overrides or {})["Head"]
	check(override ~= nil and override.rotation ~= nil,
		"the mourner never bowed its head")
	check(override.rotation.absolute ~= true,
		"the mourner's head override is absolute and would replace the " ..
		"stand animation instead of composing with it")
	check(override.rotation.vec.x < 0 and override.rotation.vec.y == 0 and
		override.rotation.vec.z == 0,
		"the mourner's head is rotated on the wrong axes")
	check(mourner.bone_writes == 1,
		"the mourner wrote its bone override " ..
		tostring(mourner.bone_writes) .. " times in one activation, not once")
	check((sparrer.bone_overrides or {})["Head"] == nil,
		"an activity other than mourn bowed a head")
	local spar_spec = harness.visuals[sparrer]
	check(spar_spec ~= nil and spar_spec.weapon == nil and
		spar_spec.weapon_family == "sword" and spar_spec.bracket == 1,
		"the sparring resident was not handed a tier-1 weapon family")
	check(sparrer._grug_wield_item == "grug_gear:sword_bronze",
		"the sparring resident holds " ..
		tostring(sparrer._grug_wield_item) .. " and not the tier-1 sword")
	--
	-- AND THE SPOKEN LINE FOLLOWS THE ACTIVITY WHERE NO TAG WAS AUTHORED.
	-- `shrine_work` carries no `tags` at all, `yard_work` carries `{"work"}`;
	-- the first must answer with its activity's line and the second with the
	-- authored tag's, or an untagged workplace would talk about nothing while
	-- standing at a grave.
	--
	check(mourner._grug_idle_tag == "mourn",
		"an untagged work socket answers with " ..
		tostring(mourner._grug_idle_tag) .. " and not its activity")
	check(sparrer._grug_idle_tag == "work",
		"a tagged work socket lost its authored tag")
	local lines = {}
	for _, key in ipairs({"mine", "brew", "carve", "mourn", "spar", "forage",
			"shade"}) do
		local text = grug_mobs.start_npc_line("dwarf", key)
		local fallback = grug_mobs.start_npc_line("dwarf", "no_such_tag")
		check(type(text) == "string" and text ~= "" and text ~= fallback,
			"the dwarf has no line of its own for " .. key)
		lines[#lines + 1] = key
	end
	line("wave2_activities", "mourn_bow_writes_" .. mourner.bone_writes,
		"spar_" .. tostring(sparrer._grug_wield_item),
		"tag_" .. mourner._grug_idle_tag .. "/" .. sparrer._grug_idle_tag,
		"lines_" .. table.concat(lines, ","))

	--
	-- 18. EVERY PEACEFUL FAMILY installs its carrier text on activation, and
	--     its ordinary ticks do not repeat that work. Observer/lifecycle work
	--     belongs to the one central carrier pass (tools/r8_tags/kat.lua).
	--
	local elder_def = harness.defs["grug_mobs:elder_dwarf"]
	check(elder_def.do_custom ~= nil, "the quest shell has no tick to gate on")
	local elder = entity_at("hall_quest")
	local walker_npc = entity_at("idle_a")
	local before = {}
	for _, mob in ipairs({elder, walker_npc, smith}) do
		before[mob] = (harness.tags[mob] and harness.tags[mob].calls) or 0
	end
	for _ = 1, 10 do
		elder_def.do_custom(elder, 1)
		villager_def.do_custom(walker_npc, 1)
		villager_def.do_custom(smith, 1)
	end
	local tagged = {}
	for _, row in ipairs({{"elder", elder, "Vale Elder"},
			{"walker", walker_npc, "Vale Dwarf"},
			{"work", smith, "Vale Dwarf"}}) do
		local seen = harness.tags[row[2]]
		check(seen ~= nil and seen.calls - before[row[2]] == 0,
			"the " .. row[1] .. " repeated its carrier text install " ..
			tostring(seen and seen.calls - before[row[2]]) .. " times")
		check(seen.text == row[3],
			"the " .. row[1] .. " installed " ..
			tostring(seen.text) .. " and not " .. row[3])
		tagged[#tagged + 1] = row[1] .. "=" .. seen.text
	end
	-- mobs_redo's own update_tag refreshes the carrier text, never the parent.
	elder._grug_tag_want = nil
	elder:update_tag()
	check(elder._grug_tag_want == "Vale Elder",
		"update_tag no longer refreshes the desired nametag text")
	check(harness.tags[elder].calls - before[elder] == 1,
		"update_tag did not reach the carrier text seam")
	line("tag_carrier", table.concat(tagged, " "), "central_observers")

	--
	-- 19. THE RESTYLE HOOK RUNS AFTER `install` (the review's F2). What it is
	--     for is `grug_traders`' profession vendors, whose race is a property
	--     of the SETTLEMENT and therefore unknowable until `_grug_start` is
	--     written -- and `core.add_entity` activates the entity, and with it
	--     `after_activate` and the visuals composition, before that happens.
	--     This fixture does not load grug_traders, so what it holds is the
	--     ordering the fix hangs on: every placement calls the hook exactly
	--     once, and the fields are already on the entity when it does.
	--
	--     The count is not compared against a literal: this fixture boots
	--     several times and the last boot placed the start AND the capital, so
	--     what is asserted is that every recorded call already carried the
	--     fields -- one missing field is the whole defect.
	check(#harness.restyled >= SLOTS,
		"the restyle hook ran " .. #harness.restyled ..
		" times for at least " .. SLOTS .. " placements")
	local settlements_restyled = {}
	for index = 1, #harness.restyled do
		local row = harness.restyled[index]
		check(type(row.start) == "string" and row.start ~= "" and
			type(row.socket) == "string" and row.socket ~= "" and
			type(row.role) == "string" and type(row.yaw) == "number",
			"the restyle hook ran before install wrote the placement fields " ..
			"(" .. tostring(row.name) .. " " .. tostring(row.start) .. "/" ..
			tostring(row.socket) .. "/" .. tostring(row.role) .. ")")
		settlements_restyled[row.start] = true
	end
	check(settlements_restyled.hearthpine and settlements_restyled.dur_brannoc,
		"the restyle hook did not run for both settlements")
	line("restyle_hook", "calls_" .. #harness.restyled,
		"start_and_capital", "after_install")

	--
	-- 20. THE SIX REAL COMPOSITIONS. Everything above is a synthetic
	--     settlement, which is the right shape for the marker, twin and unload
	--     states. The 80/20 rule and the bounded ring are about the
	--     settlements that SHIP, and the review found what that difference
	--     hides: Stillgrave's walker stands at `idle_warden_door`, its nearest
	--     other idle socket is 27.7 nodes away, and a hard WALK_RADIUS handed
	--     it a ring of ONE -- `next_spot` then returns the same index for
	--     ever, so the settlement had no moving resident at all and every
	--     synthetic state still passed.
	--
	--     So the real placement engine is booted a second time over the six
	--     starts' own authored socket tables, read out of the same blueprints
	--     `blueprint_kat` reads, and three things are asserted per start: every
	--     walker's ring has at least two entries, the walker share is inside
	--     the contract's 10-30 percent band, and every work resident got its
	--     activity.
	--
	local sockets_of = {}
	for _, key in ipairs(START_ORDER) do
		local build = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_" ..
			key .. "_blueprint.lua")
		local blueprint = build()
		sockets_of[key] = assert(blueprint.landmarks.sockets,
			key .. " exports no socket landmarks")
	end
	real_settlements = {}
	for index, key in ipairs(START_ORDER) do
		local race = START_RACE[key]
		real_settlements[index] = {key = key, race_id = race,
			faction_id = RACE_FACTION[race],
			-- Far enough apart that no settlement's scan radius reaches
			-- another's; a socket is anchor-relative and the ring is measured
			-- in world space against the same anchor, so the real anchors would
			-- prove nothing extra.
			anchor = {x = index * 4000, y = ANCHOR.y, z = 0},
			sockets = sockets_of[key]}
	end
	world = {storage = {}, objects = {}}
	boot()
	become_ready()
	local rings = {}
	local worst_ring = nil
	for index = 1, #real_settlements do
		local row = real_settlements[index]
		local walkers, residents, works, min_ring = 0, 0, 0, nil
		for object_index = 1, #world.objects do
			local mob = world.objects[object_index].mob
			if mob._grug_start == row.key then
				if mob._grug_socket_role == "idle" then
					residents = residents + 1
					if mob._grug_walker == true then
						walkers = walkers + 1
						local size = #(mob._grug_idle_spots or {})
						if not min_ring or size < min_ring then
							min_ring = size
						end
						if not worst_ring or size < worst_ring then
							worst_ring = size
						end
						check(size >= 2,
							row.key .. " gave its walker on " ..
							tostring(mob._grug_socket) .. " a ring of " ..
							size .. ": it can never move")
					end
				elseif mob._grug_socket_role == "work" then
					residents = residents + 1
					works = works + 1
					check(type(mob._grug_work_activity) == "string",
						row.key .. " placed a work resident with no activity")
				end
			end
		end
		check(residents > 0, row.key .. " placed no resident at all")
		check(walkers > 0, row.key .. " has no walking resident")
		local share = walkers / residents * 100
		check(share >= 10 and share <= 30,
			row.key .. " has a walker share of " ..
			string.format("%.1f", share) .. " percent of " .. residents ..
			" residents")
		rings[#rings + 1] = row.key .. "=" .. walkers .. "/" .. residents ..
			":work_" .. works .. ":ring_" .. tostring(min_ring)
	end
	line("real_starts", table.concat(rings, " "),
		"min_walker_ring_" .. tostring(worst_ring))

	-- A capital's anchor authenticates the settlement once per server session.
	-- Its outer districts load later as the player walks away from the core; by
	-- then the anchor mapblock may be unloaded. Pending trainers must still be
	-- served from their own newly loaded block.
	real_settlements = nil
	world = {storage = {}, objects = {}}
	capital_loaded = true
	capital_anchor_unloaded = false
	capital_outer_unloaded = true
	boot()
	step(5)
	check(entity_at("outer_cooking/cooking") == nil,
		"the unloaded outer trainer was placed early")
	capital_anchor_unloaded = true
	capital_outer_unloaded = false
	step(5)
	check(entity_at("outer_cooking/cooking") ~= nil,
		"the pending outer trainer required the anchor and shop simultaneously")
	line("capital_pending", "anchor_latched", "outer_trainer_placed")
	world = {storage = {['startnpc:dur_brannoc:hall_guard'] = '1'}, objects = {}}
	capital_anchor_unloaded = true
	capital_outer_unloaded = false
	boot()
	step(5)
	check(entity_at("outer_cooking/cooking") ~= nil,
		"a persisted capital marker did not restore outer-shop service after restart")
	line("capital_restart", "marker_restored_readiness", "outer_trainer_placed")
	world = {storage = {}, objects = {}}
	capital_anchor_unloaded = true
	capital_outer_unloaded = false
	boot()
	step(5)
	check(entity_at("outer_cooking/cooking") ~= nil,
		"a direct first arrival at the outer district still required the core")
	line("capital_direct_outer", "socket_block_authenticated",
		"outer_trainer_placed")

	-- Round 17: the same production roster claims, names and dispatches an innkeeper.
	SOCKETS[#SOCKETS + 1] = {id="home_innkeeper",role="innkeeper",x=12,y=1,z=12,
		dir={x=0,z=1},tags={"door"}}
	world = {storage={},objects={}}
	boot()
	become_ready()
	local keeper = entity_at("home_innkeeper")
	check(keeper and keeper._grug_npc_name == "Innkeeper", "innkeeper placement/name failed")
	check(keeper._grug_walker == false and not keeper._grug_idle_spots,
		"innkeeper joined the citizen amble")
	local opened_home = false
	rawset(_G,"grug_home",{open_innkeeper=function(p,e)
		opened_home = p == clicker and e == keeper
	end})
	harness.defs["grug_mobs:villager_dwarf"].on_rightclick(keeper,clicker)
	check(opened_home,"innkeeper right-click did not dispatch HOME")
	line("innkeeper","claimed","stationary","named","rightclick_home")

	restore()
	return table.concat(report)
end
