-- Negative proofs for the four census launcher gates (plan section 6.6.2-4
-- and 6.6.7).  Every gate is exercised on the decision function the launcher
-- and the worker actually call, once positively and once per way the contract
-- says it must abort.
--
-- Written because a happy-path run is not evidence: this branch already
-- shipped a verification run that reported success with zero workers started
-- and a ripgrep gate that passed vacuously, and both would have survived any
-- test that only asserted the good case.
local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-census%.[A-Za-z0-9]+$"),
	"unsafe scratch path")

local function read_file(path)
	local file = assert(io.open(path, "rb"), "missing file " .. path)
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end
local function write_file(path, bytes)
	local file = assert(io.open(path, "wb"))
	assert(file:write(bytes)) assert(file:close())
end
local function to_hex(value)
	return (value:gsub(".", function(byte)
		return ("%02x"):format(string.byte(byte))
	end))
end

local hasher = dofile(repo .. "/tools/wp40/t2_census_hasher.lua")({
	repo = repo, scratch = scratch})
local authority = dofile(repo .. "/tools/wp40/t2_census_authority.lua")({
	raw_sha256 = hasher.raw_sha256})

local checks, refusals = 0, 0
local function check(condition, label)
	checks = checks + 1
	if not condition then error("census gate test failed: " .. label, 0) end
end
-- A negative proof only counts when the call fails *for the stated reason*:
-- an abort on an unrelated typo in the fixture would otherwise read as the
-- gate working.
local function refuses(label, fragment, body, ...)
	checks, refusals = checks + 1, refusals + 1
	local ok, message = pcall(body, ...)
	if ok then error("census gate test: " .. label .. " did not abort", 0) end
	message = tostring(message)
	if not message:find(fragment, 1, true) then
		error("census gate test: " .. label .. " aborted on the wrong reason: " ..
			message, 0)
	end
end

-- ---------------------------------------------------------------- W and ranges
local corpus = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
local candidate_bytes = read_file(repo .. "/" .. authority.candidates_path)
local w = authority.derive_w(corpus, candidate_bytes, hasher.raw_sha256)
check(w.total == 4123, "W holds " .. w.total .. " seeds")
check(w.seeds[1] == "0", "W does not start at seed 0")
check(w.seeds[w.total] == "18446744073709551615", "W does not end at max-u64")
check(w.derivation.duplicates == 0, "W deduplicated unexpectedly")
check(#w.digest == 64, "W digest is not a hex digest")
local again = authority.derive_w(corpus, candidate_bytes, hasher.raw_sha256)
check(again.digest == w.digest, "W derivation is not reproducible")
for index = 2, w.total do
	check(authority.decimal_less(w.seeds[index - 1], w.seeds[index]),
		"W is not in ascending canonical order at index " .. index)
end
refuses("a candidate artifact with a corrupted decimal", "corpus label rule",
	function()
		local broken = candidate_bytes:gsub("\t3318027308425330859\t",
			"\t3318027308425330860\t", 1)
		authority.derive_w(corpus, broken, hasher.raw_sha256)
	end)
refuses("a candidate artifact with a dropped row", "holds 4095 rows",
	function()
		local broken = candidate_bytes:gsub("\n0\tscored\t[^\n]*", "", 1)
		authority.derive_w(corpus, broken, hasher.raw_sha256)
	end)

local ranges = authority.shard_ranges(w.total)
check(#ranges == authority.worker_count, "shard count changed")
local covered = 0
for index = 1, #ranges do
	check(ranges[index].first == covered, "shard " .. index .. " does not abut")
	covered = ranges[index].last + 1
end
check(covered == w.total, "the shard ranges do not cover W")
refuses("a range that is not one of the eight", "canonical shard ranges",
	authority.validate_shard_range, 0, 63, w.total)
check(authority.validate_shard_range(ranges[1].first, ranges[1].last, w.total) == 1,
	"the first canonical range was rejected")

-- ------------------------------------------------------------ shard path names
local shard_path = authority.census_shard_path(ranges[1].first, ranges[1].last)
check(shard_path == "tools/wp40/results/t2_census/census-scan-v3-0000-0515.tsv",
	"census shard path changed: " .. shard_path)
check(not shard_path:find("shard-luajit", 1, true),
	"census shard path collides with the pool pattern")
check(authority.assert_disjoint_from_pool(0, 515), "pool disjointness check failed")
refuses("a shard path that is not canonical", "not the canonical census path",
	authority.validate_census_shard_path, "tools/wp40/results/t2_census/other.tsv",
	0, 515)
refuses("a free run writing a shard file name", "must not write a shard file name",
	authority.validate_free_output_path, "/tmp/census-scan-v3-0000-0515.tsv")
refuses("a free run writing a stale M1 shard file name",
	"must not write a shard file name",
	authority.validate_free_output_path, "/tmp/census-scan1-v1-0000-0515.tsv")
refuses("a free run writing into the shard directory", "must not write into",
	authority.validate_free_output_path,
	"/home/x/tools/wp40/results/t2_census/free.tsv")

-- ------------------------------------------------------------------- GO gate
check(authority.check_go_token(nil, w.digest, authority.free_seed_budget),
	"a free-budget run was refused")
refuses("a full-W slice without the token", "needs the explicit GO token",
	authority.check_go_token, nil, w.digest, ranges[1].size)
refuses("an empty token on a gated slice", "needs the explicit GO token",
	authority.check_go_token, "", w.digest, ranges[1].size)
refuses("a token for a different W", "does not match this W",
	authority.check_go_token, string.rep("a", 64), w.digest, ranges[1].size)
refuses("a stale token on a free run", "does not match this W",
	authority.check_go_token, string.rep("b", 64), w.digest, 2)
check(authority.check_go_token(w.digest, w.digest, ranges[1].size),
	"the matching token was refused")

-- ----------------------------------------------------------------- cost gate
local cap = authority.wall_cap_seconds
local inside = authority.project_wall_seconds({
	{size = 516, completed = 1, elapsed = 25},
	{size = 515, completed = 1, elapsed = 24}})
check(math.floor(inside.wall_seconds) == 12900,
	"projection changed: " .. inside.wall_seconds)
check(authority.check_cost_gate(inside), "an inside-cap projection was refused")
-- The trap section 6.5 names: 4,123 worker-seconds per seed-second is an
-- eight-hour overrun in wall time only if the projection stays per shard.
local over = authority.project_wall_seconds({
	{size = 516, completed = 2, elapsed = 120}})
check(math.floor(over.wall_seconds) == 30960, "overrun projection changed")
refuses("a projection past the eight-hour cap", "exceeds the",
	authority.check_cost_gate, over)
refuses("a projection past a lowered cap", "exceeds the",
	authority.check_cost_gate, inside, 600)
refuses("a projection from no completions", "at least one completed sample",
	authority.project_wall_seconds, {})
refuses("a projection from a shard that completed nothing", "completed no seed",
	authority.project_wall_seconds, {{size = 516, completed = 0, elapsed = 30}})

-- --------------------------------------------------- first record and resume
-- A synthetic shard in the exact worker format.  Building it here rather than
-- capturing one keeps the negatives cheap: every mutation below is a one-line
-- edit of bytes whose good form has just been accepted.
-- The record shape is derived from the authority's declared roster rather
-- than a shadow copy: occupancy-driven kinds (count nil) emit two synthetic
-- rows, and every class/kind cell takes the first declared vocabulary value.
local function seed_record(seed)
	local rows = {"seed_begin\t" .. seed}
	for _, layout in ipairs(authority.record_rows) do
		for index = 1, layout.count or 2 do
			local cells = {layout.tag, seed}
			for field = 3, layout.fields do
				cells[field] = layout.tag .. index .. "_" .. field
			end
			if layout.class_field then
				cells[layout.class_field] = authority.classes[layout.class_set][1]
			end
			if layout.extra_field then
				cells[layout.extra_field] = authority.classes[layout.extra_set][1]
			end
			if layout.extra2_field then
				cells[layout.extra2_field] = authority.classes[layout.extra2_set][1]
			end
			rows[#rows + 1] = table.concat(cells, "\t")
		end
	end
	rows[#rows + 1] = "seed_end\t" .. seed
	return table.concat(rows, "\n") .. "\n"
end

local header = authority.shard_header_lines({
	schema = authority.schema, vocabulary = authority.vocabulary_path,
	shard_schema = authority.shard_schema, first = 0, last = 1, shard_seeds = 2,
	w_digest = w.digest, w_total = w.total, census_commit = string.rep("c", 40),
	census_tree = string.rep("t", 40), module_digest = string.rep("d", 64),
	interpreter_id = "luajit", interpreter_path = "/usr/bin/luajit-test",
	interpreter_version = "LuaJIT test"})
local prefilter = {}
for index = 1, authority.prefilter_edge_count do
	prefilter[index] = "prefilter\tedge_" .. index ..
		(index <= 14 and "\tdischarged\tout of reach" or "\tscanned\tin reach")
end
local body = table.concat(header, "\n") .. "\n" ..
	table.concat(prefilter, "\n") .. "\n" ..
	seed_record(w.seeds[1]) .. seed_record(w.seeds[2])
local function sealed(text)
	return text .. "digest\tsha256=" .. to_hex(hasher.raw_sha256(text)) .. "\n"
end
local shard = sealed(body)
local expected = {first = 0, last = 1, w_digest = w.digest,
	census_commit = string.rep("c", 40), seeds = {w.seeds[1], w.seeds[2]}}

local verified = authority.verify_shard(shard, expected)
check(#verified.seeds == 2 and verified.seeds[1] == w.seeds[1],
	"a well-formed shard did not verify")
check(verified.totals.edge == 122, "shard row totals changed")
check(verified.totals.scan2_endpoint == 16 and verified.totals.scan2_edge == 12
	and verified.totals.scan2_tuple == 4, "shard scan2 totals changed")
check(verified.totals.scan3_aperture == 16 and verified.totals.scan3_wing == 16
	and verified.totals.scan3_bank == 8 and verified.totals.scan3_width == 8
	and verified.totals.scan3_step == 4 and verified.totals.scan3_selection == 4,
	"shard scan3 totals changed")
local first_record = authority.validate_first_record(body, expected)
check(first_record and first_record.seed == w.seeds[1],
	"a well-formed first record did not validate")
check(authority.validate_first_record(
	table.concat(header, "\n") .. "\n" .. table.concat(prefilter, "\n") .. "\n" ..
	"seed_begin\t" .. w.seeds[1] .. "\n") == nil,
	"an unfinished first record was treated as complete")

refuses("a first record with an undeclared class", "undeclared class",
	authority.validate_first_record,
	(body:gsub("ordinary_interval_select", "ordinary_interval_maybe", 1)), expected)
refuses("a first record with an undeclared edge kind", "undeclared kind",
	authority.validate_first_record,
	(body:gsub("\tordinary\t", "\tordinary_ish\t", 1)), expected)
refuses("a first record missing a site", "expected 38",
	authority.validate_first_record,
	(body:gsub("\njunction\t" .. w.seeds[1] .. "\tjunction1_3[^\n]*", "", 1)), expected)
refuses("a first record with a short row", "fields, expected 13",
	authority.validate_first_record, (body:gsub("\tedge1_13\n", "\n", 1)), expected)
refuses("a first record for the wrong seed", "expected " .. w.seeds[1],
	authority.validate_first_record,
	(body:gsub("seed_begin\t" .. w.seeds[1], "seed_begin\t7", 1)), expected)
refuses("a first record under a foreign W", "different W",
	authority.validate_first_record, body,
	{first = 0, last = 1, w_digest = string.rep("f", 64)})
refuses("a first record with an unknown row tag", "unknown row tag",
	authority.validate_first_record,
	(body:gsub("\nbay\t", "\nbays\t", 1)), expected)
refuses("a first record with an undeclared scan2 edge class", "undeclared class",
	authority.validate_first_record,
	(body:gsub("scan2_exactly_one_complete_select", "scan2_probably_complete", 1)),
	expected)
refuses("a first record with an undeclared scan2 tuple mode", "undeclared kind",
	authority.validate_first_record,
	(body:gsub("\tdirect\t", "\tdirectish\t", 1)), expected)
refuses("a first record with an undeclared scan2 to-mode", "undeclared kind",
	authority.validate_first_record,
	(body:gsub("scan2_tuple1_10\tdirect", "scan2_tuple1_10\tdirectish", 1)),
	expected)
refuses("a first record missing a scan2 edge row", "expected 6",
	authority.validate_first_record,
	(body:gsub("\nscan2_edge\t" .. w.seeds[1] .. "\tscan2_edge1_3[^\n]*", "", 1)),
	expected)

-- Scan-3a (M4).  Each of the six new row kinds is proven refusable on the
-- dimension that kind actually carries: its class column, its second
-- vocabulary column where it has one, its roster count and its width.
refuses("a first record with an undeclared scan3 aperture class",
	"undeclared class", authority.validate_first_record,
	(body:gsub("aperture_direct_select", "aperture_direct_maybe", 1)), expected)
refuses("a first record with an undeclared scan3 aperture mode",
	"undeclared kind", authority.validate_first_record,
	(body:gsub("aperture_direct_select\tdirect\t",
		"aperture_direct_select\tdirectish\t", 1)),
	expected)
refuses("a first record with an undeclared scan3 wing class", "undeclared class",
	authority.validate_first_record,
	(body:gsub("wing_wedge_valid_select", "wing_wedge_valid_maybe", 1)), expected)
refuses("a first record with an undeclared scan3 bank class", "undeclared class",
	authority.validate_first_record,
	(body:gsub("bank_trace_complete_select", "bank_trace_complete_maybe", 1)),
	expected)
refuses("a first record with an undeclared scan3 width class", "undeclared class",
	authority.validate_first_record,
	(body:gsub("bay_bank_width_positive", "bay_bank_width_probably", 1)), expected)
refuses("a first record with an undeclared scan3 step outcome",
	"undeclared class", authority.validate_first_record,
	(body:gsub("\tadmitted\t", "\tadmittedish\t", 1)), expected)
refuses("a first record with an undeclared scan3 step direction",
	"undeclared kind", authority.validate_first_record,
	(body:gsub("\teast\t", "\tnortheastish\t", 1)), expected)
refuses("a first record with an undeclared scan3 selection class",
	"undeclared class", authority.validate_first_record,
	(body:gsub("single_admitted_untested", "single_admitted_maybe", 1)), expected)
refuses("a first record missing a scan3 wing row", "expected 8",
	authority.validate_first_record,
	(body:gsub("\nscan3_wing\t" .. w.seeds[1] .. "\tscan3_wing1_3[^\n]*", "", 1)),
	expected)
refuses("a first record with a short scan3 width row", "fields, expected 20",
	authority.validate_first_record, (body:gsub("\tscan3_width1_20\n", "\n", 1)),
	expected)
-- The exclusion-cause vocabulary is declared here and checked by the worker
-- against the projection's own ordered list, so a cause added on one side and
-- not the other cannot silently drop a column out of every shard.
check(#authority.wing_exclusion_causes == 7,
	"the F5 exclusion cause list changed width without the wing row")
-- The M4 schema bump is only worth its cost if a finished v2 shard can never
-- be resumed into a v3 run.  Two independent refusals: the canonical path no
-- longer names it, and the free-output rule refuses to write it either.
check(shard_path:find("census-scan-v3-", 1, true) and
	not shard_path:find("census-scan-v2-", 1, true),
	"the M4 shard name still admits a v2 shard")
refuses("a free run writing a stale M3 shard file name",
	"must not write a shard file name",
	authority.validate_free_output_path, "/tmp/census-scan-v2-0000-0515.tsv")

-- Section 6.6.4: the empty claim file of a crashed worker, a truncated shard
-- and a silently edited one all abort; none of them is an empty shard.
refuses("an empty claim file", "shard file is empty",
	authority.verify_shard, "", expected)
refuses("a claim file holding only its header", "no trailing digest line",
	authority.verify_shard, table.concat(header, "\n") .. "\n", expected)
refuses("a shard truncated mid record", "no trailing digest line",
	authority.verify_shard, body, expected)
refuses("a shard whose digest was not recomputed", "recomputed",
	authority.verify_shard, (shard:gsub("ordinary_interval_select",
		"transition_interval_select", 1)), expected)
refuses("a shard resealed around an undeclared class", "undeclared class",
	authority.verify_shard,
	sealed((body:gsub("attachment_equality_select", "attachment_equality_maybe", 1))),
	expected)
-- Removed as a plain suffix: the record bytes now contain `-` cells, which
-- are pattern-magic and would silently turn a gsub removal into a no-op.
local record_two = seed_record(w.seeds[2])
check(body:sub(-#record_two) == record_two,
	"the second seed record is not the shard body suffix")
refuses("a shard resealed with a missing seed record", "seed records",
	authority.verify_shard, sealed(body:sub(1, #body - #record_two)),
	expected)
refuses("a shard resealed for another range", "not the range",
	authority.verify_shard,
	sealed((body:gsub("shard_range\t0\t1", "shard_range\t2\t3", 1))), expected)
refuses("a shard resealed at another commit", "produced at commit",
	authority.verify_shard,
	sealed((body:gsub(string.rep("c", 40), string.rep("e", 40), 1))), expected)
-- Trailing junk is refused where the parser expects the next record to open,
-- which is the earliest and most specific place it can be named.
refuses("a shard with trailing text after its last record",
	"does not open with seed_begin",
	authority.verify_shard, sealed(body .. "bay\t0\tx\t0\t-\n"), expected)
refuses("a shard whose header lost a line", "shard header line",
	authority.verify_shard,
	sealed((body:gsub("w_total\t" .. w.total .. "\n", "", 1))), expected)
refuses("a shard whose prefilter lost a row", "prefilter row 61",
	authority.verify_shard, sealed((body:gsub("\n" .. prefilter[61], "", 1))),
	expected)
refuses("a shard whose prefilter status is undeclared", "has status",
	authority.verify_shard, sealed((body:gsub("\tdischarged\t", "\tdisarmed\t", 1))),
	expected)

-- ------------------------------------------------- M5 merge-side declarations
-- The merge reads every field by name and keys every row on a declared site,
-- so a column list that drifts from the frozen width or a site column that
-- does not exist would corrupt an artifact silently.  The authority refuses
-- both at load; what is checked here is that the declarations it loaded are
-- the ones the merge actually needs.
for _, layout in ipairs(authority.record_rows) do
	check(#layout.columns == layout.fields,
		layout.tag .. " names a different number of columns than fields")
	check(#layout.site >= 1, layout.tag .. " declares no site columns")
	local cells = {}
	for field = 1, layout.fields do cells[field] = layout.tag .. "_" .. field end
	cells[1], cells[2] = layout.tag, "0"
	check(authority.field(layout.tag, cells, layout.columns[layout.fields]) ==
		cells[layout.fields], layout.tag .. " reads its last column wrong")
	check(type(authority.site_of(layout.tag, cells)) == "string",
		layout.tag .. " has no site key")
end
refuses("a merge reading a column no row declares", "has no column named",
	authority.field, "edge", {"edge", "0"}, "not_a_column")
refuses("a merge reading a row tag no roster declares", "unknown row tag",
	authority.site_of, "not_a_tag", {"not_a_tag", "0"})

-- Section 6.2.2's universe.  Every declared decision branch must carry a
-- verdict -- the authority fails at load otherwise -- and the kind
-- vocabularies must stay out of it, or the vacuous report would call an
-- unrealized row *shape* dead policy.
local universe = authority.branch_universe()
check(#universe > 0, "the declared branch universe is empty")
local in_universe = {}
for index = 1, #universe do
	local declared = universe[index]
	check(declared.verdict == "DECIDED" or declared.verdict == "REJECTED" or
		declared.verdict == "EVENT", declared.branch .. " has no usable verdict")
	in_universe[declared.vocabulary .. "\t" .. declared.branch] = true
end
for name, kind in pairs(authority.class_vocabulary_kind) do
	if kind == "kind" then
		for _, value in ipairs(authority.classes[name]) do
			check(not in_universe[name .. "\t" .. value],
				"the kind vocabulary " .. name .. " leaked into the branch universe")
		end
	else
		for _, value in ipairs(authority.classes[name]) do
			check(in_universe[name .. "\t" .. value],
				name .. " declares " .. value .. " outside the branch universe")
		end
	end
end
for _, cause in ipairs(authority.wing_exclusion_causes) do
	check(in_universe[authority.exclusion_vocabulary .. "\t" .. cause],
		"the F5 exclusion cause " .. cause .. " is outside the branch universe")
end
-- Section 6.2.3's roster is load-bearing: 137 measurable sites and 16 open
-- ones have to add up to the 153 the contract names.
local roster_total, roster_scanned = 0, 0
for _, family in ipairs(authority.extremal_families) do
	roster_total = roster_total + family.sites
	roster_scanned = roster_scanned + (family.scanned_sites or family.sites)
	check(authority.record_row_by_tag[family.row] ~= nil,
		family.family .. " names a row kind the record does not carry")
	for _, scalar in ipairs(family.scalars) do
		local derived = authority.derived_scalars[scalar]
		check(derived ~= nil or
			authority.record_row_by_tag[family.row].column_index[scalar] ~= nil,
			family.family .. " names the unmeasurable scalar " .. scalar)
	end
end
check(roster_total == authority.extremal_site_total,
	"the extremal roster no longer covers 153 sites")
check(roster_scanned == 137,
	"the scans 1-3a extremal coverage moved from 137 sites to " .. roster_scanned)
for _, rule in ipairs(authority.flag_rules) do
	local layout = authority.record_row_by_tag[rule.row]
	check(layout ~= nil and layout.column_index[rule.column] ~= nil,
		"the " .. rule.flag .. " flag reads a column its row does not carry")
	check(rule.test == "equals" or rule.test == "at_least",
		"the " .. rule.flag .. " flag uses a test the merge does not implement")
end

-- Free worker output is the only thing the M5 merge KAT can consume, and it
-- must never be readable as a slice of `W` -- nor a shard as a free run.
local free_body = "schema\t" .. authority.schema .. "\nvocabulary\t" ..
	authority.vocabulary_path .. "\n" .. table.concat(prefilter, "\n") .. "\n" ..
	seed_record(w.seeds[1])
local free_rows = 0
local free = authority.verify_free_output(sealed(free_body), nil,
	function() free_rows = free_rows + 1 end)
check(#free.seeds == 1 and #free.prefilter == authority.prefilter_edge_count and
	free_rows > 0, "a well-formed free record set was not accepted")
refuses("a shard read as a free record set", "must be verified as a shard",
	authority.verify_free_output, shard, nil)
refuses("a free record set read as a shard", "shard header line 3",
	authority.verify_shard, sealed(free_body), nil)
refuses("a free record set with a foreign schema", "record set schema is",
	authority.verify_free_output,
	sealed((free_body:gsub(authority.schema, "grug_wp40_census_scan_v2", 1))), nil)
refuses("a free record set with an undeclared class", "undeclared class",
	authority.verify_free_output,
	sealed((free_body:gsub("attachment_equality_select",
		"attachment_equality_maybe", 1))), nil)
refuses("a free record set without its digest line", "no trailing digest line",
	authority.verify_free_output, free_body, nil)

write_file(scratch .. "/gate-shard.tsv", shard)
check(read_file(scratch .. "/gate-shard.tsv") == shard, "shard round trip failed")
hasher.close()
print(("census gate test passed: %d checks, %d of them negative"):format(
	checks, refusals))
