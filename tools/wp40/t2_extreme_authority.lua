-- Closed authority snapshot for T2 E0 scalar-measurement shards.
--
-- A worker captures every Lua/scorer input before loading the geometry
-- modules.  It loads those modules from the captured bytes and verifies the
-- same bytes again immediately before publishing a shard.  The WP43 harness
-- is intentionally not part of this code graph: only its normalized,
-- data-only vocabulary projection is consumed by Stage 1, and that projection
-- has its own frozen digest below.
return function(dependencies)
	assert(type(dependencies) == "table")
	local raw_sha256 = assert(dependencies.raw_sha256)

	local authority = {}
	local paths = {
		"mods/MAPGEN/grug_mapgen/wp40/canonical.lua",
		"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/extreme.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua",
		"mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua",
		"mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua",
		"mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua",
		"mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua",
		"tools/wp40/fixtures/t2_extreme_e0/full_scan_gate.lua",
		"tools/wp40/fixtures/t2_extreme_e0/vocabulary.lua",
		"tools/wp40/run_t2_extreme_shard.sh",
		"tools/wp40/run_t2_extreme_shards.sh",
		"tools/wp40/t2_extreme_authority.lua",
		"tools/wp40/t2_extreme_gate_check.lua",
		"tools/wp40/t2_extreme_merge.lua",
		"tools/wp40/t2_extreme_shard_worker.lua",
		"tools/wp40/t2_extreme_verify_shard.lua",
		"tools/wp40/t2_sha256_batch.py",
	}
	local expected_vocabulary_sha256 =
		"6d77298bb1861e91fb306bfe59cc8996bc64d7544034b47ed7465ba9c4aa164f"

	local function fail(message)
		error("WP40 T2 extreme authority: " .. message, 0)
	end

	local function hex(bytes)
		return (bytes:gsub(".", function(byte)
			return ("%02x"):format(string.byte(byte))
		end))
	end

	local function safe_root(repo)
		if type(repo) ~= "string" or
				not repo:match("^/[A-Za-z0-9._/-]+$") or
				repo:find("/../", 1, true) or repo:find("/./", 1, true) or
				repo:find("//", 1, true) then
			fail("repository path is unsafe")
		end
	end

	local function read_file(path)
		local file = io.open(path, "rb")
		if not file then fail("cannot read " .. path) end
		local bytes = file:read("*a")
		if not bytes or not file:close() then fail("cannot read " .. path) end
		return bytes
	end

	local function capture_files(repo, seeded)
		safe_root(repo)
		if seeded ~= nil and type(seeded) ~= "table" then
			fail("seeded file bytes are invalid")
		end
		local files = {}
		local lines = {}
		for index = 1, #paths do
			local path = paths[index]
			local bytes = seeded and seeded[path] or nil
			if bytes == nil then bytes = read_file(repo .. "/" .. path) end
			if type(bytes) ~= "string" then fail("file bytes are invalid") end
			files[path] = bytes
			lines[index] = path .. "\t" .. hex(raw_sha256(bytes))
		end
		return {files = files, file_manifest = table.concat(lines, "\n") .. "\n"}
	end

	local function capture_git_files(repo, scratch, commit)
		safe_root(repo)
		safe_root(scratch)
		if type(commit) ~= "string" or #commit ~= 40 or
				not commit:match("^[0-9a-f]+$") then
			fail("pinned Authority-DAG commit is invalid")
		end
		local type_output = scratch .. "/authority-pinned-type.txt"
		local status, reason, code = os.execute("git -C " .. repo ..
			" cat-file -t " .. commit .. " > " .. type_output)
		if not (status == 0 or status == true and reason == "exit" and code == 0) or
				read_file(type_output) ~= "commit\n" then
			fail("pinned Authority-DAG commit is invalid")
		end
		local seeded = {}
		for index = 1, #paths do
			local output = scratch .. "/authority-pinned-file-" .. index .. ".bin"
			status, reason, code = os.execute("git -C " .. repo .. " show " ..
				commit .. ":" .. paths[index] .. " > " .. output)
			if not (status == 0 or status == true and reason == "exit" and code == 0) then
				fail("pinned Authority-DAG file is missing")
			end
			seeded[paths[index]] = read_file(output)
		end
		return capture_files(repo, seeded)
	end

	local function plain_array(value, context)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail(context .. " is not a plain array")
		end
		local count = 0
		for key in pairs(value) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
				fail(context .. " is not dense")
			end
			if key > count then count = key end
		end
		for index = 1, count do
			if value[index] == nil then fail(context .. " is not dense") end
		end
		return count
	end

	local function atom(value, context)
		if type(value) ~= "string" or value == "" or
				not value:match("^[a-zA-Z0-9_:.-]+$") then
			fail(context .. " is not a canonical atom")
		end
		return value
	end
	local function optional_atom(value, context)
		if value == nil then return "-" end
		return atom(value, context)
	end

	local function vocabulary_blob(vocabulary)
		if type(vocabulary) ~= "table" or getmetatable(vocabulary) ~= nil then
			fail("vocabulary is not a plain table")
		end
		local allowed = {resource_keys = true, resource_rows = true,
			cultural_keys = true, wood_keys = true}
		for key in pairs(vocabulary) do
			if not allowed[key] then fail("vocabulary has an unknown field") end
		end
		local lines = {"grug_wp40_extreme_vocabulary_projection_v1"}
		for _, family in ipairs({"resource_keys", "cultural_keys", "wood_keys"}) do
			local rows = vocabulary[family]
			local count = plain_array(rows, family)
			for index = 1, count do
				lines[#lines + 1] = family .. "\t" .. index .. "\t" ..
					atom(rows[index], family .. " key")
			end
		end
		local rows = vocabulary.resource_rows
		local count = plain_array(rows, "resource_rows")
		for index = 1, count do
			local row = rows[index]
			if type(row) ~= "table" or getmetatable(row) ~= nil then
				fail("resource row is not a plain table")
			end
			lines[#lines + 1] = table.concat({"resource_rows", index,
				atom(row.key, "resource key"), atom(row.scope, "resource scope"),
				optional_atom(row.grade, "resource grade")}, "\t")
		end
		return table.concat(lines, "\n") .. "\n"
	end

	local function bind_vocabulary(snapshot, vocabulary)
		if type(snapshot) ~= "table" or type(snapshot.files) ~= "table" or
				type(snapshot.file_manifest) ~= "string" then
			fail("file snapshot is invalid")
		end
		local blob = vocabulary_blob(vocabulary)
		local digest = hex(raw_sha256(blob))
		if expected_vocabulary_sha256 ~= "PENDING" and
				digest ~= expected_vocabulary_sha256 then
			fail("normalized vocabulary projection changed")
		end
		local authority_blob = snapshot.file_manifest ..
			"normalized_vocabulary\t" .. digest .. "\n"
		return {files = snapshot.files, file_manifest = snapshot.file_manifest,
			vocabulary_blob = blob, vocabulary_sha256 = digest,
			authority_blob = authority_blob,
			authority_dag_sha256 = hex(raw_sha256(authority_blob))}
	end

	local function bind_expected_vocabulary(snapshot)
		if expected_vocabulary_sha256 == "PENDING" then
			fail("normalized vocabulary digest is not frozen")
		end
		local authority_blob = snapshot.file_manifest ..
			"normalized_vocabulary\t" .. expected_vocabulary_sha256 .. "\n"
		return {files = snapshot.files, file_manifest = snapshot.file_manifest,
			vocabulary_sha256 = expected_vocabulary_sha256,
			authority_blob = authority_blob,
			authority_dag_sha256 = hex(raw_sha256(authority_blob))}
	end

	local function verify(repo, snapshot, vocabulary)
		local current = capture_files(repo)
		if current.file_manifest ~= snapshot.file_manifest then
			fail("Authority-DAG files changed during the run")
		end
		for index = 1, #paths do
			local path = paths[index]
			if current.files[path] ~= snapshot.files[path] then
				fail("Authority-DAG bytes changed during the run")
			end
		end
		if vocabulary then
			local blob = vocabulary_blob(vocabulary)
			if blob ~= snapshot.vocabulary_blob or
					hex(raw_sha256(blob)) ~= snapshot.vocabulary_sha256 then
				fail("normalized vocabulary changed during the run")
			end
		end
		return true
	end

	local function load_module(snapshot, path)
		local bytes = snapshot.files[path]
		if type(bytes) ~= "string" then fail("module is outside Authority-DAG") end
		local chunk, message = loadstring(bytes, "@" .. path)
		if not chunk then fail("cannot load " .. path .. ": " .. tostring(message)) end
		return chunk()
	end

	local function git_provenance(repo, scratch)
		safe_root(repo)
		safe_root(scratch)
		local function resolve(argument, label)
			local output = scratch .. "/authority-git-" .. label .. ".txt"
			local status, reason, code = os.execute("git -C " .. repo ..
				" rev-parse --verify " .. argument .. " > " .. output)
			if not (status == 0 or status == true and reason == "exit" and code == 0) then
				fail("cannot resolve " .. label)
			end
			local value = read_file(output):match("^([0-9a-f]+)\n$")
			if not value or #value ~= 40 then fail("invalid " .. label) end
			return value
		end
		local commit = resolve("HEAD", "commit")
		return {commit = commit, tree = resolve(commit .. "^{tree}", "tree")}
	end

	local function verify_git_provenance(repo, scratch, commit, tree)
		safe_root(repo)
		safe_root(scratch)
		if type(commit) ~= "string" or #commit ~= 40 or
				not commit:match("^[0-9a-f]+$") or type(tree) ~= "string" or
				#tree ~= 40 or not tree:match("^[0-9a-f]+$") then
			fail("commit/tree provenance changed")
		end
		local type_output = scratch .. "/authority-git-pinned-type.txt"
		local status, reason, code = os.execute("git -C " .. repo ..
			" cat-file -t " .. commit .. " > " .. type_output)
		if not (status == 0 or status == true and reason == "exit" and code == 0) or
				read_file(type_output) ~= "commit\n" then
			fail("commit/tree provenance changed")
		end
		local output = scratch .. "/authority-git-pinned-tree.txt"
		status, reason, code = os.execute("git -C " .. repo ..
			" rev-parse --verify " .. commit .. "^{tree} > " .. output)
		if not (status == 0 or status == true and reason == "exit" and code == 0) then
			fail("commit/tree provenance changed")
		end
		local actual_tree = read_file(output):match("^([0-9a-f]+)\n$")
		if actual_tree ~= tree then
			fail("commit/tree provenance changed")
		end
		return true
	end

	local function canonical_measurement_ranges()
		local ranges = {}
		for index = 1, 8 do
			local first = (index - 1) * 512
			ranges[index] = {first = first, last = first + 511}
		end
		return ranges
	end

	local function validate_measurement_ranges(ranges)
		if plain_array(ranges, "measurement ranges") ~= 8 then
			fail("measurement requires exactly eight ranges")
		end
		for index = 1, 8 do
			local row = ranges[index]
			if type(row) ~= "table" or getmetatable(row) ~= nil then
				fail("measurement range is not a plain table")
			end
			local fields = 0
			for key in pairs(row) do
				if key ~= "first" and key ~= "last" then
					fail("measurement range has an unknown field")
				end
				fields = fields + 1
			end
			local first = (index - 1) * 512
			if fields ~= 2 or row.first ~= first or row.last ~= first + 511 then
				fail("measurement range partition changed")
			end
		end
		return true
	end

	local function retained_shard_path(first, last)
		if type(first) ~= "number" or type(last) ~= "number" or
				first % 1 ~= 0 or last % 1 ~= 0 then
			fail("retained shard range is invalid")
		end
		local expected
		for index = 1, 8 do
			local range_first = (index - 1) * 512
			if first == range_first and last == range_first + 511 then
				expected = ("tools/wp40/fixtures/t2_extreme_e0/" ..
					"shard-luajit-%04d-%04d.tsv"):format(first, last)
				break
			end
		end
		if not expected then fail("retained shard range is not canonical") end
		return expected
	end

	local function validate_retained_shard_path(path, first, last)
		if path ~= retained_shard_path(first, last) then
			fail("retained shard path is not canonical repo-relative text")
		end
		return true
	end

	local function validate_full_scan_gate(gate, expected)
		if type(gate) ~= "table" or getmetatable(gate) ~= nil then
			fail("full-scan gate is not a plain table")
		end
		local fields = {status = true, source_checksum = true,
			boundary_policy_checksum = true, partition_sha256 = true}
		local count = 0
		for key, value in pairs(gate) do
			if not fields[key] or type(value) ~= "string" then
				fail("full-scan gate has an unknown field")
			end
			count = count + 1
		end
		if count ~= 4 or gate.status ~= "enabled_after_r16_r17_refreeze" then
			fail("full-scan gate is not enabled")
		end
		for _, field in ipairs({"source_checksum", "boundary_policy_checksum",
				"partition_sha256"}) do
			if #gate[field] ~= 64 or not gate[field]:match("^[0-9a-f]+$") then
				fail("full-scan gate " .. field .. " is invalid")
			end
		end
		if expected ~= nil then
			if type(expected) ~= "table" or getmetatable(expected) ~= nil then
				fail("full-scan expected pins are invalid")
			end
			for key, value in pairs(expected) do
				if not fields[key] or key == "status" or type(value) ~= "string" then
					fail("full-scan expected pins are invalid")
				end
				if gate[key] ~= value then fail("full-scan " .. key .. " differs") end
			end
		end
		return true
	end

	local function preparse_shard_provenance(blob)
		if type(blob) ~= "string" or blob == "" or blob:sub(-1) ~= "\n" or
				blob:find("\r", 1, true) or blob:find(string.char(0), 1, true) then
			fail("candidate shard provenance framing is invalid")
		end
		local lines = {}
		for line in blob:gmatch("([^\n]*)\n") do
			lines[#lines + 1] = line
			if #lines == 18 then break end
		end
		local names = {"schema", "range", "source_checksum",
			"boundary_policy_checksum", "partition_sha256", "authority_dag_sha256",
			"authority_commit", "authority_tree", "interpreter_id",
			"interpreter_launcher", "interpreter_path", "interpreter_version",
			"interpreter_sha256", "measurement_scope", "stage2_status",
			"scorer_schema", "rows_sha256"}
		if #lines ~= 18 or lines[18] == "" or
				lines[18]:sub(1, 16) ~= "candidate_index\t" then
			fail("candidate shard provenance header changed")
		end
		local values = {}
		for index = 1, 17 do
			local name, value = lines[index]:match("^([^\t]+)\t([^\t]+)$")
			if index == 2 then
				name = lines[index]:match("^([^\t]+)\t")
				value = "range"
			end
			if name ~= names[index] or not value then
				fail("candidate shard provenance header changed")
			end
			values[names[index]] = value
		end
		if values.schema ~= "grug_wp40_extreme_candidate_shard_v2" then
			fail("candidate shard provenance schema changed")
		end
		for _, field in ipairs({"authority_dag_sha256", "partition_sha256"}) do
			if #values[field] ~= 64 or not values[field]:match("^[0-9a-f]+$") then
				fail("candidate shard provenance digest is invalid")
			end
		end
		for _, field in ipairs({"authority_commit", "authority_tree"}) do
			if #values[field] ~= 40 or not values[field]:match("^[0-9a-f]+$") then
				fail("candidate shard provenance commit/tree is invalid")
			end
		end
		return {authority_dag_sha256 = values.authority_dag_sha256,
			authority_commit = values.authority_commit,
			authority_tree = values.authority_tree,
			partition_sha256 = values.partition_sha256}
	end

	local function validate_pinned_authority(repo, scratch, provenance)
		if type(provenance) ~= "table" or getmetatable(provenance) ~= nil then
			fail("pinned shard provenance is invalid")
		end
		local allowed = {authority_commit = true, authority_tree = true,
			authority_dag_sha256 = true, partition_sha256 = true}
		local count = 0
		for key, value in pairs(provenance) do
			if not allowed[key] or type(value) ~= "string" then
				fail("pinned shard provenance is invalid")
			end
			count = count + 1
		end
		if count ~= 4 then fail("pinned shard provenance is invalid") end
		for _, field in ipairs({"authority_dag_sha256", "partition_sha256"}) do
			local value = provenance[field]
			if #value ~= 64 or not value:match("^[0-9a-f]+$") then
				fail("pinned shard provenance is invalid")
			end
		end
		verify_git_provenance(repo, scratch, provenance.authority_commit,
			provenance.authority_tree)
		local pinned = bind_expected_vocabulary(capture_git_files(repo, scratch,
			provenance.authority_commit))
		if pinned.authority_dag_sha256 ~= provenance.authority_dag_sha256 then
			fail("pinned commit Authority-DAG differs")
		end
		local partition_path =
			"mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua"
		if hex(raw_sha256(pinned.files[partition_path])) ~=
				provenance.partition_sha256 then
			fail("pinned commit partition bytes differ")
		end
		return pinned
	end

	authority.paths = paths
	authority.expected_vocabulary_sha256 = expected_vocabulary_sha256
	authority.capture_files = capture_files
	authority.capture_git_files = capture_git_files
	authority.vocabulary_blob = vocabulary_blob
	authority.bind_vocabulary = bind_vocabulary
	authority.bind_expected_vocabulary = bind_expected_vocabulary
	authority.verify = verify
	authority.load_module = load_module
	authority.git_provenance = git_provenance
	authority.verify_git_provenance = verify_git_provenance
	authority.canonical_measurement_ranges = canonical_measurement_ranges
	authority.validate_measurement_ranges = validate_measurement_ranges
	authority.retained_shard_path = retained_shard_path
	authority.validate_retained_shard_path = validate_retained_shard_path
	authority.validate_full_scan_gate = validate_full_scan_gate
	authority.preparse_shard_provenance = preparse_shard_provenance
	authority.validate_pinned_authority = validate_pinned_authority
	return authority
end
