-- Canonical four-seed vertical feasibility preflight for WP40 simple-map V1e.

local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local output = assert(arg[3], "preflight output path required")
local mode = arg[4] or "serial"

local ffi = rawget(_G, "wp40_ffi")
assert(ffi, "V1e R3 preflight requires LuaJIT FFI")
ffi.cdef[[
	unsigned char *SHA256(const unsigned char *data, size_t length,
		unsigned char *digest);
]]
local crypto = ffi.load("crypto")
local digest_buffer = ffi.new("unsigned char[32]")
local function raw_sha256(data)
	assert(crypto.SHA256(data, #data, digest_buffer) ~= nil, "SHA-256 failed")
	return ffi.string(digest_buffer, 32)
end

local common = dofile(repo .. "/tools/wp40/simple_map_r3_common.lua")
local offline = dofile(repo .. "/tools/wp40/simple_map_r3_offline.lua")(
	repo, scratch, raw_sha256)
local r2 = common.verify_r2(repo, raw_sha256)
local validator = dofile(repo .. "/tools/wp40/simple_map_r3_validate.lua")(common)
local seeds = {"0", "1", "9223372036854775808", "18446744073709551615"}

local input_paths = {
	"mods/MAPGEN/grug_mapgen/wp40/canonical.lua",
	"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua",
	"mods/MAPGEN/grug_mapgen/wp40/height.lua",
	"mods/MAPGEN/grug_mapgen/wp40/schemas.lua",
	"mods/MAPGEN/grug_mapgen/wp40/simple_map.lua",
	"mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua",
	"tools/wp40/run_simple_map_r3.sh",
	"tools/wp40/simple_map_r3_artifact.lua",
	"tools/wp40/simple_map_r3_common.lua",
	"tools/wp40/simple_map_r3_kat.lua",
	"tools/wp40/simple_map_r3_offline.lua",
	"tools/wp40/simple_map_r3_selftest.lua",
	"tools/wp40/simple_map_r3_validate.lua",
	"tools/wp40/simple_map_v1e_r3_preflight.lua",
}
table.sort(input_paths)

local evidence_families = {
	"relief_roots", "octave_lattices", "primary_profiles", "landmarks",
	"stations", "anchors", "hard_protection", "routes", "route_exact_pins",
	"route_water_lower_bounds", "route_raise_witnesses", "ford_approaches",
	"ford_approach_summaries", "named_water_operations", "derived_water_runs",
	"landings", "tunnels", "hydrology", "interfaces",
	"contact_face_waterfalls", "exterior_witnesses", "coastal_cores",
}

local function direct_numeric_extrema(rows)
	local result = {}
	for row_index = 1, #rows do
		local row = rows[row_index]
		for key, value in pairs(row) do
			if type(key) == "string" and type(value) == "number" then
				local item = result[key]
				if not item then
					item = {count = 0, minimum = value, maximum = value}
					result[key] = item
				end
				item.count = item.count + 1
				item.minimum = math.min(item.minimum, value)
				item.maximum = math.max(item.maximum, value)
			end
		end
	end
	return result
end

local function evidence_summary(evidence, public_metrics, validation)
	local counts, extrema = {}, {}
	for family_index = 1, #evidence_families do
		local family = evidence_families[family_index]
		local rows = evidence[family]
		common.dense_count(rows, "preflight evidence " .. family)
		counts[family] = #rows
		extrema[family] = direct_numeric_extrema(rows)
	end
	if counts.anchors ~= 100 or counts.routes ~= 139 or
			counts.tunnels ~= 2 or counts.interfaces ~= 15 or
			counts.contact_face_waterfalls ~= 3 then
		error("V1e R3 preflight evidence population differs", 0)
	end
	if validation.graded_paths ~= 139 or validation.wet_reach_contact_pairs ~= 12 or
			validation.unequal_interface_pairs ~= 7 or
			validation.hydrology_contact_roster_sha256 ~=
				r2.bindings.hydrology_contact_roster_sha256 then
		error("V1e R3 preflight validation population differs", 0)
	end
	for route_index = 1, #evidence.routes do
		if evidence.routes[route_index].maximum_step > 1 then
			error("V1e R3 preflight route maximum step differs", 0)
		end
	end
	return {
		violation_count = 0,
		family_counts = counts,
		family_numeric_extrema = extrema,
		public_metrics = public_metrics,
		operation_counts = evidence.operation_counts,
		hydrology_interface_population = evidence.hydrology_interface_population,
		validation = validation,
	}
end

local builder = common.new_tsv()
builder.add("schema", common.V1E_R3_PREFLIGHT_SCHEMA)
builder.add("layout_id", common.LAYOUT_ID)
builder.add("layout_revision_id", common.LAYOUT_REVISION_ID)
builder.add("source_schema", common.R2_SOURCE_SCHEMA)
builder.add("height_schema", common.HEIGHT_SCHEMA)
builder.add("seed_count", #seeds)
builder.add("r2_body_sha256", r2.body_sha256)
builder.add("r2_file_sha256", r2.file_sha256)
builder.add("r2_hydrology_contact_roster_sha256",
	r2.bindings.hydrology_contact_roster_sha256)
for path_index = 1, #input_paths do
	local path = input_paths[path_index]
	builder.add("input_sha256", path,
		common.digest_hex(raw_sha256, common.read_file(repo .. "/" .. path)))
end

local function build_seed(seed_index)
	local seed = seeds[seed_index]
	if not seed then error("V1e R3 preflight seed index differs", 0) end
	io.stderr:write("v1e_r3_preflight\tconstruct\t", seed, "\n")
	io.stderr:flush()
	local loaded = offline.load(seed)
	local session, horizontal, source = loaded.height, loaded.horizontal,
		loaded.source
	local public_metrics = validator.validate_api(session, raw_sha256)
	local evidence = validator.validate_evidence(session, source)
	local function progress(stage, completed, total)
		io.stderr:write("v1e_r3_preflight\t", seed, "\t", stage, "\t",
			completed, "\t", total, "\n")
		io.stderr:flush()
	end
	local validation = validator.run(session, horizontal, source, r2,
		evidence, "full", progress)
	local projection = validator.deterministic_evidence_projection(evidence)
	local digest_builder = common.new_tsv()
	common.add_evidence(digest_builder, {height = projection,
		validation = validation})
	local evidence_digest = common.digest_hex(raw_sha256, digest_builder.body())
	local metadata = common.new_tsv()
	metadata.add("seed_evidence_sha256", seed, evidence_digest)
	metadata.add("seed_canonical_kat_sha256", seed,
		session.canonical_kat_digest())
	metadata.add("seed_relief_lattice_sha256", seed,
		session.relief_lattice_digest())
	metadata.add("seed_route_sha256", seed, evidence.route_digest)
	metadata.add("seed_operation_sha256", seed, evidence.operation_digest)
	metadata.add("seed_visible_surface_sha256", seed,
		evidence.visible_surface_classification_digest)
	local summary = {
		seed = seed,
		result = evidence_summary(evidence, public_metrics, validation),
	}
	loaded, session, horizontal, source, public_metrics, evidence, validation,
		projection, digest_builder = nil, nil, nil, nil, nil, nil, nil, nil, nil
	collectgarbage("collect")
	return seed, metadata.body(), summary
end

local function add_header(target)
	target.add("schema", common.V1E_R3_PREFLIGHT_SCHEMA)
	target.add("layout_id", common.LAYOUT_ID)
	target.add("layout_revision_id", common.LAYOUT_REVISION_ID)
	target.add("source_schema", common.R2_SOURCE_SCHEMA)
	target.add("height_schema", common.HEIGHT_SCHEMA)
	target.add("seed_count", #seeds)
	target.add("r2_body_sha256", r2.body_sha256)
	target.add("r2_file_sha256", r2.file_sha256)
	target.add("r2_hydrology_contact_roster_sha256",
		r2.bindings.hydrology_contact_roster_sha256)
	for path_index = 1, #input_paths do
		local path = input_paths[path_index]
		target.add("input_sha256", path,
			common.digest_hex(raw_sha256, common.read_file(repo .. "/" .. path)))
	end
end

local function final_write(target)
	local body = target.body()
	local body_digest = common.digest_hex(raw_sha256, body)
	local bytes = body .. "preflight_sha256\t" .. body_digest .. "\n"
	common.write_file(output, bytes)
	io.write("v1e_r3_preflight_body_sha256\t", body_digest, "\n")
	io.write("v1e_r3_preflight_file_sha256\t",
		common.digest_hex(raw_sha256, bytes), "\n")
end

local function lines(bytes)
	local result = {}
	for line in bytes:gmatch("([^\n]+)\n") do result[#result + 1] = line end
	if table.concat(result, "\n") .. "\n" ~= bytes then
		error("V1e R3 preflight shard is not newline-terminated", 0)
	end
	return result
end

local function read_shard(path, expected_index)
	local bytes = common.read_file(path)
	local body, embedded = bytes:match(
		"^(.*\n)preflight_shard_sha256\t([0-9a-f]+)\n$")
	if not body or #embedded ~= 64 or
			common.digest_hex(raw_sha256, body) ~= embedded then
		error("V1e R3 preflight shard digest differs", 0)
	end
	local rows = lines(body)
	local expected_seed = seeds[expected_index]
	if rows[1] ~= "schema\tgrug_wp40_simple_map_v1e_r3_preflight_shard_v1" or
			rows[2] ~= "seed_index\t" .. expected_index or
			rows[3] ~= "seed\t" .. expected_seed or
			rows[4] ~= "metadata_begin" then
		error("V1e R3 preflight shard header differs", 0)
	end
	local metadata, evidence, cursor = {}, {}, 5
	while rows[cursor] and rows[cursor] ~= "metadata_end" do
		metadata[#metadata + 1] = rows[cursor]
		cursor = cursor + 1
	end
	if rows[cursor] ~= "metadata_end" or rows[cursor + 1] ~= "evidence_begin" then
		error("V1e R3 preflight shard metadata boundary differs", 0)
	end
	cursor = cursor + 2
	while rows[cursor] and rows[cursor] ~= "evidence_end" do
		evidence[#evidence + 1] = rows[cursor]
		cursor = cursor + 1
	end
	if rows[cursor] ~= "evidence_end" or cursor ~= #rows then
		error("V1e R3 preflight shard evidence boundary differs", 0)
	end
	local names = {"seed_evidence_sha256", "seed_canonical_kat_sha256",
		"seed_relief_lattice_sha256", "seed_route_sha256",
		"seed_operation_sha256", "seed_visible_surface_sha256"}
	if #metadata ~= #names or #evidence == 0 then
		error("V1e R3 preflight shard population differs", 0)
	end
	for index = 1, #names do
		if not metadata[index]:match("^" .. names[index] .. "\t" ..
				expected_seed .. "\t[0-9a-f]+$") then
			error("V1e R3 preflight shard metadata differs", 0)
		end
	end
	local prefix = "height/preflight/" .. ("seed_%02d"):format(expected_index)
	for index = 1, #evidence do
		local path = evidence[index]:match("^evidence[^\t]*\t([^\t]+)")
		if not path or (path ~= prefix and
				path:sub(1, #prefix + 1) ~= prefix .. "/") then
			error("V1e R3 preflight shard evidence path differs", 0)
		end
	end
	return metadata, evidence
end

if mode == "serial" then
	local summaries = {}
	for seed_index = 1, #seeds do
		local _, metadata, summary = build_seed(seed_index)
		for _, line in ipairs(lines(metadata)) do builder.add_raw(line) end
		summaries[("seed_%02d"):format(seed_index)] = summary
	end
	common.add_evidence(builder, {preflight = summaries})
	final_write(builder)
elseif mode == "shard" then
	local seed_index = assert(tonumber(arg[5]), "preflight seed index required")
	local seed, metadata, summary = build_seed(seed_index)
	local shard = common.new_tsv()
	shard.add("schema", "grug_wp40_simple_map_v1e_r3_preflight_shard_v1")
	shard.add("seed_index", seed_index)
	shard.add("seed", seed)
	shard.add("metadata_begin")
	for _, line in ipairs(lines(metadata)) do shard.add_raw(line) end
	shard.add("metadata_end")
	shard.add("evidence_begin")
	common.add_evidence_at(shard,
		"height/preflight/" .. ("seed_%02d"):format(seed_index), summary)
	shard.add("evidence_end")
	local body = shard.body()
	common.write_file(output, body .. "preflight_shard_sha256\t" ..
		common.digest_hex(raw_sha256, body) .. "\n")
elseif mode == "merge" then
	local metadata, evidence = {}, {}
	for seed_index = 1, #seeds do
		metadata[seed_index], evidence[seed_index] =
			read_shard(assert(arg[4 + seed_index], "preflight shard required"),
				seed_index)
	end
	local merged = common.new_tsv()
	add_header(merged)
	for seed_index = 1, #seeds do
		for _, line in ipairs(metadata[seed_index]) do merged.add_raw(line) end
	end
	merged.add("evidence_map", "height", 1)
	merged.add("evidence_map", "height/preflight", #seeds)
	for seed_index = 1, #seeds do
		for _, line in ipairs(evidence[seed_index]) do merged.add_raw(line) end
	end
	final_write(merged)
else
	error("V1e R3 preflight mode must be serial, shard or merge", 0)
end
