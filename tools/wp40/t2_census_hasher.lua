-- Persistent SHA-256 hasher for the WP40 T2 census (plan section 6.6, M2).
--
-- Measured on one seed-0 Scan-1 pass: 639,512 raw_sha256 calls, 1,004 of them
-- distinct, ~1.0 MB of input.  The memo below absorbs 99.8% of the calls; what
-- remains is 1,004 sha256sum forks per seed, and the fork cost is the whole
-- gap between the pass's 22.7 s CPU and its ~24 s wall.  Over full `W` that is
-- roughly 90 worker-minutes spent on process creation.
--
-- The digests are hashlib's, byte for byte what sha256sum returns, and every
-- session proves that twice: three fixed vectors before the first geometry
-- call, and the first eight real inputs compared against a direct fork.  The
-- pinned census KAT digest is the standing third proof.
return function(dependencies)
	assert(type(dependencies) == "table")
	local repo = assert(dependencies.repo, "repository root required")
	local scratch = assert(dependencies.scratch, "scratch directory required")

	local function fail(message)
		error("WP40 T2 census hasher: " .. message, 0)
	end

	for _, path in ipairs({repo, scratch}) do
		if type(path) ~= "string" or not path:match("^/[A-Za-z0-9._/-]+$") or
				path:find("/../", 1, true) or path:find("/./", 1, true) or
				path:find("//", 1, true) then
			fail("path is unsafe")
		end
	end

	local function from_hex(value)
		return (value:gsub("..", function(pair)
			return string.char(assert(tonumber(pair, 16)))
		end))
	end

	local function shell(command)
		local status, reason, code = os.execute(command)
		return status == 0 or status == true and reason == "exit" and code == 0
	end

	local direct_calls = 0
	-- The reference implementation, kept for the proofs and as the fallback:
	-- one fixed tempfile pair, because per-call names accumulated ~2,000 dead
	-- files per seed before the shell trap fired.
	local function direct_raw_sha256(data)
		direct_calls = direct_calls + 1
		local input = scratch .. "/sha-input.bin"
		local output = scratch .. "/sha-output.txt"
		local file = assert(io.open(input, "wb"))
		assert(file:write(data)) assert(file:close())
		if not shell("sha256sum " .. input .. " > " .. output) then
			fail("sha256sum failed")
		end
		file = assert(io.open(output, "rb"))
		local digest = from_hex(assert(assert(file:read("*l")):match("^([0-9a-f]+)")))
		assert(file:close())
		if #digest ~= 32 then fail("sha256sum returned no digest") end
		return digest
	end

	-- Hashing a finished shard means hashing millions of bytes that are already
	-- on disk; streaming the file through sha256sum keeps them out of the Lua
	-- heap and yields the same digest the verifier recomputes.
	local function raw_sha256_file(path)
		direct_calls = direct_calls + 1
		local output = scratch .. "/sha-output.txt"
		if not shell("sha256sum " .. path .. " > " .. output) then
			fail("sha256sum failed on " .. path)
		end
		local file = assert(io.open(output, "rb"))
		local digest = from_hex(assert(assert(file:read("*l")):match("^([0-9a-f]+)")))
		assert(file:close())
		if #digest ~= 32 then fail("sha256sum returned no digest") end
		return digest
	end

	local request_path = scratch .. "/census-sha-request.fifo"
	local response_path = scratch .. "/census-sha-response.fifo"
	local server_path = repo .. "/tools/wp40/t2_census_sha_server.py"
	local request_file, response_file

	local function start_server()
		local probe = io.open(server_path, "rb")
		if not probe then fail("the SHA responder script is missing") end
		assert(probe:close())
		-- Both failure modes below would otherwise show up as a client that
		-- blocks forever on its first FIFO open, which is the worst shape a
		-- multi-hour run can fail in.
		if not shell("command -v python3 >/dev/null 2>&1") then
			fail("python3 is required for the persistent hasher and was not found")
		end
		if not shell("python3 -c 'import sys; compile(open(sys.argv[1]).read(), " ..
				"sys.argv[1], \"exec\")' " .. server_path .. " >/dev/null 2>&1") then
			fail("the SHA responder script does not compile")
		end
		os.remove(request_path) os.remove(response_path)
		if not shell("mkfifo " .. request_path .. " " .. response_path) then
			fail("could not create the hasher FIFOs")
		end
		if not shell("python3 " .. server_path .. " " .. request_path .. " " ..
				response_path .. " </dev/null >/dev/null 2>&1 &") then
			fail("could not start the SHA responder")
		end
		-- Open order mirrors the responder's: request side first, so the two
		-- blocking opens rendezvous instead of deadlocking.
		request_file = assert(io.open(request_path, "wb"))
		response_file = assert(io.open(response_path, "rb"))
	end

	local cache = {}
	local calls, misses = 0, 0
	local proof_inputs = 0

	local function server_raw_sha256(data)
		assert(request_file:write(tostring(#data), "\n", data))
		assert(request_file:flush())
		local digest = response_file:read(32)
		if type(digest) ~= "string" or #digest ~= 32 then
			fail("the SHA responder stopped answering")
		end
		return digest
	end

	local function raw_sha256(data)
		calls = calls + 1
		local cached = cache[data]
		if cached then return cached end
		misses = misses + 1
		local digest = server_raw_sha256(data)
		if proof_inputs < 8 then
			if digest ~= direct_raw_sha256(data) then
				fail("the responder digest differs from sha256sum")
			end
			proof_inputs = proof_inputs + 1
		end
		cache[data] = digest
		return digest
	end

	start_server()

	-- Fixed vectors before any geometry runs: framing, empty input and raw
	-- bytes above 0x7f are exactly where a transport bug would hide.
	local vectors = {
		{bytes = "", digest =
			"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"},
		{bytes = "abc", digest =
			"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"},
		{bytes = string.char(0, 255, 1, 254), digest =
			"5d8d910591d272938aef5f966e0816e374beaf7b5adf02cca5f8f770596c2ce3"},
	}
	for index = 1, #vectors do
		local vector = vectors[index]
		local served = server_raw_sha256(vector.bytes)
		if served ~= from_hex(vector.digest) or served ~= direct_raw_sha256(vector.bytes) then
			fail("fixed SHA vector " .. index .. " changed")
		end
	end

	local hasher = {}
	hasher.raw_sha256 = raw_sha256
	hasher.direct_raw_sha256 = direct_raw_sha256
	hasher.raw_sha256_file = raw_sha256_file
	-- The census memo has zero cross-seed reuse -- every noise input embeds the
	-- seed -- so dropping it between seeds bounds worker memory without
	-- changing a single emitted byte.
	function hasher.forget()
		cache = {}
	end
	function hasher.stats()
		return {calls = calls, misses = misses, direct_calls = direct_calls,
			proof_inputs = proof_inputs}
	end
	function hasher.close()
		if request_file then request_file:close() request_file = nil end
		if response_file then response_file:close() response_file = nil end
		os.remove(request_path) os.remove(response_path)
	end
	return hasher
end
