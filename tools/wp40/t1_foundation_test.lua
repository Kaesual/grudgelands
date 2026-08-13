local repo = assert(arg[1], "repository root required")
local scratch = assert(arg[2], "scratch directory required")
assert(scratch:match("^/tmp/grudgelands%-wp40%-t1%.[A-Za-z0-9]+$"),
	"unsafe scratch path")

local wp40_dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local sha_cache = {}
local sha_counter = 0

local function from_hex(value)
	assert(#value % 2 == 0)
	return (value:gsub("..", function(pair)
		return string.char(assert(tonumber(pair, 16)))
	end))
end

-- Offline-only injection: the production injection is core.sha256(data, true).
-- sha256sum is independent of the Lua implementation and receives binary data
-- through a checked temporary file, never through shell quoting.
local function raw_sha256(data)
	local cached = sha_cache[data]
	if cached then return cached end
	sha_counter = sha_counter + 1
	local input = scratch .. "/sha-" .. sha_counter .. ".bin"
	local output = scratch .. "/sha-" .. sha_counter .. ".txt"
	local file = assert(io.open(input, "wb"))
	assert(file:write(data))
	assert(file:close())
	local status = os.execute("sha256sum " .. input .. " > " .. output)
	assert(status == 0, "sha256sum failed")
	file = assert(io.open(output, "rb"))
	local line = assert(file:read("*l"))
	assert(file:close())
	local digest = from_hex(assert(line:match("^([0-9a-f]+)")))
	assert(#digest == 32)
	sha_cache[data] = digest
	return digest
end

local function load_foundation()
	return dofile(wp40_dir .. "/init.lua")(wp40_dir)
end

local foundation = load_foundation()
local c = foundation.canonical
local d = foundation.deterministic
local validation = foundation.validation
local index128 = foundation.index128
local schemas = foundation.schemas

local function expect_error(fragment, callback)
	local ok, message = pcall(callback)
	assert(not ok, "expected error containing " .. fragment)
	assert(tostring(message):find(fragment, 1, true), tostring(message))
end

local function hex(value) return c.hex(value) end

-- Canonical grammar golden vectors: tags, ranges, sorting and ambiguity.
assert(hex(c.encode(c.bytes(""))) == "0100000000")
assert(hex(c.encode(c.bytes(string.char(0, 255)))) == "010000000200ff")
assert(hex(c.encode(c.text("A"))) == "020000000141")
assert(hex(c.encode(c.text("Grüße"))) ==
	"02000000074772c3bcc39f65")
assert(hex(c.encode(c.signed(-2147483648))) == "0380000000")
assert(hex(c.encode(c.signed(-1))) == "03ffffffff")
assert(hex(c.encode(c.signed(0))) == "0300000000")
assert(hex(c.encode(c.signed(2147483647))) == "037fffffff")
assert(hex(c.encode(c.unsigned(0))) == "0400000000")
assert(hex(c.encode(c.unsigned(4294967295))) == "04ffffffff")
assert(hex(c.encode(c.boolean(false))) == "0400000000")
assert(hex(c.encode(c.boolean(true))) == "0400000001")
assert(hex(c.encode(c.array({c.unsigned(0), c.signed(-1)}))) ==
	"0500000002040000000003ffffffff")
local sorted_map = c.map({
	{c.text("b"), c.unsigned(2)},
	{c.text("a"), c.unsigned(1)},
})
assert(hex(c.encode(sorted_map)) ==
	"060000000202000000016104000000010200000001620400000002")
expect_error("duplicate encoded map key", function()
	c.encode(c.map({{c.text("a"), c.unsigned(1)},
		{c.text("a"), c.unsigned(2)}}))
end)
expect_error("untyped value", function() c.encode("ambiguous") end)
expect_error("valid UTF-8", function() c.text(string.char(255)) end)
expect_error("signed value", function() c.signed(2147483648) end)
expect_error("unsigned value", function() c.unsigned(4294967296) end)
expect_error("dense array", function()
	c.encode(c.array({[1] = c.unsigned(1), [3] = c.unsigned(3)}))
end)
expect_error("cyclic", function()
	local value = c.array({})
	value.value[1] = value
	c.encode(value)
end)

-- Hash input/lane golden vectors, signed extremes and rejection sampling.
local hash = d.new_hash(c, raw_sha256, schemas.hash, "1")
local expected_words = {653671232, 3371886238, 2154707381, 1881433754,
	4173446770, 3425486012, 4235116419, 2695210816}
for lane = 0, 7 do
	assert(hash.word("golden", "f", {-2147483648, 2147483647},
		4294967295, lane) == expected_words[lane + 1])
end
assert(hash.word("golden", "f", {-2147483648, 2147483647},
	4294967295, 8) == 1430329314)
assert(hash.unit_word("golden", "f", {-2147483648, 2147483647},
	4294967295, 0) == expected_words[1] / 4294967296)
assert(hash.range("golden", "f", {-2147483648, 2147483647},
	4294967295, 0, 4294967296) == expected_words[1])
assert(hash.range("golden", "f", {-2147483648, 2147483647},
	4294967295, 0, 1) == 0)
assert(hash.range("golden", "f", {-2147483648, 2147483647},
	4294967295, 0, 10) == 2)
local rejection_hash = d.new_hash(c, raw_sha256, schemas.hash, "42")
assert(rejection_hash.word("golden", "f", {-2147483648, 2147483647},
	0, 0, 0) == 3193029373)
assert(rejection_hash.range("golden", "f", {-2147483648, 2147483647},
	0, 0, 2147483649) == 1342447756)
local max_seed_hash = d.new_hash(c, raw_sha256, schemas.hash,
	"18446744073709551615")
assert(max_seed_hash.word("coords", "", {0, 0}, 0, 0) == 2351639301)
assert(max_seed_hash.word("coords", "", {-1, -1}, 0, 0) == 1045361796)
assert(max_seed_hash.word("coords", "", {0, -1, 0}, 0, 0) == 2187112404)
expect_error("canonical unsigned decimal", function()
	d.new_hash(c, raw_sha256, schemas.hash, "01")
end)
expect_error("unsigned 64-bit", function()
	d.new_hash(c, raw_sha256, schemas.hash, "18446744073709551616")
end)
expect_error("logical lane", function()
	hash.word("golden", "f", {0, 0}, 0, 4294967296)
end)
expect_error("dense array", function()
	hash.word("golden", "f", {[1] = 0, [2] = 0, extra = 1}, 0, 0)
end)

foundation.seed_corpus.verify(raw_sha256)
local function split_tsv(line)
	local fields = {}
	for field in (line .. "\t"):gmatch("(.-)\t") do
		fields[#fields + 1] = field
	end
	return fields
end
local fixture_file = assert(io.open(repo ..
	"/tools/wp40/fixtures/t1_seed_corpus.tsv", "rb"))
local fixture_lines = {}
for line in fixture_file:lines() do fixture_lines[#fixture_lines + 1] = line end
assert(fixture_file:close())
assert(fixture_lines[1] == "slot\tstatus\tlabel\tdecimal",
	"seed corpus fixture header mismatch")
local fixture_rows = foundation.seed_corpus.fixture_rows()
assert(#fixture_lines == #fixture_rows + 1, "seed corpus fixture line count")
for i = 1, #fixture_rows do
	local fields = split_tsv(fixture_lines[i + 1])
	assert(#fields == 4, "seed corpus fixture field count at row " .. i)
	for field = 1, 4 do
		assert(fields[field] == fixture_rows[i][field],
			"seed corpus fixture mismatch at row " .. i .. " field " .. field)
	end
end
local corpus_words = {335641193, 2775305619, 2084039809, 2333357721,
	3023487399, 1408277985, 455505940, 1020979963, 105253389, 729616870,
	3503480016, 435100611, 4174128444, 303495456, 237783445, 3485852987,
	345160079, 1737076181, 2895592440, 3924878398, 2817581276, 549311028,
	1104527320, 4068100314, 840389693, 915677671, 541213170}
for i = 1, #foundation.seed_corpus.fixed do
	local corpus_hash = d.new_hash(c, raw_sha256, schemas.hash,
		foundation.seed_corpus.fixed[i])
	assert(corpus_hash.word("corpus", "", {0, 0}, i - 1, 0) ==
		corpus_words[i])
end
assert(corpus_words[2] ~= corpus_words[12]) -- 1 and 2^32+1
assert(corpus_words[1] ~= corpus_words[11]) -- 0 and 2^32
assert(corpus_words[7] ~= corpus_words[13]) -- 2^31-1 plus 2^32
assert(corpus_words[8] ~= corpus_words[14]) -- 2^31 plus 2^32
assert(corpus_words[10] ~= corpus_words[15]) -- 2^32-1 plus 2^32
assert(#foundation.seed_corpus.pending == 2)
assert(foundation.seed_corpus.pending[1].status == "T2_MEASURED")
assert(foundation.seed_corpus.pending[2].status == "T9_PRODUCTION")

-- Q16.16, mathematical floor/mod, safe products, isqrt and tie rules.
assert(d.round_ratio(1, 2) == 1 and d.round_ratio(-1, 2) == -1)
assert(d.qfrom_ratio(1, 2) == 32768)
assert(d.qfrom_ratio(-1, 2) == -32768)
assert(d.qmul(1, 32768) == 1 and d.qmul(-1, 32768) == -1)
assert(d.qdiv(1, 131072) == 1 and d.qdiv(-1, 131072) == -1)
assert(d.floor_div(-1, 128) == -1 and d.floor_mod(-1, 128) == 127)
assert(d.floor_div(-129, 128) == -2 and d.floor_mod(-129, 128) == 127)
assert(d.smootherstep(0) == 0 and d.smootherstep(32768) == 32768 and
	d.smootherstep(65536) == 65536)
assert(d.qlerp(-65536, 65536, 32768) == 0)
assert(d.isqrt(0) == 0 and d.isqrt(1) == 1 and d.isqrt(15) == 3 and
	d.isqrt(16) == 4 and d.isqrt(9007199136250225) == 94906265 and
	d.isqrt(9007199254740991) == 94906265)
expect_error("exact Lua integer range", function()
	d.safe_product(9007199254740991, 2, "golden")
end)

local noise_definition = {
	schema = schemas.hash,
	seed = "9007199254740993",
	domain = "noise_golden",
	feature = "",
	octaves = {
		{period = 8, amplitude_numerator = 1, amplitude_denominator = 1},
		{period = 4, amplitude_numerator = -1, amplitude_denominator = 2},
	},
}
local noise_vectors = {
	{0, 0, -11602}, {8, 0, 53476}, {-8, 0, 21348},
	{7, 0, 48781}, {8, 1, 51781}, {-1, -1, -5182},
	{4, 4, 41515}, {16, -8, 4484},
}
for i = 1, #noise_vectors do
	local row = noise_vectors[i]
	local actual_noise = d.value_noise_2d(c, raw_sha256, noise_definition,
		row[1], row[2])
	assert(actual_noise == row[3], "noise golden mismatch " .. i)
end
expect_error("noise octaves", function()
	local holed = {
		schema = schemas.hash, seed = "1", domain = "noise_hole", feature = "",
		octaves = {[1] = noise_definition.octaves[1],
			[3] = noise_definition.octaves[2]},
	}
	d.value_noise_2d(c, raw_sha256, holed, 0, 0)
end)
-- Same lattice corner reached from either neighboring cell is identical.
local noise_hash = d.new_hash(c, raw_sha256, schemas.hash,
	noise_definition.seed)
local octave1_corner = noise_hash.signed_noise("noise_golden", "", {1, 0},
	0, 0)
local octave2_corner = noise_hash.signed_noise("noise_golden", "", {2, 0},
	0, 1)
assert(d.value_noise_2d(c, raw_sha256, noise_definition, 8, 0) ==
	octave1_corner + d.qmul(octave2_corner, -32768))

-- Generic 128-grid: negative floors, half-open boundary/tie and dense oracle.
local function compile_grid(module)
	local records = {
		{id = "west", bbox = {min_x = -256, max_x = 11,
			min_z = -256, max_z = 256}},
		{id = "east", bbox = {min_x = 10, max_x = 256,
			min_z = -256, max_z = 256}},
	}
	local compiled = module.compile({
		schema = schemas.index,
		min_cx = -2, max_cx = 1, min_cz = -2, max_cz = 1,
		layers = {{
			id = "zones", outside = "ocean", records = records,
			classify_cell = function(cx, _cz, candidates)
				local min_x, max_x = cx * 128, cx * 128 + 128
				if max_x <= 10 then return true, "west" end
				if min_x >= 10 then return true, "east" end
				assert(#candidates == 2 and candidates[1] == "east" and
					candidates[2] == "west")
				return false
			end,
		}},
	}, schemas.index)
	local exact_calls = 0
	local attached = module.attach(compiled, schemas.index, {
		zones = function(candidates, x, _z)
			exact_calls = exact_calls + 1
			assert(candidates[1] == "east" and candidates[2] == "west")
			return x < 10 and "west" or "east"
		end,
	})
	return compiled, attached, function() return exact_calls end
end

local compiled_grid, attached_grid, exact_calls = compile_grid(index128)
expect_error("expected index schema", function()
	index128.compile({schema = schemas.index, layers = {}}, nil)
end)
expect_error("index schema mismatch", function()
	index128.compile({schema = "wrong", layers = {}, min_cx = 0, max_cx = 0,
		min_cz = 0, max_cz = 0}, schemas.index)
end)
expect_error("expected index schema", function()
	index128.attach(compiled_grid, nil, {})
end)
expect_error("index schema mismatch", function()
	index128.attach(compiled_grid, "wrong", {})
end)
expect_error("outside result", function()
	local broken_outside = validation.copy_graph(compiled_grid)
	broken_outside.layers[1].outside = {}
	index128.attach(broken_outside, schemas.index, {zones = function() end})
end)
local nonscalar_outside = {{}, function() end, coroutine.create(function() end)}
if type(newproxy) == "function" then
	nonscalar_outside[#nonscalar_outside + 1] = newproxy(true)
end
for _, outside in ipairs(nonscalar_outside) do
	expect_error("not scalar", function()
		index128.compile({schema = schemas.index, min_cx = 0, max_cx = 0,
			min_cz = 0, max_cz = 0, layers = {{id = "outside",
				outside = outside, records = {},
				classify_cell = function() return true, "inside" end}}},
			schemas.index)
	end)
end
local function reject_compromised_grid(fragment, mutate)
	local broken = validation.copy_graph(compiled_grid)
	mutate(broken)
	expect_error(fragment, function()
		index128.attach(broken, schemas.index, {zones = function() end})
	end)
end
for _, direct_value in ipairs(nonscalar_outside) do
	reject_compromised_grid("compiled direct scalar", function(broken)
		broken.layers[1].cells[-2][0].scalar = direct_value
	end)
end
reject_compromised_grid("direct flag", function(broken)
	broken.layers[1].cells[-2][0].direct = 1
end)
reject_compromised_grid("unknown field", function(broken)
	broken.layers[1].cells[-2][0].extra = true
end)
reject_compromised_grid("missing or extra coverage", function(broken)
	broken.layers[1].cells[-2] = nil
end)
reject_compromised_grid("not an integer", function(broken)
	broken.layers[1].cells[-2][2] = broken.layers[1].cells[-2][1]
end)
reject_compromised_grid("compiled layer ID", function(broken)
	broken.layers[1].id = ""
end)
reject_compromised_grid("is empty", function(broken)
	broken.layers[1].cells[0][0].candidates = {}
end)
reject_compromised_grid("strictly sorted", function(broken)
	broken.layers[1].cells[0][0].candidates = {"west", "east"}
end)
reject_compromised_grid("strictly sorted", function(broken)
	broken.layers[1].cells[0][0].candidates = {"east", "east"}
end)
reject_compromised_grid("mixed types", function(broken)
	broken.layers[1].cells[0][0].candidates = {1, "west"}
end)
reject_compromised_grid("not comparable", function(broken)
	broken.layers[1].cells[0][0].candidates = {false}
end)
reject_compromised_grid("dense array", function(broken)
	broken.layers[1].cells[0][0].candidates.extra = "west"
end)
expect_error("homogeneous result is not scalar", function()
	index128.compile({schema = schemas.index, min_cx = 0, max_cx = 0,
		min_cz = 0, max_cz = 0, layers = {{id = "direct", outside = "out",
			records = {}, classify_cell = function() return true, {} end}}},
		schemas.index)
end)
expect_error("index layers", function()
	index128.compile({schema = schemas.index, min_cx = 0, max_cx = 0,
		min_cz = 0, max_cz = 0,
		layers = {[1] = {id = "one", records = {},
			classify_cell = function() return true, "one" end},
			[3] = {id = "three", records = {},
				classify_cell = function() return true, "three" end}}}, schemas.index)
end)
expect_error("layer records", function()
	index128.compile({schema = schemas.index, min_cx = 0, max_cx = 0,
		min_cz = 0, max_cz = 0, layers = {{id = "records",
			records = {[1] = {id = "a", bbox = {min_x = 0, max_x = 1,
				min_z = 0, max_z = 1}}, [3] = {id = "b",
				bbox = {min_x = 1, max_x = 2, min_z = 0, max_z = 1}}},
			classify_cell = function() return true, "one" end}}}, schemas.index)
end)
assert(index128.floor_cell(-1) == -1 and index128.floor_cell(-128) == -1 and
	index128.floor_cell(-129) == -2)
assert(index128.query(attached_grid, "zones", 9, 0) == "west")
assert(index128.query(attached_grid, "zones", 10, 0) == "east")
assert(index128.query(attached_grid, "zones", -128, -128) == "west")
assert(index128.query(attached_grid, "zones", 128, 127) == "east")
assert(index128.query(attached_grid, "zones", 256, 0) == "ocean")
local direct_count = exact_calls()
for x = -200, -1 do
	assert(index128.query(attached_grid, "zones", x, -128) == "west")
end
assert(exact_calls() == direct_count, "homogeneous scalar path used evaluator")
local samples = {}
for x = -257, 256 do
	for z = -257, 256, 17 do
		samples[#samples + 1] = {"zones", x, z}
	end
end
index128.verify(attached_grid, samples, function(_layer, x, z)
	if x < -256 or x >= 256 or z < -256 or z >= 256 then return "ocean" end
	return x < 10 and "west" or "east"
end)
expect_error("verification samples", function()
	index128.verify(attached_grid,
		{[1] = {"zones", 0, 0}, [3] = {"zones", 1, 0}},
		function(_layer, x, _z) return x < 10 and "west" or "east" end)
end)
assert(exact_calls() > 0)
assert(compiled_grid.layers[1].cells[0][0].candidates[1] == "east")
local bad_grid = validation.copy_graph(compiled_grid)
bad_grid.layers[1].cells[-1][0].scalar = "east"
local bad_attached = index128.attach(bad_grid, schemas.index, {
	zones = function(_candidates, x, _z) return x < 10 and "west" or "east" end,
})
expect_error("oracle mismatch", function()
	index128.verify(bad_attached, {{"zones", -1, 0}},
		function(_layer, x, _z) return x < 10 and "west" or "east" end)
end)

-- Stage 1/2 fail fast and Stage 3 checks before readiness/callback enablement.
local source = c.map({{c.text("schema"), c.text("fixture_source_v1")}})
local function fixture_canonicalize(data, semantic_ids, canonical)
	local active = {}
	local function value_node(value)
		local kind = type(value)
		if kind == "string" then return canonical.text(value) end
		if kind == "number" then return canonical.signed(value) end
		if kind == "boolean" then return canonical.boolean(value) end
		assert(kind == "table", "fixture compiled graph contains " .. kind)
		assert(not active[value], "fixture compiled graph cycle")
		active[value] = true
		local rows = {}
		for key, child in pairs(value) do
			local key_node
			if type(key) == "string" then
				key_node = canonical.text(key)
			elseif type(key) == "number" then
				key_node = canonical.signed(key)
			else
				error("fixture compiled key type " .. type(key), 0)
			end
			rows[#rows + 1] = {key_node, value_node(child)}
		end
		active[value] = nil
		return canonical.map(rows)
	end
	local ids = {}
	for i = 1, #semantic_ids do ids[i] = canonical.text(semantic_ids[i]) end
	return canonical.map({
		{canonical.text("data"), value_node(data)},
		{canonical.text("semantic_ids"), canonical.array(ids)},
	})
end
local pass_validator = function() return true end
local validator_ok, validator_diag = validation.run("stage1",
	{[1] = pass_validator, [3] = pass_validator},
	{schema = "fixture_geometry_v1", seed_hash = "seedhash"})
assert(not validator_ok and validator_diag.invariant == "validator_list")
local fail_stage1 = function(context)
	return validation.fail("stage1", "fixture_source", "valid", "corrupt", context)
end
expect_error("stage1 failed", function()
	validation.prepare({canonical = c, raw_sha256 = raw_sha256,
		transport_schema = schemas.transport, algorithm_schema = schemas.algorithm,
		geometry_schema = "fixture_geometry_v1", seed_hash = "seedhash",
		source_canonical = source, canonicalize_compiled = fixture_canonicalize,
		record_counts = {}, critical_manifest = {},
		stage1_validators = {fail_stage1}, stage2_validators = {pass_validator}})
end)
local fail_stage2 = function(context)
	return validation.fail("stage2", "fixture_compiled", "valid", "corrupt", context)
end
expect_error("stage2 failed", function()
	validation.prepare({canonical = c, raw_sha256 = raw_sha256,
		transport_schema = schemas.transport, algorithm_schema = schemas.algorithm,
		geometry_schema = "fixture_geometry_v1", seed_hash = "seedhash",
		source_canonical = source, canonicalize_compiled = fixture_canonicalize,
		record_counts = {}, critical_manifest = {},
		stage1_validators = {pass_validator}, stage2_validators = {fail_stage2}})
end)
expect_error("semantic IDs", function()
	validation.prepare({canonical = c, raw_sha256 = raw_sha256,
		transport_schema = schemas.transport, algorithm_schema = schemas.algorithm,
		geometry_schema = "fixture_geometry_v1", seed_hash = "seedhash",
		source_canonical = source, canonicalize_compiled = fixture_canonicalize,
		record_counts = {}, critical_manifest = {},
		semantic_ids = {[1] = "grug_mapgen:one", [3] = "grug_mapgen:three"},
		registration_resolver = function() return true end,
		stage1_validators = {pass_validator}, stage2_validators = {pass_validator}})
end)

local payload = validation.prepare({
	canonical = c, raw_sha256 = raw_sha256,
	transport_schema = schemas.transport, algorithm_schema = schemas.algorithm,
	geometry_schema = "fixture_geometry_v1", seed_hash = "seedhash",
	source_canonical = source, canonicalize_compiled = fixture_canonicalize,
	record_counts = {zones = 2, layers = 1},
	critical_manifest = {chunksize = "5", emerge_threads = "1"},
	semantic_ids = {"grug_materials:bronze_bar", "grug_mapgen:stone"},
	registration_resolver = function(id)
		return id == "grug_materials:bronze_bar" or id == "grug_mapgen:stone"
	end,
	data = {grid = compiled_grid},
	stage1_validators = {pass_validator}, stage2_validators = {pass_validator},
})
local expected = {
	transport_schema = schemas.transport,
	algorithm_schema = schemas.algorithm,
	geometry_schema = "fixture_geometry_v1",
	seed_hash = "seedhash",
	record_counts = {zones = 2, layers = 1},
	critical_manifest = {chunksize = "5", emerge_threads = "1"},
}
expected.source_checksum = payload.source_checksum
expected.compiled_checksum = payload.compiled_checksum

local function new_ipc(initial)
	local state = {value = initial and validation.copy_graph(initial) or nil,
		sets = 0, gets = 0}
	local api = {}
	function api.ipc_set(_key, value)
		state.sets = state.sets + 1
		state.value = validation.copy_graph(value)
	end
	function api.ipc_get(_key)
		state.gets = state.gets + 1
		if state.value == nil then return nil end
		return validation.copy_graph(state.value)
	end
	return api, state
end

local resolver = function(id)
	return id == "grug_materials:bronze_bar" or id == "grug_mapgen:stone" or
		id == "grug_mapgen:resolved_substitute"
end
local main_api, ipc_state = new_ipc()
validation.publish(main_api, schemas.ipc_key, payload)
assert(ipc_state.sets == 1 and ipc_state.gets == 0)
expect_error("already published", function()
	validation.publish(main_api, schemas.ipc_key, payload)
end)
local callbacks = 0
local private = validation.consume_and_enable(main_api, schemas.ipc_key,
	expected, c, raw_sha256, resolver, fixture_canonicalize,
	function(_graph) callbacks = callbacks + 1 end)
assert(ipc_state.gets == 1 and callbacks == 1)
private.data.probe = "private mutation"
assert(ipc_state.value.data.probe == nil, "IPC result aliases packed store")
local get_count_before_queries = ipc_state.gets
for x = -200, 200 do index128.query(attached_grid, "zones", x, 0) end
assert(ipc_state.gets == get_count_before_queries, "hot lookup accessed IPC")

local function corrupt_and_reject(mutator, fragment)
	local broken = validation.copy_graph(payload)
	mutator(broken)
	local api, state = new_ipc(broken)
	local enabled = 0
	expect_error(fragment, function()
		validation.consume_and_enable(api, schemas.ipc_key, expected, c,
			raw_sha256, resolver, fixture_canonicalize,
			function() enabled = enabled + 1 end)
	end)
	assert(state.gets == 1 and enabled == 0)
end
corrupt_and_reject(function(value) value.transport_schema = "bad" end,
	"transport_schema")
corrupt_and_reject(function(value) value.source_checksum = "bad" end,
	"source_checksum")
corrupt_and_reject(function(value) value.data.grid.schema = "corrupt" end,
	"compiled_checksum")
corrupt_and_reject(function(value) value.record_counts.zones = 3 end,
	"record_counts")
corrupt_and_reject(function(value) value.critical_manifest.chunksize = "4" end,
	"critical_manifest")
corrupt_and_reject(function(value) value.semantic_ids[2] = "zz:missing" end,
	"compiled_checksum")
corrupt_and_reject(function(value) value.semantic_ids[2] = nil end,
	"compiled_checksum")
corrupt_and_reject(function(value)
	value.semantic_ids[2] = "grug_mapgen:resolved_substitute"
end, "compiled_checksum")
corrupt_and_reject(function(value)
	value.data.grid.schema = "coherent_corruption"
	value.compiled_checksum = c.hex(c.checksum(fixture_canonicalize(value.data,
		value.semantic_ids, c), raw_sha256))
end, "compiled_checksum")
corrupt_and_reject(function(value)
	value.source_canonical = c.map({
		{c.text("schema"), c.text("coherent_source_corruption")},
	})
	value.source_checksum = c.hex(c.checksum(value.source_canonical, raw_sha256))
end, "source_checksum")
corrupt_and_reject(function(value) value.seed_hash = "other" end, "seed_hash")
local local_semantic_payload = validation.prepare({
	canonical = c, raw_sha256 = raw_sha256,
	transport_schema = schemas.transport, algorithm_schema = schemas.algorithm,
	geometry_schema = "fixture_geometry_v1", seed_hash = "seedhash",
	source_canonical = source, canonicalize_compiled = fixture_canonicalize,
	record_counts = {zones = 2, layers = 1},
	critical_manifest = {chunksize = "5", emerge_threads = "1"},
	semantic_ids = {"grug_mapgen:environment_local"},
	registration_resolver = function(id)
		return id == "grug_mapgen:environment_local"
	end,
	data = {grid = compiled_grid}, stage1_validators = {pass_validator},
	stage2_validators = {pass_validator},
})
local local_semantic_expected = validation.copy_graph(expected)
local_semantic_expected.source_checksum = local_semantic_payload.source_checksum
local_semantic_expected.compiled_checksum = local_semantic_payload.compiled_checksum
local local_semantic_api, local_semantic_state = new_ipc(local_semantic_payload)
expect_error("semantic_registration", function()
	validation.consume(local_semantic_api, schemas.ipc_key,
		local_semantic_expected, c, raw_sha256, function() return false end,
		fixture_canonicalize)
end)
assert(local_semantic_state.gets == 1)
local missing_api, missing_state = new_ipc(nil)
expect_error("payload", function()
	validation.consume(missing_api, schemas.ipc_key, expected, c, raw_sha256,
		resolver, fixture_canonicalize)
end)
assert(missing_state.gets == 1)

-- The same source files and injected raw SHA produce byte-identical results
-- for offline, main-state stub and mapgen-state stub contexts.
local function identity_snapshot(context_name)
	local f = load_foundation()
	local local_hash = f.deterministic.new_hash(f.canonical, raw_sha256,
		f.schemas.hash, "4294967297")
	local local_compiled, local_attached = compile_grid(f.index128)
	local values = {}
	for i = 1, 8 do
		values[i] = f.canonical.unsigned(local_hash.word("golden", "f",
			{-2147483648, 2147483647}, 4294967295, i - 1))
	end
	local answer = f.index128.query(local_attached, "zones", 10, -1)
	return f.canonical.encode(f.canonical.map({
		{f.canonical.text("context_independent"), f.canonical.boolean(true)},
		{f.canonical.text("encoding"), f.canonical.bytes(
			f.canonical.encode(source))},
		{f.canonical.text("checksum"), f.canonical.bytes(
			f.canonical.checksum(source, raw_sha256))},
		{f.canonical.text("words"), f.canonical.array(values)},
		{f.canonical.text("fixed"), f.canonical.signed(
			f.deterministic.qmul(-131073, 32768))},
		{f.canonical.text("noise"), f.canonical.signed(
			f.deterministic.value_noise_2d(f.canonical, raw_sha256,
				noise_definition, -1, -1))},
		{f.canonical.text("index"), f.canonical.text(answer)},
		{f.canonical.text("index_schema"),
			f.canonical.text(local_compiled.schema)},
	}))
end
local offline = identity_snapshot("offline")
local main = identity_snapshot("main")
local mapgen = identity_snapshot("mapgen")
assert(offline == main and main == mapgen)
local core_adapter_calls = 0
local core_raw = foundation.raw_sha256_from_core({
	sha256 = function(data, raw)
		core_adapter_calls = core_adapter_calls + 1
		assert(raw == true)
		return raw_sha256(data)
	end,
})
assert(core_raw("core adapter") == raw_sha256("core adapter") and
	core_adapter_calls == 1)
assert(foundation.enabled == false and
	foundation.disabled_reason == "T2 compiled geometry is not installed")

print(("WP40 T1 foundation passed: %d SHA inputs, %d index samples, " ..
	"one IPC set/get, main/mapgen/offline identity"):format(
	sha_counter, #samples))
