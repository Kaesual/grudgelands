-- R8-MOB1 package 2 real-code KAT.

return function(root)
	assert(type(root) == "string" and root:sub(1, 1) == "/",
		"zero-asset KAT requires an absolute repository root")

	local zone_id = "elandor_goldmead_vale"
	local level = 15
	local timeofday = 0.9
	grug_mobs = {}
	grug_core = {start_identities = function()
		local result = {}
		for i = 1, 6 do result[i] = {anchor = {x = i * 1000, z = i * 1000}} end
		return result
	end}
	grug_zones = {
		id_at = function() return zone_id end,
		biome_at = function() return "grug_meadows" end,
		pvp_rule_at = function() return "contested" end,
		race_region_at = function() return "human" end,
		mob_level_at = function() return level end,
		surface_mob_level_at = function() return level end,
	}
	core = {get_timeofday = function() return timeofday end}
	dofile(root .. "/mods/ENTITIES/grug_mobs/spawn_policy.lua")

	local definitions = {}
	local rows = {}
	function grug_mobs.register_mob(name, def)
		grug_mobs.register_spawn_role(name, def)
		definitions[name] = def
	end
	function grug_mobs.bandit_def(description)
		return {
			description = description, clock = "any", type = "monster",
			_grug_leash_range = 25, _grug_visual = function() return {} end,
			animation = {punch_start = 189, punch_end = 198,
				punch_speed = 30},
			drops = function()
				return {{name = "grug_mobs:linen_cloth", chance = 1,
					min = 1, max = 2}}
			end,
		}
	end
	function grug_mobs.melee_rider(def, rider) def._kat_rider = rider end
	function grug_mobs.slow_player() end
	function grug_mobs.stamp_arrow_damage() end
	mobs = {}
	function mobs:spawn(def) rows[#rows + 1] = grug_mobs.prepare_spawn_row(def) end

	dofile(root .. "/mods/ENTITIES/grug_mobs/zero_asset_variants.lua")

	local expected = {
		poacher = {clock = "night", mesh = nil, surface = true, aoc = 4},
		frost_stray = {clock = "night", mesh = "grug_mobs_skeleton.b3d",
			surface = true, aoc = 4},
		sun_dried_husk = {clock = "night", mesh = "grug_mobs_zombie.b3d",
			surface = true, aoc = 5},
		song_bird = {clock = "day", mesh = "grug_mobs_gull.b3d",
			surface = true, aoc = 2},
		spiderling = {clock = "any", mesh = "grug_mobs_spider.b3d",
			min_y = -100, max_y = -40, aoc = 3},
		blood_bat = {clock = "any", mesh = "grug_mobs_cave_bat.b3d",
			min_y = -300, max_y = -101, aoc = 4},
		stone_mite = {clock = "any", mesh = "grug_mobs_cave_crawler.b3d",
			min_y = -31000, max_y = -700, aoc = 5},
	}
	local count = 0
	for short, spec in pairs(expected) do
		local name = "grug_mobs:" .. short
		local def = assert(definitions[name], "missing family " .. name)
		assert(def.clock == spec.clock, "clock differs for " .. name)
		if spec.mesh then assert(def.mesh == spec.mesh, "mesh differs for " .. name) end
		assert(def.hp_min == nil and def.hp_max == nil and def.damage == nil and
			def._grug_xp_reward == nil, "hand-owned stats in " .. name)
		assert(def.animation or short == "poacher")
		count = count + 1
	end
	assert(count == 7 and #rows == 7)
	local poacher_animation = definitions["grug_mobs:poacher"].animation
	assert(poacher_animation.shoot_start == poacher_animation.punch_start and
		poacher_animation.shoot_end == poacher_animation.punch_end and
		poacher_animation.shoot_speed == poacher_animation.punch_speed,
		"Poacher dogshoot has no real animation range")
	for i = 1, #rows do
		local row = rows[i]
		local short = row.name:match("^grug_mobs:(.+)$")
		local spec = assert(expected[short])
		assert(row.active_object_count == spec.aoc, "aoc differs for " .. short)
		if spec.surface then
			if spec.clock == "day" then
				assert(row.min_light == 10 and row.day_toggle == nil)
			else
				assert(row.max_light == 5 and row.day_toggle == false)
			end
		else
			assert(row.min_height == spec.min_y and row.max_height == spec.max_y)
			assert(row.max_light == 5 and row.day_toggle == nil)
		end
	end

	local pos = {x = 0, y = 20, z = 0}
	local routes = {
		poacher = "elandor_goldmead_vale",
		frost_stray = "elandor_stormvault_heights",
		sun_dried_husk = "kragmar_redtusk_savanna",
		song_bird = "elandor_silverleaf_glades",
	}
	for short, route in pairs(routes) do
		zone_id = route
		timeofday = short == "song_bird" and 0.5 or 0.9
		assert(grug_mobs.spawn_policy_allows("grug_mobs:" .. short, pos),
			"route rejected for " .. short)
	end
	zone_id, level = "elandor_silverleaf_glades", 6
	assert(not definitions["grug_mobs:poacher"]._grug_spawn_check(pos))
	level = 7
	assert(definitions["grug_mobs:poacher"]._grug_spawn_check(pos))
	zone_id, level = "kragmar_sunscar_flats", 6
	assert(not definitions["grug_mobs:sun_dried_husk"]._grug_spawn_check(pos))
	level = 7
	assert(definitions["grug_mobs:sun_dried_husk"]._grug_spawn_check(pos))
	for _, short in ipairs({"spiderling", "blood_bat", "stone_mite"}) do
		assert(grug_mobs.spawn_policy_allows("grug_mobs:" .. short,
			{x = 0, y = -800, z = 0}), "underground route rejected for " .. short)
	end

	local allowed_textures = {
		grug_mobs_bandit_2 = true, grug_mobs_skeleton = true,
		grug_mobs_blank = true, grug_mobs_zombie = true,
		grug_mobs_gull = true, grug_mobs_spider = true,
		grug_mobs_cave_bat = true, grug_mobs_cave_crawler = true,
	}
	for name, def in pairs(definitions) do
		if def.textures then
			for i = 1, #def.textures do
				for n = 1, #def.textures[i] do
					local base = def.textures[i][n]:match("^([^%.%^]+)%.png")
					assert(base and allowed_textures[base],
						"unlisted texture in " .. name .. ": " .. tostring(base))
				end
			end
		end
	end

	local ledger = assert(io.open(root ..
		"/mods/ENTITIES/grug_mobs/LICENSE-media.md", "rb"))
	local ledger_text = assert(ledger:read("*a"))
	ledger:close()
	assert(ledger_text:find("Runtime-only Round 8 variants", 1, true))
	assert(ledger_text:find("Stone Mite", 1, true))

	return "r8_mob1_zero_asset_v1|families=7|surface=4|underground=3|new_media=0\n"
end
