-- Startup contract audit. Structural checks run in registry.lua; this pass
-- verifies the fully loaded engine registry and fails before a world starts.

local function fail(message)
	error("grug_materials startup audit: " .. message)
end

local function raw_item(name)
	return rawget(core.registered_items, name)
end

core.register_on_mods_loaded(function()
	for _, tier in ipairs(grug_materials.TIERS) do
		local def = core.registered_nodes[tier.node]
		if not def or (def.groups or {}).grug_stratum ~= tier.id then
			fail("missing or misclassified stratum " .. tier.node)
		end
	end

	for _, resource in ipairs(grug_materials.RESOURCES) do
		local node = core.registered_nodes[resource.natural_node]
		if not node or (node.groups or {}).grug_natural ~= 1 or
				(node.groups or {}).grug_resource ~= resource.harvest_tier then
			fail("missing or misclassified resource node " .. resource.natural_node)
		end
		if not core.registered_items[resource.raw_item] then
			fail("missing raw resource item " .. resource.raw_item)
		end
		if resource.cut_item and not core.registered_items[resource.cut_item] then
			fail("missing cut resource item " .. resource.cut_item)
		end
		if resource.block_node and not core.registered_nodes[resource.block_node] then
			fail("missing storage node " .. resource.block_node)
		end
	end

	for _, material in pairs(grug_materials.CULTURAL_MATERIALS) do
		if not core.registered_items[material.item] then
			fail("missing cultural material for " .. material.race)
		end
		local row = grug_materials.RACE_REGIONS[material.race]
		local wood = row and grug_materials.SIGNATURE_WOODS[row.signature_wood]
		if not wood or not core.registered_nodes[wood.tree] or
				not core.registered_nodes[wood.wood] then
			fail("missing signature wood registration for " .. material.race)
		end
	end

	for source, target in pairs(grug_materials.LEGACY_ALIASES) do
		if raw_item(source) then
			fail("legacy id remains a playable registration: " .. source)
		end
		if core.registered_aliases[source] ~= target then
			fail("missing migration alias " .. source .. " -> " .. target)
		end
		if not core.registered_items[target] then
			fail("migration target is not registered: " .. target)
		end
	end
	for name in pairs(core.registered_items) do
		for _, stem in ipairs(grug_materials.FORBIDDEN_RUNTIME_STEMS) do
			if name:find(stem, 1, true) then
				fail("forbidden legacy registration remains: " .. name)
			end
		end
	end

	-- The retired engine level gate must not survive in any loaded node.
	for name, def in pairs(core.registered_nodes) do
		if tonumber((def.groups or {}).level) and (def.groups or {}).level > 0 then
			fail("node retains non-zero level group: " .. name)
		end
	end

	core.log("action", "[grug_materials] registry audit passed: 6 tiers, " ..
		#grug_materials.RESOURCES .. " resources, 6 race regions")
end)
