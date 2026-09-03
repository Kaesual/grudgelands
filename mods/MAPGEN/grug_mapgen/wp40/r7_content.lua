-- Closed R7 production content resolvers. The accepted 77-row R6 evidence
-- namespace remains separate from the 83-row production-R6 namespace and the
-- twelve-row P9G suffix.

return function(core_api, projection, raw_sha256)
	local MAX_SAFE = 9007199254740991
	local PRODUCTION_SCHEMA = "grug_wp40_r7_production_r6_content_v1"
	local P9G_SCHEMA = "grug_wp40_r7_p9g_content_v1"
	local ANCHOR_SCHEMA = "grug_wp40_r7_anchor_content_v1"
	local ACCEPTED_R6_ROWS = {
		{"default:acacia_bush_leaves", 8},
		{"default:acacia_bush_stem", 8},
		{"default:acacia_leaves", 8},
		{"default:acacia_tree", 8},
		{"default:apple", 8},
		{"default:aspen_leaves", 8},
		{"default:aspen_tree", 8},
		{"default:blueberry_bush_leaves_with_berries", 8},
		{"default:bush_leaves", 8},
		{"default:bush_stem", 8},
		{"default:cactus", 8},
		{"default:dirt", 1},
		{"default:dirt_with_coniferous_litter", 1},
		{"default:dirt_with_grass", 1},
		{"default:dirt_with_rainforest_litter", 1},
		{"default:dry_dirt", 1},
		{"default:dry_dirt_with_dry_grass", 1},
		{"default:dry_grass_1", 8},
		{"default:dry_grass_2", 8},
		{"default:dry_grass_3", 8},
		{"default:dry_grass_4", 8},
		{"default:dry_grass_5", 8},
		{"default:dry_shrub", 8},
		{"default:fern_1", 8},
		{"default:fern_2", 8},
		{"default:fern_3", 8},
		{"default:grass_1", 8},
		{"default:grass_2", 8},
		{"default:grass_3", 8},
		{"default:grass_4", 8},
		{"default:grass_5", 8},
		{"default:gravel", 1},
		{"default:junglegrass", 8},
		{"default:jungleleaves", 8},
		{"default:jungletree", 8},
		{"default:leaves", 8},
		{"default:papyrus", 8},
		{"default:pine_bush_needles", 8},
		{"default:pine_bush_stem", 8},
		{"default:pine_needles", 8},
		{"default:pine_tree", 8},
		{"default:sand", 1},
		{"default:snow", 10},
		{"default:snowblock", 1},
		{"default:stone", 1},
		{"default:stone_with_coal", 4},
		{"default:stone_with_copper", 4},
		{"default:stone_with_gold", 4},
		{"default:stone_with_iron", 4},
		{"default:stone_with_tin", 4},
		{"default:tree", 8},
		{"grug_materials:abyssal_crystal_ore", 4},
		{"grug_materials:abyssal_rock", 1},
		{"grug_materials:basalt", 1},
		{"grug_materials:emberrock", 1},
		{"grug_materials:granite", 1},
		{"grug_materials:slate", 1},
		{"grug_materials:stone_with_citrine", 4},
		{"grug_materials:stone_with_diamond", 4},
		{"grug_materials:stone_with_emberglass", 4},
		{"grug_materials:stone_with_garnet", 4},
		{"grug_materials:stone_with_jade", 4},
		{"grug_materials:stone_with_quartz", 4},
		{"grug_materials:stone_with_ruby", 4},
		{"grug_materials:stone_with_sapphire", 4},
		{"grug_materials:stone_with_silver", 4},
		{"grug_nodes:blight_dirt", 1},
		{"grug_nodes:bone_pile", 24},
		{"grug_nodes:dirt_with_bone_litter", 1},
		{"grug_nodes:dirt_with_canopy_litter", 1},
		{"grug_nodes:dirt_with_forest_litter", 1},
		{"grug_nodes:dirt_with_silver_litter", 1},
		{"grug_nodes:mesa_clay", 1},
		{"grug_nodes:mud", 9},
		{"grug_trees:gravewood_tree", 8},
		{"grug_trees:silverwood_leaves", 8},
		{"grug_trees:silverwood_tree", 8},
	}
	local CULTURAL_NAMES = {
		"grug_gathering:gravesalt_source",
		"grug_gathering:moonresin_source",
		"grug_gathering:red_ochre_source",
		"grug_gathering:runeslate_source",
		"grug_gathering:spirit_resin_source",
		"grug_gathering:sunwax_source",
	}
	local P9G_NAMES = {
		"grug_gathering:corn_source",
		"grug_gathering:crimson_lotus_source",
		"grug_gathering:dragonweed_source",
		"grug_gathering:gravemoss_source",
		"grug_gathering:marshbloom_source",
		"grug_gathering:melon_source",
		"grug_gathering:mushroom_source",
		"grug_gathering:potato_source",
		"grug_gathering:rock_salt_source",
		"grug_gathering:stormkelp_source",
		"grug_gathering:sunleaf_source",
		"grug_gathering:wild_cocoa_source",
	}
	local ANCHOR_NAMES = {
		"grug_nodes:camp_fire",
		"grug_nodes:guard_banner",
	}

	local function fail(message)
		error("fail_content_manifest: " .. message, 0)
	end

	local function integer(value, label, minimum, maximum)
		if type(value) ~= "number" or value ~= value or value == math.huge or
				value == -math.huge or value % 1 ~= 0 or math.abs(value) > MAX_SAFE or
				value < minimum or value > maximum then
			fail(label .. " is not an exact bounded integer")
		end
		return value
	end

	local function less_bytes(left, right)
		local count = math.min(#left, #right)
		for index = 1, count do
			local a, b = string.byte(left, index), string.byte(right, index)
			if a ~= b then return a < b end
		end
		return #left < #right
	end

	local function copy_array(values)
		local result = {}
		for index = 1, #values do result[index] = values[index] end
		return result
	end

	local function frame(value)
		local bytes = type(value) == "number" and string.format("%.0f", value) or value
		if type(bytes) ~= "string" then fail("canonical field differs") end
		return tostring(#bytes) .. ":" .. bytes
	end

	local function hex(bytes)
		return (bytes:gsub(".", function(char)
			return string.format("%02x", string.byte(char))
		end))
	end

	if type(core_api) ~= "table" or type(core_api.get_content_id) ~= "function" or
			type(core_api.get_name_from_content_id) ~= "function" or
			type(core_api.registered_nodes) ~= "table" or
			type(raw_sha256) ~= "function" or type(projection) ~= "table" or
			projection.schema ~= "grug_wp43_projection_v1" or
			type(projection.tiers) ~= "table" or type(projection.resources) ~= "table" then
		fail("construction seam differs")
	end

	local rows = {}
	for index = 1, #ACCEPTED_R6_ROWS do
		rows[index] = {ACCEPTED_R6_ROWS[index][1], ACCEPTED_R6_ROWS[index][2]}
	end
	for index = 1, #CULTURAL_NAMES do
		rows[#rows + 1] = {CULTURAL_NAMES[index], 16}
	end
	table.sort(rows, function(left, right) return less_bytes(left[1], right[1]) end)
	if #ACCEPTED_R6_ROWS ~= 77 or #rows ~= 83 or #P9G_NAMES ~= 12 then
		fail("closed population differs")
	end

	local names, cids, masks, ref_by_name = {}, {}, {}, {}
	local surface_set, vegetation_set, resource_set, stratum_set = {}, {}, {}, {}
	for index = 1, #rows do
		local name, mask = rows[index][1], rows[index][2]
		if ref_by_name[name] or (index > 1 and not less_bytes(rows[index - 1][1], name)) then
			fail("production rows are not ASCII unique")
		end
		local def = rawget(core_api.registered_nodes, name)
		if type(def) ~= "table" then fail("unregistered production target " .. name) end
		local cid = core_api.get_content_id(name)
		integer(cid, "production CID", 0, MAX_SAFE)
		names[index], cids[index], masks[index], ref_by_name[name] = name, cid, mask, index
		if math.floor(mask / 1) % 2 == 1 then surface_set[name] = true end
		if math.floor(mask / 4) % 2 == 1 then resource_set[name] = true end
		if math.floor(mask / 8) % 2 == 1 or math.floor(mask / 16) % 2 == 1 then
			vegetation_set[name] = true
		end
	end
	for index = 1, #projection.tiers do stratum_set[projection.tiers[index].node] = true end
	for index = 1, #projection.resources do
		resource_set[projection.resources[index].natural_node] = true
	end
	for index = 1, #P9G_NAMES do vegetation_set[P9G_NAMES[index]] = true end

	local ordinary_source = core_api.get_content_id("default:water_source")
	local river_source = core_api.get_content_id("default:river_water_source")
	local air_cid = core_api.CONTENT_AIR or core_api.get_content_id("air")
	local ignore_cid = core_api.CONTENT_IGNORE or core_api.get_content_id("ignore")
	integer(air_cid, "air CID", 0, MAX_SAFE)
	integer(ignore_cid, "ignore CID", 0, MAX_SAFE)

	local class_by_cid = {}
	local function content_class(name, def)
		if resource_set[name] then return 10 end
		if stratum_set[name] then return 11 end
		if surface_set[name] then return 7 end
		if vegetation_set[name] then return 8 end
		if ((def.groups or {}).grug_natural or 0) == 1 then return 6 end
		return 2
	end
	for name, def in pairs(core_api.registered_nodes) do
		if type(name) == "string" and type(def) == "table" then
			local ok, cid = pcall(core_api.get_content_id, name)
			if ok and type(cid) == "number" then
				local canonical_name = core_api.get_name_from_content_id(cid) or name
				local canonical_def = rawget(core_api.registered_nodes, canonical_name) or def
				local liquidtype = canonical_def.liquidtype or "none"
				local liquid_kind = liquidtype == "source" and 1 or
					(liquidtype == "flowing" and 2 or 0)
				local source_name = canonical_def.liquid_alternative_source
				local family = source_name == "default:water_source" and 1 or
					(source_name == "default:river_water_source" and 2 or
						(liquid_kind ~= 0 and 3 or 0))
				class_by_cid[cid] = {
					liquid_kind ~= 0 and 4 or content_class(canonical_name, canonical_def),
					family, liquid_kind,
					canonical_def.floodable == true,
					canonical_def.paramtype == "light",
					canonical_def.paramtype == "light",
					canonical_def.sunlight_propagates == true,
					integer(canonical_def.light_source or 0, "light source", 0, 15),
					canonical_def.paramtype2 or "none",
				}
			end
		end
	end
	class_by_cid[air_cid] = {1, 0, 0, true, true, true, true, 0, "none"}
	class_by_cid[ignore_cid] = {3, 0, 0, false, false, false, false, 0, "none"}

	local calls = {resolve = 0, classify = 0, metrics = 0, p9g_resolve = 0,
		anchor_resolve = 0}
	local r5 = {schema = "grug_wp40_r5_content_contract_v1",
		ignore_cid = ignore_cid, ordinary_water_family_id = 1,
		river_water_family_id = 2}
	function r5.resolve(role_id, y, aux)
		calls.resolve = calls.resolve + 1
		integer(role_id, "R5 role", 1, 16)
		integer(y, "R5 y", -31000, 31000)
		if aux ~= 0 then fail("R5 aux differs") end
		if role_id == 1 then return air_cid, 0, 0, nil end
		if role_id == 10 then return ordinary_source, 2, 0, nil end
		if role_id == 13 then return river_source, 2, 0, nil end
		local target = "default:stone"
		if role_id == 14 then
			for index = 1, #projection.tiers do
				if y >= projection.tiers[index].y_min then
					target = projection.tiers[index].node
					break
				end
			end
		end
		return core_api.get_content_id(target), 1, 0, nil
	end
	local function classify(cid, param2)
		calls.classify = calls.classify + 1
		integer(cid, "classified CID", 0, MAX_SAFE)
		integer(param2, "classified param2", 0, 255)
		local row = class_by_cid[cid]
		if not row then return 9, 0, 0, 0, false, false, false, false, 0, "none" end
		local level = row[3] == 2 and param2 % 8 or 0
		return row[1], row[2], row[3], level, row[4], row[5], row[6], row[7],
			row[8], row[9]
	end
	local function classify_runtime(cid, param2)
		calls.classify = calls.classify + 1
		integer(cid, "runtime classified CID", 0, MAX_SAFE)
		integer(param2, "runtime classified param2", 0, 255)
		local row = class_by_cid[cid]
		if not row then return 9, 0, 0, 0, false, false, false, false, 0, "none" end
		local level = row[3] == 2 and param2 % 8 or 0
		return row[1], row[2], row[3], level, row[4], row[5], row[6], row[7],
			row[8], row[9]
	end
	function r5.classify(cid, param2)
		local a, b, c, d, e, f, g, h, i = classify(cid, param2)
		return a, b, c, d, e, f, g, h, i
	end
	function r5.metrics()
		calls.metrics = calls.metrics + 1
		return {resolve_calls = calls.resolve, classify_calls = calls.classify,
			query_table_allocations = 0, metrics_result_table_allocations = calls.metrics}
	end

	local production = {schema = PRODUCTION_SCHEMA, r5 = r5,
		ignore_cid = ignore_cid, ordinary_water_family_id = 1,
		river_water_family_id = 2, content_names = names, content_cids = cids,
		content_kind_masks = masks}
	function production.resolve_r6(content_ref, param2)
		integer(content_ref, "production content ref", 1, #names)
		integer(param2, "production param2", 0, 255)
		return cids[content_ref], 1, 1, param2, masks[content_ref]
	end
	function production.classify(cid, param2) return classify(cid, param2) end
	function production.classify_runtime(cid, param2)
		return classify_runtime(cid, param2)
	end
	function production.metrics() return r5.metrics() end

	local p9g_cids = {}
	for index = 1, #P9G_NAMES do
		local name = P9G_NAMES[index]
		if index > 1 and not less_bytes(P9G_NAMES[index - 1], name) then
			fail("P9G names are not ASCII ordered")
		end
		local def = rawget(core_api.registered_nodes, name)
		if type(def) ~= "table" then fail("unregistered P9G target " .. name) end
		local cid = core_api.get_content_id(name)
		local class_id = classify(cid, 0)
		if class_id ~= 8 or cid == ignore_cid then
			fail("P9G target class differs: " .. name)
		end
		p9g_cids[index] = cid
	end
	local p9g = {schema = P9G_SCHEMA, content_names = copy_array(P9G_NAMES),
		content_cids = p9g_cids}
	function p9g.resolve_p9g(content_ref, param2)
		calls.p9g_resolve = calls.p9g_resolve + 1
		integer(content_ref, "P9G content ref", 1, 12)
		if param2 ~= 0 then fail("P9G param2 differs") end
		return p9g_cids[content_ref], 1, 1, 0, 8
	end
	function p9g.content_ref(name)
		for index = 1, #P9G_NAMES do if P9G_NAMES[index] == name then return index end end
		return nil
	end

	local anchor_cids = {}
	for index = 1, #ANCHOR_NAMES do
		local name = ANCHOR_NAMES[index]
		local def = rawget(core_api.registered_nodes, name)
		if type(def) ~= "table" then fail("unregistered anchor target " .. name) end
		local cid = core_api.get_content_id(name)
		local class_id, _, liquid_kind, _, _, _, _, sunlight, light_source, paramtype2 =
			classify(cid, 0)
		local expected_light = index == 1 and 9 or 6
		if class_id ~= 2 or liquid_kind ~= 0 or not sunlight or
				light_source ~= expected_light or paramtype2 ~= "none" or
				cid == ignore_cid or def.walkable ~= false or
				def.is_ground_content ~= false or def.drop ~= "" or
				type(def.groups) ~= "table" or def.groups.grug_camp ~= 1 then
			fail("anchor target semantics differ: " .. name)
		end
		anchor_cids[index] = cid
	end
	local anchors = {schema = ANCHOR_SCHEMA, content_names = copy_array(ANCHOR_NAMES),
		content_cids = anchor_cids}
	function anchors.resolve_anchor(content_ref, param2)
		calls.anchor_resolve = calls.anchor_resolve + 1
		integer(content_ref, "anchor content ref", 1, 2)
		if param2 ~= 0 then fail("anchor param2 differs") end
		return anchor_cids[content_ref], 1, 1, 0, 32
	end
	function anchors.content_ref(name)
		for index = 1, #ANCHOR_NAMES do
			if ANCHOR_NAMES[index] == name then return index end
		end
		return nil
	end

	local function identity(schema, identity_names, identity_cids, identity_masks)
		local parts = {frame(schema), frame(#identity_names)}
		for index = 1, #identity_names do
			parts[#parts + 1] = frame(identity_names[index])
			parts[#parts + 1] = frame(identity_cids[index])
			parts[#parts + 1] = frame(identity_masks and identity_masks[index] or 8)
		end
		local digest = raw_sha256(table.concat(parts))
		if type(digest) ~= "string" or #digest ~= 32 then fail("identity SHA differs") end
		return hex(digest)
	end
	local function semantic_identity(schema, identity_names, identity_cids,
			identity_masks)
		local parts = {frame(schema), frame(#identity_names)}
		for index = 1, #identity_names do
			local classified = class_by_cid[identity_cids[index]]
			if type(classified) ~= "table" or #classified ~= 9 then
				fail("semantic classification differs")
			end
			parts[#parts + 1] = frame(identity_names[index])
			parts[#parts + 1] = frame(identity_masks and identity_masks[index] or 8)
			for field = 1, 9 do
				local value = classified[field]
				if type(value) == "boolean" then value = value and 1 or 0 end
				parts[#parts + 1] = frame(value)
			end
		end
		local digest = raw_sha256(table.concat(parts))
		if type(digest) ~= "string" or #digest ~= 32 then fail("semantic SHA differs") end
		return hex(digest)
	end

	return {
		production = production,
		p9g = p9g,
		anchors = anchors,
		accepted_r6_rows = function()
			local copy = {}
			for index = 1, #ACCEPTED_R6_ROWS do
				copy[index] = {ACCEPTED_R6_ROWS[index][1], ACCEPTED_R6_ROWS[index][2]}
			end
			return copy
		end,
		production_digest = identity(PRODUCTION_SCHEMA, names, cids, masks),
		p9g_digest = identity(P9G_SCHEMA, P9G_NAMES, p9g_cids, nil),
		anchor_digest = identity(ANCHOR_SCHEMA, ANCHOR_NAMES, anchor_cids, nil),
		production_semantic_digest =
			semantic_identity(PRODUCTION_SCHEMA, names, cids, masks),
		p9g_semantic_digest =
			semantic_identity(P9G_SCHEMA, P9G_NAMES, p9g_cids, nil),
		anchor_semantic_digest =
			semantic_identity(ANCHOR_SCHEMA, ANCHOR_NAMES, anchor_cids, nil),
	}
end
