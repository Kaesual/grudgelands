-- Frozen native-v7 inputs for the WP40 R7 cutover.
--
-- This module is deliberately dormant until the R7 loader calls one of its
-- seams. It publishes no global, registers no callback and does not register
-- an ore while being loaded. The main loader must call
-- apply_and_validate_main(wp40, projection) first, complete every other R7
-- validation, and only then call register_ores() with the returned token.
-- The emerge loader calls validate_emerge(wp40, projection) before it
-- registers the sole mapgen callback.
--
-- Round 49 (native first): the ores, coal, anthracite and gems of every
-- tier band and the two cave plants are native v7 rows too, derived from
-- the resource table (r7_r6_manifest.lua), the WP43 tiers and deep bands
-- (the projection) and the world-content cave rows; the digest below pins
-- the derived rows as well.

local module = {}

local MAX_SAFE = 9007199254740991
local NOISE_SCHEMA = "grug_wp40_r7_noiseparams_v1"
local MGV7_SPFLAGS = "nomountains, ridges, nofloatlands, caverns"
local NOISE_DIGEST =
	"5a1183a0db4dcbf7c2fce382e907660bfd26e53325d370f62a2d9e78c04d8738"
local NATIVE_SCHEMA = "grug_wp40_r7_native_allowlist_v1"
-- Round 24 (ruling 14) appended the three decorative-nest blob rows; the
-- gravel and stratum rows before them are byte-identical to the former
-- digest c29c9c6c...97b5e2ab (Lane A tier-rock rename). Round 49 appended
-- the scatter ore rows and the two cave decorations; the nine rows before
-- them are byte-identical to the former digest a1c53c2f...a6dd31b.
local NATIVE_DIGEST =
	"e33e23571dec74784660ac0ef6f29b74b01ed492e43fda0f045c5e0520c39559"
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

local function exact_readback_spread(value, label)
	local metatable = getmetatable(value)
	if metatable ~= nil and (type(vector) ~= "table" or
			metatable ~= vector.metatable) then
		fail(label .. " has an unexpected metatable")
	end
	return exact_plain_table(value, SPREAD_KEYS, label, metatable)
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
	-- Luanti pushes NoiseParams spread through push_v3f, so current engines
	-- return the builtin vector metatable. Older fixtures/plain tables remain
	-- valid, but an unrelated metatable is still rejected.
	exact_readback_spread(value.spread, label .. " spread")
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
	local digest = sha256_hex(bytes)
	if digest ~= NOISE_DIGEST then
		fail("noise canonical digest differs: actual=" .. digest)
	end
	return bytes
end

-- Round 24 ruling 14: sparse nests of the three decorative rocks, each in
-- its preferred depth range, in default:stone and in every tier rock. They
-- are registered after the tier strata, so the strata already stand where a
-- nest lands. Blob size 7 at one blob per 28^3 nodes leaves about one voxel
-- in 120 of a rock's depth range to its nests.
local DECOR_EXPECTED = {
	{"grug_mapgen:native_decor_slate_v1", "grug_materials:slate", -400, -40, 24101},
	{"grug_mapgen:native_decor_granite_v1", "grug_materials:granite", -900, -200, 24102},
	{"grug_mapgen:native_decor_basalt_v1", "grug_materials:basalt", -31000, -600, 24103},
}
local DECOR_SCARCITY, DECOR_SIZE = 21952, 7

-- The hosts: default:stone and the five tier rocks, taken from the stratum
-- rows of the same population so the two lists cannot drift apart.
local function decor_definition(index, definitions)
	local expected = DECOR_EXPECTED[index]
	local wherein = {"default:stone"}
	for row = 2, 6 do wherein[row] = definitions[row].ore end
	return {
		name = expected[1], ore_type = "blob", ore = expected[2],
		wherein = wherein, clust_scarcity = DECOR_SCARCITY,
		clust_size = DECOR_SIZE, y_min = expected[3], y_max = expected[4],
		noise_threshold = 0.0,
		noise_params = {
			offset = 0.5, scale = 0.2, spread = {x = 5, y = 5, z = 5},
			seed = expected[5], octaves = 1, persist = 0.0,
		},
	}
end

local function fixed_definitions()
	local definitions = {
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
			ore_type = "stratum", ore = "grug_materials:t2_stone",
			wherein = "default:stone", clust_scarcity = 1,
			y_min = -300, y_max = -101,
		},
		{
			name = "grug_mapgen:native_stratum_steel_v1",
			ore_type = "stratum", ore = "grug_materials:t3_stone",
			wherein = "default:stone", clust_scarcity = 1,
			y_min = -500, y_max = -301,
		},
		{
			name = "grug_mapgen:native_stratum_silversteel_v1",
			ore_type = "stratum", ore = "grug_materials:t4_stone",
			wherein = "default:stone", clust_scarcity = 1,
			y_min = -700, y_max = -501,
		},
		{
			name = "grug_mapgen:native_stratum_embersteel_v1",
			ore_type = "stratum", ore = "grug_materials:t5_stone",
			wherein = "default:stone", clust_scarcity = 1,
			y_min = -1000, y_max = -701,
		},
		{
			name = "grug_mapgen:native_stratum_abyssal_steel_v1",
			ore_type = "stratum", ore = "grug_materials:t6_stone",
			wherein = "default:stone", clust_scarcity = 1,
			y_min = -31000, y_max = -1001,
		},
	}
	for index = 1, #DECOR_EXPECTED do
		definitions[6 + index] = decor_definition(index, definitions)
	end
	return definitions
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
	{"grug_mapgen:native_stratum_iron_v1", "grug_materials:t2_stone", -300, -101},
	{"grug_mapgen:native_stratum_steel_v1", "grug_materials:t3_stone", -500, -301},
	{"grug_mapgen:native_stratum_silversteel_v1", "grug_materials:t4_stone", -700, -501},
	{"grug_mapgen:native_stratum_embersteel_v1", "grug_materials:t5_stone", -1000, -701},
	{"grug_mapgen:native_stratum_abyssal_steel_v1", "grug_materials:t6_stone", -31000, -1001},
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

local function validate_decor(definition, index, definitions)
	local label = "native decorative nest " .. index
	local expected = DECOR_EXPECTED[index]
	exact_plain_table(definition, BLOB_KEYS, label)
	if definition.name ~= expected[1] or definition.ore_type ~= "blob" or
			definition.ore ~= expected[2] or
			definition.clust_scarcity ~= DECOR_SCARCITY or
			definition.clust_size ~= DECOR_SIZE or
			definition.y_min ~= expected[3] or definition.y_max ~= expected[4] or
			definition.noise_threshold ~= 0 then
		fail(label .. " differs")
	end
	local wherein = definition.wherein
	if type(wherein) ~= "table" or getmetatable(wherein) ~= nil or
			#wherein ~= 6 or wherein[1] ~= "default:stone" then
		fail(label .. " wherein differs")
	end
	local count = 0
	for key in pairs(wherein) do
		count = count + 1
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > 6 or
				(key > 1 and wherein[key] ~= definitions[key].ore) then
			fail(label .. " wherein differs")
		end
	end
	if count ~= 6 then fail(label .. " wherein row count differs") end
	local noise = exact_plain_table(definition.noise_params, BLOB_NOISE_KEYS,
		label .. " noise")
	exact_plain_table(noise.spread, SPREAD_KEYS, label .. " noise spread")
	if noise.offset ~= 0.5 or noise.scale ~= 0.2 or noise.spread.x ~= 5 or
			noise.spread.y ~= 5 or noise.spread.z ~= 5 or
			noise.seed ~= expected[5] or noise.octaves ~= 1 or noise.persist ~= 0 then
		fail(label .. " noise differs")
	end
	return true
end

-- Round 49 (mapgen-native-plan.md §4.1, rulings 2-4): one native scatter
-- row per resource, tier band and deep band of the resource table, after
-- the strata and nests above, so its host rock already stands where it
-- lands (ore rows run in registration order). Per host node a scatter row
-- places clust_num_ores / clust_scarcity ore nodes on average (mg_ore.cpp
-- OreScatter), so clust_scarcity = denominator * clust_num_ores keeps the
-- table's density; a deep band divides that by its multiplier, rounded to
-- a whole scarcity. Cluster shapes by vein cap (ruling 3): cap 8 (coal,
-- copper, iron, quartz, tin, anthracite) a 3-cube with 8 ores on average,
-- cap 4 (gold, silver, emberglass) a 2-cube with 4, cap 2 (gems, abyssal
-- crystal) a 2-cube with one, mostly single nodes and pairs. No noise and
-- no biome filter (ruling 4). A `lower_half_of` row covers only the lower
-- half of its band.
local CLUSTER_BY_CAP = {[8] = {3, 8}, [4] = {2, 4}, [2] = {2, 1}}
local SCATTER_KEYS = {
	name = true,
	ore_type = true,
	ore = true,
	wherein = true,
	clust_scarcity = true,
	clust_num_ores = true,
	clust_size = true,
	y_min = true,
	y_max = true,
}
local ORE_ROW_COUNT = 84

-- Round 49 (§4.1, answer 3): the two cave plants are native simple
-- decorations on every cave floor of their host rocks (`all_floors`),
-- under towns and planned water too. `all_floors` picks columns at
-- `fill_ratio` and decorates every floor in a picked column, so
-- fill_ratio = 1 / the initial denominator is the rate per floor node the
-- former Lua rows had. The engine tests the floor node's y, one below the
-- plant, so the range is the catalog row's shifted down by one. Runtime
-- renewal (vegetation_density.lua) keeps the same density.
local DECORATION_KEYS = {
	name = true,
	deco_type = true,
	decoration = true,
	place_on = true,
	flags = true,
	fill_ratio = true,
	y_min = true,
	y_max = true,
}
local CAVE_DECORATION_COUNT = 2

local FIXED_COUNT = 6 + #DECOR_EXPECTED
local NATIVE_COUNT = FIXED_COUNT + ORE_ROW_COUNT

-- The derivation inputs: the resource and cave rows from their pure source
-- files, the tiers, natural nodes and deep bands from the WP43 projection
-- that both environments hold (main builds it, emerge receives it).
local function derivation_inputs(wp40, projection)
	if type(wp40) ~= "string" or wp40 == "" then fail("mapgen directory differs") end
	if type(projection) ~= "table" or projection.schema ~= "grug_wp43_projection_v1" or
			type(projection.tiers) ~= "table" or type(projection.resources) ~= "table" or
			type(projection.density) ~= "table" or
			type(projection.density.deep_bands) ~= "table" then
		fail("WP43 projection differs")
	end
	local nodes = {}
	for index = 1, #projection.resources do
		local row = projection.resources[index]
		if type(row) ~= "table" or type(row.key) ~= "string" or
				type(row.natural_node) ~= "string" or nodes[row.key] then
			fail("projected resource " .. index .. " differs")
		end
		nodes[row.key] = row.natural_node
	end
	local bands = projection.density.deep_bands
	for index = 1, #bands do
		local band = bands[index]
		safe_integer(band.y_min, "deep band y_min")
		safe_integer(band.y_max, "deep band y_max")
		safe_integer(band.multiplier_numerator, "deep band numerator")
		safe_integer(band.multiplier_denominator, "deep band denominator")
		if band.y_min > band.y_max or band.multiplier_numerator < 1 or
				band.multiplier_denominator < 1 or
				(index > 1 and band.y_max ~= bands[index - 1].y_min - 1) then
			fail("deep band " .. index .. " differs")
		end
	end
	if #bands < 1 then fail("deep bands are absent") end
	return {resources = dofile(wp40 .. "/r7_r6_manifest.lua")().resources,
		tiers = projection.tiers, deep_bands = bands, nodes = nodes,
		plants = dofile(wp40 .. "/world_content_catalog.lua").plants,
		initial_denominator =
			dofile(wp40 .. "/habitat_registry.lua").initial_denominator}
end

local function ore_definitions(inputs)
	local tiers, bands = inputs.tiers, inputs.deep_bands
	local rows = {}
	for _, resource in ipairs(inputs.resources) do
		local node = inputs.nodes[resource.key]
		local shape = CLUSTER_BY_CAP[resource.max_nodes_per_vein]
		if type(node) ~= "string" or not shape then
			fail("resource row " .. tostring(resource.key) .. " differs")
		end
		for tier_index = 1, #tiers do
			local denominator = resource.denominators[tier_index]
			if denominator then
				safe_integer(denominator, "resource denominator")
				local tier = tiers[tier_index]
				local top, suffix = tier.y_max, ""
				if resource.lower_half_of == tier_index then
					top, suffix = tier.lower_half_y_max, "_lower"
				end
				-- {y_min, y_max, multiplier numerator, denominator, suffix}: the
				-- ordinary part above the first deep band, then each deep band.
				local pieces = {{math.max(tier.y_min, bands[1].y_max + 1), top, 1, 1, suffix}}
				for band_index = 1, #bands do
					local band = bands[band_index]
					pieces[#pieces + 1] = {math.max(tier.y_min, band.y_min),
						math.min(top, band.y_max), band.multiplier_numerator,
						band.multiplier_denominator,
						suffix .. "_deep" .. string.format("%.0f", -band.y_max)}
				end
				for _, piece in ipairs(pieces) do
					if piece[1] <= piece[2] then
						local scaled = denominator * shape[2] * piece[4]
						rows[#rows + 1] = {
							name = "grug_mapgen:native_ore_" .. resource.key .. "_t" ..
								tier_index .. piece[5] .. "_v1",
							ore_type = "scatter", ore = node, wherein = tier.node,
							clust_scarcity = math.floor((2 * scaled + piece[3]) / (2 * piece[3])),
							clust_num_ores = shape[2], clust_size = shape[1],
							y_min = piece[1], y_max = piece[2],
						}
					end
				end
			end
		end
	end
	return rows
end

local function cave_definitions(inputs)
	local rows = {}
	for _, plant in ipairs(inputs.plants) do
		if plant.mode == "cave" then
			local hosts = type(plant.hosts) == "table" and plant.hosts.stone
			if type(hosts) ~= "table" or #hosts < 1 then
				fail("cave row " .. tostring(plant.key) .. " hosts differ")
			end
			local place_on = {}
			for index = 1, #hosts do place_on[index] = hosts[index] end
			local denominator = safe_integer(
				inputs.initial_denominator(plant.key, plant.density),
				"cave row denominator")
			rows[#rows + 1] = {
				name = "grug_mapgen:native_cave_plant_" .. plant.key .. "_v1",
				deco_type = "simple", decoration = plant.node, place_on = place_on,
				flags = "all_floors", fill_ratio = 1 / denominator,
				y_min = plant.min - 1, y_max = plant.max - 1,
			}
		end
	end
	return rows
end

local function native_definitions(inputs)
	local definitions = fixed_definitions()
	local ores = ore_definitions(inputs)
	for index = 1, #ores do definitions[FIXED_COUNT + index] = ores[index] end
	return definitions, cave_definitions(inputs)
end

local function dense_array(value, count, label)
	if type(value) ~= "table" or getmetatable(value) ~= nil then
		fail(label .. " is not a plain table")
	end
	if #value ~= count then fail(label .. " count differs") end
	local actual = 0
	for key in pairs(value) do
		actual = actual + 1
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
			fail(label .. " is not a dense array")
		end
	end
	if actual ~= count then fail(label .. " row count differs") end
	return value
end

local function validate_scatter(definition, index, definitions)
	local label = "native scatter ore " .. index
	exact_plain_table(definition, SCATTER_KEYS, label)
	local shape
	for _, candidate in pairs(CLUSTER_BY_CAP) do
		if candidate[1] == definition.clust_size and
				candidate[2] == definition.clust_num_ores then
			shape = candidate
		end
	end
	local host = definition.wherein == "default:stone"
	for row = 2, 6 do host = host or definition.wherein == definitions[row].ore end
	if definition.ore_type ~= "scatter" or type(definition.name) ~= "string" or
			definition.name:sub(1, 23) ~= "grug_mapgen:native_ore_" or
			type(definition.ore) ~= "string" or not shape or not host then
		fail(label .. " differs")
	end
	safe_integer(definition.clust_scarcity, label .. " scarcity")
	safe_integer(definition.y_min, label .. " y_min")
	safe_integer(definition.y_max, label .. " y_max")
	if definition.clust_scarcity < 1 or definition.y_min > definition.y_max then
		fail(label .. " range differs")
	end
	return true
end

local function validate_cave(definition, index)
	local label = "native cave decoration " .. index
	exact_plain_table(definition, DECORATION_KEYS, label)
	local place_on = definition.place_on
	if definition.deco_type ~= "simple" or definition.flags ~= "all_floors" or
			type(definition.name) ~= "string" or
			definition.name:sub(1, 24) ~= "grug_mapgen:native_cave_" or
			type(definition.decoration) ~= "string" or type(place_on) ~= "table" or
			getmetatable(place_on) ~= nil or #place_on < 1 then
		fail(label .. " differs")
	end
	for key, name in pairs(place_on) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #place_on or
				type(name) ~= "string" then
			fail(label .. " place_on differs")
		end
	end
	finite_number(definition.fill_ratio, label .. " fill_ratio")
	local denominator = math.floor(1 / definition.fill_ratio + 0.5)
	if denominator < 1 or 1 / denominator ~= definition.fill_ratio then
		fail(label .. " fill_ratio is not one in a whole number")
	end
	safe_integer(definition.y_min, label .. " y_min")
	safe_integer(definition.y_max, label .. " y_max")
	if definition.y_min > definition.y_max then fail(label .. " range differs") end
	return denominator
end

local function validate_native_definitions(definitions, decorations)
	dense_array(definitions, NATIVE_COUNT, "native definition population")
	validate_blob(definitions[1])
	for index = 2, 6 do
		validate_stratum(definitions[index], STRATUM_EXPECTED[index - 1], index)
	end
	for index = 1, #DECOR_EXPECTED do
		validate_decor(definitions[6 + index], index, definitions)
	end
	for index = FIXED_COUNT + 1, NATIVE_COUNT do
		validate_scatter(definitions[index], index, definitions)
	end
	dense_array(decorations, CAVE_DECORATION_COUNT, "native decoration population")
	for index = 1, CAVE_DECORATION_COUNT do validate_cave(decorations[index], index) end
	return definitions, decorations
end

local function canonical_native_bytes(definitions, decorations)
	validate_native_definitions(definitions, decorations)
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
	-- Validated above: every field outside these rows is the literal the
	-- validator pins (noise 0.5/0.2, spread 5, one octave, engine defaults).
	for index = 7, FIXED_COUNT do
		local definition = definitions[index]
		rows[#rows + 1] = "blob|" .. definition.name .. "|ore=" .. definition.ore ..
			"|wherein=" .. table.concat(definition.wherein, ",") ..
			"|clust_scarcity=" .. string.format("%.0f", definition.clust_scarcity) ..
			"|clust_num_ores=1|clust_size=" ..
			string.format("%.0f", definition.clust_size) .. "|y_min=" ..
			string.format("%.0f", definition.y_min) .. "|y_max=" ..
			string.format("%.0f", definition.y_max) ..
			"|noise_threshold=0|noise=0.5,0.2,5,5,5," ..
			string.format("%.0f", definition.noise_params.seed) .. ",1,0,2,defaults\n"
	end
	-- Round 49: the scatter ores (no noise, no biomes: engine defaults) and
	-- the cave decorations (sidelen, offsets and height: engine defaults).
	for index = FIXED_COUNT + 1, NATIVE_COUNT do
		local definition = definitions[index]
		rows[#rows + 1] = "scatter|" .. definition.name .. "|ore=" .. definition.ore ..
			"|wherein=" .. definition.wherein .. "|clust_scarcity=" ..
			string.format("%.0f", definition.clust_scarcity) .. "|clust_num_ores=" ..
			string.format("%.0f", definition.clust_num_ores) .. "|clust_size=" ..
			string.format("%.0f", definition.clust_size) .. "|y_min=" ..
			string.format("%.0f", definition.y_min) .. "|y_max=" ..
			string.format("%.0f", definition.y_max) .. "\n"
	end
	for index = 1, CAVE_DECORATION_COUNT do
		local definition = decorations[index]
		rows[#rows + 1] = "decoration|" .. definition.name .. "|simple|decoration=" ..
			definition.decoration .. "|place_on=" .. table.concat(definition.place_on, ",") ..
			"|flags=all_floors|fill_ratio=1/" ..
			string.format("%.0f", validate_cave(definition, index)) .. "|y_min=" ..
			string.format("%.0f", definition.y_min) .. "|y_max=" ..
			string.format("%.0f", definition.y_max) .. "\n"
	end
	return table.concat(rows)
end

local function validated_native(inputs)
	local definitions, decorations = native_definitions(inputs)
	local bytes = canonical_native_bytes(definitions, decorations)
	if sha256_hex(bytes) ~= NATIVE_DIGEST then
		fail("native allowlist canonical digest differs")
	end
	return definitions, decorations, bytes
end

-- A validated token maps to the population it validated (weak keys), which
-- register_ores registers.
local function new_token(environment, noise_bytes, native_bytes, population)
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
	validated_tokens[token] = population
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
			sha256_hex(token.native_bytes) ~= NATIVE_DIGEST then
		fail("validation token fields differ")
	end
	return validated_tokens[token]
end

local function validate_runtime_readback(environment, wp40, projection)
	if environment ~= "main" and environment ~= "emerge" then
		fail("unknown validation environment")
	end
	local definitions, decorations, native_bytes =
		validated_native(derivation_inputs(wp40, projection))
	local noise_bytes = read_and_validate_noise()
	return new_token(environment, noise_bytes, native_bytes,
		{definitions = definitions, decorations = decorations})
end

-- `wp40`: the mapgen's wp40 directory; `projection`: the WP43 projection
-- (wp43_handoff.project), the inputs of the derived rows.
function module.apply_and_validate_main(wp40, projection)
	validated_native(derivation_inputs(wp40, projection))
	if type(core) ~= "table" or
			type(core.set_mapgen_setting_noiseparams) ~= "function" or
			type(core.set_mapgen_setting) ~= "function" then
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
	-- The v7 flags (Round 49, lane V7A: nomountains), forced over the world's
	-- map_meta.txt like the noise params: a map reset keeps that file, and
	-- with it the flags of the world's creation, which would override
	-- minetest.conf. Engine canonical form; r7_runtime.lua checks the readback.
	core.set_mapgen_setting("mgv7_spflags", MGV7_SPFLAGS, true)
	return validate_runtime_readback("main", wp40, projection)
end

-- Pure runtime validation for a main environment whose setters were already
-- applied. This performs no setting mutation, registration or publication.
function module.validate_main_readback(wp40, projection)
	return validate_runtime_readback("main", wp40, projection)
end

function module.validate_emerge(wp40, projection)
	return validate_runtime_readback("emerge", wp40, projection)
end

-- Shared pure dispatcher for loaders that keep environment identity explicit.
function module.validate_runtime_readback(environment, wp40, projection)
	return validate_runtime_readback(environment, wp40, projection)
end

-- The validated native population (fixtures and tools): the ore rows in
-- registration order, the cave decorations and the canonical bytes.
function module.population(wp40, projection)
	return validated_native(derivation_inputs(wp40, projection))
end

local function require_node(name, label)
	if core.registered_nodes[name] == nil then
		fail("native " .. label .. " node is not registered: " .. tostring(name))
	end
end

-- Registers the ore rows in their order, then the cave decorations.
function module.register_ores(token)
	local population = validate_token(token, "main")
	if ores_registered then fail("native ores were already registered") end
	if type(core) ~= "table" or type(core.register_ore) ~= "function" or
			type(core.registered_ores) ~= "table" or
			type(core.register_decoration) ~= "function" or
			type(core.registered_decorations) ~= "table" or
			type(core.registered_nodes) ~= "table" then
		fail("native ore registration API is incomplete")
	end
	local definitions, decorations = population.definitions, population.decorations
	require_node("default:stone", "wherein")
	for index = 1, #definitions do
		local definition = definitions[index]
		if core.registered_ores[definition.name] ~= nil then
			fail("native ore identity already exists: " .. definition.name)
		end
		require_node(definition.ore, "ore")
		if type(definition.wherein) == "table" then
			for host = 1, #definition.wherein do
				require_node(definition.wherein[host], "wherein")
			end
		else
			require_node(definition.wherein, "wherein")
		end
	end
	for index = 1, #decorations do
		local definition = decorations[index]
		if core.registered_decorations[definition.name] ~= nil then
			fail("native decoration identity already exists: " .. definition.name)
		end
		require_node(definition.decoration, "decoration")
		for host = 1, #definition.place_on do
			require_node(definition.place_on[host], "place_on")
		end
	end
	local handles = {}
	for index = 1, NATIVE_COUNT do
		handles[index] = core.register_ore(definitions[index])
	end
	for index = 1, NATIVE_COUNT do
		safe_integer(handles[index], "native ore handle " .. index)
		if core.registered_ores[definitions[index].name] ~= definitions[index] then
			fail("native ore registry did not retain definition " .. index)
		end
	end
	for index = 1, CAVE_DECORATION_COUNT do
		local handle = core.register_decoration(decorations[index])
		safe_integer(handle, "native decoration handle " .. index)
		if core.registered_decorations[decorations[index].name] ~= decorations[index] then
			fail("native decoration registry did not retain definition " .. index)
		end
		handles[NATIVE_COUNT + index] = handle
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
