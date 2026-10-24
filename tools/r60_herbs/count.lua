-- Round 60 lane HERBS: the gathering sources the real writer places in a few
-- surface chunks per zone (LuaJIT, no engine; the seed fleet's runtime,
-- tools/seed_fleet/runtime.lua, and its fake VoxelManip).
--
--   luajit tools/r60_herbs/count.lua REPO SEED ZONE [ZONE ...]
--
-- Per zone the four chunks holding the ground 240 nodes east, west, north
-- and south of the zone's hub (a point outside the zone is skipped), each
-- planned and written through `plan_slice` and the writer; counts every
-- `grug_gathering:*_source` node in the written chunk and the plan and write
-- CPU seconds. Run it on two trees (before and after a catalogue change) to
-- compare; the counts are the harness's, a sample, never a whole zone.
-- Prints one line per zone ("<zone> chunks=<n> <key>=<count> ...
-- seconds=<s>") and a total.
local repo, seed = arg[1], arg[2]
assert(repo and seed and arg[3], "usage: count.lua REPO SEED ZONE [ZONE ...]")
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local zones = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua").zones
local by_id = {}
for _, zone in ipairs(zones) do by_id[zone.id] = zone end
local session = R.built.zones_session

local OFFSETS = {{240, 0}, {-240, 0}, {0, 240}, {0, -240}}
local total, total_seconds, total_chunks = {}, 0, 0
for index = 3, #arg do
	local zone = assert(by_id[arg[index]], "unknown zone " .. arg[index])
	local counts, seconds, chunks = {}, 0, 0
	for _, offset in ipairs(OFFSETS) do
		local x, z = zone.hub.x + offset[1], zone.hub.z + offset[2]
		if session.id_at(x, z) == zone.id then
			local minp = {x = R.origin(x), y = R.origin(R.ground_at(x, z) + 1), z = R.origin(z)}
			local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
			-- R.chunk's steps, keeping the VoxelManip to read it back.
			local vm = R.new_vm(minp)
			local t0 = os.clock()
			local plan, generation = R.built.session.plan_slice(minp, maxp)
			R.built.writer.apply(vm, minp, maxp, plan, generation)
			seconds = seconds + os.clock() - t0
			chunks = chunks + 1
			local data = vm.written.data or vm.native.data
			for cell = 1, #data do
				local name = R.fake.get_name_from_content_id(data[cell])
				local key = name:match("^grug_gathering:(.+)_source$")
				if key then counts[key] = (counts[key] or 0) + 1 end
			end
		end
	end
	total_chunks = total_chunks + chunks
	total_seconds = total_seconds + seconds
	io.write(zone.id, " chunks=", chunks)
	local keys = {}
	for key in pairs(counts) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do
		io.write(" ", key, "=", counts[key])
		total[key] = (total[key] or 0) + counts[key]
	end
	io.write((" seconds=%.1f\n"):format(seconds))
end
io.write("TOTAL chunks=", total_chunks)
local keys = {}
for key in pairs(total) do keys[#keys + 1] = key end
table.sort(keys)
for _, key in ipairs(keys) do io.write(" ", key, "=", total[key]) end
io.write((" seconds=%.1f\n"):format(total_seconds))
