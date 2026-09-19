-- Round 9 MOB2 packages 6-8 and Bog Witch real-code KAT.

return function(root)
	assert(type(root) == "string" and root:sub(1, 1) == "/",
		"packages KAT requires an absolute repository root")

	local zone_id = "front_broken_causeway"
	local biome = "grug_swamp"
	local level = 35
	local timeofday = 0.9
	grug_mobs = {}
	grug_core = {start_identities = function()
		local out = {}
		for i = 1, 6 do
			out[i] = {anchor = {x = i * 10000, z = i * 10000}}
		end
		return out
	end}
	grug_zones = {
		id_at = function() return zone_id end,
		biome_at = function() return biome end,
		mob_level_at = function() return level end,
		pvp_rule_at = function() return "contested" end,
		race_region_at = function() return "human" end,
	}
	core = {
		get_timeofday = function() return timeofday end,
		is_player = function() return false end,
		registered_nodes = {},
	}
	dofile(root .. "/mods/ENTITIES/grug_mobs/spawn_policy.lua")

	local definitions, rows, arrows = {}, {}, {}
	function grug_mobs.register_mob(name, def)
		assert(not definitions[name], "duplicate mob registration: " .. name)
		grug_mobs.register_spawn_role(name, def)
		definitions[name] = def
	end
	function grug_mobs.register_simple_arrow(name, def) arrows[name] = def end
	function grug_mobs.stamp_arrow_damage() end
	function grug_mobs.camp_swarm(def) def._kat_swarm = true end
	function grug_mobs.stalker(def) def._kat_stalker = true end
	function grug_mobs.passive_prey(def)
		def.passive = false
		def.attack_players = false
		def.attack_npcs = false
		def.runaway = false
	end
	function grug_mobs.poison_player() end
	function grug_mobs.slow_player() end
	mobs = {}
	function mobs:spawn(def)
		rows[#rows + 1] = grug_mobs.prepare_spawn_row(def)
	end
	function mobs:register_arrow(name, def) arrows[name] = def end

	local files = {
		"goblin_miners.lua", "oerkki.lua", "glowwing.lua",
		"crystal_shard.lua", "dungeon_master.lua", "lava_flan.lua",
		"ember_wisp.lua", "land_guard.lua", "rift_spawn.lua",
		"war_construct.lua", "speargrass_tiger.lua", "shore_crab.lua",
		"bog_witch.lua",
	}
	for i = 1, #files do
		dofile(root .. "/mods/ENTITIES/grug_mobs/" .. files[i])
	end

	local expected_tiers = {
		goblin_miner = "normal", goblin_miner_slinger = "normal",
		oerkki = "normal", glowwing = "normal", crystal_shard = "normal",
		dungeon_master = "normal", lava_flan = "normal", ember_wisp = "normal",
		land_guard = "elite", rift_spawn = "normal", war_construct = "elite",
		speargrass_tiger = "normal", shore_crab = "normal",
		reef_lurker = "elite", bog_witch = "normal",
	}
	local definition_count = 0
	for short, tier in pairs(expected_tiers) do
		local def = assert(definitions["grug_mobs:" .. short],
			"missing wrapper registration: " .. short)
		assert(def._grug_tier == tier, "invalid tier for " .. short)
		assert(def.hp_min == nil and def.hp_max == nil and def.damage == nil and
			def.armor == nil and def._grug_xp_reward == nil,
			"hand-owned combat stat in " .. short)
		definition_count = definition_count + 1
	end
	assert(definition_count == 15, "unexpected new mob count")

	local bands = {
		goblin_miner = {-300, -100}, goblin_miner_slinger = {-300, -100},
		oerkki = {-700, -300}, glowwing = {-500, -300},
		crystal_shard = {-700, -300}, dungeon_master = {-1000, -500},
		lava_flan = {-31000, -700}, ember_wisp = {-31000, -700},
		land_guard = {-31000, -1000},
	}
	local band_seen = {}
	for i = 1, #rows do
		local row = rows[i]
		local short = row.name:match("^grug_mobs:(.+)$")
		local band = bands[short]
		if band then
			assert(row.min_height == band[1] and row.max_height == band[2],
				"wrong depth band for " .. short)
			assert(row.max_light == 5 and row.day_toggle == nil,
				"underground clock/light mismatch for " .. short)
			band_seen[short] = true
		elseif short ~= "rift_spawn" then
			assert(row.min_height >= 0 and row.max_height <= 300,
				"surface row outside surface band for " .. short)
		end
	end
	for short in pairs(bands) do assert(band_seen[short], "missing band row " .. short) end
	assert(#rows == 16, "unexpected spawn-row count")

	local rift = definitions["grug_mobs:rift_spawn"]
	assert(rift.attack_type == "explode" and rift.explosion_radius == 0 and
		rift.explosion_damage_radius == 0 and rift.explosion_timer == 2 and
		type(rift.do_custom) == "function" and rift.sounds and
		rift.sounds.fuse == "default_cool_lava",
		"Rift Spawn is not a terrain-safe two-second explode mob")
	local function copy(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, child in pairs(value) do result[key] = copy(child) end
		return result
	end
	local function real_mobs_step(def, fields, dtime, hazard)
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
		api_core.get_objects_inside_radius = function()
			return hazard.fallback_objects
		end
		api_core.find_node_near = function() return hazard.water and {} or nil end
		api_core.is_protected = function() return hazard.protected end
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
		env.mobs:register_mob("grug_mobs:rift_step_kat", def)
		local prototype = assert(registered_entities["grug_mobs:rift_step_kat"])
		local entity = setmetatable(fields, {__index = prototype})
		entity:on_step(dtime, {})
		return entity
	end
	vector = {offset = function(pos, x, y, z)
		return {x = pos.x + x, y = pos.y + y, z = pos.z + z}
	end}
	for _, hazard in ipairs({
		{name = "ordinary"}, {name = "water-adjacent", water = true},
		{name = "protected", protected = true},
	}) do
		local burst_hits, burst_particles, burst_sounds, removals = 0, 0, 0, 0
		local rift_object = {
			get_pos = function() return {x = 0, y = 0, z = 0} end,
			get_luaentity = function() return nil end,
			get_yaw = function() return 0 end,
			remove = function() removals = removals + 1 end,
		}
		local victim = {
			get_pos = function() return {x = 1, y = 0, z = 0} end,
			get_luaentity = function() return nil end,
			punch = function(_, source, _, toolcaps)
				assert(source == rift_object and toolcaps.damage_groups.fleshy == 17,
					"Rift Spawn used a second or unscaled damage path")
				burst_hits = burst_hits + 1
			end,
		}
		hazard.fallback_objects = {victim}
		core.is_player = function(object) return object == victim end
		core.get_objects_inside_radius = function(_, radius)
			assert(radius == 3.5)
			return {rift_object, victim}
		end
		core.add_particlespawner = function(def)
			assert(def.amount == 32 and def.time == 0.25)
			burst_particles = burst_particles + 1
		end
		core.sound_play = function(name, spec)
			assert(name == "default_item_smoke" and spec.max_hear_distance == 32)
			burst_sounds = burst_sounds + 1
		end
		local rift_instance = {
			v_start = true, timer = 1.9, timer1 = 0, explosion_timer = 2,
			damage = 17, state = "attack", node_timer = 0,
			env_damage_timer = 0, pause_timer = 0, object = rift_object,
			falling = function() return false end,
		}
		real_mobs_step(rift, rift_instance, 0.1, hazard)
		assert(burst_hits == 1 and burst_particles == 1 and
			burst_sounds == 1 and removals == 1,
			"Rift Spawn real on_step was not terminal exact-once: " .. hazard.name)
	end
	local rift_cave, rift_surface = false, false
	for i = 1, #rows do
		if rows[i].name == "grug_mobs:rift_spawn" then
			if rows[i].max_height == -1000 and rows[i].min_height == -31000 then
				rift_cave = true
			elseif rows[i].min_height == 0 then
				rift_surface = true
			end
		end
	end
	assert(rift_cave and rift_surface, "Rift Spawn dual habitat missing")
	assert(type(definitions["grug_mobs:glowwing"].fly_in) == "table" and
		type(definitions["grug_mobs:ember_wisp"].fly_in) == "table",
		"underground flier would receive surface near-ground bias")

	local surface_routes = {
		war_construct = {"front_broken_causeway", "front_shattered_line"},
		speargrass_tiger = {"kragmar_speargrass_reach", "front_shattered_line"},
		bog_witch = {"front_broken_causeway", "front_gravesalt_escarpment",
			"kragmar_thunderroot_wilds", "front_stormscale_summit"},
		rift_spawn = {"front_wyrmglass_crown", "front_gravesalt_escarpment",
			"front_skyglass_canopy", "front_stormscale_summit"},
	}
	local surface_pos = {x = 0, y = 20, z = 0}
	for short, routes in pairs(surface_routes) do
		for i = 1, #routes do
			zone_id = routes[i]
			timeofday = short == "war_construct" and 0.5 or
				(short == "speargrass_tiger" and 0.5 or 0.9)
			assert(grug_mobs.spawn_policy_allows("grug_mobs:" .. short, surface_pos),
				"route rejected for " .. short .. ": " .. routes[i])
		end
	end
	local tiger_check = definitions["grug_mobs:speargrass_tiger"]._grug_spawn_check
	for _, boundary in ipairs({{20, false}, {21, true}, {50, true}, {51, false}}) do
		level = boundary[1]
		assert(not not tiger_check(surface_pos) == boundary[2],
			"Speargrass Tiger level boundary failed at " .. level)
	end
	zone_id, biome, level, timeofday = "elandor_hearthpine_vale", "grug_beach", 3, 0.5
	assert(grug_mobs.spawn_policy_allows("grug_mobs:shore_crab", surface_pos))
	assert(definitions["grug_mobs:shore_crab"]._grug_spawn_check(surface_pos))
	biome = "grug_meadows"
	assert(grug_mobs.spawn_policy_allows("grug_mobs:shore_crab", surface_pos),
		"dry-sand host must not require a logical beach palette")
	level = 50
	assert(grug_mobs.spawn_policy_allows("grug_mobs:reef_lurker", surface_pos))
	assert(definitions["grug_mobs:reef_lurker"]._grug_spawn_check(surface_pos))
	assert(not definitions["grug_mobs:shore_crab"]._grug_spawn_check(surface_pos))

	local function read(path)
		local handle = assert(io.open(path, "rb"), path)
		local body = assert(handle:read("*a"))
		handle:close()
		return body
	end
	local media_roots = {
		root .. "/mods/ENTITIES/grug_mobs/textures/",
		root .. "/mods/ENTITIES/mobs/textures/",
		root .. "/mods/BASE/default/textures/",
		root .. "/mods/BASE/vessels/textures/",
	}
	local function shipped_texture(name)
		for i = 1, #media_roots do
			local handle = io.open(media_roots[i] .. name, "rb")
			if handle then handle:close(); return true end
		end
		return false
	end
	local texture_count, texture_seen = 0, {}
	for i = 1, #files do
		local body = read(root .. "/mods/ENTITIES/grug_mobs/" .. files[i])
		for reference in body:gmatch("[\"']([^\"']-%.png[^\"']*)[\"']") do
			local name = assert(reference:match("^([^%^]+%.png)"), reference)
			assert(shipped_texture(name),
				"missing entity/projectile/particle texture: " .. name)
			if not texture_seen[name] then
				texture_seen[name] = true
				texture_count = texture_count + 1
			end
		end
	end
	assert(texture_count > 20, "new-family texture inventory was not exercised")
	local function i32(s, at)
		local a, b, c, d = s:byte(at, at + 3)
		local value = a + b * 256 + c * 65536 + d * 16777216
		if value >= 2147483648 then value = value - 4294967296 end
		return value
	end
	local function keyed_range(body)
		local low, high
		local walk
		walk = function(first, last)
			local at = first
			while at < last do
				local tag = body:sub(at, at + 3)
				local size = i32(body, at + 4)
				local payload, after = at + 8, at + 8 + size
				if tag == "BB3D" then
					walk(payload + 4, after)
				elseif tag == "NODE" then
					local stop = assert(body:find("\0", payload, true))
					walk(stop + 1 + 40, after)
				elseif tag == "MESH" then
					walk(payload + 4, after)
				elseif tag == "KEYS" then
					local flags = i32(body, payload)
					local values = (flags % 2 == 1 and 3 or 0) +
						(math.floor(flags / 2) % 2 == 1 and 3 or 0) +
						(math.floor(flags / 4) % 2 == 1 and 4 or 0)
					local key = payload + 4
					while key < after do
						local frame = i32(body, key)
						low = low == nil and frame or math.min(low, frame)
						high = high == nil and frame or math.max(high, frame)
						key = key + 4 + values * 4
					end
				end
				at = after
			end
		end
		walk(1, #body + 1)
		return low, high
	end
	local witch = definitions["grug_mobs:bog_witch"]
	local key_low, key_high = keyed_range(read(root ..
		"/mods/ENTITIES/grug_mobs/models/" .. witch.mesh))
	assert(key_low and key_high, "Bog Witch humanoid has no keyed animation")
	assert(witch.animation.shoot_start >= key_low and
		witch.animation.shoot_end <= key_high and
		witch.animation.die_start >= key_low and witch.animation.die_end <= key_high,
		"Bog Witch shoot/die frames exceed keyed mesh range")
	assert(arrows["grug_mobs:hex_bottle"] and witch.arrow == "grug_mobs:hex_bottle",
		"Bog Witch hex bottle missing")

	local copied = {
		{"models/grug_mobs_oerkki.b3d", "mobs_monster/models/mobs_oerkki.b3d"},
		{"textures/grug_mobs_oerkki.png", "mobs_monster/textures/mobs_oerkki.png"},
		{"textures/grug_mobs_oerkki4.png", "mobs_monster/textures/mobs_oerkki4.png"},
		{"models/grug_mobs_glowwing.b3d", "animalworld/models/Dragonfly.b3d"},
		{"textures/grug_mobs_glowwing.png", "animalworld/textures/texturedragonfly.png"},
		{"models/grug_mobs_crystal_shard.b3d", "mobs_monster/models/mobs_mese_monster.b3d"},
		{"textures/grug_mobs_crystal_shard.png", "mobs_monster/textures/mobs_mese_monster_purple.png"},
		{"models/grug_mobs_dungeon_master.b3d", "mobs_monster/models/mobs_dungeon_master.b3d"},
		{"textures/grug_mobs_dungeon_master.png", "mobs_monster/textures/mobs_dungeon_master.png"},
		{"textures/grug_mobs_dungeon_master2.png", "mobs_monster/textures/mobs_dungeon_master2.png"},
		{"textures/grug_mobs_dungeon_master4.png", "mobs_monster/textures/mobs_dungeon_master4.png"},
		{"models/grug_mobs_lava_flan.b3d", "mobs_monster/models/zmobs_lava_flan.b3d"},
		{"textures/grug_mobs_lava_flan.png", "mobs_monster/textures/zmobs_lava_flan.png"},
		{"textures/grug_mobs_lava_flan2.png", "mobs_monster/textures/zmobs_lava_flan2.png"},
		{"textures/grug_mobs_lava_flan3.png", "mobs_monster/textures/zmobs_lava_flan3.png"},
		{"textures/grug_mobs_land_guard.png", "mobs_monster/textures/mobs_land_guard.png"},
		{"textures/grug_mobs_land_guard2.png", "mobs_monster/textures/mobs_land_guard2.png"},
		{"textures/grug_mobs_land_guard3.png", "mobs_monster/textures/mobs_land_guard3.png"},
		{"models/grug_mobs_war_construct.b3d", "VoxeLibre/mods/ENTITIES/mobs_mc/models/mobs_mc_iron_golem.b3d"},
		{"textures/grug_mobs_war_construct.png", "VoxeLibre/textures/mobs_mc_iron_golem.png"},
		{"models/grug_mobs_rift_spawn.b3d", "VoxeLibre/mods/ENTITIES/mobs_mc/models/vl_stalker.b3d"},
		{"textures/grug_mobs_rift_spawn.png", "VoxeLibre/textures/vl_stalker_default.png"},
		{"models/grug_mobs_speargrass_tiger.b3d", "animalworld/models/Tiger.b3d"},
		{"textures/grug_mobs_speargrass_tiger.png", "animalworld/textures/texturetiger.png"},
		{"models/grug_mobs_shore_crab.b3d", "animalworld/models/Crab.b3d"},
		{"textures/grug_mobs_shore_crab.png", "animalworld/textures/texturecrab.png"},
	}
	local ledger = read(root .. "/mods/ENTITIES/grug_mobs/LICENSE-media.md")
	for i = 1, #copied do
		local local_path = root .. "/mods/ENTITIES/grug_mobs/" .. copied[i][1]
		local source_path = root .. "/reference_projects/" .. copied[i][2]
		assert(read(local_path) == read(source_path), "copied media drift: " .. copied[i][1])
		local basename = copied[i][1]:match("([^/]+)$")
		assert(ledger:find("`" .. basename .. "`", 1, true),
			"missing ledger row: " .. basename)
	end
	for _, unclear in ipairs({
		{"mobs_oerkki2.png", "textures/grug_mobs_oerkki2.png"},
		{"mobs_oerkki3.png", "textures/grug_mobs_oerkki3.png"},
		{"mobs_dungeon_master3.png", "textures/grug_mobs_dungeon_master3.png"},
		{"zmobs_mese_monster.png", "textures/grug_mobs_crystal_shard_old.png"},
	}) do
		local handle = io.open(root .. "/mods/ENTITIES/grug_mobs/" .. unclear[2], "rb")
		if handle then handle:close() end
		assert(not handle, "UNCLEAR media present: " .. unclear[2])
		assert(not ledger:find(unclear[1], 1, true),
			"UNCLEAR source entered ledger: " .. unclear[1])
	end

	return "r9_mob2_packages_v2|families=15|rows=16|copied_media=26|textures=" ..
		texture_count .. "|" ..
		"bog_witch_keys=" .. key_low .. ".." .. key_high .. "\n"
end
