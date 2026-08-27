-- Production-independent smoke for the R4 authority gate and canonical tools.

local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
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

assert(common.digest_hex(offline.raw_sha256, "") ==
	"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
assert(common.digest_hex(offline.raw_sha256, "abc") ==
	"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")

assert(common.normalize_node(0.49) == 0)
assert(common.normalize_node(0.5) == 1)
assert(common.normalize_node(-0.49) == 0)
assert(common.normalize_node(-0.5) == -1)
assert(common.normalize_node(common.MAX_SAFE) == common.MAX_SAFE)
assert(common.normalize_node(-common.MAX_SAFE) == -common.MAX_SAFE)
assert(not pcall(common.normalize_node, 0 / 0))
assert(not pcall(common.normalize_node, math.huge))
assert(not pcall(common.normalize_node, common.MAX_SAFE + 2))
local position = common.normalize_pos({x = 1.5, y = -2.5, z = 3.49})
assert(position.x == 2 and position.y == -3 and position.z == 3)
assert(not pcall(common.normalize_pos, {x = 0, z = 0}))
assert(common.floor_div(-1, 128) == -1)
assert(common.floor_div(-128, 128) == -1)
assert(common.floor_div(-129, 128) == -2)
assert(common.round_ratio(1, 2) == 1)
assert(common.round_ratio(-1, 2) == -1)
assert(common.round_ratio(1, 3) == 0)

assert(common.rational_compare(1, 2, 2, 4) == 0)
assert(common.rational_compare(1, 3, 1, 2) < 0)
assert(common.rational_compare(common.MAX_SAFE - 1, common.MAX_SAFE,
	common.MAX_SAFE - 2, common.MAX_SAFE - 1) > 0)
assert(not pcall(common.rational_compare, -1, 2, 1, 2))

local raster = common.raster_polyline({{x = -2, z = -1}, {x = 2, z = 1}})
assert(#raster == 5)
assert(raster[1].x == -2 and raster[1].z == -1)
assert(raster[5].x == 2 and raster[5].z == 1)
assert(not pcall(common.raster_polyline, {{x = 1, z = 1}, {x = 1, z = 1}}))

local builder = common.new_tsv()
builder.add("nil_tail", 1, nil)
common.add_evidence(builder, {
	z = {2, 3},
	a = {flag = true, fraction = "1/3"},
	["slash/key"] = "percent%",
})
common.add_evidence_at(builder, "zones/preflight/seed_01", {seed = "0"})
local body = builder.body()
assert(body:match("^nil_tail\t1\t%-\n"))
assert(body:find("evidence_map\tzones", 1, true))
assert(body:find("zones/slash%2fkey", 1, true))
assert(body:find("evidence\tzones/preflight/seed_01/seed\tstring\t0", 1, true))
assert(not pcall(builder.add_raw, "bad\nline"))
assert(not pcall(builder.add, "float", 1 / 3))
local canonical_rows = {{"b", 2}, {"a", 3}, {"a", 2}}
common.sort_canonical_rows(canonical_rows, "synthetic rows")
assert(canonical_rows[1][1] == "a" and canonical_rows[1][2] == 2)
assert(canonical_rows[2][1] == "a" and canonical_rows[2][2] == 3)
assert(canonical_rows[3][1] == "b" and canonical_rows[3][2] == 2)
assert(not pcall(common.sort_canonical_rows, {{"float", 1 / 3}},
	"synthetic float rows"))

local artifact, body_digest = common.finalize_artifact(offline.raw_sha256,
	"schema\tsynthetic_r4_v1\n")
local synthetic_spec = {
	label = "synthetic artifact",
	body_sha256 = body_digest,
	file_sha256 = common.digest_hex(offline.raw_sha256, artifact),
	input_count = 0,
	required = {schema = "synthetic_r4_v1"},
}
local parsed = common.parse_artifact_bytes(offline.raw_sha256, artifact,
	synthetic_spec)
assert(parsed.input_count == 0 and parsed.bindings.schema == "synthetic_r4_v1")
local tampered = artifact:gsub("synthetic_r4_v1", "synthetic_r4_v2", 1)
assert(not pcall(common.parse_artifact_bytes, offline.raw_sha256, tampered,
	synthetic_spec))

local zero_digest = string.rep("0", 64)
local function parse_synthetic_input(body, count)
	local bytes, digest = common.finalize_artifact(offline.raw_sha256, body)
	return common.parse_artifact_bytes(offline.raw_sha256, bytes, {
		label = "synthetic input artifact",
		body_sha256 = digest,
		file_sha256 = common.digest_hex(offline.raw_sha256, bytes),
		input_count = count,
		required = {schema = "synthetic_input_v1"},
	})
end
local input_parsed = parse_synthetic_input("schema\tsynthetic_input_v1\n" ..
	"input_sha256\ta/b.lua\t" .. zero_digest .. "\n", 1)
assert(input_parsed.inputs["a/b.lua"] == zero_digest)
assert(not pcall(parse_synthetic_input, "schema\tsynthetic_input_v1\n" ..
	"input_sha256\t../escape.lua\t" .. zero_digest .. "\n", 1))
assert(not pcall(parse_synthetic_input, "schema\tsynthetic_input_v1\n" ..
	"input_sha256\ta/b.lua\t" .. zero_digest .. "\n" ..
	"input_sha256\ta/b.lua\t" .. zero_digest .. "\n", 2))

assert(not offline.loaded())
local before = offline.sha256_call_count()
local authority = offline.preflight()
local after = offline.sha256_call_count()
assert(after > before)
assert(not offline.loaded(), "authority preflight loaded production code")
assert(authority.r2.body_sha256 == common.R2_BODY_SHA256)
assert(authority.r2.file_sha256 == common.R2_FILE_SHA256)
assert(authority.r2.input_count == common.R2_INPUT_COUNT)
assert(authority.r3.body_sha256 == common.R3_BODY_SHA256)
assert(authority.r3.file_sha256 == common.R3_FILE_SHA256)
assert(authority.r3.input_count == common.R3_INPUT_COUNT)
assert(authority.input_count == common.AUTHORITY_INPUT_COUNT)
assert(authority.r2.bindings.housing_result_sha256 ==
	common.HOUSING_RESULT_SHA256)
assert(authority.inputs["mods/MAPGEN/grug_mapgen/wp40/height.lua"] ==
	"f69fcd006af40f2f473d592c412508c3d7043403b15c07bfedcb311fe6faee97")

authority.r2.bindings.schema = "mutated"
authority.inputs["mods/MAPGEN/grug_mapgen/wp40/height.lua"] = "mutated"
local second = offline.preflight()
assert(offline.sha256_call_count() == after,
	"cached authority preflight unexpectedly rehashed inputs")
assert(second.r2.bindings.schema == common.R2_ARTIFACT_SCHEMA)
assert(second.inputs["mods/MAPGEN/grug_mapgen/wp40/height.lua"] ==
	"f69fcd006af40f2f473d592c412508c3d7043403b15c07bfedcb311fe6faee97")
assert(not pcall(offline.load_foundation, "0", 1, true))
assert(not pcall(offline.load_foundation, "0", 1, {unknown = true}))

print("WP40 simple-map R4 tooling selftest passed")
