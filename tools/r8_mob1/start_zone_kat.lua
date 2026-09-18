-- R8-MOB1 package 3 real-code KAT.

return function(root)
	assert(type(root) == "string" and root:sub(1, 1) == "/",
		"start-zone KAT requires an absolute repository root")

	local zone_id, level, timeofday = "elandor_hearthpine_vale", 5, 0.5
	grug_mobs = {}
	grug_core = {
		start_identities = function()
			local out = {}
			for i = 1, 6 do
				out[i] = {anchor = {x = i * 10000, z = i * 10000}}
			end
			return out
		end,
		mono_time = function() return 1 end,
	}
	grug_zones = {
		id_at = function() return zone_id end,
		biome_at = function() return "grug_pine_hills" end,
		pvp_rule_at = function() return "contested" end,
		race_region_at = function() return "dwarf" end,
		mob_level_at = function() return level end,
	}
	core = {
		get_timeofday = function() return timeofday end,
		is_player = function() return true end,
	}
	dofile(root .. "/mods/ENTITIES/grug_mobs/spawn_policy.lua")

	local definitions, rows = {}, {}
	function grug_mobs.register_mob(name, def)
		grug_mobs.register_spawn_role(name, def)
		definitions[name] = def
	end
	function grug_mobs.melee_rider(def, fn) def._kat_rider = fn end
	function grug_mobs.passive_prey(def)
		def.passive = false
		def.attack_players = false
		def.attack_npcs = false
		def.runaway = false
		return def
	end
	function grug_mobs.camp_swarm(def) def._kat_swarm = true end
	function grug_mobs.poison_player() end
	mobs = {}
	function mobs:spawn(def)
		rows[#rows + 1] = grug_mobs.prepare_spawn_row(def)
	end

	dofile(root .. "/mods/ENTITIES/grug_mobs/start_zone_families.lua")

	local expected = {
		fox = {clock = "day", mesh = "grug_mobs_fox.b3d"},
		ibex = {clock = "day", mesh = "grug_mobs_ibex.b3d", prey = true},
		wild_turkey = {clock = "day", mesh = "grug_mobs_wild_turkey.b3d",
			critter = true},
		plains_runner = {clock = "day", mesh = "grug_mobs_plains_runner.b3d",
			critter = true},
		tapir = {clock = "day", mesh = "grug_mobs_tapir.b3d", prey = true},
		giant_rat = {clock = "night", mesh = "grug_mobs_giant_rat.b3d"},
		scorpion = {clock = "night", mesh = "grug_mobs_scorpion.b3d"},
		viper = {clock = "night", mesh = "grug_mobs_viper.b3d"},
	}
	local family_count = 0
	for short, spec in pairs(expected) do
		local def = assert(definitions["grug_mobs:" .. short],
			"missing family " .. short)
		assert(def.clock == spec.clock, "clock differs for grug_mobs:" .. short)
		assert(def.mesh == spec.mesh and def.animation, "visual differs for " .. short)
		assert(def.hp_min == nil and def.hp_max == nil and def.damage == nil and
			def._grug_xp_reward == nil, "hand-owned stats in " .. short)
		if spec.critter then assert(def._grug_tier == "critter") end
		if spec.prey then
			assert(def.passive == false and def.attack_players == false)
		end
		family_count = family_count + 1
	end
	assert(family_count == 8 and #rows == 9)

	local surface_rows, cave_rows = 0, 0
	for i = 1, #rows do
		local row = rows[i]
		if row.max_height and row.max_height <= -40 then
			cave_rows = cave_rows + 1
			assert(row.name == "grug_mobs:giant_rat")
			assert(row.day_toggle == nil and row.max_light == 5 and
				row.active_object_count == 4)
		else
			surface_rows = surface_rows + 1
			local def = definitions[row.name]
			if def.clock == "day" then
				assert(row.min_light == 10 and row.day_toggle == nil)
			else
				assert(row.max_light == 5 and row.day_toggle == false)
				assert(row.active_object_count == 5)
			end
		end
	end
	assert(surface_rows == 8 and cave_rows == 1)

	local routes = {
		fox = {"elandor_hearthpine_vale", 4, 0.5},
		ibex = {"elandor_stormvault_heights", 35, 0.5},
		wild_turkey = {"elandor_dawnmere_fields", 2, 0.5},
		plains_runner = {"kragmar_sunscar_flats", 2, 0.5},
		tapir = {"kragmar_whispering_reedlands", 25, 0.5},
		giant_rat = {"kragmar_stillgrave_hollow", 2, 0.9},
		scorpion = {"front_shattered_line", 45, 0.9},
		viper = {"kragmar_raincall_basin", 15, 0.9},
	}
	local pos = {x = 0, y = 20, z = 0}
	for short, route in pairs(routes) do
		zone_id, level, timeofday = route[1], route[2], route[3]
		assert(grug_mobs.spawn_policy_allows("grug_mobs:" .. short, pos),
			"route rejected for " .. short)
	end
	for _, short in ipairs({"fox", "ibex", "tapir", "scorpion", "viper"}) do
		local def = definitions["grug_mobs:" .. short]
		zone_id, level = short == "scorpion" and "kragmar_sunscar_flats" or
			(short == "viper" or short == "tapir") and "kragmar_kapok_cradle" or
			"elandor_hearthpine_vale", 3
		assert(not def._grug_spawn_check(pos), "band-2 leak for " .. short)
		level = 4
		assert(def._grug_spawn_check(pos), "band-2 rejection for " .. short)
	end
	assert(grug_mobs.spawn_policy_allows("grug_mobs:giant_rat",
		{x = 0, y = -200, z = 0}), "rat cave route rejected")

	for short, spec in pairs(expected) do
		local mesh = assert(io.open(root .. "/mods/ENTITIES/grug_mobs/models/" ..
			spec.mesh, "rb"))
		assert(mesh:read(4) == "BB3D", "not a B3D mesh: " .. short)
		mesh:close()
		local texture = assert(io.open(root .. "/mods/ENTITIES/grug_mobs/textures/" ..
			definitions["grug_mobs:" .. short].textures[1][1], "rb"))
		assert(texture:read(8) == "\137PNG\13\10\26\10", "not PNG: " .. short)
		texture:close()
	end

	local ledger = assert(io.open(root ..
		"/mods/ENTITIES/grug_mobs/LICENSE-media.md", "rb"))
	local ledger_text = assert(ledger:read("*a"))
	ledger:close()
	for _, spec in pairs(expected) do
		assert(ledger_text:find("`" .. spec.mesh .. "`", 1, true),
			"mesh absent from media ledger: " .. spec.mesh)
	end

	return "r8_mob1_start_v1|families=8|surface_rows=8|cave_rows=1|assets=16\n"
end
