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
	{id = "plate_surface", relief = "lowland", x = -1696, z = -2522},
	{id = "plate_deep", relief = "lowland", x = -1696, y = -37, z = -2522},
}

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
	local found
	for z = origin.z, origin.z + 79 do
		for x = origin.x, origin.x + 79 do
			local y = grug_zones.terrain_height_at(x, z)
			if grug_zones.water_class_at(x, z) == "land" and
					node_name(x, y, z) == "air" and
					node_name(x, y - 1, z) == "air" and
					node_name(x, y - 2, z) == "air" and
					node_name(x, y - 3, z) == "air" and
					node_name(x, y - 4, z) == "air" then
				found = {x = x, y = y, z = z}
				break
			end
		end
		if found then break end
	end
	if found then
		action({"case=natural_opening", "region=" .. case.id, "x=" .. found.x,
			"y=" .. found.y, "z=" .. found.z, "run=5_air"})
	else
		action({"case=natural_opening", "region=" .. case.id, "result=none"})
	end
end

local current = 0
local function run_next()
	current = current + 1
	local case = cases[current]
	if not case then
		action({"case=complete", "mgv7_spflags=" ..
			tostring(core.get_mapgen_setting("mgv7_spflags"))})
		core.request_shutdown("MAP-C witness complete", false, 0)
		return
	end
	local y = case.y or grug_zones.terrain_height_at(case.x, case.z)
	local origin = {x = chunk_origin(case.x), y = chunk_origin(y),
		z = chunk_origin(case.z)}
	local maxp = {x = origin.x + 79, y = origin.y + 79, z = origin.z + 79}
	core.emerge_area(origin, maxp, function(_, _, remaining)
		if remaining ~= 0 then return end
		inspect(case, origin)
		core.after(0, run_next)
	end)
end

core.after(0, run_next)
