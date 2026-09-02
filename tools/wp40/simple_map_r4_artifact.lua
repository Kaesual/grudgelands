-- Canonical R4 extent-shard codec and seed-zero artifact writer.

local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local output = assert(arg[3], "artifact or shard output path required")
local mode = assert(arg[4], "artifact mode required")
assert(mode == "shard" or mode == "merge", "mode must be shard or merge")

local ffi = rawget(_G, "wp40_ffi")
local injected_raw_sha256
if ffi then
	ffi.cdef[[
		unsigned char *SHA256(const unsigned char *data, size_t length,
			unsigned char *digest);
	]]
	local crypto = ffi.load("crypto")
	local digest_buffer = ffi.new("unsigned char[32]")
	injected_raw_sha256 = function(data)
		assert(crypto.SHA256(data, #data, digest_buffer) ~= nil,
			"SHA-256 failed")
		return ffi.string(digest_buffer, 32)
	end
end

local common = dofile(repo .. "/tools/wp40/simple_map_r4_common.lua")
local offline = dofile(repo .. "/tools/wp40/simple_map_r4_offline.lua")(
	repo, scratch, injected_raw_sha256)
local authority = offline.preflight()
local validator = dofile(repo .. "/tools/wp40/simple_map_r4_validate.lua")(common)
local global_registry_before = rawget(_G, "grug_zones")

local COUNT_FAMILIES = {
	"water", "id", "race", "faction", "surface", "biome",
	"territory_700", "pvp_700", "territory_701", "pvp_701",
	"zone_land_counts",
}
local COUNT_FAMILY_SET = {}
for index = 1, #COUNT_FAMILIES do
	COUNT_FAMILY_SET[COUNT_FAMILIES[index]] = true
end

local function strict_text(value, label)
	if type(value) ~= "string" or value == "" or value:find("[\t\r\n]") then
		error("R4 artifact: " .. label .. " is not canonical text", 0)
	end
	return value
end

local function count_map(value, label)
	if type(value) ~= "table" then
		error("R4 artifact: " .. label .. " is not a count map", 0)
	end
	for key, count in pairs(value) do
		strict_text(key, label .. " key")
		common.safe_integer(count, label .. " count")
		if count < 0 then error("R4 artifact: negative count in " .. label, 0) end
	end
	return value
end

local function split_tsv(line)
	local fields = {}
	local start = 1
	while true do
		local separator = line:find("\t", start, true)
		if not separator then
			fields[#fields + 1] = line:sub(start)
			break
		end
		fields[#fields + 1] = line:sub(start, separator - 1)
		start = separator + 1
	end
	return fields
end

local function positive_integer(text, label)
	if type(text) ~= "string" or not text:match("^[0-9]+$") then
		error("R4 artifact: " .. label .. " is not unsigned decimal", 0)
	end
	local value = tonumber(text)
	common.safe_integer(value, label)
	return value
end

local function signed_integer(text, label)
	if type(text) ~= "string" or not text:match("^%-?[0-9]+$") then
		error("R4 artifact: " .. label .. " is not signed decimal", 0)
	end
	local value = tonumber(text)
	common.safe_integer(value, label)
	return value
end

local function write_shard(report)
	if type(report) ~= "table" or
			report.schema ~= "grug_wp40_simple_map_r4_extent_shard_v1" then
		error("R4 artifact: validator returned an unexpected shard schema", 0)
	end
	if report.violation_count ~= 0 then
		error("R4 artifact: extent shard reported violations", 0)
	end
	local min_z = common.safe_integer(report.min_z, "shard min_z")
	local max_z = common.safe_integer(report.max_z, "shard max_z")
	local columns = common.safe_integer(report.columns, "shard columns")
	if min_z > max_z or columns ~= (max_z - min_z + 1) *
			(common.MAX_X - common.MIN_X + 1) then
		error("R4 artifact: shard extent/column count differs", 0)
	end
	local builder = common.new_tsv()
	builder.add("schema", report.schema)
	builder.add("seed", "0")
	builder.add("r2_body_sha256", authority.r2.body_sha256)
	builder.add("r3_body_sha256", authority.r3.body_sha256)
	builder.add("min_z", min_z)
	builder.add("max_z", max_z)
	builder.add("columns", columns)
	for family_index = 1, #COUNT_FAMILIES do
		local family = COUNT_FAMILIES[family_index]
		local values = count_map(report[family], family)
		for _, key in ipairs(common.sorted_keys(values)) do
			builder.add("count", family, key, values[key])
		end
	end
	if type(report.zone_land_biome_counts) ~= "table" then
		error("R4 artifact: zone-land-biome counts missing", 0)
	end
	for _, zone_id in ipairs(common.sorted_keys(report.zone_land_biome_counts)) do
		strict_text(zone_id, "zone-land-biome zone")
		local values = count_map(report.zone_land_biome_counts[zone_id],
			"zone-land-biome " .. zone_id)
		for _, biome_id in ipairs(common.sorted_keys(values)) do
			builder.add("zone_land_biome", zone_id, biome_id, values[biome_id])
		end
	end
	common.dense_count(report.row_digests, "extent row digests")
	if #report.row_digests ~= max_z - min_z + 1 then
		error("R4 artifact: extent row-digest population differs", 0)
	end
	for index = 1, #report.row_digests do
		local row = report.row_digests[index]
		if type(row) ~= "table" or row.z ~= min_z + index - 1 then
			error("R4 artifact: extent row-digest order differs", 0)
		end
		builder.add("row_digest", row.z,
			common.digest(row.scalar_sha256, "scalar row digest"),
			common.digest(row.policy_sha256, "policy row digest"),
			common.digest(row.biome_sha256, "biome row digest"))
	end
	local body = builder.body()
	local digest = common.digest_hex(offline.raw_sha256, body)
	common.write_file(output, body .. "shard_sha256\t" .. digest .. "\n")
	io.write("r4_extent_shard_sha256\t", min_z, "\t", max_z, "\t",
		digest, "\n")
end

local function read_shard(path)
	local bytes = common.read_file(path)
	local body, embedded = bytes:match("^(.*\n)shard_sha256\t([0-9a-f]+)\n$")
	if not body or #embedded ~= 64 or
			common.digest_hex(offline.raw_sha256, body) ~= embedded then
		error("R4 artifact: extent shard digest differs", 0)
	end
	if body:sub(1, 1) == "\n" or body:find("\r", 1, true) or
			body:find("\n\n", 1, true) then
		error("R4 artifact: extent shard framing differs", 0)
	end
	local report = {
		schema = "grug_wp40_simple_map_r4_extent_shard_v1",
		zone_land_biome_counts = {}, row_digests = {},
	}
	for index = 1, #COUNT_FAMILIES do report[COUNT_FAMILIES[index]] = {} end
	local seen_header = {}
	for line in body:gmatch("([^\n]+)\n") do
		local fields = split_tsv(line)
		local kind = fields[1]
		if kind == "schema" and #fields == 2 then
			if seen_header.schema or fields[2] ~= report.schema then
				error("R4 artifact: extent shard schema differs", 0)
			end
			seen_header.schema = true
		elseif kind == "seed" and #fields == 2 then
			if seen_header.seed or fields[2] ~= "0" then
				error("R4 artifact: extent shard seed differs", 0)
			end
			seen_header.seed = true
		elseif (kind == "r2_body_sha256" or kind == "r3_body_sha256") and
				#fields == 2 then
			if seen_header[kind] then
				error("R4 artifact: duplicate extent authority header", 0)
			end
			local expected = kind == "r2_body_sha256" and
				common.R2_BODY_SHA256 or common.R3_BODY_SHA256
			if fields[2] ~= expected then
				error("R4 artifact: extent authority header differs", 0)
			end
			seen_header[kind] = true
		elseif (kind == "min_z" or kind == "max_z" or kind == "columns") and
				#fields == 2 then
			if seen_header[kind] then
				error("R4 artifact: duplicate extent shard header", 0)
			end
			seen_header[kind] = true
			report[kind] = kind == "columns" and
				positive_integer(fields[2], kind) or signed_integer(fields[2], kind)
		elseif kind == "count" and #fields == 4 and
				COUNT_FAMILY_SET[fields[2]] then
			local values = report[fields[2]]
			strict_text(fields[3], "count key")
			if values[fields[3]] ~= nil then
				error("R4 artifact: duplicate extent count", 0)
			end
			values[fields[3]] = positive_integer(fields[4], "extent count")
		elseif kind == "zone_land_biome" and #fields == 4 then
			local zone_id = strict_text(fields[2], "zone-land-biome zone")
			local biome_id = strict_text(fields[3], "zone-land-biome biome")
			local values = report.zone_land_biome_counts[zone_id]
			if not values then values = {}; report.zone_land_biome_counts[zone_id] = values end
			if values[biome_id] ~= nil then
				error("R4 artifact: duplicate zone-land-biome count", 0)
			end
			values[biome_id] = positive_integer(fields[4],
				"zone-land-biome count")
		elseif kind == "row_digest" and #fields == 5 then
			report.row_digests[#report.row_digests + 1] = {
				z = signed_integer(fields[2], "row z"),
				scalar_sha256 = common.digest(fields[3], "scalar row digest"),
				policy_sha256 = common.digest(fields[4], "policy row digest"),
				biome_sha256 = common.digest(fields[5], "biome row digest"),
			}
		else
			error("R4 artifact: unknown or malformed extent shard row", 0)
		end
	end
	if not seen_header.schema or not seen_header.seed or
			not seen_header.r2_body_sha256 or not seen_header.r3_body_sha256 or
			not seen_header.min_z or not seen_header.max_z or
			not seen_header.columns then
		error("R4 artifact: incomplete extent shard header", 0)
	end
	if report.min_z > report.max_z or
			report.columns ~= (report.max_z - report.min_z + 1) *
			(common.MAX_X - common.MIN_X + 1) or
			#report.row_digests ~= report.max_z - report.min_z + 1 then
		error("R4 artifact: extent shard coverage differs", 0)
	end
	for index = 1, #report.row_digests do
		if report.row_digests[index].z ~= report.min_z + index - 1 then
			error("R4 artifact: extent shard row order differs", 0)
		end
	end
	return report
end

local function context(loaded)
	return {
		source = loaded.source,
		repo = repo,
		horizontal = loaded.horizontal,
		height = loaded.height,
		peer_session = loaded.peer_session,
	}
end

if mode == "shard" then
	local min_z = assert(tonumber(arg[5]), "extent shard min_z required")
	local max_z = assert(tonumber(arg[6]), "extent shard max_z required")
	common.safe_integer(min_z, "extent shard min_z")
	common.safe_integer(max_z, "extent shard max_z")
	if min_z < common.MIN_Z or max_z > common.MAX_Z or min_z > max_z then
		error("R4 artifact: extent shard is outside query bounds", 0)
	end
	local loaded = offline.load_foundation("0", common.WATER_LEVEL,
		{horizontal_oracle = true})
	local function progress(stage, completed, total)
		io.stderr:write("r4_progress\t", stage, "\t", completed, "\t", total, "\n")
		io.stderr:flush()
	end
	write_shard(validator.run_extent_shard(loaded.session, context(loaded),
		offline.raw_sha256, min_z, max_z, progress))
else
	local shards = {}
	for index = 5, #arg do shards[#shards + 1] = read_shard(arg[index]) end
	if #shards == 0 then error("R4 artifact: extent shards missing", 0) end
	local loaded = offline.load_foundation("0", common.WATER_LEVEL,
		{peer = true, horizontal_oracle = true, height_oracle = true})
	if global_registry_before ~= nil or rawget(_G, "grug_zones") ~= nil then
		error("R4 artifact: disabled loader published a global registry", 0)
	end
	if loaded.foundation.enabled ~= false or loaded.foundation.disabled_reason ~=
			"WP40 R4 payload is validated but not published until R7" then
		error("R4 artifact: disabled foundation boundary differs", 0)
	end
	local retained_foundation_fields = {"schemas", "canonical", "deterministic",
		"validation", "index128", "seed_corpus"}
	for _, field in ipairs(retained_foundation_fields) do
		if type(loaded.foundation[field]) ~= "table" then
			error("R4 artifact: retained foundation field differs: " .. field, 0)
		end
	end
	for _, field in ipairs({"new_session", "new_engine_session",
			"raw_sha256_from_core"}) do
		if type(loaded.foundation[field]) ~= "function" then
			error("R4 artifact: foundation constructor/seam differs: " .. field, 0)
		end
	end
	for _, field in ipairs({"compile", "compiler", "compiled_schema",
			"canonicalize_compiled", "new_offline_test_adapter", "trust_probe"}) do
		if loaded.foundation[field] ~= nil then
			error("R4 artifact: retired foundation field remains: " .. field, 0)
		end
	end
	if loaded.engine_callback_registration_calls ~= 0 or
			loaded.engine_unexpected_api_reads ~= 0 then
		error("R4 artifact: engine-shaped loader used an unexpected API", 0)
	end
	local population = validator.merge_extent_shards(shards, offline.raw_sha256,
		loaded.source)
	local session = loaded.session
	if session.canonical_kat() ~= loaded.peer_session.canonical_kat() or
			session.canonical_kat_digest() ~=
			loaded.peer_session.canonical_kat_digest() then
		error("R4 artifact: engine-free and engine-shaped sessions differ", 0)
	end
	local validation_context = context(loaded)
	local api = validator.validate_api(session, offline.raw_sha256)
	local construction = validator.validate_construction(session,
		validation_context, offline.raw_sha256)
	local supplemental = validator.validate_supplemental(session,
		validation_context, offline.raw_sha256, "full")
	local targeted_rows, targeted_coverage = validator.targeted_rows(session,
		validation_context, offline.raw_sha256)
	common.sort_canonical_rows(targeted_rows, "artifact targeted rows")
	validator.assert_targeted_coverage(targeted_coverage)
	local metrics = session.metrics()
	local projection = validator.deterministic_projection({
		api = api,
		construction = construction,
		population = population,
		supplemental = supplemental,
		targeted = {
			schema = "grug_wp40_simple_map_r4_artifact_targeted_v1",
			seed = "0",
			row_count = #targeted_rows,
			rows = targeted_rows,
			coverage = targeted_coverage,
		},
		metrics = metrics,
	})

	local builder = common.new_tsv()
	builder.add("schema", common.R4_ARTIFACT_SCHEMA)
	builder.add("zones_schema", common.ZONES_SCHEMA)
	builder.add("sparse_schema", common.SPARSE_INDEX_SCHEMA)
	builder.add("layout_id", common.LAYOUT_ID)
	builder.add("layout_revision_id", common.LAYOUT_REVISION_ID)
	builder.add("source_schema", common.SOURCE_SCHEMA)
	builder.add("horizontal_schema", common.HORIZONTAL_SCHEMA)
	builder.add("height_schema", common.HEIGHT_SCHEMA)
	builder.add("seed", "0")
	builder.add("project_water_level", common.WATER_LEVEL)
	builder.add("query_min_x", common.MIN_X)
	builder.add("query_max_x", common.MAX_X)
	builder.add("query_min_z", common.MIN_Z)
	builder.add("query_max_z", common.MAX_Z)
	builder.add("query_column_count", common.COLUMN_COUNT)
	builder.add("validation_mode", "full")
	builder.add("r2_body_sha256", authority.r2.body_sha256)
	builder.add("r2_file_sha256", authority.r2.file_sha256)
	builder.add("r3_body_sha256", authority.r3.body_sha256)
	builder.add("r3_file_sha256", authority.r3.file_sha256)
	local r4_input_paths = {
		"mods/MAPGEN/grug_mapgen/wp40/index128.lua",
		"mods/MAPGEN/grug_mapgen/wp40/zones.lua",
		"mods/MAPGEN/grug_mapgen/wp40/init.lua",
		"tools/wp40/simple_map_r4_common.lua",
		"tools/wp40/simple_map_r4_offline.lua",
		"tools/wp40/simple_map_r4_validate.lua",
		"tools/wp40/simple_map_r4_artifact.lua",
		"tools/wp40/simple_map_r4_kat.lua",
		"tools/wp40/simple_map_r4_selftest.lua",
		"tools/wp40/run_simple_map_r4.sh",
		"tools/wp40/t1_foundation_test.lua",
		"tools/wp40/t2_schema_core_test.lua",
	}
	if #r4_input_paths ~= 12 then error("R4 executable input roster differs", 0) end
	local input_manifest = common.deep_copy(authority.inputs)
	for index = 1, #r4_input_paths do
		local path = r4_input_paths[index]
		local digest = common.digest_hex(offline.raw_sha256,
			common.read_file(repo .. "/" .. path))
		if input_manifest[path] ~= nil and input_manifest[path] ~= digest then
			error("R4 artifact: input digest conflict for " .. path, 0)
		end
		input_manifest[path] = digest
	end
	local input_count = 0
	for _ in pairs(input_manifest) do input_count = input_count + 1 end
	if input_count ~= 35 then error("R4 input manifest is not exactly 35 files", 0) end
	for _, path in ipairs(common.sorted_keys(input_manifest)) do
		builder.add("input_sha256", path, input_manifest[path])
	end
	builder.add("canonical_kat_sha256", session.canonical_kat_digest())
	builder.add("peer_canonical_kat_sha256",
		loaded.peer_session.canonical_kat_digest())
	builder.add("engine_setting_reads", loaded.engine_setting_reads)
	builder.add("engine_sha256_calls", loaded.engine_sha256_calls)
	builder.add("engine_callback_registration_calls",
		loaded.engine_callback_registration_calls)
	builder.add("engine_unexpected_api_reads", loaded.engine_unexpected_api_reads)
	builder.add("foundation_enabled", loaded.foundation.enabled)
	builder.add("foundation_disabled_reason", loaded.foundation.disabled_reason)
	builder.add("global_registry_published", false)
	for _, field in ipairs(retained_foundation_fields) do
		builder.add("foundation_retained_field", field, type(loaded.foundation[field]))
	end
	for _, field in ipairs({"new_session", "new_engine_session",
			"raw_sha256_from_core"}) do
		builder.add("foundation_constructor", field, type(loaded.foundation[field]))
	end
	for _, field in ipairs({"compile", "compiler", "compiled_schema",
			"canonicalize_compiled", "new_offline_test_adapter", "trust_probe"}) do
		builder.add("foundation_retired_field_absent", field, true)
	end
	for _, key in ipairs(common.sorted_keys(metrics)) do
		builder.add("metric", key, metrics[key])
	end
	-- Flattened Lua maps cannot represent a present field whose value is nil.
	-- Bind the exact nullable public registry/anchor/travel fields explicitly.
	for zone_index = 1, #loaded.source.zones do
		local source_zone = loaded.source.zones[zone_index]
		local row = assert(session.get(source_zone.id), "public zone record missing")
		builder.add("zone_record", row.numeric_id, row.id, row.display_name,
			row.macro_region, row.race_region, row.faction, row.territory_rule,
			row.pvp_rule, row.level_min, row.level_max, row.primary_relief_id,
			row.difficulty_target, row.civic_no_hostiles, row.hub.x, row.hub.z)
		for biome_index = 1, #row.biomes do
			builder.add("zone_biome", row.id, biome_index,
				row.biomes[biome_index].id, row.biomes[biome_index].share)
		end
	end
	for anchor_index = 1, #loaded.source.anchors do
		local source_anchor = loaded.source.anchors[anchor_index]
		local zone_id = loaded.source.zones[source_anchor.zone_numeric_id].id
		local row = assert(session.anchor(zone_id, source_anchor.slot_id),
			"public anchor record missing")
		builder.add("anchor_record", anchor_index, row.id, row.numeric_id,
			row.zone_numeric_id, row.slot_id, row.template_id, row.selection_mode,
			row.approved_candidate_index, row.x, row.y, row.z, row.platform_kind,
			row.path_kind, row.functional_feature_id)
	end
	for boat_index = 1, #loaded.source.boat_paths do
		local source_boat = loaded.source.boat_paths[boat_index]
		local from_zone = loaded.source.zones[source_boat.from_zone].id
		local links = session.travel_links(from_zone)
		local row
		for link_index = 1, #links do
			if links[link_index].id == source_boat.id then row = links[link_index] end
		end
		assert(row, "public boat travel record missing")
		builder.add("boat_link", boat_index, row.id, row.kind, row.from_zone_id,
			row.to_zone_id, row.destination_zone_id, row.landing_id, row.width)
		for point_index = 1, #row.centreline do
			builder.add("boat_point", row.id, point_index,
				row.centreline[point_index].x, row.centreline[point_index].z)
		end
	end
	-- Bind the complete validated construction evidence, including all 57
	-- neighbor edges and all 42 hard-protection records. The explicit public
	-- rows above additionally preserve nullable fields as "-" sentinels.
	common.add_evidence_at(builder, "production", session.artifact_evidence())
	common.add_evidence_at(builder, "r4", projection)
	local bytes, body_digest = common.finalize_artifact(offline.raw_sha256,
		builder.body())
	common.write_file(output, bytes)
	local complete_digest = common.digest_hex(offline.raw_sha256, bytes)
	io.write("r4_artifact_body_sha256\t", body_digest, "\n")
	io.write("r4_artifact_file_sha256\t", complete_digest, "\n")
end
