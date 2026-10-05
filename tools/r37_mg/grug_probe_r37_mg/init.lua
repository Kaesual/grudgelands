-- Round 37 lane MG engine probe (tools/r37_mg/engine.sh; disposable, never
-- shipped): the before/after pair of the decoration-halo change (MGT-02).
--
-- On a fresh world it emerges one region, 5 x 5 chunk columns round the
-- Hearthpine start (anchor_001 at -1800, -2550: the town, its band and the
-- forest round it), every vertical chunk from the lowest planned ground to 40
-- nodes over the highest, and then digests every generated owner inside the
-- region: per z row the content name, param2 and light of every voxel, one
-- SHA-256 per owner, one over all owners in key order. The run before and
-- the run after must print the same digest. The per-chunk planner and writer
-- times come from the profiler's mapgen patch (GAME_PATCH, tools/wp40/profile/
-- instrument-mapgen.patch). Every line carries "[r37_mg_probe]"; the probe
-- ends the server.
local PREFIX = "[r37_mg_probe] "
local function log(message) core.log("action", PREFIX .. message) end

local CENTER_X, CENTER_Z, HALF = -1800, -2550, 2
local function chunk_origin(value)
	local block = math.floor(value / 16)
	return (math.floor((block + 2) / 5) * 5 - 2) * 16
end
local ox, oz = chunk_origin(CENTER_X), chunk_origin(CENTER_Z)
local min_x, max_x = ox - HALF * 80, ox + (HALF + 1) * 80 - 1
local min_z, max_z = oz - HALF * 80, oz + (HALF + 1) * 80 - 1

local planner = grug_mapgen.wp40.planner_source
local low, high = math.huge, -math.huge
for z = min_z, max_z, 4 do
	for x = min_x, max_x, 4 do
		local terrain_y = select(6, planner.column_values_at(x, z))
		if terrain_y < low then low = terrain_y end
		if terrain_y > high then high = terrain_y end
	end
end
local min_y, max_y = chunk_origin(low - 1), chunk_origin(high + 40) + 79

local generated = {}
core.register_on_generated(function(minp)
	if minp.x >= min_x and minp.x <= max_x and minp.y >= min_y and minp.y <= max_y and
			minp.z >= min_z and minp.z <= max_z then
		generated[#generated + 1] = {x = minp.x, y = minp.y, z = minp.z}
	end
end)

local name_of = {}
local function digest_owner(origin)
	local vm = core.get_voxel_manip()
	local maxp = {x = origin.x + 79, y = origin.y + 79, z = origin.z + 79}
	local emin, emax = vm:read_from_map(origin, maxp)
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	local data, param2, light = vm:get_data(), vm:get_param2_data(), vm:get_light_data()
	local rows = {}
	for z = origin.z, maxp.z do
		local parts = {}
		for y = origin.y, maxp.y do
			local i = area:index(origin.x, y, z)
			for _ = 0, 79 do
				local id = data[i]
				local name = name_of[id]
				if not name then
					name = core.get_name_from_content_id(id)
					name_of[id] = name
				end
				parts[#parts + 1] = name .. ":" .. param2[i] .. ":" .. light[i]
				i = i + 1
			end
		end
		rows[#rows + 1] = core.sha256(table.concat(parts, ";"))
	end
	return core.sha256(table.concat(rows, "\n"))
end

core.after(1, function()
	log(("region x %d..%d y %d..%d z %d..%d (planned ground %d..%d)"):format(
		min_x, max_x, min_y, max_y, min_z, max_z, low, high))
	local started = core.get_us_time()
	core.emerge_area({x = min_x, y = min_y, z = min_z}, {x = max_x, y = max_y, z = max_z},
		function(_, _, remaining)
			if remaining > 0 then return end
			local seconds = (core.get_us_time() - started) / 1000000
			table.sort(generated, function(a, b)
				if a.x ~= b.x then return a.x < b.x end
				if a.z ~= b.z then return a.z < b.z end
				return a.y < b.y
			end)
			local owners = {}
			for _, origin in ipairs(generated) do
				local digest = digest_owner(origin)
				owners[#owners + 1] = origin.x .. "," .. origin.y .. "," .. origin.z .. "=" .. digest
				log("owner " .. owners[#owners])
			end
			log(("RESULT owners=%d emerge_seconds=%.2f digest=%s"):format(#owners, seconds,
				core.sha256(table.concat(owners, "\n"))))
			core.request_shutdown("r37 mg probe done", false, 0)
		end)
end)
