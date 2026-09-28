-- Read-only natural vegetation density (Round 23, habitat-driven renewal).
--
-- Answers, for one live position, which natural plants the world generator
-- grows there and how densely, from the data the writers themselves use:
--   * resource plants -- the world content rows (world_content.lua) and the
--     P9G gathering rows (r7_p9g.lua) with their zone, biome, support, level
--     or depth and shore predicates; density 1 / habitat.initial_denominator
--     per eligible column (cave rows: per eligible cave-floor node);
--   * ground cover (grass, ferns, junglegrass, dry shrubs) and woody plants
--     (trees and bushes) -- the R6 decoration rows (r7_r6_manifest.lua),
--     numerator / denominator thinned by the planner's per-support decoration
--     cover factor (r6_content.lua `decoration_cover`) and their site rules.
-- Density is expected plants per eligible support; the caller counts the
-- eligible supports and the present plants around the site.
--
-- Pure: reads no engine global. The only dynamic rule is
-- `habitat.vegetation_factor`, applied to every cover and woody density: the
-- Phase 2 tree line and forest noise land there and reach renewal unchanged.
return function(deps)
	local function fail(message)
		error("vegetation density: " .. message, 0)
	end
	for _, field in ipairs({"habitat", "world_plants", "p9g_rows", "decorations",
			"template_records", "support_names"}) do
		if type(deps[field]) ~= "table" then fail("missing " .. field) end
	end
	for _, field in ipairs({"decoration_cover", "column_values_at",
			"overlay_exclusion_at", "surface_mob_level_at", "primary_relief_at",
			"static_exclusion_values_at", "surface_cave_run_at"}) do
		if type(deps[field]) ~= "function" then fail("missing " .. field) end
	end
	local habitat = deps.habitat
	local column_values_at = deps.column_values_at

	local M = {}
	-- Natural light (at noon) a surface plant needs. Forest floors under a
	-- canopy keep their undergrowth; a sapling needs what default.can_grow
	-- asks of it (light 13).
	M.SURFACE_MIN_LIGHT = 10
	M.WOODY_MIN_LIGHT = 13

	-- The sapling the vendored growth code turns into each natural woody
	-- decoration, and the node that marks one grown plant (its trunk or stem;
	-- the stemless blueberry bush by its leaves). Every template row is in
	-- exactly one of the two tables.
	local APPLE = {sapling = "default:sapling", markers = {"default:tree"}}
	local JUNGLE = {sapling = "default:junglesapling", markers = {"default:jungletree"}}
	local PINE = {sapling = "default:pine_sapling", markers = {"default:pine_tree"}}
	local GRAVEWOOD = {sapling = "grug_trees:gravewood_sapling",
		markers = {"grug_trees:gravewood_tree"}}
	local WOODY = {
		meadows_apple_tree = APPLE,
		deep_forest_apple_tree = APPLE,
		elf_forest_apple_tree = APPLE,
		deep_forest_aspen_tree = {sapling = "default:aspen_sapling",
			markers = {"default:aspen_tree"}},
		elf_forest_silverwood = {sapling = "grug_trees:silverwood_sapling",
			markers = {"grug_trees:silverwood_tree"}},
		jungle_tree = JUNGLE,
		jungle_edge_jungle_tree = JUNGLE,
		emergent_jungle_tree = {sapling = "default:emergent_jungle_sapling",
			markers = {"default:jungletree"}},
		pine_hills_pine_tree = PINE,
		pine_hills_small_pine_tree = PINE,
		savanna_acacia_tree = {sapling = "default:acacia_sapling",
			markers = {"default:acacia_tree"}},
		blight_gravewood = GRAVEWOOD,
		bone_forest_gravewood = GRAVEWOOD,
		meadows_bush = {sapling = "default:bush_sapling",
			markers = {"default:bush_stem"}},
		pine_hills_pine_bush = {sapling = "default:pine_bush_sapling",
			markers = {"default:pine_bush_stem"}},
		savanna_acacia_bush = {sapling = "default:acacia_bush_sapling",
			markers = {"default:acacia_bush_stem"}},
		pine_hills_blueberry_bush = {sapling = "default:blueberry_bush_sapling",
			markers = {"default:blueberry_bush_leaves",
				"default:blueberry_bush_leaves_with_berries"}},
	}
	-- Natural decorations with no working renewal path.
	local NOT_RENEWED = {
		-- default.can_grow needs group:soil below; the crags pine roots in gravel.
		crags_snowy_pine = "pine sapling cannot grow on gravel",
		deep_forest_apple_log = "fallen log, not a growing plant",
		-- The large-cactus seedling needs group:sand; badlands are mesa clay.
		badlands_large_cactus = "cactus seedling cannot grow on mesa clay",
		swamp_papyrus = "reed stand, not a sapling species",
	}
	-- Simple decorations that are not vegetation.
	local NOT_VEGETATION = {["grug_nodes:bone_pile"] = true}

	local function sorted_keys(set)
		local result = {}
		for key in pairs(set) do result[#result + 1] = key end
		table.sort(result)
		return result
	end

	-- Site rules of the decoration rows (r6_planner.lua `decoration_height_rule`).
	local function site_rule(row)
		if row.rule:find("surface_y_at_least_60", 1, true) then return 1 end
		if row.rule:find("surface_y_at_most_32", 1, true) then return 2 end
		if row.rule:find("surface_y_1_to_4", 1, true) then return 3 end
		return 0
	end

	-- Distinct columns holding a marker node in the row's own template: how
	-- many marker columns one grown plant contributes to a trunk count.
	local records = {}
	for index = 1, #deps.template_records do
		local record = deps.template_records[index]
		records[record.definition_id] = record
	end
	local function marker_columns(row, markers)
		local record = records[row.id]
		local rotation = record and record.rotations and record.rotations[1]
		if not rotation then fail("template record missing: " .. row.id) end
		local wanted = {}
		for index = 1, #markers do wanted[markers[index]] = true end
		local columns, count = {}, 0
		local sx, sy, sz = rotation.size_x, rotation.size_y, rotation.size_z
		for z = 1, sz do
			for y = 1, sy do
				for x = 1, sx do
					local cell = rotation.cells[(z - 1) * sx * sy + (y - 1) * sx + x]
					if cell and wanted[cell.name] and cell.probability > 0 then
						local key = x .. "," .. z
						if not columns[key] then columns[key], count = true, count + 1 end
					end
				end
			end
		end
		if count == 0 then fail("template has no marker column: " .. row.id) end
		return count
	end

	-- Decoration palettes per logical biome and support node.
	local cover_names, woody_markers, natural = {}, {}, {}
	local cover, woody = {}, {}
	local function palette(target, biome)
		local value = target[biome]
		if not value then
			value = {by_support = {}, hosts = {}}
			target[biome] = value
		end
		return value
	end
	for index = 1, #deps.decorations do
		local row = deps.decorations[index]
		local weight = row.numerator / row.denominator
		local class, entry
		if row.kind == "simple" then
			natural[row.asset_or_node] = true
			if not NOT_VEGETATION[row.asset_or_node] then
				class = cover
				cover_names[row.asset_or_node] = true
				entry = {id = row.id, node = row.asset_or_node,
					param2 = row.rule:find("param2_4", 1, true) and 4 or 0,
					rule = site_rule(row)}
			end
		elseif WOODY[row.id] then
			local species = WOODY[row.id]
			class = woody
			for m = 1, #species.markers do woody_markers[species.markers[m]] = true end
			-- A planted sapling is a plant already: it counts until it grows.
			woody_markers[species.sapling] = true
			natural[species.sapling] = true
			entry = {id = row.id, node = species.sapling, param2 = 0,
				rule = site_rule(row), markers = species.markers,
				columns = marker_columns(row, species.markers)}
		elseif not NOT_RENEWED[row.id] then
			fail("decoration row has no renewal decision: " .. row.id)
		end
		if class then
			for b = 1, #row.biomes do
				local biome = row.biomes[b]
				local target = palette(class, biome)
				for s = 1, #deps.support_names do
					local support = deps.support_names[s]
					local factor = deps.decoration_cover(row.id, biome, support)
					if factor > 0 then
						local list = target.by_support[support] or {}
						target.by_support[support] = list
						target.hosts[support] = true
						list[#list + 1] = {id = entry.id, node = entry.node,
							param2 = entry.param2, rule = entry.rule,
							markers = entry.markers, columns = entry.columns,
							weight = weight / factor}
					end
				end
			end
		end
	end
	for _, target in pairs(cover) do target.host_list = sorted_keys(target.hosts) end
	for _, target in pairs(woody) do target.host_list = sorted_keys(target.hosts) end
	-- World-wide density-weighted marker columns per plant: counts trees of a
	-- neighbouring biome's species that stand inside a counting box.
	local global_divisor = {}
	do
		local weight, columns = {}, {}
		for index = 1, #deps.decorations do
			local row = deps.decorations[index]
			local species = WOODY[row.id]
			if species then
				local w = row.numerator / row.denominator * #row.biomes
				local count = marker_columns(row, species.markers)
				for m = 1, #species.markers do
					local marker = species.markers[m]
					weight[marker] = (weight[marker] or 0) + w
					columns[marker] = (columns[marker] or 0) + w * count
				end
			end
		end
		for marker, value in pairs(weight) do
			global_divisor[marker] = columns[marker] / value
		end
		for _, species in pairs(WOODY) do global_divisor[species.sapling] = 1 end
	end
	-- Template cells are the rest of what the decorations place naturally.
	for index = 1, #deps.template_records do
		local rotation = deps.template_records[index].rotations[1]
		for c = 1, #rotation.cells do
			local name = rotation.cells[c].name
			if name ~= "air" then natural[name] = true end
		end
	end

	-- Resource sources, renewable rows only.
	local resources = {}
	local resource_by_node = {}
	local function add_resource(compiled, denominator)
		compiled.p = habitat.natural_probability(compiled.key, denominator)
		compiled.host_cache = {}
		resources[#resources + 1] = compiled
		resource_by_node[compiled.node] = compiled
		natural[compiled.node] = true
	end
	for index = 1, #deps.world_plants do
		local row = deps.world_plants[index]
		natural[row.node] = true
		if habitat.is_renewable(row.key) then
			add_resource(habitat.compile_world(row), row.density)
		end
	end
	for index = 1, #deps.p9g_rows do
		local row = deps.p9g_rows[index]
		natural[row.source_node] = true
		if habitat.is_renewable(row.key) then
			add_resource(habitat.compile_p9g(row), row.fill_denominator)
		end
	end
	for index = 1, #(deps.extra_natural_names or {}) do
		natural[deps.extra_natural_names[index]] = true
	end

	-- Every support any renewable plant accepts: the ground a spot search needs.
	local supports = {}
	for _, target in pairs(cover) do
		for name in pairs(target.hosts) do supports[name] = true end
	end
	for _, target in pairs(woody) do
		for name in pairs(target.hosts) do supports[name] = true end
	end
	for index = 1, #resources do
		local source = resources[index]
		if source.kind == "world" then
			for _, set in pairs(source.hosts) do
				for name in pairs(set) do supports[name] = true end
			end
		else
			for _, biome in pairs(source.hosts) do
				for name in pairs(biome) do supports[name] = true end
			end
		end
	end
	local support_list = sorted_keys(supports)
	local cover_list = sorted_keys(cover_names)
	local marker_list = sorted_keys(woody_markers)

	local WORLD_SHORE_WATER = {coastal_shelf = true, deep_ocean = true,
		immutable_dragon_channel = true}
	local NEIGHBOUR_X, NEIGHBOUR_Z = {-1, 1, 0, 0}, {0, 0, -1, 1}
	-- The writers' shore predicates on planned water (world_content.lua
	-- `shore`, r7_p9g.lua `shore_matches`); `ground` is the support's y.
	local function shore_ok(source, x, ground, z)
		if source.shore == "none" then return true end
		for direction = 1, 4 do
			local water, _, _, _, _, bed, level = column_values_at(
				x + NEIGHBOUR_X[direction], z + NEIGHBOUR_Z[direction])
			if source.kind == "world" then
				if level and bed < level and math.abs(ground - level) <= 1 and
						(water == "planned_water" or (source.shore == "any" and
							WORLD_SHORE_WATER[water])) then
					return true
				end
			elseif source.shore_classes[water] then
				return true
			end
		end
		return false
	end

	local function host_list(source, biome, zone)
		local key = tostring(biome) .. "\0" .. tostring(zone)
		local list = source.host_cache[key]
		if not list then
			list = habitat.host_names(source, biome, zone)
			source.host_cache[key] = list
		end
		return list
	end

	local function site_allowed(rule, values)
		if rule == 1 then return values.terrain_y >= 60 end
		if rule == 2 then return values.relief ~= "mountain" end
		return rule == 0
	end

	-- One decoration class (cover or woody) at a site, or nil.
	-- The fixed part of one decoration class at a biome, support and site
	-- rule outcome (species, summed density, marker divisors), cached.
	local function decoration_base(class_name, target, values)
		local rows = target and target.by_support[values.support]
		if not rows then return nil end
		local key = values.support .. "|" ..
			(site_allowed(1, values) and "1" or "0") ..
			(site_allowed(2, values) and "1" or "0")
		target.cache = target.cache or {}
		local base = target.cache[key]
		if base ~= nil then return base or nil end
		local species, total = {}, 0
		for index = 1, #rows do
			local row = rows[index]
			if site_allowed(row.rule, values) then
				species[#species + 1] = row
				total = total + row.weight
			end
		end
		if total <= 0 then
			target.cache[key] = false
			return nil
		end
		base = {total = total, species = species}
		if class_name == "woody" then
			-- A marker shared by two rows (jungle and emergent jungle trees)
			-- counts plants by the density-weighted mean of their columns.
			local weight, columns = {}, {}
			for index = 1, #species do
				local row = species[index]
				for m = 1, #row.markers do
					local marker = row.markers[m]
					weight[marker] = (weight[marker] or 0) + row.weight
					columns[marker] = (columns[marker] or 0) + row.weight * row.columns
				end
			end
			base.divisor = {}
			for marker, value in pairs(global_divisor) do base.divisor[marker] = value end
			for marker, value in pairs(weight) do
				base.divisor[marker] = columns[marker] / value
			end
		end
		target.cache[key] = base
		return base
	end

	-- One decoration class (cover or woody) at a site, or nil.
	local function decoration_category(class_name, target, values)
		local base = decoration_base(class_name, target, values)
		if not base then return nil end
		local factor = habitat.vegetation_factor(class_name, values)
		if factor <= 0 then return nil end
		return {class = class_name, key = class_name .. ":" .. values.biome,
			p = base.total * factor, hosts = target.host_list,
			species = base.species, divisor = base.divisor, shore = false,
			names = class_name == "cover" and cover_list or marker_list}
	end

	-- The natural plant categories at a live site: `x, y, z` the plant
	-- position, `support` the node name below it and `light` its natural
	-- light at noon. Returns an array of categories (possibly empty) and the
	-- site values, or nil and a reason. A category is
	--   {class = "resource"|"cover"|"woody", key, p (expected plants per
	--    eligible support), hosts (eligible support names), names (plant or
	--    marker names counted as present), species (weighted placements),
	--    shore (true for a shoreline row), divisor (woody: marker columns per
	--    plant)}.
	-- Whether the writer keeps a column's planned surface bare of vegetation
	-- (r6_planner.lua `p7_support`): an anchor platform, any land grade
	-- except a dry anchor grade outside the vegetation exclusion (the natural
	-- skin around starts and capitals), a sealed river or lake column, and a
	-- surface cave mouth cutting the planned surface.
	local function writer_bare(x, z, terrain_y, water_y, river_id,
			functional_kind, functional_feature_id)
		if river_id ~= nil then return true end
		if functional_kind ~= nil then
			local wet = water_y ~= nil and water_y > terrain_y
			local dry_anchor_grade = functional_kind == "land_grade" and
				type(functional_feature_id) == "string" and
				functional_feature_id:match("^anchor_%d%d%d$") ~= nil and not wet and
				deps.static_exclusion_values_at(x, z, "vegetation") == nil
			if not dry_anchor_grade then return true end
		end
		local cave_low, cave_high = deps.surface_cave_run_at(x, z)
		return cave_low ~= nil and cave_low <= terrain_y and terrain_y <= cave_high
	end

	function M.categories(x, y, z, support, light)
		local water, _, zone, biome, _, terrain_y, water_y, river_id, _,
			functional_kind, _, functional_feature_id = column_values_at(x, z)
		if water ~= "land" or type(biome) ~= "string" then return nil, "not_land" end
		local overlay = deps.overlay_exclusion_at(x, z)
		if overlay == "road_corridor" or overlay == "inland_water" then
			return nil, "overlay"
		end
		local bank = overlay == "water_bank"
		local cave = y <= terrain_y - 2
		if not cave and writer_bare(x, z, terrain_y, water_y, river_id,
				functional_kind, functional_feature_id) then
			return nil, "writer_bare"
		end
		if not cave and (light or 0) < M.SURFACE_MIN_LIGHT then return nil, "dark" end
		local values = {x = x, y = y, z = z, zone = zone, biome = biome,
			terrain_y = terrain_y, support = support,
			mode = cave and "cave" or "surface",
			level = not cave and deps.surface_mob_level_at(x, z) or nil,
			relief = not cave and deps.primary_relief_at(x, z) or nil}
		local result = {}
		for index = 1, #resources do
			local source = resources[index]
			if (not bank or source.shore ~= "none") and
					habitat.habitat_matches(source, values) and
					shore_ok(source, x, y - 1, z) then
				result[#result + 1] = {class = "resource", key = source.key,
					p = source.p, hosts = host_list(source, biome, zone),
					names = {source.node}, shore = source.shore ~= "none",
					species = {{node = source.node, param2 = 0, weight = 1}}}
			end
		end
		if not cave and not bank and terrain_y >= 1 then
			result[#result + 1] = decoration_category("cover", cover[biome], values)
			if (light or 0) >= M.WOODY_MIN_LIGHT then
				result[#result + 1] = decoration_category("woody", woody[biome], values)
			end
		end
		return result, values
	end

	-- Support names any renewable plant accepts (sorted).
	function M.support_names() return support_list end
	-- Every ground-cover plant node (sorted); counted together as one total.
	function M.cover_names() return cover_list end
	-- Every woody marker node (sorted).
	function M.woody_markers() return marker_list end
	-- Nodes the world generator places as natural vegetation (set copy).
	function M.natural_vegetation()
		local result = {}
		for name in pairs(natural) do result[name] = true end
		return result
	end
	-- Sapling per woody decoration row; rows without a renewal path.
	function M.woody_species()
		local result = {}
		for id, species in pairs(WOODY) do result[id] = species.sapling end
		return result
	end
	function M.not_renewed()
		local result = {}
		for id, reason in pairs(NOT_RENEWED) do result[id] = reason end
		return result
	end
	-- Renewable resource source by node name (key, p, kind), or nil.
	function M.resource(node)
		local source = resource_by_node[node]
		return source and {key = source.key, p = source.p, kind = source.kind,
			shore = source.shore} or nil
	end
	-- The palette of one biome and support: {class, node, weight} rows.
	function M.palette(class_name, biome, support)
		local target = (class_name == "cover" and cover or woody)[biome]
		local rows = target and target.by_support[support] or {}
		local result = {}
		for index = 1, #rows do
			result[index] = {id = rows[index].id, node = rows[index].node,
				param2 = rows[index].param2, weight = rows[index].weight,
				columns = rows[index].columns}
		end
		return result
	end
	return M
end
