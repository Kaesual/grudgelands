-- Exact repository-derived WP40 R6 construction fixtures.

return function(repo, common, raw_sha256)
	local fixtures = {}
	local INPUTS = {
		"AGENTS.md", "docs/design/biomes_mobs.md", "docs/design/items_crafting.md",
		"docs/design/world.md", "docs/design/world_zones.md",
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
		"mods/ITEMS/grug_materials/registry.lua", "mods/ITEMS/grug_nodes/init.lua",
		"mods/ITEMS/grug_trees/init.lua", "mods/MAPGEN/grug_mapgen/wp43_handoff.lua",
		"reference_projects/luanti/doc/lua_api.md",
		"reference_projects/luanti/src/mapgen/mg_schematic.cpp",
		"reference_projects/luanti/src/mapgen/mg_schematic.h",
		"reference_projects/luanti/src/mapnode.cpp",
		"reference_projects/luanti/src/script/lua_api/l_mapgen.cpp",
	}
	local RUNTIME_INPUTS = {
		"mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua",
		"mods/MAPGEN/grug_mapgen/wp40/schemas.lua",
		"mods/MAPGEN/grug_mapgen/wp40/canonical.lua",
		"mods/MAPGEN/grug_mapgen/wp40/deterministic.lua",
		"mods/MAPGEN/grug_mapgen/wp40/index128.lua",
		"mods/MAPGEN/grug_mapgen/wp40/simple_map.lua",
		"mods/MAPGEN/grug_mapgen/wp40/height.lua",
		"mods/MAPGEN/grug_mapgen/wp40/zones.lua",
		"mods/MAPGEN/grug_mapgen/wp40/planner.lua",
		"mods/MAPGEN/grug_mapgen/wp40/map_adapter.lua",
		"mods/MAPGEN/grug_mapgen/wp40/mapgen_manifest.lua",
		"mods/MAPGEN/grug_mapgen/wp40/counting_allocator.lua",
		"mods/MAPGEN/grug_mapgen/wp40/r5.lua",
		"mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua",
		"mods/MAPGEN/grug_mapgen/wp40/r6.lua",
		"mods/MAPGEN/grug_mapgen/wp40/r6_content.lua",
		"mods/MAPGEN/grug_mapgen/wp40/r6_hash.lua",
		"mods/MAPGEN/grug_mapgen/wp40/r6_planner.lua",
		"mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua",
		"mods/MAPGEN/grug_mapgen/wp40/r6_templates.lua",
		"tools/wp40/simple_map_r5_common.lua",
		"tools/wp40/simple_map_r5_vm.lua",
		"tools/wp40/r6/artifact_codec.lua",
		"tools/wp40/r6/artifact_combiner.lua",
		"tools/wp40/r6/census_roster.lua",
		"tools/wp40/r6/cli.lua",
		"tools/wp40/r6/common.lua",
		"tools/wp40/r6/evidence.lua",
		"tools/wp40/r6/finalizer.lua",
		"tools/wp40/r6/fixtures.lua",
		"tools/wp40/r6/micro_kat.lua",
		"tools/wp40/r6/micro_kat_fixture.lua",
		"tools/wp40/r6/offline.lua",
		"tools/wp40/r6/production_kat.lua",
		"tools/wp40/r6/sha256_stream.lua",
		"tools/wp40/r6/worker.lua",
		"tools/wp40/r6/run.sh",
		"tools/wp40/run_simple_map_r6.sh",
		"docs/research/wp40-simple-map-r2-artifact.tsv",
		"docs/research/wp40-simple-map-r3-artifact.tsv",
		"docs/research/wp40-simple-map-r4-artifact.tsv",
		"docs/research/wp40-simple-map-r5-artifact.tsv",
	}

	local function split(value)
		local result = {}
		for item in (value .. ";"):gmatch("([^;]+);") do result[#result + 1] = item end
		return result
	end

	local function denominator(value)
		if value == "-" then return false end
		return assert(tonumber(value))
	end

	local function ratio(value)
		local a, b = value:match("^(%d+)/(%d+)$")
		return assert(tonumber(a)), assert(tonumber(b))
	end

	local function load_projection()
		local environment = setmetatable({grug_materials = {},
			core = {get_modpath = function() return nil end}}, {__index = _G})
		local chunk = assert(loadfile(repo .. "/mods/ITEMS/grug_materials/registry.lua"))
		setfenv(chunk, environment)
		chunk()
		local materials = environment.grug_materials
		local function clone(value)
			if type(value) ~= "table" then return value end
			local result = {}
			for key, child in pairs(value) do result[clone(key)] = clone(child) end
			return result
		end
		local race_regions, keys = {}, {}
		for key in pairs(materials.RACE_REGIONS) do keys[#keys + 1] = key end
		table.sort(keys, common.less_bytes)
		for index = 1, #keys do
			local row = clone(materials.RACE_REGIONS[keys[index]])
			row._projection_key = keys[index]
			race_regions[index] = row
		end
		return {schema = "grug_wp43_projection_v1",
			tiers = clone(materials.TIERS), resources = clone(materials.RESOURCES),
			race_regions = race_regions,
			density = {g1 = clone(materials.DENSITY.g1),
				g2 = clone(materials.DENSITY.g2),
				abyssal_crystal = clone(materials.DENSITY.abyssal_crystal),
				deep_bands = {
					{y_max = materials.DENSITY.deep_bands[1].y_max,
						y_min = materials.DENSITY.deep_bands[1].y_min,
						multiplier_numerator = 5, multiplier_denominator = 4},
					{y_max = materials.DENSITY.deep_bands[2].y_max,
						y_min = materials.DENSITY.deep_bands[2].y_min,
						multiplier_numerator = 3, multiplier_denominator = 2},
				},
			},
		}
	end
	local projection = load_projection()

	local surfaces = {}
	do
		local rows = common.tsv(repo ..
			"/docs/research/wp40-simple-map-r6-surface-content.tsv")
		for index = 1, #rows do
			local row = rows[index]
			surfaces[#surfaces + 1] = {id = row.logical_biome_id,
				top = row.top_node, filler = row.filler_node,
				filler_depth = assert(tonumber(row.filler_depth)),
				shore = row.shore_node, bed = row.bed_node, dust = row.dust_node}
		end
		table.sort(surfaces, function(a, b) return common.less_bytes(a.id, b.id) end)
	end

	local resources = {}
	do
		local rows = common.tsv(repo ..
			"/docs/research/wp40-simple-map-r6-resource-density.tsv")
		for index = 1, #rows do
			local row = rows[index]
			local a1, b1 = ratio(row.deep_1500_1999_multiplier)
			local a2, b2 = ratio(row.deep_2000_floor_multiplier)
			resources[#resources + 1] = {key = row.resource_key, scope = row.scope,
				first_tier = assert(tonumber(row.first_tier)),
				denominators = {
					denominator(row.t1_host_nodes_per_ore),
					denominator(row.t2_host_nodes_per_ore),
					denominator(row.t3_host_nodes_per_ore),
					denominator(row.t4_host_nodes_per_ore),
					denominator(row.t5_host_nodes_per_ore),
					denominator(row.t6_ordinary_host_nodes_per_ore),
				},
				max_nodes_per_vein = assert(tonumber(row.max_nodes_per_vein)),
				deep_1500_1999_numerator = a1, deep_1500_1999_denominator = b1,
				deep_2000_floor_numerator = a2, deep_2000_floor_denominator = b2,
			}
		end
		table.sort(resources, function(a, b) return common.less_bytes(a.key, b.key) end)
	end

	local cultural = {}
	do
		local rows = common.tsv(repo ..
			"/docs/research/wp40-simple-map-r6-cultural-opportunities.tsv")
		for index = 1, #rows do
			local row = rows[index]
			cultural[#cultural + 1] = {race = row.race_region,
				key = row.cultural_key,
				ordinary_denominator = assert(tonumber(row.ordinary_surface_denominator)),
				concentrated_denominator = assert(tonumber(row.t4_contested_denominator)),
				biomes = split(row.allowed_logical_biomes),
				concentrated_zone = row.recommended_t4_zone_id}
		end
		table.sort(cultural, function(a, b) return common.less_bytes(a.key, b.key) end)
	end

	local mts_cache = {}
	local function read_template(filename)
		if not mts_cache[filename] then
			mts_cache[filename] = common.read_mts(repo ..
				"/mods/BASE/default/schematics/" .. filename)
		end
		return mts_cache[filename]
	end

	local decorations = {}
	do
		local rows = common.tsv(repo ..
			"/docs/research/wp40-simple-map-r6-decoration-draft.tsv")
		for index = 1, #rows do
			local source = rows[index]
			local first, last = source.decoration_id:match("^(.-)_1%.%.(%d+)$")
			local count = last and tonumber(last) or 1
			for variant = 1, count do
				local id = first and first .. "_" .. variant or source.decoration_id
				local node = source.asset_or_node
				if first then node = node:gsub("1%.%.%d+$", tostring(variant)) end
				local class
				if source.kind == "simple" then
					class = source.extra_rule == "height_2_to_4_from_domain_hash" and 3 or 4
				else
					local schematic = read_template(node)
					local large = schematic.size.x > 5 or schematic.size.z > 5
					class = (large or id == "emergent_jungle_tree" or
						id == "deep_forest_apple_log" or id == "badlands_large_cactus" or
						id == "swamp_papyrus") and 1 or 2
				end
				decorations[#decorations + 1] = {id = id,
					biomes = split(source.logical_biomes), kind = source.kind,
					asset_or_node = node, host = source.host_node,
					numerator = assert(tonumber(source.fill_numerator)),
					denominator = assert(tonumber(source.fill_denominator)),
					rule = source.extra_rule, settlement_class = class}
			end
		end
		table.sort(decorations, function(a, b) return common.less_bytes(a.id, b.id) end)
	end

	local input_sha256, input_bytes = {}, {}
	for index = 1, #INPUTS do
		local path = INPUTS[index]
		local bytes = common.read_file(repo .. "/" .. path)
		input_sha256[path] = common.hex(raw_sha256(bytes))
		input_bytes[path] = #bytes
	end
	if input_sha256["docs/research/wp40-simple-map-r6-contract.md"] ~=
			"814fbb7915c6c1590f65ec4d6c34b165543528a76c14db5f570cc8e9710a954f" then
		common.fail("reviewed R6 contract digest differs")
	end

	function fixtures.r5_manifest()
		return {
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
		}
	end

	function fixtures.r6_manifest()
		return {
			schema = "grug_wp40_r6_manifest_values_v1",
			contract_sha256 =
				"814fbb7915c6c1590f65ec4d6c34b165543528a76c14db5f570cc8e9710a954f",
			r5_manifest_values = fixtures.r5_manifest(),
			input_sha256 = input_sha256, input_bytes = input_bytes,
			surfaces = surfaces, resources = resources, cultural = cultural,
			decorations = decorations,
			r2_layout_body_sha256 =
				"1a819192fa40254aa6da1ebf5f3fa5286790ef907abe09750455e5e24c881a8b",
		}
	end

	function fixtures.template_source()
		local source = {}
		function source.read(filename) return read_template(filename) end
		return source
	end

	function fixtures.projection() return projection end

	function fixtures.new_content_contract()
		local PARAM2_KIND_BY_NAME = {
			["default:dry_shrub"] = "meshoptions",
			["default:tree"] = "facedir",
			["default:jungletree"] = "facedir",
			["default:pine_tree"] = "facedir",
			["default:acacia_tree"] = "facedir",
			["default:aspen_tree"] = "facedir",
			["default:cactus"] = "facedir",
			["grug_trees:silverwood_tree"] = "facedir",
		}
		local names, masks = {}, {}
		local function role(name, bit)
			if name == "-" or name == "air" then return end
			masks[name] = (masks[name] or 0) +
				(math.floor((masks[name] or 0) / bit) % 2 == 0 and bit or 0)
		end
		for index = 1, #surfaces do
			local row = surfaces[index]
			role(row.top, 1) role(row.filler, 1) role(row.shore, 1) role(row.bed, 1)
			role(row.dust, 2)
		end
		for index = 1, #projection.resources do role(projection.resources[index].natural_node, 4) end
		for index = 1, #decorations do
			local row = decorations[index]
			if row.kind == "simple" then role(row.asset_or_node, 8) else
				local schematic = read_template(row.asset_or_node)
				for cell = 1, #schematic.data do
					local name = schematic.data[cell].name
					if row.id == "elf_forest_silverwood" then
						if name == "default:aspen_tree" then name = "grug_trees:silverwood_tree"
						elseif name == "default:aspen_leaves" then name = "grug_trees:silverwood_leaves" end
					elseif row.id == "swamp_papyrus" and name == "default:dirt" then
						name = "grug_nodes:mud"
					elseif row.id == "deep_forest_apple_log" and
							name == "flowers:mushroom_brown" then name = "air" end
					role(name, 8)
				end
			end
		end
		for index = 1, #projection.tiers do role(projection.tiers[index].node, 1) end
		-- Synthetic WP33 fixture registrations reuse one reviewed solid node.
		role("grug_nodes:bone_pile", 16)
		for name in pairs(masks) do names[#names + 1] = name end
		table.sort(names, common.less_bytes)
		local cids, kind_masks, ref_by_name, class_by_cid, param2_kind_by_cid =
			{}, {}, {}, {}, {}
		local cid_by_name = {air = 0, ["default:water_source"] = 10,
			["default:river_water_source"] = 11}
		local next_cid = 1000
		local resource_set, stratum_set, vegetation_set, surface_set = {}, {}, {}, {}
		for index = 1, #projection.resources do resource_set[projection.resources[index].natural_node] = true end
		for index = 1, #projection.tiers do stratum_set[projection.tiers[index].node] = true end
		for index = 1, #surfaces do
			local row = surfaces[index]
			surface_set[row.top], surface_set[row.filler] = true, true
			surface_set[row.shore], surface_set[row.bed] = true, true
			if row.dust ~= "-" then vegetation_set[row.dust] = true end
		end
		for index = 1, #decorations do
			if decorations[index].kind == "simple" then
				vegetation_set[decorations[index].asset_or_node] = true
			end
		end
		for index = 1, #names do
			local name = names[index]
			if not cid_by_name[name] then cid_by_name[name], next_cid = next_cid, next_cid + 1 end
			local cid = cid_by_name[name]
			cids[index], kind_masks[index], ref_by_name[name] = cid, masks[name], index
			param2_kind_by_cid[cid] = PARAM2_KIND_BY_NAME[name] or "none"
			local class = resource_set[name] and 10 or stratum_set[name] and 11 or
				vegetation_set[name] and 8 or surface_set[name] and 7 or 8
			class_by_cid[cid] = class
		end
		class_by_cid[0], class_by_cid[10], class_by_cid[11], class_by_cid[65535] = 1, 4, 4, 3
		local calls = {resolve = 0, classify = 0, metrics = 0}
		local function classify(cid, param2)
			calls.classify = calls.classify + 1
			local class = class_by_cid[cid] or 9
			if class == 4 then
				return 4, cid == 10 and 1 or 2, 1, 0, false, true, true, true, 0,
					param2_kind_by_cid[cid] or "none"
			end
			return class, 0, 0, 0, class == 1 or class == 8, class == 1,
				class == 1, class == 1, 0, param2_kind_by_cid[cid] or "none"
		end
		local r5 = {schema = "grug_wp40_r5_content_contract_v1",
			ignore_cid = 65535, ordinary_water_family_id = 1,
			river_water_family_id = 2}
		function r5.resolve(role_id, y, aux)
			calls.resolve = calls.resolve + 1
			if aux ~= 0 then common.fail("R5 fixture aux differs") end
			if role_id == 1 then return 0, 0, 0, nil end
			if role_id == 10 then return 10, 2, 0, nil end
			if role_id == 13 then return 11, 2, 0, nil end
			local target = "default:stone"
			if role_id == 14 then
				for index = 1, #projection.tiers do
					if y >= projection.tiers[index].y_min then target = projection.tiers[index].node break end
				end
			end
			return assert(cid_by_name[target]), 1, 0, nil
		end
		function r5.classify(cid, param2)
			local class, family, liquid, level, floodable, paramtype_light,
				light_propagates, sunlight_propagates, light_source = classify(cid, param2)
			return class, family, liquid, level, floodable, paramtype_light,
				light_propagates, sunlight_propagates, light_source
		end
		function r5.metrics()
			calls.metrics = calls.metrics + 1
			return {resolve_calls = calls.resolve, classify_calls = calls.classify,
				query_table_allocations = 0, metrics_result_table_allocations = calls.metrics}
		end
		local contract = {schema = "grug_wp40_r6_content_contract_v1", r5 = r5,
			ignore_cid = 65535, ordinary_water_family_id = 1,
			river_water_family_id = 2, content_names = names, content_cids = cids,
			content_kind_masks = kind_masks}
		function contract.resolve_r6(content_ref, param2)
			return cids[content_ref], 1, 1, param2, kind_masks[content_ref]
		end
		function contract.classify(cid, param2) return classify(cid, param2) end
		function contract.metrics() return r5.metrics() end
		return contract, cid_by_name, ref_by_name
	end

	function fixtures.context(heightmap)
		local context = {schema = "grug_wp40_r5_mapgen_context_v1"}
		function context.get_heightmap() return heightmap end
		function context.metrics()
			return {heightmap_fetch_calls = 0, heightmap_external_table_allocations = 0,
				metrics_result_table_allocations = 0}
		end
		return context
	end

	function fixtures.cultural_records(r6_module)
		local api = r6_module.cultural_slot_api()
		local records = {}
		for index, key in ipairs(api.required_keys()) do
			local definition = {id = "fixture_" .. key,
				template_or_simple_kind = "simple",
				immutable_content = {cells = {{x = 0, y = 1, z = 0,
					node = "grug_nodes:bone_pile", param2 = 0, force_place = false}}},
				footprint_min_x = 0, footprint_max_x = 0,
				footprint_min_y = 1, footprint_max_y = 1,
				footprint_min_z = 0, footprint_max_z = 0,
				lower_two_policy = "preserve_p7"}
			records[index] = api.validate(key, definition)
		end
		return records
	end

	fixtures.surfaces, fixtures.resources = surfaces, resources
	fixtures.cultural, fixtures.decorations = cultural, decorations
	fixtures.inputs, fixtures.input_sha256, fixtures.input_bytes =
		INPUTS, input_sha256, input_bytes
	local receipt_files, receipt_seen = {}, {}
	for _, population in ipairs({INPUTS, RUNTIME_INPUTS}) do
		for index = 1, #population do
			local path = population[index]
			if receipt_seen[path] then
				common.fail("duplicate static-receipt input " .. path)
			end
			receipt_seen[path] = true
			receipt_files[#receipt_files + 1] = path
		end
	end
	table.sort(receipt_files, common.less_bytes)
	fixtures.static_receipt_files = receipt_files
	return fixtures
end
