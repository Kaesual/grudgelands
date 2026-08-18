-- WP40 T2 collected-correction reproduction driver (contracts section 8.4):
-- solo compiles of the named witness seeds through the full compile path --
-- partition.compile, never the census projection -- printing one canonical
-- line per seed: the compiled-graph SHA-256 and every resolved Bay-edge
-- transition terminal with its world point and previous station.  The
-- interpreter split (contracts 8.6.2) byte-compares this output between
-- LuaJIT and PUC 5.1 for the gate-1.5 witness pair.
--
-- The expected diff against the pre-correction record is stated in advance
-- by plan 7.3: terminals move by one to three stations exactly at the
-- interior-completer sites; a formerly stage-rejected D2 seed compiles for
-- the first time.  A deviation in either direction stops the package for a
-- recorded Reality correction (contracts 8.4).
local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-census%.[A-Za-z0-9]+$"),
	"unsafe scratch path")
assert(arg[3], "at least one witness seed required")

local hasher = dofile(repo .. "/tools/wp40/t2_census_hasher.lua")({
	repo = repo, scratch = scratch})
local raw_sha256 = hasher.raw_sha256

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
local partition = dofile(wp40 .. "/geometry/partition.lua")({
	canonical = canonical, deterministic = deterministic, exact = exact,
	new_boundary = new_boundary, raster = raster, raw_sha256 = raw_sha256,
	source = source, source_validator = source_validator,
	vocabulary = vocabulary})

-- The canonical plain encoding of t2_extreme_test.lua, kept byte-compatible
-- so compiled-graph digests are comparable across the two harnesses.
local function plain_bytes(value, seen)
	local kind = type(value)
	if kind == "string" then return "s" .. #value .. ":" .. value end
	if kind == "number" then
		assert(value % 1 == 0)
		return "n" .. tostring(value) .. ";"
	end
	if kind == "boolean" then return value and "b1" or "b0" end
	if kind == "nil" then return "z" end
	assert(kind == "table" and getmetatable(value) == nil)
	seen = seen or {}
	assert(not seen[value], "compiled graph contains alias/cycle")
	seen[value] = true
	local count, array = 0, true
	for key in pairs(value) do
		count = count + 1
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
			array = false
		end
	end
	if array and count == #value then
		local parts = {"a", tostring(count), ":"}
		for index = 1, count do
			parts[#parts + 1] = plain_bytes(value[index], seen)
		end
		seen[value] = nil
		return table.concat(parts)
	end
	local keys = {}
	for key in pairs(value) do
		assert(type(key) == "string")
		keys[#keys + 1] = key
	end
	table.sort(keys)
	local parts = {"m", tostring(#keys), ":"}
	for index = 1, #keys do
		parts[#parts + 1] = plain_bytes(keys[index], seen)
		parts[#parts + 1] = plain_bytes(value[keys[index]], seen)
	end
	seen[value] = nil
	return table.concat(parts)
end

local function named_rows(record, field, name)
	local rows = record[field]
	if type(rows) ~= "table" then return nil end
	for index = 1, #rows do
		if rows[index].name == name then return rows[index].values end
	end
	return nil
end

local function terminal_lines(compiled, lines)
	-- Every resolved Bay-edge transition terminal in the compiled graph, in
	-- record order: the compiled land-boundary rows carry them as the
	-- bank_transition_* named arrays.
	local edges = compiled.families and compiled.families.land_boundaries
	if type(edges) ~= "table" then return end
	for index = 1, #edges do
		local edge = edges[index]
		local ids = named_rows(edge, "text_arrays", "bank_transition_ids")
		local positions = named_rows(edge, "signed_arrays",
			"bank_transition_xz")
		if ids and positions then
			for terminal = 1, #ids do
				lines[#lines + 1] = "  terminal " .. tostring(ids[terminal]) ..
					" point " .. tostring(positions[terminal * 2 - 1]) .. ":" ..
					tostring(positions[terminal * 2])
			end
		end
	end
end

local failures = 0
for index = 3, #arg do
	local seed = arg[index]
	local ok, compiled = pcall(partition.compile, seed)
	if ok then
		local digest = canonical.hex(raw_sha256(plain_bytes(compiled)))
		print("repro seed " .. seed .. " compiled " .. digest)
		local lines = {}
		terminal_lines(compiled, lines)
		for line_index = 1, #lines do print(lines[line_index]) end
	else
		failures = failures + 1
		print("repro seed " .. seed .. " FAILED " ..
			(tostring(compiled):gsub("[\t\n]", " ")))
	end
end
if failures > 0 then
	error("correction reproduction: " .. failures .. " witness compiles failed", 0)
end
print("correction reproduction complete")
