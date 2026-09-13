-- Reproducible R8 terrain/POI/water quality and timing witness.

local repo, seed, output = assert(arg[1]), assert(arg[2]), assert(arg[3])
local scratch = assert(arg[4])
local counter, cache = 0, {}
local function from_hex(value)
	return (value:gsub("..", function(pair)
		return string.char(assert(tonumber(pair, 16)))
	end))
end
local function raw_sha256(data)
	local cached = cache[data]
	if cached then return cached end
	counter = counter + 1
	local input, digest = scratch .. "/sha-" .. counter .. ".bin",
		scratch .. "/sha-" .. counter .. ".txt"
	local file = assert(io.open(input, "wb")); assert(file:write(data)); file:close()
	local ok, why, code = os.execute("sha256sum " .. input .. " > " .. digest)
	assert(ok == 0 or ok == true and why == "exit" and code == 0)
	file = assert(io.open(digest, "rb")); local line = assert(file:read("*l")); file:close()
	assert(os.remove(input)); assert(os.remove(digest))
	local result = from_hex(assert(line:match("^([0-9a-f]+)")))
	cache[data] = result
	return result
end
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40/"
local source = dofile(wp40 .. "source/simple_map.lua")
local canonical, deterministic = dofile(wp40 .. "canonical.lua"),
	dofile(wp40 .. "deterministic.lua")
local horizontal = dofile(wp40 .. "simple_map.lua")({source = source,
	schemas = dofile(wp40 .. "schemas.lua"), canonical = canonical,
	deterministic = deterministic, raw_sha256 = raw_sha256}).new(seed)
local factory = dofile(wp40 .. "height.lua")({source = source,
	canonical = canonical, deterministic = deterministic, raw_sha256 = raw_sha256,
	horizontal_session = horizontal})

local clock = os.clock()
local height = factory.new(seed)
local construction_seconds = os.clock() - clock
local evidence = height.artifact_evidence()
local absolute, worst, minimax, ordinary = 0, 0, 0, 0
for index = 13, #evidence.anchors do
	local row = evidence.anchors[index]
	local local_worst = math.max(row.observed_max_cut, row.observed_max_fill)
	ordinary = ordinary + 1
	absolute = absolute + local_worst
	worst = math.max(worst, local_worst)
	if row.reference_rule == "ordinary_natural_core_minimax" then minimax = minimax + 1 end
end
local classes, depth_min, depth_max, varied = {}, {}, {}, {}
local samples = 0
clock = os.clock()
for z = -3200, 3200, 32 do
	for x = -3600, 3600, 32 do
		local class = horizontal.water_class_at(x, z)
		local water = height.water_surface_at(x, z)
		local terrain = height.terrain_height_at(x, z)
		if water ~= nil and water > terrain then
			local depth = water - terrain
			classes[class] = (classes[class] or 0) + 1
			depth_min[class] = math.min(depth_min[class] or depth, depth)
			depth_max[class] = math.max(depth_max[class] or depth, depth)
			varied[class .. ":" .. depth] = true
		end
		samples = samples + 1
	end
end
local query_seconds = os.clock() - clock
local file = assert(io.open(output, "wb"))
file:write("seed\t", seed, "\nordinary_anchors\t", ordinary,
	"\nordinary_worst_sum\t", absolute, "\nordinary_worst\t", worst,
	"\nordinary_minimax\t", minimax, "\nconstruction_seconds\t",
	string.format("%.6f", construction_seconds), "\nquery_count\t", samples,
	"\nquery_seconds\t", string.format("%.6f", query_seconds), "\n")
for _, class in ipairs({"planned_water", "coastal_shelf", "deep_ocean",
		"immutable_dragon_channel"}) do
	file:write("water\t", class, "\t", classes[class] or 0, "\t",
		depth_min[class] or 0, "\t", depth_max[class] or 0, "\n")
end
file:close()
