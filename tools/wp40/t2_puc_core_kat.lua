-- WP40 T2 Pinned PUC Conformance Core (PCC) semantic micro-corpus.
--
-- This test deliberately prints interpreter-neutral canonical rows.  The
-- runner executes it under LuaJIT and vendored PUC 5.1, compares stdout and
-- exit status, and then compares the bytes with the committed fixture.  The
-- expensive compiler, worker and merge carriers live in the same runner but
-- remain separate: this file is the bounded five-group semantic layer, not a
-- substitute for a full-path witness.
local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local mode = arg[3] or "micro"
assert(arg[4] == nil and (mode == "micro" or mode == "source"),
	"usage: t2_puc_core_kat.lua REPO SCRATCH [micro or source]")
assert(type(repo) == "string" and repo:match("^/[A-Za-z0-9._/-]+$") and
	type(scratch) == "string" and
	scratch:match("^/tmp/grudgelands%-wp40%-t2%-census%.[A-Za-z0-9]+$") and
	not repo:find("/../", 1, true) and not scratch:find("/../", 1, true),
	"unsafe PCC path")

local hasher = dofile(repo .. "/tools/wp40/t2_census_hasher.lua")({
	repo = repo, scratch = scratch})
local raw_sha256 = hasher.raw_sha256
local function hex(bytes)
	return (bytes:gsub(".", function(byte)
		return ("%02x"):format(string.byte(byte))
	end))
end
local function digest(text)
	return hex(raw_sha256(text))
end
local function expect_error(fragment, callback)
	local ok, message = pcall(callback)
	assert(not ok and tostring(message):find(fragment, 1, true), tostring(message))
end
local function read_file(path)
	local file = assert(io.open(path, "rb"))
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local canonical = dofile(wp40 .. "/canonical.lua")
local corpus = dofile(wp40 .. "/seed_corpus.lua")

if mode == "source" then
	local source = dofile(wp40 .. "/source/catalog.lua")
	local validator = dofile(wp40 .. "/validation/t2_source.lua")
	local projected = validator.canonicalize_source(source, canonical)
	local actual = canonical.hex(canonical.checksum(projected, raw_sha256))
	assert(actual == validator.EXPECTED_SOURCE_CHECKSUM,
		"PCC targeted Source checksum changed")
	local projected_bytes = canonical.encode(projected)
	print("pcc_source_v1")
	print("source_checksum\t" .. actual)
	print("source_bytes_sha256\t" .. digest(projected_bytes))
	print("boundary_policy_checksum\t" ..
		validator.EXPECTED_BOUNDARY_DISPLACEMENT_CHECKSUM)
	print("world_partition_checksum\t" ..
		validator.EXPECTED_WORLD_PARTITION_CHECKSUM)
	hasher.close()
	return
end

-- Group A: arithmetic, the complete 27-seed ladder and seed-width extremes.
assert(corpus.verify(raw_sha256))
local seed_lines = {}
for index = 1, #corpus.fixed do
	seed_lines[index] = tostring(index) .. "\t" .. corpus.fixed[index]
end
local seed_blob = table.concat(seed_lines, "\n") .. "\n"
assert(#corpus.fixed == 27)
assert(corpus.fixed[16] == "9007199254740991" and
	corpus.fixed[17] == "9007199254740992" and
	corpus.fixed[18] == "9007199254740993" and
	corpus.fixed[19] == "18446744073709551615")
local candidate_zero = corpus.extreme_candidate(0, raw_sha256)
local candidate_last = corpus.extreme_candidate(4095, raw_sha256)
expect_error("candidate index", function()
	corpus.extreme_candidate(-1, raw_sha256)
end)
expect_error("candidate index", function()
	corpus.extreme_candidate(4096, raw_sha256)
end)

-- Group B: canonical formatting, map-order independence and negative
-- serialization paths.  The worker and merge legs extend this group to real
-- census-record and five-artifact rendering.
local left = canonical.map({
	{canonical.text("z"), canonical.unsigned(4294967295)},
	{canonical.text("a"), canonical.signed(-2147483648)},
	{canonical.text("array"), canonical.array({
		canonical.bytes(string.char(0, 255)), canonical.boolean(true)})},
})
local right = canonical.map({
	{canonical.text("array"), canonical.array({
		canonical.bytes(string.char(0, 255)), canonical.boolean(true)})},
	{canonical.text("a"), canonical.signed(-2147483648)},
	{canonical.text("z"), canonical.unsigned(4294967295)},
})
local canonical_blob = canonical.encode(left)
assert(canonical_blob == canonical.encode(right))
expect_error("duplicate encoded map key", function()
	canonical.encode(canonical.map({
		{canonical.text("same"), canonical.unsigned(1)},
		{canonical.text("same"), canonical.unsigned(2)},
	}))
end)
expect_error("outside its integer range", function()
	canonical.encode(canonical.unsigned(4294967296))
end)

-- Group C is carried by the real merge leg.  The micro-corpus binds its input
-- roster and the fact that all three halves are mandatory, so the fixture
-- changes if the selection rule changes even before the merge is launched.
local merge_seeds = {
	"0", "2147483648", "343674299183575008", "1959553668008863006",
	"15219119262482319357", "16178445837170081103",
	"18446744073709551615",
}
local merge_blob = table.concat(merge_seeds, "\n") .. "\n"

-- Group D: boundary guards already owned by the extreme and census
-- authorities.  Their full-path shell guards remain in run_t2_extreme.sh;
-- these direct calls make the cheap index/range/GO failures executable here.
local extreme_authority = dofile(repo ..
	"/tools/wp40/t2_extreme_authority.lua")({raw_sha256 = raw_sha256})
assert(extreme_authority.validate_measurement_ranges(
	extreme_authority.canonical_measurement_ranges()))
local bad_ranges = extreme_authority.canonical_measurement_ranges()
bad_ranges[8].last = 4094
expect_error("measurement range partition changed", function()
	extreme_authority.validate_measurement_ranges(bad_ranges)
end)
local census_authority = dofile(repo ..
	"/tools/wp40/t2_census_authority.lua")({raw_sha256 = raw_sha256})
local fake_w_digest = string.rep("0", 64)
assert(census_authority.check_go_token(nil, fake_w_digest, 64))
expect_error("needs the explicit GO token", function()
	census_authority.check_go_token(nil, fake_w_digest, 65)
end)
expect_error("not one of the 8 canonical shard ranges", function()
	census_authority.validate_shard_range(0, 1, 4123)
end)

-- Group E: the three silent escapes are constructed at runtime so the source
-- itself remains legal under sweep 2.  Each interpreter validates its own
-- observed length against both documented outcomes, then prints normalized
-- bytes.  Independent dual-runtime legs compare stdout and exit status; the
-- dependency-coupled merge requires both successful exits and artifact identity.
local slash = string.char(92)
local escape_rows = {
	{name = "x41", source = slash .. "x41", luajit = 1, puc = 3},
	{name = "u41", source = slash .. "u{41}", luajit = 1, puc = 5},
	{name = "zspace", source = "a" .. slash .. "z  b", luajit = 2, puc = 5},
}
for index = 1, #escape_rows do
	local row = escape_rows[index]
	local chunk = assert(loadstring("return \"" .. row.source .. "\""))
	local observed = #chunk()
	local expected = rawget(_G, "jit") and row.luajit or row.puc
	assert(observed == expected, row.name .. " silent-escape semantics changed")
end

print("pcc_micro_v1")
print("group_a_seed_count\t" .. #corpus.fixed)
print("group_a_seed_ladder_sha256\t" .. digest(seed_blob))
print("group_a_candidate_0\t" .. candidate_zero.decimal)
print("group_a_candidate_4095\t" .. candidate_last.decimal)
print("group_b_canonical_sha256\t" .. digest(canonical_blob))
print("group_c_merge_seed_count\t" .. #merge_seeds)
print("group_c_merge_seed_sha256\t" .. digest(merge_blob))
print("group_c_required_halves\tpairs_probe,synthetic_invariance,measured_invariance")
print("group_d_guards\tindex,measurement_range,go_64,shard_cover")
for index = 1, #escape_rows do
	local row = escape_rows[index]
	print("group_e_" .. row.name .. "\tluajit=" .. row.luajit ..
		"\tpuc=" .. row.puc)
end
print("pcc_micro_passed")
hasher.close()
