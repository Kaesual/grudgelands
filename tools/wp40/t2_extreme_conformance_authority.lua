-- Closed code/artifact graph for T2c-E0-C1 PUC conformance.  The original
-- measurement DAG remains pinned separately to commit 53be77e; this graph
-- owns only later verification/orchestration and retained merge inputs.
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
		"mods/MAPGEN/grug_mapgen/wp40/compiled_schema.lua",
		"mods/MAPGEN/grug_mapgen/wp40/schemas.lua",
		"mods/MAPGEN/grug_mapgen/wp43_handoff.lua",
		"tools/wp40/t2_extreme_authority.lua",
		"tools/wp40/t2_extreme_conformance_authority.lua",
		"tools/wp40/t2_extreme_conformance.lua",
		"tools/wp40/t2_extreme_conformance_test.lua",
		"tools/wp40/t2_extreme_rescore_worker.lua",
		"tools/wp40/t2_extreme_selected_worker.lua",
		"tools/wp40/t2_extreme_conformance_verify.lua",
		"tools/wp40/t2_extreme_conformance_preflight.lua",
		"tools/wp40/t2_extreme_conformance_finalize.lua",
		"tools/wp40/t2_partition_oracle.lua",
		"tools/wp40/t2_partition_test.lua",
		"tools/wp40/run_t2_extreme_conformance.sh",
		"tools/wp40/fixtures/t2_extreme_e0/conformance_gate.lua",
		"tools/wp40/fixtures/t2_extreme_e0/candidates-luajit.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/manifest-luajit.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-0000-0511.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-0512-1023.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-1024-1535.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-1536-2047.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-2048-2559.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-2560-3071.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-3072-3583.tsv",
		"tools/wp40/fixtures/t2_extreme_e0/shard-luajit-3584-4095.tsv",
		"tools/wp43/materials_test.lua",
	}
	local function fail(message)
		error("WP40 T2 conformance authority: " .. message, 0)
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
			dag_sha256 = hex(raw_sha256("grug_wp40_t2c_e0_c1_dag_v1\n" .. manifest))}
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
			local output = scratch .. "/conformance-pinned-" .. index .. ".bin"
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
		local output = scratch .. "/conformance-git-" .. label .. ".txt"
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
		local tree = git_value(repo, scratch, expected.commit .. "^{tree}", "pinned-tree")
		if tree ~= expected.tree then fail("conformance commit/tree changed") end
		return true
	end
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
