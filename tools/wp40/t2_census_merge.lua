-- WP40 T2 census merge (plan section 6, milestone M5).  Verifies a complete
-- census record set and condenses it into the five artifacts of section 6.2
-- plus the section 6.3 manifest, deterministically and without retaining a
-- single per-seed intermediate.
--
--   t2_census_merge.lua REPO SCRATCH OUT_DIR --full-w [--cost-projection TEXT]
--   t2_census_merge.lua REPO SCRATCH OUT_DIR --records PATH [PATH...]
--
-- `--full-w` reads the eight canonical shards of `W`, verifies each against
-- the authority (digest, header, range, roster counts, declared classes) and
-- requires them to cover `W` exactly once.  `--records` reads free worker
-- output -- the `--kat` roster and small explicit ranges -- which carries the
-- frozen M1 preamble instead of a shard header and therefore states no
-- provenance; the manifest records the seed set as explicit rather than
-- derived, so a KAT merge can never be read as a slice of `W`.
--
-- Section 6.6.5 makes this the carrier of the targeted `pairs()`-order
-- divergence test, and the M5 gate is the byte-identical artifact digest under
-- LuaJIT and under the vendored PUC 5.1 on the same inputs.  Publishing into
-- the committed fixtures directory therefore requires PUC: the two runs differ
-- only in which one is allowed to write.
local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
local out_dir = assert(arg[3], "output directory required")

local function safe_absolute_path(value, label)
	assert(type(value) == "string" and value:match("^/[A-Za-z0-9._/-]+$") and
		not value:find("/../", 1, true) and not value:find("/./", 1, true) and
		not value:find("//", 1, true), "unsafe " .. label)
	return value
end
safe_absolute_path(repo, "repository root")
safe_absolute_path(out_dir, "output directory")
assert(scratch:match("^/tmp/grudgelands%-wp40%-t2%-census%.[A-Za-z0-9]+$"),
	"unsafe scratch path")

local mode, record_paths, cost_projection, expected_digest = nil, {}, nil, nil
local top_up_paths = {}
local inherited_baseline_override
local argument_index = 4
while arg[argument_index] do
	local flag = arg[argument_index]
	if flag == "--full-w" then
		assert(not mode, "one mode only")
		mode = "full_w"
		argument_index = argument_index + 1
	elseif flag == "--top-up" then
		-- The roster top-up records (contracts 9.2): free worker output
		-- with the Scan-4 tiers forced on, superseding the shard record of
		-- exactly the seeds they cover.  Full-W only; the second merge
		-- invocation consumes shards plus top-up records and publishes once.
		argument_index = argument_index + 1
		while arg[argument_index] and not arg[argument_index]:match("^%-%-") do
			top_up_paths[#top_up_paths + 1] =
				safe_absolute_path(arg[argument_index], "top-up record path")
			argument_index = argument_index + 1
		end
		assert(#top_up_paths >= 1, "--top-up needs at least one path")
	elseif flag == "--inherited-baseline" then
		-- The inherited-tier regression baseline (contracts 9.3), normally
		-- the committed v2 occupied-classes artifact; overridable so the
		-- gate suite can prove the drift refusal fires.
		inherited_baseline_override = safe_absolute_path(
			assert(arg[argument_index + 1],
				"--inherited-baseline needs a path"), "inherited baseline")
		argument_index = argument_index + 2
	elseif flag == "--records" then
		assert(not mode, "one mode only")
		mode = "records"
		argument_index = argument_index + 1
		while arg[argument_index] and not arg[argument_index]:match("^%-%-") do
			record_paths[#record_paths + 1] =
				safe_absolute_path(arg[argument_index], "record path")
			argument_index = argument_index + 1
		end
		assert(#record_paths >= 1, "--records needs at least one path")
	elseif flag == "--expect-artifacts-digest" then
		-- The determinism gate, moved in front of the write.  Without it the
		-- publishing run creates the committed artifacts and only then finds out
		-- that the other interpreter disagreed, leaving six unvetted files in
		-- the tree and a retry that aborts on "already exists" rather than on
		-- the divergence that actually happened.
		expected_digest = assert(arg[argument_index + 1],
			"--expect-artifacts-digest needs a value")
		assert(#expected_digest == 64 and not expected_digest:match("[^0-9a-f]"),
			"the expected artifacts digest is not 64 hex characters")
		argument_index = argument_index + 2
	elseif flag == "--cost-projection" then
		cost_projection = assert(arg[argument_index + 1],
			"--cost-projection needs a value")
		assert(not cost_projection:find("[\t\n]"),
			"the cost projection must be a single manifest value")
		argument_index = argument_index + 2
	else
		error("unknown census merge flag " .. flag, 0)
	end
end
assert(mode, "one of --full-w or --records is required")
assert(#top_up_paths == 0 or mode == "full_w",
	"--top-up rides on --full-w only (contracts 9.2)")

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

local is_puc = _VERSION == "Lua 5.1" and rawget(_G, "jit") == nil
local puc_path = repo .. "/tools/bin/lua51"
local published_dir = repo .. "/tools/wp40/fixtures/t2_census"
local publishing = out_dir == published_dir
-- Section 6.6.5.  The committed artifacts are the PUC run's; the LuaJIT run
-- exists to be compared against them and writes elsewhere.
assert(not publishing or is_puc,
	"publishing the census artifacts requires the vendored PUC Lua 5.1 " ..
	"(plan section 6.6.5); run the LuaJIT merge into a scratch directory")
assert(not publishing or arg[-1] == puc_path,
	"publishing requires the reviewed vendored interpreter at " .. puc_path)
assert(not publishing or mode == "full_w",
	"only a full-W merge may publish: section 6.3 commits the artifacts of a " ..
	"measurement of W, and a KAT record set states no provenance at all")

local hasher = dofile(repo .. "/tools/wp40/t2_census_hasher.lua")({
	repo = repo, scratch = scratch})
local raw_sha256 = hasher.raw_sha256
local authority = dofile(repo .. "/tools/wp40/t2_census_authority.lua")({
	raw_sha256 = raw_sha256})
local digest_of = authority.digest_of
local field, site_of = authority.field, authority.site_of
local decimal_less = authority.decimal_less

-- ------------------------------------------------------------------
-- Ordered traversal.  Every table this merge folds into an artifact is a hash
-- table, and `pairs()` hands out its keys in an order that differs between
-- LuaJIT and PUC.  Nothing below iterates one directly: keys are collected,
-- sorted by a strict total order and consumed from the array.
-- ------------------------------------------------------------------
local function sorted_keys(table_value)
	local keys = {}
	for key in pairs(table_value) do keys[#keys + 1] = key end
	table.sort(keys)
	return keys
end

local function sorted_seeds(table_value)
	local seeds = {}
	for seed in pairs(table_value) do seeds[#seeds + 1] = seed end
	table.sort(seeds, decimal_less)
	return seeds
end

-- The witness rule of section 6.1: the lexicographically least realizing seed,
-- in the canonical unsigned-64 decimal order the whole census uses.  Never
-- "the first seed seen", which is what would make an artifact depend on shard
-- order or on iteration order.
--
-- The tie-break is load-bearing rather than defensive.  A site can realize the
-- same branch through more than one row of a single seed -- a Wing counts
-- seven pair-exclusion causes on one row, and a future row kind may repeat a
-- site outright -- and "the first such row" is an arrival-order choice.  The
-- section 5 divergence test found exactly that here, so the witness row is the
-- least one of the least seed and nothing about it depends on order.
local function keep_witness(entry, seed, line)
	if not entry.witness_seed or decimal_less(seed, entry.witness_seed) or
			(seed == entry.witness_seed and line < entry.witness_line) then
		entry.witness_seed, entry.witness_line = seed, line
	end
end

local function integer(text)
	if text == "-" or text == nil then return nil end
	local value = tonumber(text)
	if not value or value % 1 ~= 0 then return nil end
	return value
end

local function count_text(value)
	return ("%d"):format(value)
end

-- ------------------------------------------------------------------
-- The aggregator.  One instance folds a stream of verified records into the
-- five artifacts; a second instance exists only so the divergence test can
-- fold the same records in a different order and compare bytes.
-- ------------------------------------------------------------------
local function new_census(options)
	local strict = options.strict
	local census = {}
	local occupied, branch_realized, sink = {}, {}, {}
	local derived_occupied = {}
	local extremal = {}
	local flagged, histograms = {}, {}
	-- The D2 detached-shoulder admissions (contracts 8.5): per admission the
	-- seed, site and station, for the histogram row and the manifest's marked
	-- addendum -- the returning seeds are listed by name, never merged
	-- silently.
	local detached_admissions = {}
	local seed_list, seed_seen = {}, {}
	local class_set_of_tag = {}
	local records = 0
	local stage_rejected_seeds = 0
	local scan4_coverage = {}

	for index = 1, #authority.record_rows do
		local layout = authority.record_rows[index]
		if layout.class_set then class_set_of_tag[layout.tag] = layout.class_set end
	end
	-- A local membership memo over the authority's own declaration: the class
	-- check below runs once per classed row of every seed, and a linear scan
	-- there costs seconds over `W` under PUC.
	local declared_class = {}
	for name in pairs(authority.classes) do
		local set = {}
		local values = authority.classes[name]
		for index = 1, #values do set[values[index]] = true end
		declared_class[name] = set
	end

	local function bucket(store, key)
		local entry = store[key]
		if not entry then entry = {} store[key] = entry end
		return entry
	end

	local function note_occupied(store, family, site, branch, verdict, seed, line)
		local entry = bucket(bucket(bucket(store, family), site), branch)
		entry.verdict = verdict
		entry.rows = (entry.rows or 0) + 1
		if entry.last_seed ~= seed then
			entry.last_seed = seed
			entry.seeds = (entry.seeds or 0) + 1
		end
		keep_witness(entry, seed, line)
		return entry
	end

	local function note_branch(vocabulary, branch, site, seed)
		local entry = bucket(bucket(branch_realized, vocabulary), branch)
		entry.rows = (entry.rows or 0) + 1
		if entry.last_seed ~= seed then
			entry.last_seed = seed
			entry.seeds = (entry.seeds or 0) + 1
		end
		entry.sites = entry.sites or {}
		entry.sites[site] = true
		if not entry.witness_seed or decimal_less(seed, entry.witness_seed) or
				(seed == entry.witness_seed and site < entry.witness_site) then
			entry.witness_seed, entry.witness_site = seed, site
		end
	end

	local function note_histogram(name, key, value)
		local entry = bucket(bucket(histograms, name), key)
		entry[value] = (entry[value] or 0) + 1
	end

	local function note_flag(seed, flag, detail)
		local entry = bucket(flagged, seed)
		local reasons = entry.reasons
		if not reasons then reasons = {} entry.reasons = reasons end
		-- A set, not a list: the same seed can realize one flag at several
		-- sites and the artifact reports which sites, sorted.
		reasons[flag .. ":" .. detail] = true
	end

	local function note_extremal(family, site, scalar, value, seed)
		local entry = bucket(bucket(bucket(extremal, family), site), scalar)
		for _, bound in ipairs({"minimum", "maximum"}) do
			local held = entry[bound]
			local better
			if not held then better = true
			elseif bound == "minimum" then
				better = value < held.value or
					(value == held.value and decimal_less(seed, held.seed))
			else
				better = value > held.value or
					(value == held.value and decimal_less(seed, held.seed))
			end
			if better then entry[bound] = {value = value, seed = seed} end
		end
	end

	-- Every classed row, checked against the declared vocabulary a second time
	-- and independently of the shard verifier.  Section 6.4 requires an
	-- explicit no-branch-matched sink, and a sink that can only be reached
	-- when the verifier is bypassed is not one; this check is the merge's own.
	local function classify(tag, fields, seed, line)
		local class_set = class_set_of_tag[tag]
		if not class_set then return nil end
		local class = fields[authority.record_row_by_tag[tag].class_field]
		local site = site_of(tag, fields)
		if not declared_class[class_set][class] then
			sink[#sink + 1] = {family = tag, site = site, branch = tostring(class),
				seed = seed, line = line,
				reason = "not a declared value of " .. class_set}
			return nil
		end
		if not authority.class_verdict[class] then
			sink[#sink + 1] = {family = tag, site = site, branch = class,
				seed = seed, line = line,
				reason = "declared in " .. class_set .. " but carries no verdict"}
			return nil
		end
		local verdict = authority.class_verdict[class]
		note_occupied(occupied, tag, site, class, verdict, seed, line)
		note_branch(class_set, class, site, seed)
		return class, site
	end

	-- One complete seed record, consumed as a unit: rows are indexed by tag
	-- first and read in a declared order, so nothing here depends on the order
	-- the rows arrived in.
	function census.add_record(seed, rows)
		records = records + 1
		if seed_seen[seed] then
			error("WP40 T2 census merge: seed " .. seed .. " appears twice", 0)
		end
		seed_seen[seed] = true
		seed_list[#seed_list + 1] = seed

		-- The v4 two-shape record grammar, re-checked here independently of
		-- the verifier like the class vocabulary below: a stage-rejected seed
		-- contributes its occupied row and its flag and nothing else -- no
		-- extremal scalar, no histogram, no derived branch -- and that is a
		-- checked property of the record rather than an accident of which
		-- folds happen to read which tags.  Only the synthetic divergence
		-- fold, which deliberately mixes every declared class into one seed,
		-- runs without this check.
		if strict and rows.stage_reject then
			if #rows.stage_reject ~= 1 then
				error("WP40 T2 census merge: seed " .. seed .. " holds " ..
					#rows.stage_reject .. " stage_reject rows", 0)
			end
			for tag in pairs(rows) do
				if tag ~= "stage_reject" then
					error("WP40 T2 census merge: seed " .. seed ..
						" mixes a stage_reject row with " .. tag .. " rows", 0)
				end
			end
		end
		if rows.stage_reject then
			stage_rejected_seeds = stage_rejected_seeds + 1
		end

		for tag_index = 1, #authority.record_rows do
			local layout = authority.record_rows[tag_index]
			local bucket_rows = rows[layout.tag]
			if bucket_rows then
				for row_index = 1, #bucket_rows do
					local fields = bucket_rows[row_index]
					classify(layout.tag, fields, seed, table.concat(fields, "\t"))
				end
			end
		end

		-- Section 6.2.3's flagged term.
		for rule_index = 1, #authority.flag_rules do
			local rule = authority.flag_rules[rule_index]
			local bucket_rows = rows[rule.row]
			if bucket_rows then
				for row_index = 1, #bucket_rows do
					local fields = bucket_rows[row_index]
					local value = field(rule.row, fields, rule.column)
					local hit
					if rule.test == "equals" then hit = value == rule.value
					elseif rule.test == "any" then
						-- Row presence is the event; the column read above still
						-- proves the row carries its declared width.
						hit = true
					elseif rule.test == "present" then
						-- The detached-shoulder admission flag (contracts 9.2,
						-- branch A): the column against its "-" placeholder.
						hit = value ~= nil and value ~= "-" and value ~= ""
					else
						local number = integer(value)
						hit = number ~= nil and number >= rule.value
					end
					if hit then
						note_flag(seed, rule.flag, site_of(rule.row, fields))
					end
				end
			end
		end

		-- Section 6.2.3's per-site extremal term.  A family may draw its
		-- sites from more than one row kind since Scan-3b: the Bank family
		-- reads the four head Banks off scan3_bank rows and the sixteen
		-- transition-incident Banks off scan3b_bank rows (contracts 9.1).
		for family_index = 1, #authority.extremal_families do
			local family = authority.extremal_families[family_index]
			local family_rows = family.rows or {family.row}
			for tag_index = 1, #family_rows do
				local row_tag = family_rows[tag_index]
				local bucket_rows = rows[row_tag]
				if bucket_rows then
				for row_index = 1, #bucket_rows do
					local fields = bucket_rows[row_index]
					local site = site_of(row_tag, fields)
					if site ~= family.excluded_site then
						for scalar_index = 1, #family.scalars do
							local scalar = family.scalars[scalar_index]
							local derived = authority.derived_scalars[scalar]
							local value
							if derived then
								for from_index = 1, #derived.from do
									local candidate =
										integer(field(row_tag, fields, derived.from[from_index]))
									if candidate and (not value or candidate > value) then
										value = candidate
									end
								end
							else
								value = integer(field(row_tag, fields, scalar))
							end
							if value then
								note_extremal(family.family, site, scalar, value, seed)
							end
						end
					elseif strict then
						-- The exclusion is a claim about the site, so it is verified
						-- rather than assumed: a Holy band that ever displaced would
						-- silently drop a real extremal seed from Scan-4's input.
						for scalar_index = 1, #family.scalars do
							local value = integer(field(row_tag, fields,
								family.scalars[scalar_index]))
							if value ~= 0 then
								error("WP40 T2 census merge: " .. family.excluded_site ..
									" realized " .. family.scalars[scalar_index] .. "=" ..
									tostring(value) .. " at seed " .. seed ..
									"; section 6.2.3 excludes it as a fixed record", 0)
							end
						end
					end
				end
				end
			end
		end

		-- The Scan-4 coverage substrate (contracts 9.6): the merge
		-- re-verifies member/face/whole coverage against the consumed
		-- membership independently of the shard verifier.
		local membership_rows = rows.scan4_membership
		if membership_rows and #membership_rows >= 1 then
			scan4_coverage[seed] = {
				member = field("scan4_membership", membership_rows[1],
					"member"),
				source = field("scan4_membership", membership_rows[1],
					"source"),
				faces = #(rows.scan4_face or {}),
				wholes = #(rows.scan4_whole or {})}
		end

		census.fold_derived(seed, rows)
		census.fold_histograms(seed, rows)
	end

	-- Section-3 table rows with no class column of their own.  Their occupancy
	-- is a fact about the same records and is reported as such; leaving them
	-- out would make the coverage report claim less than the scan measured.
	function census.fold_derived(seed, rows)
		for index = 1, #authority.derived_branches do
			local declaration = authority.derived_branches[index]
			local bucket_rows = rows[declaration.row]
			if bucket_rows then
				for row_index = 1, #bucket_rows do
					local fields = bucket_rows[row_index]
					local line = table.concat(fields, "\t")
					local site = site_of(declaration.row, fields)
					local hit = false
					if declaration.branch == "edge_singleton_interval" then
						hit = (integer(field("edge", fields, "singleton_count")) or 0) > 0
					elseif declaration.branch == "scan2_incidence_not_eligible" then
						local first = integer(field("scan2_endpoint", fields, "first"))
						local finish = integer(field("scan2_endpoint", fields, "finish"))
						local eligible =
							integer(field("scan2_endpoint", fields, "eligible_count"))
						hit = first ~= nil and finish ~= nil and eligible ~= nil and
							finish - first + 1 - eligible > 0
					elseif declaration.branch == "junction_pair_pass" then
						hit = (integer(field("junction", fields, "pass_count")) or 0) > 0
					else
						error("WP40 T2 census merge: derived branch " ..
							declaration.branch .. " has no predicate", 0)
					end
					if hit then
						note_occupied(derived_occupied, declaration.row, site,
							declaration.branch, declaration.verdict, seed, line)
					end
				end
			end
		end
	end

	-- Section 6.2.5, the named distributions plus Scan-3a's own.
	function census.fold_histograms(seed, rows)
		local edges = rows.edge
		if edges then
			for index = 1, #edges do
				note_histogram("edge_interval_count", field("edge", edges[index], "id"),
					field("edge", edges[index], "interval_count"))
			end
		end
		local attachments = rows.attachment
		if attachments then
			for index = 1, #attachments do
				note_histogram("attachment_chebyshev_distance",
					field("attachment", attachments[index], "id"),
					field("attachment", attachments[index], "distance"))
			end
		end
		local junctions = rows.junction
		if junctions then
			for index = 1, #junctions do
				local fields = junctions[index]
				local id = field("junction", fields, "id")
				local pairs_total = integer(field("junction", fields, "pair_count")) or 0
				local passed = integer(field("junction", fields, "pass_count")) or 0
				local entry = bucket(bucket(histograms, "junction_pair_pass_rate"), id)
				entry.pass = (entry.pass or 0) + passed
				entry.fail = (entry.fail or 0) + (pairs_total - passed)
			end
		end
		local bays = rows.bay
		if bays then
			for index = 1, #bays do
				note_histogram("bay_fill_count", field("bay", bays[index], "id"),
					field("bay", bays[index], "fill_count"))
			end
		end
		-- The joint (eligible, R16-success, complete) distribution of section
		-- 6.2.5.  Completion is a property of the joint tuple and therefore of
		-- the edge, not of one endpoint: the two counting numbers come from the
		-- endpoint row and the complete count from its edge's row, which is the
		-- only reading of "per transition endpoint" the record supports.  The
		-- per-edge (tuples, complete) distribution below is the exactly
		-- measured form and is emitted beside it.
		local complete_by_edge, tuples_by_edge = {}, {}
		local scan2_edges = rows.scan2_edge
		if scan2_edges then
			for index = 1, #scan2_edges do
				local fields = scan2_edges[index]
				local edge_id = field("scan2_edge", fields, "edge_id")
				complete_by_edge[edge_id] = field("scan2_edge", fields, "complete_count")
				tuples_by_edge[edge_id] = field("scan2_edge", fields, "tuple_count")
				note_histogram("scan2_edge_tuple_complete", edge_id,
					"tuples=" .. field("scan2_edge", fields, "tuple_count") ..
					" complete=" .. field("scan2_edge", fields, "complete_count") ..
					" duplicate=" .. field("scan2_edge", fields, "duplicate_count"))
			end
		end
		local endpoints = rows.scan2_endpoint
		if endpoints then
			for index = 1, #endpoints do
				local fields = endpoints[index]
				local edge_id = field("scan2_endpoint", fields, "edge_id")
				note_histogram("scan2_endpoint_joint",
					field("scan2_endpoint", fields, "id"),
					"eligible=" .. field("scan2_endpoint", fields, "eligible_count") ..
					" success=" .. field("scan2_endpoint", fields, "success_count") ..
					" complete=" .. tostring(complete_by_edge[edge_id] or "-"))
				note_histogram("scan2_endpoint_direct_elbow",
					field("scan2_endpoint", fields, "id"),
					"direct=" .. field("scan2_endpoint", fields, "direct_count") ..
					" elbow=" .. field("scan2_endpoint", fields, "elbow_count"))
			end
		end
		local apertures = rows.scan3_aperture
		if apertures then
			for index = 1, #apertures do
				local fields = apertures[index]
				note_histogram("scan3_aperture_mode", site_of("scan3_aperture", fields),
					field("scan3_aperture", fields, "mode"))
				local station = field("scan3_aperture", fields, "detached")
				if station and station ~= "-" then
					note_histogram("scan3_aperture_detached",
						site_of("scan3_aperture", fields), "station=" .. station)
					detached_admissions[#detached_admissions + 1] = {seed = seed,
						site = site_of("scan3_aperture", fields),
						station = station}
				end
			end
		end
		local wings = rows.scan3_wing
		if wings then
			for index = 1, #wings do
				local fields = wings[index]
				local id = field("scan3_wing", fields, "id")
				note_histogram("scan3_wing_wedge_valid_count", id,
					field("scan3_wing", fields, "wedge_valid_count"))
				note_histogram("scan3_wing_selected_rank", id,
					"raw=" .. field("scan3_wing", fields, "selected_raw_rank") ..
					" structural=" ..
					field("scan3_wing", fields, "selected_structural_rank"))
				-- A Wing that rejects before its K stations resolve emits `-` on
				-- both sides, and folding that into a measured zero is exactly
				-- the "measured positive" / "could not be excluded" confusion
				-- section 6.4 forbids.  The maximum is taken over the sides that
				-- actually resolved -- a side above four already rejected the
				-- Wing, so it is still visible -- and a Wing with neither side
				-- resolved gets the unmeasured bucket.
				local largest
				for _, side in ipairs({"negative_chebyshev", "positive_chebyshev"}) do
					local value = integer(field("scan3_wing", fields, side))
					if value and (not largest or value > largest) then largest = value end
				end
				note_histogram("scan3_wing_chebyshev_k_j", id,
					largest and count_text(largest) or "-")
				if largest and largest > 4 then
					note_histogram("universal_event", "chebyshev_k_j_above_four", id)
				end
				local above_five =
					integer(field("scan3_wing", fields, "exclusion_wedge_radius_above_five"))
				if above_five and above_five > 0 then
					note_histogram("universal_event", "wedge_radius_above_five", id)
				end
				for cause_index = 1, #authority.wing_exclusion_causes do
					local cause = authority.wing_exclusion_causes[cause_index]
					local count = integer(field("scan3_wing", fields,
						"exclusion_" .. cause)) or 0
					if count > 0 then
						note_occupied(occupied, "wing_exclusion", id, cause,
							authority.class_verdict[cause], seed,
							table.concat(fields, "\t"))
						note_branch(authority.exclusion_vocabulary, cause, id, seed)
						note_histogram("scan3_wing_exclusion", id .. ":" .. cause,
							count_text(count))
					end
				end
			end
		end
		local widths = rows.scan3_width
		if widths then
			for index = 1, #widths do
				local fields = widths[index]
				local id = field("scan3_width", fields, "id")
				note_histogram("scan3_bay_bank_width_class", id,
					field("scan3_width", fields, "class"))
				note_histogram("scan3_bay_bank_width_nodes", id,
					field("scan3_width", fields, "min_width_nodes"))
				note_histogram("scan3_bay_bank_column_bound_nodes", id,
					field("scan3_width", fields, "column_bound_nodes"))
				if field("scan3_width", fields, "class") ~= "bay_bank_width_positive" then
					note_histogram("universal_event", "bay_bank_width_not_positive", id)
				end
			end
		end
		local steps = rows.scan3_step
		if steps then
			for index = 1, #steps do
				local fields = steps[index]
				note_histogram("scan3_step_class",
					field("scan3_step", fields, "bank_id") .. ":" ..
					field("scan3_step", fields, "direction"),
					field("scan3_step", fields, "outcome"))
			end
		end
		local selections = rows.scan3_selection
		if selections then
			for index = 1, #selections do
				local fields = selections[index]
				note_histogram("scan3_selection_class",
					field("scan3_selection", fields, "bank_id"),
					field("scan3_selection", fields, "class"))
			end
		end
		local banks = rows.scan3_bank
		if banks then
			for index = 1, #banks do
				local fields = banks[index]
				note_histogram("scan3_bank_branch_steps",
					field("scan3_bank", fields, "id"),
					field("scan3_bank", fields, "branch_step_count"))
			end
		end
		-- Scan-3b (contracts 9.1): the sixteen-Bank counterparts of the
		-- Scan-3a step/selection/branch histograms, plus the
		-- bank-incomplete attribution histogram -- which incident Bank died
		-- and the kind and mode of its far terminal.
		local scan3b_steps = rows.scan3b_step
		if scan3b_steps then
			for index = 1, #scan3b_steps do
				local fields = scan3b_steps[index]
				note_histogram("scan3b_step_class",
					field("scan3b_step", fields, "bank_id") .. ":" ..
					field("scan3b_step", fields, "direction"),
					field("scan3b_step", fields, "outcome"))
			end
		end
		local scan3b_selections = rows.scan3b_selection
		if scan3b_selections then
			for index = 1, #scan3b_selections do
				local fields = scan3b_selections[index]
				note_histogram("scan3b_selection_class",
					field("scan3b_selection", fields, "bank_id"),
					field("scan3b_selection", fields, "class"))
			end
		end
		local scan3b_banks = rows.scan3b_bank
		if scan3b_banks then
			for index = 1, #scan3b_banks do
				local fields = scan3b_banks[index]
				note_histogram("scan3b_bank_branch_steps",
					field("scan3b_bank", fields, "id"),
					field("scan3b_bank", fields, "branch_step_count"))
			end
		end
		local attributions = rows.scan3b_attribution
		if attributions then
			for index = 1, #attributions do
				local fields = attributions[index]
				note_histogram("scan3b_attribution",
					site_of("scan3b_attribution", fields),
					"far=" .. field("scan3b_attribution", fields, "far_kind") ..
					":" .. field("scan3b_attribution", fields, "far_mode") ..
					" count=" .. field("scan3b_attribution", fields, "count"))
			end
		end
		-- Scan-4: membership occupancy and the per-seed Whole summary
		-- distribution (the H38 g/o/r/m result, pinned per seed by the KAT
		-- and distributed here).
		local memberships = rows.scan4_membership
		if memberships then
			for index = 1, #memberships do
				local fields = memberships[index]
				note_histogram("scan4_membership",
					field("scan4_membership", fields, "member"),
					field("scan4_membership", fields, "source"))
			end
		end
		local wholes = rows.scan4_whole
		if wholes then
			for index = 1, #wholes do
				local fields = wholes[index]
				note_histogram("scan4_whole_gorm",
					field("scan4_whole", fields, "class"),
					"g=" .. field("scan4_whole", fields, "g") ..
					" o=" .. field("scan4_whole", fields, "o") ..
					" r=" .. field("scan4_whole", fields, "r") ..
					" m=" .. field("scan4_whole", fields, "m"))
			end
		end
	end

	function census.state()
		return {occupied = occupied, derived = derived_occupied,
			branch_realized = branch_realized, sink = sink, extremal = extremal,
			flagged = flagged, histograms = histograms, seeds = seed_list,
			records = records, stage_rejected_seeds = stage_rejected_seeds,
			detached = detached_admissions, scan4_coverage = scan4_coverage}
	end

	return census
end

-- ------------------------------------------------------------------
-- Artifact rendering.  Every emitted line is built from sorted keys and
-- formatted integers; no float, no clock and no iteration order reaches an
-- artifact byte.
-- ------------------------------------------------------------------
local function render_occupied(state, header)
	local lines = {"schema\tgrug_wp40_census_occupied_classes_v3",
		"scan_schema\t" .. authority.schema,
		"seed_set\t" .. header.seed_set,
		"seeds\t" .. count_text(#state.seeds),
		"column\toccupied\tfamily\tsite\tbranch\tverdict\tuniversal\t" ..
			"seed_count\trow_count\twitness_seed",
		"column\tderived\tfamily\tsite\tbranch\tverdict\tseed_count\t" ..
			"row_count\twitness_seed",
		"column\twitness\tfamily\tsite\tbranch\twitness_row (verbatim, from field 5)",
		"column\tno_branch_matched\tfamily\tsite\tbranch\tseed\treason\t" ..
			"row (verbatim, from field 7)"}
	local findings, events, universals = 0, 0, 0
	local stage_reject_seeds = 0
	local witnesses = {}
	local occupied_rows = 0
	local families = sorted_keys(state.occupied)
	for family_index = 1, #families do
		local family = families[family_index]
		local sites = sorted_keys(state.occupied[family])
		for site_index = 1, #sites do
			local site = sites[site_index]
			local branches = sorted_keys(state.occupied[family][site])
			for branch_index = 1, #branches do
				local branch = branches[branch_index]
				local entry = state.occupied[family][site][branch]
				local universal = authority.refuted_universal[branch]
				if entry.verdict == "REJECTED" then findings = findings + 1 end
				if entry.verdict == "EVENT" then events = events + 1 end
				if universal then universals = universals + 1 end
				-- Each stage-rejected seed realizes exactly one stage_reject
				-- row (the two-shape grammar), so the (site, branch) buckets
				-- partition the seeds and this sum is the seed count.
				if family == "stage_reject" then
					stage_reject_seeds = stage_reject_seeds + entry.seeds
				end
				occupied_rows = occupied_rows + 1
				lines[#lines + 1] = table.concat({"occupied", family, site, branch,
					entry.verdict, universal or "-", count_text(entry.seeds),
					count_text(entry.rows), entry.witness_seed}, "\t")
				witnesses[#witnesses + 1] = table.concat({"witness", family, site,
					branch, entry.witness_line}, "\t")
			end
		end
	end
	local derived_families = sorted_keys(state.derived)
	for family_index = 1, #derived_families do
		local family = derived_families[family_index]
		local sites = sorted_keys(state.derived[family])
		for site_index = 1, #sites do
			local site = sites[site_index]
			local branches = sorted_keys(state.derived[family][site])
			for branch_index = 1, #branches do
				local branch = branches[branch_index]
				local entry = state.derived[family][site][branch]
				lines[#lines + 1] = table.concat({"derived", family, site, branch,
					entry.verdict, count_text(entry.seeds), count_text(entry.rows),
					entry.witness_seed}, "\t")
			end
		end
	end
	for index = 1, #witnesses do lines[#lines + 1] = witnesses[index] end
	-- Section 6.4's sink.  It is emitted sorted like everything else and its
	-- emptiness is stated in the summary, so a reader never has to infer a
	-- zero from an absent block.
	local sink_lines = {}
	for index = 1, #state.sink do
		local entry = state.sink[index]
		sink_lines[index] = table.concat({"no_branch_matched", entry.family,
			entry.site, entry.branch, entry.seed, entry.reason, entry.line}, "\t")
	end
	table.sort(sink_lines)
	for index = 1, #sink_lines do lines[#lines + 1] = sink_lines[index] end
	lines[#lines + 1] = table.concat({"summary",
		"occupied=" .. count_text(occupied_rows),
		"findings=" .. count_text(findings),
		"events=" .. count_text(events),
		"refuted_universals=" .. count_text(universals),
		"stage_reject_seeds=" .. count_text(stage_reject_seeds),
		"no_branch_matched=" .. count_text(#state.sink)}, "\t")
	return table.concat(lines, "\n") .. "\n",
		{occupied = occupied_rows, findings = findings, events = events,
			universals = universals, stage_rejects = stage_reject_seeds,
			sink = #state.sink}
end

local function render_vacuous(state)
	local lines = {"schema\tgrug_wp40_census_vacuous_branches_v3",
		"scan_schema\t" .. authority.schema,
		"column\tbranch\tvocabulary\tbranch\tverdict\tstatus\trealization\t" ..
			"sites\tseeds\twitness_seed\tnote",
		"column\tderived\tvocabulary\tbranch\tverdict\trealization\tnote",
		"column\tunmeasured\tvocabulary\tbranch\treason"}
	local universe = authority.branch_universe()
	local vacuous, realized = 0, 0
	for index = 1, #universe do
		local declared = universe[index]
		local by_vocabulary = state.branch_realized[declared.vocabulary]
		local entry = by_vocabulary and by_vocabulary[declared.branch]
		local realization = entry and "realized" or "vacuous"
		if entry then realized = realized + 1 else vacuous = vacuous + 1 end
		local site_count = 0
		if entry then
			local sites = sorted_keys(entry.sites)
			site_count = #sites
		end
		lines[#lines + 1] = table.concat({"branch", declared.vocabulary,
			declared.branch, declared.verdict, declared.status, realization,
			count_text(site_count), count_text(entry and entry.seeds or 0),
			entry and entry.witness_seed or "-",
			declared.note ~= "" and declared.note or "-"}, "\t")
	end
	local derived_realized = {}
	local families = sorted_keys(state.derived)
	for family_index = 1, #families do
		local family = families[family_index]
		local sites = sorted_keys(state.derived[family])
		for site_index = 1, #sites do
			local branches = sorted_keys(state.derived[family][sites[site_index]])
			for branch_index = 1, #branches do
				derived_realized[branches[branch_index]] = true
			end
		end
	end
	for index = 1, #authority.derived_branches do
		local declaration = authority.derived_branches[index]
		lines[#lines + 1] = table.concat({"derived", declaration.vocabulary,
			declaration.branch, declaration.verdict,
			derived_realized[declaration.branch] and "realized" or "vacuous",
			declaration.note .. " [" .. declaration.row .. "." ..
				declaration.predicate .. "]"}, "\t")
	end
	for index = 1, #authority.unmeasured_branches do
		local declaration = authority.unmeasured_branches[index]
		lines[#lines + 1] = table.concat({"unmeasured", declaration.vocabulary,
			declaration.branch, declaration.reason}, "\t")
	end
	lines[#lines + 1] = table.concat({"summary",
		"declared=" .. count_text(#universe),
		"realized=" .. count_text(realized),
		"vacuous=" .. count_text(vacuous),
		"derived=" .. count_text(#authority.derived_branches),
		"unmeasured=" .. count_text(#authority.unmeasured_branches)}, "\t")
	return table.concat(lines, "\n") .. "\n",
		{declared = #universe, realized = realized, vacuous = vacuous}
end

local function render_seed_set(state, header)
	local lines = {"schema\tgrug_wp40_census_scan4_seed_set_v3",
		"scan_schema\t" .. authority.schema,
		"seed_set\t" .. header.seed_set,
		"column\textremal\tfamily\tsite\tscalar\tbound\tvalue\tseed",
		"column\topen\tfamily\tsites\tscan\treason",
		"column\texcluded\tfamily\tsite\treason",
		"column\tseed\tdecimal\tterms\tdetail",
		"column\tterm\tname\tseeds\tderivation"}
	local union = {}
	local function add_union(seed, term)
		local entry = union[seed]
		if not entry then entry = {terms = {}} union[seed] = entry end
		entry.terms[term] = true
	end

	-- Term 1: the flagged seeds.
	local flagged_seeds = sorted_seeds(state.flagged)
	for index = 1, #flagged_seeds do add_union(flagged_seeds[index], "flagged") end

	-- Term 2: the per-site extremal seeds over the 153-site roster.
	local extremal_seeds, covered_sites, open_sites = 0, 0, 0
	for family_index = 1, #authority.extremal_families do
		local family = authority.extremal_families[family_index]
		local measured = state.extremal[family.family] or {}
		local sites = sorted_keys(measured)
		covered_sites = covered_sites + #sites
		for site_index = 1, #sites do
			local site = sites[site_index]
			local scalars = sorted_keys(measured[site])
			for scalar_index = 1, #scalars do
				local scalar = scalars[scalar_index]
				local entry = measured[site][scalar]
				for _, bound in ipairs({"maximum", "minimum"}) do
					local held = entry[bound]
					if held then
						lines[#lines + 1] = table.concat({"extremal", family.family,
							site, scalar, bound, count_text(held.value), held.seed}, "\t")
						add_union(held.seed, "extremal")
					end
				end
			end
		end
		if family.excluded_site then
			lines[#lines + 1] = table.concat({"excluded", family.family,
				family.excluded_site, family.excluded_reason}, "\t")
		end
		-- `sites` already counts what this contract's scans reach: the roster
		-- excludes the fixed Holy band, and a family whose sites are only
		-- partly in scope declares how many, so the open remainder is a
		-- reported number rather than a silent shortfall.  The open sites are
		-- named one per line, because "sixteen Banks are Scan-3b" is a number
		-- and the Scan-3b work list is the names.
		local declared = family.scanned_sites or family.sites
		if family.scanned_sites then
			local missing = family.sites - family.scanned_sites
			open_sites = open_sites + missing
			local named = header.open_sites and header.open_sites[family.family]
			if named then
				if header.strict and #named ~= missing then
					error("WP40 T2 census merge: the " .. family.family ..
						" family names " .. #named .. " open sites, its roster " ..
						"declares " .. missing, 0)
				end
				for open_index = 1, #named do
					lines[#lines + 1] = table.concat({"open", family.family,
						named[open_index], family.open_scan, family.open_reason}, "\t")
				end
			else
				lines[#lines + 1] = table.concat({"open", family.family, "-",
					family.open_scan, family.open_reason}, "\t")
			end
		end
		if header.strict and #sites ~= declared then
			error("WP40 T2 census merge: the " .. family.family ..
				" extremal family covered " .. #sites .. " of " .. declared ..
				" scanned sites", 0)
		end
	end
	for seed in pairs(union) do
		if union[seed].terms.extremal then extremal_seeds = extremal_seeds + 1 end
	end

	-- Term 3: the four measured winner slots, re-derived from the committed
	-- label rule rather than copied, and term 4: the fixed corpus.
	for index = 1, #header.winners do
		add_union(header.winners[index].decimal, "winner")
	end
	for index = 1, #header.corpus do add_union(header.corpus[index], "corpus") end

	local seeds = sorted_seeds(union)
	for index = 1, #seeds do
		local seed = seeds[index]
		local terms = sorted_keys(union[seed].terms)
		local detail = "-"
		local flags = state.flagged[seed]
		if flags then
			local reasons = sorted_keys(flags.reasons)
			detail = table.concat(reasons, ",")
		end
		lines[#lines + 1] = table.concat({"seed", seed,
			table.concat(terms, ","), detail}, "\t")
	end
	lines[#lines + 1] = table.concat({"term", "flagged",
		count_text(#flagged_seeds),
		"any rare class occupied: fills > 0, tail mode, multi-interval, " ..
		"two or more R16 candidates, any branching step, fragment-bearing " ..
		"attachment (analysis 3-F8), classified stage reject (analysis 3-F9; " ..
		"scannable by Scan-4 once the collected correction closes its class), " ..
		"detached-shoulder admission (contracts 9.2, RULED 2026-08-19 " ..
		"branch A: the rarest occupied configuration over W joins the flag " ..
		"vocabulary and the vocabulary hole closes for good)"}, "\t")
	lines[#lines + 1] = table.concat({"term", "extremal",
		count_text(extremal_seeds),
		"per-site minimum and maximum of the section 6.2.3 stress scalars over " ..
		count_text(covered_sites) .. " of " ..
		count_text(authority.extremal_site_total) .. " structural sites, " ..
		count_text(open_sites) .. " open until Scan-3b; ties to the " ..
		"lexicographically least seed"}, "\t")
	lines[#lines + 1] = table.concat({"term", "winners",
		count_text(#header.winners),
		"slots 28-31 of the E0 pool, read from the committed conformance gate " ..
		"and re-derived from the corpus label rule"}, "\t")
	lines[#lines + 1] = table.concat({"term", "corpus",
		count_text(#header.corpus), "the 27 fixed corpus slots"}, "\t")
	lines[#lines + 1] = table.concat({"summary",
		"union_seeds=" .. count_text(#seeds),
		"sites_declared=" .. count_text(authority.extremal_site_total),
		"sites_covered=" .. count_text(covered_sites),
		"sites_open=" .. count_text(open_sites)}, "\t")
	return table.concat(lines, "\n") .. "\n",
		{union = #seeds, covered = covered_sites, open = open_sites,
			seeds = seeds}
end

local function render_prefilter(prefilter, agreeing, verified_seeds)
	local lines = {"schema\tgrug_wp40_census_prefilter_discharge_v3",
		"scan_schema\t" .. authority.schema,
		"column\tprefilter\tedge\tstatus\treason"}
	local discharged, scanned = 0, 0
	for index = 1, #prefilter do
		local row = prefilter[index]
		if row.status == "discharged" then discharged = discharged + 1
		else scanned = scanned + 1 end
		lines[#lines + 1] = table.concat({"prefilter", row.edge_id, row.status,
			row.reason}, "\t")
	end
	lines[#lines + 1] = table.concat({"summary",
		"edges=" .. count_text(#prefilter),
		"discharged=" .. count_text(discharged),
		"scanned=" .. count_text(scanned),
		"inputs_agreeing=" .. count_text(agreeing),
		"seeds_verifying_interval_count_one=" .. count_text(verified_seeds)}, "\t")
	return table.concat(lines, "\n") .. "\n",
		{discharged = discharged, scanned = scanned}
end

local function render_histograms(state)
	local lines = {"schema\tgrug_wp40_census_histograms_v3",
		"scan_schema\t" .. authority.schema,
		"column\thist\tname\tkey\tbucket\tcount"}
	local names = sorted_keys(state.histograms)
	for name_index = 1, #names do
		local name = names[name_index]
		local keys = sorted_keys(state.histograms[name])
		for key_index = 1, #keys do
			local key = keys[key_index]
			local buckets = sorted_keys(state.histograms[name][key])
			for bucket_index = 1, #buckets do
				local bucket_name = buckets[bucket_index]
				lines[#lines + 1] = table.concat({"hist", name, key,
					tostring(bucket_name),
					count_text(state.histograms[name][key][bucket_name])}, "\t")
			end
		end
	end
	-- The three section-6.4 universals get an explicit line each, including a
	-- zero: a permanent zero that a reader has to infer from an absent row is
	-- how a dominated branch and an untested one come to look alike.
	local events = state.histograms.universal_event or {}
	local function event_total(key)
		local total = 0
		local entry = events[key]
		if entry then
			local sites = sorted_keys(entry)
			for index = 1, #sites do total = total + entry[sites[index]] end
		end
		return total
	end
	lines[#lines + 1] = table.concat({"universal", "chebyshev_k_j_above_four",
		count_text(event_total("chebyshev_k_j_above_four")),
		"section 6.4 refuted-frozen-universal event; occupancy is a finding"}, "\t")
	lines[#lines + 1] = table.concat({"universal", "wedge_radius_above_five",
		count_text(event_total("wedge_radius_above_five")),
		"dominated by the Chebyshev guard: R = 1 + max Chebyshev(K,J) <= 5 " ..
		"identically, so this zero is expected and not evidence of coverage"}, "\t")
	lines[#lines + 1] = table.concat({"universal", "bay_bank_width_not_positive",
		count_text(event_total("bay_bank_width_not_positive")),
		"section 6.4 `w = 0` event, including the unbounded class where every " ..
		"sampled station stayed positive and the exact per-column bound could " ..
		"not rule out a collapse between them"}, "\t")
	lines[#lines + 1] = "summary\thistograms=" .. count_text(#names)
	return table.concat(lines, "\n") .. "\n"
end

-- ------------------------------------------------------------------
-- The targeted `pairs()`-order divergence test (plan section 5, section
-- 6.6.5).  Two halves, because either alone proves nothing.  The probe half
-- shows that this runtime's `pairs()` really does hand out a non-sorted order,
-- so the invariance half is not passing vacuously -- a gate that cannot fail
-- is the failure mode this branch has already shipped twice.  The invariance
-- half folds a synthetic record set covering every declared class through the
-- whole artifact construction twice, in two different orders, and requires
-- byte-identical output.
-- ------------------------------------------------------------------
local function probe_pairs_order()
	local probe, expected = {}, {}
	for index = 1, 64 do
		local key = ("probe-%02d-%s"):format(index, string.rep("x", index % 7))
		probe[key] = index
		expected[#expected + 1] = key
	end
	table.sort(expected)
	local observed = {}
	for key in pairs(probe) do observed[#observed + 1] = key end
	local sorted_already = #observed == #expected
	if sorted_already then
		for index = 1, #observed do
			if observed[index] ~= expected[index] then sorted_already = false break end
		end
	end
	return not sorted_already
end

local function synthetic_records()
	local seeds = {"7", "42", "1013"}
	local records = {}
	for seed_index = 1, #seeds do
		local rows = {}
		for layout_index = 1, #authority.record_rows do
			local layout = authority.record_rows[layout_index]
			local values = layout.class_set and authority.classes[layout.class_set] or
				{false}
			local bucket = {}
			for value_index = 1, #values do
				for site_index = 1, 2 do
					local fields = {}
					for column = 1, #layout.columns do
						local name = layout.columns[column]
						if name == "tag" then fields[column] = layout.tag
						elseif name == "seed" then fields[column] = seeds[seed_index]
						elseif name == "class" or name == "outcome" then
							fields[column] = values[value_index] or "-"
						elseif name == "kind" then fields[column] = "ordinary"
						elseif name == "side" then fields[column] = "before"
						elseif name == "endpoint" then fields[column] = "from"
						elseif name == "flagged" then fields[column] = "false"
						elseif name == "mode" or name == "from_mode" or
								name == "to_mode" then fields[column] = "direct"
						elseif name == "direction" then fields[column] = "east"
						elseif name:find("_id$") or name == "id" then
							fields[column] = layout.tag .. "-site-" .. site_index
						else
							fields[column] = count_text(seed_index * 10 + column +
								value_index + site_index)
						end
					end
					bucket[#bucket + 1] = fields
				end
			end
			rows[layout.tag] = bucket
		end
		records[#records + 1] = {seed = seeds[seed_index], rows = rows}
	end
	return records
end

local function fold_records(records, order, header)
	local census = new_census({strict = false})
	for index = 1, #records do
		local record = records[order == "reverse" and #records - index + 1 or index]
		local rows = record.rows
		if order == "reverse" then
			local reversed = {}
			local tags = sorted_keys(rows)
			for tag_index = #tags, 1, -1 do
				local tag = tags[tag_index]
				local bucket = {}
				for row_index = #rows[tag], 1, -1 do
					bucket[#bucket + 1] = rows[tag][row_index]
				end
				reversed[tag] = bucket
			end
			rows = reversed
		end
		census.add_record(record.seed, rows)
	end
	local state = census.state()
	local occupied = render_occupied(state, header)
	local vacuous = render_vacuous(state)
	local seed_set = render_seed_set(state, header)
	local histograms = render_histograms(state)
	return occupied .. vacuous .. seed_set .. histograms
end

local function assert_order_invariance(records, header, label)
	local forward = fold_records(records, "forward", header)
	local reverse = fold_records(records, "reverse", header)
	if forward ~= reverse then
		error("WP40 T2 census merge: the " .. label .. " artifacts depend on " ..
			"iteration order (plan section 5 divergence test)", 0)
	end
	return digest_of(forward)
end

-- ------------------------------------------------------------------
-- Inputs.
-- ------------------------------------------------------------------
local corpus = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")

-- The four measured winner slots are a committed artifact, and the merge
-- re-derives each one from the corpus label rule before using it: a copied
-- decimal would be exactly the second copy of a rule this tree keeps aborting
-- on, and the derivation costs four hashes.
local function winner_slots()
	local gate = dofile(repo ..
		"/tools/wp40/fixtures/t2_extreme_e0/conformance_gate.lua")
	assert(gate.schema == "grug_wp40_extreme_conformance_gate_v1",
		"the conformance gate schema changed")
	assert(type(gate.winners) == "table" and #gate.winners == 4,
		"the conformance gate does not name four winner slots")
	local winners = {}
	for index = 1, #gate.winners do
		local winner = gate.winners[index]
		assert(winner.slot == 27 + index, "winner slots are not 28..31 in order")
		local derived = corpus.extreme_candidate(winner.candidate_index, raw_sha256)
		assert(derived.decimal == winner.decimal,
			"winner slot " .. winner.slot .. " disagrees with the corpus label rule")
		winners[index] = {slot = winner.slot, id = winner.id,
			candidate_index = winner.candidate_index, decimal = winner.decimal}
	end
	return winners
end

local census = new_census({strict = true})

local function new_collector(sink)
	local current_seed, rows
	local collector = {}
	function collector.flush()
		if current_seed then sink(current_seed, rows) end
		current_seed, rows = nil, nil
	end
	function collector.row(tag, fields, seed)
		if seed ~= current_seed then
			collector.flush()
			current_seed, rows = seed, {}
		end
		local bucket = rows[tag]
		if not bucket then bucket = {} rows[tag] = bucket end
		bucket[#bucket + 1] = fields
	end
	return collector
end

local prefilter_reference, prefilter_lines, inputs_agreeing = nil, nil, 0
local function absorb_prefilter(prefilter)
	local texts = {}
	for index = 1, #prefilter do texts[index] = prefilter[index].line end
	local joined = table.concat(texts, "\n")
	if prefilter_reference == nil then
		prefilter_reference, prefilter_lines = joined, prefilter
	elseif joined ~= prefilter_reference then
		error("WP40 T2 census merge: the seed-independent prefilter block " ..
			"differs between inputs", 0)
	end
	inputs_agreeing = inputs_agreeing + 1
end

-- The top-up overlay (contracts 9.2): a top-up record supersedes the shard
-- record of its seed, and everything outside the Scan-4 block must be
-- byte-identical between the two -- the worker is deterministic, so a
-- disagreement is a finding, not a merge choice.
local scan4_tags = {scan4_membership = true, scan4_face = true,
	scan4_whole = true, scan4_whole_interval = true, scan4_fragment = true}
local top_up_records, top_up_consumed = {}, {}
local function joined_rows(bucket_rows)
	local texts = {}
	for index = 1, #(bucket_rows or {}) do
		texts[index] = table.concat(bucket_rows[index], "\t")
	end
	return table.concat(texts, "\n")
end

local collector = new_collector(function(seed, rows)
	local top_up = top_up_records[seed]
	if top_up then
		for index = 1, #authority.record_rows do
			local tag = authority.record_rows[index].tag
			if not scan4_tags[tag] and (rows[tag] or top_up[tag]) and
					joined_rows(rows[tag]) ~= joined_rows(top_up[tag]) then
				error("WP40 T2 census merge: the top-up record for seed " ..
					seed .. " disagrees with its shard record at " .. tag ..
					" rows -- the worker is deterministic, so this is a " ..
					"finding (contracts 9.2)", 0)
			end
		end
		top_up_consumed[seed] = true
		census.add_record(seed, top_up)
	else
		census.add_record(seed, rows)
	end
end)

local manifest_inputs, header = {}, {}
if #top_up_paths > 0 then
	local reload = new_collector(function(seed, rows)
		if top_up_records[seed] then
			error("WP40 T2 census merge: top-up seed " .. seed ..
				" appears twice", 0)
		end
		top_up_records[seed] = rows
	end)
	for index = 1, #top_up_paths do
		local bytes = read_file(top_up_paths[index])
		local verified = authority.verify_free_output(bytes, nil, reload.row)
		reload.flush()
		absorb_prefilter(verified.prefilter)
		local name = top_up_paths[index]:match("([^/]+)$")
		manifest_inputs[#manifest_inputs + 1] = table.concat({"top_up",
			count_text(index), name, verified.digest,
			count_text(#verified.seeds)}, "\t")
		hasher.forget()
	end
end
if mode == "full_w" then
	local w = authority.derive_w(corpus,
		read_file(repo .. "/" .. authority.candidates_path), raw_sha256)
	hasher.forget()
	local ranges = authority.shard_ranges(w.total)
	local shared
	for index = 1, #ranges do
		local range = ranges[index]
		local relative = authority.census_shard_path(range.first, range.last)
		authority.validate_census_shard_path(relative, range.first, range.last)
		local expected_seeds = {}
		for seed_index = range.first, range.last do
			expected_seeds[#expected_seeds + 1] = w.seeds[seed_index + 1]
		end
		local bytes = read_file(repo .. "/" .. relative)
		local verified = authority.verify_shard(bytes,
			{first = range.first, last = range.last, w_digest = w.digest,
				seeds = expected_seeds}, collector.row)
		collector.flush()
		absorb_prefilter(verified.prefilter)
		local provenance = {verified.header.census_commit, verified.header.census_tree,
			verified.header.module_digest, verified.header.interpreter_id,
			verified.header.interpreter_path, verified.header.interpreter_version,
			verified.header.w_digest, verified.header.w_total}
		local joined = table.concat(provenance, "\t")
		if shared == nil then shared = {joined = joined, header = verified.header}
		elseif joined ~= shared.joined then
			error("WP40 T2 census merge: shard " .. relative ..
				" was produced by different code or a different W than shard 1", 0)
		end
		manifest_inputs[#manifest_inputs + 1] = table.concat({"shard",
			count_text(range.first), count_text(range.last), relative,
			verified.digest, count_text(#verified.seeds)}, "\t")
		hasher.forget()
	end
	header.seed_set = "full_w"
	header.strict = true
	header.provenance = shared.header
	header.w = w
else
	for index = 1, #record_paths do
		local bytes = read_file(record_paths[index])
		local verified = authority.verify_free_output(bytes, nil, collector.row)
		collector.flush()
		absorb_prefilter(verified.prefilter)
		local name = record_paths[index]:match("([^/]+)$")
		manifest_inputs[#manifest_inputs + 1] = table.concat({"records",
			count_text(index), name, verified.digest,
			count_text(#verified.seeds)}, "\t")
	end
	header.seed_set = "explicit"
	-- Every seed emits the complete per-seed roster, so the site coverage
	-- assertion is meaningful on a one-seed record set too; only the synthetic
	-- fold of the divergence test runs without it.
	header.strict = true
	corpus.verify(raw_sha256)
end
header.winners = winner_slots()
header.corpus = corpus.fixed

-- The Bank family is complete since Scan-3b (contracts 9.1): the four head
-- Banks arrive on scan3_bank rows and the sixteen transition-incident Banks
-- on scan3b_bank rows, so no extremal family declares an open remainder any
-- more and the strict site-coverage assertion in render_seed_set holds the
-- full 153.

local state = census.state()
if mode == "full_w" then
	if #state.seeds ~= header.w.total then
		error("WP40 T2 census merge: the shards hold " .. #state.seeds ..
			" of " .. header.w.total .. " seeds of W", 0)
	end
	for index = 1, #state.seeds do
		if state.seeds[index] ~= header.w.seeds[index] then
			error("WP40 T2 census merge: shard seed " .. index ..
				" is " .. state.seeds[index] .. ", W declares " ..
				header.w.seeds[index], 0)
		end
	end
end
if #state.seeds == 0 then
	error("WP40 T2 census merge: no seed record was consumed", 0)
end
do
	local unconsumed = {}
	for seed in pairs(top_up_records) do
		if not top_up_consumed[seed] then unconsumed[#unconsumed + 1] = seed end
	end
	table.sort(unconsumed, decimal_less)
	if #unconsumed > 0 then
		error("WP40 T2 census merge: top-up record seed " .. unconsumed[1] ..
			" (" .. #unconsumed .. " total) matches no shard seed of W", 0)
	end
end

-- Contracts 9.6: the merge re-verifies Scan-4 coverage against the consumed
-- membership independently of the shard verifier -- every member record
-- carries all 38 face rows and exactly one whole row, and no non-member
-- record carries any Scan-4 tier row.
local scan4_member_count = 0
for index = 1, #state.seeds do
	local seed = state.seeds[index]
	local coverage = state.scan4_coverage[seed]
	if coverage then
		if coverage.member == "member" then
			scan4_member_count = scan4_member_count + 1
			if coverage.faces ~= 38 or coverage.wholes ~= 1 then
				error("WP40 T2 census merge: member seed " .. seed ..
					" carries " .. coverage.faces .. " face rows and " ..
					coverage.wholes .. " whole rows (contracts 9.6)", 0)
			end
		elseif coverage.faces ~= 0 or coverage.wholes ~= 0 then
			error("WP40 T2 census merge: non-member seed " .. seed ..
				" carries Scan-4 tier rows (contracts 9.6)", 0)
		end
	end
end

-- The prefilter's verified prediction (section 6.2.4 / 6.6.8): a discharged
-- edge realizes exactly one interval on every seed.  The worker aborts on a
-- violation, and the merge re-derives the same fact from the rows it merged so
-- the committed list records a checked claim rather than a trusted one.
local discharged_edges = {}
for index = 1, #prefilter_lines do
	if prefilter_lines[index].status == "discharged" then
		discharged_edges[prefilter_lines[index].edge_id] = true
	end
end
local prefilter_verified_seeds = 0
do
	local interval_hist = state.histograms.edge_interval_count or {}
	local edge_ids = sorted_keys(interval_hist)
	for index = 1, #edge_ids do
		local edge_id = edge_ids[index]
		if discharged_edges[edge_id] then
			local buckets = sorted_keys(interval_hist[edge_id])
			for bucket_index = 1, #buckets do
				if buckets[bucket_index] ~= "1" then
					error("WP40 T2 census merge: discharged edge " .. edge_id ..
						" realized interval count " .. buckets[bucket_index], 0)
				end
			end
		end
	end
	-- Only full records feed the interval-count histogram this re-check
	-- walks: a stage-rejected seed emits no edge rows and verifies nothing,
	-- so counting it would overstate artifact 4's checked claim.
	prefilter_verified_seeds = #state.seeds - state.stage_rejected_seeds
end

-- ------------------------------------------------------------------
-- The divergence test, then the artifacts.
-- ------------------------------------------------------------------
local probe_unsorted = probe_pairs_order()
if not probe_unsorted then
	-- Recording this and carrying on would leave the invariance half passing
	-- for the one reason that makes it meaningless, in a manifest that is not
	-- even covered by the compared digest.  A gate that cannot fail is the
	-- failure this branch has already shipped twice, so the merge refuses to
	-- certify anything in a runtime where the probe proves nothing.
	error("WP40 T2 census merge: this runtime's pairs() handed out a sorted " ..
		"iteration order for the probe table, so the section 5 divergence test " ..
		"has nothing to detect and its invariance half would pass vacuously; " ..
		"widen the probe before trusting a merge here", 0)
end
local synthetic_digest = assert_order_invariance(synthetic_records(),
	{seed_set = "synthetic", strict = false, winners = header.winners,
		corpus = header.corpus}, "synthetic")
-- The measured half runs where the records fit in memory twice, which is
-- exactly the KAT case the M5 gate runs; a full-`W` set is folded once and
-- rests on the synthetic half, which covers every declared class and therefore
-- every aggregation path the real one takes.
local record_invariance = "not_run_above_free_budget"
if mode == "records" and #state.seeds <= authority.free_seed_budget then
	local collected_records = {}
	local reload = new_collector(function(seed, rows)
		collected_records[#collected_records + 1] = {seed = seed, rows = rows}
	end)
	for index = 1, #record_paths do
		authority.verify_free_output(read_file(record_paths[index]), nil, reload.row)
		reload.flush()
	end
	assert_order_invariance(collected_records,
		{seed_set = header.seed_set, strict = false, winners = header.winners,
			corpus = header.corpus}, "measured")
	record_invariance = "passed"
end

local occupied_text, occupied_summary = render_occupied(state, header)
local vacuous_text, vacuous_summary = render_vacuous(state)
local seed_set_text, seed_set_summary = render_seed_set(state, header)
local prefilter_text, prefilter_summary = render_prefilter(prefilter_lines,
	inputs_agreeing, prefilter_verified_seeds)
local histogram_text = render_histograms(state)

-- The roster top-up protocol (contracts 9.2): the Scan-3b extremal sites can
-- produce bounds whose witnesses sit outside the consumed membership.  The
-- merge computes that pending list from its own aggregation and refuses to
-- publish while it is nonempty: a marked top-up run supplies the missing
-- records and the second invocation consumes shards plus top-up records and
-- publishes once.  Full-W only -- an explicit record set cannot cover the
-- union's winner and corpus terms by construction.
if mode == "full_w" then
	local pending = {}
	for index = 1, #seed_set_summary.seeds do
		local union_seed = seed_set_summary.seeds[index]
		local coverage = state.scan4_coverage[union_seed]
		if not coverage or coverage.member ~= "member" then
			pending[#pending + 1] = union_seed
		end
	end
	if #pending > 0 then
		io.stderr:write("WP40 T2 census merge: " .. #pending .. " seed(s) of " ..
			"the recomputed Scan-4 union lack the Scan-4 block; the roster " ..
			"top-up list (contracts 9.2):\n")
		for index = 1, #pending do
			io.stderr:write("  top_up_pending\t" .. pending[index] .. "\n")
		end
		io.stderr:flush()
		error("WP40 T2 census merge: refusing to publish while the top-up " ..
			"list is nonempty (contracts 9.2): run the marked top-up " ..
			"(worker seeds-mode with --scan4-forced) over the listed seeds " ..
			"and merge again with --top-up", 0)
	end
end

-- The inherited-tier regression assertion (contracts 9.3): the full pass
-- recomputes the v5 tiers, so every inherited-tier occupied/derived/witness
-- row must equal its v2 counterpart outside the header block -- a drift
-- there is a finding, not a refresh.  Full-W only: the committed baseline is
-- a measurement of W.
local inherited_status = "not_compared_explicit_records"
local inherited_drift, inherited_first
if mode == "full_w" then
	local baseline_path = inherited_baseline_override or
		(repo .. "/tools/wp40/fixtures/t2_census/census-occupied-classes-v2.tsv")
	local baseline_bytes = read_file(baseline_path)
	local function inherited_lines(text)
		local kept = {}
		for line in (text):gmatch("([^\n]*)\n") do
			local kind, family = line:match("^(occupied)\t([^\t]+)\t")
			if not kind then
				kind, family = line:match("^(derived)\t([^\t]+)\t")
			end
			if not kind then
				kind, family = line:match("^(witness)\t([^\t]+)\t")
			end
			if kind and not family:match("^scan3b_") and
					not family:match("^scan4_") then
				kept[#kept + 1] = line
			end
		end
		return kept
	end
	local ours = inherited_lines(occupied_text)
	local base = inherited_lines(baseline_bytes)
	inherited_drift = 0
	for index = 1, math.max(#ours, #base) do
		if ours[index] ~= base[index] then
			inherited_drift = inherited_drift + 1
			if not inherited_first then
				inherited_first = "v3: " .. tostring(ours[index]) ..
					" | v2: " .. tostring(base[index])
			end
		end
	end
	inherited_status = (inherited_drift == 0 and "identical_to_baseline"
		or ("drift=" .. count_text(inherited_drift))) ..
		" baseline_sha256=" .. digest_of(baseline_bytes)
end

local artifacts = {
	{name = "census-occupied-classes-v3.tsv", text = occupied_text},
	{name = "census-vacuous-branches-v3.tsv", text = vacuous_text},
	{name = "census-scan4-seed-set-v3.tsv", text = seed_set_text},
	{name = "census-prefilter-discharge-v3.tsv", text = prefilter_text},
	{name = "census-histograms-v3.tsv", text = histogram_text},
}
local artifact_lines = {}
for index = 1, #artifacts do
	artifacts[index].digest = digest_of(artifacts[index].text)
	artifact_lines[index] = artifacts[index].name .. "\t" .. artifacts[index].digest
end
-- The compared digest covers the five artifacts only.  The manifest names the
-- interpreter that produced it and therefore differs between the LuaJIT and
-- PUC runs by construction; folding it in would make the M5 gate unfalsifiable.
local artifacts_digest = digest_of(table.concat(artifact_lines, "\n") .. "\n")
if expected_digest and artifacts_digest ~= expected_digest then
	error("WP40 T2 census merge: this run's artifacts digest is " ..
		artifacts_digest .. ", the run it is compared against produced " ..
		expected_digest .. " (plan section 6.6.5); nothing was written", 0)
end

local manifest = {"schema\tgrug_wp40_census_manifest_v3",
	"scan_schema\t" .. authority.schema,
	"vocabulary\t" .. authority.vocabulary_path,
	"seed_set\t" .. header.seed_set,
	"seed_count\t" .. count_text(#state.seeds)}
local function manifest_line(...)
	manifest[#manifest + 1] = table.concat({...}, "\t")
end
if mode == "full_w" then
	local provenance = header.provenance
	manifest_line("census_commit", provenance.census_commit)
	manifest_line("census_tree", provenance.census_tree)
	manifest_line("module_digest", provenance.module_digest)
	manifest_line("worker_interpreter_id", provenance.interpreter_id)
	manifest_line("worker_interpreter_path", provenance.interpreter_path)
	manifest_line("worker_interpreter_version", provenance.interpreter_version)
	manifest_line("w_digest", header.w.digest)
	manifest_line("w_total", count_text(header.w.total))
	manifest_line("w_derivation", "corpus_fixed=" ..
		count_text(header.w.derivation.corpus_fixed) .. " pool_candidates=" ..
		count_text(header.w.derivation.pool_candidates) .. " candidates=" ..
		header.w.derivation.candidates_path .. " duplicates=" ..
		count_text(header.w.derivation.duplicates) .. " order=" ..
		header.w.derivation.order)
else
	-- A free record set carries the frozen M1 preamble and no provenance at
	-- all, so the manifest says so instead of inventing a commit: this is a
	-- KAT artifact, and it must never read like a slice of W.
	manifest_line("census_commit", "-")
	manifest_line("census_tree", "-")
	manifest_line("module_digest", "-")
	manifest_line("worker_interpreter_id", "-")
	manifest_line("worker_interpreter_path", "-")
	manifest_line("worker_interpreter_version", "-")
	manifest_line("seed_set_derivation",
		"an explicit worker record set; free worker output carries no shard " ..
		"header, so this artifact states no commit, tree or interpreter and is " ..
		"not a measurement of W")
	local seeds = {}
	for index = 1, #state.seeds do seeds[index] = state.seeds[index] end
	table.sort(seeds, decimal_less)
	manifest_line("seeds", table.concat(seeds, ","))
end
manifest_line("merge_interpreter_id", is_puc and "puc_lua51" or "luajit")
manifest_line("merge_interpreter_version", _VERSION ..
	(is_puc and "" or " (LuaJIT)"))
manifest_line("cost_projection", cost_projection or
	"not recorded by this merge; the launcher's first-completion projection is " ..
	"the section 6.5 gate and is printed by the run")
-- Section 6.6.6: the classification stance travels with the artifacts.
manifest_line("classification_stance",
	"the scanners classify by the decided U1 and U2 readings (plan section 5) " ..
	"even though the catalog strings follow only with the collected " ..
	"correction: the census is R15-style structural search, not a policy edit")
manifest_line("retention_stance",
	"section 6.3: no per-seed intermediate is committed; the flagged seed set " ..
	"is an artifact and is exempt, and every finding carries its site, its " ..
	"witness row and the decision the policy currently reaches")
manifest_line("divergence_test",
	"pairs_order_probe_unsorted=" .. tostring(probe_unsorted) ..
	" synthetic_invariance=passed synthetic_digest=" .. synthetic_digest ..
	" measured_invariance=" .. record_invariance)
manifest_line("findings",
	"occupied_rejected=" .. count_text(occupied_summary.findings) ..
	" events=" .. count_text(occupied_summary.events) ..
	" refuted_universals=" .. count_text(occupied_summary.universals) ..
	" stage_reject_seeds=" .. count_text(occupied_summary.stage_rejects) ..
	" vacuous_branches=" .. count_text(vacuous_summary.vacuous) ..
	" no_branch_matched=" .. count_text(occupied_summary.sink))
-- The D2 addendum (contracts 8.5): every seed the detached-shoulder
-- admission returned to the scanned universe, listed by name with its
-- admission site and station -- a marked table, never a silent merge.
do
	local admissions = {}
	for index = 1, #state.detached do
		admissions[index] = state.detached[index]
	end
	table.sort(admissions, function(left, right)
		if left.site ~= right.site then return left.site < right.site end
		return decimal_less(left.seed, right.seed)
	end)
	for index = 1, #admissions do
		manifest_line("detached_shoulder_admission", admissions[index].site ..
			" seed=" .. admissions[index].seed ..
			" station=" .. admissions[index].station)
	end
end
manifest_line("scan4_seed_set",
	"union_seeds=" .. count_text(seed_set_summary.union) ..
	" sites_covered=" .. count_text(seed_set_summary.covered) ..
	" of " .. count_text(authority.extremal_site_total) ..
	" sites_open=" .. count_text(seed_set_summary.open))
-- The v3 provenance block (contracts 9.3): v3 supersedes v2 for every
-- downstream consumer, names the consumed v2 baseline by digest, records
-- the 9.2 ruling, the coverage against the consumed membership, the
-- inherited-tier comparison and the top-up table.
manifest_line("supersedes",
	"the v2 artifact set (grug_wp40_census_manifest_v2) for every " ..
	"downstream consumer; the v1/v2 artifacts and the v4/v5 shards stay " ..
	"untouched as the prior records")
manifest_line("consumed_scan4_membership",
	"seed_set=" .. authority.scan4_membership_source.seed_set_path ..
	" sha256=" .. authority.scan4_membership_source.seed_set_digest ..
	" manifest=" .. authority.scan4_membership_source.manifest_path ..
	" sha256=" .. authority.scan4_membership_source.manifest_digest ..
	" union=" .. count_text(authority.scan4_membership_source.union))
manifest_line("scan4_ruling", authority.scan4_membership_source.ruling)
manifest_line("scan4_coverage", "members=" .. count_text(scan4_member_count) ..
	" of consumed_union=" ..
	count_text(authority.scan4_membership_source.union))
manifest_line("inherited_tier", inherited_status)
if #top_up_paths == 0 then
	manifest_line("top_up", "none")
end
for index = 1, #manifest_inputs do manifest[#manifest + 1] = manifest_inputs[index] end
for index = 1, #artifacts do
	manifest_line("artifact", artifacts[index].name, artifacts[index].digest)
end
manifest_line("artifacts_digest", artifacts_digest)
local manifest_text = table.concat(manifest, "\n") .. "\n"

-- The outputs are created last and atomically, and never over an existing
-- file: a rejected merge must not leave half an artifact set behind.
local outputs = {}
for index = 1, #artifacts do
	outputs[#outputs + 1] = {path = out_dir .. "/" .. artifacts[index].name,
		text = artifacts[index].text}
end
outputs[#outputs + 1] = {path = out_dir .. "/census-manifest-v3.tsv",
	text = manifest_text}
for index = 1, #outputs do
	local existing = io.open(outputs[index].path, "rb")
	if existing then
		existing:close()
		error("census merge output already exists: " .. outputs[index].path, 0)
	end
end
local written = {}
local published, publish_message = pcall(function()
	for index = 1, #outputs do
		local temporary = outputs[index].path .. ".tmp"
		local file = assert(io.open(temporary, "wb"))
		assert(file:write(outputs[index].text))
		assert(file:close())
		assert(read_file(temporary) == outputs[index].text,
			"artifact bytes changed after write")
		assert(os.rename(temporary, outputs[index].path), "atomic publish failed")
		written[#written + 1] = outputs[index].path
	end
end)
if not published then
	for index = 1, #outputs do os.remove(outputs[index].path .. ".tmp") end
	for index = 1, #written do os.remove(written[index]) end
	hasher.close()
	error(publish_message, 0)
end
hasher.close()

print(("WP40 T2 census merge seed_set=%s seeds=%d inputs=%d artifacts_digest=%s"):
	format(header.seed_set, #state.seeds, inputs_agreeing, artifacts_digest))
for index = 1, #artifacts do
	print(("WP40 T2 census artifact %s sha256=%s"):format(artifacts[index].name,
		artifacts[index].digest))
end
print(("WP40 T2 census findings rejected=%d events=%d refuted_universals=%d " ..
	"stage_reject_seeds=%d vacuous=%d/%d no_branch_matched=%d"):format(
	occupied_summary.findings, occupied_summary.events,
	occupied_summary.universals, occupied_summary.stage_rejects,
	vacuous_summary.vacuous, vacuous_summary.declared, occupied_summary.sink))
print(("WP40 T2 census scan4 seed set union=%d sites=%d/%d open=%d prefilter " ..
	"discharged=%d/%d"):format(seed_set_summary.union, seed_set_summary.covered,
	authority.extremal_site_total, seed_set_summary.open,
	prefilter_summary.discharged,
	prefilter_summary.discharged + prefilter_summary.scanned))
print("WP40 T2 census divergence test probe_unsorted=" .. tostring(probe_unsorted) ..
	" synthetic=passed measured=" .. record_invariance)
if occupied_summary.sink > 0 then
	-- Section 6.4: the merge completes and reports; it does not swallow.  An
	-- unmatched class falsifies the completeness argument and is worth
	-- stopping for, so the artifacts are written and the exit status says so.
	io.stderr:write("WP40 T2 census merge: " .. occupied_summary.sink ..
		" row(s) matched no declared branch; see the no_branch_matched block " ..
		"of census-occupied-classes-v3.tsv (plan section 6.4)\n")
	os.exit(3)
end
if inherited_drift and inherited_drift > 0 then
	-- Contracts 9.3: an inherited-tier drift is a finding, not a refresh --
	-- the artifacts are written and reported, and the exit status stops the
	-- publication from being accepted.
	io.stderr:write("WP40 T2 census merge: " .. inherited_drift ..
		" inherited-tier occupied row(s) drifted from the v2 baseline " ..
		"(contracts 9.3); first: " .. tostring(inherited_first) .. "\n")
	os.exit(4)
end
