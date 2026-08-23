-- Focused WP40 T2 Bay-v3/dry-face-v2 ownership-handoff package.
-- Full mode performs exactly the two pinned LuaJIT witness compiles. Fixture
-- mode is the representative PUC-5.1 KAT: it exercises the same exported
-- validators and verifies the retained full-run bytes without compiling a
-- world under the slow fallback interpreter.

local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local mode = assert(arg[3], "test mode required")
local capture_path = arg[4]
assert((mode == "full" or mode == "fixture") and arg[5] == nil,
	"unsupported handoff test mode")
assert(mode == "full" or capture_path == nil,
	"fixture mode accepts no capture path")

local fixture_path = repo ..
	"/tools/wp40/fixtures/t2_bay_v3_handoff/handoff-v1.tsv"
local adoption_ledger_path = repo ..
	"/tools/wp40/fixtures/t2_census/s11-adoption-ledger-v1.txt"
local connectivity_seed = "35408571026545897"
local adoption_seed = "18171940200422843206"
local adoption_line = "ADOPTION seed=18171940200422843206 chains=1 " ..
	"columns=1 rejected=0 " ..
	"zone_face:kragmar_sunscar_flats/1[z=2252:x=877..877]"

local hasher = dofile(repo .. "/tools/wp40/t2_census_hasher.lua")({
	repo = repo, scratch = scratch})
local raw_sha256 = hasher.raw_sha256
local function hex(bytes)
	return (bytes:gsub(".", function(byte)
		return ("%02x"):format(string.byte(byte))
	end))
end

local function read_file(path)
	local file = assert(io.open(path, "rb"), "cannot read " .. path)
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end

local function write_file(path, bytes)
	local file = assert(io.open(path, "wb"), "cannot write " .. path)
	assert(file:write(bytes))
	assert(file:close())
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
local vocabulary = dofile(repo ..
	"/tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua")
local new_boundary = dofile(wp40 .. "/geometry/boundary.lua")
local compiler = dofile(wp40 .. "/geometry/partition.lua")({
	canonical = canonical, deterministic = deterministic, exact = exact,
	new_boundary = new_boundary, raster = raster, raw_sha256 = raw_sha256,
	source = source, source_validator = source_validator,
	vocabulary = vocabulary})

local function deep_copy(value, active)
	if type(value) ~= "table" then return value end
	assert(getmetatable(value) == nil, "test value has a metatable")
	active = active or {}
	assert(not active[value], "test value contains a cycle")
	active[value] = true
	local result = {}
	for key, child in pairs(value) do
		result[deep_copy(key, active)] = deep_copy(child, active)
	end
	active[value] = nil
	return result
end

local function stable(value, active)
	local kind = type(value)
	if kind == "nil" then return "n" end
	if kind == "boolean" then return value and "b1" or "b0" end
	if kind == "number" then
		assert(value == value and value ~= math.huge and value ~= -math.huge and
			value % 1 == 0, "non-integer test value")
		return "i" .. (value == 0 and "0" or tostring(value)) .. ";"
	end
	if kind == "string" then return "s" .. #value .. ":" .. value end
	assert(kind == "table" and getmetatable(value) == nil,
		"non-plain test value")
	active = active or {}
	assert(not active[value], "cyclic test value")
	active[value] = true
	local keys = {}
	for key in pairs(value) do
		assert(type(key) == "number" or type(key) == "string",
			"unsupported test key")
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		if type(a) ~= type(b) then return type(a) < type(b) end
		return a < b
	end)
	local parts = {"t", tostring(#keys), ":"}
	for index = 1, #keys do
		local key = keys[index]
		parts[#parts + 1] = stable(key, active)
		parts[#parts + 1] = stable(value[key], active)
	end
	active[value] = nil
	return table.concat(parts)
end

local function digest(value)
	return hex(raw_sha256(stable(value)))
end

local function expect_error(fragment, callback)
	local ok, message = pcall(callback)
	assert(not ok, "expected error containing " .. fragment)
	assert(tostring(message):find(fragment, 1, true), tostring(message))
end

local function named_row(record, field, name)
	for index = 1, #record[field] do
		if record[field][index].name == name then return record[field][index] end
	end
	error(record.id .. " lacks " .. name)
end

local function scalar(record, field, name)
	return named_row(record, field, name).value
end

local function array(record, field, name)
	return named_row(record, field, name).values
end

local function by_id(rows, id)
	for index = 1, #rows do if rows[index].id == id then return rows[index] end end
	error("missing record " .. id)
end

local function remove_named(rows, name)
	for index = 1, #rows do
		if rows[index].name == name then
			table.remove(rows, index)
			return
		end
	end
	error("missing removable field " .. name)
end

local function legacy_projection(families)
	local legacy = deep_copy(families)
	for index = 1, #legacy.bays do
		local bay = legacy.bays[index]
		bay.record_schema = "grug_wp40_bay_v2"
		remove_named(bay.unsigned_values, "connectivity_fill_count")
		remove_named(bay.signed_arrays, "connectivity_fill_xz")
	end
	for index = 1, #legacy.dry_faces do
		local face = legacy.dry_faces[index]
		face.record_schema = "grug_wp40_dry_face_v1"
		remove_named(face.unsigned_values, "adopted_residue_interval_count")
		remove_named(face.signed_arrays, "adopted_residue_z_first_finish")
	end
	return legacy
end

local function minimal_bay(values, count)
	return {record_schema = "grug_wp40_bay_v3", id = "bay_kat",
		unsigned_values = {{name = "connectivity_fill_count", value = count}},
		signed_arrays = {{name = "connectivity_fill_xz", values = values}}}
end

local function minimal_face(id, values, count)
	return {record_schema = "grug_wp40_dry_face_v2", id = id,
		unsigned_values = {{name = "adopted_residue_interval_count", value = count}},
		signed_arrays = {{name = "adopted_residue_z_first_finish", values = values}}}
end

local function adoption_authority(face_id, members)
	return {adopted = {{face_id = face_id, members = members}}, rejected = {}}
end

local function run_validator_kats()
	local bay_authority = {{x = 7, z = -2}, {x = -3, z = 9}}
	local bay = minimal_bay({-3, 9, 7, -2}, 2)
	assert(compiler.validate_bay_connectivity_handoff(bay, bay_authority))
	assert(bay_authority[1].x == 7 and bay.signed_arrays[1].values[1] == -3,
		"Bay handoff aliases or mutates its authority")
	expect_error("count changed", function()
		compiler.validate_bay_connectivity_handoff(
			minimal_bay({-3, 9, 7, -2}, 1), bay_authority)
	end)
	expect_error("not sorted", function()
		compiler.validate_bay_connectivity_handoff(
			minimal_bay({7, -2, -3, 9}, 2), bay_authority)
	end)
	expect_error("duplicate", function()
		compiler.validate_bay_connectivity_handoff(
			minimal_bay({-3, 9, -3, 9}, 2), bay_authority)
	end)
	expect_error("does not match authority", function()
		compiler.validate_bay_connectivity_handoff(bay, {{x = -3, z = 9}})
	end)

	local members = {{z = 4, first = 8, finish = 9},
		{z = 3, first = 10, finish = 10}}
	local adoption = adoption_authority("face_a", members)
	local face = minimal_face("face_a", {3, 10, 10, 4, 8, 9}, 2)
	assert(compiler.validate_dry_face_adoption_handoff(face, adoption))
	assert(members[1].z == 4 and face.signed_arrays[1].values[1] == 3,
		"dry-face handoff aliases or mutates its authority")
	expect_error("count changed", function()
		compiler.validate_dry_face_adoption_handoff(
			minimal_face("face_a", {3, 10, 10, 4, 8, 9}, 1), adoption)
	end)
	expect_error("not sorted", function()
		compiler.validate_dry_face_adoption_handoff(
			minimal_face("face_a", {4, 8, 9, 3, 10, 10}, 2), adoption)
	end)
	expect_error("duplicate", function()
		compiler.validate_dry_face_adoption_handoff(
			minimal_face("face_a", {3, 10, 10, 3, 10, 10}, 2), adoption)
	end)
	expect_error("do not match authority", function()
		compiler.validate_dry_face_adoption_handoff(face,
			adoption_authority("face_b", members))
	end)
	expect_error("overlaps within a row", function()
		compiler.validate_dry_face_adoption_handoff(
			minimal_face("face_a", {3, 10, 12, 3, 12, 13}, 2),
			adoption_authority("face_a", {{z = 3, first = 10, finish = 12},
				{z = 3, first = 12, finish = 13}}))
	end)
	expect_error("reversed", function()
		compiler.validate_dry_face_adoption_handoff(
			minimal_face("face_a", {3, 12, 10}, 1),
			adoption_authority("face_a", {{z = 3, first = 12, finish = 10}}))
	end)
	expect_error("rejected residue", function()
		compiler.validate_dry_face_adoption_handoff(
			minimal_face("face_a", {}, 0), {adopted = {}, rejected = {{}}})
	end)
end

local ledger = read_file(adoption_ledger_path)
assert(ledger:find(adoption_line .. "\n", 1, true),
	"pinned section-11 adoption witness changed")
run_validator_kats()

if mode == "fixture" then
	local fixture = read_file(fixture_path)
	assert(fixture:match("^schema\tgrug_wp40_bay_v3_handoff_fixture_v1\n"),
		"handoff fixture schema changed")
	assert(fixture:find("witness\tconnectivity\t" .. connectivity_seed ..
		"\twhole_gap_reject\n", 1, true),
		"connectivity witness fixture changed")
	assert(fixture:find("witness\tadoption\t" .. adoption_seed ..
		"\tzone_face:kragmar_sunscar_flats\t2252\t877\t877\n", 1, true),
		"adoption witness fixture changed")
	local lines, seen = 0, {}
	for line in fixture:gmatch("([^\n]+)\n") do
		lines = lines + 1
		assert(not seen[line], "handoff fixture contains a duplicate line")
		seen[line] = true
	end
	assert(lines > 30 and lines < 300, "handoff fixture case budget changed")
	local interpreter = rawget(_G, "jit") and "LuaJIT" or "PUC-5.1"
	print("WP40 T2 Bay-v3 handoff fixture KAT passed interpreter=" .. interpreter ..
		" fixture_sha256=" .. hex(raw_sha256(fixture)) .. " cases=" .. lines)
	hasher.close()
	return
end

assert(rawget(_G, "jit") ~= nil,
	"full ownership-handoff witnesses must run under LuaJIT")
local lines = {"schema\tgrug_wp40_bay_v3_handoff_fixture_v1",
	"witness\tconnectivity\t" .. connectivity_seed .. "\twhole_gap_reject",
	"witness\tadoption\t" .. adoption_seed ..
		"\tzone_face:kragmar_sunscar_flats\t2252\t877\t877"}
local unchanged_families = {"land_boundaries", "perimeters",
	"mouth_apertures", "closure_wings", "coast_shelf", "islands", "channels"}

local function append_payload_evidence(seed, compiled)
	local legacy = legacy_projection(compiled.families)
	for index = 1, #unchanged_families do
		local name = unchanged_families[index]
		assert(digest(compiled.families[name]) == digest(legacy[name]))
		lines[#lines + 1] = table.concat({"legacy_digest", seed, name,
			digest(legacy[name])}, "\t")
	end
	lines[#lines + 1] = table.concat({"legacy_digest", seed, "bays",
		digest(legacy.bays)}, "\t")
	lines[#lines + 1] = table.concat({"legacy_digest", seed, "dry_faces",
		digest(legacy.dry_faces)}, "\t")
	lines[#lines + 1] = table.concat({"legacy_digest", seed, "partition",
		digest(legacy)}, "\t")
	lines[#lines + 1] = table.concat({"new_digest", seed, "bays",
		digest(compiled.families.bays)}, "\t")
	lines[#lines + 1] = table.concat({"new_digest", seed, "dry_faces",
		digest(compiled.families.dry_faces)}, "\t")
	lines[#lines + 1] = table.concat({"new_digest", seed, "partition",
		digest(compiled.families)}, "\t")
end

local started = os.time()
local connectivity = compiler.compile(connectivity_seed)
local connectivity_seconds = os.time() - started
local connectivity_total = 0
for index = 1, #connectivity.families.bays do
	local bay = connectivity.families.bays[index]
	compiler.validate_bay_payload(bay)
	local count = scalar(bay, "unsigned_values", "connectivity_fill_count")
	local values = array(bay, "signed_arrays", "connectivity_fill_xz")
	assert(#values == count * 2)
	connectivity_total = connectivity_total + count
	local line = table.concat({"connectivity", bay.id, tostring(count)}, "\t")
	if #values > 0 then line = line .. "\t" .. table.concat(values, ",") end
	lines[#lines + 1] = line
end
assert(connectivity_total > 0,
	"connectivity witness has zero closing columns; seed search is forbidden")
append_payload_evidence(connectivity_seed, connectivity)
print(("WP40 T2 Bay-v3 connectivity witness seed=%s columns=%d wall=%ds"):format(
	connectivity_seed, connectivity_total, connectivity_seconds))
connectivity = nil
collectgarbage("collect")
hasher.forget()

started = os.time()
local adoption = compiler.compile(adoption_seed)
local adoption_seconds = os.time() - started
local adoption_total, adoption_faces = 0, 0
for index = 1, #adoption.families.dry_faces do
	local face = adoption.families.dry_faces[index]
	local count = scalar(face, "unsigned_values",
		"adopted_residue_interval_count")
	local values = array(face, "signed_arrays",
		"adopted_residue_z_first_finish")
	assert(#values == count * 3)
	if count > 0 then adoption_faces = adoption_faces + 1 end
	adoption_total = adoption_total + count
	local line = table.concat({"adoption", face.id, tostring(count)}, "\t")
	if #values > 0 then line = line .. "\t" .. table.concat(values, ",") end
	lines[#lines + 1] = line
end
assert(adoption_total == 1 and adoption_faces == 1,
	"pinned adoption witness is not exactly one interval on one face")
local adopted_face = by_id(adoption.families.dry_faces,
	"zone_face:kragmar_sunscar_flats")
assert(scalar(adopted_face, "unsigned_values",
	"adopted_residue_interval_count") == 1)
local adopted_values = array(adopted_face, "signed_arrays",
	"adopted_residue_z_first_finish")
assert(#adopted_values == 3 and adopted_values[1] == 2252 and
	adopted_values[2] == 877 and adopted_values[3] == 877,
	"pinned adoption interval changed")
append_payload_evidence(adoption_seed, adoption)
print(("WP40 T2 dry-face-v2 adoption witness seed=%s intervals=%d wall=%ds"):format(
	adoption_seed, adoption_total, adoption_seconds))

table.sort(lines, function(a, b)
	if a:match("^schema\t") then return not b:match("^schema\t") end
	if b:match("^schema\t") then return false end
	return a < b
end)
local blob = table.concat(lines, "\n") .. "\n"
if capture_path then
	write_file(capture_path, blob)
else
	assert(blob == read_file(fixture_path), "handoff fixture bytes changed")
end
print("WP40 T2 Bay-v3 ownership handoff passed cases=" .. #lines ..
	" fixture_sha256=" .. hex(raw_sha256(blob)) .. " total_wall=" ..
	tostring(connectivity_seconds + adoption_seconds) .. "s")
hasher.close()
