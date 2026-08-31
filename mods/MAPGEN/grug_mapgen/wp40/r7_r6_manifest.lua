-- Frozen production constructor values for the accepted R6 catalogs. The
-- accepted evidence hashes remain historical inputs; R7 authenticates its own
-- current source set separately before enabling the writer.

local INPUT_ROWS = [[
AGENTS.md|b12f55731dfee4e050f97ea0c221415fdffd9cef7ded5b0b8b7a3b5c16c4a53b|55978
docs/design/biomes_mobs.md|f1f3255033565d2eecb7752ac96b0585946e631f8e19a8f8a8af2ccc704f1fe4|103928
docs/design/items_crafting.md|b1210336d8733fd4cc606bc40f19758229a8fa75c69dc92cc891b55abbbdcdd1|125115
docs/design/world.md|3d99b9e32d64a271bb641b23d6a181850b3fb28cc6ae95bdb1c9a84a77a9ffb6|56864
docs/design/world_zones.md|f8bf8e8639d03d0932b70b9177f96bcb3e8c3a5288e65be61250233dd9e670ec|97916
docs/research/luanti-lua.md|0ea956b3ffc0594791a6b63f8fee4e912a5c1019010378294f191713158db79e|22929
docs/research/wp40-simple-map-r6-contract.md|814fbb7915c6c1590f65ec4d6c34b165543528a76c14db5f570cc8e9710a954f|61941
docs/research/wp40-simple-map-r6-cultural-opportunities.tsv|a398970fda8ecf0324ba807218aff1d2632910d85be6e68a4f4afa4e00a7967e|1831
docs/research/wp40-simple-map-r6-decisions.md|af0860e5d03239f9074510bca2247d9d46eabdce54cb425f0cd833f708ffcc58|6412
docs/research/wp40-simple-map-r6-decoration-draft.tsv|87167c0ad64e347387a36465270b5e87f215d6fe04f13eff2e68fa01c9037b6b|5451
docs/research/wp40-simple-map-r6-resource-density.tsv|31e616e0686d9099777de2304b6c21ba5294393444ec7ab1ef1cac1360443394|3655
docs/research/wp40-simple-map-r6-seed-corpus.tsv|c055c7910e97f6062111f33f15365c5d85694c51c0b474b0ffa378ba14e65c37|2443
docs/research/wp40-simple-map-r6-surface-content.tsv|085e3a3e3cefb8ea36bac101e8f801175cd5e8f2b32f9bad280eefe45412e5e4|10298
docs/research/wp43_wp40_handoff.md|85d0d0a24ec49602c22443c42ab9c7aa1bab1d441376a1d4f7be2e89b63dd9d8|9712
mods/BASE/default/schematics/acacia_bush.mts|2bbbf10178e47cca46a0fca4b038fc3dd2c6d34493e12a5994af71fb12872e3e|114
mods/BASE/default/schematics/acacia_tree.mts|9ca2398b751769529285cac76cb160eadc16889229679e7c9c3273b1e5b488ff|207
mods/BASE/default/schematics/apple_log.mts|815149bc000ad7141054ca1c8d00b3e551d910df872224ae0ceaacc74482bed9|88
mods/BASE/default/schematics/apple_tree.mts|63a8fac562fbc9cc1a1eacb00cb89a7d933c61b1c453df9817d9528528be7e02|209
mods/BASE/default/schematics/aspen_tree.mts|608033066589f71031da6e5eafbf2a29f38a443f104e70c7c0ae836e9c428dd6|174
mods/BASE/default/schematics/blueberry_bush.mts|e84c601c878b840fcacfed3b63110d8f1e92e061c30f5fc353fa84edc7f24fc8|80
mods/BASE/default/schematics/bush.mts|d7c609334560f5bc6c02525e2c79db0dd399dd99d4d3d1630a57927693b389f6|99
mods/BASE/default/schematics/emergent_jungle_tree.mts|84aa1bfe7a472e7d40ad6bb740a298b4bb9d079c2f96285a1d1874a0b469a34a|504
mods/BASE/default/schematics/jungle_tree.mts|89fd44e42457e75442e42324a22385c87a5f3f6f55dbafa6c4a61709631743f7|255
mods/BASE/default/schematics/large_cactus.mts|034be90f56d4002c8167fed1b8b18ce184ee59fa3e4d42569922e3143b7c8619|87
mods/BASE/default/schematics/papyrus_on_dirt.mts|bb9ba20b069a6f6661fe2c0179b23533e94776da41f7d38d47bbc7fd345f74d1|73
mods/BASE/default/schematics/pine_bush.mts|50ebbfb83d0bf1827086f3652c49b7b750d8eb13c7b3cbcbada7c0dcb5410431|110
mods/BASE/default/schematics/pine_tree.mts|3d91afa7dd3fbf6d15c295716af5409d3d77b0dff1464d623ef91433fdfd508f|178
mods/BASE/default/schematics/small_pine_tree.mts|a1b4e0dae20116c67f852f10578ddeda65f9596e60ae7c40cb5352124eefcdce|174
mods/BASE/default/schematics/snowy_pine_tree_from_sapling.mts|d0c408bfff1cfde8c3867c6e1c6b6672230c90c610ae95902a13c609c3f0433b|235
mods/ITEMS/grug_materials/registry.lua|fc58d8589530b67cd7b44f8e05e09a68fc16f7881054cb9d432d184f28282873|24894
mods/ITEMS/grug_nodes/init.lua|6559fc6f30ca8d857697c01fce61c54aca3a13c1ccdc562be327f607437ab152|7891
mods/ITEMS/grug_trees/init.lua|25c1398719f93ac194350fd6935513c798f9df2dd459b69e06208c52beb3626a|9688
mods/MAPGEN/grug_mapgen/wp43_handoff.lua|14883f4ad90dcb1c18b6a093cbbb12cee300894d35db4e7974d6eef9c25a5be4|12099
reference_projects/luanti/doc/lua_api.md|6da3d285a40902c904f5f673cd32cdc2e47cce62559f0c0ebb4d8acb7efe1287|541196
reference_projects/luanti/src/mapgen/mg_schematic.cpp|64ca88cd9bc4b05230b8fda1a4b379c13912cdc524398a2855ebff626664b4be|14918
reference_projects/luanti/src/mapgen/mg_schematic.h|2f70779d64ef7422252eb7d4fb86bb2de6c865217f7b765a0993aab1b743a1dd|3394
reference_projects/luanti/src/mapnode.cpp|e4a54937a861143116774858aa39fff1b30560ad838282989ec54b038c74f389|17743
reference_projects/luanti/src/script/lua_api/l_mapgen.cpp|93590ed8fc136e352a38ef874e6b3e9d684ce943a48868ec22dc1aec15258ee0|54820
]]

local SURFACE_ROWS = [[
grug_badlands|grug_nodes:mesa_clay|grug_nodes:mesa_clay|3|default:gravel|default:gravel|-
grug_badlands_east|grug_nodes:mesa_clay|grug_nodes:mesa_clay|3|default:gravel|default:gravel|-
grug_beach|default:sand|default:sand|2|default:sand|default:sand|-
grug_blight|grug_nodes:blight_dirt|default:dirt|3|default:gravel|default:gravel|-
grug_bone_forest|grug_nodes:dirt_with_bone_litter|default:dirt|3|default:gravel|default:gravel|-
grug_crags|default:gravel|default:gravel|2|default:gravel|default:gravel|-
grug_crags_snowy|default:snowblock|default:gravel|2|default:gravel|default:gravel|default:snow
grug_deep_forest|grug_nodes:dirt_with_forest_litter|default:dirt|3|default:sand|default:sand|-
grug_deep_jungle|grug_nodes:dirt_with_canopy_litter|default:dirt|3|default:sand|default:sand|-
grug_elf_forest|grug_nodes:dirt_with_silver_litter|default:dirt|3|default:sand|default:sand|-
grug_jungle_edge|default:dirt_with_rainforest_litter|default:dirt|3|default:sand|default:sand|-
grug_jungle_fringe|grug_nodes:dirt_with_canopy_litter|default:dirt|3|default:sand|default:sand|-
grug_meadows|default:dirt_with_grass|default:dirt|3|default:sand|default:sand|-
grug_pine_hills|default:dirt_with_coniferous_litter|default:dirt|3|default:gravel|default:gravel|-
grug_savanna|default:dry_dirt_with_dry_grass|default:dry_dirt|3|default:sand|default:sand|-
grug_swamp|grug_nodes:mud|grug_nodes:mud|2|grug_nodes:mud|grug_nodes:mud|-
]]

local RESOURCE_ROWS = [[
abyssal_crystal|universal|5|-;-;-;-;2048;2048|2
citrine|regional_g1|2|-;12000;6000;3000;3000;3000|3
coal|universal|1|128;128;128;128;128;128|8
copper|universal|1|256;256;256;256;256;256|8
diamond|regional_g2|4|-;-;-;12000;6000;3000|2
emberglass|universal|4|-;-;-;2048;2048;2048|4
garnet|regional_g1|2|-;12000;6000;3000;3000;3000|3
gold|universal|2|-;1024;1024;1024;1024;1024|4
iron|universal|1|128;128;128;128;128;128|8
jade|regional_g1|2|-;12000;6000;3000;3000;3000|3
quartz|universal|1|256;256;256;256;256;256|8
ruby|regional_g2|4|-;-;-;12000;6000;3000|2
sapphire|regional_g2|4|-;-;-;12000;6000;3000|2
silver|universal|3|-;-;1024;1024;1024;1024|4
tin|universal|1|384;384;384;384;384;384|8
]]

local CULTURAL_ROWS = [[
undead|gravesalt|grug_blight;grug_bone_forest;grug_swamp;grug_beach|kragmar_blackwind_rise
elf|moonresin|grug_elf_forest;grug_deep_forest;grug_jungle_fringe|elandor_glassroot_wilds
orc|red_ochre|grug_savanna;grug_badlands|kragmar_bannerbreak_mesa
dwarf|runeslate|grug_pine_hills;grug_crags;grug_crags_snowy|elandor_stormvault_heights
troll|spirit_resin|grug_jungle_edge;grug_deep_jungle;grug_swamp;grug_badlands_east|kragmar_thunderroot_wilds
human|sunwax|grug_meadows;grug_deep_forest|elandor_ashenward_march
]]

local DECORATION_ROWS = [[
badlands_dry_shrub|grug_badlands;grug_badlands_east|simple|default:dry_shrub|grug_nodes:mesa_clay|1|125|param2_4|4
badlands_large_cactus|grug_badlands;grug_badlands_east|template|large_cactus.mts|grug_nodes:mesa_clay|1|1000|center_xz;quarter_turn_rotation|1
blight_bone_pile|grug_blight|simple|grug_nodes:bone_pile|grug_nodes:blight_dirt|1|500|none|4
blight_dry_shrub|grug_blight|simple|default:dry_shrub|grug_nodes:blight_dirt|3|200|param2_4|4
blight_gravewood|grug_blight|simple|grug_trees:gravewood_tree|grug_nodes:blight_dirt|3|2000|height_2_to_4_from_domain_hash|3
bone_forest_bone_pile|grug_bone_forest|simple|grug_nodes:bone_pile|grug_nodes:dirt_with_bone_litter|1|250|none|4
bone_forest_gravewood|grug_bone_forest|simple|grug_trees:gravewood_tree|grug_nodes:dirt_with_bone_litter|3|200|height_2_to_4_from_domain_hash|3
crags_snowy_pine|grug_crags|template|snowy_pine_tree_from_sapling.mts|default:gravel|1|500|surface_y_at_least_60;center_xz;quarter_turn_rotation|2
deep_forest_apple_log|grug_deep_forest|template|apple_log.mts|grug_nodes:dirt_with_forest_litter|1|1000|offset_y_plus_1;center_x_only;replace_mushroom_with_air;quarter_turn_rotation|1
deep_forest_apple_tree|grug_deep_forest|template|apple_tree.mts|grug_nodes:dirt_with_forest_litter|3|250|center_xz;quarter_turn_rotation|1
deep_forest_aspen_tree|grug_deep_forest|template|aspen_tree.mts|grug_nodes:dirt_with_forest_litter|1|125|center_xz;quarter_turn_rotation|2
deep_forest_fern_1|grug_deep_forest|simple|default:fern_1|grug_nodes:dirt_with_forest_litter|1|50|one_entry_per_variant|4
deep_forest_fern_2|grug_deep_forest|simple|default:fern_2|grug_nodes:dirt_with_forest_litter|1|50|one_entry_per_variant|4
deep_forest_fern_3|grug_deep_forest|simple|default:fern_3|grug_nodes:dirt_with_forest_litter|1|50|one_entry_per_variant|4
elf_forest_apple_tree|grug_elf_forest|template|apple_tree.mts|grug_nodes:dirt_with_silver_litter|1|500|center_xz;quarter_turn_rotation|1
elf_forest_grass_1|grug_elf_forest|simple|default:grass_1|grug_nodes:dirt_with_silver_litter|1|50|one_entry_per_variant|4
elf_forest_grass_2|grug_elf_forest|simple|default:grass_2|grug_nodes:dirt_with_silver_litter|1|50|one_entry_per_variant|4
elf_forest_grass_3|grug_elf_forest|simple|default:grass_3|grug_nodes:dirt_with_silver_litter|1|50|one_entry_per_variant|4
elf_forest_silverwood|grug_elf_forest|template|aspen_tree.mts|grug_nodes:dirt_with_silver_litter|1|200|silverwood_replacements;center_xz;quarter_turn_rotation|2
emergent_jungle_tree|grug_deep_jungle;grug_jungle_fringe|template|emergent_jungle_tree.mts|grug_nodes:dirt_with_canopy_litter|1|200|surface_y_at_most_32;offset_y_minus_4;center_xz;quarter_turn_rotation|1
jungle_edge_jungle_tree|grug_jungle_edge|template|jungle_tree.mts|default:dirt_with_rainforest_litter|1|125|center_xz;quarter_turn_rotation|2
jungle_edge_junglegrass|grug_jungle_edge|simple|default:junglegrass|default:dirt_with_rainforest_litter|1|25|none|4
jungle_junglegrass|grug_deep_jungle;grug_jungle_fringe|simple|default:junglegrass|grug_nodes:dirt_with_canopy_litter|1|20|none|4
jungle_tree|grug_deep_jungle;grug_jungle_fringe|template|jungle_tree.mts|grug_nodes:dirt_with_canopy_litter|1|50|center_xz;quarter_turn_rotation|2
meadows_apple_tree|grug_meadows|template|apple_tree.mts|default:dirt_with_grass|3|2000|center_xz;quarter_turn_rotation|1
meadows_bush|grug_meadows|template|bush.mts|default:dirt_with_grass|1|250|center_xz;quarter_turn_rotation|2
meadows_grass_1|grug_meadows|simple|default:grass_1|default:dirt_with_grass|3|50|one_entry_per_variant|4
meadows_grass_2|grug_meadows|simple|default:grass_2|default:dirt_with_grass|3|50|one_entry_per_variant|4
meadows_grass_3|grug_meadows|simple|default:grass_3|default:dirt_with_grass|3|50|one_entry_per_variant|4
meadows_grass_4|grug_meadows|simple|default:grass_4|default:dirt_with_grass|3|50|one_entry_per_variant|4
meadows_grass_5|grug_meadows|simple|default:grass_5|default:dirt_with_grass|3|50|one_entry_per_variant|4
pine_hills_blueberry_bush|grug_pine_hills|template|blueberry_bush.mts|default:dirt_with_coniferous_litter|1|1000|offset_y_plus_1;center_xz;quarter_turn_rotation|2
pine_hills_fern_1|grug_pine_hills|simple|default:fern_1|default:dirt_with_coniferous_litter|1|50|one_entry_per_variant|4
pine_hills_fern_2|grug_pine_hills|simple|default:fern_2|default:dirt_with_coniferous_litter|1|50|one_entry_per_variant|4
pine_hills_fern_3|grug_pine_hills|simple|default:fern_3|default:dirt_with_coniferous_litter|1|50|one_entry_per_variant|4
pine_hills_pine_bush|grug_pine_hills|template|pine_bush.mts|default:dirt_with_coniferous_litter|3|500|center_xz;quarter_turn_rotation|2
pine_hills_pine_tree|grug_pine_hills|template|pine_tree.mts|default:dirt_with_coniferous_litter|1|250|center_xz;quarter_turn_rotation|2
pine_hills_small_pine_tree|grug_pine_hills|template|small_pine_tree.mts|default:dirt_with_coniferous_litter|1|500|center_xz;quarter_turn_rotation|2
savanna_acacia_bush|grug_savanna|template|acacia_bush.mts|default:dry_dirt_with_dry_grass|1|250|center_xz;quarter_turn_rotation|2
savanna_acacia_tree|grug_savanna|template|acacia_tree.mts|default:dry_dirt_with_dry_grass|1|500|center_xz;quarter_turn_rotation|1
savanna_dry_grass_1|grug_savanna|simple|default:dry_grass_1|default:dry_dirt_with_dry_grass|3|50|one_entry_per_variant|4
savanna_dry_grass_2|grug_savanna|simple|default:dry_grass_2|default:dry_dirt_with_dry_grass|3|50|one_entry_per_variant|4
savanna_dry_grass_3|grug_savanna|simple|default:dry_grass_3|default:dry_dirt_with_dry_grass|3|50|one_entry_per_variant|4
savanna_dry_grass_4|grug_savanna|simple|default:dry_grass_4|default:dry_dirt_with_dry_grass|3|50|one_entry_per_variant|4
savanna_dry_grass_5|grug_savanna|simple|default:dry_grass_5|default:dry_dirt_with_dry_grass|3|50|one_entry_per_variant|4
savanna_dry_shrub|grug_savanna|simple|default:dry_shrub|default:dry_dirt_with_dry_grass|1|250|param2_4|4
swamp_dry_shrub|grug_swamp|simple|default:dry_shrub|grug_nodes:mud|1|250|param2_4|4
swamp_papyrus|grug_swamp|template|papyrus_on_dirt.mts|grug_nodes:mud|1|50|surface_y_1_to_4;replace_dirt_with_mud;center_xz;quarter_turn_rotation|1
]]

local function fields(line)
	local result = {}
	for value in (line .. "|"):gmatch("([^|]*)|") do result[#result + 1] = value end
	return result
end

local function array(value)
	local result = {}
	for item in (value .. ";"):gmatch("([^;]+);") do result[#result + 1] = item end
	return result
end

local function lines(value, callback)
	for line in value:gmatch("[^\r\n]+") do callback(fields(line)) end
end

return function()
	local input_sha256, input_bytes = {}, {}
	lines(INPUT_ROWS, function(row)
		input_sha256[row[1]], input_bytes[row[1]] = row[2], assert(tonumber(row[3]))
	end)
	local surfaces = {}
	lines(SURFACE_ROWS, function(row)
		surfaces[#surfaces + 1] = {id = row[1], top = row[2], filler = row[3],
			filler_depth = assert(tonumber(row[4])), shore = row[5], bed = row[6],
			dust = row[7]}
	end)
	local resources = {}
	lines(RESOURCE_ROWS, function(row)
		local denominators = array(row[4])
		for index = 1, #denominators do
			if denominators[index] == "-" then
				denominators[index] = false
			else
				denominators[index] = assert(tonumber(denominators[index]))
			end
		end
		resources[#resources + 1] = {key = row[1], scope = row[2],
			first_tier = assert(tonumber(row[3])), denominators = denominators,
			max_nodes_per_vein = assert(tonumber(row[5])),
			deep_1500_1999_numerator = 5, deep_1500_1999_denominator = 4,
			deep_2000_floor_numerator = 3, deep_2000_floor_denominator = 2}
	end)
	local cultural = {}
	lines(CULTURAL_ROWS, function(row)
		cultural[#cultural + 1] = {race = row[1], key = row[2],
			ordinary_denominator = 4096, concentrated_denominator = 1024,
			biomes = array(row[3]), concentrated_zone = row[4]}
	end)
	local decorations = {}
	lines(DECORATION_ROWS, function(row)
		decorations[#decorations + 1] = {id = row[1], biomes = array(row[2]),
			kind = row[3], asset_or_node = row[4], host = row[5],
			numerator = assert(tonumber(row[6])), denominator = assert(tonumber(row[7])),
			rule = row[8], settlement_class = assert(tonumber(row[9]))}
	end)
	return {
		schema = "grug_wp40_r6_manifest_values_v1",
		contract_sha256 =
			"814fbb7915c6c1590f65ec4d6c34b165543528a76c14db5f570cc8e9710a954f",
		r5_manifest_values = {
			schema = "grug_wp40_r5_mapgen_manifest_v1",
			engine_commit = "df04879066de6eb94ca43996822a6dfacc74feca",
			mg_name = "v7", water_level = 1, mapgen_limit = 31007, chunksize = 5,
			central_owner_y_min = -30912, central_owner_y_max = 30927,
			heightmap_entries = 6400, heightmap_sentinel = -31007,
			heightmap_order = "x_fast_z_outer", emerge_threads = 1,
			engine_emerge_setting = "num_emerge_threads",
			mg_flags = "biomes,caves,decorations,dungeons,light,ores",
			mgv7_spflags = "caverns,mountains,ridges", mgv7_dungeon_ymin = -31000,
			mgv7_dungeon_ymax = -193, authored_floor = -37,
			force_native_dungeon = false,
		},
		input_sha256 = input_sha256, input_bytes = input_bytes,
		surfaces = surfaces, resources = resources, cultural = cultural,
		decorations = decorations,
		r2_layout_body_sha256 =
			"1a819192fa40254aa6da1ebf5f3fa5286790ef907abe09750455e5e24c881a8b",
	}
end
