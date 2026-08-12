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
		if (node.groups or {}).cracky then
			fail("resource node retains competing cracky group: " ..
				resource.natural_node)
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

	for _, node_name in ipairs(grug_materials.NATURAL_GROUND_NODES) do
		local def = core.registered_nodes[node_name]
		if not def or (def.groups or {}).grug_natural ~= 1 then
			fail("generated ground lacks natural marker: " .. node_name)
		end
	end

	for _, material in ipairs(grug_materials.PROCESSED_MATERIALS) do
		if not raw_item(material.item) then
			fail("missing concrete processed item " .. material.item)
		end
		local block = rawget(core.registered_nodes, material.block_node)
		local groups = block and block.groups or {}
		if not block or groups.grug_natural or groups.grug_resource or
				groups.grug_stratum or (tonumber(groups.level) or 0) > 0 then
			fail("missing or misclassified storage node " .. material.block_node)
		end
		if block.drop ~= material.block_node then
			fail("storage node must drop itself: " .. material.block_node)
		end
	end
	for _, tier in ipairs(grug_materials.TIERS) do
		if not raw_item(tier.bar_item) or
				not rawget(core.registered_nodes, tier.block_node) then
			fail("missing processed tier forms for " .. tier.key)
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
	for _, derivative in ipairs(grug_materials.STORAGE_DERIVATIVES) do
		local target = raw_item(derivative.target)
		if not target or target.description ~= derivative.description or
			(target.groups or {}).grug_natural then
			fail("invalid canonical storage derivative: " .. derivative.target)
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
		local groups = def.groups or {}
		if tonumber(groups.level) and groups.level > 0 then
			fail("node retains non-zero level group: " .. name)
		end
		if groups.grug_resource then
			local resource = grug_materials.resource_for_node(name)
			if not resource or groups.grug_resource ~= resource.harvest_tier or
				groups.cracky then
				fail("unregistered or malformed resource group: " .. name)
			end
		end
	end

	for name, def in pairs(core.registered_items) do
		local groups = def.groups or {}
		if groups.grug_pick_tier then
			local tier = tonumber(groups.grug_pick_tier)
			local caps = def.tool_capabilities and def.tool_capabilities.groupcaps or {}
			if not tier or tier ~= math.floor(tier) or tier < 1 or tier > 6 or
				not caps.cracky or not caps.grug_resource or
				caps.cracky.maxlevel ~= 0 or caps.grug_resource.maxlevel ~= 0 then
				fail("invalid Grudgelands pick contract: " .. name)
			end
			for harvest_tier = 1, 5 do
				if not caps.grug_resource.times[harvest_tier] then
					fail("incomplete resource capability on " .. name)
				end
			end
		end
	end
	local active_max_drop_levels = {
		["default:pick_wood"] = 0,
		["default:pick_stone"] = 0,
		["default:pick_bronze"] = 1,
		["default:pick_steel"] = 1,
	}
	local active_punch_uses = {
		["default:pick_wood"] = 10,
		["default:pick_stone"] = 20,
		["default:pick_bronze"] = 60,
		["default:pick_steel"] = 60,
	}
	for name, expected in pairs(active_max_drop_levels) do
		local def = core.registered_items[name]
		local actual = def and def.tool_capabilities and
			def.tool_capabilities.max_drop_level
		if actual ~= expected then
			fail("unexpected max_drop_level on " .. name)
		end
		if def.tool_capabilities.punch_attack_uses ~= active_punch_uses[name] then
			fail("unexpected punch_attack_uses on " .. name)
		end
	end

	for tier = 1, 6 do
		local profile = grug_materials.PICK_PROFILES[tier]
		local caps = grug_materials.build_pick_capabilities(tier)
		if not profile or profile.tier ~= tier or
			caps.groupcaps.cracky.maxlevel ~= 0 or
			caps.groupcaps.grug_resource.maxlevel ~= 0 or
			profile.key ~= grug_materials.TIERS[tier].key or
			profile.ordinary_time <= 0 or profile.uses <= 0 then
			fail("invalid pure pick profile at tier " .. tier)
		end
		for rating = 1, 3 do
			if not profile.cracky_times[rating] or
				profile.cracky_times[rating] <= 0 then
				fail("incomplete cracky profile at tier " .. tier)
			end
		end
		for harvest_tier = 1, 5 do
			local shortfall = math.max(0, harvest_tier - tier)
			local multiplier = grug_materials.SHORTFALL_MULTIPLIERS[shortfall] or 10
			if caps.groupcaps.grug_resource.times[harvest_tier] ~=
				profile.ordinary_time * multiplier then
				fail("incorrect harvest multiplier at pick tier " .. tier ..
					", resource tier " .. harvest_tier)
			end
		end
		if tier > 1 then
			local previous = grug_materials.PICK_PROFILES[tier - 1]
			if profile.ordinary_time > previous.ordinary_time then
				fail("ordinary resource time slows at tier " .. tier)
			end
			for rating, seconds in pairs(profile.cracky_times) do
				local previous_seconds = previous.cracky_times[rating]
				if previous_seconds and seconds > previous_seconds then
					fail("pick profile slows at tier " .. tier ..
						", cracky rating " .. rating)
				end
			end
		end
	end

	if core.node_dig ~= grug_materials.node_dig_wrapper then
		fail("core.node_dig wrapper was replaced after grug_materials loaded")
	end

	core.log("action", "[grug_materials] registry audit passed: 6 tiers, " ..
		#grug_materials.RESOURCES .. " resources, " ..
		#grug_materials.PROCESSED_MATERIALS ..
		" processed forms, 6 race regions")
end)
