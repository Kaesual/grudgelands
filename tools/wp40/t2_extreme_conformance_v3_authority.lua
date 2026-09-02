-- Closed code/input graph for the T2c-E0-C1 PUC conformance over the v3 pool.
--
-- This module is deliberately NOT an edit of t2_extreme_conformance_authority.
-- That module must stay byte-identical: t2_partition_test.lua re-materializes
-- the pre-v3 conformance DAG 086855378e... from commit 5a2fc0d through its
-- exact roster, so changing the roster would make the historical gate
-- permanently unreproducible.  The v3 chain therefore owns its own graph, with
-- its own domain-separated DAG prefix, so a pre-v3 and a v3 manifest can never
-- collide even if the two rosters ever became equal.
--
-- The roster names every file whose bytes can change a v3 conformance result or
-- any digest a v3 result row records:
--
--   * the v3 chain itself (this module, the conformance module, the two
--     workers, verify/preflight/finalize, the recorded-evidence driver, the
--     KAT and the runner);
--   * the v3 gate, the v3 merged artifact, the v3 manifest and the eight v3
--     shards -- the retained measurement inputs the chain reads;
--   * the four pre-v3 fixtures the KAT reads as NEGATIVE inputs
--     (conformance_gate.lua, candidates-luajit.tsv, manifest-luajit.tsv and
--     shard-luajit-0000-0511.tsv).  It presents each of them to a v3 reader and
--     requires rejection, so their bytes can change what the KAT proves;
--   * t2_partition_test.lua and t2_partition_oracle.lua, which the selected
--     worker executes, plus the WP40 schema modules and the WP43 material
--     surface those two load (materials_test.lua -> stairs/grug_materials/
--     grug_nodes/mapgen ores, and wp43_handoff.lua), the shared phase selector
--     and the partition payload cache;
--   * every file the measurement Authority-DAG covers (t2_extreme_authority's
--     paths and stage_paths).  The v3 chain no longer asserts that the live
--     measurement DAG equals the gate -- it cannot, the Section 11 correction
--     landed after the pool was measured -- and records it as
--     execution_authority_dag_sha256 instead.  t2_extreme_conformance_verify
--     recomputes that field from the live tree, so the preflight must be able
--     to prove the live tree equals the pinned commit for every byte it
--     depends on.  That includes the measurement launchers and the merge/shard
--     tools, which never execute during a conformance run but are inputs to
--     that digest.
--
-- Not in the roster, on purpose: t2_extreme_conformance_authority.lua and the
-- seven pre-v3 shards that the KAT does not read.  No v3 code path reads any of
-- them, so their bytes cannot change a v3 result.  The pre-v3 files that ARE
-- listed are listed as negative KAT inputs only; nothing here reads one as
-- evidence, and there is no v3 writer for any of them.
--
-- THE ROSTER IS ALSO THE PINNED CLOSURE.  A finished 24-row conformance
-- artifact stays reusable while -- and only while -- every roster path is
-- byte-identical between the commit the artifact recorded and the current
-- working tree.  closure_equality proves exactly that, parse_recorded_pins
-- takes the commit/tree/DAG out of the artifact's own bytes instead of trusting
-- HEAD, assert_recorded_history refuses a commit that is not an ancestor of
-- HEAD, and verify_recorded_evidence composes the three and then hands the
-- RECORDED pins to the finalizer's verify path, which re-derives the artifact
-- from all 24 retained rows.  Equality of the final TSV alone is never
-- accepted.  Because this module is itself a roster member, a proven closure is
-- also proof that the roster used is the recorded commit's roster.  None of
-- this touches generation: the first run still has to produce all 24 rows from
-- one clean immutable commit.
--
-- TWO LIMITS OF THAT CLOSURE, both deliberate and both covered elsewhere.  The
-- PUC interpreter tools/bin/lua51 certainly changes a v3 result, but it is
-- built per checkout and gitignored (.gitignore: tools/bin/), so it can never
-- be a roster member -- capture_git would refuse it.  It is pinned per RESULT
-- ROW instead: t2_extreme_conformance_verify.lua re-hashes the live argv[0] and
-- requires it to equal every row's interpreter_sha256 and the merged artifact's
-- merge_interpreter_sha256, for all twenty-four rows.  And the comparison here
-- is over blob BYTES only: git mode is not compared, so a tracked symlink would
-- be compared as its target text on the pinned side and as the linked file's
-- content on the working-tree side.  The repository has no tracked symlinks;
-- introducing one into the roster would need this to be revisited.
return function(dependencies)
	assert(type(dependencies) == "table")
	local raw_sha256 = assert(dependencies.raw_sha256)
	local authority = {}
	local paths = {
		"mods/BASE/stairs/init.lua",
		"mods/ITEMS/grug_materials/audit.lua",
		"mods/ITEMS/grug_materials/derivatives.lua",
		"mods/ITEMS/grug_materials/init.lua",
		"mods/ITEMS/grug_materials/migration.lua",
		"mods/ITEMS/grug_materials/mining.lua",
		"mods/ITEMS/grug_materials/ores.lua",
		"mods/ITEMS/grug_materials/overrides.lua",
		"mods/ITEMS/grug_materials/registry.lua",
		"mods/ITEMS/grug_nodes/init.lua",
		"mods/ITEMS/grug_nodes/ore_respawn.lua",
		"mods/MAPGEN/grug_mapgen/ores.lua",
		"mods/MAPGEN/grug_mapgen/wp40/canonical.lua",
		"mods/MAPGEN/grug_mapgen/wp40/compiled_schema.lua",
		"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/boundary.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/extreme.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua",
		"mods/MAPGEN/grug_mapgen/wp40/schemas.lua",
		"mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua",
		"mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua",
		"mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua",
		"mods/MAPGEN/grug_mapgen/wp43_handoff.lua",
		"tools/wp40/fixtures/t2_extreme_e0/candidates-luajit-v3.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/candidates-luajit.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/conformance_gate.lua",
		"tools/wp40/fixtures/t2_extreme_e0/conformance_gate_v3.lua",
		"tools/wp40/fixtures/t2_extreme_e0/full_scan_gate.lua",
		"tools/wp40/fixtures/t2_extreme_e0/manifest-luajit-v3.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/manifest-luajit.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-0000-0511.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-v3-0000-0511.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-v3-0512-1023.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-v3-1024-1535.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-v3-1536-2047.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-v3-2048-2559.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-v3-2560-3071.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-v3-3072-3583.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-v3-3584-4095.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua",
		"tools/wp40/run_t2_extreme_conformance.sh",
		"tools/wp40/run_t2_extreme_shard.sh",
		"tools/wp40/run_t2_extreme_shards.sh",
		"tools/wp40/t2_extreme_authority.lua",
		"tools/wp40/t2_extreme_conformance.lua",
		"tools/wp40/t2_extreme_conformance_finalize.lua",
		"tools/wp40/t2_extreme_conformance_preflight.lua",
		"tools/wp40/t2_extreme_conformance_recorded.lua",
		"tools/wp40/t2_extreme_conformance_test.lua",
		"tools/wp40/t2_extreme_conformance_v3_authority.lua",
		"tools/wp40/t2_extreme_conformance_verify.lua",
		"tools/wp40/t2_extreme_gate_check.lua",
		"tools/wp40/t2_extreme_merge.lua",
		"tools/wp40/t2_extreme_rescore_worker.lua",
		"tools/wp40/t2_extreme_selected_worker.lua",
		"tools/wp40/t2_extreme_shard_worker.lua",
		"tools/wp40/t2_extreme_verify_shard.lua",
		"tools/wp40/t2_partition_oracle.lua",
		"tools/wp40/t2_partition_test.lua",
		"tools/wp40/t2_payload_cache.lua",
		"tools/wp40/t2_phase_selector.lua",
		"tools/wp40/t2_s1_authority.lua",
		"tools/wp40/t2_sha256_batch.py",
		"tools/wp43/materials_test.lua",
	}
	local function fail(message)
		error("WP40 T2 v3 conformance authority: " .. message, 0)
	end
	local function safe_root(path)
		if type(path) ~= "string" or not path:match("^/[A-Za-z0-9._/-]+$") or
				path:find("/../", 1, true) or path:find("/./", 1, true) or
				path:sub(-3) == "/.." or path:sub(-2) == "/." or
				path:find("/" .. "/", 1, true) then fail("unsafe path") end
		return path
	end
	local function read_file(path)
		local file = io.open(path, "rb")
		if not file then fail("cannot read " .. path) end
		local bytes = file:read("*a")
		if not bytes or not file:close() then fail("cannot read " .. path) end
		return bytes
	end
	local function hex(bytes)
		return (bytes:gsub(".", function(byte)
			return ("%02x"):format(string.byte(byte))
		end))
	end
	-- git's own message is captured, not discarded.  "this path is not in that
	-- commit", "git is not installed", "this is not a git repository" and "the
	-- object database is damaged" are all one non-zero exit status, and a
	-- refusal that only ever says "file is missing" sends the operator looking
	-- for a deleted mod file.  Only the first line is appended -- the rest is
	-- advice -- and it is appended to our own diagnostic, never instead of it.
	local function git_reason(path)
		local file = io.open(path, "rb")
		if not file then return "" end
		local bytes = file:read("*a")
		file:close()
		if type(bytes) ~= "string" then return "" end
		local first = bytes:match("^%s*([^\r\n]+)")
		if not first then return "" end
		if #first > 200 then first = first:sub(1, 200) end
		return " (git: " .. first .. ")"
	end
	-- A closure member is a repository-relative path.  It is validated because
	-- the caller may supply its own list (the KAT drives the very same closure
	-- code against a synthetic repository) and because capture_git puts it on a
	-- git command line.
	local function safe_member(path)
		-- As strict as safe_root, one level down: no dot-leading component and no
		-- "/." at all, so "./tools/a.lua", "tools/./a.lua" and a trailing "/."
		-- are refused.  Without that, one file could enter a caller-supplied list
		-- twice under two spellings and be counted as two distinct members.
		if type(path) ~= "string" or #path == 0 or #path > 200 or
				not path:match("^[A-Za-z0-9_][A-Za-z0-9._/-]*$") or
				path:find("..", 1, true) or path:find("/" .. "/", 1, true) or
				path:find("/.", 1, true) or path:sub(-1) == "/" then
			fail("unsafe closure member: " .. tostring(path))
		end
		return path
	end
	for index = 1, #paths do safe_member(paths[index]) end
	local function member_list(list)
		if list == nil then return paths end
		if type(list) ~= "table" or #list == 0 then fail("closure path list is empty") end
		local seen = {}
		for index = 1, #list do
			local path = safe_member(list[index])
			if seen[path] then fail("closure path list repeats " .. path) end
			seen[path] = true
		end
		return list
	end
	local function capture(repo, seeded, list)
		safe_root(repo)
		local members = member_list(list)
		local files, lines = {}, {}
		for index = 1, #members do
			local path = members[index]
			local bytes = seeded and seeded[path] or read_file(repo .. "/" .. path)
			if type(bytes) ~= "string" then fail("captured bytes are invalid") end
			files[path] = bytes
			lines[index] = path .. "\t" .. hex(raw_sha256(bytes))
		end
		local manifest = table.concat(lines, "\n") .. "\n"
		return {files = files, file_manifest = manifest,
			dag_sha256 = hex(raw_sha256("grug_wp40_t2c_e0_c1_v3_dag_v1\n" .. manifest))}
	end
	local function verify(repo, snapshot)
		if type(snapshot) ~= "table" or type(snapshot.files) ~= "table" or
				type(snapshot.file_manifest) ~= "string" or
				type(snapshot.dag_sha256) ~= "string" then
			fail("snapshot is invalid")
		end
		local current = capture(repo)
		if current.file_manifest ~= snapshot.file_manifest or
				current.dag_sha256 ~= snapshot.dag_sha256 then
			fail("conformance files changed during the run")
		end
		for index = 1, #paths do
			local path = paths[index]
			if current.files[path] ~= snapshot.files[path] then
				fail("conformance bytes changed during the run")
			end
		end
		return true
	end
	local function capture_git(repo, scratch, commit, list)
		safe_root(repo) safe_root(scratch)
		if type(commit) ~= "string" or #commit ~= 40 or
				not commit:match("^[0-9a-f]+$") then fail("pinned commit is invalid") end
		local members = member_list(list)
		local seeded = {}
		for index = 1, #members do
			local output = scratch .. "/v3-conformance-pinned-" .. index .. ".bin"
			local errors = scratch .. "/v3-conformance-pinned-" .. index .. ".err"
			local status, reason, code = os.execute("git -C " .. repo .. " show " ..
				commit .. ":" .. members[index] .. " > " .. output .. " 2> " .. errors)
			if not (status == 0 or status == true and reason == "exit" and code == 0) then
				fail("pinned conformance file is missing: " .. members[index] ..
					git_reason(errors))
			end
			seeded[members[index]] = read_file(output)
		end
		return capture(repo, seeded, members)
	end
	local function load_module(snapshot, path)
		local bytes = snapshot.files[path]
		if type(bytes) ~= "string" then fail("module is outside conformance DAG") end
		local chunk, message = loadstring(bytes, "@" .. path)
		if not chunk then fail("cannot load module: " .. tostring(message)) end
		return chunk()
	end
	local function git_value(repo, scratch, argument, label)
		safe_root(repo) safe_root(scratch)
		local tree_commit = type(argument) == "string" and
			argument:match("^([0-9a-f]+)%^%{tree%}$") or nil
		local plain_commit = type(argument) == "string" and #argument == 40 and
			argument:match("^[0-9a-f]+$")
		if argument ~= "HEAD" and not plain_commit and
				(not tree_commit or #tree_commit ~= 40) then
			fail("git argument changed")
		end
		local output = scratch .. "/v3-conformance-git-" .. label .. ".txt"
		local status, reason, code = os.execute("git -C " .. repo ..
			" rev-parse --verify " .. argument .. " > " .. output)
		if not (status == 0 or status == true and reason == "exit" and code == 0) then
			fail("cannot resolve conformance " .. label)
		end
		local value = read_file(output):match("^([0-9a-f]+)\n$")
		if not value or #value ~= 40 then fail("conformance git id changed") end
		return value
	end
	local function current_provenance(repo, scratch)
		local commit = git_value(repo, scratch, "HEAD", "commit")
		return {commit = commit,
			tree = git_value(repo, scratch, commit .. "^{tree}", "tree")}
	end
	local function validate_provenance(repo, scratch, expected)
		if type(expected) ~= "table" or type(expected.commit) ~= "string" or
				type(expected.tree) ~= "string" or #expected.commit ~= 40 or
				#expected.tree ~= 40 or not expected.commit:match("^[0-9a-f]+$") or
				not expected.tree:match("^[0-9a-f]+$") then
			fail("conformance provenance is invalid")
		end
		local tree = git_value(repo, scratch, expected.commit .. "^{tree}",
			"pinned-tree")
		if tree ~= expected.tree then fail("conformance commit/tree changed") end
		return true
	end
	-- ------------------------------------------- recorded-evidence reuse ----
	-- (1) Every member of the pinned closure must be byte-identical between the
	-- recorded commit and the CURRENT working tree.  The first differing path is
	-- named: "the closure changed" is not an actionable diagnostic, and the
	-- reader has to know whether a rerun is owed to a real input or to an
	-- unrelated edit.
	local function closure_equality(repo, scratch, commit, list)
		local members = member_list(list)
		local pinned = capture_git(repo, scratch, commit, members)
		local working = capture(repo, nil, members)
		for index = 1, #members do
			local path = members[index]
			if pinned.files[path] ~= working.files[path] then
				fail("closure member differs from the recorded commit: " .. path)
			end
		end
		if pinned.file_manifest ~= working.file_manifest or
				pinned.dag_sha256 ~= working.dag_sha256 then
			fail("closure manifest differs from the recorded commit")
		end
		return pinned
	end
	-- (2) The recorded commit must really be a commit of THIS repository's
	-- history.  An object that merely exists (a dangling commit, a tree id, an
	-- object fetched from elsewhere) is refused: --quiet keeps git silent so the
	-- diagnostic below is the only thing a reader sees.
	local function commit_object(repo, scratch, commit)
		safe_root(repo) safe_root(scratch)
		if type(commit) ~= "string" or #commit ~= 40 or
				not commit:match("^[0-9a-f]+$") then
			fail("recorded commit is not a commit id")
		end
		local output = scratch .. "/v3-conformance-recorded-commit.txt"
		local errors = scratch .. "/v3-conformance-recorded-commit.err"
		-- --quiet keeps git silent about an id that is simply not there, so
		-- anything the capture does contain is an environment failure worth
		-- repeating.
		local status, reason, code = os.execute("git -C " .. repo ..
			" rev-parse --verify --quiet " .. commit .. "^{commit} > " .. output ..
			" 2> " .. errors)
		if not (status == 0 or status == true and reason == "exit" and code == 0) then
			fail("recorded commit is not available in this repository: " .. commit ..
				git_reason(errors))
		end
		local value = read_file(output):match("^([0-9a-f]+)\n$")
		if value ~= commit then fail("recorded commit is not a commit object") end
		return value
	end
	local function assert_recorded_history(repo, scratch, commit)
		commit_object(repo, scratch, commit)
		local errors = scratch .. "/v3-conformance-recorded-history.err"
		-- Exit 1 is the plain "not an ancestor" answer and says nothing on
		-- stderr; a higher status is a broken environment and does.
		local status, reason, code = os.execute("git -C " .. repo ..
			" merge-base --is-ancestor " .. commit .. " HEAD > /dev/null 2> " .. errors)
		if not (status == 0 or status == true and reason == "exit" and code == 0) then
			fail("recorded commit is outside repository history: " .. commit ..
				git_reason(errors))
		end
		return true
	end
	-- (3) The three pins come out of the artifact's own bytes.  Shape is checked
	-- before any of them reaches a git command line, duplicates are refused
	-- (an appended second pin line must not be able to redirect the check), and
	-- only the v3 FINAL artifact schema is accepted -- a pre-v3 final artifact
	-- and a v3 result row both carry conformance_* fields and neither is this.
	local final_schema = "grug_wp40_extreme_puc_conformance_v3"
	local function parse_recorded_pins(blob)
		if type(blob) ~= "string" or #blob == 0 or blob:sub(-1) ~= "\n" then
			fail("recorded conformance artifact bytes are invalid")
		end
		local headers = {}
		for line in blob:gmatch("([^\n]*)\n") do
			local name, value = line:match("^([A-Za-z0-9_]+)\t([^\t]*)$")
			if name then
				if headers[name] then
					fail("recorded conformance artifact repeats " .. name)
				end
				headers[name] = value
			end
		end
		if not blob:match("^schema\t" .. final_schema .. "\n") or
				headers.schema ~= final_schema then
			fail("recorded conformance artifact is not a v3 final artifact")
		end
		if headers.status ~= "passed" then
			fail("recorded conformance artifact did not pass")
		end
		local function pin(name, width)
			local value = headers[name]
			if type(value) ~= "string" then
				fail("recorded conformance artifact is missing " .. name)
			end
			if #value ~= width or not value:match("^[0-9a-f]+$") then
				fail("recorded conformance artifact " .. name ..
					" is not a lowercase " .. width .. "-hex id")
			end
			return value
		end
		return {commit = pin("conformance_commit", 40),
			tree = pin("conformance_tree", 40),
			dag = pin("conformance_dag_sha256", 64)}
	end
	-- The composition, in the only order that is fail-closed: read the pins from
	-- the artifact, prove the commit is ours, prove its tree, prove the whole
	-- closure is unchanged, prove the recorded DAG is that closure's DAG -- and
	-- only then re-verify the evidence itself against the RECORDED pins.  The
	-- caller supplies run_finalizer so the composition is testable without a
	-- 24-row conformance; it must re-derive the final artifact from every
	-- retained row (the finalizer's verify mode does exactly that) and return
	-- true only then.
	local function verify_recorded_evidence(options)
		if type(options) ~= "table" then fail("recorded evidence request is invalid") end
		local repo, scratch = options.repo, options.scratch
		safe_root(repo) safe_root(scratch)
		if type(options.run_finalizer) ~= "function" then
			fail("recorded evidence needs a finalizer")
		end
		local members = member_list(options.paths)
		local recorded = parse_recorded_pins(options.artifact_bytes)
		assert_recorded_history(repo, scratch, recorded.commit)
		validate_provenance(repo, scratch, recorded)
		local snapshot = closure_equality(repo, scratch, recorded.commit, members)
		if snapshot.dag_sha256 ~= recorded.dag then
			fail("recorded conformance DAG differs from the pinned closure")
		end
		if options.run_finalizer(recorded) ~= true then
			fail("recorded evidence failed re-verification against its own commit")
		end
		return recorded
	end
	authority.DAG_PREFIX = "grug_wp40_t2c_e0_c1_v3_dag_v1"
	authority.FINAL_ARTIFACT_SCHEMA = final_schema
	authority.paths = paths
	authority.capture = capture
	authority.capture_git = capture_git
	authority.verify = verify
	authority.load_module = load_module
	authority.current_provenance = current_provenance
	authority.validate_provenance = validate_provenance
	authority.closure_equality = closure_equality
	authority.assert_recorded_history = assert_recorded_history
	authority.parse_recorded_pins = parse_recorded_pins
	authority.verify_recorded_evidence = verify_recorded_evidence
	authority.read_file = read_file
	authority.hex = hex
	return authority
end
