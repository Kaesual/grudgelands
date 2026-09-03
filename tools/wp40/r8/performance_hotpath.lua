-- Bounded engine-free timing and byte-parity probe for the authentic WP40 R8
-- production runtime. Timings are diagnostic; canonical output digests are the
-- correctness gate. Run this tool under LuaJIT during development.

local repo, order = arg[1], arg[2] or "forward"
if type(repo) ~= "string" or repo == "" then
	error("usage: performance_hotpath.lua REPO [forward|reverse]", 0)
end
if order ~= "forward" and order ~= "reverse" then
	error("performance order must be forward or reverse", 0)
end

local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local raw_sha256 = common.new_sha256()
local clock = os.clock

local cases = {
	{id = "human_capital", x = 0, y = "surface", z = -1500},
	{id = "goldmead_inland_housing", x = 0, y = "surface", z = -2050},
	{id = "wyrmglass_channel", x = -2675, y = "surface", z = 0},
	{id = "copperfell_shelf", x = -2600, y = "surface", z = -2200},
	{id = "deep_cross_border_resource", x = -1691, y = -842, z = 191},
	{id = "capital_high_slice", x = 0, y = 240, z = -1500},
}

if order == "reverse" then
	local reversed = {}
	for index = #cases, 1, -1 do reversed[#reversed + 1] = cases[index] end
	cases = reversed
end

local function origin(value)
	local block = math.floor(value / 16)
	return (math.floor((block + 2) / 5) * 5 - 2) * 16
end

local function append_u32(parts, value)
	if value < 0 then value = value + 4294967296 end
	parts[#parts + 1] = string.char(
		value % 256,
		math.floor(value / 256) % 256,
		math.floor(value / 65536) % 256,
		math.floor(value / 16777216) % 256)
end

local function central_digest(snapshot, minp, maxp)
	local axis_x = snapshot.emax.x - snapshot.emin.x + 1
	local axis_y = snapshot.emax.y - snapshot.emin.y + 1
	local stride_z = axis_x * axis_y
	local blocks, parts = {}, {}
	local function flush()
		if #parts > 0 then
			blocks[#blocks + 1] = table.concat(parts)
			parts = {}
		end
	end
	local function index_at(x, y, z)
		return (z - snapshot.emin.z) * stride_z +
			(y - snapshot.emin.y) * axis_x + (x - snapshot.emin.x) + 1
	end
	blocks[#blocks + 1] = "grug_wp40_r8_performance_snapshot_v1\0content\0"
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				append_u32(parts, snapshot.data[index_at(x, y, z)])
				if #parts == 4096 then flush() end
			end
		end
	end
	flush()
	blocks[#blocks + 1] = "\0param2\0"
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				parts[#parts + 1] = string.char(
					snapshot.param2[index_at(x, y, z)])
				if #parts == 4096 then flush() end
			end
		end
	end
	flush()
	blocks[#blocks + 1] = "\0light\0"
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				parts[#parts + 1] = string.char(snapshot.light[index_at(x, y, z)])
				if #parts == 4096 then flush() end
			end
		end
	end
	flush()
	return common.hex(raw_sha256(table.concat(blocks)))
end

local function delta(after, before, field)
	return (after[field] or 0) - (before[field] or 0)
end

local function prepare_case(fixture, case)
	local sample_y = case.y
	if sample_y == "surface" then
		sample_y = fixture.built.zones_session.terrain_height_at(case.x, case.z) + 1
	end
	local minp = {x = origin(case.x), y = origin(sample_y), z = origin(case.z)}
	local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
	local heightmap = {}
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			local height = fixture.built.zones_session.terrain_height_at(x, z)
			heightmap[#heightmap + 1] = height >= minp.y and height <= maxp.y and
				height or -31007
		end
	end
	fixture.set_heightmap(heightmap)
	return minp, maxp
end

local construct_started = clock()
local fixture = dofile(repo .. "/tools/wp40/r7/runtime_fixture.lua")(
	repo, "0", "production")
local construct_seconds = clock() - construct_started
collectgarbage("collect")

io.write("schema\tgrug_wp40_r8_performance_hotpath_v1\n")
io.write("order\t", order, "\n")
io.write(string.format("construction_cpu_seconds\t%.6f\n", construct_seconds))
io.write("case\tminp\tplan_cpu_seconds\twriter_cpu_seconds\tclassify_calls\t",
	"modified_voxels\tp9g_accepted\tdigest\n")

local digest_rows = {}
for case_index = 1, #cases do
	local case = cases[case_index]
	local minp, maxp = prepare_case(fixture, case)
	local vm, _, observer = fixture.new_vm(minp, maxp)
	local before = fixture.built.session.metrics()
	local plan_started = clock()
	local plan, generation = fixture.built.session.plan_slice(minp, maxp)
	local plan_seconds = clock() - plan_started
	local writer_started = clock()
	local result = fixture.built.writer.apply(vm, minp, maxp, plan, generation)
	local writer_seconds = clock() - writer_started
	if type(result) ~= "string" then error("writer result differs", 0) end
	local after = fixture.built.session.metrics()
	local snapshot = observer.snapshot()
	local digest = central_digest(snapshot, minp, maxp)
	digest_rows[#digest_rows + 1] = case.id .. "\t" .. digest .. "\n"
	io.write(string.format(
		"%s\t%d,%d,%d\t%.6f\t%.6f\t%d\t%d\t%d\t%s\n",
		case.id, minp.x, minp.y, minp.z, plan_seconds, writer_seconds,
		delta(after.content, before.content, "classify_calls"),
		delta(after.settlement, before.settlement, "modified_voxels"),
		delta(after.p9g or {}, before.p9g or {}, "accepted"), digest))
	io.write(string.format("cache\t%s\thits\t%d\tmisses\t%d\tevictions\t%d\n",
		case.id,
		delta(after.planner, before.planner, "runtime_column_cache_hits"),
		delta(after.planner, before.planner, "runtime_column_cache_misses"),
		delta(after.planner, before.planner, "runtime_column_cache_evictions")))
	vm, observer, snapshot, plan, generation = nil, nil, nil, nil, nil
	collectgarbage("collect")
end

-- A surface owner followed immediately by its high vertical sibling isolates
-- the bounded cache's intended live reuse without changing the canonical
-- six-case byte digest above.
local warm_surface = {x = 0, y = "surface", z = -1500}
local warm_high = {x = 0, y = 240, z = -1500}
local warm_minp, warm_maxp = prepare_case(fixture, warm_surface)
local before_warmup = fixture.built.session.metrics()
local warmup_started = clock()
fixture.built.session.plan_slice(warm_minp, warm_maxp)
local warmup_seconds = clock() - warmup_started
local after_warmup = fixture.built.session.metrics()
local high_minp, high_maxp = prepare_case(fixture, warm_high)
local high_started = clock()
fixture.built.session.plan_slice(high_minp, high_maxp)
local high_seconds = clock() - high_started
local after_high = fixture.built.session.metrics()
io.write(string.format(
	"warm_cache\thuman_capital_to_high_slice\twarmup_cpu_seconds\t%.6f\t" ..
	"warm_cpu_seconds\t%.6f\twarmup_hits\t%d\twarmup_misses\t%d\t" ..
	"warm_hits\t%d\twarm_misses\t%d\tentries\t%d\tlimit\t%d\n",
	warmup_seconds, high_seconds,
	delta(after_warmup.planner, before_warmup.planner,
		"runtime_column_cache_hits"),
	delta(after_warmup.planner, before_warmup.planner,
		"runtime_column_cache_misses"),
	delta(after_high.planner, after_warmup.planner, "runtime_column_cache_hits"),
	delta(after_high.planner, after_warmup.planner, "runtime_column_cache_misses"),
	after_high.planner.runtime_column_cache_entries,
	after_high.planner.runtime_column_cache_limit))

table.sort(digest_rows)
io.write("canonical_digest\t", common.hex(raw_sha256(table.concat(digest_rows))), "\n")
io.write(string.format("lua_heap_bytes_after_collect\t%.0f\n",
	collectgarbage("count") * 1024))
