-- R8-MOB1 package 5 real-code KAT.

return function(root)
	assert(type(root) == "string" and root:sub(1, 1) == "/",
		"boss KAT requires an absolute repository root")

	local registered, craftitems, globalsteps = {}, {}, {}
	local callbacks = {hit = {}, heal = {}, absorb = {}, death = {}, join = {}}
	local store = {}
	local lair_loaded = true
	local radius_objects = {}
	local faction_by_name = {}
	local movement = {walk = 0, path = 0, snap = 0, clear = 0, socket = 0}
	local stalled, path_result = 0, false
	local storage = {
		get_string = function(_, key) return store[key] or "" end,
		set_string = function(_, key, value) store[key] = value end,
	}
	local spawned, spawn_count
	core = {
		get_mod_storage = function() return storage end,
		register_craftitem = function(name, def) craftitems[name] = def end,
		register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
		register_on_dieplayer = function(fn) callbacks.death[#callbacks.death + 1] = fn end,
		register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
		get_objects_inside_radius = function() return radius_objects end,
		get_player_by_name = function() return nil end,
		get_node_or_nil = function()
			return {name = lair_loaded and "air" or "ignore"}
		end,
		get_connected_players = function() return {} end,
		sound_play = function() end,
		add_particlespawner = function() end,
		chat_send_all = function() end,
		chat_send_player = function() end,
		serialize = function() return "" end,
		deserialize = function() return nil end,
		is_player = function(object) return object and object._is_player == true end,
		yaw_to_dir = function() return {x = 0, y = 0, z = 1} end,
		add_entity = function(pos, name)
			spawn_count = (spawn_count or 0) + 1
			spawned = {pos = pos, name = name, ent = {}}
			return {
				get_luaentity = function() return spawned.ent end,
				get_pos = function() return pos end,
				set_velocity = function() end,
			}
		end,
	}
	grug_core = {
		register_on_player_hit_mob = function(fn) callbacks.hit[#callbacks.hit + 1] = fn end,
		register_on_effective_heal = function(fn) callbacks.heal[#callbacks.heal + 1] = fn end,
		register_on_effective_absorb = function(fn)
			callbacks.absorb[#callbacks.absorb + 1] = fn
		end,
		get_player_faction = function(name) return faction_by_name[name] end,
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
		register_simple_arrow = function() end,
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
	ItemStack = function() return {} end

	dofile(root .. "/mods/ENTITIES/grug_mobs/bosses.lua")

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
		assert(type(def.do_custom) == "function" and type(def.on_die) == "function")
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
		assert(king._grug_visual({_grug_level = 65}).weapon_family ==
			expected_weapons[race], "wrong closest available king weapon: " .. race)
		race_count = race_count + 1
	end
	assert(race_count == 6 and craftitems["grug_mobs:fallen_crown"])
	assert(#callbacks.hit == 1 and #callbacks.heal == 1 and #callbacks.absorb == 1 and
		#callbacks.death == 1 and #callbacks.join == 1 and #globalsteps == 1)

	store["boss:dragon:stormscale:alive"] = "1"
	store["boss:dragon:wyrmglass:due"] = tostring(os.time() - 1)
	lair_loaded = false
	globalsteps[1](10)
	assert(store["boss:dragon:wyrmglass:warned"] ~= "1",
		"unloaded lair started its warning")
	lair_loaded = true
	local warning_started = os.time()
	globalsteps[1](10)
	assert(store["boss:dragon:wyrmglass:warned"] == "1")
	assert(tonumber(store["boss:dragon:wyrmglass:due"]) >= warning_started + 60,
		"late activation did not receive a full warning")

	local function player(name, faction, x)
		faction_by_name[name] = faction
		local object = {_is_player = true, hits = 0, pushes = 0}
		function object:get_player_name() return name end
		function object:get_hp() return 100 end
		function object:get_pos() return {x = x, y = 0, z = 0} end
		function object:punch() self.hits = self.hits + 1 end
		function object:add_velocity() self.pushes = self.pushes + 1 end
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

	local dragon = {object = king_object, temp = {}, attack = enemy,
		damage = 10, set_velocity = function() end, set_animation = function() end}
	registered["grug_mobs:ice_dragon"].do_custom(dragon, 2)
	registered["grug_mobs:ice_dragon"].do_custom(dragon, 2)
	assert(enemy.hits == 2 and friendly.hits == 1 and factionless.hits == 1,
		"neutral dragon AoE inherited king faction filtering")

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
	globalsteps[1](10)
	assert(spawned.name == "grug_mobs:ice_dragon")
	assert(spawned.pos.x == -3260 and spawned.pos.y == 73 and spawned.pos.z == -40)
	assert(#spawned.ent._grug_perches == 3 and
		spawned.ent._grug_boss_id == "dragon:wyrmglass")
	assert(store["boss:dragon:wyrmglass:alive"] == "1" and
		store["boss:dragon:wyrmglass:due"] == "" and
		store["boss:dragon:wyrmglass:warned"] == "",
		"first-spawn heartbeat stored the wrong dragon state")
	globalsteps[1](10)
	assert(spawn_count == 1, "alive gate permitted a duplicate heartbeat spawn")

	local start_file = assert(io.open(root ..
		"/mods/ENTITIES/grug_mobs/start_npcs.lua", "rb"))
	local start_text = assert(start_file:read("*a"))
	start_file:close()
	assert(start_text:find('register_start_socket_role("king"', 1, true))
	for _, id in ipairs({"throne_guard_west", "throne_guard_east",
		"door_guard_west", "door_guard_east"}) do
		assert(start_text:find(id, 1, true), "missing royal socket " .. id)
	end

	local ledger = assert(io.open(root ..
		"/mods/ENTITIES/grug_mobs/LICENSE-media.md", "rb"))
	local license = assert(ledger:read("*a"))
	ledger:close()
	for _, file in ipairs({"grug_mobs_ice_dragon.b3d",
		"grug_mobs_jungle_wyvern.b3d", "grug_mobs_dragon_shading.png",
		"grug_mobs_ice_dragon.png", "grug_mobs_jungle_wyvern.png"}) do
		assert(license:find("`" .. file .. "`", 1, true), file)
	end

	return "r8_mob1_boss_v3|dragons=2|kings=6|royal_guards=24|perches=3|" ..
		"warning=60|heartbeat_spawns=1|king_enemy_aoe=1|" ..
		"guard_full_step_follow_snap=1|guard_reset=0\n"
end
