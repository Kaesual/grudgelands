-- The 18 WP33 source-node registrations. This module never places a node.

return function(engine, catalog, harvest)
	if type(engine) ~= "table" or type(catalog) ~= "table" or
			type(harvest) ~= "table" then
		error("grug_gathering: node dependencies differ", 0)
	end

	local function source_definition(row, groups, cultural)
		local definition = {
			description = row.name .. " Source",
			drawtype = cultural and "nodebox" or "plantlike",
			tiles = {row.image},
			inventory_image = row.image,
			wield_image = row.image,
			paramtype = "light",
			sunlight_propagates = true,
			walkable = false,
			buildable_to = false,
			is_ground_content = false,
			liquidtype = "none",
			floodable = false,
			groups = groups,
			drop = row.raw_item,
			can_dig = harvest.can_dig(row),
			sounds = cultural and default.node_sound_stone_defaults() or
				default.node_sound_leaves_defaults(),
		}
		if cultural then
			definition.node_box = {type = "fixed",
				fixed = {-0.35, -0.5, -0.35, 0.35, -0.2, 0.35}}
			definition.selection_box = {type = "fixed",
				fixed = {-0.4, -0.5, -0.4, 0.4, -0.15, 0.4}}
		else
			definition.visual_scale = 1.0
			definition.selection_box = {type = "fixed",
				fixed = {-0.35, -0.5, -0.35, 0.35, 0.35, 0.35}}
		end
		return definition
	end

	local registered_nodes = {}
	local cultural = catalog.cultural_sources()
	for index = 1, #cultural do
		local row = cultural[index]
		local groups = {
			grug_gathering_source = 1,
			grug_cultural_source = 1,
			not_in_creative_inventory = 1,
		}
		groups[row.ordinary_group] = 3
		local concentrated_group = row.concentrated_family == "pick" and "cracky" or
			(row.concentrated_family == "axe" and "choppy" or "crumbly")
		groups[concentrated_group] = groups[concentrated_group] or 3
		engine.register_node(row.source_node,
			source_definition(row, groups, true))
		registered_nodes[#registered_nodes + 1] = row.source_node
	end

	local p9g = catalog.p9g_sources()
	for index = 1, #p9g do
		local row = p9g[index]
		engine.register_craftitem(row.raw_item, {
			description = row.name,
			inventory_image = row.image,
		})
		local groups = {
			grug_gathering_source = 1,
			not_in_creative_inventory = 1,
			snappy = 3,
			oddly_breakable_by_hand = 3,
		}
		if row.harvest_kind == "healing_herb" then
			groups.grug_healing_herb = row.required_group
		elseif row.harvest_kind == "spice" then
			groups.grug_spice = row.required_group
		elseif row.harvest_kind == "food" then
			groups.grug_food = 1
		elseif row.harvest_kind == "found_only_food" then
			groups.grug_food = 1
			groups.grug_found_only_food = 1
		else
			error("grug_gathering: unknown P9G harvest kind", 0)
		end
		engine.register_node(row.source_node,
			source_definition(row, groups, false))
		registered_nodes[#registered_nodes + 1] = row.source_node
	end

	return registered_nodes
end
