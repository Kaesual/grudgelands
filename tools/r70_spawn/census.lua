-- Round 70 lane SPAWN: a whole world's census of chosen surface sources on the
-- seed fleet's harness (tools/seed_fleet/runtime.lua: the real planner and
-- writer, no engine).
--
--   luajit tools/r70_spawn/census.lua REPO SEED [--keys a,b,c] [--part I/N]
--       [--estimate CHUNKS] [--out FILE]
--
-- REPO is the tree measured, so a checkout of an older commit can be counted
-- with this script. Every column of the world's bounds is read once from the
-- planner (zone, biome, water), a candidate list follows from the rows'
-- zones, biomes and shore reach (a superset of what the writers accept), and
-- only the chunks holding a candidate are planned and written.
--
-- For each source and zone it prints a line "source zone eligible written
-- outside":
--   eligible  candidates whose written ground and planned column the renewal
--             authority (vegetation_density.lua `categories`) accepts: the
--             habitat, the shore rule and the claim exclusions;
--   written   source nodes the writer left in the chunks;
--   outside   written nodes the renewal authority does not accept there, each
--             named on stderr with its reason. Writer and renewal read one
--             habitat, so only `writer_bare` columns may land here (a few on
--             the two islands, on the base too: renewal keeps off them).
--
-- --part I/N takes every N-th chunk (a seed's run split over processes; add
-- the parts with tools/r70_spawn/table.py). --estimate K writes K evenly
-- spaced chunks only and prints the projected seconds of the full pass. A
-- chunk costs about a second: run this through the shared process queue.
local repo, seed = arg[1], arg[2]
assert(repo and seed and seed:match("^%d+$"), "usage: census.lua REPO SEED [options]")
local KEYS = {"bamboo_shoot", "frost_melon", "rock_salt", "stormkelp", "sugar_cane",
	"wild_cocoa"}
local part, parts, estimate, out_path = 1, 1, nil, nil
do
	local index = 3
	while arg[index] do
		local name, value = arg[index], arg[index + 1]
		if name == "--keys" then
			KEYS = {}
			for key in value:gmatch("[^,]+") do KEYS[#KEYS + 1] = key end
		elseif name == "--part" then
			part, parts = value:match("^(%d+)/(%d+)$")
			part, parts = tonumber(part), tonumber(parts)
		elseif name == "--estimate" then
			estimate = tonumber(value)
		elseif name == "--out" then
			out_path = value
		else
			error("unknown option " .. name)
		end
		index = index + 2
	end
end

local t0 = os.clock()
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local native = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_native.lua")
local authority = R.main.build_authority(native.identities())
local density = authority.vegetation
local habitat = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/habitat_registry.lua")
local world_catalog = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/world_content_catalog.lua")
local gathering = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
local WORLD = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua").world_bounds
local column_values_at = R.planner_source.column_values_at
local CHUNK = 80

-- The rows counted: their zones and biomes (nil: any) and the neighbour
-- reach of a shore rule (0: none needs water beside it).
local targets, by_key, by_node = {}, {}, {}
local function reach_of(predicate)
	if predicate == "none" then return 0 end
	if predicate == "no_water" then return 0 end
	if predicate:match("_cardinal$") then return 1 end
	return habitat.VEGETATION.SHORE_REACH
end
local function add_target(key, node, zones, biomes, reach)
	local target = {key = key, node = node, zones = zones, biomes = biomes, reach = reach,
		bit = #targets, zone_counts = {}}
	targets[#targets + 1] = target
	by_key[key] = target
	by_node[node] = target
end
local wanted = {}
for _, key in ipairs(KEYS) do wanted[key] = true end
for _, row in ipairs(gathering.p9g_sources()) do
	if wanted[row.key] then
		local zones, biomes = {}, {}
		for _, zone in ipairs(row.zones) do zones[zone] = true end
		for _, host in ipairs(row.hosts) do biomes[host.biome] = true end
		add_target(row.key, row.source_node, zones, biomes, reach_of(row.shore_predicate))
	end
end
for _, row in ipairs(world_catalog.plants) do
	if wanted[row.key] and row.mode == "surface" then
		local zones
		if #row.zones > 0 then
			zones = {}
			for _, zone in ipairs(row.zones) do zones[zone] = true end
		end
		local biomes
		if not row.hosts.any then
			biomes = {}
			for biome in pairs(row.hosts) do biomes[biome] = true end
		end
		add_target(row.key, row.node, zones, biomes, row.shore == "none" and 0 or 1)
	end
end
assert(#targets == #KEYS and #targets <= 15, "a key names no surface row")

-- One pass over the columns with a sliding window of rows, as deep as the
-- largest reach: a row is judged once the rows after it are read.
local width = WORLD.max_x - WORLD.min_x + 1
local largest = 0
for _, target in ipairs(targets) do largest = math.max(largest, target.reach) end
local rows = {}
for slot = 0, 2 * largest do rows[slot] = {wet = {}, bits = {}, ground = {}} end
local function row_of(z) return rows[z % (2 * largest + 1)] end
local match_cache = {}
local function match_bits(zone, biome)
	local key = zone .. "\0" .. biome
	local value = match_cache[key]
	if not value then
		value = 0
		for _, target in ipairs(targets) do
			if (not target.zones or target.zones[zone]) and
					(not target.biomes or target.biomes[biome]) then
				value = value + 2 ^ target.bit
			end
		end
		match_cache[key] = value
	end
	return value
end
local function read_row(z)
	local row = row_of(z)
	local wet, bits, ground = row.wet, row.bits, row.ground
	for i = 1, width do
		local water, _, zone, biome, _, terrain_y = column_values_at(WORLD.min_x + i - 1, z)
		wet[i] = water ~= "land"
		bits[i] = (not wet[i] and terrain_y >= 1 and zone and biome) and match_bits(zone, biome) or 0
		ground[i] = terrain_y
	end
end
local function near_water(i, z, reach)
	for dz = -reach, reach do
		local nz = z + dz
		if nz >= WORLD.min_z and nz <= WORLD.max_z then
			local wet = row_of(nz).wet
			for dx = -reach, reach do
				if (reach > 1 or dx == 0 or dz == 0) and wet[i + dx] then return true end
			end
		end
	end
	return false
end
local chunks, chunk_keys, candidates = {}, {}, 0
local function chunk_of(x, y, z)
	local ox, oy, oz = R.origin(x), R.origin(y), R.origin(z)
	local key = ox .. "," .. oy .. "," .. oz
	local chunk = chunks[key]
	if not chunk then
		chunk = {x = ox, y = oy, z = oz, n = 0}
		chunks[key] = chunk
		chunk_keys[#chunk_keys + 1] = key
	end
	return chunk
end
local function judge_row(z)
	local row = row_of(z)
	for i = 1, width do
		local mask = row.bits[i]
		if mask ~= 0 then
			for t = 1, #targets do
				local target = targets[t]
				if math.floor(mask / 2 ^ target.bit) % 2 == 1 and
						(target.reach == 0 or near_water(i, z, target.reach)) then
					local x, ground = WORLD.min_x + i - 1, row.ground[i]
					local chunk = chunk_of(x, ground, z)
					chunk.n = chunk.n + 1
					chunk[chunk.n * 3 - 2], chunk[chunk.n * 3 - 1], chunk[chunk.n * 3] = x, z, ground
					candidates = candidates + 1
					-- the root may stand in the chunk above
					local _ = chunk_of(x, ground + 1, z)
					break
				end
			end
		end
	end
end
for z = WORLD.min_z, WORLD.max_z + largest do
	if z <= WORLD.max_z then read_row(z) end
	if z - largest >= WORLD.min_z then judge_row(z - largest) end
end
table.sort(chunk_keys)
local t1 = os.clock()
io.stderr:write(("census %s: build and columns %.0fs: %d candidates in %d chunks\n")
	:format(seed, t1 - t0, candidates, #chunk_keys))

-- The writer, chunk by chunk.
local function count(target, zone, field)
	local row = target.zone_counts[zone]
	if not row then
		row = {eligible = 0, written = 0, outside = 0}
		target.zone_counts[zone] = row
	end
	row[field] = row[field] + 1
end
local function accepted(key, x, y, z, support)
	local categories, reason = density.categories(x, y, z, support, 15)
	if categories then
		reason = "no such category"
		for c = 1, #categories do
			if categories[c].class == "resource" and categories[c].key == key then return true end
		end
	end
	io.stderr:write(("outside: %s at %d,%d,%d on %s: %s\n"):format(key, x, y, z, support, reason))
	return false
end
local cid_target = {}
for _, target in ipairs(targets) do cid_target[R.fake.get_content_id(target.node)] = target end
local name_of = R.fake.get_name_from_content_id
local function vm_index(minp, x, y, z)
	return (z - minp.z + 16) * 12544 + (y - minp.y + 16) * 112 + (x - minp.x + 16) + 1
end
local stride = estimate and math.max(1, math.floor(#chunk_keys / estimate)) or parts
local offset = estimate and 1 or part
local ran, t3 = 0, os.clock()
for position = offset, #chunk_keys, stride do
	local chunk = chunks[chunk_keys[position]]
	local minp = {x = chunk.x, y = chunk.y, z = chunk.z}
	local maxp = {x = chunk.x + CHUNK - 1, y = chunk.y + CHUNK - 1, z = chunk.z + CHUNK - 1}
	local vm = R.new_vm(minp)
	local plan, generation = R.built.session.plan_slice(minp, maxp)
	R.built.writer.apply(vm, minp, maxp, plan, generation)
	local data = vm.written.data or vm.native.data
	for c = 1, chunk.n do
		local x, z, ground = chunk[c * 3 - 2], chunk[c * 3 - 1], chunk[c * 3]
		local support = name_of(data[vm_index(minp, x, ground, z)])
		local categories = density.categories(x, ground + 1, z, support, 15)
		if categories then
			local _, _, zone = column_values_at(x, z)
			for k = 1, #categories do
				local category = categories[k]
				local target = category.class == "resource" and by_key[category.key]
				if target then count(target, zone, "eligible") end
			end
		end
	end
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			local i = vm_index(minp, minp.x, y, z)
			for x = minp.x, maxp.x do
				local target = cid_target[data[i]]
				if target then
					local _, _, zone = column_values_at(x, z)
					count(target, zone, "written")
					if y > minp.y and not accepted(target.key, x, y, z, name_of(data[i - 112])) then
						count(target, zone, "outside")
					end
				end
				i = i + 1
			end
		end
	end
	ran = ran + 1
end
local t4 = os.clock()

local lines = {}
for _, target in ipairs(targets) do
	local zones = {}
	for zone in pairs(target.zone_counts) do zones[#zones + 1] = zone end
	table.sort(zones)
	for _, zone in ipairs(zones) do
		local row = target.zone_counts[zone]
		lines[#lines + 1] = ("%s %s %d %d %d"):format(target.key, zone, row.eligible, row.written,
			row.outside)
	end
end
local text = table.concat(lines, "\n") .. "\n"
if out_path then
	local file = assert(io.open(out_path, "w"))
	file:write(text)
	file:close()
else
	io.write(text)
end
local per_chunk = ran > 0 and (t4 - t3) / ran or 0
io.stderr:write(("census %s: %d chunks in %.0fs (%.2fs each)%s\n"):format(seed, ran, t4 - t3,
	per_chunk, estimate and (", the full pass about %.0f min"):format(per_chunk * #chunk_keys / 60)
		or ""))
