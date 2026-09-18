-- R8-MOB1 package 5 real-code KAT.

return function(root)
	assert(type(root) == "string" and root:sub(1, 1) == "/",
		"boss KAT requires an absolute repository root")

	local registered, craftitems, globalsteps = {}, {}, {}
	local callbacks = {hit = {}, heal = {}, absorb = {}, death = {}, join = {}}
	local store = {}
	local lair_loaded = true
	local storage = {
		get_string = function(_, key) return store[key] or "" end,
		set_string = function(_, key, value) store[key] = value end,
	}
	local spawned
	core = {
		get_mod_storage = function() return storage end,
		register_craftitem = function(name, def) craftitems[name] = def end,
		register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
		register_on_dieplayer = function(fn) callbacks.death[#callbacks.death + 1] = fn end,
		register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
		get_objects_inside_radius = function() return {} end,
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
		is_player = function() return false end,
		yaw_to_dir = function() return {x = 0, y = 0, z = 1} end,
		add_entity = function(pos, name)
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
		get_player_faction = function() return "accord" end,
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
		place_on_ground = function() end,
		walk_toward = function() end,
		start_npc_claim = function() return true end,
		guard_definition = function(faction, description, texture)
			return {description = description, _grug_faction = faction,
				textures = {{texture}}, do_custom = function() end}
		end,
	}
	ItemStack = function() return {} end

	dofile(root .. "/mods/ENTITIES/grug_mobs/bosses.lua")

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
	for _, race in ipairs({"dwarf", "human", "elf", "undead", "orc", "troll"}) do
		local king = assert(registered["grug_mobs:king_" .. race], race)
		local guard = assert(registered["grug_mobs:royal_guard_" .. race], race)
		assert(king._grug_fixed_level == 65 and king._grug_tier == "elite")
		assert(guard._grug_fixed_level == 60 and guard._grug_tier == "elite")
		assert(king.hp_min == nil and king.hp_max == nil and king.damage == nil)
		assert(king.textures[1][1] == "grug_mobs_royal_" .. race .. ".png")
		race_count = race_count + 1
	end
	assert(race_count == 6 and craftitems["grug_mobs:fallen_crown"])
	assert(#callbacks.hit == 1 and #callbacks.heal == 1 and #callbacks.absorb == 1 and
		#callbacks.death == 1 and #callbacks.join == 1 and #globalsteps == 1)

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

	assert(grug_mobs.boss_spawn_due("wyrmglass"))
	assert(spawned.name == "grug_mobs:ice_dragon")
	assert(spawned.pos.x == -3260 and spawned.pos.y == 73 and spawned.pos.z == -40)
	assert(#spawned.ent._grug_perches == 3 and
		spawned.ent._grug_boss_id == "dragon:wyrmglass")

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

	return "r8_mob1_boss_v1|dragons=2|kings=6|royal_guards=24|perches=3|warning=60\n"
end
