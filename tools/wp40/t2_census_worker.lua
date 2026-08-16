-- WP40 T2 census worker (plan section 6.6, milestone M1).  One process
-- evaluates an explicit seed list through partition.census_scan1 and emits
-- one canonical TSV: Scan-1 interval/attachment/junction/fill projections
-- plus the verified seed-independent F1 prefilter and a trailing digest.
-- Full-W range sharding, resume and the cost gate are the M2 launcher's job;
-- this worker deliberately caps explicit seed lists (plan section 6.6.7).
local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local output_path = assert(arg[3], "output path required")
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-census%.[A-Za-z0-9]+$"),
	"unsafe scratch path")

local seeds, kat_mode = {}, false
for index = 4, #arg do
	if arg[index] == "--kat" then
		kat_mode = true
	else
		local seed = arg[index]
		assert(type(seed) == "string" and seed:match("^%d+$"),
			"seed must be a decimal string")
		seeds[#seeds + 1] = seed
	end
end
if kat_mode then
	assert(#seeds == 0, "--kat accepts no explicit seeds")
	seeds = {"0", "18446744073709551615"}
end
assert(#seeds >= 1, "at least one seed required")
assert(#seeds <= 64,
	"explicit census seed lists are capped at 64; the full-W run is the " ..
	"GO-gated M2 launcher's job")

local existing = io.open(output_path, "rb")
if existing then existing:close() error("census output already exists", 0) end

local sha_cache, sha_counter = {}, 0
local function from_hex(value)
	return (value:gsub("..", function(pair)
		return string.char(assert(tonumber(pair, 16)))
	end))
end
local function to_hex(value)
	return (value:gsub(".", function(byte)
		return ("%02x"):format(string.byte(byte))
	end))
end
local function raw_sha256(data)
	local cached = sha_cache[data]
	if cached then return cached end
	sha_counter = sha_counter + 1
	local input = scratch .. "/sha-" .. sha_counter .. ".bin"
	local output = scratch .. "/sha-" .. sha_counter .. ".txt"
	local file = assert(io.open(input, "wb"))
	assert(file:write(data)) assert(file:close())
	local status, reason, code = os.execute("sha256sum " .. input .. " > " .. output)
	assert(status == 0 or status == true and reason == "exit" and code == 0)
	file = assert(io.open(output, "rb"))
	local digest = from_hex(assert(assert(file:read("*l")):match("^([0-9a-f]+)")))
	assert(file:close()) assert(#digest == 32)
	sha_cache[data] = digest
	return digest
end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local exact = dofile(wp40 .. "/geometry/exact.lua")({
	deterministic = deterministic})
local raster = dofile(wp40 .. "/geometry/raster.lua")({canonical = canonical,
	deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256})
local source = dofile(wp40 .. "/source/catalog.lua")
local source_validator = dofile(wp40 .. "/validation/t2_source.lua")
-- The closed WP43 vocabulary projection retained for the E0 pool; recorded
-- here so the census manifest names its vocabulary authority explicitly.
local vocabulary_path = "tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua"
local vocabulary = dofile(repo .. "/" .. vocabulary_path)
local new_boundary = dofile(wp40 .. "/geometry/boundary.lua")
local partition = dofile(wp40 .. "/geometry/partition.lua")({
	canonical = canonical, deterministic = deterministic, exact = exact,
	new_boundary = new_boundary, raster = raster, raw_sha256 = raw_sha256,
	source = source, source_validator = source_validator,
	vocabulary = vocabulary})

local lines = {}
local function emit(...)
	lines[#lines + 1] = table.concat({...}, "\t")
end
local function opt(value)
	if value == nil then return "-" end
	return tostring(value)
end

emit("schema", partition.census_scan1_schema)
emit("vocabulary", vocabulary_path)

local prefilter_serialized
local scans_by_seed = {}
for seed_index = 1, #seeds do
	local seed = seeds[seed_index]
	local started = os.time()
	local scan = partition.census_scan1(seed)
	scans_by_seed[seed] = scan
	local serialized_rows = {}
	for index = 1, #scan.prefilter do
		local row = scan.prefilter[index]
		serialized_rows[index] = table.concat({row.edge_id,
			row.discharged and "discharged" or "scanned", row.reason}, "\t")
	end
	local serialized = table.concat(serialized_rows, "\n")
	if seed_index == 1 then
		prefilter_serialized = serialized
		for index = 1, #serialized_rows do
			lines[#lines + 1] = "prefilter\t" .. serialized_rows[index]
		end
	elseif serialized ~= prefilter_serialized then
		error("WP40 census: seed-independent prefilter drifted at seed " ..
			seed, 0)
	end
	local discharged_by_edge = {}
	for index = 1, #scan.prefilter do
		discharged_by_edge[scan.prefilter[index].edge_id] =
			scan.prefilter[index].discharged
	end
	emit("seed_begin", seed)
	for index = 1, #scan.edges do
		local row = scan.edges[index]
		if discharged_by_edge[row.id] and row.interval_count ~= 1 then
			error("WP40 census: discharged edge " .. row.id ..
				" realized interval count " .. row.interval_count ..
				" at seed " .. seed, 0)
		end
		emit("edge", seed, row.id, row.kind, row.class,
			tostring(row.interval_count), opt(row.qualifying_count),
			tostring(row.singleton_count), opt(row.selected_first),
			opt(row.selected_finish), tostring(row.station_count),
			tostring(row.topology_ceiling_nodes),
			tostring(row.max_abs_scalar_q))
	end
	for index = 1, #scan.perimeters do
		local row = scan.perimeters[index]
		emit("perimeter", seed, row.id, tostring(row.station_count),
			tostring(row.topology_ceiling_nodes),
			tostring(row.max_abs_scalar_q))
	end
	for index = 1, #scan.aperture_stress do
		local row = scan.aperture_stress[index]
		emit("aperture", seed, row.id, row.side,
			tostring(row.d_x), tostring(row.d_z), tostring(row.d_scalar_q),
			tostring(row.d_sample_distance),
			tostring(row.w_x), tostring(row.w_z), tostring(row.w_scalar_q),
			tostring(row.w_sample_distance),
			tostring(row.a_x), tostring(row.a_z), tostring(row.a_scalar_q),
			tostring(row.a_sample_distance))
	end
	for index = 1, #scan.attachments do
		local row = scan.attachments[index]
		emit("attachment", seed, row.id, row.edge_id, row.endpoint, row.class,
			opt(row.distance), tostring(row.interval_count),
			row.e and tostring(row.e.x) or "-", row.e and tostring(row.e.z) or "-",
			row.a and tostring(row.a.x) or "-", row.a and tostring(row.a.z) or "-",
			opt(row.canonical_index))
	end
	for index = 1, #scan.junctions do
		local row = scan.junctions[index]
		emit("junction", seed, row.id, tostring(row.pair_count),
			tostring(row.pass_count), tostring(row.fail_count),
			opt(row.min_clearance))
	end
	for index = 1, #scan.junction_pair_rejects do
		local row = scan.junction_pair_rejects[index]
		emit("junction_pair", seed, row.junction_id, row.left_edge,
			row.right_edge, row.class)
	end
	for index = 1, #scan.bay_fills do
		local row = scan.bay_fills[index]
		local fill_texts = {}
		for fill_index = 1, #row.fill_points do
			fill_texts[fill_index] = row.fill_points[fill_index].x .. ":" ..
				row.fill_points[fill_index].z
		end
		emit("bay", seed, row.id, tostring(row.fill_count),
			#fill_texts > 0 and table.concat(fill_texts, ",") or "-")
	end
	emit("seed_end", seed)
	-- The SHA memo cache has zero cross-seed reuse (every noise input embeds
	-- the seed), so dropping it bounds worker memory over long seed lists
	-- without changing a single emitted byte.
	sha_cache = {}
	io.stderr:write("census seed " .. seed .. " done " .. seed_index .. "/" ..
		#seeds .. " wall=" .. os.difftime(os.time(), started) .. "s cpu=" ..
		string.format("%.1f", os.clock()) .. "s\n")
	io.stderr:flush()
end

local body = table.concat(lines, "\n") .. "\n"
local digest = to_hex(raw_sha256(body))
local file = assert(io.open(output_path, "wb"))
assert(file:write(body, "digest\tsha256=", digest, "\n"))
assert(file:close())
print("census scan1 rows " .. #lines .. " digest " .. digest)

if kat_mode then
	local fixture_path = repo ..
		"/tools/wp40/fixtures/t2_census/scan1_kat_v1.lua"
	local fixture_chunk, fixture_diagnostic = loadfile(fixture_path)
	assert(fixture_chunk, "census KAT fixture missing or invalid: " ..
		tostring(fixture_diagnostic))
	local fixture = fixture_chunk()
	for seed_index = 1, #seeds do
		local seed = seeds[seed_index]
		local scan = scans_by_seed[seed]
		assert(#scan.edges == 61, "census KAT expects 61 edge rows")
		assert(#scan.perimeters == 3, "census KAT expects 3 perimeter rows")
		for index = 1, #scan.perimeters do
			local row = scan.perimeters[index]
			if row.id == "perimeter_holy_grounds" then
				assert(row.topology_ceiling_nodes == 0 and
					row.max_abs_scalar_q == 0,
					"census KAT: the fixed Holy band must stay zero-displacement")
			end
		end
		assert(#scan.aperture_stress == 8,
			"census KAT expects 8 aperture stress rows")
		assert(#scan.attachments == 8, "census KAT expects 8 attachment rows")
		assert(#scan.junctions == 38, "census KAT expects 38 junction rows")
		assert(#scan.bay_fills == 4, "census KAT expects 4 bay rows")
		local transition_rows, pass_total = 0, 0
		for index = 1, #scan.edges do
			local row = scan.edges[index]
			assert(row.class == "ordinary_interval_select" or
				row.class == "transition_interval_select",
				"census KAT seed " .. seed .. " edge " .. row.id ..
				" class " .. row.class)
			if row.qualifying_count then
				transition_rows = transition_rows + 1
				assert(row.qualifying_count == 1,
					"census KAT transition qualifying count differs")
			end
		end
		assert(transition_rows == 6, "census KAT expects 6 transition edges")
		for index = 1, #scan.junctions do
			pass_total = pass_total + scan.junctions[index].pass_count
			assert(scan.junctions[index].fail_count == 0,
				"census KAT junction pair failed")
		end
		assert(pass_total == 102, "census KAT expects 102 passing pairs")
		for index = 1, #scan.attachments do
			assert(scan.attachments[index].distance and
				scan.attachments[index].distance <= 1,
				"census KAT attachment distance exceeds one")
		end
		local expected_fills = assert(fixture.fills[seed],
			"census KAT fixture lacks seed " .. seed)
		for index = 1, #scan.bay_fills do
			assert(scan.bay_fills[index].fill_count == expected_fills[index],
				"census KAT fill count differs at " ..
				scan.bay_fills[index].id .. " seed " .. seed)
		end
	end
	assert(digest == fixture.digest,
		"census KAT determinism digest differs: " .. digest)
	print("census scan1 KAT passed (seeds 0 and max-u64, digest pinned)")
end
