-- R8-MOB1 package 4 real-code KAT.

return function(root)
	assert(type(root) == "string" and root:sub(1, 1) == "/",
		"night-family KAT requires an absolute repository root")
	local zone_id, timeofday = "elandor_copperfell_foothills", 0.9
	grug_mobs = {}
	grug_core = {start_identities = function()
		local out = {}
		for i = 1, 6 do out[i] = {anchor = {x = i * 10000, z = i * 10000}} end
		return out
	end}
	grug_zones = {
		id_at = function() return zone_id end,
		biome_at = function() return "grug_crags" end,
		pvp_rule_at = function() return "contested" end,
		race_region_at = function() return "dwarf" end,
	}
	core = {get_timeofday = function() return timeofday end}
	dofile(root .. "/mods/ENTITIES/grug_mobs/spawn_policy.lua")

	local definitions, rows, arrows = {}, {}, {}
	function grug_mobs.register_mob(name, def)
		grug_mobs.register_spawn_role(name, def)
		definitions[name] = def
	end
	function grug_mobs.camp_swarm(def) def._kat_swarm = true end
	function grug_mobs.stalker(def) def._kat_stalker = true end
	function grug_mobs.stamp_arrow_damage() end
	function grug_mobs.atlas_textures(name, count)
		local out = {}
		for i = 1, count do out[i] = name end
		return out
	end
	function grug_mobs.poison_player() end
	function grug_mobs.slow_player() end
	function grug_mobs.slow() end
	mobs = {}
	function mobs:spawn(def) rows[#rows + 1] = grug_mobs.prepare_spawn_row(def) end
	function mobs:register_arrow(name, def) arrows[name] = def end

	dofile(root .. "/mods/ENTITIES/grug_mobs/night_families.lua")

	local expected = {
		goblin_raider = {mesh = "grug_mobs_goblin.b3d", aoc = 3},
		goblin_slinger = {mesh = "grug_mobs_goblin.b3d", aoc = 2,
			arrow = "grug_mobs:rock_entity"},
		goblin_hound = {mesh = "grug_mobs_goblin_hound.b3d", aoc = 2},
		snow_leopard = {mesh = "grug_mobs_panther.b3d", aoc = 4},
		wisp = {mesh = "grug_mobs_wisp.b3d", aoc = 4},
		ashen_treant = {mesh = "grug_mobs_treant.b3d", aoc = 3},
		gravewood_treant = {mesh = "grug_mobs_treant.b3d", aoc = 3},
	}
	local count = 0
	for short, spec in pairs(expected) do
		local def = assert(definitions["grug_mobs:" .. short], short)
		assert(def.clock == "night", "clock differs for grug_mobs:" .. short)
		assert(def.mesh == spec.mesh and def.animation, "visual differs for " .. short)
		assert(def.hp_min == nil and def.hp_max == nil and def.damage == nil and
			def._grug_xp_reward == nil, "hand-owned stats in " .. short)
		if spec.arrow then assert(def.arrow == spec.arrow) end
		count = count + 1
	end
	assert(count == 7 and #rows == 7)
	for i = 1, #rows do
		local row = rows[i]
		local short = row.name:match("^grug_mobs:(.+)$")
		assert(row.max_light == 5 and row.day_toggle == false)
		assert(row.active_object_count == expected[short].aoc,
			"night aoc differs for " .. short)
	end
	assert(definitions["grug_mobs:goblin_raider"]._kat_swarm)
	local slinger = definitions["grug_mobs:goblin_slinger"]
	assert(slinger.attack_type == "dogshoot" and
		slinger.animation.shoot_start == slinger.animation.punch_start and
		slinger.animation.shoot_end == slinger.animation.punch_end,
		"Goblin Slinger dogshoot has no real animation range")
	assert(definitions["grug_mobs:snow_leopard"]._kat_stalker)
	assert(type(definitions["grug_mobs:wisp"].do_custom) == "function")
	assert(type(definitions["grug_mobs:ashen_treant"].do_custom) == "function")

	local routes = {
		goblin_raider = "kragmar_speargrass_reach",
		goblin_slinger = "elandor_frostbarrow_shelf",
		goblin_hound = "kragmar_bannerbreak_mesa",
		snow_leopard = "elandor_stormvault_heights",
		wisp = "elandor_whitebridge_shire",
		ashen_treant = "elandor_ashenward_march",
		gravewood_treant = "kragmar_ossuary_reach",
	}
	local pos = {x = 0, y = 20, z = 0}
	for short, route in pairs(routes) do
		zone_id = route
		assert(grug_mobs.spawn_policy_allows("grug_mobs:" .. short, pos),
			"route rejected for " .. short)
	end
	timeofday = 0.5
	zone_id = "elandor_whitebridge_shire"
	assert(not grug_mobs.spawn_policy_allows("grug_mobs:wisp", pos),
		"night family allowed by day")

	local ledger = assert(io.open(root ..
		"/mods/ENTITIES/grug_mobs/LICENSE-media.md", "rb"))
	local ledger_text = assert(ledger:read("*a"))
	ledger:close()
	for _, mesh in ipairs({"grug_mobs_goblin.b3d", "grug_mobs_goblin_hound.b3d",
		"grug_mobs_wisp.b3d", "grug_mobs_treant.b3d"}) do
		local file = assert(io.open(root .. "/mods/ENTITIES/grug_mobs/models/" ..
			mesh, "rb"))
		assert(file:read(4) == "BB3D")
		file:close()
		assert(ledger_text:find("`" .. mesh .. "`", 1, true), mesh)
	end

	return "r8_mob1_night_v1|families=7|rows=7|meshes=4\n"
end
