-- Round 51 TERRAIN T4: the "no land moves" comparison and the surface
-- shares. Builds the real mapgen runtime of one seed
-- (tools/seed_fleet/runtime.lua) and writes, for a fixed set of chunks, every
-- voxel the real plan_slice and writer leave in the fake VoxelManip, so the
-- dumps of two checkouts can be compared node by node:
--
--   luajit tools/r51_t4/compare.lua REPO SEED OUT
--   python3 tools/r51_t4/diff_dumps.py OUT_before OUT_after
--
-- REPO is the checkout to measure (run the tool once on an export of the
-- base commit and once on the branch). The chunks are chosen from the
-- layout alone (the same on both sides): on a 16-node lattice over the world
-- bounds, the 80 x 80 chunk column holding the most swamp samples, the most
-- steep badlands samples (on a 4-node lattice, a column 2 or more above a
-- direct neighbour), the most snowy crags samples and the most coast samples
-- (land 2..6 above the sea level next to a non-land sample); each at the
-- chunk height of its median sampled ground. A warm-up chunk (the first land chunk
-- of the lattice) is written first and not dumped.
--
-- OUT holds the layout digests (placement, water, roads, capitals, roster,
-- trees), then per chunk a header line, one "B x z biome" line per column and
-- one "C x z y0 name*count ..." line per column: the column's nodes from the
-- chunk's lowest y up, run-length encoded. It prints each chunk's plan and
-- write CPU seconds (the median of three runs after the dumped one). With
-- `time` it writes no dump and prints each region's generation time: the
-- 3 x 3 chunks round the chosen chunk, each planned and written once.
local repo, seed, out_path, mode = arg[1], arg[2], arg[3], arg[4]
assert(repo and seed and seed:match("^%d+$") and out_path,
	"usage: compare.lua REPO SEED OUT [time]")

local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local function hex(bytes) return common.hex(R.sha(bytes)) end
local S = R.built.zones_session
local WORLD = {min_x = -4190, max_x = 4190, min_z = -3740, max_z = 3740}

local file = assert(io.open(out_path, "w"))
local function emit(line) file:write(line, "\n") end
emit("# layout")
emit("roster " .. tostring(R.built.anchor_roster.sha256))
emit("placement " .. hex(R.main.placement_layout_text()))
emit("water " .. hex(R.main.water_layout_text()))
emit("roads " .. hex(R.main.road_layout_text()))
emit("capitals " .. hex(R.main.capital_layout_text()))
emit("trees " .. tostring(R.built.manifest.values.r6_generated_templates_sha256))

-- The lattice and the chunk scores.
local STEP = 16
local score = {swamp = {}, badlands = {}, snowy = {}, coast = {}}
local heights = {}
local function key_of(x, z) return R.origin(x) .. "," .. R.origin(z) end
local function add(kind, x, z, h)
	local key = key_of(x, z)
	score[kind][key] = (score[kind][key] or 0) + 1
	local list = heights[kind .. key]
	if not list then list = {} heights[kind .. key] = list end
	list[#list + 1] = h
end
local warmup
for z = WORLD.min_z + 8, WORLD.max_z - 8, STEP do
	for x = WORLD.min_x + 8, WORLD.max_x - 8, STEP do
		if S.water_class_at(x, z) == "land" then
			local biome, h = S.biome_at(x, z), S.terrain_height_at(x, z)
			warmup = warmup or {x, z, h}
			if biome == "grug_swamp" then add("swamp", x, z, h) end
			if biome == "grug_crags_snowy" then add("snowy", x, z, h) end
			if biome == "grug_badlands" or biome == "grug_badlands_east" then
				-- a lip: 2 or more above a direct neighbour, on a 4-node
				-- lattice inside the sample's cell
				for dz = 0, STEP - 4, 4 do
					for dx = 0, STEP - 4, 4 do
						local sx, sz = x + dx, z + dz
						local sh = S.terrain_height_at(sx, sz)
						if sh - math.min(S.terrain_height_at(sx + 1, sz), S.terrain_height_at(sx - 1, sz),
								S.terrain_height_at(sx, sz + 1), S.terrain_height_at(sx, sz - 1)) >= 2 then
							add("badlands", sx, sz, sh)
						end
					end
				end
			end
			if h >= 2 and h <= 6 then
				for _, d in ipairs({{STEP, 0}, {-STEP, 0}, {0, STEP}, {0, -STEP}}) do
					if S.water_class_at(x + d[1], z + d[2]) ~= "land" then
						add("coast", x, z, h)
						break
					end
				end
			end
		end
	end
end
local chunks = {}
for _, kind in ipairs({"swamp", "badlands", "snowy", "coast"}) do
	local best, best_count
	local keys = {}
	for key in pairs(score[kind]) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do
		if not best or score[kind][key] > best_count then best, best_count = key, score[kind][key] end
	end
	if best then
		local list = heights[kind .. best]
		table.sort(list)
		local x0, z0 = best:match("^(%-?%d+),(%-?%d+)$")
		chunks[#chunks + 1] = {label = kind, x = tonumber(x0), z = tonumber(z0),
			y = R.origin(math.max(list[math.floor((#list + 1) / 2)], 1)), samples = best_count}
	end
end

local fake = R.fake
local names = {}
local function name_of(cid)
	local n = names[cid]
	if not n then n = fake.get_name_from_content_id(cid) names[cid] = n end
	return n
end
local function dump(c)
	local minp = {x = c.x, y = c.y, z = c.z}
	local result = R.chunk(minp)
	emit(("# chunk %s %d %d %d samples=%d hash=%s"):format(c.label, c.x, c.y, c.z,
		c.samples, result.data_hash))
	-- The fake VM's data: the emerged area is the chunk plus a 16-node shell.
	local data = result.data
	local ex, ey, ez = c.x - 16, c.y - 16, c.z - 16
	for z = c.z, c.z + 79 do
		for x = c.x, c.x + 79 do
			emit(("B %d %d %s"):format(x, z, tostring(S.biome_at(x, z))))
			local parts, run_name, run_count = {}, nil, 0
			for y = c.y, c.y + 79 do
				local n = name_of(data[(z - ez) * 12544 + (y - ey) * 112 + (x - ex) + 1])
				if n == run_name then
					run_count = run_count + 1
				else
					if run_name then parts[#parts + 1] = run_name .. "*" .. run_count end
					run_name, run_count = n, 1
				end
			end
			parts[#parts + 1] = run_name .. "*" .. run_count
			emit(("C %d %d %d %s"):format(x, z, c.y, table.concat(parts, " ")))
		end
	end
end

-- R.chunk returns no voxel data: keep what its hash reads.
do
	local real_chunk = R.chunk
	R.chunk = function(minp, hooks)
		local captured
		local saved = R.written_hash
		R.written_hash = function(vm)
			captured = vm.written.data or vm.native.data
			return saved(vm)
		end
		local result = real_chunk(minp, hooks)
		R.written_hash = saved
		result.data = captured
		return result
	end
end

R.chunk({x = R.origin(warmup[1]), y = R.origin(math.max(warmup[3], 1)), z = R.origin(warmup[2])})
if mode == "time" then
	-- Generation time per region: the 3 x 3 chunks round each chosen one,
	-- each planned and written once (cold), plan and write CPU summed.
	file:close()
	for _, c in ipairs(chunks) do
		local plan, write = 0, 0
		for dz = -80, 80, 80 do
			for dx = -80, 80, 80 do
				local result = R.chunk({x = c.x + dx, y = c.y, z = c.z + dz})
				plan, write = plan + result.plan_seconds, write + result.write_seconds
			end
		end
		print(("region %-8s %5d %4d %5d  9 chunks: plan %.3f s  write %.3f s  total %.3f s")
			:format(c.label, c.x, c.y, c.z, plan, write, plan + write))
	end
	return
end
for _, c in ipairs(chunks) do dump(c) end
file:close()
for _, c in ipairs(chunks) do
	local plans, writes = {}, {}
	for run = 1, 3 do
		local result = R.chunk({x = c.x, y = c.y, z = c.z})
		plans[run], writes[run] = result.plan_seconds, result.write_seconds
	end
	table.sort(plans) table.sort(writes)
	print(("time %-8s %5d %4d %5d  plan %.3f s  write %.3f s"):format(c.label, c.x, c.y, c.z,
		plans[2], writes[2]))
end
