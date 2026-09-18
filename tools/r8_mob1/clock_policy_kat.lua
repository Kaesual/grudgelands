-- R8-MOB1 package 1 KAT: production clock roles, row stamping, underground
-- exception, fallbacks, and both casts for every named land zone.

return function(root)
	assert(type(root) == "string" and root:sub(1, 1) == "/",
		"clock KAT requires an absolute repository root")

	local current_zone = "elandor_hearthpine_vale"
	local current_biome = "grug_meadows"
	local current_time = 0.5

	grug_mobs = {}
	grug_core = {
		start_identities = function()
			local rows = {}
			for i = 1, 6 do
				rows[i] = {anchor = {x = i * 10000, y = 0, z = i * 10000}}
			end
			return rows
		end,
	}
	grug_zones = {
		id_at = function() return current_zone end,
		biome_at = function() return current_biome end,
		pvp_rule_at = function() return "contested" end,
		race_region_at = function() return "human" end,
	}
	core = {get_timeofday = function() return current_time end}

	dofile(root .. "/mods/ENTITIES/grug_mobs/spawn_policy.lua")

	local roles = {
		["grug_mobs:boar"] = "day",
		["grug_mobs:plague_boar"] = "day",
		["grug_mobs:jungle_boar"] = "day",
		["grug_mobs:rabbit"] = "day",
		["grug_mobs:hare"] = "day",
		["grug_mobs:zombie"] = {
			settled = "night", war = "night", blight = "any",
		},
		["grug_mobs:wolf"] = "any",
		["grug_mobs:blightfang_wolf"] = "any",
		["grug_mobs:bear"] = "day",
		["grug_mobs:plaguehide_bear"] = "day",
		["grug_mobs:stag"] = "day",
		["grug_mobs:gaunt_stag"] = "day",
		["grug_mobs:giant_spider"] = "night",
		["grug_mobs:pale_spider"] = "night",
		["grug_mobs:skeleton_archer"] = "night",
		["grug_mobs:bone_weevil"] = "day",
		["grug_mobs:crag_eagle"] = "day",
		["grug_mobs:vulture"] = "day",
		["grug_mobs:stone_golem"] = "any",
		["grug_mobs:mesa_golem"] = "any",
		["grug_mobs:mountain_ram"] = "day",
		["grug_mobs:hyena"] = "any",
		["grug_mobs:zebra"] = "day",
		["grug_mobs:jungle_lynx"] = "day",
		["grug_mobs:panther"] = "night",
		["grug_mobs:serpent"] = "day",
		["grug_mobs:jungle_ape"] = "day",
		["grug_mobs:jungle_spider"] = "night",
		["grug_mobs:parrot"] = "day",
		["grug_mobs:crocodile"] = "any",
		["grug_mobs:bog_ooze"] = "any",
		["grug_mobs:bog_fowl"] = "day",
		["grug_mobs:skeleton_raider"] = "night",
		["grug_mobs:carrion_crow"] = "any",
	}
	for name, clock in pairs(roles) do
		grug_mobs.register_spawn_role(name, {clock = clock, passive = true})
	end
	assert(not pcall(grug_mobs.register_spawn_role, "missing", {}))
	assert(not pcall(grug_mobs.register_spawn_role, "bad", {clock = "dusk"}))

	local day = grug_mobs.prepare_spawn_row({
		name = "grug_mobs:boar", min_light = 1, max_light = 15,
		day_toggle = false, active_object_count = 5, max_height = 200,
	})
	assert(day.min_light == 10 and day.max_light == nil and
		day.day_toggle == nil and day.active_object_count == 5)
	local night = grug_mobs.prepare_spawn_row({
		name = "grug_mobs:giant_spider", min_light = 10,
		active_object_count = 4, max_height = 200,
	})
	assert(night.min_light == nil and night.max_light == 5 and
		night.day_toggle == false and night.active_object_count == 5)
	local rounded = grug_mobs.prepare_spawn_row({
		name = "grug_mobs:skeleton_archer", active_object_count = 3,
		max_height = 200,
	})
	assert(rounded.active_object_count == 4)
	local cave = grug_mobs.prepare_spawn_row({
		name = "grug_mobs:giant_spider", max_light = 5,
		day_toggle = false, active_object_count = 4, max_height = -40,
	})
	assert(cave.max_light == 5 and cave.day_toggle == nil and
		cave.active_object_count == 4)

	local zones = {
		{"elandor_hearthpine_vale", 1, 10},
		{"elandor_copperfell_foothills", 11, 20},
		{"elandor_dur_brannoc", 20, 30, true},
		{"elandor_frostbarrow_shelf", 21, 30},
		{"elandor_stormvault_heights", 31, 40},
		{"elandor_dawnmere_fields", 1, 10},
		{"elandor_goldmead_vale", 11, 20},
		{"elandor_highcourt", 20, 30, true},
		{"elandor_whitebridge_shire", 21, 30},
		{"elandor_ashenward_march", 31, 40},
		{"elandor_silverleaf_glades", 1, 10},
		{"elandor_starbough_vale", 11, 20},
		{"elandor_lethariel", 20, 30, true},
		{"elandor_lorindor", 21, 30},
		{"elandor_moonfall_wood", 21, 30},
		{"elandor_glassroot_wilds", 31, 40},
		{"kragmar_stillgrave_hollow", 1, 10},
		{"kragmar_mournfen", 11, 20},
		{"kragmar_nhal_veyr", 20, 30, true},
		{"kragmar_ossuary_reach", 21, 30},
		{"kragmar_blackwind_rise", 31, 40},
		{"kragmar_sunscar_flats", 1, 10},
		{"kragmar_redtusk_savanna", 11, 20},
		{"kragmar_gor_drazhak", 20, 30, true},
		{"kragmar_speargrass_reach", 21, 30},
		{"kragmar_bannerbreak_mesa", 31, 40},
		{"kragmar_kapok_cradle", 1, 10},
		{"kragmar_raincall_basin", 11, 20},
		{"kragmar_kezamba", 20, 30, true},
		{"kragmar_whispering_reedlands", 21, 30},
		{"kragmar_totemwater_reach", 21, 30},
		{"kragmar_thunderroot_wilds", 31, 40},
		{"front_wyrmglass_crown", 60, 60},
		{"front_gravesalt_escarpment", 51, 59},
		{"front_broken_causeway", 31, 40},
		{"front_shattered_line", 41, 50},
		{"front_skyglass_canopy", 51, 59},
		{"front_stormscale_summit", 60, 60},
	}

	local casts = 0
	for i = 1, #zones do
		local zone = zones[i]
		for band = 1, 3 do
			local midpoint = math.floor(zone[2] +
				(zone[3] - zone[2]) * (band * 2 - 1) / 6)
			assert(midpoint >= zone[2] and midpoint <= zone[3])
			local day_cast = assert(grug_mobs.zone_clock_cast(zone[1], "day"))
			local night_cast = assert(grug_mobs.zone_clock_cast(zone[1], "night"))
			if zone[4] then
				assert(#day_cast == 0 and #night_cast == 0,
					"capital cast is not empty: " .. zone[1])
			else
				assert(#day_cast > 0, "empty day cast: " .. zone[1])
				assert(#night_cast > 0, "empty night cast: " .. zone[1])
			end
			casts = casts + 2
		end
	end
	assert(#zones == 38 and casts == 228)
	local mountain_night = table.concat(assert(grug_mobs.zone_clock_cast(
		"elandor_frostbarrow_shelf", "night")), ",")
	assert(mountain_night:find("grug_mobs:skeleton_archer", 1, true),
		"mountain night fallback missing")
	local lorindor_night = table.concat(assert(grug_mobs.zone_clock_cast(
		"elandor_lorindor", "night")), ",")
	assert(lorindor_night == "grug_mobs:skeleton_archer",
		"Lorindor fallback changed its exact day roster")

	current_zone, current_biome = "elandor_hearthpine_vale", "grug_meadows"
	current_time = 0.5
	assert(grug_mobs.spawn_clock_allows("grug_mobs:boar", {x = 0, y = 1, z = 0}))
	assert(not grug_mobs.spawn_clock_allows("grug_mobs:giant_spider",
		{x = 0, y = 1, z = 0}))
	current_time = 0.9
	assert(not grug_mobs.spawn_clock_allows("grug_mobs:boar", {x = 0, y = 1, z = 0}))
	assert(grug_mobs.spawn_clock_allows("grug_mobs:giant_spider",
		{x = 0, y = 1, z = 0}))
	current_zone, current_biome = "kragmar_stillgrave_hollow", "grug_blight"
	assert(grug_mobs.spawn_clock_allows("grug_mobs:zombie", {x = 0, y = 1, z = 0}))
	current_time = 0.5
	assert(grug_mobs.spawn_clock_allows("grug_mobs:zombie", {x = 0, y = 1, z = 0}))
	assert(grug_mobs.spawn_clock_allows("grug_mobs:giant_spider",
		{x = 0, y = -100, z = 0}))

	local handle = assert(io.open(root .. "/mods/ENTITIES/grug_mobs/boar.lua", "rb"))
	local boar_source = assert(handle:read("*a"))
	handle:close()
	assert(boar_source:find('clock = "day"', 1, true),
		"Boar clock declaration changed")

	return "r8_mob1_clock_v1|zones=38|band_casts=228|night_factor=5/4|fallbacks=6\n"
end
