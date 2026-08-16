-- Single declaration point for the WP40 T2 census run (plan section 6.6).
--
-- The launcher, the shard worker and the milestone-M5 merge all need the same
-- four facts: how `W` is derived, how a shard range and its file name are
-- formed, which decision classes and site counts a Scan-1 seed record may
-- contain, and when a run is allowed to start.  The extreme launcher records
-- in its own comment what a second copy of such a rule costs -- a stale local
-- copy of the shard-name rule aborted a fresh pool launch before any seed was
-- measured -- so every consumer asks this file instead of restating it.
--
-- Nothing here loads geometry or hashes anything by itself: the caller injects
-- `raw_sha256`, which keeps the module usable from the launcher (one process),
-- from a worker (persistent hasher) and from the PUC merge alike.
return function(dependencies)
	assert(type(dependencies) == "table")
	local raw_sha256 = dependencies.raw_sha256

	local authority = {}

	local function fail(message)
		error("WP40 T2 census authority: " .. message, 0)
	end

	local function hex(bytes)
		return (bytes:gsub(".", function(byte)
			return ("%02x"):format(string.byte(byte))
		end))
	end

	local function digest_of(text)
		if type(raw_sha256) ~= "function" then fail("no hasher was injected") end
		local raw = raw_sha256(text)
		if type(raw) ~= "string" or #raw ~= 32 then fail("hasher returned no digest") end
		return hex(raw)
	end

	-- Section 6.6.1: eight range-sharded LuaJIT workers.  Section 6.5: eight
	-- hours wall *at eight workers* -- the two numbers belong together, and
	-- splitting them is exactly how a worker-seconds anchor turns into a
	-- wall-time threshold that is wrong by the worker count.
	local worker_count = 8
	local wall_cap_seconds = 8 * 60 * 60
	-- Section 6.6.7: KATs and small explicit ranges run freely.  Everything
	-- above this budget needs the GO token, which replaces the M1 worker's
	-- 64-seed list cap now that range mode exists.
	local free_seed_budget = 64

	-- v3 since M4: the record carries the Scan-1, Scan-3a and Scan-2 rows.  The
	-- version is one unit for the whole record -- the merge and the
	-- first-record validator consume complete seed records, never one scan's
	-- rows alone -- and the shard name carries it too, so a v2 shard left on
	-- disk can never be resumed into a v3 run.
	local schema = "grug_wp40_census_scan_v3"
	local shard_schema = "grug_wp40_census_scan_shard_v3"
	local vocabulary_path = "tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua"
	local candidates_path =
		"tools/wp40/fixtures/t2_extreme_e0/candidates-luajit-v3.tsv"
	local candidates_schema = "grug_wp40_extreme_measurement_artifact_v3"
	local pool_candidate_count = 4096

	-- The declared class vocabulary of a Scan-1 seed record.  Section 6.6.2
	-- validates a worker's first completed record against exactly this, and the
	-- M5 merge keys the occupied-class table on it, so an unlisted string is a
	-- structural failure here rather than an unnoticed extra row there.
	local classes = {
		prefilter_status = {"discharged", "scanned"},
		edge_kind = {"ordinary", "ordinary_attachment", "transition",
			"transition_attachment"},
		edge_class = {"ordinary_interval_select", "ordinary_interval_zero_reject",
			"ordinary_interval_multi_reject", "transition_interval_select",
			"transition_interval_zero_reject", "transition_interval_multi_reject"},
		attachment_class = {"attachment_equality_select",
			"attachment_adjacent_select", "attachment_distance_reject",
			"attachment_edge_without_interval"},
		junction_pair_class = {"junction_pair_short_raster",
			"junction_pair_not_endpoint", "junction_pair_left_not_eight_connected",
			"junction_pair_right_not_eight_connected", "junction_pair_shared_station",
			"junction_pair_x_cross"},
		-- Scan-2 (M3).  Endpoint rows are the F2 counting tier and the section
		-- 6.2.3 transition stress scalars; edge rows carry the R19 joint
		-- decision under the decided U1/U2 readings; tuple rows are the
		-- per-tuple witnesses, keyed by their read-set envelope digest.
		scan2_endpoint_class = {"scan2_counting_evaluated",
			"scan2_no_selected_interval"},
		scan2_edge_class = {"scan2_exactly_one_complete_select",
			"scan2_zero_complete_reject", "scan2_multi_complete_reject",
			"scan2_duplicate_authority_reject", "scan2_selected_below_192_reject",
			"scan2_no_selected_interval"},
		scan2_tuple_class = {"scan2_tuple_complete",
			"scan2_tuple_empty_combined_clip", "scan2_tuple_clip_not_contiguous",
			"scan2_tuple_probe_invalid", "scan2_tuple_probe_wet",
			"scan2_tuple_previous_binding_unsatisfiable",
			"scan2_tuple_bank_incomplete"},
		scan2_flag = {"true", "false"},
		scan2_tuple_mode = {"direct", "diagonal_elbow", "-"},
		-- Scan-3a (M4).  The table-to-vocabulary map lives beside the
		-- projection in partition.lua's census_scan3a comment; what belongs
		-- here is the enumerable class space itself, because the M5
		-- vacuous-branch report is exactly "declared minus realized" over
		-- these lists and can never enumerate a branch some seed realized.
		--
		-- F4, analysis section 3-F4.  Table row 4 (`W` missing / non-unique /
		-- non-diagonal / not same-Bay-only raw+final) is four classes here,
		-- one of which -- W not immediately aperture-included -- that row does
		-- not name.  The wrong-tail-water-side row is decided in trace_bank
		-- rather than at resolution and is evaluated directly by Scan-3a, and
		-- terminal identity drift reads only seed-independent catalog state,
		-- so it is declared and expected vacuous.
		scan3_aperture_class = {"aperture_direct_select", "aperture_tail_select",
			"aperture_d_not_dry_equality_reject",
			"aperture_d_cardinal_water_reject", "aperture_w_not_diagonal_reject",
			"aperture_w_not_bay_water_reject", "aperture_w_foreign_water_reject",
			"aperture_w_not_aperture_included_reject",
			"aperture_shoulder_elbow_count_reject",
			"aperture_tail_wrong_water_side_reject",
			"aperture_terminal_identity_drift_reject"},
		scan3_aperture_mode = {"direct", "diagonal_shoulder", "-"},
		-- F5, analysis section 3-F5, under the 2026-08-16 pair-exclusion
		-- reading: the non-simple/zero-area and `R > 5` rows are per-pair
		-- exclusions counted on the Wing row, not seed rejects, so the only
		-- wedge-shaped reject left is the zero-count one.  The last two classes
		-- have no table row at all (empty distance-layer DAG, finite path
		-- bound) and the Chebyshev one is the section 6.4 refuted frozen
		-- universal.
		scan3_wing_class = {"wing_wedge_valid_select", "wing_missing_k_reject",
			"wing_k_chebyshev_above_four_reject", "wing_no_complete_tail_reject",
			"wing_no_wedge_valid_joint_tail_pair_reject",
			"wing_path_bound_exceeded_reject"},
		-- F3, analysis section 3-F3, over the four head Banks only; the sixteen
		-- transition-incident traces are Scan-3b.  Every class is a
		-- `bay_bank_reject` clause except the select.  Foreign-water contact
		-- has no class of its own: `bay_candidate` absorbs it, so it reaches
		-- the census as a zero-reachable-successor reject.
		scan3_bank_class = {"bank_trace_complete_select",
			"bank_terminal_unresolved_reject", "bank_start_anchor_invalid_reject",
			"bank_target_noncandidate_reject",
			"bank_zero_reachable_successor_reject", "bank_repeated_column_reject",
			"bank_x_cross_reject", "bank_reachability_frame_cap_reject",
			"bank_reachability_stack_cap_reject", "bank_main_trace_cap_reject",
			"bank_trace_envelope_empty_reject"},
		-- The realized step-class space is the cross product of these two:
		-- eight Moore directions in the declared clockwise base order times the
		-- first failing successor predicate, plus admission.  Six predicates,
		-- not the table's five: "unseen" is two separable bits and the diagonal
		-- X-cross compatibility the table lists only among the rejects is a
		-- successor admission predicate.
		scan3_step_direction = {"east", "southeast", "south", "southwest",
			"west", "northwest", "north", "northeast"},
		scan3_step_outcome = {"admitted", "previous", "seen_state",
			"seen_column", "x_cross", "noncandidate", "water_side"},
		-- Terminal reachability is not a successor predicate at all: trace_bank
		-- tests it only at branch width two or more, so a lone admitted
		-- successor is taken untested.  That asymmetry is the first class here
		-- rather than a silent case of "first pass selected".
		scan3_selection_class = {"single_admitted_untested",
			"branch_first_reachable", "branch_later_reachable",
			"branch_none_reachable", "zero_admitted_successors"},
		-- Section 6.4 / source authority section 7.2.  A negative width would
		-- already have aborted Scan-1 inside exact.bay_segment, so its class
		-- exists to be reported vacuous rather than to be reached.
		scan3_width_class = {"bay_bank_width_positive",
			"bay_bank_width_zero_event", "bay_bank_width_negative_event"},
	}
	local class_sets = {}
	for name, values in pairs(classes) do
		local set = {}
		for index = 1, #values do set[values[index]] = true end
		class_sets[name] = set
	end

	-- Per-seed site roster and row width.  `count` nil means the row kind is
	-- occupancy-driven (a junction-pair reject is only emitted when a pair
	-- fails), everything else must appear exactly `count` times per seed:
	-- "every site present" from section 6.6.2 is a count, not a hope.
	local record_rows = {
		{tag = "edge", count = 61, fields = 13, class_field = 5,
			class_set = "edge_class", extra_field = 4, extra_set = "edge_kind"},
		{tag = "perimeter", count = 3, fields = 6},
		{tag = "aperture", count = 8, fields = 16},
		{tag = "attachment", count = 8, fields = 13, class_field = 6,
			class_set = "attachment_class"},
		{tag = "junction", count = 38, fields = 7},
		{tag = "junction_pair", fields = 6, class_field = 6,
			class_set = "junction_pair_class"},
		{tag = "bay", count = 4, fields = 5},
		{tag = "scan2_endpoint", count = 8, fields = 14, class_field = 6,
			class_set = "scan2_endpoint_class", extra_field = 7,
			extra_set = "scan2_flag"},
		{tag = "scan2_edge", count = 6, fields = 10, class_field = 4,
			class_set = "scan2_edge_class", extra_field = 5,
			extra_set = "scan2_flag"},
		{tag = "scan2_tuple", fields = 16, class_field = 5,
			class_set = "scan2_tuple_class", extra_field = 7,
			extra_set = "scan2_tuple_mode", extra2_field = 11,
			extra2_set = "scan2_tuple_mode"},
		-- Scan-3a (M4).  Eight aperture incidences, eight Wings, four head
		-- Banks and four Bay bank-width rows are per-seed rosters; the step and
		-- selection rows are occupancy-driven, since a direction/outcome pair
		-- no step realized has no row and that absence is the measurement.
		{tag = "scan3_aperture", count = 8, fields = 14, class_field = 5,
			class_set = "scan3_aperture_class", extra_field = 6,
			extra_set = "scan3_aperture_mode"},
		{tag = "scan3_wing", count = 8, fields = 30, class_field = 5,
			class_set = "scan3_wing_class"},
		{tag = "scan3_bank", count = 4, fields = 12, class_field = 5,
			class_set = "scan3_bank_class"},
		{tag = "scan3_width", count = 4, fields = 19, class_field = 4,
			class_set = "scan3_width_class"},
		{tag = "scan3_step", fields = 6, class_field = 5,
			class_set = "scan3_step_outcome", extra_field = 4,
			extra_set = "scan3_step_direction"},
		{tag = "scan3_selection", fields = 8, class_field = 4,
			class_set = "scan3_selection_class"},
	}
	local record_row_by_tag = {}
	for index = 1, #record_rows do
		record_row_by_tag[record_rows[index].tag] = record_rows[index]
	end
	local prefilter_edge_count = 61

	-- Shards are per-seed intermediates, which section 6.3 forbids committing,
	-- so they live under the gitignored results tree; only the five merged
	-- artifacts reach fixtures/t2_census/.  The name shares no prefix with
	-- either pool shard pattern, and `assert_disjoint_from_pool` below proves
	-- that instead of asserting it in prose (section 6.6.1).
	local shard_directory = "tools/wp40/results/t2_census"
	local shard_pattern = "census-scan-v3-%04d-%04d.tsv"
	local pool_shard_patterns = {"shard-luajit-v3-%04d-%04d.tsv",
		"shard-luajit-%04d-%04d.tsv"}

	-- Every file whose bytes can move a census row.  The worker pins these
	-- before it loads them and re-reads them before it publishes: the extreme
	-- launcher buys the same guarantee with a per-shard `git archive` of the
	-- whole tree, which is eight full exports here for one property.
	local module_paths = {
		"mods/MAPGEN/grug_mapgen/wp40/canonical.lua",
		"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/boundary.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua",
		"mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua",
		"mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua",
		"mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua",
		"tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua",
		"tools/wp40/t2_census_authority.lua",
		"tools/wp40/t2_census_hasher.lua",
		"tools/wp40/t2_census_worker.lua",
	}

	-- The launcher-side files that decide whether and how a run starts.  A
	-- full-`W` run requires these and every module path above to be committed
	-- and unmodified, which is what makes the commit and tree in a shard header
	-- a statement about the code that produced it.
	local launcher_paths = {
		"tools/wp40/run_t2_census.sh",
		"tools/wp40/t2_census_gate.lua",
		"tools/wp40/t2_census_sha_server.py",
	}

	local function positive_integer(value, label)
		if type(value) ~= "number" or value % 1 ~= 0 or value < 0 then
			fail(label .. " is not a nonnegative integer")
		end
		return value
	end

	local function census_shard_path(first, last)
		positive_integer(first, "shard first index")
		positive_integer(last, "shard last index")
		if last < first then fail("shard range is empty") end
		if first > 99999 or last > 99999 then fail("shard range is out of range") end
		return shard_directory .. "/" .. shard_pattern:format(first, last)
	end

	local function assert_disjoint_from_pool(first, last)
		local name = shard_pattern:format(first, last)
		for index = 1, #pool_shard_patterns do
			local pool_name = pool_shard_patterns[index]:format(first, last)
			if name == pool_name then fail("census shard name collides with a pool shard") end
			local stem = pool_name:match("^(.-)%-%d")
			if stem and name:find(stem, 1, true) then
				fail("census shard name contains the pool shard stem " .. stem)
			end
		end
		return true
	end

	local function validate_census_shard_path(path, first, last)
		if type(path) ~= "string" then fail("shard path is not text") end
		if path ~= census_shard_path(first, last) then
			fail("shard path is not the canonical census path for its range")
		end
		assert_disjoint_from_pool(first, last)
		return true
	end

	-- A free run (KAT or a small explicit range) writes wherever the caller
	-- points it, but it must never land on a shard name: a 3-seed file sitting
	-- at a shard path would be resumed as a finished shard.
	local function validate_free_output_path(path)
		if type(path) ~= "string" or path == "" then fail("output path is not text") end
		local name = path:match("([^/]+)$") or path
		if name:match("^census%-scan%d*%-v%d+%-%d+%-%d+%.tsv$") then
			fail("a free census run must not write a shard file name")
		end
		if path:find(shard_directory, 1, true) then
			fail("a free census run must not write into the shard directory")
		end
		return true
	end

	-- Section 6.6.1: eight ranges covering W exactly once.  |W| is not a
	-- multiple of eight -- unlike the pool's clean 512s -- so the remainder goes
	-- to the leading shards and the cover is asserted, never assumed.
	local function shard_ranges(total)
		positive_integer(total, "W size")
		if total < worker_count then fail("W is smaller than the worker count") end
		local base = math.floor(total / worker_count)
		local remainder = total - base * worker_count
		local ranges, first = {}, 0
		for index = 1, worker_count do
			local size = base + (index <= remainder and 1 or 0)
			ranges[index] = {first = first, last = first + size - 1, size = size}
			first = first + size
		end
		if first ~= total then fail("shard ranges do not cover W") end
		return ranges
	end

	-- What a shard must agree on to be resumable: the bytes that can move a
	-- row, not the commit that happened to be checked out.  Keying resume on
	-- the commit would invalidate every finished shard the moment an unrelated
	-- docs commit landed mid-run.
	local function module_digest(read_file)
		if type(read_file) ~= "function" then fail("module digest needs a reader") end
		local lines = {}
		for index = 1, #module_paths do
			local path = module_paths[index]
			local bytes = read_file(path)
			if type(bytes) ~= "string" then fail("module bytes are missing for " .. path) end
			lines[index] = path .. "\t" .. digest_of(bytes)
		end
		return digest_of(table.concat(lines, "\n") .. "\n")
	end

	-- A gated range is one of those eight and nothing else.  Without this a
	-- single GO-token worker could take all of `W` in one process -- eight
	-- times the wall time the cost gate is written against.
	local function validate_shard_range(first, last, total)
		local ranges = shard_ranges(total)
		for index = 1, #ranges do
			if ranges[index].first == first and ranges[index].last == last then
				return index
			end
		end
		fail("range " .. tostring(first) .. ".." .. tostring(last) ..
			" is not one of the " .. worker_count .. " canonical shard ranges of W")
	end

	-- Canonical unsigned-64 decimal order: no leading zeros, so a shorter text
	-- is the smaller number and equal lengths compare lexicographically.  The
	-- seeds never pass through a Lua number.
	local function decimal_less(left, right)
		if #left ~= #right then return #left < #right end
		return left < right
	end

	local function validate_seed_text(seed, label)
		if type(seed) ~= "string" or not seed:match("^%d+$") then
			fail(label .. " is not decimal text")
		end
		if seed ~= "0" and seed:match("^0") then
			fail(label .. " has a leading zero")
		end
		if #seed > 20 or #seed == 20 and seed > "18446744073709551615" then
			fail(label .. " exceeds the unsigned 64-bit range")
		end
		return seed
	end

	-- Section 6.3: W is derived from the committed artifacts and the derivation
	-- travels with the run.  The pool term is recomputed from the corpus label
	-- rule rather than read out of the TSV, and the TSV is then required to
	-- agree row for row -- a hardcoded list, or a silently regenerated
	-- candidates file, both fail here.
	local function derive_w(corpus, candidate_bytes, hasher)
		local hash = hasher or raw_sha256
		if type(hash) ~= "function" then fail("no hasher was injected") end
		if type(corpus) ~= "table" or type(corpus.extreme_candidate) ~= "function" then
			fail("seed corpus module is missing")
		end
		if type(candidate_bytes) ~= "string" then fail("candidate rows are missing") end
		corpus.verify(hash)

		local rows, header_seen = {}, false
		for line in (candidate_bytes .. "\n"):gmatch("(.-)\n") do
			if line ~= "" then
				local fields = {}
				for field in (line .. "\t"):gmatch("(.-)\t") do
					fields[#fields + 1] = field
				end
				if fields[1] == "schema" and fields[2] ~= candidates_schema then
					fail("candidate artifact schema changed")
				end
				if fields[1] == "candidate_index" then header_seen = true
				elseif header_seen then rows[#rows + 1] = fields end
			end
		end
		if not header_seen then fail("candidate artifact has no row header") end
		if #rows ~= pool_candidate_count then
			fail("candidate artifact holds " .. #rows .. " rows, expected " ..
				pool_candidate_count)
		end

		local seeds, seen, duplicates = {}, {}, 0
		local function add(seed, label)
			validate_seed_text(seed, label)
			if seen[seed] then duplicates = duplicates + 1 return end
			seen[seed] = true
			seeds[#seeds + 1] = seed
		end
		for index = 1, #corpus.fixed do
			add(corpus.fixed[index], "corpus slot " .. index)
		end
		for index = 0, pool_candidate_count - 1 do
			local derived = corpus.extreme_candidate(index, hash)
			local row = rows[index + 1]
			if row[1] ~= tostring(index) or row[2] ~= "scored" then
				fail("candidate row " .. index .. " is not a scored row in index order")
			end
			if row[6] ~= derived.decimal or row[4] ~= derived.digest then
				fail("candidate row " .. index .. " disagrees with the corpus label rule")
			end
			add(derived.decimal, "pool candidate " .. index)
		end
		-- The two named endpoints of section 6.6: they arrive through the corpus
		-- slots, and a corpus edit that dropped one would otherwise pass here.
		if not seen["0"] or not seen["18446744073709551615"] then
			fail("W lost seed 0 or max-u64")
		end
		table.sort(seeds, decimal_less)

		local blob = table.concat(seeds, "\n") .. "\n"
		return {seeds = seeds, total = #seeds, digest = digest_of(blob),
			derivation = {
				schema = "grug_wp40_census_w_v1",
				corpus_fixed = #corpus.fixed,
				pool_candidates = pool_candidate_count,
				candidates_path = candidates_path,
				candidates_schema = candidates_schema,
				duplicates = duplicates,
				order = "ascending canonical unsigned-64 decimal",
			}}
	end

	-- Section 6.6.7.  The token is the W digest itself, so it states which seed
	-- set was approved and a worker can check it against its own derivation --
	-- which is what stops a direct worker call from starting a full-W slice now
	-- that the M1 list cap is gone.  A wrong token fails even below the free
	-- budget: a token that does not match means the caller is out of date.
	local function check_go_token(token, w_digest, seed_count)
		positive_integer(seed_count, "seed count")
		if type(w_digest) ~= "string" or #w_digest ~= 64 or
				w_digest:match("[^0-9a-f]") then
			fail("the W digest is not 64 hex characters")
		end
		if token ~= nil and token ~= "" then
			if type(token) ~= "string" or token ~= w_digest then
				fail("the GO token does not match this W: expected " .. w_digest)
			end
			return true
		end
		if seed_count > free_seed_budget then
			fail("a census run over " .. seed_count .. " seeds needs the explicit " ..
				"GO token; free runs are capped at " .. free_seed_budget ..
				" seeds (plan section 6.6.7).  This W's token is " .. w_digest)
		end
		return true
	end

	-- Section 6.6.3.  Worker-seconds are projected onto wall time at the stated
	-- worker count by taking the slowest shard, because the shards run
	-- concurrently: summing them would inflate the projection by the worker
	-- count, dividing a total by it would deflate an unbalanced run.
	local function project_wall_seconds(samples)
		if type(samples) ~= "table" or #samples == 0 then
			fail("cost projection needs at least one completed sample")
		end
		-- Seeded below zero rather than at it, so the first sample always claims
		-- `slowest`: a fleet whose first completions all land inside one second
		-- would otherwise project a nil slowest for its callers to dereference.
		local projected, slowest = -1, nil
		for index = 1, #samples do
			local sample = samples[index]
			if type(sample) ~= "table" then fail("cost sample is not a table") end
			positive_integer(sample.size, "shard size")
			positive_integer(sample.completed, "completed seeds")
			if sample.completed < 1 then fail("cost sample completed no seed") end
			if type(sample.elapsed) ~= "number" or sample.elapsed < 0 then
				fail("cost sample has no elapsed time")
			end
			local shard = sample.elapsed / sample.completed * sample.size
			if shard > projected then projected, slowest = shard, sample end
		end
		return {wall_seconds = projected, worker_count = worker_count,
			cap_seconds = wall_cap_seconds, slowest = slowest}
	end

	local function check_cost_gate(projection, cap)
		if type(projection) ~= "table" or type(projection.wall_seconds) ~= "number" then
			fail("cost projection is malformed")
		end
		local limit = cap or wall_cap_seconds
		if type(limit) ~= "number" or limit <= 0 then fail("cost cap is invalid") end
		if projection.wall_seconds > limit then
			fail(("projected %d s wall at %d workers exceeds the %d s cap " ..
				"(plan section 6.5)"):format(math.floor(projection.wall_seconds),
				worker_count, math.floor(limit)))
		end
		return true
	end

	local function split_line(line)
		local fields = {}
		for field in (line .. "\t"):gmatch("(.-)\t") do fields[#fields + 1] = field end
		return fields
	end

	local function split_lines(text)
		if type(text) ~= "string" then fail("shard text is not a string") end
		local lines = {}
		local position = 1
		while position <= #text do
			local newline = text:find("\n", position, true)
			if not newline then
				fail("shard text ends without a newline")
			end
			lines[#lines + 1] = text:sub(position, newline - 1)
			position = newline + 1
		end
		return lines
	end

	-- The shard header.  Range mode adds these lines to the M1 body; `--kat`
	-- and explicit seed lists keep the frozen M1 bytes exactly, which is what
	-- lets the pinned KAT digest stay the proof that the hasher change was
	-- digest-neutral.
	local shard_header_tags = {"schema", "vocabulary", "shard_schema",
		"shard_range", "shard_seeds", "w_digest", "w_total", "census_commit",
		"census_tree", "module_digest", "interpreter_id", "interpreter_path",
		"interpreter_version"}

	local function shard_header_lines(header)
		if type(header) ~= "table" then fail("shard header is not a table") end
		local lines = {}
		for index = 1, #shard_header_tags do
			local tag = shard_header_tags[index]
			local value = header[tag]
			if tag == "shard_range" then
				positive_integer(header.first, "shard first index")
				positive_integer(header.last, "shard last index")
				value = header.first .. "\t" .. header.last
			end
			if type(value) ~= "string" and type(value) ~= "number" then
				fail("shard header field " .. tag .. " is missing")
			end
			value = tostring(value)
			if value == "" or value:find("\n", 1, true) then
				fail("shard header field " .. tag .. " is not a single value")
			end
			lines[index] = tag .. "\t" .. value
		end
		return lines
	end

	local function parse_header(lines, expected)
		local header = {}
		for index = 1, #shard_header_tags do
			local line = lines[index]
			if type(line) ~= "string" then fail("shard header is truncated") end
			local fields = split_line(line)
			local tag = shard_header_tags[index]
			if fields[1] ~= tag then
				fail("shard header line " .. index .. " is " .. tostring(fields[1]) ..
					", expected " .. tag)
			end
			if tag == "shard_range" then
				if #fields ~= 3 then fail("shard_range needs two indices") end
				header.first = tonumber(fields[2])
				header.last = tonumber(fields[3])
				if not header.first or not header.last then
					fail("shard_range indices are not numbers")
				end
				positive_integer(header.first, "shard first index")
				positive_integer(header.last, "shard last index")
			else
				if #fields ~= 2 then fail("shard header field " .. tag .. " is malformed") end
				header[tag] = fields[2]
			end
		end
		if header.schema ~= schema then fail("shard schema is " .. tostring(header.schema)) end
		if header.shard_schema ~= shard_schema then
			fail("shard framing schema is " .. tostring(header.shard_schema))
		end
		if header.vocabulary ~= vocabulary_path then
			fail("shard vocabulary authority is " .. tostring(header.vocabulary))
		end
		if expected then
			if expected.first and header.first ~= expected.first or
					expected.last and header.last ~= expected.last then
				fail("shard range is not the range this shard was launched for")
			end
			if expected.w_digest and header.w_digest ~= expected.w_digest then
				fail("shard was produced for a different W")
			end
			if expected.census_commit and header.census_commit ~= expected.census_commit then
				fail("shard was produced at commit " .. tostring(header.census_commit))
			end
			if expected.module_digest and header.module_digest ~= expected.module_digest then
				fail("shard was produced by different module bytes: " ..
					tostring(header.module_digest))
			end
		end
		local seeds = tonumber(header.shard_seeds)
		if not seeds or seeds ~= header.last - header.first + 1 then
			fail("shard_seeds disagrees with shard_range")
		end
		header.shard_seeds = seeds
		return header
	end

	local function validate_prefilter(lines, offset)
		for index = 1, prefilter_edge_count do
			local line = lines[offset + index]
			if type(line) ~= "string" then fail("prefilter block is truncated") end
			local fields = split_line(line)
			if fields[1] ~= "prefilter" or #fields ~= 4 then
				fail("prefilter row " .. index .. " is malformed")
			end
			if not class_sets.prefilter_status[fields[3]] then
				fail("prefilter row " .. index .. " has status " .. tostring(fields[3]))
			end
			if fields[2] == "" or fields[4] == "" then
				fail("prefilter row " .. index .. " has an empty edge or reason")
			end
		end
		return offset + prefilter_edge_count
	end

	-- One seed record, checked against the contract: every declared site
	-- present exactly once per its roster count, every row the declared width,
	-- every class string drawn from the declared vocabulary, every row carrying
	-- the block's own seed.  Returns the index after `seed_end`.
	local function validate_record(lines, offset, expected_seed)
		local open_line = lines[offset + 1]
		if type(open_line) ~= "string" then fail("seed record is missing") end
		local open_fields = split_line(open_line)
		if open_fields[1] ~= "seed_begin" or #open_fields ~= 2 then
			fail("seed record does not open with seed_begin")
		end
		local seed = validate_seed_text(open_fields[2], "seed record seed")
		if expected_seed and seed ~= expected_seed then
			fail("seed record holds seed " .. seed .. ", expected " .. expected_seed)
		end
		local counts = {}
		local index = offset + 2
		while true do
			local line = lines[index]
			if type(line) ~= "string" then fail("seed record " .. seed .. " is truncated") end
			local fields = split_line(line)
			local tag = fields[1]
			if tag == "seed_end" then
				if #fields ~= 2 or fields[2] ~= seed then
					fail("seed record " .. seed .. " closes on a different seed")
				end
				break
			end
			local layout = record_row_by_tag[tag]
			if not layout then
				fail("seed record " .. seed .. " holds an unknown row tag " .. tostring(tag))
			end
			if #fields ~= layout.fields then
				fail(tag .. " row in seed " .. seed .. " has " .. #fields ..
					" fields, expected " .. layout.fields)
			end
			if fields[2] ~= seed then
				fail(tag .. " row in seed " .. seed .. " carries seed " .. tostring(fields[2]))
			end
			if layout.class_set and
					not class_sets[layout.class_set][fields[layout.class_field]] then
				fail(tag .. " row in seed " .. seed .. " has undeclared class " ..
					tostring(fields[layout.class_field]))
			end
			if layout.extra_set and
					not class_sets[layout.extra_set][fields[layout.extra_field]] then
				fail(tag .. " row in seed " .. seed .. " has undeclared kind " ..
					tostring(fields[layout.extra_field]))
			end
			if layout.extra2_set and
					not class_sets[layout.extra2_set][fields[layout.extra2_field]] then
				fail(tag .. " row in seed " .. seed .. " has undeclared kind " ..
					tostring(fields[layout.extra2_field]))
			end
			counts[tag] = (counts[tag] or 0) + 1
			index = index + 1
		end
		for row_index = 1, #record_rows do
			local layout = record_rows[row_index]
			if layout.count and (counts[layout.tag] or 0) ~= layout.count then
				fail("seed record " .. seed .. " holds " .. (counts[layout.tag] or 0) ..
					" " .. layout.tag .. " rows, expected " .. layout.count)
			end
		end
		return index, seed, counts
	end

	-- Section 6.6.2, run against a shard that is still being written: return
	-- nil when no record has closed yet, and fail hard on anything the contract
	-- forbids.  "Not ready yet" and "broken" must never look alike here.
	local function validate_first_record(text, expected)
		local lines = split_lines(text)
		if #lines < #shard_header_tags then return nil end
		local header = parse_header(lines, expected)
		local offset = #shard_header_tags
		local closed = false
		for index = offset + 1, #lines do
			if lines[index]:sub(1, 9) == "seed_end\t" then closed = true break end
		end
		if not closed then return nil end
		offset = validate_prefilter(lines, offset)
		local expected_seed = expected and expected.seeds and expected.seeds[1]
		local _, seed, counts = validate_record(lines, offset, expected_seed)
		return {seed = seed, header = header, counts = counts}
	end

	-- Section 6.6.4.  Every failure below is a loud abort, including the empty
	-- claim file a crashed worker leaves behind: a zero-length or digest-less
	-- path is unparseable, never an empty shard.
	local function verify_shard(text, expected)
		if type(text) ~= "string" then fail("shard bytes are missing") end
		if text == "" then
			fail("shard file is empty -- a claimed but unfinished worker output")
		end
		local lines = split_lines(text)
		local last_line = lines[#lines]
		local digest = last_line and last_line:match("^digest\tsha256=([0-9a-f]+)$")
		if not digest or #digest ~= 64 then
			fail("shard file has no trailing digest line -- unfinished or corrupt")
		end
		local body_length = #text - (#last_line + 1)
		local body = text:sub(1, body_length)
		local recomputed = digest_of(body)
		if recomputed ~= digest then
			fail("shard digest is " .. digest .. ", recomputed " .. recomputed)
		end
		local header = parse_header(lines, expected)
		local offset = validate_prefilter(lines, #shard_header_tags)
		local seeds, totals = {}, {}
		local expected_seeds = expected and expected.seeds
		while offset < #lines - 1 do
			local expected_seed = expected_seeds and expected_seeds[#seeds + 1]
			local next_offset, seed, counts = validate_record(lines, offset, expected_seed)
			seeds[#seeds + 1] = seed
			for tag, count in pairs(counts) do totals[tag] = (totals[tag] or 0) + count end
			offset = next_offset
		end
		if offset ~= #lines - 1 then fail("shard holds trailing text after its last record") end
		if #seeds ~= header.shard_seeds then
			fail("shard holds " .. #seeds .. " seed records, its header declares " ..
				header.shard_seeds)
		end
		if expected_seeds and #expected_seeds ~= #seeds then
			fail("shard covers " .. #seeds .. " of " .. #expected_seeds .. " expected seeds")
		end
		return {header = header, seeds = seeds, totals = totals, digest = digest}
	end

	authority.schema = schema
	authority.shard_schema = shard_schema
	authority.vocabulary_path = vocabulary_path
	authority.candidates_path = candidates_path
	authority.worker_count = worker_count
	authority.wall_cap_seconds = wall_cap_seconds
	authority.free_seed_budget = free_seed_budget
	authority.pool_candidate_count = pool_candidate_count
	authority.classes = classes
	authority.record_rows = record_rows
	authority.prefilter_edge_count = prefilter_edge_count
	authority.module_paths = module_paths
	authority.module_digest = module_digest
	authority.launcher_paths = launcher_paths
	authority.shard_directory = shard_directory
	authority.shard_header_tags = shard_header_tags
	authority.shard_header_lines = shard_header_lines
	authority.census_shard_path = census_shard_path
	authority.validate_census_shard_path = validate_census_shard_path
	authority.validate_free_output_path = validate_free_output_path
	authority.assert_disjoint_from_pool = assert_disjoint_from_pool
	authority.shard_ranges = shard_ranges
	authority.validate_shard_range = validate_shard_range
	authority.decimal_less = decimal_less
	authority.validate_seed_text = validate_seed_text
	authority.derive_w = derive_w
	authority.check_go_token = check_go_token
	authority.project_wall_seconds = project_wall_seconds
	authority.check_cost_gate = check_cost_gate
	authority.validate_first_record = validate_first_record
	authority.verify_shard = verify_shard
	authority.digest_of = digest_of
	return authority
end
