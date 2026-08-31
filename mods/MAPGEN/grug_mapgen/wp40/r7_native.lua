-- Frozen native-v7 inputs for the WP40 R7 cutover.
--
-- This module is deliberately dormant until the R7 loader calls one of its
-- seams. It publishes no global, registers no callback and does not register
-- an ore while being loaded. The future main loader must call
-- apply_and_validate_main() first, complete every other R7 validation, and
-- only then call register_ores() with the returned token. The emerge loader
-- calls validate_emerge() before it registers the sole mapgen callback.

local module = {}

local MAX_SAFE = 9007199254740991
local NOISE_SCHEMA = "grug_wp40_r7_noiseparams_v1"
local NOISE_DIGEST =
	"5a1183a0db4dcbf7c2fce382e907660bfd26e53325d370f62a2d9e78c04d8738"
local NATIVE_SCHEMA = "grug_wp40_r7_native_allowlist_v1"
local NATIVE_DIGEST =
	"d1fe4ac1c7cbe5525af65bde48cc4309870c01e4d474785f2cf0cda3d2639480"
local FLOAT32_POINT_SIX = 0.60000002384185791015625

local TOKEN_MARKER = "grug_wp40_r7_native_validation_token_v1"
local TOKEN_METATABLE = {__metatable = TOKEN_MARKER}
local validated_tokens = setmetatable({}, {__mode = "k"})
local ores_registered = false

local TABLE_KEYS = {
	offset = true,
	scale = true,
	persist = true,
	persistence = true,
	lacunarity = true,
	seed = true,
	octaves = true,
	flags = true,
	spread = true,
}
local SPREAD_KEYS = {x = true, y = true, z = true}
local TOKEN_KEYS = {
	schema = true,
	environment = true,
	noise_schema = true,
	noise_digest = true,
	noise_bytes = true,
	native_schema = true,
	native_digest = true,
	native_bytes = true,
}
local BLOB_KEYS = {
	name = true,
	ore_type = true,
	ore = true,
	wherein = true,
	clust_scarcity = true,
	clust_size = true,
	y_min = true,
	y_max = true,
	noise_threshold = true,
	noise_params = true,
}
local STRATUM_KEYS = {
	name = true,
	ore_type = true,
	ore = true,
	wherein = true,
	clust_scarcity = true,
	y_min = true,
	y_max = true,
}
local BLOB_NOISE_KEYS = {
	offset = true,
	scale = true,
	spread = true,
	seed = true,
	octaves = true,
	persist = true,
}
local NOISE_SETTER_KEYS = {
	offset = true,
	scale = true,
	spread = true,
	seed = true,
	octaves = true,
	persist = true,
	lacunarity = true,
}
local NOISE_SETTER_FLAG_KEYS = {
	offset = true,
	scale = true,
	spread = true,
	seed = true,
	octaves = true,
	persist = true,
	lacunarity = true,
	flags = true,
}

local function fail(message)
	error("WP40 R7 native: " .. message, 0)
end

local function finite_number(value, label)
	if type(value) ~= "number" or value ~= value or value == math.huge or
			value == -math.huge then
		fail(label .. " is not a finite number")
	end
	return value
end

local function safe_integer(value, label)
	finite_number(value, label)
	if value % 1 ~= 0 or math.abs(value) > MAX_SAFE then
		fail(label .. " is not a safe integer")
	end
	return value
end

local function exact_plain_table(value, keys, label, expected_metatable)
	if type(value) ~= "table" then fail(label .. " is not a table") end
	local metatable = getmetatable(value)
	if expected_metatable == nil then
		if metatable ~= nil then fail(label .. " has a metatable") end
	elseif metatable ~= expected_metatable then
		fail(label .. " metatable identity differs")
	end
	local actual = 0
	for key in pairs(value) do
		actual = actual + 1
		if not keys[key] then
			fail(label .. " has unknown field " .. tostring(key))
		end
	end
	local expected = 0
	for key in pairs(keys) do
		expected = expected + 1
		if rawget(value, key) == nil then
			fail(label .. " is missing field " .. key)
		end
	end
	if actual ~= expected then fail(label .. " field count differs") end
	return value
end

local function dense_single_string(value, expected, label)
	if type(value) ~= "table" then fail(label .. " is not a table") end
	if getmetatable(value) ~= nil then fail(label .. " has a metatable") end
	if value[1] ~= expected or value[2] ~= nil then
		fail(label .. " does not contain its one expected value")
	end
	local count = 0
	for key in pairs(value) do
		count = count + 1
		if key ~= 1 then fail(label .. " is not a dense one-row array") end
	end
	if count ~= 1 then fail(label .. " row count differs") end
	return value
end

local function sha256_hex(bytes)
	if type(bytes) ~= "string" then fail("SHA-256 input is not bytes") end
	if type(core) ~= "table" or type(core.sha256) ~= "function" then
		fail("core.sha256 is unavailable")
	end
	local digest = core.sha256(bytes, false)
	if type(digest) ~= "string" or #digest ~= 64 or
			digest:find("[^0-9a-f]") then
		fail("core.sha256 did not return a lowercase hexadecimal digest")
	end
	return digest
end

local function noise_terrain_base()
	return {
		offset = 14, scale = 70, spread = {x = 600, y = 600, z = 600},
		seed = 82341, octaves = 5, persist = 0.6, lacunarity = 2.0,
	}
end

local function noise_terrain_alt()
	return {
		offset = 10, scale = 25, spread = {x = 600, y = 600, z = 600},
		seed = 5934, octaves = 5, persist = 0.6, lacunarity = 2.0,
	}
end

local function noise_heat()
	return {
		offset = 50, scale = 35, spread = {x = 1000, y = 1000, z = 1000},
		seed = 5349, octaves = 3, persist = 0.5, lacunarity = 2.0,
		flags = "eased",
	}
end

local function noise_humidity()
	return {
		offset = 50, scale = 35, spread = {x = 1000, y = 1000, z = 1000},
		seed = 842, octaves = 3, persist = 0.5, lacunarity = 2.0,
		flags = "eased",
	}
end

local function noise_heat_blend()
	return {
		offset = 0, scale = 4, spread = {x = 32, y = 32, z = 32},
		seed = 13, octaves = 2, persist = 1.0, lacunarity = 2.0,
		flags = "eased",
	}
end

local function noise_humidity_blend()
	return {
		offset = 0, scale = 4, spread = {x = 32, y = 32, z = 32},
		seed = 90003, octaves = 2, persist = 1.0, lacunarity = 2.0,
		flags = "eased",
	}
end

local NOISE_SPECS = {
	{
		name = "mgv7_np_terrain_base", offset = 14, scale = 70,
		spread_x = 600, spread_y = 600, spread_z = 600,
		seed = 82341, octaves = 5, persist = FLOAT32_POINT_SIX,
		lacunarity = 2, flags = "defaults", lexical_persist = "0.6",
	},
	{
		name = "mgv7_np_terrain_alt", offset = 10, scale = 25,
		spread_x = 600, spread_y = 600, spread_z = 600,
		seed = 5934, octaves = 5, persist = FLOAT32_POINT_SIX,
		lacunarity = 2, flags = "defaults", lexical_persist = "0.6",
	},
	{
		name = "mg_biome_np_heat", offset = 50, scale = 35,
		spread_x = 1000, spread_y = 1000, spread_z = 1000,
		seed = 5349, octaves = 3, persist = 0.5,
		lacunarity = 2, flags = "eased", lexical_persist = "0.5",
	},
	{
		name = "mg_biome_np_humidity", offset = 50, scale = 35,
		spread_x = 1000, spread_y = 1000, spread_z = 1000,
		seed = 842, octaves = 3, persist = 0.5,
		lacunarity = 2, flags = "eased", lexical_persist = "0.5",
	},
	{
		name = "mg_biome_np_heat_blend", offset = 0, scale = 4,
		spread_x = 32, spread_y = 32, spread_z = 32,
		seed = 13, octaves = 2, persist = 1,
		lacunarity = 2, flags = "eased", lexical_persist = "1",
	},
	{
		name = "mg_biome_np_humidity_blend", offset = 0, scale = 4,
		spread_x = 32, spread_y = 32, spread_z = 32,
		seed = 90003, octaves = 2, persist = 1,
		lacunarity = 2, flags = "eased", lexical_persist = "1",
	},
}

local function canonical_noise_bytes()
	local rows = {NOISE_SCHEMA .. "\n"}
	for index = 1, #NOISE_SPECS do
		local spec = NOISE_SPECS[index]
		rows[#rows + 1] = spec.name ..
			"|offset=" .. string.format("%.0f", spec.offset) ..
			"|scale=" .. string.format("%.0f", spec.scale) ..
			"|spread=" .. string.format("%.0f", spec.spread_x) .. "," ..
				string.format("%.0f", spec.spread_y) .. "," ..
				string.format("%.0f", spec.spread_z) ..
			"|seed=" .. string.format("%.0f", spec.seed) ..
			"|octaves=" .. string.format("%.0f", spec.octaves) ..
			"|persist=" .. spec.lexical_persist ..
			"|lacunarity=" .. string.format("%.0f", spec.lacunarity) ..
			"|flags=" .. spec.flags .. "\n"
	end
	return table.concat(rows)
end

local function validate_noise_setter(value, spec)
	local label = "noise setter " .. spec.name
	local has_flags = spec.flags ~= "defaults"
	exact_plain_table(value,
		has_flags and NOISE_SETTER_FLAG_KEYS or NOISE_SETTER_KEYS, label)
	exact_plain_table(value.spread, SPREAD_KEYS, label .. " spread")
	local setter_persist = spec.lexical_persist == "0.6" and 0.6 or spec.persist
	if value.offset ~= spec.offset or value.scale ~= spec.scale or
			value.persist ~= setter_persist or value.lacunarity ~= spec.lacunarity or
			value.seed ~= spec.seed or value.octaves ~= spec.octaves or
			value.spread.x ~= spec.spread_x or value.spread.y ~= spec.spread_y or
			value.spread.z ~= spec.spread_z or
			(has_flags and value.flags ~= spec.flags) then
		fail(label .. " differs")
	end
	return value
end

local function validate_noise_table(value, spec)
	local label = "noise readback " .. spec.name
	exact_plain_table(value, TABLE_KEYS, label)
	exact_plain_table(value.spread, SPREAD_KEYS, label .. " spread")
	local numeric = {
		"offset", "scale", "persist", "persistence", "lacunarity",
		"seed", "octaves",
	}
	for index = 1, #numeric do
		local key = numeric[index]
		finite_number(value[key], label .. " " .. key)
	end
	safe_integer(value.seed, label .. " seed")
	safe_integer(value.octaves, label .. " octaves")
	finite_number(value.spread.x, label .. " spread.x")
	finite_number(value.spread.y, label .. " spread.y")
	finite_number(value.spread.z, label .. " spread.z")
	if value.persist ~= value.persistence then
		fail(label .. " persist aliases differ")
	end
	if value.offset ~= spec.offset or value.scale ~= spec.scale or
			value.persist ~= spec.persist or value.lacunarity ~= spec.lacunarity or
			value.seed ~= spec.seed or value.octaves ~= spec.octaves or
			value.flags ~= spec.flags or value.spread.x ~= spec.spread_x or
			value.spread.y ~= spec.spread_y or value.spread.z ~= spec.spread_z then
		fail(label .. " differs from the binary32 contract")
	end
	return true
end

local function read_and_validate_noise()
	if type(core) ~= "table" or
			type(core.get_mapgen_setting_noiseparams) ~= "function" then
		fail("noise readback API is unavailable")
	end
	for index = 1, #NOISE_SPECS do
		local spec = NOISE_SPECS[index]
		local value = core.get_mapgen_setting_noiseparams(spec.name)
		if value == nil then fail("noise readback " .. spec.name .. " is nil") end
		validate_noise_table(value, spec)
	end
	local bytes = canonical_noise_bytes()
	if sha256_hex(bytes) ~= NOISE_DIGEST then
		fail("noise canonical digest differs")
	end
	return bytes
end

local function native_definitions()
	return {
		{
			name = "grug_mapgen:native_gravel_blob_v1",
			ore_type = "blob", ore = "default:gravel",
			wherein = {"default:stone"}, clust_scarcity = 4096,
			clust_size = 5, y_min = -31000, y_max = 31000,
			noise_threshold = 0.0,
			noise_params = {
				offset = 0.5, scale = 0.2, spread = {x = 5, y = 5, z = 5},
				seed = 766, octaves = 1, persist = 0.0,
			},
		},
		{
			name = "grug_mapgen:native_stratum_iron_v1",
			ore_type = "stratum", ore = "grug_materials:slate",
			wherein = "default:stone", clust_scarcity = 1,
			y_min = -300, y_max = -101,
		},
		{
			name = "grug_mapgen:native_stratum_steel_v1",
			ore_type = "stratum", ore = "grug_materials:basalt",
			wherein = "default:stone", clust_scarcity = 1,
			y_min = -500, y_max = -301,
		},
		{
			name = "grug_mapgen:native_stratum_silversteel_v1",
			ore_type = "stratum", ore = "grug_materials:granite",
			wherein = "default:stone", clust_scarcity = 1,
			y_min = -700, y_max = -501,
		},
		{
			name = "grug_mapgen:native_stratum_embersteel_v1",
			ore_type = "stratum", ore = "grug_materials:emberrock",
			wherein = "default:stone", clust_scarcity = 1,
			y_min = -1000, y_max = -701,
		},
		{
			name = "grug_mapgen:native_stratum_abyssal_steel_v1",
			ore_type = "stratum", ore = "grug_materials:abyssal_rock",
			wherein = "default:stone", clust_scarcity = 1,
			y_min = -31000, y_max = -1001,
		},
	}
end

local function validate_blob(definition)
	exact_plain_table(definition, BLOB_KEYS, "native gravel definition")
	if definition.name ~= "grug_mapgen:native_gravel_blob_v1" or
			definition.ore_type ~= "blob" or definition.ore ~= "default:gravel" or
			definition.clust_scarcity ~= 4096 or definition.clust_size ~= 5 or
			definition.y_min ~= -31000 or definition.y_max ~= 31000 or
			definition.noise_threshold ~= 0 then
		fail("native gravel definition differs")
	end
	dense_single_string(definition.wherein, "default:stone",
		"native gravel wherein")
	local noise = exact_plain_table(definition.noise_params, BLOB_NOISE_KEYS,
		"native gravel noise")
	exact_plain_table(noise.spread, SPREAD_KEYS, "native gravel noise spread")
	if noise.offset ~= 0.5 or noise.scale ~= 0.2 or noise.spread.x ~= 5 or
			noise.spread.y ~= 5 or noise.spread.z ~= 5 or noise.seed ~= 766 or
			noise.octaves ~= 1 or noise.persist ~= 0 then
		fail("native gravel noise differs")
	end
	return true
end

local STRATUM_EXPECTED = {
	{"grug_mapgen:native_stratum_iron_v1", "grug_materials:slate", -300, -101},
	{"grug_mapgen:native_stratum_steel_v1", "grug_materials:basalt", -500, -301},
	{"grug_mapgen:native_stratum_silversteel_v1", "grug_materials:granite", -700, -501},
	{"grug_mapgen:native_stratum_embersteel_v1", "grug_materials:emberrock", -1000, -701},
	{"grug_mapgen:native_stratum_abyssal_steel_v1", "grug_materials:abyssal_rock", -31000, -1001},
}

local function validate_stratum(definition, expected, index)
	exact_plain_table(definition, STRATUM_KEYS,
		"native stratum definition " .. index)
	if definition.name ~= expected[1] or definition.ore_type ~= "stratum" or
			definition.ore ~= expected[2] or definition.wherein ~= "default:stone" or
			definition.clust_scarcity ~= 1 or definition.y_min ~= expected[3] or
			definition.y_max ~= expected[4] then
		fail("native stratum definition " .. index .. " differs")
	end
	return true
end

local function validate_native_definitions(definitions)
	if type(definitions) ~= "table" or getmetatable(definitions) ~= nil then
		fail("native definition population is not a plain table")
	end
	if #definitions ~= 6 then fail("native definition count differs") end
	local count = 0
	for key in pairs(definitions) do
		count = count + 1
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > 6 then
			fail("native definition population is not a dense six-row array")
		end
	end
	if count ~= 6 then fail("native definition row count differs") end
	validate_blob(definitions[1])
	for index = 2, 6 do
		validate_stratum(definitions[index], STRATUM_EXPECTED[index - 1], index)
	end
	return definitions
end

local function canonical_native_bytes(definitions)
	validate_native_definitions(definitions)
	local blob = definitions[1]
	local noise = blob.noise_params
	-- These three values are engine defaults for absent fields
	-- (l_mapgen.cpp:1354 and c_content.cpp:2066,2072-2073). Derive them
	-- from absence instead of maintaining a second explicit definition.
	local clust_num_ores = rawget(blob, "clust_num_ores") or 1
	local lacunarity = rawget(noise, "lacunarity") or 2
	local flags = rawget(noise, "flags") or "defaults"
	local rows = {NATIVE_SCHEMA .. "\n"}
	rows[#rows + 1] = "blob|" .. blob.name .. "|ore=" .. blob.ore ..
		"|wherein=" .. blob.wherein[1] .. "|clust_scarcity=" ..
		string.format("%.0f", blob.clust_scarcity) .. "|clust_num_ores=" ..
		string.format("%.0f", clust_num_ores) .. "|clust_size=" ..
		string.format("%.0f", blob.clust_size) .. "|y_min=" ..
		string.format("%.0f", blob.y_min) .. "|y_max=" ..
		string.format("%.0f", blob.y_max) .. "|noise_threshold=0|noise=0.5,0.2," ..
		string.format("%.0f", noise.spread.x) .. "," ..
		string.format("%.0f", noise.spread.y) .. "," ..
		string.format("%.0f", noise.spread.z) .. "," ..
		string.format("%.0f", noise.seed) .. "," ..
		string.format("%.0f", noise.octaves) .. ",0," ..
		string.format("%.0f", lacunarity) .. "," .. flags .. "\n"
	for index = 2, 6 do
		local definition = definitions[index]
		rows[#rows + 1] = "stratum|" .. definition.name .. "|ore=" ..
			definition.ore .. "|wherein=default:stone|clust_scarcity=1|y_min=" ..
			string.format("%.0f", definition.y_min) .. "|y_max=" ..
			string.format("%.0f", definition.y_max) .. "\n"
	end
	return table.concat(rows)
end

local function validated_native()
	local definitions = validate_native_definitions(native_definitions())
	local bytes = canonical_native_bytes(definitions)
	if sha256_hex(bytes) ~= NATIVE_DIGEST then
		fail("native allowlist canonical digest differs")
	end
	return definitions, bytes
end

local function new_token(environment, noise_bytes, native_bytes)
	if environment ~= "main" and environment ~= "emerge" then
		fail("unknown validation environment")
	end
	local token = {
		schema = TOKEN_MARKER,
		environment = environment,
		noise_schema = NOISE_SCHEMA,
		noise_digest = NOISE_DIGEST,
		noise_bytes = noise_bytes,
		native_schema = NATIVE_SCHEMA,
		native_digest = NATIVE_DIGEST,
		native_bytes = native_bytes,
	}
	setmetatable(token, TOKEN_METATABLE)
	validated_tokens[token] = true
	return token
end

local function validate_token(token, environment)
	if type(token) ~= "table" or not validated_tokens[token] or
			getmetatable(token) ~= TOKEN_MARKER then
		fail("validation token identity differs")
	end
	exact_plain_table(token, TOKEN_KEYS, "validation token", TOKEN_MARKER)
	if token.schema ~= TOKEN_MARKER or token.environment ~= environment or
			token.noise_schema ~= NOISE_SCHEMA or token.noise_digest ~= NOISE_DIGEST or
			token.noise_bytes ~= canonical_noise_bytes() or
			token.native_schema ~= NATIVE_SCHEMA or token.native_digest ~= NATIVE_DIGEST or
			token.native_bytes ~= canonical_native_bytes(native_definitions()) then
		fail("validation token fields differ")
	end
	return true
end

function module.apply_and_validate_main()
	validated_native()
	if type(core) ~= "table" or
			type(core.set_mapgen_setting_noiseparams) ~= "function" then
		fail("noise setter API is unavailable")
	end
	-- Validate all six literal setter tables before the first setting mutation.
	local terrain_base = validate_noise_setter(noise_terrain_base(), NOISE_SPECS[1])
	local terrain_alt = validate_noise_setter(noise_terrain_alt(), NOISE_SPECS[2])
	local heat = validate_noise_setter(noise_heat(), NOISE_SPECS[3])
	local humidity = validate_noise_setter(noise_humidity(), NOISE_SPECS[4])
	local heat_blend = validate_noise_setter(noise_heat_blend(), NOISE_SPECS[5])
	local humidity_blend = validate_noise_setter(noise_humidity_blend(),
		NOISE_SPECS[6])
	core.set_mapgen_setting_noiseparams("mgv7_np_terrain_base",
		terrain_base, true)
	core.set_mapgen_setting_noiseparams("mgv7_np_terrain_alt",
		terrain_alt, true)
	core.set_mapgen_setting_noiseparams("mg_biome_np_heat",
		heat, true)
	core.set_mapgen_setting_noiseparams("mg_biome_np_humidity",
		humidity, true)
	core.set_mapgen_setting_noiseparams("mg_biome_np_heat_blend",
		heat_blend, true)
	core.set_mapgen_setting_noiseparams("mg_biome_np_humidity_blend",
		humidity_blend, true)
	local noise_bytes = read_and_validate_noise()
	local _, native_bytes = validated_native()
	return new_token("main", noise_bytes, native_bytes)
end

function module.validate_emerge()
	local _, native_bytes = validated_native()
	local noise_bytes = read_and_validate_noise()
	return new_token("emerge", noise_bytes, native_bytes)
end

function module.register_ores(token)
	validate_token(token, "main")
	if ores_registered then fail("native ores were already registered") end
	if type(core) ~= "table" or type(core.register_ore) ~= "function" or
			type(core.registered_ores) ~= "table" or
			type(core.registered_nodes) ~= "table" then
		fail("native ore registration API is incomplete")
	end
	local definitions = validated_native()
	for index = 1, #definitions do
		local definition = definitions[index]
		if core.registered_ores[definition.name] ~= nil then
			fail("native ore identity already exists: " .. definition.name)
		end
		if core.registered_nodes[definition.ore] == nil then
			fail("native ore node is not registered: " .. definition.ore)
		end
		if core.registered_nodes["default:stone"] == nil then
			fail("native wherein node default:stone is not registered")
		end
	end
	local handles = {}
	handles[1] = core.register_ore(definitions[1])
	handles[2] = core.register_ore(definitions[2])
	handles[3] = core.register_ore(definitions[3])
	handles[4] = core.register_ore(definitions[4])
	handles[5] = core.register_ore(definitions[5])
	handles[6] = core.register_ore(definitions[6])
	for index = 1, 6 do
		safe_integer(handles[index], "native ore handle " .. index)
		if core.registered_ores[definitions[index].name] ~= definitions[index] then
			fail("native ore registry did not retain definition " .. index)
		end
	end
	ores_registered = true
	return handles
end

function module.identities()
	return {
		noise_schema = NOISE_SCHEMA,
		noise_digest = NOISE_DIGEST,
		native_schema = NATIVE_SCHEMA,
		native_digest = NATIVE_DIGEST,
	}
end

return module
