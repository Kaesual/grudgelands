-- Round 23 Phase 2 portable harness (LuaJIT): the real vegetation rule,
-- the real R6 content module (surface selector, decoration cover), the real
-- R6 planner and the real renewal density authority, built without the
-- engine. Terrain and zones come from the real zones.lua planner source
-- (world_source.lua; no roads or capital layouts). The content contract is a
-- synthetic stand-in with the node roles r6_content.lua checks (the engine
-- builds the real one from registered nodes in r7_content.lua).
local H = {}

function H.new(repo)
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local sha = common.new_sha256()
	local habitat = dofile(wp40 .. "/habitat_registry.lua")
	local manifest = dofile(wp40 .. "/r7_r6_manifest.lua")()
	local B = {repo = repo, wp40 = wp40, sha = sha, habitat = habitat,
		manifest = manifest, common = common}

	-- The WP43 projection r6_content.lua validates (as wp43_handoff.lua
	-- projects the registry).
	local function projection()
		local env = setmetatable({grug_materials = {},
			core = {get_modpath = function() return nil end}}, {__index = _G})
		local chunk = assert(loadfile(repo .. "/mods/ITEMS/grug_materials/registry.lua"))
		setfenv(chunk, env)
		chunk()
		local m = env.grug_materials
		local bands = {}
		for i, band in ipairs(m.DENSITY.deep_bands) do
			local num, den = band.multiplier == 1.25 and 5 or 3,
				band.multiplier == 1.25 and 4 or 2
			bands[i] = {y_max = band.y_max, y_min = band.y_min,
				multiplier_numerator = num, multiplier_denominator = den}
		end
		return {schema = "grug_wp43_projection_v1", tiers = m.TIERS,
			resources = m.RESOURCES, race_regions = {},
			density = {gem = m.DENSITY.gem,
				abyssal_crystal = m.DENSITY.abyssal_crystal, deep_bands = bands}}
	end
	B.projection = projection()

	-- Synthetic content contract: every node the content module names, with
	-- the role bits and classes it checks (surface 7, dust 8, resource 10,
	-- decoration 8).
	function B.contract(extra_surface_names)
		local masks = {}
		local function role(name, bit_value)
			if name == "-" or name == "air" or name == nil then return end
			masks[name] = (masks[name] or 0) +
				(math.floor((masks[name] or 0) / bit_value) % 2 == 0 and bit_value or 0)
		end
		local surface_set, dust_set, resource_set, deco_set = {}, {}, {}, {}
		local function surface(name) role(name, 1) surface_set[name] = true end
		for _, row in ipairs(manifest.surfaces) do
			surface(row.top) surface(row.filler) surface(row.shore) surface(row.bed)
			if row.dust ~= "-" then role(row.dust, 2) dust_set[row.dust] = true end
		end
		for _, name in ipairs({"default:dirt_with_grass", "default:dirt",
				"grug_nodes:dirt_with_forest_litter", "default:dirt_with_coniferous_litter",
				"grug_nodes:dirt_with_silver_litter", "grug_nodes:dirt_with_moss",
				"default:dirt_with_rainforest_litter", "grug_nodes:dirt_with_canopy_litter",
				"grug_nodes:mud", "default:dry_dirt_with_dry_grass", "default:dry_dirt",
				"grug_nodes:mesa_clay", "grug_nodes:blight_dirt", "grug_nodes:ash_ground",
				"grug_nodes:dirt_with_bone_litter", "default:gravel", "default:stone",
				"default:sand", "default:sandstone", "default:snowblock"}) do
			surface(name)
		end
		for _, name in ipairs(extra_surface_names or {}) do surface(name) end
		for _, tier in ipairs(B.projection.tiers) do surface(tier.node) end
		role("default:snow", 2) dust_set["default:snow"] = true
		for _, row in ipairs(B.projection.resources) do
			role(row.natural_node, 4) resource_set[row.natural_node] = true
		end
		for _, row in ipairs(manifest.decorations) do
			if row.kind == "simple" then
				role(row.asset_or_node, 8) deco_set[row.asset_or_node] = true
			end
		end
		local names = {}
		for name in pairs(masks) do names[#names + 1] = name end
		table.sort(names, common.less_bytes)
		local cids, kind_masks, class_by_cid = {}, {}, {}
		for index, name in ipairs(names) do
			local cid = 1000 + index
			cids[index], kind_masks[index] = cid, masks[name]
			class_by_cid[cid] = resource_set[name] and 10 or
				((dust_set[name] or deco_set[name]) and not surface_set[name]) and 8 or 7
		end
		class_by_cid[0], class_by_cid[10], class_by_cid[11], class_by_cid[65535] = 1, 4, 4, 3
		local function classify(cid)
			local class = class_by_cid[cid] or 9
			if class == 4 then
				return 4, cid == 10 and 1 or 2, 1, 0, false, true, true, true, 0, "none"
			end
			return class, 0, 0, 0, class == 1 or class == 8, class == 1,
				class == 1, class == 1, 0, "none"
		end
		local r5 = {schema = "grug_wp40_r5_content_contract_v1", ignore_cid = 65535,
			ordinary_water_family_id = 1, river_water_family_id = 2}
		function r5.resolve(role_id)
			if role_id == 1 then return 0, 0, 0, nil end
			if role_id == 10 then return 10, 2, 0, nil end
			if role_id == 13 then return 11, 2, 0, nil end
			return 1001, 1, 0, nil
		end
		function r5.classify(cid, param2)
			local a, b, c, d, e, f, g, h, i = classify(cid, param2)
			return a, b, c, d, e, f, g, h, i
		end
		function r5.metrics() return {} end
		local contract = {schema = "grug_wp40_r6_content_contract_v1", r5 = r5,
			ignore_cid = 65535, ordinary_water_family_id = 1, river_water_family_id = 2,
			content_names = names, content_cids = cids, content_kind_masks = kind_masks}
		function contract.resolve_r6(ref, param2)
			return cids[ref], 1, 1, param2, kind_masks[ref]
		end
		function contract.classify(cid, param2) return classify(cid, param2) end
		function contract.metrics() return {} end
		return contract
	end

	-- The real content module over a contract; `habitat_module` defaults to
	-- the shipped habitat_registry.
	function B.content(extra_surface_names, habitat_module)
		local factory = dofile(wp40 .. "/r6_content.lua")
		return factory(manifest, B.contract(extra_surface_names), B.projection,
			habitat_module or habitat)
	end

	-- Template footprints from the MTS headers (the planner's halo only).
	function B.templates()
		local mx, my, mz = 1, 1, 1
		for _, row in ipairs(manifest.decorations) do
			if row.kind == "template" then
				local dir = row.asset_or_node:match("^grug_gravewood_") and
					"/mods/ITEMS/grug_trees/schematics/" or "/mods/BASE/default/schematics/"
				local bytes = common.read_file(repo .. dir .. row.asset_or_node)
				local function u16(o) local a, b = bytes:byte(o, o + 1) return a * 256 + b end
				assert(bytes:sub(1, 4) == "MTSM")
				local sx, sy, sz = u16(7), u16(9), u16(11)
				mx, mz = math.max(mx, sx, sz), math.max(mz, sx, sz)
				my = math.max(my, sy)
			end
		end
		return {maximum_footprint = function() return mx, my, mz end}
	end

	-- The real R6 planner over a planner source; the R5 planner is a stub
	-- (the decoration rows do not read its plan).
	function B.planner(full_seed, planner_source, content, source)
		local identity = {}
		local allocator_factory = dofile(wp40 .. "/counting_allocator.lua")
		local planner_module = dofile(wp40 .. "/r6_planner.lua")
		return planner_module.new({
			full_seed_string = full_seed, planner_source = planner_source,
			r5_planner = {plan_slice = function()
				return {construction_identity = identity}, 1
			end},
			horizontal = planner_source, content = content, templates = B.templates(),
			hash = dofile(wp40 .. "/r6_hash.lua")(sha), source = source or {zones = {}},
			construction_identity = {value = false},
			counting_allocator = allocator_factory.new("grug_wp40_r6_planner_allocator_v1"),
		})
	end

	-- The real renewal density authority over a column source.
	function B.density(rule, content, column_values_at, extra)
		extra = extra or {}
		local support_names = content.content_contract().content_names
		local records = {}
		for _, row in ipairs(manifest.decorations) do
			if row.kind == "template" then
				records[#records + 1] = {definition_id = row.id, rotations = {{
					size_x = 1, size_y = 1, size_z = 1,
					cells = {{name = "default:tree", probability = 254}}}}}
			end
		end
		-- every marker node a woody row may count, one column each
		local markers = {"default:acacia_bush_stem", "default:acacia_tree",
			"default:aspen_tree", "default:blueberry_bush_leaves",
			"default:blueberry_bush_leaves_with_berries", "default:bush_stem",
			"default:jungletree", "default:pine_bush_stem", "default:pine_tree",
			"default:tree", "grug_trees:gravewood_tree", "grug_trees:silverwood_tree"}
		for _, record in ipairs(records) do
			local cells = {}
			for i, name in ipairs(markers) do cells[i] = {name = name, probability = 254} end
			record.rotations[1].size_y, record.rotations[1].cells = #cells, cells
		end
		return dofile(wp40 .. "/vegetation_density.lua")({
			habitat = habitat, vegetation_rule = rule, world_plants = {}, p9g_rows = {},
			decorations = manifest.decorations,
			decoration_cover = function(id, biome, support_name)
				local ref = content.content_ref(support_name)
				return ref and content.decoration_cover(id, biome, ref) or 0
			end,
			support_names = support_names, template_records = records,
			column_values_at = column_values_at,
			overlay_exclusion_at = extra.overlay_exclusion_at or function() return nil end,
			surface_mob_level_at = function() return 5 end,
			primary_relief_at = extra.primary_relief_at or function() return "hills" end,
			static_exclusion_values_at = function() return nil end,
			surface_cave_run_at = function() return nil end,
		})
	end
	return B
end

return H
