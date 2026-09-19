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
	local cache = coast.new_lattice_cache(4)
	local builds = 0
	local function mixed_lattice(chunk_x, chunk_z)
		builds = builds + 1
		local values = {}
		for index = 1, 16 do
			local mixed = (chunk_x * 37 + chunk_z * 19 + index * 11) % 7
			values[index] = mixed < 2 and "water" or mixed == 2 and "cave" or "stone"
		end
		return values
	end
	local sequence = {{-2, -1}, {-1, -1}, {-2, 0}, {-1, 0}, {-2, -1},
		{-1, -1}, {-2, 0}, {-1, 0}}
	for sequence_index = 1, #sequence do
		local chunk_x, chunk_z = sequence[sequence_index][1], sequence[sequence_index][2]
		local reference = mixed_lattice(chunk_x, chunk_z)
		local optimized = cache.get(chunk_x, chunk_z, mixed_lattice)
		for index = 1, #reference do
			check(reference[index] == optimized[index],
				"cached lattice differs from mixed reference fixture")
		end
	end
	check(builds == 12, "four-entry lattice cache rebuilt a resident chunk")
	local stable_profile, stable_class = coast.profile(2, 1, -44, false,
		"highland", 24)
	check(coast.run_key(2, 1, -44, stable_class) == "2/1/-44/sea_highland",
		"ordinary run identity differs")
	local low_profile, low_class = coast.profile(2, 1, -44, false,
		"wetland_delta", 24)
	check(low_class == "sea_wetland_delta" and
		coast.run_key(2, 1, -44, low_class) ~=
		coast.run_key(2, 1, -44, stable_class), "fallback run was not split")
	check(stable_profile == coast.profile(2, 1, -44, false, "highland", 7),
		"one stable run changed profile")
	local relief_ids = {"wetland_delta", "lowland", "rolling_hills", "plateau",
		"highland", "mountain"}
	local relief_beaches, counts = {},
		{beach = 0, bluff = 0, cliff = 0, terraced_cliff = 0}
	for relief_index = 1, #relief_ids do
		local relief_id = relief_ids[relief_index]
		local sea_beaches, fresh_beaches = 0, 0
		for run = -1000, 1000 do
			local profile = coast.profile(7, 2, run, false, relief_id, 24)
			local freshwater = coast.profile(7, 2, run, true, relief_id, 24)
			counts[profile] = counts[profile] + 1
			if profile == "beach" then sea_beaches = sea_beaches + 1 end
			if freshwater == "beach" then fresh_beaches = fresh_beaches + 1 end
			check(profile == coast.profile(7, 2, run, false, relief_id, 24),
				"profile is not deterministic")
		end
		relief_beaches[relief_id] = sea_beaches
		if relief_id == "mountain" then
			check(sea_beaches == 0 and fresh_beaches == 0,
				"mountain shore selected sand")
		elseif relief_id == "plateau" or relief_id == "highland" then
			check(fresh_beaches == 0, relief_id .. " freshwater rim selected sand")
		else
			check(fresh_beaches > 0, relief_id .. " freshwater sand rim is absent")
		end
	end
	check(relief_beaches.wetland_delta > relief_beaches.lowland and
		relief_beaches.lowland > relief_beaches.rolling_hills and
		relief_beaches.rolling_hills > relief_beaches.plateau and
		relief_beaches.plateau > relief_beaches.highland and
		relief_beaches.highland > relief_beaches.mountain,
		"six relief-profile beach shares are not descending")
	for draw = 0, 999 do
		local width, rise, blend = coast.band(draw, "beach", false)
		check(width >= 20 and width <= 28 and rise >= 2 and rise <= 5 and
			blend >= 16 and blend <= 24, "sea beach band bounds differ")
		local fresh_width = coast.band(draw, "beach", true)
		check(fresh_width >= 2 and fresh_width <= 4,
			"freshwater beach rim bounds differ")
	end
	local top, filler, depth = coast_surface_rule("beach", false, 7)
	check(top == "default:sand" and filler == "default:sandstone" and depth == 3,
		"sea beach material differs")
	check(coast_surface_rule("beach", true, 4) == "default:sand",
		"freshwater sand rim differs")
	check(select(2, coast_surface_rule("bluff", false, 3)) == "default:gravel" and
		select(2, coast_surface_rule("cliff", false, 3)) == "default:stone" and
		select(2, coast_surface_rule("cliff", true, 1)) == "default:stone",
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
		"relief_beaches\t" .. table.concat({relief_beaches.wetland_delta,
			relief_beaches.lowland, relief_beaches.rolling_hills,
			relief_beaches.plateau, relief_beaches.highland,
			relief_beaches.mountain}, "/"),
		"strata\t200/min_distinct=" .. distinct_min .. "/clay_hits=" .. clay_columns ..
			"/floor_clips=" .. clipped,
		cave_rows, writer_rows}, "\n")
end
