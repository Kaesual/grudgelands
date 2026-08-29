-- Engine-free, lineage-gated loader for the disabled WP40 R5 implementation.

return function(repo, scratch, injected_raw_sha256, frozen_input_manifest)
	assert(type(repo) == "string" and
		repo:match("^/[A-Za-z0-9._/+:%-]+$"),
		"safe absolute repository root required")
	assert(type(scratch) == "string" and
		scratch:match("^/tmp/grudgelands%-wp40%-r5%.[A-Za-z0-9]+$"),
		"unsafe WP40 R5 scratch directory")
	if injected_raw_sha256 ~= nil then
		assert(type(injected_raw_sha256) == "function",
			"injected raw SHA-256 must be a function")
	end

	local common = dofile(repo .. "/tools/wp40/simple_map_r5_common.lua")
	local function fail(message) common.fail("offline: " .. message) end
	if frozen_input_manifest ~= nil and type(frozen_input_manifest) ~= "table" then
		fail("frozen input manifest must be a parsed manifest table")
	end
	local manifest_gated = frozen_input_manifest ~= nil
	if manifest_gated then
		frozen_input_manifest = common.deep_copy(frozen_input_manifest)
	end

	local command_counter, sha256_calls, sha256_cache = 0, 0, {}
	local function command_ok(command)
		local first, second, third = os.execute(command)
		return first == 0 or first == true and second == "exit" and third == 0
	end

	local function next_scratch_file(label, suffix)
		command_counter = command_counter + 1
		return scratch .. "/r5-" .. label .. "-" .. command_counter .. suffix
	end

	local function from_hex(value)
		if type(value) ~= "string" or #value ~= 64 or
				not value:match("^[0-9a-f]+$") then
			fail("SHA-256 command returned invalid hex")
		end
		return (value:gsub("..", function(pair)
			return string.char(assert(tonumber(pair, 16)))
		end))
	end

	local function raw_sha256(bytes)
		if type(bytes) ~= "string" then fail("SHA-256 input is not bytes") end
		local cached = #bytes <= 4096 and sha256_cache[bytes] or nil
		if cached then return cached end
		sha256_calls = sha256_calls + 1
		local digest
		if injected_raw_sha256 then
			digest = injected_raw_sha256(bytes)
		else
			local input = next_scratch_file("sha", ".bin")
			local output = next_scratch_file("sha", ".txt")
			common.write_file(input, bytes)
			if not command_ok("sha256sum " .. input .. " > " .. output) then
				fail("sha256sum command failed")
			end
			local line = common.read_file(output):match("^([0-9a-f]+)")
			if not os.remove(input) or not os.remove(output) then
				fail("SHA-256 scratch cleanup failed")
			end
			digest = from_hex(line)
		end
		if type(digest) ~= "string" or #digest ~= 32 then
			fail("SHA-256 seam did not return 32 bytes")
		end
		if #bytes <= 4096 then sha256_cache[bytes] = digest end
		return digest
	end

	local function git_object(commit, path)
		common.require_git40(commit, "Git object commit")
		if type(path) ~= "string" or
			not path:match("^[A-Za-z0-9._/+:%-]+$") then
			fail("unsafe Git object path")
		end
		common.encode_path(path)
		local output = next_scratch_file("git", ".bin")
		local command = "git -C " .. repo .. " show " .. commit .. ":" ..
			path .. " > " .. output
		if not command_ok(command) then
			fail("Git object read failed: " .. path)
		end
		local bytes = common.read_file(output)
		if not os.remove(output) then fail("Git object scratch cleanup failed") end
		return bytes
	end

	local function git_line(arguments)
		if arguments ~= "rev-parse HEAD" then
			fail("unsafe Git query")
		end
		local output = next_scratch_file("query", ".txt")
		if not command_ok("git -C " .. repo .. " " .. arguments ..
				" > " .. output) then fail("Git query failed") end
		local bytes = common.read_file(output)
		if not os.remove(output) then fail("Git query scratch cleanup failed") end
		local line = bytes:match("^([^\r\n]+)\n$")
		if not line then fail("Git query output differs") end
		return line
	end

	local function require_commit(commit)
		common.require_git40(commit, "required commit")
		if not command_ok("git -C " .. repo .. " cat-file -e " .. commit ..
				"^{commit}") then fail("required commit object is absent") end
		return commit
	end

	local function require_ancestor(ancestor, descendant, label)
		require_commit(ancestor)
		require_commit(descendant)
		if not command_ok("git -C " .. repo .. " merge-base --is-ancestor " ..
				ancestor .. " " .. descendant) then
			fail(label .. " ancestry differs")
		end
		return true
	end

	local function verify_literals()
		for _, value in ipairs({
			common.R2_BODY_SHA256, common.R2_FILE_SHA256,
			common.R3_BODY_SHA256, common.R3_FILE_SHA256,
			common.R4_HISTORICAL_BODY_SHA256,
			common.R4_HISTORICAL_FILE_SHA256,
			common.R4_REVIEW_FILE_SHA256, common.R4_REVIEW_VERDICT_SHA256,
			common.R4_TARGETED_KAT_BODY_SHA256,
			common.R4_TARGETED_KAT_FILE_SHA256,
			common.R4_SEED_0_KAT_SHA256,
		}) do
			common.require_sha256(value, "accepted lineage literal")
		end
		for _, value in ipairs({
			common.R4_ACCEPTED_COMMIT, common.R5_DRAFT_COMMIT,
			common.R5_AUDIT_FIX_COMMIT, common.R5_R4_MERGE_COMMIT,
			common.R5_BPLUS_COMMIT,
		}) do
			common.require_git40(value, "accepted lineage commit")
		end
	end

	local function verify_ancestry()
		local candidate = git_line("rev-parse HEAD")
		common.require_git40(candidate, "candidate HEAD")
		require_commit(common.R4_ACCEPTED_COMMIT)
		require_commit(common.R5_DRAFT_COMMIT)
		require_commit(common.R5_AUDIT_FIX_COMMIT)
		require_commit(common.R5_R4_MERGE_COMMIT)
		require_commit(common.R5_BPLUS_COMMIT)
		return candidate, {
			accepted_r4_ancestor_candidate = require_ancestor(
				common.R4_ACCEPTED_COMMIT, candidate,
				"accepted R4/candidate"),
			draft_ancestor_audit = require_ancestor(common.R5_DRAFT_COMMIT,
				common.R5_AUDIT_FIX_COMMIT, "draft/audit"),
			audit_ancestor_merge = require_ancestor(common.R5_AUDIT_FIX_COMMIT,
				common.R5_R4_MERGE_COMMIT, "audit/merge"),
			accepted_r4_ancestor_merge = require_ancestor(
				common.R4_ACCEPTED_COMMIT, common.R5_R4_MERGE_COMMIT,
				"accepted R4/merge"),
			merge_ancestor_bplus = require_ancestor(common.R5_R4_MERGE_COMMIT,
				common.R5_BPLUS_COMMIT, "merge/B+"),
			bplus_ancestor_candidate = require_ancestor(common.R5_BPLUS_COMMIT,
				candidate, "B+/candidate"),
		}
	end

	local function parse_historical_artifact()
		local bytes = git_object(common.R4_ACCEPTED_COMMIT,
			"docs/research/wp40-simple-map-r4-artifact.tsv")
		local parsed = common.parse_finalized_artifact(raw_sha256, bytes,
			common.R4_HISTORICAL_BODY_SHA256,
			common.R4_HISTORICAL_FILE_SHA256, "historical R4 artifact")
		local inputs, count = {}, 0
		for line in parsed.body:gmatch("([^\n]+)\n") do
			local path, digest = line:match(
				"^input_sha256\t([^\t]+)\t([0-9a-f]+)$")
			if path then
				if not path:match("^[A-Za-z0-9._/+:%-]+$") or inputs[path] then
					fail("historical R4 input path differs")
				end
				common.encode_path(path)
				common.require_sha256(digest, "historical R4 input digest")
				local actual = common.digest_hex(raw_sha256,
					git_object(common.R4_ACCEPTED_COMMIT, path))
				if actual ~= digest then
					fail("historical R4 input changed: " .. path)
				end
				inputs[path], count = digest, count + 1
			end
		end
		if count ~= 35 then fail("historical R4 input population differs") end
		parsed.inputs, parsed.input_count = inputs, count
		return parsed
	end

	local function verify_historical_review()
		local bytes = git_object(common.R4_ACCEPTED_COMMIT,
			"docs/research/wp40-simple-map-r4-review.md")
		if common.digest_hex(raw_sha256, bytes) ~= common.R4_REVIEW_FILE_SHA256 then
			fail("historical R4 review file SHA-256 differs")
		end
		local heading = "## Independent implementation review\n"
		local start_at, end_at = bytes:find(heading, 1, true)
		if not start_at or bytes:find(heading, end_at + 1, true) then
			fail("historical independent-review section population differs")
		end
		local section = bytes:sub(end_at + 1)
		local next_heading = section:find("\n## ", 1, true)
		if next_heading then section = section:sub(1, next_heading - 1) end
		local count, verdict = 0, nil
		for value in section:gmatch(
				"%- Extracted verdict SHA%-256:\n  `([0-9a-f]+)`%.") do
			count, verdict = count + 1, value
		end
		if count ~= 1 or verdict ~= common.R4_REVIEW_VERDICT_SHA256 then
			fail("historical independent-review verdict differs")
		end
		common.require_sha256(verdict, "historical R4 review verdict")
		return {file_sha256 = common.R4_REVIEW_FILE_SHA256,
			verdict_sha256 = verdict}
	end

	local function make_historical_tree(label)
		local root = scratch .. "/historical-" .. label .. "/wp40"
		if not command_ok("mkdir -p " .. root .. "/source") then
			fail("historical input-tree creation failed")
		end
		for index = 1, #common.HISTORICAL_R4_KAT_PATHS do
			local path = common.HISTORICAL_R4_KAT_PATHS[index]
			local relative = assert(path:match("^mods/MAPGEN/grug_mapgen/wp40/(.+)$"))
			local target = root .. "/" .. relative
			common.write_file(target, git_object(common.R4_ACCEPTED_COMMIT, path))
			if not command_ok("chmod 0444 " .. target) then
				fail("historical input-tree permission failed")
			end
		end
		return root
	end

	local function historical_kats(root, label)
		if label ~= "a" and label ~= "b" then
			fail("historical KAT output label differs")
		end
		local factory = dofile(root .. "/init.lua")
		if type(factory) ~= "function" then fail("historical R4 factory missing") end
		local foundation = factory(root)
		if type(foundation) ~= "table" or
				type(foundation.new_session) ~= "function" then
			fail("historical R4 foundation differs")
		end
		local kats, digests = {}, {}
		for index = 1, #common.CANONICAL_SEEDS do
			local seed = common.CANONICAL_SEEDS[index]
			local session = foundation.new_session(seed, raw_sha256,
				common.WATER_LEVEL)
			if type(session) ~= "table" or
					type(session.canonical_kat) ~= "function" or
					type(session.canonical_kat_digest) ~= "function" then
				fail("historical R4 public KAT seam differs")
			end
			local bytes = session.canonical_kat()
			local digest = common.digest_hex(raw_sha256, bytes)
			if session.canonical_kat_digest() ~= digest then
				fail("historical R4 public KAT digest differs")
			end
			kats[index], digests[index] = bytes, digest
		end
		if digests[1] ~= common.R4_SEED_0_KAT_SHA256 then
			fail("historical R4 seed-zero public KAT differs")
		end
		local bundle = common.frame_r4_public_kat_bundle(
			common.CANONICAL_SEEDS, kats)
		local bundle_digest = common.digest_hex(raw_sha256, bundle)
		local output_root = scratch .. "/historical-" .. label .. "/evidence"
		if not command_ok("mkdir -p " .. output_root) then
			fail("historical KAT output creation failed")
		end
		for index = 1, #kats do
			common.write_file(output_root .. "/seed-" .. index .. ".kat", kats[index])
		end
		common.write_file(output_root .. "/bundle.bin", bundle)
		common.write_file(output_root .. "/bundle.sha256", bundle_digest .. "\n")
		return kats, digests, bundle, bundle_digest
	end

	local authority
	local initialized = false
	local source, schemas, canonical, deterministic, index128
	local zones_factory, zones_module, foundation_factory
	local manifest_module, allocator_factory, planner_factory, adapter_factory
	local planner_candidate_fixture, adapter_replacement_fixture
	local r5_module, vm_module, new_paired_context_fixture
	local recording_factory, recorded_allocators
	local loader = {raw_sha256 = raw_sha256}

	function loader.sha256_call_count()
		return sha256_calls
	end

	local function verify_contract_digest(input_manifest)
		if not common.R5_CONTRACT_SHA256 then
			fail("frozen R5 contract digest authority is missing")
		end
		local expected = common.require_sha256(common.R5_CONTRACT_SHA256,
			"frozen R5 contract SHA-256")
		local actual = input_manifest.digests[
			"docs/research/wp40-simple-map-r5-contract.md"]
		if actual ~= expected then fail("frozen R5 contract SHA-256 differs") end
		return actual
	end

	local function build_preflight()
		if manifest_gated then
			fail("historical preflight is unavailable in manifest-gated mode")
		end
		verify_literals()
		local candidate_commit, ancestry = verify_ancestry()
		local historical_artifact = parse_historical_artifact()
		local review = verify_historical_review()
		local root_a = make_historical_tree("a")
		local kats_a, digests_a, bundle_a, bundle_digest_a =
			historical_kats(root_a, "a")
		local root_b = make_historical_tree("b")
		local kats_b, digests_b, bundle_b, bundle_digest_b =
			historical_kats(root_b, "b")
		for index = 1, #common.CANONICAL_SEEDS do
			if kats_a[index] ~= kats_b[index] or
					digests_a[index] ~= digests_b[index] then
				fail("independent historical R4 public KAT differs")
			end
		end
		if bundle_a ~= bundle_b or bundle_digest_a ~= bundle_digest_b then
			fail("independent historical R4 public-KAT bundle differs")
		end
		local parent = common.verify_parent_authority(repo, raw_sha256)
		local input_manifest = common.capture_input_manifest(repo, raw_sha256,
			parent.r2.inputs, parent.r3.inputs)
		local contract_path = "docs/research/wp40-simple-map-r5-contract.md"
		local contract_sha256 = input_manifest.digests[contract_path]
		if not contract_sha256 then fail("R5 contract is absent from input manifest") end
		verify_contract_digest(input_manifest)
		return {
			schema = common.R5_PREFLIGHT_SCHEMA,
			candidate_commit = candidate_commit,
			ancestry = ancestry,
			r2 = parent.r2,
			r3 = parent.r3,
			r4 = {
				accepted_commit = common.R4_ACCEPTED_COMMIT,
				artifact_body_sha256 = historical_artifact.body_sha256,
				artifact_file_sha256 = historical_artifact.file_sha256,
				review_file_sha256 = review.file_sha256,
				review_verdict_sha256 = review.verdict_sha256,
				targeted_kat_body_sha256 = common.R4_TARGETED_KAT_BODY_SHA256,
				targeted_kat_file_sha256 = common.R4_TARGETED_KAT_FILE_SHA256,
				seed_kat_bytes = kats_a,
				seed_kat_digests = digests_a,
				bundle_bytes = bundle_a,
				bundle_sha256 = bundle_digest_a,
			},
			input_manifest = input_manifest,
			contract_sha256 = contract_sha256,
		}
	end

	function loader.preflight()
		if manifest_gated then
			fail("historical preflight is unavailable in manifest-gated mode")
		end
		if not authority then authority = build_preflight() end
		return common.deep_copy(authority)
	end

	function loader.input_manifest()
		if manifest_gated then return common.deep_copy(frozen_input_manifest) end
		if not authority then authority = build_preflight() end
		return common.deep_copy(authority.input_manifest)
	end

	function loader.verify_input_manifest()
		local manifest, parent
		if manifest_gated then
			-- This is current-byte validation, not historical lineage authority.
			parent = common.verify_parent_authority(repo, raw_sha256)
			manifest = frozen_input_manifest
		else
			if not authority then authority = build_preflight() end
			parent, manifest = authority, authority.input_manifest
		end
		common.verify_input_manifest(repo, raw_sha256, manifest,
			parent.r2.inputs, parent.r3.inputs)
		verify_contract_digest(manifest)
		return true
	end

	function loader.read_bound_input(relative_path)
		if type(relative_path) ~= "string" then
			fail("bound input path must be text")
		end
		local expected = common.bound_input_sha256(relative_path)
		if expected == nil then fail("bound input path is not authorized") end
		loader.verify_input_manifest()
		local manifest = loader.input_manifest()
		if manifest.digests[relative_path] ~= expected then
			fail("bound input manifest digest differs")
		end
		local bytes = common.read_file(repo .. "/" .. relative_path)
		if common.digest_hex(raw_sha256, bytes) ~= expected then
			fail("bound input current-file digest differs")
		end
		return bytes
	end

	function loader.read_current_input(relative_path)
		if type(relative_path) ~= "string" or
				common.encode_path(relative_path) ~= relative_path then
			fail("current input path must be plain safe relative text")
		end
		loader.verify_input_manifest()
		local manifest = loader.input_manifest()
		local expected = manifest.digests[relative_path]
		if expected == nil then
			fail("current input path is outside the frozen manifest")
		end
		common.require_sha256(expected, "current input manifest digest")
		local bytes = common.read_file(repo .. "/" .. relative_path)
		if common.digest_hex(raw_sha256, bytes) ~= expected then
			fail("current input current-file digest differs")
		end
		return bytes
	end

	function loader.loaded()
		return initialized
	end

	local function initialize()
		if initialized then return end
		-- This is the last gate before the first current production/tool dofile.
		loader.verify_input_manifest()
		local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
		source = dofile(directory .. "/source/simple_map.lua")
		schemas = dofile(directory .. "/schemas.lua")
		canonical = dofile(directory .. "/canonical.lua")
		deterministic = dofile(directory .. "/deterministic.lua")
		index128 = dofile(directory .. "/index128.lua")
		zones_factory = dofile(directory .. "/zones.lua")
		foundation_factory = dofile(directory .. "/init.lua")
		manifest_module = dofile(directory .. "/mapgen_manifest.lua")
		allocator_factory = dofile(directory .. "/counting_allocator.lua")
		planner_factory, planner_candidate_fixture =
			dofile(directory .. "/planner.lua")
		adapter_factory, adapter_replacement_fixture =
			dofile(directory .. "/map_adapter.lua")
		local r5_factory = dofile(directory .. "/r5.lua")
		vm_module, new_paired_context_fixture =
			dofile(repo .. "/tools/wp40/simple_map_r5_vm.lua")
		if type(source) ~= "table" or source.schema ~= common.SOURCE_SCHEMA or
				source.layout_id ~= common.LAYOUT_ID or
				source.layout_revision_id ~= common.LAYOUT_REVISION_ID or
				type(schemas) ~= "table" or
				schemas.simple_map ~= common.HORIZONTAL_SCHEMA or
				type(zones_factory) ~= "function" or
				type(foundation_factory) ~= "function" or
				type(manifest_module) ~= "table" or
				type(allocator_factory) ~= "table" or
				type(allocator_factory.new) ~= "function" or
				type(planner_factory) ~= "function" or
				type(planner_candidate_fixture) ~= "function" or
				type(adapter_factory) ~= "function" or
				type(adapter_replacement_fixture) ~= "function" or
				type(r5_factory) ~= "function" or
				type(vm_module) ~= "table" or type(vm_module.new) ~= "function" or
				type(new_paired_context_fixture) ~= "function" then
			fail("current module factory seam differs")
		end
		zones_module = zones_factory({source = source, schemas = schemas,
			canonical = canonical, deterministic = deterministic,
			index128 = index128,
			horizontal_factory = dofile(directory .. "/simple_map.lua"),
			height_factory = dofile(directory .. "/height.lua"),
			raw_sha256 = raw_sha256})
		recorded_allocators = {}
		local function recording_new(...)
			local count = select("#", ...)
			local result = allocator_factory.new(...)
			if count == 1 then
				recorded_allocators[#recorded_allocators + 1] = result
			end
			return result
		end
		recording_factory = {new = recording_new}
		r5_module = r5_factory({
			zones_factory = zones_factory,
			planner_factory = planner_factory,
			adapter_factory = adapter_factory,
			manifest_module = manifest_module,
			allocator_factory = recording_factory,
			source = source, schemas = schemas, canonical = canonical,
			deterministic = deterministic, index128 = index128,
			horizontal_factory = dofile(directory .. "/simple_map.lua"),
			height_factory = dofile(directory .. "/height.lua"),
			raw_sha256 = raw_sha256,
		})
		if type(zones_module) ~= "table" or
				type(zones_module.new) ~= "function" or
				type(zones_module.new_with_planner_source) ~= "function" or
				type(r5_module) ~= "table" or type(r5_module.new) ~= "function" or
				type(r5_module.status) ~= "function" then
			fail("current constructed module seam differs")
		end
		initialized = true
	end

	function loader.load_public(full_seed_string, configured_water_level)
		initialize()
		local session = zones_module.new(full_seed_string, configured_water_level)
		local private_session, planner_source =
			zones_module.new_with_planner_source(full_seed_string,
				configured_water_level)
		local foundation = foundation_factory(
			repo .. "/mods/MAPGEN/grug_mapgen/wp40")
		local foundation_session = foundation.new_session(full_seed_string,
			raw_sha256, configured_water_level)
		return {
			input_manifest = loader.input_manifest(),
			source = source,
			schemas = schemas,
			canonical = canonical,
			deterministic = deterministic,
			index128 = index128,
			zones_module = zones_module,
			foundation = foundation,
			foundation_session = foundation_session,
			session = session,
			private_session = private_session,
			planner_source = planner_source,
		}
	end

	function loader.load_r5(full_seed_string, manifest_values,
			content_contract, mapgen_context_or_request)
		initialize()
		local mapgen_context = mapgen_context_or_request
		local paired_context, trace_token
		local paired_request = type(mapgen_context_or_request) == "table" and
			rawget(mapgen_context_or_request, "schema") ==
				common.R5_PAIRED_CONTEXT_REQUEST_SCHEMA
		if paired_request then
			if getmetatable(mapgen_context_or_request) ~= nil then
				fail("paired context request must be a plain table")
			end
			local field_count = 0
			for key in pairs(mapgen_context_or_request) do
				if key ~= "schema" and key ~= "heightmap" then
					fail("paired context request has an unexpected field")
				end
				field_count = field_count + 1
			end
			local heightmap_source = rawget(mapgen_context_or_request, "heightmap")
			if field_count ~= 2 or type(heightmap_source) ~= "table" or
					getmetatable(heightmap_source) ~= nil then
				fail("paired context request differs")
			end
			paired_context, trace_token =
				new_paired_context_fixture(heightmap_source)
			if type(paired_context) ~= "table" or
					getmetatable(paired_context) ~= nil or
					paired_context.schema ~= common.R5_MAPGEN_CONTEXT_SCHEMA or
					type(paired_context.get_heightmap) ~= "function" or
					type(paired_context.metrics) ~= "function" or
					type(trace_token) ~= "function" then
				fail("paired context fixture seam differs")
			end
			local context_field_count = 0
			for key in pairs(paired_context) do
				if key ~= "schema" and key ~= "get_heightmap" and key ~= "metrics" then
					fail("paired context fixture has an unexpected field")
				end
				context_field_count = context_field_count + 1
			end
			if context_field_count ~= 3 then
				fail("paired context fixture field population differs")
			end
			mapgen_context = paired_context
		end
		local before = #recorded_allocators
		local session, planner_source, planner, adapter = r5_module.new(
			full_seed_string, common.WATER_LEVEL, manifest_values,
			content_contract, mapgen_context)
		if #recorded_allocators ~= before + 2 then
			fail("R5 construction allocator population differs")
		end
		local loaded = {
			input_manifest = loader.input_manifest(),
			source = source,
			schemas = schemas,
			canonical = canonical,
			deterministic = deterministic,
			index128 = index128,
			zones_module = zones_module,
			manifest_module = manifest_module,
			allocator_factory = allocator_factory,
			planner_candidate_fixture = planner_candidate_fixture,
			adapter_replacement_fixture = adapter_replacement_fixture,
			vm_module = vm_module,
			r5_module = r5_module,
			session = session,
			planner_source = planner_source,
			planner = planner,
			adapter = adapter,
			allocators = {recorded_allocators[before + 1],
				recorded_allocators[before + 2]},
		}
		if paired_request then
			return loaded, paired_context, trace_token
		end
		return loaded
	end

	return loader
end
