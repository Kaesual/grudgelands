-- Pure WP33 catalog. This file deliberately reads no engine global so the
-- same bytes can be loaded in the main and mapgen environments.

local SCHEMA = "grug_wp33_gathering_catalog_v1"
local NODE_SOURCE = "mods/ITEMS/grug_gathering/nodes.lua"
local HARVEST_SOURCE = "mods/ITEMS/grug_gathering/harvest.lua"
local NODE_SOURCE_SHA256 =
	"df082b58d7d41276dcbec163603f95181d64d258ca1464233bac672dda1cb354"
local HARVEST_SOURCE_SHA256 =
	"ae3ea6e5c3b18368fd83ff80aefd3526c23e2e5a2b4087b4df9cfd8c172b48e0"
local EXPECTED_MANIFEST_SHA256 =
	"65c192d04686d01390bdd51b627daf539f11bbf435750c96245a994246254432"

local PLACEMENT = {
	schema = "P9G-1",
	kind = "simple",
	root_offset = {x = 0, y = 1, z = 0},
	cells = {{x = 0, y = 0, z = 0, param2 = 0, force_place = false}},
	footprint_min = {x = 0, y = 0, z = 0},
	footprint_max = {x = 0, y = 0, z = 0},
	lower_two_policy = "preserve_p7",
	minimum_surface_y = 1,
	fill_numerator = 1,
	write_capability = 8,
	root_predecessor = "accepted_p7_air_clear",
	support_authority = "settled_p7_or_immediately_lower_analytic_p7",
	failure_policy = "reject_no_move_retry_refill_or_fallback",
}

local ALL_DRY_HOSTS = {
	{biome = "grug_badlands", support = "grug_nodes:mesa_clay"},
	{biome = "grug_badlands_east", support = "grug_nodes:mesa_clay"},
	{biome = "grug_beach", support = "default:sand"},
	{biome = "grug_blight", support = "grug_nodes:blight_dirt"},
	{biome = "grug_bone_forest", support = "grug_nodes:dirt_with_bone_litter"},
	{biome = "grug_crags", support = "default:gravel"},
	{biome = "grug_crags_snowy", support = "default:snowblock"},
	{biome = "grug_deep_forest", support = "grug_nodes:dirt_with_forest_litter"},
	{biome = "grug_deep_jungle", support = "grug_nodes:dirt_with_canopy_litter"},
	{biome = "grug_elf_forest", support = "grug_nodes:dirt_with_silver_litter"},
	{biome = "grug_jungle_edge", support = "default:dirt_with_rainforest_litter"},
	{biome = "grug_jungle_fringe", support = "grug_nodes:dirt_with_canopy_litter"},
	{biome = "grug_meadows", support = "default:dirt_with_grass"},
	{biome = "grug_pine_hills", support = "default:dirt_with_coniferous_litter"},
	{biome = "grug_savanna", support = "default:dry_dirt_with_dry_grass"},
	{biome = "grug_swamp", support = "grug_nodes:mud"},
}

local function host(biome, support)
	return {biome = biome, support = support}
end

local function p9g(id, key, name, density, zones, hosts, shore, kind, grade,
		farmable, image)
	return {
		placement_class = "new_p9g_source",
		id = id,
		key = key,
		name = name,
		raw_item = "grug_gathering:" .. key,
		source_node = "grug_gathering:" .. key .. "_source",
		fill_numerator = 1,
		fill_denominator = density,
		zones = zones,
		hosts = hosts,
		shore_predicate = shore,
		shore_water_classes = shore == "none" and {} or {
			"coastal_shelf", "deep_ocean", "immutable_dragon_channel",
			"planned_water",
		},
		harvest_kind = kind,
		required_group = grade or 0,
		drop_count = 1,
		farmable = farmable,
		image = image,
		source_file = NODE_SOURCE,
		source_file_sha256 = NODE_SOURCE_SHA256,
	}
end

local P9G = {
	p9g("wp33_corn_source_v1", "corn", "Corn", 256, {
		"elandor_ashenward_march", "elandor_dawnmere_fields",
		"elandor_goldmead_vale", "elandor_whitebridge_shire",
		"front_broken_causeway", "front_shattered_line",
		"kragmar_bannerbreak_mesa", "kragmar_redtusk_savanna",
		"kragmar_speargrass_reach", "kragmar_sunscar_flats",
	}, {
		host("grug_meadows", "default:dirt_with_grass"),
		host("grug_savanna", "default:dry_dirt_with_dry_grass"),
	}, "none", "food", nil, true,
		"default_dry_grass_3.png^[colorize:#d9ad35:95"),
	p9g("wp33_crimson_lotus_source_v1", "crimson_lotus", "Crimson Lotus", 1024, {
		"front_skyglass_canopy", "front_stormscale_summit",
	}, {
		host("grug_deep_jungle", "grug_nodes:dirt_with_canopy_litter"),
		host("grug_jungle_fringe", "grug_nodes:dirt_with_canopy_litter"),
	}, "none", "healing_herb", 3, false,
		"default_marram_grass_1.png^[colorize:#d32459:145"),
	p9g("wp33_dragonweed_source_v1", "dragonweed", "Dragonweed", 768, {
		"elandor_ashenward_march", "elandor_frostbarrow_shelf",
		"kragmar_bannerbreak_mesa", "kragmar_ossuary_reach",
	}, {
		host("grug_badlands", "grug_nodes:mesa_clay"),
		host("grug_bone_forest", "grug_nodes:dirt_with_bone_litter"),
		host("grug_crags", "default:gravel"),
		host("grug_deep_forest", "grug_nodes:dirt_with_forest_litter"),
	}, "none", "healing_herb", 2, false,
		"default_dry_grass_2.png^[colorize:#7e2f8c:120"),
	p9g("wp33_gravemoss_source_v1", "gravemoss", "Gravemoss", 512, {
		"elandor_copperfell_foothills", "kragmar_mournfen",
	}, {
		host("grug_blight", "grug_nodes:blight_dirt"),
		host("grug_pine_hills", "default:dirt_with_coniferous_litter"),
	}, "none", "healing_herb", 1, false,
		"default_fern_1.png^[colorize:#526c45:100"),
	p9g("wp33_marshbloom_source_v1", "marshbloom", "Marshbloom", 512, {
		"elandor_lorindor", "elandor_whitebridge_shire",
		"kragmar_ossuary_reach", "kragmar_whispering_reedlands",
	}, {host("grug_swamp", "grug_nodes:mud")}, "none", "spice", 2, true,
		"default_marram_grass_2.png^[colorize:#84b7a0:115"),
	p9g("wp33_melon_source_v1", "melon", "Melon", 512, {
		"elandor_glassroot_wilds", "front_skyglass_canopy",
		"front_stormscale_summit", "kragmar_kapok_cradle",
		"kragmar_raincall_basin", "kragmar_thunderroot_wilds",
		"kragmar_totemwater_reach", "kragmar_whispering_reedlands",
	}, {
		host("grug_deep_jungle", "grug_nodes:dirt_with_canopy_litter"),
		host("grug_jungle_edge", "default:dirt_with_rainforest_litter"),
		host("grug_jungle_fringe", "grug_nodes:dirt_with_canopy_litter"),
	}, "none", "food", nil, true,
		"default_apple.png^[colorize:#61a94e:95"),
	p9g("wp33_mushroom_source_v1", "mushroom", "Mushroom", 384, {
		"elandor_ashenward_march", "elandor_glassroot_wilds",
		"elandor_lorindor", "elandor_moonfall_wood",
		"elandor_whitebridge_shire", "front_broken_causeway",
		"front_gravesalt_escarpment", "front_skyglass_canopy",
		"front_stormscale_summit", "kragmar_blackwind_rise",
		"kragmar_ossuary_reach", "kragmar_thunderroot_wilds",
		"kragmar_totemwater_reach", "kragmar_whispering_reedlands",
	}, {
		host("grug_bone_forest", "grug_nodes:dirt_with_bone_litter"),
		host("grug_deep_forest", "grug_nodes:dirt_with_forest_litter"),
		host("grug_swamp", "grug_nodes:mud"),
	}, "none", "found_only_food", nil, false,
		"default_pine_bush_sapling.png^[colorize:#9b7653:150"),
	p9g("wp33_potato_source_v1", "potato", "Potato", 256, {
		"elandor_ashenward_march", "elandor_dawnmere_fields",
		"elandor_goldmead_vale", "elandor_whitebridge_shire",
		"front_broken_causeway",
	}, {host("grug_meadows", "default:dirt_with_grass")}, "none", "food", nil,
		true, "default_clay_lump.png^[colorize:#b58b55:95"),
	p9g("wp33_rock_salt_source_v1", "rock_salt", "Rock Salt", 1024, {
		"front_gravesalt_escarpment", "front_stormscale_summit",
		"front_wyrmglass_crown",
	}, {host("grug_beach", "default:sand")}, "salt_cardinal",
		"found_only_food", nil, false,
		"default_clay_lump.png^[colorize:#f4efe2:155"),
	p9g("wp33_stormkelp_source_v1", "stormkelp", "Stormkelp", 1024, {
		"front_gravesalt_escarpment", "front_skyglass_canopy",
		"front_stormscale_summit", "front_wyrmglass_crown",
	}, ALL_DRY_HOSTS, "dry_cardinal", "spice", 3, true,
		"default_marram_grass_3.png^[colorize:#3c8290:120"),
	p9g("wp33_sunleaf_source_v1", "sunleaf", "Sunleaf", 384, {
		"elandor_goldmead_vale", "elandor_starbough_vale",
		"kragmar_raincall_basin", "kragmar_redtusk_savanna",
	}, {
		host("grug_elf_forest", "grug_nodes:dirt_with_silver_litter"),
		host("grug_jungle_edge", "default:dirt_with_rainforest_litter"),
		host("grug_meadows", "default:dirt_with_grass"),
		host("grug_savanna", "default:dry_dirt_with_dry_grass"),
	}, "none", "spice", 1, true,
		"default_grass_3.png^[colorize:#e5d34a:105"),
	p9g("wp33_wild_cocoa_source_v1", "wild_cocoa", "Wild Cocoa", 1024, {
		"front_skyglass_canopy", "front_stormscale_summit",
	}, {
		host("grug_deep_jungle", "grug_nodes:dirt_with_canopy_litter"),
		host("grug_jungle_fringe", "grug_nodes:dirt_with_canopy_litter"),
	}, "none", "found_only_food", nil, false,
		"default_pine_bush_sapling.png^[colorize:#70452d:175"),
}

local REUSE = {
	{placement_class = "reuse_r6_source", id = "wp33_apple_r6_reuse_v1",
		key = "apple", name = "Apple", feature_ids = {
			"deep_forest_apple_tree", "elf_forest_apple_tree",
			"meadows_apple_tree"}, source_items = {"default:apple"},
		outputs = {"default:apple"}, harvest_kind = "existing_food",
		farmable = true},
	{placement_class = "reuse_r6_source", id = "wp33_blueberry_r6_reuse_v1",
		key = "blueberry", name = "Blueberries", feature_ids = {
			"pine_hills_blueberry_bush"},
		source_items = {"default:blueberry_bush_leaves_with_berries"},
		outputs = {"default:blueberries"}, harvest_kind = "existing_food",
		farmable = true},
	{placement_class = "reuse_r6_source", id = "wp33_gravewood_r6_reuse_v1",
		key = "gravewood", name = "Gravewood", feature_ids = {
			"blight_gravewood", "bone_forest_gravewood"},
		source_items = {"grug_trees:gravewood_tree"},
		outputs = {"grug_trees:gravewood_wood"}, harvest_kind = "signature_wood",
		farmable = false},
	{placement_class = "reuse_r6_source", id = "wp33_kapok_r6_reuse_v1",
		key = "kapok", name = "Kapok", feature_ids = {
			"emergent_jungle_tree", "jungle_edge_jungle_tree", "jungle_tree"},
		source_items = {"default:jungletree"}, outputs = {"default:junglewood"},
		harvest_kind = "signature_wood", farmable = false},
	{placement_class = "reuse_r6_source",
		id = "wp33_mountain_pine_r6_reuse_v1", key = "mountain_pine",
		name = "Mountain Pine", feature_ids = {"crags_snowy_pine",
			"pine_hills_pine_tree", "pine_hills_small_pine_tree"},
		source_items = {"default:pine_tree"}, outputs = {"default:pine_wood"},
		harvest_kind = "signature_wood", farmable = false},
	{placement_class = "reuse_r6_source", id = "wp33_oak_r6_reuse_v1",
		key = "oak", name = "Oak", feature_ids = {"deep_forest_apple_log",
			"deep_forest_apple_tree", "elf_forest_apple_tree",
			"meadows_apple_tree"}, source_items = {"default:tree"},
		outputs = {"default:wood"}, harvest_kind = "signature_wood",
		farmable = false},
	{placement_class = "reuse_r6_source", id = "wp33_silverwood_r6_reuse_v1",
		key = "silverwood", name = "Silverwood", feature_ids = {
			"elf_forest_silverwood"},
		source_items = {"grug_trees:silverwood_tree"},
		outputs = {"grug_trees:silverwood_wood"},
		harvest_kind = "signature_wood", farmable = false},
	{placement_class = "reuse_r6_source",
		id = "wp33_spikethorn_acacia_r6_reuse_v1", key = "spikethorn_acacia",
		name = "Spikethorn Acacia", feature_ids = {"savanna_acacia_tree"},
		source_items = {"default:acacia_tree"},
		outputs = {"default:acacia_wood"}, harvest_kind = "signature_wood",
		farmable = false},
}

local function cultural(key, material, biomes, zone, ordinary_family,
		ordinary_group, concentrated_family, image, digest)
	local id = "wp33_" .. key .. "_source_v1"
	local node = "grug_gathering:" .. key .. "_source"
	return {
		placement_class = "r6_cultural_slot",
		id = id,
		key = key,
		name = material,
		raw_item = "grug_materials:" .. key,
		source_node = node,
		eligible_biomes = biomes,
		ordinary_fill_numerator = 1,
		ordinary_fill_denominator = 4096,
		concentrated_fill_numerator = 1,
		concentrated_fill_denominator = 1024,
		concentrated_zone = zone,
		ordinary_family = ordinary_family,
		ordinary_group = ordinary_group,
		concentrated_family = concentrated_family,
		concentrated_tier = 4,
		drop_count = 1,
		image = image,
		source_file = NODE_SOURCE,
		source_file_sha256 = NODE_SOURCE_SHA256,
		registration = {
			schema = "grug_wp40_r6_cultural_registration_v1",
			cultural_key = key,
			id = id,
			template_or_simple_kind = "simple",
			footprint_min_x = 0, footprint_max_x = 0,
			footprint_min_y = 1, footprint_max_y = 1,
			footprint_min_z = 0, footprint_max_z = 0,
			lower_two_policy = "preserve_p7",
			cells = {{x = 0, y = 1, z = 0, node = node, param2 = 0,
				force_place = false}},
			digest = digest,
		},
	}
end

local CULTURAL = {
	cultural("gravesalt", "Gravesalt", {"grug_beach", "grug_blight",
		"grug_bone_forest", "grug_swamp"}, "kragmar_blackwind_rise",
		"shovel", "crumbly", "pick",
		"default_clay.png^[colorize:#ddd8c8:145",
		"a2c5e9ccc3728b45a20e09b7b745132b8671384d74e53f9b069cc3a4571ab8e0"),
	cultural("moonresin", "Moonresin", {"grug_deep_forest", "grug_elf_forest",
		"grug_jungle_fringe"}, "elandor_glassroot_wilds", "axe", "choppy",
		"axe", "default_tree.png^[colorize:#a9c9ee:130",
		"3d849bf5fdc17cc888b050fd11e46f18170e9621e6cffdf8e114bd1c212789bd"),
	cultural("red_ochre", "Red Ochre", {"grug_badlands", "grug_savanna"},
		"kragmar_bannerbreak_mesa", "shovel", "crumbly", "shovel",
		"default_clay.png^[colorize:#a54122:150",
		"065bb11cfae02e288513dd0b88274b937637e6049394dfee15bab13be356b515"),
	cultural("runeslate", "Runeslate", {"grug_crags", "grug_crags_snowy",
		"grug_pine_hills"}, "elandor_stormvault_heights", "hand",
		"oddly_breakable_by_hand", "pick",
		"default_stone.png^[colorize:#64758a:110",
		"1225bd16c920a85a6cca65a1f13d13df05910a5f32889bfdecbab301267098a8"),
	cultural("spirit_resin", "Spirit Resin", {"grug_badlands_east",
		"grug_deep_jungle", "grug_jungle_edge", "grug_swamp"},
		"kragmar_thunderroot_wilds", "axe", "choppy", "axe",
		"default_tree.png^[colorize:#8ca833:130",
		"266533b8cafb2f39a02164448fec5ad6ef21bdad9bcf40f783574b36ea672418"),
	cultural("sunwax", "Sunwax", {"grug_deep_forest", "grug_meadows"},
		"elandor_ashenward_march", "hand", "oddly_breakable_by_hand", "axe",
		"default_tree.png^[colorize:#f0c45a:120",
		"1b2c9ca121f67e9c939e048163f25fda7cfac59f7d3f70e9c737d38a8d41737e"),
}

local function copy(value, active)
	if type(value) ~= "table" then return value end
	active = active or {}
	if active[value] then error("grug_gathering: catalog graph contains a cycle", 0) end
	active[value] = true
	local result = {}
	for key, child in pairs(value) do result[copy(key, active)] = copy(child, active) end
	active[value] = nil
	return result
end

local function frame(value)
	local bytes
	if type(value) == "number" then
		if value % 1 ~= 0 then error("grug_gathering: non-integer canonical field", 0) end
		bytes = string.format("%.0f", value)
	elseif type(value) == "boolean" then
		bytes = value and "true" or "false"
	elseif type(value) == "string" then
		bytes = value
	else
		error("grug_gathering: invalid canonical field", 0)
	end
	return tostring(#bytes) .. ":" .. bytes
end

local function append(parts, value)
	parts[#parts + 1] = frame(value)
end

local function append_array(parts, values)
	append(parts, #values)
	for index = 1, #values do append(parts, values[index]) end
end

local function append_hosts(parts, hosts)
	append(parts, #hosts)
	for index = 1, #hosts do
		append(parts, hosts[index].biome)
		append(parts, hosts[index].support)
	end
end

local function canonical_bytes()
	local parts = {}
	append(parts, SCHEMA)
	append(parts, NODE_SOURCE)
	append(parts, NODE_SOURCE_SHA256)
	append(parts, HARVEST_SOURCE)
	append(parts, HARVEST_SOURCE_SHA256)
	append(parts, PLACEMENT.schema)
	append(parts, PLACEMENT.kind)
	for _, axis in ipairs({"x", "y", "z"}) do append(parts, PLACEMENT.root_offset[axis]) end
	for _, axis in ipairs({"x", "y", "z"}) do append(parts, PLACEMENT.cells[1][axis]) end
	append(parts, PLACEMENT.cells[1].param2)
	append(parts, PLACEMENT.cells[1].force_place)
	for _, bound in ipairs({PLACEMENT.footprint_min, PLACEMENT.footprint_max}) do
		for _, axis in ipairs({"x", "y", "z"}) do append(parts, bound[axis]) end
	end
	append(parts, PLACEMENT.lower_two_policy)
	append(parts, PLACEMENT.minimum_surface_y)
	append(parts, PLACEMENT.fill_numerator)
	append(parts, PLACEMENT.write_capability)
	append(parts, PLACEMENT.root_predecessor)
	append(parts, PLACEMENT.support_authority)
	append(parts, PLACEMENT.failure_policy)
	append(parts, "new_p9g_source")
	append(parts, #P9G)
	for index = 1, #P9G do
		local row = P9G[index]
		for _, field in ipairs({"placement_class", "id", "key", "name", "raw_item",
				"source_node", "fill_numerator", "fill_denominator"}) do
			append(parts, row[field])
		end
		append_array(parts, row.zones)
		append_hosts(parts, row.hosts)
		append(parts, row.shore_predicate)
		append_array(parts, row.shore_water_classes)
		for _, field in ipairs({"harvest_kind", "required_group", "drop_count",
				"farmable", "image", "source_file", "source_file_sha256"}) do
			append(parts, row[field])
		end
	end
	append(parts, "reuse_r6_source")
	append(parts, #REUSE)
	for index = 1, #REUSE do
		local row = REUSE[index]
		for _, field in ipairs({"placement_class", "id", "key", "name"}) do
			append(parts, row[field])
		end
		append_array(parts, row.feature_ids)
		append_array(parts, row.source_items)
		append_array(parts, row.outputs)
		append(parts, row.harvest_kind)
		append(parts, row.farmable)
	end
	append(parts, "r6_cultural_slot")
	append(parts, #CULTURAL)
	for index = 1, #CULTURAL do
		local row = CULTURAL[index]
		for _, field in ipairs({"placement_class", "id", "key", "name", "raw_item",
				"source_node"}) do append(parts, row[field]) end
		append_array(parts, row.eligible_biomes)
		for _, field in ipairs({"ordinary_fill_numerator",
				"ordinary_fill_denominator", "concentrated_fill_numerator",
				"concentrated_fill_denominator", "concentrated_zone",
				"ordinary_family", "ordinary_group", "concentrated_family",
				"concentrated_tier", "drop_count", "image", "source_file",
				"source_file_sha256"}) do append(parts, row[field]) end
		local registration = row.registration
		for _, field in ipairs({"schema", "cultural_key", "id",
				"template_or_simple_kind", "footprint_min_x", "footprint_max_x",
				"footprint_min_y", "footprint_max_y", "footprint_min_z",
				"footprint_max_z", "lower_two_policy"}) do
			append(parts, registration[field])
		end
		append(parts, #registration.cells)
		local cell = registration.cells[1]
		for _, field in ipairs({"x", "y", "z", "node", "param2", "force_place"}) do
			append(parts, cell[field])
		end
		append(parts, registration.digest)
	end
	return table.concat(parts)
end

local CANONICAL_BYTES = canonical_bytes()
local module = {}

function module.manifest()
	return {
		schema = SCHEMA,
		sha256 = EXPECTED_MANIFEST_SHA256,
		canonical_bytes = CANONICAL_BYTES,
		source_files = {
			{path = NODE_SOURCE, sha256 = NODE_SOURCE_SHA256},
			{path = HARVEST_SOURCE, sha256 = HARVEST_SOURCE_SHA256},
		},
		placement = copy(PLACEMENT),
		population = {new_p9g_source = 12, reuse_r6_source = 8,
			r6_cultural_slot = 6},
	}
end

function module.p9g_sources() return copy(P9G) end
function module.reuse_sources() return copy(REUSE) end
function module.cultural_sources() return copy(CULTURAL) end
function module.cultural_registrations()
	local result = {}
	for index = 1, #CULTURAL do result[index] = copy(CULTURAL[index].registration) end
	return result
end

return module
