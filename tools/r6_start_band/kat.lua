-- Real-code KAT for the deterministic inner level band around all six starts.

return function(repo)
	assert(type(repo) == "string" and repo:sub(1, 1) == "/",
		"absolute repository root required")

	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local source = dofile(wp40 .. "/source/simple_map.lua")
	local schemas = dofile(wp40 .. "/schemas.lua")
	local canonical = dofile(wp40 .. "/canonical.lua")
	local deterministic = dofile(wp40 .. "/deterministic.lua")
	local horizontal_factory = dofile(wp40 .. "/simple_map.lua")
	local raw_sha256 = common.new_sha256()
	local zones_module = dofile(wp40 .. "/zones.lua")({
		source = source,
		schemas = schemas,
		canonical = canonical,
		deterministic = deterministic,
		index128 = dofile(wp40 .. "/index128.lua"),
		horizontal_factory = horizontal_factory,
		height_factory = dofile(wp40 .. "/height.lua"),
		coupled_grade = dofile(wp40 .. "/coupled_grade.lua")(),
		raw_sha256 = raw_sha256,
	})
	local session = zones_module.new_runtime("0", 1)
	local horizontal = horizontal_factory({
		source = source,
		schemas = schemas,
		canonical = canonical,
		deterministic = deterministic,
		raw_sha256 = raw_sha256,
	}).new("0")

	local starts = {
		{"elandor_hearthpine_vale", -1800, -2550, 1},
		{"elandor_dawnmere_fields", 0, -2550, 1},
		{"elandor_silverleaf_glades", 1800, -2550, 1},
		{"kragmar_stillgrave_hollow", -1800, 2550, -1},
		{"kragmar_sunscar_flats", 0, 2550, -1},
		{"kragmar_kapok_cradle", 1800, 2550, -1},
	}
	local cardinal = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
	local circle = {
		{150, 0}, {106, 106}, {0, 150}, {-106, 106},
		{-150, 0}, {-106, -106}, {0, -150}, {106, -106},
	}
	local rows = {"schema\tgrug_r6_start_band_kat_v1\n"}
	local sample_count = 0

	local function check(ok, message)
		if not ok then error("R6 start-band KAT: " .. message, 0) end
	end

	local function level_at(x, z, context)
		local level = session.surface_mob_level_at(x, z)
		check(type(level) == "number" and level % 1 == 0,
			context .. " is not an integer level")
		check(session.surface_mob_level_at(x, z) == level,
			context .. " is not deterministic")
		sample_count = sample_count + 1
		return level
	end

	for start_index = 1, #starts do
		local expected = starts[start_index]
		local zone_id, anchor_x, anchor_z, front_sign =
			expected[1], expected[2], expected[3], expected[4]
		local anchor = session.anchor(zone_id, "start")
		check(anchor and anchor.x == anchor_x and anchor.z == anchor_z,
			"authored start anchor differs for " .. zone_id)
		local zone = session.get(zone_id)
		check(zone.level_min == 1 and zone.level_max == 10,
			"outer start-zone range differs for " .. zone_id)

		for _, radius in ipairs({0, 50, 100, 150}) do
			local expected_level = radius <= 100 and 1 or 2
			for direction_index = 1, #cardinal do
				local direction = cardinal[direction_index]
				local level = level_at(anchor_x + direction[1] * radius,
					anchor_z + direction[2] * radius,
					zone_id .. " cardinal radius " .. radius)
				check(level == expected_level,
					zone_id .. " radius " .. radius .. " expected " ..
					expected_level .. ", got " .. level)
			end
		end

		for sample_index = 1, #circle do
			local offset = circle[sample_index]
			local level = level_at(anchor_x + offset[1], anchor_z + offset[2],
				zone_id .. " 150 m circle sample " .. sample_index)
			check(level <= 2, zone_id .. " 150 m circle exceeds level 2")
		end

		local level_150 = level_at(anchor_x, anchor_z + front_sign * 150,
			zone_id .. " front 150")
		local level_300 = level_at(anchor_x, anchor_z + front_sign * 300,
			zone_id .. " front 300")
		local level_600 = level_at(anchor_x, anchor_z + front_sign * 600,
			zone_id .. " front 600")
		check(level_300 >= level_150 and level_600 >= level_300,
			zone_id .. " front progression is not monotone")

		for direction_index = 1, #cardinal do
			local direction = cardinal[direction_index]
			local x = anchor_x + direction[1] * 151
			local z = anchor_z + direction[2] * 151
			local _, macro_region = horizontal.classification_values_at(x, z)
			local unbanded = horizontal.difficulty_for_macro_at(x, z, macro_region)
			check(level_at(x, z, zone_id .. " unbanded radius 151") == unbanded,
				zone_id .. " changed the existing curve beyond 150 m")
		end

		check(session.guard_level_at({x = anchor_x, y = 0, z = anchor_z}) == 20,
			"guard contract changed at " .. zone_id)
		rows[#rows + 1] = table.concat({zone_id, anchor_x, anchor_z,
			level_150, level_300, level_600}, "\t") .. "\n"
	end

	local body = table.concat(rows) .. "samples\t" .. sample_count .. "\n"
	local digest = common.hex(raw_sha256(body))
	return body .. "output_sha256\t" .. digest .. "\n"
end
