-- Proves the stage-S1 scope claim that the E0 pool pin now rests on:
--
--   1. the published S1 Source projection is frozen (known-answer),
--   2. Source records that S1 does not read cannot move it -- and, stronger,
--      cannot move the selector's own scalar records either,
--   3. every S1 input does move it,
--   4. the S1 authority digest covers the S1 module plus its arithmetic
--      surface and nothing from partition.lua, catalog.lua or t2_source.lua.

local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(scratch:match("^/tmp/grudgelands%-wp40%-s1%-authority%.[A-Za-z0-9]+$"),
	"unsafe scratch path")

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local sha_cache, sha_counter = {}, 0
local function from_hex(value)
	return (value:gsub("..", function(pair)
		return string.char(assert(tonumber(pair, 16)))
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

local function read_file(path)
	local file = assert(io.open(path, "rb"))
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end

local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local exact = dofile(wp40 .. "/geometry/exact.lua")({deterministic = deterministic})
local raster = dofile(wp40 .. "/geometry/raster.lua")({canonical = canonical,
	deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256})
local source = dofile(wp40 .. "/source/catalog.lua")
local vocabulary = dofile(repo ..
	"/tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua")
local new_boundary = dofile(wp40 .. "/geometry/boundary.lua")
local s1_authority = dofile(repo .. "/tools/wp40/t2_s1_authority.lua")({
	raw_sha256 = raw_sha256})

-- The projection is a pure function of Source, so every mutated instance runs
-- with an accepting validator: the point is precisely to read a Source the
-- frozen Stage-1 checksum would reject.
local function make(source_value)
	return new_boundary({canonical = canonical, deterministic = deterministic,
		exact = exact, raster = raster, raw_sha256 = raw_sha256,
		source = source_value,
		source_validator = {validate = function() return true end},
		vocabulary = vocabulary})
end

local function copy_value(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local result = {}
	seen[value] = result
	for key, child in pairs(value) do
		result[copy_value(key, seen)] = copy_value(child, seen)
	end
	return result
end

local function plain(value)
	if type(value) ~= "table" then return string.format("%q", tostring(value)) end
	local numeric, text = {}, {}
	for key in pairs(value) do
		if type(key) == "number" then numeric[#numeric + 1] = key
		else text[#text + 1] = tostring(key) end
	end
	table.sort(numeric) table.sort(text)
	local parts = {"{"}
	for index = 1, #numeric do
		parts[#parts + 1] = "[" .. numeric[index] .. "]=" ..
			plain(value[numeric[index]]) .. ","
	end
	for index = 1, #text do
		parts[#parts + 1] = "[" .. string.format("%q", text[index]) .. "]=" ..
			plain(value[text[index]]) .. ","
	end
	parts[#parts + 1] = "}"
	return table.concat(parts)
end

local base = make(source)
local base_projection = base.s1_source_checksum()

-- Known answer.  A change here is a real S1 Source change and must invalidate
-- the measured pool; nothing else may.
local EXPECTED_S1_SOURCE_PROJECTION =
	"83b1b16a8afd11af654b5dd3e1d9921006848a0903e7b0c01ab39b27edddd652"
assert(base_projection == EXPECTED_S1_SOURCE_PROJECTION,
	"S1 Source projection checksum drift: " .. base_projection)
assert(base.PROJECTION_SCHEMA == "grug_wp40_s1_boundary_projection_v1",
	"S1 projection schema changed")

local function projection_of(mutate)
	local mutated = copy_value(source)
	mutate(mutated)
	return make(mutated).s1_source_checksum()
end

local function unchanged(label, mutate)
	assert(projection_of(mutate) == base_projection,
		"non-S1 Source change moved the S1 projection: " .. label)
end

local function changed(label, mutate)
	assert(projection_of(mutate) ~= base_projection,
		"S1 Source change did not move the S1 projection: " .. label)
end

-- (2) Records S1 does not read.  These are exactly the later-stage rosters and
-- policies that R11..R19 edited inside source/catalog.lua.
unchanged("a brand-new unrelated record kind", function(s)
	s.wp40_unrelated_probe_records = {{id = "probe_0", value = 1},
		{id = "probe_1", value = 2}}
end)
unchanged("an appended bay edge transition", function(s)
	s.bay_edge_transitions[#s.bay_edge_transitions + 1] =
		copy_value(s.bay_edge_transitions[1])
end)
unchanged("an appended Bay Bank component", function(s)
	s.bay_bank_components[#s.bay_bank_components + 1] =
		copy_value(s.bay_bank_components[1])
end)
unchanged("an appended perimeter span", function(s)
	s.perimeter_spans[#s.perimeter_spans + 1] = copy_value(s.perimeter_spans[1])
end)
unchanged("an appended perimeter attachment", function(s)
	s.perimeter_attachments[#s.perimeter_attachments + 1] =
		copy_value(s.perimeter_attachments[1])
end)
unchanged("an appended zone face", function(s)
	s.zone_faces[#s.zone_faces + 1] = copy_value(s.zone_faces[1])
end)
unchanged("an appended bay mouth aperture", function(s)
	s.bay_mouth_apertures[#s.bay_mouth_apertures + 1] =
		copy_value(s.bay_mouth_apertures[1])
end)
unchanged("an appended closure wing", function(s)
	s.bay_closure_wings[#s.bay_closure_wings + 1] =
		copy_value(s.bay_closure_wings[1])
end)
unchanged("a rewritten world-partition policy string", function(s)
	s.geometry_policies.world_partition.bay_notch_fill_policy_id =
		"single_pass_same_bay_raw_mask_degree_one_notch_v2"
end)
unchanged("a rewritten relief-field policy", function(s)
	s.geometry_policies.relief_field.id = "relief_probe_v9"
end)
unchanged("a renumbered zone", function(s)
	s.zones[1].numeric_id = s.zones[1].numeric_id + 1000
end)
unchanged("an appended relief junction", function(s)
	s.relief_junctions[#s.relief_junctions + 1] = copy_value(s.relief_junctions[1])
end)
unchanged("an appended landmark", function(s)
	s.landmarks[#s.landmarks + 1] = copy_value(s.landmarks[1])
end)
unchanged("a nonfixed anchor at a fresh column", function(s)
	local probe = copy_value(s.anchors[1])
	probe.id = "anchor_probe_nonfixed"
	probe.placement_mode = "relaxed"
	probe.position = {x = 12345, z = -12345}
	s.anchors[#s.anchors + 1] = probe
end)

-- (3) Every S1 input.
changed("a moved land-edge control", function(s)
	s.land_edges[1].control[1].x = s.land_edges[1].control[1].x + 1
end)
changed("a moved perimeter polygon vertex", function(s)
	s.perimeters[1].polygon[1].z = s.perimeters[1].polygon[1].z + 1
end)
changed("a changed perimeter max displacement", function(s)
	s.perimeters[1].max_displacement = s.perimeters[1].max_displacement - 1
end)
changed("a changed land-edge noise domain", function(s)
	s.land_edges[1].noise_domain = s.land_edges[1].noise_domain .. "_probe"
end)
changed("a reordered perimeter roster", function(s)
	s.perimeters[1], s.perimeters[2] = s.perimeters[2], s.perimeters[1]
end)
changed("a changed island envelope radius", function(s)
	s.islands[1].envelope.radius_x = s.islands[1].envelope.radius_x + 1
end)
changed("a reversed fixed-closure reference", function(s)
	s.perimeters[1].r7_fixed_closure.edge_refs[1].direction = "forward"
end)
changed("a retargeted junction departure", function(s)
	s.junction_departures[1].edge_id = s.junction_departures[2].edge_id
	s.junction_departures[2].edge_id = "land_035"
end)
changed("a widened mainland frame", function(s)
	s.constants.mainland_frame.min_x = s.constants.mainland_frame.min_x - 1
end)
changed("an extra holy junction column", function(s)
	s.constants.holy_junction_x[#s.constants.holy_junction_x + 1] = 1234
end)
changed("a new fixed anchor column", function(s)
	local probe = copy_value(s.anchors[1])
	probe.id = "anchor_probe_fixed"
	probe.placement_mode = "fixed"
	probe.position = {x = 12345, z = -12345}
	s.anchors[#s.anchors + 1] = probe
end)
-- Authority prose is provenance, not input.  R16, R18 and R19 each rewrote the
-- boundary-displacement prose while leaving every S1 geometric input
-- bit-identical; binding it here would have re-invalidated the pool exactly
-- the way whole-file pins did.  The records keep their own frozen Stage-1
-- checksums, which the encoding below must reproduce bit for bit.
unchanged("a rewritten boundary-displacement policy string", function(s)
	s.geometry_policies.boundary_displacement.step_rule =
		s.geometry_policies.boundary_displacement.step_rule .. "_probe"
end)
unchanged("a rewritten route-raster policy string", function(s)
	s.geometry_policies.route_raster.major_axis_rule =
		s.geometry_policies.route_raster.major_axis_rule .. "_probe"
end)
unchanged("a rewritten extreme-selector policy string", function(s)
	s.geometry_policies.geometry_extreme_selector.score_rule =
		s.geometry_policies.geometry_extreme_selector.score_rule .. "_probe"
end)

local stage1_validator = dofile(wp40 .. "/validation/t2_source.lua")
local policies = base.s1_policy_checksums()
assert(policies.boundary_displacement ==
	stage1_validator.EXPECTED_BOUNDARY_DISPLACEMENT_CHECKSUM,
	"S1 policy provenance disagrees with the production Stage-1 checksum")
assert(policies.route_raster ==
	"2f8690642442c96345994bee6960408e4fe2f02cfd35eafdfc1b4ec7d4a6695c" and
	policies.geometry_extreme_selector ==
	"e40b7862436c27ffe97f4e81510a7e86b31a6d4c6772b2d68bf16bdfec070751",
	"S1 policy provenance drift")

-- (2, strengthened) The checksum claim is only worth what the scalars are.
-- Score the selector's own S1 records on a Source carrying every unrelated
-- mutation at once and require the bytes to be identical.
local unrelated = copy_value(source)
unrelated.wp40_unrelated_probe_records = {{id = "probe_0", value = 1}}
unrelated.bay_edge_transitions[#unrelated.bay_edge_transitions + 1] =
	copy_value(unrelated.bay_edge_transitions[1])
unrelated.bay_bank_components[#unrelated.bay_bank_components + 1] =
	copy_value(unrelated.bay_bank_components[1])
unrelated.zone_faces[#unrelated.zone_faces + 1] = copy_value(unrelated.zone_faces[1])
unrelated.geometry_policies.world_partition.bay_notch_fill_policy_id =
	"single_pass_same_bay_raw_mask_degree_one_notch_v2"
unrelated.geometry_policies.boundary_displacement.step_rule =
	unrelated.geometry_policies.boundary_displacement.step_rule .. "_probe"
unrelated.zones[1].numeric_id = unrelated.zones[1].numeric_id + 1000
assert(make(unrelated).s1_source_checksum() == base_projection,
	"combined non-S1 mutation moved the S1 projection")

local base_records = plain(base.extreme_scalar_records("0"))
local unrelated_records = plain(make(unrelated).extreme_scalar_records("0"))
assert(base_records == unrelated_records,
	"combined non-S1 mutation moved the selector scalar records")

-- The mirror-image control: one fixed anchor mid-way along the first mainland
-- coast segment is a new zero-jitter column, so it is inside S1's surface and
-- must move both the projection and the measured scalars.
local jittered = copy_value(source)
local coast_a = jittered.perimeters[1].polygon[1]
local coast_b = jittered.perimeters[1].polygon[2]
local probe_anchor = copy_value(jittered.anchors[1])
probe_anchor.id = "anchor_probe_fixed"
probe_anchor.placement_mode = "fixed"
probe_anchor.position = {x = math.floor((coast_a.x + coast_b.x) / 2),
	z = math.floor((coast_a.z + coast_b.z) / 2)}
jittered.anchors[#jittered.anchors + 1] = probe_anchor
assert(make(jittered).s1_source_checksum() ~= base_projection,
	"a new zero-jitter column did not move the S1 projection")
assert(plain(make(jittered).extreme_scalar_records("0")) ~= base_records,
	"a new zero-jitter column did not move the selector scalar records")

-- (4) Authority scope.
local files = {}
local pinned_paths = {s1_authority.module_path}
for index = 1, #s1_authority.arithmetic_paths do
	pinned_paths[#pinned_paths + 1] = s1_authority.arithmetic_paths[index]
end
for index = 1, #pinned_paths do
	files[pinned_paths[index]] = read_file(repo .. "/" .. pinned_paths[index])
end
local base_digest = s1_authority.digest(files, base_projection,
	base.PROJECTION_SCHEMA)
assert(s1_authority.verify(files, base_projection, base.PROJECTION_SCHEMA,
	base_digest))

for index = 1, #s1_authority.excluded_paths do
	local excluded = s1_authority.excluded_paths[index]
	for pinned_index = 1, #pinned_paths do
		assert(pinned_paths[pinned_index] ~= excluded,
			"S1 authority still pins " .. excluded)
	end
	assert(not s1_authority.blob(files, base_projection,
		base.PROJECTION_SCHEMA):find(excluded, 1, true),
		"S1 authority blob mentions " .. excluded)
end

for index = 1, #pinned_paths do
	local mutated = {}
	for path, bytes in pairs(files) do mutated[path] = bytes end
	mutated[pinned_paths[index]] = mutated[pinned_paths[index]] .. "\n-- probe\n"
	assert(s1_authority.digest(mutated, base_projection, base.PROJECTION_SCHEMA) ~=
		base_digest, "S1 authority ignored " .. pinned_paths[index])
end
assert(s1_authority.digest(files,
	"0000000000000000000000000000000000000000000000000000000000000000",
	base.PROJECTION_SCHEMA) ~= base_digest,
	"S1 authority ignored its Source projection")

print("WP40 T2 S1 authority passed: projection " .. base_projection ..
	" authority " .. base_digest .. " over " .. #pinned_paths ..
	" pinned files, " .. sha_counter .. " digests")
