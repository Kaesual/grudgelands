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
--     workers, verify/preflight/finalize, the KAT and the runner);
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
	local function capture(repo, seeded)
		safe_root(repo)
		local files, lines = {}, {}
		for index = 1, #paths do
			local path = paths[index]
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
	local function capture_git(repo, scratch, commit)
		safe_root(repo) safe_root(scratch)
		if type(commit) ~= "string" or #commit ~= 40 or
				not commit:match("^[0-9a-f]+$") then fail("pinned commit is invalid") end
		local seeded = {}
		for index = 1, #paths do
			local output = scratch .. "/v3-conformance-pinned-" .. index .. ".bin"
			local status, reason, code = os.execute("git -C " .. repo .. " show " ..
				commit .. ":" .. paths[index] .. " > " .. output)
			if not (status == 0 or status == true and reason == "exit" and code == 0) then
				fail("pinned conformance file is missing")
			end
			seeded[paths[index]] = read_file(output)
		end
		return capture(repo, seeded)
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
	authority.DAG_PREFIX = "grug_wp40_t2c_e0_c1_v3_dag_v1"
	authority.paths = paths
	authority.capture = capture
	authority.capture_git = capture_git
	authority.verify = verify
	authority.load_module = load_module
	authority.current_provenance = current_provenance
	authority.validate_provenance = validate_provenance
	authority.read_file = read_file
	authority.hex = hex
	return authority
end
