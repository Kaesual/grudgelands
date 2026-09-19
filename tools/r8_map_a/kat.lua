-- Portable R8-MAP-A rule KAT.  Fixed-layout populations remain LuaJIT-only;
-- this file exercises the production rule functions under both interpreters.

return function(root)
	local function check(condition, message)
		if not condition then error("R8-MAP-A KAT: " .. message, 0) end
	end
	local _, coast_factory = dofile(root ..
		"/mods/MAPGEN/grug_mapgen/wp40/height.lua")
	local _, coast_surface_rule = dofile(root ..
		"/mods/MAPGEN/grug_mapgen/wp40/r6_content.lua")
	local settlement = dofile(root ..
		"/mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua")
	local source = dofile(root ..
		"/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua")

	local coast = coast_factory("0")
	local stable_profile, stable_class = coast.profile(2, 1, -44, false,
		"highland", 24)
	check(coast.run_key(2, 1, -44, stable_class) == "2/1/-44/sea_ordinary",
		"ordinary run identity differs")
	local low_profile, low_class = coast.profile(2, 1, -44, false,
		"wetland_delta", 24)
	check(low_class == "sea_low" and
		coast.run_key(2, 1, -44, low_class) ~=
		coast.run_key(2, 1, -44, stable_class), "fallback run was not split")
	check(stable_profile == coast.profile(2, 1, -44, false, "highland", 7),
		"one stable run changed profile")
	local counts = {beach = 0, bluff = 0, cliff = 0, terraced_cliff = 0}
	local total = 0
	for owner = 1, 38 do
		for orientation = 1, 4 do
			for run = -80, 80 do
				local profile = coast.profile(owner, orientation, run, false,
					"highland", 24)
				counts[profile] = counts[profile] + 1
				total = total + 1
				check(profile == coast.profile(owner, orientation, run, false,
					"highland", 24), "profile is not deterministic")
			end
		end
	end
	local expected = {beach = 40, bluff = 25, cliff = 20, terraced_cliff = 15}
	for profile, percentage in pairs(expected) do
		local actual = counts[profile] * 100 / total
		check(math.abs(actual - percentage) <= 2,
			profile .. " synthetic mix differs")
	end
	for run = -1000, 1000 do
		local freshwater = coast.profile(7, 2, run, true, "rolling_hills", 20)
		check(freshwater == "beach" or freshwater == "bluff",
			"freshwater selected abrupt profile")
		local low = coast.profile(18, 4, run, false, "wetland_delta", 30)
		check(low == "beach" or low == "bluff", "wetland fallback differs")
	end

	local top, filler, depth = coast_surface_rule("beach", false, 7)
	check(top == "default:sand" and filler == "default:sandstone" and depth == 3,
		"sea beach material differs")
	check(coast_surface_rule("beach", true, 2) == "default:sand" and
		coast_surface_rule("beach", true, 3) == nil,
		"freshwater sand lip differs")
	check(select(2, coast_surface_rule("bluff", false, 3)) == "default:gravel" and
		select(2, coast_surface_rule("cliff", false, 3)) == "default:stone" and
		coast_surface_rule("cliff", true, 1) == nil,
		"non-beach coast material differs")

	local strata = settlement.r8_strata_new("0", source)
	local distinct_min, clay_columns, clipped = 99, 0, 0
	for sample = 1, 200 do
		local zone = source.zones[(sample - 1) % #source.zones + 1]
		local biome = zone.biomes[(sample - 1) % #zone.biomes + 1].id
		local x = zone.hub.x + (sample * 37 % 121) - 60
		local z = zone.hub.z + (sample * 53 % 121) - 60
		local materials = {}
		for depth_index = 4, 40 do
			local material = strata.material_at(zone.id, biome, 3, x, z, depth_index)
			if material and material ~= "default:dirt" and material ~= "default:stone" then
				materials[material] = true
			end
			if material == "default:clay" then clay_columns = clay_columns + 1 end
			if 1 - depth_index < -37 then clipped = clipped + 1 end
		end
		local count = 0
		for _ in pairs(materials) do count = count + 1 end
		if count < distinct_min then distinct_min = count end
		check(count >= 2, "sample shaft lacks two non-stone/non-dirt materials")
	end
	check(clay_columns > 0 and clipped > 0, "clay or authored-floor clip absent")
	check(strata.secondary_for("grug_savanna") == "default:sandstone" and
		strata.secondary_for("grug_badlands") == "grug_materials:basalt" and
		strata.secondary_for("grug_meadows") == "default:desert_stone" and
		strata.secondary_for("grug_pine_hills") == "grug_materials:slate" and
		strata.secondary_for("grug_deep_jungle") == "default:mossycobble",
		"secondary palette mapping differs")

	local cave_rows = dofile(root .. "/tools/wp40/quality/cave_fixture.lua")(root)
	check(cave_rows:find("schema\tgrug_wp40_quality_caves_v2", 1, true) and
		cave_rows:find("hillside\t", 1, true) and
		cave_rows:find("sinkhole\t", 1, true), "mouth placement fixture differs")

	local writer_rows = dofile(root .. "/tools/r8_map_a/writer_kat.lua")(root)
	return table.concat({"schema\tgrug_r8_map_a_kat_v1",
		"profile_mix\t" .. counts.beach .. "/" .. counts.bluff .. "/" ..
			counts.cliff .. "/" .. counts.terraced_cliff,
		"strata\t200/min_distinct=" .. distinct_min .. "/clay_hits=" .. clay_columns ..
			"/floor_clips=" .. clipped,
		cave_rows, writer_rows}, "\n")
end
