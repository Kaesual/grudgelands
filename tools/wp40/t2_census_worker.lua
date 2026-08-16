-- WP40 T2 census worker (plan section 6.6, milestones M1-M4).  One process
-- evaluates a seed slice through partition.census_scan and emits one
-- canonical TSV: the Scan-1 interval/attachment/junction/fill projections,
-- the Scan-2 counting and tuple tiers (M3), the Scan-3a aperture, Wing,
-- bank-width and head-Bank projections (M4), the verified seed-independent
-- F1 prefilter and a trailing digest.
--
-- Three modes.  `--kat` (seeds 0, the Slot-29 R19 witness and max-u64) and
-- an explicit seed list are the free paths; their pinned digest is the
-- determinism gate, re-pinned at M4 because the record legitimately grew
-- Scan-3a rows.  `--range FIRST LAST` is the M2 shard mode over `W`: it adds
-- the shard framing the launcher resumes and verifies against, streams each
-- record so the launcher can check the first one while the run continues
-- (section 6.6.2), and refuses to start above the free seed budget without
-- the GO token (section 6.6.7).  The token is this `W`'s own digest, so a
-- direct worker call cannot conjure one.
local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local output_path = assert(arg[3], "output path required")
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-census%.[A-Za-z0-9]+$"),
	"unsafe scratch path")
assert(type(output_path) == "string" and output_path:match("^/[A-Za-z0-9._/-]+$") and
	not output_path:find("/../", 1, true) and not output_path:find("//", 1, true),
	"unsafe output path")

local mode = "seeds"
local seeds, seed_seen = {}, {}
local range_first, range_last, go_token
local shard_meta = {}
local shard_meta_flags = {["--commit"] = "census_commit", ["--tree"] = "census_tree",
	["--interpreter-id"] = "interpreter_id",
	["--interpreter-path"] = "interpreter_path",
	["--interpreter-version"] = "interpreter_version"}

local function add_seed(value)
	assert(type(value) == "string" and value:match("^%d+$"),
		"seed must be a decimal string")
	assert(value == "0" or value:match("^[1-9]"),
		"seed must be canonical decimal text without leading zeros")
	assert(#value < 20 or #value == 20 and value <= "18446744073709551615",
		"seed exceeds the unsigned 64-bit range")
	assert(not seed_seen[value], "duplicate seed in list")
	seed_seen[value] = true
	seeds[#seeds + 1] = value
end

local argument_index = 4
while arg[argument_index] do
	local flag = arg[argument_index]
	if flag == "--kat" then
		assert(mode == "seeds", "--kat cannot be combined with another mode")
		mode = "kat"
		argument_index = argument_index + 1
	elseif flag == "--range" then
		assert(mode == "seeds", "--range cannot be combined with another mode")
		mode = "range"
		range_first = tonumber(arg[argument_index + 1])
		range_last = tonumber(arg[argument_index + 2])
		assert(range_first and range_last and range_first % 1 == 0 and
			range_last % 1 == 0 and range_first >= 0 and range_last >= range_first,
			"--range needs two ascending nonnegative integers")
		argument_index = argument_index + 3
	elseif flag == "--go-token" then
		go_token = assert(arg[argument_index + 1], "--go-token needs a value")
		argument_index = argument_index + 2
	elseif shard_meta_flags[flag] then
		shard_meta[shard_meta_flags[flag]] =
			assert(arg[argument_index + 1], flag .. " needs a value")
		argument_index = argument_index + 2
	else
		assert(not flag:match("^%-%-"), "unknown census worker flag " .. flag)
		add_seed(flag)
		argument_index = argument_index + 1
	end
end
if mode == "kat" then
	assert(#seeds == 0, "--kat accepts no explicit seeds")
	seeds = {"0", "16178445837170081103", "18446744073709551615"}
elseif mode == "range" then
	assert(#seeds == 0, "--range accepts no explicit seeds")
end

local function read_file(path)
	local file = assert(io.open(path, "rb"), "missing file " .. path)
	local bytes = assert(file:read("*a"))
	assert(file:close())
	return bytes
end
local function to_hex(value)
	return (value:gsub(".", function(byte)
		return ("%02x"):format(string.byte(byte))
	end))
end

local hasher = dofile(repo .. "/tools/wp40/t2_census_hasher.lua")({
	repo = repo, scratch = scratch})
local raw_sha256 = hasher.raw_sha256
local authority = dofile(repo .. "/tools/wp40/t2_census_authority.lua")({
	raw_sha256 = raw_sha256})

-- Pinned before the modules are loaded and re-read before the shard is
-- published, so a mid-run edit to partition.lua cannot leave half a shard
-- measured against one tree and half against another.  The same digest is
-- what the launcher resumes against, so it is computed in one place.
local function module_digest()
	return authority.module_digest(function(path)
		return read_file(repo .. "/" .. path)
	end)
end
local pinned_module_digest = module_digest()
hasher.forget()

-- `W` is derived, never listed: seed 0, max-u64 and the corpus slots from the
-- committed corpus module, the 4,096 pool candidates from the committed label
-- rule, cross-checked row for row against the committed candidate artifact
-- (plan section 6.3).  Deriving it costs 4,096 hashes, so free runs that need
-- neither the slice nor the token never pay for it.
local derived_w
local function require_w()
	if derived_w then return derived_w end
	local corpus = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
	derived_w = authority.derive_w(corpus,
		read_file(repo .. "/" .. authority.candidates_path), raw_sha256)
	hasher.forget()
	return derived_w
end

if mode == "range" then
	local w = require_w()
	assert(range_last < w.total, "range end " .. range_last ..
		" is outside W (" .. w.total .. " seeds)")
	for index = range_first, range_last do add_seed(w.seeds[index + 1]) end
end
assert(#seeds >= 1, "at least one seed required")
if #seeds > authority.free_seed_budget or go_token then
	authority.check_go_token(go_token, require_w().digest, #seeds)
end

local shard_mode = mode == "range" and #seeds > authority.free_seed_budget
if shard_mode then
	authority.validate_shard_range(range_first, range_last, require_w().total)
	assert(output_path == repo .. "/" ..
		authority.census_shard_path(range_first, range_last),
		"a gated census range must publish at its canonical shard path")
	authority.validate_census_shard_path(
		authority.census_shard_path(range_first, range_last), range_first, range_last)
	for _, field in pairs(shard_meta_flags) do
		assert(shard_meta[field], "shard mode requires " .. field)
	end
else
	authority.validate_free_output_path(output_path)
end

-- Claim the output path up front instead of only checking it: the run takes
-- minutes to hours, and a late-write-only design would let a second worker
-- started in that window clobber the first result.  A crash leaves a file with
-- no trailing digest line, which resume verification treats as unparseable and
-- aborts on -- never as an empty shard (plan section 6.6.4).
local existing = io.open(output_path, "rb")
if existing then existing:close() error("census output already exists", 0) end
local output_file = assert(io.open(output_path, "wb"))

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local exact = dofile(wp40 .. "/geometry/exact.lua")({
	deterministic = deterministic})
local raster = dofile(wp40 .. "/geometry/raster.lua")({canonical = canonical,
	deterministic = deterministic, exact = exact, raw_sha256 = raw_sha256})
local source = dofile(wp40 .. "/source/catalog.lua")
local source_validator = dofile(wp40 .. "/validation/t2_source.lua")
-- The closed WP43 vocabulary projection retained for the E0 pool; recorded
-- here so the census manifest names its vocabulary authority explicitly.
local vocabulary_path = authority.vocabulary_path
local vocabulary = dofile(repo .. "/" .. vocabulary_path)
local new_boundary = dofile(wp40 .. "/geometry/boundary.lua")
local partition = dofile(wp40 .. "/geometry/partition.lua")({
	canonical = canonical, deterministic = deterministic, exact = exact,
	new_boundary = new_boundary, raster = raster, raw_sha256 = raw_sha256,
	source = source, source_validator = source_validator,
	vocabulary = vocabulary})

-- Buffered per line, flushed per seed record.  Section 6.6.2 has the launcher
-- validate each worker's first completed record while the workers keep
-- running, which a run that only materializes its output at the end cannot
-- support.
local pending, line_count = {}, 0
local function emit(...)
	pending[#pending + 1] = table.concat({...}, "\t")
end
local function flush_record()
	if #pending == 0 then return end
	assert(output_file:write(table.concat(pending, "\n"), "\n"))
	assert(output_file:flush())
	line_count = line_count + #pending
	pending = {}
end
local function opt(value)
	if value == nil then return "-" end
	return tostring(value)
end

emit("schema", partition.census_scan_schema)
emit("vocabulary", vocabulary_path)
if shard_mode then
	local w = require_w()
	local header = {schema = partition.census_scan_schema,
		vocabulary = vocabulary_path, shard_schema = authority.shard_schema,
		first = range_first, last = range_last, shard_seeds = #seeds,
		w_digest = w.digest, w_total = w.total, module_digest = pinned_module_digest,
		census_commit = shard_meta.census_commit, census_tree = shard_meta.census_tree,
		interpreter_id = shard_meta.interpreter_id,
		interpreter_path = shard_meta.interpreter_path,
		interpreter_version = shard_meta.interpreter_version}
	local lines = authority.shard_header_lines(header)
	-- shard_header_lines re-emits schema and vocabulary in the frozen M1 order,
	-- so the two already queued above are the first two of that list.
	assert(lines[1] == pending[1] and lines[2] == pending[2],
		"shard header disagrees with the frozen M1 preamble")
	for index = 3, #lines do pending[#pending + 1] = lines[index] end
	flush_record()
end

local prefilter_serialized
local scans_by_seed = {}
local run_started = os.time()
for seed_index = 1, #seeds do
	local seed = seeds[seed_index]
	local started = os.time()
	local scan = partition.census_scan(seed)
	if mode == "kat" then scans_by_seed[seed] = scan end
	local serialized_rows = {}
	for index = 1, #scan.prefilter do
		local row = scan.prefilter[index]
		serialized_rows[index] = table.concat({row.edge_id,
			row.discharged and "discharged" or "scanned", row.reason}, "\t")
	end
	local serialized = table.concat(serialized_rows, "\n")
	if seed_index == 1 then
		prefilter_serialized = serialized
		for index = 1, #serialized_rows do
			pending[#pending + 1] = "prefilter\t" .. serialized_rows[index]
		end
	elseif serialized ~= prefilter_serialized then
		error("WP40 census: seed-independent prefilter drifted at seed " ..
			seed, 0)
	end
	emit("seed_begin", seed)
	-- The discharged-edge hard abort (plan section 6.6.8) lives inside
	-- census_scan1 itself, so every consumer of the projection gets it.
	for index = 1, #scan.edges do
		local row = scan.edges[index]
		emit("edge", seed, row.id, row.kind, row.class,
			tostring(row.interval_count), opt(row.qualifying_count),
			tostring(row.singleton_count), opt(row.selected_first),
			opt(row.selected_finish), tostring(row.station_count),
			tostring(row.topology_ceiling_nodes),
			tostring(row.max_abs_scalar_q))
	end
	for index = 1, #scan.perimeters do
		local row = scan.perimeters[index]
		emit("perimeter", seed, row.id, tostring(row.station_count),
			tostring(row.topology_ceiling_nodes),
			tostring(row.max_abs_scalar_q))
	end
	for index = 1, #scan.aperture_stress do
		local row = scan.aperture_stress[index]
		emit("aperture", seed, row.id, row.side,
			tostring(row.d_x), tostring(row.d_z), tostring(row.d_scalar_q),
			tostring(row.d_sample_distance),
			tostring(row.w_x), tostring(row.w_z), tostring(row.w_scalar_q),
			tostring(row.w_sample_distance),
			tostring(row.a_x), tostring(row.a_z), tostring(row.a_scalar_q),
			tostring(row.a_sample_distance))
	end
	for index = 1, #scan.attachments do
		local row = scan.attachments[index]
		emit("attachment", seed, row.id, row.edge_id, row.endpoint, row.class,
			opt(row.distance), tostring(row.interval_count),
			opt(row.e and row.e.x), opt(row.e and row.e.z),
			opt(row.a and row.a.x), opt(row.a and row.a.z),
			opt(row.canonical_index))
	end
	for index = 1, #scan.junctions do
		local row = scan.junctions[index]
		emit("junction", seed, row.id, tostring(row.pair_count),
			tostring(row.pass_count), tostring(row.fail_count),
			opt(row.min_clearance))
	end
	for index = 1, #scan.junction_pair_rejects do
		local row = scan.junction_pair_rejects[index]
		emit("junction_pair", seed, row.junction_id, row.left_edge,
			row.right_edge, row.class)
	end
	for index = 1, #scan.bay_fills do
		local row = scan.bay_fills[index]
		local fill_texts = {}
		for fill_index = 1, #row.fill_points do
			fill_texts[fill_index] = row.fill_points[fill_index].x .. ":" ..
				row.fill_points[fill_index].z
		end
		emit("bay", seed, row.id, tostring(row.fill_count),
			#fill_texts > 0 and table.concat(fill_texts, ",") or "-")
	end
	-- Scan-2 rows (M3) follow the complete M1 block, so each seed record
	-- keeps the M1 bytes as an exact prefix.
	for index = 1, #scan.scan2_endpoints do
		local row = scan.scan2_endpoints[index]
		local success_texts = {}
		local successes = row.successes
		if successes then
			for success_index = 1, #successes do
				local success = successes[success_index]
				success_texts[success_index] = success.index .. ":" ..
					success.mode
			end
		end
		emit("scan2_endpoint", seed, row.id, row.edge_id, row.endpoint,
			row.class, tostring(row.flagged), opt(row.first), opt(row.finish),
			opt(row.eligible_count), opt(row.success_count),
			opt(row.direct_count), opt(row.elbow_count),
			#success_texts > 0 and table.concat(success_texts, ",") or "-")
	end
	for index = 1, #scan.scan2_edges do
		local row = scan.scan2_edges[index]
		emit("scan2_edge", seed, row.edge_id, row.class, tostring(row.flagged),
			tostring(row.tuple_count), tostring(row.complete_count),
			tostring(row.duplicate_count), opt(row.selected_tuple_index),
			opt(row.selected_station_count))
	end
	for index = 1, #scan.scan2_tuples do
		local row = scan.scan2_tuples[index]
		emit("scan2_tuple", seed, row.edge_id, tostring(row.tuple_index),
			row.class, opt(row.from_index), row.from_mode or "-",
			opt(row.from_point), opt(row.from_previous), opt(row.to_index),
			row.to_mode or "-", opt(row.to_point), opt(row.to_previous),
			opt(row.probe_station_count), row.key, opt(row.detail))
	end
	-- Scan-3a rows (M4) follow the Scan-2 block, so each seed record keeps the
	-- M1 bytes and then the M1+M3 bytes as exact prefixes.
	for index = 1, #scan.scan3_apertures do
		local row = scan.scan3_apertures[index]
		emit("scan3_aperture", seed, row.id, row.side, row.class,
			row.mode or "-", opt(row.d), opt(row.t), opt(row.w),
			opt(row.selected_elbow), opt(row.water_side_ok), row.bank_id,
			tostring(row.terminal_index), opt(row.detail))
	end
	for index = 1, #scan.scan3_wings do
		local row = scan.scan3_wings[index]
		-- The exclusion columns are positional over the projection's own
		-- declared cause order, checked against the authority's copy of it, so
		-- adding a cause on either side aborts here rather than quietly
		-- reordering or dropping a column in every shard.
		assert(#row.exclusion_causes == #authority.wing_exclusion_causes,
			"census scan3 wing exclusion cause count differs from the authority")
		for cause_index = 1, #row.exclusion_causes do
			assert(row.exclusion_causes[cause_index] ==
				authority.wing_exclusion_causes[cause_index],
				"census scan3 wing exclusion cause " .. cause_index .. " is " ..
				tostring(row.exclusion_causes[cause_index]) .. ", the authority " ..
				"declares " .. tostring(authority.wing_exclusion_causes[cause_index]))
		end
		local excluded = row.exclusion_counts
		emit("scan3_wing", seed, row.id, row.bay_id, row.class,
			opt(row.negative_k_count), opt(row.positive_k_count),
			opt(row.negative_k), opt(row.positive_k),
			opt(row.negative_chebyshev), opt(row.positive_chebyshev),
			opt(row.negative_path_count), opt(row.positive_path_count),
			opt(row.negative_tail_length), opt(row.positive_tail_length),
			opt(row.radius), opt(row.path_bound),
			opt(row.raw_pair_count), opt(row.structural_pair_count),
			opt(row.wedge_valid_count),
			opt(row.selected_raw_rank), opt(row.selected_structural_rank),
			opt(excluded[1]), opt(excluded[2]), opt(excluded[3]), opt(excluded[4]),
			opt(excluded[5]), opt(excluded[6]), opt(excluded[7]),
			opt(row.detail))
	end
	for index = 1, #scan.scan3_banks do
		local row = scan.scan3_banks[index]
		emit("scan3_bank", seed, row.id, row.bay_id, row.class,
			tostring(row.step_count), opt(row.station_count),
			tostring(row.max_frames), tostring(row.max_stack),
			tostring(row.branch_step_count),
			tostring(row.multi_reachable_step_count), opt(row.detail))
	end
	for index = 1, #scan.scan3_bay_widths do
		local row = scan.scan3_bay_widths[index]
		emit("scan3_width", seed, row.id, row.class,
			tostring(row.station_count), tostring(row.min_numerator),
			tostring(row.min_length), tostring(row.min_width_nodes),
			tostring(row.min_segment), tostring(row.min_station),
			tostring(row.min_x), tostring(row.min_z),
			tostring(row.min_delta_nodes),
			opt(row.jittered_numerator), opt(row.jittered_length),
			opt(row.jittered_width_nodes), opt(row.jittered_delta_nodes),
			tostring(row.min_delta), tostring(row.max_delta),
			tostring(row.column_bound_nodes))
	end
	for index = 1, #scan.scan3_steps do
		local row = scan.scan3_steps[index]
		emit("scan3_step", seed, row.bank_id, row.direction, row.outcome,
			tostring(row.count))
	end
	for index = 1, #scan.scan3_selections do
		local row = scan.scan3_selections[index]
		emit("scan3_selection", seed, row.bank_id, row.class,
			tostring(row.count), tostring(row.max_width),
			tostring(row.multi_reachable), tostring(row.unknown_reachable))
	end
	emit("seed_end", seed)
	flush_record()
	-- The SHA memo has zero cross-seed reuse (every noise input embeds the
	-- seed), so dropping it bounds worker memory over long seed lists without
	-- changing a single emitted byte.
	hasher.forget()
	io.stderr:write("census seed " .. seed .. " done " .. seed_index .. "/" ..
		#seeds .. " wall=" .. os.difftime(os.time(), started) .. "s cpu=" ..
		string.format("%.1f", os.clock()) .. "s\n")
	io.stderr:flush()
	if shard_mode then
		local elapsed = math.max(0, os.difftime(os.time(), run_started))
		local remaining = #seeds - seed_index
		local eta = math.floor(elapsed * remaining / seed_index)
		print(("WP40 T2 census shard progress range=%04d..%04d current=%04d " ..
			"completed=%d/%d wall_seconds=%d eta_seconds=%d"):format(
			range_first, range_last, range_first + seed_index - 1, seed_index,
			#seeds, elapsed, eta))
		io.stdout:flush()
	end
end

assert(#pending == 0, "census worker left rows unflushed")
assert(output_file:close())
assert(module_digest() == pinned_module_digest,
	"a census input module changed during the run")
local digest = to_hex(hasher.raw_sha256_file(output_path))
local finish = assert(io.open(output_path, "ab"))
assert(finish:write("digest\tsha256=", digest, "\n"))
assert(finish:close())
hasher.close()
print("census scan rows " .. line_count .. " digest " .. digest)

if mode == "kat" then
	local fixture_path = repo ..
		"/tools/wp40/fixtures/t2_census/scan_kat_v3.lua"
	local fixture_chunk, fixture_diagnostic = loadfile(fixture_path)
	assert(fixture_chunk, "census KAT fixture missing or invalid: " ..
		tostring(fixture_diagnostic))
	local fixture = fixture_chunk()
	assert(fixture.schema == partition.census_scan_schema,
		"census KAT fixture schema differs")
	assert(type(fixture.r19_witness) == "table" and fixture.r19_witness.seed and
		fixture.r19_witness.endpoint and fixture.r19_witness.edge,
		"census KAT fixture lacks its R19 witness declaration")
	assert(type(fixture.tail_mode_witness) == "table" and
		fixture.tail_mode_witness.seed and fixture.tail_mode_witness.aperture and
		fixture.tail_mode_witness.side,
		"census KAT fixture lacks its aperture tail-mode witness declaration")
	-- A witness seed missing from the roster would silently skip the witness
	-- assertion below; refuse that shape outright.
	assert(scans_by_seed[fixture.r19_witness.seed],
		"census KAT roster does not cover the fixture's R19 witness seed")
	assert(scans_by_seed[fixture.tail_mode_witness.seed],
		"census KAT roster does not cover the fixture's tail-mode witness seed")
	assert(#fixture.r15_corpus == 8,
		"census KAT fixture expects eight retained R15 corpus rows")
	for seed_index = 1, #seeds do
		local seed = seeds[seed_index]
		local scan = scans_by_seed[seed]
		assert(#scan.edges == 61, "census KAT expects 61 edge rows")
		assert(#scan.perimeters == 3, "census KAT expects 3 perimeter rows")
		for index = 1, #scan.perimeters do
			local row = scan.perimeters[index]
			if row.id == "perimeter_holy_grounds" then
				assert(row.topology_ceiling_nodes == 0 and
					row.max_abs_scalar_q == 0,
					"census KAT: the fixed Holy band must stay zero-displacement")
			end
		end
		assert(#scan.aperture_stress == 8,
			"census KAT expects 8 aperture stress rows")
		assert(#scan.attachments == 8, "census KAT expects 8 attachment rows")
		assert(#scan.junctions == 38, "census KAT expects 38 junction rows")
		assert(#scan.bay_fills == 4, "census KAT expects 4 bay rows")
		local transition_rows, pass_total = 0, 0
		for index = 1, #scan.edges do
			local row = scan.edges[index]
			assert(row.class == "ordinary_interval_select" or
				row.class == "transition_interval_select",
				"census KAT seed " .. seed .. " edge " .. row.id ..
				" class " .. row.class)
			if row.qualifying_count then
				transition_rows = transition_rows + 1
				assert(row.qualifying_count == 1,
					"census KAT transition qualifying count differs")
			end
		end
		assert(transition_rows == 6, "census KAT expects 6 transition edges")
		for index = 1, #scan.junctions do
			pass_total = pass_total + scan.junctions[index].pass_count
			assert(scan.junctions[index].fail_count == 0,
				"census KAT junction pair failed")
		end
		assert(pass_total == 102, "census KAT expects 102 passing pairs")
		for index = 1, #scan.attachments do
			assert(scan.attachments[index].distance and
				scan.attachments[index].distance <= 1,
				"census KAT attachment distance exceeds one")
		end
		local expected_fills = assert(fixture.fills[seed],
			"census KAT fixture lacks seed " .. seed)
		for index = 1, #scan.bay_fills do
			assert(scan.bay_fills[index].fill_count == expected_fills[index],
				"census KAT fill count differs at " ..
				scan.bay_fills[index].id .. " seed " .. seed)
		end
		-- Scan-2 (M3): the counting tier and R19 joint decision are pinned
		-- per endpoint and per edge, on top of the byte digest below.
		local expected_scan2 = assert(fixture.scan2[seed],
			"census KAT fixture lacks scan2 for seed " .. seed)
		assert(#scan.scan2_endpoints == 8,
			"census KAT expects 8 scan2 endpoint rows")
		assert(#scan.scan2_edges == 6, "census KAT expects 6 scan2 edge rows")
		for index = 1, #scan.scan2_endpoints do
			local row = scan.scan2_endpoints[index]
			local expected = assert(expected_scan2.endpoints[row.id],
				"census KAT scan2 endpoint fixture lacks " .. row.id)
			assert(row.class == "scan2_counting_evaluated" and
				row.eligible_count == expected.eligible and
				row.success_count == expected.success and
				row.direct_count == expected.direct and
				row.elbow_count == expected.elbow,
				"census KAT scan2 endpoint differs at " .. row.id ..
				" seed " .. seed)
		end
		for index = 1, #scan.scan2_edges do
			local row = scan.scan2_edges[index]
			local expected = assert(expected_scan2.edges[row.edge_id],
				"census KAT scan2 edge fixture lacks " .. row.edge_id)
			assert(row.class == expected.class and
				row.tuple_count == expected.tuples and
				row.complete_count == expected.complete,
				"census KAT scan2 edge differs at " .. row.edge_id ..
				" seed " .. seed)
		end
		if seed == fixture.r19_witness.seed then
			-- The R19 witness (analysis section 3-F2): the fixture-named
			-- endpoint carries at least two R16 candidates and its edge
			-- exactly one complete tuple.  Fixture-driven so the witness
			-- seed, endpoint and edge live in exactly one place.
			local witnessed = false
			for index = 1, #scan.scan2_endpoints do
				local row = scan.scan2_endpoints[index]
				if row.id == fixture.r19_witness.endpoint then
					assert(row.success_count and row.success_count >= 2,
						"census KAT: the R19 witness endpoint lost its candidates")
					for edge_index = 1, #scan.scan2_edges do
						local edge_row = scan.scan2_edges[edge_index]
						if edge_row.edge_id == fixture.r19_witness.edge and
								edge_row.complete_count == 1 then
							witnessed = true
						end
					end
				end
			end
			assert(witnessed,
				"census KAT: the R19 two-candidate/one-complete witness is absent")
		end
		-- Scan-3a (M4).  F4: every incidence resolves, and the mode split is
		-- pinned per seed so the first tail-mode occupancy cannot disappear
		-- unnoticed.
		assert(#scan.scan3_apertures == 8,
			"census KAT expects 8 scan3 aperture rows")
		local modes = {direct = 0, diagonal_shoulder = 0}
		for index = 1, #scan.scan3_apertures do
			local row = scan.scan3_apertures[index]
			assert(row.class == "aperture_direct_select" or
				row.class == "aperture_tail_select",
				"census KAT scan3 aperture " .. row.id .. ":" .. row.side ..
				" class " .. row.class .. " seed " .. seed)
			modes[row.mode] = assert(modes[row.mode],
				"census KAT scan3 aperture mode " .. tostring(row.mode)) + 1
			if row.mode == "diagonal_shoulder" then
				assert(row.water_side_ok == true,
					"census KAT: a tail-mode incidence put W on the wrong side")
			end
		end
		local expected_modes = assert(fixture.aperture_modes[seed],
			"census KAT fixture lacks aperture modes for seed " .. seed)
		assert(modes.direct == expected_modes.direct and
			modes.diagonal_shoulder == expected_modes.diagonal_shoulder,
			"census KAT scan3 aperture mode split differs at seed " .. seed ..
			": " .. modes.direct .. "/" .. modes.diagonal_shoulder)
		if seed == fixture.tail_mode_witness.seed then
			local witnessed = false
			for index = 1, #scan.scan3_apertures do
				local row = scan.scan3_apertures[index]
				if row.id == fixture.tail_mode_witness.aperture and
						row.side == fixture.tail_mode_witness.side then
					witnessed = row.class == "aperture_tail_select"
				end
			end
			assert(witnessed,
				"census KAT: the aperture tail-mode witness is absent")
		end
		-- F5: the census Wing analysis is compared row for row against the
		-- retained R15 Stage-1 corpus (source authority section 6.1).  The
		-- corpus is an oracle here and never an input -- the projection
		-- enumerates every pair itself.
		assert(#scan.scan3_wings == 8, "census KAT expects 8 scan3 wing rows")
		for index = 1, #scan.scan3_wings do
			local row = scan.scan3_wings[index]
			local expected = fixture.r15_corpus[index]
			assert(expected and expected.id == row.id,
				"census KAT scan3 wing " .. index .. " is " .. row.id ..
				", the retained corpus names " ..
				tostring(expected and expected.id))
			assert(row.class == "wing_wedge_valid_select",
				"census KAT scan3 wing " .. row.id .. " class " .. row.class ..
				" seed " .. seed)
			assert(row.raw_pair_count == expected.raw and
				row.structural_pair_count == expected.structural and
				row.wedge_valid_count == expected.wedge_valid and
				row.selected_raw_rank == expected.rank and
				row.radius == expected.radius and
				row.negative_tail_length == expected.negative_length and
				row.positive_tail_length == expected.positive_length,
				"census KAT scan3 wing " .. row.id ..
				" diverged from the retained R15 corpus at seed " .. seed)
			assert(row.negative_chebyshev <= 4 and row.positive_chebyshev <= 4,
				"census KAT: Chebyshev(K,J) exceeded four at " .. row.id)
		end
		-- F3: the four head Banks, their trace stress scalars, and the
		-- branch-occupancy note the analysis asks the census to log.
		assert(#scan.scan3_banks == 4, "census KAT expects 4 scan3 bank rows")
		for index = 1, #scan.scan3_banks do
			local row = scan.scan3_banks[index]
			local expected = fixture.head_banks[index]
			assert(expected and expected.id == row.id,
				"census KAT scan3 bank " .. index .. " is " .. row.id)
			assert(row.class == "bank_trace_complete_select",
				"census KAT scan3 bank " .. row.id .. " class " .. row.class ..
				" seed " .. seed .. " " .. tostring(row.detail))
			assert(row.step_count == expected.steps and
				row.station_count == expected.stations,
				"census KAT scan3 bank " .. row.id .. " trace shape differs: " ..
				row.step_count .. "/" .. tostring(row.station_count) ..
				" seed " .. seed)
			assert(row.branch_step_count == 0 and
				row.multi_reachable_step_count == 0 and row.max_frames == 0 and
				row.max_stack == 0,
				"census KAT scan3 bank " .. row.id ..
				" gained a branching step; the F3 branch note needs re-reading")
		end
		-- Section 6.4: the `w = 0` universal, and the margin behind it.
		assert(#scan.scan3_bay_widths == 4,
			"census KAT expects 4 scan3 width rows")
		for index = 1, #scan.scan3_bay_widths do
			local row = scan.scan3_bay_widths[index]
			assert(row.class == "bay_bank_width_positive",
				"census KAT scan3 width " .. row.id .. " class " .. row.class)
			assert(row.min_width_nodes == fixture.bank_width.min_width_nodes and
				row.min_segment == fixture.bank_width.min_segment,
				"census KAT scan3 width " .. row.id .. " minimum moved to " ..
				row.min_width_nodes .. " at segment " .. row.min_segment ..
				" seed " .. seed)
			assert(row.min_delta_nodes == 0,
				"census KAT: the narrowest bank width station gained jitter")
			assert(math.abs(row.min_delta) <= fixture.bank_width.delta_bound and
				math.abs(row.max_delta) <= fixture.bank_width.delta_bound,
				"census KAT scan3 width " .. row.id ..
				" jitter exceeded its declared bound")
			-- The exact per-column lower bound, which is what actually rules a
			-- collapse out: the station minimum alone cannot, because the
			-- compiler evaluates the same numerator at columns between stations.
			-- The exact value is pinned by the digest; what is asserted by name
			-- is that it stays positive and above the structural floor.
			assert(row.column_bound_nodes > 0 and row.column_bound_nodes >=
				fixture.bank_width.column_bound_floor,
				"census KAT scan3 width " .. row.id .. " column bound is " ..
				row.column_bound_nodes .. " seed " .. seed)
		end
	end
	assert(digest == fixture.digest,
		"census KAT determinism digest differs: " .. digest)
	print("census scan KAT passed (seeds 0, Slot 29 and max-u64, digest pinned)")
end
