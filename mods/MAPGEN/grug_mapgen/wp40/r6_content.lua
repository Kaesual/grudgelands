-- Closed WP40 R6 catalogs and injected content-contract validation.

return function(manifest_values, content_contract, wp43_projection)
	local MAX_SAFE = 9007199254740991
	local PARAM2_KINDS = {none = true, facedir = true, wallmounted = true,
		colorfacedir = true, colorwallmounted = true, ["4dir"] = true,
		color4dir = true, degrotate = true, colordegrotate = true,
		meshoptions = true, leveled = true, flowingliquid = true,
		glasslikeliquidlevel = true, waving = true, color = true}
	local CONTRACT_SHA256 =
		"814fbb7915c6c1590f65ec4d6c34b165543528a76c14db5f570cc8e9710a954f"
	local function less_bytes(left, right)
		local count = math.min(#left, #right)
		for index = 1, count do
			local left_byte, right_byte = string.byte(left, index), string.byte(right, index)
			if left_byte ~= right_byte then return left_byte < right_byte end
		end
		return #left < #right
	end
	local REQUIRED_INPUTS = {
		"AGENTS.md",
		"docs/design/biomes_mobs.md",
		"docs/design/items_crafting.md",
		"docs/design/world.md",
		"docs/design/world_zones.md",
		"docs/research/luanti-lua.md",
		"docs/research/wp40-simple-map-r6-contract.md",
		"docs/research/wp40-simple-map-r6-cultural-opportunities.tsv",
		"docs/research/wp40-simple-map-r6-decisions.md",
		"docs/research/wp40-simple-map-r6-decoration-draft.tsv",
		"docs/research/wp40-simple-map-r6-resource-density.tsv",
		"docs/research/wp40-simple-map-r6-seed-corpus.tsv",
		"docs/research/wp40-simple-map-r6-surface-content.tsv",
		"docs/research/wp43_wp40_handoff.md",
		"mods/BASE/default/schematics/acacia_bush.mts",
		"mods/BASE/default/schematics/acacia_tree.mts",
		"mods/BASE/default/schematics/apple_log.mts",
		"mods/BASE/default/schematics/apple_tree.mts",
		"mods/BASE/default/schematics/aspen_tree.mts",
		"mods/BASE/default/schematics/blueberry_bush.mts",
		"mods/BASE/default/schematics/bush.mts",
		"mods/BASE/default/schematics/emergent_jungle_tree.mts",
		"mods/BASE/default/schematics/jungle_tree.mts",
		"mods/BASE/default/schematics/large_cactus.mts",
		"mods/BASE/default/schematics/papyrus_on_dirt.mts",
		"mods/BASE/default/schematics/pine_bush.mts",
		"mods/BASE/default/schematics/pine_tree.mts",
		"mods/BASE/default/schematics/small_pine_tree.mts",
		"mods/BASE/default/schematics/snowy_pine_tree_from_sapling.mts",
		"mods/ITEMS/grug_materials/registry.lua",
		"mods/ITEMS/grug_nodes/init.lua",
		"mods/ITEMS/grug_trees/init.lua",
		"mods/MAPGEN/grug_mapgen/wp43_handoff.lua",
		"reference_projects/luanti/doc/lua_api.md",
		"reference_projects/luanti/src/mapgen/mg_schematic.cpp",
		"reference_projects/luanti/src/mapgen/mg_schematic.h",
		"reference_projects/luanti/src/mapnode.cpp",
		"reference_projects/luanti/src/script/lua_api/l_mapgen.cpp",
	}
	local SURFACE_EXPECTED = {
		grug_badlands = {"grug_nodes:mesa_clay", "grug_nodes:mesa_clay", 3,
			"default:gravel", "-"},
		grug_badlands_east = {"grug_nodes:mesa_clay", "grug_nodes:mesa_clay", 3,
			"default:gravel", "-"},
		grug_beach = {"default:sand", "default:sand", 2, "default:sand", "-"},
		grug_blight = {"grug_nodes:blight_dirt", "default:dirt", 3,
			"default:gravel", "-"},
		grug_bone_forest = {"grug_nodes:dirt_with_bone_litter", "default:dirt", 3,
			"default:gravel", "-"},
		grug_crags = {"default:gravel", "default:gravel", 2,
			"default:gravel", "-"},
		grug_crags_snowy = {"default:snowblock", "default:gravel", 2,
			"default:gravel", "default:snow"},
		grug_deep_forest = {"grug_nodes:dirt_with_forest_litter", "default:dirt", 3,
			"default:sand", "-"},
		grug_deep_jungle = {"grug_nodes:dirt_with_canopy_litter", "default:dirt", 3,
			"default:sand", "-"},
		grug_elf_forest = {"grug_nodes:dirt_with_silver_litter", "default:dirt", 3,
			"default:sand", "-"},
		grug_jungle_edge = {"default:dirt_with_rainforest_litter", "default:dirt", 3,
			"default:sand", "-"},
		grug_jungle_fringe = {"grug_nodes:dirt_with_canopy_litter", "default:dirt", 3,
			"default:sand", "-"},
		grug_meadows = {"default:dirt_with_grass", "default:dirt", 3,
			"default:sand", "-"},
		grug_pine_hills = {"default:dirt_with_coniferous_litter", "default:dirt", 3,
			"default:gravel", "-"},
		grug_savanna = {"default:dry_dirt_with_dry_grass", "default:dry_dirt", 3,
			"default:sand", "-"},
		grug_swamp = {"grug_nodes:mud", "grug_nodes:mud", 2, "grug_nodes:mud", "-"},
	}
	local RESOURCE_EXPECTED = {
		abyssal_crystal = {"universal", 5, 2, {false, false, false, false, 2048, 2048}},
		citrine = {"regional_g1", 2, 3, {false, 12000, 6000, 3000, 3000, 3000}},
		coal = {"universal", 1, 8, {128, 128, 128, 128, 128, 128}},
		copper = {"universal", 1, 8, {256, 256, 256, 256, 256, 256}},
		diamond = {"regional_g2", 4, 2, {false, false, false, 12000, 6000, 3000}},
		emberglass = {"universal", 4, 4, {false, false, false, 2048, 2048, 2048}},
		garnet = {"regional_g1", 2, 3, {false, 12000, 6000, 3000, 3000, 3000}},
		gold = {"universal", 2, 4, {false, 1024, 1024, 1024, 1024, 1024}},
		iron = {"universal", 1, 8, {128, 128, 128, 128, 128, 128}},
		jade = {"regional_g1", 2, 3, {false, 12000, 6000, 3000, 3000, 3000}},
		quartz = {"universal", 1, 8, {256, 256, 256, 256, 256, 256}},
		ruby = {"regional_g2", 4, 2, {false, false, false, 12000, 6000, 3000}},
		sapphire = {"regional_g2", 4, 2, {false, false, false, 12000, 6000, 3000}},
		silver = {"universal", 3, 4, {false, false, 1024, 1024, 1024, 1024}},
		tin = {"universal", 1, 8, {384, 384, 384, 384, 384, 384}},
	}
	local CULTURAL_EXPECTED = {
		dwarf = {"runeslate", "elandor_stormvault_heights",
			{"grug_pine_hills", "grug_crags", "grug_crags_snowy"}},
		elf = {"moonresin", "elandor_glassroot_wilds",
			{"grug_elf_forest", "grug_deep_forest", "grug_jungle_fringe"}},
		human = {"sunwax", "elandor_ashenward_march",
			{"grug_meadows", "grug_deep_forest"}},
		orc = {"red_ochre", "kragmar_bannerbreak_mesa",
			{"grug_savanna", "grug_badlands"}},
		troll = {"spirit_resin", "kragmar_thunderroot_wilds",
			{"grug_jungle_edge", "grug_deep_jungle", "grug_swamp",
				"grug_badlands_east"}},
		undead = {"gravesalt", "kragmar_blackwind_rise",
			{"grug_blight", "grug_bone_forest", "grug_swamp", "grug_beach"}},
	}

	local function fail(prefix, message)
		error(prefix .. ": " .. message, 0)
	end

	local function safe_integer(value, label, minimum, maximum, prefix)
		if type(value) ~= "number" or value ~= value or value == math.huge or
				value == -math.huge or value % 1 ~= 0 or math.abs(value) > MAX_SAFE or
				value < minimum or value > maximum then
			fail(prefix, label .. " is not an exact bounded integer")
		end
		return value
	end

	local function text(value, label, prefix)
		if type(value) ~= "string" or value == "" or
				value:find("\0", 1, true) or value:find("\t", 1, true) or
				value:find("\r", 1, true) or value:find("\n", 1, true) then
			fail(prefix, label .. " is not length-safe text")
		end
		return value
	end

	local function sha256(value, label)
		if type(value) ~= "string" or #value ~= 64 or
				not value:match("^[0-9a-f]+$") then
			fail("fail_manifest", label .. " is not lowercase SHA-256")
		end
		return value
	end

	local function dense(values, label, prefix)
		if type(values) ~= "table" or getmetatable(values) ~= nil then
			fail(prefix, label .. " is not a plain array")
		end
		local count = #values
		for index = 1, count do
			if values[index] == nil then fail(prefix, label .. " has a hole") end
		end
		for key in pairs(values) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then
				fail(prefix, label .. " is not dense")
			end
		end
		return count
	end

	local function exact_fields(value, fields, label, prefix)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail(prefix, label .. " is not a plain table")
		end
		for key in pairs(value) do
			if not fields[key] then fail(prefix, label .. " has unexpected field " .. tostring(key)) end
		end
		for key in pairs(fields) do
			if value[key] == nil then fail(prefix, label .. " is missing " .. key) end
		end
		return value
	end

	local function deep_copy(value, active)
		if type(value) ~= "table" then return value end
		active = active or {}
		if active[value] then fail("fail_manifest", "catalog graph contains a cycle") end
		active[value] = true
		local copy = {}
		for key, child in pairs(value) do copy[deep_copy(key, active)] = deep_copy(child, active) end
		active[value] = nil
		return copy
	end

	local function equal_array(left, right)
		if #left ~= #right then return false end
		for index = 1, #left do if left[index] ~= right[index] then return false end end
		return true
	end

	local function has_bit(mask, bit_value)
		return math.floor(mask / bit_value) % 2 == 1
	end

	exact_fields(manifest_values, {
		schema = true, contract_sha256 = true, r5_manifest_values = true,
		input_sha256 = true, input_bytes = true, surfaces = true,
		resources = true, cultural = true, decorations = true,
		r2_layout_body_sha256 = true,
	}, "manifest values", "fail_manifest")
	if manifest_values.schema ~= "grug_wp40_r6_manifest_values_v1" or
			sha256(manifest_values.contract_sha256, "contract digest") ~= CONTRACT_SHA256 or
			sha256(manifest_values.r2_layout_body_sha256, "R2 layout body digest") ~=
				"1a819192fa40254aa6da1ebf5f3fa5286790ef907abe09750455e5e24c881a8b" then
		fail("fail_manifest", "R6 lineage identity differs")
	end
	if type(manifest_values.r5_manifest_values) ~= "table" then
		fail("fail_manifest", "R5 manifest values missing")
	end
	if type(manifest_values.input_sha256) ~= "table" or
			type(manifest_values.input_bytes) ~= "table" then
		fail("fail_manifest", "input identity maps missing")
	end
	local input_count = 0
	for index = 1, #REQUIRED_INPUTS do
		local path = REQUIRED_INPUTS[index]
		sha256(manifest_values.input_sha256[path], "input digest " .. path)
		safe_integer(manifest_values.input_bytes[path], "input byte count " .. path,
			0, MAX_SAFE, "fail_manifest")
		input_count = input_count + 1
	end
	for path in pairs(manifest_values.input_sha256) do
		local found = false
		for index = 1, #REQUIRED_INPUTS do
			if REQUIRED_INPUTS[index] == path then found = true end
		end
		if not found then fail("fail_manifest", "unexpected input identity " .. tostring(path)) end
	end
	for path in pairs(manifest_values.input_bytes) do
		if manifest_values.input_sha256[path] == nil then
			fail("fail_manifest", "input byte count lacks digest " .. tostring(path))
		end
	end
	if input_count ~= #REQUIRED_INPUTS then fail("fail_manifest", "input population differs") end

	local surfaces, surface_by_id = {}, {}
	if dense(manifest_values.surfaces, "surface catalog", "fail_content_manifest") ~= 16 then
		fail("fail_content_manifest", "surface catalog population differs")
	end
	for index = 1, #manifest_values.surfaces do
		local row = manifest_values.surfaces[index]
		exact_fields(row, {id = true, top = true, filler = true, filler_depth = true,
			shore = true, bed = true, dust = true}, "surface row", "fail_content_manifest")
		local expected = SURFACE_EXPECTED[text(row.id, "surface ID", "fail_content_manifest")]
		if not expected or surface_by_id[row.id] or row.top ~= expected[1] or
				row.filler ~= expected[2] or row.filler_depth ~= expected[3] or
				row.shore ~= expected[4] or row.bed ~= expected[4] or
				(row.dust or "-") ~= expected[5] then
			fail("fail_content_manifest", "surface row differs at " .. row.id)
		end
		if index > 1 and not less_bytes(manifest_values.surfaces[index - 1].id,
				row.id) then
			fail("fail_content_manifest", "surface rows are not ASCII ordered")
		end
		surfaces[index], surface_by_id[row.id] = deep_copy(row), deep_copy(row)
	end
	for id in pairs(SURFACE_EXPECTED) do
		if not surface_by_id[id] then fail("fail_content_manifest", "surface ID missing " .. id) end
	end

	local resources, resource_by_key = {}, {}
	if dense(manifest_values.resources, "resource catalog", "fail_resource_manifest") ~= 15 then
		fail("fail_resource_manifest", "resource catalog population differs")
	end
	for index = 1, #manifest_values.resources do
		local row = manifest_values.resources[index]
		exact_fields(row, {key = true, scope = true, first_tier = true,
			denominators = true, max_nodes_per_vein = true,
			deep_1500_1999_numerator = true, deep_1500_1999_denominator = true,
			deep_2000_floor_numerator = true, deep_2000_floor_denominator = true},
			"resource row", "fail_resource_manifest")
		local expected = RESOURCE_EXPECTED[text(row.key, "resource key", "fail_resource_manifest")]
		if not expected or resource_by_key[row.key] or row.scope ~= expected[1] or
				row.first_tier ~= expected[2] or row.max_nodes_per_vein ~= expected[3] or
				dense(row.denominators, "resource denominators", "fail_resource_manifest") ~= 6 or
				not equal_array(row.denominators, expected[4]) or
				row.deep_1500_1999_numerator ~= 5 or
				row.deep_1500_1999_denominator ~= 4 or
				row.deep_2000_floor_numerator ~= 3 or
				row.deep_2000_floor_denominator ~= 2 then
			fail("fail_resource_manifest", "resource row differs at " .. row.key)
		end
		if index > 1 and not less_bytes(manifest_values.resources[index - 1].key,
				row.key) then
			fail("fail_resource_manifest", "resource rows are not ASCII ordered")
		end
		resources[index], resource_by_key[row.key] = deep_copy(row), deep_copy(row)
	end

	local cultural, cultural_by_race, cultural_by_key = {}, {}, {}
	if dense(manifest_values.cultural, "cultural catalog",
			"fail_cultural_registration") ~= 6 then
		fail("fail_cultural_registration", "cultural catalog population differs")
	end
	for index = 1, #manifest_values.cultural do
		local row = manifest_values.cultural[index]
		exact_fields(row, {race = true, key = true, ordinary_denominator = true,
			concentrated_denominator = true, biomes = true, concentrated_zone = true},
			"cultural row", "fail_cultural_registration")
		local expected = CULTURAL_EXPECTED[text(row.race, "cultural race",
			"fail_cultural_registration")]
		if not expected or cultural_by_race[row.race] or cultural_by_key[row.key] or
				row.key ~= expected[1] or row.ordinary_denominator ~= 4096 or
				row.concentrated_denominator ~= 1024 or
				row.concentrated_zone ~= expected[2] or
				dense(row.biomes, "cultural biomes", "fail_cultural_registration") ~= #expected[3] or
				not equal_array(row.biomes, expected[3]) then
			fail("fail_cultural_registration", "cultural row differs at " .. row.race)
		end
		if index > 1 and not less_bytes(manifest_values.cultural[index - 1].key,
				row.key) then
			fail("fail_cultural_registration", "cultural rows are not key ordered")
		end
		cultural[index] = deep_copy(row)
		cultural_by_race[row.race], cultural_by_key[row.key] = deep_copy(row), deep_copy(row)
	end

	local decorations, decoration_by_id = {}, {}
	if dense(manifest_values.decorations, "decoration catalog",
			"fail_content_manifest") ~= 48 then
		fail("fail_content_manifest", "expanded decoration population differs")
	end
	for index = 1, #manifest_values.decorations do
		local row = manifest_values.decorations[index]
		exact_fields(row, {id = true, biomes = true, kind = true, asset_or_node = true,
			host = true, numerator = true, denominator = true, rule = true,
			settlement_class = true}, "decoration row", "fail_content_manifest")
		text(row.id, "decoration ID", "fail_content_manifest")
		if decoration_by_id[row.id] or (index > 1 and not less_bytes(
				manifest_values.decorations[index - 1].id, row.id)) then
			fail("fail_content_manifest", "decoration IDs are not ASCII unique")
		end
		if row.kind ~= "simple" and row.kind ~= "template" then
			fail("fail_content_manifest", "decoration kind differs")
		end
		dense(row.biomes, "decoration biomes", "fail_content_manifest")
		for biome_index = 1, #row.biomes do
			if not SURFACE_EXPECTED[row.biomes[biome_index]] then
				fail("fail_content_manifest", "decoration biome is unknown")
			end
		end
		safe_integer(row.numerator, "decoration numerator", 1, 3,
			"fail_content_manifest")
		safe_integer(row.denominator, "decoration denominator", 1, 2000,
			"fail_content_manifest")
		safe_integer(row.settlement_class, "settlement class", 1, 4,
			"fail_content_manifest")
		if (row.kind == "simple" and row.settlement_class ~= 3 and
				row.settlement_class ~= 4) or
				(row.kind == "template" and row.settlement_class ~= 1 and
					row.settlement_class ~= 2) then
			fail("fail_content_manifest", "decoration class/kind differs")
		end
		decorations[index], decoration_by_id[row.id] = deep_copy(row), deep_copy(row)
	end

	if type(wp43_projection) ~= "table" or
			wp43_projection.schema ~= "grug_wp43_projection_v1" or
			dense(wp43_projection.resources, "WP43 resources",
				"fail_resource_manifest") ~= 15 or
			dense(wp43_projection.tiers, "WP43 tiers", "fail_resource_manifest") ~= 6 then
		fail("fail_resource_manifest", "WP43 projection differs")
	end
	local projected_resources = {}
	for index = 1, #wp43_projection.resources do
		local projected = wp43_projection.resources[index]
		if type(projected) ~= "table" or not resource_by_key[projected.key] or
				projected_resources[projected.key] or type(projected.natural_node) ~= "string" or
				type(projected.harvest_tier) ~= "number" then
			fail("fail_resource_manifest", "WP43 resource identity differs")
		end
		projected_resources[projected.key] = projected
		resource_by_key[projected.key].node = projected.natural_node
		resource_by_key[projected.key].harvest_tier = projected.harvest_tier
		for row_index = 1, #resources do
			if resources[row_index].key == projected.key then
				resources[row_index].node = projected.natural_node
				resources[row_index].harvest_tier = projected.harvest_tier
			end
		end
	end
	for key in pairs(RESOURCE_EXPECTED) do
		if not projected_resources[key] then
			fail("fail_resource_manifest", "WP43 resource missing " .. key)
		end
	end
	local density = wp43_projection.density
	if type(density) ~= "table" or type(density.g2) ~= "table" or
			type(density.abyssal_crystal) ~= "table" or
			type(density.g2.host_nodes_per_ore) ~= "table" or
			dense(density.deep_bands, "WP43 deep bands", "fail_resource_manifest") ~= 2 or
			density.g2.host_nodes_per_ore[4] ~= 12000 or
			density.g2.host_nodes_per_ore[5] ~= 6000 or
			density.g2.host_nodes_per_ore[6] ~= 3000 or
			density.abyssal_crystal.host_nodes_per_ore ~= 2048 or
			density.deep_bands[1].multiplier_numerator ~= 5 or
			density.deep_bands[1].multiplier_denominator ~= 4 or
			density.deep_bands[2].multiplier_numerator ~= 3 or
			density.deep_bands[2].multiplier_denominator ~= 2 then
		fail("fail_resource_manifest", "WP43 density projection differs")
	end

	exact_fields(content_contract, {schema = true, r5 = true, ignore_cid = true,
		ordinary_water_family_id = true, river_water_family_id = true,
		content_names = true, content_cids = true, content_kind_masks = true,
		resolve_r6 = true, classify = true, metrics = true}, "content contract",
		"fail_content_manifest")
	if (content_contract.schema ~= "grug_wp40_r6_content_contract_v1" and
			content_contract.schema ~= "grug_wp40_r7_production_r6_content_v1") or
			type(content_contract.r5) ~= "table" or
			content_contract.r5.schema ~= "grug_wp40_r5_content_contract_v1" or
			type(content_contract.resolve_r6) ~= "function" or
			type(content_contract.classify) ~= "function" or
			type(content_contract.metrics) ~= "function" or
			content_contract.ignore_cid ~= content_contract.r5.ignore_cid or
			content_contract.ordinary_water_family_id ~=
				content_contract.r5.ordinary_water_family_id or
			content_contract.river_water_family_id ~=
				content_contract.r5.river_water_family_id then
		fail("fail_content_manifest", "outer/R5 content contract differs")
	end
	local content_count = dense(content_contract.content_names, "content names",
		"fail_content_manifest")
	if content_count < 1 or content_count > 1024 or
			dense(content_contract.content_cids, "content CIDs", "fail_content_manifest") ~= content_count or
			dense(content_contract.content_kind_masks, "content masks",
				"fail_content_manifest") ~= content_count then
		fail("fail_content_manifest", "content arrays differ")
	end
	local content_ref_by_name, param2_kind_by_ref = {}, {}
	for index = 1, content_count do
		local name = text(content_contract.content_names[index], "content name",
			"fail_content_manifest")
		if content_ref_by_name[name] or (index > 1 and not less_bytes(
				content_contract.content_names[index - 1], name)) then
			fail("fail_content_manifest", "content names are not ASCII unique")
		end
		safe_integer(content_contract.content_cids[index], "content CID", 0,
			MAX_SAFE - 1, "fail_content_manifest")
		safe_integer(content_contract.content_kind_masks[index], "content role mask", 1,
			31, "fail_content_manifest")
		local first = {content_contract.resolve_r6(index, 0)}
		local second = {content_contract.resolve_r6(index, 0)}
		if #first ~= 5 or #second ~= 5 then
			fail("fail_content_manifest", "content resolver arity differs")
		end
		for field = 1, 5 do
			if first[field] ~= second[field] then
				fail("fail_content_manifest", "content resolver is not pure")
			end
		end
		if first[1] ~= content_contract.content_cids[index] or first[2] < 0 or
				first[2] > 2 or first[3] ~= 1 or first[4] ~= 0 or
				first[5] ~= content_contract.content_kind_masks[index] then
			fail("fail_content_manifest", "content resolver tuple differs")
		end
		-- `classify` preserves the exact nine-scalar R5 prefix.  R6 owns one
		-- fail-closed tenth scalar for the node's engine paramtype2 rotation
		-- family; templates consume only this construction-validated copy.
		local classified = {content_contract.classify(
			content_contract.content_cids[index], 0)}
		local repeated = {content_contract.classify(
			content_contract.content_cids[index], 0)}
		local r5_classified = {content_contract.r5.classify(
			content_contract.content_cids[index], 0)}
		if #classified ~= 10 or #repeated ~= 10 or #r5_classified ~= 9 or
				not PARAM2_KINDS[classified[10]] then
			fail("fail_content_manifest", "content classifier arity/kind differs")
		end
		for field = 1, 10 do
			if classified[field] ~= repeated[field] then
				fail("fail_content_manifest", "content classifier is not pure")
			end
			if field <= 9 and classified[field] ~= r5_classified[field] then
				fail("fail_content_manifest", "outer/R5 classifier prefix differs")
			end
		end
		param2_kind_by_ref[index] = classified[10]
		content_ref_by_name[name] = index
	end

	local function require_role(name, role_bit, accepted_classes, label)
		local ref = content_ref_by_name[name]
		if not ref or not has_bit(content_contract.content_kind_masks[ref], role_bit) then
			fail("fail_content_manifest", label .. " lacks required role: " .. name)
		end
		local class_id = content_contract.classify(content_contract.content_cids[ref], 0)
		if not accepted_classes[class_id] then
			fail("fail_content_manifest", label .. " class differs: " .. name)
		end
		return ref
	end
	local p7_classes = {[6] = true, [7] = true, [11] = true}
	for index = 1, #surfaces do
		local row = surfaces[index]
		row.top_ref = require_role(row.top, 1, p7_classes, "surface top")
		row.filler_ref = require_role(row.filler, 1, p7_classes, "surface filler")
		row.shore_ref = require_role(row.shore, 1, p7_classes, "surface shore")
		row.bed_ref = require_role(row.bed, 1, p7_classes, "surface bed")
		if row.dust ~= "-" then
			row.dust_ref = require_role(row.dust, 2, {[8] = true}, "surface dust")
		else
			row.dust_ref = 0
		end
		surface_by_id[row.id] = deep_copy(row)
	end
	for index = 1, #resources do
		local row = resources[index]
		row.content_ref = require_role(row.node, 4, {[10] = true}, "resource")
		resource_by_key[row.key] = deep_copy(row)
	end
	for index = 1, #decorations do
		local row = decorations[index]
		if row.kind == "simple" then
			row.content_ref = require_role(row.asset_or_node, 8,
				{[6] = true, [7] = true, [8] = true, [11] = true}, "decoration")
		end
		decoration_by_id[row.id] = deep_copy(row)
	end

	local module = {}
	function module.required_inputs() return deep_copy(REQUIRED_INPUTS) end
	function module.surfaces() return deep_copy(surfaces) end
	function module.resources() return deep_copy(resources) end
	function module.cultural() return deep_copy(cultural) end
	function module.decorations() return deep_copy(decorations) end
	function module.surface(id) return deep_copy(surface_by_id[id]) end
	function module.resource(key) return deep_copy(resource_by_key[key]) end
	function module.cultural_for_race(race) return deep_copy(cultural_by_race[race]) end
	function module.cultural_for_key(key) return deep_copy(cultural_by_key[key]) end
	function module.decoration(id) return deep_copy(decoration_by_id[id]) end
	function module.content_ref(name) return content_ref_by_name[name] end
	function module.param2_kind(content_ref)
		return param2_kind_by_ref[content_ref]
	end
	function module.content_contract() return content_contract end
	function module.r5_manifest_values() return manifest_values.r5_manifest_values end
	function module.r2_layout_body_sha256() return manifest_values.r2_layout_body_sha256 end
	function module.wp43_projection() return deep_copy(wp43_projection) end
	return module
end
