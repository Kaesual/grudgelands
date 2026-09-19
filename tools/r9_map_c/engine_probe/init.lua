-- Disposable seed-0 witness for the shipped MAP-C terrain features.

grug_r9_map_c_engine_probe = {}

local function chunk_origin(value)
	local block = math.floor(value / 16)
	return (math.floor((block + 2) / 5) * 5 - 2) * 16
end

local function node_name(x, y, z)
	return core.get_node({x = x, y = y, z = z}).name
end

local function action(parts)
	core.log("action", "GRUG_R9_MAP_C_WITNESS " .. table.concat(parts, " "))
end

local cases = {
	{id = "wet", relief = "wetland_delta", x = -1800, z = 2050},
	{id = "rolling", relief = "rolling_hills", x = -1800, z = -2050},
	{id = "mountain", relief = "mountain", x = -3150, z = 0},
	{id = "opening_search_a", relief = "lowland", x = -2085, z = -2783},
	{id = "opening_search_b", relief = "lowland", x = -2225, z = -2637},
	{id = "opening_search_c", relief = "lowland", x = -1422, z = -2470},
	{id = "coast_band", relief = "lowland", x = 1784, z = -2960,
		coast_profile = "beach/1/25/false/11/2/-62/sea_lowland/1/lowland"},
	{id = "plate_surface", relief = "lowland", x = -1696, z = -2522},
	{id = "plate_deep", relief = "lowland", x = -1696, y = -37, z = -2522},
	{id = "snowy_crags_opening", relief = "highland", x = -2196, z = -1031,
		snowy_opening = true},
}

local snowy_witness_found = false

local function inspect(case, origin)
	local terrain_y = grug_zones.terrain_height_at(case.x, case.z)
	if case.id == "plate_deep" then
		local nodes = {}
		for y = -37, -33 do nodes[#nodes + 1] = y .. ":" .. node_name(case.x, y, case.z) end
		action({"case=plate", "x=" .. case.x, "z=" .. case.z,
			"terrain_y=" .. terrain_y, "nodes=" .. table.concat(nodes, ",")})
		return
	end
	action({"case=" .. case.id, "relief=" .. case.relief, "x=" .. case.x,
		"z=" .. case.z, "terrain_y=" .. terrain_y,
		"surface=" .. node_name(case.x, terrain_y, case.z),
		"below=" .. node_name(case.x, terrain_y - 1, case.z),
		"above=" .. node_name(case.x, terrain_y + 1, case.z)})
	if case.coast_profile then
		action({"case=coast_band_active", "x=" .. case.x, "z=" .. case.z,
			"profile=" .. case.coast_profile,
			"enabled=" .. tostring(core.settings:get_bool(
				"grug_mapgen_r9_coast_band_enabled", true)),
			"surface=" .. node_name(case.x, terrain_y, case.z)})
	end
	local found
	if case.snowy_opening then
		for z = origin.z, origin.z + 79 do
			for x = origin.x, origin.x + 79 do
				local y = grug_zones.terrain_height_at(x, z)
				local above = node_name(x, y + 1, z)
				if grug_zones.biome_at(x, z) == "grug_crags_snowy" and
						grug_zones.water_class_at(x, z) == "land" and
						node_name(x, y, z) == "air" and above ~= "default:snow" and
						above ~= "ignore" then
					found = {x = x, y = y, z = z}
					break
				end
			end
			if found then break end
		end
	else
		for z = origin.z, origin.z + 79 do
			for x = origin.x, origin.x + 79 do
				local y = grug_zones.terrain_height_at(x, z)
				local surface_air = node_name(x, y, z) == "air"
				local deep_open = surface_air and node_name(x, y - 1, z) == "air" and
					node_name(x, y - 2, z) == "air" and
					node_name(x, y - 3, z) == "air" and
					node_name(x, y - 4, z) == "air"
				if grug_zones.water_class_at(x, z) == "land" and deep_open then
					found = {x = x, y = y, z = z}
					break
				end
			end
			if found then break end
		end
	end
	if found then
		if case.snowy_opening then
			local above = node_name(found.x, found.y + 1, found.z)
			action({"case=snowy_crags_opening", "region=" .. case.id,
				"biome=" .. tostring(grug_zones.biome_at(found.x, found.z)),
				"x=" .. found.x, "y=" .. found.y, "z=" .. found.z,
				"surface=air", "above=" .. above})
			if above == "default:snow" or above == "ignore" then
				error("MAP-C snowy opening retained snow at T+1", 0)
			end
			snowy_witness_found = true
		else
			action({"case=natural_opening", "region=" .. case.id, "x=" .. found.x,
				"y=" .. found.y, "z=" .. found.z, "run=5_air"})
		end
	else
		action({"case=natural_opening", "region=" .. case.id, "result=none"})
	end
end

local current = 0
local function run_next()
	current = current + 1
	local case = cases[current]
	if not case then
		if not snowy_witness_found then
			error("MAP-C snowy-crags opening witness is absent", 0)
		end
		action({"case=complete", "mgv7_spflags=" ..
			tostring(core.get_mapgen_setting("mgv7_spflags"))})
		core.request_shutdown("MAP-C witness complete", false, 0)
		return
	end
	if case.snowy_opening and snowy_witness_found then
		core.after(0, run_next)
		return
	end
	local y = case.y or grug_zones.terrain_height_at(case.x, case.z)
	local origin = {x = chunk_origin(case.x), y = chunk_origin(y),
		z = chunk_origin(case.z)}
	local maxp = {x = origin.x + 79,
		y = origin.y + (case.snowy_opening and 80 or 79), z = origin.z + 79}
	core.emerge_area(origin, maxp, function(_, _, remaining)
		if remaining ~= 0 then return end
		inspect(case, origin)
		core.after(0, run_next)
	end)
end

core.after(0, run_next)
