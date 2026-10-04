-- The 12 WP33 source-node registrations. This module never places a node.

return function(engine, catalog, harvest)
	if type(engine) ~= "table" or type(catalog) ~= "table" or
			type(harvest) ~= "table" then
		error("grug_gathering: node dependencies differ", 0)
	end

	local function source_definition(row, groups)
		local definition = {
			description = row.name .. " Source",
			drawtype = "plantlike",
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
			sounds = default.node_sound_leaves_defaults(),
			visual_scale = 1.0,
			selection_box = {type = "fixed",
				fixed = {-0.35, -0.5, -0.35, 0.35, 0.35, 0.35}},
		}
		return definition
	end

	local registered_nodes = {}
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
		engine.register_node(row.source_node, source_definition(row, groups))
		registered_nodes[#registered_nodes + 1] = row.source_node
	end

	return registered_nodes
end
