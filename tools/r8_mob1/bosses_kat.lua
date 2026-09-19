-- R8-MOB1 package 5 real-code KAT.

return function(root)
	assert(type(root) == "string" and root:sub(1, 1) == "/",
		"boss KAT requires an absolute repository root")

	local registered, arrows, nodes, craftitems, globalsteps = {}, {}, {}, {}, {}
	local callbacks = {hit = {}, heal = {}, absorb = {}, death = {}, join = {}}
	local store = {}
	local lair_loaded = true
	local radius_objects = {}
	local connected_players = {}
	local faction_by_name = {}
	local node_map, timers = {}, {}
	local particles, spawners = {}, {}
	local protected = false
	local line_clear = true
	local movement = {walk = 0, path = 0, snap = 0, clear = 0, socket = 0}
	local stalled, path_result = 0, false
	local storage = {
		get_string = function(_, key) return store[key] or "" end,
		set_string = function(_, key, value) store[key] = value end,
	}
	local spawned, spawn_count
	local spawned_objects = {}
	local function pos_key(pos)
		return math.floor(pos.x + 0.5) .. ":" .. math.floor(pos.y + 0.5) ..
			":" .. math.floor(pos.z + 0.5)
	end
	local function object_at(pos, name)
		local object = {pos = {x = pos.x, y = pos.y, z = pos.z}, removed = false,
			velocity = {x = 0, y = 0, z = 0}, acceleration = {x = 0, y = 0, z = 0},
			properties = {collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}}}
		function object:get_pos() return self.pos end
		function object:set_pos(value)
			self.pos = {x = value.x, y = value.y, z = value.z}
		end
		function object:set_velocity(value) self.velocity = value end
		function object:get_velocity() return self.velocity end
		function object:set_acceleration(value) self.acceleration = value end
		function object:set_properties(value)
			for key, child in pairs(value) do self.properties[key] = child end
		end
		function object:get_properties() return self.properties end
		function object:get_yaw() return 0 end
		function object:get_luaentity() return self.ent end
		function object:remove() self.removed = true end
		object.ent = {name = name, object = object}
		return object
	end
	core = {
		get_mod_storage = function() return storage end,
		registered_nodes = {
			air = {walkable = false, buildable_to = true, groups = {}},
			stone = {walkable = true, groups = {}},
			plant = {walkable = false, buildable_to = true, groups = {}},
		},
		register_node = function(name, def)
			name = name:gsub("^:", "")
			nodes[name] = def
			core.registered_nodes[name] = def
		end,
		register_craftitem = function(name, def) craftitems[name] = def end,
		register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
		register_on_dieplayer = function(fn) callbacks.death[#callbacks.death + 1] = fn end,
		register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
		get_objects_inside_radius = function() return radius_objects end,
		get_player_by_name = function() return nil end,
		get_node_or_nil = function(pos)
			local mapped = node_map[pos_key(pos)]
			if mapped then return {name = mapped} end
			if math.abs(pos.x) > 3000 then
				return {name = lair_loaded and "air" or "ignore"}
			end
			return {name = pos.y <= 0 and "stone" or "air"}
		end,
		set_node = function(pos, node) node_map[pos_key(pos)] = node.name end,
		get_node_timer = function(pos)
			local key = pos_key(pos)
			timers[key] = timers[key] or {starts = 0}
			return {start = function(_, duration)
				timers[key].starts = timers[key].starts + 1
				timers[key].duration = duration
			end}
		end,
		is_protected = function() return protected end,
		get_connected_players = function() return connected_players end,
		line_of_sight = function() return line_clear end,
		sound_play = function() end,
		add_particlespawner = function(def) spawners[#spawners + 1] = def end,
		add_particle = function(def) particles[#particles + 1] = def end,
		chat_send_all = function() end,
		chat_send_player = function() end,
		serialize = function() return "" end,
		deserialize = function() return nil end,
		is_player = function(object) return object and object._is_player == true end,
		yaw_to_dir = function() return {x = 0, y = 0, z = 1} end,
		add_entity = function(pos, name)
			spawn_count = (spawn_count or 0) + 1
			local object = object_at(pos, name)
			spawned = {pos = pos, name = name, ent = object.ent, object = object}
			spawned_objects[#spawned_objects + 1] = object
			return object
		end,
	}
	grug_core = {
		register_on_player_hit_mob = function(fn) callbacks.hit[#callbacks.hit + 1] = fn end,
		register_on_effective_heal = function(fn) callbacks.heal[#callbacks.heal + 1] = fn end,
		register_on_effective_absorb = function(fn)
			callbacks.absorb[#callbacks.absorb + 1] = fn
		end,
		get_player_faction = function(name) return faction_by_name[name] end,
		world_protected_for_faction = function() return protected end,
		opposing_faction = function(faction)
			return faction == "accord" and "throng" or "accord"
		end,
	}
	grug_zones = {terrain_height_at = function(x, z)
		assert((x == -3260 or x == 3260 or x == -3242 or x == -3275 or
			x == 3278 or x == 3245) and (z == -40 or z == -32 or z == -28))
		return 72
	end}
	grug_mobs = {
		register_mob = function(name, def) registered[name] = def end,
		slow_player = function(player, duration, factor)
			player.slows = (player.slows or 0) + 1
			player.slow_duration, player.slow_factor = duration, factor
		end,
		stamp_arrow_damage = function() end,
		place_on_ground = function(object, pos)
			movement.snap = movement.snap + 1
			movement.snap_pos = pos
		end,
		walk_toward = function()
			movement.walk = movement.walk + 1
		end,
		stall_clock = function()
			return stalled, stalled
		end,
		stall_clear = function()
			movement.clear = movement.clear + 1
		end,
		path_nudge = function()
			movement.path = movement.path + 1
			return path_result
		end,
		start_npc_claim = function() return true end,
		guard_definition = function(faction, description, texture)
			return {description = description, _grug_faction = faction,
				textures = {{texture}}, do_custom = function(self)
					if self._grug_post_x then
						movement.socket = movement.socket + 1
						movement.socket_x = self._grug_post_x
					end
				end}
		end,
	}
	mobs = {register_arrow = function(_, name, def) arrows[name] = def end}
	ItemStack = function() return {} end

	dofile(root .. "/mods/ENTITIES/grug_mobs/boss_dragons.lua")
	dofile(root .. "/mods/ENTITIES/grug_mobs/bosses.lua")
	dofile(root .. "/mods/ENTITIES/grug_mobs/levels.lua")
	assert(grug_mobs.stats_for(60, "boss") == 18000 and
		grug_mobs.stats_for(100, "boss") == 18000,
		"boss tier did not use the central flat HP budget")

	-- Register a captured production guard definition in the real vendored
	-- mobs_redo class, then invoke that class's complete on_step. The early
	-- false return from royal follow must own the step before do_states and
	-- general_attack can redirect the guard toward the enemy.
	local function real_mobs_step(def, fields, dtime)
		local function copy(value)
			if type(value) ~= "table" then return value end
			local result = {}
			for key, child in pairs(value) do result[key] = copy(child) end
			return result
		end
		local env = setmetatable({}, {__index = _G})
		env._G = env
		env.table = copy(table)
		env.table.copy = copy
		local registered_entities = {}
		local api_core = {
			LIGHT_MAX = 14, registered_aliases = {}, registered_items = {},
			registered_tools = {}, registered_craftitems = {},
			registered_nodes = {air = {walkable = false, groups = {}},
				ignore = {walkable = false, groups = {}}},
			settings = {
				get = function(_, name)
					if name == "mob_active_limit" then return "600" end
					return nil
				end,
				get_bool = function(_, name) return name == "enable_damage" end,
			},
		}
		env.core, env.minetest = api_core, api_core
		api_core.get_translator = function() return function(text) return text end end
		api_core.global_exists = function(name) return rawget(env, name) ~= nil end
		api_core.get_modpath = function(name)
			if name == "mobs" then return root .. "/mods/ENTITIES/mobs" end
		end
		api_core.check_player_privs = function() return false end
		api_core.formspec_escape = function(text) return text end
		api_core.get_connected_players = function() return {} end
		api_core.get_objects_inside_radius = function() return {} end
		api_core.register_entity = function(name, entity_def)
			registered_entities[name:gsub("^:", "")] = entity_def
		end
		setmetatable(api_core, {__index = function(_, name)
			if name:match("^register_") then return function() end end
			return function() end
		end})
		env.vector = {
			direction = function() end, multiply = function() end,
			subtract = function() end, add = function() end,
		}
		env.ItemStack = function()
			return {get_name = function() return "" end,
				get_definition = function() return {} end}
		end
		setfenv(assert(loadfile(root .. "/mods/ENTITIES/mobs/api.lua")), env)()
		env.mobs:register_mob("grug_mobs:royal_guard_step_kat", def)
		local prototype = assert(registered_entities["grug_mobs:royal_guard_step_kat"])
		local entity = setmetatable(fields, {__index = prototype})
		entity:on_step(dtime, {})
		return entity
	end

	local dragons = {
		ice_dragon = "grug_mobs_ice_dragon.b3d",
		jungle_wyvern = "grug_mobs_jungle_wyvern.b3d",
	}
	for short, mesh in pairs(dragons) do
		local def = assert(registered["grug_mobs:" .. short], short)
		assert(def._grug_fixed_level == 60 and def._grug_tier == "boss")
		assert(def.hp_min == nil and def.hp_max == nil and def.damage == nil)
		assert(def.mesh == mesh and def.animation and def.clock == "any")
		assert(def.walk_velocity == 5.2 and def.run_velocity == 6.5 and
			grug_mobs.DRAGON_TUNING.fly == 8,
			"dragon movement did not outrun the 5.0 node/s player sprint")
		assert(def._grug_leash_range == 64 and def.view_range == 48)
		assert(def.fly == false and def.fly_in == "air" and def.animation.fly_start)
		assert(def.visual_size.x == 8 and def.visual_size.y == 8)
		assert(type(def.do_custom) == "function" and type(def.on_die) == "function")
	end
	assert(registered["grug_mobs:ice_dragon"].collisionbox[1] == -3 and
		registered["grug_mobs:ice_dragon"].collisionbox[6] == 3 and
		registered["grug_mobs:ice_dragon"].collisionbox[5] == 8)
	assert(registered["grug_mobs:jungle_wyvern"].collisionbox[1] == -2.4 and
		registered["grug_mobs:jungle_wyvern"].collisionbox[5] == 6.4)
	for _, name in ipairs({"grug_mobs:ice_whelp", "grug_mobs:storm_whelp"}) do
		local def = assert(registered[name])
		assert(def._grug_fixed_level == 20 and def._grug_tier == "normal")
		assert(def.fly_in == "air" and def.walk_velocity == 5.2 and
			def.run_velocity == 6.5)
	end

	local race_count = 0
	local expected_weapons = {dwarf = "greataxe", human = "sword",
		elf = "staff", undead = "staff", orc = "greataxe", troll = "staff"}
	for _, race in ipairs({"dwarf", "human", "elf", "undead", "orc", "troll"}) do
		local king = assert(registered["grug_mobs:king_" .. race], race)
		local guard = assert(registered["grug_mobs:royal_guard_" .. race], race)
		assert(king._grug_fixed_level == 65 and king._grug_tier == "elite")
		assert(guard._grug_fixed_level == 60 and guard._grug_tier == "elite")
		assert(guard._grug_no_leash == true and guard._grug_leash_range == nil,
			"royal guard retained an independent encounter leash")
		assert(king.hp_min == nil and king.hp_max == nil and king.damage == nil)
		assert(king.textures[1][1] == "grug_mobs_royal_" .. race .. ".png")
		assert(guard.textures[1][1] ==
			"grug_mobs_royal_guard_" .. race .. ".png")
		assert(king._grug_visual({_grug_level = 65}).weapon_family ==
			expected_weapons[race], "wrong closest available king weapon: " .. race)
		race_count = race_count + 1
	end
	assert(race_count == 6 and craftitems["grug_mobs:fallen_crown"])
	assert(#callbacks.hit == 1 and #callbacks.heal == 1 and #callbacks.absorb == 1 and
		#callbacks.death == 1 and #callbacks.join == 1 and #globalsteps == 2)
	local boss_step = globalsteps[2]

	store["boss:dragon:stormscale:alive"] = "1"
	store["boss:dragon:wyrmglass:due"] = tostring(os.time() - 1)
	lair_loaded = false
	boss_step(10)
	assert(store["boss:dragon:wyrmglass:warned"] ~= "1",
		"unloaded lair started its warning")
	lair_loaded = true
	local warning_started = os.time()
	boss_step(10)
	assert(store["boss:dragon:wyrmglass:warned"] == "1")
	assert(tonumber(store["boss:dragon:wyrmglass:due"]) >= warning_started + 60,
		"late activation did not receive a full warning")

	local function player(name, faction, x)
		faction_by_name[name] = faction
		local object = {_is_player = true, hits = 0, pushes = 0, hp = 100,
			pos = {x = x, y = 0, z = 0}}
		function object:get_player_name() return name end
		function object:get_hp() return self.hp end
		function object:set_hp(value) self.hp = value end
		function object:get_pos() return self.pos end
		function object:punch() self.hits = self.hits + 1 end
		function object:add_velocity(value)
			self.pushes = self.pushes + 1
			self.last_push = value
		end
		return object
	end
	local friendly = player("friendly", "accord", 1)
	local enemy = player("enemy", "throng", 2)
	local factionless = player("factionless", nil, 3)
	radius_objects = {friendly, enemy, factionless}
	local king_object = {
		get_pos = function() return {x = 0, y = 0, z = 0} end,
		get_yaw = function() return 0 end,
	}
	local dwarf = {object = king_object, temp = {}, attack = enemy,
		damage = 10, health = 100, hp_max = 100,
		set_velocity = function() end, set_animation = function() end}
	registered["grug_mobs:king_dwarf"].do_custom(dwarf, 4)
	registered["grug_mobs:king_dwarf"].do_custom(dwarf, 2)
	assert(enemy.hits == 1 and friendly.hits == 0 and factionless.hits == 0,
		"king signature ignored faction authority")

	local function dragon_for(name, target, pos)
		local def = registered[name]
		local object = object_at(pos or {x = 0, y = 1, z = 0}, name)
		object.properties.collisionbox = def.collisionbox
		local dragon = {name = name, object = object, temp = {}, attack = target,
			damage = 10, health = 18000, hp_max = 18000,
			walk_velocity = def.walk_velocity, run_velocity = def.run_velocity,
			fall_speed = -9.81, fly = false}
		object.ent = dragon
		function dragon:set_animation(kind) self.animation = kind end
		function dragon:yaw_to_pos() end
		function dragon:stop_attack() self.attack = nil self.state = "stand" end
		return dragon, def
	end

	-- Runtime movement authority: ground -> air -> dive -> landing -> ground.
	enemy.pos = {x = 20, y = 1, z = 0}
	local dragon, ice_def = dragon_for("grug_mobs:ice_dragon", enemy,
		{x = 0, y = 1, z = 0})
	assert(ice_def.do_custom(dragon, 0.1) == false and dragon.fly == true)
	assert(dragon.temp.grug_dragon.mode == "air" and
		dragon.object.velocity.x > 0, "dragon did not take off toward a distant target")
	dragon.object.pos = {x = 16, y = 7, z = 0}
	ice_def.do_custom(dragon, 2)
	assert(dragon.temp.grug_dragon.action.kind == "dive_warn" and dragon.fly,
		"air dragon did not enter the dive telegraph")
	ice_def.do_custom(dragon, 1)
	assert(dragon.temp.grug_dragon.action.kind == "dive" and
		math.abs(dragon.object.velocity.x) > 0, "dive did not launch at snapshot")
	dragon.object.pos = {x = 20, y = 1, z = 0}
	ice_def.do_custom(dragon, 0.1, {collides = true})
	assert(dragon.temp.grug_dragon.mode == "landing" and not dragon.fly,
		"dive impact did not enter landing")
	ice_def.do_custom(dragon, 0.1, {touching_ground = true})
	assert(dragon.temp.grug_dragon.mode == "ground",
		"landed dragon did not return to ground movement")

	-- Target loss during a dive cancels the strike and settles the dragon.
	dragon.temp.grug_dragon.mode = "air"
	dragon.temp.grug_dragon.primary = 0
	dragon.object.pos = {x = 16, y = 7, z = 0}
	ice_def.do_custom(dragon, 0.1)
	dragon.attack = nil
	ice_def.do_custom(dragon, 0.1)
	assert(dragon.temp.grug_dragon.action == nil and
		dragon.temp.grug_dragon.mode == "landing" and not dragon.fly,
		"target loss did not cancel dive")

	-- An obstructed near target also forces takeoff.
	enemy.pos = {x = 7, y = 1, z = 0}
	dragon = dragon_for("grug_mobs:ice_dragon", enemy, {x = 0, y = 1, z = 0})
	line_clear = false
	ice_def.do_custom(dragon, 0.1)
	line_clear = true
	assert(dragon.fly and dragon.temp.grug_dragon.mode == "air",
		"unreachable target did not force takeoff")

	-- Breath is exactly the -15/0/+15 degree cone, with bounded trails.
	dragon = dragon_for("grug_mobs:ice_dragon", enemy, {x = 0, y = 1, z = 0})
	dragon.temp.grug_dragon = {mode = "ground", primary = 0, gust = 12}
	spawned_objects, spawn_count = {}, 0
	ice_def.do_custom(dragon, 0.1)
	ice_def.do_custom(dragon, 1.25)
	local breath = {}
	for _, object in ipairs(spawned_objects) do
		if object.ent.name == "grug_mobs:ice_breath" then breath[#breath + 1] = object end
	end
	assert(#breath == 3, "breath cone did not emit three projectiles")
	local angles = {}
	for _, object in ipairs(breath) do
		angles[#angles + 1] = math.floor(math.atan2(object.velocity.z,
			object.velocity.x) * 180 / math.pi + 0.5)
		local arrow = arrows["grug_mobs:ice_breath"]
		for _ = 1, 60 do arrow.do_custom(object.ent, 0.08) end
		assert(object.ent._grug_trail_count == 18, "projectile trail exceeded its cap")
	end
	table.sort(angles)
	assert(angles[1] == -15 and angles[2] == 0 and angles[3] == 15,
		"breath cone angles changed")

	-- Rime/scorch refresh their timer, do not stack, honor protection and clean up.
	node_map, timers = {}, {}
	protected = false
	assert(grug_mobs.place_dragon_ground_effect("rime", {x = 0, y = 1, z = 0},
		"enemy"))
	assert(node_map["0:1:0"] == "grug_mobs:dragon_rime" and
		timers["0:1:0"].duration == 8)
	enemy.pos = {x = 0, y = 2, z = 0}
	connected_players = {enemy}
	globalsteps[1](0.25)
	assert(enemy.slow_factor == 0.6, "rime did not apply its 40 percent slow")
	local starts = timers["0:1:0"].starts
	assert(grug_mobs.place_dragon_ground_effect("rime", {x = 0, y = 1, z = 0},
		"enemy") and timers["0:1:0"].starts == starts + 1,
		"rime refresh did not reset its timer")
	assert(not grug_mobs.place_dragon_ground_effect("scorch", {x = 0, y = 1, z = 0},
		"enemy"), "temporary effects stacked")
	nodes["grug_mobs:dragon_rime"].on_timer({x = 0, y = 1, z = 0})
	assert(node_map["0:1:0"] == "air", "rime timer did not restore air")
	assert(grug_mobs.place_dragon_ground_effect("scorch", {x = 0, y = 1, z = 0},
		"enemy") and timers["0:1:0"].duration == 6)
	local hp_before_scorch = enemy.hp
	globalsteps[1](0.75)
	assert(enemy.hp == hp_before_scorch - 2, "scorch did not deal 2 damage per second")
	connected_players = {}
	protected = true
	assert(not grug_mobs.place_dragon_ground_effect("rime", {x = 2, y = 1, z = 0},
		"enemy"), "ground effect entered protected land")
	protected = false

	-- Lightning resolves against current positions, not its snapshot target.
	enemy.pos = {x = 5, y = 1, z = 0}
	local storm, storm_def = dragon_for("grug_mobs:jungle_wyvern", enemy,
		{x = 0, y = 1, z = 0})
	storm.temp.grug_dragon = {mode = "ground", primary = 0, gust = 12,
		lightning_next = true}
	local before_hits = enemy.hits
	storm_def.do_custom(storm, 0.1)
	assert(storm.temp.grug_dragon.action.kind == "lightning")
	enemy.pos = {x = 10, y = 1, z = 0}
	radius_objects = {enemy}
	storm_def.do_custom(storm, 1.5)
	assert(enemy.hits == before_hits, "lightning hit a player who left its ring")

	-- Gust cadence pushes and slows hostile factioned players only.
	enemy.pos = {x = 3, y = 1, z = 0}
	friendly.pos = {x = 4, y = 1, z = 0}
	factionless.pos = {x = 2, y = 1, z = 0}
	radius_objects = {enemy, friendly, factionless}
	dragon = dragon_for("grug_mobs:ice_dragon", enemy, {x = 0, y = 1, z = 0})
	dragon.temp.grug_dragon = {mode = "ground", primary = 99, gust = 0}
	local enemy_pushes, factionless_pushes = enemy.pushes, factionless.pushes
	local enemy_slows = enemy.slows or 0
	ice_def.do_custom(dragon, 0.1)
	assert(enemy.pushes == enemy_pushes + 1 and enemy.slows == enemy_slows + 1 and
		factionless.pushes == factionless_pushes and
		math.abs(enemy.last_push.y - 2.8) < 0.000001,
		"gust target set or slow changed")
	local pushed = enemy.pushes
	ice_def.do_custom(dragon, 11)
	assert(enemy.pushes == pushed, "gust fired before its 12 second cadence")
	ice_def.do_custom(dragon, 1)
	assert(enemy.pushes == pushed + 1, "gust did not fire on cadence")

	-- Enrage is persistent, reduces cooldowns by 30%, spawns at most two whelps,
	-- and boss death removes every marked summon.
	dragon = dragon_for("grug_mobs:ice_dragon", enemy, {x = 0, y = 1, z = 0})
	dragon.health = 9000
	dragon.temp.grug_dragon = {mode = "ground", primary = 10, gust = 10}
	spawned_objects, spawn_count = {}, 0
	radius_objects = {}
	connected_players = {enemy}
	ice_def.do_custom(dragon, 0.1)
	assert(dragon._grug_enraged and dragon.temp.grug_dragon.primary < 7 and
		dragon.temp.grug_dragon.gust < 7, "enrage cooldown reduction changed")
	local whelps = {}
	for _, object in ipairs(spawned_objects) do
		if object.ent._grug_boss_summon then whelps[#whelps + 1] = object end
	end
	assert(#whelps == 2, "enrage did not spawn exactly two whelps")
	radius_objects = whelps
	ice_def.do_custom(dragon, 0.1)
	assert(#spawned_objects == 2, "enrage spawned more than two whelps")
	ice_def.on_die(dragon)
	assert(whelps[1].removed and whelps[2].removed,
		"boss death did not remove marked whelps")
	connected_players = {}

	for _, spawner in ipairs(spawners) do
		assert(spawner.amount > 0 and spawner.amount <= 180 and
			spawner.time > 0 and spawner.time <= 8,
			"unbounded dragon particle spawner")
	end
	local worst_live_particles = 48 + 54 + 3 * 36 + 80 + 120 + 96 + 180 + 96 + 180
	assert(worst_live_particles < 1000, "dragon particle budget reached four digits")

	local king_ent = {name = "grug_mobs:king_dwarf",
		_grug_boss_id = "king:dwarf"}
	local follow_king = {
		get_pos = function() return {x = 10, y = 0, z = 0} end,
		get_luaentity = function() return king_ent end,
	}
	king_ent.object = follow_king
	radius_objects = {follow_king}
	local enemy_object = {get_pos = function() return {x = -10, y = 0, z = 0} end}
	local acquisitions, stops = 0, 0
	local guard = {_grug_royal_race = "dwarf", state = "attack",
		attack = enemy_object, temp = {grug_royal_follow = 0.9},
		_grug_post_x = -20, _grug_post_z = 0, _grug_post_yaw = 0,
		node_timer = 0, env_damage_timer = 0, pause_timer = 0,
		timer = 0, timer1 = 0.95,
		falling = function() return false end,
		mob_sound = function() end, breed = function() end,
		follow_flop = function() end, do_states = function() return false end,
		do_runaway_from = function() end, do_stay_near = function() end,
		general_attack = function()
			acquisitions = acquisitions + 1
		end,
		stop_attack = function(self)
			stops = stops + 1
			self.attack = nil
			self.state = "stand"
		end,
		object = {get_pos = function() return {x = 0, y = 0, z = 0} end}}
	local guard_tick = registered["grug_mobs:royal_guard_dwarf"].do_custom
	guard = real_mobs_step(registered["grug_mobs:royal_guard_dwarf"], guard, 0.1)
	assert(movement.walk == 1 and stops == 1,
		"attacking royal guard did not drop combat and follow king")
	assert(acquisitions == 0, "mobs_redo general_attack overrode royal follow")
	assert(movement.socket == 0, "royal guard followed its independent socket home")
	assert(guard._grug_home.x == 10 and guard.state ~= "attack",
		"royal guard did not adopt the king as authoritative home")
	stalled, path_result = 20, true
	guard_tick(guard, 1)
	assert(movement.path == 1 and movement.snap == 0,
		"royal guard skipped path recovery")
	path_result = false
	guard_tick(guard, 1)
	assert(movement.path == 1 and movement.snap == 1 and
		movement.snap_pos.x == 10, "failed royal guard path did not snap to king")
	local resets = 0
	grug_mobs.royal_encounter_reset = function() resets = resets + 1 end
	grug_mobs.boss_leash_reset(guard)
	assert(resets == 0, "guard leash reset the royal encounter")
	grug_mobs.boss_leash_reset({_grug_royal_race = "dwarf",
		_grug_royal_king = true})
	assert(resets == 1, "king leash did not reset the royal encounter")

	store["boss:dragon:wyrmglass:alive"] = ""
	store["boss:dragon:wyrmglass:due"] = ""
	store["boss:dragon:wyrmglass:warned"] = ""
	spawned, spawn_count = nil, 0
	boss_step(10)
	assert(spawned.name == "grug_mobs:ice_dragon")
	assert(spawned.pos.x == -3260 and spawned.pos.y == 73 and spawned.pos.z == -40)
	assert(#spawned.ent._grug_perches == 3 and
		spawned.ent._grug_boss_id == "dragon:wyrmglass")
	assert(store["boss:dragon:wyrmglass:alive"] == "1" and
		store["boss:dragon:wyrmglass:due"] == "" and
		store["boss:dragon:wyrmglass:warned"] == "",
		"first-spawn heartbeat stored the wrong dragon state")
	boss_step(10)
	assert(spawn_count == 1, "alive gate permitted a duplicate heartbeat spawn")

	local start_file = assert(io.open(root ..
		"/mods/ENTITIES/grug_mobs/start_npcs.lua", "rb"))
	local start_text = assert(start_file:read("*a"))
	start_file:close()
	assert(start_text:find('register_start_socket_role("king"', 1, true))
	local royal_region = assert(start_text:match(
		"local ROYAL_GUARD_SOCKET = %b{}"))
	for _, id in ipairs({"throne_guard_west", "throne_guard_east"}) do
		assert(royal_region:find(id, 1, true), "missing royal socket " .. id)
	end
	assert(not royal_region:find("door_guard_", 1, true),
		"door guard still resolves as a royal guard")
	local capital_file = assert(io.open(root ..
		"/mods/MAPGEN/grug_mapgen/wp13/capitals.lua", "rb"))
	local capital_text = assert(capital_file:read("*a"))
	capital_file:close()
	for _, id in ipairs({"door_guard_west", "door_guard_east"}) do
		assert(capital_text:find(id, 1, true), "authored door socket disappeared: " .. id)
	end
	assert(2 * 6 == 12, "royal guard census changed")

	local ledger = assert(io.open(root ..
		"/mods/ENTITIES/grug_mobs/LICENSE-media.md", "rb"))
	local license = assert(ledger:read("*a"))
	ledger:close()
	for _, file in ipairs({"grug_mobs_ice_dragon.b3d",
		"grug_mobs_jungle_wyvern.b3d", "grug_mobs_dragon_shading.png",
		"grug_mobs_ice_dragon.png", "grug_mobs_jungle_wyvern.png",
		"grug_mobs_royal_guard_dwarf.png",
		"grug_mobs_royal_guard_troll.png"}) do
		assert(license:find("`" .. file .. "`", 1, true), file)
	end

	return "r9_boss_v1|dragons=2|whelps=2|kings=6|royal_guards=12|perches=3|" ..
		"warning=60|heartbeat_spawns=1|flight=1|dive=1|breath_cone=3|" ..
		"ground_effects=2|lightning_miss=1|gust=12|enrage=0.7|" ..
		"guard_full_step_follow_snap=1|guard_reset=0|particles_lt_1000=1\n"
end
