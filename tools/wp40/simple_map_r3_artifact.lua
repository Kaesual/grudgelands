-- Canonical R3 artifact writer. Full mode is the LuaJIT exhaustive gate.

local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local output = assert(arg[3], "artifact output path required")
local mode = arg[4] or "full"
assert(mode == "full" or mode == "quick", "mode must be full or quick")

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
		assert(crypto.SHA256(data, #data, digest_buffer) ~= nil, "SHA-256 failed")
		return ffi.string(digest_buffer, 32)
	end
end

local common = dofile(repo .. "/tools/wp40/simple_map_r3_common.lua")
local offline = dofile(repo .. "/tools/wp40/simple_map_r3_offline.lua")(
	repo, scratch, injected_raw_sha256)
local r2 = common.verify_r2(repo, offline.raw_sha256)
local validator = dofile(repo .. "/tools/wp40/simple_map_r3_validate.lua")(common)

local start_construct = os.clock()
local loaded = offline.load("0")
local construction_cpu_seconds = os.clock() - start_construct
local session, horizontal, source = loaded.height, loaded.horizontal, loaded.source
local public_metrics = validator.validate_api(session, offline.raw_sha256)
local evidence = validator.validate_evidence(session, source)

local function progress(stage, completed, total)
	io.stderr:write("r3_progress\t", stage, "\t", completed, "\t", total, "\n")
	io.stderr:flush()
end
local start_validate = os.clock()
local validation = validator.run(session, horizontal, source, r2,
	evidence, mode, progress)
local validation_cpu_seconds = os.clock() - start_validate

local builder = common.new_tsv()
builder.add("schema", common.R3_ARTIFACT_SCHEMA)
builder.add("height_schema", common.HEIGHT_SCHEMA)
builder.add("layout_id", source.layout_id)
builder.add("layout_revision_id", source.layout_revision_id)
builder.add("source_schema", source.schema)
builder.add("seed", "0")
builder.add("project_water_level", common.WATER_LEVEL)
builder.add("validation_mode", mode)
builder.add("r2_body_sha256", r2.body_sha256)
builder.add("r2_file_sha256", r2.file_sha256)

local input_paths = {
	"mods/MAPGEN/grug_mapgen/wp40/schemas.lua",
	"mods/MAPGEN/grug_mapgen/wp40/canonical.lua",
	"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua",
	"mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua",
	"mods/MAPGEN/grug_mapgen/wp40/simple_map.lua",
	"mods/MAPGEN/grug_mapgen/wp40/height.lua",
	"tools/wp40/simple_map_r3_common.lua",
	"tools/wp40/simple_map_r3_offline.lua",
	"tools/wp40/simple_map_r3_validate.lua",
	"tools/wp40/simple_map_r3_artifact.lua",
	"tools/wp40/simple_map_r3_kat.lua",
	"tools/wp40/simple_map_r3_selftest.lua",
	"tools/wp40/run_simple_map_r3.sh",
}
for index = 1, #input_paths do
	local path = input_paths[index]
	builder.add("input_sha256", path,
		common.digest_hex(offline.raw_sha256, common.read_file(repo .. "/" .. path)))
end
builder.add("canonical_kat_sha256", session.canonical_kat_digest())
builder.add("relief_lattice_sha256", session.relief_lattice_digest())
for _, key in ipairs(common.sorted_keys(public_metrics)) do
	builder.add("metric", key, public_metrics[key])
end
common.add_evidence(builder, {
	height = validator.deterministic_evidence_projection(evidence),
	validation = validation,
})

local body = builder.body()
local body_digest = common.digest_hex(offline.raw_sha256, body)
local bytes = body .. "artifact_sha256\t" .. body_digest .. "\n"
common.write_file(output, bytes)
local complete_digest = common.digest_hex(offline.raw_sha256, bytes)

io.write("r3_artifact_body_sha256\t", body_digest, "\n")
io.write("r3_artifact_file_sha256\t", complete_digest, "\n")
io.write(("r3_timing_unbound\tconstruction_cpu_seconds\t%.6f\n"):
	format(construction_cpu_seconds))
io.write(("r3_timing_unbound\tvalidation_cpu_seconds\t%.6f\n"):
	format(validation_cpu_seconds))
