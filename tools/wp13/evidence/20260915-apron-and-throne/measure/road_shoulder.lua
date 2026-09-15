-- The vegetation shoulder beside the gate approach. For each start and a few z
-- rows on the approach, the smallest lateral distance at which a biome
-- decoration may host
-- (the planner's predicate), and the same for an ordinary stretch of the same
-- primary route well away from the start. A start approach must not host closer
-- to its carriageway than an ordinary road of the same class does.
--
-- Round-B's script, with three rows added per start: playtest round 1 opens the
-- ten-node protection apron to vegetation, and the gate road CROSSES that
-- apron, so the three offsets 65/69/73 are the ones that prove the road keeps
-- its own clear corridor where the new hosts are. The round-B offsets are kept
-- exactly as they were, so the two rounds' numbers stay comparable.
local repo, seed, output = assert(arg[1]), assert(arg[2]), assert(arg[3])
local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local src = dofile(directory .. "/source/simple_map.lua")
local canonical = dofile(directory .. "/canonical.lua")
local deterministic = dofile(directory .. "/deterministic.lua")
local raw_sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local horizontal = dofile(directory .. "/simple_map.lua")({source = src,
	schemas = dofile(directory .. "/schemas.lua"), canonical = canonical,
	deterministic = deterministic, raw_sha256 = raw_sha256}).new(seed)
local height = dofile(directory .. "/height.lua")({source = src,
	canonical = canonical, deterministic = deterministic, raw_sha256 = raw_sha256,
	horizontal_session = horizontal, coupled_grade = dofile(directory .. "/coupled_grade.lua")(),
}).new_runtime(seed)
local start_anchor = {}
for index = 1, #src.anchors do
	local anchor = src.anchors[index]
	if anchor.slot_id == "start" then start_anchor[anchor.zone_numeric_id] = anchor end
end
-- A column may host a biome decoration when no functional surface owns it, or
-- when it is this start's own dry grade and the vegetation exclusion set lets it
-- (`r6_planner.lua`'s `dry_start_grade`).
local function hosts(x, z, anchor_id)
	local kind, _, feature = height.functional_surface_values_at(x, z)
	if kind == nil then
		return horizontal.static_exclusion_values_at(x, z, "vegetation") == nil
	end
	if kind ~= "land_grade" or feature ~= anchor_id then return false end
	return horizontal.static_exclusion_values_at(x, z, "vegetation") == nil
end
local file = assert(io.open(output, "wb"))
file:write("seed\t", seed, "\n")
file:write("start\troute\tkind\tz_offset\tfirst_host_west\tfirst_host_east\n")
for index = 1, #src.routes do
	local route = src.routes[index]
	local anchor = start_anchor[route.zone_a]
	if anchor then
		local hub = src.zones[route.zone_a].hub
		local sign = src.zones[route.zone_b].hub.z > hub.z and 1 or -1
		for _, row in ipairs({{65, "apron"}, {69, "apron"}, {73, "apron"},
				{80, "approach"}, {100, "approach"}, {120, "approach"}}) do
			local offset, kind = row[1], row[2]
			local z = hub.z + sign * offset
			local west, east
			for dx = 0, 40 do
				if not west and hosts(hub.x - dx, z, anchor.id) then west = dx end
				if not east and hosts(hub.x + dx, z, anchor.id) then east = dx end
			end
			file:write(table.concat({anchor.id, route.id, kind, offset,
				west or ">40", east or ">40"}, "\t"), "\n")
		end
		-- The same route where it is an ordinary primary: the row through its
		-- authored crossing pin, which is 360-405 nodes out and owned by nobody.
		local pin = route.centreline[route.pinned_point_index]
		local west, east
		for dx = 0, 40 do
			if not west and hosts(pin.x - dx, pin.z, anchor.id) then west = dx end
			if not east and hosts(pin.x + dx, pin.z, anchor.id) then east = dx end
		end
		file:write(table.concat({anchor.id, route.id, "ordinary", "pin",
			west or ">40", east or ">40"}, "\t"), "\n")
	end
end
assert(file:close())
print("road_shoulder\tok\t" .. output)
