-- WP40 T2 section-11 bay-transition acceptance checker (contracts 11.11).
--
-- The section-11 package landed as 931e857.  Its acceptance evidence is
-- untracked (it lives under tools/wp40/results/), so the acceptance ledger
-- itself is pinned here: the six canonical tables under
-- tools/wp40/fixtures/t2_census/ are byte-exact copies of that run's
-- artifacts, and this checker is the committed proof that a given artifact
-- set still IS that ledger.  It is the executable form of the 11.11 pins --
-- adoption 118 seeds / 119 chains, family-B evidence 105 stations -- which
-- supersede the 11.10 pins of 117/118 and 93 (both corrected on measurement,
-- inside ruled mechanics; see contracts 11.11 for the provenance).
--
-- Two independent layers, both fail-closed:
--
--   1. Byte equality artifact vs fixture.  The fixtures give byte truth --
--      no hashing, no external process, no network.
--   2. Structural pins RECOMPUTED FROM THE ARTIFACT BYTES, never from the
--      fixtures.  Layer 1 alone would only prove "the two files agree";
--      layer 2 states what the ledger must SAY, so a fixture and an artifact
--      that drifted together still fail.
--
-- ringcol is the one table compared on sorted content rather than raw bytes:
-- the family-A ring evidence is emitted in probe traversal order, which is
-- not canonical (the banked and the final capture hold the same 8 rows in
-- different order).  Row content, row count and duplicate-freedom are still
-- pinned exactly; only the line order is released.
--
-- Seeds are 64-bit and exceed the exact integer range of a Lua 5.1 number,
-- so every seed is handled as a STRING and never passed through tonumber.
--
-- Output is deterministic canonical bytes: fixed line order, no timestamps,
-- no floats, no table-iteration order anywhere in the output path.  Runs
-- identically under LuaJIT and under tools/bin/lua51.
--
--   lua t2_s11_acceptance_check.lua REPO [ARTIFACTS_DIR]
--
-- ARTIFACTS_DIR defaults to
-- REPO/tools/wp40/results/bay-transition-package-final-artifacts.
-- Exit 0 with a final line ACCEPTANCE GREEN, or exit 1 with FAILURES PRESENT.

local repo = assert(arg[1], "repository root required")
local artifacts_dir = arg[2] or
	(repo .. "/tools/wp40/results/bay-transition-package-final-artifacts")
local fixtures_dir = repo .. "/tools/wp40/fixtures/t2_census"

-- The 11.11 acceptance ledger, as data.  Every number below is a pin: none
-- of them may be relaxed to reach green.
local ADOPTION_LINES = 118
local ADOPTION_CHAINS = 119
local ADOPTION_NEW_SEED = "18171940200422843206"
local ADOPTION_NEW_LINE = "ADOPTION seed=18171940200422843206 chains=1 " ..
	"columns=1 rejected=0 " ..
	"zone_face:kragmar_sunscar_flats/1[z=2252:x=877..877]"
local BJOIN_ROWS = 105
local BJOIN_SEEDS = 60
local BJOIN_CLASS = "face_appendix_select"
local BJOIN_MAX_DISTANCE = 12
-- The corrected complete-population histogram (11.10's 93-row capture was an
-- incomplete diagnostics capture; the maximum 12 is unchanged, so the W := 12
-- ruling's substance is untouched).  Distances absent here must be absent in
-- the artifact too -- the check is set equality, not containment.
local BJOIN_HISTOGRAM = {
	{1, 15}, {2, 15}, {3, 3}, {4, 3}, {8, 7}, {9, 9}, {10, 25}, {11, 23},
	{12, 5}}
-- The five d=12 seeds of the 11.10 ruling, re-accepted under W = 12.
local BJOIN_D12_SEEDS = {
	"18171940200422843206", "4154650258832672681", "4733240883161403671",
	"501535562992590246", "7921513688806375529"}
local INHERIT_ROWS = 25
local INHERIT_COLUMNS = 7
local PINCH_ROWS = 21
local CARRIERS = 796
local CARRIERS_FLOOR = 792
local RINGCOL_ROWS = 8

-- key, artifact basename, fixture basename, comparison mode.
local TABLES = {
	{"adoption", "adoption-actual.txt", "s11-adoption-ledger-v1.txt", "bytes"},
	{"bjoin", "bjoin-actual.tsv", "s11-bjoin-complete-v1.tsv", "bytes"},
	{"inherit", "inherit-actual.tsv", "s11-inherit-v1.tsv", "bytes"},
	{"pinch", "pinch-actual.tsv", "s11-pinch-v1.tsv", "bytes"},
	{"carriers", "carriers.txt", "s11-carriers-v1.txt", "bytes"},
	{"ringcol", "ringcol-actual.tsv", "s11-ringcol-v1.tsv", "sorted"},
}

local failures = 0

local function report(ok, label, detail)
	if not ok then failures = failures + 1 end
	print(string.format("%s %s %s", ok and "PASS" or "FAIL", label,
		detail or ""))
end

local function read_file(path)
	local handle = io.open(path, "rb")
	if not handle then return nil end
	local bytes = handle:read("*a")
	handle:close()
	return bytes
end

-- Split on "\n" and drop the single trailing empty field a final newline
-- leaves behind.  A file without a trailing newline keeps its last line, and
-- an embedded blank line is kept as a line -- both would fail a row-count pin
-- rather than pass silently.
local function split_lines(bytes)
	local lines = {}
	for line in string.gmatch(bytes, "([^\n]*)\n?") do
		lines[#lines + 1] = line
	end
	if #lines > 0 and lines[#lines] == "" then
		lines[#lines] = nil
	end
	return lines
end

local function sorted_copy(lines)
	local copy = {}
	for index = 1, #lines do copy[index] = lines[index] end
	table.sort(copy)
	return copy
end

local function count_duplicates(lines)
	local seen, duplicates = {}, 0
	for index = 1, #lines do
		local line = lines[index]
		if seen[line] then duplicates = duplicates + 1 end
		seen[line] = true
	end
	return duplicates
end

-- Deterministic: the caller supplies the key order, never pairs().
local function distinct_count(keys)
	local seen, total = {}, 0
	for index = 1, #keys do
		if not seen[keys[index]] then
			seen[keys[index]] = true
			total = total + 1
		end
	end
	return total
end

-- ---------------------------------------------------------------- layer 1

local loaded = {}

local function check_table(entry)
	local key, artifact_name, fixture_name, mode = entry[1], entry[2],
		entry[3], entry[4]
	local artifact = read_file(artifacts_dir .. "/" .. artifact_name)
	local fixture = read_file(fixtures_dir .. "/" .. fixture_name)
	if not artifact then
		report(false, key .. "-artifact-readable", "missing " .. artifact_name)
		return
	end
	-- Parsed before the fixture check: a readable artifact still gets its
	-- structural pins recomputed when the fixture is missing, so the only
	-- failure reported is the accurate one (a missing fixture), not a
	-- misleading "artifact not loaded".
	loaded[key] = split_lines(artifact)
	if not fixture then
		report(false, key .. "-fixture-readable", "missing " .. fixture_name)
		return
	end
	if mode == "bytes" then
		report(artifact == fixture, key .. "-bytes",
			string.format("artifact-bytes=%d fixture-bytes=%d", #artifact,
				#fixture))
	else
		local artifact_sorted = table.concat(sorted_copy(loaded[key]), "\n")
		local fixture_sorted = table.concat(
			sorted_copy(split_lines(fixture)), "\n")
		report(artifact_sorted == fixture_sorted, key .. "-sorted-content",
			string.format("artifact-rows=%d fixture-rows=%d", #loaded[key],
				#split_lines(fixture)))
	end
end

-- ---------------------------------------------------------------- layer 2

local function check_adoption(lines)
	report(#lines == ADOPTION_LINES, "adoption-lines",
		string.format("lines=%d/%d", #lines, ADOPTION_LINES))
	local seeds, chains, malformed, rejected_nonzero = {}, 0, 0, 0
	local new_line_hits, new_seed_hits = 0, 0
	for index = 1, #lines do
		local line = lines[index]
		local seed = string.match(line, "^ADOPTION seed=(%d+) ")
		local chain_text = string.match(line, " chains=(%d+) ")
		local rejected = string.match(line, " rejected=(%d+) ")
		if not seed or not chain_text or not rejected then
			malformed = malformed + 1
		else
			seeds[#seeds + 1] = seed
			chains = chains + tonumber(chain_text)
			if rejected ~= "0" then
				rejected_nonzero = rejected_nonzero + 1
			end
			if seed == ADOPTION_NEW_SEED then
				new_seed_hits = new_seed_hits + 1
			end
		end
		if line == ADOPTION_NEW_LINE then
			new_line_hits = new_line_hits + 1
		end
	end
	report(malformed == 0, "adoption-grammar",
		string.format("malformed-lines=%d", malformed))
	report(distinct_count(seeds) == ADOPTION_LINES, "adoption-distinct-seeds",
		string.format("seeds=%d/%d", distinct_count(seeds), ADOPTION_LINES))
	report(chains == ADOPTION_CHAINS, "adoption-chain-sum",
		string.format("chains=%d/%d", chains, ADOPTION_CHAINS))
	report(rejected_nonzero == 0, "adoption-rejected-zero",
		string.format("rows-with-nonzero-rejected=%d", rejected_nonzero))
	-- The one corrected line of 11.11: the shore-attached 11.7-B chain of the
	-- first-measured d=12 seed, pinned verbatim (face and column included).
	report(new_line_hits == 1 and new_seed_hits == 1, "adoption-new-chain",
		string.format("exact-line=%d seed-rows=%d (seed=%s sunscar z=2252:x=877)",
			new_line_hits, new_seed_hits, ADOPTION_NEW_SEED))
end

local function check_bjoin(lines)
	report(#lines == BJOIN_ROWS, "bjoin-rows",
		string.format("rows=%d/%d", #lines, BJOIN_ROWS))
	report(count_duplicates(lines) == 0, "bjoin-no-duplicates",
		string.format("duplicate-rows=%d", count_duplicates(lines)))
	local seeds, malformed, wrong_class = {}, 0, 0
	local histogram, max_distance = {}, 0
	local d12_seeds = {}
	for index = 1, #lines do
		local line = lines[index]
		local seed = string.match(line, "^(%d+)\t")
		local distance_text = string.match(line, "\tnearest_join_distance=(%d+)\t")
		local class = string.match(line, "\tclass=([%w_]+)$")
		if not seed or not distance_text or not class then
			malformed = malformed + 1
		else
			seeds[#seeds + 1] = seed
			if class ~= BJOIN_CLASS then wrong_class = wrong_class + 1 end
			local distance = tonumber(distance_text)
			histogram[distance] = (histogram[distance] or 0) + 1
			if distance > max_distance then max_distance = distance end
			if distance == BJOIN_MAX_DISTANCE then
				d12_seeds[#d12_seeds + 1] = seed
			end
		end
	end
	report(malformed == 0, "bjoin-grammar",
		string.format("malformed-rows=%d", malformed))
	report(distinct_count(seeds) == BJOIN_SEEDS, "bjoin-distinct-seeds",
		string.format("seeds=%d/%d", distinct_count(seeds), BJOIN_SEEDS))
	report(wrong_class == 0, "bjoin-class-select",
		string.format("rows-not-%s=%d", BJOIN_CLASS, wrong_class))
	-- Set equality both ways: every pinned bucket present with its exact
	-- count, and no distance outside the pinned buckets.
	local histogram_ok, pinned_total = true, 0
	local rendered = {}
	for index = 1, #BJOIN_HISTOGRAM do
		local distance = BJOIN_HISTOGRAM[index][1]
		local want = BJOIN_HISTOGRAM[index][2]
		local got = histogram[distance] or 0
		pinned_total = pinned_total + got
		if got ~= want then histogram_ok = false end
		rendered[#rendered + 1] = string.format("%d=%d/%d", distance, got, want)
	end
	local unpinned = 0
	for index = 1, #lines do
		local distance_text = string.match(lines[index],
			"\tnearest_join_distance=(%d+)\t")
		if distance_text then
			local distance, pinned = tonumber(distance_text), false
			for entry = 1, #BJOIN_HISTOGRAM do
				if BJOIN_HISTOGRAM[entry][1] == distance then pinned = true end
			end
			if not pinned then unpinned = unpinned + 1 end
		end
	end
	report(histogram_ok and unpinned == 0 and pinned_total == BJOIN_ROWS,
		"bjoin-histogram",
		string.format("%s unpinned-rows=%d total=%d/%d",
			table.concat(rendered, " "), unpinned, pinned_total, BJOIN_ROWS))
	report(max_distance == BJOIN_MAX_DISTANCE, "bjoin-max-distance",
		string.format("max=%d/%d", max_distance, BJOIN_MAX_DISTANCE))
	-- The five re-accepted seeds, by identity: each must carry at least one
	-- d=12 row, and no sixth seed may appear at d=12.
	local present, missing = {}, {}
	for index = 1, #d12_seeds do present[d12_seeds[index]] = true end
	for index = 1, #BJOIN_D12_SEEDS do
		if not present[BJOIN_D12_SEEDS[index]] then
			missing[#missing + 1] = BJOIN_D12_SEEDS[index]
		end
	end
	report(#missing == 0 and distinct_count(d12_seeds) == #BJOIN_D12_SEEDS,
		"bjoin-d12-seeds",
		string.format("seeds=%d/%d missing=%s", distinct_count(d12_seeds),
			#BJOIN_D12_SEEDS,
			#missing == 0 and "none" or table.concat(missing, ",")))
end

local function check_inherit(lines)
	report(#lines == INHERIT_ROWS, "inherit-rows",
		string.format("rows=%d/%d", #lines, INHERIT_ROWS))
	local columns, malformed = {}, 0
	for index = 1, #lines do
		local z, x = string.match(lines[index], "^%d+\tinherit\t(%-?%d+)\t(%-?%d+)\t")
		if not z then
			malformed = malformed + 1
		else
			columns[#columns + 1] = z .. ":" .. x
		end
	end
	report(malformed == 0, "inherit-grammar",
		string.format("malformed-rows=%d", malformed))
	report(distinct_count(columns) == INHERIT_COLUMNS, "inherit-columns",
		string.format("distinct-columns=%d/%d", distinct_count(columns),
			INHERIT_COLUMNS))
end

local function check_pinch(lines)
	report(#lines == PINCH_ROWS, "pinch-rows",
		string.format("rows=%d/%d", #lines, PINCH_ROWS))
end

local function check_carriers(lines)
	local malformed = 0
	for index = 1, #lines do
		if not string.match(lines[index], "^%d+$") then
			malformed = malformed + 1
		end
	end
	report(malformed == 0, "carriers-grammar",
		string.format("malformed-lines=%d", malformed))
	local distinct = distinct_count(lines)
	report(distinct == CARRIERS and #lines == CARRIERS, "carriers-count",
		string.format("distinct=%d/%d lines=%d", distinct, CARRIERS, #lines))
	report(distinct >= CARRIERS_FLOOR, "carriers-floor",
		string.format("distinct=%d (>=%d)", distinct, CARRIERS_FLOOR))
end

local function check_ringcol(lines)
	report(#lines == RINGCOL_ROWS, "ringcol-rows",
		string.format("rows=%d/%d", #lines, RINGCOL_ROWS))
	report(count_duplicates(lines) == 0, "ringcol-no-duplicates",
		string.format("duplicate-rows=%d", count_duplicates(lines)))
end

-- ---------------------------------------------------------------- driver

print("== WP40 T2 section-11 acceptance ledger (contracts 11.11) ==")
print("artifacts " .. artifacts_dir)
print("fixtures " .. fixtures_dir)

print("== byte equality artifact vs canonical fixture ==")
for index = 1, #TABLES do check_table(TABLES[index]) end

print("== structural pins recomputed from the artifact bytes ==")
local STRUCTURAL = {
	{"adoption", check_adoption}, {"bjoin", check_bjoin},
	{"inherit", check_inherit}, {"pinch", check_pinch},
	{"carriers", check_carriers}, {"ringcol", check_ringcol},
}
for index = 1, #STRUCTURAL do
	local key, checker = STRUCTURAL[index][1], STRUCTURAL[index][2]
	if loaded[key] then
		checker(loaded[key])
	else
		report(false, key .. "-structural", "artifact not loaded")
	end
end

if failures == 0 then
	print("ACCEPTANCE GREEN")
	os.exit(0)
end
print(string.format("failing checks: %d", failures))
print("FAILURES PRESENT")
os.exit(1)
