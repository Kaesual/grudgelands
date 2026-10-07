-- One seed of the seed fleet (tools/run.sh): the real mapgen runtime as main
-- builds it on a world's first start (tools/seed_fleet/runtime.lua:
-- r7_runtime.lua over the shared world assembly -- inland water, roads,
-- capitals, every settlement prepared -- and its `build`: the zones session,
-- the R7 anchor roster and every settlement's configuration), every
-- tributary's junction stretch at most JOIN_MAX nodes, and the per-chunk path
-- (Round 37, audit MGT-01/MGS-02): a sample of chunks planned and written
-- through the real `plan_slice` and writer against a fake VoxelManip.
--
--   luajit tools/seed_fleet/seed.lua REPO SEED
--
-- The sample is a function of the seed: one map corner, the first coast on
-- the way from it to the centre, one sea mouth of a river, the edge of one
-- capital's protected city and the collar of one other settlement (a start,
-- village, outpost, camp or POI), each the chunk holding the column's ground
-- or water surface.
--
-- A seed may also name chunks of its own in tools/seed_fleet/chunks.txt (a
-- chunk that once failed in a real world, Round 41); they are planned and
-- written after the sample.
--
-- Prints one line, "OK <seed> <seconds> <roster sha256> chunks=<n>
-- chunk_seconds=<s>" or "FAIL <seed> <seconds> <error>" and then raises (a
-- non-zero exit). A failure in the per-chunk path names the chunk.
local repo, seed = arg[1], arg[2]
assert(repo and seed and seed:match("^%d+$"), "usage: seed.lua REPO SEED")
local t0 = os.clock()
-- A tributary's last stretch (its snap onto the parent) stays short: on main
-- before Round 34 F3 the longest over 150 seeds was about 110 nodes; moving
-- the junction past a core adds at most 2 * (core radius + reach + pad) +
-- one step, under 200 for every core but a dragon arena (on the islands), so
-- 320 means the snap went astray (a long straight canyon).
local JOIN_MAX = 320
local X_LIMIT, Z_LIMIT = 3740, 3340

local R, rivers
local function build()
	R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
	local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local module = dofile(dir .. "/water_layout.lua")(dofile(dir .. "/terrain_data.lua").water)
	rivers = module.deserialize(R.main.water_layout_text()).rivers
	for _, r in ipairs(rivers) do
		local n = #r.x
		if r.parent and n > 1 then
			local dx, dz = r.x[n] - r.x[n - 1], r.z[n] - r.z[n - 1]
			local d = math.sqrt(dx * dx + dz * dz)
			if d > JOIN_MAX then
				error(("river %d joins its parent across %.0f nodes (bound %d)")
					:format(r.id, d, JOIN_MAX), 0)
			end
		end
	end
end

-- The sample: {label, x, z} columns, chosen by bytes of a digest of the seed.
local function sample()
	local bytes = {R.sha("seed_fleet_chunks:" .. seed):byte(1, 8)}
	local function pick(index, count) return bytes[index] % count + 1 end
	local zones = R.built.zones_session
	local columns = {}
	local sx = pick(1, 2) == 1 and -1 or 1
	local sz = pick(2, 2) == 1 and -1 or 1
	columns[#columns + 1] = {"corner", sx * X_LIMIT, sz * Z_LIMIT}
	-- the first land on the diagonal from that corner to the centre
	for step = 8, X_LIMIT, 8 do
		local x, z = sx * (X_LIMIT - step), sz * math.floor(Z_LIMIT - step * Z_LIMIT / X_LIMIT)
		if zones.water_class_at(x, z) == "land" then
			columns[#columns + 1] = {"coast", x, z}
			break
		end
	end
	local mouths = {}
	for _, r in ipairs(rivers) do
		if not r.parent and r.end_kind == "sea" then mouths[#mouths + 1] = r end
	end
	if #mouths > 0 then
		local r = mouths[pick(3, #mouths)]
		columns[#columns + 1] = {"river mouth " .. r.id, r.x[#r.x], r.z[#r.z]}
	end
	local rows, capitals, others = R.main.settlement_sockets(R.built), {}, {}
	for _, row in ipairs(rows) do
		if row.slot == "capital" then capitals[#capitals + 1] = row
		else others[#others + 1] = row end
	end
	local DIRECTIONS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
	local direction = DIRECTIONS[pick(4, 4)]
	local capital = capitals[pick(5, #capitals)]
	local shape = R.main.capital_protection()[capital.anchor.id]
	for d = 0, 800, 4 do
		local x, z = capital.anchor.x + direction[1] * d, capital.anchor.z + direction[2] * d
		if not shape.member(x, z) then
			columns[#columns + 1] = {"capital edge " .. capital.key, x, z}
			break
		end
	end
	-- just outside the settlement's own cells (its prepared bounds; a start's
	-- pad is 128 nodes wide)
	local other = others[pick(6, #others)]
	local prepared = R.main.prepared_handover()[other.key]
	local reach = 72
	if prepared then
		local b = prepared.bounds
		reach = math.max(direction[1] > 0 and b.max.x or 0, direction[1] < 0 and -b.min.x or 0,
			direction[2] > 0 and b.max.z or 0, direction[2] < 0 and -b.min.z or 0) + 8
	end
	columns[#columns + 1] = {"collar " .. other.key, other.anchor.x + direction[1] * reach,
		other.anchor.z + direction[2] * reach}
	return columns
end

-- The named chunks of this seed: {label, minp}.
local function named_chunks()
	local result = {}
	local file = io.open(repo .. "/tools/seed_fleet/chunks.txt", "r")
	if not file then return result end
	for line in file:lines() do
		local s, x, y, z, label = line:match("^(%d+)%s+(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)%s*(.*)$")
		if s == seed then
			result[#result + 1] = {label ~= "" and label or "named",
				{x = tonumber(x), y = tonumber(y), z = tonumber(z)}}
		end
	end
	file:close()
	return result
end

local ok, err = pcall(build)
local roster = ok and R.built.anchor_roster.sha256
local chunks, chunk_seconds = 0, 0
if ok then
	local started = os.clock()
	local columns
	ok, err = pcall(sample)
	if ok then columns = err end
	for _, column in ipairs(ok and columns or {}) do
		local label, x, z = column[1], column[2], column[3]
		local minp = {x = R.origin(x), y = R.origin(math.max(R.ground_at(x, z), 1)),
			z = R.origin(z)}
		ok, err = pcall(R.chunk, minp)
		if not ok then
			err = ("chunk %d,%d,%d (%s): %s"):format(minp.x, minp.y, minp.z, label, tostring(err))
			break
		end
		chunks = chunks + 1
	end
	for _, named in ipairs(ok and named_chunks() or {}) do
		local minp = named[2]
		ok, err = pcall(R.chunk, minp)
		if not ok then
			err = ("chunk %d,%d,%d (%s): %s"):format(minp.x, minp.y, minp.z, named[1],
				tostring(err))
			break
		end
		chunks = chunks + 1
	end
	chunk_seconds = os.clock() - started
end
local seconds = ("%.1f"):format(os.clock() - t0)
if ok then
	print("OK", seed, seconds, roster, "chunks=" .. chunks,
		("chunk_seconds=%.1f"):format(chunk_seconds))
else
	print("FAIL", seed, seconds, (tostring(err):gsub("[\t\n]", " ")))
	error("seed " .. seed .. " failed", 0)
end
