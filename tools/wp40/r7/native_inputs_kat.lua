-- LuaJIT development KAT for the dormant WP40 R7 native-input module.
-- Run with:
--   luajit -e 'wp40_ffi=require("ffi")' \
--     tools/wp40/r7/native_inputs_kat.lua <repository-root>

local repo = assert(arg[1], "repository root required")
local ffi = assert(rawget(_G, "wp40_ffi"), "wp40_ffi injection required")

ffi.cdef[[
	typedef unsigned long size_t;
	unsigned char *SHA256(const unsigned char *data, size_t length,
		unsigned char *digest);
]]

local crypto = ffi.load("crypto")
local digest_buffer = ffi.new("unsigned char[32]")
local float_buffer = ffi.new("float[1]")

local function sha256_hex(bytes)
	assert(type(bytes) == "string", "SHA-256 input must be bytes")
	assert(crypto.SHA256(bytes, #bytes, digest_buffer) ~= nil,
		"SHA-256 failed")
	local raw = ffi.string(digest_buffer, 32)
	return (raw:gsub(".", function(byte)
		return string.format("%02x", string.byte(byte))
	end))
end

local function binary32(value)
	float_buffer[0] = value
	return tonumber(float_buffer[0])
end

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[copy(key)] = copy(child) end
	return setmetatable(result, getmetatable(value))
end

local function expect_failure(callback, fragment)
	local ok, message = pcall(callback)
	assert(not ok, "failure fixture unexpectedly passed")
	assert(type(message) == "string" and message:find(fragment, 1, true),
		"failure fixture returned " .. tostring(message))
end

local NOISE_NAMES = {
	"mgv7_np_terrain_base",
	"mgv7_np_terrain_alt",
	"mg_biome_np_heat",
	"mg_biome_np_humidity",
	"mg_biome_np_heat_blend",
	"mg_biome_np_humidity_blend",
}

local REQUIRED_NODES = {
	"default:stone",
	"default:gravel",
	"grug_materials:slate",
	"grug_materials:basalt",
	"grug_materials:granite",
	"grug_materials:emberrock",
	"grug_materials:abyssal_rock",
}

local engine_vector_metatable = {}
local saved_vector = rawget(_G, "vector")
rawset(_G, "vector", {metatable = engine_vector_metatable})

local function normalized_noise(definition)
	return {
		offset = binary32(definition.offset),
		scale = binary32(definition.scale),
		persist = binary32(definition.persist),
		persistence = binary32(definition.persist),
		lacunarity = binary32(definition.lacunarity),
		seed = definition.seed,
		octaves = definition.octaves,
		flags = definition.flags or "defaults",
		spread = setmetatable({
			x = binary32(definition.spread.x),
			y = binary32(definition.spread.y),
			z = binary32(definition.spread.z),
		}, engine_vector_metatable),
	}
end

local function new_core(options)
	options = options or {}
	local state = {
		setters = {}, readbacks = {}, reads = {}, ores = {},
		callbacks = 0, publications = 0,
	}
	local api = {registered_nodes = {}, registered_ores = {}}
	for index = 1, #REQUIRED_NODES do
		api.registered_nodes[REQUIRED_NODES[index]] = {name = REQUIRED_NODES[index]}
	end
	function api.sha256(bytes, raw)
		assert(raw == false, "native module requested raw SHA-256")
		if options.bad_sha then return string.rep("0", 64) end
		return sha256_hex(bytes)
	end
	function api.set_mapgen_setting_noiseparams(name, definition, override_meta)
		state.setters[#state.setters + 1] = {
			name = name, definition = copy(definition), override_meta = override_meta,
		}
		state.readbacks[name] = normalized_noise(definition)
	end
	function api.get_mapgen_setting_noiseparams(name)
		state.reads[#state.reads + 1] = name
		local value = copy(state.readbacks[name])
		if options.corrupt then value = options.corrupt(name, value) end
		return value
	end
	function api.register_ore(definition)
		state.ores[#state.ores + 1] = definition
		api.registered_ores[definition.name] = definition
		return #state.ores
	end
	function api.register_mapgen_script()
		state.publications = state.publications + 1
	end
	function api.register_on_generated()
		state.callbacks = state.callbacks + 1
	end
	return api, state
end

local module_path = repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_native.lua"
local saved_core = rawget(_G, "core")

local api, state = new_core()
rawset(_G, "core", api)
local native = dofile(module_path)
assert(#state.setters == 0 and #state.reads == 0 and #state.ores == 0,
	"loading the native module caused a side effect")
assert(state.callbacks == 0 and state.publications == 0,
	"loading the native module registered a writer")

local identities = native.identities()
assert(identities.noise_schema == "grug_wp40_r7_noiseparams_v1")
assert(identities.noise_digest ==
	"5a1183a0db4dcbf7c2fce382e907660bfd26e53325d370f62a2d9e78c04d8738")
assert(identities.native_schema == "grug_wp40_r7_native_allowlist_v1")
assert(identities.native_digest ==
	"d1fe4ac1c7cbe5525af65bde48cc4309870c01e4d474785f2cf0cda3d2639480")

local main_token = native.apply_and_validate_main()
assert(#state.setters == 6 and #state.reads == 6,
	"main validation did not use exactly six setters/readbacks")
for index = 1, 6 do
	assert(state.setters[index].name == NOISE_NAMES[index],
		"noise setter order differs at " .. index)
	assert(state.setters[index].override_meta == true,
		"noise setter did not use override_meta=true")
	assert(state.reads[index] == NOISE_NAMES[index],
		"noise readback order differs at " .. index)
end
assert(state.readbacks.mgv7_np_terrain_base.persist ==
	0.60000002384185791015625, "mock did not produce binary32 0.6")
assert(state.callbacks == 0 and state.publications == 0 and #state.ores == 0,
	"main validation registered or published content")

local pure_setters_before = #state.setters
native.validate_main_readback()
native.validate_runtime_readback("emerge")
assert(#state.setters == pure_setters_before and #state.reads == 18,
	"pure runtime readback mutated settings or skipped a readback")
expect_failure(function() native.validate_runtime_readback("other") end,
	"unknown validation environment")
assert(#state.setters == pure_setters_before and #state.reads == 18,
	"invalid environment touched the runtime readback API")
assert(state.callbacks == 0 and state.publications == 0 and #state.ores == 0,
	"pure runtime readback registered or published content")

local saved_noise_digest = main_token.noise_digest
main_token.noise_digest = string.rep("0", 64)
expect_failure(function() native.register_ores(main_token) end,
	"validation token fields differ")
assert(#state.ores == 0, "mutated token partially registered ores")
main_token.noise_digest = saved_noise_digest
expect_failure(function() native.register_ores({}) end,
	"validation token identity differs")
assert(#state.ores == 0, "foreign token partially registered ores")

local handles = native.register_ores(main_token)
assert(#handles == 6 and #state.ores == 6, "native registration count differs")
local expected_ores = {
	{"grug_mapgen:native_gravel_blob_v1", "blob", "default:gravel", -31000, 31000},
	{"grug_mapgen:native_stratum_iron_v1", "stratum", "grug_materials:slate", -300, -101},
	{"grug_mapgen:native_stratum_steel_v1", "stratum", "grug_materials:basalt", -500, -301},
	{"grug_mapgen:native_stratum_silversteel_v1", "stratum", "grug_materials:granite", -700, -501},
	{"grug_mapgen:native_stratum_embersteel_v1", "stratum", "grug_materials:emberrock", -1000, -701},
	{"grug_mapgen:native_stratum_abyssal_steel_v1", "stratum", "grug_materials:abyssal_rock", -31000, -1001},
}
for index = 1, 6 do
	local actual, expected = state.ores[index], expected_ores[index]
	assert(actual.name == expected[1] and actual.ore_type == expected[2] and
		actual.ore == expected[3] and actual.y_min == expected[4] and
		actual.y_max == expected[5], "native definition order differs at " .. index)
end
assert(state.callbacks == 0 and state.publications == 0,
	"native registration installed a writer")
expect_failure(function() native.register_ores(main_token) end,
	"native ores were already registered")

local setters_before, reads_before = #state.setters, #state.reads
local emerge_native = dofile(module_path)
emerge_native.validate_emerge()
assert(#state.setters == setters_before and #state.reads == reads_before + 6,
	"emerge validation mutated settings or skipped readbacks")
for index = 1, 6 do
	assert(state.reads[reads_before + index] == NOISE_NAMES[index],
		"emerge readback order differs at " .. index)
end
assert(state.callbacks == 0 and state.publications == 0,
	"emerge validation installed a writer")

local bad_sha_api, bad_sha_state = new_core({bad_sha = true})
rawset(_G, "core", bad_sha_api)
local bad_sha_native = dofile(module_path)
expect_failure(function() bad_sha_native.apply_and_validate_main() end,
	"native allowlist canonical digest differs")
assert(#bad_sha_state.setters == 0 and #bad_sha_state.ores == 0 and
	bad_sha_state.callbacks == 0 and bad_sha_state.publications == 0,
	"digest failure was not side-effect-free")

local function readback_failure(corrupt, fragment)
	local failure_api, failure_state = new_core({corrupt = corrupt})
	rawset(_G, "core", failure_api)
	local failure_native = dofile(module_path)
	expect_failure(function() failure_native.apply_and_validate_main() end, fragment)
	assert(#failure_state.ores == 0 and failure_state.callbacks == 0 and
		failure_state.publications == 0,
		"readback failure registered or published content")
end

readback_failure(function(name, value)
	if name == NOISE_NAMES[1] then
		value.persist = 0.6
		value.persistence = 0.6
	end
	return value
end, "binary32 contract")

readback_failure(function(name, value)
	if name == NOISE_NAMES[2] then value.unexpected = 1 end
	return value
end, "unknown field unexpected")

readback_failure(function(name, value)
	if name == NOISE_NAMES[3] then value.persistence = nil end
	return value
end, "missing field persistence")

readback_failure(function(name, value)
	if name == NOISE_NAMES[4] then setmetatable(value.spread, {}) end
	return value
end, "spread has an unexpected metatable")

readback_failure(function(name, value)
	if name == NOISE_NAMES[5] then value.flags = "defaults" end
	return value
end, "binary32 contract")

local missing_api, missing_state = new_core()
rawset(_G, "core", missing_api)
local missing_native = dofile(module_path)
local missing_token = missing_native.apply_and_validate_main()
missing_api.registered_nodes["grug_materials:granite"] = nil
expect_failure(function() missing_native.register_ores(missing_token) end,
	"native ore node is not registered")
assert(#missing_state.ores == 0, "missing-node gate partially registered ores")

local duplicate_api, duplicate_state = new_core()
rawset(_G, "core", duplicate_api)
local duplicate_native = dofile(module_path)
local duplicate_token = duplicate_native.apply_and_validate_main()
duplicate_api.registered_ores["grug_mapgen:native_stratum_iron_v1"] = {}
expect_failure(function() duplicate_native.register_ores(duplicate_token) end,
	"native ore identity already exists")
assert(#duplicate_state.ores == 0,
	"duplicate-identity gate partially registered ores")

rawset(_G, "core", saved_core)
rawset(_G, "vector", saved_vector)
print("WP40 R7 native inputs KAT PASS noise=" .. identities.noise_digest ..
	" native=" .. identities.native_digest .. " setters=6 reads=24 ores=6")
